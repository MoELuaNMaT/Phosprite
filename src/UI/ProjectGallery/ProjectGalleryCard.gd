class_name ProjectGalleryCard
extends Button

signal open_requested(path: String)

const Entry := preload("res://src/ProjectLibrary/ProjectLibraryEntry.gd")

var entry: ProjectLibraryEntry
var thumbnail_loaded := false

@onready var thumbnail_frame := %ThumbnailFrame as Control
@onready var thumbnail_rect := %Thumbnail as TextureRect
@onready var thumbnail_status := %ThumbnailStatus as Label
@onready var size_label := %CanvasSize as Label
@onready var modified_label := %ModifiedTime as Label


func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func bind(project_entry: ProjectLibraryEntry) -> void:
	entry = project_entry
	thumbnail_loaded = false
	thumbnail_rect.texture = null
	if entry.health_state == Entry.HealthState.CORRUPTED:
		thumbnail_status.text = tr("Corrupted")
		thumbnail_status.visible = true
		size_label.text = tr("Unreadable project")
		modified_label.text = _format_modified_time(entry.modified_time)
		thumbnail_loaded = true
		return
	thumbnail_status.text = ""
	thumbnail_status.visible = false
	size_label.text = "%d × %d px" % [entry.canvas_size.x, entry.canvas_size.y]
	modified_label.text = _format_modified_time(entry.modified_time)


func set_card_width(card_width: float) -> void:
	var width := maxf(card_width, 1.0)
	custom_minimum_size = Vector2(width, width + 54.0)
	thumbnail_frame.custom_minimum_size = Vector2(width, width)


func set_thumbnail(image: Image) -> void:
	thumbnail_loaded = true
	if image == null or image.is_empty():
		thumbnail_rect.texture = null
		thumbnail_status.text = tr("No preview")
		thumbnail_status.visible = true
		return
	thumbnail_rect.texture = ImageTexture.create_from_image(image)
	thumbnail_status.visible = false


func _on_pressed() -> void:
	if entry != null:
		open_requested.emit(entry.path)


func _format_modified_time(unix_time: int) -> String:
	if unix_time <= 0:
		return tr("Unknown date")
	var value := Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02d  %02d:%02d" % [
		int(value.get("year", 0)),
		int(value.get("month", 0)),
		int(value.get("day", 0)),
		int(value.get("hour", 0)),
		int(value.get("minute", 0)),
	]
