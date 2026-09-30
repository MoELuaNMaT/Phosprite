class_name SingleFrameLayerStrip
extends PanelContainer

const LAYER_CARD_SCENE := preload("res://src/UI/Timeline/SingleFrameLayerCard.tscn")
const GROUP_BRACKET_SCENE := preload("res://src/UI/Timeline/SingleFrameLayerGroupBracket.tscn")
const GESTURE_RESOLVER := preload("res://src/UI/ProjectGallery/ProjectCardGestureResolver.gd")
const DOUBLE_TAP_MSEC := 350
const DOUBLE_TAP_DISTANCE := 32.0

var multiselect_mode := false
var _bound_project: Project
var _displayed_frame := -1
var _gesture_resolver := GESTURE_RESOLVER.new()
var _cards_by_layer: Dictionary = {}
var _last_tap_msec := -1
var _last_tap_layer := -1
var _last_tap_position := Vector2.INF

@onready var layer_content := %LayerContent as VBoxContainer
@onready var group_bracket_lane := %GroupBracketLane as Control
@onready var layer_row := %LayerRow as HBoxContainer
@onready var scroll_container := %LayerScroll as ScrollContainer
@onready var add_layer_button := %AddLayer as Button
@onready var multiselect_bar := %MultiSelectBar as HBoxContainer
@onready var selection_count := %SelectionCount as Label
@onready var exit_multiselect_button := %ExitMultiSelect as Button
@onready var create_folder_button := %CreateFolder as Button
@onready var merge_layers_button := %MergeLayers as Button
@onready var duplicate_layers_button := %DuplicateLayers as Button


func _ready() -> void:
	add_layer_button.pressed.connect(_on_add_layer_pressed)
	exit_multiselect_button.pressed.connect(_on_exit_multiselect_pressed)
	create_folder_button.pressed.connect(_on_create_folder_pressed)
	merge_layers_button.pressed.connect(_on_merge_layers_pressed)
	duplicate_layers_button.pressed.connect(_on_duplicate_layers_pressed)
	Global.cel_switched.connect(_on_cel_switched)
	set_process(true)
	set_project(Global.current_project)


func _process(_delta: float) -> void:
	_consume_gesture_actions(_gesture_resolver.poll(Time.get_ticks_msec()))


func _exit_tree() -> void:
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
		multiselect_bar.hide()
		return
	_displayed_frame = project.current_frame
	for visual_index in project.layers.size():
		var layer_index := project.layers.size() - 1 - visual_index
		if project.layers[layer_index] is GroupLayer:
			continue
		var card := LAYER_CARD_SCENE.instantiate() as SingleFrameLayerCard
		layer_row.add_child(card)
		layer_row.move_child(card, layer_row.get_child_count() - 2)
		card.setup(project, layer_index, project.current_frame, self)
		card.pointer_down.connect(_on_card_pointer_down)
		card.pointer_up.connect(_on_card_pointer_up)
		card.pointer_cancel.connect(_on_card_pointer_cancel)
		_cards_by_layer[layer_index] = card
	_update_multiselect_bar()
	call_deferred("_rebuild_group_brackets")
	call_deferred("_ensure_current_layer_visible")


func sync_selection() -> void:
	var project := _bound_project
	if project == null:
		return
	for child in layer_row.get_children():
		if child is SingleFrameLayerCard:
			(child as SingleFrameLayerCard)._sync_selected()
	_update_multiselect_bar()
	call_deferred("_ensure_current_layer_visible")


func set_multiselect_mode(enabled: bool, initial_layer := -1) -> void:
	if multiselect_mode == enabled and initial_layer < 0:
		return
	multiselect_mode = enabled
	_reset_last_tap()
	_gesture_resolver.reset()
	if not is_instance_valid(multiselect_bar):
		return
	multiselect_bar.visible = enabled
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
	_update_multiselect_bar()


func _bind_project(project: Project) -> void:
	_unbind_project()
	_bound_project = project
	multiselect_mode = false
	_gesture_resolver.reset()
	_reset_last_tap()
	if is_instance_valid(multiselect_bar):
		multiselect_bar.hide()
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
	_reset_last_tap()


func _consume_gesture_actions(actions: Array[Dictionary]) -> void:
	for action: Dictionary in actions:
		var layer_index := int(str(action.get("path", "-1")))
		if not _is_valid_card_layer(layer_index):
			continue
		var position: Vector2 = action.get("position", Vector2.ZERO)
		var kind := int(action.get("kind", -1))
		match kind:
			GESTURE_RESOLVER.ActionKind.SINGLE_TAP:
				_on_resolved_single_tap(layer_index, position)
			GESTURE_RESOLVER.ActionKind.LONG_PRESS:
				_on_resolved_long_press(layer_index)


