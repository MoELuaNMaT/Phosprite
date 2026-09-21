class_name ProjectLibrary
extends RefCounted

const StoragePolicy := preload("res://src/PlatformServices/StoragePolicy.gd")
const ProjectIdentityScript := preload("res://src/ProjectLibrary/ProjectIdentity.gd")
const Entry := preload("res://src/ProjectLibrary/ProjectLibraryEntry.gd")
const RecoveryStore := preload("res://src/ProjectLibrary/ProjectRecoveryStore.gd")

const GALLERY_SCHEMA := 1
const GALLERY_ENTRY := "gallery.json"
const DATA_ENTRY := "data.json"
const PREVIEW_ENTRY := "preview.png"

var projects_directory := StoragePolicy.PROJECTS_DIRECTORY


func _init(directory := StoragePolicy.PROJECTS_DIRECTORY) -> void:
	projects_directory = directory


## Returns the current managed-project library without instantiating Project objects.
## Only ZIP metadata, preview.png and filesystem timestamps are read on the healthy fast path.
func scan(include_thumbnails := true) -> Array[ProjectLibraryEntry]:
	var entries: Array[ProjectLibraryEntry] = []
	if not DirAccess.dir_exists_absolute(projects_directory):
		var dir_error := DirAccess.make_dir_recursive_absolute(projects_directory)
		if dir_error != OK:
			return entries

	var file_names := DirAccess.get_files_at(projects_directory)
	for file_name in file_names:
		if file_name.get_extension().to_lower() != StoragePolicy.PROJECT_EXTENSION.trim_prefix("."):
			continue
		entries.append(_read_entry(projects_directory.path_join(file_name), include_thumbnails))

	_repair_duplicate_uuids(entries)
	for entry: ProjectLibraryEntry in entries:
		entry.has_pending_recovery = (
			entry.health_state == ProjectLibraryEntry.HealthState.OK
			and RecoveryStore.has_pending_recovery(entry.uuid)
		)
	entries.sort_custom(_sort_newest_first)
	return entries


static func build_gallery_metadata(project_uuid: String, canvas_size: Vector2i) -> Dictionary:
	return {
		"schema": GALLERY_SCHEMA,
		"project_uuid": project_uuid,
		"size_x": canvas_size.x,
		"size_y": canvas_size.y,
	}


func load_thumbnail(entry: ProjectLibraryEntry) -> Image:
	if entry == null or entry.health_state != ProjectLibraryEntry.HealthState.OK:
		return null
	if entry.thumbnail != null:
		return entry.thumbnail
	var reader := ZIPReader.new()
	if reader.open(entry.path) != OK:
		return null
	if not reader.file_exists(PREVIEW_ENTRY):
		reader.close()
		return null
	var image := Image.new()
	var error := image.load_png_from_buffer(reader.read_file(PREVIEW_ENTRY))
	reader.close()
	if error != OK:
		return null
	entry.thumbnail = image
	return image


func _read_entry(path: String, include_thumbnail := true) -> ProjectLibraryEntry:
	var entry := Entry.new(path)
	entry.modified_time = FileAccess.get_modified_time(path)

	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		entry.health_state = ProjectLibraryEntry.HealthState.CORRUPTED
		return entry
	if not reader.file_exists(DATA_ENTRY):
		reader.close()
		entry.health_state = ProjectLibraryEntry.HealthState.CORRUPTED
		return entry

	var metadata := _read_gallery_metadata(reader)
	if metadata.is_empty():
		metadata = _read_legacy_metadata(reader)
	if metadata.is_empty():
		reader.close()
		entry.health_state = ProjectLibraryEntry.HealthState.CORRUPTED
		return entry

	entry.uuid = metadata["project_uuid"]
	entry.canvas_size = Vector2i(metadata["size_x"], metadata["size_y"])
	if include_thumbnail and reader.file_exists(PREVIEW_ENTRY):
		var image := Image.new()
		if image.load_png_from_buffer(reader.read_file(PREVIEW_ENTRY)) == OK:
			entry.thumbnail = image
	reader.close()
	return entry


func _read_gallery_metadata(reader: ZIPReader) -> Dictionary:
	if not reader.file_exists(GALLERY_ENTRY):
		return {}
	var value: Variant = _parse_json(reader.read_file(GALLERY_ENTRY))
	if not value is Dictionary:
		return {}
	var gallery := value as Dictionary
	if int(gallery.get("schema", 0)) != GALLERY_SCHEMA:
		return {}
	var project_uuid := str(gallery.get("project_uuid", ""))
	if not ProjectIdentityScript.is_valid_uuid(project_uuid):
		return {}
	var size_x := int(gallery.get("size_x", 0))
	var size_y := int(gallery.get("size_y", 0))
	if size_x <= 0 or size_y <= 0:
		return {}
	return build_gallery_metadata(project_uuid, Vector2i(size_x, size_y))


