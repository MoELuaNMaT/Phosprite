extends "res://tests/test_base.gd"

const Factory := preload("res://src/ProjectLibrary/ProjectFactory.gd")

const TEST_ROOT := "user://p3_e_factory_tests"


func teardown() -> void:
	_remove_tree(TEST_ROOT)


func test_p3_e_exact_presets_and_default_size() -> void:
	check_eq(
		Factory.DEFAULT_SIZE,
		Vector2i(64, 64),
		"P3-E New Project must default to 64x64",
	)
	check_eq(
		Factory.SQUARE_PRESETS,
		[
			Vector2i(16, 16),
			Vector2i(32, 32),
			Vector2i(64, 64),
			Vector2i(128, 128),
			Vector2i(256, 256),
			Vector2i(512, 512),
		],
		"New Project must expose the six approved 1:1 tiers",
	)
	check_eq(
		Factory.FOUR_THREE_PRESETS,
		[
			Vector2i(21, 16),
			Vector2i(43, 32),
			Vector2i(85, 64),
			Vector2i(171, 128),
			Vector2i(341, 256),
			Vector2i(683, 512),
		],
		"New Project must expose the six approved 4:3 tiers",
	)
	check_eq(
		Factory.SIXTEEN_NINE_PRESETS,
		[
			Vector2i(28, 16),
			Vector2i(57, 32),
			Vector2i(114, 64),
			Vector2i(228, 128),
			Vector2i(455, 256),
			Vector2i(910, 512),
		],
		"New Project must expose the six approved 16:9 tiers",
	)
	check_eq(
		Factory.all_presets().size(), 18, "New Project must expose exactly 18 built-in presets"
	)


func test_p3_e_dialog_source_uses_two_column_single_selector_layout() -> void:
	var dialog_scene := FileAccess.get_file_as_string(
		"res://src/UI/ProjectGallery/NewProjectDialog.tscn"
	)
	var dialog_src := FileAccess.get_file_as_string(
		"res://src/UI/ProjectGallery/NewProjectDialog.gd"
	)
	check_has(
		dialog_scene,
		'[node name="Content" type="HBoxContainer" parent="Margin"]',
		"New Project content must use a left/right layout",
	)
	check_has(
		dialog_scene,
		'[node name="PresetSelector" type="OptionButton"',
		"left column must expose a single preset dropdown",
	)
	check_has(
		dialog_scene,
		'[node name="CustomRatio" type="Button"',
		"ratio tabs must reserve the fourth Custom preset entry",
	)
	check_has(
		dialog_scene,
		"disabled = true",
		"reserved Custom preset entry must not expose unfinished behavior",
	)
	check_true(
		not dialog_scene.contains('name="CurrentSize"'),
		"duplicate top size preview must be removed",
	)
	check_has(
		dialog_src,
		"preset_selector.select(-1)",
		"manual custom dimensions must clear a stale preset selection",
	)


func test_p3_e_timestamp_name_and_collision_suffixes_are_stable() -> void:
	_reset_root()
	var name := (
		Factory
		. make_untitled_name(
			{
				"year": 2026,
				"month": 9,
				"day": 21,
				"hour": 15,
				"minute": 6,
				"second": 7,
			}
		)
	)
	check_eq(
		name,
		"未命名_2026-09-21_15-06-07",
		"P3-E timestamped untitled name must use the approved format",
	)
	var first := Factory.make_unique_project_path(name, TEST_ROOT)
	check_eq(
		first,
		TEST_ROOT.path_join(name + ".pxo"),
		"first project should use the unsuffixed timestamp name",
	)
	_touch(first)
	var second := Factory.make_unique_project_path(name, TEST_ROOT)
	check_eq(
		second,
		TEST_ROOT.path_join(name + "_1.pxo"),
		"first collision must use _1",
	)
	_touch(second)
	var third := Factory.make_unique_project_path(name, TEST_ROOT)
	check_eq(
		third,
		TEST_ROOT.path_join(name + "_2.pxo"),
		"second collision must use _2",
	)


func test_p3_e_source_contract_is_ipad_specific_and_save_before_editor() -> void:
	var shell_src := FileAccess.get_file_as_string("res://src/AppShell/AppShellController.gd")
	var gallery_src := FileAccess.get_file_as_string(
		"res://src/UI/ProjectGallery/ProjectGallery.gd"
	)
	var main_scene := FileAccess.get_file_as_string("res://src/Main.tscn")
	var ipad_dialog := FileAccess.get_file_as_string(
		"res://src/UI/ProjectGallery/NewProjectDialog.gd"
	)
	var desktop_dialog := FileAccess.get_file_as_string("res://src/UI/Dialogs/CreateNewImage.gd")

	check_has(
		gallery_src,
		"signal new_project_requested",
		"P3-E must enter from the existing Gallery New button contract",
	)
	check_has(
		shell_src,
		"if not managed_mode or not is_instance_valid(new_project_dialog):",
		"desktop/non-managed shells must not open the iPad New Project panel",
	)
	check_has(
		main_scene,
		'path="res://src/UI/ProjectGallery/NewProjectDialog.tscn"',
		"P3-E must use a dedicated Gallery New Project scene",
	)
	check_has(
		ipad_dialog,
		"ProjectFactoryScript.DEFAULT_SIZE",
		"iPad New Project UI must own the P3-E 64x64 default",
	)
	check_has(
		desktop_dialog,
		"var current_content := Content.BLANK",
		"desktop CreateNewImage must retain its existing content workflow",
	)
	check_has(
		desktop_dialog,
		"fill_color_node.color = Global.default_fill_color",
		"desktop CreateNewImage must retain its existing fill-color workflow",
	)

	var save_call := shell_src.find(
		'save_coordinator.flush_project(project, "new_project", target_path)'
	)
	var editor_call := shell_src.find("show_editor()", save_call)
	check_true(save_call >= 0, "P3-E must force the initial managed PXO save")
	check_true(
		editor_call > save_call,
		"P3-E must enter Editor only after the initial PXO save succeeds",
	)
	check_has(
		shell_src,
		"_rollback_uncommitted_project(project, target_path)",
		"failed first save must roll back the transient project",
	)


func _touch(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_8(1)
		file.close()


func _reset_root() -> void:
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
