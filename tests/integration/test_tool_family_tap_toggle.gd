extends "res://tests/test_base.gd"

const TOOL_BUTTONS := preload("res://src/UI/ToolsPanel/ToolButtons.gd")
const PROFILE_3 := preload("res://src/UI/Workspace/WorkspaceUIProfile3.gd")


func test_folded_selection_and_shape_groups_use_tap_toggle_instead_of_hold() -> void:
	for is_selected in [false, true]:
		for is_open in [false, true]:
			var expected := (
				TOOL_BUTTONS.FamilyTapAction.SELECT
				if not is_selected
				else (
					TOOL_BUTTONS.FamilyTapAction.CLOSE
					if is_open
					else TOOL_BUTTONS.FamilyTapAction.OPEN
				)
			)
			check_eq(
				TOOL_BUTTONS.resolve_ios_family_tap(is_selected, is_open),
				expected,
				"selected and open state selects, opens or closes predictably",
			)

	var source := FileAccess.get_file_as_string("res://src/UI/ToolsPanel/ToolButtons.gd")
	check_true(
		not source.contains("IOS_SELECTION_MENU_LONG_PRESS_SECONDS"),
		"selection group no longer requires a long press",
	)
	check_true(
		not source.contains("IOS_SHAPE_MENU_LONG_PRESS_SECONDS"),
		"shape group no longer requires a long press",
	)
	check_true(
		not source.contains("_try_open_ios_selection_menu"),
		"no delayed selection popup can open after a tap or drag",
	)
	check_true(
		not source.contains("_try_open_ios_shape_menu"),
		"no delayed shape popup can open after a tap or drag",
	)
	check_has(
		source,
		'call_deferred(\n\t\t"_commit_touch_tool_activation"',
		"tool replacement and family popup changes wait until touch dispatch finishes",
	)
	check_has(
		source,
		'"menu_was_open": (',
		"touch remembers an already-open menu even if the system auto-dismisses it",
	)


func test_folded_family_menu_toggles_for_both_tool_groups_and_ui3_proxy() -> void:
	var original_slots := Tools._slots.duplicate()
	var root := Control.new()
	root.size = Vector2(800, 600)
	tree.root.add_child(root)
	var toolbar := TOOL_BUTTONS.new()
	root.add_child(toolbar)
	var selection_anchor := Button.new()
	selection_anchor.name = &"RectSelect"
	selection_anchor.position = Vector2(30, 30)
	selection_anchor.size = Vector2(36, 36)
	root.add_child(selection_anchor)
	var shape_anchor := Button.new()
	shape_anchor.name = &"LineTool"
	shape_anchor.position = Vector2(730, 30)
	shape_anchor.size = Vector2(36, 36)
	root.add_child(shape_anchor)
	var selection_menu := PopupMenu.new()
	selection_menu.name = &"SelectionFamilyMenu"
	selection_menu.add_item("Rectangle", 0)
	root.add_child(selection_menu)
	var shape_menu := PopupMenu.new()
	shape_menu.name = &"ShapeFamilyMenu"
	shape_menu.add_item("Line", 0)
	root.add_child(shape_menu)
	toolbar.set("_ios_selection_menu", selection_menu)
	toolbar.set("_ios_shape_menu", shape_menu)
	var slot := Tools.Slot.new("Left tool")
	slot.button = MOUSE_BUTTON_LEFT
	slot.tool_node = Node.new()
	slot.tool_node.name = &"RectSelect"
	root.add_child(slot.tool_node)
	Tools._slots[MOUSE_BUTTON_LEFT] = slot

	toolbar.toggle_ios_family_menu(true, selection_anchor)
	check_true(selection_menu.visible, "selected selection group opens on tap")
	check_true(not shape_menu.visible, "selection tap does not open the shape menu")
	toolbar.toggle_ios_family_menu(true, selection_anchor)
	check_true(not selection_menu.visible, "tapping the same selected group closes it")
	toolbar._apply_ios_family_tap(true, selection_anchor, true)
	check_true(not selection_menu.visible, "release after auto-dismiss does not reopen menu")

	slot.tool_node.name = &"LineTool"
	toolbar.toggle_ios_family_menu(false, shape_anchor)
	check_true(shape_menu.visible, "selected shape group opens on tap")
	check_true(not selection_menu.visible, "only one family menu is open")
	toolbar.toggle_ios_family_menu(false, shape_anchor)
	check_true(not shape_menu.visible, "second shape tap closes its menu")
	check_true(
		not toolbar._is_ios_family_current(true),
		"unselected family does not count as selected",
	)
	check_eq(
		TOOL_BUTTONS.resolve_ios_family_tap(false, false),
		TOOL_BUTTONS.FamilyTapAction.SELECT,
		"first tap on an inactive group selects its saved tool without opening a menu",
	)

	var ui3 := PROFILE_3.new()
	root.add_child(ui3)
	ui3.active = true
	ui3.set("_tool_buttons", toolbar)
	# UI3 proxies have a different button name; their source is the family representative.
	ui3._on_toolbar_tool_pressed(shape_anchor, shape_anchor)
	check_true(shape_menu.visible, "UI3 selected shape proxy opens the same family menu")
	ui3._on_toolbar_tool_pressed(shape_anchor, shape_anchor)
	check_true(not shape_menu.visible, "UI3 selected proxy closes the same family menu")

	toolbar._hide_ios_family_menus()
	Tools._slots = original_slots
	root.queue_free()
	await tree.process_frame


func test_other_long_press_interactions_are_preserved() -> void:
	var canvas_adapter := FileAccess.get_file_as_string(
		"res://src/InputAdapter/CanvasInputAdapter.gd"
	)
	check_true(
		canvas_adapter.contains("FINGER_LONG_PRESS_SECONDS"),
		"canvas long-press sampling must not be removed with tool group menus",
	)