func _on_resolved_single_tap(layer_index: int, position: Vector2) -> void:
	if multiselect_mode:
		_toggle_layer_in_multiselect(layer_index)
		return
	if _register_double_tap(layer_index, position):
		var card := _cards_by_layer.get(layer_index) as SingleFrameLayerCard
		if is_instance_valid(card):
			card.toggle_layer_visibility()
		_reset_last_tap()
		return
	_select_only_layer(layer_index)


func _on_resolved_long_press(layer_index: int) -> void:
	_reset_last_tap()
	if not multiselect_mode:
		set_multiselect_mode(true, layer_index)
	elif not _is_layer_selected(layer_index):
		_toggle_layer_in_multiselect(layer_index)


func _register_double_tap(layer_index: int, position: Vector2) -> bool:
	var now_msec := Time.get_ticks_msec()
	var matched := (
		_last_tap_msec >= 0
		and now_msec - _last_tap_msec <= DOUBLE_TAP_MSEC
		and _last_tap_layer == layer_index
		and _last_tap_position.distance_to(position) <= DOUBLE_TAP_DISTANCE
	)
	if matched:
		return true
	_last_tap_msec = now_msec
	_last_tap_layer = layer_index
	_last_tap_position = position
	return false


func _reset_last_tap() -> void:
	_last_tap_msec = -1
	_last_tap_layer = -1
	_last_tap_position = Vector2.INF


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
	if project == null or project != Global.current_project or not _is_valid_card_layer(layer_index):
		return
	Global.transform_content_confirmed.emit()
	var frame_layer := [project.current_frame, layer_index]
	if project.selected_cels.has(frame_layer):
		if project.selected_cels.size() <= 1:
			return
		project.selected_cels.erase(frame_layer)
		if project.current_layer == layer_index:
			project.change_cel(-1, int(project.selected_cels[0][1]))
		else:
			project.change_cel(-1, project.current_layer)
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
	var indices := PackedInt32Array()
	var project := _bound_project
	if project == null:
		return indices
	for cel in project.selected_cels:
		if cel.size() < 2:
			continue
		var layer_index := int(cel[1])
		if (
			layer_index >= 0
			and layer_index < project.layers.size()
			and not indices.has(layer_index)
		):
			indices.append(layer_index)
	indices.sort()
	return indices


func _update_multiselect_bar() -> void:
	if not is_instance_valid(multiselect_bar):
		return
	multiselect_bar.visible = multiselect_mode
	if not multiselect_mode:
		return
	var indices := _selected_layer_indices()
	selection_count.text = tr("%d selected") % indices.size()
	create_folder_button.disabled = not _can_create_folder(indices)
	merge_layers_button.disabled = not _can_merge_layers(indices)
	duplicate_layers_button.disabled = indices.is_empty()


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


func _on_exit_multiselect_pressed() -> void:
	set_multiselect_mode(false)


func _on_create_folder_pressed() -> void:
	_create_folder_from_selection()


func _on_merge_layers_pressed() -> void:
	var indices := _selected_layer_indices()
	if not _can_merge_layers(indices) or not is_instance_valid(Global.animation_timeline):
		return
	Global.animation_timeline.flatten_layers(indices, false)
	call_deferred("_update_multiselect_bar")


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
	group_bracket_lane.custom_minimum_size = Vector2(1.0, 28.0)


func _rebuild_group_brackets() -> void:
	var project := _bound_project
	if project == null or not is_instance_valid(group_bracket_lane):
		return
	await get_tree().process_frame
	if project != _bound_project or not is_instance_valid(group_bracket_lane):
		return
	_clear_group_brackets()
	var max_lane := -1
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
		max_lane = maxi(max_lane, lane)
		var bracket := GROUP_BRACKET_SCENE.instantiate() as SingleFrameLayerGroupBracket
		group_bracket_lane.add_child(bracket)
		bracket.setup(layer)
		bracket.set_span(left, right - left, lane)
	if max_lane >= 0:
		group_bracket_lane.visible = true
		group_bracket_lane.custom_minimum_size = Vector2(
			maxf(layer_row.size.x, 1.0),
			(max_lane + 1) * SingleFrameLayerGroupBracket.BRACKET_HEIGHT
		)
	else:
		group_bracket_lane.visible = false
	group_bracket_lane.size.x = maxf(layer_row.size.x, group_bracket_lane.size.x)

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
