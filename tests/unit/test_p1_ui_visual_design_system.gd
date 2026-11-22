extends "res://tests/test_base.gd"

const Tokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")
const PixelStyle := preload("res://src/UI/DesignSystem/PhospritePixelStyle.gd")
const VisualTheme := preload("res://src/UI/Workspace/WorkspaceVisualTheme.gd")


func _source_theme() -> Theme:
	var theme := Theme.new()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("30343c")
	theme.set_stylebox(&"panel", &"PanelContainer", panel)
	theme.set_color(&"font_color", &"Label", Color("edf2f8"))
	theme.default_font = ThemeDB.fallback_font
	theme.default_font_size = 17
	return theme


func test_exact_semantic_colors_and_explicit_preset_detection() -> void:
	check_eq(
		Tokens.color(Tokens.SUNNY, &"panel_surface"),
		Color("F2EFE9"),
		"Sunny Cream panel surface must match its production hex token"
	)
	check_eq(
		Tokens.color(Tokens.TWILIGHT, &"panel_surface"),
		Color("242220"),
		"Twilight Berry panel surface must match its production hex token"
	)
	check_eq(
		Tokens.color(Tokens.SUNNY, &"pixel_shadow"),
		Color("C9C2B6"),
		"Sunny Cream should never fall back to a blurry gray shadow"
	)
	for mode in [Tokens.SUNNY, Tokens.TWILIGHT]:
		check_eq(
			Tokens.detect_mode(
				Tokens.color(mode, &"panel_surface"), Tokens.color(mode, &"accent_primary")
			),
			mode,
			"only a complete matching color pair should select a new preset"
		)
	check_eq(
		Tokens.detect_mode(Color("F2EFE9"), Color("F06D4F")),
		Tokens.LEGACY,
		"a mixed/partial color pair must not opt into pixel chrome"
	)
	check_eq(
		Tokens.detect_mode(Color("30343c"), Color("8aa0df")),
		Tokens.LEGACY,
		"existing user themes must keep their legacy rendering path"
	)


func test_three_pixel_nine_slice_tiers_use_integer_margins_and_crisp_corners() -> void:
	for tier in [Tokens.TIER_L, Tokens.TIER_M, Tokens.TIER_S]:
		var side: int = Tokens.tier_size(tier)
		var margin: int = Tokens.tier_texture_margin(tier)
		var content: int = Tokens.tier_content_margin(tier)
		var style := PixelStyle.make_style(tier, Color("F2EFE9"), Color("2C2A29"), Color("C9C2B6"))
		check_true(style is StyleBoxTexture, "each tier must produce a nine-slice style")
		check_eq(style.region_rect.size, Vector2(side, side), "tier image dimensions")
		check_eq(int(style.texture_margin_left), margin, "nine-slice left margin")
		check_eq(int(style.texture_margin_top), margin, "nine-slice top margin")
		check_eq(int(style.texture_margin_right), margin, "nine-slice right margin")
		check_eq(int(style.texture_margin_bottom), margin, "nine-slice bottom margin")
		check_eq(int(style.content_margin_left), content, "content left margin")
		check_eq(int(style.content_margin_top), content, "content top margin")
		var image: Image = style.texture.get_image()
		check_eq(image.get_width(), side, "image width must match spec")
		check_eq(image.get_height(), side, "image height must match spec")
		check_eq(image.get_pixel(0, 0).a, 0.0, "pixel corner must be fully transparent")
		check_eq(
			image.get_pixel(side / 2, 0),
			Color("2C2A29"),
			"topmost border should be a solid non-antialiased ink pixel"
		)
		check_eq(
			image.get_pixel(side / 2, side / 2),
			Color("F2EFE9"),
			"interior must keep the exact fill color"
		)


func test_floating_shadow_is_hard_two_pixel_offset() -> void:
	var style := PixelStyle.make_style(
		Tokens.TIER_L, Color("F2EFE9"), Color("2C2A29"), Color("C9C2B6"), true
	)
	var image: Image = style.texture.get_image()
	check_eq(image.get_pixel(23, 12), Color("C9C2B6"), "right-side shadow is exactly 2px")
	check_eq(image.get_pixel(12, 23), Color("C9C2B6"), "bottom shadow is exactly 2px")
	check_eq(image.get_pixel(0, 0).a, 0.0, "outermost corner should remain transparent")
	check_eq(image.get_pixel(12, 12), Color("F2EFE9"), "opaque body must cover shadow")


