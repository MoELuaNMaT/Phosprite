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


func test_e3_removes_obsolete_overflow_but_preserves_native_frame_handlers() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	for hidden_button in [
		"_copy_frame.hide()",
		"_move_frame_left.hide()",
		"_move_frame_right.hide()",
		"_first_frame.hide()",
		"_last_frame.hide()",
	]:
		check_has(src, hidden_button, "gesture-owned action is no longer an iPad toolbar item")
	check_true(
		not src.contains("TimelineActionsMenu"), "obsolete Frame overflow menu must be removed"
	)
	check_true(
		not src.contains("_timeline_settings.hide()"),
		"Timeline settings must be available as an independent button",
	)
	check_has(src, "_timeline_settings.custom_minimum_size", "Timeline settings is touch sized")

func test_e3_tag_actions_reuse_existing_frame_context_handlers() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(src, 'name = "TimelineNewTagButton"', "New Tag has a direct iPad entry")
	check_has(src, 'name = "TimelineImportTagButton"', "Import Tag has a direct iPad entry")
	check_has(src, "_call_current_frame_menu_action(5)", "New Tag uses the native handler")
	check_has(src, "_call_current_frame_menu_action(6)", "Import Tag uses the native handler")
	check_true(not ("undo_redo" in src), "E3/E4 adapter must not create a second UndoRedo path")
	check_true(not ("move_frames" in src), "E3/E4 adapter must not implement Frame movement")

func test_e4_frame_and_cel_actions_are_available_at_the_object_long_press() -> void:
	var manager_src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	var frame_src := FileAccess.get_file_as_string("res://src/UI/Timeline/FrameButton.gd")
	var cel_src := FileAccess.get_file_as_string("res://src/UI/Timeline/CelButton.gd")
	var layer_src := FileAccess.get_file_as_string("res://src/UI/Timeline/LayerButton.gd")
	check_true(
		not manager_src.contains('popup.add_item(tr("Frame properties / duration")'),
		"per-frame duration must not appear in the iPad toolbar",
	)
	check_has(frame_src, "PROPERTIES, MOVE_LEFT, MOVE_RIGHT, NEW_TAG, IMPORT_TAG",
		"iPad Frame context hides settings relocated to gestures or dedicated controls")
	check_has(frame_src, "Global.animation_timeline.reverse_frames(indices)",
		"Frame long press keeps Reverse Frames")
	check_has(frame_src, "DrawingAlgos.center(indices)", "Frame long press keeps Center Frames")
	check_has(cel_src, "_sync_link_actions_visibility", "Cel long press owns Link and Unlink")
	check_has(cel_src, "selected_frames.size() >= 2", "Link actions require multi-selection")
	for layer_action in ["DUPLICATE", "MERGE_DOWN", "EFFECTS"]:
		check_has(layer_src, "MenuOptions." + layer_action, "Animation layer menu includes action")
	check_has(
		manager_src,
		'frame_button.call("_on_PopupMenu_id_pressed", id)',
		"dedicated Tag controls still use the original Frame action handler",
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
