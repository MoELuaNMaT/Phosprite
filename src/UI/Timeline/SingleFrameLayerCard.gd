class_name SingleFrameLayerCard
extends Button

var layer_index := -1
var frame_index := -1
var _layer: BaseLayer
var _cel: BaseCel

@onready var preview_texture := %PreviewTexture as TextureRect
@onready var layer_name_label := %LayerName as Label


func _ready() -> void:
	toggle_mode = true
	pressed.connect(_on_pressed)
	if not Global.cel_switched.is_connected(_sync_selected):
		Global.cel_switched.connect(_sync_selected)


func _exit_tree() -> void:
	_disconnect_bound_data()
	if Global.cel_switched.is_connected(_sync_selected):
		Global.cel_switched.disconnect(_sync_selected)


func setup(new_layer_index: int, new_frame_index: int) -> void:
	_disconnect_bound_data()
	layer_index = new_layer_index
	frame_index = new_frame_index
	var project := Global.current_project
	if (
		project == null
		or layer_index < 0
		or layer_index >= project.layers.size()
		or frame_index < 0
		or frame_index >= project.frames.size()
	):
		return
	_layer = project.layers[layer_index]
	_cel = project.frames[frame_index].cels[layer_index]
	layer_name_label.text = _layer.name
	tooltip_text = _layer.name
	preview_texture.texture = _cel.image_texture
	_layer.name_changed.connect(_on_layer_name_changed)
	_cel.texture_changed.connect(_on_cel_texture_changed)
	_sync_selected()


func _disconnect_bound_data() -> void:
	if is_instance_valid(_layer) and _layer.name_changed.is_connected(_on_layer_name_changed):
		_layer.name_changed.disconnect(_on_layer_name_changed)
	if is_instance_valid(_cel) and _cel.texture_changed.is_connected(_on_cel_texture_changed):
		_cel.texture_changed.disconnect(_on_cel_texture_changed)
	_layer = null
	_cel = null


func _on_pressed() -> void:
	var project := Global.current_project
	if project == null or layer_index < 0 or layer_index >= project.layers.size():
		return
	project.selected_cels.clear()
	project.selected_cels.append([project.current_frame, layer_index])
	project.change_cel(-1, layer_index)


func _on_layer_name_changed() -> void:
	if not is_instance_valid(_layer):
		return
	layer_name_label.text = _layer.name
	tooltip_text = _layer.name


func _on_cel_texture_changed() -> void:
	if is_instance_valid(_cel):
		preview_texture.texture = _cel.image_texture


func _sync_selected() -> void:
	var project := Global.current_project
	button_pressed = (
		project != null
		and layer_index >= 0
		and layer_index < project.layers.size()
		and project.current_layer == layer_index
	)
