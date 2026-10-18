class_name SingleFrameLayerStrip
extends PanelContainer

enum ContextAction {
	PROPERTIES,
	CLIPPING_MASK,
	FLATTEN,
	FLATTEN_VISIBLE,
	MULTI_SELECT = 1000,
	MOVE_LEFT,
	MOVE_RIGHT,
	DUPLICATE,
	MERGE_RIGHT,
	EFFECTS,
	RENAME,
	CREATE_FOLDER,
	MERGE_SELECTED,
}

const LAYER_CARD_SCENE := preload("res://src/UI/Timeline/SingleFrameLayerCard.tscn")
const GROUP_BRACKET_SCENE := preload("res://src/UI/Timeline/SingleFrameLayerGroupBracket.tscn")
const BLEND_MODE_MENU := preload("res://src/UI/Timeline/LayerBlendModeMenu.gd")
const GESTURE_RESOLVER := preload("res://src/UI/ProjectGallery/ProjectCardGestureResolver.gd")
const CONTEXT_HOLD_MSEC := 650

const VISIBLE_EYE_TEXTURE := preload("res://assets/graphics/layers/layer_visible.png")
const INVISIBLE_EYE_TEXTURE := preload("res://assets/graphics/layers/layer_invisible.png")

var multiselect_mode := false
var _bound_project: Project
var _displayed_frame := -1
var _gesture_resolver := GESTURE_RESOLVER.new()
var _cards_by_layer: Dictionary = {}
var _settings_layer: BaseLayer
var _blend_menu_has_group := -1
var _context_layer_index := -1

@onready var layer_settings_panel := %LayerSettingsPanel as PanelContainer
@onready var current_layer_name := %CurrentLayerName as Label
@onready var layer_opacity_slider := %OpacitySlider as ValueSlider
@onready var layer_visibility_button := %OpacityEye as Button
@onready var layer_visibility_icon := %OpacityEyeIcon as TextureRect
@onready var layer_style_button := %LayerStyle as OptionButton
@onready var layer_content := %LayerContent as Control
@onready var group_bracket_lane := %GroupBracketLane as Control
@onready var layer_row := %LayerRow as HBoxContainer
@onready var scroll_container := %LayerScroll as ScrollContainer
@onready var add_layer_button := %AddLayer as Button
@onready var layer_context_menu := %LayerContextMenu as PopupMenu


func _ready() -> void:
	_gesture_resolver.long_press_msec = CONTEXT_HOLD_MSEC
	_setup_context_menu()
	layer_opacity_slider.value_changed.connect(_on_layer_opacity_changed)
	layer_visibility_button.pressed.connect(_on_layer_visibility_pressed)
	layer_style_button.item_selected.connect(_on_blend_mode_selected)
	add_layer_button.pressed.connect(_on_add_layer_pressed)
	Global.cel_switched.connect(_on_cel_switched)
	set_process(true)
	set_project(Global.current_project)
	_sync_layer_settings()


func _process(_delta: float) -> void:
	_consume_gesture_actions(_gesture_resolver.poll(Time.get_ticks_msec()))


func _exit_tree() -> void:
	_disconnect_settings_layer()
	_unbind_project()
	_gesture_resolver.reset()
	if Global.cel_switched.is_connected(_on_cel_switched):
		Global.cel_switched.disconnect(_on_cel_switched)


func set_project(project: Project) -> void:
	if _bound_project == project:
		refresh()
		return
	_bind_project(project)
	refresh()


func refresh() -> void:
	if not is_instance_valid(layer_row):
		return
	_cards_by_layer.clear()
	for child in layer_row.get_children():
		if child == add_layer_button:
			continue
		layer_row.remove_child(child)
		child.queue_free()
	_clear_group_brackets()

	var project := _bound_project
	if project == null:
		_displayed_frame = -1
		multiselect_mode = false
		_sync_layer_settings()
		return
	_displayed_frame = project.current_frame
	for visual_index in project.layers.size():
		var layer_index := project.layers.size() - 1 - visual_index
		if project.layers[layer_index] is GroupLayer:
			continue
		var card := LAYER_CARD_SCENE.instantiate() as SingleFrameLayerCard
		layer_row.add_child(card)
		layer_row.move_child(card, layer_row.get_child_count() - 2)
		card.setup(project, layer_index, project.current_frame)
		card.pointer_down.connect(_on_card_pointer_down)
		card.pointer_up.connect(_on_card_pointer_up)
		card.pointer_cancel.connect(_on_card_pointer_cancel)
		card.context_requested.connect(_show_card_context_menu)
		card.swipe_selection.connect(_on_card_swipe_selection)
		_cards_by_layer[layer_index] = card
	_sync_layer_settings()
	call_deferred("_sync_content_geometry")
	call_deferred("_rebuild_group_brackets")
	call_deferred("_ensure_current_layer_visible")


