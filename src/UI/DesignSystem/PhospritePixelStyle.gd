class_name PhospritePixelStyle
extends RefCounted

## Deterministic, nearest-neighbor-friendly nine-slice resources.
## Chibi Low-Res Pixel UI Grid:
## - Floppy Disk Cards use U = 5px (~41x44 logical pixels) for chunky, plump Q-version charm:
##   * Stroke = 5px (1U), Bevel = 5px (1U), Shadow = 5px (1U)
##   * Plump rounded corners (2U/1U step) + 4-step 45-deg top-right chamfer (20px = 4U)
##   * Uniform 10px (2U) outline-to-outline gap on all 4 sides around the preview sticker
## - TopBar & Tactile Keycap Buttons use U = 4px for chunky toy-like 3D depth.

const Tokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")
const SHADOW_OFFSET := 2
const BAR_U := 4
const FLOPPY_U := 5
const FLOPPY_STROKE := 5
const FLOPPY_SHADOW := 5

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
		var draw_outline := outline.a > 0.001

		if with_shadow and not pressed_shift:
			for y in range(side):
				for x in range(side):
					if _inside(x - shadow_offset, y - shadow_offset, body_side, corner_steps):
						image.set_pixel(x, y, shadow)

		for y in range(body_side):
			for x in range(body_side):
				if not _inside(x, y, body_side, corner_steps):
					continue
				var edge := false
				if draw_outline:
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


## Chunky Chibi 3D Pixel Keycap Button (U = 4px default):
## - Plump 1U corners, 1U stroke, 1U top/left highlight, 1U shade, 2U lip, 1U shadow
static func make_beveled_button_style(
	background: Color,
	highlight: Color,
	shade: Color,
	outline: Color,
	shadow: Color,
	with_shadow := true,
	stroke := BAR_U,
	recessed := false,
	pressed_shift := false,
	pad_x := 12.0,
	pad_y := 6.0
) -> StyleBoxTexture:
	var u := clampi(stroke, 3, 5)
	var shadow_offset := u if (with_shadow or pressed_shift) else 0
	var side := u * 11
	var body_side := side - shadow_offset
	var body_offset := shadow_offset if pressed_shift else 0
	var corner := u
	var tex_key := (
		"chibi_btn|%s|%s|%s|%s|%s|%d|%d|%d|%d"
		% [
			background.to_html(),
			highlight.to_html(),
			shade.to_html(),
			outline.to_html(),
			shadow.to_html(),
			int(with_shadow),
			u,
			int(recessed),
			int(pressed_shift),
		]
	)
	var texture := _texture_cache.get(tex_key) as ImageTexture
	if texture == null:
		var image := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)

		if with_shadow and not pressed_shift:
			for y in range(side):
				for x in range(side):
					if _inside_chamfer_rect(
						x - shadow_offset, y - shadow_offset, body_side, corner
					):
						image.set_pixel(x, y, shadow)

		var top_bevel := u
		var left_bevel := u
		var right_bevel := u
		var bottom_bevel := u if recessed else (u * 2)
		var tl_color := shade if recessed else highlight
		var br_color := highlight if recessed else shade

		for y in range(body_side):
			for x in range(body_side):
				if not _inside_chamfer_rect(x, y, body_side, corner):
					continue
				var is_outline := false
				for d in range(1, u + 1):
					if (
						not _inside_chamfer_rect(x - d, y, body_side, corner)
						or not _inside_chamfer_rect(x + d, y, body_side, corner)
						or not _inside_chamfer_rect(x, y - d, body_side, corner)
						or not _inside_chamfer_rect(x, y + d, body_side, corner)
					):
						is_outline = true
						break
				if is_outline:
					image.set_pixel(x + body_offset, y + body_offset, outline)
					continue
				var ix := x - u
				var iy := y - u
				var iw := body_side - u * 2
				var ih := body_side - u * 2
				var pixel_col := background
				if iy >= ih - bottom_bevel or ix >= iw - right_bevel:
					pixel_col = br_color
				elif iy < top_bevel or ix < left_bevel:
					pixel_col = tl_color
				image.set_pixel(x + body_offset, y + body_offset, pixel_col)

		texture = ImageTexture.create_from_image(image)
		_texture_cache[tex_key] = texture

	var style := StyleBoxTexture.new()
	style.texture = texture
	style.region_rect = Rect2(Vector2.ZERO, Vector2(side, side))
	style.texture_margin_left = u * 3
	style.texture_margin_top = u * 3
	style.texture_margin_right = u * 3 + shadow_offset
	style.texture_margin_bottom = u * 4 + shadow_offset
	var s := float(shadow_offset)
	if with_shadow and not pressed_shift:
		style.content_margin_left = pad_x
		style.content_margin_top = pad_y
		style.content_margin_right = pad_x + s
		style.content_margin_bottom = pad_y + s + float(u)
	elif pressed_shift:
		style.content_margin_left = pad_x + s
		style.content_margin_top = pad_y + s
		style.content_margin_right = pad_x
		style.content_margin_bottom = pad_y
	else:
		style.content_margin_left = pad_x
		style.content_margin_top = pad_y
		style.content_margin_right = pad_x
		style.content_margin_bottom = pad_y
	style.draw_center = true
	return style


