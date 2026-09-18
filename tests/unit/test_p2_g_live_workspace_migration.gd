extends "res://tests/test_base.gd"

const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const Manager := preload("res://src/UI/Workspace/WorkspaceModuleManager.gd")
const DockHost := preload("res://src/UI/Workspace/WorkspaceDockHost.gd")
const Surface := preload("res://src/UI/Workspace/WorkspaceSurface.gd")
const Store := preload("res://src/UI/Workspace/WorkspaceLayoutStore.gd")
const Migration := preload("res://src/UI/Workspace/WorkspaceEditorMigration.gd")
const Interaction := preload("res://src/UI/Workspace/WorkspaceInteractionController.gd")
const VisualTheme := preload("res://src/UI/Workspace/WorkspaceVisualTheme.gd")


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

	var live_controls: Dictionary = {}
	for module_id in Builtins.get_live_panel_ids():
		var panel := Control.new()
		panel.name = Builtins.get_live_panel_node_name(module_id)
		legacy.add_child(panel)
		live_controls[module_id] = panel

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
	return {
		"root": root,
		"legacy": legacy,
		"main_canvas": main_canvas,
		"controls": live_controls,
		"manager": manager,
		"host": host,
		"surface": surface,
		"store": store,
		"migration": migration,
	}


func _free_fixture(fixture: Dictionary) -> void:
	var manager := fixture["manager"] as WorkspaceModuleManager
	manager.destroy_all_modules()
	(fixture["root"] as Control).free()


func test_live_migration_adopts_existing_controls_and_promotes_main_canvas() -> void:
	var fixture := _make_live_fixture()
	var root := fixture["root"] as Control
	var legacy := fixture["legacy"] as DockableContainer
	var main_canvas := fixture["main_canvas"] as Control
	var controls := fixture["controls"] as Dictionary
	var manager := fixture["manager"] as WorkspaceModuleManager
	var surface := fixture["surface"] as WorkspaceSurface

	check_true(not legacy.visible, "legacy DockableContainer should be hidden after migration")
	check_eq(main_canvas.get_parent(), root, "Main Canvas should become the stable central child")
	for module_id in Builtins.get_live_panel_ids():
		var module := manager.get_instance(module_id)
		check_true(module != null, "every live editor panel should have a managed module")
		check_eq(
			module.get_content(),
			controls[module_id],
			"migration must preserve the exact existing panel Control identity"
		)
		check_true(module.is_external_content(), "live panels should be marked as adopted content")

	check_eq(
		surface.get_module_placement(Builtins.TOOLS_ID),
		WorkspaceSurface.Placement.DOCKED,
		"Tools should participate in the default live Workspace layout"
	)
	check_eq(
		surface.get_module_placement(Builtins.TILES_ID),
		WorkspaceSurface.Placement.NONE,
		"context-only Tiles should not consume default Workspace geometry"
	)
	_free_fixture(fixture)


func test_dock_host_empty_space_passes_input_and_only_occupied_docks_shrink_canvas() -> void:
	var manager := Manager.new()
	var host := DockHost.new()
	Builtins.register_defaults(manager)
	host.size = Vector2(1000.0, 700.0)
	check_true(host.setup(manager), "dock host should initialize")
	check_eq(
		host.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Workspace root must pass Canvas input"
	)
	check_eq(
		host.get_content_rect(),
		Rect2(Vector2.ZERO, host.size),
		"empty docks must not reserve permanent Canvas space"
	)
	var left_snap: Rect2 = host.get_zone_rects()[WorkspaceDockLayout.DockZone.LEFT]
	check_eq(left_snap.size.x, host.EMPTY_ZONE_EXTENT, "empty left edge should retain a snap band")
	check_true(
		host.dock_module(
			Builtins.PREVIEW_ID, WorkspaceDockLayout.DockZone.LEFT, 0, Vector2(240.0, 180.0)
		),
		"Preview should dock for geometry validation"
	)
	check_eq(
		host.get_content_rect().position.x, 240.0, "occupied left dock should reserve its width"
	)
	check_eq(
		host.get_content_rect().size.x,
		760.0,
		"central Canvas width should shrink only by the occupied dock"
	)
	manager.destroy_all_modules()
	host.free()
	manager.free()


func test_docked_collapse_stays_in_place_and_out_of_bottom_tray() -> void:
	var fixture := _make_live_fixture()
	var root := fixture["root"] as Control
	var manager := fixture["manager"] as WorkspaceModuleManager
	var surface := fixture["surface"] as WorkspaceSurface
	var preview := manager.get_instance(Builtins.PREVIEW_ID)
	var preview_content := preview.get_content()
	var before_parent := preview.get_parent()
	var before_position := preview.position

	var interaction := Interaction.new()
	root.add_child(interaction)
	check_true(interaction.setup(manager, surface), "interaction controller should initialize")
	check_true(
		surface.collapse_module(Builtins.PREVIEW_ID), "docked Preview should collapse in place"
	)
	check_eq(
		preview.get_parent(),
		before_parent,
		"docked collapse must keep the adopted module in its original dock host"
	)
	check_eq(
		preview.position,
		before_position,
		"docked collapse must leave the title bar at the original position"
	)
	check_true(not preview_content.visible, "docked collapse should hide panel content")
	check_true(
		not interaction.get_tray().visible,
		"docked collapse must not create the legacy bottom text-button tray"
	)

	check_true(
		surface.restore_module(Builtins.PREVIEW_ID), "docked Preview should restore in place"
	)
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		WorkspaceSurface.Placement.DOCKED,
		"restore should return Preview to DOCKED placement"
	)
	check_eq(
		manager.get_instance(Builtins.PREVIEW_ID), preview, "restore must preserve module identity"
	)
	check_eq(preview.get_parent(), before_parent, "restore must not remount through another parent")
	check_eq(
		preview.position, before_position, "restore must not jump to the top-left before returning"
	)
	check_eq(preview.get_content(), preview_content, "restore must preserve live panel identity")
	check_true(preview_content.visible, "restore should reveal the original panel content")
	_free_fixture(fixture)


