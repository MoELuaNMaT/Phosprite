extends "res://tests/test_base.gd"

const BOOTSTRAP := preload("res://src/UI/Timeline/TimelinePanelTouchBootstrap.gd")
const MANAGER := preload("res://src/UI/Timeline/TimelinePanelTouchManager.gd")
const BOOTSTRAP_SOURCE := "res://src/UI/Timeline/TimelinePanelTouchBootstrap.gd"
const MANAGER_SOURCE := "res://src/UI/Timeline/TimelinePanelTouchManager.gd"
const FRAME_SCENE_SOURCE := "res://src/UI/Timeline/FrameButton.tscn"


func test_frame_scene_installs_timeline_touch_manager_additively() -> void:
	var src := FileAccess.get_file_as_string(FRAME_SCENE_SOURCE)
	check_has(src, "FrameButton.gd", "native FrameButton behavior must remain installed")
	check_has(
		src,
		"TimelinePanelTouchBootstrap.gd",
		"E3/E4 touch layout bootstrap must be additive",
	)
	check_has(src, "TimelinePanelTouchBootstrap", "Frame scene must host the bootstrap node")


func test_e3_direct_timeline_actions_use_finger_sized_targets() -> void:
	check_eq(MANAGER.IOS_TOUCH_TARGET_PX, 44.0, "direct iPad Timeline actions must use 44 pt")
	check_eq(MANAGER.IOS_FPS_TARGET_WIDTH, 88.0, "FPS control needs a wider touch target")
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	for direct_action in [
		"_add_frame,",
		"_delete_frame,",
		"_previous_frame,",
		"_play_backwards,",
		"_play_forward,",
		"_next_frame,",
		"_onion_skinning,",
		"_loop_animation,",
	]:
		check_has(src, direct_action, "high-frequency Timeline actions must remain direct")
	check_has(
		src,
		"button.custom_minimum_size = Vector2(IOS_TOUCH_TARGET_PX, IOS_TOUCH_TARGET_PX)",
		"direct actions must share the 44 pt geometry",
	)
	check_has(
		src,
		"_fps_value.custom_minimum_size = Vector2(IOS_FPS_TARGET_WIDTH, IOS_TOUCH_TARGET_PX)",
		"FPS must remain direct and finger sized",
	)


func test_e3_low_frequency_actions_move_into_one_more_menu() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	for hidden_button in [
		"_copy_frame.hide()",
		"_move_frame_left.hide()",
		"_move_frame_right.hide()",
		"_first_frame.hide()",
		"_last_frame.hide()",
		"_timeline_settings.hide()",
	]:
		check_has(src, hidden_button, "low-frequency action must leave the direct iPad toolbar")
	check_has(src, 'popup.add_item(tr("Duplicate frame")', "More menu must expose Duplicate")
	check_has(src, 'popup.add_item(tr("Move frame left")', "More menu must expose Move Left")
	check_has(src, 'popup.add_item(tr("Move frame right")', "More menu must expose Move Right")
	check_has(src, 'popup.add_item(tr("Jump to first frame")', "More menu must expose First")
	check_has(src, 'popup.add_item(tr("Jump to last frame")', "More menu must expose Last")
	check_has(src, 'popup.add_item(tr("Timeline settings")', "More menu must expose settings")


func test_e3_menu_delegates_to_existing_timeline_handlers() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	for handler in [
		'_timeline.call("_on_CopyFrame_pressed")',
		'_timeline.call("_on_MoveLeft_pressed")',
		'_timeline.call("_on_MoveRight_pressed")',
		'_timeline.call("_on_FirstFrame_pressed")',
		'_timeline.call("_on_LastFrame_pressed")',
		'_timeline.call("_on_timeline_settings_button_pressed")',
	]:
		check_has(src, handler, "E3 must delegate to the existing Timeline handler")
	check_true(not ("undo_redo" in src), "E3/E4 adapter must not create a second UndoRedo path")
	check_true(not ("move_frames" in src), "E3/E4 adapter must not implement Frame movement")


