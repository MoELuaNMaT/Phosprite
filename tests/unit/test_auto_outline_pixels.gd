extends "res://tests/test_base.gd"

const OUTLINE_SHADER := preload("res://src/Shaders/Effects/AutoOutline.gdshader")


func _blank_image() -> Image:
	var image := Image.create_empty(7, 7, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	return image


func _render(image: Image, width := 1, diagonals := false) -> void:
	var params := {
		"outline_color": Color.BLACK,
		"outline_width": width,
		"include_diagonals": diagonals,
	}
	var renderer := ShaderImageEffect.new()
	renderer.generate_image(image, OUTLINE_SHADER, params, image.get_size())


func test_blank_canvas_stays_transparent_with_outline_enabled() -> void:
	var image := _blank_image()
	_render(image)
	for y in image.get_height():
		for x in image.get_width():
			check_eq(image.get_pixel(x, y).a, 0.0, "transparent canvas cannot turn white")


func test_single_pixel_keeps_original_color_and_draws_only_four_neighbors() -> void:
	var image := _blank_image()
	image.set_pixel(3, 3, Color.RED)
	_render(image)
	check_eq(image.get_pixel(3, 3), Color.RED, "source pixels are not overwritten")
	for cell in [Vector2i(2, 3), Vector2i(4, 3), Vector2i(3, 2), Vector2i(3, 4)]:
		check_eq(image.get_pixelv(cell), Color.BLACK, "direct neighbors receive outline")
	for cell in [Vector2i(2, 2), Vector2i(4, 2), Vector2i(2, 4), Vector2i(4, 4)]:
		check_eq(image.get_pixelv(cell).a, 0.0, "diagonals remain clear in 4-way mode")
	check_eq(image.get_pixel(0, 0).a, 0.0, "distant pixel remains transparent")


func test_diagonal_outline_has_no_canvas_flood() -> void:
	var image := _blank_image()
	image.set_pixel(3, 3, Color.RED)
	_render(image, 1, true)
	for y in image.get_height():
		for x in image.get_width():
			if maxi(absi(x - 3), absi(y - 3)) <= 1:
				check_true(image.get_pixel(x, y).a > 0.0, "8-way neighbor is covered")
			else:
				check_eq(image.get_pixel(x, y).a, 0.0, "outside shape remains clear")


func test_outline_recomputes_after_erase_without_ghost_pixels() -> void:
	var source := _blank_image()
	source.set_pixel(3, 3, Color.RED)
	var first_preview := source.duplicate()
	_render(first_preview)
	check_eq(first_preview.get_pixel(2, 3), Color.BLACK, "initial border is visible")
	source.set_pixel(3, 3, Color.TRANSPARENT)
	var next_preview := source.duplicate()
	_render(next_preview)
	for y in next_preview.get_height():
		for x in next_preview.get_width():
			check_eq(next_preview.get_pixel(x, y).a, 0.0, "erased border leaves no residue")


func test_two_pixel_width_and_canvas_edge_are_clamped() -> void:
	var image := _blank_image()
	image.set_pixel(0, 0, Color.BLUE)
	_render(image, 2)
	check_eq(image.get_pixel(0, 0), Color.BLUE, "source at canvas edge is intact")
	check_eq(image.get_pixel(1, 0), Color.BLACK, "neighbor at canvas edge is outlined")
	check_eq(image.get_pixel(2, 0), Color.BLACK, "second pixel has a border")
	check_eq(image.get_pixel(1, 1), Color.BLACK, "diagonal Manhattan distance two")
	check_eq(image.get_pixel(2, 2).a, 0.0, "pixels outside radius are untouched")
	check_eq(image.get_pixel(6, 6).a, 0.0, "outline does not wrap to opposite edge")


func test_original_image_is_untouched_by_temporary_effect_preview() -> void:
	var cel_image := _blank_image()
	cel_image.set_pixel(3, 3, Color.RED)
	var display_image := cel_image.duplicate()
	_render(display_image)
	check_eq(cel_image.get_pixel(2, 3).a, 0.0, "original layer remains clear")
	check_eq(display_image.get_pixel(2, 3), Color.BLACK, "only display copy is outlined")
