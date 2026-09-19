extends PanelContainer

const NAVIGATION := preload("res://src/InputAdapter/CanvasInputAdapter.gd")

@onready var preview_viewport_container := $VBox/HBox/PreviewViewportContainer as SubViewportContainer
@onready var canvas_preview := $"%CanvasPreview" as Node2D
@onready var camera := $"%CameraPreview" as CanvasCamera
@onready var play_button := $"%PlayButton" as Button
@onready var start_frame := $"%StartFrame" as ValueSlider
@onready var end_frame := $"%EndFrame" as ValueSlider

var _preview_touches: Dictionary = {}
var _navigation_ids := PackedInt32Array()
var _baseline_centroid := Vector2.ZERO
var _baseline_distance := 0.0
var _baseline_zoom := Vector2.ONE
var _baseline_offset := Vector2.ZERO
var _baseline_angle := 0.0
var _anchor_canvas := Vector2.ZERO
var _pan_active := false
var _pinch_active := false


func _input(event: InputEvent) -> void:
	if OS.get_name() != "iOS" or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		_handle_preview_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_preview_drag(event as InputEventScreenDrag)


func _gui_input(event: InputEvent) -> void:
	var checker: ColorRect = $VBox/HBox/PreviewViewportContainer/SubViewport/TransparentChecker
	if event is InputEventMouseButton:
		var mouse_pos := checker.get_local_mouse_position()
		if (
			mouse_pos.x >= 0
			and mouse_pos.y >= 0
			and mouse_pos.x <= checker.size.x
			and mouse_pos.y <= checker.size.y
		):
			if event.double_click:
				if canvas_preview.mode == canvas_preview.Mode.SPRITESHEET:
					var sprite_sheet_idx = canvas_preview.frame_index
					var x: int = sprite_sheet_idx % canvas_preview.h_frames
					var y: int = sprite_sheet_idx / canvas_preview.v_frames
					mouse_pos += Vector2(x, y) * checker.size
				Global.camera.offset = mouse_pos


func _handle_preview_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if not preview_viewport_container.get_global_rect().has_point(event.position):
			return
		_preview_touches[event.index] = _preview_local_position(event.position)
		_try_begin_preview_navigation()
	else:
		if not _preview_touches.has(event.index):
			return
		_preview_touches.erase(event.index)
		if event.index in _navigation_ids:
			_rebase_preview_navigation()
	get_viewport().set_input_as_handled()


func _handle_preview_drag(event: InputEventScreenDrag) -> void:
	if not _preview_touches.has(event.index):
		return
	_preview_touches[event.index] = _preview_local_position(event.position)
	if _navigation_ids.size() < 2:
		_try_begin_preview_navigation()
	if event.index in _navigation_ids:
		_update_preview_navigation()
	get_viewport().set_input_as_handled()


func _preview_local_position(screen_position: Vector2) -> Vector2:
	return (
		preview_viewport_container.get_global_transform_with_canvas().affine_inverse()
		* screen_position
	)


func _try_begin_preview_navigation() -> void:
	if _navigation_ids.size() == 2 or _preview_touches.size() < 2:
		return
	var ids := PackedInt32Array()
	for touch_id: int in _preview_touches:
		ids.append(touch_id)
	ids.sort()
	_navigation_ids = PackedInt32Array([ids[0], ids[1]])
	_capture_preview_navigation_baseline()


func _capture_preview_navigation_baseline() -> void:
	if _navigation_ids.size() != 2:
		return
	var geometry := _preview_navigation_geometry()
	_baseline_centroid = geometry["centroid"]
	_baseline_distance = float(geometry["distance"])
	_baseline_zoom = camera.zoom
	_baseline_offset = camera.offset
	_baseline_angle = camera.camera_angle
	_anchor_canvas = NAVIGATION.screen_to_canvas_point(
		_baseline_centroid,
		preview_viewport_container.size,
		_baseline_zoom,
		_baseline_offset,
		_baseline_angle
	)
	_pan_active = false
	_pinch_active = false


func _rebase_preview_navigation() -> void:
	_navigation_ids.clear()
	_pan_active = false
	_pinch_active = false
	_try_begin_preview_navigation()


