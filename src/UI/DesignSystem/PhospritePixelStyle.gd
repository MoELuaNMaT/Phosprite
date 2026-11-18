class_name PhospritePixelStyle
extends RefCounted

## Deterministic, nearest-neighbor-friendly nine-slice resources.
## Do not make the user canvas a child of a dedicated filtering control just
## to style its window: the workspace renders these as isolated chrome.
##
## Each asset is built once when its theme changes, never on every draw frame.
## The two-pixel hard shadow is painted into the source texture. This avoids
## StyleBoxFlat.shadow_size, which applies an unwanted soft shadow.

const Tokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")
const SHADOW_OFFSET := 2


static func make_style(
	tier: StringName,
	background: Color,
	outline: Color,
	shadow: Color,
	with_shadow := false
) -> StyleBoxTexture:
	var side := Tokens.tier_size(tier)
	var slice_margin := Tokens.tier_texture_margin(tier)
	if side <= 0 or slice_margin <= 0:
		push_error("Invalid Phosprite pixel tier: %s" % tier)
		return null

	var image := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var body_side := side - (SHADOW_OFFSET if with_shadow else 0)
	var corner_steps := Tokens.corner_cutoffs(tier)

	if with_shadow:
		for y in range(side):
			for x in range(side):
				if _inside(x - SHADOW_OFFSET, y - SHADOW_OFFSET, body_side, corner_steps):
					image.set_pixel(x, y, shadow)

	for y in range(body_side):
		for x in range(body_side):
			if not _inside(x, y, body_side, corner_steps):
				continue
			var edge := (
				not _inside(x - 1, y, body_side, corner_steps)
				or not _inside(x + 1, y, body_side, corner_steps)
				or not _inside(x, y - 1, body_side, corner_steps)
				or not _inside(x, y + 1, body_side, corner_steps)
			)
			image.set_pixel(x, y, outline if edge else background)

	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	style.region_rect = Rect2(Vector2.ZERO, Vector2(side, side))
	style.texture_margin_left = slice_margin
	style.texture_margin_right = slice_margin
	style.texture_margin_top = slice_margin
	style.texture_margin_bottom = slice_margin
	style.content_margin_left = Tokens.tier_content_margin(tier)
	style.content_margin_right = Tokens.tier_content_margin(tier)
	style.content_margin_top = Tokens.tier_content_margin(tier)
	style.content_margin_bottom = Tokens.tier_content_margin(tier)
	style.draw_center = true
	return style


static func _inside(x: int, y: int, side: int, corner_steps: PackedInt32Array) -> bool:
	if x < 0 or y < 0 or x >= side or y >= side:
		return false
	var row_from_edge := mini(y, side - y - 1)
	var column_from_edge := mini(x, side - x - 1)
	var cutoff := 0
	if row_from_edge < corner_steps.size():
		cutoff = corner_steps[row_from_edge]
	return column_from_edge >= cutoff
