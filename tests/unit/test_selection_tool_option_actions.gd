extends "res://tests/test_base.gd"


func test_selection_actions_use_adaptive_icon_flow_for_all_selection_tools() -> void:
	var tool := BaseSelectionTool.new()
	tool._create_selection_actions()
	var actions := tool.get_node_or_null(^"SelectionActions") as VBoxContainer
	check_true(actions != null, "all selection tools inherit the same action section")
	if actions == null:
		tool.free()
		return
	check_eq(actions.get_child_count(), 5, "heading, quick actions, wrap, modify, modify choices")
	check_true(actions.get_child(0) is Label, "actions have a clear section heading")
	var quick := actions.get_node_or_null(^"QuickActions") as HFlowContainer
	check_true(quick != null, "quick actions can wrap in a narrow tool options panel")
	if quick != null:
		check_eq(quick.get_child_count(), 5, "all five selection commands remain available")
		check_eq(
			quick.alignment,
			FlowContainer.ALIGNMENT_CENTER,
			"wrapped action rows center in the panel"
		)
		for child in quick.get_children():
			var button := child as Button
			check_true(button != null, "quick selection action is a button")
			if button != null:
				check_true(not button.text.is_empty(), "quick icons show a caption below each icon")
				check_eq(
					button.vertical_icon_alignment, VERTICAL_ALIGNMENT_TOP, "caption is under icon"
				)
				check_true(button.icon != null, "quick actions have licensed icons")
				check_true(not button.tooltip_text.is_empty(), "quick actions keep tooltips")
				check_eq(
					button.custom_minimum_size,
					Vector2(36, 48),
					"touch controls reserve room for caption"
				)
				check_true(button.pressed.get_connections().size() > 0, "original command is wired")
	check_true(
		actions.get_node_or_null(^"WrapStrokes") is CheckBox, "wrap toggle remains independent"
	)
	var modify_toggle := actions.get_node_or_null(^"ModifySelection") as Button
	check_true(modify_toggle != null, "Modify has an icon entry")
	var modify := actions.get_node_or_null(^"ModifyActions") as HFlowContainer
	check_true(modify != null, "Modify uses adaptive icon layout")
	if modify != null:
		check_eq(modify.get_child_count(), 4, "expand, shrink, border, center remain")
		check_eq(modify.alignment, FlowContainer.ALIGNMENT_CENTER, "modify rows remain centered")
		check_true(not modify.visible, "Modify actions start collapsed")
		for child in modify.get_children():
			var button := child as Button
			check_true(button != null and button.icon != null, "Modify choices are icon buttons")
	if modify_toggle != null:
		check_eq(modify_toggle.text, "Modify", "Modify trigger explains the icon")
		check_eq(
			modify_toggle.vertical_icon_alignment,
			VERTICAL_ALIGNMENT_TOP,
			"Modify icon is above caption"
		)
		check_true(modify_toggle.icon != null, "Modify trigger has an icon")
	if modify_toggle != null and modify != null:
		modify_toggle.button_pressed = true
		check_true(modify.visible, "Modify actions expand inside Tool Options")
	tool.free()


func test_selection_action_states_keep_reselect_available_after_clear() -> void:
	var source := FileAccess.get_file_as_string("res://src/Tools/BaseSelectionTool.gd")
	check_has(source, "var has_selection := project.has_selection", "read selection state")
	check_has(
		source,
		"not has_selection and not project.prev_selection_map.is_invisible()",
		"Reselect is available only after a prior selection is cleared"
	)
	check_has(source, "button.visible = has_selection", "hide irrelevant Clear and Invert buttons")
	check_has(
		source, "_selection_modify_toggle.visible = has_selection", "hide Modify without selection"
	)
	check_has(
		source, "_selection_modify_group.visible = false", "collapse Modify when no selection"
	)


func test_selection_actions_use_existing_handlers_and_ios_visibility() -> void:
	var source := FileAccess.get_file_as_string("res://src/Tools/BaseSelectionTool.gd")
	check_has(
		source, "Global.top_menu_container.select_menu_id_pressed(id)", "reuse select actions"
	)
	check_has(source, '"_selection_modify_submenu_id_pressed"', "reuse Modify dialogs")
	check_has(source, '&"SelectionActions"', "the iOS compact options keep the action group")
	check_has(source, "SelectionNode.flag_tilemode", "Wrap Strokes preserves shared state")
	var menu := FileAccess.get_file_as_string("res://src/UI/TopMenuContainer/TopMenuContainer.gd")
	check_has(
		menu,
		"menu_bar.set_menu_hidden(",
		"the Select popup remains in the source bar but is hidden in compact mode"
	)
	check_has(menu, "select_menu.id_pressed.connect(select_menu_id_pressed)", "shortcuts remain")
