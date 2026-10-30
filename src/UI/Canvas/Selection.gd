class_name SelectionNode
extends Node2D

signal transformation_confirmed
signal transformation_canceled

enum SelectionOperation { ADD, SUBTRACT, INTERSECT }
const CLIPBOARD_FILE_PATH := "user://clipboard.txt"

# flags (additional properties of selection that can be toggled)
static var flag_tilemode := false

var undo_data: Dictionary
var is_pasting := false
var preview_selection_map := SelectionMap.new()
var preview_selection_texture := ImageTexture.new()
var _marching_ants_time_elapsed := 0.0
var _paste_target_cels: Array[BaseCel] = []
var _selection_context_menu: PanelContainer
var _selection_action_buttons: Array[Button] = []
var _selection_confirm_button: Button
var _selection_cancel_button: Button

@onready var canvas := get_parent() as Canvas
@onready var transformation_handles := $TransformationHandles as TransformationHandles
@onready var marching_ants_outline := $MarchingAntsOutline as Sprite2D


func _ready() -> void:
	set_process(true)
	_on_selection_properties_updated()
	# Ensure to only call _input() if the cursor is inside the main canvas viewport
	Global.main_viewport.mouse_entered.connect(set_process_input.bind(true))
	Global.main_viewport.mouse_exited.connect(set_process_input.bind(false))
	marching_ants_outline.texture = preview_selection_texture
	transformation_handles.preview_transform_changed.connect(_update_marching_ants)
	Global.project_switched.connect(_project_switched)
	Global.transform_content_confirmed.connect(transform_content_confirm)
	Global.transform_content_canceled.connect(transform_content_cancel)
	Global.selection_properties_updated.connect(_on_selection_properties_updated)
	Global.camera.zoom_changed.connect(_update_on_zoom)
	_ensure_selection_context_menu()


func _exit_tree() -> void:
	# Any UI profile may reparent the shared Canvas while changing its layout.
	# Preserve the toolbar across reparenting; only release it on real deletion.
	if is_queued_for_deletion() and is_instance_valid(_selection_context_menu):
		_selection_context_menu.queue_free()


func _process(delta: float) -> void:
	_marching_ants_time_elapsed += delta
	marching_ants_outline.material.set_shader_parameter("time", _marching_ants_time_elapsed)
	_ensure_selection_context_menu()
	_update_selection_context_menu()


func _input(event: InputEvent) -> void:
	if transformation_handles.is_transforming():
		if event.is_action_pressed(&"transformation_confirm"):
			transform_content_confirm()
		elif event.is_action_pressed(&"transformation_cancel"):
			transform_content_cancel()


func _draw() -> void:
	marching_ants_outline.visible = Global.current_project.has_selection
	transformation_handles.queue_redraw()


func _on_selection_properties_updated() -> void:
	var mat := marching_ants_outline.material as ShaderMaterial
	mat.set_shader_parameter(&"animated", Global.selection_animated_borders)
	mat.set_shader_parameter(&"first_color", Global.selection_border_color_1)
	mat.set_shader_parameter(&"second_color", Global.selection_border_color_2)
	queue_redraw()


func _update_on_zoom() -> void:
	var zoom := Global.camera.zoom.x
	var size := maxi(
		Global.current_project.selection_map.get_size().x,
		Global.current_project.selection_map.get_size().y
	)
	marching_ants_outline.material.set_shader_parameter("width", 1.0 / zoom)
	marching_ants_outline.material.set_shader_parameter("frequency", zoom * 10 * size / 64)


func select_rect(rect: Rect2i, operation := SelectionOperation.ADD) -> void:
	var project := Global.current_project
	# Used only if the selection is outside of the canvas boundaries,
	# on the left and/or above (negative coords)
	var offset_position := Vector2i.ZERO
	if project.selection_offset.x < 0:
		rect.position.x -= project.selection_offset.x
		offset_position.x = project.selection_offset.x
	if project.selection_offset.y < 0:
		rect.position.y -= project.selection_offset.y
		offset_position.y = project.selection_offset.y

	if offset_position != Vector2i.ZERO:
		project.selection_map.move_bitmap_values(project)

	if operation == SelectionOperation.ADD:
		project.selection_map.fill_rect(rect, Color(1, 1, 1, 1))
	elif operation == SelectionOperation.SUBTRACT:
		project.selection_map.fill_rect(rect, Color(0))
	elif operation == SelectionOperation.INTERSECT:
		var previous_selection_map := SelectionMap.new()
		previous_selection_map.copy_from(project.selection_map)
		project.selection_map.clear()
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var pos := Vector2i(x, y)
				if !Rect2i(Vector2i.ZERO, previous_selection_map.get_size()).has_point(pos):
					continue
				project.selection_map.select_pixel(
					pos, previous_selection_map.is_pixel_selected(pos, false)
				)

	if offset_position != Vector2i.ZERO and project.has_selection:
		project.selection_map.move_bitmap_values(project)


