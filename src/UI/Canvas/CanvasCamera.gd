class_name CanvasCamera
extends Node2D

signal zoom_changed
signal rotation_changed
signal offset_changed

enum Cameras { MAIN, SECOND, SMALL }

const CAMERA_SPEED_RATE := 15.0
const TWO_FINGER_EPSILON := 0.01

@export var index := 0

var zoom := Vector2.ONE:
	set(value):
		zoom = value
		Global.current_project.cameras_zoom[index] = zoom
		zoom_changed.emit()
		_update_viewport_transform()
var camera_angle := 0.0:
	set(value):
		camera_angle = wrapf(value, -PI, PI)
		camera_angle_degrees = rad_to_deg(camera_angle)
		Global.current_project.cameras_rotation[index] = camera_angle
		rotation_changed.emit()
		_update_viewport_transform()
var camera_angle_degrees := 0.0
var offset := Vector2.ZERO:
	set(value):
		offset = value
		Global.current_project.cameras_offset[index] = offset
		offset_changed.emit()
		_update_viewport_transform()
var camera_screen_center := Vector2.ZERO
var zoom_in_max := Vector2(500, 500)
var zoom_out_max := Vector2(0.01, 0.01)
var viewport_container: SubViewportContainer
var transparent_checker: ColorRect
var mouse_pos := Vector2.ZERO
var drag := false
var rotation_slider: ValueSlider
var zoom_slider: ValueSlider
var should_tween := true
var auto_release_gui_focus := true
var _two_finger_transform_active := false
var _two_finger_start_offset := Vector2.ZERO
var _two_finger_start_zoom := Vector2.ONE
var _two_finger_start_angle := 0.0
var _two_finger_start_centroid := Vector2.ZERO
var _two_finger_start_distance := 0.0

@onready var viewport := get_viewport()


static func solve_two_finger_transform(
	start_offset: Vector2,
	start_zoom: Vector2,
	start_angle: float,
	viewport_size: Vector2,
	start_centroid: Vector2,
	start_distance: float,
	current_centroid: Vector2,
	current_distance: float,
	min_zoom: Vector2,
	max_zoom: Vector2,
	rotation_delta := 0.0
) -> Dictionary:
	if start_distance <= TWO_FINGER_EPSILON or current_distance <= TWO_FINGER_EPSILON:
		return {}
	if start_zoom.x <= 0.0 or start_zoom.y <= 0.0:
		return {}

	var scale_factor := current_distance / start_distance
	var min_scale := maxf(min_zoom.x / start_zoom.x, min_zoom.y / start_zoom.y)
	var max_scale := minf(max_zoom.x / start_zoom.x, max_zoom.y / start_zoom.y)
	if max_scale < min_scale:
		return {}
	scale_factor = clampf(scale_factor, min_scale, max_scale)

	var target_zoom := start_zoom * scale_factor
	var target_angle := wrapf(start_angle + rotation_delta, -PI, PI)
	var half_viewport := viewport_size * 0.5
	var anchor := (
		start_offset
		+ (start_centroid - half_viewport).rotated(start_angle) * (Vector2.ONE / start_zoom)
	)
	var target_offset := (
		anchor
		- (current_centroid - half_viewport).rotated(target_angle) * (Vector2.ONE / target_zoom)
	)
	return {
		"offset": target_offset,
		"zoom": target_zoom,
		"angle": target_angle,
		"anchor": anchor,
	}


func _ready() -> void:
	viewport.size_changed.connect(_update_viewport_transform)
	Global.project_switched.connect(_project_switched)
	if not DisplayServer.is_touchscreen_available():
		set_process_input(false)
	if index == Cameras.MAIN:
		rotation_slider = Global.top_menu_container.get_node("%RotationSlider")
		rotation_slider.value_changed.connect(_rotation_slider_value_changed)
		zoom_slider = Global.top_menu_container.get_node("%ZoomSlider")
		zoom_slider.value_changed.connect(_zoom_slider_value_changed)
	zoom_changed.connect(_zoom_changed)
	rotation_changed.connect(_rotation_changed)
	viewport_container = get_viewport().get_parent()
	transparent_checker = get_viewport().get_node("TransparentChecker")
	update_transparent_checker_offset()


