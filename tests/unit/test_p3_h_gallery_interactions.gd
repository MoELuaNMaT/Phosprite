extends "res://tests/test_base.gd"

const Resolver := preload("res://src/UI/ProjectGallery/ProjectCardGestureResolver.gd")
const Library := preload("res://src/ProjectLibrary/ProjectLibrary.gd")
const Identity := preload("res://src/ProjectLibrary/ProjectIdentity.gd")

const TEST_ROOT := "user://p3_h_gallery_unit_tests"
const UUID_A := "11111111-2222-4333-8444-555555555555"


func teardown() -> void:
	_remove_tree(TEST_ROOT)


func test_tap_is_immediate_and_long_press_is_exclusive() -> void:
	var resolver := Resolver.new()
	var path := TEST_ROOT.path_join("gesture.pxo")

	check_eq(resolver.pointer_down(path, Vector2(10, 10), 0).size(), 0, "down must not open")
	var single := resolver.pointer_up(path, Vector2(10, 10), 50)
	check_eq(single.size(), 1, "single tap must resolve immediately on release")
	if single.size() == 1:
		check_eq(
			single[0]["kind"], Resolver.ActionKind.SINGLE_TAP, "resolved action must be single"
		)
	check_eq(resolver.poll(350).size(), 0, "single tap must not leave a delayed action queued")

	resolver.reset()
	resolver.pointer_down(path, Vector2(20, 20), 1000)
	var first := resolver.pointer_up(path, Vector2(20, 20), 1050)
	resolver.pointer_down(path, Vector2(22, 22), 1100)
	var second := resolver.pointer_up(path, Vector2(22, 22), 1150)
	check_eq(first.size(), 1, "first quick tap must resolve independently")
	check_eq(second.size(), 1, "second quick tap must also resolve independently")
	if first.size() == 1:
		check_eq(first[0]["kind"], Resolver.ActionKind.SINGLE_TAP, "first quick tap stays single")
	if second.size() == 1:
		check_eq(second[0]["kind"], Resolver.ActionKind.SINGLE_TAP, "no double-tap mode may remain")

	resolver.reset()
	resolver.pointer_down(path, Vector2(30, 30), 3000)
	check_eq(resolver.poll(3999).size(), 0, "long press must wait the full threshold")
	var long_press := resolver.poll(4000)
	check_eq(long_press.size(), 1, "one second hold must resolve long press")
	if long_press.size() == 1:
		check_eq(long_press[0]["kind"], Resolver.ActionKind.LONG_PRESS, "action must be long press")
	check_eq(
		resolver.pointer_up(path, Vector2(30, 30), 4050).size(),
		0,
		"long release must not open the project after the context gesture",
	)


func test_gallery_card_suppresses_synthetic_mouse_after_touch() -> void:
	check_true(
		ProjectGalleryCard.should_suppress_mouse_after_touch(
			1200, 1000, Vector2(42, 48), Vector2(40, 46)
		),
		"mouse event near a recent touch must be treated as synthetic",
	)
	check_true(
		not ProjectGalleryCard.should_suppress_mouse_after_touch(
			1700, 1000, Vector2(42, 48), Vector2(40, 46)
		),
		"mouse input outside the suppression window must remain available",
	)
	check_true(
		not ProjectGalleryCard.should_suppress_mouse_after_touch(
			1200, 1000, Vector2(200, 200), Vector2(40, 46)
		),
		"a spatially independent mouse event must not be suppressed",
	)


func test_project_library_rename_duplicate_and_delete_contract() -> void:
	_reset_test_root()
	var foo_path := TEST_ROOT.path_join("foo.pxo")
	check_true(_write_pxo(foo_path, UUID_A), "source PXO fixture should be writable")
	var library := Library.new(TEST_ROOT)

	var duplicate_one := library.duplicate_project(foo_path)
	check_true(bool(duplicate_one.get("ok", false)), "first duplicate should succeed")
	check_eq(
		str(duplicate_one.get("path", "")).get_file(),
		"foo_1.pxo",
		"foo must duplicate to foo_1",
	)
	check_true(
		Identity.is_valid_uuid(str(duplicate_one.get("uuid", ""))),
		"duplicate must receive a UUID",
	)
	check_ne(str(duplicate_one.get("uuid", "")), UUID_A, "duplicate UUID must differ from source")

	var duplicate_two := library.duplicate_project(foo_path)
	check_eq(
		str(duplicate_two.get("path", "")).get_file(),
		"foo_2.pxo",
		"next duplicate must be foo_2",
	)
	var duplicate_nested := library.duplicate_project(str(duplicate_one.get("path", "")))
	check_eq(
		str(duplicate_nested.get("path", "")).get_file(),
		"foo_1_1.pxo",
		"duplicating foo_1 must become foo_1_1",
	)

	var rename := library.rename_project(foo_path, "renamed")
	check_true(bool(rename.get("ok", false)), "healthy project rename should succeed")
	var renamed_path := str(rename.get("path", ""))
	check_eq(renamed_path.get_file(), "renamed.pxo", "rename must change only the filename")
	check_true(not FileAccess.file_exists(foo_path), "old path must disappear after rename")
	var renamed_uuid := ""
	for entry: ProjectLibraryEntry in library.scan(false):
		if entry.path.get_file() == "renamed.pxo":
			renamed_uuid = entry.uuid
	check_eq(renamed_uuid, UUID_A, "rename must preserve project UUID")

	var conflict := library.rename_project(renamed_path, "foo_1")
	check_true(not bool(conflict.get("ok", true)), "rename collision must be rejected")
	check_eq(
		int(conflict.get("error", OK)),
		ERR_ALREADY_EXISTS,
		"collision must report already exists",
	)
	check_true(FileAccess.file_exists(renamed_path), "failed rename must leave source untouched")

	check_eq(
		library.delete_project(renamed_path, UUID_A),
		OK,
		"delete must remove the formal PXO",
	)
	check_true(
		not FileAccess.file_exists(renamed_path), "deleted project must be permanently removed"
	)


