class_name PhospriteQIcons
extends RefCounted

## Unified Q-version (Chibi / Puffy) pixel icon loader with integer 2x scaling.
## Standard icons: 20x20 PNG (16x16 safe box + 2px padding) -> 32x32 nearest.
## Compact icons:  16x16 PNG (12x12 safe box + 2px padding) -> 24x24 nearest.

const TOOL_PATHS := {
	&"RectSelect": "res://assets/graphics/q_icons/tools/rect_select.png",
	&"EllipseSelect": "res://assets/graphics/q_icons/tools/ellipse_select.png",
	&"PolygonSelect": "res://assets/graphics/q_icons/tools/polygon_select.png",
	&"ColorSelect": "res://assets/graphics/q_icons/tools/color_select.png",
	&"MagicWand": "res://assets/graphics/q_icons/tools/magic_wand.png",
	&"Lasso": "res://assets/graphics/q_icons/tools/lasso.png",
	&"PaintSelect": "res://assets/graphics/q_icons/tools/draw_select.png",
	&"Move": "res://assets/graphics/q_icons/tools/move.png",
	&"Crop": "res://assets/graphics/q_icons/tools/crop.png",
	&"Text": "res://assets/graphics/q_icons/tools/text.png",
	&"3DShapeEdit": "res://assets/graphics/q_icons/tools/shape_3d_edit.png",
	&"Zoom": "res://assets/graphics/q_icons/tools/zoom.png",
	&"Pan": "res://assets/graphics/q_icons/tools/pan.png",
	&"ColorPicker": "res://assets/graphics/q_icons/tools/color_picker.png",
	&"Pencil": "res://assets/graphics/q_icons/tools/pencil.png",
	&"Eraser": "res://assets/graphics/q_icons/tools/eraser.png",
	&"Bucket": "res://assets/graphics/q_icons/tools/bucket.png",
	&"Shading": "res://assets/graphics/q_icons/tools/shading.png",
	&"LineTool": "res://assets/graphics/q_icons/tools/line.png",
	&"CurveTool": "res://assets/graphics/q_icons/tools/curve.png",
	&"RectangleTool": "res://assets/graphics/q_icons/tools/rectangle.png",
	&"EllipseTool": "res://assets/graphics/q_icons/tools/ellipse.png",
	&"IsometricBoxTool": "res://assets/graphics/q_icons/tools/isometric_box.png",
	&"GradientTool": "res://assets/graphics/q_icons/tools/gradient.png",
}

const STANDARD_PATHS := {
	&"gallery": "res://assets/graphics/q_icons/top/back_gallery.png",
	&"settings": "res://assets/graphics/q_icons/top/settings_gear.png",
	&"effects": "res://assets/graphics/q_icons/top/effects_fx.png",
	&"undo": "res://assets/graphics/q_icons/top/undo.png",
	&"redo": "res://assets/graphics/q_icons/top/redo.png",
	&"undo_history": "res://assets/graphics/q_icons/top/undo_history.png",
	&"export_share": "res://assets/graphics/q_icons/top/export_share.png",
	&"more_overflow": "res://assets/graphics/q_icons/top/more_overflow.png",
	&"new": "res://assets/graphics/q_icons/gallery/new_plus.png",
	&"import": "res://assets/graphics/q_icons/gallery/import_folder.png",
	&"multi_select": "res://assets/graphics/q_icons/gallery/multi_select.png",
	&"ui1": "res://assets/graphics/q_icons/layout/profile_ui1.png",
	&"ui3": "res://assets/graphics/q_icons/layout/profile_ui3.png",
	&"ui4": "res://assets/graphics/q_icons/layout/profile_ui4.png",
	&"grid_toggle": "res://assets/graphics/q_icons/ui3/grid_toggle.png",
	&"more_tools": "res://assets/graphics/q_icons/ui3/more_tools.png",
	&"mirror_h": "res://assets/graphics/q_icons/options/mirror_h.png",
	&"mirror_v": "res://assets/graphics/q_icons/options/mirror_v.png",
	&"pixel_perfect": "res://assets/graphics/q_icons/options/pixel_perfect.png",
	&"alpha_lock": "res://assets/graphics/q_icons/options/alpha_lock.png",
	&"play": "res://assets/graphics/q_icons/timeline/play.png",
	&"pause": "res://assets/graphics/q_icons/timeline/pause.png",
	&"play_backwards": "res://assets/graphics/q_icons/timeline/play_backwards.png",
	&"step_first": "res://assets/graphics/q_icons/timeline/step_first.png",
	&"step_last": "res://assets/graphics/q_icons/timeline/step_last.png",
	&"next_frame": "res://assets/graphics/q_icons/timeline/next_frame.png",
	&"prev_frame": "res://assets/graphics/q_icons/timeline/prev_frame.png",
	&"onion_skin": "res://assets/graphics/q_icons/timeline/onion_skin.png",
	&"onion_skin_off": "res://assets/graphics/q_icons/timeline/onion_skin_off.png",
	&"loop": "res://assets/graphics/q_icons/timeline/loop.png",
	&"loop_pingpong": "res://assets/graphics/q_icons/timeline/loop_pingpong.png",
	&"loop_none": "res://assets/graphics/q_icons/timeline/loop_none.png",
	&"new_item": "res://assets/graphics/q_icons/timeline/new_item.png",
	&"remove_item": "res://assets/graphics/q_icons/timeline/remove_item.png",
	&"copy_item": "res://assets/graphics/q_icons/timeline/copy_item.png",
	&"merge_down": "res://assets/graphics/q_icons/timeline/merge_down.png",
	&"move_up": "res://assets/graphics/q_icons/timeline/move_up.png",
	&"move_down": "res://assets/graphics/q_icons/timeline/move_down.png",
}

