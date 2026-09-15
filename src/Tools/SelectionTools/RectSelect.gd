extends BaseSelectionTool

const CANVAS_INPUT_ADAPTER := preload("res://src/InputAdapter/CanvasInputAdapter.gd")
const TOUCH_PERFECT_HOLD_SECONDS := 1.0

var _rect := Rect2i()

var _square := false  ## Mouse Click + Shift
var _expand_from_center := false  ## Mouse Click + Ctrl
var _displace_origin = false  ## Mouse Click + Alt
var _touch_hold_generation := 0
var _touch_hold_armed := false
var _touch_hold_anchor_screen := Vector2.ZERO
var _touch_perfect_locked := false


func _input(event: InputEvent) -> void:
	if !_move and _rect.has_area():
		if event.is_action_pressed("shape_perfect"):
			_square = true
		elif event.is_action_released("shape_perfect"):
			_square = false
		if event.is_action_pressed("shape_center"):
			_expand_from_center = true
		elif event.is_action_released("shape_center"):
			_expand_from_center = false
		if event.is_action_pressed("shape_displace"):
			_displace_origin = true
		elif event.is_action_released("shape_displace"):
			_displace_origin = false


func draw_start(pos: Vector2i) -> void:
	_reset_touch_perfect_hold()
	super.draw_start(pos)


func draw_move(pos: Vector2i) -> void:
	if transformation_handles.arrow_key_move:
		return
	pos = snap_position(pos)
	super.draw_move(pos)
	if !_move:
		if _displace_origin:
			_start_pos += pos - _offset
		_rect = _get_result_rect(_start_pos, pos)
		_set_cursor_text(_rect)
		_offset = pos
		_update_touch_perfect_hold()


func draw_end(pos: Vector2i) -> void:
	if transformation_handles.arrow_key_move:
		return
	pos = snap_position(pos)
	super.draw_end(pos)
	_reset_tool()


func cancel_tool() -> void:
	super()
	_reset_tool()


func _reset_tool() -> void:
	_rect = Rect2i()
	_square = false
	_expand_from_center = false
	_displace_origin = false
	_reset_touch_perfect_hold()


func _reset_touch_perfect_hold() -> void:
	_touch_hold_generation += 1
	_touch_hold_armed = false
	_touch_hold_anchor_screen = Vector2.ZERO
	_touch_perfect_locked = false


func _update_touch_perfect_hold() -> void:
	if not _is_adapter_touch_selection_drag() or _touch_perfect_locked:
		return
	var current_screen := _current_touch_screen_position()
	if (
		_touch_hold_armed
		and not CANVAS_INPUT_ADAPTER.long_press_motion_exceeds_slop(
			_touch_hold_anchor_screen, current_screen
		)
	):
		return
	_touch_hold_generation += 1
	_touch_hold_armed = true
	_touch_hold_anchor_screen = current_screen
	var generation := _touch_hold_generation
	var timer := get_tree().create_timer(TOUCH_PERFECT_HOLD_SECONDS)
	timer.timeout.connect(_try_lock_touch_perfect_shape.bind(generation))


func _try_lock_touch_perfect_shape(generation: int) -> void:
	if (
		generation != _touch_hold_generation
		or not _touch_hold_armed
		or _touch_perfect_locked
		or not _is_adapter_touch_selection_drag()
	):
		return
	var current_screen := _current_touch_screen_position()
	if CANVAS_INPUT_ADAPTER.long_press_motion_exceeds_slop(
		_touch_hold_anchor_screen, current_screen
	):
		return
	_square = true
	_touch_hold_armed = false
	_touch_perfect_locked = true
	# Re-evaluate immediately at the stationary touch point. No additional drag event is
	# required, which is the reason this cannot be implemented as another motion threshold.
	draw_move(Vector2i(Global.canvas.current_pixel.floor()))
	Global.canvas.previews.queue_redraw()


func _is_adapter_touch_selection_drag() -> bool:
	if OS.get_name() != "iOS" or _move or not is_instance_valid(Global.canvas):
		return false
	var adapter = Global.canvas._input_adapter
	return adapter != null and int(adapter._content_touch_id) != -1


