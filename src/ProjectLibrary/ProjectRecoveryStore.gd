class_name ProjectRecoveryStore
extends RefCounted

const ProjectIdentityScript := preload("res://src/ProjectLibrary/ProjectIdentity.gd")

const DIRECTORY_NAME := "projects"
const RECOVERY_DIRECTORY := "user://backups/projects"
const PROJECT_EXTENSION := ".pxo"
const STAGING_SUFFIX := ".staging"
const PREVIOUS_SUFFIX := ".previous"


static func ensure_directory() -> Error:
	if DirAccess.dir_exists_absolute(RECOVERY_DIRECTORY):
		return OK
	return DirAccess.make_dir_recursive_absolute(RECOVERY_DIRECTORY)


static func recovery_path(project_uuid: String) -> String:
	if not ProjectIdentityScript.is_valid_uuid(project_uuid):
		return ""
	return RECOVERY_DIRECTORY.path_join(project_uuid + PROJECT_EXTENSION)


static func staging_path(project_uuid: String) -> String:
	var path := recovery_path(project_uuid)
	return "" if path.is_empty() else path + STAGING_SUFFIX


## The most recent verified project file is preserved outside the commit slot.
static func previous_path(project_uuid: String) -> String:
	var path := recovery_path(project_uuid)
	return "" if path.is_empty() else path + PREVIOUS_SUFFIX


static func has_pending_recovery(project_uuid: String) -> bool:
	var path := recovery_path(project_uuid)
	return not path.is_empty() and FileAccess.file_exists(path)


static func validate_snapshot(path: String, expected_uuid := "") -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		return false
	if not reader.file_exists("data.json"):
		reader.close()
		return false
	var parser := JSON.new()
	var parse_error := parser.parse(reader.read_file("data.json").get_string_from_utf8())
	if parse_error != OK or not parser.data is Dictionary:
		reader.close()
		return false
	var data := parser.data as Dictionary
	var project_uuid := str(data.get("project_uuid", ""))
	var valid := (
		ProjectIdentityScript.is_valid_uuid(project_uuid)
		and (expected_uuid.is_empty() or project_uuid == expected_uuid)
		and _validate_snapshot_contents(reader, data)
	)
	reader.close()
	return valid


## Check actual assets referenced by data.json before promoting a recovery file.
## A parseable header is insufficient: the project could have lost its cels.
static func _validate_snapshot_contents(reader: ZIPReader, data: Dictionary) -> bool:
	if not data.has("layers") or not data["layers"] is Array:
		return false
	if not data.has("frames") or not data["frames"] is Array:
		return false
	var layers := data["layers"] as Array
	var frames := data["frames"] as Array
	var width := int(data.get("size_x", 0))
	var height := int(data.get("size_y", 0))
	if width < 1 or height < 1 or layers.is_empty() or frames.is_empty():
		return false
	# Do not allocate a large array based on untrusted file dimensions.
	if width > 16384 or height > 16384 or int(width) * int(height) > 4096 * 4096:
		return false
	var format_code := int(data.get("color_mode", Image.FORMAT_RGBA8))
	if format_code == -1:
		format_code = Image.FORMAT_RGBA8
	var probe_image := Image.create_empty(1, 1, false, format_code as Image.Format)
	var bytes_per_pixel := probe_image.get_data_size()
	if bytes_per_pixel <= 0:
		return false
	var expected_bytes := width * height * bytes_per_pixel
	for frame_index in frames.size():
		var frame: Variant = frames[frame_index]
		if not frame is Dictionary or not frame.has("cels") or not frame["cels"] is Array:
			return false
		if frame["cels"].size() != layers.size():
			return false
		for layer_index in layers.size():
			var layer: Variant = layers[layer_index]
			var cel: Variant = frame["cels"][layer_index]
			if not layer is Dictionary or not cel is Dictionary:
				return false
			# The PXO deserializer reads these fields without a default.
			if not cel.has("opacity"):
				return false
			if int(layer.get("type", -1)) == 0 and not layer.has("new_cels_linked"):
				return false
			if int(layer.get("type", -1)) != 0:
				continue  # Group, tile map, audio and 3D layer payloads differ.
			var image_path := "image_data/frames/%d/layer_%d" % [frame_index + 1, layer_index + 1]
			if not reader.file_exists(image_path):
				return false
			if reader.read_file(image_path).size() != expected_bytes:
				return false
			if int(data.get("color_mode", Image.FORMAT_RGBA8)) == -1:
				var index_path := "image_data/frames/%d/indices_layer_%d" % [
					frame_index + 1, layer_index + 1
				]
				if not reader.file_exists(index_path):
					return false
				if reader.read_file(index_path).size() != width * height:
					return false
	var brushes: Variant = data.get("brushes", [])
	var references: Variant = data.get("reference_images", [])
	if not brushes is Array or not references is Array:
		return false
	for index in brushes.size():
		var brush_path := "image_data/brushes/brush_%d" % index
		if not reader.file_exists(brush_path) or reader.read_file(brush_path).is_empty():
			return false
	for index in references.size():
		var reference_path := "image_data/reference_images/reference_%d" % index
		if not reader.file_exists(reference_path):
			return false
		if reader.read_file(reference_path).is_empty():
			return false
	return true


static func install_staging(project_uuid: String) -> Error:
	var staged := staging_path(project_uuid)
	var recovery := recovery_path(project_uuid)
	if staged.is_empty() or recovery.is_empty():
		return ERR_INVALID_PARAMETER
	if not validate_snapshot(staged, project_uuid):
		return ERR_FILE_CORRUPT
	var err := DirAccess.rename_absolute(staged, recovery)
	if err != OK:
		return err
	return OK


static func commit_to_project(project_uuid: String, project_path: String) -> Error:
	var recovery := recovery_path(project_uuid)
	if recovery.is_empty() or project_path.is_empty():
		return ERR_INVALID_PARAMETER
	if not validate_snapshot(recovery, project_uuid):
		return ERR_FILE_CORRUPT
	# Retain the last verified formal file, so an apparently successful update
	# cannot be the only surviving version if a later load fails.
	if FileAccess.file_exists(project_path) and validate_snapshot(project_path, project_uuid):
		var old_version := previous_path(project_uuid)
		var copy_error := DirAccess.copy_absolute(project_path, old_version)
		if copy_error != OK:
			return copy_error
	return DirAccess.rename_absolute(recovery, project_path)


static func restore_to_project(project_uuid: String, project_path: String) -> Error:
	return commit_to_project(project_uuid, project_path)


static func discard(project_uuid: String) -> Error:
	var recovery := recovery_path(project_uuid)
	if recovery.is_empty():
		return ERR_INVALID_PARAMETER
	if FileAccess.file_exists(recovery):
		var error := DirAccess.remove_absolute(recovery)
		if error != OK:
			return error
	# Do not discard the last verified version when the user dismisses an
	# interrupted save. It can still be useful for manual recovery.
	return OK


static func remove_staging(project_uuid: String) -> void:
	var staged := staging_path(project_uuid)
	if not staged.is_empty() and FileAccess.file_exists(staged):
		DirAccess.remove_absolute(staged)
