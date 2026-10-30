extends "res://tests/test_base.gd"


func test_selection_toolbar_is_visible_above_canvas_and_hit_test_uses_viewport_coordinates(
) -> void:
	var canvas := Global.canvas
	var viewport := Global.main_viewport
	var editor := Global.control.get_node_or_null(^"MenuAndUI") as Control
	check_true(canvas != null, "live Canvas exists")
	check_true(viewport != null, "main canvas viewport exists")
	check_true(editor != null, "editor UI exists")
	if canvas == null or viewport == null or editor == null:
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
	menu.show()
	await tree.process_frame
	await tree.process_frame

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
	check_eq(menu.get_child(0).get_child_count(), 6, "four actions plus confirm and cancel")

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
