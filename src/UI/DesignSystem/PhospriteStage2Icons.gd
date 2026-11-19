class_name PhospriteStage2Icons
extends RefCounted

## Pure integer pixel icons. Sources are 20x20 lossless PNGs, each with a
## 16x16 drawing box and two transparent pixels of external padding.
## Crop to the source safe area and render at exactly 2x (32px). This avoids
## 20->32 non-integer filtering and keeps existing 40px touch buttons usable.
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


static func icon(id: StringName) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var source: Texture2D
	match id:
		&"gallery":
			source = GALLERY
		&"settings":
			source = SETTINGS
		&"effects":
			source = EFFECTS
		&"new":
			source = NEW
		&"import":
			source = IMPORT
		&"multi_select":
			source = MULTI_SELECT
		&"ui1":
			source = UI1
		&"ui3":
			source = UI3
		&"ui4":
			source = UI4
		_:
			return null
	var image := source.get_image().get_region(Rect2i(2, 2, 16, 16))
	image.resize(32, 32, Image.INTERPOLATE_NEAREST)
	var texture := ImageTexture.create_from_image(image)
	_cache[id] = texture
	return texture
