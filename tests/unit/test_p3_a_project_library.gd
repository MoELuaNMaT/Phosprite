extends "res://tests/test_base.gd"

const Library := preload("res://src/ProjectLibrary/ProjectLibrary.gd")
const Entry := preload("res://src/ProjectLibrary/ProjectLibraryEntry.gd")
const Identity := preload("res://src/ProjectLibrary/ProjectIdentity.gd")

const TEST_ROOT := "user://p3_a_project_library_tests"
const ORIGINAL_UUID := "12345678-1234-4234-8234-123456789abc"


func teardown() -> void:
	_remove_tree(TEST_ROOT)


func test_uuid_generation_is_valid_and_unique() -> void:
	var first := Identity.generate_uuid()
	var second := Identity.generate_uuid()
	check_true(Identity.is_valid_uuid(first), "generated project UUID must be valid")
	check_true(Identity.is_valid_uuid(second), "second generated project UUID must be valid")
	check_ne(first, second, "independent projects must not share generated UUIDs")
	check_true(not Identity.is_valid_uuid(""), "empty project identity must be rejected")
	check_true(
		not Identity.is_valid_uuid("12345678-1234-1234-1234-not-a-valid-id"),
		"non-hex project identity must be rejected",
	)


func test_scan_reads_gallery_metadata_thumbnail_and_mtime() -> void:
	_reset_test_root()
	var project_path := TEST_ROOT.path_join("gallery.pxo")
	check_true(
		_write_pxo(project_path, ORIGINAL_UUID, Vector2i(48, 32), true, true),
		"fixture PXO should be written",
	)

	var library := Library.new(TEST_ROOT)
	var entries := library.scan()
	check_eq(entries.size(), 1, "one managed project should be discovered")
	if entries.is_empty():
		return
	var entry := entries[0] as ProjectLibraryEntry
	check_eq(entry.path, project_path, "entry should retain its managed PXO path")
	check_eq(entry.uuid, ORIGINAL_UUID, "Gallery UUID should be read without Project loading")
	check_eq(entry.canvas_size, Vector2i(48, 32), "Gallery canvas size should be read")
	check_eq(
		entry.modified_time,
		FileAccess.get_modified_time(project_path),
		"entry should expose the filesystem Unix modification time",
	)
	check_eq(
		entry.health_state,
		Entry.HealthState.OK,
		"a valid managed PXO should be marked healthy",
	)
	check_true(entry.thumbnail != null, "preview.png should become the Gallery thumbnail")
	if entry.thumbnail != null:
		check_eq(entry.thumbnail.get_size(), Vector2i(2, 2), "thumbnail PNG should decode")
	check_true(
		not entry.has_pending_recovery,
		"P3-A should expose recovery state without inventing P3-B recovery records",
	)


func test_legacy_pxo_gets_transient_uuid_without_scan_rewrite() -> void:
	_reset_test_root()
	var project_path := TEST_ROOT.path_join("legacy.pxo")
	check_true(
		_write_pxo(project_path, "", Vector2i(16, 24), false, false),
		"legacy fixture without Gallery metadata should be written",
	)

	var entries := Library.new(TEST_ROOT).scan()
	check_eq(entries.size(), 1, "legacy PXO should still enter the Project Library")
	if entries.is_empty():
		return
	var entry := entries[0] as ProjectLibraryEntry
	check_true(
		Identity.is_valid_uuid(entry.uuid),
		"legacy PXO should receive an in-memory identity on first management",
	)
	check_eq(entry.canvas_size, Vector2i(16, 24), "legacy size should fall back to data.json")
	check_eq(entry.health_state, Entry.HealthState.OK, "legacy PXO should remain healthy")

	var reader := ZIPReader.new()
	check_eq(reader.open(project_path), OK, "legacy fixture should remain readable after scan")
	if reader.file_exists("data.json"):
		var data := _read_zip_json(reader, "data.json")
		check_true(
			not data.has("project_uuid"),
			"scan alone must not mutate an old PXO; normal save performs UUID backfill",
		)
	check_true(
		not reader.file_exists(Library.GALLERY_ENTRY),
		"scan alone must not add gallery.json to an old PXO",
	)
	reader.close()


