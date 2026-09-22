class_name ProjectFactory
extends RefCounted

const StoragePolicy := preload("res://src/PlatformServices/StoragePolicy.gd")

const DEFAULT_SIZE := Vector2i(64, 64)
const MAX_CANVAS_SIDE := 16384
const MAX_CANVAS_PIXELS := 4096 * 4096

const SQUARE_PRESETS: Array[Vector2i] = [
	Vector2i(16, 16),
	Vector2i(32, 32),
	Vector2i(64, 64),
	Vector2i(128, 128),
	Vector2i(256, 256),
	Vector2i(512, 512),
]
const FOUR_THREE_PRESETS: Array[Vector2i] = [
	Vector2i(21, 16),
	Vector2i(43, 32),
	Vector2i(85, 64),
	Vector2i(171, 128),
	Vector2i(341, 256),
	Vector2i(683, 512),
]
const SIXTEEN_NINE_PRESETS: Array[Vector2i] = [
	Vector2i(28, 16),
	Vector2i(57, 32),
	Vector2i(114, 64),
	Vector2i(228, 128),
	Vector2i(455, 256),
	Vector2i(910, 512),
]


static func is_canvas_size_supported(canvas_size: Vector2i) -> bool:
	if canvas_size.x < 1 or canvas_size.y < 1:
		return false
	if canvas_size.x > MAX_CANVAS_SIDE or canvas_size.y > MAX_CANVAS_SIDE:
		return false
	return int(canvas_size.x) * int(canvas_size.y) <= MAX_CANVAS_PIXELS


static func canvas_size_limit_message(canvas_size: Vector2i) -> String:
	if canvas_size.x > MAX_CANVAS_SIDE or canvas_size.y > MAX_CANVAS_SIDE:
		return tr("Width and height must each be %d px or less.") % MAX_CANVAS_SIDE
	if int(canvas_size.x) * int(canvas_size.y) > MAX_CANVAS_PIXELS:
		return tr(
			"Canvas is too large. Maximum total area is %d pixels (for example 4096 × 4096)."
		) % MAX_CANVAS_PIXELS
	return ""


static func all_presets() -> Array[Vector2i]:
	var presets: Array[Vector2i] = []
	presets.append_array(SQUARE_PRESETS)
	presets.append_array(FOUR_THREE_PRESETS)
	presets.append_array(SIXTEEN_NINE_PRESETS)
	return presets


static func create_blank_project(project_name: String, canvas_size: Vector2i) -> Project:
	if not is_canvas_size_supported(canvas_size):
		return null
	var project := Project.new([], project_name, canvas_size)
	project.layers.append(PixelLayer.new(project))
	project.frames.append(project.new_empty_frame())
	return project


static func make_untitled_name(date_time := {}) -> String:
	var value: Dictionary = date_time
	if value.is_empty():
		value = Time.get_datetime_dict_from_system()
	return (
		"未命名_%04d-%02d-%02d_%02d-%02d-%02d"
		% [
			int(value.get("year", 0)),
			int(value.get("month", 0)),
			int(value.get("day", 0)),
			int(value.get("hour", 0)),
			int(value.get("minute", 0)),
			int(value.get("second", 0)),
		]
	)


static func make_unique_project_path(
	base_name: String, directory := StoragePolicy.PROJECTS_DIRECTORY
) -> String:
	var safe_name := base_name.validate_filename()
	if safe_name.ends_with(StoragePolicy.PROJECT_EXTENSION):
		safe_name = safe_name.trim_suffix(StoragePolicy.PROJECT_EXTENSION)
	if safe_name.is_empty():
		safe_name = StoragePolicy.FALLBACK_NAME
	var candidate := directory.path_join(safe_name + StoragePolicy.PROJECT_EXTENSION)
	var suffix := 1
	while FileAccess.file_exists(candidate):
		candidate = directory.path_join(
			"%s_%d%s" % [safe_name, suffix, StoragePolicy.PROJECT_EXTENSION]
		)
		suffix += 1
	return candidate
