extends "res://tests/test_base.gd"

const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const Manager := preload("res://src/UI/Workspace/WorkspaceModuleManager.gd")
const DockHost := preload("res://src/UI/Workspace/WorkspaceDockHost.gd")
const Surface := preload("res://src/UI/Workspace/WorkspaceSurface.gd")
const Store := preload("res://src/UI/Workspace/WorkspaceLayoutStore.gd")
const Migration := preload("res://src/UI/Workspace/WorkspaceEditorMigration.gd")
const UIProfileController := preload("res://src/UI/Workspace/WorkspaceUIProfileController.gd")
const UIProfile3 := preload("res://src/UI/Workspace/WorkspaceUIProfile3.gd")


func _make_live_fixture() -> Dictionary:
	var root := Control.new()
	root.size = Vector2(1200.0, 800.0)
	var legacy := DockableContainer.new()
	legacy.name = &"DockableContainer"
	legacy.size = root.size
	root.add_child(legacy)

	var main_canvas := Control.new()
	main_canvas.name = &"Main Canvas"
	legacy.add_child(main_canvas)
	var tabs := PanelContainer.new()
	tabs.name = &"TabsContainer"
	tabs.custom_minimum_size = Vector2(0.0, 32.0)
	main_canvas.add_child(tabs)

	var left_tool_options := ScrollContainer.new()
	left_tool_options.name = &"Left Tool Options"
	left_tool_options.custom_minimum_size = Vector2(72.0, 72.0)
	legacy.add_child(left_tool_options)
	var left_panel := MarginContainer.new()
	left_panel.name = &"LeftPanelContainer"
	left_panel.custom_minimum_size = Vector2(56.0, 0.0)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_tool_options.add_child(left_panel)

	var legacy_palette := Control.new()
	legacy_palette.name = &"Palettes"
	legacy_palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legacy_palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	legacy.add_child(legacy_palette)
	var legacy_color_picker := Control.new()
	legacy_color_picker.name = &"Color Picker"
	legacy_color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legacy_color_picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	legacy.add_child(legacy_color_picker)

	for module_id in Builtins.get_live_panel_ids():
		if module_id == Builtins.PALETTE_ID:
			continue
		var panel: Control
		if module_id == Builtins.TOOLS_ID:
			var tools := ScrollContainer.new()
			tools.name = Builtins.get_live_panel_node_name(module_id)
			tools.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			var palette := PanelContainer.new()
			palette.name = &"PanelContainer"
			palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
			tools.add_child(palette)
			var flow := HFlowContainer.new()
			flow.name = &"ToolButtons"
			flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			palette.add_child(flow)
			panel = tools
		else:
			panel = Control.new()
			panel.name = Builtins.get_live_panel_node_name(module_id)
		legacy.add_child(panel)

	var manager := Manager.new()
	root.add_child(manager)
	check_true(
		Builtins.register_defaults(manager), "built-in Workspace definitions should register"
	)

	var host := DockHost.new()
	host.name = &"WorkspaceDockHost"
	host.size = root.size
	root.add_child(host)
	check_true(host.setup(manager), "dock host should initialize")

	var surface := Surface.new()
	root.add_child(surface)
	check_true(surface.setup(manager, host), "surface should initialize")

	var store := Store.new()
	root.add_child(store)
	check_true(store.setup(surface, ConfigFile.new()), "layout store should initialize")

	var migration := Migration.new()
	root.add_child(migration)
	check_true(
		migration.setup(root, legacy, manager, surface, store),
		"live editor migration should complete transactionally"
	)
	check_true(
		migration.merge_left_tool_options_after_startup(),
		"fixture should simulate post-startup Left Tool Options merge"
	)
	return {
		"root": root,
		"manager": manager,
		"surface": surface,
		"store": store,
		"migration": migration,
	}


func _free_fixture(fixture: Dictionary) -> void:
	var manager := fixture["manager"] as WorkspaceModuleManager
	manager.destroy_all_modules()
	(fixture["root"] as Control).free()


func _make_controller(fixture: Dictionary) -> WorkspaceUIProfileController:
	var root := fixture["root"] as Control
	var migration := fixture["migration"] as WorkspaceEditorMigration
	var store := fixture["store"] as WorkspaceLayoutStore
	var menu := PopupMenu.new()
	root.add_child(menu)
	var controller := UIProfileController.new()
	root.add_child(controller)
	check_true(controller.setup(menu, migration, store), "UI profile controller should initialize")
	return controller


