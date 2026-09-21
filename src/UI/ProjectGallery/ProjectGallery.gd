class_name ProjectGallery
extends Control

signal project_open_requested(path: String)
signal new_project_requested
signal import_requested
signal exit_multiselect_requested

const StoragePolicy := preload("res://src/PlatformServices/StoragePolicy.gd")
const ProjectLibraryScript := preload("res://src/ProjectLibrary/ProjectLibrary.gd")
const CARD_SCENE := preload("res://src/UI/ProjectGallery/ProjectGalleryCard.tscn")

const LANDSCAPE_COLUMNS := 6
const PORTRAIT_COLUMNS := 4
const GRID_SIDE_MARGIN := 32.0
const GRID_SEPARATION := 16.0
const THUMBNAIL_PRELOAD_MARGIN := 96.0

var library: ProjectLibrary
var entries: Array[ProjectLibraryEntry] = []
var refresh_count := 0
var scroll_reset_count := 0
var multiselect_mode := false

var _cards: Array[ProjectGalleryCard] = []

@onready var scroll_container := %ProjectScroll as ScrollContainer
@onready var grid := %ProjectGrid as GridContainer
@onready var empty_state := %EmptyState as Label
@onready var exit_multiselect_button := %ExitMultiSelect as Button


func _ready() -> void:
	if library == null:
		library = ProjectLibraryScript.new(StoragePolicy.PROJECTS_DIRECTORY)
	if not resized.is_connected(_on_gallery_resized):
		resized.connect(_on_gallery_resized)
	var vertical_scroll := scroll_container.get_v_scroll_bar()
	if not vertical_scroll.value_changed.is_connected(_on_scroll_changed):
		vertical_scroll.value_changed.connect(_on_scroll_changed)
	call_deferred("_update_layout")


func configure(directory := StoragePolicy.PROJECTS_DIRECTORY) -> void:
	library = ProjectLibraryScript.new(directory)


func refresh() -> Array[ProjectLibraryEntry]:
	if library == null:
		library = ProjectLibraryScript.new(StoragePolicy.PROJECTS_DIRECTORY)
	entries = library.scan(false)
	refresh_count += 1
	_rebuild_cards()
	return entries


func reset_scroll_position() -> void:
	scroll_container.scroll_horizontal = 0
	scroll_container.scroll_vertical = 0
	scroll_reset_count += 1
	call_deferred("_load_visible_thumbnails")


func find_entry(path: String) -> ProjectLibraryEntry:
	var normalized := _normalized_path(path)
	for entry: ProjectLibraryEntry in entries:
		if _normalized_path(entry.path) == normalized:
			return entry
	return null


func request_open(path: String) -> void:
	project_open_requested.emit(path)


func set_multiselect_mode(enabled: bool) -> void:
	multiselect_mode = enabled
	exit_multiselect_button.visible = enabled


func _rebuild_cards() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	_cards.clear()

	for entry: ProjectLibraryEntry in entries:
		var card := CARD_SCENE.instantiate() as ProjectGalleryCard
		if card == null:
			continue
		grid.add_child(card)
		card.bind(entry)
		card.open_requested.connect(_on_card_open_requested)
		_cards.append(card)

	empty_state.visible = entries.is_empty()
	call_deferred("_update_layout")
	call_deferred("_load_visible_thumbnails")


func _update_layout() -> void:
	if not is_instance_valid(grid) or not is_instance_valid(scroll_container):
		return
	var columns := LANDSCAPE_COLUMNS if size.x >= size.y else PORTRAIT_COLUMNS
	grid.columns = columns
	var available_width := maxf(scroll_container.size.x - GRID_SIDE_MARGIN * 2.0, 1.0)
	var separators := GRID_SEPARATION * float(columns - 1)
	var card_width := maxf(floorf((available_width - separators) / float(columns)), 72.0)
	for card: ProjectGalleryCard in _cards:
		card.set_card_width(card_width)
	call_deferred("_load_visible_thumbnails")


func _load_visible_thumbnails() -> void:
	if not visible or library == null or not is_instance_valid(scroll_container):
		return
	var visible_rect := scroll_container.get_global_rect().grow(THUMBNAIL_PRELOAD_MARGIN)
	for card: ProjectGalleryCard in _cards:
		if card.thumbnail_loaded or card.entry == null:
			continue
		if not visible_rect.intersects(card.get_global_rect()):
			continue
		card.set_thumbnail(library.load_thumbnail(card.entry))


func _on_gallery_resized() -> void:
	call_deferred("_update_layout")


func _on_scroll_changed(_value: float) -> void:
	call_deferred("_load_visible_thumbnails")


func _on_card_open_requested(path: String) -> void:
	project_open_requested.emit(path)


func _on_new_project_pressed() -> void:
	new_project_requested.emit()


func _on_import_pressed() -> void:
	import_requested.emit()


func _on_exit_multiselect_pressed() -> void:
	set_multiselect_mode(false)
	exit_multiselect_requested.emit()


func _normalized_path(path: String) -> String:
	return ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()
