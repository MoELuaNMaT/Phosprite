extends "res://tests/test_base.gd"

const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const Profile3 := preload("res://src/UI/Workspace/WorkspaceUIProfile3.gd")
const Profile4 := preload("res://src/UI/Workspace/WorkspaceUIProfile4.gd")
const Migration := preload("res://src/UI/Workspace/WorkspaceEditorMigration.gd")

var _spawned_tools: Array[Node] = []


func test_ui3_options_use_touch_width_and_restore_legacy_narrow_layouts() -> void:
	var manager := WorkspaceModuleManager.new()
	var dock_host := WorkspaceDockHost.new()
	var surface := WorkspaceSurface.new()
	var root := Control.new()
	root.size = Vector2(1200.0, 800.0)
	tree.root.add_child(root)
	root.add_child(manager)
	root.add_child(dock_host)
	root.add_child(surface)
	dock_host.size = root.size
	check_true(Builtins.register_defaults(manager), "workspace definitions register")
	check_true(dock_host.setup(manager), "dock host initializes")
	check_true(surface.setup(manager, dock_host), "workspace surface initializes")
	var left_options := ScrollContainer.new()
	root.add_child(left_options)
	var profile := Profile3.new()
	root.add_child(profile)
	check_true(profile.setup(root, left_options, surface), "UI3 profile initializes")

	var definition := manager.get_definition(Builtins.UI3_TOOL_OPTIONS_ID)
	check_eq(Builtins.TOOL_SIDEBAR_WIDTH, Migration.UI1_TOOLS_FIXED_WIDTH, "UI1 unchanged")
	check_eq(Builtins.TOOL_SIDEBAR_WIDTH, Profile4.RIGHT_WIDTH, "UI4 unchanged")
	check_eq(Builtins.TOOL_OPTIONS_COLUMN_WIDTH, Migration.TOOL_OPTIONS_WIDTH, "UI1 remains 56px")
	check_eq(definition.minimum_size.x, 248.0, "UI3 advanced options have a usable width")
	check_eq(definition.preferred_size.x, 300.0, "UI3 advanced options default to 300px")
	check_eq(definition.maximum_size.x, 440.0, "UI3 advanced options can be resized")
	check_true(not definition.is_horizontal_resize_locked(), "full options resize horizontally")

	# Recreate the previous version's saved 56px module, then upgrade it.
	definition.minimum_size.x = Builtins.TOOL_OPTIONS_COLUMN_WIDTH
	definition.preferred_size.x = Builtins.TOOL_OPTIONS_COLUMN_WIDTH
	var old_rect := Rect2(Vector2(130.0, 60.0), Vector2(56.0, 400.0))
	check_true(surface.float_module(Builtins.UI3_TOOL_OPTIONS_ID, old_rect), "old layout loads")
	definition.minimum_size.x = 248.0
	definition.preferred_size.x = 300.0
	check_true(profile._ensure_options_module_placement(), "old options are normalized")
	var module := manager.get_instance(Builtins.UI3_TOOL_OPTIONS_ID)
	module.apply_visual_theme(WorkspaceVisualTheme.new(), &"floating")
	profile._set_ui3_module_chrome_visible(false)
	check_true(module.is_header_chrome_visible(), "detail window retains drag header")
	check_true(module.get_header_height() > 0.0, "detail window has a touch header")
	check_eq(
		surface.get_floating_rect(Builtins.UI3_TOOL_OPTIONS_ID).size.x,
		248.0,
		"legacy 56px options expand to the new minimum",
	)
	check_eq(
		surface.get_floating_rect(Builtins.UI3_TOOL_OPTIONS_ID).size.y,
		old_rect.size.y,
		"old window height remains unchanged",
	)
	check_true(surface.collapse_module(Builtins.UI3_TOOL_OPTIONS_ID), "legacy fold loads")
	check_true(profile._ensure_options_module_placement(), "old collapsed window unfolds")
	check_eq(
		surface.get_module_placement(Builtins.UI3_TOOL_OPTIONS_ID),
		WorkspaceSurface.Placement.FLOATING,
		"advanced options restore expanded",
	)
	check_eq(
		surface.get_floating_rect(Builtins.UI3_TOOL_OPTIONS_ID).size.x,
		248.0,
		"restored legacy window maintains minimum readable width",
	)
	root.queue_free()
	await tree.process_frame


func teardown() -> void:
	for tool in _spawned_tools:
		if is_instance_valid(tool):
			tool.queue_free()
	_spawned_tools.clear()


