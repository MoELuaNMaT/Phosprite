class_name AutoOutlineRenderer
extends RefCounted
## Pixel-exact, non-destructive outline of the source layer's alpha silhouette.
## Uses the original alpha snapshot, so the generated outline never feeds itself.


static func apply(image: Image, params: Dictionary) -> void:
	var image_size := image.get_size()
	if image_size.x <= 0 or image_size.y <= 0:
		return
	var color: Color = params.get("outline_color", Color.BLACK)
	if color.a <= 0.0:
		return
	var outline_width := clampi(int(params.get("outline_width", 1)), 1, 4)
	var diagonals := bool(params.get("include_diagonals", false))
	var used_rect := image.get_used_rect()
	if not used_rect.has_area():
		return

	var image_width := image_size.x
	var image_height := image_size.y
	var original_alpha := PackedByteArray()
	original_alpha.resize(image_width * image_height)
	if image.get_format() == Image.FORMAT_RGBA8:
		# Avoid millions of Image.get_pixel() calls on typical RGBA8 projects.
		var raw_pixels := image.get_data()
		for index in original_alpha.size():
			original_alpha[index] = raw_pixels[index * 4 + 3]
	else:
		for y in image_height:
			for x in image_width:
				original_alpha[y * image_width + x] = (roundi(
					clampf(image.get_pixel(x, y).a, 0.0, 1.0) * 255.0
				))

	# Only expand pixels on the four-neighbor boundary of the original shape.
	# A fully opaque interior requires no work regardless of brush width.
	for y in range(maxi(0, used_rect.position.y), mini(image_height, used_rect.end.y)):
		for x in range(maxi(0, used_rect.position.x), mini(image_width, used_rect.end.x)):
			var index := y * image_width + x
			if original_alpha[index] == 0:
				continue
			var on_boundary := (
				(x > 0 and original_alpha[index - 1] == 0)
				or (x + 1 < image_width and original_alpha[index + 1] == 0)
				or (y > 0 and original_alpha[index - image_width] == 0)
				or (y + 1 < image_height and original_alpha[index + image_width] == 0)
			)
			if not on_boundary:
				continue
			for dy in range(-outline_width, outline_width + 1):
				var ny := y + dy
				if ny < 0 or ny >= image_height:
					continue
				for dx in range(-outline_width, outline_width + 1):
					if dx == 0 and dy == 0:
						continue
					if diagonals:
						if maxi(absi(dx), absi(dy)) > outline_width:
							continue
					elif absi(dx) + absi(dy) > outline_width:
						continue
					var nx := x + dx
					if nx < 0 or nx >= image_width:
						continue
					# Read ONLY the saved alpha. Pixels painted by this
					# pass cannot become new sources of the outline.
					if original_alpha[ny * image_width + nx] == 0:
						image.set_pixel(nx, ny, color)