func _update_preview_navigation() -> void:
	if _navigation_ids.size() != 2:
		return
	var geometry := _preview_navigation_geometry()
	var centroid: Vector2 = geometry["centroid"]
	var distance := float(geometry["distance"])

	if not _pan_active:
		_pan_active = NAVIGATION.navigation_pan_exceeds_dead_zone(
			_baseline_centroid, centroid
		)
	if not _pinch_active:
		_pinch_active = NAVIGATION.navigation_pinch_exceeds_dead_zone(
			_baseline_distance, distance
		)

	var effective_centroid := _baseline_centroid
	if _pan_active:
		effective_centroid = centroid
	var scale_ratio := 1.0
	if _pinch_active:
		scale_ratio = NAVIGATION.navigation_scale_ratio(_baseline_distance, distance)

	var target_zoom := NAVIGATION.navigation_zoom_from_ratio(
		_baseline_zoom,
		scale_ratio,
		Global.integer_zoom,
		camera.zoom_out_max,
		camera.zoom_in_max
	)
	var target_offset := NAVIGATION.navigation_offset_for_anchor(
		_anchor_canvas,
		effective_centroid,
		preview_viewport_container.size,
		target_zoom,
		_baseline_angle
	)

	if not camera.zoom.is_equal_approx(target_zoom):
		camera.zoom = target_zoom
	if not camera.offset.is_equal_approx(target_offset):
		camera.offset = target_offset
	camera.update_transparent_checker_offset()


func _preview_navigation_geometry() -> Dictionary:
	var first: Vector2 = _preview_touches[_navigation_ids[0]]
	var second: Vector2 = _preview_touches[_navigation_ids[1]]
	return NAVIGATION.navigation_pair_geometry(first, second)


func _on_PlayButton_toggled(button_pressed: bool) -> void:
	if button_pressed:
		if canvas_preview.mode == canvas_preview.Mode.TIMELINE:
			if Global.current_project.frames.size() <= 1:
				play_button.button_pressed = false
				return
		else:
			if start_frame.value == end_frame.value:
				play_button.button_pressed = false
				return
		canvas_preview.animation_timer.start()
		Global.change_button_texturerect(play_button.get_child(0), "pause.png")
	else:
		canvas_preview.animation_timer.stop()
		Global.change_button_texturerect(play_button.get_child(0), "play.png")


func _on_OptionButton_item_selected(index: int) -> void:
	play_button.button_pressed = false
	canvas_preview.mode = index
	if index == 0:
		$VBox/Animation/VBoxContainer/Options.visible = false
		canvas_preview.transparent_checker.fit_rect(
			Rect2(Vector2.ZERO, Global.current_project.size)
		)
	else:
		$VBox/Animation/VBoxContainer/Options.visible = true
	canvas_preview.queue_redraw()


func _on_HFrames_value_changed(value: float) -> void:
	canvas_preview.h_frames = value
	var frames: int = canvas_preview.h_frames * canvas_preview.v_frames
	start_frame.max_value = frames
	end_frame.max_value = frames
	canvas_preview.queue_redraw()


func _on_VFrames_value_changed(value: float) -> void:
	canvas_preview.v_frames = value
	var frames: int = canvas_preview.h_frames * canvas_preview.v_frames
	start_frame.max_value = frames
	end_frame.max_value = frames
	canvas_preview.queue_redraw()


func _on_StartFrame_value_changed(value: float) -> void:
	canvas_preview.frame_index = value - 1
	canvas_preview.start_sprite_sheet_frame = value
	if end_frame.value < value:
		end_frame.value = value
	canvas_preview.queue_redraw()


func _on_EndFrame_value_changed(value: float) -> void:
	canvas_preview.end_sprite_sheet_frame = value
	if start_frame.value > value:
		start_frame.value = value
		canvas_preview.frame_index = value - 1
	canvas_preview.queue_redraw()


func _on_PreviewViewportContainer_mouse_entered() -> void:
	camera.set_process_input(true)


func _on_PreviewViewportContainer_mouse_exited() -> void:
	camera.set_process_input(false)
