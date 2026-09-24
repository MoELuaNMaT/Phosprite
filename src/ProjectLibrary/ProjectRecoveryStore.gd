class_name ProjectRecoveryStore
extends RefCounted

const ProjectIdentityScript := preload("res://src/ProjectLibrary/ProjectIdentity.gd")

const DIRECTORY_NAME := "projects"
const RECOVERY_DIRECTORY := "user://backups/projects"
const PROJECT_EXTENSION := ".pxo"
const STAGING_SUFFIX := ".staging"


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
	reader.close()
	if parse_error != OK or not parser.data is Dictionary:
		return false
	var data := parser.data as Dictionary
	var project_uuid := str(data.get("project_uuid", ""))
	if not ProjectIdentityScript.is_valid_uuid(project_uuid):
		return false
	if not expected_uuid.is_empty() and project_uuid != expected_uuid:
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
	return DirAccess.rename_absolute(recovery, project_path)


static func restore_to_project(project_uuid: String, project_path: String) -> Error:
	return commit_to_project(project_uuid, project_path)


static func discard(project_uuid: String) -> Error:
	var recovery := recovery_path(project_uuid)
	if recovery.is_empty():
		return ERR_INVALID_PARAMETER
	if not FileAccess.file_exists(recovery):
		return OK
	return DirAccess.remove_absolute(recovery)


static func remove_staging(project_uuid: String) -> void:
	var staged := staging_path(project_uuid)
	if not staged.is_empty() and FileAccess.file_exists(staged):
		DirAccess.remove_absolute(staged)
