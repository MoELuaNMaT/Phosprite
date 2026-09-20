class_name ProjectSaveCoordinator
extends Node

const StoragePolicy := preload("res://src/PlatformServices/StoragePolicy.gd")
const ProjectIdentityScript := preload("res://src/ProjectLibrary/ProjectIdentity.gd")
const RecoveryStore := preload("res://src/ProjectLibrary/ProjectRecoveryStore.gd")

const IDLE_SAVE_DELAY_MSEC := 2000
const MAX_DIRTY_AGE_MSEC := 30000

var managed_storage_enabled := false
var projects_directory := StoragePolicy.PROJECTS_DIRECTORY
var last_error: Error = OK

var _states: Dictionary = {}


func configure(
	enabled: bool, directory := StoragePolicy.PROJECTS_DIRECTORY
) -> void:
	managed_storage_enabled = enabled
	projects_directory = directory
	set_process(enabled)


func _ready() -> void:
	if not Global.project_data_changed.is_connected(_on_project_data_changed):
		Global.project_data_changed.connect(_on_project_data_changed)
	set_process(managed_storage_enabled)


func _exit_tree() -> void:
	if Global.project_data_changed.is_connected(_on_project_data_changed):
		Global.project_data_changed.disconnect(_on_project_data_changed)


func _process(_delta: float) -> void:
	if not managed_storage_enabled:
		return
	var now_msec := Time.get_ticks_msec()
	for project: Project in Global.projects:
		if not project.has_changed:
			_reset_dirty_window(project)
			continue
		if _is_save_due(project, now_msec):
			flush_project(project, "autosave")


func mark_project_dirty(project: Project, now_msec := -1) -> void:
	if project == null or not managed_storage_enabled:
		return
	var timestamp := Time.get_ticks_msec() if now_msec < 0 else now_msec
	var state := _state_for(project)
	state["generation"] = int(state["generation"]) + 1
	if int(state["first_dirty_msec"]) < 0:
		state["first_dirty_msec"] = timestamp
	state["last_dirty_msec"] = timestamp


func is_save_due(project: Project, now_msec := -1) -> bool:
	if project == null or not managed_storage_enabled or not project.has_changed:
		return false
	var state := _state_for(project)
	if bool(state["saving"]):
		return false
	var first_dirty := int(state["first_dirty_msec"])
	var last_dirty := int(state["last_dirty_msec"])
	if first_dirty < 0 or last_dirty < 0:
		return false
	var timestamp := Time.get_ticks_msec() if now_msec < 0 else now_msec
	return (
		timestamp - last_dirty >= IDLE_SAVE_DELAY_MSEC
		or timestamp - first_dirty >= MAX_DIRTY_AGE_MSEC
	)


