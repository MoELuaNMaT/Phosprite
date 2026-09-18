extends "res://tests/test_base.gd"

const ADAPTER := preload("res://src/InputAdapter/CanvasInputAdapter.gd")


func test_ui_touch_outside_main_canvas_cannot_acquire_canvas_ownership() -> void:
	var viewport := Global.main_viewport
	var canvas := Global.canvas
	check_true(is_instance_valid(viewport), "live editor must expose Main Canvas viewport")
	check_true(is_instance_valid(canvas), "live editor must expose Canvas")
	if not is_instance_valid(viewport) or not is_instance_valid(canvas):
		return

	await tree.process_frame
	await tree.process_frame
	var canvas_rect := viewport.get_global_rect()
	check_true(canvas_rect.has_area(), "Main Canvas viewport must have real geometry")
	if not canvas_rect.has_area():
		return

	var outside_candidates := [
		Vector2(canvas_rect.position.x - 8.0, canvas_rect.get_center().y),
		Vector2(canvas_rect.end.x + 8.0, canvas_rect.get_center().y),
		Vector2(canvas_rect.get_center().x, canvas_rect.position.y - 8.0),
		Vector2(canvas_rect.get_center().x, canvas_rect.end.y + 8.0),
	]
	var window_rect := Rect2(Vector2.ZERO, tree.root.size)
	var outside := Vector2(-1000.0, -1000.0)
	for candidate: Vector2 in outside_candidates:
		if window_rect.has_point(candidate) and not canvas_rect.has_point(candidate):
			outside = candidate
			break
	check_true(outside.x > -999.0, "test needs a visible UI point outside Main Canvas")
	if outside.x <= -999.0:
		return

	var adapter := ADAPTER.new()
	var ui_press := InputEventScreenTouch.new()
	ui_press.index = 71
	ui_press.device = 0
	ui_press.position = outside
	ui_press.pressed = true
	adapter.call("_begin_touch", canvas, ui_press)
	var touches: Dictionary = adapter.get("_touches")
	check_true(
		not touches.has(ui_press.index),
		"a touch that begins over Workspace UI must never enter Canvas ownership"
	)

	var canvas_press := InputEventScreenTouch.new()
	canvas_press.index = 72
	canvas_press.device = 0
	canvas_press.position = canvas_rect.get_center()
	canvas_press.pressed = true
	adapter.call("_begin_touch", canvas, canvas_press)
	touches = adapter.get("_touches")
	check_true(
		touches.has(canvas_press.index),
		"a touch that begins inside Main Canvas must still enter the normal arbitration path"
	)

	adapter.reset(canvas)
