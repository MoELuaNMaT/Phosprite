extends "res://tests/test_base.gd"

const BOOTSTRAP := preload("res://src/UI/Timeline/LayerPanelTouchBootstrap.gd")
const MANAGER := preload("res://src/UI/Timeline/LayerPanelTouchManager.gd")
const BOOTSTRAP_SOURCE := "res://src/UI/Timeline/LayerPanelTouchBootstrap.gd"
const MANAGER_SOURCE := "res://src/UI/Timeline/LayerPanelTouchManager.gd"
const LAYER_SCENE_SOURCE := "res://src/UI/Timeline/LayerButton.tscn"


func test_layer_side_actions_get_finger_width_without_forcing_row_height() -> void:
	check_eq(BOOTSTRAP.IOS_SIDE_TOUCH_WIDTH, 44.0, "Layer side actions must use 44 pt width")
	var src := FileAccess.get_file_as_string(BOOTSTRAP_SOURCE)
	check_has(
		src,
		"button.custom_minimum_size.x = IOS_SIDE_TOUCH_WIDTH",
		"Visibility, Lock, Link and Expand must grow horizontally for direct touch",
	)
	check_true(
		not ("button.custom_minimum_size.y" in src),
		"D4-C must leave Layer row height under the existing Timeline cel_size preference",
	)


func test_layer_scene_installs_touch_layout_without_replacing_existing_adapters() -> void:
	var src := FileAccess.get_file_as_string(LAYER_SCENE_SOURCE)
	check_has(src, "LayerTouchAdapter.gd", "D4-A/B touch adapter must remain installed")
	check_has(src, "LayerPanelTouchBootstrap.gd", "D4-C layout bootstrap must be installed")
	check_has(src, "LayerTouchAdapter", "existing Layer touch node must remain")
	check_has(src, "LayerPanelTouchBootstrap", "new layout node must be additive")


func test_ios_layer_toolbar_uses_touch_sized_direct_actions() -> void:
	check_eq(MANAGER.IOS_TOUCH_TARGET_PX, 44.0, "iPad toolbar touch target must be 44 pt")
	check_eq(MANAGER.IOS_ADD_LAYER_TARGET_WIDTH, 88.0, "Add Layer keeps two 44 pt halves")
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(
		src,
		"_add_layer.custom_minimum_size = Vector2(IOS_ADD_LAYER_TARGET_WIDTH, IOS_TOUCH_TARGET_PX)",
		"Add Layer must expose Pixel-add and layer-type popup as two touch-sized halves",
	)
	check_has(
		src,
		"_remove_layer.custom_minimum_size = Vector2(IOS_TOUCH_TARGET_PX, IOS_TOUCH_TARGET_PX)",
		"Delete Layer must remain a direct 44 pt action",
	)


func test_low_frequency_layer_actions_move_into_one_more_menu() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	for hidden_button in [
		"_move_up_layer.hide()",
		"_move_down_layer.hide()",
		"_clone_layer.hide()",
		"_merge_down_layer.hide()",
		"_layer_fx.hide()",
	]:
		check_has(src, hidden_button, "low-frequency Layer actions must leave the direct iPad row")
	check_has(src, 'popup.add_item(tr("Move layer up")', "More menu must expose Move Up")
	check_has(src, 'popup.add_item(tr("Move layer down")', "More menu must expose Move Down")
	check_has(src, 'popup.add_item(tr("Duplicate layer")', "More menu must expose Duplicate")
	check_has(src, 'popup.add_item(tr("Merge down")', "More menu must expose Merge Down")
	check_has(src, 'popup.add_item(tr("Layer effects")', "More menu must expose Layer Effects")


func test_more_menu_reuses_existing_layer_business_handlers() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(
		src, '_timeline.call("change_layer_order", true)', "Move Up must reuse existing handler"
	)
	check_has(
		src, '_timeline.call("change_layer_order", false)', "Move Down must reuse existing handler"
	)
	check_has(
		src, '_timeline.call("_on_CloneLayer_pressed")', "Duplicate must reuse existing handler"
	)
	check_has(
		src, '_timeline.call("_on_MergeDownLayer_pressed")', "Merge must reuse existing handler"
	)
	check_has(src, '_timeline.call("_on_layer_fx_pressed")', "Layer FX must reuse existing handler")
	check_true(not ("undo_redo" in src), "D4-C must not introduce a second Layer transaction")
	check_true(not ("move_layers" in src), "D4-C must not introduce Layer movement logic")


func test_more_menu_disabled_state_follows_existing_buttons() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(src, "_move_up_layer.disabled", "Move Up menu state must follow the existing Button")
	check_has(
		src, "_move_down_layer.disabled", "Move Down menu state must follow the existing Button"
	)
	check_has(src, "_merge_down_layer.disabled", "Merge menu state must follow the existing Button")
	check_has(src, "_layer_fx.disabled", "Layer FX menu state must follow the existing Button")
	check_has(
		src, "popup.about_to_popup.connect(_sync_action_states)", "state must refresh before open"
	)


func test_d4c_is_ios_only_and_does_not_touch_timeline_frame_controls() -> void:
	var bootstrap_src := FileAccess.get_file_as_string(BOOTSTRAP_SOURCE)
	var manager_src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(bootstrap_src, 'OS.get_name() != "iOS"', "row layout adapter must be iOS-only")
	check_has(manager_src, 'OS.get_name() != "iOS"', "toolbar layout adapter must be iOS-only")
	check_true(not ("AddFrame" in manager_src), "D4-C must not modify Frame controls")
	check_true(not ("Cel" in manager_src), "D4-C must not enter P1-E Cel behavior")