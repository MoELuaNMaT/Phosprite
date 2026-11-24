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

	var prev_tool: String = (
		str(Tools._slots[MOUSE_BUTTON_LEFT].tool_node.name)
		if is_instance_valid(Tools._slots[MOUSE_BUTTON_LEFT].tool_node)
		else "Pencil"
	)
	var prev_color: Color = Tools.get_assigned_color(MOUSE_BUTTON_LEFT)
	var prev_pp := Tools.pixel_perfect
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
		Vector2i(10, 4),
		Vector2i(12, 4),
	]
	for p in test_pixels:
		image.set_pixelv(p, Color(0, 0, 0, 0))

	# 1. Single tap via adapter press + release (Pencil path, pixel_perfect off)
	Tools.pixel_perfect = false
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

	# 2. Two-pixel drag (6,4) -> (7,4) with pixel_perfect ON
	Tools.pixel_perfect = true
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

	# 3. Direct CanvasInputAdapter touch single-tap (DIRECT pending content -> release)
	var adapter := CanvasInputAdapter.new()
	adapter.initialize()
	var touch_pos := _viewport_pos_for_pixel(canvas, Vector2i(12, 4))
	var t_down := InputEventScreenTouch.new()
	t_down.index = 0
	t_down.pressed = true
	t_down.position = touch_pos
	adapter._handle_touch(canvas, t_down)
	var t_up := InputEventScreenTouch.new()
	t_up.index = 0
	t_up.pressed = false
	t_up.position = touch_pos
	adapter._handle_touch(canvas, t_up)
	check_true(
		image.get_pixel(12, 4).a > 0.9,
		"DIRECT touch single tap must draw pixel (12,4), got %s" % str(image.get_pixel(12, 4))
	)

	# 4. Verify stacked PixelPerfect checkbox is centered with hit halo and clickable title
	var pencil_node: Node = Tools._slots[MOUSE_BUTTON_LEFT].tool_node
	if is_instance_valid(pencil_node):
		var pp_cb := pencil_node.get_node_or_null(^"PixelPerfect") as CheckBox
		var pp_label := pencil_node.get_node_or_null(^"PixelPerfectOptionLabel") as Label
		if is_instance_valid(pp_cb):
			check_eq(
				pp_cb.size_flags_horizontal,
				Control.SIZE_SHRINK_CENTER,
				"stacked checkbox must stay horizontally centered"
			)
			var hit_style := pp_cb.get_theme_stylebox(&"normal")
			check_true(
				hit_style.content_margin_left >= 14.0 and hit_style.content_margin_right >= 14.0,
				"stacked checkbox must carry symmetric horizontal hit halo padding"
			)
			check_true(
				hit_style.content_margin_top >= 8.0 and hit_style.content_margin_bottom >= 8.0,
				"stacked checkbox must carry symmetric vertical hit halo padding"
			)
		if is_instance_valid(pp_label) and is_instance_valid(pp_cb):
			check_eq(
				pp_label.horizontal_alignment,
				HORIZONTAL_ALIGNMENT_CENTER,
				"checkbox option label must be centered"
			)
			check_eq(
				pp_label.get_theme_font_size(&"font_size"),
				12,
				"option label must use the unified 12px Pencil font size"
			)
			var before_toggle := pp_cb.button_pressed
			var lbl_tap := InputEventScreenTouch.new()
			lbl_tap.pressed = true
			pp_label.gui_input.emit(lbl_tap)
			check_eq(
				pp_cb.button_pressed,
				not before_toggle,
				"tapping the checkbox title label must toggle the checkbox"
			)
			pp_cb.set_pressed_no_signal(before_toggle)

	# 5. Verify Selection and ColorPicker tools share centered alignment and unified 12px font size
	Tools.assign_tool("RectSelect", MOUSE_BUTTON_LEFT)
	var rect_node: Node = Tools._slots[MOUSE_BUTTON_LEFT].tool_node
	if is_instance_valid(rect_node):
		var actions_label := rect_node.get_node_or_null(^"SelectionActions/ActionsLabel") as Label
		var wrap_cb := rect_node.get_node_or_null(^"SelectionActions/WrapStrokes") as CheckBox
		var wrap_lbl := (
			rect_node.get_node_or_null(^"SelectionActions/WrapStrokesOptionLabel") as Label
		)
		if is_instance_valid(actions_label):
			check_eq(
				actions_label.get_theme_font_size(&"font_size"),
				12,
				"Selection ActionsLabel must match Pencil's 12px font size"
			)
			check_eq(
				actions_label.horizontal_alignment,
				HORIZONTAL_ALIGNMENT_CENTER,
				"Selection ActionsLabel must be centered"
			)
		if is_instance_valid(wrap_cb):
			check_eq(
				wrap_cb.size_flags_horizontal,
				Control.SIZE_SHRINK_CENTER,
				"Selection WrapStrokes checkbox must be centered"
			)
		check_true(
			is_instance_valid(wrap_lbl),
			"Selection WrapStrokes must have a stacked clickable title label"
		)

	Tools.assign_tool("ColorPicker", MOUSE_BUTTON_LEFT)
	var picker_node: Node = Tools._slots[MOUSE_BUTTON_LEFT].tool_node
	if is_instance_valid(picker_node):
		var picker_box := picker_node.get_node_or_null(^"ColorPicker") as VBoxContainer
		if is_instance_valid(picker_box):
			check_eq(
				picker_box.size_flags_horizontal,
				Control.SIZE_EXPAND_FILL,
				"ColorPicker VBoxContainer must expand across the column for centered alignment"
			)

	Tools.pixel_perfect = prev_pp
	Tools.assign_tool(prev_tool, MOUSE_BUTTON_LEFT)
	Tools.assign_color(prev_color, MOUSE_BUTTON_LEFT, false)
