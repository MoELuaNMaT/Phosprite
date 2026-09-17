class_name CanvasBoundary
extends Node2D

const VisualPolicy := preload("res://src/UI/Canvas/CanvasVisualPolicy.gd")


func _ready() -> void:
	Global.project_about_to_switch.connect(_on_project_about_to_switch)
	Global.project_switched.connect(_on_project_switched)
	var project := Global.current_project
	if not project.resized.is_connected(queue_redraw):
		project.resized.connect(queue_redraw)
	if is_instance_valid(Global.control) and not Global.control.theme_changed.is_connected(queue_redraw):
		Global.control.theme_changed.connect(queue_redraw)


func _draw() -> void:
	var target_rect := Global.current_project.tiles.get_bounding_rect()
	if not target_rect.has_area():
		return
	var source_theme: Theme = null
	if is_instance_valid(Global.control):
		source_theme = Global.control.theme
	var border_color := VisualPolicy.resolve_boundary_color(source_theme)
	# Negative width asks Godot for a screen-space hairline, so zooming does not turn the
	# document edge into a thick Canvas-space band.
	draw_rect(target_rect, border_color, false, -1.0)


func _on_project_about_to_switch() -> void:
	var project := Global.current_project
	if project.resized.is_connected(queue_redraw):
		project.resized.disconnect(queue_redraw)


func _on_project_switched() -> void:
	var project := Global.current_project
	if not project.resized.is_connected(queue_redraw):
		project.resized.connect(queue_redraw)
	queue_redraw()
