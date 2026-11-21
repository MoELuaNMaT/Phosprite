extends "res://tests/test_base.gd"

const Tokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")
const PixelStyle := preload("res://src/UI/DesignSystem/PhospritePixelStyle.gd")
const VisualTheme := preload("res://src/UI/Workspace/WorkspaceVisualTheme.gd")

const PAPER := Color("F2EFE9")
const INK := Color("2C2A29")
const SHADOW := Color("C9C2B6")


func _source_theme() -> Theme:
	var source := Theme.new()
	source.default_font = ThemeDB.fallback_font
	source.default_font_size = 16
	return source


func test_three_options_are_real_nine_slice_strokes_without_edge_gaps() -> void:
	for tier in [Tokens.TIER_L, Tokens.TIER_M, Tokens.TIER_S]:
		for unit in [1, 2, 3]:
			var style := PixelStyle.make_style(tier, PAPER, INK, SHADOW, true, unit)
			check_true(style != null, "all three pixel levels must render a stylebox")
			var image := style.texture.get_image()
			var side := Tokens.tier_size(tier, unit)
			var margin := Tokens.tier_texture_margin(tier, unit)
			check_eq(image.get_width(), side, "internal image width")
			check_eq(image.get_height(), side, "internal image height")
			check_eq(style.region_rect.size, Vector2(side, side), "nine-slice source region")
			check_eq(int(style.texture_margin_left), margin, "left slice matches source")
			check_eq(int(style.texture_margin_right), margin, "right slice matches source")
			check_eq(int(style.texture_margin_top), margin, "top slice matches source")
			check_eq(int(style.texture_margin_bottom), margin, "bottom slice matches source")
			check_eq(
				int(style.content_margin_left),
				Tokens.tier_content_margin(tier),
				"content padding must not grow with stroke width"
			)
			check_true(margin * 2 < side, "nine-slice center must not collapse")
			check_eq(image.get_pixel(0, 0).a, 0.0, "stepped corner remains transparent")
			# A broken 9-slice can repeat transparent columns along the entire
			# top/bottom border. Every pixel of its top center must be opaque.
			for x in range(margin, side - margin):
				check_eq(image.get_pixel(x, 0), INK, "top center has no missing pixels")
			for y in range(margin, side - margin):
				check_eq(image.get_pixel(0, y), INK, "left center has no missing pixels")
				check_eq(image.get_pixel(side - 1, y), SHADOW, "right shadow stays solid")
			check_eq(image.get_pixel(side / 2, side - 1), SHADOW, "bottom shadow must be preserved")


func test_one_two_three_pixel_strokes_have_expected_real_thickness() -> void:
	for unit in [1, 2, 3]:
		var style := PixelStyle.make_style(Tokens.TIER_L, PAPER, INK, SHADOW, false, unit)
		var image := style.texture.get_image()
		var x := int(image.get_width() / 2)
		for y in range(unit):
			check_eq(image.get_pixel(x, y), INK, "upper edge has selected stroke width")
		check_eq(image.get_pixel(x, unit), PAPER, "body starts after exact stroke width")
		check_eq(image.get_pixel(x, image.get_height() - unit), INK, "lower stroke is opaque")
		if unit > 1:
			check_eq(
				Tokens.corner_cutoffs(Tokens.TIER_L, unit)[0],
				Tokens.corner_cutoffs(Tokens.TIER_L, unit)[1],
				"larger visual pixel steps create visible staircase blocks"
			)
		var with_shadow := PixelStyle.make_style(Tokens.TIER_L, PAPER, INK, SHADOW, true, unit)
		var shadow_img := with_shadow.texture.get_image()
		var shadow_y := int(shadow_img.get_height() / 2)
		var shadow_start := shadow_img.get_width() - 2 * unit
		for x_shadow in range(shadow_start, shadow_img.get_width()):
			check_eq(
				shadow_img.get_pixel(x_shadow, shadow_y),
				SHADOW,
				"right-side shadow spans exactly 2x pixel unit"
			)


func test_workspace_refresh_updates_thickness_but_not_theme_or_geometry() -> void:
	var theme := VisualTheme.new()
	var base := Tokens.color(Tokens.SUNNY, &"panel_surface")
	var accent := Tokens.color(Tokens.SUNNY, &"accent_primary")
	var source := _source_theme()
	for unit in [1, 2, 3, 1]:
		check_true(theme.refresh(source, base, accent, 0.3, unit), "rebuild style on change")
		check_eq(theme.pixel_unit, unit, "live pixel unit retained")
		check_eq(theme.default_font, source.default_font, "never replace translated font")
		check_eq(theme.default_font_size, 16, "font size stays constant")
		var box := theme.get_render_module_style(&"floating") as StyleBoxTexture
		check_true(box != null, "floating module remains pixel styled")
		check_eq(
			int(box.texture_margin_top),
			Tokens.tier_texture_margin(Tokens.TIER_L, unit),
			"every switch must generate new corner geometry"
		)
		check_true(
			theme.get_render_module_style(&"bottom_bar") is StyleBoxFlat,
			"Timeline remains docked and unchanged"
		)
	check_true(
		theme.refresh(source, Color("30343c"), Color("8aa0df"), 0.3, 3),
		"legacy theme must still refresh"
	)
	check_true(
		theme.get_render_module_style(&"floating") is StyleBoxFlat,
		"legacy themes must never be pixel styled by this preference"
	)


func test_settings_store_pixel_unit_and_wire_live_workspace_refresh() -> void:
	var preferences := FileAccess.get_file_as_string("res://src/Preferences/PreferencesDialog.gd")
	var workspace := FileAccess.get_file_as_string("res://src/UI/UI.gd")
	var global := FileAccess.get_file_as_string("res://src/Autoload/Global.gd")
	for expected in [
		'["iPadPixelUISettings", "Interface", "Language"]',
		'"%dpx" % unit, unit',
		'Global.config_cache.set_value("preferences", "pixel_ui_unit", Global.pixel_ui_unit)',
		"Global.config_cache.save(Global.CONFIG_PATH)",
	]:
		check_has(preferences, expected, "iPad options are visible and persisted")
	check_has(
		workspace,
		"Global.pixel_ui_unit_changed.connect(_refresh_workspace_theme)",
		"changing setting must refresh the existing live Workspace"
	)
	check_has(global, "clampi(int(value), 1, 3)", "invalid saved pixel scale is clamped")
