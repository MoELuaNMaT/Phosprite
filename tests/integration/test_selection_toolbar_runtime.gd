extends "res://tests/test_base.gd"


func test_selection_toolbar_is_visible_above_canvas_and_hit_test_uses_viewport_coordinates(
) -> void:
	var project := Global.current_project
	var canvas := Global.canvas
	var viewport := Global.main_viewport
	var editor := Global.control.get_node_or_null(^"MenuAndUI") as Control
	check_true(project != null, "active project is available")
	check_true(canvas != null, "live Canvas exists")
	check_true(viewport != null, "main canvas viewport exists")
	check_true(editor != null, "editor UI exists")
	if project == null or canvas == null or viewport == null or editor == null:
		return

	var selection := canvas.selection
	var original_editor_visible := editor.visible
	var previous_map := SelectionMap.new()
	previous_map.copy_from(project.selection_map)
	var original_offset := project.selection_offset
	var original_tool: Node = null
	var slot: Tools.Slot = null
	var fake_selection_tool := BaseSelectionTool.new()

	if Tools._slots.has(MOUSE_BUTTON_LEFT):
		slot = Tools._slots[MOUSE_BUTTON_LEFT]
		original_tool = slot.tool_node
		slot.tool_node = fake_selection_tool
	else:
		check_true(false, "left tool slot should be initialized")
		fake_selection_tool.free()
		return

	editor.visible = true
	project.selection_map.clear()
	project.selection_map.fill_rect(Rect2i(4, 4, 12, 12), Color.WHITE)
	project.selection_map_changed()
	await tree.process_frame
	await tree.process_frame

	var menu := selection.get("_selection_context_menu") as PanelContainer
	check_true(menu != null, "selection toolbar was created")
	if menu != null:
		check_eq(menu.get_parent(), Global.control, "menu must be in the root UI overlay")
		check_true(menu.is_visible_in_tree(), "menu must be actually visible after selection")
		check_true(
			menu.get_global_rect().has_area(), "visible selection menu must have a real hit area"
		)
		var local_touch := (
			viewport.get_global_transform_with_canvas().affine_inverse()
			* menu.get_global_rect().get_center()
		)
		check_true(
			selection.is_selection_menu_point(local_touch),
			"iPad touch on menu must be recognized in SubViewport coordinates"
		)
		check_eq(
			menu.get_child(0).get_child_count(), 6, "toolbar keeps four actions and confirm/cancel"
		)

	project.selection_map.copy_from(previous_map)
	project.selection_offset = original_offset
	project.selection_map_changed()
	slot.tool_node = original_tool
	fake_selection_tool.free()
	editor.visible = original_editor_visible
	await tree.process_frame


func test_selection_toolbar_hides_when_editor_is_not_visible() -> void:
	var editor := Global.control.get_node_or_null(^"MenuAndUI") as Control
	var selection := Global.canvas.selection
	var menu := selection.get("_selection_context_menu") as PanelContainer
	check_true(editor != null and menu != null, "editor and selection toolbar are available")
	if editor == null or menu == null:
		return
	var was_visible := editor.visible
	editor.visible = false
	await tree.process_frame
	check_true(not menu.is_visible_in_tree(), "gallery must not show the editor menu")
	editor.visible = was_visible
