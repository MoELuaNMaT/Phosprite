class_name PaletteGrid
extends GridContainer

signal swatch_pressed(mouse_button: int, index: int)
signal swatch_double_clicked(mouse_button: int, index: int, position: Vector2)
signal swatch_dropped(source_index: int, target_index: int)

const DEFAULT_SWATCH_SIZE := Vector2(26, 26)
const IOS_DEFAULT_SWATCH_SIZE := Vector2(32, 32)
const MIN_SWATCH_SIZE := Vector2(8, 8)
const MAX_SWATCH_SIZE := Vector2(64, 64)
const IOS_TOUCH_TAP_SLOP_PX := 12.0
const IOS_TOUCH_DOUBLE_TAP_MSEC := 350
const IOS_TOUCH_REORDER_HOLD_MSEC := 450
const IOS_TOUCH_TARGET_SIZE := 44.0
const IOS_TOUCH_MOUSE_FILTER_META := &"phosprite_palette_touch_mouse_filter"
const IOS_TOUCH_TOOLTIP_META := &"phosprite_palette_touch_tooltip"

var swatches: Array[PaletteSwatch] = []
var current_palette: Palette = null
var grid_window_origin := Vector2i.ZERO
var grid_size := Vector2i.ZERO
var grid_locked := true:
	set(value):
		grid_locked = value
		if grid_locked:
			columns = maxi(1, grid_size.x)
		else:
			_on_resized()
var swatch_size := DEFAULT_SWATCH_SIZE

var _ios_touch_candidates: Dictionary = {}
var _ios_touch_ui_mode := false
var _ios_last_tap_msec := -1
var _ios_last_tap_palette_index := -1
var _ios_last_tap_position := Vector2.INF
var _ios_last_tap_nonempty := false


func _ready() -> void:
	var default_swatch_size := DEFAULT_SWATCH_SIZE
	if OS.get_name() == "iOS":
		default_swatch_size = IOS_DEFAULT_SWATCH_SIZE
	swatch_size = Global.config_cache.get_value("palettes", "swatch_size", default_swatch_size)
	Palettes.palette_selected.connect(select_palette)
	Tools.color_changed.connect(find_and_select_color)
	resized.connect(_on_resized)
	if OS.get_name() == "iOS":
		call_deferred("_install_ios_palette_touch_targets")


