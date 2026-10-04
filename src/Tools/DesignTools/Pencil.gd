extends BaseDrawTool

var _prev_mode := false
var _last_position := Vector2i(Vector2.INF)
var _changed := false
var _overwrite := false
var _fill_inside := false
var _fill_inside_rect := Rect2i()  ## The bounding box that surrounds the area that gets filled.
var _draw_points := PackedVector2Array()
var _old_spacing_mode := false  ## Needed to reset spacing mode in case we change it

const DITHER_SIZES := [2, 4, 8, 16]

var _dither_enabled := false
var _dither_size := 4
var _dither_coverage := 50


class PencilOp:
	extends Drawer.ColorOp
	var changed := false
	var overwrite := false

	func process(src: Color, dst: Color) -> Color:
		changed = true
		src.a *= strength
		if overwrite:
			return src
		return dst.blend(src)


func _init() -> void:
	_drawer.color_op = PencilOp.new()


func _ready() -> void:
	super._ready()
	var pattern: OptionButton = $DitherSettings/PatternRow/Pattern
	if pattern.item_count == 0:
		for size in DITHER_SIZES:
			pattern.add_item("%d × %d" % [size, size])
	update_config()


func _on_Overwrite_toggled(button_pressed: bool) -> void:
	_overwrite = button_pressed
	update_config()
	save_config()


func _on_FillInside_toggled(button_pressed: bool) -> void:
	_fill_inside = button_pressed
	update_config()
	save_config()


func _on_SpacingMode_toggled(button_pressed: bool) -> void:
	# This acts as an interface to access the intrinsic spacing_mode feature
	# BaseTool holds the spacing system, but for a tool to access them it's recommended to do it in
	# their own script
	_spacing_mode = button_pressed
	update_config()
	save_config()


func _on_Spacing_value_changed(value: Vector2) -> void:
	_spacing = value
	save_config()


func _on_Dither_toggled(button_pressed: bool) -> void:
	_dither_enabled = button_pressed
	update_config()
	save_config()


func _on_DitherPattern_item_selected(index: int) -> void:
	if index < 0 or index >= DITHER_SIZES.size():
		return
	_dither_size = DITHER_SIZES[index]
	save_config()


func _on_DitherCoverage_value_changed(value: float) -> void:
	_dither_coverage = clampi(roundi(value), 1, 100)
	save_config()


func _input(event: InputEvent) -> void:
	super(event)
	var overwrite_button: CheckBox = $Overwrite

	if event.is_action_pressed("change_tool_mode"):
		_prev_mode = overwrite_button.button_pressed
	if event.is_action("change_tool_mode"):
		overwrite_button.set_pressed_no_signal(!_prev_mode)
		_overwrite = overwrite_button.button_pressed
	if event.is_action_released("change_tool_mode"):
		overwrite_button.set_pressed_no_signal(_prev_mode)
		_overwrite = overwrite_button.button_pressed


func get_config() -> Dictionary:
	var config := super.get_config()
	config["overwrite"] = _overwrite
	config["fill_inside"] = _fill_inside
	config["spacing_mode"] = _spacing_mode
	config["spacing"] = _spacing
	config["dither_enabled"] = _dither_enabled
	config["dither_size"] = _dither_size
	config["dither_coverage"] = _dither_coverage
	return config


func set_config(config: Dictionary) -> void:
	super.set_config(config)
	_overwrite = config.get("overwrite", _overwrite)
	_fill_inside = config.get("fill_inside", _fill_inside)
	_spacing_mode = config.get("spacing_mode", _spacing_mode)
	_spacing = config.get("spacing", _spacing)
	_dither_enabled = config.get("dither_enabled", _dither_enabled)
	var configured_dither_size: int = config.get("dither_size", _dither_size)
	_dither_size = configured_dither_size if configured_dither_size in DITHER_SIZES else 4
	_dither_coverage = clampi(int(config.get("dither_coverage", _dither_coverage)), 1, 100)


func update_config() -> void:
	super.update_config()
	$Overwrite.button_pressed = _overwrite
	$FillInside.button_pressed = _fill_inside
	$SpacingMode.button_pressed = _spacing_mode
	$Spacing.visible = _spacing_mode
	$Spacing.value = _spacing
	$Dither.button_pressed = _dither_enabled
	$DitherSettings.visible = _dither_enabled
	var dither_index := DITHER_SIZES.find(_dither_size)
	if dither_index >= 0 and $DitherSettings/PatternRow/Pattern.item_count > dither_index:
		$DitherSettings/PatternRow/Pattern.select(dither_index)
	$DitherSettings/DitherCoverage.value = _dither_coverage


func draw_start(pos: Vector2i) -> void:
	_old_spacing_mode = _spacing_mode
	pos = snap_position(pos)
	super.draw_start(pos)

	Global.transform_content_confirmed.emit()
	prepare_undo()
	var can_skip_mask := true
	if tool_slot.color.a < 1 and !_overwrite:
		can_skip_mask = false
	update_mask(can_skip_mask)
	_changed = false
	_drawer.color_op.changed = false
	_drawer.color_op.overwrite = _overwrite
	_draw_points = []

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
		_spacing_mode = false  # spacing mode is disabled during line mode
		if Global.mirror_view:
			# mirroring position is ONLY required by "Preview"
			pos.x = (Global.current_project.size.x - 1) - pos.x
		_line_start = pos
		_line_end = pos
		update_line_polylines(_line_start, _line_end)
	else:
		if _fill_inside:
			_draw_points.append(pos)
			_fill_inside_rect = Rect2i(pos, Vector2i.ZERO)
		draw_tool(draw_pos)
		_last_position = pos
		Global.canvas.sprite_changed_this_frame = true
	cursor_text = ""