func transform_content_confirm(
	project := Global.current_project, should_emit_signal := true
) -> void:
	if not transformation_handles.is_transforming():
		return
	var preview_image := transformation_handles.pre_transformed_image
	var original_selection_rect = project.selection_map.get_selection_rect(project)
	transformation_handles.bake_transform_to_selection(project.selection_map, true)
	var bounds := DrawingAlgos.get_transformed_bounds(
		original_selection_rect.size, transformation_handles.preview_transform
	)
	bounds.position -= bounds.position
	var target_cels := _paste_target_cels if is_pasting else get_selected_draw_cels()
	for cel in target_cels:
		var cel_image := cel.get_image()
		var src := Image.new()
		src.copy_from(preview_image)
		if not is_pasting:
			if not is_instance_valid(cel.transformed_content):
				continue
			src.copy_from(cel.transformed_content)
			cel.transformed_content = null
		var transformation_origin := transformation_handles.get_transform_top_left(src.get_size())
		if Tools.is_placing_tiles() and not is_pasting:
			if cel is not CelTileMap:
				continue
			var tilemap := cel as CelTileMap
			@warning_ignore("integer_division")
			var horizontal_size := bounds.size.x / tilemap.get_tile_size().x
			@warning_ignore("integer_division")
			var vertical_size := bounds.size.y / tilemap.get_tile_size().y
			var selected_cells := tilemap.resize_selection(
				transformation_handles.pre_transform_tilemap_cells, horizontal_size, vertical_size
			)
			src.crop(bounds.size.x, bounds.size.y)
			tilemap.apply_resizing_to_image(src, selected_cells, bounds, true)
		else:
			transformation_handles.bake_transform_to_image(src, bounds)

		if Tools.is_placing_tiles():
			if cel.get_tile_shape() != TileSet.TILE_SHAPE_SQUARE:
				continue
			cel_image.blit_rect(src, bounds, transformation_origin)
		else:
			cel_image.blit_rect_mask(src, src, bounds, transformation_origin)
		cel_image.convert_rgb_to_indexed()
	commit_undo("Move Selection", undo_data)

	is_pasting = false
	_paste_target_cels.clear()
	transformation_handles.only_transforms_selection = false
	queue_redraw()
	canvas.queue_redraw()
	if should_emit_signal:
		transformation_confirmed.emit()


func transform_content_cancel(project := Global.current_project) -> void:
	if not transformation_handles.is_transforming():
		return
	project.selection_offset = transformation_handles.pre_transform_selection_offset
	project.selection_map_changed()
	var target_cels := _paste_target_cels if is_pasting else get_selected_draw_cels()
	for cel in target_cels:
		var cel_image := cel.get_image()
		if !is_pasting and cel.transformed_content:
			cel_image.blit_rect_mask(
				cel.transformed_content,
				cel.transformed_content,
				Rect2i(Vector2i.ZERO, Global.current_project.selection_map.get_size()),
				project.selection_map.get_selection_rect(project).position
			)
			cel.transformed_content = null
	for cel_index in project.selected_cels:
		canvas.update_texture(cel_index[1])
	is_pasting = false
	_paste_target_cels.clear()
	transformation_handles.only_transforms_selection = false
	queue_redraw()
	canvas.queue_redraw()
	transformation_canceled.emit()


func commit_undo(action: String, undo_data_tmp: Dictionary) -> void:
	if !undo_data_tmp:
		print("No undo data found!")
		return
	var project := Global.current_project
	if Tools.is_placing_tiles() and not is_pasting:
		for cel in undo_data_tmp:
			if cel is CelTileMap:
				(cel as CelTileMap).re_index_all_cells(true)
	else:
		project.update_tilemaps(undo_data_tmp, TileSetPanel.TileEditingMode.AUTO)
	var redo_data := get_undo_data(undo_data_tmp["undo_image"])
	project.undo_redo.create_action(action)
	project.deserialize_cel_undo_data(redo_data, undo_data_tmp)
	project.undo_redo.add_do_property(project, "selection_offset", redo_data["outline_offset"])

	project.undo_redo.add_undo_property(
		project, "selection_offset", undo_data_tmp["outline_offset"]
	)

	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_do_method(project.selection_map_changed)
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.add_undo_method(project.selection_map_changed)
	project.undo_redo.commit_action()

	undo_data.clear()


