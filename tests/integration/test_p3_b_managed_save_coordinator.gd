extends "res://tests/test_base.gd"

const Coordinator := preload("res://src/ProjectLibrary/ProjectSaveCoordinator.gd")
const Identity := preload("res://src/ProjectLibrary/ProjectIdentity.gd")
const Library := preload("res://src/ProjectLibrary/ProjectLibrary.gd")
const RecoveryStore := preload("res://src/ProjectLibrary/ProjectRecoveryStore.gd")

const TEST_PROJECTS_DIR := "user://p3_b_managed_save_tests"
const FORMAL_PATH := TEST_PROJECTS_DIR.path_join("managed.pxo")
const MISSING_DIR := "user://p3_b_missing_commit_parent"
const MISSING_TARGET := MISSING_DIR.path_join("managed.pxo")

var _project: Project
var _coordinator: ProjectSaveCoordinator
var _original_name := ""
var _original_path := ""
var _original_uuid := ""
var _original_changed := false
var _test_uuid := ""


func teardown() -> void:
	if is_instance_valid(_coordinator):
		var parent := _coordinator.get_parent()
		if is_instance_valid(parent):
			parent.remove_child(_coordinator)
		_coordinator.free()
	if _project != null:
		_project.name = _original_name
		_project.save_path = _original_path
		_project.project_uuid = _original_uuid
		_project.has_changed = _original_changed
	if not _test_uuid.is_empty():
		RecoveryStore.remove_staging(_test_uuid)
		RecoveryStore.discard(_test_uuid)
	_remove_tree(TEST_PROJECTS_DIR)
	_remove_tree(MISSING_DIR)


func test_managed_save_timing_generation_recovery_and_restore() -> void:
	var main := tree.current_scene
	check_true(main != null, "runner must load Main before the P3-B integration test")
	if main == null:
		return
	_project = Global.current_project
	check_true(_project != null, "P3-B integration requires the live editor project")
	if _project == null:
		return

	_original_name = _project.name
	_original_path = _project.save_path
	_original_uuid = _project.project_uuid
	_original_changed = _project.has_changed
	_test_uuid = Identity.generate_uuid()
	check_true(Identity.is_valid_uuid(_test_uuid), "test project must receive a valid UUID")
	if not Identity.is_valid_uuid(_test_uuid):
		return

	_remove_tree(TEST_PROJECTS_DIR)
	_remove_tree(MISSING_DIR)
	DirAccess.make_dir_recursive_absolute(TEST_PROJECTS_DIR)
	RecoveryStore.remove_staging(_test_uuid)
	RecoveryStore.discard(_test_uuid)

	_project.name = "p3_b_managed"
	_project.project_uuid = _test_uuid
	_project.save_path = FORMAL_PATH
	_project.has_changed = true

	_coordinator = Coordinator.new()
	_coordinator.configure(true, TEST_PROJECTS_DIR, false)
	_coordinator.mark_project_dirty(_project, 0)
	check_true(
		not _coordinator.is_save_due(_project, 1999),
		"dirty project must not autosave before the two-second idle debounce",
	)
	check_true(
		_coordinator.is_save_due(_project, 2000),
		"dirty project must autosave at the two-second idle boundary",
	)

	_coordinator.call("_reset_dirty_window", _project)
	_coordinator.mark_project_dirty(_project, 0)
	for timestamp in range(1000, 30000, 1000):
		_coordinator.mark_project_dirty(_project, timestamp)
	check_true(
		not _coordinator.is_save_due(_project, 29999),
		"continuous edits must not save before the thirty-second maximum age",
	)
	check_true(
		_coordinator.is_save_due(_project, 30000),
		"continuous edits must force a save at thirty seconds",
	)

	main.add_child(_coordinator)
	var injected_dirty := [false]
	var mutate_during_serialize := func(_data: Dictionary):
		if not injected_dirty[0]:
			injected_dirty[0] = true
			_project.has_changed = true
	_project.serialized.connect(mutate_during_serialize)

	check_true(
		_coordinator.flush_project(_project, "autosave"),
		"ordinary autosave may commit one generation while a newer generation remains dirty",
	)
	check_file_exists(FORMAL_PATH, "autosave must atomically create the formal managed PXO")
	check_true(
		RecoveryStore.validate_snapshot(FORMAL_PATH, _test_uuid),
		"formal managed PXO must validate after the transaction commits",
	)
	check_true(
		_project.has_changed,
		"a generation created during serialization must remain dirty after the older save completes",
	)
	check_true(
		not RecoveryStore.has_pending_recovery(_test_uuid),
		"successful formal replacement must consume the transaction recovery slot",
	)

	if _project.serialized.is_connected(mutate_during_serialize):
		_project.serialized.disconnect(mutate_during_serialize)
	check_true(
		_coordinator.flush_project(_project, "forced"),
		"a forced flush should save the remaining dirty generation",
	)
	check_true(
		not _project.has_changed,
		"a stable forced flush must clear project dirty state",
	)

	_project.save_path = MISSING_TARGET
	_project.has_changed = true
	check_true(
		not _coordinator.flush_project(_project, "leave_editor"),
		"a failed formal commit must block leaving the editor",
	)
	check_true(
		_project.has_changed,
		"failed commit must preserve dirty state",
	)
	check_true(
		RecoveryStore.has_pending_recovery(_test_uuid),
		"failed formal replacement must preserve the validated recovery candidate",
	)
	check_true(
		RecoveryStore.validate_snapshot(RecoveryStore.recovery_path(_test_uuid), _test_uuid),
		"preserved recovery must itself remain a valid PXO",
	)

	var entries := Library.new(TEST_PROJECTS_DIR).scan()
	check_eq(entries.size(), 1, "formal managed project should remain visible after a failed newer commit")
	if entries.size() == 1:
		check_true(
			entries[0].has_pending_recovery,
			"Project Library must expose the pending recovery for the matching UUID",
		)

	check_eq(
		RecoveryStore.restore_to_project(_test_uuid, FORMAL_PATH),
		OK,
		"the preserved recovery should restore over the matching formal project",
	)
	check_true(
		not RecoveryStore.has_pending_recovery(_test_uuid),
		"successful explicit restore must consume the recovery slot",
	)
	check_true(
		RecoveryStore.validate_snapshot(FORMAL_PATH, _test_uuid),
		"restored formal file must validate with the same stable project identity",
	)
	_project.save_path = FORMAL_PATH
	OpenSave.finalize_project_save(FORMAL_PATH, _project, false, true)
	check_true(
		not _project.has_changed,
		"successful recovery finalization should return the live Project to clean state",
	)


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for directory in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(directory))
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