func test_button_states_preserve_fonts_and_change_only_visual_resources() -> void:
	var theme := PixelStyle.make_button_theme(Tokens.SUNNY)
	check_true(theme != null, "Sunny button style must exist")
	check_true(not theme.has_default_font(), "button theme must not override translated fonts")
	for state in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		check_true(theme.get_stylebox(state, &"Button") is StyleBoxTexture, "R6 %s style" % state)
	var normal := theme.get_stylebox(&"normal", &"Button") as StyleBoxTexture
	var pressed := theme.get_stylebox(&"pressed", &"Button") as StyleBoxTexture
	check_eq(
		normal.texture.get_image().get_pixel(19, 9),
		Color("C9C2B6"),
		"normal button has a hard lower-right shadow"
	)
	check_eq(
		pressed.texture.get_image().get_pixel(19, 9),
		Color("2C2A29"),
		"pressed button has no shadow and retains its own 1px outline"
	)
	check_eq(theme.get_color(&"font_color", &"Button"), Color("242220"), "text ink token")
	check_true(PixelStyle.make_button_theme(Tokens.LEGACY) == null, "legacy not overridden")


func test_workspace_chrome_opt_in_and_legacy_round_trip() -> void:
	var source := _source_theme()
	var theme := VisualTheme.new()
	var sunny_base := Tokens.color(Tokens.SUNNY, &"panel_surface")
	var sunny_accent := Tokens.color(Tokens.SUNNY, &"accent_primary")
	check_true(theme.refresh(source, sunny_base, sunny_accent), "Sunny theme should refresh")
	check_eq(theme.pixel_mode, Tokens.SUNNY, "new theme should opt into pixel mode")
	check_true(
		theme.get_render_module_style(&"floating") is StyleBoxTexture,
		"only opted-in Workspace floating chrome should switch to nine-slice"
	)
	check_true(
		theme.get_render_header_style(&"floating") is StyleBoxTexture,
		"floating header should use the same pixel tier"
	)
	check_true(
		theme.get_render_module_style(&"bottom_bar") is StyleBoxTexture,
		"Stage 4 pixel Timeline surface must use the same opt-in nine-slice skin"
	)
	check_true(
		theme.get_render_module_style(&"docked") is StyleBoxTexture,
		"Stage 4 docked UI1/UI4 panels use opt-in pixel chrome"
	)
	check_eq(theme.get_module_style(&"floating").shadow_size, 0, "no soft floating shadow")
	check_eq(theme.default_font_size, 17, "source font size must stay unchanged")
	check_eq(theme.default_font, ThemeDB.fallback_font, "source font must remain unchanged")

	var dark_base := Tokens.color(Tokens.TWILIGHT, &"panel_surface")
	var dark_accent := Tokens.color(Tokens.TWILIGHT, &"accent_primary")
	check_true(theme.refresh(source, dark_base, dark_accent), "Twilight should refresh")
	check_eq(theme.pixel_mode, Tokens.TWILIGHT, "dark preset should opt into pixel mode")
	check_eq(theme.surface_color, Color("242220"), "dark surface should use semantic token")

	check_true(
		theme.refresh(source, Color("30343c"), Color("8aa0df")),
		"existing theme must remain switchable"
	)
	check_eq(theme.pixel_mode, Tokens.LEGACY, "legacy mode should restore after switching back")
	check_true(
		theme.get_render_module_style(&"floating") is StyleBoxFlat,
		"legacy floating style should be restored, not retained from the pilot"
	)
	check_eq(theme.get_module_style(&"floating").shadow_size, 3, "legacy shadow unchanged")
	check_true(
		theme.get_render_module_style(&"bottom_bar") is StyleBoxFlat,
		"legacy Timeline must regain its original attached panel material"
	)
	check_eq(theme.default_font_size, 17, "font size survives round trip")
