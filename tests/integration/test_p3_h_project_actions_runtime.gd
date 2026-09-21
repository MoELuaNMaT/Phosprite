extends "res://tests/test_base.gd"

const StoragePolicy := preload("res://src/PlatformServices/StoragePolicy.gd")
const Factory := preload("res://src/ProjectLibrary/ProjectFactory.gd")
const RecoveryStore := preload("res://src/ProjectLibrary/ProjectRecoveryStore.gd")

const TEST_ROOT := "user://p3_h_project_action_runtime"

var _main: Control
var _baseline_project_count := 0
var _baseline_current_project: Project


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
			_main.new_project_dialog,
			_main.import_source_dialog,
			_main.image_import_mode_dialog
		)
	_remove_tree(TEST_ROOT)


func test_loaded_project_tracks_gallery_rename_and_delete() -> void:
	_prepare_managed_main()
	if _main == null:
		return

	var project := Factory.create_blank_project("runtime_source", Vector2i(24, 20))
	Global.projects.append(project)
	project.has_changed = true
	var source_path := TEST_ROOT.path_join("runtime_source.pxo")
	check_true(
		_main.project_save_coordinator.flush_project(project, "p3_h_fixture", source_path),
		"runtime project fixture must be committed through the managed save coordinator",
	)
	var project_index := Global.projects.find(project)
	Global.current_project_index = project_index
	_main.project_gallery_root.refresh()

	var rename := _main.project_gallery_root.rename_project(source_path, "runtime_renamed")
	var renamed_path := TEST_ROOT.path_join("runtime_renamed.pxo")
	check_true(bool(rename.get("ok", false)), "Gallery rename should succeed")
	check_eq(
		project.save_path,
		renamed_path,
		"loaded Project.save_path must follow Gallery rename",
	)
	check_eq(project.name, "runtime_renamed", "loaded project name must follow Gallery rename")
	check_eq(
		project.file_name,
		"runtime_renamed",
		"loaded project file_name must follow Gallery rename",
	)
	check_file_exists(renamed_path, "renamed managed project must exist on disk")

	var duplicate := _main.project_gallery_root.duplicate_projects(
		PackedStringArray([renamed_path])
	)
	var created: PackedStringArray = duplicate.get("created", PackedStringArray())
	check_eq(created.size(), 1, "Gallery duplicate should create one managed project")
	if created.size() == 1:
		check_eq(
			created[0].get_file(),
			"runtime_renamed_1.pxo",
			"runtime duplicate naming must match P3-H",
		)
		check_file_exists(created[0], "runtime duplicate must exist on disk")

	var deleted := _main.project_gallery_root.delete_projects(PackedStringArray([renamed_path]))
	var deleted_paths: PackedStringArray = deleted.get("deleted", PackedStringArray())
	check_eq(
		deleted_paths.size(),
		1,
		"Gallery delete should remove the selected formal project",
	)
	check_true(not FileAccess.file_exists(renamed_path), "deleted formal PXO must be gone")
	check_true(
		not Global.projects.has(project),
		"loaded deleted project must be removed from runtime",
	)
	check_true(
		Global.current_project != project,
		"deleted project must no longer be the active editor project",
	)


func _prepare_managed_main() -> void:
	_main = tree.current_scene
	check_true(_main != null, "runner must load Main before P3-H integration tests")
	if _main == null:
		return
	_baseline_project_count = Global.projects.size()
	_baseline_current_project = Global.current_project
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
	_main.app_shell_controller.show_gallery(false)


func _cleanup_added_projects() -> void:
	while Global.projects.size() > _baseline_project_count:
		var index := Global.projects.size() - 1
		var project := Global.projects[index]
		if index < Global.tabs.get_tab_count():
			Global.tabs.remove_tab(index)
		if not project.project_uuid.is_empty():
			RecoveryStore.discard(project.project_uuid)
			RecoveryStore.remove_staging(project.project_uuid)
		project.remove()
	if _baseline_current_project != null and Global.projects.has(_baseline_current_project):
		Global.current_project_index = Global.projects.find(_baseline_current_project)


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for directory in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(directory))
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