func test_profile_3_uses_supported_button_properties() -> void:
	var source := FileAccess.get_file_as_string("res://src/UI/Workspace/WorkspaceUIProfile3.gd")
	check_true(
		not source.contains(".icon_max_width"),
		"Godot 4.7 Button has no icon_max_width property; assigning it aborts UI3 toolbar creation",
	)


func test_profile_3_contract_matches_procreate_taskbar() -> void:
	check_eq(UIProfile3.BRUSH_TOOL, &"Pencil", "profile 3 brush entry must use Pencil")
	check_eq(UIProfile3.ERASER_TOOL, &"Eraser", "profile 3 eraser entry must use Eraser")
	check_true(UIProfile3.is_primary_tool(&"Pencil"), "Pencil should be a primary taskbar tool")
	check_true(UIProfile3.is_primary_tool(&"Eraser"), "Eraser should be a primary taskbar tool")
	check_true(
		not UIProfile3.is_primary_tool(&"Move"),
		"Move should remain a normal first-level tool rather than a Pencil/Eraser primary",
	)


func test_existing_slot_3_is_upgraded_to_procreate_layout_once() -> void:
	var fixture := _make_live_fixture()
	var surface := fixture["surface"] as WorkspaceSurface
	var store := fixture["store"] as WorkspaceLayoutStore

	check_true(store.save_current_layout(false), "profile 1 baseline should persist")
	check_true(store.set_active_layout_slot(3), "test should seed legacy slot 3")
	check_true(store.save_current_layout(false), "legacy slot 3 snapshot should exist")
	check_eq(
		store.get_ui_profile_version(3), 0, "legacy slot 3 should have no implementation version"
	)
	check_true(
		store.set_active_layout_slot(1), "profile 1 should be active before controller setup"
	)

	var controller := _make_controller(fixture)
	check_true(controller.switch_profile(3), "existing slot 3 should upgrade successfully")
	check_eq(
		store.get_ui_profile_version(3),
		Migration.UI_PROFILE_3_LAYOUT_VERSION,
		"profile 3 implementation version should persist after upgrade",
	)
	var preview_rect := surface.get_floating_rect(Builtins.PREVIEW_ID)
	check_eq(
		preview_rect.position,
		surface.get_floating_bounds().position + UIProfile3.PREVIEW_MARGIN,
		"legacy slot 3 should receive the Procreate upper-left Preview default exactly once",
	)
	_free_fixture(fixture)


func test_profile_3_parks_tools_and_palette_and_defaults_preview_upper_left() -> void:
	var fixture := _make_live_fixture()
	var surface := fixture["surface"] as WorkspaceSurface
	var store := fixture["store"] as WorkspaceLayoutStore
	var controller := _make_controller(fixture)

	var profile_one_tools := surface.get_module_placement(Builtins.TOOLS_ID)
	var profile_one_palette := surface.get_module_placement(Builtins.PALETTE_ID)
	check_ne(profile_one_tools, WorkspaceSurface.Placement.NONE, "profile 1 should own Tools")
	check_ne(profile_one_palette, WorkspaceSurface.Placement.NONE, "profile 1 should own Palette")
	check_true(store.save_current_layout(false), "profile 1 baseline should persist")

	check_true(controller.switch_profile(3), "profile 3 should activate")
	for module_id in [
		Builtins.TOOLS_ID,
		Builtins.PALETTE_ID,
		Builtins.RIGHT_TOOL_OPTIONS_ID,
	]:
		check_eq(
			surface.get_module_placement(module_id),
			WorkspaceSurface.Placement.NONE,
			"profile 3 should remove standalone workspace chrome for its taskbar modules",
		)
		check_true(
			surface.is_module_parked(module_id),
			"profile 3 should park taskbar-backed modules rather than destroy them",
		)

	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		WorkspaceSurface.Placement.FLOATING,
		"profile 3 should keep Preview as a floating module",
	)
	var preview_rect := surface.get_floating_rect(Builtins.PREVIEW_ID)
	var bounds := surface.get_floating_bounds()
	check_eq(
		preview_rect.position,
		bounds.position + UIProfile3.PREVIEW_MARGIN,
		"first profile 3 activation should place Preview in the upper-left",
	)

	check_true(controller.switch_profile(1), "leaving profile 3 should restore profile 1")
	check_eq(
		surface.get_module_placement(Builtins.TOOLS_ID),
		profile_one_tools,
		"profile 1 Tools placement must survive profile 3",
	)
	check_eq(
		surface.get_module_placement(Builtins.PALETTE_ID),
		profile_one_palette,
		"profile 1 Palette placement must survive profile 3",
	)
	_free_fixture(fixture)


