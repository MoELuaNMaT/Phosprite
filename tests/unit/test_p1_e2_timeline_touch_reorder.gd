extends "res://tests/test_base.gd"

const MANAGER := preload("res://src/UI/Timeline/TimelineTouchSelectionManager.gd")
const MANAGER_SOURCE := "res://src/UI/Timeline/TimelineTouchSelectionManager.gd"
const CEL_SOURCE := "res://src/UI/Timeline/CelButton.gd"
const FRAME_SOURCE := "res://src/UI/Timeline/FrameButton.gd"


func test_e2_uses_d4b_long_press_and_slop_contract() -> void:
	check_eq(MANAGER.IOS_TOUCH_REORDER_HOLD_MSEC, 450, "E2 long press must match D4-B")
	check_eq(MANAGER.IOS_TOUCH_TAP_SLOP_PX, 12.0, "pre-ownership scroll slop must stay 12px")
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	var hold_pos := src.find("held_msec >= IOS_TOUCH_REORDER_HOLD_MSEC")
	var slop_pos := src.find("origin.distance_to(event.position) > IOS_TOUCH_TAP_SLOP_PX")
	check_true(
		hold_pos >= 0 and slop_pos > hold_pos,
		"a held touch must acquire reorder before slop cancels it"
	)


func test_e2_reuses_native_cel_and_frame_drag_payloads() -> void:
	var manager_src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	var cel_src := FileAccess.get_file_as_string(CEL_SOURCE)
	var frame_src := FileAccess.get_file_as_string(FRAME_SOURCE)
	check_has(
		cel_src, "func _build_cel_drag_data", "Cel drag payload must have one reusable builder"
	)
	check_has(
		frame_src,
		"func _build_frame_drag_data",
		"Frame drag payload must have one reusable builder"
	)
	check_has(
		manager_src,
		'source.call("_build_cel_drag_data", false)',
		"Finger Cel drag must reuse the native payload"
	)
	check_has(
		manager_src,
		'source.call("_build_frame_drag_data", false)',
		"Finger Frame drag must reuse the native payload"
	)
	check_true(
		not ("undo_redo" in manager_src),
		"the touch adapter must not create a second transaction path"
	)


func test_touch_payload_disables_modifier_swap_but_desktop_keeps_it() -> void:
	for path in [CEL_SOURCE, FRAME_SOURCE]:
		var src := FileAccess.get_file_as_string(path)
		check_has(
			src,
			"modifier_swap_override != null",
			"touch payload must support an explicit modifier override"
		)
		check_has(
			src,
			"if data.size() >= 3",
			"third payload field must override modifier Swap when present"
		)
		check_has(
			src,
			"return Global.is_ctrl_or_cmd_pressed()",
			"legacy two-field desktop drag must keep Ctrl/Cmd Swap"
		)


func test_native_drop_uses_passed_local_position_for_left_right() -> void:
	for path in [CEL_SOURCE, FRAME_SOURCE]:
		var src := FileAccess.get_file_as_string(path)
		check_has(
			src,
			"func _drop_data(pos: Vector2, data)",
			"native drop must consume the supplied local position"
		)
		check_has(
			src,
			"if pos.x < size.x / 2.0",
			"left/right placement must be based on the supplied drop position"
		)


func test_e2_preserves_selected_sources_and_collapses_unselected_sources() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(
		src,
		"if not project.selected_cels.has(frame_layer)",
		"unselected Cel source must collapse to itself"
	)
	check_has(
		src,
		"var frame_is_selected := false",
		"Frame reorder must derive membership from selected_cels"
	)
	check_has(src, "if not frame_is_selected", "unselected Frame source must collapse to itself")
	check_has(
		src,
		"project.selected_cels.clear()",
		"source collapse must keep the existing selected_cels model"
	)


func test_e2_reuses_native_can_drop_and_drop_once() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(
		src,
		'target.call("_can_drop_data", local_position, _reorder_data)',
		"E2 must reuse native drop validation"
	)
	check_has(
		src,
		'target.call("_drop_data", local_position, _reorder_data)',
		"valid release must delegate one native drop"
	)
	check_has(
		src,
		"if not is_instance_valid(_drop_target) or _reorder_data.is_empty()",
		"invalid release must stay transaction-free"
	)


func test_e2_has_stationary_edge_auto_scroll_for_frames_and_cels() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_eq(MANAGER.AUTO_SCROLL_MIN_SPEED, 90.0, "auto-scroll minimum must match D4-B")
	check_eq(MANAGER.AUTO_SCROLL_MAX_SPEED, 520.0, "auto-scroll maximum must match D4-B")
	check_eq(MANAGER.AUTO_SCROLL_RAMP_PX, 72.0, "auto-scroll ramp must match D4-B")
	check_has(
		src,
		"func _process(delta: float)",
		"stationary finger auto-scroll needs per-frame processing"
	)
	check_has(
		src,
		"_update_horizontal_scroll",
		"Frame and Cel drag must support horizontal edge scrolling"
	)
	check_has(src, "_update_vertical_scroll", "Cel drag must support vertical edge scrolling")


func test_e2_visual_feedback_reuses_timeline_highlight_and_cleans_up() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(src, "_create_reorder_preview", "owned reorder must show a floating preview")
	check_has(src, "_create_source_outline", "owned reorder must leave a source marker")
	check_has(
		src,
		'var drag_highlight := _timeline.get("drag_highlight")',
		"drop feedback must reuse the Timeline highlight"
	)
	check_has(src, "_clear_reorder_preview()", "cancel/release must clear the floating preview")
	check_has(src, "_clear_source_outline()", "cancel/release must clear the source marker")
