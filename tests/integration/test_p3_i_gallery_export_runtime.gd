extends "res://tests/test_base.gd"

const StoragePolicy := preload("res://src/PlatformServices/StoragePolicy.gd")
const Factory := preload("res://src/ProjectLibrary/ProjectFactory.gd")
const ProfileScript := preload("res://src/ProjectLibrary/ExportProfile.gd")
const CoordinatorScript := preload("res://src/ProjectLibrary/ProjectExportCoordinator.gd")

const TEST_ROOT := "user://p3_i_export_runtime"
const OUTPUT_ROOT := "user://p3_i_export_runtime/output"
const FIRST_PATH := "user://p3_i_export_runtime/first.pxo"
const SECOND_PATH := "user://p3_i_export_runtime/second.pxo"

var _main: Control
var _coordinator: ProjectExportCoordinator
var _baseline_project_count := 0
var _baseline_current_project: Project


func teardown() -> void:
	if is_instance_valid(_coordinator):
		_coordinator.queue_free()
	if is_instance_valid(_main):
		_main.project_save_coordinator.configure(false, StoragePolicy.PROJECTS_DIRECTORY, false)
	_remove_tree(TEST_ROOT)


func test_batch_export_reuses_profile_without_cross_project_cache() -> void:
	_prepare_main()
	if _main == null:
		return

	check_true(
		_write_project_fixture(FIRST_PATH, Vector2i(8, 5), Color(0.9, 0.1, 0.1, 1.0)),
		"first Gallery export fixture must be writable",
	)
	check_true(
		_write_project_fixture(SECOND_PATH, Vector2i(13, 7), Color(0.1, 0.2, 0.9, 1.0)),
		"second Gallery export fixture must be writable",
	)
	DirAccess.make_dir_recursive_absolute(OUTPUT_ROOT)

	var profile := ProfileScript.capture(Global.current_project)
	profile.current_tab = Export.ExportTab.IMAGE
	profile.file_format = Export.FileFormat.PNG
	profile.export_directory_path = OUTPUT_ROOT
	profile.frame_current_tag = Export.ExportFrames.ALL_FRAMES
	profile.export_layers = Export.VISIBLE_LAYERS
	profile.split_layers = false
	profile.export_json = false
	profile.resize = 100

	var project_count_before := Global.projects.size()
	var current_before := Global.current_project
	var result := await _coordinator.run_batch(
		PackedStringArray([FIRST_PATH, SECOND_PATH]), profile
	)
	var exported: PackedStringArray = result.get("exported", PackedStringArray())
	var failed: PackedStringArray = result.get("failed", PackedStringArray())

	check_eq(exported.size(), 2, "both selected projects must export")
	check_eq(failed.size(), 0, "successful batch export must have no failed paths")
	check_file_exists(OUTPUT_ROOT.path_join("first.png"), "first project must use first.png")
	check_file_exists(OUTPUT_ROOT.path_join("second.png"), "second project must use second.png")

	var first_image := Image.load_from_file(OUTPUT_ROOT.path_join("first.png"))
	var second_image := Image.load_from_file(OUTPUT_ROOT.path_join("second.png"))
	check_eq(first_image.get_size(), Vector2i(8, 5), "first export must use first project cache")
	check_eq(
		second_image.get_size(),
		Vector2i(13, 7),
		"second export must rebuild cache for the second project",
	)
	check_true(
		first_image.get_pixel(0, 0).r > first_image.get_pixel(0, 0).b,
		"first output must retain the first project's red content",
	)
	check_true(
		second_image.get_pixel(0, 0).b > second_image.get_pixel(0, 0).r,
		"second output must retain the second project's blue content",
	)
	check_eq(
		Global.projects.size(),
		project_count_before,
		"transient batch export must release every temporary Project",
	)
	check_true(
		Global.current_project == current_before,
		"transient batch export must not replace the Editor current project",
	)
	check_eq(Export.processed_images.size(), 0, "processed_images must be empty after the batch")
	check_eq(Export.blended_frames.size(), 0, "blended_frames must be empty after the batch")


func _prepare_main() -> void:
	_main = tree.current_scene
	check_true(_main != null, "runner must load Main before P3-I integration tests")
	if _main == null:
		return
	_baseline_project_count = Global.projects.size()
	_baseline_current_project = Global.current_project
	_remove_tree(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(TEST_ROOT)
	_coordinator = CoordinatorScript.new()
	_coordinator.configure(_main.export_dialog)
	tree.root.add_child(_coordinator)


func _write_project_fixture(path: String, size: Vector2i, color: Color) -> bool:
	var project := Factory.create_blank_project(path.get_file().get_basename(), size)
	Global.projects.append(project)
	var cel := project.frames[0].cels[0]
	if cel is PixelCel:
		cel.get_image().fill(color)
	project.has_changed = true
	var saved := OpenSave.save_pxo_file(path, true, false, project, true)
	var index := Global.projects.find(project)
	if index >= 0 and index < Global.tabs.get_tab_count():
		Global.tabs.remove_tab(index)
	project.remove()
	return saved


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for directory in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(directory))
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
