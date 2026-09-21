extends "res://tests/test_base.gd"

const StoragePolicy := preload("res://src/PlatformServices/StoragePolicy.gd")

const TEST_ROOT := "user://p3_j_motion_runtime"

var _main: Control


func teardown() -> void:
	if is_instance_valid(_main):
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


func test_gallery_return_scroll_and_mode_transition_finish_stably() -> void:
	_prepare_managed_main()
	if _main == null:
		return

	var shell: AppShellController = _main.app_shell_controller
	var gallery: ProjectGallery = _main.project_gallery_root

	shell.show_editor(false)
	gallery.scroll_container.scroll_vertical = 48
	var reset_before := gallery.scroll_reset_count
	check_true(shell.show_gallery(true, true), "managed shell must enter Gallery")
	check_eq(
		gallery.scroll_reset_count,
		reset_before + 1,
		"Gallery entry must request one scroll reset",
	)
	check_true(
		gallery._interaction_locks.has(&"mode_transition"),
		"Gallery input must lock during the entry transition",
	)
	check_true(
		gallery.modulate.a < 1.0,
		"Gallery destination root must begin the transition below full opacity",
	)

	await tree.process_frame
	check_eq(
		gallery.scroll_container.scroll_vertical,
		0,
		"deferred post-layout scroll contract must land at the top",
	)
	await tree.create_timer(0.22).timeout
	check_true(
		not gallery._interaction_locks.has(&"mode_transition"),
		"mode transition lock must be released after motion completes",
	)
	check_true(
		is_equal_approx(gallery.modulate.a, 1.0),
		"Gallery transition must finish at full opacity",
	)
	check_true(
		gallery.position.distance_to(Vector2.ZERO) < 0.01,
		"Gallery transition must settle back at its base position",
	)


func test_orientation_reflow_preserves_card_order_and_unlocks_touch() -> void:
	_prepare_managed_main()
	if _main == null:
		return
	for i in 10:
		check_true(
			_write_pxo(TEST_ROOT.path_join("card_%02d.pxo" % i), i),
			"orientation fixture must be writable",
		)

	var gallery: ProjectGallery = _main.project_gallery_root
	gallery.refresh()
	await tree.process_frame

	gallery.set_anchors_preset(Control.PRESET_TOP_LEFT)
	gallery.position = Vector2.ZERO
	gallery.size = Vector2(1200, 700)
	gallery._update_layout()
	await tree.process_frame
	check_eq(gallery.grid.columns, 6, "landscape Gallery must use six columns")
	var order_before := _card_paths(gallery)

	gallery.size = Vector2(700, 1200)
	gallery._update_layout()
	check_eq(gallery.grid.columns, 4, "portrait Gallery must use four columns")
	var order_after := _card_paths(gallery)
	check_eq(
		order_after,
		order_before,
		"6-to-4 reflow must never reorder project cards",
	)
	check_true(
		gallery._interaction_locks.has(&"reflow"),
		"orientation change must lock card input before FLIP starts",
	)

	await tree.process_frame
	var has_visual_delta := false
	for card: ProjectGalleryCard in gallery._cards:
		if (
			card.visual_root.position.distance_to(Vector2.ZERO) > 0.01
			or card.visual_root.scale.distance_to(Vector2.ONE) > 0.01
		):
			has_visual_delta = true
			break
	check_true(has_visual_delta, "orientation change must visibly interpolate from the old layout")

	await tree.create_timer(0.24).timeout
	check_true(
		not gallery._interaction_locks.has(&"reflow"),
		"reflow interaction lock must be released after the FLIP duration",
	)
	for card: ProjectGalleryCard in gallery._cards:
		check_true(card.interaction_enabled, "every card must be interactive again after reflow")
		check_true(
			card.visual_root.position.distance_to(Vector2.ZERO) < 0.01,
			"reflowed cards must finish at zero visual translation",
		)
		check_true(
			card.visual_root.scale.distance_to(Vector2.ONE) < 0.01,
			"reflowed cards must finish at unit visual scale",
		)

	gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _prepare_managed_main() -> void:
	_main = tree.current_scene
	check_true(_main != null, "runner must load Main before P3-J runtime tests")
	if _main == null:
		return
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


func _card_paths(gallery: ProjectGallery) -> PackedStringArray:
	var paths := PackedStringArray()
	for card: ProjectGalleryCard in gallery._cards:
		if card.entry != null:
			paths.append(card.entry.path)
	return paths


func _write_pxo(path: String, index: int) -> bool:
	var uuid := "aaaaaaaa-bbbb-4ccc-8ddd-%012d" % (index + 1)
	var packer := ZIPPacker.new()
	if packer.open(path) != OK:
		return false
	var data := {
		"project_uuid": uuid,
		"size_x": 16 + index,
		"size_y": 16 + index,
		"layers": [],
		"frames": [],
	}
	if not _write_entry(packer, "data.json", JSON.stringify(data).to_utf8_buffer()):
		packer.close()
		return false
	var gallery := {
		"schema": 1,
		"project_uuid": uuid,
		"canvas_width": 16 + index,
		"canvas_height": 16 + index,
	}
	if not _write_entry(packer, "gallery.json", JSON.stringify(gallery).to_utf8_buffer()):
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
