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
static var _topbar_cache: Dictionary = {}
static var _pill_cache: Dictionary = {}
static var _floppy_cache: Dictionary = {}


static func active_mode() -> StringName:
	if Global.theme_preset_index == Themes.CUSTOM_THEME_INDEX:
		return Tokens.LEGACY
	return Tokens.detect_mode(Global.theme_base_color, Global.theme_accent_color)


## Chunkier pixel outline unit for unmistakable Neo-Y2K pixel art feel (3px when default unit=2).
static func chunky_unit() -> int:
	return PixelStyle.BAR_U


static func make_panel(
	mode: StringName,
	tier: StringName,
	surface: StringName,
	with_shadow := false,
	border_token: StringName = &"outline_ink",
	shadow_token: StringName = &"pixel_shadow"
) -> StyleBoxTexture:
	if mode == Tokens.LEGACY:
		return null
	var unit := clampi(Global.pixel_ui_unit, 1, 3)
	var key := (
		"%s|%s|%s|%d|%s|%s|%d"
		% [mode, tier, surface, int(with_shadow), border_token, shadow_token, unit]
	)
	if _panel_cache.has(key):
		return _panel_cache[key] as StyleBoxTexture
	var border_color := (
		Color.TRANSPARENT if border_token == &"" else Tokens.color(mode, border_token)
	)
	var shadow_color := (
		Color.TRANSPARENT if shadow_token == &"" else Tokens.color(mode, shadow_token)
	)
	var style := PixelStyle.make_style(
		tier, Tokens.color(mode, surface), border_color, shadow_color, with_shadow, unit
	)
	if style != null:
		_panel_cache[key] = style
	return style


## Gallery panels already have child MarginContainers and card content insets.
static func make_shell(
	mode: StringName,
	tier: StringName,
	surface: StringName,
	with_shadow := false,
	border_token: StringName = &"outline_ink",
	shadow_token: StringName = &"pixel_shadow"
) -> StyleBoxTexture:
	if mode == Tokens.LEGACY:
		return null
	var unit := clampi(Global.pixel_ui_unit, 1, 3)
	var key := (
		"%s|%s|%s|%d|%s|%s|%d"
		% [mode, tier, surface, int(with_shadow), border_token, shadow_token, unit]
	)
	if _shell_cache.has(key):
		return _shell_cache[key] as StyleBoxTexture
	var border_color := (
		Color.TRANSPARENT if border_token == &"" else Tokens.color(mode, border_token)
	)
	var shadow_color := (
		Color.TRANSPARENT if shadow_token == &"" else Tokens.color(mode, shadow_token)
	)
	var style := PixelStyle.make_style(
		tier, Tokens.color(mode, surface), border_color, shadow_color, with_shadow, unit
	)
	if style != null:
		style.content_margin_left = 0.0
		style.content_margin_top = 0.0
		style.content_margin_right = 0.0
		style.content_margin_bottom = 0.0
		_shell_cache[key] = style
	return style


## Full-width 3D beveled dreamy top bar with specular rim, shade lip, and border.
static func make_topbar_style(mode: StringName) -> StyleBoxFlat:
	if mode == Tokens.LEGACY:
		return null
	var key := "clean_topbar|%s" % mode
	if _topbar_cache.has(key):
		return _topbar_cache[key] as StyleBoxFlat
	var style := PixelStyle.make_dock_bar_style(
		Tokens.color(mode, &"topbar_surface"), Tokens.color(mode, &"topbar_shade"), 2
	)
	_topbar_cache[key] = style
	return style


## Recessed pixel pill embedded into the topbar (for selection count status badge).
static func make_recessed_topbar_pill(
	mode: StringName, pad_x := 12.0, pad_y := 6.0
) -> StyleBoxTexture:
	if mode == Tokens.LEGACY:
		return null
	var key := "clean_topbar_pill|%s|%.1f|%.1f" % [mode, pad_x, pad_y]
	if _pill_cache.has(key):
		return _pill_cache[key] as StyleBoxTexture
	var style := PixelStyle.make_flat_pill(
		Tokens.TIER_S, Tokens.color(mode, &"topbar_pill_surface"), 2, pad_x, pad_y
	)
	if style != null:
		_pill_cache[key] = style
	return style


