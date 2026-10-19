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


func test_low_frequency_layer_actions_use_layer_context_instead_of_overflow() -> void:
	var toolbar_src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	var layer_scene := FileAccess.get_file_as_string(LAYER_SCENE_SOURCE)
	for hidden_button in [
		"_move_up_layer.hide()",
		"_move_down_layer.hide()",
		"_clone_layer.hide()",
		"_merge_down_layer.hide()",
		"_layer_fx.hide()",
	]:
		check_has(toolbar_src, hidden_button, "secondary actions are not direct iPad buttons")
	check_true(
		not toolbar_src.contains("LayerActionsMenu"), "obsolete layer overflow button is removed"
	)
	for label in ["Duplicate layer", "Merge down", "Layer effects"]:
		check_has(layer_scene, label, "native layer context menu exposes the action")


func test_layer_context_actions_reuse_existing_layer_business_handlers() -> void:
	var src := FileAccess.get_file_as_string("res://src/UI/Timeline/LayerButton.gd")
	check_has(src, "Global.animation_timeline._on_CloneLayer_pressed()", "duplicate is native")
	check_has(src, "Global.animation_timeline._on_MergeDownLayer_pressed()", "merge is native")
	check_has(src, "Global.animation_timeline.open_current_layer_effects()", "effects are native")
	check_has(src, "_focus_context_layer()", "context actions target the held layer")


func test_layer_context_menu_disabled_state_follows_native_buttons() -> void:
	var src := FileAccess.get_file_as_string("res://src/UI/Timeline/LayerButton.gd")
	check_has(src, "timeline._toggle_layer_buttons()", "context state refreshes on open")
	check_has(src, "timeline.merge_down_layer.disabled", "merge disabled state is native")
	check_has(src, "project.layers[layer_index] is AudioLayer", "effects exclude Audio Layers")
	check_has(
		src,
		"popup_menu.about_to_popup.connect(_sync_layer_context_menu)",
		"context state must refresh before opening",
	)


func test_d4c_is_ios_only_and_does_not_touch_timeline_frame_controls() -> void:
	var bootstrap_src := FileAccess.get_file_as_string(BOOTSTRAP_SOURCE)
	var manager_src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(bootstrap_src, 'OS.get_name() != "iOS"', "row layout adapter must be iOS-only")
	check_has(manager_src, 'OS.get_name() != "iOS"', "toolbar layout adapter must be iOS-only")
	check_true(not ("AddFrame" in manager_src), "D4-C must not modify Frame controls")
	check_true(not ("Cel" in manager_src), "D4-C must not enter P1-E Cel behavior")
