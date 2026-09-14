extends BaseSelectionTool

const CANVAS_INPUT_ADAPTER := preload("res://src/InputAdapter/CanvasInputAdapter.gd")
const TOUCH_DOUBLE_TAP_MSEC := 350

var _last_position := Vector2i(Vector2.INF)
var _draw_points: Array[Vector2i] = []
var _ready_to_apply := false
var _touch_last_tap_msec := -1
var _touch_last_tap_screen := Vector2.ZERO
var _touch_cancel_button: Button


func _init() -> void:
	# To prevent tool from remaining active when switching projects
	Global.project_about_to_switch.connect(_clear)


func _ready() -> void:
	super()
	if OS.get_name() != "iOS":
		return
	_touch_cancel_button = Button.new()
	_touch_cancel_button.name = "TouchCancelPolygon"
	_touch_cancel_button.text = tr("Cancel polygon")
	_touch_cancel_button.tooltip_text = tr("Cancel the current polygon selection")
	_touch_cancel_button.custom_minimum_size = Vector2(0, 44)
	_touch_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_touch_cancel_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_touch_cancel_button.visible = false
	_touch_cancel_button.pressed.connect(cancel_tool)
	add_child(_touch_cancel_button)


func _input(event: InputEvent) -> void:
	if _move:
		return
	if event is InputEventMouseMotion:
		_last_position = Global.canvas.current_pixel.floor()
		if Global.mirror_view:
			_last_position.x = (Global.current_project.size.x - 1) - _last_position.x
	elif event is InputEventMouseButton:
		if event.double_click and event.button_index == tool_slot.button and _draw_points:
			$DoubleClickTimer.start()
			_draw_points.append_array(Geometry2D.bresenham_line(_draw_points[-1], _draw_points[0]))
			_ready_to_apply = true
			apply_selection(Vector2i.ZERO)  # Argument doesn't matter
	else:
		if event.is_action_pressed("transformation_cancel") and _ongoing_selection:
			_clear()


func draw_start(pos: Vector2i) -> void:
	if !$DoubleClickTimer.is_stopped():
		return
	pos = snap_position(pos)
	super.draw_start(pos)
	if !_move and !_draw_points:
		_ongoing_selection = true
		_draw_points.append(pos)
		_last_position = pos
	if _ongoing_selection and is_instance_valid(_touch_cancel_button):
		_touch_cancel_button.visible = true


func draw_move(pos: Vector2i) -> void:
	if transformation_handles.arrow_key_move:
		return
	pos = snap_position(pos)
	super.draw_move(pos)


func draw_end(pos: Vector2i) -> void:
	if transformation_handles.arrow_key_move:
		return
	pos = snap_position(pos)
	if !_move and _draw_points:
		if _consume_ios_touch_double_tap():
			$DoubleClickTimer.start()
			_draw_points.append_array(Geometry2D.bresenham_line(_draw_points[-1], _draw_points[0]))
			_ready_to_apply = true
			super.draw_end(pos)
			return
		if _draw_points.size() > 1 or _draw_points[-1] != pos:
			_draw_points.append_array(Geometry2D.bresenham_line(_draw_points[-1], pos))
		if pos == _draw_points[0] and _draw_points.size() > 1:
			_ready_to_apply = true

	super.draw_end(pos)


func cancel_tool() -> void:
	super()
	_clear()


func draw_preview() -> void:
	var previews := Global.canvas.previews_sprite
	if _ongoing_selection and !_move:
		var preview_draw_points := _draw_points.duplicate() as Array[Vector2i]
		preview_draw_points.append_array(
			Geometry2D.bresenham_line(_draw_points[-1], _last_position)
		)
		var image := Image.create(
			Global.current_project.size.x, Global.current_project.size.y, false, Image.FORMAT_LA8
		)
		for point in preview_draw_points:
			var draw_point := point
			if Global.mirror_view:  # This fixes previewing in mirror mode
				draw_point.x = image.get_width() - draw_point.x - 1
			if Rect2i(Vector2i.ZERO, image.get_size()).has_point(draw_point):
				image.set_pixelv(draw_point, Color.WHITE)

		var circle_radius := Vector2.ONE * (10.0 / Global.camera.zoom.x)
		if _last_position == _draw_points[0] and _draw_points.size() > 1:
			var canvas := Global.canvas.previews
			draw_empty_circle(
				canvas, Vector2(_draw_points[0]) + Vector2.ONE * 0.5, circle_radius, Color.BLACK
			)

		# Handle mirroring
		for point in mirror_array(preview_draw_points):
			var draw_point := point
			if Global.mirror_view:  # This fixes previewing in mirror mode
				draw_point.x = image.get_width() - draw_point.x - 1
			if Rect2i(Vector2i.ZERO, image.get_size()).has_point(draw_point):
				image.set_pixelv(draw_point, Color.WHITE)
		var texture := ImageTexture.create_from_image(image)
		previews.texture = texture


