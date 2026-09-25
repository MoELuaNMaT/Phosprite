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


func test_profile_3_contract_matches_procreate_taskbar() -> void:
	check_eq(UIProfile3.BRUSH_TOOL, &"Pencil", "profile 3 brush entry must use Pencil")
	check_eq(UIProfile3.ERASER_TOOL, &"Eraser", "profile 3 eraser entry must use Eraser")
	check_true(UIProfile3.is_primary_tool(&"Pencil"), "Pencil should be a primary taskbar tool")
	check_true(UIProfile3.is_primary_tool(&"Eraser"), "Eraser should be a primary taskbar tool")
	check_false(
		UIProfile3.is_primary_tool(&"Move"),
		"Move and the remaining toolbar tools should stay inside Other Tools",
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


func test_unused_normal_profile_does_not_inherit_profile_3_composition() -> void:
	var fixture := _make_live_fixture()
	var surface := fixture["surface"] as WorkspaceSurface
	var store := fixture["store"] as WorkspaceLayoutStore
	var controller := _make_controller(fixture)

	var profile_one_tools := surface.get_module_placement(Builtins.TOOLS_ID)
	var profile_one_palette := surface.get_module_placement(Builtins.PALETTE_ID)
	check_true(store.save_current_layout(false), "profile 1 baseline should persist")
	check_true(controller.switch_profile(3), "profile 3 should activate")
	check_false(store.has_layout_slot(4), "profile 4 should still be unused")
	check_true(
		controller.switch_profile(4), "first switch from profile 3 to profile 4 should succeed"
	)
	check_eq(
		surface.get_module_placement(Builtins.TOOLS_ID),
		profile_one_tools,
		"profile 4 must seed normal Tools instead of profile 3 parking",
	)
	check_eq(
		surface.get_module_placement(Builtins.PALETTE_ID),
		profile_one_palette,
		"profile 4 must seed normal Palette instead of profile 3 parking",
	)
	_free_fixture(fixture)
