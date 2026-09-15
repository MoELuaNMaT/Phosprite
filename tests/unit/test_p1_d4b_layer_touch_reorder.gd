extends "res://tests/test_base.gd"

const LAYER_TOUCH_ADAPTER := preload("res://src/UI/Timeline/LayerTouchAdapter.gd")
const LAYER_TOUCH_SOURCE := "res://src/UI/Timeline/LayerTouchAdapter.gd"
const LAYER_MAIN_SOURCE := "res://src/UI/Timeline/LayerMainButton.gd"


func test_layer_touch_reorder_uses_approved_hold_and_slop() -> void:
	check_eq(
		LAYER_TOUCH_ADAPTER.IOS_TOUCH_REORDER_HOLD_MSEC,
		450,
		"Layer reorder must use the approved long-press threshold",
	)
	check_eq(
		LAYER_TOUCH_ADAPTER.IOS_TOUCH_TAP_SLOP_PX,
		12.0,
		"Layer reorder must preserve the established touch slop",
	)


func test_pre_hold_drag_remains_timeline_scroll() -> void:
	var src := FileAccess.get_file_as_string(LAYER_TOUCH_SOURCE)
	check_has(
		src,
		'candidate["cancelled"] = true',
		"movement before reorder ownership must cancel the Layer tap candidate",
	)
	check_has(
		src,
		"Before reorder ownership, vertical movement belongs to the Timeline ScrollContainer",
		"D4-B must explicitly preserve Timeline scrolling before ownership",
	)
	check_has(src, "return false", "pre-hold movement must remain available to Timeline scroll")


func test_long_press_builds_existing_layer_drag_payload() -> void:
	var touch_src := FileAccess.get_file_as_string(LAYER_TOUCH_SOURCE)
	var main_src := FileAccess.get_file_as_string(LAYER_MAIN_SOURCE)
	check_has(
		touch_src,
		'_main_button.call("_build_layer_drag_data")',
		"touch reorder must reuse the Layer drag payload builder",
	)
	check_has(
		main_src,
		"func _build_layer_drag_data() -> Array:",
		"desktop and touch Layer drag must share one payload builder",
	)
	check_has(
		main_src,
		"for child in layer.get_children(true):",
		"shared payload construction must include Group descendants",
	)
	check_has(main_src, 'return ["Layer", layers]', "shared payload must retain native Layer data")


func test_unselected_long_press_becomes_single_layer_drag() -> void:
	var src := FileAccess.get_file_as_string(LAYER_TOUCH_SOURCE)
	check_has(
		src,
		"if not _main_button.button_pressed:",
		"long press outside the current selection must first select its source Layer",
	)
	check_has(
		src,
		"_select_layer_for_touch()",
		"unselected touch reorder must reuse the existing single-Layer selection path",
	)


func test_touch_target_and_commit_reuse_native_drop_contract() -> void:
	var src := FileAccess.get_file_as_string(LAYER_TOUCH_SOURCE)
	check_has(
		src,
		'target_main.call("_can_drop_data", local_position, _reorder_data)',
		"touch target validation must call the native Layer drop validator",
	)
	check_has(
		src,
		'_drop_target.call("_drop_data", _drop_local_position, _reorder_data)',
		"touch release must commit through the native Layer drop transaction",
	)
	check_true(
		not ("project.move_layers" in src),
		"touch adapter must not introduce a second Layer movement transaction",
	)
	check_true(
		not ("project.swap_layers" in src),
		"touch adapter must not introduce a second Layer swap transaction",
	)


func test_group_reparent_and_ancestor_rules_remain_native() -> void:
	var src := FileAccess.get_file_as_string(LAYER_MAIN_SOURCE)
	check_has(
		src,
		"curr_layer.accepts_child(last_layer)",
		"Group center drop must continue using the existing accepts_child rule",
	)
	check_has(
		src,
		"drop_layer.is_ancestor_of(curr_layer)",
		"native drop validation must continue blocking ancestor-to-descendant moves",
	)
	check_has(
		src,
		"project.move_layers.bind",
		"Group and normal Layer moves must keep the existing project transaction",
	)
	check_has(
		src,
		'project.undo_redo.create_action("Change Layer Order")',
		"Layer reorder must remain one native UndoRedo action",
	)


