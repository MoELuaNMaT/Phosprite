extends "res://tests/test_base.gd"

var _spawned_tools: Array[Node] = []


func teardown() -> void:
	for tool in _spawned_tools:
		if is_instance_valid(tool):
			tool.queue_free()
	_spawned_tools.clear()


func test_ui3_compact_layout_survives_live_pencil_tool() -> void:
	var tool := await _spawn_tool("Pencil")
	tool.set_compact_option_layout(true)
	await tree.process_frame
	check_eq(tool.columns, 1, "live Pencil Tool Options must survive UI3 vertical compaction")
	tool.set_compact_option_layout(false)
	await tree.process_frame
	check_eq(tool.columns, 1, "Pencil Tool Options must restore its original single-column layout")


func test_ui3_compact_layout_survives_nested_gradient_grid() -> void:
	var tool := await _spawn_tool("Gradient")
	tool.set_compact_option_layout(true)
	await tree.process_frame
	var options := tool.get_node("GradientOptions") as GridContainer
	check_eq(options.columns, 1, "nested Gradient properties must stack vertically in UI3")
	tool.set_compact_option_layout(false)
	await tree.process_frame
	check_eq(options.columns, 2, "nested Gradient properties must restore their original columns")


func _spawn_tool(tool_name: String) -> BaseTool:
	var definition: Tools.Tool = Tools.tools[tool_name]
	var tool := definition.instantiate_scene() as BaseTool
	tool.name = tool_name
	var slot := Tools.Slot.new("Left tool")
	slot.button = MOUSE_BUTTON_LEFT
	slot.color = Color.BLACK
	tool.tool_slot = slot
	_spawned_tools.append(tool)
	tree.root.add_child(tool)
	await tree.process_frame
	return tool