## Cached 3D Embossed & Recessed 3.5-inch Floppy Disk card components.
static func make_floppy_shell(mode: StringName, selected: bool) -> StyleBoxTexture:
	if mode == Tokens.LEGACY:
		return null
	var stroke := PixelStyle.FLOPPY_U
	var key := "shell3d|%s|%d|%d" % [mode, int(selected), stroke]
	if _floppy_cache.has(key):
		return _floppy_cache[key] as StyleBoxTexture
	var bg := Tokens.color(mode, &"floppy_shell_selected" if selected else &"floppy_shell")
	var hi := Tokens.color(
		mode, &"floppy_shell_selected_light" if selected else &"floppy_shell_light"
	)
	var sh := Tokens.color(
		mode, &"floppy_shell_selected_shade" if selected else &"floppy_shell_shade"
	)
	var ink := Tokens.color(mode, &"floppy_ink")
	var shadow := Tokens.color(mode, &"floppy_shadow_selected" if selected else &"floppy_shadow")
	var style := PixelStyle.make_floppy_shell_style(
		bg, hi, sh, ink, shadow, stroke, PixelStyle.FLOPPY_SHADOW
	)
	if style != null:
		_floppy_cache[key] = style
	return style


static func make_floppy_shutter(mode: StringName, selected: bool) -> StyleBoxTexture:
	if mode == Tokens.LEGACY:
		return null
	var stroke := PixelStyle.FLOPPY_U
	var key := "shutter3d|%s|%d|%d" % [mode, int(selected), stroke]
	if _floppy_cache.has(key):
		return _floppy_cache[key] as StyleBoxTexture
	var bg := Tokens.color(mode, &"floppy_shutter_selected" if selected else &"floppy_shutter")
	var hi := Tokens.color(
		mode, &"floppy_shutter_selected_light" if selected else &"floppy_shutter_light"
	)
	var sh := Tokens.color(
		mode, &"floppy_shutter_selected_shade" if selected else &"floppy_shutter_shade"
	)
	var ink := Tokens.color(mode, &"floppy_ink")
	var cast := Tokens.color(
		mode, &"floppy_shell_selected_shade" if selected else &"floppy_shell_shade"
	)
	var style := PixelStyle.make_shutter_style(bg, hi, sh, ink, cast, stroke)
	if style != null:
		_floppy_cache[key] = style
	return style


static func make_floppy_sticker(mode: StringName, selected: bool) -> StyleBoxTexture:
	if mode == Tokens.LEGACY:
		return null
	var stroke := PixelStyle.FLOPPY_U
	var key := "sticker3d|%s|%d|%d" % [mode, int(selected), stroke]
	if _floppy_cache.has(key):
		return _floppy_cache[key] as StyleBoxTexture
	var bg := Tokens.color(mode, &"floppy_label")
	var in_sh := Tokens.color(mode, &"floppy_label_inner_shadow")
	var in_hi := Tokens.color(mode, &"floppy_label_inner_light")
	var stripe := Tokens.color(
		mode, &"floppy_label_stripe_selected" if selected else &"floppy_label_stripe"
	)
	var stripe_hi := Tokens.color(
		mode, &"floppy_label_stripe_selected_light" if selected else &"floppy_label_stripe_light"
	)
	var stripe_sh := Tokens.color(
		mode, &"floppy_label_stripe_selected_shade" if selected else &"floppy_label_stripe_shade"
	)
	var ink := Tokens.color(mode, &"floppy_ink")
	var style := PixelStyle.make_sticker_style(
		bg, in_sh, in_hi, stripe, stripe_hi, stripe_sh, ink, stroke
	)
	if style != null:
		_floppy_cache[key] = style
	return style


static func make_floppy_slot(mode: StringName) -> StyleBoxTexture:
	if mode == Tokens.LEGACY:
		return null
	var key := "slot3d|%s" % mode
	if _floppy_cache.has(key):
		return _floppy_cache[key] as StyleBoxTexture
	var style := PixelStyle.make_recessed_well_style(
		Tokens.color(mode, &"floppy_shutter_slot"),
		Tokens.color(mode, &"floppy_shutter_slot_shadow"),
		Tokens.color(mode, &"floppy_shutter_slot_light"),
		Tokens.color(mode, &"floppy_ink"),
		PixelStyle.BAR_U,
		0.0,
		0.0
	)
	if style != null:
		_floppy_cache[key] = style
	return style


