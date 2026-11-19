class_name PhospriteStage4Chrome
extends RefCounted

## Stage 4 skin for existing Palette, UI1/UI4 and Timeline controls.
## All overrides are opt-in and reversible; no gesture or data model changes.
const Tokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")
const PixelStyle := preload("res://src/UI/DesignSystem/PhospritePixelStyle.gd")
const Stage2 := preload("res://src/UI/DesignSystem/PhospriteStage2Chrome.gd")

const STYLE_KEYS := [&"normal", &"hover", &"pressed", &"disabled", &"focus"]
const COLOR_KEYS := [
	&"font_color", &"font_hover_color", &"font_pressed_color",
	&"font_disabled_color", &"font_focus_color",
]
const ORIGINAL_BUTTON_META := &"phosprite_stage4_original_button"
const ORIGINAL_PANEL_META := &"phosprite_stage4_original_panel"
const ORIGINAL_OPTION_META := &"phosprite_stage4_original_option"
static var _styles: Dictionary = {}


static func active_mode() -> StringName:
	return Stage2.active_mode()


static func button_style(mode: StringName, state: StringName) -> StyleBoxTexture:
	if mode == Tokens.LEGACY:
		return null
	var cache_key := "%s/%d/%s" % [mode, Global.pixel_ui_unit, state]
	if _styles.has(cache_key):
		return _styles[cache_key] as StyleBoxTexture
	var surface := &"panel_surface"
	var border := Tokens.color(mode, &"outline_ink")
	var with_shadow := false
	match state:
		&"hover", &"guide":
			surface = &"accent_soft"
		&"pressed", &"selected":
			surface = &"accent_primary"
		&"disabled":
			surface = &"well_surface"
		&"focus":
			border = Tokens.color(mode, &"accent_primary")
		&"well":
			surface = &"well_surface"
	var style := PixelStyle.make_style(
		Tokens.TIER_M,
		Tokens.color(mode, surface),
		border,
		Tokens.color(mode, &"pixel_shadow"),
		with_shadow,
		Global.pixel_ui_unit
	)
	# Existing toolbar rows control their own padding and hit areas.
	for side in [&"left", &"right", &"top", &"bottom"]:
		style.set("content_margin_%s" % side, 0.0)
	_styles[cache_key] = style
	return style


static func style_button(button: Button, mode: StringName, guide := false) -> void:
	if not is_instance_valid(button):
		return
	if mode == Tokens.LEGACY:
		restore_button(button)
		return
	if not button.has_meta(ORIGINAL_BUTTON_META):
		var original := {
			"styles": {}, "colors": {},
			"filter": button.texture_filter, "flat": button.flat,
		}
		for key in STYLE_KEYS:
			if button.has_theme_stylebox_override(key):
				original.styles[key] = button.get_theme_stylebox(key)
		for key in COLOR_KEYS:
			if button.has_theme_color_override(key):
				original.colors[key] = button.get_theme_color(key)
		button.set_meta(ORIGINAL_BUTTON_META, original)
	button.flat = false
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for key in STYLE_KEYS:
		button.add_theme_stylebox_override(
			key, button_style(mode, &"guide" if guide and key == &"normal" else key)
		)
	var foreground := Tokens.color(mode, &"text_primary")
	for key in COLOR_KEYS:
		button.add_theme_color_override(
			key, Tokens.color(mode, &"text_muted") if key == &"font_disabled_color" else foreground
	)


static func restore_button(button: Button) -> void:
	if not is_instance_valid(button) or not button.has_meta(ORIGINAL_BUTTON_META):
		return
	var original: Dictionary = button.get_meta(ORIGINAL_BUTTON_META)
	for key in STYLE_KEYS:
		if original.styles.has(key):
			button.add_theme_stylebox_override(key, original.styles[key])
		else:
			button.remove_theme_stylebox_override(key)
	for key in COLOR_KEYS:
		if original.colors.has(key):
			button.add_theme_color_override(key, original.colors[key])
		else:
			button.remove_theme_color_override(key)
	button.texture_filter = int(original.filter)
	button.flat = bool(original.flat)
	button.remove_meta(ORIGINAL_BUTTON_META)


static func style_panel(panel: Control, mode: StringName, tier := Tokens.TIER_L) -> void:
	if not is_instance_valid(panel):
		return
	var key := ORIGINAL_PANEL_META
	if mode == Tokens.LEGACY:
		if panel.has_meta(key):
			var original: Dictionary = panel.get_meta(key)
			if bool(original.had):
				panel.add_theme_stylebox_override(&"panel", original.style)
			else:
				panel.remove_theme_stylebox_override(&"panel")
			panel.remove_meta(key)
		return
	if not panel.has_meta(key):
		panel.set_meta(
			key, {
				"had": panel.has_theme_stylebox_override(&"panel"),
				"style": panel.get_theme_stylebox(&"panel"),
			}
		)
	var style := Stage2.make_shell(mode, tier, &"panel_surface")
	panel.add_theme_stylebox_override(&"panel", style)


static func style_option(option: OptionButton, mode: StringName) -> void:
	if not is_instance_valid(option):
		return
	if mode == Tokens.LEGACY:
		restore_button(option)
	else:
		style_button(option, mode)


static func draw_scrubby_pill(item: CanvasItem, bounds: Rect2, mode: StringName) -> void:
	if mode == Tokens.LEGACY:
		return
	item.draw_style_box(button_style(mode, &"well"), bounds)
