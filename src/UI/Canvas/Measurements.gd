extends Node2D

const WIDTH := 2
const LINE_MEASUREMENT_OFFSET_SCREEN := 18.0
const LINE_MEASUREMENT_TICK_SCREEN := 8.0
const LINE_MEASUREMENT_PADDING_SCREEN := 6.0
const LINE_MEASUREMENT_WIDTH_SCREEN := 2.0

var font: Font
var line_color := Global.guide_color
var mode := Global.MeasurementMode.NONE
var apparent_width: float = WIDTH
var rect_bounds: Rect2i
var text_server := TextServerManager.get_primary_interface()
var line_measurement_visible := false
var line_measurement_start := Vector2.ZERO
var line_measurement_end := Vector2.ZERO

@onready var canvas := get_parent() as Canvas


func _ready() -> void:
	font = Themes.get_font()


func update_measurement(mode_idx := Global.MeasurementMode.NONE) -> void:
	mode = mode_idx
	queue_redraw()


func _draw() -> void:
	match mode:
		Global.MeasurementMode.DISPLAY_RECT:
			_prepare_cel_rect()
			_draw_move_measurement()
		Global.MeasurementMode.MOVE:
			_prepare_movement_rect()
			_draw_move_measurement()
		_:
			rect_bounds = Rect2i()
	if line_measurement_visible:
		_draw_line_measurement()


func _input(event: InputEvent) -> void:
	apparent_width = WIDTH / get_viewport().canvas_transform.get_scale().x
	if event.is_action_released(&"change_layer_automatically"):
		update_measurement(Global.MeasurementMode.NONE)
	elif event.is_action(&"change_layer_automatically"):
		update_measurement(Global.MeasurementMode.DISPLAY_RECT)
	elif event is InputEventMouseMotion and mode == Global.MeasurementMode.DISPLAY_RECT:
		update_measurement(Global.MeasurementMode.DISPLAY_RECT)


func update_line_measurement(start_pos: Vector2, end_pos: Vector2) -> void:
	line_measurement_start = start_pos
	line_measurement_end = end_pos
	line_measurement_visible = true
	queue_redraw()


func clear_line_measurement() -> void:
	if not line_measurement_visible:
		return
	line_measurement_visible = false
	queue_redraw()


func _draw_line_measurement() -> void:
	var line_delta := line_measurement_end - line_measurement_start
	var line_length := line_delta.length()
	if is_zero_approx(line_length):
		return

	var viewport_transform := get_viewport().canvas_transform
	var canvas_zoom := viewport_transform.get_scale()
	var viewport_rotation := viewport_transform.get_rotation()
	var screen_delta := (line_delta * canvas_zoom).rotated(viewport_rotation)
	if is_zero_approx(screen_delta.length()):
		return

	# Keep the dimension line visually above the dragged line in screen space.
	var screen_direction := screen_delta.normalized()
	var screen_normal := screen_direction.orthogonal()
	if screen_normal.y > 0.0:
		screen_normal = -screen_normal
	var canvas_normal_per_screen_pixel := screen_normal.rotated(-viewport_rotation) / canvas_zoom
	var offset := canvas_normal_per_screen_pixel * LINE_MEASUREMENT_OFFSET_SCREEN
	var measure_start := line_measurement_start + offset
	var measure_end := line_measurement_end + offset
	var measure_center := (measure_start + measure_end) * 0.5

	var font_size := Themes.get_font_size()
	var length_px := roundi(line_length)
	var label := text_server.format_number(str(length_px)) + "px"
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)

	# Leave a real gap in the dimension line for the upright label.
	var half_label_extent_screen := (
		(text_size.x * absf(screen_direction.x) + text_size.y * absf(screen_direction.y)) * 0.5
		+ LINE_MEASUREMENT_PADDING_SCREEN
	)
	var screen_pixels_per_canvas_pixel := screen_delta.length() / line_length
	var half_gap := half_label_extent_screen / screen_pixels_per_canvas_pixel
	var line_direction := line_delta / line_length
	var line_width := LINE_MEASUREMENT_WIDTH_SCREEN / maxf(absf(canvas_zoom.x), 0.001)
	if half_gap < line_length * 0.5:
		draw_line(measure_start, measure_center - line_direction * half_gap, line_color, line_width)
		draw_line(measure_center + line_direction * half_gap, measure_end, line_color, line_width)

	var tick_half := canvas_normal_per_screen_pixel * (LINE_MEASUREMENT_TICK_SCREEN * 0.5)
	draw_line(measure_start - tick_half, measure_start + tick_half, line_color, line_width)
	draw_line(measure_end - tick_half, measure_end + tick_half, line_color, line_width)

	# Counter-transform only the label: position follows the line, glyphs stay upright on screen.
	var label_screen_pos := (measure_center * canvas_zoom).rotated(viewport_rotation)
	var label_pos := (
		label_screen_pos
		+ Vector2(-text_size.x * 0.5, font.get_ascent(font_size) - text_size.y * 0.5)
	)
	draw_set_transform(Vector2.ZERO, -viewport_rotation, Vector2.ONE / canvas_zoom)
	draw_string(
		font,
		label_pos + Vector2.ONE,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		Color(0.0, 0.0, 0.0, 0.8)
	)
	draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, line_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _prepare_cel_rect() -> void:
	var project := Global.current_project
	var pos := canvas.current_pixel.floor()
	if Global.mirror_view:
		pos.x = project.size.x - pos.x - 1
	var cel := project.get_current_cel()
	var image := cel.get_image()
	rect_bounds = image.get_used_rect()
	if pos.x > image.get_width() - 1 or pos.y > image.get_height() - 1 or pos.x < 0 or pos.y < 0:
		return

	var curr_frame := project.frames[project.current_frame]
	for layer in project.layers.size():
		var layer_index := (project.layers.size() - 1) - layer
		if project.layers[layer_index].is_visible_in_hierarchy():
			image = curr_frame.cels[layer_index].get_image()
			var color := image.get_pixelv(pos)
			if not is_zero_approx(color.a):
				rect_bounds = image.get_used_rect()
				break


