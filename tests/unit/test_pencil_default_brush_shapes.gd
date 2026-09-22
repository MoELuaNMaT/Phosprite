extends "res://tests/test_base.gd"

const BrushShapes := preload("res://src/Tools/BrushShapeGenerator.gd")
const BASE_DRAW_SOURCE := "res://src/Tools/BaseDraw.gd"
const BASE_DRAW_SCENE := "res://src/Tools/BaseDraw.tscn"
const BRUSH_POPUP_SOURCE := "res://src/UI/Buttons/BrushesPopup.gd"


func test_default_square_masks_cover_filled_and_one_pixel_hollow_variants() -> void:
	check_eq(
		BrushShapes.get_points(BrushShapes.Shape.FILLED_SQUARE, 3).size(),
		9,
		"3px filled square must cover its complete 3x3 stamp",
	)
	check_eq(
		BrushShapes.get_points(BrushShapes.Shape.HOLLOW_SQUARE, 1).size(),
		1,
		"1px hollow square must collapse to the same single pixel as the filled square",
	)
	check_eq(
		BrushShapes.get_points(BrushShapes.Shape.HOLLOW_SQUARE, 2).size(),
		4,
		"2px hollow square has no interior and must cover all four pixels",
	)
	check_eq(
		BrushShapes.get_points(BrushShapes.Shape.HOLLOW_SQUARE, 3).size(),
		8,
		"3px hollow square must leave exactly the center pixel empty",
	)
	check_eq(
		BrushShapes.get_points(BrushShapes.Shape.HOLLOW_SQUARE, 5).size(),
		16,
		"5px hollow square must keep a one-pixel perimeter",
	)


func test_circle_masks_share_the_production_ellipse_rasterizer_and_stay_in_bounds() -> void:
	for size in [1, 2, 3, 7, 16]:
		var hollow := BrushShapes.get_points(BrushShapes.Shape.HOLLOW_CIRCLE, size)
		var filled := BrushShapes.get_points(BrushShapes.Shape.FILLED_CIRCLE, size)
		check_true(not hollow.is_empty(), "hollow circle mask must never be empty")
		check_true(not filled.is_empty(), "filled circle mask must never be empty")
		check_true(
			filled.size() >= hollow.size(),
			"filled circle must contain at least as many raster pixels as its outline",
		)
		for point in filled:
			check_true(
				point.x >= 0 and point.y >= 0 and point.x < size and point.y < size,
				"circle raster points must remain inside the requested brush bounding box",
			)


func test_preview_source_tracks_brush_size_but_is_safely_bounded() -> void:
	var one := BrushShapes.create_preview_image(BrushShapes.Shape.FILLED_SQUARE, 1)
	var sixteen := BrushShapes.create_preview_image(BrushShapes.Shape.FILLED_CIRCLE, 16)
	var huge := BrushShapes.create_preview_image(BrushShapes.Shape.FILLED_CIRCLE, 4096)
	check_eq(one.get_size(), Vector2i.ONE, "Size 1 preview must be generated from a one-pixel mask")
	check_eq(
		sixteen.get_size(),
		Vector2i(16, 16),
		"normal brush sizes must retain their native raster precision in the preview source",
	)
	check_eq(
		huge.get_size(),
		Vector2i.ONE * BrushShapes.PREVIEW_SOURCE_LIMIT,
		"very large brushes must cap preview source precision instead of allocating huge images",
	)


func test_pencil_preview_uses_fixed_visual_bounds_and_nearest_neighbor_scaling() -> void:
	var scene := FileAccess.get_file_as_string(BASE_DRAW_SCENE)
	check_has(scene, "offset_left = 4.0", "preview must keep a fixed inset inside the 32px brush button")
	check_has(scene, "offset_top = 4.0", "preview must keep a fixed inset inside the 32px brush button")
	check_has(scene, "offset_right = 28.0", "preview must keep a fixed 24px visual width")
	check_has(scene, "offset_bottom = 28.0", "preview must keep a fixed 24px visual height")
	check_has(scene, "texture_filter = 1", "preview scaling must remain nearest-neighbor")
	check_has(
		scene,
		"stretch_mode = 5",
		"preview must scale every source mask into the same centered aspect-fit visual box",
	)


func test_pencil_defaults_expose_four_shapes_without_renumbering_legacy_types() -> void:
	var popup := FileAccess.get_file_as_string(BRUSH_POPUP_SOURCE)
	check_has(
		popup,
		"enum { PIXEL, CIRCLE, FILLED_CIRCLE, FILE, RANDOM_FILE, CUSTOM, HOLLOW_SQUARE }",
		"new hollow square must append after persisted legacy brush type values",
	)
	for tooltip in [
		'"Square brush"',
		'"Hollow square brush"',
		'"Filled circle brush"',
		'"Hollow circle brush"',
	]:
		check_has(popup, tooltip, "Default Brushes must expose all four approved geometric shapes")
	check_has(
		popup,
		"if child.brush.type == type:",
		"legacy default brush restore must resolve by persisted type instead of changed display index",
	)


func test_base_draw_uses_procedural_preview_and_real_hollow_square_stamp() -> void:
	var source := FileAccess.get_file_as_string(BASE_DRAW_SOURCE)
	check_has(
		source,
		"BrushShapes.create_preview_image(shape, _brush_size)",
		"size changes must regenerate the selected default brush preview procedurally",
	)
	check_has(
		source,
		"Brushes.HOLLOW_SQUARE:",
		"BaseDraw must recognize the new hollow-square default brush",
	)
	check_has(
		source,
		"return _compute_draw_tool_hollow_square(pos)",
		"hollow-square selection must affect the real Pencil stamp rather than only its icon",
	)
