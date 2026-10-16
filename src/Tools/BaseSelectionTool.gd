class_name BaseSelectionTool
extends BaseTool

enum Mode { DEFAULT, ADD, SUBTRACT, INTERSECT }

var undo_data: Dictionary
var _move := false
var _start_pos := Vector2i.ZERO
var _offset := Vector2i.ZERO
## For tools such as the Polygon selection tool where you have to
## click multiple times to create a selection
var _ongoing_selection := false

var _mode_selected := 0
var _add := false  ## Shift + Mouse Click
var _subtract := false  ## Ctrl + Mouse Click
var _intersect := false  ## Shift + Ctrl + Mouse Click

## Used to check if the state of content transformation has been changed
## while draw_move() is being called. For example, pressing Enter while still moving content
var _transformation_status_changed := false
var _skip_slider_logic := false
var _selection_action_buttons: Dictionary = {}
var _selection_wrap_checkbox: CheckBox
var _selection_modify_group: VBoxContainer
var _observed_selection_project: Project

@onready var selection_node := Global.canvas.selection
@onready var transformation_handles := selection_node.transformation_handles
@onready var algorithm_option_button := $Algorithm as OptionButton
@onready var position_sliders := $Position as ValueSliderV2
@onready var size_sliders := $Size as ValueSliderV2
@onready var rotation_slider := $Rotation as ValueSlider
@onready var shear_slider := $Shear as ValueSlider


func _ready() -> void:
	super()
	algorithm_option_button.add_item(tr("Nearest neighbor"))
	algorithm_option_button.add_item("cleanEdge", DrawingAlgos.RotationAlgorithm.CLEANEDGE)
	algorithm_option_button.add_item("OmniScale", DrawingAlgos.RotationAlgorithm.OMNISCALE)
	algorithm_option_button.select(0)
	set_confirm_buttons_visibility()
	set_spinbox_values()
	refresh_options()
	_sync_mode_buttons()
	selection_node.transformation_confirmed.connect(func(): _transformation_status_changed = true)
	selection_node.transformation_canceled.connect(func(): _transformation_status_changed = true)
	transformation_handles.preview_transform_changed.connect(set_confirm_buttons_visibility)
	_create_selection_actions()
	if not Global.project_switched.is_connected(_on_selection_actions_project_switched):
		Global.project_switched.connect(_on_selection_actions_project_switched)
	_on_selection_actions_project_switched()
	_apply_ios_compact_options()


func _apply_ios_compact_options() -> void:
	if OS.get_name() != "iOS":
		return
	var visible_controls: Array[StringName] = [
		&"ColorRect", &"ModeLabel", &"ModeButtons", &"SelectionActions"
	]
	if name == &"MagicWand":
		visible_controls.append(&"ToleranceSlider")
	for child in get_children():
		if child is Control:
			(child as Control).visible = StringName(child.name) in visible_controls


## These are the same project-wide commands as Select > ..., now shown in
## every selection tool's narrow, scrollable Tool Options column.
func _create_selection_actions() -> void:
	var actions := VBoxContainer.new()
	actions.name = &"SelectionActions"
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override(&"separation", 4)
	add_child(actions)

	var heading := Label.new()
	heading.name = &"ActionsLabel"
	heading.text = tr("Selection actions")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	actions.add_child(heading)

	_add_selection_action(actions, "Select all", Global.SelectMenu.SELECT_ALL)
	_add_selection_action(actions, "Clear selection", Global.SelectMenu.CLEAR)
	_add_selection_action(actions, "Reselect", Global.SelectMenu.RESELECT)
	_add_selection_action(actions, "Invert selection", Global.SelectMenu.INVERT)
	_add_selection_action(actions, "Select cel area", Global.SelectMenu.SELECT_CEL_AREA)

	_selection_wrap_checkbox = CheckBox.new()
	_selection_wrap_checkbox.name = &"WrapStrokes"
	_selection_wrap_checkbox.text = tr("Wrap Strokes")
	_selection_wrap_checkbox.tooltip_text = tr("Wrap Strokes")
	_selection_wrap_checkbox.button_pressed = SelectionNode.flag_tilemode
	_selection_wrap_checkbox.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection_wrap_checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selection_wrap_checkbox.toggled.connect(_on_selection_wrap_toggled)
	actions.add_child(_selection_wrap_checkbox)

	var modify_toggle := _make_selection_action_button("Modify selection")
	modify_toggle.name = &"ModifySelection"
	modify_toggle.toggle_mode = true
	modify_toggle.toggled.connect(_on_selection_modify_toggled)
	actions.add_child(modify_toggle)

	_selection_modify_group = VBoxContainer.new()
	_selection_modify_group.name = &"ModifyActions"
	_selection_modify_group.visible = false
	_selection_modify_group.add_theme_constant_override(&"separation", 4)
	actions.add_child(_selection_modify_group)
	for index in 4:
		var labels := ["Expand selection", "Shrink selection", "Selection border", "Center selection"]
		var button := _make_selection_action_button(labels[index])
		button.pressed.connect(_on_selection_modify_pressed.bind(index))
		_selection_modify_group.add_child(button)


