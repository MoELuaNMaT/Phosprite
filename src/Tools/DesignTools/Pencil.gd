extends BaseDrawTool

const DITHER_SIZES := [2, 4, 8, 16]
const AUTO_OUTLINE_SHADER := preload("res://src/Shaders/Effects/AutoOutline.gdshader")
const AUTO_OUTLINE_NAME := "Auto Outline"

var _last_position := Vector2i(Vector2.INF)
var _changed := false
var _dither_enabled := false
var _dither_size := 4
var _dither_coverage := 50
var _auto_outline_color := Color.BLACK
var _auto_outline_width := 1
var _auto_outline_diagonals := false
var _syncing_auto_outline := false
var _observed_auto_outline_layer: PixelLayer


class PencilOp:
	extends Drawer.ColorOp
	var changed := false

	func process(src: Color, dst: Color) -> Color:
		changed = true
		src.a *= strength
		return dst.blend(src)


func _init() -> void:
	_drawer.color_op = PencilOp.new()


func _ready() -> void:
	super._ready()
	var pattern: OptionButton = $DitherSettings/PatternRow/Pattern
	if pattern.item_count == 0:
		for size in DITHER_SIZES:
			pattern.add_item("%d × %d" % [size, size])
	var outline_shape := $AutoOutlineSettings/ShapeRow/Shape as OptionButton
	if outline_shape.item_count == 0:
		outline_shape.add_item("4-way")
		outline_shape.add_item("8-way")
	update_config()
	if not Tools.draw_options_changed.is_connected(_sync_global_draw_options):
		Tools.draw_options_changed.connect(_sync_global_draw_options)
	_sync_global_draw_options()
	Global.cel_switched.connect(_sync_auto_outline_ui)
	Global.project_switched.connect(_sync_auto_outline_ui)
	_sync_auto_outline_ui()


func _exit_tree() -> void:
	if Tools.draw_options_changed.is_connected(_sync_global_draw_options):
		Tools.draw_options_changed.disconnect(_sync_global_draw_options)
	if Global.cel_switched.is_connected(_sync_auto_outline_ui):
		Global.cel_switched.disconnect(_sync_auto_outline_ui)
	if Global.project_switched.is_connected(_sync_auto_outline_ui):
		Global.project_switched.disconnect(_sync_auto_outline_ui)
	if is_instance_valid(_observed_auto_outline_layer):
		var cb := Callable(self, "_schedule_auto_outline_ui_sync")
		if _observed_auto_outline_layer.effects_added_removed.is_connected(cb):
			_observed_auto_outline_layer.effects_added_removed.disconnect(cb)
	super._exit_tree()


func _global_draw_options() -> Node:
	return get_tree().get_first_node_in_group(&"GlobalDrawOptions")


func _sync_global_draw_options() -> void:
	$PixelPerfect.set_pressed_no_signal(Tools.pixel_perfect)
	$TransparentOnly.set_pressed_no_signal(Tools.alpha_locked)


func _on_pixel_perfect_toggled(enabled: bool) -> void:
	var options := _global_draw_options()
	if is_instance_valid(options):
		var source := options.get("pixel_perfect") as BaseButton
		if is_instance_valid(source):
			source.button_pressed = enabled
			return
	Tools.pixel_perfect = enabled
	Global.config_cache.set_value("tools", "pixel_perfect", enabled)
	Tools.draw_options_changed.emit()


func _on_transparent_only_toggled(enabled: bool) -> void:
	var options := _global_draw_options()
	if is_instance_valid(options):
		var source := options.get("alpha_lock") as BaseButton
		if is_instance_valid(source):
			source.button_pressed = enabled
			return
	Tools.alpha_locked = enabled
	Global.config_cache.set_value("tools", "alpha_locked", enabled)
	Tools.draw_options_changed.emit()


func _on_pressure_settings_pressed() -> void:
	var options := _global_draw_options()
	if is_instance_valid(options):
		options.call(&"show_dynamics_at", $PressureSettings)


func _on_Opacity_value_changed(value: float) -> void:
	_strength = clampf(value / 100.0, 0.0, 1.0)
	update_config()
	save_config()


func _on_Dither_toggled(button_pressed: bool) -> void:
	_dither_enabled = button_pressed
	update_config()
	save_config()


