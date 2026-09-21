extends "res://tests/test_base.gd"

const StoragePolicy := preload("res://src/PlatformServices/StoragePolicy.gd")
const Factory := preload("res://src/ProjectLibrary/ProjectFactory.gd")
const Resolver := preload("res://src/ProjectLibrary/CanvasSizeResolver.gd")
const ImportService := preload("res://src/ProjectLibrary/ProjectImportService.gd")
const RecoveryStore := preload("res://src/ProjectLibrary/ProjectRecoveryStore.gd")

const TEST_ROOT := "user://p3_f_import_projects"
const SOURCE_ROOT := "user://p3_f_import_sources"
const SOURCE_IMAGE := "user://p3_f_import_sources/source.png"
const SOURCE_PXO := "user://p3_f_import_sources/external.pxo"

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
			_main.new_project_dialog,
			_main.import_source_dialog,
			_main.image_import_mode_dialog
		)
	_remove_tree(TEST_ROOT)
	_remove_tree(SOURCE_ROOT)


func test_image_layer_import_downfits_centers_and_commits_managed_pxo() -> void:
	_prepare_managed_main()
	if _main == null:
		return
	var source := _write_source_image(Vector2i(128, 64))
	check_true(source != null, "P3-F image fixture should be writable")
	if source == null:
		return
	var source_bytes := FileAccess.get_file_as_bytes(SOURCE_IMAGE)

	var project: Project = _main.app_shell_controller.import_service.import_image(
		SOURCE_IMAGE, source, ImportService.ImageMode.LAYER, Vector2i(64, 64)
	)
	check_true(project != null, "image-as-layer import should create a managed Project")
	if project == null:
		return
	check_eq(project.size, Vector2i(64, 64), "custom import canvas size must be preserved")
	check_true(
		project.save_path.begins_with(TEST_ROOT + "/"),
		"image import must save into managed Projects storage",
	)
	check_file_exists(project.save_path, "image import must commit a formal PXO")
	check_true(
		RecoveryStore.validate_snapshot(project.save_path, project.project_uuid),
		"imported image PXO must validate against its Project UUID",
	)
	check_eq(
		FileAccess.get_file_as_bytes(SOURCE_IMAGE),
		source_bytes,
		"image import must never mutate the external source file",
	)

	var cel := project.frames[0].cels[0] as PixelCel
	check_eq(
		cel.get_image().get_used_rect(),
		Rect2i(0, 16, 64, 32),
		"oversized source must nearest-neighbor downfit and center inside the canvas",
	)


func test_image_layer_import_keeps_64px_sprite_exactly_one_to_one() -> void:
	_prepare_managed_main()
	if _main == null:
		return
	var source := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	source.fill(Color.TRANSPARENT)
	source.set_pixel(0, 0, Color.RED)
	source.set_pixel(17, 31, Color.BLUE)
	source.set_pixel(63, 63, Color.GREEN)
	check_eq(source.save_png(SOURCE_IMAGE), OK, "64×64 pixel fixture must be writable")

	var project: Project = _main.app_shell_controller.import_service.import_image(
		SOURCE_IMAGE, source, ImportService.ImageMode.LAYER, source.get_size()
	)
	check_true(project != null, "64×64 image-as-layer import should create a managed Project")
	if project == null:
		return
	check_eq(project.size, Vector2i(64, 64), "64×64 source must create a 64×64 project by default")
	var cel := project.frames[0].cels[0] as PixelCel
	var imported := cel.get_image()
	check_eq(
		imported.get_size(), Vector2i(64, 64), "imported layer must keep the source dimensions"
	)
	check_eq(
		imported.get_pixel(0, 0), Color.RED, "top-left pixel must remain at the same coordinate"
	)
	check_eq(
		imported.get_pixel(17, 31), Color.BLUE, "interior pixel must remain at the same coordinate"
	)
	check_eq(
		imported.get_pixel(63, 63),
		Color.GREEN,
		"bottom-right pixel must remain at the same coordinate",
	)


