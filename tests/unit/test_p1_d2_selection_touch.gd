extends "res://tests/test_base.gd"

const ADAPTER := preload("res://src/InputAdapter/CanvasInputAdapter.gd")
const TOOL_BUTTONS := preload("res://src/UI/ToolsPanel/ToolButtons.gd")
const TOOL_BUTTONS_SOURCE := "res://src/UI/ToolsPanel/ToolButtons.gd"
const RECT_SOURCE := "res://src/Tools/SelectionTools/RectSelect.gd"
const ELLIPSE_SOURCE := "res://src/Tools/SelectionTools/EllipseSelect.gd"
const POLYGON_SOURCE := "res://src/Tools/SelectionTools/PolygonSelect.gd"
const BASE_SHAPE_SOURCE := "res://src/Tools/BaseShapeDrawer.gd"
const BASE_SELECTION_SOURCE := "res://src/Tools/BaseSelectionTool.gd"
const TRANSFORM_SOURCE := "res://src/UI/Canvas/TransformationHandles.gd"


func test_ios_selection_family_contains_exact_seven_tools() -> void:
	var expected := [
		&"ColorSelect",
		&"EllipseSelect",
		&"Lasso",
		&"MagicWand",
		&"PaintSelect",
		&"PolygonSelect",
		&"RectSelect",
	]
	check_eq(
		TOOL_BUTTONS.IOS_SELECTION_TOOLS,
		expected,
		"the compact iOS Selection entry must expose exactly the approved seven tools"
	)
	check_eq(
		TOOL_BUTTONS.normalize_ios_recent_selection_tool(&"EllipseSelect"),
		&"EllipseSelect",
		"a valid recent Selection subtool must survive normalization"
	)
	check_eq(
		TOOL_BUTTONS.normalize_ios_recent_selection_tool(&"Pencil"),
		&"RectSelect",
		"invalid/stale recent Selection state must fall back to RectSelect"
	)


func test_selection_family_is_ios_only_and_persists_recent_child() -> void:
	var src := FileAccess.get_file_as_string(TOOL_BUTTONS_SOURCE)
	check_has(src, 'OS.get_name() == "iOS"', "Selection compaction must remain iOS-only")
	check_has(
		src,
		"IOS_SELECTION_MENU_LONG_PRESS_SECONDS",
		"the compact Selection entry needs an explicit long-press acquisition path"
	)
	check_has(
		src,
		"_try_open_ios_selection_menu",
		"long press must open the Selection child menu instead of selecting immediately"
	)
	check_has(
		src,
		"_activate_ios_selection_tool(_ios_selection_recent_tool)",
		"a normal tap must activate the persisted recent Selection child"
	)
	check_has(
		src,
		"Global.config_cache.set_value",
		"the recent Selection child must persist through the shared config cache"
	)
	check_has(
		src,
		"Global.config_cache.save(Global.CONFIG_PATH)",
		"recent Selection state must be durable across app restart"
	)


func test_selection_family_reasserts_compaction_after_startup_visibility_pass() -> void:
	var src := FileAccess.get_file_as_string(TOOL_BUTTONS_SOURCE)
	check_has(
		src,
		"Global.pixelorama_opened.connect(_on_ios_pixelorama_opened)",
		"initial compaction must run again after the application's final startup visibility pass"
	)
	check_has(
		src,
		"Global.cel_switched.connect(_on_ios_cel_switched)",
		"layer/cel visibility refreshes must not expand the seven Selection buttons again"
	)
	check_has(
		src,
		'call_deferred("_sync_ios_selection_family_visual")',
		"compaction re-sync must run after the generic visibility listeners"
	)


func test_rect_and_ellipse_perfect_hold_reuse_d1_touch_slop() -> void:
	for path in [RECT_SOURCE, ELLIPSE_SOURCE]:
		var src := FileAccess.get_file_as_string(path)
		check_has(
			src,
			"TOUCH_PERFECT_HOLD_SECONDS := 1.0",
			"perfect-shape touch hold must use the approved 1000 ms dwell"
		)
		check_has(
			src,
			"CANVAS_INPUT_ADAPTER.long_press_motion_exceeds_slop",
			"perfect-shape hold must reuse the D1 touch-slop rule"
		)
		check_true(
			not ("TOUCH_PERFECT_SLOP" in src), "D2 must not invent a second touch-slop constant"
		)
		check_has(
			src,
			"_update_touch_perfect_hold()",
			"the dwell timer must be armed from an active drag, not touch-down"
		)
		check_has(
			src,
			"_touch_perfect_locked = true",
			"once acquired, 1:1 must stay locked until the selection ends"
		)