func sync_selection() -> void:
	var project := _bound_project
	if project == null:
		return
	for child in layer_row.get_children():
		if child is SingleFrameLayerCard:
			(child as SingleFrameLayerCard)._sync_selected()
	_sync_layer_settings()
	call_deferred("_ensure_current_layer_visible")


func set_multiselect_mode(enabled: bool, initial_layer := -1) -> void:
	if multiselect_mode == enabled and initial_layer < 0:
		return
	multiselect_mode = enabled
	_gesture_resolver.reset()
	call_deferred("_sync_content_geometry")
	var project := _bound_project
	if project == null or project != Global.current_project:
		return
	if enabled:
		if initial_layer >= 0:
			_select_only_layer(initial_layer)
	else:
		project.selected_cels.clear()
		project.selected_cels.append([project.current_frame, project.current_layer])
		project.change_cel(-1, project.current_layer)


func _bind_project(project: Project) -> void:
	_unbind_project()
	_bound_project = project
	multiselect_mode = false
	_gesture_resolver.reset()
	if not is_instance_valid(_bound_project):
		return
	if not _bound_project.layers_updated.is_connected(_on_layers_updated):
		_bound_project.layers_updated.connect(_on_layers_updated)
	if not _bound_project.frames_updated.is_connected(_on_frames_updated):
		_bound_project.frames_updated.connect(_on_frames_updated)


func _unbind_project() -> void:
	if not is_instance_valid(_bound_project):
		_bound_project = null
		return
	if _bound_project.layers_updated.is_connected(_on_layers_updated):
		_bound_project.layers_updated.disconnect(_on_layers_updated)
	if _bound_project.frames_updated.is_connected(_on_frames_updated):
		_bound_project.frames_updated.disconnect(_on_frames_updated)
	_bound_project = null


func _on_layers_updated() -> void:
	refresh()


func _on_frames_updated() -> void:
	refresh()


func _on_cel_switched() -> void:
	if _bound_project != Global.current_project:
		set_project(Global.current_project)
		return
	var project := _bound_project
	if project == null:
		return
	if _displayed_frame != project.current_frame:
		refresh()
	else:
		sync_selection()


func _on_layer_opacity_changed(value: float) -> void:
	var project := _bound_project
	if (
		project == null
		or project != Global.current_project
		or project.current_layer < 0
		or project.current_layer >= project.layers.size()
	):
		return
	var layer := project.layers[project.current_layer]
	var new_opacity := value / 100.0
	if is_equal_approx(layer.opacity, new_opacity):
		return
	if Global.layer_opacity_undoable:
		project.undo_redo.create_action("Change Layer Opacity", UndoRedo.MergeMode.MERGE_ENDS)
		project.undo_redo.add_do_property(layer, "opacity", new_opacity)
		project.undo_redo.add_undo_property(layer, "opacity", layer.opacity)
		project.undo_redo.add_do_method(Global.canvas.queue_redraw)
		project.undo_redo.add_undo_method(Global.canvas.queue_redraw)
		project.undo_redo.add_do_method(_sync_layer_settings)
		project.undo_redo.add_undo_method(_sync_layer_settings)
		project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
		project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
		project.undo_redo.commit_action()
	else:
		layer.opacity = new_opacity
		Global.canvas.queue_redraw()
		_sync_layer_settings()