func _make_selection_action_button(label: String) -> Button:
	var button := Button.new()
	button.text = tr(label)
	button.tooltip_text = tr(label)
	button.custom_minimum_size = Vector2(SIDEBAR_CONTROL_WIDTH, 28.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	return button


func _add_selection_action(container: VBoxContainer, label: String, id: int) -> void:
	var button := _make_selection_action_button(label)
	button.pressed.connect(_on_selection_action_pressed.bind(id))
	container.add_child(button)
	_selection_action_buttons[id] = button


func _on_selection_action_pressed(id: int) -> void:
	if not is_instance_valid(Global.top_menu_container):
		return
	Global.top_menu_container.select_menu_id_pressed(id)
	_refresh_selection_action_states.call_deferred()


func _on_selection_wrap_toggled(_pressed: bool) -> void:
	_on_selection_action_pressed(Global.SelectMenu.WRAP_STROKES)
	if is_instance_valid(_selection_wrap_checkbox):
		_selection_wrap_checkbox.set_pressed_no_signal(SelectionNode.flag_tilemode)


func _on_selection_modify_toggled(expanded: bool) -> void:
	if is_instance_valid(_selection_modify_group):
		_selection_modify_group.visible = expanded


func _on_selection_modify_pressed(id: int) -> void:
	if is_instance_valid(Global.top_menu_container):
		Global.top_menu_container.call(&"_selection_modify_submenu_id_pressed", id)


func _on_selection_actions_project_switched() -> void:
	if is_instance_valid(_observed_selection_project):
		var callback := Callable(self, "_refresh_selection_action_states")
		if _observed_selection_project.selection_changed.is_connected(callback):
			_observed_selection_project.selection_changed.disconnect(callback)
	_observed_selection_project = Global.current_project
	if is_instance_valid(_observed_selection_project):
		var callback := Callable(self, "_refresh_selection_action_states")
		if not _observed_selection_project.selection_changed.is_connected(callback):
			_observed_selection_project.selection_changed.connect(callback)
	_refresh_selection_action_states()


func _refresh_selection_action_states() -> void:
	if not is_instance_valid(_selection_wrap_checkbox):
		return
	_selection_wrap_checkbox.set_pressed_no_signal(SelectionNode.flag_tilemode)
	var project := Global.current_project
	if not is_instance_valid(project):
		return
	var clear_button := _selection_action_buttons.get(Global.SelectMenu.CLEAR) as Button
	if is_instance_valid(clear_button):
		clear_button.disabled = not project.has_selection
	var reselect_button := _selection_action_buttons.get(Global.SelectMenu.RESELECT) as Button
	if is_instance_valid(reselect_button):
		reselect_button.disabled = (
			project.has_selection or project.prev_selection_map.is_invisible()
		)


func set_confirm_buttons_visibility() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	set_spinbox_values()
	if OS.get_name() == "iOS":
		_apply_ios_compact_options()
		return
	get_tree().set_group(
		&"ShowOnActiveTransformation", "visible", transformation_handles.is_transforming()
	)


## Ensure all items are added when we are selecting an option.
func refresh_options() -> void:
	$Modes.clear()
	$Modes.add_item(tr("Replace selection"))
	$Modes.add_item(tr("Add to selection"))
	$Modes.add_item(tr("Subtract from selection"))
	$Modes.add_item(tr("Intersection of selections"))
	$Modes.select(_mode_selected)
	_sync_mode_buttons()


func _sync_mode_buttons() -> void:
	for index in $ModeButtons.get_child_count():
		var button := $ModeButtons.get_child(index) as BaseButton
		if button != null:
			button.set_pressed_no_signal(index == _mode_selected)


func get_config() -> Dictionary:
	var config := super.get_config()
	config["mode_selected"] = _mode_selected
	return config


func set_config(config: Dictionary) -> void:
	_mode_selected = clampi(int(config.get("mode_selected", 0)), Mode.DEFAULT, Mode.INTERSECT)


func update_config() -> void:
	refresh_options()


func set_spinbox_values() -> void:
	_skip_slider_logic = true
	var project := Global.current_project
	var select_rect := project.selection_map.get_selection_rect(project)
	var has_selection := select_rect.has_area()
	if not has_selection:
		size_sliders.press_ratio_button(false)
	position_sliders.editable = has_selection
	size_sliders.editable = has_selection
	if transformation_handles.is_transforming():
		select_rect = selection_node.preview_selection_map.get_selection_rect(project)
		rotation_slider.value = rad_to_deg(transformation_handles.preview_transform.get_rotation())
		shear_slider.value = rad_to_deg(transformation_handles.preview_transform.get_skew())
	position_sliders.value = select_rect.position
	size_sliders.value = select_rect.size
	_skip_slider_logic = false


func draw_start(mouse_pos: Vector2i) -> void:
	var pos: Vector2i = snap_position(mouse_pos)
	super(pos)
	_transformation_status_changed = false
	if transformation_handles.arrow_key_move:
		return
	var project := Global.current_project
	_intersect = Input.is_action_pressed("selection_intersect", true)
	_add = Input.is_action_pressed("selection_add", true)
	_subtract = Input.is_action_pressed("selection_subtract", true)
	_start_pos = pos
	_offset = pos

	var quick_copy := Input.is_action_pressed("transform_copy_selection_content", true)
	# we check if the un-snapped point was hovering a selection
	if (
		selection_node.preview_selection_map.is_pixel_selected(mouse_pos)
		and (!_add and !_subtract and !_intersect or quick_copy)
		and !_ongoing_selection
	):
		if not project.layers[project.current_layer].can_layer_get_drawn():
			return
		# Move current selection
		_move = true
		if quick_copy:  # Move selection without cutting it from the original position (quick copy)
			if transformation_handles.is_transforming():
				Global.transform_content_confirmed.emit()
			transformation_handles.begin_transform(null, project, true)
			var select_rect := project.selection_map.get_selection_rect(project)
			for cel in _get_selected_draw_unlocked_cels():
				var image := cel.get_image()
				image.blit_rect_mask(
					cel.transformed_content,
					cel.transformed_content,
					Rect2i(Vector2i.ZERO, project.selection_map.get_size()),
					select_rect.position
				)
			Global.canvas.queue_redraw()

		else:
			transformation_handles.begin_transform()

	else:  # No moving
		Global.transform_content_confirmed.emit()
	undo_data = selection_node.get_undo_data(false)


func draw_move(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super(pos)
	if transformation_handles.arrow_key_move:
		return
	if _transformation_status_changed:
		return
	if not _move:
		return
	var project := Global.current_project
	var select_rect := project.selection_map.get_selection_rect(project)
	if Tools.is_placing_tiles():
		var cel := project.get_current_cel() as CelTileMap
		var grid_size := cel.get_tile_size()
		var offset := cel.offset % grid_size
		_offset = Tools.snap_to_rectangular_grid_boundary(_offset, grid_size, offset)
		pos = Tools.snap_to_rectangular_grid_boundary(pos, grid_size, offset)
	if Input.is_action_pressed("transform_snap_axis"):  # Snap to axis
		var angle := Vector2(pos).angle_to_point(_start_pos)
		if absf(angle) <= PI / 4 or absf(angle) >= 3 * PI / 4:
			pos.y = _start_pos.y
		else:
			pos.x = _start_pos.x
	if Input.is_action_pressed("transform_snap_grid"):
		_offset = _offset.snapped(Global.grids[0].grid_size)
		var prev_pos: Vector2i = select_rect.position
		selection_node.marching_ants_outline.offset += Vector2(select_rect.position - prev_pos)
		pos = pos.snapped(Global.grids[0].grid_size)
		var grid_offset := Global.grids[0].grid_offset
		grid_offset = Vector2i(
			fmod(grid_offset.x, Global.grids[0].grid_size.x),
			fmod(grid_offset.y, Global.grids[0].grid_size.y)
		)
		pos += grid_offset

	transformation_handles.move_transform(pos - _offset)
	_offset = pos
	_set_cursor_text(select_rect)


func draw_end(pos: Vector2i) -> void:
	pos = snap_position(pos)
	super(pos)
	if transformation_handles.arrow_key_move:
		return
	if not _move:
		apply_selection(pos)

	_move = false
	cursor_text = ""


func cancel_tool() -> void:
	super()
	# Adapter ownership can end without a synthesized mouse release (for example when a
	# second finger takes over navigation or the app loses focus). A Selection handle is
	# transient input state, so cancellation must release it without committing/reverting
	# the existing transform preview.
	if is_instance_valid(transformation_handles):
		transformation_handles.active_handle = null


func apply_selection(_position: Vector2i) -> void:
	# if a shortcut is activated then that will be obeyed instead
	match _mode_selected:
		Mode.ADD:
			if !_subtract && !_intersect:
				_add = true
		Mode.SUBTRACT:
			if !_add && !_intersect:
				_subtract = true
		Mode.INTERSECT:
			if !_add && !_subtract:
				_intersect = true


func select_tilemap_cell(
	cel: CelTileMap, cell_position: Vector2i, selection: SelectionMap, select: bool
) -> void:
	var rect := Rect2i(cell_position + cel.offset, cel.get_tile_size())
	selection.select_rect(rect, select)


func _get_selected_draw_unlocked_cels() -> Array[BaseCel]:
	var cels: Array[BaseCel]
	var project := Global.current_project
	for cel_index in project.selected_cels:
		var cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
		if not cel is PixelCel:
			continue
		if not project.layers[cel_index[1]].can_layer_get_drawn():
			continue
		cels.append(cel)
	return cels


func _on_confirm_button_pressed() -> void:
	Global.transform_content_confirmed.emit()


func _on_cancel_button_pressed() -> void:
	Global.transform_content_canceled.emit()


func _on_modes_item_selected(index: int) -> void:
	_mode_selected = clampi(index, Mode.DEFAULT, Mode.INTERSECT)
	_sync_mode_buttons()
	save_config()


func _on_mode_button_pressed(index: int) -> void:
	_mode_selected = clampi(index, Mode.DEFAULT, Mode.INTERSECT)
	$Modes.select(_mode_selected)
	_sync_mode_buttons()
	save_config()


func _on_algorithm_item_selected(index: int) -> void:
	var id := algorithm_option_button.get_item_id(index)
	transformation_handles.transformation_algorithm = id


func _set_cursor_text(rect: Rect2i) -> void:
	cursor_text = "%s, %s" % [rect.position.x, rect.position.y]
	cursor_text += " -> %s, %s" % [rect.end.x - 1, rect.end.y - 1]
	cursor_text += " (%s, %s)" % [rect.size.x, rect.size.y]


func _on_position_value_changed(value: Vector2) -> void:
	if _skip_slider_logic:
		return
	if !Global.current_project.has_selection:
		return
	if not transformation_handles.is_transforming():
		transformation_handles.begin_transform()
	transformation_handles.move_transform(value - transformation_handles.preview_transform.origin)


func _on_size_value_changed(value: Vector2i) -> void:
	if _skip_slider_logic:
		return
	if !Global.current_project.has_selection:
		return
	if not transformation_handles.is_transforming():
		transformation_handles.begin_transform()
	var image_size := selection_node.preview_selection_map.get_used_rect().size
	var delta := value - image_size
	transformation_handles.resize_transform(delta)


func _on_rotation_value_changed(value: float) -> void:
	if _skip_slider_logic:
		return
	if !Global.current_project.has_selection:
		return
	if not transformation_handles.is_transforming():
		transformation_handles.begin_transform()
	var angle := deg_to_rad(value)
	transformation_handles.rotate_transform(angle)


func _on_shear_value_changed(value: float) -> void:
	if _skip_slider_logic:
		return
	if !Global.current_project.has_selection:
		return
	if not transformation_handles.is_transforming():
		transformation_handles.begin_transform()
	var angle := deg_to_rad(value)
	transformation_handles.shear_transform(angle)