func test_direct_touch_never_inherits_modifier_swap() -> void:
	var touch_src := FileAccess.get_file_as_string(LAYER_TOUCH_SOURCE)
	var main_src := FileAccess.get_file_as_string(LAYER_MAIN_SOURCE)
	check_has(
		touch_src,
		"data.append(false)",
		"direct-touch payload must explicitly disable modifier Swap semantics",
	)
	check_has(
		main_src,
		"var allow_modifier_swap := data.size() < 3 or bool(data[2])",
		"native drag must default to existing modifier behavior unless touch opts out",
	)
	check_has(
		main_src,
		"allow_modifier_swap and Global.is_ctrl_or_cmd_pressed()",
		"desktop Ctrl/Cmd Swap must remain available on native pointer drag",
	)


func test_reorder_feedback_uses_preview_source_outline_and_native_target_highlight() -> void:
	var src := FileAccess.get_file_as_string(LAYER_TOUCH_SOURCE)
	check_has(src, "PREVIEW_OPACITY := 0.88", "touch reorder must expose a following preview")
	check_has(
		src,
		"outline.draw_dashed_line",
		"source Layer must receive a distinct dashed reorder marker",
	)
	check_has(
		src,
		"Global.animation_timeline.drag_highlight.hide()",
		"touch reorder must reuse and clear the existing native target highlight",
	)


func test_reorder_owns_scroll_only_after_acquisition_and_supports_edge_scroll() -> void:
	var src := FileAccess.get_file_as_string(LAYER_TOUCH_SOURCE)
	check_eq(
		LAYER_TOUCH_ADAPTER.AUTO_SCROLL_MIN_SPEED,
		90.0,
		"Layer edge-scroll minimum speed must match the proven Palette interaction",
	)
	check_eq(
		LAYER_TOUCH_ADAPTER.AUTO_SCROLL_MAX_SPEED,
		520.0,
		"Layer edge-scroll maximum speed must match the proven Palette interaction",
	)
	check_eq(
		LAYER_TOUCH_ADAPTER.AUTO_SCROLL_RAMP_PX,
		72.0,
		"Layer edge-scroll ramp must match the proven Palette interaction",
	)
	check_has(
		src,
		"scroll.scroll_vertical = int(round(_managed_scroll))",
		"reorder ownership must hold Timeline scroll while the finger remains inside",
	)
	check_has(
		src,
		"_managed_scroll += signf(overflow) * speed * delta",
		"stationary edge overflow must keep driving managed auto-scroll",
	)


func test_invalid_release_and_touch_cancel_are_no_op_transactions() -> void:
	var src := FileAccess.get_file_as_string(LAYER_TOUCH_SOURCE)
	check_has(src, "if event.canceled:", "system-cancelled touch must cleanly end reorder")
	check_has(
		src,
		"if not is_instance_valid(_drop_target) or _reorder_data.is_empty():",
		"release without a legal target must not call the native drop transaction",
	)
	check_has(src, "_finish_reorder()", "all reorder endings must clear feedback and state")


func test_desktop_native_drag_contract_remains_available() -> void:
	var src := FileAccess.get_file_as_string(LAYER_MAIN_SOURCE)
	check_has(
		src, "func _get_drag_data(_position: Vector2) -> Variant:", "desktop native drag remains"
	)
	check_has(src, "set_drag_preview(box)", "desktop native drag preview remains unchanged")
	check_has(
		src,
		"var allow_modifier_swap := data.size() < 3 or bool(data[2])",
		"legacy two-field desktop payload must continue allowing modifier Swap",
	)
