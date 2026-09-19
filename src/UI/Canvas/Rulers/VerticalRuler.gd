extends Button

const RULER_WIDTH := 16

@export var viewport_container: SubViewportContainer
@export var camera: CanvasCamera

var major_subdivision := 2
var minor_subdivision := 4

var first: Vector2
var last: Vector2
var text_server := TextServerManager.get_primary_interface()
var canvas_edge_overlay_mode := false


func _ready() -> void:
	Global.project_switched.connect(queue_redraw)
	viewport_container.resized.connect(queue_redraw)
	camera.zoom_changed.connect(queue_redraw)
	camera.rotation_changed.connect(queue_redraw)
	camera.offset_changed.connect(queue_redraw)


func set_canvas_edge_overlay_mode(enabled: bool) -> void:
	canvas_edge_overlay_mode = enabled
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	for guide in Global.current_project.guides:
		guide.force_input(event)


# Code taken and modified from Godot's source code
func _draw() -> void:
	var font := Themes.get_font()
	var transform := Transform2D()
	var ruler_transform := Transform2D()
	var major_subdivide := Transform2D()
	var minor_subdivide := Transform2D()
	var zoom := camera.zoom.x
	transform.y = Vector2(zoom, zoom)

	# This tracks the "true" top left corner of the drawing:
	transform.origin = (
		viewport_container.size / 2 + camera.offset.rotated(-camera.camera_angle) * -zoom
	)

	var proj_size := Global.current_project.size

	# Calculating the rotated corners of the image, use min to find the top one
	var a := Vector2.ZERO  # Top left
	var b := Vector2(proj_size.x, 0).rotated(-camera.camera_angle)  # Top right
	var c := Vector2(0, proj_size.y).rotated(-camera.camera_angle)  # Bottom left
	var d := Vector2(proj_size.x, proj_size.y).rotated(-camera.camera_angle)  # Bottom right
	transform.origin.y += minf(minf(a.y, b.y), minf(c.y, d.y)) * zoom
	if canvas_edge_overlay_mode:
		transform.origin.y = 0.0

	var basic_rule := 100.0
	var i := 0
	while basic_rule * zoom > 100:
		basic_rule /= 5.0 if i % 2 else 2.0
		i += 1
	i = 0
	while basic_rule * zoom < 100:
		basic_rule *= 2.0 if i % 2 else 5.0
		i += 1

	ruler_transform = ruler_transform.scaled(Vector2(basic_rule, basic_rule))

	major_subdivide = major_subdivide.scaled(
		Vector2(1.0 / major_subdivision, 1.0 / major_subdivision)
	)
	minor_subdivide = minor_subdivide.scaled(
		Vector2(1.0 / minor_subdivision, 1.0 / minor_subdivision)
	)

	var tick_transform := ruler_transform * major_subdivide * minor_subdivide
	var final_transform := transform * tick_transform
	first = final_transform.affine_inverse() * Vector2.ZERO
	last = final_transform.affine_inverse() * viewport_container.size

	var tick_step := tick_transform.y.y
	var start_index := maxi(0, ceili(first.y))
	var document_end_index := floori(float(proj_size.y) / tick_step)
	var end_index := mini(ceili(last.y), document_end_index + 1)
	for j in range(start_index, end_index):
		var pos: Vector2 = final_transform * Vector2(0, j)
		var val := (tick_transform * Vector2(0, j)).y
		var is_document_end := is_equal_approx(val, float(proj_size.y))
		if j % (major_subdivision * minor_subdivision) == 0:
			draw_line(Vector2(0, pos.y), Vector2(RULER_WIDTH, pos.y), Color.WHITE)
			if not is_document_end:
				_draw_value(font, pos.y, val)
		elif j % minor_subdivision == 0:
			draw_line(
				Vector2(RULER_WIDTH * 0.33, pos.y), Vector2(RULER_WIDTH, pos.y), Color.WHITE
			)
		else:
			draw_line(
				Vector2(RULER_WIDTH * 0.66, pos.y), Vector2(RULER_WIDTH, pos.y), Color.WHITE
			)

	_draw_document_end(font, transform, proj_size.y)


func _draw_value(font: Font, y_position: float, value: float) -> void:
	var text_angle := -PI / 2
	var text_pos := Vector2(font.get_height() - 4, y_position - 2)
	if is_layout_rtl():
		text_angle = PI / 2
		text_pos = Vector2(font.get_height() - 18, y_position + 2)
	var text_xform := Transform2D(text_angle, text_pos)
	draw_set_transform_matrix(text_xform)
	var str_to_draw := "%*.*f" % [0, step_decimals(value), snappedf(value, 0.1)]
	str_to_draw = text_server.format_number(str_to_draw)
	draw_string(
		font, Vector2(), str_to_draw, HORIZONTAL_ALIGNMENT_LEFT, -1, Themes.get_font_size()
	)
	draw_set_transform_matrix(Transform2D())


func _draw_document_end(font: Font, transform: Transform2D, document_height: int) -> void:
	var end_pos := (transform * Vector2(0.0, document_height)).y
	if end_pos < 0.0 or end_pos > size.y + 0.5:
		return
	draw_line(Vector2(0.0, end_pos), Vector2(RULER_WIDTH, end_pos), Color.WHITE)
	var end_text := text_server.format_number(str(document_height))
	var text_angle := -PI / 2
	var text_pos := Vector2(font.get_height() - 4, end_pos - 2)
	if is_layout_rtl():
		text_angle = PI / 2
		var text_width := font.get_string_size(
			end_text, HORIZONTAL_ALIGNMENT_LEFT, -1, Themes.get_font_size()
		).x
		text_pos = Vector2(font.get_height() - 18, end_pos - text_width - 2)
	var text_xform := Transform2D(text_angle, text_pos)
	draw_set_transform_matrix(text_xform)
	draw_string(
		font, Vector2(), end_text, HORIZONTAL_ALIGNMENT_LEFT, -1, Themes.get_font_size()
	)
	draw_set_transform_matrix(Transform2D())


func _on_VerticalRuler_pressed() -> void:
	create_guide()


func create_guide() -> void:
	if !Global.show_guides:
		return
	var guide := Guide.new()
	if absf(camera.camera_angle_degrees) < 45 or absf(camera.camera_angle_degrees) > 135:
		guide.type = guide.Types.VERTICAL
		guide.add_point(Vector2(Global.canvas.current_pixel.x, -19999))
		guide.add_point(Vector2(Global.canvas.current_pixel.x, 19999))
	else:
		guide.type = guide.Types.HORIZONTAL
		guide.add_point(Vector2(-19999, Global.canvas.current_pixel.y))
		guide.add_point(Vector2(19999, Global.canvas.current_pixel.y))
	Global.canvas.add_child(guide)
	queue_redraw()