func _on_layer_visibility_pressed() -> void:
	var project := _bound_project
	if (
		project == null
		or project != Global.current_project
		or project.current_layer < 0
		or project.current_layer >= project.layers.size()
	):
		return
	var layer := project.layers[project.current_layer]
	Global.transform_content_confirmed.emit()
	if Global.layer_visibility_undoable:
		project.undo_redo.create_action("Change Layer Visibility")
		project.undo_redo.add_do_property(layer, "visible", not layer.visible)
		project.undo_redo.add_undo_property(layer, "visible", layer.visible)
		project.undo_redo.add_do_property(Global.canvas, "update_all_layers", true)
		project.undo_redo.add_undo_property(Global.canvas, "update_all_layers", true)
		project.undo_redo.add_do_method(Global.canvas.queue_redraw)
		project.undo_redo.add_undo_method(Global.canvas.queue_redraw)
		project.undo_redo.add_do_method(_sync_layer_settings)
		project.undo_redo.add_undo_method(_sync_layer_settings)
		if is_instance_valid(Global.animation_timeline):
			project.undo_redo.add_do_method(Global.animation_timeline.update_global_layer_buttons)
			project.undo_redo.add_undo_method(Global.animation_timeline.update_global_layer_buttons)
		project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
		project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
		project.undo_redo.commit_action()
	else:
		layer.visible = not layer.visible
		Global.canvas.update_all_layers = true
		Global.canvas.queue_redraw()
		if is_instance_valid(Global.animation_timeline):
			Global.animation_timeline.update_global_layer_buttons()
		_sync_layer_settings()


func _on_blend_mode_selected(index: int) -> void:
	var project := _bound_project
	if (
		project == null
		or project != Global.current_project
		or project.current_layer < 0
		or project.current_layer >= project.layers.size()
	):
		return
	var layer := project.layers[project.current_layer]
	if layer is AudioLayer:
		return
	var mode := layer_style_button.get_item_id(index)
	if mode == layer.blend_mode:
		return
	if Global.layer_blend_mode_undoable:
		project.undo_redo.create_action("Set Blend Mode")
		project.undo_redo.add_do_property(layer, "blend_mode", mode)
		project.undo_redo.add_undo_property(layer, "blend_mode", layer.blend_mode)
		project.undo_redo.add_do_method(_refresh_blend_mode_rendering)
		project.undo_redo.add_undo_method(_refresh_blend_mode_rendering)
		project.undo_redo.add_do_method(_sync_layer_settings)
		project.undo_redo.add_undo_method(_sync_layer_settings)
		project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
		project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
		project.undo_redo.commit_action()
	else:
		layer.blend_mode = mode as BaseLayer.BlendModes
		_refresh_blend_mode_rendering()
		_sync_layer_settings()


func _refresh_blend_mode_rendering() -> void:
	if is_instance_valid(Global.animation_timeline):
		Global.animation_timeline._update_layers()
	elif is_instance_valid(Global.canvas):
		Global.canvas.update_all_layers = true
		Global.canvas.draw_layers()


func _refresh_blend_mode_options(layer: BaseLayer) -> void:
	var allows_group := layer is GroupLayer
	if _blend_menu_has_group != int(allows_group):
		BLEND_MODE_MENU.populate(layer_style_button, allows_group)
		_blend_menu_has_group = int(allows_group)
	layer_style_button.selected = layer_style_button.get_item_index(layer.blend_mode)


func _sync_layer_settings() -> void:
	if not is_instance_valid(layer_settings_panel):
		return
	var project := _bound_project
	var has_layer := (
		project != null
		and project == Global.current_project
		and project.current_layer >= 0
		and project.current_layer < project.layers.size()
	)
	layer_settings_panel.modulate = Color(1.0, 1.0, 1.0, 1.0 if has_layer else 0.55)
	layer_opacity_slider.editable = has_layer
	layer_visibility_button.disabled = not has_layer
	layer_style_button.disabled = not has_layer
	if not has_layer:
		_disconnect_settings_layer()
		current_layer_name.text = tr("No layer")
		_set_opacity_slider_value(100.0)
		layer_visibility_icon.texture = VISIBLE_EYE_TEXTURE
		layer_visibility_button.tooltip_text = tr("Toggle layer visibility")
		layer_style_button.selected = -1
		return

	var layer := project.layers[project.current_layer]
	_bind_settings_layer(layer)
	current_layer_name.text = layer.name
	_set_opacity_slider_value(layer.opacity * 100.0)
	_sync_visibility_icon(layer)
	_refresh_blend_mode_options(layer)
	layer_style_button.disabled = layer is AudioLayer


func _sync_visibility_icon(layer: BaseLayer) -> void:
	layer_visibility_icon.texture = VISIBLE_EYE_TEXTURE if layer.visible else INVISIBLE_EYE_TEXTURE
	layer_visibility_button.tooltip_text = tr("Hide layer") if layer.visible else tr("Show layer")