const COMPACT_PATHS := {
	&"window_close": "res://assets/graphics/q_icons/chrome/window_close.png",
	&"chevron_down": "res://assets/graphics/q_icons/chrome/chevron_down.png",
	&"swap_colors": "res://assets/graphics/q_icons/ui3/swap_colors.png",
	&"add_color": "res://assets/graphics/q_icons/palette/add_color.png",
	&"remove_color": "res://assets/graphics/q_icons/palette/remove_color.png",
	&"sort_colors": "res://assets/graphics/q_icons/palette/sort_colors.png",
	&"lock_grid": "res://assets/graphics/q_icons/palette/lock_grid.png",
	&"eye_open": "res://assets/graphics/q_icons/timeline/eye_open.png",
	&"eye_closed": "res://assets/graphics/q_icons/timeline/eye_closed.png",
	&"lock_closed": "res://assets/graphics/q_icons/timeline/lock_closed.png",
	&"lock_open": "res://assets/graphics/q_icons/timeline/lock_open.png",
	&"cel_linked": "res://assets/graphics/q_icons/timeline/cel_linked.png",
	&"cel_unlinked": "res://assets/graphics/q_icons/timeline/cel_unlinked.png",
	&"layer_pixel": "res://assets/graphics/q_icons/timeline/layer_pixel.png",
	&"layer_group": "res://assets/graphics/q_icons/timeline/layer_group.png",
	&"layer_tilemap": "res://assets/graphics/q_icons/timeline/layer_tilemap.png",
	&"layer_audio": "res://assets/graphics/q_icons/timeline/layer_audio.png",
}

static var _cache: Dictionary = {}


static func tool_icon(tool_name: StringName) -> Texture2D:
	var path: String = TOOL_PATHS.get(tool_name, "")
	if path.is_empty():
		return null
	return _load_scaled("tool:%s" % tool_name, path, 16, 32)


static func standard_icon(id: StringName) -> Texture2D:
	var path: String = STANDARD_PATHS.get(id, "")
	if path.is_empty():
		return null
	return _load_scaled("std:%s" % id, path, 16, 32)


static func compact_icon(id: StringName) -> Texture2D:
	var path: String = COMPACT_PATHS.get(id, "")
	if path.is_empty():
		return null
	return _load_scaled("cmp:%s" % id, path, 12, 24)


static func _load_scaled(
	cache_key: String, path: String, safe_side: int, target_side: int
) -> Texture2D:
	if _cache.has(cache_key):
		return _cache[cache_key] as Texture2D
	var source := ResourceLoader.load(path) as Texture2D
	if source == null:
		return null
	var image := source.get_image()
	if image == null or image.is_empty():
		return null
	var region := image.get_region(Rect2i(2, 2, safe_side, safe_side))
	region.resize(target_side, target_side, Image.INTERPOLATE_NEAREST)
	var texture := ImageTexture.create_from_image(region)
	_cache[cache_key] = texture
	return texture
