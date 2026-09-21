extends "res://tests/test_base.gd"

const Library := preload("res://src/ProjectLibrary/ProjectLibrary.gd")
const Entry := preload("res://src/ProjectLibrary/ProjectLibraryEntry.gd")
const RecoveryStore := preload("res://src/ProjectLibrary/ProjectRecoveryStore.gd")

const TEST_ROOT := "user://p3_k_final_gate_unit"
const STRESS_COUNT := 120
const DUPLICATE_COUNT := 12
const RECOVERY_UUID := "90000000-0000-4000-8000-000000000001"


func teardown() -> void:
	_remove_tree(TEST_ROOT)
	RecoveryStore.remove_staging(RECOVERY_UUID)
	RecoveryStore.discard(RECOVERY_UUID)


func test_large_library_scan_stays_metadata_only_and_tracks_external_rescan() -> void:
	_reset_test_root()
	var preview_bytes := _preview_bytes()
	for index in STRESS_COUNT:
		var path := TEST_ROOT.path_join("project_%03d.pxo" % index)
		check_true(
			_write_pxo(
				path,
				_uuid_for(index + 1),
				Vector2i(16 + index % 17, 16 + index % 13),
				preview_bytes,
				"payload-%03d" % index
			),
			"stress project fixture %d should be writable" % index,
		)

	var library := Library.new(TEST_ROOT)
	var entries := library.scan(false)
	check_eq(entries.size(), STRESS_COUNT, "stress scan must discover every managed PXO")
	for entry: ProjectLibraryEntry in entries:
		check_true(
			entry.health_state == Entry.HealthState.OK,
			"stress scan should keep healthy PXOs healthy",
		)
		check_true(
			entry.thumbnail == null,
			"metadata-only stress scan must not decode preview.png",
		)

	var removed_path := TEST_ROOT.path_join("project_000.pxo")
	var modified_path := TEST_ROOT.path_join("project_057.pxo")
	var modified_uuid := _uuid_for(58)
	var added_path := TEST_ROOT.path_join("external_added.pxo")
	var corrupted_path := TEST_ROOT.path_join("external_corrupted.pxo")
	check_eq(
		DirAccess.remove_absolute(removed_path),
		OK,
		"external delete fixture should remove one managed PXO",
	)
	check_eq(
		DirAccess.remove_absolute(modified_path),
		OK,
		"external modify fixture should replace the old managed PXO",
	)
	check_true(
		_write_pxo(
			modified_path,
			modified_uuid,
			Vector2i(321, 123),
			preview_bytes,
			"externally-modified"
		),
		"external modification should rewrite the selected PXO",
	)
	check_true(
		_write_pxo(
			added_path,
			_uuid_for(999),
			Vector2i(48, 24),
			preview_bytes,
			"externally-added"
		),
		"external add should create a new managed PXO",
	)
	var corrupt := FileAccess.open(corrupted_path, FileAccess.WRITE)
	check_true(corrupt != null, "corrupted external fixture should open for writing")
	if corrupt != null:
		corrupt.store_string("not a zip archive")
		corrupt.close()

	var rescanned := library.scan(false)
	check_eq(
		rescanned.size(),
		STRESS_COUNT + 1,
		"rescan must reflect one delete, one add and one new corrupted PXO",
	)
	check_true(
		_find_entry(rescanned, removed_path) == null,
		"externally deleted project must disappear on rescan",
	)
	var modified := _find_entry(rescanned, modified_path)
	check_true(modified != null, "externally modified project must remain discoverable")
	if modified != null:
		check_eq(
			modified.canvas_size,
			Vector2i(321, 123),
			"rescan must refresh externally changed gallery metadata",
		)
		check_eq(
			modified.uuid,
			modified_uuid,
			"external metadata refresh must preserve the project's UUID",
		)
	var added := _find_entry(rescanned, added_path)
	check_true(added != null, "externally added project must appear on rescan")
	var corrupted := _find_entry(rescanned, corrupted_path)
	check_true(corrupted != null, "corrupted external PXO must remain visible in Gallery data")
	if corrupted != null:
		check_eq(
			corrupted.health_state,
			Entry.HealthState.CORRUPTED,
			"corrupted external PXO must be classified instead of crashing scan",
		)

	var source := FileAccess.get_file_as_string("res://src/ProjectLibrary/ProjectLibrary.gd")
	check_true(
		not source.contains("Project.new("),
		"Project Library fast scan must not instantiate full Project objects",
	)
	check_true(
		not source.contains(".deserialize("),
		"Project Library fast scan must not deserialize full editor projects",
	)


