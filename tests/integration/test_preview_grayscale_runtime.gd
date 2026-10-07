extends "res://tests/test_base.gd"

func test_live_preview_instances_receive_shared_grayscale_state() -> void:
	check_true(tree != null, "integration suite should receive the SceneTree")
	if tree == null:
		return

	var previews := tree.get_nodes_in_group(&"CanvasPreviews")
	check_true(not previews.is_empty(), "live editor must contain at least one CanvasPreview")
	if previews.is_empty():
		return

	Global.greyscale_view = true
	await tree.process_frame

	for preview: CanvasItem in previews:
		var current_material := preview.material as ShaderMaterial
		check_true(
			is_instance_valid(current_material),
			"every live CanvasPreview must have a ShaderMaterial while grayscale is enabled",
		)
		if is_instance_valid(current_material):
			check_eq(
				current_material.get_shader_parameter(&"greyscale_view"),
				true,
				"the visible CanvasPreview material must receive greyscale_view=true",
			)
		var animation_material := preview.get("animation_material") as ShaderMaterial
		check_true(
			is_instance_valid(animation_material),
			"every live CanvasPreview must retain an animation ShaderMaterial",
		)
		if is_instance_valid(animation_material):
			check_eq(
				animation_material.get_shader_parameter(&"greyscale_view"),
				true,
				"the animation Preview material must receive greyscale_view=true",
			)

	Global.greyscale_view = false
	await tree.process_frame

	for preview: CanvasItem in previews:
		var current_material := preview.material as ShaderMaterial
		if is_instance_valid(current_material):
			check_eq(
				current_material.get_shader_parameter(&"greyscale_view"),
				false,
				"the visible CanvasPreview material must receive greyscale_view=false",
			)
