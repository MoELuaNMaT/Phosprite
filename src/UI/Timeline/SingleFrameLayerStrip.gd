class_name SingleFrameLayerStrip
extends PanelContainer

const LAYER_CARD_SCENE := preload("res://src/UI/Timeline/SingleFrameLayerCard.tscn")

var _bound_project: Project
var _displayed_frame := -1

@onready var layer_row := %LayerRow as HBoxContainer
@onready var scroll_container := %LayerScroll as ScrollContainer
@onready var add_layer_button := %AddLayer as Button


func _ready() -> void:
	add_layer_button.pressed.connect(_on_add_layer_pressed)
	Global.project_about_to_switch.connect(_on_project_about_to_switch)
	Global.project_switched.connect(_on_project_switched)
	Global.cel_switched.connect(_on_cel_switched)
	_bind_project(Global.current_project)
	refresh()


func _exit_tree() -> void:
	_unbind_project()
	if Global.project_about_to_switch.is_connected(_on_project_about_to_switch):
		Global.project_about_to_switch.disconnect(_on_project_about_to_switch)
	if Global.project_switched.is_connected(_on_project_switched):
		Global.project_switched.disconnect(_on_project_switched)
	if Global.cel_switched.is_connected(_on_cel_switched):
		Global.cel_switched.disconnect(_on_cel_switched)


func refresh() -> void:
	var project := Global.current_project
	if project == null or not is_instance_valid(layer_row):
		return
	if _bound_project != project:
		_bind_project(project)
	for child in layer_row.get_children():
		if child == add_layer_button:
			continue
		layer_row.remove_child(child)
		child.queue_free()

	_displayed_frame = project.current_frame
	for visual_index in project.layers.size():
		var layer_index := project.layers.size() - 1 - visual_index
		var card := LAYER_CARD_SCENE.instantiate() as SingleFrameLayerCard
		layer_row.add_child(card)
		layer_row.move_child(card, layer_row.get_child_count() - 2)
		card.setup(layer_index, project.current_frame)
	call_deferred("_ensure_current_layer_visible")


func sync_selection() -> void:
	var project := Global.current_project
	if project == null:
		return
	for child in layer_row.get_children():
		if child is SingleFrameLayerCard:
			(child as SingleFrameLayerCard)._sync_selected()
	call_deferred("_ensure_current_layer_visible")


func _bind_project(project: Project) -> void:
	_unbind_project()
	_bound_project = project
	if not is_instance_valid(_bound_project):
		return
	if not _bound_project.layers_updated.is_connected(_on_layers_updated):
		_bound_project.layers_updated.connect(_on_layers_updated)
	if not _bound_project.frames_updated.is_connected(_on_frames_updated):
		_bound_project.frames_updated.connect(_on_frames_updated)


func _unbind_project() -> void:
	if not is_instance_valid(_bound_project):
		_bound_project = null
		return
	if _bound_project.layers_updated.is_connected(_on_layers_updated):
		_bound_project.layers_updated.disconnect(_on_layers_updated)
	if _bound_project.frames_updated.is_connected(_on_frames_updated):
		_bound_project.frames_updated.disconnect(_on_frames_updated)
	_bound_project = null


func _on_project_about_to_switch() -> void:
	_unbind_project()


func _on_project_switched() -> void:
	_bind_project(Global.current_project)
	refresh()


func _on_layers_updated() -> void:
	refresh()


func _on_frames_updated() -> void:
	refresh()


func _on_cel_switched() -> void:
	var project := Global.current_project
	if project == null:
		return
	if _displayed_frame != project.current_frame:
		refresh()
	else:
		sync_selection()


func _on_add_layer_pressed() -> void:
	if is_instance_valid(Global.animation_timeline):
		Global.animation_timeline.add_default_pixel_layer()


func _ensure_current_layer_visible() -> void:
	var project := Global.current_project
	if project == null or not is_instance_valid(scroll_container):
		return
	for child in layer_row.get_children():
		if child is SingleFrameLayerCard and child.layer_index == project.current_layer:
			scroll_container.ensure_control_visible(child)
			return
