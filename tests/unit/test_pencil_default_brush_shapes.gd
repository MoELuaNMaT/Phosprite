extends "res://tests/test_base.gd"

const BrushShapes := preload("res://src/Tools/BrushShapeGenerator.gd")
const BASE_DRAW_SOURCE := "res://src/Tools/BaseDraw.gd"
const BASE_DRAW_SCENE := "res://src/Tools/BaseDraw.tscn"
const BRUSH_POPUP_SOURCE := "res://src/UI/Buttons/BrushesPopup.gd"
const PENCIL_SOURCE := "res://src/Tools/DesignTools/Pencil.gd"
const PENCIL_SCENE := "res://src/Tools/DesignTools/Pencil.tscn"
const VALUE_SLIDER_SOURCE := "res://src/UI/Nodes/Sliders/ValueSlider.gd"


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


func test_preview_source_keeps_white_padding_around_black_brush_glyph() -> void:
	var one := BrushShapes.create_preview_image(BrushShapes.Shape.FILLED_SQUARE, 1)
	var sixteen := BrushShapes.create_preview_image(BrushShapes.Shape.FILLED_CIRCLE, 16)
	var huge := BrushShapes.create_preview_image(BrushShapes.Shape.FILLED_SQUARE, 4096)
	var padding := BrushShapes.PREVIEW_PADDING
	check_eq(
		one.get_size(),
		Vector2i.ONE * (1 + padding * 2),
		"1px brush preview must reserve visible white padding around the glyph",
	)
	check_eq(
		sixteen.get_size(),
		Vector2i.ONE * (16 + padding * 2),
		"normal brush previews must keep their native mask plus a white border",
	)
	check_eq(
		huge.get_size(),
		Vector2i.ONE * BrushShapes.PREVIEW_SOURCE_LIMIT,
		"very large brushes must remain bounded after padding is applied",
	)
	check_eq(one.get_pixel(0, 0), Color.WHITE, "preview corners must stay white")
	check_eq(
		one.get_pixel(padding, padding),
		Color.BLACK,
		"only the actual brush glyph pixels should be black",
	)
	check_eq(huge.get_pixel(0, 0), Color.WHITE, "large previews must also keep a white border")
	check_eq(
		huge.get_pixel(padding, padding),
		Color.BLACK,
		"large square glyphs must begin inside the white border rather than covering it",
	)


func test_pencil_preview_uses_fixed_visual_bounds_and_nearest_neighbor_scaling() -> void:
	var scene := FileAccess.get_file_as_string(BASE_DRAW_SCENE)
	check_has(
		scene, "offset_left = 4.0", "preview must keep a fixed inset inside the 32px brush button"
	)
	check_has(
		scene, "offset_top = 4.0", "preview must keep a fixed inset inside the 32px brush button"
	)
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
		"BrushShapes.create_preview_image(shape, _brush_size, Color.BLACK)",
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


func test_pencil_options_are_reduced_to_brush_size_and_opacity() -> void:
	var pencil_scene := FileAccess.get_file_as_string(PENCIL_SCENE)
	var pencil_source := FileAccess.get_file_as_string(PENCIL_SOURCE)
	check_has(pencil_scene, '[node name="Opacity"', "Pencil must expose an Opacity control")
	check_has(pencil_scene, "max_value = 100.0", "Pencil opacity must use a 0-100 percent range")
	for removed in ["Overwrite", "FillInside", "SpacingMode", 'name="Spacing"']:
		check_true(
			not pencil_scene.contains(removed),
			"Pencil scene must remove legacy option: %s" % removed
		)
	check_has(
		pencil_source,
		"$DensityValueSlider.visible = false",
		"Pencil must hide inherited Density even after BaseDraw refreshes brush state",
	)
	check_has(
		pencil_source,
		"_brush_density = 100",
		"hidden Pencil density must be fixed at 100 so stale saved density cannot affect drawing",
	)
	check_has(
		pencil_source,
		'config["strength"] = _strength',
		"Pencil opacity must persist through the existing strength channel",
	)
	for legacy_key in ["brush_density", "overwrite", "fill_inside", "spacing_mode", "spacing"]:
		check_has(
			pencil_source,
			'config.erase("%s")' % legacy_key,
			"Pencil must stop persisting removed option: %s" % legacy_key,
		)


func test_pencil_numeric_controls_use_drag_only_arrow_value_presentation() -> void:
	var base_scene := FileAccess.get_file_as_string(BASE_DRAW_SCENE)
	var pencil_scene := FileAccess.get_file_as_string(PENCIL_SCENE)
	var slider_source := FileAccess.get_file_as_string(VALUE_SLIDER_SOURCE)
	check_has(
		base_scene,
		'[node name="Brush" type="VBoxContainer"',
		"Brush controls must stack vertically"
	)
	check_has(
		base_scene,
		'[node name="BrushLabel" type="Label" parent="Brush"',
		"brush selector must have its name on a separate row above the button",
	)
	for scene_source in [base_scene, pencil_scene]:
		check_has(
			scene_source,
			"allow_text_input = false",
			"numeric Pencil controls must disable text entry"
		)
		check_has(
			scene_source,
			"show_drag_arrows = true",
			"numeric Pencil controls must show < value > drag affordance"
		)
		check_has(
			scene_source,
			"show_arrows = false",
			"numeric Pencil controls must remove old up/down arrow buttons"
		)
	check_has(
		slider_source,
		'return str(tr(prefix), " < ", display_value, " >").strip_edges()',
		"drag-only values must render in the requested < value > form",
	)


func test_tool_option_fields_put_names_above_numeric_and_checkbox_controls() -> void:
	var tool := BaseTool.new()
	var slider := ValueSlider.new()
	slider.name = &"Size"
	slider.prefix = "Size:"
	slider.show_drag_arrows = true
	tool.add_child(slider)
	var checkbox := CheckBox.new()
	checkbox.name = &"Continuous"
	checkbox.text = "Continuous"
	tool.add_child(checkbox)

	tool._apply_stacked_option_layout(tool)

	check_eq(tool.get_child_count(), 4, "each control should gain one separate label row")
	var size_label := tool.get_child(0) as Label
	check_true(size_label != null, "numeric option name must become a separate Label")
	check_eq(size_label.text, "Size:", "numeric option label must keep its name")
	check_eq(slider.prefix, "", "numeric value row must no longer repeat the option name")
	check_eq(
		slider.size_flags_horizontal,
		Control.SIZE_SHRINK_CENTER,
		"numeric drag control should sit centered on the row below its name",
	)
	var checkbox_label := tool.get_child(2) as Label
	check_true(checkbox_label != null, "checkbox option name must become a separate Label")
	check_eq(
		checkbox_label.text,
		"Continuous:",
		"checkbox labels should receive the same name-above-control presentation",
	)
	check_eq(checkbox.text, "", "checkbox row itself must contain only the checkbox control")
	check_eq(
		checkbox.size_flags_horizontal,
		Control.SIZE_SHRINK_CENTER,
		"checkbox control should sit centered on the row below its name",
	)
	tool.free()