## Chunky Chibi 3D Embossed Docked TopBar (U = 4px):
## Top 4px highlight, bottom 4px shade bevel, 4px ink border, 4px cast shadow.
static func make_beveled_dock_bar_style(
	background: Color,
	highlight: Color,
	shade: Color,
	border: Color,
	cast_shadow: Color,
	stroke := BAR_U
) -> StyleBoxTexture:
	var u := clampi(stroke, 3, 5)
	var w := u * 6
	var h := u * 8
	var tex_key := (
		"chibi_topbar|%s|%s|%s|%s|%s|%d"
		% [
			background.to_html(),
			highlight.to_html(),
			shade.to_html(),
			border.to_html(),
			cast_shadow.to_html(),
			u,
		]
	)
	var texture := _texture_cache.get(tex_key) as ImageTexture
	if texture == null:
		var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		for y in range(h):
			var col := background
			if y < u:
				col = highlight
			elif y >= h - u:
				col = cast_shadow
			elif y >= h - u * 2:
				col = border
			elif y >= h - u * 3:
				col = shade
			for x in range(w):
				image.set_pixel(x, y, col)
		texture = ImageTexture.create_from_image(image)
		_texture_cache[tex_key] = texture

	var style := StyleBoxTexture.new()
	style.texture = texture
	style.region_rect = Rect2(Vector2.ZERO, Vector2(w, h))
	style.texture_margin_left = u * 2
	style.texture_margin_right = u * 2
	style.texture_margin_top = u * 2
	style.texture_margin_bottom = u * 4
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = float(u * 2)
	style.draw_center = true
	return style


## Chunky Recessed Pixel Well (topbar status pill, floppy shutter slot, empty checkbox).
static func make_recessed_well_style(
	background: Color,
	inner_shadow: Color,
	inner_light: Color,
	outline: Color,
	stroke := BAR_U,
	pad_x := 12.0,
	pad_y := 6.0
) -> StyleBoxTexture:
	var u := clampi(stroke, 3, 5)
	var side := u * 8
	var tex_key := (
		"chibi_well|%s|%s|%s|%s|%d"
		% [
			background.to_html(),
			inner_shadow.to_html(),
			inner_light.to_html(),
			outline.to_html(),
			u,
		]
	)
	var texture := _texture_cache.get(tex_key) as ImageTexture
	if texture == null:
		var image := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		var draw_outline := outline.a > 0.001
		var corner := u
		for y in range(side):
			for x in range(side):
				if not _inside_chamfer_rect(x, y, side, corner):
					continue
				var is_edge := false
				if draw_outline:
					for d in range(1, u + 1):
						if (
							not _inside_chamfer_rect(x - d, y, side, corner)
							or not _inside_chamfer_rect(x + d, y, side, corner)
							or not _inside_chamfer_rect(x, y - d, side, corner)
							or not _inside_chamfer_rect(x, y + d, side, corner)
						):
							is_edge = true
							break
				if is_edge:
					image.set_pixel(x, y, outline)
					continue
				var inset := u if draw_outline else 0
				var ix := x - inset
				var iy := y - inset
				var iw := side - inset * 2
				var ih := side - inset * 2
				var col := background
				if iy < u or ix < u:
					col = inner_shadow
				elif iy >= ih - u or ix >= iw - u:
					col = inner_light
				image.set_pixel(x, y, col)
		texture = ImageTexture.create_from_image(image)
		_texture_cache[tex_key] = texture

	var style := StyleBoxTexture.new()
	style.texture = texture
	style.region_rect = Rect2(Vector2.ZERO, Vector2(side, side))
	style.texture_margin_left = u * 3
	style.texture_margin_top = u * 3
	style.texture_margin_right = u * 3
	style.texture_margin_bottom = u * 3
	style.content_margin_left = pad_x
	style.content_margin_top = pad_y
	style.content_margin_right = pad_x
	style.content_margin_bottom = pad_y
	style.draw_center = true
	return style