func _on_settings_layer_visibility_changed() -> void:
	if is_instance_valid(_settings_layer):
		_sync_visibility_icon(_settings_layer)


func _set_opacity_slider_value(value: float) -> void:
	var callback := Callable(self, "_on_layer_opacity_changed")
	var was_connected := layer_opacity_slider.value_changed.is_connected(callback)
	if was_connected:
		layer_opacity_slider.value_changed.disconnect(callback)
	layer_opacity_slider.value = value
	if was_connected:
		layer_opacity_slider.value_changed.connect(callback)


func _bind_settings_layer(layer: BaseLayer) -> void:
	if _settings_layer == layer:
		return
	_disconnect_settings_layer()
	_settings_layer = layer
	if is_instance_valid(_settings_layer):
		_settings_layer.name_changed.connect(_on_settings_layer_name_changed)
		_settings_layer.visibility_changed.connect(_on_settings_layer_visibility_changed)


func _disconnect_settings_layer() -> void:
	if not is_instance_valid(_settings_layer):
		_settings_layer = null
		return
	if _settings_layer.name_changed.is_connected(_on_settings_layer_name_changed):
		_settings_layer.name_changed.disconnect(_on_settings_layer_name_changed)
	if _settings_layer.visibility_changed.is_connected(_on_settings_layer_visibility_changed):
		_settings_layer.visibility_changed.disconnect(_on_settings_layer_visibility_changed)
	_settings_layer = null


func _on_settings_layer_name_changed() -> void:
	if is_instance_valid(_settings_layer):
		current_layer_name.text = _settings_layer.name


func _on_add_layer_pressed() -> void:
	if _bound_project != Global.current_project:
		return
	if is_instance_valid(Global.animation_timeline):
		Global.animation_timeline.add_default_pixel_layer()


func _on_card_pointer_down(layer_index: int, position: Vector2, timestamp_msec: int) -> void:
	_consume_gesture_actions(
		_gesture_resolver.pointer_down(str(layer_index), position, timestamp_msec)
	)


func _on_card_pointer_up(layer_index: int, position: Vector2, timestamp_msec: int) -> void:
	_consume_gesture_actions(
		_gesture_resolver.pointer_up(str(layer_index), position, timestamp_msec)
	)


func _on_card_pointer_cancel(layer_index: int) -> void:
	_gesture_resolver.pointer_cancel(str(layer_index))


func _on_card_swipe_selection(layer_index: int) -> void:
	if not _is_valid_card_layer(layer_index):
		return
	# A down swipe is additive and independently toggles every layer card.
	# First swipe starts with an empty explicit multi-selection rather than
	# counting the previously focused layer as an accidental selection.
	if not multiselect_mode:
		set_multiselect_mode(true)
		_bound_project.selected_cels.clear()
	_toggle_layer_in_multiselect(layer_index)


func _setup_context_menu() -> void:
	layer_context_menu.add_item(tr("Properties"), ContextAction.PROPERTIES)
	layer_context_menu.add_item(tr("Rename"), ContextAction.RENAME)
	layer_context_menu.add_check_item(
		tr("Clipping mask (layer to right)"), ContextAction.CLIPPING_MASK
	)
	layer_context_menu.add_item(tr("Flatten"), ContextAction.FLATTEN)
	layer_context_menu.add_item(tr("Flatten visible"), ContextAction.FLATTEN_VISIBLE)
	layer_context_menu.add_separator()
	layer_context_menu.add_item(tr("Move layer left (up)"), ContextAction.MOVE_LEFT)
	layer_context_menu.add_item(tr("Move layer right (down)"), ContextAction.MOVE_RIGHT)
	layer_context_menu.add_item(tr("Duplicate layer"), ContextAction.DUPLICATE)
	layer_context_menu.add_item(tr("Create folder from selection"), ContextAction.CREATE_FOLDER)
	layer_context_menu.add_item(tr("Merge selected layers"), ContextAction.MERGE_SELECTED)
	layer_context_menu.add_item(tr("Merge right (down)"), ContextAction.MERGE_RIGHT)
	layer_context_menu.add_item(tr("Layer effects"), ContextAction.EFFECTS)
	layer_context_menu.add_separator()
	layer_context_menu.add_item(tr("Select multiple layers"), ContextAction.MULTI_SELECT)
	layer_context_menu.id_pressed.connect(_on_context_action)
	layer_context_menu.about_to_popup.connect(_sync_context_menu)