func _on_DitherPattern_item_selected(index: int) -> void:
	if index < 0 or index >= DITHER_SIZES.size():
		return
	_dither_size = DITHER_SIZES[index]
	save_config()


func _on_DitherCoverage_value_changed(value: float) -> void:
	_dither_coverage = clampi(roundi(value), 1, 100)
	save_config()


## Auto Outline is a persisted layer effect, not a set of pixels added at each dab.
## This keeps the edge correct when the source is erased, moved or repainted.
func _current_outline_layer() -> PixelLayer:
	var project := Global.current_project
	if not is_instance_valid(project):
		return null
	if project.current_layer < 0 or project.current_layer >= project.layers.size():
		return null
	return project.layers[project.current_layer] as PixelLayer


func _find_auto_outline(layer: PixelLayer) -> LayerEffect:
	if not is_instance_valid(layer):
		return null
	for effect in layer.effects:
		if effect.name == AUTO_OUTLINE_NAME and effect.shader_or_include == AUTO_OUTLINE_SHADER:
			return effect
	return null


func _schedule_auto_outline_ui_sync() -> void:
	# Undo methods can run in reverse order. Read the final effect state afterward.
	_sync_auto_outline_ui.call_deferred()


func _sync_auto_outline_ui() -> void:
	if not is_inside_tree():
		return
	_syncing_auto_outline = true
	var layer := _current_outline_layer()
	if _observed_auto_outline_layer != layer:
		var callback := Callable(self, "_schedule_auto_outline_ui_sync")
		if is_instance_valid(_observed_auto_outline_layer):
			if _observed_auto_outline_layer.effects_added_removed.is_connected(callback):
				_observed_auto_outline_layer.effects_added_removed.disconnect(callback)
		_observed_auto_outline_layer = layer
		if is_instance_valid(layer):
			if not layer.effects_added_removed.is_connected(callback):
				layer.effects_added_removed.connect(callback)
	var effect := _find_auto_outline(layer)
	var enabled := is_instance_valid(effect) and effect.enabled
	$AutoOutline.disabled = not is_instance_valid(layer)
	$AutoOutline.set_pressed_no_signal(enabled)
	$AutoOutlineSettings.visible = enabled
	if is_instance_valid(effect):
		_auto_outline_color = effect.params.get("outline_color", _auto_outline_color)
		_auto_outline_width = clampi(int(effect.params.get("outline_width", 1)), 1, 4)
		_auto_outline_diagonals = bool(effect.params.get("include_diagonals", false))
	$AutoOutlineSettings/ColorRow/Color.color = _auto_outline_color
	$AutoOutlineSettings/Thickness.value = _auto_outline_width
	$AutoOutlineSettings/ShapeRow/Shape.select(1 if _auto_outline_diagonals else 0)
	_syncing_auto_outline = false


func _outline_params() -> Dictionary[String, Variant]:
	return {
		"outline_color": _auto_outline_color,
		"outline_width": _auto_outline_width,
		"include_diagonals": _auto_outline_diagonals,
	}


func _redraw_outline_layer(layer: PixelLayer) -> void:
	if not is_instance_valid(layer) or Global.current_project != layer.project:
		return
	if is_instance_valid(Global.canvas):
		Global.canvas.update_all_layers = true
		Global.canvas.queue_redraw()


func _on_auto_outline_toggled(enabled: bool) -> void:
	if _syncing_auto_outline:
		return
	var layer := _current_outline_layer()
	if not is_instance_valid(layer):
		_sync_auto_outline_ui()
		return
	var project := Global.current_project
	var effect := _find_auto_outline(layer)
	if not is_instance_valid(effect):
		if not enabled:
			return
		effect = LayerEffect.new(
			AUTO_OUTLINE_NAME, AUTO_OUTLINE_SHADER, "Procedural", _outline_params()
		)
		effect.layer = layer
		project.undo_redo.create_action("Add Auto Outline")
		project.undo_redo.add_do_method(func(): layer.effects.append(effect))
		project.undo_redo.add_undo_method(func(): layer.effects.erase(effect))
	else:
		if effect.enabled == enabled:
			_sync_auto_outline_ui()
			return
		project.undo_redo.create_action("Toggle Auto Outline")
		project.undo_redo.add_do_property(effect, "enabled", enabled)
		project.undo_redo.add_undo_property(effect, "enabled", not enabled)
	project.undo_redo.add_do_method(layer.emit_effects_added_removed)
	project.undo_redo.add_do_method(_redraw_outline_layer.bind(layer))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(layer.emit_effects_added_removed)
	project.undo_redo.add_undo_method(_redraw_outline_layer.bind(layer))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()
	_sync_auto_outline_ui()