func test_image_reference_import_preserves_source_pixels_and_centers_transform() -> void:
	_prepare_managed_main()
	if _main == null:
		return
	var source := _write_source_image(Vector2i(128, 64))
	if source == null:
		return
	var canvas_size := Resolver.resolve(source.get_size())
	var project: Project = _main.app_shell_controller.import_service.import_image(
		SOURCE_IMAGE, source, ImportService.ImageMode.REFERENCE, canvas_size
	)
	check_true(project != null, "image-as-reference import should create a managed Project")
	if project == null:
		return
	check_eq(
		project.reference_images.size(),
		1,
		"reference mode must attach exactly one ReferenceImage to the new project",
	)
	if project.reference_images.is_empty():
		return
	var reference: ReferenceImage = project.reference_images[0]
	check_true(
		reference.is_inside_tree(),
		"reference import must be mounted immediately instead of appearing only after reload",
	)
	check_true(
		reference.get_parent() == Global.canvas.reference_image_container,
		"reference import must reuse the existing canvas ReferenceImage container lifecycle",
	)
	var expected_scale := Resolver.reference_scale(source.get_size(), canvas_size)
	check_eq(
		reference.scale,
		Vector2.ONE * expected_scale,
		"reference image must use a uniform fit transform rather than destructive resize",
	)
	check_eq(
		reference.position,
		Resolver.reference_position(source.get_size(), canvas_size, expected_scale),
		"reference image must be centered after fit",
	)
	check_file_exists(project.save_path, "reference-image import must also become a managed PXO")


func test_pxo_copy_in_preserves_source_and_repairs_only_imported_duplicate_uuid() -> void:
	_prepare_managed_main()
	if _main == null:
		return
	DirAccess.make_dir_recursive_absolute(SOURCE_ROOT)
	var fixture := Factory.create_blank_project("external", Vector2i(32, 24))
	check_true(
		OpenSave.save_pxo_file(SOURCE_PXO, true, false, fixture, true),
		"external PXO fixture should be serializable without becoming a managed project",
	)
	var source_bytes := FileAccess.get_file_as_bytes(SOURCE_PXO)
	var source_uuid := fixture.project_uuid

	var first: Project = _main.app_shell_controller.import_service.import_pxo(SOURCE_PXO)
	check_true(first != null, "first PXO copy-in should succeed")
	if first == null:
		return
	check_eq(first.project_uuid, source_uuid, "first managed copy may retain the external UUID")
	check_eq(
		first.save_path,
		TEST_ROOT.path_join("external.pxo"),
		"first PXO copy-in should retain the basename inside managed Projects",
	)

	var first_uuid: String = first.project_uuid
	var second: Project = _main.app_shell_controller.import_service.import_pxo(SOURCE_PXO)
	check_true(second != null, "second PXO copy-in should resolve the path collision")
	if second == null:
		return
	check_eq(
		second.save_path,
		TEST_ROOT.path_join("external_1.pxo"),
		"second PXO copy-in must use the _1 collision suffix",
	)
	check_ne(
		second.project_uuid,
		first_uuid,
		(
			"duplicate PXO import must assign identity to the imported copy, "
			+ "not rewrite the existing project"
		),
	)
	check_eq(
		first.project_uuid,
		first_uuid,
		"existing managed Project identity must remain unchanged after duplicate import",
	)
	check_eq(
		FileAccess.get_file_as_bytes(SOURCE_PXO),
		source_bytes,
		"PXO copy-in must never modify the external source",
	)


func test_image_handoff_opens_mode_then_seeds_layer_canvas_dialog_from_source_size() -> void:
	_prepare_managed_main()
	if _main == null:
		return
	var source := _write_source_image(Vector2i(60, 40))
	if source == null:
		return

	check_true(
		_main.app_shell_controller.handoff_import_path(SOURCE_IMAGE),
		"ordinary file path handoff must reach the P3-F image mode flow",
	)
	check_eq(
		_main.app_shell_controller.pending_import_path,
		SOURCE_IMAGE,
		"image mode decision must retain the handed-off source path",
	)
	_main.image_import_mode_dialog.layer_requested.emit()
	check_eq(
		_main.new_project_dialog.selected_size,
		Vector2i(60, 40),
		"作为图层 must seed NewProjectDialog with the exact source pixel dimensions",
	)
	_main.new_project_dialog.hide()
	_main.app_shell_controller._on_new_project_canceled()


func _prepare_managed_main() -> void:
	_main = tree.current_scene
	check_true(_main != null, "runner must load Main before P3-F integration tests")
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


func _write_source_image(image_size: Vector2i) -> Image:
	var image := Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.25, 0.5, 0.75, 1.0))
	if image.save_png(SOURCE_IMAGE) != OK:
		return null
	return image


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
