extends SubViewportContainer

const CanvasVisualPolicy := preload("res://src/UI/Canvas/CanvasVisualPolicy.gd")

@export var camera_path: NodePath

var _canvas_backdrop: ColorRect

@onready var camera := get_node(camera_path) as CanvasCamera


func _ready() -> void:
	material = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_install_canvas_backdrop()
	if not Themes.theme_switched.is_connected(_refresh_canvas_backdrop):
		Themes.theme_switched.connect(_refresh_canvas_backdrop)


func _install_canvas_backdrop() -> void:
	var viewport := camera.get_viewport()
	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.name = &"CanvasBackdropLayer"
	backdrop_layer.layer = -100
	viewport.add_child(backdrop_layer)

	_canvas_backdrop = ColorRect.new()
	_canvas_backdrop.name = &"CanvasBackdrop"
	_canvas_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop_layer.add_child(_canvas_backdrop)
	_canvas_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_refresh_canvas_backdrop()


func _refresh_canvas_backdrop() -> void:
	var source_theme: Theme = null
	if is_instance_valid(Global.control):
		source_theme = Global.control.theme
	_canvas_backdrop.color = CanvasVisualPolicy.resolve_backdrop_color(source_theme)


func _on_ViewportContainer_mouse_entered() -> void:
	camera.set_process_input(true)
	Global.control.left_cursor.visible = Global.show_left_tool_icon
	Global.control.right_cursor.visible = Global.show_right_tool_icon
	if Global.single_tool_mode:
		Global.control.right_cursor.visible = false
	if Global.cross_cursor:
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)


func _on_ViewportContainer_mouse_exited() -> void:
	camera.set_process_input(false)
	camera.drag = false
	Global.control.left_cursor.visible = false
	Global.control.right_cursor.visible = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
