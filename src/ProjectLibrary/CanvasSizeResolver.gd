class_name CanvasSizeResolver
extends RefCounted

const ProjectFactoryScript := preload("res://src/ProjectLibrary/ProjectFactory.gd")

const FALLBACK_SIZE := Vector2i(256, 256)
const RATIO_SQUARE := 1.0
const RATIO_FOUR_THREE := 4.0 / 3.0
const RATIO_SIXTEEN_NINE := 16.0 / 9.0


static func resolve(source_size: Vector2i) -> Vector2i:
	if source_size.x <= 0 or source_size.y <= 0:
		return FALLBACK_SIZE
	var landscape := source_size.x >= source_size.y
	var major := maxi(source_size.x, source_size.y)
	var minor := mini(source_size.x, source_size.y)
	var ratio := float(major) / float(minor)
	var presets := _nearest_family(ratio)
	for preset: Vector2i in presets:
		var oriented := preset if landscape else Vector2i(preset.y, preset.x)
		if oriented.x >= source_size.x and oriented.y >= source_size.y:
			return oriented
	return FALLBACK_SIZE


static func fit_layer_size(source_size: Vector2i, canvas_size: Vector2i) -> Vector2i:
	if source_size.x <= 0 or source_size.y <= 0 or canvas_size.x <= 0 or canvas_size.y <= 0:
		return Vector2i.ZERO
	if source_size.x <= canvas_size.x and source_size.y <= canvas_size.y:
		return source_size
	var scale_factor := minf(
		float(canvas_size.x) / float(source_size.x),
		float(canvas_size.y) / float(source_size.y)
	)
	return Vector2i(
		maxi(1, floori(float(source_size.x) * scale_factor)),
		maxi(1, floori(float(source_size.y) * scale_factor))
	)


static func centered_offset(content_size: Vector2i, canvas_size: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(canvas_size.x - content_size.x) * 0.5),
		floori(float(canvas_size.y - content_size.y) * 0.5)
	)


static func reference_scale(source_size: Vector2i, canvas_size: Vector2i) -> float:
	if source_size.x <= 0 or source_size.y <= 0 or canvas_size.x <= 0 or canvas_size.y <= 0:
		return 1.0
	return minf(
		float(canvas_size.x) / float(source_size.x),
		float(canvas_size.y) / float(source_size.y)
	)


static func reference_position(
	source_size: Vector2i, canvas_size: Vector2i, scale_factor: float
) -> Vector2:
	var fitted := Vector2(source_size) * scale_factor
	return (Vector2(canvas_size) - fitted) * 0.5


static func _nearest_family(ratio: float) -> Array[Vector2i]:
	var square_distance := absf(ratio - RATIO_SQUARE)
	var four_three_distance := absf(ratio - RATIO_FOUR_THREE)
	var sixteen_nine_distance := absf(ratio - RATIO_SIXTEEN_NINE)
	if square_distance <= four_three_distance and square_distance <= sixteen_nine_distance:
		return ProjectFactoryScript.SQUARE_PRESETS
	if four_three_distance <= sixteen_nine_distance:
		return ProjectFactoryScript.FOUR_THREE_PRESETS
	return ProjectFactoryScript.SIXTEEN_NINE_PRESETS