func test_e4_frame_and_cel_advanced_actions_reuse_existing_context_handlers() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(
		src,
		'popup.add_item(tr("Frame properties / duration")',
		"Frame duration must be reachable from the iPad More menu",
	)
	check_has(src, 'popup.add_item(tr("New tag")', "Tag creation must be reachable")
	check_has(src, 'popup.add_item(tr("Import tag")', "Tag import must be reachable")
	check_has(src, 'popup.add_item(tr("Cel properties")', "Cel properties must be reachable")
	check_has(src, 'popup.add_item(tr("Link selected cels")', "Linked Cel must be reachable")
	check_has(src, 'popup.add_item(tr("Unlink selected cels")', "Unlink must be reachable")
	check_has(
		src,
		'frame_button.call("_on_PopupMenu_id_pressed", id)',
		"Frame advanced actions must reuse FrameButton's context handler",
	)
	check_has(
		src,
		'cel_button.call("_on_PopupMenu_id_pressed", id)',
		"Cel advanced actions must reuse CelButton's context handler",
	)


func test_e4_onion_skin_stays_direct_without_algorithm_changes() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(src, "_onion_skinning,", "Onion Skin must stay in the direct iPad toolbar")
	check_true(
		not ("onion_skinning_past_rate" in src),
		"E4 must not reimplement Onion Skin settings or rendering",
	)
	check_true(not ("canvas_onion_skinning" in src), "E4 must not enter Onion Skin algorithms")


func test_e4_tag_resize_uses_touch_edge_zone_and_native_resize_transaction() -> void:
	check_eq(MANAGER.TAG_EDGE_TOUCH_PX, 22.0, "each Tag edge needs a 44 pt total touch zone")
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(src, "InputEventScreenTouch", "Tag resize must accept direct Finger touch")
	check_has(src, "InputEventScreenDrag", "Tag resize must follow direct Finger drag")
	check_has(
		src,
		'_tag_resize_ui.call("_resize_tag", _tag_resize_side, value)',
		"Tag touch resize must commit through AnimationTagUI._resize_tag",
	)
	check_has(
		src,
		'_tag_resize_ui.call("update_position_and_size", _tag_resize_preview)',
		"Tag touch resize must preview through existing Tag UI geometry",
	)
	check_true(
		not ('&"animation_tags"' in src),
		"adapter must not duplicate AnimationTagUI's animation_tags transaction",
	)


func test_e4_short_tag_keeps_center_tap_for_editing() -> void:
	var manager := MANAGER.new()
	var rect := Rect2(100.0, 0.0, 30.0, 32.0)
	check_eq(
		manager.call("_tag_resize_side_for_x", rect, 100.0),
		MANAGER.TAG_DRAG_FROM,
		"short Tag left edge must remain resizeable",
	)
	check_eq(
		manager.call("_tag_resize_side_for_x", rect, 130.0),
		MANAGER.TAG_DRAG_TO,
		"short Tag right edge must remain resizeable",
	)
	check_eq(
		manager.call("_tag_resize_side_for_x", rect, 115.0),
		0,
		"short Tag center must stay available for the native edit tap",
	)
	manager.free()


func test_e3_e4_adapter_is_ios_only_and_keeps_existing_touch_manager_separate() -> void:
	var bootstrap_src := FileAccess.get_file_as_string(BOOTSTRAP_SOURCE)
	var manager_src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(bootstrap_src, 'OS.get_name() != "iOS"', "bootstrap must be iOS-only")
	check_has(manager_src, 'OS.get_name() != "iOS"', "manager must be iOS-only")
	check_true(
		not ("TimelineTouchSelectionManager" in manager_src),
		"E3/E4 must not take ownership of E1/E2 selection/reorder",
	)
	check_has(
		bootstrap_src,
		"timeline.has_node(PANEL_MANAGER_NAME)",
		"many FrameButton instances must still install only one manager",
	)