func _update_auto_outline_settings() -> void:
	if _syncing_auto_outline:
		return
	var layer := _current_outline_layer()
	var effect := _find_auto_outline(layer)
	if is_instance_valid(effect):
		var params := _outline_params()
		for key in params:
			effect.params[key] = params[key]
		_redraw_outline_layer(layer)
		Global.current_project.has_changed = true
	save_config()


func _on_auto_outline_color_changed(color: Color) -> void:
	_auto_outline_color = color
	_update_auto_outline_settings()


func _on_auto_outline_width_changed(value: float) -> void:
	_auto_outline_width = clampi(roundi(value), 1, 4)
	_update_auto_outline_settings()


func _on_auto_outline_shape_selected(index: int) -> void:
	_auto_outline_diagonals = index == 1
	_update_auto_outline_settings()


func get_config() -> Dictionary:
	var config := super.get_config()
	config.erase("brush_density")
	config.erase("overwrite")
	config.erase("fill_inside")
	config.erase("spacing_mode")
	config.erase("spacing")
	config["strength"] = _strength
	config["dither_enabled"] = _dither_enabled
	config["dither_size"] = _dither_size
	config["dither_coverage"] = _dither_coverage
	config["auto_outline_color"] = _auto_outline_color
	config["auto_outline_width"] = _auto_outline_width
	config["auto_outline_diagonals"] = _auto_outline_diagonals
	return config


func set_config(config: Dictionary) -> void:
	super.set_config(config)
	_brush_density = 100
	_spacing_mode = false
	_spacing = Vector2i.ZERO
	_strength = clampf(float(config.get("strength", _strength)), 0.0, 1.0)
	_dither_enabled = bool(config.get("dither_enabled", _dither_enabled))
	var configured_dither_size := int(config.get("dither_size", _dither_size))
	_dither_size = configured_dither_size if configured_dither_size in DITHER_SIZES else 4
	_dither_coverage = clampi(int(config.get("dither_coverage", _dither_coverage)), 1, 100)
	var configured_outline_color = config.get("auto_outline_color", _auto_outline_color)
	if configured_outline_color is Color:
		_auto_outline_color = configured_outline_color
	_auto_outline_width = clampi(int(config.get("auto_outline_width", _auto_outline_width)), 1, 4)
	_auto_outline_diagonals = bool(config.get("auto_outline_diagonals", _auto_outline_diagonals))


func update_config() -> void:
	super.update_config()
	_sync_global_draw_options()
	$DensityValueSlider.visible = false
	$Opacity.value = _strength * 100.0
	$Dither.button_pressed = _dither_enabled
	$DitherSettings.visible = _dither_enabled
	var dither_index := DITHER_SIZES.find(_dither_size)
	if dither_index >= 0 and $DitherSettings/PatternRow/Pattern.item_count > dither_index:
		$DitherSettings/PatternRow/Pattern.select(dither_index)
	$DitherSettings/Coverage.value = _dither_coverage
	_sync_auto_outline_ui()


func update_brush() -> void:
	super.update_brush()
	$DensityValueSlider.visible = false


func draw_start(pos: Vector2i) -> void:
	_spacing_mode = false
	pos = snap_position(pos)
	super.draw_start(pos)

	Global.transform_content_confirmed.emit()
	prepare_undo()
	update_mask(tool_slot.color.a >= 1.0 and is_equal_approx(_strength, 1.0))
	_changed = false
	_drawer.color_op.changed = false
	_drawer.reset()

	_draw_line = Input.is_action_pressed("draw_create_line")
	var project := Global.current_project
	var draw_pos := pos
	if project.get_current_cel() is Cel3D:
		var layer := project.layers[project.current_layer] as Layer3D
		draw_pos = draw_on_3d_object(pos, layer)
		if draw_pos == Vector2i(Vector2.INF):
			return
	if _draw_line:
		if Global.mirror_view:
			pos.x = (Global.current_project.size.x - 1) - pos.x
		_line_start = pos
		_line_end = pos
		update_line_polylines(_line_start, _line_end)
	else:
		draw_tool(draw_pos)
		_last_position = pos
		Global.canvas.sprite_changed_this_frame = true
	cursor_text = ""


