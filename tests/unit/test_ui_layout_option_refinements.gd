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
		'[node name="ToolOptions" type="BoxContainer"',
		"shared tool options root must support runtime orientation",
	)
	check_has(base_scene, "vertical = true", "UI 1 must keep vertical tool options by default")
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
		"UI 3 taskbar and Other Tools entries must apply selected-tool highlighting",
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
		"current != _last_active_tool",
		"UI 3 must close persistent popups when the active tool actually changes",
	)