func test_corrupted_pxo_remains_visible_as_corrupted_entry() -> void:
	_reset_test_root()
	var project_path := TEST_ROOT.path_join("broken.pxo")
	var file := FileAccess.open(project_path, FileAccess.WRITE)
	check_true(file != null, "corrupted fixture file should be creatable")
	if file != null:
		file.store_string("not a zip archive")
		file.close()

	var entries := Library.new(TEST_ROOT).scan()
	check_eq(entries.size(), 1, "a broken PXO should not disappear from the library")
	if entries.is_empty():
		return
	var entry := entries[0] as ProjectLibraryEntry
	check_eq(entry.path, project_path, "corrupted entry should keep its source path")
	check_eq(entry.uuid, "", "corrupted data must not receive a persisted fake identity")
	check_eq(entry.canvas_size, Vector2i.ZERO, "unknown corrupted size should remain zero")
	check_eq(
		entry.health_state,
		Entry.HealthState.CORRUPTED,
		"unreadable PXO should be explicitly marked CORRUPTED",
	)


func test_duplicate_uuid_keeps_canonical_path_and_rewrites_other_copy() -> void:
	_reset_test_root()
	var a_path := TEST_ROOT.path_join("a.pxo")
	var b_path := TEST_ROOT.path_join("b.pxo")
	check_true(
		_write_pxo(a_path, ORIGINAL_UUID, Vector2i(20, 12), true, false),
		"canonical duplicate fixture should be written",
	)
	check_true(
		_write_pxo(b_path, ORIGINAL_UUID, Vector2i(20, 12), true, false),
		"second duplicate fixture should be written",
	)

	var library := Library.new(TEST_ROOT)
	var entries := library.scan()
	check_eq(entries.size(), 2, "both copied projects should remain visible")
	var a_entry := _find_entry(entries, a_path)
	var b_entry := _find_entry(entries, b_path)
	check_true(a_entry != null, "lexicographically first duplicate should remain present")
	check_true(b_entry != null, "rewritten duplicate should remain present")
	if a_entry == null or b_entry == null:
		return
	check_eq(
		a_entry.uuid,
		ORIGINAL_UUID,
		"normalized lexicographically first path must keep the original UUID",
	)
	check_true(
		Identity.is_valid_uuid(b_entry.uuid),
		"non-canonical copy should receive a valid replacement UUID",
	)
	check_ne(b_entry.uuid, ORIGINAL_UUID, "duplicate copy must no longer share project identity")

	var rewritten_uuid := b_entry.uuid
	var reader := ZIPReader.new()
	check_eq(reader.open(b_path), OK, "rewritten duplicate should still be a valid PXO ZIP")
	if reader.file_exists("data.json"):
		check_eq(
			_read_zip_json(reader, "data.json").get("project_uuid", ""),
			rewritten_uuid,
			"duplicate repair must persist the new UUID in data.json",
		)
	if reader.file_exists(Library.GALLERY_ENTRY):
		check_eq(
			_read_zip_json(reader, Library.GALLERY_ENTRY).get("project_uuid", ""),
			rewritten_uuid,
			"duplicate repair must persist the new UUID in gallery.json",
		)
	check_true(
		reader.file_exists("payload.bin"),
		"metadata-only duplicate repair must preserve unrelated PXO entries",
	)
	if reader.file_exists("payload.bin"):
		check_eq(
			reader.read_file("payload.bin").get_string_from_utf8(),
			"keep-me",
			"metadata-only duplicate repair must preserve unrelated PXO bytes",
		)
	reader.close()

	var rescanned_entry := _find_entry(library.scan(), b_path)
	check_true(rescanned_entry != null, "rewritten project should survive a second scan")
	if rescanned_entry != null:
		check_eq(
			rescanned_entry.uuid,
			rewritten_uuid,
			"duplicate repair must be stable instead of generating a new UUID every scan",
		)


func test_scan_filters_non_pxo_and_sorts_newest_first() -> void:
	_reset_test_root()
	var older_path := TEST_ROOT.path_join("older.pxo")
	var newer_path := TEST_ROOT.path_join("newer.pxo")
	check_true(
		_write_pxo(older_path, Identity.generate_uuid(), Vector2i(8, 8), true, false),
		"older fixture should be written",
	)
	await tree.create_timer(1.1).timeout
	check_true(
		_write_pxo(newer_path, Identity.generate_uuid(), Vector2i(8, 8), true, false),
		"newer fixture should be written",
	)
	var ignored := FileAccess.open(TEST_ROOT.path_join("notes.txt"), FileAccess.WRITE)
	if ignored != null:
		ignored.store_string("ignore")
		ignored.close()

	var entries := Library.new(TEST_ROOT).scan()
	check_eq(entries.size(), 2, "Project Library should only include .pxo files")
	if entries.size() == 2:
		check_eq(entries[0].path, newer_path, "newest mtime should sort first")
		check_eq(entries[1].path, older_path, "older mtime should sort later")


