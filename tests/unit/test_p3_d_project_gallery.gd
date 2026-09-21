extends "res://tests/test_base.gd"

const Library := preload("res://src/ProjectLibrary/ProjectLibrary.gd")
const Entry := preload("res://src/ProjectLibrary/ProjectLibraryEntry.gd")
const CardScene := preload("res://src/UI/ProjectGallery/ProjectGalleryCard.tscn")
const GalleryScript := preload("res://src/UI/ProjectGallery/ProjectGallery.gd")

const TEST_ROOT := "user://p3_d_gallery_tests"
const TEST_UUID := "dddddddd-eeee-4fff-8aaa-bbbbbbbbbbbb"


func teardown() -> void:
	_remove_tree(TEST_ROOT)


func test_gallery_source_contract_matches_p3_d_layout() -> void:
	var gallery_src := FileAccess.get_file_as_string(
		"res://src/UI/ProjectGallery/ProjectGallery.gd"
	)
	var gallery_scene := FileAccess.get_file_as_string(
		"res://src/UI/ProjectGallery/ProjectGallery.tscn"
	)
	var card_scene := FileAccess.get_file_as_string(
		"res://src/UI/ProjectGallery/ProjectGalleryCard.tscn"
	)
	var card_src := FileAccess.get_file_as_string(
		"res://src/UI/ProjectGallery/ProjectGalleryCard.gd"
	)

	check_has(
		gallery_src,
		"const LANDSCAPE_COLUMNS := 6",
		"landscape Project Gallery must use six fixed columns",
	)
	check_has(
		gallery_src,
		"const PORTRAIT_COLUMNS := 4",
		"portrait Project Gallery must use four fixed columns",
	)
	check_has(
		gallery_src,
		"entries = library.scan(false)",
		"Gallery scan must skip thumbnail decode so cards can load lazily",
	)
	check_has(
		gallery_src,
		"visible_rect.intersects(card.get_global_rect())",
		"only cards near the visible scroll region should request thumbnails",
	)
	check_has(
		gallery_scene,
		'text = "Phosprite"',
		"Gallery Top Bar must show the Phosprite brand on the left",
	)
	check_has(
		gallery_scene,
		'text = "Import"',
		"Gallery Top Bar must expose the Import entry",
	)
	check_has(
		gallery_scene,
		'text = "New"',
		"Gallery Top Bar must expose the New entry",
	)
	check_has(
		gallery_scene,
		'text = "Exit Multi-Select"',
		"Gallery Top Bar must expose an exit control when multiselect mode is active",
	)
	check_has(
		card_scene,
		"stretch_mode = 5",
		"thumbnail must use keep-aspect-centered instead of crop/stretch",
	)
	check_true(
		not card_scene.to_lower().contains("checker"),
		"Project Gallery thumbnail cards must not render checkerboard transparency",
	)
	check_true(
		not card_src.contains("entry.path.get_file"),
		"project cards must not derive or display the project filename",
	)
	check_true(
		not card_src.contains("entry.name"),
		"project cards must not display a project name",
	)
	check_has(
		card_src,
		'size_label.text = "%d × %d px"',
		"healthy cards must display canvas dimensions",
	)
	check_has(
		card_src,
		"_format_modified_time(entry.modified_time)",
		"cards must display last modification time",
	)
	check_has(
		card_src,
		"Time.get_time_zone_from_system()",
		"Gallery modification time must follow the device local time zone",
	)


