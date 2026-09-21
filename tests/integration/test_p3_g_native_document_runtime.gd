extends "res://tests/test_base.gd"

const StoragePolicy := preload("res://src/PlatformServices/StoragePolicy.gd")
const Factory := preload("res://src/ProjectLibrary/ProjectFactory.gd")
const BridgeScript := preload("res://src/PlatformServices/IOSDocumentBridge.gd")
const RecoveryStore := preload("res://src/ProjectLibrary/ProjectRecoveryStore.gd")

const TEST_ROOT := "user://p3_g_native_projects"
const SOURCE_ROOT := "user://p3_g_native_sources"
const FIRST_SOURCE := "user://p3_g_native_sources/first.pxo"
const SECOND_SOURCE := "user://p3_g_native_sources/second.pxo"

var _main: Control
var _bridge: IOSDocumentBridge
var _baseline_project_count := 0
var _baseline_current_index := 0


func teardown() -> void:
	if is_instance_valid(_bridge):
		_bridge.queue_free()
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
	_remove_tree(SOURCE_ROOT)


func test_native_batch_handoff_imports_all_paths_and_enters_editor_only_on_last() -> void:
	_prepare_managed_main()
	if _main == null:
		return
	check_true(
		_write_external_project(FIRST_SOURCE, "first", Vector2i(20, 20)),
		"first native handoff fixture must be writable",
	)
	check_true(
		_write_external_project(SECOND_SOURCE, "second", Vector2i(24, 18)),
		"second native handoff fixture must be writable",
	)

	var mode_events: Array[int] = []
	var collect_mode := func(next_mode: AppShellController.Mode): mode_events.append(next_mode)
	_main.app_shell_controller.mode_changed.connect(collect_mode)

	var before := Global.projects.size()
	_bridge.enqueue_import_paths(PackedStringArray([FIRST_SOURCE, SECOND_SOURCE]))
	for _frame in 6:
		await tree.process_frame

	check_eq(
		Global.projects.size(),
		before + 2,
		"one native multi-selection batch must import every selected path",
	)
	check_file_exists(
		TEST_ROOT.path_join("first.pxo"),
		"first selected external project must become a managed PXO",
	)
	check_file_exists(
		TEST_ROOT.path_join("second.pxo"),
		"second selected external project must become a managed PXO",
	)
	check_eq(
		mode_events.count(AppShellController.Mode.EDITOR),
		1,
		"batch handoff must enter Editor only after the final path completes",
	)
	check_eq(
		_main.app_shell_controller.mode,
		AppShellController.Mode.EDITOR,
		"the final successful native import must end in Editor",
	)
	check_eq(
		Global.current_project.save_path,
		TEST_ROOT.path_join("second.pxo"),
		"the final selected document must be the project shown in Editor",
	)

	if _main.app_shell_controller.mode_changed.is_connected(collect_mode):
		_main.app_shell_controller.mode_changed.disconnect(collect_mode)


func test_native_bridge_is_safe_without_ios_singleton_in_headless_ci() -> void:
	_prepare_managed_main()
	if _main == null:
		return
	check_true(
		_bridge.native_bridge == null,
		"headless/desktop regression must not require the iOS singleton",
	)
	check_true(
		not _bridge.reveal_in_files(TEST_ROOT.path_join("missing.pxo")),
		"Reveal in Files must fail safely when the native singleton is unavailable",
	)


func _prepare_managed_main() -> void:
	_main = tree.current_scene
	check_true(_main != null, "runner must load Main before P3-G integration tests")
	if _main == null:
		return
	_baseline_project_count = Global.projects.size()
	_baseline_current_index = Global.current_project_index
	_remove_tree(TEST_ROOT)
	_remove_tree(SOURCE_ROOT)
	DirAccess.make_dir_recursive_absolute(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(SOURCE_ROOT)

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

	_bridge = BridgeScript.new()
	_bridge.configure(_main.app_shell_controller)
	tree.root.add_child(_bridge)
	_bridge.start()


func _write_external_project(path: String, project_name: String, size: Vector2i) -> bool:
	var project := Factory.create_blank_project(project_name, size)
	return OpenSave.save_pxo_file(path, true, false, project, true)


func _cleanup_added_projects() -> void:
	while Global.projects.size() > _baseline_project_count:
		var index := Global.projects.size() - 1
		var project := Global.projects[index]
		if index < Global.tabs.tab_count:
			Global.tabs.remove_tab(index)
		if not project.project_uuid.is_empty():
			RecoveryStore.discard(project.project_uuid)
			RecoveryStore.remove_staging(project.project_uuid)
		project.remove()
	if Global.projects.size() > 0:
		Global.current_project_index = mini(_baseline_current_index, Global.projects.size() - 1)


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for directory in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(directory))
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
