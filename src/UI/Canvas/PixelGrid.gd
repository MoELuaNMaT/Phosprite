extends Node2D

const CanvasVisualPolicy := preload("res://src/UI/Canvas/CanvasVisualPolicy.gd")


func _ready() -> void:
	Global.pixel_grid_updated.connect(queue_redraw)
	Global.project_about_to_switch.connect(_on_project_about_to_switch)
	Global.project_switched.connect(_on_project_switched)
	Global.camera.zoom_changed.connect(queue_redraw)


func _draw() -> void:
	if not Global.draw_pixel_grid:
		return

	var zoom_percentage := 100.0 * Global.camera.zoom.x
	if zoom_percentage < Global.pixel_grid_show_at_zoom:
		return

	var target_rect := Global.current_project.tiles.get_bounding_rect()
	if not target_rect.has_area():
		return

	var grid_multiline_points := PackedVector2Array()
	var first_x := floori(target_rect.position.x) + 1
	var last_x := ceili(target_rect.end.x)
	var first_y := floori(target_rect.position.y) + 1
	var last_y := ceili(target_rect.end.y)

	# The project border owns the outer edge. Drawing pixel-grid lines there too creates a
	# visibly heavier seam, especially on Retina/high-DPI displays.
	for x in range(first_x, last_x):
		grid_multiline_points.push_back(Vector2(x, target_rect.position.y))
		grid_multiline_points.push_back(Vector2(x, target_rect.end.y))

	for y in range(first_y, last_y):
		grid_multiline_points.push_back(Vector2(target_rect.position.x, y))
		grid_multiline_points.push_back(Vector2(target_rect.end.x, y))

	if not grid_multiline_points.is_empty():
		var line_color := Global.pixel_grid_color
		line_color.a *= CanvasVisualPolicy.PIXEL_GRID_ALPHA_FACTOR
		draw_multiline(grid_multiline_points, line_color)


func _on_project_about_to_switch() -> void:
	var project := Global.current_project
	project.resized.disconnect(queue_redraw)


func _on_project_switched() -> void:
	var project := Global.current_project
	if not project.resized.is_connected(queue_redraw):
		project.resized.connect(queue_redraw)
