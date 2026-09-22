class_name TimelineHeaderControls
extends HBoxContainer

var text_server := TextServerManager.get_primary_interface()

@onready var frame_mark := %CurrentFrameMark as Label


func _ready() -> void:
	%Undo.pressed.connect(_on_undo_pressed)
	%Redo.pressed.connect(_on_redo_pressed)
	if not Global.project_switched.is_connected(_update_frame_mark):
		Global.project_switched.connect(_update_frame_mark)
	if not Global.cel_switched.is_connected(_update_frame_mark):
		Global.cel_switched.connect(_update_frame_mark)
	_update_frame_mark()


func _exit_tree() -> void:
	if Global.project_switched.is_connected(_update_frame_mark):
		Global.project_switched.disconnect(_update_frame_mark)
	if Global.cel_switched.is_connected(_update_frame_mark):
		Global.cel_switched.disconnect(_update_frame_mark)


func _on_undo_pressed() -> void:
	if Global.current_project != null:
		Global.current_project.commit_undo()


func _on_redo_pressed() -> void:
	if Global.current_project != null:
		Global.current_project.commit_redo()


func _update_frame_mark() -> void:
	var project := Global.current_project
	if project == null:
		frame_mark.text = "-/-"
		return
	var current_frame := text_server.format_number(str(project.current_frame + 1))
	var frame_count := text_server.format_number(str(project.frames.size()))
	frame_mark.text = "%s/%s" % [current_frame, frame_count]
