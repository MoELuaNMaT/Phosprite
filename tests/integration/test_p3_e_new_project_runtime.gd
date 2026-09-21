extends "res://tests/test_base.gd"

const StoragePolicy := preload("res://src/PlatformServices/StoragePolicy.gd")
const RecoveryStore := preload("res://src/ProjectLibrary/ProjectRecoveryStore.gd")

const TEST_ROOT := "user://p3_e_new_project_tests"
const BLOCKER_PATH := "user://p3_e_new_project_blocker"

var _main: Control
var _baseline_project_count := 0
var _baseline_current_index := 0


func teardown() -> void:
	if is_instance_valid(_main):
		_main.project_save_coordinator.configure(false, StoragePolicy.PROJECTS_DIRECTORY, false)
		_cleanup_added_projects()
		_main.project_gallery_root.configure(StoragePolicy.PROJECTS_DIRECTORY)
		_main.app_shell_controller.configure(
			false,
			_main.editor_root,
			_main.project_gallery_root,
			_main.project_recovery_dialog,
			_main.project_save_coordinator,
			_main.new_project_dialog
		)
	_remove_tree(TEST_ROOT)
	if FileAccess.file_exists(BLOCKER_PATH):
		DirAccess.remove_absolute(BLOCKER_PATH)


func test_new_project_dialog_reopens_with_synced_64_by_64_default() -> void:
	_prepare_main()
	if _main == null:
		return
	var dialog := _main.new_project_dialog as NewProjectDialog
	dialog.width_value.value = 123
	dialog.height_value.value = 45
	dialog.popup_for_new_project()

	check_eq(
		dialog.selected_size,
		Vector2i(64, 64),
		"each P3-E New Project session must reset its selected size to 64x64",
	)
	check_eq(
		int(dialog.width_value.value),
		64,
		"reopened New Project width input must match the 64x64 default",
	)
	check_eq(
		int(dialog.height_value.value),
		64,
		"reopened New Project height input must match the 64x64 default",
	)
	dialog.hide()


func test_new_project_is_saved_before_editor_and_blank_canvas_is_transparent() -> void:
	_prepare_main()
	if _main == null:
		return
	_reset_root()
	_configure_managed(TEST_ROOT)

	var count_before := Global.projects.size()
	var tabs_before := Global.tabs.tab_count
	check_true(
		_main.app_shell_controller.create_new_project(Vector2i(85, 64)),
		"P3-E should create and commit a valid 4:3 project",
	)
	check_eq(
		_main.app_shell_controller.mode,
		AppShellController.Mode.EDITOR,
		"successful first save must transition Gallery to Editor",
	)
	check_eq(
		Global.projects.size(),
		count_before + 1,
		"successful New Project must append exactly one runtime project",
	)
	check_eq(
		Global.tabs.tab_count,
		tabs_before + 1,
		"successful New Project must append exactly one editor tab",
	)

	var project := Global.current_project
	check_eq(project.size, Vector2i(85, 64), "new Project must keep the selected preset size")
	check_true(
		project.name.begins_with("未命名_"),
		"new Project must use the timestamped untitled display name",
	)
	check_true(
		project.save_path.begins_with(TEST_ROOT + "/"),
		"new Project must be committed into managed Projects storage before Editor",
	)
	check_file_exists(project.save_path, "successful P3-E creation must leave a formal PXO")
	check_true(
		RecoveryStore.validate_snapshot(project.save_path, project.project_uuid),
		"formal PXO must validate against the new Project UUID",
	)
	check_true(
		not project.has_changed, "successful first commit must clear the new Project dirty bit"
	)
	check_true(
		not RecoveryStore.has_pending_recovery(project.project_uuid),
		"successful first commit must not leave a recovery candidate behind",
	)

	var image := project.frames[0].cels[0].get_image()
	check_eq(
		image.get_pixel(0, 0).a,
		0.0,
		"P3-E blank project must start transparent with no fill/background option",
	)


func test_failed_first_save_rolls_back_project_tab_and_stays_in_gallery() -> void:
	_prepare_main()
	if _main == null:
		return
	_remove_tree(TEST_ROOT)
	if FileAccess.file_exists(BLOCKER_PATH):
		DirAccess.remove_absolute(BLOCKER_PATH)
	var blocker := FileAccess.open(BLOCKER_PATH, FileAccess.WRITE)
	check_true(blocker != null, "failure fixture must create a file where a directory is required")
	if blocker == null:
		return
	blocker.store_string("block")
	blocker.close()

	_configure_managed(BLOCKER_PATH)
	var count_before := Global.projects.size()
	var tabs_before := Global.tabs.tab_count
	var current_before := Global.current_project

	check_true(
		not _main.app_shell_controller.create_new_project(Vector2i(64, 64)),
		"initial save failure must reject the New Project transition",
	)
	check_eq(
		Global.projects.size(),
		count_before,
		"failed first save must remove the transient Project",
	)
	check_eq(
		Global.tabs.tab_count,
		tabs_before,
		"failed first save must remove the transient editor tab",
	)
	check_true(
		Global.current_project == current_before,
		"failed first save must leave the previous current Project untouched",
	)
	check_eq(
		_main.app_shell_controller.mode,
		AppShellController.Mode.GALLERY,
		"failed first save must leave the user in Project Gallery",
	)


func _prepare_main() -> void:
	_main = tree.current_scene
	check_true(_main != null, "runner must load Main before the P3-E integration tests")
	if _main == null:
		return
	_baseline_project_count = Global.projects.size()
	_baseline_current_index = Global.current_project_index


func _configure_managed(directory: String) -> void:
	_main.project_save_coordinator.configure(true, directory, false)
	_main.project_gallery_root.configure(directory)
	_main.app_shell_controller.configure(
		true,
		_main.editor_root,
		_main.project_gallery_root,
		_main.project_recovery_dialog,
		_main.project_save_coordinator,
		_main.new_project_dialog
	)
	_main.app_shell_controller.show_gallery(false)


func _cleanup_added_projects() -> void:
	while Global.projects.size() > _baseline_project_count:
		var index := Global.projects.size() - 1
		var project := Global.projects[index]
		if index < Global.tabs.tab_count:
			Global.tabs.remove_tab(index)
		project.remove()
	if Global.projects.size() > 0:
		Global.current_project_index = mini(_baseline_current_index, Global.projects.size() - 1)


func _reset_root() -> void:
	_remove_tree(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(TEST_ROOT)


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for directory in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(directory))
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
