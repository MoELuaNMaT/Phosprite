class_name PhospritePixelStyle
extends RefCounted

## Deterministic, nearest-neighbor-friendly nine-slice resources.
## Do not make the user canvas a child of a dedicated filtering control just
## to style its window: the workspace renders these as isolated chrome.
##
## Textures are cached by visual key so repeated style lookups never re-upload
## GPU textures or trigger redundant theme invalidations.
## The hard shadow follows the selected 1/2/3px unit (2/4/6px offset).
## The window size and nine-slice geometry stay constant. This avoids
## StyleBoxFlat.shadow_size, which applies an unwanted soft shadow.

const Tokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")
const SHADOW_OFFSET := 2

static var _texture_cache: Dictionary = {}


static func make_style(
	tier: StringName,
	background: Color,
	outline: Color,
	shadow: Color,
	with_shadow := false,
	pixel_unit := 1,
	pressed_shift := false
) -> StyleBoxTexture:
	var unit := clampi(pixel_unit, 1, 3)
	var side := Tokens.tier_size(tier, unit)
	var slice_margin := Tokens.tier_texture_margin(tier, unit)
	if side <= 0 or slice_margin <= 0:
		push_error("Invalid Phosprite pixel tier: %s" % tier)
		return null
	var shadow_offset := SHADOW_OFFSET * unit
	var tex_key := (
		"%s|%s|%s|%s|%d|%d|%d"
		% [
			tier,
			background.to_html(),
			outline.to_html(),
			shadow.to_html(),
			int(with_shadow),
			unit,
			int(pressed_shift),
		]
	)
	var texture := _texture_cache.get(tex_key) as ImageTexture
	if texture == null:
		var image := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		var use_inset := with_shadow or pressed_shift
		var body_side := side - (shadow_offset if use_inset else 0)
		var body_offset := shadow_offset if pressed_shift else 0
		var corner_steps := Tokens.corner_cutoffs(tier, unit)

		if with_shadow and not pressed_shift:
			for y in range(side):
				for x in range(side):
					if _inside(x - shadow_offset, y - shadow_offset, body_side, corner_steps):
						image.set_pixel(x, y, shadow)

		for y in range(body_side):
			for x in range(body_side):
				if not _inside(x, y, body_side, corner_steps):
					continue
				# Erode the silhouette inward by an integer number of pixels.
				# A wider stroke must not enlarge the nine-slice or touch target.
				var edge := false
				for distance in range(1, unit + 1):
					if (
						not _inside(x - distance, y, body_side, corner_steps)
						or not _inside(x + distance, y, body_side, corner_steps)
						or not _inside(x, y - distance, body_side, corner_steps)
						or not _inside(x, y + distance, body_side, corner_steps)
					):
						edge = true
						break
				image.set_pixel(x + body_offset, y + body_offset, outline if edge else background)
		texture = ImageTexture.create_from_image(image)
		_texture_cache[tex_key] = texture

	var style := StyleBoxTexture.new()
	style.texture = texture
	style.region_rect = Rect2(Vector2.ZERO, Vector2(side, side))
	style.texture_margin_left = slice_margin
	style.texture_margin_right = slice_margin
	style.texture_margin_top = slice_margin
	style.texture_margin_bottom = slice_margin
	var pad := float(Tokens.tier_content_margin(tier))
	var s := float(shadow_offset)
	# Keep all content margins strictly non-negative: Godot treats < 0 as unset
	# and falls back to texture_margin. Normal/hover reserve pad + s on the
	# shadow side, while pressed shifts content (+s, +s) with identical total span.
	if with_shadow and not pressed_shift:
		style.content_margin_left = pad
		style.content_margin_top = pad
		style.content_margin_right = pad + s
		style.content_margin_bottom = pad + s
	elif pressed_shift:
		style.content_margin_left = pad + s
		style.content_margin_top = pad + s
		style.content_margin_right = pad
		style.content_margin_bottom = pad
	else:
		style.content_margin_left = pad
		style.content_margin_top = pad
		style.content_margin_right = pad
		style.content_margin_bottom = pad
	style.draw_center = true
	return style


## Reusable R6 button states. Deliberately no font override: Godot's current
## language-aware font fallback remains in charge of all labels and numbers.
## Callers may install the returned Theme on a new opt-in button in stage 2.
static func make_button_theme(mode: StringName, pixel_unit := 1) -> Theme:
	if not Tokens.get_palette(mode).has("panel_surface"):
		return null

	var outline := Tokens.color(mode, &"outline_ink")
	var shadow := Tokens.color(mode, &"pixel_shadow")
	var surface := Tokens.color(mode, &"panel_surface")
	var soft := Tokens.color(mode, &"accent_soft")
	var active := Tokens.color(mode, &"accent_primary")
	var well := Tokens.color(mode, &"well_surface")
	var foreground := Tokens.color(mode, &"text_primary")
	var muted := Tokens.color(mode, &"text_muted")
	var theme := Theme.new()

	theme.set_stylebox(
		&"normal", &"Button", make_style(Tokens.TIER_M, surface, outline, shadow, true, pixel_unit)
	)
	theme.set_stylebox(
		&"hover", &"Button", make_style(Tokens.TIER_M, soft, outline, shadow, true, pixel_unit)
	)
	theme.set_stylebox(
		&"pressed",
		&"Button",
		make_style(Tokens.TIER_M, active, outline, shadow, false, pixel_unit, true)
	)
	theme.set_stylebox(
		&"disabled", &"Button", make_style(Tokens.TIER_M, well, outline, shadow, false, pixel_unit)
	)
	theme.set_stylebox(
		&"focus", &"Button", make_style(Tokens.TIER_M, soft, active, shadow, false, pixel_unit)
	)
	theme.set_color(&"font_color", &"Button", foreground)
	theme.set_color(&"font_hover_color", &"Button", foreground)
	theme.set_color(&"font_pressed_color", &"Button", foreground)
	theme.set_color(&"font_disabled_color", &"Button", muted)
	theme.set_color(&"font_focus_color", &"Button", foreground)
	return theme


static func _inside(x: int, y: int, side: int, corner_steps: PackedInt32Array) -> bool:
	if x < 0 or y < 0 or x >= side or y >= side:
		return false
	var row_from_edge := mini(y, side - y - 1)
	var column_from_edge := mini(x, side - x - 1)
	var cutoff := 0
	if row_from_edge < corner_steps.size():
		cutoff = corner_steps[row_from_edge]
	return column_from_edge >= cutoff