func _read_legacy_metadata(reader: ZIPReader) -> Dictionary:
	var value: Variant = _parse_json(reader.read_file(DATA_ENTRY))
	if not value is Dictionary:
		return {}
	var data := value as Dictionary
	var size_x := int(data.get("size_x", 0))
	var size_y := int(data.get("size_y", 0))
	if size_x <= 0 or size_y <= 0:
		return {}
	var project_uuid := str(data.get("project_uuid", ""))
	if not ProjectIdentityScript.is_valid_uuid(project_uuid):
		project_uuid = ProjectIdentityScript.generate_uuid()
	if project_uuid.is_empty():
		return {}
	return build_gallery_metadata(project_uuid, Vector2i(size_x, size_y))


func _repair_duplicate_uuids(entries: Array[ProjectLibraryEntry]) -> void:
	var groups: Dictionary = {}
	for entry in entries:
		if entry.health_state != ProjectLibraryEntry.HealthState.OK or entry.uuid.is_empty():
			continue
		if not groups.has(entry.uuid):
			groups[entry.uuid] = []
		(groups[entry.uuid] as Array).append(entry)

	var reserved_uuids: Dictionary = {}
	for uuid in groups:
		reserved_uuids[uuid] = true
	for uuid in groups:
		var duplicates := groups[uuid] as Array
		if duplicates.size() < 2:
			continue
		duplicates.sort_custom(
			func(a: ProjectLibraryEntry, b: ProjectLibraryEntry):
				return _normalized_path(a.path) < _normalized_path(b.path)
		)
		for index in range(1, duplicates.size()):
			var entry := duplicates[index] as ProjectLibraryEntry
			var replacement_uuid := _unique_uuid(reserved_uuids)
			if replacement_uuid.is_empty():
				entry.health_state = ProjectLibraryEntry.HealthState.CORRUPTED
				entry.uuid = ""
				continue
			if not _rewrite_project_identity(entry.path, replacement_uuid, entry.canvas_size):
				entry.health_state = ProjectLibraryEntry.HealthState.CORRUPTED
				entry.uuid = ""
				continue
			entry.uuid = replacement_uuid
			entry.modified_time = FileAccess.get_modified_time(entry.path)
			reserved_uuids[replacement_uuid] = true


func _rewrite_project_identity(path: String, project_uuid: String, canvas_size: Vector2i) -> bool:
	var reader := ZIPReader.new()
	if reader.open(path) != OK or not reader.file_exists(DATA_ENTRY):
		return false
	var data_value: Variant = _parse_json(reader.read_file(DATA_ENTRY))
	if not data_value is Dictionary:
		reader.close()
		return false
	var data := data_value as Dictionary
	data["project_uuid"] = project_uuid

	var temp_path := path + ".p3_uuid_tmp"
	_remove_if_present(temp_path)

	var packer := ZIPPacker.new()
	if packer.open(temp_path) != OK:
		reader.close()
		return false

	var write_ok := true
	for file_path in reader.get_files():
		if file_path.ends_with("/") or file_path == GALLERY_ENTRY:
			continue
		var bytes := reader.read_file(file_path)
		if file_path == DATA_ENTRY:
			bytes = JSON.stringify(data).to_utf8_buffer()
		packer.compression_level = reader.get_compression_level(file_path)
		if packer.start_file(file_path) != OK:
			write_ok = false
			break
		if packer.write_file(bytes) != OK or packer.close_file() != OK:
			write_ok = false
			break

	if write_ok:
		var gallery_bytes := (
			JSON.stringify(build_gallery_metadata(project_uuid, canvas_size)).to_utf8_buffer()
		)
		packer.compression_level = ZIPPacker.COMPRESSION_DEFAULT
		if packer.start_file(GALLERY_ENTRY) != OK:
			write_ok = false
		elif packer.write_file(gallery_bytes) != OK or packer.close_file() != OK:
			write_ok = false

	packer.close()
	reader.close()
	if not write_ok:
		_remove_if_present(temp_path)
		return false

	if DirAccess.rename_absolute(temp_path, path) != OK:
		_remove_if_present(temp_path)
		return false
	return true


func _unique_uuid(reserved_uuids: Dictionary) -> String:
	for _attempt in 16:
		var project_uuid := ProjectIdentityScript.generate_uuid()
		if not project_uuid.is_empty() and not reserved_uuids.has(project_uuid):
			return project_uuid
	return ""


func _parse_json(bytes: PackedByteArray) -> Variant:
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK:
		return null
	return parser.data


func _sort_newest_first(a: ProjectLibraryEntry, b: ProjectLibraryEntry) -> bool:
	if a.modified_time != b.modified_time:
		return a.modified_time > b.modified_time
	return _normalized_path(a.path) < _normalized_path(b.path)


func _normalized_path(path: String) -> String:
	return ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()


func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
