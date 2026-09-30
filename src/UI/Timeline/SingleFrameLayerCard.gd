class_name SingleFrameLayerCard
extends Button

var layer_index := -1
var frame_index := -1
var _project: Project
var _layer: BaseLayer
var _cel: BaseCel

@onready var preview_texture := %PreviewTexture as TextureRect
@onready var layer_name_label := %LayerName as Label


func _ready() -> void:
	toggle_mode = true
	pressed.connect(_on_pressed)
	gui_input.connect(_on_gui_input)
	if not Global.cel_switched.is_connected(_sync_selected):
		Global.cel_switched.connect(_sync_selected)


func _exit_tree() -> void:
	_disconnect_bound_data()
	if Global.cel_switched.is_connected(_sync_selected):
		Global.cel_switched.disconnect(_sync_selected)


func setup(project: Project, new_layer_index: int, new_frame_index: int) -> void:
	_disconnect_bound_data()
	_project = project
	layer_index = new_layer_index
	frame_index = new_frame_index
	if (
		_project == null
		or layer_index < 0
		or layer_index >= _project.layers.size()
		or frame_index < 0
		or frame_index >= _project.frames.size()
	):
		return
	_layer = _project.layers[layer_index]
	_cel = _project.frames[frame_index].cels[layer_index]
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
	_project = null
	_layer = null
	_cel = null


func _on_pressed() -> void:
	if (
		_project == null
		or _project != Global.current_project
		or layer_index < 0
		or layer_index >= _project.layers.size()
	):
		return
	_project.selected_cels.clear()
	_project.selected_cels.append([_project.current_frame, layer_index])
	_project.change_cel(-1, layer_index)


func _on_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and event.double_click
	):
		_toggle_layer_visibility()


func _toggle_layer_visibility() -> void:
	if (
		_project == null
		or _project != Global.current_project
		or not is_instance_valid(_layer)
		or layer_index < 0
		or layer_index >= _project.layers.size()
		or _project.layers[layer_index] != _layer
	):
		return

	Global.transform_content_confirmed.emit()
	var project := _project
	var layer := _layer
	if Global.layer_visibility_undoable:
		project.undo_redo.create_action("Change Layer Visibility")
		project.undo_redo.add_do_property(layer, "visible", not layer.visible)
		project.undo_redo.add_undo_property(layer, "visible", layer.visible)
		project.undo_redo.add_do_property(Global.canvas, "update_all_layers", true)
		project.undo_redo.add_undo_property(Global.canvas, "update_all_layers", true)
		project.undo_redo.add_do_method(Global.canvas.queue_redraw)
		project.undo_redo.add_undo_method(Global.canvas.queue_redraw)
		if is_instance_valid(Global.animation_timeline):
			project.undo_redo.add_do_method(Global.animation_timeline.update_global_layer_buttons)
			project.undo_redo.add_undo_method(Global.animation_timeline.update_global_layer_buttons)
		project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
		project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
		project.undo_redo.commit_action()
	else:
		layer.visible = not layer.visible
		Global.canvas.update_all_layers = true
		Global.canvas.queue_redraw()
		if is_instance_valid(Global.animation_timeline):
			Global.animation_timeline.update_global_layer_buttons()


func _on_layer_name_changed() -> void:
	if not is_instance_valid(_layer):
		return
	layer_name_label.text = _layer.name
	tooltip_text = _layer.name


func _on_cel_texture_changed() -> void:
	if is_instance_valid(_cel):
		preview_texture.texture = _cel.image_texture


func _sync_selected() -> void:
	button_pressed = (
		_project != null
		and _project == Global.current_project
		and layer_index >= 0
		and layer_index < _project.layers.size()
		and _project.current_layer == layer_index
	)
