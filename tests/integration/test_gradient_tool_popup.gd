extends "res://tests/test_base.gd"

var _spawned_tools: Array[Node] = []


func teardown() -> void:
	for tool in _spawned_tools:
		if is_instance_valid(tool):
			if tool.get_parent() != null:
				tool.get_parent().remove_child(tool)
			tool.queue_free()
	_spawned_tools.clear()


func test_gradient_preview_shares_live_editor_and_preserves_configuration() -> void:
	var tool := await _spawn_gradient_tool()
	var editor := tool.gradient_edit
	var preview := tool.gradient_preview_button
	var popup := tool.gradient_popup
	var preview_texture := preview.icon as GradientTexture2D
	check_true(preview_texture != null, "gradient entry must use a generated gradient texture")
	if preview_texture == null:
		return
	check_true(
		editor.get_parent() == popup.get_node("PopupMargin"), "the full editor lives in the popup"
	)
	check_true(not popup.visible, "the editor starts closed")
	check_eq(preview.custom_minimum_size, Vector2(32, 32), "the preview matches selection mode buttons")
	check_eq(preview_texture.fill_from, Vector2(0, 1), "gradient begins at bottom left")
	check_eq(preview_texture.fill_to, Vector2(1, 0), "gradient ends at top right")
	check_true(
		preview_texture.gradient == editor.gradient, "preview and tool use the same gradient"
	)

	var custom_gradient := Gradient.new()
	custom_gradient.add_point(0.5, Color.RED)
	editor.set_gradient(custom_gradient)
	check_true(preview_texture.gradient == custom_gradient, "editing refreshes the preview")
	check_eq(
		tool.get_config()["gradient"]["offsets"].size(),
		3,
		"the updated gradient is kept in the tool configuration"
	)
	tool.set_compact_option_layout(true)
	await tree.process_frame
	check_true(preview.icon == preview_texture, "UI3 compaction preserves preview texture")
	check_true(editor.get_parent() == popup.get_node("PopupMargin"), "UI3 does not move the editor")
	tool.set_compact_option_layout(false)


func _spawn_gradient_tool() -> GradientTool:
	var definition: Tools.Tool = Tools.tools["Gradient"]
	var tool := definition.instantiate_scene() as GradientTool
	tool.name = "Gradient"
	var slot := Tools.Slot.new("Left tool")
	slot.button = MOUSE_BUTTON_LEFT
	slot.color = Color.BLACK
	tool.tool_slot = slot
	tool.prepare_stacked_option_layout()
	_spawned_tools.append(tool)
	tree.root.add_child(tool)
	await tree.process_frame
	return tool


func test_gradient_icon_modes_are_stacked_and_keep_saved_values() -> void:
	var tool := await _spawn_gradient_tool()
	check_eq(tool.get_node("GradientOptions").columns, 1, "labels sit above each option")
	for name in [
		"ShapeOptionButton", "DitheringOptionButton", "RepeatOptionButton", "FillAreaOptions"
	]:
		var button := tool.get_node("GradientOptions/" + name) as Button
		check_true(button != null, "mode selectors use icon buttons: " + name)
		if button == null:
			continue
		check_eq(button.custom_minimum_size, Vector2(32, 32), "mode buttons match 32px selection buttons")
		check_true(button.icon != null, "selected mode has a visible icon")
		check_true(button.text.is_empty(), "mode selection uses no dropdown text")
	check_eq(tool._mode_icons("shape").size(), 2, "shape has two choices")
	check_eq(
		tool._mode_icons("dither").size(),
		1 + ShaderLoader.dither_matrices.size(),
		"Bayer list includes all project textures"
	)
	check_eq(tool._mode_icons("repeat").size(), 4, "repeat has four choices")
	check_eq(tool._mode_icons("fill_area").size(), 3, "fill area has three choices")
	tool._on_mode_choice_selected("shape", 1)
	tool._on_mode_choice_selected("dither", 2)
	tool._on_mode_choice_selected("repeat", 2)
	tool._on_mode_choice_selected("fill_area", 2)
	check_eq(tool.get_config()["shape"], 1, "radial shape saved")
	check_eq(tool.get_config()["selected_dither_index"], 2, "Bayer 4x4 saved")
	check_eq(tool.get_config()["repeat"], 2, "mirrored repeat saved")
	check_eq(tool.get_config()["fill_area"], 2, "whole selection saved")
	check_true(
		not tool.get_node("GradientOptions/ToleranceLabel").visible,
		"whole selection hides tolerance"
	)
	check_true(
		not tool.get_node("GradientOptions/ToleranceSlider").visible,
		"whole selection hides the numeric value"
	)
	check_true(
		tool.dithering_option_button.icon == ShaderLoader.dither_matrices[1].texture,
		"Bayer uses original grayscale resource"
	)
	tool._on_mode_choice_selected("fill_area", 0)
	check_true(
		tool.get_node("GradientOptions/ToleranceSlider").visible,
		"other fill modes restore tolerance"
	)
	tool.set_compact_option_layout(true)
	await tree.process_frame
	check_eq(tool.get_node("GradientOptions").columns, 1, "UI3 keeps stacked options")
	check_eq(
		tool.shape_option_button.custom_minimum_size, Vector2(32, 32), "UI3 preserves compact square buttons"
	)
	tool.set_compact_option_layout(false)
