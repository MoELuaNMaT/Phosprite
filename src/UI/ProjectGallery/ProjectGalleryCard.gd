class_name ProjectGalleryCard
extends Button

signal pointer_down(path: String, position: Vector2, timestamp_msec: int)
signal pointer_up(path: String, position: Vector2, timestamp_msec: int)
signal pointer_cancel(path: String)

const Entry := preload("res://src/ProjectLibrary/ProjectLibraryEntry.gd")
const DRAG_CANCEL_DISTANCE := 12.0
const STATUS_NORMAL_COLOR := Color(0.721569, 0.733333, 0.756863, 1.0)
const STATUS_ERROR_COLOR := Color(1.0, 0.45, 0.42, 1.0)

var entry: ProjectLibraryEntry
var thumbnail_loaded := false
var selected := false
var interaction_enabled := true
var _pointer_active := false
var _pointer_origin := Vector2.ZERO

@onready var visual_root := %VisualRoot as Control
@onready var thumbnail_frame := %ThumbnailFrame as Control
@onready var thumbnail_rect := %Thumbnail as TextureRect
@onready var thumbnail_status := %ThumbnailStatus as Label
@onready var size_label := %CanvasSize as Label
@onready var modified_label := %ModifiedTime as Label
@onready var selection_outline := %SelectionOutline as Panel
@onready var selection_check := %SelectionCheck as Label


func bind(project_entry: ProjectLibraryEntry) -> void:
	entry = project_entry
	thumbnail_loaded = false
	thumbnail_rect.texture = null
	set_selected(false)
	if entry.health_state == Entry.HealthState.CORRUPTED:
		_set_thumbnail_status(tr("Corrupted"), true)
		size_label.text = tr("Unreadable project")
		modified_label.text = _format_modified_time(entry.modified_time)
		thumbnail_loaded = true
		return
	_set_thumbnail_status(tr("Loading preview…"), false)
	size_label.text = "%d × %d px" % [entry.canvas_size.x, entry.canvas_size.y]
	modified_label.text = _format_modified_time(entry.modified_time)


func set_card_width(card_width: float) -> void:
	var width := maxf(card_width, 1.0)
	var thumbnail_width := maxf(width - 16.0, 1.0)
	custom_minimum_size = Vector2(width, width + 54.0)
	thumbnail_frame.custom_minimum_size = Vector2(thumbnail_width, thumbnail_width)


func set_thumbnail(image: Image) -> void:
	thumbnail_loaded = true
	if image == null or image.is_empty():
		thumbnail_rect.texture = null
		_set_thumbnail_status(tr("Preview unavailable"), true)
		return
	thumbnail_rect.texture = ImageTexture.create_from_image(image)
	thumbnail_status.visible = false


func set_interaction_enabled(value: bool) -> void:
	interaction_enabled = value
	if not value:
		_pointer_active = false


func prepare_reflow(old_rect: Rect2) -> void:
	if not is_instance_valid(visual_root):
		return
	var new_rect := get_global_rect()
	if new_rect.size.x <= 0.0 or new_rect.size.y <= 0.0:
		return
	visual_root.position = old_rect.position - new_rect.position
	visual_root.scale = Vector2(
		maxf(old_rect.size.x / new_rect.size.x, 0.01),
		maxf(old_rect.size.y / new_rect.size.y, 0.01)
	)


func play_reflow(duration: float) -> void:
	if not is_instance_valid(visual_root):
		return
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual_root, "position", Vector2.ZERO, duration)
	tween.tween_property(visual_root, "scale", Vector2.ONE, duration)


func reset_visual_transform() -> void:
	if not is_instance_valid(visual_root):
		return
	visual_root.position = Vector2.ZERO
	visual_root.scale = Vector2.ONE


func set_selected(value: bool) -> void:
	selected = value
	if is_instance_valid(selection_outline):
		selection_outline.visible = value
	if is_instance_valid(selection_check):
		selection_check.visible = value


func _gui_input(event: InputEvent) -> void:
	if entry == null or not interaction_enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_pointer(touch.position)
		else:
			_finish_pointer(touch.position)
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_maybe_cancel_pointer(drag.position)
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
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


func _begin_pointer(local_position: Vector2) -> void:
	_pointer_active = true
	_pointer_origin = local_position
	pointer_down.emit(entry.path, _to_global_position(local_position), Time.get_ticks_msec())


func _finish_pointer(local_position: Vector2) -> void:
	if not _pointer_active:
		return
	_pointer_active = false
	pointer_up.emit(entry.path, _to_global_position(local_position), Time.get_ticks_msec())


func _maybe_cancel_pointer(local_position: Vector2) -> void:
	if not _pointer_active or local_position.distance_to(_pointer_origin) <= DRAG_CANCEL_DISTANCE:
		return
	_pointer_active = false
	pointer_cancel.emit(entry.path)


func _to_global_position(local_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * local_position


func _set_thumbnail_status(message: String, is_error: bool) -> void:
	thumbnail_status.text = message
	thumbnail_status.visible = true
	thumbnail_status.add_theme_color_override(
		"font_color", STATUS_ERROR_COLOR if is_error else STATUS_NORMAL_COLOR
	)


func _format_modified_time(unix_time: int) -> String:
	if unix_time <= 0:
		return tr("Unknown date")
	var time_zone := Time.get_time_zone_from_system()
	var local_unix_time := unix_time + int(time_zone.get("bias", 0)) * 60
	var value := Time.get_datetime_dict_from_unix_time(local_unix_time)
	return (
		"%04d-%02d-%02d  %02d:%02d"
		% [
			int(value.get("year", 0)),
			int(value.get("month", 0)),
			int(value.get("day", 0)),
			int(value.get("hour", 0)),
			int(value.get("minute", 0)),
		]
	)
