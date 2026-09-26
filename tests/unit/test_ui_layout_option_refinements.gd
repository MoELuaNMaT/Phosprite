extends "res://tests/test_base.gd"


func test_bucket_and_curve_modes_use_exclusive_buttons() -> void:
	var bucket_scene := FileAccess.get_file_as_string("res://src/Tools/DesignTools/Bucket.tscn")
	var curve_scene := FileAccess.get_file_as_string("res://src/Tools/DesignTools/CurveTool.tscn")

	check_has(bucket_scene, 'id="ButtonGroup_fill_area"', "Bucket Fill area must use a ButtonGroup")
	check_has(bucket_scene, 'id="ButtonGroup_fill_with"', "Bucket Fill with must use a ButtonGroup")
	check_true(
		not bucket_scene.contains('[node name="FillAreaOptions" type="OptionButton"'),
		"Bucket Fill area must no longer be an OptionButton",
	)
	check_true(
		not bucket_scene.contains('[node name="FillWithOptions" type="OptionButton"'),
		"Bucket Fill with must no longer be an OptionButton",
	)
	check_has(
		curve_scene,
		'id="ButtonGroup_bezier_mode"',
		"Curve Chained/Single mode must use a ButtonGroup",
	)
	check_true(
		not curve_scene.contains('[node name="BezierMode" type="OptionButton"'),
		"Curve mode must no longer use an OptionButton",
	)


func test_profiles_2_and_3_request_horizontal_tool_options_only_in_their_presentations() -> void:
	var base_scene := FileAccess.get_file_as_string("res://src/Tools/BaseTool.tscn")
	var base_src := FileAccess.get_file_as_string("res://src/Tools/BaseTool.gd")
	var profile_2 := FileAccess.get_file_as_string("res://src/UI/Workspace/WorkspaceUIProfile2.gd")
	var profile_3 := FileAccess.get_file_as_string("res://src/UI/Workspace/WorkspaceUIProfile3.gd")

	check_has(
		base_scene,
		'[node name="ToolOptions" type="GridContainer"',
		"shared tool options root must support title-over-control horizontal grouping",
	)
	check_has(base_scene, "columns = 1", "UI 1 must keep one-column vertical options by default")
	check_has(
		base_src,
		"func set_horizontal_option_layout(enabled: bool)",
		"shared tool options must expose an explicit presentation-only orientation switch",
	)
	check_has(
		profile_2,
		"set_horizontal_option_layout(true)",
		"UI 2 must opt into horizontal tool options",
	)
	check_has(
		profile_3,
		"set_horizontal_option_layout(true)",
		"UI 3 must opt into horizontal tool options",
	)
	check_has(
		profile_2,
		"_top_tools_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL",
		"UI 2 top tools host must consume remaining toolbar width so icons align right",
	)


func test_profile_3_popups_are_persistent_and_selected_tools_are_highlighted() -> void:
	var profile_3 := FileAccess.get_file_as_string("res://src/UI/Workspace/WorkspaceUIProfile3.gd")

	check_has(
		profile_3,
		"const SELECTED_TOOL_TINT",
		"UI 3 must define a distinct selected-tool tint",
	)
	check_has(
		profile_3,
		"_apply_tool_button_highlight",
		"UI 3 taskbar entries must apply selected-tool highlighting",
	)
	check_has(
		profile_3,
		"set_process_input(false)",
		"UI 3 must not globally dismiss popups from unrelated pointer input",
	)
	check_true(
		not profile_3.contains("func _input(event: InputEvent)"),
		"UI 3 popup lifetime must no longer be driven by click-outside input",
	)
	check_has(
		profile_3,
		"_refresh_config_panel.call_deferred()",
		"UI 3 must keep the config panel open and refresh it when the active tool changes",
	)