func apply_selection(pos: Vector2i) -> void:
	super.apply_selection(pos)
	if !_ready_to_apply:
		return
	var project := Global.current_project
	var cleared := false
	var previous_selection_map := SelectionMap.new()  # Used for intersect
	previous_selection_map.copy_from(project.selection_map)
	if !_add and !_subtract and !_intersect:
		cleared = true
		Global.canvas.selection.clear_selection()
	if _draw_points.size() > 3:
		if _intersect:
			project.selection_map.clear()
		lasso_selection(_draw_points, project, previous_selection_map)
		# Handle mirroring
		var callable := lasso_selection.bind(project, previous_selection_map)
		mirror_array(_draw_points, callable)
	else:
		if !cleared:
			Global.canvas.selection.clear_selection()

	Global.canvas.selection.commit_undo("Select", undo_data)
	_clear()


func _clear() -> void:
	_ongoing_selection = false
	Global.canvas.previews_sprite.texture = null
	_draw_points.clear()
	_ready_to_apply = false
	_touch_last_tap_msec = -1
	_touch_last_tap_screen = Vector2.ZERO
	if is_instance_valid(_touch_cancel_button):
		_touch_cancel_button.visible = false
	Global.canvas.previews.queue_redraw()


func _consume_ios_touch_double_tap() -> bool:
	if not _is_adapter_touch_polygon_input():
		return false
	var now := Time.get_ticks_msec()
	var current_screen := _current_touch_screen_position()
	var is_double_tap := (
		_touch_last_tap_msec >= 0
		and now - _touch_last_tap_msec <= TOUCH_DOUBLE_TAP_MSEC
		and not CANVAS_INPUT_ADAPTER.long_press_motion_exceeds_slop(
			_touch_last_tap_screen, current_screen
		)
	)
	_touch_last_tap_msec = now
	_touch_last_tap_screen = current_screen
	return is_double_tap


func _is_adapter_touch_polygon_input() -> bool:
	if OS.get_name() != "iOS" or not is_instance_valid(Global.canvas):
		return false
	var adapter = Global.canvas._input_adapter
	return adapter != null and int(adapter._content_touch_id) != -1


func _current_touch_screen_position() -> Vector2:
	return Global.canvas.get_global_transform_with_canvas() * Global.canvas.current_pixel


func lasso_selection(
	points: Array[Vector2i], project: Project, previous_selection_map: SelectionMap
) -> void:
	var selection_map := project.selection_map
	var selection_size := selection_map.get_size()
	var bounding_rect := Rect2i(points[0], Vector2i.ZERO)
	for point in points:
		bounding_rect = bounding_rect.expand(point)
		if point.x < 0 or point.y < 0 or point.x >= selection_size.x or point.y >= selection_size.y:
			continue
		if _intersect:
			if previous_selection_map.is_pixel_selected(point):
				select_pixel(point, project, true)
		else:
			select_pixel(point, project, !_subtract)

	var v := Vector2i()
	for x in bounding_rect.size.x:
		v.x = x + bounding_rect.position.x
		for y in bounding_rect.size.y:
			v.y = y + bounding_rect.position.y
			if Geometry2D.is_point_in_polygon(v, points):
				if _intersect:
					if previous_selection_map.is_pixel_selected(v):
						select_pixel(v, project, true)
				else:
					select_pixel(v, project, !_subtract)


func select_pixel(point: Vector2i, project: Project, select: bool) -> void:
	if Tools.is_placing_tiles():
		var tilemap := project.get_current_cel() as CelTileMap
		var cell_position := tilemap.get_cell_position(point) * tilemap.get_tile_size()
		select_tilemap_cell(tilemap, cell_position, project.selection_map, select)
	var selection_size := project.selection_map.get_size()
	if point.x >= 0 and point.y >= 0 and point.x < selection_size.x and point.y < selection_size.y:
		project.selection_map.select_pixel(point, select)


# Thanks to
# https://www.reddit.com/r/godot/comments/3ktq39/drawing_empty_circles_and_curves/cv0f4eo/
func draw_empty_circle(
	canvas: CanvasItem, circle_center: Vector2, circle_radius: Vector2, color: Color
) -> void:
	var draw_counter := 1
	var line_origin := Vector2()
	var line_end := Vector2()
	line_origin = circle_radius + circle_center

	while draw_counter <= 360:
		line_end = circle_radius.rotated(deg_to_rad(draw_counter)) + circle_center
		canvas.draw_line(line_origin, line_end, color)
		draw_counter += 1
		line_origin = line_end

	line_end = circle_radius.rotated(TAU) + circle_center
	canvas.draw_line(line_origin, line_end, color)
