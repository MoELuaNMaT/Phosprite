class_name PhospriteStage2Icons
extends RefCounted

## Pure integer pixel icons. Sources are 20x20 lossless PNGs, each with a
## 16x16 drawing box and two transparent pixels of external padding.
## - icon(id): crops to the 16x16 safe area and renders at exact 2x (32px).
## - icon_1x(id): crops to the 16x16 safe area at exact 1x (16px), ideal for
##   36-38px action buttons with text labels so icons keep ~45% height ratio
##   and never crowd borders or hard shadows.
const GALLERY := preload("res://assets/graphics/q_icons/top/back_gallery.png")
const SETTINGS := preload("res://assets/graphics/q_icons/top/settings_gear.png")
const EFFECTS := preload("res://assets/graphics/q_icons/top/effects_fx.png")
const NEW := preload("res://assets/graphics/q_icons/gallery/new_plus.png")
const IMPORT := preload("res://assets/graphics/q_icons/gallery/import_folder.png")
const MULTI_SELECT := preload("res://assets/graphics/q_icons/gallery/multi_select.png")
const UI1 := preload("res://assets/graphics/q_icons/layout/profile_ui1.png")
const UI3 := preload("res://assets/graphics/q_icons/layout/profile_ui3.png")
const UI4 := preload("res://assets/graphics/q_icons/layout/profile_ui4.png")

static var _cache: Dictionary = {}
static var _cache_1x: Dictionary = {}


static func _source_for(id: StringName) -> Texture2D:
	match id:
		&"gallery":
			return GALLERY
		&"settings":
			return SETTINGS
		&"effects":
			return EFFECTS
		&"new":
			return NEW
		&"import":
			return IMPORT
		&"multi_select":
			return MULTI_SELECT
		&"ui1":
			return UI1
		&"ui3":
			return UI3
		&"ui4":
			return UI4
		_:
			return null


static func icon(id: StringName) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var source := _source_for(id)
	if source == null:
		return null
	var image := source.get_image().get_region(Rect2i(2, 2, 16, 16))
	image.resize(32, 32, Image.INTERPOLATE_NEAREST)
	var texture := ImageTexture.create_from_image(image)
	_cache[id] = texture
	return texture


static func icon_1x(id: StringName) -> Texture2D:
	if _cache_1x.has(id):
		return _cache_1x[id]
	var source := _source_for(id)
	if source == null:
		return null
	var image := source.get_image().get_region(Rect2i(2, 2, 16, 16))
	var texture := ImageTexture.create_from_image(image)
	_cache_1x[id] = texture
	return texture