## Low-Res Chibi 3.5-inch Floppy Disk Shell (U = 5px => ~41x44 logical pixels!):
## - Plump 2-step Q-version rounded corners on TL/BL/BR ([2U, 1U, 0] = [10px, 5px, 0])
## - Bold 4-step 45-degree pixel chamfer on top-right (20px = 4U, four huge 5x5 pixel blocks!)
## - Chunky 5px (1U) ink outline + uniform 5px (1U) 3D highlight/shade bevel + 5px (1U) drop shadow
static func make_floppy_shell_style(
	background: Color,
	highlight: Color,
	shade: Color,
	outline: Color,
	shadow: Color,
	stroke := FLOPPY_STROKE,
	shadow_offset := FLOPPY_SHADOW
) -> StyleBoxTexture:
	var u := clampi(stroke, 4, 6)
	var sh := shadow_offset
	var body_side := u * 16  # 80px
	var side := body_side + sh  # 85px
	var chamfer := u * 4  # 20px = four big chunky 5x5 pixel stair-steps!
	var tex_key := (
		"chibi_floppy_shell|%s|%s|%s|%s|%s|%d|%d"
		% [
			background.to_html(),
			highlight.to_html(),
			shade.to_html(),
			outline.to_html(),
			shadow.to_html(),
			u,
			sh,
		]
	)
	var texture := _texture_cache.get(tex_key) as ImageTexture
	if texture == null:
		var image := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)

		for y in range(side):
			for x in range(side):
				if _inside_chibi_floppy(x - sh, y - sh, body_side, chamfer, u):
					image.set_pixel(x, y, shadow)

		for y in range(body_side):
			for x in range(body_side):
				if not _inside_chibi_floppy(x, y, body_side, chamfer, u):
					continue
				var edge := false
				for d in range(1, u + 1):
					if (
						not _inside_chibi_floppy(x - d, y, body_side, chamfer, u)
						or not _inside_chibi_floppy(x + d, y, body_side, chamfer, u)
						or not _inside_chibi_floppy(x, y - d, body_side, chamfer, u)
						or not _inside_chibi_floppy(x, y + d, body_side, chamfer, u)
					):
						edge = true
						break
				if edge:
					image.set_pixel(x, y, outline)
					continue

				# Strict uniform 1U (5px) 3D bevel on ALL 4 sides
				var near_bottom_right := (
					not _inside_chibi_floppy(x + u * 2, y, body_side, chamfer, u)
					or not _inside_chibi_floppy(x, y + u * 2, body_side, chamfer, u)
				)
				var near_top_left := (
					not _inside_chibi_floppy(x - u * 2, y, body_side, chamfer, u)
					or not _inside_chibi_floppy(x, y - u * 2, body_side, chamfer, u)
				)
				var col := background
				if near_bottom_right:
					col = shade
				elif near_top_left:
					col = highlight
				image.set_pixel(x, y, col)

		texture = ImageTexture.create_from_image(image)
		_texture_cache[tex_key] = texture

	var style := StyleBoxTexture.new()
	style.texture = texture
	style.region_rect = Rect2(Vector2.ZERO, Vector2(side, side))
	style.texture_margin_left = u * 5
	style.texture_margin_top = u * 6
	style.texture_margin_right = u * 6 + sh
	style.texture_margin_bottom = u * 5 + sh
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	style.draw_center = true
	return style