func _prepare_movement_rect() -> void:
	var project := Global.current_project
	if project.has_selection and not Tools.is_placing_tiles():
		rect_bounds = canvas.selection.preview_selection_map.get_used_rect()
		rect_bounds.position = Vector2i(
			canvas.selection.transformation_handles.preview_transform.origin
		)
		if !rect_bounds.has_area():
			rect_bounds = project.selection_map.get_selection_rect(project)
		return
	if rect_bounds.has_area():
		return
	var selected_cels := Global.current_project.selected_cels
	var frames := []
	for selected_cel in selected_cels:
		if not selected_cel[0] in frames:
			frames.append(selected_cel[0])
	for frame in frames:
		# Find used rect of the current frame (across all of the layers)
		var used_rect := Rect2i()
		for cel_idx in project.frames[frame].cels.size():
			if not [frame, cel_idx] in selected_cels:
				continue
			var cel := project.frames[frame].cels[cel_idx]
			if not cel is PixelCel:
				continue
			var cel_rect := cel.get_image().get_used_rect()
			if cel_rect.has_area():
				used_rect = used_rect.merge(cel_rect) if used_rect.has_area() else cel_rect
		if not used_rect.has_area():
			continue
		if !rect_bounds.has_area():
			rect_bounds = used_rect
		else:
			rect_bounds = rect_bounds.merge(used_rect)
	if not rect_bounds.has_area():
		rect_bounds = Rect2i(Vector2i.ZERO, project.size)


func _draw_move_measurement() -> void:
	var p_size := Global.current_project.size
	var dashed_color := line_color
	dashed_color.a = 0.5
	# Draw boundary
	var boundary := Rect2i(rect_bounds)
	boundary.position += canvas.move_preview_location
	if Global.mirror_view:
		boundary.position.x = p_size.x - boundary.size.x - boundary.position.x
	draw_rect(boundary, line_color, false, apparent_width)
	# calculate lines
	var top := Vector2(boundary.get_center().x, boundary.position.y)
	var bottom := Vector2(boundary.get_center().x, boundary.end.y)
	var left := Vector2(boundary.position.x, boundary.get_center().y)
	var right := Vector2(boundary.end.x, boundary.get_center().y)
	# Top, bottom
	var p_vertical := PackedVector2Array([Vector2(top.x, 0), Vector2(bottom.x, p_size.y)])
	# Left, right
	var p_horizontal := PackedVector2Array([Vector2(0, left.y), Vector2(p_size.x, right.y)])
	var lines: Array[PackedVector2Array] = []
	if left.x > -boundary.size.x:  # Left side
		if left.x < p_size.x:
			lines.append(PackedVector2Array([left, p_horizontal[0]]))
		else:
			lines.append(PackedVector2Array([left, p_horizontal[1]]))
	if right.x < p_size.x + boundary.size.x:  # Right side
		if right.x > 0:
			lines.append(PackedVector2Array([right, p_horizontal[1]]))
		else:
			lines.append(PackedVector2Array([right, p_horizontal[0]]))
	if top.y > -boundary.size.y:  # Top side
		if top.y < p_size.y:
			lines.append(PackedVector2Array([top, p_vertical[0]]))
		else:
			lines.append(PackedVector2Array([top, p_vertical[1]]))
	if bottom.y < p_size.y + boundary.size.y:  # Bottom side
		if bottom.y > 0:
			lines.append(PackedVector2Array([bottom, p_vertical[1]]))
		else:
			lines.append(PackedVector2Array([bottom, p_vertical[0]]))
	for line in lines:
		if !Rect2i(Vector2i.ZERO, p_size + Vector2i.ONE).has_point(line[1]):
			var point_a := Vector2.ZERO
			var point_b := Vector2.ZERO
			# Project lines if needed
			if line[1] == p_vertical[0]:  # Upper horizontal projection
				point_a = Vector2(p_size.x / 2.0, 0)
				point_b = Vector2(top.x, 0)
			elif line[1] == p_vertical[1]:  # Lower horizontal projection
				point_a = Vector2(p_size.x / 2.0, p_size.y)
				point_b = Vector2(bottom.x, p_size.y)
			elif line[1] == p_horizontal[0]:  # Left vertical projection
				point_a = Vector2(0, p_size.y / 2.0)
				point_b = Vector2(0, left.y)
			elif line[1] == p_horizontal[1]:  # Right vertical projection
				point_a = Vector2(p_size.x, p_size.y / 2.0)
				point_b = Vector2(p_size.x, right.y)
			var offset := (point_b - point_a).normalized() * (boundary.size / 2.0)
			draw_dashed_line(point_a + offset, point_b + offset, dashed_color, apparent_width)
		draw_line(line[0], line[1], line_color, apparent_width)
		var canvas_zoom := get_viewport().canvas_transform.get_scale()
		var canvas_rotation := -get_viewport().canvas_transform.get_rotation()
		var string_vec := line[0] + (line[1] - line[0]) / 2.0
		var string_pos := (string_vec * canvas_zoom).rotated(-canvas_rotation)
		var string := text_server.format_number(str(line[0].distance_to(line[1]), "px"))
		draw_set_transform(Vector2.ZERO, canvas_rotation, Vector2.ONE / canvas_zoom)
		draw_string(font, string_pos, string)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