func test_gallery_orientation_and_thumbnail_hit_target_regressions() -> void:
	check_eq(
		GalleryScript.columns_for_viewport_size(Vector2(1366, 1024)),
		6,
		"landscape Gallery must resolve to six columns",
	)
	check_eq(
		GalleryScript.columns_for_viewport_size(Vector2(1024, 1366)),
		4,
		"portrait Gallery must resolve to four columns even with five or more cards",
	)
	var gallery_src := FileAccess.get_file_as_string(
		"res://src/UI/ProjectGallery/ProjectGallery.gd"
	)
	var main_src := FileAccess.get_file_as_string("res://src/Main.gd")
	check_has(
		gallery_src,
		"if size.x > 0.0 and size.y > 0.0:",
		"Gallery orientation must come from its actual safe-area Control geometry",
	)
	check_true(
		not gallery_src.contains('if OS.get_name() == "iOS":\n\t\tvar window := get_window()'),
		"iPad Gallery must not bypass its safe-area layout by preferring Window.size",
	)
	check_has(
		main_src,
		"get_window().size_changed.connect(_on_mobile_window_size_changed)",
		"sensor rotation must re-resolve the mobile safe area",
	)

	var card := CardScene.instantiate() as ProjectGalleryCard
	check_true(card != null, "Gallery card scene must instantiate for hit-target regression")
	if card == null:
		return
	tree.root.add_child(card)
	check_eq(
		card.thumbnail_frame.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"thumbnail frame must pass tap/double-tap/long-press input through to the whole card",
	)
	card.get_parent().remove_child(card)
	card.free()


func test_project_library_supports_lazy_thumbnail_decode() -> void:
	_reset_test_root()
	var project_path := TEST_ROOT.path_join("lazy.pxo")
	check_true(
		_write_pxo(project_path, TEST_UUID, Vector2i(32, 20)),
		"lazy-thumbnail fixture should be written",
	)

	var library := Library.new(TEST_ROOT)
	var entries := library.scan(false)
	check_eq(entries.size(), 1, "lazy scan should still discover the managed project")
	if entries.is_empty():
		return
	var entry := entries[0] as ProjectLibraryEntry
	check_true(entry.thumbnail == null, "lazy Gallery scan must not decode preview.png eagerly")

	var image := library.load_thumbnail(entry)
	check_true(image != null, "visible card thumbnail should decode on demand")
	if image != null:
		check_eq(image.get_size(), Vector2i(3, 2), "lazy thumbnail must preserve PNG dimensions")
	check_true(
		entry.thumbnail == image,
		"decoded lazy thumbnail should be cached on its ProjectLibraryEntry",
	)
	check_true(
		library.load_thumbnail(entry) == image,
		"subsequent visible-card loads should reuse the cached thumbnail",
	)


func test_corrupted_card_remains_renderable_without_project_name() -> void:
	var card := CardScene.instantiate() as ProjectGalleryCard
	check_true(card != null, "P3-D ProjectGalleryCard scene must instantiate")
	if card == null:
		return
	tree.root.add_child(card)
	var entry := Entry.new(TEST_ROOT.path_join("broken.pxo"))
	entry.health_state = Entry.HealthState.CORRUPTED
	entry.modified_time = 1
	card.bind(entry)

	check_true(card.thumbnail_loaded, "corrupted cards must not try to lazy-load a preview")
	check_eq(
		card.size_label.text,
		"Unreadable project",
		"corrupted project must retain a visible abnormal card state",
	)
	check_eq(
		card.thumbnail_status.text, "Corrupted", "corrupted card must identify its failure state"
	)
	card.get_parent().remove_child(card)
	card.free()


func _write_pxo(path: String, project_uuid: String, canvas_size: Vector2i) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var packer := ZIPPacker.new()
	if packer.open(path) != OK:
		return false
	var data := {
		"project_uuid": project_uuid,
		"size_x": canvas_size.x,
		"size_y": canvas_size.y,
		"layers": [],
		"frames": [],
	}
	if not _write_entry(packer, "data.json", JSON.stringify(data).to_utf8_buffer()):
		packer.close()
		return false
	var gallery := Library.build_gallery_metadata(project_uuid, canvas_size)
	if not _write_entry(packer, Library.GALLERY_ENTRY, JSON.stringify(gallery).to_utf8_buffer()):
		packer.close()
		return false
	var preview := Image.create(3, 2, false, Image.FORMAT_RGBA8)
	preview.fill(Color(0.25, 0.5, 0.75, 0.5))
	if not _write_entry(packer, Library.PREVIEW_ENTRY, preview.save_png_to_buffer()):
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


func _reset_test_root() -> void:
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
