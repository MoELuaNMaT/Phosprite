extends "res://tests/test_base.gd"

const VECTOR_SCENE := preload("res://src/UI/Nodes/Sliders/ValueSliderV2.tscn")


func test_tool_numeric_control_uses_vertical_arrows_and_clear_background() -> void:
	var tool := BaseTool.new()
	tool.name = "Pencil"
	var slider := ValueSlider.new()
	slider.name = "BrushSize"
	slider.min_value = 1.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = 12.0
	slider.prefix = "Size:"
	slider.suffix = "px"
	tool._configure_sidebar_value_slider(slider)
	check_true(slider.tool_vertical_drag, "tool sliders use vertical dragging")
	check_true(not slider.show_progress, "tool sliders have no progress track")
	check_true(not slider.show_drag_arrows, "old inline left/right arrows are disabled")
	check_true(not slider.show_arrows, "separate side arrow buttons remain hidden")
	check_true(not slider.allow_text_input, "touch dragging does not open keyboard")
	check_true(slider.texture_under == null, "tool slider has no black background")
	check_true(slider.texture_progress == null, "tool slider has no colored progress bar")
	check_eq(slider.tint_under, Color.TRANSPARENT, "slider underlay is transparent")
	check_eq(slider.tint_progress, Color.TRANSPARENT, "slider progress is transparent")
	check_eq(slider.custom_minimum_size, Vector2(54, 48), "vertical arrows fit 54x48")
	check_eq(slider._line_edit.offset_top, 12.0, "value is below upper arrow")
	check_eq(slider._line_edit.offset_bottom, -12.0, "value is above lower arrow")
	check_eq(slider.min_value, 1.0, "minimum stays unchanged")
	check_eq(slider.max_value, 100.0, "maximum stays unchanged")
	check_eq(slider.step, 1.0, "step stays unchanged")
	check_almost_eq(slider.drag_sensitivity, 0.1, 0.001, "brush precision is preserved")
	check_true(
		not slider._format_float_string().contains("<"),
		"number no longer displays a left arrow",
	)
	slider._reset_display(true)
	check_true(slider.texture_under == null, "theme refresh cannot restore black background")
	slider.free()
	tool.free()


func test_all_tool_vector_components_reuse_vertical_mode() -> void:
	var tool := BaseTool.new()
	var vector := VECTOR_SCENE.instantiate() as ValueSliderV2
	tool._configure_sidebar_vector_slider(vector)
	check_eq(vector.grid_columns, 1, "coordinate controls remain vertically stacked")
	for slider in vector.get_sliders():
		check_true(slider.tool_vertical_drag, "position and size components use vertical mode")
		check_eq(slider.custom_minimum_size, Vector2(54, 48), "vector component has arrow space")
	vector.free()
	tool.free()


func test_vertical_drag_uses_pointer_y_and_preserves_range() -> void:
	var slider := ValueSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.value = 50.0
	slider.step = 1.0
	slider.drag_sensitivity = 1.0
	slider.custom_minimum_size = Vector2(54, 48)
	slider.configure_tool_vertical_drag()
	tree.root.add_child(slider)
	slider.size = Vector2(54, 48)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(27, 24)
	slider._gui_input(press)

	var activate := InputEventMouseMotion.new()
	activate.position = Vector2(27, 18)
	slider._gui_input(activate)
	check_eq(slider.state, ValueSlider.SLIDING, "vertical pointer motion starts drag")
	var up := InputEventMouseMotion.new()
	up.position = Vector2(27, 8)
	slider._gui_input(up)
	check_eq(slider.value, 66.0, "dragging upward increases value")
	var horizontal := InputEventMouseMotion.new()
	horizontal.position = Vector2(42, 8)
	slider._gui_input(horizontal)
	check_eq(slider.value, 66.0, "horizontal movement does not alter vertical value")
	var down := InputEventMouseMotion.new()
	down.position = Vector2(42, 42)
	slider._gui_input(down)
	check_eq(slider.value, 32.0, "dragging downward decreases value")
	var beyond_max := InputEventMouseMotion.new()
	beyond_max.position = Vector2(42, -200)
	slider._gui_input(beyond_max)
	check_eq(slider.value, 100.0, "upper range is still enforced")
	var beyond_min := InputEventMouseMotion.new()
	beyond_min.position = Vector2(42, 400)
	slider._gui_input(beyond_min)
	check_eq(slider.value, 0.0, "lower range is still enforced")
	slider.queue_free()


func test_non_tool_sliders_remain_horizontal_and_keep_track() -> void:
	var slider := ValueSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.value = 50.0
	check_true(not slider.tool_vertical_drag, "other sliders keep horizontal gesture")
	check_true(slider.show_progress, "other sliders keep progress presentation")
	slider.free()


func test_every_tool_scene_numeric_option_uses_vertical_mode() -> void:
	var paths := [
		"res://src/Tools/BaseDraw.tscn",
		"res://src/Tools/BaseSelectionTool.tscn",
		"res://src/Tools/DesignTools/Pencil.tscn",
		"res://src/Tools/DesignTools/Eraser.tscn",
		"res://src/Tools/DesignTools/Bucket.tscn",
		"res://src/Tools/DesignTools/Gradient.tscn",
		"res://src/Tools/DesignTools/RectangleTool.tscn",
		"res://src/Tools/DesignTools/IsometricBoxTool.tscn",
		"res://src/Tools/DesignTools/Shading.tscn",
		"res://src/Tools/SelectionTools/MagicWand.tscn",
		"res://src/Tools/UtilityTools/CropTool.tscn",
	]
	for path in paths:
		var scene := load(path) as PackedScene
		check_true(scene != null, "%s loads as a tool scene" % path)
		if scene == null:
			continue
		var tool := scene.instantiate() as BaseTool
		check_true(tool != null, "%s extends BaseTool" % path)
		if tool == null:
			continue
		tool.prepare_stacked_option_layout()
		var count := _count_and_check_vertical_sliders(tool)
		check_true(count > 0, "%s has numeric controls covered by the shared mode" % path)
		tool.free()


func _count_and_check_vertical_sliders(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is ValueSlider:
			count += 1
			check_true(child.tool_vertical_drag, "%s uses vertical drag" % child.name)
			check_true(child.texture_under == null, "%s has no dark slider track" % child.name)
		elif child is ValueSliderV2:
			for component in child.get_sliders():
				count += 1
				check_true(
					component.tool_vertical_drag, "%s component uses vertical drag" % child.name
				)
		elif child is Container:
			count += _count_and_check_vertical_sliders(child)
	return count