static func make_checkbox_badge(mode: StringName, selected: bool) -> StyleBoxTexture:
	if mode == Tokens.LEGACY:
		return null
	var key := "chk3d|%s|%d" % [mode, int(selected)]
	if _floppy_cache.has(key):
		return _floppy_cache[key] as StyleBoxTexture
	var style: StyleBoxTexture
	if selected:
		# Embossed glowing sky-blue cap
		var bg := Tokens.color(mode, &"accent_primary")
		style = PixelStyle.make_beveled_button_style(
			bg,
			bg.lightened(0.35),
			bg.darkened(0.28),
			Tokens.color(mode, &"floppy_ink"),
			Color.TRANSPARENT,
			false,
			PixelStyle.BAR_U,
			false,
			false,
			0.0,
			0.0
		)
	else:
		# Recessed empty checkbox well
		style = PixelStyle.make_recessed_well_style(
			Tokens.color(mode, &"floppy_label"),
			Tokens.color(mode, &"floppy_label_inner_shadow"),
			Tokens.color(mode, &"floppy_label_inner_light"),
			Tokens.color(mode, &"checkbox_border"),
			PixelStyle.BAR_U,
			0.0,
			0.0
		)
	if style != null:
		_floppy_cache[key] = style
	return style


static func _make_clean_btn_box(
	bg: Color, lip_color: Color, pad_x: float, pad_y: float, lip_px := 3, pressed := false
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.anti_aliasing = false
	if lip_px > 0 and not pressed:
		# Single clean bottom 3D depth layer (one-layer tactile button)
		style.border_width_bottom = lip_px
		style.border_color = lip_color
		style.content_margin_left = pad_x
		style.content_margin_right = pad_x
		style.content_margin_top = pad_y
		style.content_margin_bottom = pad_y + float(lip_px)
	else:
		# Pressed / active latched state: lip flattened, subtle top inset border
		style.border_width_top = 2 if pressed else 0
		style.border_color = lip_color
		style.content_margin_left = pad_x
		style.content_margin_right = pad_x
		style.content_margin_top = pad_y + (2.0 if pressed else 0.0)
		style.content_margin_bottom = pad_y
	return style


static func _button_styles(mode: StringName, variant: StringName, on_topbar := false) -> Dictionary:
	var unit := clampi(Global.pixel_ui_unit, 1, 3)
	var key := "btn_clean|%s|%d|%s|%d" % [mode, unit, variant, int(on_topbar)]
	if _button_cache.has(key):
		return _button_cache[key] as Dictionary
	var pad_x := 14.0
	var pad_y := 6.0

	var normal_bg := (
		Color("#F7F6FF")
		if (on_topbar and mode == Tokens.SUNNY)
		else Tokens.color(mode, &"topbar_btn_surface" if on_topbar else &"panel_surface")
	)
	var hover_bg := (
		Color("#FFFFFF")
		if (on_topbar and mode == Tokens.SUNNY)
		else Tokens.color(mode, &"topbar_btn_hover" if on_topbar else &"accent_soft")
	)
	var pressed_bg := Tokens.color(mode, &"accent_primary")
	var disabled_bg := Tokens.color(mode, &"topbar_pill_surface" if on_topbar else &"well_surface")
	var border := (
		Tokens.color(mode, &"topbar_btn_border")
		if on_topbar
		else Tokens.color(mode, &"outline_ink")
	)

	match variant:
		&"cta":
			normal_bg = Tokens.color(mode, &"accent_cta_coral")
			hover_bg = Tokens.color(mode, &"accent_cta_coral_hover")
			pressed_bg = Tokens.color(mode, &"accent_cta_coral").darkened(0.1)
			border = Color.TRANSPARENT
		&"active":
			normal_bg = Tokens.color(mode, &"accent_primary")
			hover_bg = Tokens.color(mode, &"accent_primary").lightened(0.08)
			pressed_bg = Tokens.color(mode, &"accent_primary").darkened(0.1)
			border = Color.TRANSPARENT
		&"danger":
			normal_bg = Tokens.color(mode, &"danger_primary")
			hover_bg = Tokens.color(mode, &"danger_primary").lightened(0.08)
			pressed_bg = Tokens.color(mode, &"danger_primary").darkened(0.12)
			border = Color.TRANSPARENT
		&"subtle":
			normal_bg = (
				Color("#F7F6FF")
				if (on_topbar and mode == Tokens.SUNNY)
				else Tokens.color(mode, &"topbar_btn_surface" if on_topbar else &"panel_surface")
			)
			hover_bg = (
				Color("#FFFFFF")
				if (on_topbar and mode == Tokens.SUNNY)
				else Tokens.color(mode, &"topbar_btn_hover" if on_topbar else &"accent_soft")
			)
			pressed_bg = Tokens.color(mode, &"accent_primary")

	var is_latched := variant == &"active"
	var lip_normal := normal_bg.darkened(0.28)
	var lip_hover := hover_bg.darkened(0.28)
	var lip_pressed := pressed_bg.darkened(0.32)
	var styles := {
		&"normal":
		_make_clean_btn_box(
			normal_bg, lip_normal, pad_x, pad_y, 0 if is_latched else 3, is_latched
		),
		&"hover":
		_make_clean_btn_box(hover_bg, lip_hover, pad_x, pad_y, 0 if is_latched else 3, is_latched),
		&"pressed": _make_clean_btn_box(pressed_bg, lip_pressed, pad_x, pad_y, 0, true),
		&"disabled": _make_clean_btn_box(disabled_bg, disabled_bg, pad_x, pad_y, 0, false),
		&"focus":
		_make_clean_btn_box(
			normal_bg, lip_normal, pad_x, pad_y, 0 if is_latched else 3, is_latched
		),
	}
	_button_cache[key] = styles
	return styles


static func style_button(button: Button, mode: StringName, cta := false) -> void:
	style_button_variant(button, mode, &"cta" if cta else &"secondary", false)


static func style_button_variant(
	button: Button, mode: StringName, variant: StringName = &"secondary", on_topbar := false
) -> void:
	if not is_instance_valid(button):
		return
	if mode == Tokens.LEGACY:
		clear_button(button)
		return
	if not button.has_meta(&"stage2_legacy_texture_filter"):
		button.set_meta(&"stage2_legacy_texture_filter", button.texture_filter)
	if button.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var styles := _button_styles(mode, variant, on_topbar)
	for key in BUTTON_STYLES:
		var target := styles[key] as StyleBox
		if not button.has_theme_stylebox_override(key) or button.get_theme_stylebox(key) != target:
			button.add_theme_stylebox_override(key, target)

	var primary_text := Tokens.color(mode, &"text_primary")
	var on_accent := Tokens.color(mode, &"text_on_accent")
	var muted := Tokens.color(mode, &"text_muted")
	var danger := Tokens.color(mode, &"danger_primary")

	var normal_font := (
		primary_text if (mode == Tokens.SUNNY) else Tokens.color(mode, &"topbar_btn_text")
	)
	var hover_font := normal_font
	var pressed_font := on_accent
	match variant:
		&"cta", &"active", &"danger":
			normal_font = on_accent
			hover_font = on_accent
			pressed_font = on_accent

	var color_map := {
		&"font_color": normal_font,
		&"font_hover_color": hover_font,
		&"font_pressed_color": pressed_font,
		&"font_focus_color": normal_font,
		&"font_disabled_color": muted,
	}
	for key in color_map:
		var target_c: Color = color_map[key]
		if not button.has_theme_color_override(key) or button.get_theme_color(key) != target_c:
			button.add_theme_color_override(key, target_c)

	# Q icons are colored PNGs, not monochrome SVG masks. Keep their actual pixels.
	for key in [
		&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_focus_color"
	]:
		if not button.has_theme_color_override(key) or button.get_theme_color(key) != Color.WHITE:
			button.add_theme_color_override(key, Color.WHITE)
	var disabled_icon := Color(1.0, 1.0, 1.0, 0.45)
	if (
		not button.has_theme_color_override(&"icon_disabled_color")
		or (button.get_theme_color(&"icon_disabled_color") != disabled_icon)
	):
		button.add_theme_color_override(&"icon_disabled_color", disabled_icon)
	button.add_theme_constant_override(&"h_separation", 6)


static func clear_button(button: Button) -> void:
	if not is_instance_valid(button):
		return
	for key in BUTTON_STYLES:
		button.remove_theme_stylebox_override(key)
	for key in BUTTON_COLORS:
		button.remove_theme_color_override(key)
	button.remove_theme_constant_override(&"h_separation")
	if button.has_meta(&"stage2_legacy_texture_filter"):
		button.texture_filter = int(button.get_meta(&"stage2_legacy_texture_filter"))
		button.remove_meta(&"stage2_legacy_texture_filter")
