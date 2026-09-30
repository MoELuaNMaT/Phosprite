class_name SingleFrameLayerCard
extends Button

signal pointer_down(layer_index: int, position: Vector2, timestamp_msec: int)
signal pointer_up(layer_index: int, position: Vector2, timestamp_msec: int)
signal pointer_cancel(layer_index: int)

const DRAG_CANCEL_DISTANCE := 24.0
const SYNTHETIC_MOUSE_SUPPRESSION_MSEC := 500
const SYNTHETIC_MOUSE_SUPPRESSION_DISTANCE := 32.0

var layer_index := -1
var frame_index := -1
var selection_host: SingleFrameLayerStrip
var _project: Project
var _layer: BaseLayer
var _cel: BaseCel
var _pointer_active := false
var _pointer_origin := Vector2.ZERO
var _last_touch_msec := -1
var _last_touch_position := Vector2.ZERO

@onready var preview_texture := %PreviewTexture as TextureRect
@onready var layer_name_label := %LayerName as Label


func _ready() -> void:
	toggle_mode = true
	gui_input.connect(_on_gui_input)
	if not Global.cel_switched.is_connected(_sync_selected):
		Global.cel_switched.connect(_sync_selected)


func _exit_tree() -> void:
	_disconnect_bound_data()
	if Global.cel_switched.is_connected(_sync_selected):
		Global.cel_switched.disconnect(_sync_selected)


func setup(
	project: Project,
	new_layer_index: int,
	new_frame_index: int,
	host: SingleFrameLayerStrip = null
) -> void:
	_disconnect_bound_data()
	_project = project
	selection_host = host
	layer_index = new_layer_index
	frame_index = new_frame_index
	if (
		_project == null
		or layer_index < 0
		or layer_index >= _project.layers.size()
		or frame_index < 0
		or frame_index >= _project.frames.size()
	):
		return
	_layer = _project.layers[layer_index]
	_cel = _project.frames[frame_index].cels[layer_index]
	layer_name_label.text = _layer.name
	tooltip_text = _layer.name
	preview_texture.texture = _cel.image_texture
	_layer.name_changed.connect(_on_layer_name_changed)
	_cel.texture_changed.connect(_on_cel_texture_changed)
	_sync_selected()


func _disconnect_bound_data() -> void:
	if is_instance_valid(_layer) and _layer.name_changed.is_connected(_on_layer_name_changed):
		_layer.name_changed.disconnect(_on_layer_name_changed)
	if is_instance_valid(_cel) and _cel.texture_changed.is_connected(_on_cel_texture_changed):
		_cel.texture_changed.disconnect(_on_cel_texture_changed)
	_project = null
	_layer = null
	_cel = null
	_pointer_active = false


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_remember_touch(touch.position)
		if touch.pressed:
			_begin_pointer(touch.position)
		else:
			_finish_pointer(touch.position)
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_remember_touch(drag.position)
		_maybe_cancel_pointer(drag.position)
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if _should_suppress_mouse_after_touch(
			Time.get_ticks_msec(),
			_last_touch_msec,
			mouse_button.position,
			_last_touch_position
		):
			accept_event()
			return
		if mouse_button.pressed:
			_begin_pointer(mouse_button.position)
		else:
			_finish_pointer(mouse_button.position)
		return
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if (mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_maybe_cancel_pointer(mouse_motion.position)


func _remember_touch(local_position: Vector2) -> void:
	_last_touch_msec = Time.get_ticks_msec()
	_last_touch_position = local_position


func _begin_pointer(local_position: Vector2) -> void:
	_pointer_active = true
	_pointer_origin = local_position
	pointer_down.emit(layer_index, _to_global_position(local_position), Time.get_ticks_msec())


func _finish_pointer(local_position: Vector2) -> void:
	if not _pointer_active:
		return
	_pointer_active = false
	pointer_up.emit(layer_index, _to_global_position(local_position), Time.get_ticks_msec())


func _maybe_cancel_pointer(local_position: Vector2) -> void:
	if not _pointer_active or local_position.distance_to(_pointer_origin) <= DRAG_CANCEL_DISTANCE:
		return
	_pointer_active = false
	pointer_cancel.emit(layer_index)


func _to_global_position(local_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * local_position


static func _should_suppress_mouse_after_touch(
	now_msec: int,
	last_touch_msec: int,
	mouse_position: Vector2,
	last_touch_position: Vector2
) -> bool:
	if last_touch_msec < 0:
		return false
	var elapsed := now_msec - last_touch_msec
	if elapsed < 0 or elapsed > SYNTHETIC_MOUSE_SUPPRESSION_MSEC:
		return false
	return mouse_position.distance_to(last_touch_position) <= SYNTHETIC_MOUSE_SUPPRESSION_DISTANCE


func toggle_layer_visibility() -> void:
	if (
		_project == null
		or _project != Global.current_project
		or not is_instance_valid(_layer)
		or layer_index < 0
		or layer_index >= _project.layers.size()
		or _project.layers[layer_index] != _layer
	):
		return

	Global.transform_content_confirmed.emit()
	var project := _project
	var layer := _layer
	if Global.layer_visibility_undoable:
		project.undo_redo.create_action("Change Layer Visibility")
		project.undo_redo.add_do_property(layer, "visible", not layer.visible)
		project.undo_redo.add_undo_property(layer, "visible", layer.visible)
		project.undo_redo.add_do_property(Global.canvas, "update_all_layers", true)
		project.undo_redo.add_undo_property(Global.canvas, "update_all_layers", true)
		project.undo_redo.add_do_method(Global.canvas.queue_redraw)
		project.undo_redo.add_undo_method(Global.canvas.queue_redraw)
		if is_instance_valid(Global.animation_timeline):
			project.undo_redo.add_do_method(Global.animation_timeline.update_global_layer_buttons)
			project.undo_redo.add_undo_method(Global.animation_timeline.update_global_layer_buttons)
		project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
		project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
		project.undo_redo.commit_action()
	else:
		layer.visible = not layer.visible
		Global.canvas.update_all_layers = true
		Global.canvas.queue_redraw()
		if is_instance_valid(Global.animation_timeline):
			Global.animation_timeline.update_global_layer_buttons()


func _on_layer_name_changed() -> void:
	if not is_instance_valid(_layer):
		return
	layer_name_label.text = _layer.name
	tooltip_text = _layer.name


func _on_cel_texture_changed() -> void:
	if is_instance_valid(_cel):
		preview_texture.texture = _cel.image_texture


func _sync_selected() -> void:
	button_pressed = (
		_project != null
		and _project == Global.current_project
		and layer_index >= 0
		and layer_index < _project.layers.size()
		and [_project.current_frame, layer_index] in _project.selected_cels
	)