## Low-Res Chibi Top Metal Shutter Plate (U = 5px):
## - Flush top, 1U bottom corners, 5px stroke, uniform 5px bevel, 5px cast shadow
static func make_shutter_style(
	background: Color,
	highlight: Color,
	shade: Color,
	outline: Color,
	cast_shadow: Color,
	stroke := FLOPPY_STROKE
) -> StyleBoxTexture:
	var u := clampi(stroke, 4, 6)
	var w := u * 9
	var cast_h := u
	var body_h := u * 9
	var h := body_h + cast_h
	var tex_key := (
		"chibi_shutter|%s|%s|%s|%s|%s|%d"
		% [
			background.to_html(),
			highlight.to_html(),
			shade.to_html(),
			outline.to_html(),
			cast_shadow.to_html(),
			u,
		]
	)
	var texture := _texture_cache.get(tex_key) as ImageTexture
	if texture == null:
		var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)

		for y in range(body_h, h):
			for x in range(u, w - u):
				image.set_pixel(x, y, cast_shadow)

		for y in range(body_h):
			for x in range(w):
				if not _inside_shutter(x, y, w, body_h, u):
					continue
				var edge := false
				for d in range(1, u + 1):
					if (
						not _inside_shutter(x - d, y, w, body_h, u)
						or not _inside_shutter(x + d, y, w, body_h, u)
						or not _inside_shutter(x, y - d, w, body_h, u)
						or not _inside_shutter(x, y + d, w, body_h, u)
					):
						edge = true
						break
				if edge:
					image.set_pixel(x, y, outline)
					continue
				var col := background
				if y >= body_h - u * 2 or x >= w - u * 2:
					col = shade
				elif y < u * 2 or x < u * 2:
					col = highlight
				image.set_pixel(x, y, col)
		texture = ImageTexture.create_from_image(image)
		_texture_cache[tex_key] = texture

	var style := StyleBoxTexture.new()
	style.texture = texture
	style.region_rect = Rect2(Vector2.ZERO, Vector2(w, h))
	style.texture_margin_left = u * 3
	style.texture_margin_top = u * 3
	style.texture_margin_right = u * 3
	style.texture_margin_bottom = u * 3 + cast_h
	# Symmetric padding on 5px grid: L=R=14px (5+5+4), T=B=10px (5+5+0) + 5px cast
	style.content_margin_left = float(u * 2 + 4)
	style.content_margin_right = float(u * 2 + 4)
	style.content_margin_top = float(u * 2)
	style.content_margin_bottom = float(u * 2 + cast_h)
	style.draw_center = true
	return style


