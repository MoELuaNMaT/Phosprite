extends "res://tests/test_base.gd"

const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const Manager := preload("res://src/UI/Workspace/WorkspaceModuleManager.gd")
const DockHost := preload("res://src/UI/Workspace/WorkspaceDockHost.gd")
const Surface := preload("res://src/UI/Workspace/WorkspaceSurface.gd")
const Store := preload("res://src/UI/Workspace/WorkspaceLayoutStore.gd")
const Migration := preload("res://src/UI/Workspace/WorkspaceEditorMigration.gd")
const Interaction := preload("res://src/UI/Workspace/WorkspaceInteractionController.gd")
const VisualTheme := preload("res://src/UI/Workspace/WorkspaceVisualTheme.gd")


func _make_live_fixture(config_cache: ConfigFile = null) -> Dictionary:
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
	var config := config_cache
	if config == null:
		config = ConfigFile.new()
	check_true(store.setup(surface, config), "layout store should initialize")

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


func test_touch_collapse_ignores_emulated_mouse_duplicate() -> void:
	var fixture := _make_live_fixture()
	var root := fixture["root"] as Control
	var manager := fixture["manager"] as WorkspaceModuleManager
	var surface := fixture["surface"] as WorkspaceSurface
	var interaction := Interaction.new()
	root.add_child(interaction)
	check_true(interaction.setup(manager, surface), "interaction controller should initialize")
	tree.root.add_child(root)
	await tree.process_frame
	await tree.process_frame

	var preview: WorkspaceModule = manager.get_instance(Builtins.PREVIEW_ID)
	var collapse_point := Vector2(preview.size.x - 8.0, 8.0)

	var touch := InputEventScreenTouch.new()
	touch.device = 0
	touch.index = 0
	touch.pressed = true
	touch.position = collapse_point
	preview.gui_input.emit(touch)
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		WorkspaceSurface.Placement.COLLAPSED,
		"physical touch should collapse the module once"
	)

	var emulated_mouse := InputEventMouseButton.new()
	emulated_mouse.device = InputEvent.DEVICE_ID_EMULATION
	emulated_mouse.button_index = MOUSE_BUTTON_LEFT
	emulated_mouse.pressed = true
	emulated_mouse.position = collapse_point
	preview.gui_input.emit(emulated_mouse)
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		WorkspaceSurface.Placement.COLLAPSED,
		"emulated mouse press from the same touch must not immediately restore the module"
	)

	preview.gui_input.emit(touch)
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		WorkspaceSurface.Placement.DOCKED,
		"second physical touch should restore the module once"
	)
	preview.gui_input.emit(emulated_mouse)
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		WorkspaceSurface.Placement.DOCKED,
		"emulated mouse press must not immediately collapse the restored module"
	)

	check_true(
		surface.dock_module(
			Builtins.PREVIEW_ID, WorkspaceDockLayout.DockZone.BOTTOM, 1, Vector2(220.0, 140.0)
		),
		"Preview should move beside the expanded Timeline"
	)
	await tree.process_frame
	await tree.process_frame
	var timeline: WorkspaceModule = manager.get_instance(Builtins.TIMELINE_ID)
	check_true(
		not timeline.is_content_collapsed(),
		"Timeline must remain expanded while its Bottom Dock sibling is tested"
	)

	collapse_point = Vector2(preview.size.x - 8.0, 8.0)
	touch.position = collapse_point
	emulated_mouse.position = collapse_point
	preview.gui_input.emit(touch)
	preview.gui_input.emit(emulated_mouse)
	await tree.process_frame
	await tree.process_frame
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		WorkspaceSurface.Placement.COLLAPSED,
		"Bottom Dock sibling must collapse independently while Timeline is expanded"
	)
	check_almost_eq(
		preview.size.y,
		preview.get_header_height(),
		0.01,
		"Bottom Dock sibling must remain at header height while Timeline stays expanded"
	)

	preview.gui_input.emit(touch)
	preview.gui_input.emit(emulated_mouse)
	await tree.process_frame
	await tree.process_frame
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		WorkspaceSurface.Placement.DOCKED,
		"Bottom Dock sibling must restore independently while Timeline is expanded"
	)
	check_true(
		not preview.is_content_collapsed(),
		"Bottom Dock sibling content must stay restored after the emulated duplicate event"
	)

	tree.root.remove_child(root)
	_free_fixture(fixture)