func test_duplicate_uuid_repair_is_unique_and_stable_under_batch_rescan() -> void:
	_reset_test_root()
	var preview_bytes := _preview_bytes()
	var duplicate_uuid := "81111111-2222-4333-8444-555555555555"
	for index in DUPLICATE_COUNT:
		var path := TEST_ROOT.path_join("duplicate_%02d.pxo" % index)
		check_true(
			_write_pxo(
				path,
				duplicate_uuid,
				Vector2i(32 + index, 24 + index),
				preview_bytes,
				"duplicate-%02d" % index
			),
			"duplicate UUID fixture %d should be writable" % index,
		)

	var library := Library.new(TEST_ROOT)
	var first_scan := library.scan(false)
	check_eq(
		first_scan.size(),
		DUPLICATE_COUNT,
		"duplicate UUID stress scan must retain every physical project",
	)
	var uuid_by_path: Dictionary = {}
	var unique_uuids: Dictionary = {}
	for entry: ProjectLibraryEntry in first_scan:
		check_true(
			not unique_uuids.has(entry.uuid),
			"every duplicate physical copy must leave scan with a unique UUID",
		)
		unique_uuids[entry.uuid] = true
		uuid_by_path[entry.path] = entry.uuid
	check_eq(
		unique_uuids.size(),
		DUPLICATE_COUNT,
		"duplicate repair must generate exactly one stable identity per project",
	)
	var canonical_path := TEST_ROOT.path_join("duplicate_00.pxo")
	check_eq(
		str(uuid_by_path.get(canonical_path, "")),
		duplicate_uuid,
		"lexicographically first duplicate must keep the original UUID",
	)

	var second_scan := library.scan(false)
	check_eq(
		second_scan.size(),
		DUPLICATE_COUNT,
		"second duplicate scan must retain the same physical project count",
	)
	for entry: ProjectLibraryEntry in second_scan:
		check_eq(
			entry.uuid,
			str(uuid_by_path.get(entry.path, "")),
			"duplicate UUID repair must be stable across repeated scans",
		)


func test_interrupted_transaction_boundaries_preserve_formal_and_recovery() -> void:
	_reset_test_root()
	RecoveryStore.remove_staging(RECOVERY_UUID)
	RecoveryStore.discard(RECOVERY_UUID)
	var preview_bytes := _preview_bytes()
	var formal_path := TEST_ROOT.path_join("recovery_target.pxo")
	check_true(
		_write_pxo(
			formal_path,
			RECOVERY_UUID,
			Vector2i(40, 30),
			preview_bytes,
			"formal-v1"
		),
		"formal recovery fixture should be writable",
	)
	var staged_path := RecoveryStore.staging_path(RECOVERY_UUID)
	check_true(
		_write_pxo(
			staged_path,
			RECOVERY_UUID,
			Vector2i(40, 30),
			preview_bytes,
			"recovery-v2"
		),
		"staging recovery fixture should be writable",
	)
	check_true(
		RecoveryStore.validate_snapshot(staged_path, RECOVERY_UUID),
		"kill-before-install fixture must be a valid staging PXO",
	)
	check_eq(
		_read_payload(formal_path),
		"formal-v1",
		"process death before staging install must leave formal PXO untouched",
	)
	check_true(
		not RecoveryStore.has_pending_recovery(RECOVERY_UUID),
		"staging alone must not masquerade as an installed recovery candidate",
	)

	check_eq(
		RecoveryStore.install_staging(RECOVERY_UUID),
		OK,
		"validated staging must install into the single recovery slot",
	)
	check_eq(
		_read_payload(formal_path),
		"formal-v1",
		"process death after recovery install but before formal commit must preserve old formal PXO",
	)
	check_true(
		RecoveryStore.has_pending_recovery(RECOVERY_UUID),
		"installed recovery must survive an interrupted formal commit",
	)
	check_eq(
		_read_payload(RecoveryStore.recovery_path(RECOVERY_UUID)),
		"recovery-v2",
		"installed recovery must retain the newer serialized payload",
	)

	var fresh_library := Library.new(TEST_ROOT)
	var fresh_entries := fresh_library.scan(false)
	var fresh_entry := _find_entry(fresh_entries, formal_path)
	check_true(
		fresh_entry != null,
		"a fresh Project Library instance must still discover the formal project after interruption",
	)
	if fresh_entry != null:
		check_true(
			fresh_entry.has_pending_recovery,
			"pending recovery state must be reconstructed from disk after process memory is lost",
		)

	check_eq(
		RecoveryStore.restore_to_project(RECOVERY_UUID, formal_path),
		OK,
		"explicit restore must atomically promote the surviving recovery candidate",
	)
	check_eq(
		_read_payload(formal_path),
		"recovery-v2",
		"restored formal project must contain the recovery payload",
	)
	check_true(
		not RecoveryStore.has_pending_recovery(RECOVERY_UUID),
		"successful restore must consume the recovery slot",
	)
	check_true(
		not FileAccess.file_exists(staged_path),
		"successful install/restore sequence must not leave stale staging behind",
	)


func _uuid_for(index: int) -> String:
	return "10000000-0000-4000-8000-%012d" % index


func _preview_bytes() -> PackedByteArray:
	var preview := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	preview.fill(Color(0.25, 0.5, 0.75, 0.5))
	return preview.save_png_to_buffer()


func _write_pxo(
	path: String,
	project_uuid: String,
	canvas_size: Vector2i,
	preview_bytes: PackedByteArray,
	payload: String
) -> bool:
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
	if not _write_entry(
		packer, Library.GALLERY_ENTRY, JSON.stringify(gallery).to_utf8_buffer()
	):
		packer.close()
		return false
	if not preview_bytes.is_empty():
		if not _write_entry(packer, Library.PREVIEW_ENTRY, preview_bytes):
			packer.close()
			return false
	if not _write_entry(packer, "payload.txt", payload.to_utf8_buffer()):
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


func _read_payload(path: String) -> String:
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		return ""
	if not reader.file_exists("payload.txt"):
		reader.close()
		return ""
	var value := reader.read_file("payload.txt").get_string_from_utf8()
	reader.close()
	return value


func _find_entry(entries: Array[ProjectLibraryEntry], path: String) -> ProjectLibraryEntry:
	for entry: ProjectLibraryEntry in entries:
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
