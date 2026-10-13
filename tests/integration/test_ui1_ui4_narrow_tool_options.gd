extends "res://tests/test_base.gd"

var _spawned_tools: Array[Node] = []


func teardown() -> void:
	for tool in _spawned_tools:
		if is_instance_valid(tool):
			tool.queue_free()
	_spawned_tools.clear()


func test_ui1_ui4_shared_mode_padding_and_all_tool_minimum_widths() -> void:
	check_eq(
		WorkspaceEditorMigration.TOOL_OPTIONS_WIDTH,
		BaseTool.MODE_ICON_BUTTON_SIZE + 24.0,
		"right column is one 32px icon plus symmetric 12px margins",
	)
	check_eq(
		WorkspaceUIProfile4.RIGHT_WIDTH,
		WorkspaceEditorMigration.UI1_TOOLS_FIXED_WIDTH,
		"UI1 and UI4 Tools modules have identical total width",
	)
	for tool_name in ["Pencil", "Eraser", "RectSelect", "Bucket", "Gradient", "LineTool"]:
		var definition: Tools.Tool = Tools.tools[tool_name]
		var tool := definition.instantiate_scene() as BaseTool
		tool.name = tool_name
		var slot := Tools.Slot.new("Left tool")
		slot.button = MOUSE_BUTTON_LEFT
		slot.color = Color.BLACK
		tool.tool_slot = slot
		tool.prepare_stacked_option_layout()
		_spawned_tools.append(tool)
		tree.root.add_child(tool)
		await tree.process_frame
		var width := tool.get_combined_minimum_size().x
		print("[UI1-UI4 SIDEBAR] %s minimum width: %s" % [tool_name, width])
		check_true(
			width <= WorkspaceEditorMigration.TOOL_OPTIONS_WIDTH,
			"%s tool options must fit the same 56px column (measured %s)"
			% [tool_name, width],
		)
