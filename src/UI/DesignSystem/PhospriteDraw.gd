class_name PhospriteDraw
extends RefCounted

## Pixel-aligned R4 swatch geometry. Color values remain unmodified.
## Use this from a CanvasItem._draw() callback only.
const Tokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")
const SWATCH_INSET := 2


static func swatch_rect(control_size: Vector2) -> Rect2i:
	var measured := Vector2i(control_size.round())
	return Rect2i(
		SWATCH_INSET,
		SWATCH_INSET,
		maxi(0, measured.x - SWATCH_INSET * 2),
		maxi(0, measured.y - SWATCH_INSET * 2)
	)


static func draw_pixel_swatch_r4(
	item: CanvasItem,
	control_size: Vector2,
	fill_color: Color,
	mode: StringName,
	is_empty: bool,
	left_selected: bool,
	right_selected: bool
) -> void:
	var rect := swatch_rect(control_size)
	if rect.size.x < 8 or rect.size.y < 8:
		item.draw_rect(Rect2(Vector2.ZERO, control_size), fill_color)
		return
	var unit := clampi(Global.pixel_ui_unit, 1, 3)
	var outline := Tokens.color(mode, &"outline_ink")
	var primary := Tokens.color(mode, &"accent_primary")
	if left_selected:
		_draw_silhouette(
			item, Rect2i(Vector2i.ZERO, Vector2i(control_size.round())), primary, unit
		)
	_draw_silhouette(item, rect, outline, unit)
	var inner := rect.grow(-unit)
	if inner.size.x < 2 or inner.size.y < 2:
		return
	# A swatch is a color sample, not a shaded illustration. Never paint a
	# white highlight over the user's actual paint color.
	if is_empty:
		_draw_silhouette(item, inner, Tokens.color(mode, &"well_surface"), unit)
	else:
		if fill_color.a < 1.0:
			_draw_checker(item, inner, unit, mode)
		_draw_silhouette(item, inner, fill_color, unit)
	if right_selected:
		# Secondary selection must not consume the reserved coral CTA color.
		var dot_size := maxi(5, mini(rect.size.x, rect.size.y) / 4)
		var dot := Rect2i(
			rect.end - Vector2i(dot_size + unit + 1, dot_size + unit + 1),
			Vector2i(dot_size, dot_size)
		)
		_draw_silhouette(item, dot, outline, 1)
		_draw_silhouette(
			item, dot.grow(-1), Tokens.color(mode, &"accent_soft"), 1
		)


static func draw_pixel_selection_outline(
	item: CanvasItem, size: Vector2, mode: StringName
) -> void:
	var bounds := Rect2i(Vector2i.ZERO, Vector2i(size.round()))
	if bounds.size.x < 8 or bounds.size.y < 8:
		return
	var unit := clampi(Global.pixel_ui_unit, 1, 3)
	var accent := Tokens.color(mode, &"accent_primary")
	var cutoffs := Tokens.corner_cutoffs(Tokens.TIER_M, unit)
	for y in range(bounds.size.y):
		var cut := _cutoff(y, bounds.size.y, cutoffs)
		for x in range(cut, bounds.size.x - cut):
			if (
				x < cut + unit
				or x >= bounds.size.x - cut - unit
				or y < unit
				or y >= bounds.size.y - unit
			):
				item.draw_rect(Rect2i(x, y, 1, 1), accent)


static func _draw_silhouette(
	item: CanvasItem, rect: Rect2i, fill: Color, unit: int
) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var cutoffs := Tokens.corner_cutoffs(Tokens.TIER_S, unit)
	for y in range(rect.size.y):
		var cut := _cutoff(y, rect.size.y, cutoffs)
		var width := rect.size.x - cut * 2
		if width > 0:
			item.draw_rect(Rect2i(rect.position.x + cut, rect.position.y + y, width, 1), fill)


static func _draw_checker(item: CanvasItem, rect: Rect2i, unit: int, mode: StringName) -> void:
	var light := Tokens.color(mode, &"panel_surface")
	var dark := Tokens.color(mode, &"well_surface")
	var cutoffs := Tokens.corner_cutoffs(Tokens.TIER_S, unit)
	for y in range(rect.size.y):
		var cut := _cutoff(y, rect.size.y, cutoffs)
		var left := rect.position.x + cut
		var right := rect.end.x - cut
		var x := left
		while x < right:
			var end_x := mini(right, (x / 4 + 1) * 4)
			var tile_color := light if ((x / 4 + y / 4) % 2 == 0) else dark
			item.draw_rect(
				Rect2i(x, rect.position.y + y, end_x - x, 1), tile_color
			)
			x = end_x


static func _cutoff(y: int, height: int, steps: PackedInt32Array) -> int:
	var distance := mini(y, height - 1 - y)
	return steps[distance] if distance >= 0 and distance < steps.size() else 0
