class_name PhospriteStage4Chrome
extends RefCounted

## Stage 4 skin for existing Palette, UI1/UI4 and Timeline controls.
## Uses clean, centered single-layer 3D tactile pixel buttons (symmetric margins,
## subtle 1px border + 2px bottom depth lip, flattened pressed/selected state)
## so icons stay dead-center inside compact 24-32px toolbar buttons.
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


static func button_style(mode: StringName, state: StringName) -> StyleBox:
	if mode == Tokens.LEGACY:
		return null
	var unit := clampi(Global.pixel_ui_unit, 1, 3)
	var cache_key := "s4_v2|%s/%d/%s" % [mode, unit, state]
	if _styles.has(cache_key):
		return _styles[cache_key] as StyleBox

	var is_light := mode == Tokens.SUNNY
	var bg := Tokens.color(mode, &"panel_surface")
	var border := Tokens.color(mode, &"border_subtle")
	var is_pressed := state in [&"pressed", &"selected"]
	var is_well := state == &"well"
	var has_lip := state in [&"normal", &"hover", &"guide"]

	match state:
		&"normal":
			bg = Tokens.color(mode, &"elevated_surface")
		&"hover", &"guide":
			bg = Tokens.color(mode, &"accent_soft")
			border = Tokens.color(mode, &"accent_primary").lerp(border, 0.5)
		&"pressed", &"selected":
			bg = Tokens.color(mode, &"accent_primary")
			border = bg.darkened(0.25)
		&"disabled":
			bg = Tokens.color(mode, &"well_surface")
			border = Color(border, 0.6)
		&"focus":
			bg = Tokens.color(mode, &"elevated_surface")
			border = Tokens.color(mode, &"accent_primary")
		&"well":
			bg = Tokens.color(mode, &"well_surface")

	var lip_col := Tokens.color(mode, &"outline_ink")
	if is_pressed or is_well:
		lip_col = bg.darkened(0.24 if is_light else 0.38)
	var style := PixelStyle.make_single_layer_button_style(
		bg, Tokens.color(mode, &"outline_ink"), lip_col, has_lip, is_pressed or is_well, 4.0, 3.0
	)

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
			else (
				Tokens.color(mode, &"text_on_accent")
				if key == &"font_pressed_color"
				else foreground
			)
		)
		if not button.has_theme_color_override(key) or button.get_theme_color(key) != target_c:
			button.add_theme_color_override(key, target_c)
	set_q_icon_colors(button, true)


static func icon_tint_for_button(mode: StringName, button: BaseButton) -> Color:
	if mode == Tokens.LEGACY:
		return Color.WHITE
	if is_instance_valid(button) and button.disabled:
		return Color(Tokens.color(mode, &"text_muted"), 0.45)
	if is_instance_valid(button) and button.button_pressed:
		return Tokens.color(mode, &"text_on_accent")
	return Tokens.color(mode, &"text_primary")


static func set_q_icon_colors(button: Button, enabled: bool) -> void:
	if not is_instance_valid(button):
		return
	if enabled:
		var mode := active_mode()
		var fg := Tokens.color(mode, &"text_primary") if mode != Tokens.LEGACY else Color.WHITE
		var on_acc := (
			Tokens.color(mode, &"text_on_accent") if mode != Tokens.LEGACY else Color.WHITE
		)
		var muted := (
			Tokens.color(mode, &"text_muted") if mode != Tokens.LEGACY else Color(1, 1, 1, 0.5)
		)
		var icon_map := {
			&"icon_normal_color": fg,
			&"icon_hover_color": fg,
			&"icon_pressed_color": on_acc,
			&"icon_focus_color": fg,
		}
		for key in icon_map:
			var target_ic: Color = icon_map[key]
			if not button.has_theme_color_override(key) or button.get_theme_color(key) != target_ic:
				button.add_theme_color_override(key, target_ic)
		var dis := Color(muted, 0.45)
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


static func style_panel(panel: Control, mode: StringName, _tier := Tokens.TIER_L) -> void:
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
	# Flat borderless inner panel so docked modules never show double nested borders
	var style := StyleBoxFlat.new()
	style.bg_color = Tokens.color(mode, &"panel_surface")
	style.anti_aliasing = false
	panel.add_theme_stylebox_override(&"panel", style)


static func style_option(option: OptionButton, mode: StringName) -> void:
	if not is_instance_valid(option):
		return
	if mode == Tokens.LEGACY:
		restore_button(option)
	else:
		style_button(option, mode)


static func draw_scrubby_pill(_item: CanvasItem, _bounds: Rect2, mode: StringName) -> void:
	if mode == Tokens.LEGACY:
		return
	# Ultra-clean borderless vertical numeric control (no clunky slab box around "1 px" / "100 %")
