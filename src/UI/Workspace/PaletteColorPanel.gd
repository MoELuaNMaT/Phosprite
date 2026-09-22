class_name PaletteColorPanel
extends VSplitContainer

const TOUCH_SPLITTER_SLOP := 14.0
const COMPACT_PALETTE_BOTTOM_PADDING := 4.0

var _color_options_expanded := false
var _normal_palette_height := -1.0
var _expanded_manual_override := false
var _applying_auto_split := false
var _touch_drag_index := -1
var _touch_drag_origin_y := 0.0
var _touch_drag_start_offset := 0

@onready var palettes := $Palettes as PalettePanel
@onready var color_picker_panel := $"Color Picker"


func _ready() -> void:
	dragged.connect(_on_split_dragged)
	resized.connect(_on_panel_resized)
	if color_picker_panel.has_signal(&"color_options_toggled"):
		color_picker_panel.connect(&"color_options_toggled", _on_color_options_toggled)
	if not Palettes.palette_selected.is_connected(_on_palette_selected):
		Palettes.palette_selected.connect(_on_palette_selected)
	if color_picker_panel.has_method(&"is_color_options_expanded"):
		_color_options_expanded = bool(color_picker_panel.call(&"is_color_options_expanded"))
	_normal_palette_height = palettes.size.y
	if _color_options_expanded:
		call_deferred("_apply_compact_palette_split")
	else:
		call_deferred("_capture_normal_palette_height")
	queue_redraw()


func _exit_tree() -> void:
	if Palettes.palette_selected.is_connected(_on_palette_selected):
		Palettes.palette_selected.disconnect(_on_palette_selected)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		_handle_split_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_split_drag(event as InputEventScreenDrag)


func _capture_normal_palette_height() -> void:
	if not _color_options_expanded and is_instance_valid(palettes):
		_normal_palette_height = palettes.size.y


func _on_color_options_toggled(expanded: bool) -> void:
	_color_options_expanded = expanded
	_expanded_manual_override = false
	if expanded:
		_normal_palette_height = palettes.size.y
		call_deferred("_apply_compact_palette_split")
	else:
		call_deferred("_restore_normal_palette_split")


func _on_palette_selected(_palette_name: String) -> void:
	if _color_options_expanded and not _expanded_manual_override:
		call_deferred("_apply_compact_palette_split")


func _on_panel_resized() -> void:
	queue_redraw()
	if _applying_auto_split:
		return
	if _color_options_expanded and not _expanded_manual_override:
		call_deferred("_apply_compact_palette_split")


func _on_split_dragged(_offset: int) -> void:
	queue_redraw()
	if _applying_auto_split:
		return
	if _color_options_expanded:
		_expanded_manual_override = true
	else:
		_normal_palette_height = palettes.size.y


func _apply_compact_palette_split() -> void:
	if not _color_options_expanded or _expanded_manual_override or not is_instance_valid(palettes):
		return
	var target_height := palettes.get_used_color_content_height() + COMPACT_PALETTE_BOTTOM_PADDING
	_set_palette_height(target_height)


func _restore_normal_palette_split() -> void:
	if _normal_palette_height < 0.0 or not is_instance_valid(palettes):
		return
	_set_palette_height(_normal_palette_height)


func _set_palette_height(target_height: float) -> void:
	var delta := target_height - palettes.size.y
	if absf(delta) < 0.5:
		return
	_applying_auto_split = true
	split_offset += roundi(delta)
	_applying_auto_split = false


func _handle_split_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _touch_drag_index != -1 or not _splitter_hit_test(event.position):
			return
		_touch_drag_index = event.index
		_touch_drag_origin_y = event.position.y
		_touch_drag_start_offset = split_offset
		get_viewport().set_input_as_handled()
		return
	if event.index != _touch_drag_index:
		return
	_touch_drag_index = -1
	get_viewport().set_input_as_handled()


func _handle_split_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_drag_index:
		return
	var delta_y := event.position.y - _touch_drag_origin_y
	split_offset = _touch_drag_start_offset + roundi(delta_y)
	queue_redraw()
	if _color_options_expanded:
		_expanded_manual_override = true
	else:
		_normal_palette_height = palettes.size.y
	get_viewport().set_input_as_handled()


func _splitter_hit_test(viewport_position: Vector2) -> bool:
	var rect := get_global_rect()
	if viewport_position.x < rect.position.x or viewport_position.x > rect.end.x:
		return false
	var splitter_y := palettes.get_global_rect().end.y
	return absf(viewport_position.y - splitter_y) <= TOUCH_SPLITTER_SLOP


func _draw() -> void:
	if not is_instance_valid(palettes):
		return
	var y := palettes.size.y
	var line_color := get_theme_color(&"font_color", &"Label")
	line_color.a = 0.22
	draw_line(Vector2(0.0, y), Vector2(size.x, y), line_color, 1.0)
