extends "res://tests/test_base.gd"


func test_selection_actions_are_vertical_and_shared_by_all_selection_tools() -> void:
	var tool := BaseSelectionTool.new()
	tool._create_selection_actions()
	var actions := tool.get_node_or_null(^"SelectionActions") as VBoxContainer
	check_true(actions != null, "all selection tools inherit a vertical action container")
	if actions == null:
		tool.free()
		return
	check_eq(actions.get_child_count(), 9, "five actions, a wrap toggle and Modify group")
	check_true(actions.get_child(0) is Label, "actions have a clear section heading")
	for index in range(1, 6):
		var button := actions.get_child(index) as Button
		check_true(button != null, "selection action is a tappable button")
		if button != null:
			check_true(button.custom_minimum_size.x <= 54.0, "button fits narrow tool column")
	check_true(actions.get_node_or_null(^"WrapStrokes") is CheckBox, "wrap option is a toggle")
	var modify_toggle := actions.get_node_or_null(^"ModifySelection") as Button
	check_true(modify_toggle != null, "Modify has an entry")
	var modify := actions.get_node_or_null(^"ModifyActions") as VBoxContainer
	check_true(modify != null, "Modify includes its four original operations")
	if modify != null:
		check_eq(modify.get_child_count(), 4, "expand, shrink, border, center remain")
		check_true(not modify.visible, "Modify actions start collapsed")
	if modify_toggle != null and modify != null:
		modify_toggle.button_pressed = true
		check_true(modify.visible, "Modify actions expand inside Tool Options")
	tool.free()


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