func get_undo_data(undo_image: bool) -> Dictionary:
	var data := {}
	var project := Global.current_project
	data[project.selection_map] = project.selection_map.data
	data["outline_offset"] = project.selection_offset
	data["undo_image"] = undo_image

	if undo_image:
		var snapshot_cels := _paste_target_cels if is_pasting else get_selected_draw_cels()
		project.serialize_cel_undo_data(snapshot_cels, data)
	return data


func _update_marching_ants() -> void:
	preview_selection_map.copy_from(Global.current_project.selection_map)
	if is_instance_valid(transformation_handles.transformed_selection_map):
		transformation_handles.bake_transform_to_selection(preview_selection_map)
	preview_selection_texture.set_image(preview_selection_map)


# TODO: Change BaseCel to PixelCel if Godot ever fixes issues
# with typed arrays being cast into other types.
func get_selected_draw_cels() -> Array[BaseCel]:
	var cels: Array[BaseCel] = []
	var project := Global.current_project
	for cel_index in project.selected_cels:
		var cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
		if not cel is PixelCel:
			continue
		if project.layers[cel_index[1]].can_layer_get_drawn():
			cels.append(cel)
	return cels


func _get_selected_draw_images(tile_cel_pointer: Array[CelTileMap]) -> Array[ImageExtended]:
	var images: Array[ImageExtended] = []
	var project := Global.current_project
	for cel_index in project.selected_cels:
		var cel: BaseCel = project.frames[cel_index[0]].cels[cel_index[1]]
		if not cel is PixelCel:
			continue
		if cel is CelTileMap and Tools.is_placing_tiles():
			tile_cel_pointer.append(cel)
			continue
		if project.layers[cel_index[1]].can_layer_get_drawn():
			var image := cel.get_image()
			if is_instance_valid(image) and image is ImageExtended:  # Avoid type conflicts
				images.append(cel.get_image())
	return images


## Returns the portion of current cel's image enclosed by the selection.
func get_enclosed_image() -> Image:
	var project := Global.current_project
	if !project.has_selection:
		return

	var image := project.get_current_cel().get_image()
	var enclosed_img := Image.new()
	if transformation_handles.is_transforming():
		enclosed_img.copy_from(transformation_handles.transformed_image)
	else:
		enclosed_img = get_selected_image(image)
	return enclosed_img


func cut() -> void:
	var project := Global.current_project
	if !project.layers[project.current_layer].can_layer_get_drawn():
		return
	copy()
	delete(false)


## Copies the selection content (works in or between pixelorama instances only).
func copy() -> void:
	var project := Global.current_project
	var cl_image := Image.new()
	var cl_selection_map := SelectionMap.new()
	var cl_big_bounding_rectangle := Rect2()
	var cl_selection_offset := Vector2.ZERO

	var image := project.get_current_cel().get_image()
	var to_copy := Image.new()
	if !project.has_selection:
		to_copy.copy_from(image)
		cl_selection_map.copy_from(project.selection_map)
		cl_selection_map.select_all()
		cl_big_bounding_rectangle = Rect2(Vector2.ZERO, project.size)
	else:
		var selection_rect := project.selection_map.get_selection_rect(project)
		if transformation_handles.is_transforming():
			if transformation_handles.only_transforms_selection:
				transform_content_confirm()
				selection_rect = project.selection_map.get_selection_rect(project)
		if transformation_handles.is_transforming():
			to_copy.copy_from(transformation_handles.transformed_image)
			cl_selection_map = preview_selection_map
		else:
			to_copy = image.get_region(selection_rect)
			# Remove unincluded pixels if the selection is not a single rectangle
			var offset_pos := selection_rect.position
			for x in to_copy.get_size().x:
				for y in to_copy.get_size().y:
					var pos := Vector2i(x, y)
					if offset_pos.x < 0:
						offset_pos.x = 0
					if offset_pos.y < 0:
						offset_pos.y = 0
					if not project.selection_map.is_pixel_selected(pos + offset_pos, false):
						to_copy.set_pixelv(pos, Color(0))
			cl_selection_map.copy_from(project.selection_map)
		cl_big_bounding_rectangle = selection_rect

	cl_image = to_copy
	cl_selection_offset = project.selection_offset
	var transfer_clipboard := {
		"image": cl_image,
		"selection_map": cl_selection_map.data,
		"big_bounding_rectangle": cl_big_bounding_rectangle,
		"selection_offset": cl_selection_offset,
	}

	var clipboard_file := FileAccess.open(CLIPBOARD_FILE_PATH, FileAccess.WRITE)
	clipboard_file.store_var(transfer_clipboard, true)
	clipboard_file.close()

	if !to_copy.is_empty():
		var pattern: Patterns.Pattern = Global.patterns_popup.get_pattern(0)
		pattern.image = to_copy
		var tex := ImageTexture.create_from_image(to_copy)
		var container = Global.patterns_popup.get_node("ScrollContainer/PatternContainer")
		container.get_child(0).get_child(0).texture = tex