func test_gallery_schema_contains_only_p3_a_identity_and_canvas_metadata() -> void:
	var metadata := Library.build_gallery_metadata(ORIGINAL_UUID, Vector2i(320, 180))
	var keys := metadata.keys()
	keys.sort()
	check_eq(
		keys,
		["project_uuid", "schema", "size_x", "size_y"],
		"gallery.json schema 1 should stay minimal and independent of full Project serialization",
	)
	check_eq(metadata["schema"], 1, "P3-A Gallery metadata schema should be version 1")
	check_eq(\n\t\tmetadata["project_uuid"], ORIGINAL_UUID, "Gallery metadata should carry stable identity"\n\t)
	check_eq(metadata["size_x"], 320, "Gallery metadata should carry canvas width")
	check_eq(metadata["size_y"], 180, "Gallery metadata should carry canvas height")


func test_project_and_save_sources_persist_uuid_and_gallery_contract() -> void:
	var project_src := FileAccess.get_file_as_string("res://src/Classes/Project.gd")
	var save_src := FileAccess.get_file_as_string("res://src/Autoload/OpenSave.gd")
	check_has(
		project_src,
		'"project_uuid": project_uuid',
		"Project.serialize must persist the stable identity into data.json",
	)
	check_has(
		project_src,
		'dict.get("project_uuid", "")',
		"Project.deserialize must restore identity from existing PXO data",
	)
	check_has(
		save_src,
		"ProjectLibraryScript.build_gallery_metadata(project.project_uuid, project.size)",
		"normal PXO writes must build Gallery metadata from the saved Project",
	)
	check_has(
		save_src,
		"zip_packer.start_file(ProjectLibraryScript.GALLERY_ENTRY)",
		"normal PXO writes must include gallery.json",
	)


func _write_pxo(
	path: String,
	project_uuid: String,
	canvas_size: Vector2i,
	include_gallery: bool,
	include_preview: bool
) -> bool:
	var packer := ZIPPacker.new()
	if packer.open(path) != OK:
		return false
	var data := {
		"size_x": canvas_size.x,
		"size_y": canvas_size.y,
		"layers": [],
		"frames": [],
	}
	if not project_uuid.is_empty():
		data["project_uuid"] = project_uuid
	if not _write_zip_entry(packer, "data.json", JSON.stringify(data).to_utf8_buffer()):
		packer.close()
		return false
	if not _write_zip_entry(
		packer, "mimetype", "application/x-pixelorama".to_utf8_buffer()
	):
		packer.close()
		return false
	if include_gallery:
		var gallery := Library.build_gallery_metadata(project_uuid, canvas_size)
		if not _write_zip_entry(
			packer, Library.GALLERY_ENTRY, JSON.stringify(gallery).to_utf8_buffer()
		):
			packer.close()
			return false
	if include_preview:
		var preview := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		preview.fill(Color(0.25, 0.5, 0.75, 1.0))
		if not _write_zip_entry(packer, "preview.png", preview.save_png_to_buffer()):
			packer.close()
			return false
	if not _write_zip_entry(packer, "payload.bin", "keep-me".to_utf8_buffer()):
		packer.close()
		return false
	return packer.close() == OK


func _write_zip_entry(packer: ZIPPacker, path: String, bytes: PackedByteArray) -> bool:
	if packer.start_file(path) != OK:
		return false
	if packer.write_file(bytes) != OK:
		return false
	return packer.close_file() == OK


func _read_zip_json(reader: ZIPReader, path: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(reader.read_file(path).get_string_from_utf8()) != OK:
		return {}
	if not parser.data is Dictionary:
		return {}
	return parser.data as Dictionary


func _find_entry(entries: Array[ProjectLibraryEntry], path: String) -> ProjectLibraryEntry:
	for entry in entries:
		if entry.path == path:
			return entry
	return null


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
