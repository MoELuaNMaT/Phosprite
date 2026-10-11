extends "res://tests/test_base.gd"

const PREVIEW_SCENE := preload("res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.tscn")
const BLEND_SHADER := "res://src/Shaders/BlendLayers.gdshader"


func test_preview_and_canvas_toggle_greyscale_together() -> void:
	var original_state := Global.greyscale_view
	var preview := PREVIEW_SCENE.instantiate() as PanelContainer
	tree.root.add_child(preview)
	await tree.process_frame

	var button := preview.get_node_or_null("%GrayscaleButton") as Button
	var image_node := preview.get_node_or_null("%CanvasPreview") as Node2D
	var main_overlay := (
		Global.main_viewport.get_node_or_null("SubViewport/CanvasLayer/GreyscaleVision")
		as ColorRect
	)
	check_true(button != null, "Preview must have a grayscale button")
	check_true(image_node != null, "Preview must have a composited image renderer")
	check_true(main_overlay != null, "Canvas must have a grayscale overlay")
	if button == null or image_node == null or main_overlay == null:
		preview.queue_free()
		return

	var main_material := Global.canvas.material as ShaderMaterial
	var animation_material := image_node.get("animation_material") as ShaderMaterial
	check_true(main_material != null, "Canvas must have a compositing shader")
	check_true(animation_material != null, "Animated Preview must have a compositing shader")
	if main_material == null or animation_material == null:
		preview.queue_free()
		return
	check_eq(
		animation_material.shader.resource_path,
		BLEND_SHADER,
		"Preview must render animated frames with the grayscale-aware shader"
	)

	Global.greyscale_view = false
	await tree.process_frame
	check_true(not main_overlay.visible, "Canvas must start in color mode")
	check_true(
		not bool(main_material.get_shader_parameter(&"greyscale_view")),
		"Canvas shader must start in color mode"
	)
	check_true(
		not bool(animation_material.get_shader_parameter(&"greyscale_view")),
		"Animated Preview must start in color mode"
	)

	button.button_pressed = true
	await tree.process_frame
	check_true(Global.greyscale_view, "Preview button must update global state")
	check_true(main_overlay.visible, "Canvas must enter grayscale mode")
	check_true(
		bool(main_material.get_shader_parameter(&"greyscale_view")),
		"Canvas compositing must enter grayscale mode"
	)
	check_true(
		bool(animation_material.get_shader_parameter(&"greyscale_view")),
		"Animated Preview compositing must enter grayscale mode"
	)

	Global.greyscale_view = false
	await tree.process_frame
	check_true(not button.button_pressed, "Preview button must return to color mode")
	check_true(
		not bool(animation_material.get_shader_parameter(&"greyscale_view")),
		"Animated Preview must return to color mode"
	)

	# UI3 reparents the same module; _ready() is not called a second time.
	var holder := Control.new()
	tree.root.add_child(holder)
	preview.reparent(holder)
	await tree.process_frame
	check_true(
		Global.greyscale_view_changed.is_connected(
			Callable(preview, "_on_greyscale_view_changed")
		),
		"Preview toggle must reconnect when UI3 reparents the module"
	)
	check_true(
		Global.greyscale_view_changed.is_connected(
			Callable(image_node, "_on_greyscale_view_changed")
		),
		"Preview renderer must reconnect when UI3 reparents the module"
	)
	Global.greyscale_view = true
	await tree.process_frame
	check_true(button.button_pressed, "Preview button must follow state after reparenting")
	check_true(
		bool(animation_material.get_shader_parameter(&"greyscale_view")),
		"Preview renderer must follow state after reparenting"
	)

	holder.queue_free()
	await tree.process_frame
	var reopened := PREVIEW_SCENE.instantiate() as PanelContainer
	tree.root.add_child(reopened)
	await tree.process_frame
	var reopened_image := reopened.get_node_or_null("%CanvasPreview") as Node2D
	var reopened_material: ShaderMaterial = null
	if reopened_image != null:
		reopened_material = reopened_image.get("animation_material") as ShaderMaterial
	check_true(
		reopened_material != null
		and bool(reopened_material.get_shader_parameter(&"greyscale_view")),
		"Reopened Preview must restore grayscale rendering"
	)
	reopened.queue_free()
	Global.greyscale_view = original_state
	await tree.process_frame
