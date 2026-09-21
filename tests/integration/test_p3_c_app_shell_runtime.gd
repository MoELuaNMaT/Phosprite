extends "res://tests/test_base.gd"

const StoragePolicy := preload("res://src/PlatformServices/StoragePolicy.gd")
const Library := preload("res://src/ProjectLibrary/ProjectLibrary.gd")
const RecoveryStore := preload("res://src/ProjectLibrary/ProjectRecoveryStore.gd")

const TEST_DIRECTORY := "user://p3_c_app_shell_tests"
const TEST_PROJECT_PATH := "user://p3_c_app_shell_tests/recovery_target.pxo"
const TEST_UUID := "cccccccc-dddd-4eee-8fff-aaaaaaaaaaaa"

var _main: Control


func teardown() -> void:
	RecoveryStore.remove_staging(TEST_UUID)
	RecoveryStore.discard(TEST_UUID)
	_remove_tree(TEST_DIRECTORY)
	if is_instance_valid(_main):
		_main.project_recovery_dialog.hide()
		_main.project_gallery_root.configure(StoragePolicy.PROJECTS_DIRECTORY)
		_main.app_shell_controller.configure(
			false,
			_main.editor_root,
			_main.project_gallery_root,
			_main.project_recovery_dialog,
			_main.project_save_coordinator
		)


func test_app_shell_runtime_routes_home_and_scopes_recovery_prompt() -> void:
	_main = tree.current_scene
	check_true(_main != null, "runner must load Main before the P3-C integration test")
	if _main == null:
		return

	var shell: AppShellController = _main.app_shell_controller
	var gallery: ProjectGallery = _main.project_gallery_root
	check_true(shell != null, "Main must own the P3-C AppShellController")
	check_true(gallery != null, "Main must own the P3-C ProjectGallery shell")
	if shell == null or gallery == null:
		return

	check_eq(
		shell.mode,
		AppShellController.Mode.EDITOR,
		"desktop regression runtime must retain the existing Editor startup state",
	)
	check_true(_main.editor_root.visible, "desktop startup must keep the Editor root visible")
	check_true(not gallery.visible, "desktop startup must keep the Project Gallery hidden")

	gallery.configure(TEST_DIRECTORY)
	shell.configure(
		true,
		_main.editor_root,
		gallery,
		_main.project_recovery_dialog,
		_main.project_save_coordinator
	)
	shell.show_editor()
	var refresh_before := gallery.refresh_count
	var reset_before := gallery.scroll_reset_count
	check_true(shell.return_home(), "a clean Editor must be able to return to Gallery")
	check_eq(shell.mode, AppShellController.Mode.GALLERY, "Home must switch the shell to Gallery")
	check_true(not _main.editor_root.visible, "Gallery state must hide the Editor root")
	check_true(gallery.visible, "Gallery state must expose the Project Gallery root")
	check_eq(
		gallery.refresh_count,
		refresh_before + 1,
		"returning Home must rescan the Project Library exactly once",
	)
	check_eq(
		gallery.scroll_reset_count,
		reset_before + 1,
		"returning Home must reset the Gallery scroll contract",
	)

	_remove_tree(TEST_DIRECTORY)
	DirAccess.make_dir_recursive_absolute(TEST_DIRECTORY)
	RecoveryStore.remove_staging(TEST_UUID)
	RecoveryStore.discard(TEST_UUID)
	check_true(
		_write_snapshot(TEST_PROJECT_PATH, TEST_UUID),
		"formal P3-C project fixture should be writable",
	)
	var staged := RecoveryStore.staging_path(TEST_UUID)
	check_true(_write_snapshot(staged, TEST_UUID), "recovery staging fixture should be writable")
	check_eq(
		RecoveryStore.install_staging(TEST_UUID),
		OK,
		"recovery fixture should install into the selected project's single slot",
	)
	gallery.refresh()

	var project_count_before := Global.projects.size()
	check_true(
		not shell.open_project_path(TEST_PROJECT_PATH),
		"opening a project with recovery must stop at the recovery decision",
	)
	check_eq(
		shell.mode,
		AppShellController.Mode.GALLERY,
		"recovery prompt must leave the user in Gallery until a decision is made",
	)
	check_eq(
		shell.pending_recovery_uuid,
		TEST_UUID,
		"recovery prompt must bind to the selected project's UUID",
	)
	check_eq(
		shell.pending_recovery_path,
		TEST_PROJECT_PATH,
		"recovery prompt must bind to the selected project's formal path",
	)
	check_eq(
		Global.projects.size(),
		project_count_before,
		"showing recovery UI must not open or duplicate a Project",
	)
	check_true(
		RecoveryStore.has_pending_recovery(TEST_UUID),
		"showing recovery UI must not consume the recovery candidate",
	)

	_main.project_recovery_dialog.canceled.emit()
	check_eq(
		shell.pending_recovery_uuid,
		"",
		"canceling the prompt must clear only the transient dialog selection",
	)
	check_true(
		RecoveryStore.has_pending_recovery(TEST_UUID),
		"canceling the prompt must preserve recovery for the next open attempt",
	)
	check_eq(
		shell.mode,
		AppShellController.Mode.GALLERY,
		"canceling recovery must remain in Gallery instead of opening the project",
	)


func _write_snapshot(path: String, project_uuid: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var packer := ZIPPacker.new()
	if packer.open(path) != OK:
		return false
	var data := {
		"project_uuid": project_uuid,
		"size_x": 24,
		"size_y": 18,
		"layers": [],
		"frames": [],
	}
	if not _write_zip_entry(packer, "data.json", JSON.stringify(data).to_utf8_buffer()):
		packer.close()
		return false
	var gallery_data := Library.build_gallery_metadata(project_uuid, Vector2i(24, 18))
	if not _write_zip_entry(
		packer, Library.GALLERY_ENTRY, JSON.stringify(gallery_data).to_utf8_buffer()
	):
		packer.close()
		return false
	if not _write_zip_entry(
		packer, "mimetype", "application/x-pixelorama".to_utf8_buffer()
	):
		packer.close()
		return false
	return packer.close() == OK


func _write_zip_entry(packer: ZIPPacker, path: String, bytes: PackedByteArray) -> bool:
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
