extends "res://tests/test_base.gd"

const CANVAS_SOURCE := "res://src/UI/Canvas/Canvas.gd"
const INPUT_ADAPTER_SOURCE := "res://src/InputAdapter/CanvasInputAdapter.gd"
const ROUTER_SOURCE := "res://src/InputAdapter/TouchTransformHandleRouter.gd"
const BASE_SELECTION_SOURCE := "res://src/Tools/BaseSelectionTool.gd"


func test_adapter_routes_transform_handles_before_selection_tool_draw() -> void:
	var canvas := FileAccess.get_file_as_string(CANVAS_SOURCE)
	check_has(
		canvas,
		"TOUCH_TRANSFORM_HANDLE_ROUTER.handle_event(self, viewport_position, event)",
		"CanvasInputAdapter-owned content events must get a transform-handle acquisition chance"
	)
	var handler_start := canvas.find("func handle_adapter_tool_event")
	var router_call := canvas.find("TOUCH_TRANSFORM_HANDLE_ROUTER.handle_event", handler_start)
	var tool_call := canvas.find("_handle_tool_event", router_call)
	check_true(
		handler_start >= 0 and router_call > handler_start and tool_call > router_call,
		"touch handle routing must run before the normal Selection tool draw path"
	)
	check_has(
		canvas,
		"if TOUCH_TRANSFORM_HANDLE_ROUTER.handle_event(self, viewport_position, event):\n\t\treturn",
		"acquired handles must consume adapter events before Selection content move"
	)


func test_touch_router_reuses_existing_transform_handle_state_machine() -> void:
	var router := FileAccess.get_file_as_string(ROUTER_SOURCE)
	check_has(
		router,
		"transformation_handles._handle_mouse_press(local_position, hovered_handle)",
		"touch press must enter the existing desktop handle press boundary"
	)
	check_has(
		router,
		"transformation_handles._handle_mouse_drag(local_position)",
		"touch drag must reuse the existing scale/rotate/skew implementation"
	)
	check_has(
		router,
		"transformation_handles.active_handle = null",
		"touch release must end the same existing active-handle state"
	)
	check_true(
		not ("begin_transform(" in router),
		"the adapter router must not create a parallel transform lifecycle"
	)


func test_touch_handle_target_is_44px_and_nearest_wins() -> void:
	var router := FileAccess.get_file_as_string(ROUTER_SOURCE)
	check_has(
		router,
		"TOUCH_HANDLE_DIAMETER_PX := 44.0",
		"touch handle acquisition must use the D2C 44 px invisible target"
	)
	check_has(
		router,
		"distance_px <= TOUCH_HANDLE_RADIUS_PX and distance_px < best_distance_px",
		"overlapping expanded targets must resolve to the nearest existing handle"
	)
	check_has(
		router,
		"get_global_transform_with_canvas().affine_inverse()",
		"adapter viewport coordinates must be converted into TransformationHandles local space"
	)
	check_has(
		router, "if Global.mirror_view:", "touch hit testing must preserve mirrored-canvas behavior"
	)
	check_has(
		router,
		"if index == 0 and not transformation_handles.is_rotated_or_skewed():",
		"the invisible pivot must not become a touch target before it is actually shown"
	)


func test_selection_modes_and_content_transform_keep_existing_model() -> void:
	var base := FileAccess.get_file_as_string(BASE_SELECTION_SOURCE)
	check_has(
		base,
		"enum Mode { DEFAULT, ADD, SUBTRACT, INTERSECT }",
		"D2C must keep the existing Replace/Add/Subtract/Intersect state model"
	)
	check_has(
		base,
		"selection_node.preview_selection_map.is_pixel_selected(mouse_pos)",
		"touch content move must still acquire through the existing selected-content test"
	)
	check_has(
		base,
		"transformation_handles.begin_transform()",
		"moving selected content must still begin the existing transform lifecycle"
	)
	check_has(
		base,
		"func _on_confirm_button_pressed()",
		"D2C must retain the existing transform Confirm boundary"
	)
	check_has(
		base,
		"func _on_cancel_button_pressed()",
		"D2C must retain the existing transform Cancel boundary"
	)
	check_has(
		base,
		"Global.transform_content_confirmed.emit()",
		"Confirm must commit through the existing transform signal"
	)
	check_has(
		base,
		"Global.transform_content_canceled.emit()",
		"Cancel must roll back through the existing transform signal"
	)


func test_adapter_cancellation_releases_acquired_transform_handle() -> void:
	var base := FileAccess.get_file_as_string(BASE_SELECTION_SOURCE)
	var adapter := FileAccess.get_file_as_string(INPUT_ADAPTER_SOURCE)
	check_has(
		base,
		"func cancel_tool() -> void:",
		"Selection must own cleanup of its transient handle state when content ownership is canceled"
	)
	check_has(
		base,
		"transformation_handles.active_handle = null",
		"Selection cancellation must release an acquired transform handle and restore Global.can_draw"
	)
	check_has(
		adapter,
		"func reset(canvas: Node2D) -> void:\n\tif _content_touch_id != -1:\n\t\t_cancel_active_tool()",
		"focus/reset cancellation must continue through the selected tool cancellation boundary"
	)
	var takeover_start := adapter.find("func _try_promote_direct_content_to_navigation")
	var takeover_cancel := adapter.find("_cancel_active_tool()", takeover_start)
	check_true(
		takeover_start >= 0 and takeover_cancel > takeover_start,
		"second-finger navigation takeover must cancel the active Selection tool before navigation"
	)
