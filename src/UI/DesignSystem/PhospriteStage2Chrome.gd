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


static func active_mode() -> StringName:
	if Global.theme_preset_index == Themes.CUSTOM_THEME_INDEX:
		return Tokens.LEGACY
	return Tokens.detect_mode(Global.theme_base_color, Global.theme_accent_color)


static func make_panel(
	mode: StringName, tier: StringName, surface: StringName, with_shadow := false
) -> StyleBoxTexture:
	if mode == Tokens.LEGACY:
		return null
	return PixelStyle.make_style(
		tier,
		Tokens.color(mode, surface),
		Tokens.color(mode, &"outline_ink"),
		Tokens.color(mode, &"pixel_shadow"),
		with_shadow,
		Global.pixel_ui_unit
	)


static func style_button(button: Button, mode: StringName, cta := false) -> void:
	if not is_instance_valid(button):
		return
	if mode == Tokens.LEGACY:
		clear_button(button)
		return
	var normal_surface := &"accent_cta_coral" if cta else &"panel_surface"
	var color := Tokens.color(mode, &"text_primary")
	var outline := Tokens.color(mode, &"outline_ink")
	var muted := Tokens.color(mode, &"text_muted")
	var shadow := Tokens.color(mode, &"pixel_shadow")
	var normal := make_panel(mode, Tokens.TIER_M, normal_surface, true)
	var hover := make_panel(
		mode, Tokens.TIER_M, &"accent_cta_coral" if cta else &"accent_soft", true
	)
	var pressed := make_panel(mode, Tokens.TIER_M, &"accent_primary")
	var disabled := make_panel(mode, Tokens.TIER_M, &"well_surface")
	var focused := PixelStyle.make_style(
		Tokens.TIER_M,
		Tokens.color(mode, normal_surface),
		Tokens.color(mode, &"accent_primary"),
		shadow,
		false,
		Global.pixel_ui_unit
	)
	for key in BUTTON_STYLES:
		match key:
			&"normal":
				button.add_theme_stylebox_override(key, normal)
			&"hover":
				button.add_theme_stylebox_override(key, hover)
			&"pressed":
				button.add_theme_stylebox_override(key, pressed)
			&"disabled":
				button.add_theme_stylebox_override(key, disabled)
			&"focus":
				button.add_theme_stylebox_override(key, focused)
	for key in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		button.add_theme_color_override(key, color)
	button.add_theme_color_override(&"font_disabled_color", muted)
	# Q icons are colored PNGs, not monochrome SVG masks. Keep their actual pixels.
	for key in [
		&"icon_normal_color",
		&"icon_hover_color",
		&"icon_pressed_color",
		&"icon_disabled_color",
		&"icon_focus_color"
	]:
		button.add_theme_color_override(key, Color.WHITE)
	button.remove_theme_color_override(&"icon_disabled_color")
	button.add_theme_color_override(&"icon_disabled_color", Color(1.0, 1.0, 1.0, 0.5))


static func clear_button(button: Button) -> void:
	if not is_instance_valid(button):
		return
	for key in BUTTON_STYLES:
		button.remove_theme_stylebox_override(key)
	for key in BUTTON_COLORS:
		button.remove_theme_color_override(key)
