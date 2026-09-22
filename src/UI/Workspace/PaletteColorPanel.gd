class_name PaletteColorPanel
extends VSplitContainer

const COMPACT_PALETTE_BOTTOM_PADDING := 4.0

var _color_options_expanded := false
var _normal_palette_height := -1.0
var _expanded_manual_override := false
var _applying_auto_split := false

@onready var palettes := $Palettes as PalettePanel
@onready var color_picker_panel := $"Color Picker"


func _ready() -> void:
	dragged.connect(_on_split_dragged)
	drag_ended.connect(_on_split_drag_ended)
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


func _on_split_drag_ended() -> void:
	if not _color_options_expanded:
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
	var offsets := split_offsets
	if offsets.is_empty():
		offsets = PackedInt32Array([0])
	offsets[0] += roundi(delta)
	_applying_auto_split = true
	split_offsets = offsets
	clamp_split_offset()
	_applying_auto_split = false
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(palettes):
		return
	var y := palettes.size.y
	var line_color := get_theme_color(&"font_color", &"Label")
	line_color.a = 0.22
	draw_line(Vector2(0.0, y), Vector2(size.x, y), line_color, 1.0)