func test_floating_collapse_stays_in_place_and_out_of_bottom_tray() -> void:
	var fixture := _make_live_fixture()
	var root := fixture["root"] as Control
	var manager := fixture["manager"] as WorkspaceModuleManager
	var surface := fixture["surface"] as WorkspaceSurface
	var interaction := Interaction.new()
	root.add_child(interaction)
	check_true(interaction.setup(manager, surface), "interaction controller should initialize")
	var target_rect := Rect2(320.0, 180.0, 360.0, 240.0)
	check_true(surface.float_module(Builtins.PREVIEW_ID, target_rect), "Preview should float")
	var preview: WorkspaceModule = manager.get_instance(Builtins.PREVIEW_ID)
	var actual_float_rect := surface.get_floating_rect(Builtins.PREVIEW_ID)
	var before_position := preview.position
	var before_width := preview.size.x
	check_true(surface.collapse_module(Builtins.PREVIEW_ID), "floating Preview should collapse")
	check_true(
		surface.is_floating_collapsed(Builtins.PREVIEW_ID), "collapse should remain floating"
	)
	check_eq(
		preview.position, before_position, "collapsed bar should stay at its floating position"
	)
	check_eq(preview.size.x, before_width, "collapsed bar should keep its floating width")
	check_eq(
		surface.get_restore_state(Builtins.PREVIEW_ID).get("rect", Rect2()) as Rect2,
		actual_float_rect,
		"floating collapse should preserve the complete pre-collapse rectangle"
	)
	check_true(
		not interaction.get_tray().visible,
		"floating-origin collapse must not become a bottom tray text button"
	)
	check_true(surface.restore_module(Builtins.PREVIEW_ID), "collapsed floating bar should restore")
	check_eq(
		surface.get_floating_rect(Builtins.PREVIEW_ID),
		actual_float_rect,
		"restore should recover the complete pre-collapse rectangle"
	)
	_free_fixture(fixture)


func test_workspace_chrome_exposes_header_collapse_and_floating_resize_targets() -> void:
	var fixture := _make_live_fixture()
	var manager := fixture["manager"] as WorkspaceModuleManager
	var surface := fixture["surface"] as WorkspaceSurface
	var preview := manager.get_instance(Builtins.PREVIEW_ID)
	check_true(
		preview.is_header_drag_point(Vector2(8.0, 8.0)), "header should expose a drag target"
	)
	check_true(
		preview.is_collapse_point(Vector2(preview.size.x - 8.0, 8.0)),
		"header trailing edge should expose collapse"
	)
	check_true(
		surface.float_module(Builtins.PREVIEW_ID, Rect2(300.0, 180.0, 360.0, 240.0)),
		"Preview should float before resize validation"
	)
	preview.apply_visual_theme(VisualTheme.new(), &"floating")
	check_true(
		preview.is_resize_point(preview.size - Vector2(4.0, 4.0)),
		"floating panel should expose a bottom-right resize target"
	)
	_free_fixture(fixture)


func test_live_module_catalog_keeps_main_canvas_outside_workspace_modules() -> void:
	var ids := Builtins.get_live_panel_ids()
	check_true(ids.has(Builtins.PREVIEW_ID), "Preview should be a live Workspace module")
	check_true(ids.has(Builtins.PALETTE_ID), "Palette should be a live Workspace module")
	check_true(ids.has(Builtins.TIMELINE_ID), "Timeline should be a live Workspace module")
	check_true(ids.has(Builtins.TOOLS_ID), "Tools should be a live Workspace module")
	for module_id in ids:
		check_true(
			Builtins.get_live_panel_node_name(module_id) != "Main Canvas",
			"Main Canvas must remain the stable central editing surface"
		)


func test_live_ui_owns_restore_timing_and_window_menu_bridge() -> void:
	var ui_source := FileAccess.get_file_as_string("res://src/UI/UI.gd")
	var bridge_source := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceWindowMenuBridge.gd"
	)
	check_true(
		not ui_source.contains('workspace_layout_store.call_deferred(&"restore_current_layout")'),
		"P2-D hidden restore must not run before live panels are adopted"
	)
	check_true(
		ui_source.contains("workspace_migration.setup("),
		"UI should route live editor startup through the migration transaction"
	)
	check_true(
		bridge_source.contains("_disconnect_legacy_handlers"),
		"Workspace bridge should explicitly retire legacy Window handlers"
	)
	check_true(
		bridge_source.contains("Global.pixelorama_opened.disconnect(callable)"),
		"legacy DockableLayout startup application must be disconnected"
	)
