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
		"BrushShapes.create_preview_image(shape, icon_size, Color.BLACK)",
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


func test_pencil_options_are_reduced_to_brush_size_opacity_and_dither() -> void:
	var pencil_scene := FileAccess.get_file_as_string(PENCIL_SCENE)
	var pencil_source := FileAccess.get_file_as_string(PENCIL_SOURCE)
	check_has(pencil_scene, '[node name="Opacity"', "Pencil must expose an Opacity control")
	check_has(pencil_scene, "max_value = 100.0", "Pencil opacity must use a 0-100 percent range")
	check_has(pencil_scene, '[node name="Dither" type="CheckBox"', "Pencil must expose Dither")
	check_has(
		pencil_scene,
		'[node name="Pattern" type="OptionButton" parent="DitherSettings/PatternRow"',
		"Dither must expose an ordered-pattern selector",
	)
	check_has(
		pencil_scene,
		'[node name="Coverage" parent="DitherSettings"',
		"Dither must expose a coverage percentage control",
	)
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
	check_has(
		pencil_source,
		"const DITHER_SIZES := [2, 4, 8, 16]",
		"Pencil must offer stable Bayer matrix sizes",
	)
	for dither_key in ["dither_enabled", "dither_size", "dither_coverage"]:
		check_has(
			pencil_source,
			'config["%s"]' % dither_key,
			"Dither option must persist: %s" % dither_key,
		)
	check_has(
		pencil_source,
		"not _dither_allows_pixel(pos)",
		"geometric Pencil stamps must skip pixels through the dither rule",
	)
	check_has(
		pencil_source,
		"_apply_dither_to_brush_image(effective_brush, src_rect, dst)",
		"image brushes must use the same canvas-space dither rule",
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
		check_true(
			not scene_source.contains("show_drag_arrows = true"),
			"tool scenes must not request legacy left/right drag arrows"
		)
	check_has(
		slider_source,
		"func configure_tool_vertical_drag() -> void:",
		"tool value controls must support transparent vertical arrow mode",
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
	check_eq(size_label.text, "Size", "numeric option label must remove its colon")
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
		"Continuous",
		"checkbox labels should use the same centered no-colon presentation",
	)
	check_eq(checkbox.text, "", "checkbox row itself must contain only the checkbox control")
	check_eq(
		checkbox.size_flags_horizontal,
		Control.SIZE_SHRINK_CENTER,
		"checkbox control should sit centered on the row below its name",
	)
	tool.free()


func test_all_tool_numeric_options_are_drag_only_and_precision_tools_are_slower() -> void:
	var generic_tool := BaseTool.new()
	generic_tool.name = &"Bucket"
	var generic_slider := ValueSlider.new()
	generic_slider.prefix = "Tolerance:"
	generic_tool.add_child(generic_slider)
	generic_tool._apply_stacked_option_layout(generic_tool)
	check_true(not generic_slider.allow_text_input, "tool numeric controls must disable text input")
	check_true(
		generic_slider.tool_vertical_drag, "tool numeric controls must use vertical drag mode"
	)
	check_true(
		not generic_slider.show_arrows, "tool numeric controls must hide legacy arrow buttons"
	)
	check_true(
		not generic_slider.show_progress, "tool numeric controls should use pure drag presentation"
	)
	check_eq(
		generic_slider.drag_sensitivity,
		1.0,
		"ordinary tools should keep the default numeric drag sensitivity",
	)
	check_eq(generic_slider.prefix, "", "stacked numeric controls should move their name above")

	generic_tool.free()

	for tool_name in ["Pencil", "Eraser"]:
		var precision_tool := BaseTool.new()
		precision_tool.name = tool_name
		var size_slider := ValueSlider.new()
		size_slider.name = &"BrushSize"
		size_slider.prefix = "Size:"
		precision_tool.add_child(size_slider)
		var opacity_slider := ValueSlider.new()
		opacity_slider.name = &"Opacity"
		opacity_slider.prefix = "Opacity:"
		precision_tool.add_child(opacity_slider)
		precision_tool._apply_stacked_option_layout(precision_tool)
		check_eq(
			size_slider.drag_sensitivity,
			BaseTool.PRECISION_BRUSH_SIZE_DRAG_SENSITIVITY,
			"%s brush size dragging must use the extra-slow sensitivity" % tool_name,
		)
		check_eq(
			opacity_slider.drag_sensitivity,
			BaseTool.PRECISION_TOOL_DRAG_SENSITIVITY,
			"%s opacity dragging must keep the existing precision sensitivity" % tool_name,
		)
		check_eq(
			size_slider.custom_minimum_size.x,
			BaseTool.SIDEBAR_CONTROL_WIDTH,
			"%s numeric control must fit the narrow sidebar" % tool_name,
		)
		precision_tool.free()


func test_value_slider_drag_math_uses_configurable_sensitivity() -> void:
	var slider_source := FileAccess.get_file_as_string(VALUE_SLIDER_SOURCE)
	check_has(
		slider_source,
		"@export_range(0.05, 2.0, 0.05) var drag_sensitivity := 1.0",
		"ValueSlider must expose a reusable drag-sensitivity multiplier",
	)
	check_has(
		slider_source,
		"var drag_delta := axis_delta * drag_sensitivity",
		"pointer delta must be scaled before numeric values are changed",
	)


func test_sidebar_labels_and_nested_numeric_prefixes_are_centered_without_colons() -> void:
	var tool := BaseTool.new()
	var title := Label.new()
	title.text = "Mode:"
	tool.add_child(title)
	var pair := ValueSliderV2.new()
	tool.add_child(pair)
	tool._apply_stacked_option_layout(tool)
	check_eq(
		title.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "option labels must be centered"
	)
	check_eq(title.text, "Mode", "option labels must drop trailing colons")
	for slider in pair.get_sliders():
		check_true(not slider.prefix.ends_with(":"), "nested X/Y numeric prefixes must drop colons")
		check_true(slider.tool_vertical_drag, "nested X/Y controls must use vertical dragging")
		check_eq(
			slider.custom_minimum_size.x,
			BaseTool.SIDEBAR_CONTROL_WIDTH,
			"nested numeric controls must use the compact right-column width",
		)
	tool.free()


func test_ipad_brush_popup_hides_pc_file_categories_and_keeps_preview_centered() -> void:
	var popup_src := FileAccess.get_file_as_string(BRUSH_POPUP_SOURCE)
	var popup_scene := FileAccess.get_file_as_string("res://src/UI/Buttons/BrushesPopup.tscn")
	var base_draw_src := FileAccess.get_file_as_string(BASE_DRAW_SOURCE)
	check_has(
		popup_src,
		'return OS.get_name() == "iOS" or Global.single_tool_mode',
		"iPad brush mode must activate on iOS and single-tool iPad layout",
	)
	check_has(
		popup_src,
		"func popup_for_button(",
		"BrushesPopup must size and position itself cleanly for iPad geometric brush switching",
	)
	check_has(
		popup_src,
		"if is_ipad_brush_mode() and type in [FILE, RANDOM_FILE]:",
		"persisted PC file brush types must fall back to the default geometric brush on iPad",
	)
	check_has(
		base_draw_src,
		"Global.brushes_popup.popup_for_button(brush_button, tool_option_container)",
		"Pencil and Eraser must open the compact iPad brush switcher instead of desktop column math",
	)
	check_has(
		popup_scene,
		(
			'[node name="FileLabel" type="Label" parent="Background/Brushes/Categories"'
			+ " unique_id=1705630477]\nvisible = false"
		),
		"File Brushes heading must start hidden in BrushesPopup scene",
	)
	var tool := BaseTool.new()
	var brush_btn := Button.new()
	brush_btn.name = &"Type"
	var preview := TextureRect.new()
	preview.name = &"Texture"
	brush_btn.add_child(preview)
	tool.add_child(brush_btn)
	tool._apply_stacked_option_layout(tool)
	check_eq(
		brush_btn.size_flags_horizontal,
		Control.SIZE_SHRINK_CENTER,
		"Brush preview button must stay centered instead of stretching across the sidebar",
	)
	check_eq(
		brush_btn.custom_minimum_size,
		Vector2(32.0, 32.0),
		"Brush preview button must keep its 32x32 square bounds",
	)
	tool.free()


func test_brush_preview_buttons_render_black_scaled_glyph_and_keep_dark_border_on_focus() -> void:
	for scene_path in [
		"res://src/Tools/DesignTools/Pencil.tscn",
		"res://src/Tools/DesignTools/Eraser.tscn",
		"res://src/Tools/DesignTools/RectangleTool.tscn",
		"res://src/Tools/DesignTools/EllipseTool.tscn",
		"res://src/Tools/DesignTools/LineTool.tscn",
	]:
		var tool := (load(scene_path) as PackedScene).instantiate() as BaseDrawTool
		var brush_btn := tool.get_node(^"Brush/Type") as Button
		var preview_rect := tool.get_node(^"Brush/Type/Texture") as TextureRect
		check_eq(
			brush_btn.focus_mode,
			Control.FOCUS_NONE,
			(
				"%s brush button must disable focus so tapping never paints a white focus overlay"
				% scene_path
			),
		)
		for style_name in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
			var sb := brush_btn.get_theme_stylebox(style_name) as StyleBoxFlat
			check_true(
				sb != null,
				"%s brush button %s style must be StyleBoxFlat" % [scene_path, style_name]
			)
			if sb != null:
				check_eq(
					sb.border_width_left,
					2,
					"%s brush button %s style must keep a 2px border" % [scene_path, style_name],
				)
				check_true(
					sb.border_color.get_luminance() < 0.3,
					(
						"%s brush button %s style must keep a dark ink border"
						% [scene_path, style_name]
					),
				)
		tool._brush = Brushes.get_default_brush()
		tool._brush_size = 1
		tool._refresh_default_brush_preview()
		check_true(preview_rect.visible, "%s brush preview rect must be visible" % scene_path)
		check_eq(
			preview_rect.size,
			Vector2(24.0, 24.0),
			"%s brush preview rect must be 24x24" % scene_path
		)
		check_eq(
			preview_rect.modulate,
			Color.WHITE,
			"%s brush preview rect must stay un-tinted" % scene_path
		)
		check_true(
			preview_rect.texture != null, "%s brush preview texture must be assigned" % scene_path
		)
		var img_small := preview_rect.texture.get_image()
		check_eq(
			img_small.get_pixel(img_small.get_width() / 2, img_small.get_height() / 2),
			Color.BLACK,
			"%s 1px brush preview must draw black in the center" % scene_path,
		)
		tool._brush_size = 10
		tool._refresh_default_brush_preview()
		var img_large := preview_rect.texture.get_image()
		check_true(
			img_large.get_width() > img_small.get_width(),
			"%s 10px brush preview must scale with brush size" % scene_path,
		)
		check_eq(
			img_large.get_pixel(img_large.get_width() / 2, img_large.get_height() / 2),
			Color.BLACK,
			"%s 10px brush preview must draw black in the center" % scene_path,
		)
		var hollow_brush := Brushes.Brush.new()
		hollow_brush.type = Brushes.HOLLOW_SQUARE
		tool._brush = hollow_brush
		tool._brush_size = 1
		tool._refresh_default_brush_preview()
		var img_hollow := preview_rect.texture.get_image()
		check_eq(
			img_hollow.get_pixel(img_hollow.get_width() / 2, img_hollow.get_height() / 2),
			Color.WHITE,
			"%s 1px hollow square preview must keep a visible white center" % scene_path,
		)
		check_eq(
			img_hollow.get_pixel(2, 2),
			Color.BLACK,
			"%s 1px hollow square preview must draw a visible black outline" % scene_path,
		)
		var glyph_overlay := brush_btn.get_node_or_null(^"BrushGlyphOverlay") as Control
		check_true(
			glyph_overlay != null and glyph_overlay.visible,
			"%s brush button must attach a visible direct-draw BrushGlyphOverlay" % scene_path,
		)
		tool.free()
