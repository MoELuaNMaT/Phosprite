extends "res://tests/test_base.gd"


func _viewport_pos_for_pixel(canvas: Canvas, pixel: Vector2i) -> Vector2:
	return canvas.get_global_transform_with_canvas() * (Vector2(pixel) + Vector2(0.5, 0.5))


func test_pencil_single_tap_and_two_pixel_drag_draw_starting_pixel() -> void:
	var project := Global.current_project
	var canvas := Global.canvas
	check_true(is_instance_valid(project), "editor must have an active project")
	check_true(is_instance_valid(canvas), "editor must have an active canvas")
	if not is_instance_valid(project) or not is_instance_valid(canvas):
		return

	var prev_tool := Tools.get_assigned_tool_name(MOUSE_BUTTON_LEFT)
	var prev_color := Tools.get_assigned_color(MOUSE_BUTTON_LEFT)
	Tools.assign_tool("Pencil", MOUSE_BUTTON_LEFT)
	Tools.assign_color(Color(1.0, 0.0, 0.0, 1.0), MOUSE_BUTTON_LEFT, false)

	var cel := project.get_current_cel() as PixelCel
	check_true(cel != null, "current cel must be a PixelCel")
	if cel == null:
		return
	var image := cel.get_image()
	var test_pixels: Array[Vector2i] = [
		Vector2i(4, 4),
		Vector2i(6, 4),
		Vector2i(7, 4),
		Vector2i(9, 4),
	]
	for p in test_pixels:
		image.set_pixelv(p, Color(0, 0, 0, 0))

	# 1. Single tap via adapter press + release (Pencil path)
	var tap_pos := _viewport_pos_for_pixel(canvas, Vector2i(4, 4))
	var press := InputEventMouseButton.new()
	press.device = -1
	press.position = tap_pos
	press.global_position = tap_pos
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	canvas.handle_adapter_tool_event(tap_pos, press)

	var after_press_color := image.get_pixel(4, 4)
	check_true(
		after_press_color.a > 0.9,
		"single-tap press must immediately draw pixel (4,4), got %s" % str(after_press_color)
	)

	var release := InputEventMouseButton.new()
	release.device = -1
	release.position = tap_pos
	release.global_position = tap_pos
	release.button_index = MOUSE_BUTTON_LEFT
	release.button_mask = 0
	release.pressed = false
	canvas.handle_adapter_tool_event(tap_pos, release)

	var after_release_color := image.get_pixel(4, 4)
	check_true(
		after_release_color.a > 0.9,
		"single-tap release must preserve pixel (4,4), got %s" % str(after_release_color)
	)

	# 2. Two-pixel drag (6,4) -> (7,4)
	var drag_start_pos := _viewport_pos_for_pixel(canvas, Vector2i(6, 4))
	var drag_end_pos := _viewport_pos_for_pixel(canvas, Vector2i(7, 4))
	var p2 := InputEventMouseButton.new()
	p2.device = -1
	p2.position = drag_start_pos
	p2.global_position = drag_start_pos
	p2.button_index = MOUSE_BUTTON_LEFT
	p2.button_mask = MOUSE_BUTTON_MASK_LEFT
	p2.pressed = true
	canvas.handle_adapter_tool_event(drag_start_pos, p2)

	var m2 := InputEventMouseMotion.new()
	m2.device = -1
	m2.position = drag_end_pos
	m2.global_position = drag_end_pos
	m2.relative = drag_end_pos - drag_start_pos
	m2.button_mask = MOUSE_BUTTON_MASK_LEFT
	m2.pressure = 0.5
	canvas.handle_adapter_tool_event(drag_end_pos, m2)

	var r2 := InputEventMouseButton.new()
	r2.device = -1
	r2.position = drag_end_pos
	r2.global_position = drag_end_pos
	r2.button_index = MOUSE_BUTTON_LEFT
	r2.button_mask = 0
	r2.pressed = false
	canvas.handle_adapter_tool_event(drag_end_pos, r2)

	check_true(
		image.get_pixel(6, 4).a > 0.9,
		"2-pixel drag must draw starting pixel (6,4), got %s" % str(image.get_pixel(6, 4))
	)
	check_true(
		image.get_pixel(7, 4).a > 0.9,
		"2-pixel drag must draw destination pixel (7,4), got %s" % str(image.get_pixel(7, 4))
	)

	Tools.assign_tool(prev_tool, MOUSE_BUTTON_LEFT)
	Tools.assign_color(prev_color, MOUSE_BUTTON_LEFT, false)
