extends "res://tests/test_base.gd"


func test_curve_touch_activation_survives_real_single_tool_mode() -> void:
	var previous_single_tool_mode := Global.single_tool_mode
	Global.single_tool_mode = true
	await tree.process_frame
	await tree.process_frame

	var tool_buttons := Tools._tool_buttons
	check_true(is_instance_valid(tool_buttons), "live editor must expose ToolButtons")
	if not is_instance_valid(tool_buttons):
		Global.single_tool_mode = previous_single_tool_mode
		return

	var curve: Tools.Tool = Tools.tools.get("Curve")
	check_true(curve != null, "Curve must exist in the live tool registry")
	if curve == null or not is_instance_valid(curve.button_node):
		Global.single_tool_mode = previous_single_tool_mode
		return
	var curve_button := curve.button_node as BaseButton
	check_true(curve_button.is_visible_in_tree(), "Curve button must be visible before touch activation")

	var touch_point := curve_button.get_global_rect().get_center()
	var press := InputEventScreenTouch.new()
	press.device = 0
	press.index = 91
	press.position = touch_point
	press.pressed = true
	check_true(
		bool(tool_buttons.call("_handle_tool_touch", press)),
		"real Curve button press must be owned by ToolButtons"
	)

	var release := InputEventScreenTouch.new()
	release.device = 0
	release.index = 91
	release.position = touch_point
	release.pressed = false
	check_true(
		bool(tool_buttons.call("_handle_tool_touch", release)),
		"real Curve button release must schedule one activation"
	)

	await tree.process_frame
	await tree.process_frame
	await tree.process_frame

	for button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		check_true(Tools._slots.has(button), "single-tool mode must keep both tool slots")
		if not Tools._slots.has(button):
			continue
		var slot: Tools.Slot = Tools._slots[button]
		check_true(
			is_instance_valid(slot.tool_node),
			"Curve activation must leave a live Tool Options node in each slot"
		)
		if not is_instance_valid(slot.tool_node):
			continue
		check_eq(String(slot.tool_node.name), "Curve", "both slots must resolve to Curve")
		check_true(
			slot.tool_node.get_node_or_null("BezierOptions/BezierMode") is OptionButton,
			"Curve Bezier mode control must survive _ready/load_config/update_config"
		)
		check_true(
			slot.tool_node.get_node_or_null("FillCheckbox") is CheckBox,
			"Curve Fill control must survive activation"
		)

	Tools.assign_tool("Pencil", MOUSE_BUTTON_LEFT)
	await tree.process_frame
	await tree.process_frame
	check_eq(
		String(Tools._slots[MOUSE_BUTTON_LEFT].tool_node.name),
		"Pencil",
		"leaving Curve after touch activation must remain safe"
	)

	Global.single_tool_mode = previous_single_tool_mode
	await tree.process_frame