func _show_card_context_menu(layer_index: int, position: Vector2) -> void:
	if not _is_valid_card_layer(layer_index):
		return
	_context_layer_index = layer_index
	# Preserve an existing multi-selection; otherwise target the card under the finger.
	if not _is_layer_selected(layer_index):
		_select_only_layer(layer_index)
	elif _bound_project.current_layer != layer_index:
		_bound_project.change_cel(-1, layer_index)
	_sync_context_menu()
	layer_context_menu.popup_on_parent(Rect2(position, Vector2.ONE))


func _sync_context_menu() -> void:
	if not _is_valid_card_layer(_context_layer_index):
		return
	var project := _bound_project
	var layer := project.layers[_context_layer_index]
	var clip_index := layer_context_menu.get_item_index(ContextAction.CLIPPING_MASK)
	layer_context_menu.set_item_checked(clip_index, layer.clipping_mask)
	layer_context_menu.set_item_disabled(clip_index, _context_layer_index == 0)
	var timeline := Global.animation_timeline as AnimationTimeline
	if not is_instance_valid(timeline):
		return
	# The horizontal card order is reversed from the underlying layer indices.
	# A higher-index layer is left (above); a lower-index layer is right (below).
	timeline._toggle_layer_buttons()
	_set_context_disabled(ContextAction.MOVE_LEFT, timeline.move_up_layer.disabled)
	_set_context_disabled(ContextAction.MOVE_RIGHT, timeline.move_down_layer.disabled)
	_set_context_disabled(ContextAction.MERGE_RIGHT, timeline.merge_down_layer.disabled)
	_set_context_disabled(ContextAction.EFFECTS, timeline.layer_fx.disabled)
	var selection := _selected_layer_indices()
	_set_context_disabled(ContextAction.CREATE_FOLDER, not _can_create_folder(selection))
	_set_context_disabled(ContextAction.MERGE_SELECTED, not _can_merge_layers(selection))


func _set_context_disabled(action: int, disabled: bool) -> void:
	var index := layer_context_menu.get_item_index(action)
	if index >= 0:
		layer_context_menu.set_item_disabled(index, disabled)


func _on_context_action(action: int) -> void:
	if not _is_valid_card_layer(_context_layer_index):
		return
	var timeline := Global.animation_timeline as AnimationTimeline
	if not is_instance_valid(timeline):
		return
	var project := _bound_project
	if not _is_layer_selected(_context_layer_index):
		_select_only_layer(_context_layer_index)
	match action:
		ContextAction.MULTI_SELECT:
			if not multiselect_mode:
				set_multiselect_mode(true, _context_layer_index)
		ContextAction.PROPERTIES, ContextAction.RENAME:
			var dialog := Global.control.find_child("LayerProperties") as AcceptDialog
			if is_instance_valid(dialog):
				dialog.set("layer_indices", _selected_layer_indices())
				dialog.popup_centered_clamped()
		ContextAction.CLIPPING_MASK:
			if _context_layer_index <= 0:
				return
			# Reuse the Animation layer handler so its clipping icon and canvas
			# refresh immediately when the command comes from Single Frame.
			var visual_index := project.layers.size() - 1 - _context_layer_index
			var button := timeline.layer_vbox.get_child(visual_index) as LayerButton
			if is_instance_valid(button):
				button._on_popup_menu_id_pressed(LayerButton.MenuOptions.CLIPPING_MASK)
		ContextAction.FLATTEN:
			timeline.flatten_layers.call_deferred(_selected_layer_indices(), false)
		ContextAction.FLATTEN_VISIBLE:
			timeline.flatten_layers.call_deferred(_selected_layer_indices(), true)
		ContextAction.MOVE_LEFT:
			if not timeline.move_up_layer.disabled:
				timeline.change_layer_order(true)
		ContextAction.MOVE_RIGHT:
			if not timeline.move_down_layer.disabled:
				timeline.change_layer_order(false)
		ContextAction.DUPLICATE:
			_duplicate_selected_layers()
		ContextAction.CREATE_FOLDER:
			_create_folder_from_selection()
		ContextAction.MERGE_SELECTED:
			_on_merge_layers_pressed()
		ContextAction.MERGE_RIGHT:
			if not timeline.merge_down_layer.disabled:
				timeline._on_MergeDownLayer_pressed()
		ContextAction.EFFECTS:
			if not timeline.layer_fx.disabled:
				timeline._on_layer_fx_pressed()