func _input(event: InputEvent) -> void:
	if (
		OS.get_name() == "iOS"
		and (
			event is InputEventScreenTouch
			or event is InputEventScreenDrag
			or event is InputEventGesture
		)
	):
		# P1-B derives iPad navigation from raw multitouch in CanvasInputAdapter.
		# Consuming the legacy gesture path here prevents double pan/zoom and Pencil cancellation.
		return
	if not DisplayServer.is_touchscreen_available() and auto_release_gui_focus:
		get_window().gui_release_focus()
	if !Global.can_draw:
		drag = false
		return
	mouse_pos = viewport_container.get_local_mouse_position()
	if event.is_action_pressed(&"pan"):
		drag = true
	elif event.is_action_released(&"pan"):
		drag = false
	elif event.is_action_pressed(&"zoom_in", false, true):  # Wheel Up Event
		zoom_camera(1)
	elif event.is_action_pressed(&"zoom_out", false, true):  # Wheel Down Event
		zoom_camera(-1)
	elif event.is_action_pressed(&"rotate_right", false, true):  # Wheel Up Event
		rotate_camera(1)
	elif event.is_action_pressed(&"rotate_left", false, true):  # Wheel Down Event
		rotate_camera(-1)

	elif event is InputEventMagnifyGesture:  # Zoom gesture on touchscreens
		var scale_factor := (event as InputEventMagnifyGesture).factor
		var zoom_strength := log(scale_factor) * 8.0
		zoom_camera(zoom_strength, event.position)
	elif event is InputEventPanGesture:
		# Pan gesture on touchscreens
		offset = offset + event.delta.rotated(camera_angle) * 2.0 / zoom
	elif event is InputEventMouseMotion:
		if drag:
			offset = offset - event.relative.rotated(camera_angle) / zoom
			update_transparent_checker_offset()
	else:
		var dir := Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
		if dir != Vector2.ZERO and not Tools.has_selection_tool():
			offset = offset + (dir.rotated(camera_angle) / zoom) * CAMERA_SPEED_RATE


func rotate_camera(dir: float) -> void:
	camera_angle += PI / 180 * dir


func zoom_camera(dir: float, event_pos := mouse_pos) -> void:
	var viewport_size := viewport_container.size
	if Global.smooth_zoom:
		var zoom_margin := zoom * dir / 5
		var new_zoom := zoom + zoom_margin
		if Global.integer_zoom:
			new_zoom = (zoom + Vector2.ONE * dir).floor()
		if new_zoom < zoom_in_max && new_zoom > zoom_out_max:
			var new_offset := (
				offset
				+ (
					(-0.5 * viewport_size + event_pos).rotated(camera_angle)
					* (Vector2.ONE / zoom - Vector2.ONE / new_zoom)
				)
			)
			var tween := create_tween().set_parallel()
			tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
			tween.tween_property(self, "zoom", new_zoom, 0.05)
			tween.tween_property(self, "offset", new_offset, 0.05)
	else:
		var prev_zoom := zoom
		var zoom_margin := zoom * dir / 10
		if Global.integer_zoom:
			zoom_margin = (Vector2.ONE * dir).floor()
		if zoom + zoom_margin <= zoom_in_max:
			zoom += zoom_margin
		if zoom < zoom_out_max:
			if Global.integer_zoom:
				zoom = Vector2.ONE
			else:
				zoom = zoom_out_max
		offset = (
			offset
			+ (
				(-0.5 * viewport_size + event_pos).rotated(camera_angle)
				* (Vector2.ONE / prev_zoom - Vector2.ONE / zoom)
			)
		)


func begin_two_finger_transform(start_centroid: Vector2, start_distance: float) -> bool:
	if not is_instance_valid(viewport_container) or start_distance <= TWO_FINGER_EPSILON:
		return false
	_two_finger_transform_active = true
	_two_finger_start_offset = offset
	_two_finger_start_zoom = zoom
	_two_finger_start_angle = camera_angle
	_two_finger_start_centroid = start_centroid
	_two_finger_start_distance = start_distance
	return true


func update_two_finger_transform(
	current_centroid: Vector2, current_distance: float, rotation_delta := 0.0
) -> void:
	if not _two_finger_transform_active:
		return
	var result := solve_two_finger_transform(
		_two_finger_start_offset,
		_two_finger_start_zoom,
		_two_finger_start_angle,
		viewport_container.size,
		_two_finger_start_centroid,
		_two_finger_start_distance,
		current_centroid,
		current_distance,
		zoom_out_max,
		zoom_in_max,
		rotation_delta
	)
	if result.is_empty():
		return
	camera_angle = result["angle"]
	zoom = result["zoom"]
	offset = result["offset"]
	update_transparent_checker_offset()


