extends "res://tests/test_base.gd"

const STORAGE_POLICY_SOURCE := "res://src/PlatformServices/StoragePolicy.gd"
const MAIN_SOURCE := "res://src/Main.gd"
const OPEN_SAVE_SOURCE := "res://src/Autoload/OpenSave.gd"
const BASELINE_DOC := "res://docs/p3_0_baseline_freeze.md"


func test_p3_0_managed_storage_baseline_is_user_projects_pxo() -> void:
	var src := FileAccess.get_file_as_string(STORAGE_POLICY_SOURCE)
	check_has(
		src,
		'const PROJECTS_DIRECTORY := "user://Projects"',
		"P3 must inherit the existing managed iOS project directory",
	)
	check_has(
		src,
		'const PROJECT_EXTENSION := ".pxo"',
		"P3 must keep .pxo as the managed project extension",
	)
	check_has(
		src,
		'return OS.get_name() == "iOS"',
		"managed project storage must remain an iOS-only policy at the baseline",
	)
	check_has(
		src,
		'"%s_%d%s" % [base_name, index, PROJECT_EXTENSION]',
		"managed storage must retain collision-safe suffix allocation",
	)


func test_p3_0_save_dispatch_baseline_keeps_managed_ios_storage() -> void:
	var src := FileAccess.get_file_as_string(MAIN_SOURCE)
	check_has(
		src,
		'const STORAGE_POLICY := preload("res://src/PlatformServices/StoragePolicy.gd")',
		"Main must keep routing project saves through StoragePolicy",
	)
	check_has(
		src,
		"func request_save(intent: SaveIntent, target_project: Project) -> void:",
		"P3 starts from the existing unified save entry point",
	)
	check_has(
		src,
		"elif STORAGE_POLICY.uses_managed_project_storage():",
		"a first iOS Save must still use managed project storage",
	)
	check_has(
		src,
		"_save_to_managed_directory(target_project)",
		"managed iOS Save and Quit Save must still reach the managed directory helper",
	)
	check_has(
		src,
		"asks_for_new_name and STORAGE_POLICY.uses_managed_project_storage()",
		"iOS Save As must remain confined to the managed project directory",
	)


func test_p3_0_pxo_container_identity_is_unchanged() -> void:
	var src := FileAccess.get_file_as_string(OPEN_SAVE_SOURCE)
	check_has(
		src,
		"func save_pxo_file(",
		"P3 must start from the existing .pxo serializer",
	)
	check_has(
		src,
		'zip_packer.start_file("data.json")',
		".pxo must retain its data.json payload",
	)
	check_has(
		src,
		'zip_packer.start_file("mimetype")',
		".pxo must retain its mimetype entry",
	)
	check_has(
		src,
		'"application/x-pixelorama".to_utf8_buffer()',
		".pxo must remain Pixelorama-compatible at the P3 baseline",
	)


func test_p3_0_legacy_autosave_is_crash_backup_not_managed_save() -> void:
	var src := FileAccess.get_file_as_string(OPEN_SAVE_SOURCE)
	check_has(
		src,
		'const BACKUPS_DIRECTORY := "user://backups"',
		"legacy crash backups must remain rooted at user://backups",
	)
	check_has(
		src,
		"autosave_timer.wait_time = Global.autosave_interval * 60",
		"the P2-G baseline autosave must remain interval driven",
	)
	check_has(
		src,
		"project.backup_path = (current_session_backup.path_join(",
		"legacy autosave must continue allocating a recovery path per project",
	)
	check_has(
		src,
		"save_pxo_file(project.backup_path, true, false, project)",
		"legacy autosave must write a recovery copy instead of the formal managed save",
	)


func test_p3_0_records_legacy_startup_before_gallery_routing() -> void:
	var doc := FileAccess.get_file_as_string(BASELINE_DOC)
	check_has(
		doc,
		"RestoreSessionConfirmationDialog",
		"P3-0 must preserve evidence of the legacy global startup recovery popup",
	)
	check_has(
		doc,
		"Global.open_last_project",
		"P3-0 must preserve evidence of the legacy last-project startup gate",
	)
	check_has(
		doc,
		"the global startup recovery popup is removed",
		"the baseline must record that P3-C is allowed to replace the startup recovery flow",
	)


func test_p3_0_baseline_document_names_source_and_scope() -> void:
	check_file_exists(BASELINE_DOC, "P3-0 must ship a baseline-freeze document")
	var doc := FileAccess.get_file_as_string(BASELINE_DOC)
	check_has(
		doc,
		"ea5c0169fd1e2df1a90895ec98167e64c9fa5958",
		"the P3 baseline must name the verified P2-G source HEAD",
	)
	check_has(
		doc,
		"codex/implement-p3-project-gallery",
		"the P3 baseline must name the implementation branch",
	)
	check_has(
		doc,
		"P3-0 does not make those production changes.",
		"the baseline must explicitly defer startup/recovery production changes",
	)
	check_has(
		doc,
		"P3-0 does not implement any of the following:",
		"the baseline must explicitly record its production scope exclusions",
	)
