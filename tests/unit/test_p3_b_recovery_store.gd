extends "res://tests/test_base.gd"

const RecoveryStore := preload("res://src/ProjectLibrary/ProjectRecoveryStore.gd")
const Coordinator := preload("res://src/ProjectLibrary/ProjectSaveCoordinator.gd")
const Library := preload("res://src/ProjectLibrary/ProjectLibrary.gd")

const TEST_UUID := "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"
const TEST_TARGET_DIR := "user://p3_b_recovery_store_tests"
const TEST_TARGET := TEST_TARGET_DIR.path_join("restored.pxo")
const MISSING_TARGET := "user://p3_b_missing_parent/restored.pxo"


func teardown() -> void:
	_remove_tree(TEST_TARGET_DIR)
	_remove_tree("user://p3_b_missing_parent")
	RecoveryStore.remove_staging(TEST_UUID)
	RecoveryStore.discard(TEST_UUID)


func test_recovery_staging_must_validate_before_install() -> void:
	_reset_paths()
	var staged := RecoveryStore.staging_path(TEST_UUID)
	check_true(
		_write_snapshot(staged, TEST_UUID),
		"a valid recovery staging PXO should be writable",
	)
	check_true(
		RecoveryStore.validate_snapshot(staged, TEST_UUID),
		"staging validation must confirm ZIP/data.json and project UUID",
	)
	check_eq(
		RecoveryStore.install_staging(TEST_UUID),
		OK,
		"a validated staging file should install into the single recovery slot",
	)
	check_true(
		RecoveryStore.has_pending_recovery(TEST_UUID),
		"installed recovery should be discoverable by project UUID",
	)
	check_true(
		not FileAccess.file_exists(staged),
		"installing recovery should consume the staging file",
	)


func test_failed_restore_keeps_recovery_until_success_or_discard() -> void:
	_reset_paths()
	var staged := RecoveryStore.staging_path(TEST_UUID)
	check_true(_write_snapshot(staged, TEST_UUID), "recovery fixture should be writable")
	check_eq(RecoveryStore.install_staging(TEST_UUID), OK, "recovery fixture should install")

	var failed := RecoveryStore.restore_to_project(TEST_UUID, MISSING_TARGET)
	check_ne(failed, OK, "restore into a missing parent directory must fail")
	check_true(
		RecoveryStore.has_pending_recovery(TEST_UUID),
		"failed restore must preserve the recovery candidate",
	)

	DirAccess.make_dir_recursive_absolute(TEST_TARGET_DIR)
	check_eq(
		RecoveryStore.restore_to_project(TEST_UUID, TEST_TARGET),
		OK,
		"restore into a valid project location should succeed",
	)
	check_file_exists(TEST_TARGET, "successful restore should replace the formal PXO")
	check_true(
		not RecoveryStore.has_pending_recovery(TEST_UUID),
		"successful restore must consume the recovery slot",
	)
	check_true(
		RecoveryStore.validate_snapshot(TEST_TARGET, TEST_UUID),
		"restored formal PXO must retain the expected project UUID",
	)


func test_wrong_uuid_or_corrupt_snapshot_never_installs() -> void:
	_reset_paths()
	var staged := RecoveryStore.staging_path(TEST_UUID)
	check_true(
		_write_snapshot(staged, "11111111-2222-4333-8444-555555555555"),
		"mismatched fixture should be writable",
	)
	check_true(
		not RecoveryStore.validate_snapshot(staged, TEST_UUID),
		"validation must reject a recovery belonging to another project",
	)
	check_eq(
		RecoveryStore.install_staging(TEST_UUID),
		ERR_FILE_CORRUPT,
		"mismatched project identity must block recovery installation",
	)
	check_true(
		not RecoveryStore.has_pending_recovery(TEST_UUID),
		"rejected staging must never appear as a pending recovery",
	)


func test_p3_b_source_contract_keeps_timing_and_stage_boundaries() -> void:
	var coordinator_src := FileAccess.get_file_as_string(
		"res://src/ProjectLibrary/ProjectSaveCoordinator.gd"
	)
	var main_src := FileAccess.get_file_as_string("res://src/Main.gd")
	var global_src := FileAccess.get_file_as_string("res://src/Autoload/Global.gd")
	var open_save_src := FileAccess.get_file_as_string("res://src/Autoload/OpenSave.gd")
	var library_src := FileAccess.get_file_as_string(
		"res://src/ProjectLibrary/ProjectLibrary.gd"
	)

	check_has(
		coordinator_src,
		"const IDLE_SAVE_DELAY_MSEC := 2000",
		"P3-B must debounce ordinary dirty saves by two seconds",
	)
	check_has(
		coordinator_src,
		"const MAX_DIRTY_AGE_MSEC := 30000",
		"continuous edits must still force a save by thirty seconds",
	)
	check_has(
		coordinator_src,
		"RecoveryStore.install_staging(project.project_uuid)",
		"managed save must install a validated recovery candidate before commit",
	)
	check_has(
		coordinator_src,
		"RecoveryStore.commit_to_project(project.project_uuid, target_path)",
		"managed save must atomically promote recovery into the formal PXO",
	)
	check_has(
		main_src,
		'project_save_coordinator.flush_all("background")',
		"backgrounding must force a managed-project flush",
	)
	check_has(
		main_src,
		'project_save_coordinator.flush_before_leaving_editor()',
		"P3-C Home navigation must have a blocking flush gate",
	)
	check_has(
		global_src,
		"project_switch_guard.call(current_project, projects[value])",
		"project switching must be cancellable when its forced save fails",
	)
	check_has(
		open_save_src,
		"not StoragePolicy.uses_managed_project_storage()",
		"legacy session autosave must not compete with P3-B managed autosave",
	)
	check_has(
		library_src,
		"RecoveryStore.has_pending_recovery(entry.uuid)",
		"Project Library entries must expose pending per-project recovery state",
	)


func _write_snapshot(path: String, project_uuid: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var packer := ZIPPacker.new()
	if packer.open(path) != OK:
		return false
	var data := {
		"project_uuid": project_uuid,
		"size_x": 8,
		"size_y": 8,
		"layers": [],
		"frames": [],
	}
	if packer.start_file("data.json") != OK:
		packer.close()
		return false
	if packer.write_file(JSON.stringify(data).to_utf8_buffer()) != OK:
		packer.close()
		return false
	if packer.close_file() != OK:
		packer.close()
		return false
	if packer.start_file("mimetype") != OK:
		packer.close()
		return false
	if packer.write_file("application/x-pixelorama".to_utf8_buffer()) != OK:
		packer.close()
		return false
	if packer.close_file() != OK:
		packer.close()
		return false
	return packer.close() == OK


func _reset_paths() -> void:
	_remove_tree(TEST_TARGET_DIR)
	_remove_tree("user://p3_b_missing_parent")
	RecoveryStore.remove_staging(TEST_UUID)
	RecoveryStore.discard(TEST_UUID)


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for directory in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(directory))
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
