extends "res://tests/test_base.gd"

const PREVIEW_SCENE := preload("res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.tscn")
const GREYSCALE_NODE := "VBox/HBox/PreviewViewportContainer/SubViewport/CanvasLayer/GreyscaleVision"


func test_preview_and_canvas_toggle_greyscale_together() -> void:
	var previous_state := Global.greyscale_view
	var preview := PREVIEW_SCENE.instantiate() as PanelContainer
	tree.root.add_child(preview)
	await tree.process_frame

	var overlay := preview.get_node_or_null(GREYSCALE_NODE) as ColorRect
	var button := preview.get_node_or_null("%GrayscaleButton") as Button
	var main_overlay := Global.control.find_child("GreyscaleVision", true, false) as ColorRect
	check_true(overlay != null, "Preview must own a greyscale rendering layer")
	check_true(main_overlay != null, "Canvas must own a greyscale rendering layer")
	check_true(button != null, "Preview must keep its greyscale toggle")
	if overlay == null or main_overlay == null or button == null:
		preview.queue_free()
		return

	var preview_material := overlay.material as ShaderMaterial
	var canvas_material := main_overlay.material as ShaderMaterial
	check_true(preview_material != null, "Preview layer must have a shader")
	if preview_material != null and canvas_material != null:
		check_eq(
			preview_material.shader.resource_path,
			canvas_material.shader.resource_path,
			"Preview and Canvas must share the same greyscale shader"
		)
	check_eq(
		overlay.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"Preview shader must not capture finger input"
	)

	Global.greyscale_view = false
	await tree.process_frame
	check_true(not overlay.visible, "Preview must start in color mode")
	check_true(not main_overlay.visible, "Canvas must start in color mode")
	button.button_pressed = true
	await tree.process_frame
	check_true(Global.greyscale_view, "Preview button must change the shared state")
	check_true(overlay.visible, "Preview image must enter greyscale mode")
	check_true(main_overlay.visible, "Canvas image must enter greyscale mode")

	Global.greyscale_view = false
	await tree.process_frame
	check_true(not overlay.visible, "Preview must return to color")
	check_true(not main_overlay.visible, "Canvas must return to color")
	check_true(not button.button_pressed, "Preview button must follow the shared state")
	Global.greyscale_view = true
	await tree.process_frame
	check_true(overlay.visible, "View menu must update the Preview image")
	check_true(button.button_pressed, "View menu must update the Preview toggle")

	preview.queue_free()
	await tree.process_frame
	var reopened := PREVIEW_SCENE.instantiate() as PanelContainer
	tree.root.add_child(reopened)
	await tree.process_frame
	var reopened_overlay := reopened.get_node_or_null(GREYSCALE_NODE) as ColorRect
	check_true(
		reopened_overlay != null and reopened_overlay.visible,
		"Reopened Preview must inherit the current greyscale state"
	)
	reopened.queue_free()
	Global.greyscale_view = previous_state
	await tree.process_frame
