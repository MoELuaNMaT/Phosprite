extends "res://tests/test_base.gd"

const LAYER_TOUCH_ADAPTER := preload("res://src/UI/Timeline/LayerTouchAdapter.gd")
const LAYER_TOUCH_SOURCE := "res://src/UI/Timeline/LayerTouchAdapter.gd"
const LAYER_BUTTON_SOURCE := "res://src/UI/Timeline/LayerButton.gd"
const LAYER_BUTTON_SCENE := "res://src/UI/Timeline/LayerButton.tscn"


func test_layer_direct_touch_single_tap_selects_existing_layer_path() -> void:
	var src := FileAccess.get_file_as_string(LAYER_TOUCH_SOURCE)
	check_has(src, 'OS.get_name() != "iOS"', "D4-A touch adaptation must remain iOS-only")
	check_has(
		src,
		"_layer_button._select_current_layer()",
		"single direct touch must reuse the existing LayerButton selection path"
	)
	check_has(
		src,
		"Global.transform_content_confirmed.emit()",
		"touch layer selection must preserve the existing transform-confirm boundary"
	)


func test_layer_double_touch_selects_then_opens_existing_context_menu() -> void:
	var src := FileAccess.get_file_as_string(LAYER_TOUCH_SOURCE)
	check_eq(
		LAYER_TOUCH_ADAPTER.IOS_TOUCH_DOUBLE_TAP_MSEC,
		350,
		"Layer double touch must use the established bounded double-tap window"
	)
	check_eq(
		LAYER_TOUCH_ADAPTER.IOS_TOUCH_TAP_SLOP_PX,
		12.0,
		"Layer double touch must use the established touch slop"
	)
	check_has(
		src,
		"_select_layer_for_touch()",
		"the second touch must still ensure the touched layer is selected"
	)
	check_has(
		src,
		"_popup_menu.popup_on_parent",
		"double touch must open the existing Layer context menu rather than a new menu"
	)


func test_layer_context_menu_exposes_rename_through_existing_editor() -> void:
	var src := FileAccess.get_file_as_string(LAYER_TOUCH_SOURCE)
	check_has(
		src, 'add_item(tr("Rename"), RENAME_MENU_ID)', "touch context menu must expose Rename"
	)
	check_has(
		src,
		"_layer_button._show_rename_edit()",
		"Rename must reuse the existing LayerButton LineEdit/Undo path"
	)
	check_true(not ("three_dot" in src), "D4-A must not add a parallel three-dot action model")


func test_layer_touch_scroll_movement_is_not_claimed_by_d4a() -> void:
	var src := FileAccess.get_file_as_string(LAYER_TOUCH_SOURCE)
	check_has(
		src,
		'candidate["cancelled"] = true',
		"movement beyond touch slop must cancel tap/double-touch recognition"
	)
	check_has(
		src,
		"return false",
		"D4-A drag cancellation must leave scrolling available to the surrounding Timeline"
	)
	check_true(not ("reordering" in src), "D4-A must not pre-implement D4-B reorder ownership")
	check_true(
		not ("_drop_data" in src), "D4-A must not bypass the existing Layer drop transaction"
	)


func test_layer_touch_suppresses_synthetic_mouse_and_restores_real_pointer() -> void:
	var src := FileAccess.get_file_as_string(LAYER_TOUCH_SOURCE)
	check_has(
		src,
		"IOS_TOUCH_MOUSE_FILTER_META",
		"direct touch mode must preserve the original LayerMainButton mouse filter"
	)
	check_has(
		src,
		"Control.MOUSE_FILTER_IGNORE",
		"touch-owned LayerMainButton must suppress duplicate synthesized mouse activation"
	)
	check_has(
		src,
		"event.device != -1",
		"a real pointer event must restore native mouse/trackpad Layer behavior"
	)
	check_has(src, "_restore_pointer_layer_ui()", "pointer restoration must be explicit")


func test_desktop_layer_double_click_and_right_click_semantics_remain_unchanged() -> void:
	var src := FileAccess.get_file_as_string(LAYER_BUTTON_SOURCE)
	check_has(src, "if event.double_click:", "desktop left double click must still be recognized")
	check_has(src, "_show_rename_edit()", "desktop left double click must still enter Rename")
	check_has(
		src,
		"event.button_index == MOUSE_BUTTON_RIGHT and event.pressed",
		"desktop right click must still open the native Layer context menu"
	)


func test_layer_scene_installs_touch_adapter_without_replacing_layer_button() -> void:
	var scene := FileAccess.get_file_as_string(LAYER_BUTTON_SCENE)
	check_has(
		scene,
		'path="res://src/UI/Timeline/LayerTouchAdapter.gd"',
		"LayerButton scene must install the D4-A adapter"
	)
	check_has(
		scene, 'script = ExtResource("1_6hlpe")', "LayerButton must keep its existing core script"
	)
