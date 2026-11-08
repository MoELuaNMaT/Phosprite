extends "res://tests/test_base.gd"


func test_legacy_curve_checkpoint_does_not_trigger_startup_dialog() -> void:
	var tools_source := FileAccess.get_file_as_string("res://src/Autoload/Tools.gd")
	var curve_source := FileAccess.get_file_as_string("res://src/Tools/DesignTools/CurveTool.gd")
	check_true(
		not tools_source.contains("_report_previous_curve_activation_crash"),
		"startup cannot report an in-progress current CurveTool initialization as a previous crash",
	)
	check_true(
		not tools_source.contains("func write_curve_activation_phase"),
		"Tools must not overwrite one shared crash marker from two asynchronous tool slots",
	)
	check_true(
		not curve_source.contains("write_curve_activation_phase"),
		"CurveTool must not synchronously write a checkpoint during initialization or config",
	)
	check_has(
		tools_source,
		"DirAccess.remove_absolute(LEGACY_CURVE_ACTIVATION_TRACE_PATH)",
		"the obsolete trace is cleaned when launching iOS",
	)
	var cleanup := tools_source.find(
		"DirAccess.remove_absolute(LEGACY_CURVE_ACTIVATION_TRACE_PATH)"
	)
	var restore := tools_source.find("set_tool(tool_name, MOUSE_BUTTON_LEFT)")
	check_true(
		cleanup > 0 and cleanup < restore,
		"the old trace must be removed before the user-selected tools are restored",
	)


func test_curve_tool_can_initialize_both_saved_tool_slots() -> void:
	# The regression runner loads Main.tscn but Tools skips automatic initialization
	# in headless mode. Recreate the two real tool slots and use Tools.set_tool(),
	# including its frame-delayed config sharing.
	var original_slots := Tools._slots.duplicate()
	var original_panels := Tools._panels.duplicate()
	var original_share_options := Global.share_options_between_tools
	var original_move_guides := Global.move_guides_on_canvas
	var original_left_tool_types := Tools._left_tools_per_layer_type.duplicate()
	var original_right_tool_types := Tools._right_tools_per_layer_type.duplicate()
	var original_config_connection := Tools.config_changed.is_connected(Tools.attempt_config_share)
	var error_dialog_was_visible := Global.error_dialog.visible
	var left_panel := Control.new()
	var right_panel := Control.new()
	left_panel.name = &"CurveLeftSlotFixture"
	right_panel.name = &"CurveRightSlotFixture"
	tree.root.add_child(left_panel)
	tree.root.add_child(right_panel)
	var left_slot := Tools.Slot.new("Left tool")
	left_slot.button = MOUSE_BUTTON_LEFT
	left_slot.color = Color.BLACK
	var right_slot := Tools.Slot.new("Right tool")
	right_slot.button = MOUSE_BUTTON_RIGHT
	right_slot.color = Color.WHITE
	Tools._slots[MOUSE_BUTTON_LEFT] = left_slot
	Tools._slots[MOUSE_BUTTON_RIGHT] = right_slot
	Tools._panels[MOUSE_BUTTON_LEFT] = left_panel
	Tools._panels[MOUSE_BUTTON_RIGHT] = right_panel
	Global.share_options_between_tools = true

	Tools.set_tool("CurveTool", MOUSE_BUTTON_LEFT)
	Tools.set_tool("CurveTool", MOUSE_BUTTON_RIGHT)
	await tree.process_frame
	await tree.process_frame
	for button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var slot := Tools._slots[button] as Tools.Slot
		var curve := slot.tool_node as BaseTool
		check_true(curve != null, "CurveTool is restored in slot %d" % button)
		if curve == null:
			continue
		check_true(curve.is_node_ready(), "CurveTool finishes ready in slot %d" % button)
		check_true(
			curve.get_node_or_null("BezierOptions/BezierMode/Chained") is Button,
			"curve's chain mode remains available in slot %d" % button,
		)
		check_true(
			curve.get_node_or_null("BezierOptions/BezierMode/Single") is Button,
			"curve's single mode remains available in slot %d" % button,
		)
		check_true(
			curve.get_node_or_null("Brush/BrushSize") is ValueSlider,
			"curve retains its shared brush size control in slot %d" % button,
		)
		check_true(
			(curve.get_node("Brush/BrushSize") as ValueSlider).tool_vertical_drag,
			"the new vertical numeric control works during CurveTool restoration",
		)
		var config := curve.get_config()
		config["bezier_mode"] = 1
		curve.set_config(config)
		curve.update_config()
		check_true(
			(curve.get_node("BezierOptions/BezierMode/Single") as Button).button_pressed,
			"CurveTool config loads and selects single mode in slot %d" % button,
		)

	check_eq(
		Global.error_dialog.visible,
		error_dialog_was_visible,
		"restoring CurveTool does not raise an unexpected error dialog",
	)
	# Do not keep temporary nodes or overwrite tool registry state for other suites.
	Tools._slots = original_slots
	Tools._panels = original_panels
	Tools._left_tools_per_layer_type = original_left_tool_types
	Tools._right_tools_per_layer_type = original_right_tool_types
	Global.share_options_between_tools = original_share_options
	Global.move_guides_on_canvas = original_move_guides
	if not original_config_connection and Tools.config_changed.is_connected(Tools.attempt_config_share):
		Tools.config_changed.disconnect(Tools.attempt_config_share)
	left_panel.queue_free()
	right_panel.queue_free()
	await tree.process_frame