static func has_app_clipboard() -> bool:
	return FileAccess.file_exists(CLIPBOARD_FILE_PATH)


static func has_system_clipboard() -> bool:
	return DisplayServer.clipboard_has_image()


static func get_clipboard_size(app_clipboard: bool) -> Vector2i:
	var image := get_clipboard_image(app_clipboard)
	if is_instance_valid(image) and not image.is_empty():
		return image.get_size()
	return Vector2i.ONE  # The minimum valid size of an image


static func get_clipboard_image(app_clipboard: bool) -> Image:
	var image: Image
	if app_clipboard:
		if has_app_clipboard():
			var clipboard_file := FileAccess.open(CLIPBOARD_FILE_PATH, FileAccess.READ)
			var clipboard = clipboard_file.get_var(true)
			clipboard_file.close()
			if (
				typeof(clipboard) == TYPE_DICTIONARY
				and clipboard.has_all(
					["image", "selection_map", "big_bounding_rectangle", "selection_offset"]
				)
				and not clipboard.image.is_empty()
			):
				image = clipboard.image
	else:
		if has_system_clipboard():
			image = DisplayServer.clipboard_get_image()
	return image


## Pastes the selection content.
func paste(in_place := false) -> void:
	if !FileAccess.file_exists(CLIPBOARD_FILE_PATH):
		return
	var clipboard_file := FileAccess.open(CLIPBOARD_FILE_PATH, FileAccess.READ)
	var clipboard = clipboard_file.get_var(true)
	clipboard_file.close()

	# Sanity checks
	if typeof(clipboard) != TYPE_DICTIONARY:
		return
	if !clipboard.has_all(["image", "selection_map", "big_bounding_rectangle", "selection_offset"]):
		return
	if clipboard.image.is_empty():
		return

	if transformation_handles.is_transforming():
		transform_content_confirm()
	_paste_target_cels = get_selected_draw_cels()
	if _paste_target_cels.is_empty():
		return
	undo_data = get_undo_data(true)
	clear_selection()
	var project := Global.current_project

	var clip_map := SelectionMap.new()
	clip_map.data = clipboard.selection_map
	var max_size := Vector2i(
		maxi(clip_map.get_size().x, project.selection_map.get_size().x),
		maxi(clip_map.get_size().y, project.selection_map.get_size().y)
	)

	project.selection_map.copy_from(clip_map)
	project.selection_map.crop(max_size.x, max_size.y)
	var selection_rect := project.selection_map.get_selection_rect(project)
	project.selection_offset = clipboard.selection_offset
	var transform_origin: Vector2 = clipboard.big_bounding_rectangle.position
	var grid_size := Global.grids[0].grid_size
	var grid_offset := Global.grids[0].grid_offset
	if not in_place:  # If "Paste" is selected, and not "Paste in Place"
		var camera_center := Global.camera.camera_screen_center
		camera_center -= Vector2(selection_rect.size) / 2.0
		var max_pos := project.size - selection_rect.size
		if max_pos.x >= 0:
			camera_center.x = clampf(camera_center.x, 0, max_pos.x)
		else:
			camera_center.x = 0
		if max_pos.y >= 0:
			camera_center.y = clampf(camera_center.y, 0, max_pos.y)
		else:
			camera_center.y = 0
		transform_origin = Vector2i(camera_center.floor())
		if Tools.is_placing_tiles():
			var tilemap_cel := Global.current_project.get_current_cel() as CelTileMap
			var tile_size := tilemap_cel.get_tile_size()
			var offset := tilemap_cel.offset % tile_size
			transform_origin = Vector2i(
				Tools.snap_to_rectangular_grid_boundary(transform_origin, tile_size, offset)
			)
		elif Global.snap_to_rectangular_grid_center:
			# Offset the selection so that the center of selection falls above the center of grid.
			transform_origin = (
				Vector2i(
					Tools.snap_to_rectangular_grid_center(transform_origin, grid_size, grid_offset)
				)
				- Vector2i((clipboard.image.get_size() / 2.0).floor())
			)
		elif Global.snap_to_rectangular_grid_boundary:
			transform_origin = Vector2i(
				Tools.snap_to_rectangular_grid_boundary(transform_origin, grid_size, grid_offset)
			)
		project.selection_map.move_bitmap_values(Global.current_project, false)
	else:
		if Tools.is_placing_tiles():
			var tilemap_cel := Global.current_project.get_current_cel() as CelTileMap
			var tile_size := tilemap_cel.get_tile_size()
			var offset := tilemap_cel.offset % tile_size
			project.selection_offset = Tools.snap_to_rectangular_grid_boundary(
				project.selection_offset, tile_size, offset
			)
			transform_origin = Vector2i(
				Tools.snap_to_rectangular_grid_boundary(transform_origin, tile_size, offset)
			)
		elif Global.snap_to_rectangular_grid_center:
			# Offset the selection so that the center of selection falls above the center of grid.
			project.selection_offset = (
				Tools.snap_to_rectangular_grid_center(
					project.selection_offset, grid_size, grid_offset
				)
				- (clipboard.image.get_size() / 2.0).floor()
			)
			transform_origin = (
				Vector2i(
					Tools.snap_to_rectangular_grid_center(transform_origin, grid_size, grid_offset)
				)
				- Vector2i((clipboard.image.get_size() / 2.0).floor())
			)
		elif Global.snap_to_rectangular_grid_boundary:
			project.selection_offset = Tools.snap_to_rectangular_grid_boundary(
				project.selection_offset, grid_size, grid_offset
			)
			transform_origin = Vector2i(
				Tools.snap_to_rectangular_grid_boundary(transform_origin, grid_size, grid_offset)
			)

	is_pasting = true
	project.selection_map_changed()
	transformation_handles.begin_transform(clipboard.image)
	transformation_handles.preview_transform.origin = transform_origin
	queue_redraw()


