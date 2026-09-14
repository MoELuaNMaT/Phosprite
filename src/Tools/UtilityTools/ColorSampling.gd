extends RefCounted

## Shared canvas color sampling used by the Color Picker tool and temporary touch picking.
## The target button is kept explicit so Primary/Secondary remain data-model choices rather
## than being coupled to any particular future touch gesture for switching them.

enum { TOP_COLOR, CURRENT_LAYER }


static func pick_color(pos: Vector2i, target_button: int, mode := TOP_COLOR) -> bool:
	var project := Global.current_project
	pos = project.tiles.get_canon_position(pos)
	if pos.x < 0 or pos.y < 0:
		return false
	if Tools.is_placing_tiles():
		var cel := project.get_current_cel() as CelTileMap
		Tools.selected_tile_index_changed.emit(cel.get_cell_index_at_coords(pos))
		return true

	var image := Image.new()
	image.copy_from(project.get_current_cel().get_image())
	if pos.x > image.get_width() - 1 or pos.y > image.get_height() - 1:
		return false

	var color := Color(0, 0, 0, 0)
	var palette_index := -1
	match mode:
		TOP_COLOR:
			var curr_frame := project.frames[project.current_frame]
			for layer in project.layers.size():
				var idx := (project.layers.size() - 1) - layer
				if project.layers[idx].is_visible_in_hierarchy():
					var cel := curr_frame.cels[idx]
					image = cel.get_image()
					color = image.get_pixelv(pos)
					if cel is PixelCel:
						if cel.image.is_indexed:
							palette_index = cel.image.indices_image.get_pixel(pos.x, pos.y).r8 - 1
					if not is_zero_approx(color.a):
						break
		CURRENT_LAYER:
			color = image.get_pixelv(pos)
			var current_cel = project.get_current_cel()
			if current_cel is PixelCel:
				if current_cel.image.is_indexed:
					palette_index = current_cel.image.index_image.get_pixel(pos.x, pos.y).r8 - 1
		_:
			return false

	Tools.assign_color(color, target_button, false, palette_index)
	return true
