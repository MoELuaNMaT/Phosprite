class_name PhospriteThemeBridge
extends RefCounted

## Global pixel-art Theme skinning for Sunny Cream & Twilight Berry.
## Replaces smooth vector StyleBoxFlat borders, checkboxes, sliders, popups,
## inputs, scrollbars and separators with integer-stepped pixel resources
## while keeping Godot's CJK font fallback cascade untouched.

const Tokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")
const PixelStyle := preload("res://src/UI/DesignSystem/PhospritePixelStyle.gd")
const QIcons := preload("res://src/UI/DesignSystem/PhospriteQIcons.gd")


static func apply_to_theme(theme: Theme, mode: StringName, pixel_unit := 2) -> void:
	if theme == null or mode == Tokens.LEGACY:
		return
	var u := clampi(pixel_unit, 1, 3)
	var ink := Tokens.color(mode, &"outline_ink")
	var shadow := Tokens.color(mode, &"pixel_shadow")
	var surface := Tokens.color(mode, &"panel_surface")
	var well := Tokens.color(mode, &"well_surface")
	var soft := Tokens.color(mode, &"accent_soft")
	var accent := Tokens.color(mode, &"accent_primary")
	var text := Tokens.color(mode, &"text_primary")
	var muted := Tokens.color(mode, &"text_muted")

	var panel_l := PixelStyle.make_style(Tokens.TIER_L, surface, ink, shadow, true, u)
	var panel_m := PixelStyle.make_style(Tokens.TIER_M, surface, ink, shadow, false, u)
	var well_m := PixelStyle.make_style(Tokens.TIER_M, well, ink, shadow, false, u)
	var focus_m := PixelStyle.make_style(Tokens.TIER_M, well, accent, shadow, false, u)
	var hover_s := PixelStyle.make_style(Tokens.TIER_S, soft, ink, shadow, false, u)
	var btn_normal := PixelStyle.make_style(Tokens.TIER_M, surface, ink, shadow, true, u)
	var btn_hover := PixelStyle.make_style(Tokens.TIER_M, soft, ink, shadow, true, u)
	var btn_pressed := PixelStyle.make_style(Tokens.TIER_M, accent, ink, shadow, false, u, true)
	var btn_disabled := PixelStyle.make_style(Tokens.TIER_M, well, ink, shadow, false, u)
	var btn_focus := PixelStyle.make_style(Tokens.TIER_M, soft, accent, shadow, false, u)

	# Keep unreplaced monochrome SVG/PNG icons crisp against Sunny Cream & Twilight Berry.
	theme.set_color(&"modulate_color", &"Icons", text)
	theme.set_color(&"font_color", &"Label", text)

	# 1. Buttons, MenuButtons, OptionButtons, CheckBoxes, CheckButtons
	for btype in [&"Button", &"MenuButton", &"OptionButton", &"CheckBox", &"CheckButton"]:
		theme.set_stylebox(&"normal", btype, btn_normal)
		theme.set_stylebox(&"hover", btype, btn_hover)
		theme.set_stylebox(&"pressed", btype, btn_pressed)
		theme.set_stylebox(&"hover_pressed", btype, btn_pressed)
		theme.set_stylebox(&"disabled", btype, btn_disabled)
		theme.set_stylebox(&"focus", btype, btn_focus)
		theme.set_color(&"font_color", btype, text)
		theme.set_color(&"font_hover_color", btype, text)
		theme.set_color(&"font_pressed_color", btype, Color.WHITE)
		theme.set_color(&"font_hover_pressed_color", btype, Color.WHITE)
		theme.set_color(&"font_disabled_color", btype, muted)
		theme.set_color(&"icon_normal_color", btype, text)
		theme.set_color(&"icon_hover_color", btype, text)
		theme.set_color(&"icon_focus_color", btype, text)
		theme.set_color(&"icon_pressed_color", btype, Color.WHITE)
		theme.set_color(&"icon_hover_pressed_color", btype, Color.WHITE)
		theme.set_color(&"icon_disabled_color", btype, Color(muted, 0.55))

	var chevron := QIcons.compact_icon_1x(&"chevron_down")
	if chevron != null:
		theme.set_icon(&"arrow", &"OptionButton", chevron)
		# Keep colored pixel chevron un-tinted by monochrome icon modulation.
		theme.set_color(&"icon_normal_color", &"OptionButton", Color.WHITE)
		theme.set_color(&"icon_hover_color", &"OptionButton", Color.WHITE)
		theme.set_color(&"icon_focus_color", &"OptionButton", Color.WHITE)

	# Pixel CheckBox & Radio icons (crisp integer squares, zero vector curves)
	var chk_off := _make_pixel_checkbox(false, false, surface, accent, ink)
	var chk_on := _make_pixel_checkbox(true, false, surface, accent, ink)
	var rad_off := _make_pixel_checkbox(false, true, surface, accent, ink)
	var rad_on := _make_pixel_checkbox(true, true, surface, accent, ink)
	for ctype in [&"CheckBox", &"PopupMenu"]:
		theme.set_icon(&"unchecked", ctype, chk_off)
		theme.set_icon(&"checked", ctype, chk_on)
		theme.set_icon(&"radio_unchecked", ctype, rad_off)
		theme.set_icon(&"radio_checked", ctype, rad_on)
	for ctype in [&"CheckBox", &"CheckButton"]:
		theme.set_color(&"icon_normal_color", ctype, Color.WHITE)
		theme.set_color(&"icon_hover_color", ctype, Color.WHITE)
		theme.set_color(&"icon_focus_color", ctype, Color.WHITE)

	# 2. Popups, Dialogs, Panels, Tooltips, Tabs
	for ptype in [&"PopupMenu", &"PopupPanel", &"AcceptDialog", &"TooltipPanel"]:
		theme.set_stylebox(&"panel", ptype, panel_l)
	theme.set_stylebox(&"hover", &"PopupMenu", hover_s)
	theme.set_color(&"font_color", &"PopupMenu", text)
	theme.set_color(&"font_hover_color", &"PopupMenu", text)
	theme.set_color(&"font_color", &"TooltipLabel", text)

	# Inner layout containers (Panel / PanelContainer) must remain flat and borderless
	# so WorkspaceModule windows do not render nested double/triple black frames
	# and CanvasVisualPolicy / Themes can read surface bg_color cleanly.
	var flat_panel := StyleBoxFlat.new()
	flat_panel.bg_color = surface
	flat_panel.anti_aliasing = false
	flat_panel.content_margin_left = 2.0
	flat_panel.content_margin_top = 2.0
	flat_panel.content_margin_right = 2.0
	flat_panel.content_margin_bottom = 2.0
	for flat_type in [&"Panel", &"PanelContainer"]:
		theme.set_stylebox(&"panel", flat_type, flat_panel)

	for cpanel in [&"TabContainer", &"FoldableContainer"]:
		theme.set_stylebox(&"panel", cpanel, panel_m)

	for ttype in [&"TabBar", &"TabContainer"]:
		theme.set_stylebox(&"tab_selected", ttype, btn_pressed)
		theme.set_stylebox(&"tab_hovered", ttype, btn_hover)
		theme.set_stylebox(&"tab_unselected", ttype, well_m)
		theme.set_color(&"font_selected_color", ttype, Color.WHITE)
		theme.set_color(&"font_unselected_color", ttype, muted)

	# 3. LineEdit & TextEdit
	for itype in [&"LineEdit", &"TextEdit"]:
		theme.set_stylebox(&"normal", itype, well_m)
		theme.set_stylebox(&"focus", itype, focus_m)
		theme.set_stylebox(&"read_only", itype, btn_disabled)
		theme.set_color(&"font_color", itype, text)

	# 4. Pixel Sliders & ScrollBars & Separators
	var track_s := PixelStyle.make_style(Tokens.TIER_S, well, ink, shadow, false, 1)
	var fill_s := PixelStyle.make_style(Tokens.TIER_S, accent, ink, shadow, false, 1)
	var grab_tex := _make_pixel_grabber(surface, ink)
	var grab_hi := _make_pixel_grabber(soft, ink)
	for stype in [&"HSlider", &"VSlider"]:
		theme.set_stylebox(&"slider", stype, track_s)
		theme.set_stylebox(&"grabber_area", stype, fill_s)
		theme.set_stylebox(&"grabber_area_highlight", stype, fill_s)
		theme.set_icon(&"grabber", stype, grab_tex)
		theme.set_icon(&"grabber_highlight", stype, grab_hi)

	for sbtype in [&"HScrollBar", &"VScrollBar"]:
		theme.set_stylebox(&"scroll", sbtype, track_s)
		theme.set_stylebox(&"grabber", sbtype, hover_s)
		theme.set_stylebox(&"grabber_highlight", sbtype, fill_s)
		theme.set_stylebox(&"grabber_pressed", sbtype, fill_s)

	var h_sep := StyleBoxFlat.new()
	h_sep.bg_color = Color(ink, 0.25)
	h_sep.content_margin_top = float(u)
	h_sep.anti_aliasing = false
	theme.set_stylebox(&"separator", &"HSeparator", h_sep)
	theme.set_stylebox(&"separator", &"PopupMenu", h_sep)

	var v_sep := StyleBoxFlat.new()
	v_sep.bg_color = Color(ink, 0.25)
	v_sep.content_margin_left = float(u)
	v_sep.anti_aliasing = false
	theme.set_stylebox(&"separator", &"VSeparator", v_sep)


