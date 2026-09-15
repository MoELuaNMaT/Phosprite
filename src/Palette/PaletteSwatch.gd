class_name PaletteSwatch
extends ColorRect

signal pressed(mouse_button: int)
signal double_clicked(mouse_button: int, position: Vector2)
signal dropped(source_index: int, new_index: int)

const DEFAULT_COLOR := Color(0.0, 0.0, 0.0, 0.0)
const DRAG_OUTLINE_INSET_PX := 4
const DRAG_OUTLINE_DASH_PX := 3
const DRAG_OUTLINE_GAP_PX := 2

var index := -1
var color_index := -1
var show_left_highlight := false
var show_right_highlight := false
var show_dragging_outline := false:
	set(value):
		if show_dragging_outline == value:
			return
		show_dragging_outline = value
		queue_redraw()
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

	if show_dragging_outline and not empty:
		_draw_dragging_outline()

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


func _draw_dragging_outline() -> void:
	var left := float(DRAG_OUTLINE_INSET_PX)
	var top := float(DRAG_OUTLINE_INSET_PX)
	var right := size.x - float(DRAG_OUTLINE_INSET_PX)
	var bottom := size.y - float(DRAG_OUTLINE_INSET_PX)
	if right <= left or bottom <= top:
		return
	var step := DRAG_OUTLINE_DASH_PX + DRAG_OUTLINE_GAP_PX
	for x in range(DRAG_OUTLINE_INSET_PX, int(right), step):
		var end_x := minf(float(x + DRAG_OUTLINE_DASH_PX), right)
		_draw_drag_dash(Vector2(float(x), top), Vector2(end_x, top))
		_draw_drag_dash(Vector2(float(x), bottom), Vector2(end_x, bottom))
	for y in range(DRAG_OUTLINE_INSET_PX, int(bottom), step):
		var end_y := minf(float(y + DRAG_OUTLINE_DASH_PX), bottom)
		_draw_drag_dash(Vector2(left, float(y)), Vector2(left, end_y))
		_draw_drag_dash(Vector2(right, float(y)), Vector2(right, end_y))


func _draw_drag_dash(from: Vector2, to: Vector2) -> void:
	# A dark underlay plus a white 1 px dash stays legible on both light and dark swatches.
	draw_line(from, to, Color.BLACK, 2.0)
	draw_line(from, to, Color.WHITE, 1.0)


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
	if (
		DisplayServer.is_touchscreen_available()
		and not (show_left_highlight or show_right_highlight)
	):
		return null
	if empty:
		return ["Swatch", null]
	var drag_icon: PaletteSwatch = duplicate()
	drag_icon.show_left_highlight = false
	drag_icon.show_right_highlight = false
	drag_icon.show_dragging_outline = false
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
	if event is InputEventMouseButton:
		if not get_global_rect().has_point(event.global_position):
			return
		if event.double_click and not empty:
			double_clicked.emit(event.button_index, get_global_rect().position)
		if event.is_released():
			if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
				pressed.emit(event.button_index)
		elif event.is_pressed():
			if (
				DisplayServer.is_touchscreen_available()
				and (show_left_highlight or show_right_highlight)
			):
				accept_event()