func test_ui4_uses_its_own_fixed_panes_after_switching_from_ui3() -> void:
	var fixture := _make_live_fixture()
	var surface := fixture["surface"] as WorkspaceSurface
	var store := fixture["store"] as WorkspaceLayoutStore
	var controller := _make_controller(fixture)

	check_true(store.save_current_layout(false), "profile 1 baseline should persist")
	check_true(controller.switch_profile(3), "profile 3 should activate")
	check_true(not store.has_layout_slot(4), "UI4 has no saved layout yet")
	check_true(controller.switch_profile(4), "switching from UI3 to UI4 should succeed")
	check_eq(
		surface.get_module_placement(Builtins.TOOLS_ID),
		WorkspaceSurface.Placement.DOCKED,
		"UI4 Tools must dock rather than inherit UI3 parking",
	)
	check_eq(
		surface.get_module_placement(Builtins.PALETTE_ID),
		WorkspaceSurface.Placement.DOCKED,
		"UI4 Palette must dock rather than inherit UI3 parking",
	)
	check_eq(
		surface.dock_host.layout.get_module_zone(Builtins.TOOLS_ID),
		WorkspaceDockLayout.DockZone.RIGHT,
		"UI4 tool configuration docks on the right",
	)
	check_eq(
		surface.dock_host.layout.get_module_zone(Builtins.PALETTE_ID),
		WorkspaceDockLayout.DockZone.LEFT,
		"UI4 swatches and picker dock on the left",
	)
	_free_fixture(fixture)


func test_profile_3_tool_options_are_advanced_and_floating() -> void:
	var profile_source := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceUIProfile3.gd"
	)
	var content_scene := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/UI3ToolOptionsContent.tscn"
	)
	var builtins := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceBuiltinModules.gd"
	)
	check_has(
		profile_source,
		"_set_current_options_compact(false)",
		"UI3 must use the original complete settings instead of compacting their width",
	)
	check_has(
		profile_source,
		"left_tool_options.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED",
		"compact Tool Options must never require horizontal scrolling",
	)
	check_has(
		profile_source,
		"if control.visible:",
		"UI 3 must only reserve configuration space for controls that are actually visible",
	)
	check_has(
		content_scene,
		'[node name="FamilyChooser" type="HFlowContainer" parent="."]',
		"advanced tools retain the existing family chooser",
	)
	check_has(
		builtins,
		"ui3_tool_options.minimum_size = Vector2(208.0, 112.0)",
		"secondary tool options must be usable on a touch screen",
	)
	check_has(
		builtins,
		"ui3_tool_options.preferred_size = Vector2(260.0, 220.0)",
		"secondary options are a proper resizable floating window",
	)
	check_has(
		builtins,
		"ui3_tool_options.maximum_size = Vector2(360.0, 620.0)",
		"secondary options have room for larger dynamic tool forms",
	)


func test_profile_3_toolbar_and_config_panel_contract() -> void:
	var source := FileAccess.get_file_as_string("res://src/UI/Workspace/WorkspaceUIProfile3.gd")
	var builtins := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceBuiltinModules.gd"
	)
	check_has(
		builtins,
		'const UI3_TOOL_OPTIONS_ID := &"ui3_tool_options"',
		"UI 3 tool options must be a registered Workspace module",
	)
	check_has(
		source,
		"surface.float_module(Builtins.UI3_TOOL_OPTIONS_ID, rect)",
		"UI 3 tool options must use the Workspace floating-window system",
	)
	check_true(
		not source.contains("_options_popup: PanelContainer"),
		"UI 3 must not use an ad-hoc rigid PanelContainer for tool options",
	)
	check_has(
		source,
		"_refresh_config_panel.call_deferred()",
		"active tool changes must refresh the floating configuration panel",
	)
	var brush_index := source.find("_taskbar.add_child(_brush_button)")
	var eraser_index := source.find("_taskbar.add_child(_eraser_button)")
	var color_index := source.find("_taskbar.add_child(_color_button)")
	check_true(
		brush_index >= 0 and eraser_index > brush_index and color_index > eraser_index,
		"UI 3 taskbar must end with Pencil, Eraser, then the current color at the far right",
	)
	check_has(
		source,
		"_color_indicator.draw.connect(_draw_color_indicator)",
		"current color indicator must wire its draw callback",
	)
	check_true(
		not source.contains("UIProfile3OtherToolsPopup"),
		"UI 3 must no longer hide first-level tools inside an Other Tools popup",
	)
	check_has(
		source,
		'content.get_node_or_null(^"FamilyChooser")',
		"selection and shape family choices must live inside the Workspace config module",
	)