func flush_project(project: Project, reason := "forced") -> bool:
	if project == null or not managed_storage_enabled:
		return true
	if not project.has_changed:
		_reset_dirty_window(project)
		return true
	if not ProjectIdentityScript.is_valid_uuid(project.project_uuid):
		project.project_uuid = ProjectIdentityScript.generate_uuid()
	if not ProjectIdentityScript.is_valid_uuid(project.project_uuid):
		return _fail_save(project, reason, ERR_CANT_CREATE)

	var state := _state_for(project)
	if int(state["first_dirty_msec"]) < 0:
		mark_project_dirty(project)
		state = _state_for(project)
	if bool(state["saving"]):
		return false

	var directory_error := _ensure_projects_directory()
	if directory_error != OK:
		return _fail_save(project, reason, directory_error)
	var recovery_error := RecoveryStore.ensure_directory()
	if recovery_error != OK:
		return _fail_save(project, reason, recovery_error)

	var target_path := _target_path(project)
	if target_path.is_empty():
		return _fail_save(project, reason, ERR_INVALID_PARAMETER)
	var staged_path := RecoveryStore.staging_path(project.project_uuid)
	if staged_path.is_empty():
		return _fail_save(project, reason, ERR_INVALID_PARAMETER)

	RecoveryStore.remove_staging(project.project_uuid)
	state["saving"] = true
	var start_generation := int(state["generation"])
	var snapshot_saved := OpenSave.save_pxo_file(staged_path, true, false, project, true)
	if not snapshot_saved:
		state["saving"] = false
		RecoveryStore.remove_staging(project.project_uuid)
		return _fail_save(project, reason, ERR_CANT_CREATE)
	if not RecoveryStore.validate_snapshot(staged_path, project.project_uuid):
		state["saving"] = false
		RecoveryStore.remove_staging(project.project_uuid)
		return _fail_save(project, reason, ERR_FILE_CORRUPT)

	var install_error := RecoveryStore.install_staging(project.project_uuid)
	if install_error != OK:
		state["saving"] = false
		RecoveryStore.remove_staging(project.project_uuid)
		return _fail_save(project, reason, install_error)

	var commit_error := RecoveryStore.commit_to_project(project.project_uuid, target_path)
	if commit_error != OK:
		state["saving"] = false
		return _fail_save(project, reason, commit_error)

	var generation_is_current := int(state["generation"]) == start_generation
	OpenSave.finalize_project_save(target_path, project, false, generation_is_current)
	state["saving"] = false
	state["error_reported"] = false
	last_error = OK
	if generation_is_current:
		_reset_dirty_window(project)
		return true
	var last_dirty := int(state["last_dirty_msec"])
	state["first_dirty_msec"] = Time.get_ticks_msec() if last_dirty < 0 else last_dirty
	return reason == "autosave"


func flush_all(reason := "forced") -> bool:
	if not managed_storage_enabled:
		return true
	var success := true
	for project: Project in Global.projects:
		if project.has_changed and not flush_project(project, reason):
			success = false
	return success


func flush_before_leaving_editor() -> bool:
	return flush_all("leave_editor")


func can_switch_project(current_project: Project, _next_project: Project) -> bool:
	if not managed_storage_enabled:
		return true
	return flush_project(current_project, "switch_project")


func _on_project_data_changed(project: Project) -> void:
	mark_project_dirty(project)


func _is_save_due(project: Project, now_msec: int) -> bool:
	return is_save_due(project, now_msec)


func _state_for(project: Project) -> Dictionary:
	var key := project.project_uuid
	if not _states.has(key):
		_states[key] = {
			"generation": 0,
			"first_dirty_msec": -1,
			"last_dirty_msec": -1,
			"saving": false,
			"error_reported": false,
		}
	return _states[key] as Dictionary


func _reset_dirty_window(project: Project) -> void:
	if project == null or not _states.has(project.project_uuid):
		return
	var state := _states[project.project_uuid] as Dictionary
	state["first_dirty_msec"] = -1
	state["last_dirty_msec"] = -1


func _ensure_projects_directory() -> Error:
	if DirAccess.dir_exists_absolute(projects_directory):
		return OK
	return DirAccess.make_dir_recursive_absolute(projects_directory)


func _target_path(project: Project) -> String:
	if not project.save_path.is_empty():
		return project.save_path
	var base_name := project.name.validate_filename()
	if base_name.ends_with(StoragePolicy.PROJECT_EXTENSION):
		base_name = base_name.trim_suffix(StoragePolicy.PROJECT_EXTENSION)
	if base_name.is_empty():
		base_name = StoragePolicy.FALLBACK_NAME
	var path := projects_directory.path_join(base_name + StoragePolicy.PROJECT_EXTENSION)
	var index := 2
	while FileAccess.file_exists(path):
		path = projects_directory.path_join(
			"%s_%d%s" % [base_name, index, StoragePolicy.PROJECT_EXTENSION]
		)
		index += 1
	return path


func _fail_save(project: Project, reason: String, error: Error) -> bool:
	last_error = error
	var state := _state_for(project)
	state["saving"] = false
	var now_msec := Time.get_ticks_msec()
	state["first_dirty_msec"] = now_msec
	state["last_dirty_msec"] = now_msec
	if not bool(state["error_reported"]):
		state["error_reported"] = true
		Global.popup_error(
			(
				tr("Could not save project %s before %s. Error code %s (%s)")
				% [project.name, reason, error, error_string(error)]
			)
		)
	return false