func _consume_gesture_actions(actions: Array[Dictionary]) -> void:
	for action: Dictionary in actions:
		var layer_index := int(str(action.get("path", "-1")))
		if not _is_valid_card_layer(layer_index):
			continue
		var kind := int(action.get("kind", -1))
		match kind:
			GESTURE_RESOLVER.ActionKind.SINGLE_TAP:
				_on_resolved_single_tap(layer_index)
			GESTURE_RESOLVER.ActionKind.LONG_PRESS:
				_show_card_context_menu(layer_index, action.get("position", Vector2.ZERO))


func _on_resolved_single_tap(layer_index: int) -> void:
	if multiselect_mode:
		# A normal tap ends the whole multi-selection and focuses only
		# the tapped layer, even when it was already in the batch.
		set_multiselect_mode(false)
	_select_only_layer(layer_index)


func _select_only_layer(layer_index: int) -> void:
	var project := _bound_project
	if (
		project == null
		or project != Global.current_project
		or not _is_valid_card_layer(layer_index)
	):
		return
	Global.transform_content_confirmed.emit()
	project.selected_cels.clear()
	project.selected_cels.append([project.current_frame, layer_index])
	project.change_cel(-1, layer_index)


func _toggle_layer_in_multiselect(layer_index: int) -> void:
	var project := _bound_project
	if (
		project == null
		or project != Global.current_project
		or not _is_valid_card_layer(layer_index)
	):
		return
	Global.transform_content_confirmed.emit()
	var frame_layer := [project.current_frame, layer_index]
	if project.selected_cels.has(frame_layer):
		project.selected_cels.erase(frame_layer)
		if project.selected_cels.is_empty():
			# Unlike change_cel(), emitting the selection update leaves
			# zero selected layers after a repeated downward swipe.
			Global.cel_switched.emit()
		else:
			project.change_cel(-1, int(project.selected_cels[0][1]))
	else:
		project.selected_cels.append(frame_layer)
		project.change_cel(-1, layer_index)


func _is_layer_selected(layer_index: int) -> bool:
	var project := _bound_project
	if project == null:
		return false
	return [project.current_frame, layer_index] in project.selected_cels


func _is_valid_card_layer(layer_index: int) -> bool:
	return (
		_bound_project != null
		and _bound_project == Global.current_project
		and layer_index >= 0
		and layer_index < _bound_project.layers.size()
		and not _bound_project.layers[layer_index] is GroupLayer
		and _cards_by_layer.has(layer_index)
	)


func _selected_layer_indices() -> PackedInt32Array:
	if not is_instance_valid(_bound_project):
		return PackedInt32Array()
	return _selected_layers_for_frame(
		_bound_project.selected_cels, _bound_project.current_frame, _bound_project.layers.size()
	)


static func _selected_layers_for_frame(
	selected_cels: Array, frame_index: int, layer_count: int
) -> PackedInt32Array:
	# Project.selected_cels is the source of truth, not a transient Button state
	# or the obsolete multi-select counter. Deduplicate by layer index.
	var indices := PackedInt32Array()
	for cel in selected_cels:
		if cel.size() < 2 or int(cel[0]) != frame_index:
			continue
		var layer_index := int(cel[1])
		if layer_index >= 0 and layer_index < layer_count and not indices.has(layer_index):
			indices.append(layer_index)
	indices.sort()
	return indices


func _can_create_folder(indices: PackedInt32Array) -> bool:
	var project := _bound_project
	if project == null or indices.is_empty():
		return false
	var common_parent: BaseLayer = project.layers[indices[0]].parent
	for layer_index in indices:
		var layer := project.layers[layer_index]
		if layer is GroupLayer or layer.parent != common_parent:
			return false
	return true


func _can_merge_layers(indices: PackedInt32Array) -> bool:
	var project := _bound_project
	if project == null or indices.size() < 2:
		return false
	for layer_index in indices:
		var layer := project.layers[layer_index]
		if layer is AudioLayer or layer is GroupLayer:
			return false
	return true


func _on_create_folder_pressed() -> void:
	_create_folder_from_selection()