func end_two_finger_transform() -> void:
	_two_finger_transform_active = false


func zoom_100() -> void:
	zoom = Vector2.ONE
	offset = Global.current_project.size / 2


func fit_to_frame(size: Vector2) -> void:
	viewport_container = get_viewport().get_parent()
	var h_ratio := viewport_container.size.x / size.x
	var v_ratio := viewport_container.size.y / size.y
	var ratio := minf(h_ratio, v_ratio)
	if ratio == 0 or !viewport_container.visible:
		return
	# Temporarily disable integer zoom.
	var reset_integer_zoom := Global.integer_zoom
	if reset_integer_zoom:
		Global.integer_zoom = !Global.integer_zoom
	offset = size / 2

	# Adjust to the rotated size:
	if camera_angle != 0.0:
		# Calculating the rotated corners of the frame to find its rotated size.
		var a := Vector2.ZERO  # Top left
		var b := Vector2(size.x, 0).rotated(camera_angle)  # Top right.
		var c := Vector2(0, size.y).rotated(camera_angle)  # Bottom left.
		var d := Vector2(size.x, size.y).rotated(camera_angle)  # Bottom right.

		# Find how far apart each opposite point is on each axis, and take the longer one.
		size.x = maxf(absf(a.x - d.x), absf(b.x - c.x))
		size.y = maxf(absf(a.y - d.y), absf(b.y - c.y))

	ratio = clampf(ratio, 0.1, ratio)
	zoom = Vector2(ratio, ratio)
	if reset_integer_zoom:
		Global.integer_zoom = !Global.integer_zoom


func update_transparent_checker_offset() -> void:
	var o := get_global_transform_with_canvas().get_origin()
	var s := get_global_transform_with_canvas().get_scale()
	transparent_checker.update_offset(o, s)


## Updates the viewport's canvas transform, which is the area of the canvas that is
## currently visible. Called every time the camera's zoom, rotation or origin changes.
func _update_viewport_transform() -> void:
	if not is_instance_valid(viewport):
		return
	var zoom_scale := Vector2.ONE / zoom
	var viewport_size := get_viewport_rect().size
	var half_size := viewport_size * 0.5
	var screen_offset := -(half_size * zoom_scale).rotated(camera_angle) + offset
	var xform := Transform2D(camera_angle, zoom_scale, 0, screen_offset)
	camera_screen_center = xform * half_size
	viewport.canvas_transform = xform.affine_inverse()


func _zoom_changed() -> void:
	update_transparent_checker_offset()
	if index == Cameras.MAIN:
		should_tween = false
		zoom_slider.set_value_no_signal_update_display(zoom.x * 100.0)
		should_tween = true
		for guide in Global.current_project.guides:
			guide.width = 1.0 / zoom.x * 2


func _rotation_changed() -> void:
	if index == Cameras.MAIN:
		# Negative to make going up in value clockwise, and match the spinbox which does the same
		rotation_slider.value = -camera_angle_degrees


func _zoom_slider_value_changed(value: float) -> void:
	if value <= 0:
		value = 1
	var new_zoom := Vector2(value, value) / 100.0
	if zoom.is_equal_approx(new_zoom):
		return
	if Global.smooth_zoom and should_tween:
		var tween := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "zoom", new_zoom, 0.05)
	else:
		zoom = new_zoom


func _rotation_slider_value_changed(value: float) -> void:
	# Negative makes going up rotate clockwise
	var angle := deg_to_rad(-value)
	var difference := angle - camera_angle
	var canvas_center: Vector2 = Global.current_project.size / 2
	offset = (offset - canvas_center).rotated(difference) + canvas_center
	camera_angle = angle


func _project_switched() -> void:
	end_two_finger_transform()
	offset = Global.current_project.cameras_offset[index]
	camera_angle = Global.current_project.cameras_rotation[index]
	zoom = Global.current_project.cameras_zoom[index]


func _rotate_camera_around_point(degrees: float, point: Vector2) -> void:
	var angle := deg_to_rad(degrees)
	offset = (offset - point).rotated(angle) + point
	camera_angle = camera_angle + angle
