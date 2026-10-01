class_name PaletteSwatch
extends ColorRect

signal pressed(mouse_button: int)
signal double_clicked(mouse_button: int, position: Vector2)
signal dropped(source_index: int, new_index: int)
signal dragged_outside(index: int)

const DEFAULT_COLOR := Color(0.0, 0.0, 0.0, 0.0)
const LONG_PRESS_DRAG_SECONDS := 0.35
const LONG_PRESS_MOVE_TOLERANCE := 8.0

var index := -1
var color_index := -1
var show_left_highlight := false
var show_right_highlight := false
var _show_pending_empty_highlight := false
var _long_press_token := 0
var _pressed_button := -1
var _press_position := Vector2.ZERO
var _long_press_drag_started := false
var _suppress_release_click := false
var _press_moved := false
var empty := true:
	set(value):
		empty = value
		if empty:
			mouse_default_cursor_shape = Control.CURSOR_ARROW
			color = Global.control.theme.get_stylebox("disabled", "Button").bg_color
		else:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _init() -> void:
	color = DEFAULT_COLOR
	custom_minimum_size = Vector2(8, 8)
	size = Vector2(8, 8)
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(_on_gui_input)


func _ready() -> void:
	var transparent_checker := TransparentChecker.new()
	transparent_checker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transparent_checker.show_behind_parent = true
	transparent_checker.visible = not is_equal_approx(color.a, 1.0)
	add_child(transparent_checker)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		if empty:
			empty = true
	elif what == NOTIFICATION_DRAG_END and _long_press_drag_started:
		var palette_grid := get_parent() as Control
		var pointer_position := get_viewport().get_mouse_position()
		if (
			is_instance_valid(palette_grid)
			and not palette_grid.get_global_rect().has_point(pointer_position)
		):
			dragged_outside.emit(index)
		_long_press_drag_started = false


func set_swatch_color(new_color: Color) -> void:
	color = new_color
	if get_child_count() > 0:
		get_child(0).visible = not is_equal_approx(color.a, 1.0)


func set_swatch_size(swatch_size: Vector2) -> void:
	custom_minimum_size = swatch_size
	size = swatch_size


func _draw() -> void:
	if not empty:
		# Black border around swatches with a color
		draw_rect(Rect2(Vector2.ONE, size), Color.BLACK, false, 1)

	if show_left_highlight:
		# Display outer border highlight
		draw_rect(Rect2(Vector2.ONE, size), Color.WHITE, false, 1)
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(2, 2)), Color.BLACK, false, 1)

	if show_right_highlight:
		# Display inner border highlight
		var margin := size / 4
		draw_rect(Rect2(margin, size - margin * 2), Color.BLACK, false, 1)
		draw_rect(
			Rect2(margin - Vector2.ONE, size - margin * 2 + Vector2(2, 2)), Color.WHITE, false, 1
		)
	if _show_pending_empty_highlight:
		_draw_dashed_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color.WHITE)
	if Global.show_pixel_indices:
		var text := str(color_index + 1)
		var font := Themes.get_font()
		var str_pos := Vector2(size.x / 2, size.y - 2)
		var text_color := Global.control.theme.get_color(&"font_color", &"Label")
		draw_string_outline(
			font,
			str_pos,
			text,
			HORIZONTAL_ALIGNMENT_RIGHT,
			-1,
			size.x / 2,
			1,
			text_color.inverted()
		)
		draw_string(font, str_pos, text, HORIZONTAL_ALIGNMENT_RIGHT, -1, size.x / 2, text_color)


func _draw_dashed_rect(rect: Rect2, line_color: Color) -> void:
	_draw_dashed_segment(rect.position, Vector2(rect.end.x, rect.position.y), line_color)
	_draw_dashed_segment(Vector2(rect.end.x, rect.position.y), rect.end, line_color)
	_draw_dashed_segment(rect.end, Vector2(rect.position.x, rect.end.y), line_color)
	_draw_dashed_segment(Vector2(rect.position.x, rect.end.y), rect.position, line_color)


func _draw_dashed_segment(from: Vector2, to: Vector2, line_color: Color) -> void:
	var segment_length := from.distance_to(to)
	if segment_length <= 0.0:
		return
	var direction := (to - from) / segment_length
	var cursor := 0.0
	while cursor < segment_length:
		var dash_end := minf(cursor + 3.0, segment_length)
		draw_line(from + direction * cursor, from + direction * dash_end, line_color, 1.0)
		cursor += 5.0


func show_pending_empty_highlight(new_value: bool) -> void:
	_show_pending_empty_highlight = new_value
	queue_redraw()


## Enables drawing of highlights which indicate selected swatches
func show_selected_highlight(new_value: bool, mouse_button: int) -> void:
	if not empty:
		match mouse_button:
			MOUSE_BUTTON_LEFT:
				show_left_highlight = new_value
			MOUSE_BUTTON_RIGHT:
				show_right_highlight = new_value
		queue_redraw()


func _get_drag_data(_position: Vector2) -> Variant:
	if DisplayServer.is_touchscreen_available() and not show_left_highlight:
		return null
	if empty:
		return ["Swatch", null]
	var drag_icon: PaletteSwatch = duplicate()
	drag_icon.show_left_highlight = false
	drag_icon.show_right_highlight = false
	drag_icon.empty = false
	set_drag_preview(drag_icon)
	return ["Swatch", {source_index = index}]


func _can_drop_data(_position: Vector2, data) -> bool:
	if typeof(data) != TYPE_ARRAY:
		return false
	if data[0] != "Swatch":
		return false
	return true


func _drop_data(_position: Vector2, data) -> void:
	dropped.emit(data[1].source_index, index)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _pressed_button != -1 and not _long_press_drag_started:
		if event.position.distance_to(_press_position) > LONG_PRESS_MOVE_TOLERANCE:
			_press_moved = true
			_cancel_long_press()
		return
	if event is InputEventMouseButton:
		if not get_global_rect().has_point(event.global_position):
			return
		if event.double_click and not empty:
			double_clicked.emit(event.button_index, get_global_rect().position)
		if event.is_pressed():
			if (
				not empty
				and (
					event.button_index == MOUSE_BUTTON_LEFT
					or event.button_index == MOUSE_BUTTON_RIGHT
				)
			):
				_arm_long_press(event.button_index, event.position)
			if DisplayServer.is_touchscreen_available() and show_left_highlight:
				accept_event()
		elif event.is_released():
			var suppress_click := _suppress_release_click or _press_moved
			_cancel_long_press()
			_suppress_release_click = false
			_press_moved = false
			if suppress_click:
				accept_event()
				return
			if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
				pressed.emit(event.button_index)


func _arm_long_press(mouse_button: int, position: Vector2) -> void:
	_long_press_token += 1
	var token := _long_press_token
	_pressed_button = mouse_button
	_press_position = position
	_press_moved = false
	get_tree().create_timer(LONG_PRESS_DRAG_SECONDS).timeout.connect(
		_on_long_press_timeout.bind(token), CONNECT_ONE_SHOT
	)


func _on_long_press_timeout(token: int) -> void:
	if token != _long_press_token or _pressed_button == -1 or empty:
		return
	_long_press_drag_started = true
	_suppress_release_click = true
	var drag_icon: PaletteSwatch = duplicate()
	drag_icon.show_left_highlight = false
	drag_icon.show_right_highlight = false
	drag_icon._show_pending_empty_highlight = false
	drag_icon.empty = false
	force_drag(["Swatch", {source_index = index, long_press = true}], drag_icon)


func _cancel_long_press() -> void:
	_long_press_token += 1
	_pressed_button = -1
