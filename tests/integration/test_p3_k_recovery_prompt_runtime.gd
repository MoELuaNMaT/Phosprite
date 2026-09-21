extends "res://tests/test_base.gd"

const StoragePolicy := preload("res://src/PlatformServices/StoragePolicy.gd")
const Library := preload("res://src/ProjectLibrary/ProjectLibrary.gd")
const RecoveryStore := preload("res://src/ProjectLibrary/ProjectRecoveryStore.gd")

const TEST_ROOT := "user://p3_k_recovery_prompt_runtime"
const TEST_PATH := "user://p3_k_recovery_prompt_runtime/recovery_prompt.pxo"
const TEST_UUID := "92222222-3333-4444-8555-666666666666"

var _main: Control


func teardown() -> void:
	RecoveryStore.remove_staging(TEST_UUID)
	RecoveryStore.discard(TEST_UUID)
	_remove_tree(TEST_ROOT)
	if is_instance_valid(_main):
		_main.project_recovery_dialog.hide()
		Global.dialog_open(false)
		_main.project_gallery_root.configure(StoragePolicy.PROJECTS_DIRECTORY)
		_main.app_shell_controller.configure(
			false,
			_main.editor_root,
			_main.project_gallery_root,
			_main.project_recovery_dialog,
			_main.project_save_coordinator,
			_main.new_project_dialog,
			_main.import_source_dialog,
			_main.image_import_mode_dialog
		)


func test_recovery_prompt_survives_loss_of_transient_controller_state() -> void:
	_prepare_managed_main()
	if _main == null:
		return

	check_true(
		_write_snapshot(TEST_PATH, TEST_UUID, "formal-v1"),
		"formal recovery-prompt fixture should be writable",
	)
	var staged := RecoveryStore.staging_path(TEST_UUID)
	check_true(
		_write_snapshot(staged, TEST_UUID, "recovery-v2"),
		"recovery-prompt staging fixture should be writable",
	)
	check_eq(
		RecoveryStore.install_staging(TEST_UUID),
		OK,
		"recovery-prompt fixture should install into the persistent recovery slot",
	)

	var gallery: ProjectGallery = _main.project_gallery_root
	var shell: AppShellController = _main.app_shell_controller
	gallery.refresh()
	check_true(
		not shell.open_project_path(TEST_PATH),
		"opening a project with pending recovery must stop at the per-project prompt",
	)
	check_eq(
		shell.pending_recovery_uuid,
		TEST_UUID,
		"first prompt must bind to the matching project UUID",
	)
	check_eq(
		shell.mode,
		AppShellController.Mode.GALLERY,
		"recovery decision must leave the app in Gallery",
	)
	check_true(
		RecoveryStore.has_pending_recovery(TEST_UUID),
		"showing the prompt must not consume persistent recovery",
	)

	# Model process death while the recovery prompt is visible: transient selection
	# and dialog state disappear, but the disk recovery slot survives.
	shell.call("_clear_pending_recovery")
	_main.project_recovery_dialog.hide()
	Global.dialog_open(false)
	check_eq(
		shell.pending_recovery_uuid,
		"",
		"simulated process-memory loss must clear only transient controller state",
	)
	check_true(
		RecoveryStore.has_pending_recovery(TEST_UUID),
		"simulated death at the prompt must leave recovery data on disk",
	)

	gallery.refresh()
	var entry := gallery.find_entry(TEST_PATH)
	check_true(
		entry != null,
		"fresh Gallery scan must rediscover the formal project after simulated death",
	)
	if entry != null:
		check_true(
			entry.has_pending_recovery,
			"fresh Gallery scan must reconstruct pending recovery from disk",
		)

	check_true(
		not shell.open_project_path(TEST_PATH),
		"opening the same project after restart-style rescan must prompt again",
	)
	check_eq(
		shell.pending_recovery_uuid,
		TEST_UUID,
		"second prompt must bind to the same persistent recovery candidate",
	)
	_main.project_recovery_dialog.canceled.emit()
	check_true(
		RecoveryStore.has_pending_recovery(TEST_UUID),
		"canceling after the restart-style prompt must remain non-destructive",
	)
	check_eq(
		shell.mode,
		AppShellController.Mode.GALLERY,
		"canceling recovery must still leave the app in Gallery",
	)


func _prepare_managed_main() -> void:
	_main = tree.current_scene
	check_true(_main != null, "runner must load Main before the P3-K runtime gate")
	if _main == null:
		return
	RecoveryStore.remove_staging(TEST_UUID)
	RecoveryStore.discard(TEST_UUID)
	_remove_tree(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(TEST_ROOT)
	_main.project_save_coordinator.configure(true, TEST_ROOT, false)
	_main.project_gallery_root.configure(TEST_ROOT)
	_main.app_shell_controller.configure(
		true,
		_main.editor_root,
		_main.project_gallery_root,
		_main.project_recovery_dialog,
		_main.project_save_coordinator,
		_main.new_project_dialog,
		_main.import_source_dialog,
		_main.image_import_mode_dialog
	)
	_main.app_shell_controller.show_gallery(false, false)


func _write_snapshot(path: String, project_uuid: String, payload: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var packer := ZIPPacker.new()
	if packer.open(path) != OK:
		return false
	var data := {
		"project_uuid": project_uuid,
		"size_x": 32,
		"size_y": 24,
		"layers": [],
		"frames": [],
	}
	if not _write_entry(packer, "data.json", JSON.stringify(data).to_utf8_buffer()):
		packer.close()
		return false
	var gallery := Library.build_gallery_metadata(project_uuid, Vector2i(32, 24))
	if not _write_entry(packer, Library.GALLERY_ENTRY, JSON.stringify(gallery).to_utf8_buffer()):
		packer.close()
		return false
	if not _write_entry(packer, "payload.txt", payload.to_utf8_buffer()):
		packer.close()
		return false
	if not _write_entry(packer, "mimetype", "application/x-pixelorama".to_utf8_buffer()):
		packer.close()
		return false
	return packer.close() == OK


func _write_entry(packer: ZIPPacker, path: String, bytes: PackedByteArray) -> bool:
	if packer.start_file(path) != OK:
		return false
	if packer.write_file(bytes) != OK:
		return false
	return packer.close_file() == OK


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for directory in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(directory))
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