func test_ui3_compact_layout_survives_live_pencil_tool() -> void:
	var tool := await _spawn_tool("Pencil")
	var original_order := _child_names(tool)
	var opacity := tool.get_node("Opacity") as ValueSlider
	var initial_opacity_width := opacity.custom_minimum_size.x
	var initial_opacity_flags := opacity.size_flags_horizontal
	var initial_color_visible := tool.color_rect.visible
	tool.set_compact_option_layout(true)
	await tree.process_frame
	check_eq(tool.columns, 1, "live Pencil Tool Options must survive UI3 vertical compaction")
	check_eq(
		opacity.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "UI3 expands the active option"
	)
	check_eq(
		opacity.custom_minimum_size.x,
		BaseTool.SIDEBAR_CONTROL_WIDTH,
		"UI3 uses 54px slider footprint"
	)
	check_true(not tool.color_rect.visible, "UI3 hides the legacy tool color strip")
	# Newly visible groups must not initiate a second layout capture or reorder.
	var dither_settings := tool.get_node("DitherSettings") as VBoxContainer
	dither_settings.visible = true
	await tree.process_frame
	check_eq(
		_child_names(tool),
		original_order,
		"UI3 compact must preserve Pencil child order while the Container is live",
	)
	for _refresh in 8:
		tool.set_compact_option_layout(true)
		await tree.process_frame
	check_eq(
		_child_names(tool),
		original_order,
		"repeated UI3 refreshes must never reorder live Pencil controls",
	)
	tool.set_compact_option_layout(false)
	await tree.process_frame
	check_eq(tool.columns, 1, "Pencil Tool Options must restore its original single-column layout")
	check_eq(
		opacity.custom_minimum_size.x,
		initial_opacity_width,
		"UI3 must restore slider minimum width"
	)
	check_eq(
		opacity.size_flags_horizontal, initial_opacity_flags, "UI3 must restore slider size flags"
	)
	check_eq(
		tool.color_rect.visible, initial_color_visible, "UI3 must restore the original color strip"
	)
	check_eq(
		_child_names(tool),
		original_order,
		"leaving UI3 compact must restore styling without moving Pencil controls",
	)


func test_ui3_compact_layout_survives_nested_gradient_grid() -> void:
	var tool := await _spawn_tool("Gradient")
	tool.set_compact_option_layout(true)
	await tree.process_frame
	var options := tool.get_node("GradientOptions") as GridContainer
	check_eq(options.columns, 1, "nested Gradient properties must stack vertically in UI3")
	tool.set_compact_option_layout(false)
	await tree.process_frame
	check_eq(options.columns, 1, "nested Gradient properties keep the intended vertical layout")


func test_stacked_tool_options_are_built_before_scene_entry() -> void:
	var definition: Tools.Tool = Tools.tools["Pencil"]
	var tool := definition.instantiate_scene() as BaseTool
	tool.name = "Pencil"
	var slot := Tools.Slot.new("Left tool")
	slot.button = MOUSE_BUTTON_LEFT
	slot.color = Color.BLACK
	tool.tool_slot = slot
	_spawned_tools.append(tool)
	tool.prepare_stacked_option_layout()
	var original_order := _child_names(tool)
	check_true(
		tool.get_node_or_null("OpacityOptionLabel") is Label,
		"stacked opacity label should exist before the tool enters the tree",
	)
	tree.root.add_child(tool)
	await tree.process_frame
	check_eq(
		_child_names(tool),
		original_order,
		"BaseTool._ready must not insert or reorder live options after preparation",
	)
	tool.prepare_stacked_option_layout()
	check_eq(
		_child_names(tool), original_order, "preparing already prepared options must be a no-op"
	)
	var source := FileAccess.get_file_as_string("res://src/Autoload/Tools.gd")
	var set_pos := source.find("func set_tool(")
	var prepare_pos := source.find("tool_options.prepare_stacked_option_layout()", set_pos)
	var attach_pos := source.find("panel.add_child(slot.tool_node)", set_pos)
	check_true(
		prepare_pos > set_pos and attach_pos > prepare_pos,
		"runtime Tools.set_tool must prepare option children before attaching the live panel",
	)
	tool.queue_free()
	_spawned_tools.erase(tool)
	await tree.process_frame


func _spawn_tool(tool_name: String) -> BaseTool:
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
	return tool


func _child_names(tool: BaseTool) -> PackedStringArray:
	var names := PackedStringArray()
	for child in tool.get_children():
		names.append(child.name)
	return names


func test_ui3_quick_pencil_slider_mirrors_live_tool_value() -> void:
	var tool := await _spawn_tool("Pencil")
	var root := Control.new()
	tree.root.add_child(root)
	var profile := Profile3.new()
	root.add_child(profile)
	profile.ui_root = root
	check_true(profile._create_quick_bar(), "quick controls can be created on canvas")
	profile._add_quick_slider(tool, ^"Brush/BrushSize", "Size", true)
	var group := profile._quick_controls.get_child(0) as VBoxContainer
	var slider := group.get_child(1) as VSlider
	var actual := tool.get_node("Brush/BrushSize") as Range
	slider.value = 8.0
	check_eq(actual.value, 8.0, "UI3 quick slider edits original Pencil size")
	actual.value = 12.0
	check_eq(slider.value, 12.0, "UI3 quick slider follows original size updates")
	profile._clear_quick_bindings()
	root.queue_free()
	await tree.process_frame


func test_ui3_quick_bucket_modes_drive_existing_source_buttons() -> void:
	var tool := await _spawn_tool("Bucket")
	var root := Control.new()
	tree.root.add_child(root)
	var profile := Profile3.new()
	root.add_child(profile)
	profile.ui_root = root
	check_true(profile._create_quick_bar(), "bucket quick controls can be created")
	profile._add_quick_modes(tool, ^"FillAreaOptions")
	var mode2 := tool.get_node("FillAreaOptions/SimilarColors") as BaseButton
	profile._on_quick_mode_pressed(mode2)
	await tree.process_frame
	check_true(mode2.button_pressed, "source Bucket selects matching-color fill")
	var proxy := (profile._quick_mode_pairs[1] as Dictionary).get("proxy") as BaseButton
	check_true(proxy.button_pressed, "UI3 mode button follows the Bucket selection")
	profile._clear_quick_bindings()
	root.queue_free()
	await tree.process_frame