func test_p3_h_gallery_source_uses_explicit_multiselect_and_long_press_menus() -> void:
	var gallery_src := FileAccess.get_file_as_string(
		"res://src/UI/ProjectGallery/ProjectGallery.gd"
	)
	var card_scene := FileAccess.get_file_as_string(
		"res://src/UI/ProjectGallery/ProjectGalleryCard.tscn"
	)
	var card_src := FileAccess.get_file_as_string(
		"res://src/UI/ProjectGallery/ProjectGalleryCard.gd"
	)
	var gallery_scene := FileAccess.get_file_as_string(
		"res://src/UI/ProjectGallery/ProjectGallery.tscn"
	)
	var resolver_src := FileAccess.get_file_as_string(
		"res://src/UI/ProjectGallery/ProjectCardGestureResolver.gd"
	)
	var main_src := FileAccess.get_file_as_string("res://src/Main.gd")
	var top_menu_src := FileAccess.get_file_as_string(
		"res://src/UI/TopMenuContainer/TopMenuContainer.gd"
	)
	check_true(
		not gallery_src.contains("ActionKind.DOUBLE_TAP"),
		"Gallery must not retain a double-tap action path",
	)
	check_has(
		gallery_src,
		"project_open_requested.emit(path)",
		"ordinary single tap must open the project directly",
	)
	check_has(
		gallery_src,
		"func _on_resolved_long_press(path: String, position: Vector2) -> void:",
		"long press must own the context-menu gesture",
	)
	check_has(
		gallery_src,
		'call_deferred("_show_project_action_menu", path, position)',
		"normal-mode long press must open the single-project action menu",
	)
	check_has(
		gallery_src,
		'call_deferred("_show_batch_action_menu", position, path)',
		"multiselect long press must keep access to batch actions",
	)
	check_has(
		gallery_src,
		(
			'show_feedback(tr("%d projects duplicated.") % selected.size())'
			+ "\n\t\t\t\tset_multiselect_mode(false)"
		),
		"successful batch duplicate must finish the multi-select task and clear selection mode",
	)
	check_has(
		gallery_scene,
		'text = "Multi-Select"',
		"Gallery top bar must expose the explicit multiselect entry at rest",
	)
	check_has(
		gallery_src,
		'multiselect_button.text = tr("Exit Multi-Select") if enabled else tr("Multi-Select")',
		"the same top-right control must switch between enter and exit labels",
	)
	check_true(
		not resolver_src.contains("DOUBLE_TAP_WINDOW_MSEC"),
		"gesture resolver must not delay single taps for a double-tap window",
	)
	check_has(
		resolver_src,
		"actions.append(_action(ActionKind.SINGLE_TAP, path, position))",
		"single tap must resolve directly from pointer_up",
	)
	check_has(
		card_scene,
		'[node name="ProjectGalleryCard" type="PanelContainer"]',
		"project cards must not inherit native Button pressed/hover draw states",
	)
	check_has(
		card_scene,
		"mouse_filter = 1",
		"project cards must pass drag events to the enclosing ScrollContainer",
	)
	check_true(
		not card_scene.contains("theme_override_styles/pressed"),
		"project cards must not have a native pressed highlight that can latch after popups",
	)
	check_true(
		not card_scene.contains("theme_override_styles/hover"),
		"project cards must not expose hover as a false selection state",
	)
	check_has(
		card_src,
		"should_suppress_mouse_after_touch(",
		"card input must deduplicate touch-generated mouse events on iPad",
	)
	check_has(
		card_src,
		"const DRAG_CANCEL_DISTANCE := 24.0",
		"touch slop must tolerate normal iPad finger jitter before canceling a tap",
	)
	check_has(
		card_scene,
		"SelectionOutline",
		"selected cards must have a prominent outline",
	)
	check_has(
		card_scene,
		"SelectionCheck",
		"selected cards must have a top-right checkmark",
	)
	check_has(
		gallery_src,
		"reveal_in_files_requested.emit",
		"single project menu must expose Reveal in Files",
	)
	check_has(
		gallery_src,
		"export_projects_requested.emit",
		"P3-H must expose the deferred P3-I export hook",
	)
	check_has(
		main_src,
		"ios_document_bridge.reveal_in_files(path)",
		"Reveal in Files must route into the P3-G native bridge",
	)
	check_has(
		top_menu_src,
		"row.move_child(return_home_button, mini(menu_bar.get_index() + 1",
		"managed Projects/Home button must stay left of the iPadOS center multitasking control",
	)


func _write_pxo(path: String, project_uuid: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var packer := ZIPPacker.new()
	if packer.open(path) != OK:
		return false
	var data := {
		"project_uuid": project_uuid,
		"size_x": 16,
		"size_y": 16,
		"layers": [],
		"frames": [],
	}
	if not _write_entry(packer, "data.json", JSON.stringify(data).to_utf8_buffer()):
		packer.close()
		return false
	var gallery := Library.build_gallery_metadata(project_uuid, Vector2i(16, 16))
	if not _write_entry(packer, Library.GALLERY_ENTRY, JSON.stringify(gallery).to_utf8_buffer()):
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