## Low-Res Chibi Recessed Floppy Paper Sticker Well (U = 5px):
## - Chunky 5px (1U) outline, plump 1U corners
## - Chunky 2U (10px) pastel header stripe (5px specular + 5px main) + 5px divider
## - Cute 1U (5x5) glossy white sparkle pixel on top-left of stripe!
## - Uniform 5px (1U) recessed inner well shadow/light on all 4 sides
static func make_sticker_style(
	background: Color,
	inner_shadow: Color,
	inner_light: Color,
	stripe: Color,
	stripe_light: Color,
	_stripe_shade: Color,
	outline: Color,
	stroke := FLOPPY_STROKE
) -> StyleBoxTexture:
	var u := clampi(stroke, 4, 6)
	var stripe_h := u * 2  # 10px = 5px highlight + 5px core
	var divider_h := u  # 5px
	var side := u * 12  # 60px
	var tex_key := (
		"chibi_sticker|%s|%s|%s|%s|%s|%s|%d"
		% [
			background.to_html(),
			inner_shadow.to_html(),
			inner_light.to_html(),
			stripe.to_html(),
			stripe_light.to_html(),
			outline.to_html(),
			u,
		]
	)
	var texture := _texture_cache.get(tex_key) as ImageTexture
	if texture == null:
		var image := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		var divider_y := u + stripe_h
		var well_top := divider_y + divider_h
		for y in range(side):
			for x in range(side):
				if not _inside_chamfer_rect(x, y, side, u):
					continue
				var edge := false
				for d in range(1, u + 1):
					if (
						not _inside_chamfer_rect(x - d, y, side, u)
						or not _inside_chamfer_rect(x + d, y, side, u)
						or not _inside_chamfer_rect(x, y - d, side, u)
						or not _inside_chamfer_rect(x, y + d, side, u)
					):
						edge = true
						break
				if edge:
					image.set_pixel(x, y, outline)
				elif y < divider_y:
					# Cute glossy sparkle pixel at top-left of the pastel stripe!
					if x >= u * 2 and x < u * 3 and y >= u and y < u * 2:
						image.set_pixel(x, y, Color.WHITE)
					elif y < u * 2:
						image.set_pixel(x, y, stripe_light)
					else:
						image.set_pixel(x, y, stripe)
				elif y < well_top:
					image.set_pixel(x, y, outline)
				else:
					var col := background
					if y < well_top + u or x < u * 2:
						col = inner_shadow
					elif y >= side - u * 2 or x >= side - u * 2:
						col = inner_light
					image.set_pixel(x, y, col)
		texture = ImageTexture.create_from_image(image)
		_texture_cache[tex_key] = texture

	var style := StyleBoxTexture.new()
	style.texture = texture
	style.region_rect = Rect2(Vector2.ZERO, Vector2(side, side))
	style.texture_margin_left = u * 4
	style.texture_margin_top = u + stripe_h + divider_h + u * 2
	style.texture_margin_right = u * 4
	style.texture_margin_bottom = u * 4
	# Symmetric 5px (1U) inner pad around the flat recessed cream preview well
	style.content_margin_left = float(u * 3)
	style.content_margin_right = float(u * 3)
	style.content_margin_bottom = float(u * 3)
	style.content_margin_top = float(u + stripe_h + divider_h + u * 2)
	style.draw_center = true
	return style


