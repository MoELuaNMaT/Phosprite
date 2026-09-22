class_name BrushShapeGenerator
extends RefCounted

enum Shape {
	FILLED_SQUARE,
	HOLLOW_SQUARE,
	FILLED_CIRCLE,
	HOLLOW_CIRCLE,
}

const PREVIEW_SOURCE_LIMIT := 64


static func get_points(shape: Shape, brush_size: int) -> Array[Vector2i]:
	var size := maxi(1, brush_size)
	match shape:
		Shape.FILLED_SQUARE:
			return _get_filled_square_points(size)
		Shape.HOLLOW_SQUARE:
			return _get_hollow_square_points(size)
		Shape.FILLED_CIRCLE:
			return DrawingAlgos.get_ellipse_points_filled(Vector2i.ZERO, Vector2i.ONE * size)
		Shape.HOLLOW_CIRCLE:
			return DrawingAlgos.get_ellipse_points(Vector2i.ZERO, Vector2i.ONE * size)
	return []


static func create_preview_image(
	shape: Shape, brush_size: int, color := Color.WHITE, source_limit := PREVIEW_SOURCE_LIMIT
) -> Image:
	var preview_size := mini(maxi(1, brush_size), maxi(1, source_limit))
	var image := Image.create(preview_size, preview_size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for point in get_points(shape, preview_size):
		if (
			point.x >= 0
			and point.y >= 0
			and point.x < preview_size
			and point.y < preview_size
		):
			image.set_pixelv(point, color)
	return image


static func _get_filled_square_points(size: int) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for y in size:
		for x in size:
			points.append(Vector2i(x, y))
	return points


static func _get_hollow_square_points(size: int) -> Array[Vector2i]:
	if size <= 2:
		return _get_filled_square_points(size)
	var points: Array[Vector2i] = []
	for x in size:
		points.append(Vector2i(x, 0))
		points.append(Vector2i(x, size - 1))
	for y in range(1, size - 1):
		points.append(Vector2i(0, y))
		points.append(Vector2i(size - 1, y))
	return points