func draw_move(pos_i: Vector2i) -> void:
	var pos := _get_stabilized_position(pos_i)
	pos = snap_position(pos)
	super.draw_move(pos)

	if _draw_line:
		_spacing_mode = false  # spacing mode is disabled during line mode
		if Global.mirror_view:
			# mirroring position is ONLY required by "Preview"
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
		if _fill_inside:
			_draw_points.append(pos)
			_fill_inside_rect = _fill_inside_rect.expand(pos)


func draw_end(pos: Vector2i) -> void:
	pos = snap_position(pos)

	if _draw_line:
		_spacing_mode = false  # spacing mode is disabled during line mode
		if Global.mirror_view:
			# now we revert back the coordinates from their mirror form so that line can be drawn
			_line_start.x = (Global.current_project.size.x - 1) - _line_start.x
			_line_end.x = (Global.current_project.size.x - 1) - _line_end.x
		draw_tool(_line_start)
		draw_fill_gap(_line_start, _line_end)
		_draw_line = false
	else:
		if _fill_inside:
			_draw_points.append(pos)
			if _draw_points.size() > 3:
				var v := Vector2i()
				for x in _fill_inside_rect.size.x:
					v.x = x + _fill_inside_rect.position.x
					for y in _fill_inside_rect.size.y:
						v.y = y + _fill_inside_rect.position.y
						if Geometry2D.is_point_in_polygon(v, _draw_points):
							if _spacing_mode:
								# use of get_spacing_position() in Pencil.gd is a rare case
								# (you would ONLY need _spacing_mode and _spacing in most cases)
								v = get_spacing_position(v)
							draw_tool(v)

	_fill_inside_rect = Rect2i()
	commit_undo()
	super.draw_end(pos)
	cursor_text = ""
	update_random_image()
	_spacing_mode = _old_spacing_mode


func _set_pixel_no_cache(pos: Vector2i, ignore_mirroring := false) -> void:
	if _dither_enabled and not Tools.is_placing_tiles() and not _dither_allows_pixel(pos):
		return
	super._set_pixel_no_cache(pos, ignore_mirroring)


func _dither_allows_pixel(pos: Vector2i) -> bool:
	if not _dither_enabled or _dither_coverage >= 100:
		return true
	var size := _dither_size
	var x := ((pos.x % size) + size) % size
	var y := ((pos.y % size) + size) % size
	var threshold := 0
	var multiplier := 1
	var current_size := size
	while current_size > 1:
		var half := current_size >> 1
		var quadrant_x := 1 if x >= half else 0
		var quadrant_y := 1 if y >= half else 0
		var quadrant := 0
		if quadrant_y == 0:
			quadrant = 2 if quadrant_x == 1 else 0
		else:
			quadrant = 1 if quadrant_x == 1 else 3
		threshold += quadrant * multiplier
		multiplier *= 4
		x %= half
		y %= half
		current_size = half
	var cell_count := size * size
	var visible_cells := clampi(
		roundi(cell_count * _dither_coverage / 100.0), 1, cell_count
	)
	return threshold < visible_cells


func _apply_dither_to_brush_image(
	brush_image: Image, src_rect: Rect2i, dst: Vector2i
) -> Image:
	if not _dither_enabled or _dither_coverage >= 100:
		return brush_image
	var filtered := Image.new()
	filtered.copy_from(brush_image)
	var end_x := src_rect.position.x + src_rect.size.x
	var end_y := src_rect.position.y + src_rect.size.y
	for y in range(src_rect.position.y, end_y):
		for x in range(src_rect.position.x, end_x):
			var canvas_pos := dst + Vector2i(x - src_rect.position.x, y - src_rect.position.y)
			if not _dither_allows_pixel(canvas_pos):
				filtered.set_pixel(x, y, Color.TRANSPARENT)
	return filtered


func _draw_brush_image(brush_image: Image, src_rect: Rect2i, dst: Vector2i) -> void:
	brush_image = _apply_dither_to_brush_image(brush_image, src_rect, dst)
	_changed = true
	var images := _get_selected_draw_images()
	if _overwrite:
		for draw_image in images:
			if Tools.alpha_locked:
				var mask := draw_image.get_region(Rect2i(dst, brush_image.get_size()))
				draw_image.blit_rect_mask(brush_image, mask, src_rect, dst)
			else:
				draw_image.blit_rect(brush_image, src_rect, dst)
			draw_image.convert_rgb_to_indexed()
	else:
		for draw_image in images:
			if Tools.alpha_locked:
				var mask := draw_image.get_region(Rect2i(dst, brush_image.get_size()))
				draw_image.blend_rect_mask(brush_image, mask, src_rect, dst)
			else:
				draw_image.blend_rect(brush_image, src_rect, dst)
			draw_image.convert_rgb_to_indexed()
	update_materials(images)