static func _make_pixel_checkbox(
	checked: bool, radio: bool, surface: Color, accent: Color, ink: Color
) -> ImageTexture:
	var img := Image.create_empty(18, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var fill := accent if checked else surface
	for y in range(2, 16):
		for x in range(2, 16):
			var corner_dist := mini(x - 2, 15 - x) + mini(y - 2, 15 - y)
			if corner_dist < (3 if radio else 1):
				continue
			var is_border := x <= 3 or x >= 14 or y <= 3 or y >= 14 or (radio and corner_dist == 3)
			img.set_pixel(x, y, ink if is_border else fill)
	if checked:
		if radio:
			for y in range(7, 11):
				for x in range(7, 11):
					img.set_pixel(x, y, Color.WHITE)
		else:
			for pt in [
				Vector2i(5, 9),
				Vector2i(6, 10),
				Vector2i(7, 11),
				Vector2i(8, 10),
				Vector2i(9, 9),
				Vector2i(10, 8),
				Vector2i(11, 7),
				Vector2i(12, 6),
			]:
				img.set_pixel(pt.x, pt.y, Color.WHITE)
				img.set_pixel(pt.x, pt.y + 1, Color.WHITE)
	return ImageTexture.create_from_image(img)


static func _make_pixel_grabber(surface: Color, ink: Color) -> ImageTexture:
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for y in range(1, 15):
		for x in range(1, 15):
			if (x == 1 or x == 14) and (y == 1 or y == 14):
				continue
			var edge := x <= 2 or x >= 13 or y <= 2 or y >= 13
			img.set_pixel(x, y, ink if edge else surface)
	img.set_pixel(4, 4, Color.WHITE)
	img.set_pixel(5, 4, Color.WHITE)
	return ImageTexture.create_from_image(img)