func paste_from_clipboard() -> void:
	if not DisplayServer.clipboard_has_image():
		return
	var clipboard_image := DisplayServer.clipboard_get_image()
	if clipboard_image.is_empty() or clipboard_image.is_invisible():
		return
	if transformation_handles.is_transforming():
		transform_content_confirm()
	_paste_target_cels = get_selected_draw_cels()
	if _paste_target_cels.is_empty():
		return
	undo_data = get_undo_data(true)
	clear_selection()
	var project := Global.current_project
	clipboard_image.convert(project.get_image_format())
	var clip_map := SelectionMap.new()
	clip_map.copy_from(
		Image.create(
			clipboard_image.get_width(),
			clipboard_image.get_height(),
			false,
			project.selection_map.get_format()
		)
	)
	clip_map.fill_rect(Rect2i(Vector2i.ZERO, clipboard_image.get_size()), Color(1, 1, 1, 1))
	var max_size := Vector2i(
		maxi(clip_map.get_size().x, project.selection_map.get_size().x),
		maxi(clip_map.get_size().y, project.selection_map.get_size().y)
	)

	project.selection_map.copy_from(clip_map)
	project.selection_map.crop(max_size.x, max_size.y)
	project.selection_map_changed()
	transformation_handles.begin_transform(clipboard_image)
	is_pasting = true
	queue_redraw()


