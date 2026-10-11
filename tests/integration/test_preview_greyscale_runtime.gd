extends "res://tests/test_base.gd"

const PREVIEW_SCENE := preload("res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.tscn")
const PREVIEW_SHADER := "res://src/Shaders/PreviewGreyscale.gdshader"


func test_preview_and_canvas_toggle_greyscale_together() -> void:
	var previous_state := Global.greyscale_view
	var preview := PREVIEW_SCENE.instantiate() as PanelContainer
	tree.root.add_child(preview)
	await tree.process_frame

	var viewport_container := (
		preview.get_node_or_null("VBox/HBox/PreviewViewportContainer") as SubViewportContainer
	)
	var button := preview.get_node_or_null("%GrayscaleButton") as Button
	var main_overlay := (
		Global.main_viewport.get_node_or_null("SubViewport/CanvasLayer/GreyscaleVision")
		as ColorRect
	)
	check_true(viewport_container != null, "Preview must have a SubViewportContainer")
	check_true(main_overlay != null, "Canvas must keep its screen greyscale layer")
	check_true(button != null, "Preview must keep its greyscale toggle")
	if viewport_container == null or main_overlay == null or button == null:
		preview.queue_free()
		return

	var preview_shader_source := FileAccess.get_file_as_string(PREVIEW_SHADER)
	check_has(
		preview_shader_source,
		"texture(TEXTURE, UV)",
		"Preview must filter its rendered texture, not read the screen"
	)
	check_true(
		not ("hint_screen_texture" in preview_shader_source),
		"Preview must not depend on the SubViewport screen back-buffer"
	)
	var global_src := FileAccess.get_file_as_string("res://src/Autoload/Global.gd")
	check_true(
		not ('control.find_child("GreyscaleVision"' in global_src),
		"global greyscale must target Main Canvas independently of Preview order"
	)

	Global.greyscale_view = false
	await tree.process_frame
	check_true(viewport_container.material == null, "Preview color mode must be unfiltered")
	check_true(not main_overlay.visible, "Canvas must start in color mode")
	button.button_pressed = true
	await tree.process_frame
	check_true(Global.greyscale_view, "Preview button must change the shared state")
	var preview_material := viewport_container.material as ShaderMaterial
	check_true(preview_material != null, "Preview must filter the composited image in greyscale")
	if preview_material != null:
		check_eq(
			preview_material.shader.resource_path,
			PREVIEW_SHADER,
			"Preview must use the texture-sampling greyscale shader"
		)
	check_true(main_overlay.visible, "Canvas image must enter greyscale mode")

	Global.greyscale_view = false
	await tree.process_frame
	check_true(viewport_container.material == null, "Preview must restore original color rendering")
	check_true(not main_overlay.visible, "Canvas must return to color")
	check_true(not button.button_pressed, "Preview button must follow shared state")
	Global.greyscale_view = true
	await tree.process_frame
	check_true(viewport_container.material is ShaderMaterial, "View menu must filter Preview")
	check_true(button.button_pressed, "View menu must update Preview button")

	preview.queue_free()
	await tree.process_frame
	var reopened := PREVIEW_SCENE.instantiate() as PanelContainer
	tree.root.add_child(reopened)
	await tree.process_frame
	var reopened_container := (
		reopened.get_node_or_null("VBox/HBox/PreviewViewportContainer") as SubViewportContainer
	)
	check_true(
		reopened_container != null and reopened_container.material is ShaderMaterial,
		"Reopened Preview must restore actual greyscale filtering"
	)
	reopened.queue_free()
	Global.greyscale_view = previous_state
	await tree.process_frame
