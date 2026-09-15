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


func test_e1_is_ios_only_and_keeps_e2_drag_ownership_out_of_scope() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(src, 'OS.get_name() != "iOS"', "E1 manager must be iOS-only")
	check_has(
		src,
		"E1 never acquires drag ownership",
		"ScreenDrag must remain scroll cancellation only until E2",
	)
	check_true(not ("_drop_data" in src), "E1 must not implement Cel/Frame drop transactions")
	check_true(not ("undo_redo" in src), "E1 must not create a second Timeline transaction path")


func test_timeline_multi_select_has_an_explicit_touch_entry() -> void:
	check_eq(MANAGER.IOS_MULTI_SELECT_HEIGHT, 44.0, "multi-select entry must be finger sized")
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(src, 'name = "TimelineMultiSelectButton"', "E1 must expose an explicit mode control")
	check_has(src, 'text = tr("Select")', "multi-select mode must have a visible label")
	check_has(src, "toggle_mode = true", "multi-select entry must expose persistent mode state")


func test_normal_touch_collapses_to_one_cel_or_current_layer_frame_cel() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(
		src,
		"project.selected_cels.append(frame_layer)",
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


func test_multi_select_toggles_cels_and_whole_frames_without_empty_selection() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(
		src,
		"project.selected_cels.erase(frame_layer)",
		"multi-select Cel touch must support removing an existing selection",
	)
	check_has(
		src,
		"for layer in project.layers.size()",
		"multi-select Frame touch must address every Cel in that Frame",
	)
	check_has(
		src,
		"if project.selected_cels.is_empty()",
		"Frame toggling must guard the existing non-empty selected_cels contract",
	)
	check_has(
		src,
		"if project.selected_cels.size() <= 1",
		"Cel toggling must not remove the final selected Cel",
	)


func test_double_tap_opens_existing_cel_and_frame_context_menus() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_eq(MANAGER.IOS_TOUCH_DOUBLE_TAP_MSEC, 350, "double-tap window must match Layer touch UX")
	check_has(
		src,
		'target.get_node_or_null("PopupMenu")',
		"E1 must reuse each existing Cel/Frame PopupMenu",
	)
	check_has(src, "popup.popup_on_parent", "double tap must open the existing context menu")
	check_has(
		src,
		"_prepare_frame_popup",
		"touch Frame popup must refresh the same existing action availability",
	)


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