## Deletes the drawing enclosed within the selection's area.
func delete(selected_cels := true) -> void:
	var project := Global.current_project
	if !project.layers[project.current_layer].can_layer_get_drawn():
		return
	if transformation_handles.is_transforming():
		if (
			transformation_handles.transformed_image.is_empty()
			or transformation_handles.transformed_image.is_invisible()
		):
			transform_content_confirm()
		else:
			transformation_handles.reset_transform()
			clear_selection()
			transformation_handles.set_selection(null, Rect2())
			is_pasting = false
			queue_redraw()
			commit_undo("Draw", undo_data)
			return

	var undo_data_tmp := get_undo_data(true)
	var images: Array[ImageExtended]
	var tile_cels: Array[CelTileMap]
	if selected_cels:
		images = _get_selected_draw_images(tile_cels)
	else:
		var current_cel_image := project.get_current_cel().get_image()
		# Avoid type conflict
		if is_instance_valid(current_cel_image) and current_cel_image is ImageExtended:
			images = [current_cel_image]
		if project.get_current_cel() is CelTileMap:
			if Tools.is_placing_tiles():
				images.clear()
				tile_cels.append(project.get_current_cel())

	if project.has_selection:
		var blank := project.new_empty_image()
		var selection_map_copy := project.selection_map.return_cropped_copy(project, project.size)
		var selection_rect := selection_map_copy.get_used_rect()
		for image in images:
			image.blit_rect_mask(blank, selection_map_copy, selection_rect, selection_rect.position)
			image.convert_rgb_to_indexed()
		var selection = project.selection_map.get_used_rect()
		for tile_cel: CelTileMap in tile_cels:
			var row := 0
			for y in range(
				selection.position.y, selection.end.y, floori(tile_cel.tile_size.y / 2.0)
			):
				var current_offset := floori(tile_cel.tile_size.x / 2.0) if row % 2 != 0 else 0
				for x in range(
					selection.position.x + current_offset, selection.end.x, tile_cel.tile_size.x
				):
					var point = Vector2i(x, y) + Vector2i((Vector2(tile_cel.tile_size) / 2).ceil())
					if selection.has_point(point):
						var tile_position := tile_cel.get_cell_position(point)
						var cell := tile_cel.get_cell_at(tile_position)
						tile_cel.set_index(cell, 0)
						tile_cel.update_tilemap()
				row += 1
	else:
		for image in images:
			image.fill(0)
			image.convert_rgb_to_indexed()
	clear_selection()
	commit_undo("Draw", undo_data_tmp)


## Makes a project brush out of the current selection's content.
func new_brush() -> void:
	var brush := get_enclosed_image()
	if brush and !brush.is_invisible():
		var brush_used: Image = brush.get_region(brush.get_used_rect())
		Global.current_project.brushes.append(brush_used)
		Brushes.add_project_brush(brush_used)


## Select the entire region of current cel.
func select_all() -> void:
	var undo_data_tmp := get_undo_data(false)
	clear_selection()
	var full_rect := Rect2i(Vector2i.ZERO, Global.current_project.size)
	select_rect(full_rect)
	commit_undo("Select", undo_data_tmp)


## Inverts the selection.
func invert() -> void:
	transform_content_confirm()
	var project := Global.current_project
	var undo_data_tmp := get_undo_data(false)
	project.selection_map.crop(project.size.x, project.size.y)
	project.selection_map.invert()
	project.selection_map_changed()
	project.selection_offset = Vector2.ZERO
	commit_undo("Select", undo_data_tmp)


## Clears the selection.
func clear_selection(use_undo := false) -> void:
	var project := Global.current_project
	if not project.has_selection:
		return
	transform_content_confirm()
	var undo_data_tmp := get_undo_data(false)
	project.selection_map.crop(project.size.x, project.size.y)
	project.selection_map.clear()
	project.selection_offset = Vector2.ZERO
	queue_redraw()
	if use_undo:
		commit_undo("Clear Selection", undo_data_tmp)


func reselect() -> void:
	var project := Global.current_project
	if project.has_selection or project.prev_selection_map.is_invisible():
		return
	var undo_data_tmp := get_undo_data(false)
	project.selection_map.copy_from(project.prev_selection_map)
	commit_undo("Reselect", undo_data_tmp)


func select_cel_rect() -> void:
	transform_content_confirm()
	var project := Global.current_project
	var undo_data_tmp := get_undo_data(false)
	project.selection_map.crop(project.size.x, project.size.y)
	project.selection_map.clear()
	var current_cel := project.get_current_cel()
	var cel_image: Image
	if current_cel is GroupCel:
		var group_layer := project.layers[project.current_layer] as GroupLayer
		cel_image = group_layer.blend_children(project.frames[project.current_frame])
	else:
		cel_image = current_cel.get_image()
	project.selection_map.select_rect(cel_image.get_used_rect())
	project.selection_map_changed()
	project.selection_offset = Vector2.ZERO
	commit_undo("Select", undo_data_tmp)


