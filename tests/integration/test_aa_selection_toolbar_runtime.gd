extends "res://tests/test_base.gd"


func test_selection_toolbar_is_visible_above_canvas_and_hit_test_uses_viewport_coordinates(
) -> void:
	var canvas := Global.canvas
	var viewport := Global.main_viewport
	var editor := Global.control.get_node_or_null(^"MenuAndUI") as Control
	check_true(is_instance_valid(canvas), "live Canvas exists")
	check_true(is_instance_valid(viewport), "main canvas viewport exists")
	check_true(is_instance_valid(editor), "editor UI exists")
	if (
		not is_instance_valid(canvas)
		or not is_instance_valid(viewport)
		or not is_instance_valid(editor)
	):
		return

	var selection := canvas.selection
	var menu := selection.get("_selection_context_menu") as PanelContainer
	check_true(menu != null, "selection toolbar was created")
	if menu == null:
		return

	var original_editor_visible := editor.visible
	var original_processing := selection.is_processing()
	var original_menu_visible := menu.visible
	editor.visible = true
	# The test runner skips tool initialization. Test the actual GUI hosting and
	# hit geometry independently of the tool-selection predicate.
	selection.set_process(false)
	# UI3 migrates Main Canvas by temporarily removing it from the tree.
	# A reparent does not rerun _ready(), so the menu must survive _exit_tree().
	var parent_node := selection.get_parent()
	var old_index := selection.get_index()
	parent_node.remove_child(selection)
	parent_node.add_child(selection)
	parent_node.move_child(selection, old_index)
	menu.show()
	await tree.process_frame
	await tree.process_frame

	check_true(is_instance_valid(menu), "toolbar must survive UI3-style scene reparent")
	check_eq(menu.get_parent(), Global.control, "menu must be hosted by root UI")
	check_true(menu.is_visible_in_tree(), "menu is rendered above embedded canvas")
	check_true(menu.get_global_rect().has_area(), "menu has a real GUI hit rectangle")
	var local_touch := (
		viewport.get_global_transform_with_canvas().affine_inverse()
		* menu.get_global_rect().get_center()
	)
	check_true(
		selection.is_selection_menu_point(local_touch),
		"iPad touch on menu maps from SubViewport to root GUI"
	)
	check_eq(menu.get_child(0).get_child_count(), 7, "five actions plus confirm and cancel")

	menu.visible = original_menu_visible
	selection.set_process(original_processing)
	editor.visible = original_editor_visible
	await tree.process_frame


func test_selection_toolbar_hides_when_editor_is_not_visible() -> void:
	var editor := Global.control.get_node_or_null(^"MenuAndUI") as Control
	var menu := Global.canvas.selection.get("_selection_context_menu") as PanelContainer
	check_true(editor != null and menu != null, "editor and selection toolbar are available")
	if editor == null or menu == null:
		return

	var was_visible := editor.visible
	editor.visible = false
	await tree.process_frame
	check_true(not Global.main_viewport.is_visible_in_tree(), "gallery hides editor viewport")
	editor.visible = was_visible


func test_selection_toolbar_can_be_recreated_after_late_editor_binding() -> void:
	var canvas := Global.canvas
	check_true(is_instance_valid(canvas), "editor canvas is alive")
	if not is_instance_valid(canvas):
		return
	var selection := canvas.selection
	var original_menu := selection.get("_selection_context_menu") as PanelContainer
	check_true(is_instance_valid(original_menu), "selection menu is initialized")
	if not is_instance_valid(original_menu):
		return
	original_menu.free()
	selection._ensure_selection_context_menu()
	await tree.process_frame
	var menu := selection.get("_selection_context_menu") as PanelContainer
	check_true(is_instance_valid(menu), "selection toolbar initializes after UI is ready")
	if not is_instance_valid(menu):
		return
	check_eq(menu.get_parent(), Global.control, "recovered menu belongs to common root")
	check_eq(menu.get_child(0).get_child_count(), 7, "all seven touch buttons are restored")
	check_eq(
		(selection.get("_selection_action_buttons") as Array).size(),
		5,
		"only five ordinary action buttons remain after rebuilding"
	)


func test_selection_delete_button_is_connected_and_has_touch_target() -> void:
	var selection := Global.canvas.selection
	var menu := selection.get("_selection_context_menu") as PanelContainer
	check_true(is_instance_valid(menu), "global selection toolbar is initialized")
	if not is_instance_valid(menu):
		return
	var actions := selection.get("_selection_action_buttons") as Array
	check_eq(actions.size(), 5, "global toolbar has five selection actions")
	if actions.size() != 5:
		return
	var delete_button := actions[4] as Button
	check_eq(delete_button.text, tr("Delete"), "the new action is labeled Delete")
	check_true(
		delete_button.pressed.is_connected(Callable(selection, "delete_selection_contents")),
		"Delete triggers the existing selection removal path"
	)
	check_true(
		delete_button.custom_minimum_size.y >= 44.0, "Delete remains reachable by touch"
	)