func _input(event: InputEvent) -> void:
	if OS.get_name() != "iOS" or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		_handle_ios_palette_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_ios_palette_drag(event as InputEventScreenDrag)
	elif (
		(event is InputEventMouseMotion or event is InputEventMouseButton)
		and event.device != -1
	):
		_restore_pointer_palette_ui()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.ctrl_pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			change_swatch_size(Vector2i.ONE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			change_swatch_size(-Vector2i.ONE)
		else:
			return
		resize_grid()
		get_window().set_input_as_handled()


func select_palette(_new_palette_name: String) -> void:
	var new_palette := Palettes.current_palette
	if current_palette != new_palette:
		current_palette = new_palette
		grid_window_origin = Vector2.ZERO
	resize_grid()
	find_and_select_color({"color": Tools._slots[MOUSE_BUTTON_LEFT].color}, MOUSE_BUTTON_LEFT)
	find_and_select_color({"color": Tools._slots[MOUSE_BUTTON_RIGHT].color}, MOUSE_BUTTON_RIGHT)
	var left_selected := Palettes.left_selected_color
	var right_selected := Palettes.right_selected_color
	select_swatch(MOUSE_BUTTON_LEFT, left_selected, left_selected)
	select_swatch(MOUSE_BUTTON_RIGHT, right_selected, right_selected)


func setup_swatches() -> void:
	if grid_locked:
		columns = maxi(1, grid_size.x)  # Columns cannot be 0
	for child in get_children():
		child.queue_free()
	swatches.clear()
	for i in range(grid_size.x * grid_size.y):
		var swatch := PaletteSwatch.new()
		swatch.index = i
		init_swatch(swatch)
		swatch.pressed.connect(_on_palette_swatch_pressed.bind(i))
		swatch.double_clicked.connect(_on_palette_swatch_double_clicked.bind(i))
		swatch.dropped.connect(_on_palette_swatch_dropped)
		add_child(swatch)
		swatches.push_back(swatch)


func init_swatch(swatch: PaletteSwatch) -> void:
	swatch.color_index = swatch.index
	var color = current_palette.get_color(swatch.index)
	if color != null:
		swatch.set_swatch_color(color)
		swatch.empty = false
	else:
		swatch.set_swatch_color(PaletteSwatch.DEFAULT_COLOR)
		swatch.empty = true
	swatch.set_swatch_size(swatch_size)
	if OS.get_name() == "iOS" and _ios_touch_ui_mode:
		_set_ios_touch_mouse_filter(swatch, true)


## Called when the color changes, either the left or the right, determined by [param mouse_button].
## If current palette has [param color_info], then select the first slot that has it.
## This is helpful when we select color indirectly (e.g through colorpicker)
func find_and_select_color(color_info: Dictionary, mouse_button: int) -> void:
	var target_color: Color = color_info.get("color", Color(0, 0, 0, 0))
	var palette_color_index: int = color_info.get("index", -1)
	if not is_instance_valid(current_palette):
		return
	var selected_index := Palettes.current_palette_get_selected_color_index(mouse_button)
	if palette_color_index != -1:  # If color has a defined index in palette then prioritize index
		if selected_index == palette_color_index:  # Index already selected
			return
		select_swatch(mouse_button, palette_color_index, selected_index)
		match mouse_button:
			MOUSE_BUTTON_LEFT:
				Palettes.left_selected_color = palette_color_index
			MOUSE_BUTTON_RIGHT:
				Palettes.right_selected_color = palette_color_index
		return
	else:  # If it doesn't then select the first match in the palette
		if get_swatch_color(selected_index) == target_color:  # Color already selected
			return
		for color_ind in swatches.size():
			if (
				target_color.is_equal_approx(swatches[color_ind].color)
				or target_color.to_html() == swatches[color_ind].color.to_html()
			):
				var index := convert_grid_index_to_palette_index(color_ind)
				select_swatch(mouse_button, index, selected_index)
				match mouse_button:
					MOUSE_BUTTON_LEFT:
						Palettes.left_selected_color = index
					MOUSE_BUTTON_RIGHT:
						Palettes.right_selected_color = index
				return
	# Unselect swatches when tools color is changed
	var swatch_to_unselect := -1
	if mouse_button == MOUSE_BUTTON_LEFT:
		swatch_to_unselect = Palettes.left_selected_color
		Palettes.left_selected_color = -1
	elif mouse_button == MOUSE_BUTTON_RIGHT:
		swatch_to_unselect = Palettes.right_selected_color
		Palettes.right_selected_color = -1

	unselect_swatch(mouse_button, swatch_to_unselect)


## Displays a left/right highlight over a swatch
func select_swatch(mouse_button: int, palette_index: int, old_palette_index: int) -> void:
	if not is_instance_valid(current_palette):
		return
	var index := convert_palette_index_to_grid_index(palette_index)
	var old_index := convert_palette_index_to_grid_index(old_palette_index)
	if index >= 0 and index < swatches.size():
		# Remove highlight from old index swatch and add to index swatch
		if old_index >= 0 and old_index < swatches.size():
			# Old index could be undefined when no swatch was previously selected
			swatches[old_index].show_selected_highlight(false, mouse_button)
		swatches[index].show_selected_highlight(true, mouse_button)


func unselect_swatch(mouse_button: int, palette_index: int) -> void:
	var index := convert_palette_index_to_grid_index(palette_index)
	if index >= 0 and index < swatches.size():
		swatches[index].show_selected_highlight(false, mouse_button)


func set_swatch_color(palette_index: int, color: Color) -> void:
	var index := convert_palette_index_to_grid_index(palette_index)
	if index >= 0 and index < swatches.size():
		swatches[index].set_swatch_color(color)


func get_swatch_color(palette_index: int) -> Color:
	var index := convert_palette_index_to_grid_index(palette_index)
	if index >= 0 and index < swatches.size():
		return swatches[index].color
	return Color.TRANSPARENT


## Grid index adds grid window origin
func convert_grid_index_to_palette_index(index: int) -> int:
	return (
		(index / grid_size.x + grid_window_origin.y) * current_palette.width
		+ (index % grid_size.x + grid_window_origin.x)
	)


func convert_palette_index_to_grid_index(palette_index: int) -> int:
	var x := palette_index % current_palette.width
	var y := palette_index / current_palette.width
	return (x - grid_window_origin.x) + (y - grid_window_origin.y) * grid_size.x


func resize_grid() -> void:
	if is_instance_valid(current_palette):
		grid_size.x = current_palette.width
		grid_size.y = current_palette.height
	else:
		grid_size = Vector2i.ZERO
	setup_swatches()


func change_swatch_size(size_diff: Vector2) -> void:
	swatch_size += size_diff
	if swatch_size.x < MIN_SWATCH_SIZE.x:
		swatch_size = MIN_SWATCH_SIZE
	elif swatch_size.x > MAX_SWATCH_SIZE.x:
		swatch_size = MAX_SWATCH_SIZE

	for swatch in get_children():
		swatch.set_swatch_size(swatch_size)

	Global.config_cache.set_value("palettes", "swatch_size", swatch_size)
	_on_resized()


func _on_resized() -> void:
	if not grid_locked:
		columns = maxi(1, size.x / (swatch_size.x + 3))


func _on_palette_swatch_pressed(mouse_button: int, index: int) -> void:
	var palette_index := convert_grid_index_to_palette_index(index)
	swatch_pressed.emit(mouse_button, palette_index)


func _on_palette_swatch_double_clicked(mouse_button: int, pos: Vector2, index: int) -> void:
	var palette_index := convert_grid_index_to_palette_index(index)
	swatch_double_clicked.emit(mouse_button, palette_index, pos)


func _on_palette_swatch_dropped(source_index: int, target_index: int) -> void:
	var palette_source_index := convert_grid_index_to_palette_index(source_index)
	var palette_target_index := convert_grid_index_to_palette_index(target_index)
	swatch_dropped.emit(palette_source_index, palette_target_index)


func _handle_ios_palette_touch(event: InputEventScreenTouch) -> bool:
	if event.pressed:
		var action := _ios_palette_action_at(event.position)
		if action.is_empty():
			return false
		_enter_ios_touch_palette_ui()
		var palette_index := -1
		if action == &"swatch":
			palette_index = _ios_palette_index_at(event.position)
		_ios_touch_candidates[event.index] = {
			"action": action,
			"origin": event.position,
			"palette_index": palette_index,
			"pressed_msec": Time.get_ticks_msec(),
			"cancelled": false,
			"reordering": false,
		}
		return true

	if not _ios_touch_candidates.has(event.index):
		return false
	var candidate: Dictionary = _ios_touch_candidates[event.index]
	_ios_touch_candidates.erase(event.index)
	if bool(candidate.get("cancelled", false)):
		return true
	var origin: Vector2 = candidate.get("origin", event.position)
	if origin.distance_to(event.position) > IOS_TOUCH_TAP_SLOP_PX and not bool(
		candidate.get("reordering", false)
	):
		return true
	var action: StringName = candidate.get("action", &"")
	if action == &"swatch":
		var palette_index: int = int(candidate.get("palette_index", -1))
		if palette_index < 0:
			return true
		if bool(candidate.get("reordering", false)):
			var target_index := _ios_palette_index_at(event.position)
			if target_index >= 0 and target_index != palette_index:
				swatch_dropped.emit(palette_index, target_index)
			get_viewport().set_input_as_handled()
			return true
		var nonempty := _ios_palette_index_has_color(palette_index)
		var active_button := _ios_active_palette_button()
		swatch_pressed.emit(active_button, palette_index)
		if _register_ios_palette_tap(palette_index, event.position, nonempty):
			swatch_double_clicked.emit(
				active_button, palette_index, _ios_palette_swatch_global_position(palette_index)
			)
		return true
	if action == &"add" or action == &"delete":
		_activate_ios_palette_toolbar_action(action)
		return true
	return false


func _handle_ios_palette_drag(event: InputEventScreenDrag) -> bool:
	if not _ios_touch_candidates.has(event.index):
		return false
	var candidate: Dictionary = _ios_touch_candidates[event.index]
	if bool(candidate.get("cancelled", false)):
		return true
	var origin: Vector2 = candidate.get("origin", event.position)
	var distance := origin.distance_to(event.position)
	var action: StringName = candidate.get("action", &"")
	if action != &"swatch":
		if distance > IOS_TOUCH_TAP_SLOP_PX:
			candidate["cancelled"] = true
			_ios_touch_candidates[event.index] = candidate
		return true
	if bool(candidate.get("reordering", false)):
		get_viewport().set_input_as_handled()
		return true
	var source_index: int = int(candidate.get("palette_index", -1))
	var pressed_msec: int = int(candidate.get("pressed_msec", Time.get_ticks_msec()))
	var held_msec := Time.get_ticks_msec() - pressed_msec
	if held_msec >= IOS_TOUCH_REORDER_HOLD_MSEC and _ios_palette_index_has_color(source_index):
		candidate["reordering"] = true
		_ios_touch_candidates[event.index] = candidate
		get_viewport().set_input_as_handled()
		return true
	if distance > IOS_TOUCH_TAP_SLOP_PX:
		candidate["cancelled"] = true
		_ios_touch_candidates[event.index] = candidate
	return true


func _ios_palette_action_at(screen_position: Vector2) -> StringName:
	if _ios_palette_index_at(screen_position) >= 0:
		return &"swatch"
	var panel := _ios_palette_panel()
	if not is_instance_valid(panel):
		return &""
	var add_button := panel.get_node_or_null("PaletteVBoxContainer/PaletteButtons/AddColor") as Control
	if is_instance_valid(add_button) and add_button.get_global_rect().has_point(screen_position):
		return &"add"
	var delete_button := (
		panel.get_node_or_null("PaletteVBoxContainer/PaletteButtons/DeleteColor") as Control
	)
	if is_instance_valid(delete_button) and delete_button.get_global_rect().has_point(screen_position):
		return &"delete"
	return &""


func _ios_palette_index_at(screen_position: Vector2) -> int:
	if not is_instance_valid(current_palette):
		return -1
	var scroll_container := get_parent() as Control
	if is_instance_valid(scroll_container) and not scroll_container.get_global_rect().has_point(
		screen_position
	):
		return -1
	for grid_index in swatches.size():
		var swatch := swatches[grid_index]
		if is_instance_valid(swatch) and swatch.get_global_rect().has_point(screen_position):
			return convert_grid_index_to_palette_index(grid_index)
	return -1


func _ios_palette_swatch_global_position(palette_index: int) -> Vector2:
	var grid_index := convert_palette_index_to_grid_index(palette_index)
	if grid_index >= 0 and grid_index < swatches.size():
		var swatch := swatches[grid_index]
		if is_instance_valid(swatch):
			return swatch.get_global_rect().position
	return get_global_rect().position


func _ios_palette_index_has_color(palette_index: int) -> bool:
	return (
		is_instance_valid(current_palette)
		and palette_index >= 0
		and current_palette.get_color(palette_index) != null
	)


func _ios_active_palette_button() -> int:
	if Tools.picking_color_for == MOUSE_BUTTON_RIGHT:
		return MOUSE_BUTTON_RIGHT
	return MOUSE_BUTTON_LEFT


func _register_ios_palette_tap(
	palette_index: int, screen_position: Vector2, nonempty: bool
) -> bool:
	var now := Time.get_ticks_msec()
	var is_double_tap := (
		nonempty
		and _ios_last_tap_nonempty
		and _ios_last_tap_palette_index == palette_index
		and _ios_last_tap_msec >= 0
		and now - _ios_last_tap_msec <= IOS_TOUCH_DOUBLE_TAP_MSEC
		and _ios_last_tap_position.distance_to(screen_position) <= IOS_TOUCH_TAP_SLOP_PX
	)
	if is_double_tap:
		_ios_last_tap_msec = -1
		_ios_last_tap_palette_index = -1
		_ios_last_tap_position = Vector2.INF
		_ios_last_tap_nonempty = false
		return true
	_ios_last_tap_msec = now
	_ios_last_tap_palette_index = palette_index
	_ios_last_tap_position = screen_position
	_ios_last_tap_nonempty = nonempty
	return false


func _activate_ios_palette_toolbar_action(action: StringName) -> void:
	var panel := _ios_palette_panel()
	if not is_instance_valid(panel):
		return
	var event := InputEventMouseButton.new()
	event.button_index = _ios_active_palette_button()
	event.pressed = true
	match action:
		&"add":
			panel._on_AddColor_gui_input(event)
		&"delete":
			panel._on_DeleteColor_gui_input(event)


func _install_ios_palette_touch_targets() -> void:
	var panel := _ios_palette_panel()
	if not is_instance_valid(panel):
		return
	var button_container := panel.get_node_or_null("PaletteVBoxContainer/PaletteButtons")
	if not is_instance_valid(button_container):
		return
	for child in button_container.get_children():
		if child is Control:
			var control := child as Control
			var minimum_size := control.custom_minimum_size
			minimum_size.y = maxf(minimum_size.y, IOS_TOUCH_TARGET_SIZE)
			if not control is OptionButton:
				minimum_size.x = maxf(minimum_size.x, IOS_TOUCH_TARGET_SIZE)
			control.custom_minimum_size = minimum_size


func _enter_ios_touch_palette_ui() -> void:
	_ios_touch_ui_mode = true
	for swatch in swatches:
		if is_instance_valid(swatch):
			_set_ios_touch_mouse_filter(swatch, true)
	for control in _ios_palette_toolbar_controls():
		if not control.has_meta(IOS_TOUCH_TOOLTIP_META):
			control.set_meta(IOS_TOUCH_TOOLTIP_META, control.tooltip_text)
		control.tooltip_text = ""
		control.release_focus()
	var panel := _ios_palette_panel()
	if not is_instance_valid(panel):
		return
	for path in [
		"PaletteVBoxContainer/PaletteButtons/AddColor",
		"PaletteVBoxContainer/PaletteButtons/DeleteColor",
	]:
		var control := panel.get_node_or_null(path) as Control
		if is_instance_valid(control):
			_set_ios_touch_mouse_filter(control, true)


func _restore_pointer_palette_ui() -> void:
	if not _ios_touch_ui_mode:
		return
	_ios_touch_ui_mode = false
	_ios_touch_candidates.clear()
	for swatch in swatches:
		if is_instance_valid(swatch):
			_set_ios_touch_mouse_filter(swatch, false)
	for control in _ios_palette_toolbar_controls():
		if control.has_meta(IOS_TOUCH_TOOLTIP_META):
			control.tooltip_text = String(control.get_meta(IOS_TOUCH_TOOLTIP_META, ""))
			control.remove_meta(IOS_TOUCH_TOOLTIP_META)
	var panel := _ios_palette_panel()
	if not is_instance_valid(panel):
		return
	for path in [
		"PaletteVBoxContainer/PaletteButtons/AddColor",
		"PaletteVBoxContainer/PaletteButtons/DeleteColor",
	]:
		var control := panel.get_node_or_null(path) as Control
		if is_instance_valid(control):
			_set_ios_touch_mouse_filter(control, false)


func _set_ios_touch_mouse_filter(control: Control, ignore: bool) -> void:
	if ignore:
		if not control.has_meta(IOS_TOUCH_MOUSE_FILTER_META):
			control.set_meta(IOS_TOUCH_MOUSE_FILTER_META, control.mouse_filter)
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif control.has_meta(IOS_TOUCH_MOUSE_FILTER_META):
		control.mouse_filter = int(control.get_meta(IOS_TOUCH_MOUSE_FILTER_META))
		control.remove_meta(IOS_TOUCH_MOUSE_FILTER_META)


func _ios_palette_toolbar_controls() -> Array[Control]:
	var controls: Array[Control] = []
	var panel := _ios_palette_panel()
	if not is_instance_valid(panel):
		return controls
	var button_container := panel.get_node_or_null("PaletteVBoxContainer/PaletteButtons")
	if not is_instance_valid(button_container):
		return controls
	for child in button_container.get_children():
		if child is Control:
			controls.append(child as Control)
	return controls


func _ios_palette_panel() -> PalettePanel:
	if owner is PalettePanel:
		return owner as PalettePanel
	var current := get_parent()
	while is_instance_valid(current):
		if current is PalettePanel:
			return current as PalettePanel
		current = current.get_parent()
	return null
