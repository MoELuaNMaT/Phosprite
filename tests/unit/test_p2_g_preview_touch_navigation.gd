extends "res://tests/test_base.gd"


func test_preview_touch_navigation_reuses_canvas_math_without_zoom_slider() -> void:
	var scene_source := FileAccess.get_file_as_string(
		"res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.tscn"
	)
	var preview_source := FileAccess.get_file_as_string(
		"res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.gd"
	)
	var adapter_source := FileAccess.get_file_as_string(
		"res://src/InputAdapter/CanvasInputAdapter.gd"
	)
	check_true(
		not scene_source.contains("PreviewZoomSlider"),
		"Preview should no longer expose the legacy zoom slider"
	)
	check_true(
		scene_source.contains('groups=["CanvasTouchBlockers"]'),
		"Preview content should block touch-through into the full-background Main Canvas"
	)
	check_true(
		(
			preview_source.contains("InputEventScreenTouch")
			and preview_source.contains("InputEventScreenDrag")
		),
		"Preview should own raw two-finger touch navigation on iOS"
	)
	check_true(
		(
			preview_source.contains("NAVIGATION.navigation_pair_geometry")
			and preview_source.contains("NAVIGATION.navigation_zoom_from_ratio")
			and preview_source.contains("NAVIGATION.navigation_offset_for_anchor")
		),
		"Preview should reuse the Canvas navigation geometry, zoom and anchored-pan math"
	)
	check_true(
		(
			adapter_source.contains("CANVAS_TOUCH_BLOCKER_GROUP")
			and adapter_source.contains("get_nodes_in_group(CANVAS_TOUCH_BLOCKER_GROUP)")
		),
		"Main Canvas touch arbitration should reject touches that begin over Preview"
	)
