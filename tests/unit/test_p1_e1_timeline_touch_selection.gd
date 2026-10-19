extends "res://tests/test_base.gd"

const BOOTSTRAP := preload("res://src/UI/Timeline/LayerPanelTouchBootstrap.gd")
const MANAGER := preload("res://src/UI/Timeline/TimelineTouchSelectionManager.gd")
const BOOTSTRAP_SOURCE := "res://src/UI/Timeline/LayerPanelTouchBootstrap.gd"
const MANAGER_SOURCE := "res://src/UI/Timeline/TimelineTouchSelectionManager.gd"


func test_e1_installs_one_ios_timeline_selection_manager() -> void:
	var src := FileAccess.get_file_as_string(BOOTSTRAP_SOURCE)
	check_has(
		src,
		"TimelineTouchSelectionManager.gd",
		"the existing iOS bootstrap must install the E1 Timeline selection manager",
	)
	check_has(
		src,
		"timeline.has_node(TIMELINE_SELECTION_MANAGER_NAME)",
		"multiple Layer rows must not create duplicate Timeline selection managers",
	)


func test_e1_is_ios_only_and_e2_reuses_the_same_touch_manager() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(src, 'OS.get_name() != "iOS"', "Timeline touch manager must remain iOS-only")
	check_has(
		src,
		"Before long-press ownership, movement belongs to the existing Timeline scroll views",
		"E1 scroll arbitration must remain intact before E2 long-press ownership",
	)
	check_true(
		not ("undo_redo" in src),
		"the shared E1/E2 touch manager must delegate business transactions to native controls",
	)


func test_timeline_toolbar_has_no_obsolete_select_mode_button() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_true(
		not src.contains("TimelineMultiSelectButton"),
		"the iPad Timeline toolbar must not create the obsolete Select toggle",
	)
	check_true(
		not src.contains("IOS_MULTI_SELECT_WIDTH"),
		"remove unused selection button geometry",
	)
	check_true(
		not src.contains("_multi_select_enabled"),
		"normal taps must no longer depend on a separate selection mode",
	)


func test_normal_touch_collapses_to_one_cel_or_current_layer_frame_cel() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(
		src,
		"project.selected_cels.append([frame, layer])",
		"normal Cel touch must select the tapped Cel through selected_cels",
	)
	check_has(src, "project.change_cel(frame, layer)", "Cel touch must use Project.change_cel")
	check_has(
		src,
		"project.selected_cels.append([frame, project.current_layer])",
		"normal Frame touch must select the current-layer Cel in that Frame",
	)
	check_has(
		src,
		"project.change_cel(frame, project.current_layer)",
		"Frame touch must keep Project as the selection authority",
	)


func test_direct_touch_selects_one_cel_or_frame_without_an_old_mode_state() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	var cel_begin := src.find("func _select_cel_for_touch(")
	var frame_begin := src.find("func _select_frame_for_touch(")
	var context_begin := src.find("func _show_existing_context_menu(")
	check_true(
		cel_begin >= 0 and frame_begin > cel_begin and context_begin > frame_begin,
		"both direct-touch selection handlers must remain available",
	)
	if cel_begin < 0 or frame_begin <= cel_begin or context_begin <= frame_begin:
		return
	var cel_logic := src.substr(cel_begin, frame_begin - cel_begin)
	var frame_logic := src.substr(frame_begin, context_begin - frame_begin)
	check_has(cel_logic, "project.selected_cels.clear()", "Cel tap clears prior selection")
	check_has(frame_logic, "project.selected_cels.clear()", "Frame tap clears prior selection")
	check_has(
		cel_logic, "project.selected_cels.append([frame, layer])", "Cel tap sets only its own Cel"
	)
	check_has(
		frame_logic,
		"project.selected_cels.append([frame, project.current_layer])",
		"Frame tap sets only the current-layer Cel",
	)
	check_true(
		not cel_logic.contains("project.selected_cels.erase("),
		"old tap-to-toggle multi-selection must not reactivate",
	)


func test_stationary_long_press_opens_existing_cel_and_frame_context_menus() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_eq(MANAGER.IOS_TOUCH_CONTEXT_HOLD_MSEC, 650, "stationary menu hold is 650 ms")
	check_has(src, 'target.get_node_or_null("PopupMenu")', "reuse existing Cel/Frame menu")
	check_has(src, "popup.popup_on_parent", "hold opens native context menu")
	check_has(src, "_prepare_frame_popup", "Frame menu refreshes disabled actions")
	check_has(src, 'candidate["menu_opened"] = true', "only open menu once per hold")
	check_has(src, 'if bool(candidate.get("menu_opened", false)):', "release cannot select")
	check_true(not src.contains("IOS_TOUCH_DOUBLE_TAP_MSEC"), "double tap no longer opens menu")
	check_true(not src.contains("_register_tap("), "remove double-tap recognizer")
	check_has(src, "_apply_touch_selection(kind, target)", "repeated taps remain single taps")


func test_touch_selection_suppresses_synthetic_mouse_but_preserves_physical_pointer() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(
		src,
		"control.mouse_filter = Control.MOUSE_FILTER_IGNORE",
		"direct touch must suppress the synthetic mouse press on the same Cel/Frame",
	)
	check_has(
		src,
		"event.device != -1",
		"physical mouse/trackpad input must restore native desktop-style controls",
	)
	check_has(
		src,
		"control.mouse_filter = int(control.get_meta(IOS_TOUCH_MOUSE_FILTER_META))",
		"pointer restoration must restore each control's original mouse filter",
	)
