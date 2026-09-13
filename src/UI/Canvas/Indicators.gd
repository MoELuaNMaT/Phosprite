extends Node2D


func _input(event: InputEvent) -> void:
	if event is InputEventMouse or event is InputEventKey:
		queue_redraw()


func _draw() -> void:
	# Draw rectangle to indicate the pixel currently being hovered on.
	# Touch has no hover phase, so the adapter keeps this visible only while a
	# finger/Pencil actually owns content; physical mouse/trackpad keeps legacy hover.
	var canvas := Global.canvas as Canvas
	if Global.can_draw and (
		not is_instance_valid(canvas) or canvas.should_draw_tool_indicator()
	):
		Tools.draw_indicator()