func select_cel_pixels(layer: BaseLayer, frame: Frame) -> void:
	transform_content_confirm()
	var project := Global.current_project
	var undo_data_tmp := get_undo_data(false)
	project.selection_map.crop(project.size.x, project.size.y)
	project.selection_map.clear()
	var current_cel := frame.cels[layer.index]
	var cel_image: Image
	if current_cel is GroupCel:
		cel_image = (layer as GroupLayer).blend_children(frame)
	else:
		cel_image = current_cel.get_image()
	var selection_format := project.selection_map.get_format()
	project.selection_map.copy_from(cel_image)
	project.selection_map.convert(selection_format)
	project.selection_map_changed()
	project.selection_offset = Vector2.ZERO
	commit_undo("Select", undo_data_tmp)


func _project_switched() -> void:
	marching_ants_outline.offset = Global.current_project.selection_offset
	_update_marching_ants()
	queue_redraw()


## The selection toolbar is a canvas feature shared by UI1, UI3 and UI4.
## Editor UI nodes may be bound after Selection._ready() in any profile.
## Retry until the common root is ready rather than losing the toolbar forever.
func _ensure_selection_context_menu() -> void:
	if (
		is_instance_valid(_selection_context_menu)
		and not _selection_context_menu.is_queued_for_deletion()
	):
		return
	if not is_inside_tree() or not is_instance_valid(Global.control):
		return
	if not is_instance_valid(Global.main_viewport):
		return
	_selection_context_menu = null
	_create_selection_context_menu()


## The menu lives above the embedded canvas in the shared editor UI, not in
## a profile-specific panel or SubViewportContainer.
func _create_selection_context_menu() -> void:
	if not is_instance_valid(Global.control) or not is_instance_valid(Global.main_viewport):
		return
	# Re-creating the overlay must not leave references to old, freed buttons.
	_selection_action_buttons.clear()
	_selection_confirm_button = null
	_selection_cancel_button = null
	_selection_context_menu = PanelContainer.new()
	_selection_context_menu.name = &"SelectionContextMenu"
	_selection_context_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_selection_context_menu.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 0.96)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(5)
	_selection_context_menu.add_theme_stylebox_override(&"panel", style)
	# _ready() is running inside the embedded viewport, so defer adding
	# a sibling under the editor root until its child setup has finished.
	Global.control.add_child.call_deferred(_selection_context_menu)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override(&"separation", 4)
	_selection_context_menu.add_child(actions)
	_add_selection_menu_button(actions, "Copy", Callable(self, "copy"))
	_add_selection_menu_button(actions, "Cut", Callable(self, "cut"))
	_add_selection_menu_button(actions, "Paste", Callable(self, "paste"))
	_add_selection_menu_button(actions, "New Layer", Callable(self, "create_layer_from_selection"))
	_selection_confirm_button = _add_selection_menu_button(
		actions, "Confirm", Callable(self, "transform_content_confirm")
	)
	_selection_cancel_button = _add_selection_menu_button(
		actions, "Cancel", Callable(self, "transform_content_cancel")
	)