func _current_touch_screen_position() -> Vector2:
	return Global.canvas.get_global_transform_with_canvas() * Global.canvas.current_pixel


func draw_preview() -> void:
	if _move:
		return
	var project := Global.current_project
	var canvas: Node2D = Global.canvas.previews
	var pos := canvas.position
	var canvas_scale := canvas.scale
	if Global.mirror_view:
		pos.x = pos.x + project.size.x
		canvas_scale.x = -1
	canvas.draw_set_transform(pos, canvas.rotation, canvas_scale)
	canvas.draw_rect(_rect, Color.BLACK, false)
	# Handle mirroring
	var mirror_positions := Tools.get_mirrored_positions(_rect.position, project, 1)
	var mirror_ends := Tools.get_mirrored_positions(_rect.end, project, 1)
	for i in mirror_positions.size():
		var mirror_rect := Rect2i()
		mirror_rect.position = mirror_positions[i]
		mirror_rect.end = mirror_ends[i]
		canvas.draw_rect(mirror_rect, Color.BLACK, false)

	canvas.draw_set_transform(canvas.position, canvas.rotation, canvas.scale)


func apply_selection(pos: Vector2i) -> void:
	super.apply_selection(pos)
	var project := Global.current_project
	if !_add and !_subtract and !_intersect:
		Global.canvas.selection.clear_selection()
		if _rect.size == Vector2i.ZERO and project.has_selection:
			Global.canvas.selection.commit_undo("Select", undo_data)
	if _rect.size == Vector2i.ZERO:
		return
	var operation := 0
	if _subtract:
		operation = 1
	elif _intersect:
		operation = 2
	Global.canvas.selection.select_rect(_rect, operation)
	# Handle mirroring
	var mirror_positions := Tools.get_mirrored_positions(_rect.position, project, 1)
	var mirror_ends := Tools.get_mirrored_positions(_rect.end, project, 1)
	for i in mirror_positions.size():
		var mirror_rect := Rect2i()
		mirror_rect.position = mirror_positions[i]
		mirror_rect.end = mirror_ends[i]
		Global.canvas.selection.select_rect(mirror_rect.abs(), operation)

	Global.canvas.selection.commit_undo("Select", undo_data)


## Given an origin point and destination point, returns a rect representing
## where the shape will be drawn and what is its size
func _get_result_rect(origin: Vector2i, dest: Vector2i) -> Rect2i:
	if Tools.is_placing_tiles():
		var cel := Global.current_project.get_current_cel() as CelTileMap
		var grid_size := cel.get_tile_size()
		var offset := cel.offset % grid_size
		origin = Tools.snap_to_rectangular_grid_boundary(origin, grid_size, offset)
		dest = Tools.snap_to_rectangular_grid_boundary(dest, grid_size, offset)
	var rect := Rect2i()

	# Center the rect on the mouse
	if _expand_from_center:
		var new_size := dest - origin
		# Make rect 1:1 while centering it on the mouse
		if _square:
			var square_size := maxi(absi(new_size.x), absi(new_size.y))
			new_size = Vector2i(square_size, square_size)

		origin -= new_size
		dest = origin + 2 * new_size

	# Make rect 1:1 while not trying to center it
	if _square:
		var square_size := mini(absi(origin.x - dest.x), absi(origin.y - dest.y))
		rect.position.x = origin.x if origin.x < dest.x else origin.x - square_size
		rect.position.y = origin.y if origin.y < dest.y else origin.y - square_size
		rect.size = Vector2i(square_size, square_size)
	# Get the rect without any modifications
	else:
		rect.position = Vector2i(mini(origin.x, dest.x), mini(origin.y, dest.y))
		rect.size = (origin - dest).abs()

	if (
		not Tools.is_placing_tiles()
		and not Global.snap_to_rectangular_grid_boundary
		and not Global.snap_to_rectangular_grid_center
	):
		rect.size += Vector2i.ONE

	return rect