func test_profile_3_quick_controls_are_separate_from_full_options() -> void:
	var source := FileAccess.get_file_as_string("res://src/UI/Workspace/WorkspaceUIProfile3.gd")
	for expected in [
		"UIProfile3QuickControls",
		'_add_quick_slider(tool, ^"Brush/BrushSize"',
		"_hide_advanced_panel()",
		"surface.park_module(Builtins.UI3_TOOL_OPTIONS_ID)",
	]:
		check_has(source, expected, "UI3 exposes touch-first controls without losing tool state")
	check_has(
		source,
		"if not is_primary_tool(tool_name):",
		"only Pencil and Eraser may display the left strip",
	)
	check_true(
		not source.contains("MoreToolOptions") and not source.contains("UIProfile3ToolSettings"),
		"left More and redundant top gear must not duplicate the tool button entry",
	)
	check_has(
		source,
		"source.value_changed.connect(callback)",
		"quick sliders must track external tool value changes",
	)
	check_has(
		source,
		"source.value = value",
		"quick sliders must write into the existing tool option",
	)
	check_has(
		source,
		"_set_current_options_compact(false)\n\t_reparent_left_options(_options_host)",
		"UI3 no longer compacts the actual options when displaying them",
	)


func test_profile_3_slider_writes_to_existing_range_without_duplicate_state() -> void:
	var profile := UIProfile3.new()
	var source := HSlider.new()
	source.min_value = 1.0
	source.max_value = 64.0
	source.step = 1.0
	profile._on_quick_slider_changed(7.0, source)
	check_eq(source.value, 7.0, "quick control changes authoritative Range")
	profile._on_quick_slider_changed(0.0, source)
	check_eq(source.value, 1.0, "tool's own minimum value is honored")
	source.free()
	profile.free()


func test_profile_3_tool_options_are_dismissible_without_collapsing_titlebar() -> void:
	var scene := FileAccess.get_file_as_string("res://src/UI/Workspace/UI3ToolOptionsContent.tscn")
	check_true(
		not scene.contains('name="CloseOptions"'),
		"UI3 tool settings have no redundant Done button",
	)
	var source := FileAccess.get_file_as_string("res://src/UI/Workspace/WorkspaceUIProfile3.gd")
	check_has(
		source,
		"surface.park_module(Builtins.UI3_TOOL_OPTIONS_ID)",
		"closing detail window removes both content and its floating titlebar",
	)


func test_ui3_top_right_tool_icons_own_full_settings() -> void:
	var source := FileAccess.get_file_as_string("res://src/UI/Workspace/WorkspaceUIProfile3.gd")
	check_has(
		source,
		"_select_tool_and_toggle_options(tool_name)",
		"the Pencil and Eraser buttons use the shared tool-settings entry",
	)
	check_has(
		source,
		"_select_tool_and_toggle_options(target)",
		"all other first-level tool buttons use the same tool-settings entry",
	)
	check_has(
		source,
		"if already_selected and _advanced_open:",
		"tapping the current tool a second time closes the complete settings",
	)
	check_has(
		source,
		"_show_advanced_panel.call_deferred()",
		"switching tools opens settings after the new BaseTool is available",
	)
	check_true(
		not source.contains('current == &"CropTool" and not _advanced_open'),
		"changing to Crop through another route must not auto-open a floating window",
	)


func test_ui3_tool_options_close_on_blank_canvas_and_content_fit_contract() -> void:
	var source := FileAccess.get_file_as_string("res://src/UI/Workspace/WorkspaceUIProfile3.gd")
	check_has(
		source,
		"func _is_blank_canvas_point(pointer: Vector2) -> bool:",
		"outside clicks are tested against the canvas, not arbitrary window bounds"
	)
	check_has(source, "_hide_advanced_panel()", "outside tap hides the original Workspace module")
	check_has(source, "_resize_advanced_to_content()", "tool content controls popup height")
	check_has(
		source,
		"current.minimum_size_changed.connect(",
		"expanded and collapsed tool settings must resize the popup"
	)