func test_perfect_hold_is_touch_owned_and_stationary_timer_driven() -> void:
	var rect := FileAccess.get_file_as_string(RECT_SOURCE)
	check_has(
		rect,
		"adapter._content_touch_id",
		"perfect-shape acquisition must be limited to CanvasInputAdapter-owned touch/Pencil input"
	)
	check_has(
		rect,
		"get_tree().create_timer(TOUCH_PERFECT_HOLD_SECONDS)",
		"stationary dwell must resolve without requiring another drag event"
	)
	check_has(
		rect,
		"draw_move(Vector2i(Global.canvas.current_pixel.floor()))",
		"the 1:1 preview must refresh immediately when the timer fires"
	)
	check_true(
		ADAPTER.long_press_motion_exceeds_slop(
			Vector2.ZERO, Vector2(ADAPTER.FINGER_LONG_PRESS_SLOP_PX, 0)
		),
		"D2 must inherit the same 12 px acquisition boundary verified by D1"
	)


func test_rectangle_and_ellipse_draw_tools_share_touch_perfect_hold() -> void:
	var src := FileAccess.get_file_as_string(BASE_SHAPE_SOURCE)
	check_has(
		src,
		"TOUCH_PERFECT_HOLD_SECONDS := 1.0",
		"Rectangle/Ellipse drawing must use the same 1000 ms dwell as Selection"
	)
	check_has(
		src,
		"CANVAS_INPUT_ADAPTER.long_press_motion_exceeds_slop",
		"drawing shapes must reuse the shared D1 touch slop"
	)
	check_has(
		src,
		"_touch_perfect_locked = true",
		"drawing shape 1:1 mode must remain locked through the current drag"
	)
	check_has(
		src,
		'Input.is_action_pressed(&"shape_perfect") or _touch_perfect_locked',
		"touch perfect-shape acquisition must extend rather than replace desktop modifiers"
	)
	check_has(
		src,
		"draw_move(Vector2i(Global.canvas.current_pixel.floor()))",
		"Rectangle/Ellipse preview must refresh immediately when dwell completes"
	)


func test_polygon_touch_completion_and_cancel_are_explicit() -> void:
	var src := FileAccess.get_file_as_string(POLYGON_SOURCE)
	check_has(
		src,
		"_consume_ios_touch_double_tap()",
		"Polygon touch input must have an iOS double-tap completion path"
	)
	check_has(
		src,
		"CANVAS_INPUT_ADAPTER.long_press_motion_exceeds_slop",
		"double-tap and first-point matching must reuse the shared touch slop"
	)
	check_has(
		src,
		"_is_ios_touch_close_to_first_point()",
		"the visible first point must be a touch-sized close target instead of exact-pixel only"
	)
	check_has(
		src,
		"pos = _draw_points[0]",
		"a touch hit on the first point must snap to the existing exact close/apply boundary"
	)
	check_has(
		src,
		"if pos == _draw_points[0] and _draw_points.size() > 1",
		"touch tolerance must preserve the existing polygon close-and-apply behavior"
	)
	check_has(
		src,
		'_touch_cancel_button.text = tr("Cancel polygon")',
		"an ongoing polygon must expose a touch-accessible explicit cancel action"
	)
	check_has(
		src,
		"_touch_cancel_button.pressed.connect(cancel_tool)",
		"the touch cancel action must use the existing cancellation boundary"
	)


func test_selection_modes_remain_the_existing_four_mode_model() -> void:
	var src := FileAccess.get_file_as_string(BASE_SELECTION_SOURCE)
	check_has(
		src,
		"enum Mode { DEFAULT, ADD, SUBTRACT, INTERSECT }",
		"Selection must retain the existing four-mode state model"
	)
	for label in [
		"Replace selection",
		"Add to selection",
		"Subtract from selection",
		"Intersection of selections"
	]:
		check_has(src, label, "all four existing Selection modes must remain visible in the UI")
	check_has(
		src,
		"func _on_modes_item_selected",
		"mobile Selection mode changes must continue through the existing mode model"
	)


func test_transform_touch_acceptance_keeps_existing_transform_model() -> void:
	var transform := FileAccess.get_file_as_string(TRANSFORM_SOURCE)
	var base := FileAccess.get_file_as_string(BASE_SELECTION_SOURCE)
	for transform_type in ["SCALE", "ROTATE", "SKEW", "PIVOT"]:
		check_has(
			transform,
			"TransformHandle.Type.%s" % transform_type,
			"Selection transform must retain the existing %s handle path" % transform_type
		)
	check_has(
		base,
		"transform_content_confirm",
		"touch confirmation must keep the existing transform commit boundary"
	)
	check_has(
		base,
		"transform_content_cancel",
		"touch cancellation must keep the existing transform rollback boundary"
	)
