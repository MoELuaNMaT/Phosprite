extends BaseDrawTool

var _last_position := Vector2i(Vector2.INF)
var _changed := false


class PencilOp:
	extends Drawer.ColorOp
	var changed := false

	func process(src: Color, dst: Color) -> Color:
		changed = true
		src.a *= strength
		return dst.blend(src)


func _init() -> void:
	_drawer.color_op = PencilOp.new()


func _on_Opacity_value_changed(value: float) -> void:
	_strength = clampf(value / 100.0, 0.0, 1.0)
	update_config()
	save_config()


func get_config() -> Dictionary:
	var config := super.get_config()
	config.erase("brush_density")
	config.erase("overwrite")
	config.erase("fill_inside")
	config.erase("spacing_mode")
	config.erase("spacing")
	config["strength"] = _strength
	return config


func set_config(config: Dictionary) -> void:
	super.set_config(config)
	_brush_density = 100
	_spacing_mode = false
	_spacing = Vector2i.ZERO
	_strength = clampf(float(config.get("strength", _strength)), 0.0, 1.0)


func update_config() -> void:
	super.update_config()
	$DensityValueSlider.visible = false
	$Opacity.value = _strength * 100.0


func update_brush() -> void:
	super.update_brush()
	$DensityValueSlider.visible = false


func draw_start(pos: Vector2i) -> void:
	_spacing_mode = false
	pos = snap_position(pos)
	super.draw_start(pos)

	Global.transform_content_confirmed.emit()
	prepare_undo()
	update_mask(tool_slot.color.a >= 1.0 and is_equal_approx(_strength, 1.0))
	_changed = false
	_drawer.color_op.changed = false
	_drawer.reset()

	_draw_line = Input.is_action_pressed("draw_create_line")
	var project := Global.current_project
	var draw_pos := pos
	if project.get_current_cel() is Cel3D:
		var layer := project.layers[project.current_layer] as Layer3D
		draw_pos = draw_on_3d_object(pos, layer)
		if draw_pos == Vector2i(Vector2.INF):
			return
	if _draw_line:
		if Global.mirror_view:
			pos.x = (Global.current_project.size.x - 1) - pos.x
		_line_start = pos
		_line_end = pos
		update_line_polylines(_line_start, _line_end)
	else:
		draw_tool(draw_pos)
		_last_position = pos
		Global.canvas.sprite_changed_this_frame = true
	cursor_text = ""


func draw_move(pos_i: Vector2i) -> void:
	var pos := _get_stabilized_position(pos_i)
	pos = snap_position(pos)
	super.draw_move(pos)

	if _draw_line:
		if Global.mirror_view:
			pos.x = (Global.current_project.size.x - 1) - pos.x
		var d := _line_angle_constraint(_line_start, pos)
		_line_end = d.position
		cursor_text = d.text
		update_line_polylines(_line_start, _line_end)
	else:
		if _last_position == Vector2i(Vector2.INF):
			return
		draw_fill_gap(_last_position, pos)
		_last_position = pos
		cursor_text = ""
		Global.canvas.sprite_changed_this_frame = true


func draw_end(pos: Vector2i) -> void:
	pos = snap_position(pos)

	if _draw_line:
		if Global.mirror_view:
			_line_start.x = (Global.current_project.size.x - 1) - _line_start.x
			_line_end.x = (Global.current_project.size.x - 1) - _line_end.x
		draw_tool(_line_start)
		draw_fill_gap(_line_start, _line_end)
		_draw_line = false

	commit_undo()
	super.draw_end(pos)
	cursor_text = ""
	update_random_image()
	_spacing_mode = false


func _draw_brush_image(brush_image: Image, src_rect: Rect2i, dst: Vector2i) -> void:
	_changed = true
	var effective_brush := brush_image
	var opacity := clampf(_drawer.color_op.strength, 0.0, 1.0)
	if not is_equal_approx(opacity, 1.0):
		effective_brush = brush_image.duplicate()
		for y in effective_brush.get_height():
			for x in effective_brush.get_width():
				var color := effective_brush.get_pixel(x, y)
				color.a *= opacity
				effective_brush.set_pixel(x, y, color)

	var images := _get_selected_draw_images()
	for draw_image in images:
		if Tools.alpha_locked:
			var mask := draw_image.get_region(Rect2i(dst, effective_brush.get_size()))
			draw_image.blend_rect_mask(effective_brush, mask, src_rect, dst)
		else:
			draw_image.blend_rect(effective_brush, src_rect, dst)
		draw_image.convert_rgb_to_indexed()
	update_materials(images)
