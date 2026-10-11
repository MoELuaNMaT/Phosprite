extends "res://tests/test_base.gd"

var _spawned_tools: Array[Node] = []


func teardown() -> void:
	for tool in _spawned_tools:
		if is_instance_valid(tool):
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
	check_eq(preview.custom_minimum_size, Vector2(42, 42), "the entry has a square minimum size")
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