func _on_merge_layers_pressed() -> void:
	var indices := _selected_layer_indices()
	if not _can_merge_layers(indices) or not is_instance_valid(Global.animation_timeline):
		return
	Global.animation_timeline.flatten_layers(indices, false)


func _on_duplicate_layers_pressed() -> void:
	_duplicate_selected_layers()


func _create_folder_from_selection() -> void:
	var project := _bound_project
	var indices := _selected_layer_indices()
	if project == null or project != Global.current_project or not _can_create_folder(indices):
		return

	var original_parents: Array = []
	for layer_index in indices:
		original_parents.append(project.layers[layer_index].parent)
	var common_parent: BaseLayer = original_parents[0]

	var folder := GroupLayer.new(project)
	folder.name = _next_folder_name(project)
	folder.parent = common_parent
	var folder_cels := []
	for frame in project.frames:
		folder_cels.append(folder.new_empty_cel())

	var folder_index := indices[-1] + 1
	var target_start := folder_index - indices.size()
	var target_indices := PackedInt32Array()
	var folder_parents: Array = []
	var selected_after := []
	for i in indices.size():
		var target_index := target_start + i
		target_indices.append(target_index)
		folder_parents.append(folder)
		selected_after.append([project.current_frame, target_index])

	var old_current_layer := project.current_layer
	var old_selection := project.selected_cels.duplicate(true)
	var folder_indices := PackedInt32Array([folder_index])

	project.undo_redo.create_action("Create Layer Folder")
	project.undo_redo.add_do_method(
		project.add_layers.bind([folder], folder_indices, [folder_cels])
	)
	project.undo_redo.add_do_method(
		project.move_layers.bind(indices, target_indices, folder_parents)
	)
	project.undo_redo.add_do_property(project, "selected_cels", selected_after)
	project.undo_redo.add_do_method(project.change_cel.bind(-1, target_indices[-1]))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))

	project.undo_redo.add_undo_method(
		project.move_layers.bind(target_indices, indices, original_parents)
	)
	project.undo_redo.add_undo_method(project.remove_layers.bind(folder_indices))
	project.undo_redo.add_undo_property(project, "selected_cels", old_selection)
	project.undo_redo.add_undo_method(project.change_cel.bind(-1, old_current_layer))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()


func _next_folder_name(project: Project) -> String:
	var folder_count := 0
	for layer in project.layers:
		if layer is GroupLayer:
			folder_count += 1
	return "%s %d" % [tr("Folder"), folder_count + 1]


func _duplicate_selected_layers() -> void:
	var project := _bound_project
	var source_indices := _selected_layer_indices()
	if project == null or project != Global.current_project or source_indices.is_empty():
		return

	var clones: Array[BaseLayer] = []
	var all_cels := []
	var new_indices := PackedInt32Array()
	for i in source_indices.size():
		var source_index := source_indices[i]
		var src_layer := project.layers[source_index]
		if src_layer is GroupLayer:
			return
		var clone_data := _clone_layer_with_cels(project, src_layer)
		var cl_layer := clone_data.get("layer") as BaseLayer
		if not is_instance_valid(cl_layer):
			return
		clones.append(cl_layer)
		all_cels.append(clone_data.get("cels", []))
		new_indices.append(source_index + 1 + i)

	var old_current_layer := project.current_layer
	var old_selection := project.selected_cels.duplicate(true)
	var new_selection := []
	for layer_index in new_indices:
		new_selection.append([project.current_frame, layer_index])

	project.undo_redo.create_action("Add Layer")
	project.undo_redo.add_do_method(project.add_layers.bind(clones, new_indices, all_cels))
	project.undo_redo.add_do_property(project, "selected_cels", new_selection)
	project.undo_redo.add_do_method(project.change_cel.bind(-1, new_indices[-1]))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(project.remove_layers.bind(new_indices))
	project.undo_redo.add_undo_property(project, "selected_cels", old_selection)
	project.undo_redo.add_undo_method(project.change_cel.bind(-1, old_current_layer))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()