func _add_selection_menu_button(parent: HBoxContainer, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = tr(title)
	button.tooltip_text = tr(title)
	button.custom_minimum_size = Vector2(54, 44)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(action)
	parent.add_child(button)
	if title != "Confirm" and title != "Cancel":
		_selection_action_buttons.append(button)
	return button


func _update_selection_context_menu() -> void:
	if (
		not is_instance_valid(_selection_context_menu)
		or not _selection_context_menu.is_inside_tree()
	):
		return
	if (
		not is_instance_valid(Global.current_project)
		or not is_instance_valid(Global.main_viewport)
		or not Global.main_viewport.is_visible_in_tree()
	):
		_selection_context_menu.hide()
		return
	var project := Global.current_project
	if not project.has_selection or not Tools.selection_tool_has_selection():
		_selection_context_menu.hide()
		return
	var pending := is_pasting
	var can_edit := (
		project.current_layer >= 0
		and project.current_layer < project.layers.size()
		and project.layers[project.current_layer].can_layer_get_drawn()
		and project.get_current_cel() is PixelCel
	)
	for button in _selection_action_buttons:
		button.visible = not pending
		button.disabled = not can_edit and button.text != tr("Paste")
	_selection_action_buttons[2].disabled = not SelectionNode.has_app_clipboard()
	_selection_confirm_button.visible = pending
	_selection_cancel_button.visible = pending

	# The four corners give the correct bottom-right anchor even after rotation.
	var anchor := Vector2(project.selection_map.get_selection_rect(project).end)
	if transformation_handles.is_transforming():
		var map := transformation_handles.transformed_selection_map
		if is_instance_valid(map):
			var selection_size := Vector2(map.get_size())
			var transform := transformation_handles.preview_transform
			anchor = transform * Vector2.ZERO
			for corner in [
				Vector2(selection_size.x, 0.0), Vector2(0.0, selection_size.y), selection_size
			]:
				var transformed: Vector2 = transform * corner
				anchor.x = maxf(anchor.x, transformed.x)
				anchor.y = maxf(anchor.y, transformed.y)
	# Canvas coordinates are in the embedded SubViewport. Convert through
	# its container into the root GUI before positioning the floating toolbar.
	var canvas_to_viewport := canvas.get_global_transform_with_canvas()
	var viewport_to_screen := Global.main_viewport.get_global_transform_with_canvas()
	var screen_to_root := Global.control.get_global_transform_with_canvas().affine_inverse()
	var viewport_to_root := screen_to_root * viewport_to_screen
	var root_anchor := viewport_to_root * (canvas_to_viewport * anchor)
	var top_left := viewport_to_root * Vector2.ZERO
	var bottom_right := viewport_to_root * Global.main_viewport.size
	var area := Rect2(top_left, bottom_right - top_left).abs()
	var menu_size := _selection_context_menu.get_combined_minimum_size()
	var point := Vector2(root_anchor.x - menu_size.x, root_anchor.y + 12.0)
	if point.y + menu_size.y > area.end.y - 8.0:
		point.y = root_anchor.y - menu_size.y - 12.0
	point.x = clampf(
		point.x, area.position.x + 8.0, maxf(area.position.x + 8.0, area.end.x - menu_size.x - 8.0)
	)
	point.y = clampf(
		point.y, area.position.y + 8.0, maxf(area.position.y + 8.0, area.end.y - menu_size.y - 8.0)
	)
	_selection_context_menu.position = point
	_selection_context_menu.show()


## Used by the iOS input adapter to leave selection-menu touches to GUI buttons.
func is_selection_menu_point(screen_point: Vector2) -> bool:
	return (
		is_instance_valid(_selection_context_menu)
		and _selection_context_menu.visible
		and _selection_context_menu.is_visible_in_tree()
		and (_selection_context_menu.get_global_rect().has_point(
			Global.main_viewport.get_global_transform_with_canvas() * screen_point
		))
	)


## Create a real pixel layer containing only the selected pixels. The source
## layer is not modified, and the normal layer command owns undo/redo.
func create_layer_from_selection() -> void:
	var project := Global.current_project
	if is_pasting or not project.has_selection:
		return
	if not project.get_current_cel() is PixelCel:
		return
	if not project.layers[project.current_layer].can_layer_get_drawn():
		return
	if transformation_handles.is_transforming():
		transform_content_confirm()
	var source_image := project.get_current_cel().get_image()
	var selected_image := get_selected_image(source_image)
	if selected_image.is_empty():
		return
	var selection_rect := (
		project.selection_map.return_cropped_copy(project, project.size).get_used_rect()
	)
	var source_frame := project.current_frame
	Global.animation_timeline.add_layer(PixelLayer.new(project), project)
	var target := project.frames[source_frame].cels[project.current_layer] as PixelCel
	if not is_instance_valid(target):
		return
	var target_image := target.get_image()
	target_image.blit_rect_mask(
		selected_image,
		selected_image,
		Rect2i(Vector2i.ZERO, selected_image.get_size()),
		selection_rect.position
	)
	target_image.convert_rgb_to_indexed()
	target.update_texture()
	canvas.queue_redraw()


static func get_selected_image(cel_image: Image) -> Image:
	var project := Global.current_project
	var selection_map_copy := project.selection_map.return_cropped_copy(project, project.size)
	var selection_rect := selection_map_copy.get_used_rect()
	var image := Image.create(
		selection_rect.size.x, selection_rect.size.y, false, project.get_image_format()
	)
	image.blit_rect_mask(cel_image, selection_map_copy, selection_rect, Vector2i.ZERO)
	return image
