class_name ProjectGallery
extends Control

signal project_open_requested(path: String)

const StoragePolicy := preload("res://src/PlatformServices/StoragePolicy.gd")
const ProjectLibraryScript := preload("res://src/ProjectLibrary/ProjectLibrary.gd")

var library: ProjectLibrary
var entries: Array[ProjectLibraryEntry] = []
var refresh_count := 0
var scroll_reset_count := 0


func _ready() -> void:
	if library == null:
		library = ProjectLibraryScript.new(StoragePolicy.PROJECTS_DIRECTORY)


func configure(directory := StoragePolicy.PROJECTS_DIRECTORY) -> void:
	library = ProjectLibraryScript.new(directory)


func refresh() -> Array[ProjectLibraryEntry]:
	if library == null:
		library = ProjectLibraryScript.new(StoragePolicy.PROJECTS_DIRECTORY)
	entries = library.scan()
	refresh_count += 1
	return entries


func reset_scroll_position() -> void:
	# P3-C owns the navigation contract. P3-D will bind this to the real ScrollContainer.
	scroll_reset_count += 1


func find_entry(path: String) -> ProjectLibraryEntry:
	var normalized := _normalized_path(path)
	for entry: ProjectLibraryEntry in entries:
		if _normalized_path(entry.path) == normalized:
			return entry
	return null


func request_open(path: String) -> void:
	project_open_requested.emit(path)


func _normalized_path(path: String) -> String:
	return ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()