func draw_move(pos_i: Vector2i) -> void:
	var pos := _get_stabilized_position(pos_i)
	pos = snap_position(pos)
	super.draw_move(pos)

	if _draw_line:
		if Global.mirror_view:
			pos.x = (Global.current_project.size.x - 1) - pos.x
		var d := _line_angle_constraint(_line_start, pos)
		_line_end = d.position
		cursor_text = d.text
		update_line_polylines(_line_start, _line_end)
	else:
		if _last_position == Vector2i(Vector2.INF):
			return
		draw_fill_gap(_last_position, pos)
		_last_position = pos
		cursor_text = ""
		Global.canvas.sprite_changed_this_frame = true


func draw_end(pos: Vector2i) -> void:
	pos = snap_position(pos)

	if _draw_line:
		if Global.mirror_view:
			_line_start.x = (Global.current_project.size.x - 1) - _line_start.x
			_line_end.x = (Global.current_project.size.x - 1) - _line_end.x
		draw_tool(_line_start)
		draw_fill_gap(_line_start, _line_end)
		_draw_line = false

	commit_undo()
	super.draw_end(pos)
	cursor_text = ""
	update_random_image()
	_spacing_mode = false


func _set_pixel_no_cache(pos: Vector2i, ignore_mirroring := false) -> void:
	if _dither_enabled and not Tools.is_placing_tiles() and not _dither_allows_pixel(pos):
		return
	super._set_pixel_no_cache(pos, ignore_mirroring)


func _dither_allows_pixel(pos: Vector2i) -> bool:
	if not _dither_enabled or _dither_coverage >= 100:
		return true
	var size := _dither_size
	var x := ((pos.x % size) + size) % size
	var y := ((pos.y % size) + size) % size
	var threshold := 0
	var multiplier := 1
	var current_size := size
	while current_size > 1:
		var half := current_size >> 1
		var quadrant_x := 1 if x >= half else 0
		var quadrant_y := 1 if y >= half else 0
		var quadrant := 0
		if quadrant_y == 0:
			quadrant = 2 if quadrant_x == 1 else 0
		else:
			quadrant = 1 if quadrant_x == 1 else 3
		threshold += quadrant * multiplier
		multiplier *= 4
		x %= half
		y %= half
		current_size = half
	var cell_count := size * size
	var visible_cells := clampi(roundi(cell_count * _dither_coverage / 100.0), 1, cell_count)
	return threshold < visible_cells


func _apply_dither_to_brush_image(brush_image: Image, src_rect: Rect2i, dst: Vector2i) -> Image:
	if not _dither_enabled or _dither_coverage >= 100:
		return brush_image
	var filtered := Image.new()
	filtered.copy_from(brush_image)
	var end_x := src_rect.position.x + src_rect.size.x
	var end_y := src_rect.position.y + src_rect.size.y
	for y in range(src_rect.position.y, end_y):
		for x in range(src_rect.position.x, end_x):
			var canvas_pos := dst + Vector2i(x - src_rect.position.x, y - src_rect.position.y)
			if not _dither_allows_pixel(canvas_pos):
				filtered.set_pixel(x, y, Color.TRANSPARENT)
	return filtered


func _draw_brush_image(brush_image: Image, src_rect: Rect2i, dst: Vector2i) -> void:
	_changed = true
	var effective_brush := brush_image
	var opacity := clampf(_drawer.color_op.strength, 0.0, 1.0)
	if not is_equal_approx(opacity, 1.0):
		effective_brush = brush_image.duplicate()
		for y in effective_brush.get_height():
			for x in effective_brush.get_width():
				var color := effective_brush.get_pixel(x, y)
				color.a *= opacity
				effective_brush.set_pixel(x, y, color)
	effective_brush = _apply_dither_to_brush_image(effective_brush, src_rect, dst)

	var images := _get_selected_draw_images()
	for draw_image in images:
		if Tools.alpha_locked:
			var mask := draw_image.get_region(Rect2i(dst, effective_brush.get_size()))
			draw_image.blend_rect_mask(effective_brush, mask, src_rect, dst)
		else:
			draw_image.blend_rect(effective_brush, src_rect, dst)
		draw_image.convert_rgb_to_indexed()
	update_materials(images)
