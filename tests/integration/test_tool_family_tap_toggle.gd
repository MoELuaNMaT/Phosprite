extends "res://tests/test_base.gd"

const TOOL_BUTTONS := preload("res://src/UI/ToolsPanel/ToolButtons.gd")


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


func test_family_popup_placement_stays_visible_on_both_sides_of_ipad() -> void:
	var screen := Vector2(800, 600)
	var menu := Vector2(190, 260)
	var selection_rect := Rect2(Vector2(30, 60), Vector2(36, 36))
	var shape_rect := Rect2(Vector2(730, 60), Vector2(36, 36))
	var selection_position := TOOL_BUTTONS.ios_family_menu_position(selection_rect, menu, screen)
	var shape_position := TOOL_BUTTONS.ios_family_menu_position(shape_rect, menu, screen)
	check_true(
		selection_position.x > selection_rect.end.x,
		"left toolbar opens menu to the right of its icon",
	)
	check_true(
		shape_position.x < shape_rect.position.x,
		"UI3 right taskbar opens menu to the left of its icon",
	)
	for position in [selection_position, shape_position]:
		check_true(position.x >= 0, "popup stays inside left viewport edge")
		check_true(position.y >= 0, "popup stays inside top viewport edge")
		check_true(position.x + menu.x <= screen.x, "popup stays inside right viewport edge")
		check_true(position.y + menu.y <= screen.y, "popup stays inside bottom viewport edge")


func test_ui3_family_proxy_uses_same_toggle_and_keeps_other_settings() -> void:
	var source := FileAccess.get_file_as_string("res://src/UI/Workspace/WorkspaceUIProfile3.gd")
	check_has(
		source,
		'_tool_buttons.call("toggle_ios_family_menu", selection_family, _proxy)',
		"selected UI3 family icon opens or closes the shared family chooser",
	)
	check_has(
		source,
		"_source_represents_tool(source, _current_left_tool_name())",
		"UI3 only opens family choices for its currently active family",
	)
	check_has(
		source,
		"_select_tool_and_toggle_options(target)",
		"other UI3 buttons continue to open and close their tool settings",
	)
	check_has(
		source,
		"_refresh_taskbar.call_deferred()",
		"UI3 keeps active tool highlighting consistent after family clicks",
	)


func test_other_long_press_interactions_are_preserved() -> void:
	var canvas_adapter := FileAccess.get_file_as_string(
		"res://src/InputAdapter/CanvasInputAdapter.gd"
	)
	check_true(
		canvas_adapter.contains("FINGER_LONG_PRESS_SECONDS"),
		"canvas long-press sampling must not be removed with tool group menus",
	)
