class_name PhospriteStage4Chrome
extends RefCounted

## Stage 4 skin for existing Palette, UI1/UI4 and Timeline controls.
## All overrides are opt-in and reversible; no gesture or data model changes.
const Tokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")
const PixelStyle := preload("res://src/UI/DesignSystem/PhospritePixelStyle.gd")
const Stage2 := preload("res://src/UI/DesignSystem/PhospriteStage2Chrome.gd")

const STYLE_KEYS := [&"normal", &"hover", &"pressed", &"disabled", &"focus"]
const COLOR_KEYS := [
	&"font_color",
	&"font_hover_color",
	&"font_pressed_color",
	&"font_disabled_color",
	&"font_focus_color",
]
const ICON_COLOR_KEYS := [
	&"icon_normal_color",
	&"icon_hover_color",
	&"icon_pressed_color",
	&"icon_disabled_color",
	&"icon_focus_color",
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
	var unit := clampi(Global.pixel_ui_unit, 1, 3)
	var cache_key := "%s/%d/%s" % [mode, unit, state]
	if _styles.has(cache_key):
		return _styles[cache_key] as StyleBoxTexture
	var surface := &"panel_surface"
	var border := Tokens.color(mode, &"outline_ink")
	var with_shadow := state in [&"normal", &"hover", &"guide"]
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
	var is_pressed := state in [&"pressed", &"selected"]
	var style := PixelStyle.make_style(
		Tokens.TIER_M,
		Tokens.color(mode, surface),
		border,
		Tokens.color(mode, &"pixel_shadow"),
		with_shadow,
		unit,
		is_pressed
	)
	# Compact positive margins (total 8px at unit=2): never negative, so Godot
	# never treats content_margin_right/bottom as unset (-1 sentinel).
	var pad := 2.0
	var s := float(PixelStyle.SHADOW_OFFSET * unit)
	if with_shadow and not is_pressed:
		style.content_margin_left = pad
		style.content_margin_top = pad
		style.content_margin_right = pad + s
		style.content_margin_bottom = pad + s
	elif is_pressed:
		style.content_margin_left = pad + s
		style.content_margin_top = pad + s
		style.content_margin_right = pad
		style.content_margin_bottom = pad
	else:
		var half := floorf(s * 0.5)
		style.content_margin_left = pad + half
		style.content_margin_top = pad + half
		style.content_margin_right = pad + half
		style.content_margin_bottom = pad + half
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
			"styles": {},
			"colors": {},
			"filter": button.texture_filter,
			"flat": button.flat,
		}
		for key in STYLE_KEYS:
			if button.has_theme_stylebox_override(key):
				original.styles[key] = button.get_theme_stylebox(key)
		for key in COLOR_KEYS + ICON_COLOR_KEYS:
			if button.has_theme_color_override(key):
				original.colors[key] = button.get_theme_color(key)
		button.set_meta(ORIGINAL_BUTTON_META, original)
	if button.flat:
		button.flat = false
	if button.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for key in STYLE_KEYS:
		var target := button_style(mode, &"guide" if guide and key == &"normal" else key)
		if not button.has_theme_stylebox_override(key) or button.get_theme_stylebox(key) != target:
			button.add_theme_stylebox_override(key, target)
	var foreground := Tokens.color(mode, &"text_primary")
	var muted := Tokens.color(mode, &"text_muted")
	for key in COLOR_KEYS:
		var target_c := (
			muted
			if key == &"font_disabled_color"
			else (Color.WHITE if key == &"font_pressed_color" else foreground)
		)
		if not button.has_theme_color_override(key) or button.get_theme_color(key) != target_c:
			button.add_theme_color_override(key, target_c)


static func set_q_icon_colors(button: Button, enabled: bool) -> void:
	if not is_instance_valid(button):
		return
	if enabled:
		for key in [
			&"icon_normal_color",
			&"icon_hover_color",
			&"icon_pressed_color",
			&"icon_focus_color",
		]:
			if (
				not button.has_theme_color_override(key)
				or button.get_theme_color(key) != Color.WHITE
			):
				button.add_theme_color_override(key, Color.WHITE)
		var dis := Color(1.0, 1.0, 1.0, 0.45)
		if (
			not button.has_theme_color_override(&"icon_disabled_color")
			or (button.get_theme_color(&"icon_disabled_color") != dis)
		):
			button.add_theme_color_override(&"icon_disabled_color", dis)
	else:
		for key in ICON_COLOR_KEYS:
			button.remove_theme_color_override(key)


static func restore_button(button: Button) -> void:
	if not is_instance_valid(button) or not button.has_meta(ORIGINAL_BUTTON_META):
		return
	var original: Dictionary = button.get_meta(ORIGINAL_BUTTON_META)
	for key in STYLE_KEYS:
		if original.styles.has(key):
			button.add_theme_stylebox_override(key, original.styles[key])
		else:
			button.remove_theme_stylebox_override(key)
	for key in COLOR_KEYS + ICON_COLOR_KEYS:
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
		(
			panel
			. set_meta(
				key,
				{
					"had": panel.has_theme_stylebox_override(&"panel"),
					"style": panel.get_theme_stylebox(&"panel"),
				}
			)
		)
	var style := Stage2.make_shell(mode, tier, &"panel_surface")
	if (
		not panel.has_theme_stylebox_override(&"panel")
		or panel.get_theme_stylebox(&"panel") != style
	):
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
