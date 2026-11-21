class_name PhospriteStage2Chrome
extends RefCounted

## Reusable, opt-in pixel UI chrome for Stage 2 (Gallery and editor top bars).
## Does not alter the shared Theme, user canvas, project data or touch handlers.
## Every override can be removed when switching back to a legacy preset.

const Tokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")
const PixelStyle := preload("res://src/UI/DesignSystem/PhospritePixelStyle.gd")

const BUTTON_STYLES := [&"normal", &"hover", &"pressed", &"disabled", &"focus"]
const BUTTON_COLORS := [
	&"font_color",
	&"font_hover_color",
	&"font_pressed_color",
	&"font_disabled_color",
	&"font_focus_color",
	&"icon_normal_color",
	&"icon_hover_color",
	&"icon_pressed_color",
	&"icon_disabled_color",
	&"icon_focus_color"
]

static var _panel_cache: Dictionary = {}
static var _shell_cache: Dictionary = {}
static var _button_cache: Dictionary = {}


static func active_mode() -> StringName:
	if Global.theme_preset_index == Themes.CUSTOM_THEME_INDEX:
		return Tokens.LEGACY
	return Tokens.detect_mode(Global.theme_base_color, Global.theme_accent_color)


static func make_panel(
	mode: StringName, tier: StringName, surface: StringName, with_shadow := false
) -> StyleBoxTexture:
	if mode == Tokens.LEGACY:
		return null
	var unit := clampi(Global.pixel_ui_unit, 1, 3)
	var key := "%s|%s|%s|%d|%d" % [mode, tier, surface, int(with_shadow), unit]
	if _panel_cache.has(key):
		return _panel_cache[key] as StyleBoxTexture
	var style := PixelStyle.make_style(
		tier,
		Tokens.color(mode, surface),
		Tokens.color(mode, &"outline_ink"),
		Tokens.color(mode, &"pixel_shadow"),
		with_shadow,
		unit
	)
	if style != null:
		_panel_cache[key] = style
	return style


## Gallery panels already have child MarginContainers and card content insets.
## Do not add the nine-slice's default 8px content padding a second time:
## that would inflate the 64px Gallery topbar and crop card thumbnails.
## This changes only Control layout margins, not the pixel border artwork.
static func make_shell(
	mode: StringName, tier: StringName, surface: StringName, with_shadow := false
) -> StyleBoxTexture:
	if mode == Tokens.LEGACY:
		return null
	var unit := clampi(Global.pixel_ui_unit, 1, 3)
	var key := "%s|%s|%s|%d|%d" % [mode, tier, surface, int(with_shadow), unit]
	if _shell_cache.has(key):
		return _shell_cache[key] as StyleBoxTexture
	var style := PixelStyle.make_style(
		tier,
		Tokens.color(mode, surface),
		Tokens.color(mode, &"outline_ink"),
		Tokens.color(mode, &"pixel_shadow"),
		with_shadow,
		unit
	)
	if style != null:
		style.content_margin_left = 0.0
		style.content_margin_top = 0.0
		style.content_margin_right = 0.0
		style.content_margin_bottom = 0.0
		_shell_cache[key] = style
	return style


static func _button_styles(mode: StringName, cta: bool) -> Dictionary:
	var unit := clampi(Global.pixel_ui_unit, 1, 3)
	var key := "%s|%d|%d" % [mode, unit, int(cta)]
	if _button_cache.has(key):
		return _button_cache[key] as Dictionary
	var normal_surface := &"accent_cta_coral" if cta else &"panel_surface"
	var outline := Tokens.color(mode, &"outline_ink")
	var shadow := Tokens.color(mode, &"pixel_shadow")
	var styles := {
		&"normal": make_panel(mode, Tokens.TIER_M, normal_surface, true),
		&"hover":
		make_panel(mode, Tokens.TIER_M, &"accent_cta_coral" if cta else &"accent_soft", true),
		&"pressed":
		PixelStyle.make_style(
			Tokens.TIER_M, Tokens.color(mode, &"accent_primary"), outline, shadow, false, unit, true
		),
		&"disabled": make_panel(mode, Tokens.TIER_M, &"well_surface"),
		&"focus":
		PixelStyle.make_style(
			Tokens.TIER_M,
			Tokens.color(mode, normal_surface),
			Tokens.color(mode, &"accent_primary"),
			shadow,
			false,
			unit
		),
	}
	_button_cache[key] = styles
	return styles


static func style_button(button: Button, mode: StringName, cta := false) -> void:
	if not is_instance_valid(button):
		return
	if mode == Tokens.LEGACY:
		clear_button(button)
		return
	if not button.has_meta(&"stage2_legacy_texture_filter"):
		button.set_meta(&"stage2_legacy_texture_filter", button.texture_filter)
	if button.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var styles := _button_styles(mode, cta)
	for key in BUTTON_STYLES:
		var target := styles[key] as StyleBox
		if not button.has_theme_stylebox_override(key) or button.get_theme_stylebox(key) != target:
			button.add_theme_stylebox_override(key, target)
	var color := Tokens.color(mode, &"text_primary")
	var muted := Tokens.color(mode, &"text_muted")
	for key in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		var target_c := Color.WHITE if key == &"font_pressed_color" else color
		if not button.has_theme_color_override(key) or button.get_theme_color(key) != target_c:
			button.add_theme_color_override(key, target_c)
	if (
		not button.has_theme_color_override(&"font_disabled_color")
		or (button.get_theme_color(&"font_disabled_color") != muted)
	):
		button.add_theme_color_override(&"font_disabled_color", muted)
	# Q icons are colored PNGs, not monochrome SVG masks. Keep their actual pixels.
	for key in [
		&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_focus_color"
	]:
		if not button.has_theme_color_override(key) or button.get_theme_color(key) != Color.WHITE:
			button.add_theme_color_override(key, Color.WHITE)
	var disabled_icon := Color(1.0, 1.0, 1.0, 0.5)
	if (
		not button.has_theme_color_override(&"icon_disabled_color")
		or (button.get_theme_color(&"icon_disabled_color") != disabled_icon)
	):
		button.add_theme_color_override(&"icon_disabled_color", disabled_icon)


static func clear_button(button: Button) -> void:
	if not is_instance_valid(button):
		return
	for key in BUTTON_STYLES:
		button.remove_theme_stylebox_override(key)
	for key in BUTTON_COLORS:
		button.remove_theme_color_override(key)
	if button.has_meta(&"stage2_legacy_texture_filter"):
		button.texture_filter = int(button.get_meta(&"stage2_legacy_texture_filter"))
		button.remove_meta(&"stage2_legacy_texture_filter")