func _clone_layer_with_cels(project: Project, src_layer: BaseLayer) -> Dictionary:
	var cl_layer: BaseLayer
	if src_layer is LayerTileMap:
		cl_layer = LayerTileMap.new(project, src_layer.tileset)
		cl_layer.place_only_mode = src_layer.place_only_mode
		cl_layer.tile_size = src_layer.tile_size
		cl_layer.tile_shape = src_layer.tile_shape
		cl_layer.tile_layout = src_layer.tile_layout
		cl_layer.tile_offset_axis = src_layer.tile_offset_axis
	else:
		cl_layer = src_layer.get_script().new(project)
		if src_layer is AudioLayer:
			cl_layer.audio = src_layer.audio
	cl_layer.project = project
	cl_layer.index = src_layer.index
	var src_layer_data: Dictionary = src_layer.serialize()
	for link_set in src_layer_data.get("link_sets", []):
		link_set["cels"].clear()
	cl_layer.deserialize(src_layer_data)
	cl_layer.name = str(cl_layer.name, " (", tr("copy"), ")")

	var cloned_cels := []
	for frame in project.frames:
		var src_cel := frame.cels[src_layer.index]
		var new_cel := src_cel.duplicate_cel()
		if src_cel.link_set == null:
			new_cel.set_content(src_cel.copy_content())
		else:
			var link_index := src_layer.cel_link_sets.find(src_cel.link_set)
			if link_index >= 0 and link_index < cl_layer.cel_link_sets.size():
				new_cel.link_set = cl_layer.cel_link_sets[link_index]
				if new_cel.link_set["cels"].size() > 0:
					var linked_cel: BaseCel = new_cel.link_set["cels"][0]
					new_cel.set_content(linked_cel.get_content(), linked_cel.image_texture)
				else:
					new_cel.set_content(src_cel.copy_content())
				new_cel.link_set["cels"].append(new_cel)
			else:
				new_cel.set_content(src_cel.copy_content())
		cloned_cels.append(new_cel)
	return {"layer": cl_layer, "cels": cloned_cels}


func _clear_group_brackets() -> void:
	if not is_instance_valid(group_bracket_lane):
		return
	for child in group_bracket_lane.get_children():
		child.free()
	group_bracket_lane.visible = false


func _sync_content_geometry() -> void:
	if (
		not is_instance_valid(layer_content)
		or not is_instance_valid(layer_row)
		or not is_instance_valid(group_bracket_lane)
	):
		return
	var row_size := layer_row.get_combined_minimum_size()
	row_size.y = maxf(row_size.y, 126.0)
	layer_row.size = row_size
	layer_content.custom_minimum_size = row_size
	layer_content.size = row_size
	group_bracket_lane.position = Vector2.ZERO
	group_bracket_lane.size = row_size


func _rebuild_group_brackets() -> void:
	var project := _bound_project
	if project == null or not is_instance_valid(group_bracket_lane):
		return
	await get_tree().process_frame
	if project != _bound_project or not is_instance_valid(group_bracket_lane):
		return
	_clear_group_brackets()
	_sync_content_geometry()
	var has_brackets := false
	for layer in project.layers:
		if not layer is GroupLayer:
			continue
		var descendants := layer.get_children(true)
		var left := INF
		var right := -INF
		for descendant in descendants:
			var card := _cards_by_layer.get(descendant.index) as Control
			if not is_instance_valid(card):
				continue
			left = minf(left, card.position.x)
			right = maxf(right, card.position.x + card.size.x)
		if is_inf(left) or is_inf(right) or right <= left:
			continue
		var lane := layer.get_hierarchy_depth()
		has_brackets = true
		var bracket := GROUP_BRACKET_SCENE.instantiate() as SingleFrameLayerGroupBracket
		group_bracket_lane.add_child(bracket)
		bracket.setup(layer)
		bracket.set_span(left, right - left, lane)
	group_bracket_lane.visible = has_brackets
	group_bracket_lane.size = layer_content.size


func _ensure_current_layer_visible() -> void:
	var project := _bound_project
	if project == null or not is_instance_valid(scroll_container):
		return
	var current_card := _cards_by_layer.get(project.current_layer) as Control
	if is_instance_valid(current_card):
		scroll_container.ensure_control_visible(current_card)
		return
	if project.current_layer < 0 or project.current_layer >= project.layers.size():
		return
	var current_layer := project.layers[project.current_layer]
	if current_layer is GroupLayer:
		for child in current_layer.get_children(true):
			var child_card := _cards_by_layer.get(child.index) as Control
			if is_instance_valid(child_card):
				scroll_container.ensure_control_visible(child_card)
				return
