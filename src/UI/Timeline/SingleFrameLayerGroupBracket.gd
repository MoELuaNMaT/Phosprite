class_name SingleFrameLayerGroupBracket
extends Control

const BRACKET_HEIGHT := 28.0

var group_layer: GroupLayer

@onready var line := %BracketLine as Line2D
@onready var label := %FolderName as Label


func setup(layer: GroupLayer) -> void:
	_disconnect_layer()
	group_layer = layer
	if not is_instance_valid(group_layer):
		return
	label.text = group_layer.name
	group_layer.name_changed.connect(_on_name_changed)
	group_layer.ui_color_changed.connect(_update_color)
	_update_color()


func _exit_tree() -> void:
	_disconnect_layer()


func _disconnect_layer() -> void:
	if not is_instance_valid(group_layer):
		group_layer = null
		return
	if group_layer.name_changed.is_connected(_on_name_changed):
		group_layer.name_changed.disconnect(_on_name_changed)
	if group_layer.ui_color_changed.is_connected(_update_color):
		group_layer.ui_color_changed.disconnect(_update_color)
	group_layer = null


func set_span(left: float, width: float, lane: int) -> void:
	position = Vector2(left, lane * BRACKET_HEIGHT)
	size = Vector2(maxf(width, 1.0), BRACKET_HEIGHT)
	custom_minimum_size = size
	var right := size.x
	line.points = PackedVector2Array([
		Vector2(0.0, BRACKET_HEIGHT - 1.0),
		Vector2(0.0, 4.0),
		Vector2(right, 4.0),
		Vector2(right, BRACKET_HEIGHT - 1.0),
	])


func _on_name_changed() -> void:
	if is_instance_valid(group_layer):
		label.text = group_layer.name


func _update_color() -> void:
	if not is_instance_valid(line) or not is_instance_valid(label):
		return
	var color := get_theme_color(&"font_color", &"Label")
	if is_instance_valid(group_layer) and not is_zero_approx(group_layer.ui_color.a):
		color = group_layer.ui_color
	line.default_color = color
	label.modulate = color