func test_tool_profile_switch_contract_keeps_one_authoritative_options_node() -> void:
	var tools_src := FileAccess.get_file_as_string("res://src/Autoload/Tools.gd")
	var migration_src := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceEditorMigration.gd"
	)
	var controller_src := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceUIProfileController.gd"
	)
	check_has(
		tools_src,
		"func synchronize_tool_panel(button: int) -> bool:",
		"tool runtime must be able to purge stale BaseTool option nodes",
	)
	check_has(
		tools_src,
		"child == slot.tool_node or child is not BaseTool",
		"tool synchronization must preserve only the authoritative slot node",
	)
	check_has(
		migration_src,
		"func sync_active_tool_presentation() -> bool:",
		"workspace migration must expose active-tool presentation synchronization",
	)
	check_has(
		controller_src,
		"applied = migration.sync_active_tool_presentation()",
		"UI profile switches must resync tool state after applying the target layout",
	)


func test_ui2_keeps_crop_and_color_picker_optionless() -> void:
	var profile_2 := FileAccess.get_file_as_string("res://src/UI/Workspace/WorkspaceUIProfile2.gd")
	check_has(
		profile_2,
		'const NO_POPUP_TOOLS: Array[StringName] = [&"Crop", &"ColorPicker"]',
		"UI 2 Crop and Color Picker must not expose profile popup options",
	)


func test_ui3_moves_family_selection_into_persistent_config_panel() -> void:
	var profile_3 := FileAccess.get_file_as_string("res://src/UI/Workspace/WorkspaceUIProfile3.gd")
	check_has(
		profile_3,
		"func _refresh_family_row(current: StringName)",
		"UI 3 config panel must own selection/shape family switching",
	)
	check_has(
		profile_3,
		"button.pressed.connect(_on_family_tool_pressed.bind(tool_name))",
		"UI 3 family choices must directly select the requested family tool",
	)
	check_has(
		profile_3,
		"or (tool_name in SELECTION_TOOLS and tool_name != SELECTION_TOOLBAR_REP)",
		"UI 3 taskbar must collapse selection children into one first-level family entry",
	)
	check_has(
		profile_3,
		"or (tool_name in SHAPE_TOOLS and tool_name != SHAPE_TOOLBAR_REP)",
		"UI 3 taskbar must collapse shape children into one first-level family entry",
	)


func test_ui1_mode_buttons_reserve_full_text_width() -> void:
	var base_src := FileAccess.get_file_as_string("res://src/Tools/BaseTool.gd")
	var builtins_src := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceBuiltinModules.gd"
	)
	check_has(
		base_src,
		"const MODE_BUTTON_MIN_WIDTH := 112.0",
		"exclusive mode buttons must reserve enough width for their full labels",
	)
	check_has(
		base_src,
		"button.clip_text = false",
		"exclusive mode button text must not be clipped",
	)
	check_has(
		builtins_src,
		"Vector2(168.0, 220.0), Vector2(176.0, 520.0)",
		"UI 1 Tools module must be wide enough for readable mode buttons",
	)


func test_saved_ui_profile_waits_for_real_tools_readiness_on_startup() -> void:
	var tools_src := FileAccess.get_file_as_string("res://src/Autoload/Tools.gd")
	var ui_src := FileAccess.get_file_as_string("res://src/UI/UI.gd")
	check_has(
		tools_src, "signal runtime_ready", "Tools must expose deterministic startup readiness"
	)
	check_has(
		tools_src,
		"_runtime_ready = true",
		"Tools must mark itself ready only after initial tool setup completes",
	)
	check_has(
		ui_src,
		"await Tools.runtime_ready",
		"Workspace startup must wait for Tools before restoring profile presentation",
	)
	check_true(
		not ui_src.contains("for _attempt in range(4)"),
		"saved UI profile restore must not depend on a four-frame timing guess",
	)
	check_has(
		ui_src,
		"workspace_migration.sync_workspace_content_visibility()",
		"saved profile startup must re-apply its custom composition after Tools is ready",
	)