static func make_dock_bar_style(
	background: Color, bottom_border: Color, border_width := 4
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_bottom = clampi(border_width, 1, 5)
	style.border_color = bottom_border
	style.anti_aliasing = false
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style


static func make_flat_pill(
	tier: StringName, background: Color, pixel_unit := 2, pad_x := 8.0, pad_y := 4.0
) -> StyleBoxTexture:
	var style := make_style(
		tier, background, Color.TRANSPARENT, Color.TRANSPARENT, false, pixel_unit, false
	)
	if style != null:
		style.content_margin_left = pad_x
		style.content_margin_right = pad_x
		style.content_margin_top = pad_y
		style.content_margin_bottom = pad_y
	return style


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


static func _inside_chamfer_rect(x: int, y: int, side: int, corner: int) -> bool:
	if x < 0 or y < 0 or x >= side or y >= side:
		return false
	if (x < corner or x >= side - corner) and (y < corner or y >= side - corner):
		return false
	return true


## Plump Chibi Floppy silhouette on U-pixel grid:
## - Top-right: 4 chunky 45-deg pixel steps (4U = 20px)
## - Top-left, bottom-left, bottom-right: 2-step rounded corners (2U outer, 1U inner)
static func _inside_chibi_floppy(x: int, y: int, side: int, chamfer: int, u: int) -> bool:
	if x < 0 or y < 0 or x >= side or y >= side:
		return false
	# Top-right 45-degree quantized pixel chamfer (4 big chunky steps)
	if y < chamfer:
		var band := int(y / u)
		var right_cut := chamfer - band * u
		if x >= side - right_cut:
			return false
	# Plump 2-step rounded corners on top-left, bottom-left, bottom-right
	var ry := mini(y, side - 1 - y)
	var rx := mini(x, side - 1 - x)
	var is_top_right := y < chamfer and x >= side - chamfer
	if not is_top_right:
		if ry < u and rx < u * 2:
			return false
		if ry < u * 2 and rx < u:
			return false
	return true


static func _inside_shutter(x: int, y: int, w: int, h: int, u: int) -> bool:
	if x < 0 or y < 0 or x >= w or y >= h:
		return false
	# Square flush top corners, plump 1U rounded bottom corners
	if y >= h - u and (x < u or x >= w - u):
		return false
	return true


## Clean, centered single-layer 3D tactile pixel button as a cached StyleBoxTexture:
## - Strictly symmetric horizontal padding so compact 24-32px icons stay dead-center
## - Subtle 1px border + 2px bottom depth lip (flattened to 2px top inset when pressed)
static func make_single_layer_button_style(
	bg: Color,
	border: Color,
	lip_color: Color,
	has_lip := true,
	recessed := false,
	pad_x := 4.0,
	pad_y := 3.0
) -> StyleBoxTexture:
	var side := 20
	var tex_key := (
		"s1_btn|%s|%s|%s|%d|%d"
		% [bg.to_html(), border.to_html(), lip_color.to_html(), int(has_lip), int(recessed)]
	)
	var texture := _texture_cache.get(tex_key) as ImageTexture
	if texture == null:
		var image := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		for y in range(side):
			for x in range(side):
				# Crisp 2px pixel-stepped corners
				var rx := mini(x, side - 1 - x)
				var ry := mini(y, side - 1 - y)
				if rx + ry < 2:
					continue
				var is_outer := x == 0 or x == side - 1 or y == 0 or y == side - 1 or rx + ry == 2
				if is_outer:
					image.set_pixel(x, y, border)
				elif has_lip and y >= side - 3:
					image.set_pixel(x, y, lip_color)
				elif recessed and y <= 2:
					image.set_pixel(x, y, lip_color)
				else:
					image.set_pixel(x, y, bg)
		texture = ImageTexture.create_from_image(image)
		_texture_cache[tex_key] = texture

	var style := StyleBoxTexture.new()
	style.texture = texture
	style.region_rect = Rect2(Vector2.ZERO, Vector2(side, side))
	style.texture_margin_left = 5
	style.texture_margin_top = 5
	style.texture_margin_right = 5
	style.texture_margin_bottom = 5
	style.content_margin_left = pad_x
	style.content_margin_right = pad_x
	style.content_margin_top = pad_y + (1.0 if recessed else 0.0)
	style.content_margin_bottom = pad_y + (2.0 if has_lip else 0.0)
	style.draw_center = true
	return style


## Flat edge-docked panel / bar as a cached StyleBoxTexture (0px corners, crisp divider).
static func make_flat_panel_texture(
	bg: Color, top_border: Color, bottom_border: Color, border_px := 2
) -> StyleBoxTexture:
	var w := 12
	var h := 16
	var b := clampi(border_px, 1, 3)
	var tex_key := (
		"flat_bar|%s|%s|%s|%d" % [bg.to_html(), top_border.to_html(), bottom_border.to_html(), b]
	)
	var texture := _texture_cache.get(tex_key) as ImageTexture
	if texture == null:
		var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		for y in range(h):
			var col := bg
			if top_border.a > 0.001 and y < b:
				col = top_border
			elif bottom_border.a > 0.001 and y >= h - b:
				col = bottom_border
			for x in range(w):
				image.set_pixel(x, y, col)
		texture = ImageTexture.create_from_image(image)
		_texture_cache[tex_key] = texture

	var style := StyleBoxTexture.new()
	style.texture = texture
	style.region_rect = Rect2(Vector2.ZERO, Vector2(w, h))
	style.texture_margin_left = 3
	style.texture_margin_right = 3
	style.texture_margin_top = b + 2
	style.texture_margin_bottom = b + 2
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	style.draw_center = true
	return style
