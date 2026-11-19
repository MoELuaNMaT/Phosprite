extends "res://tests/test_base.gd"

const Tokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")
const Stage4 := preload("res://src/UI/DesignSystem/PhospriteStage4Chrome.gd")
const PixelDraw := preload("res://src/UI/DesignSystem/PhospriteDraw.gd")


func test_stage4_swatch_rect_preserves_28px_color_area_inside_32px_cell() -> void:
	check_eq(
		PixelDraw.swatch_rect(Vector2(32, 32)),
		Rect2i(2, 2, 28, 28),
		"the iPad 32px touch cell must contain a 28px pixel swatch",
	)
	check_eq(PixelDraw.swatch_rect(Vector2(8, 8)), Rect2i(2, 2, 4, 4), "small cells stay bounded")


func test_stage4_button_chrome_is_opt_in_and_reversible() -> void:
	var button := Button.new()
	var original_filter := button.texture_filter
	var original_flat := button.flat
	var original_size := button.custom_minimum_size
	Stage4.style_button(button, Tokens.SUNNY)
	check_true(button.has_theme_stylebox_override(&"normal"), "pixel normal needs R6 chrome")
	check_true(button.has_theme_stylebox_override(&"pressed"), "pixel pressed needs R6 chrome")
	check_true(button.has_theme_stylebox_override(&"disabled"), "pixel disabled needs R6 chrome")
	check_eq(
		button.texture_filter,
		CanvasItem.TEXTURE_FILTER_NEAREST,
		"pixel background uses nearest sampling",
	)
	check_eq(button.custom_minimum_size, original_size, "styling never changes the touch rect")
	Stage4.style_button(button, Tokens.LEGACY)
	check_true(
		not button.has_theme_stylebox_override(&"normal"),
		"legacy theme removes Stage 4 normal override",
	)
	check_eq(button.texture_filter, original_filter, "theme switching restores sampling")
	check_eq(button.flat, original_flat, "theme switching restores flat state")
	button.free()


func test_stage4_pixel_styling_does_not_override_fonts() -> void:
	var src := FileAccess.get_file_as_string(
		"res://src/UI/DesignSystem/PhospriteStage4Chrome.gd"
	)
	check_true(not ("default_font" in src), "font fallback must stay owned by global Theme")
	check_true(not ("add_theme_font_override" in src), "CJK font must not be replaced")


func test_stage4_palette_uses_actual_swatch_color_not_selected_index() -> void:
	var swatch := FileAccess.get_file_as_string("res://src/Palette/PaletteSwatch.gd")
	var grid := FileAccess.get_file_as_string("res://src/Palette/PaletteGrid.gd")
	check_has(swatch, "PixelDraw.draw_pixel_swatch_r4", "swatch visuals use pixel renderer")
	check_has(swatch, "color = new_color", "swatch color remains the source color")
	check_has(grid, "_find_exact_color_index", "palette selection derives from actual brush color")
	check_has(grid, "IOS_TOUCH_REORDER_HOLD_MSEC", "palette hold-to-reorder stays installed")
	check_has(grid, "pending_empty_palette_index", "empty cell double-tap behavior stays installed")


func test_stage4_retains_two_layer_drag_release_fix() -> void:
	var source := FileAccess.get_file_as_string("res://src/UI/Timeline/LayerMainButton.gd")
	check_has(source, "_apply_layer_drop.call_deferred(", "layer move stays deferred until input end")


func test_stage4_ui1_vertical_scrub_and_ui4_split_touch_are_unchanged() -> void:
	var slider := FileAccess.get_file_as_string(
		"res://src/UI/Nodes/Sliders/ValueSlider.gd"
	)
	var ui4 := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceUIProfile4.gd"
	)
	check_has(slider, "func configure_tool_vertical_drag()", "existing vertical scrub is retained")
	check_has(slider, "tool_vertical_drag = true", "existing vertical drag setting stays true")
	check_has(slider, "Stage4.draw_scrubby_pill", "only vertical value visuals change")
	check_has(ui4, "_split_handle.gui_input.connect(_on_split_handle_input)", "UI4 splitter gestures stay native")
	check_has(ui4, "_split_handle.draw.connect(_draw_stage4_split_handle)", "UI4 adds visual grip only")


func test_stage4_preserves_36px_existing_timeline_cells() -> void:
	var scene := FileAccess.get_file_as_string("res://src/UI/Timeline/CelButton.tscn")
	check_has(scene, "custom_minimum_size = Vector2(36, 36)", "frame cells stay 36 by 36")
	var layer_touch := FileAccess.get_file_as_string(
		"res://src/UI/Timeline/LayerTouchAdapter.gd"
	)
	check_has(layer_touch, "IOS_TOUCH_REORDER_HOLD_MSEC := 450", "layer reorder gesture stays 450ms")