func test_persisted_collapsed_modules_restart_hidden_and_restore_without_reparenting() -> void:
	var config := ConfigFile.new()
	var first := _make_live_fixture(config)
	var first_manager := first["manager"] as WorkspaceModuleManager
	var first_surface := first["surface"] as WorkspaceSurface
	var first_store := first["store"] as WorkspaceLayoutStore

	for module_id in [Builtins.PREVIEW_ID, Builtins.TOOLS_ID]:
		var module := first_manager.get_instance(module_id)
		var content := module.get_content()
		check_true(first_surface.collapse_module(module_id), "module should collapse before save")
		check_eq(
			content.get_parent(),
			module,
			"collapsed content must stay parented to its WorkspaceModule before save"
		)
		check_true(not content.visible, "collapsed content must be hidden before save")
	check_true(first_store.save_current_layout(false), "collapsed layout should persist to ConfigFile")
	_free_fixture(first)

	var second := _make_live_fixture(config)
	var second_manager := second["manager"] as WorkspaceModuleManager
	var second_surface := second["surface"] as WorkspaceSurface

	for module_id in [Builtins.PREVIEW_ID, Builtins.TOOLS_ID]:
		var module := second_manager.get_instance(module_id)
		var content := module.get_content()
		check_eq(
			second_surface.get_module_placement(module_id),
			WorkspaceSurface.Placement.COLLAPSED,
			"restart should restore the saved collapsed placement"
		)
		check_eq(
			content.get_parent(),
			module,
			"restored collapsed content must remain inside its WorkspaceModule"
		)
		check_true(
			not content.visible,
			"restored collapsed content must stay hidden instead of drawing at screen origin"
		)
		check_true(second_surface.restore_module(module_id), "saved collapsed module should expand")
		check_eq(
			content.get_parent(),
			module,
			"expanding after restart must not reparent the live panel content"
		)
		check_true(content.visible, "expanding after restart should reveal the original content")
	_free_fixture(second)


func test_tools_scene_is_configured_to_fill_workspace_width() -> void:
	var packed := load("res://src/UI/ToolsPanel/Tools.tscn") as PackedScene
	check_true(packed != null, "Tools scene should load")
	var tools := packed.instantiate() as ScrollContainer
	check_true(tools != null, "Tools scene root should remain a ScrollContainer")
	check_eq(
		tools.size_flags_horizontal,
		Control.SIZE_EXPAND_FILL,
		"Tools root should expand to the Workspace module width"
	)
	check_eq(
		tools.size_flags_vertical,
		Control.SIZE_EXPAND_FILL,
		"Tools root should expand to the Workspace module height"
	)
	var panel := tools.get_node("PanelContainer") as PanelContainer
	check_eq(
		panel.size_flags_horizontal,
		Control.SIZE_EXPAND_FILL,
		"Tools panel should use all horizontal space offered by the window"
	)
	check_eq(
		panel.size_flags_vertical,
		Control.SIZE_EXPAND_FILL,
		"Tools panel should use all vertical space offered by the window"
	)
	var flow := tools.get_node("PanelContainer/ToolButtons") as HFlowContainer
	check_true(flow != null, "Tools should keep HFlowContainer adaptive wrapping")
	check_eq(
		flow.size_flags_horizontal,
		Control.SIZE_EXPAND_FILL,
		"Tool button flow should expand to the available window width before wrapping"
	)
	tools.free()


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
