class_name TouchTransformHandleRouter
extends RefCounted

## Routes CanvasInputAdapter-owned touch/Pencil events into the existing Selection transform
## handle state machine. Visual handle size is unchanged; only touch acquisition uses a larger
## target, and overlapping targets resolve to the nearest existing handle.
const TOUCH_HANDLE_DIAMETER_PX := 44.0
const TOUCH_HANDLE_RADIUS_PX := TOUCH_HANDLE_DIAMETER_PX * 0.5
const MIN_ZOOM := 0.0001


static func handle_event(canvas, viewport_position: Vector2, event: InputEvent) -> bool:
	if event is not InputEventMouseButton and event is not InputEventMouseMotion:
		return false
	if not is_instance_valid(canvas) or not is_instance_valid(canvas.selection):
		return false
	var transformation_handles = canvas.selection.transformation_handles
	if not is_instance_valid(transformation_handles):
		return false
	if not is_instance_valid(transformation_handles.transformed_selection_map):
		return false
	if not Tools.has_selection_tool():
		return false

	var project := Global.current_project
	if not is_instance_valid(project) or project.layers.is_empty():
		return false
	if not project.layers[project.current_layer].can_layer_get_drawn():
		return false

	var local_position: Vector2 = (
		transformation_handles.get_global_transform_with_canvas().affine_inverse() * viewport_position
	)
	if Global.mirror_view:
		local_position.x = project.size.x - local_position.x

	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index != MOUSE_BUTTON_LEFT:
			return false
		if button_event.pressed:
			var hovered_handle = _nearest_touch_handle(transformation_handles, local_position)
			if hovered_handle == null:
				return false
			transformation_handles._handle_mouse_press(local_position, hovered_handle)
			return is_instance_valid(transformation_handles.active_handle)
		if is_instance_valid(transformation_handles.active_handle):
			transformation_handles.active_handle = null
			return true
		return false

	if is_instance_valid(transformation_handles.active_handle):
		transformation_handles._handle_mouse_drag(local_position)
		return true
	return false


static func _nearest_touch_handle(transformation_handles, local_position: Vector2):
	var zoom_x: float = maxf(absf(Global.camera.zoom.x), MIN_ZOOM)
	var best_handle = null
	var best_distance_px := INF
	for index in transformation_handles.handles.size():
		var handle = transformation_handles.handles[index]
		# The pivot handle is intentionally hidden until a rotation or skew exists.
		if index == 0 and not transformation_handles.is_rotated_or_skewed():
			continue
		var local_distance: float = transformation_handles.get_handle_position(handle).distance_to(
			local_position
		)
		var distance_px: float = local_distance * zoom_x
		if distance_px <= TOUCH_HANDLE_RADIUS_PX and distance_px < best_distance_px:
			best_distance_px = distance_px
			best_handle = handle
	return best_handle
