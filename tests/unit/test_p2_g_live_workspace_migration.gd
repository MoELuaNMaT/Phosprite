extends "res://tests/test_base.gd"

const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const Manager := preload("res://src/UI/Workspace/WorkspaceModuleManager.gd")
const DockHost := preload("res://src/UI/Workspace/WorkspaceDockHost.gd")
const Surface := preload("res://src/UI/Workspace/WorkspaceSurface.gd")
const Store := preload("res://src/UI/Workspace/WorkspaceLayoutStore.gd")
const Migration := preload("res://src/UI/Workspace/WorkspaceEditorMigration.gd")
const Interaction := preload("res://src/UI/Workspace/WorkspaceInteractionController.gd")
const VisualTheme := preload("res://src/UI/Workspace/WorkspaceVisualTheme.gd")
const ThemeController := preload("res://src/UI/Workspace/WorkspaceThemeController.gd")


func _make_live_fixture(
	config_cache: ConfigFile = null,
	preview_initially_visible := true,
	merge_tool_options_after_startup := true
) -> Dictionary:
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

	var live_controls: Dictionary = {}
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
		if module_id == Builtins.PREVIEW_ID:
			panel.visible = preview_initially_visible
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
	live_controls[Builtins.PALETTE_ID] = manager.get_instance(Builtins.PALETTE_ID).get_content()
	if merge_tool_options_after_startup:
		check_true(
			migration.merge_left_tool_options_after_startup(),
			"fixture should simulate post-startup Left Tool Options merge"
		)
	return {
		"root": root,
		"legacy": legacy,
		"main_canvas": main_canvas,
		"controls": live_controls,
		"left_tool_options": left_tool_options,
		"left_panel": left_panel,
		"legacy_palette": legacy_palette,
		"legacy_color_picker": legacy_color_picker,
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
		WorkspaceSurface.Placement.FLOATING,
		"Tools should start as a snapped floating Workspace panel",
	)
	check_eq(
		fixture["host"].layout.get_module_zone(Builtins.TOOLS_ID),
		WorkspaceDockLayout.DockZone.NONE,
		"Tools must not reserve a real dock zone",
	)
	check_eq(
		surface.get_module_placement(Builtins.TILES_ID),
		WorkspaceSurface.Placement.NONE,
		"context-only Tiles should not consume default Workspace geometry"
	)
	_free_fixture(fixture)


func test_project_tabs_are_promoted_to_full_width_second_row_and_canvas_ignores_dock_extents(
) -> void:
	var fixture := _make_live_fixture()
	var root := fixture["root"] as Control
	var main_canvas := fixture["main_canvas"] as Control
	var host := fixture["host"] as WorkspaceDockHost
	var surface := fixture["surface"] as WorkspaceSurface
	var tabs := root.get_node_or_null(^"TabsContainer") as Control
	check_true(tabs != null, "project tabs should be promoted out of Main Canvas")
	check_eq(tabs.get_parent(), root, "project tabs should live directly in the UI root")
	check_almost_eq(tabs.position.y, 0.0, 0.01, "project tabs should occupy the UI second row")
	check_almost_eq(tabs.size.x, root.size.x, 0.01, "project tabs should span the full UI width")
	check_almost_eq(
		main_canvas.position.y, tabs.size.y, 0.01, "Canvas should begin directly below project tabs"
	)
	var canvas_rect := Rect2(main_canvas.position, main_canvas.size)
	check_true(
		(
			surface
			. dock_module(
				Builtins.PREVIEW_ID,
				WorkspaceDockLayout.DockZone.RIGHT,
				0,
				Vector2(420.0, 240.0),
				{},
				true,
			)
		),
		"legacy right-dock requests should migrate Preview to a right-snapped floating rect",
	)
	await tree.process_frame
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		WorkspaceSurface.Placement.FLOATING,
		"legacy dock request must keep Preview floating",
	)
	check_eq(
		host.layout.get_module_zone(Builtins.PREVIEW_ID),
		WorkspaceDockLayout.DockZone.NONE,
		"floating Preview must not reserve dock geometry",
	)
	check_eq(
		Rect2(main_canvas.position, main_canvas.size),
		canvas_rect,
		"changing Dock extents must not resize or shift the background Canvas",
	)
	check_almost_eq(
		host.offset_top,
		tabs.size.y,
		0.01,
		"Workspace panels should start below the project-tabs row",
	)
	_free_fixture(fixture)


func test_context_hidden_panels_keep_scene_tree_lifecycle_without_layout_geometry() -> void:
	var fixture := _make_live_fixture()
	var root := fixture["root"] as Control
	var manager := fixture["manager"] as WorkspaceModuleManager
	var surface := fixture["surface"] as WorkspaceSurface
	var migration := fixture["migration"] as WorkspaceEditorMigration
	tree.root.add_child(root)
	await tree.process_frame

	var right_options := manager.get_instance(Builtins.RIGHT_TOOL_OPTIONS_ID)
	check_eq(
		surface.get_module_placement(Builtins.RIGHT_TOOL_OPTIONS_ID),
		WorkspaceSurface.Placement.FLOATING,
		"Right Tool Options starts as a floating panel before single-tool hiding",
	)
	check_true(
		migration.set_context_panel_visible(Builtins.RIGHT_TOOL_OPTIONS_ID, false),
		"single-tool hiding should park Right Tool Options",
	)
	check_eq(
		surface.get_module_placement(Builtins.RIGHT_TOOL_OPTIONS_ID),
		WorkspaceSurface.Placement.NONE,
		"parked context panels must not consume Workspace geometry",
	)
	check_true(
		surface.is_module_parked(Builtins.RIGHT_TOOL_OPTIONS_ID),
		"hidden Right Tool Options must remain mounted in the private context host",
	)
	check_true(
		right_options.is_inside_tree(),
		"hidden Right Tool Options must stay inside SceneTree for dynamic tool readiness",
	)
	check_true(
		right_options.get_content().is_inside_tree(),
		"the adopted Tool Options content must stay inside SceneTree while hidden",
	)
	check_true(
		not right_options.is_visible_in_tree(),
		"the parked module must remain visually hidden",
	)
	var dynamic_tool_child := Control.new()
	right_options.get_content().add_child(dynamic_tool_child)
	await tree.process_frame
	check_true(
		dynamic_tool_child.is_node_ready(),
		"a tool node added while its context panel is hidden must still execute _ready",
	)

	var tiles := manager.get_instance(Builtins.TILES_ID)
	check_eq(
		surface.get_module_placement(Builtins.TILES_ID),
		WorkspaceSurface.Placement.NONE,
		"Tiles begins as a context-only panel outside layout geometry",
	)
	check_true(
		migration.set_context_panel_visible(Builtins.TILES_ID, false),
		"an initially hidden context panel should also be parked",
	)
	check_true(
		surface.is_module_parked(Builtins.TILES_ID),
		"placement NONE must not mean outside SceneTree for live context panels",
	)
	check_true(tiles.is_inside_tree(), "parked Tiles module must be inside SceneTree")

	check_true(
		migration.set_context_panel_visible(Builtins.RIGHT_TOOL_OPTIONS_ID, true),
		"showing Right Tool Options should restore its previous floating placement",
	)
	check_eq(
		surface.get_module_placement(Builtins.RIGHT_TOOL_OPTIONS_ID),
		WorkspaceSurface.Placement.FLOATING,
		"restoring a parked context panel should recover its floating placement",
	)
	check_true(
		not surface.is_module_parked(Builtins.RIGHT_TOOL_OPTIONS_ID),
		"restored Right Tool Options must leave the hidden context host",
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


func test_default_floating_collapse_stays_in_place_and_out_of_bottom_tray() -> void:
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
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		WorkspaceSurface.Placement.FLOATING,
		"default Preview should already be floating",
	)
	check_true(surface.collapse_module(Builtins.PREVIEW_ID), "floating Preview should collapse")
	check_eq(preview.get_parent(), before_parent, "collapse must keep the floating parent")
	check_eq(
		preview.position, before_position, "collapsed title bar must stay at the snapped position"
	)
	check_true(not preview_content.visible, "collapse should hide panel content")
	check_true(
		not interaction.get_tray().visible,
		"floating collapse must not create the legacy bottom text-button tray",
	)

	check_true(
		surface.restore_module(Builtins.PREVIEW_ID), "floating Preview should restore in place"
	)
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		WorkspaceSurface.Placement.FLOATING,
		"restore should return Preview to FLOATING placement",
	)
	check_eq(
		manager.get_instance(Builtins.PREVIEW_ID), preview, "restore must preserve module identity"
	)
	check_eq(preview.get_parent(), before_parent, "restore must preserve the floating-layer parent")
	check_eq(preview.position, before_position, "restore must not jump through another placement")
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
	var emulated_mouse := InputEventMouseButton.new()
	emulated_mouse.device = InputEvent.DEVICE_ID_EMULATION
	emulated_mouse.button_index = MOUSE_BUTTON_LEFT
	emulated_mouse.pressed = true
	emulated_mouse.position = collapse_point

	preview.gui_input.emit(touch)
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		WorkspaceSurface.Placement.COLLAPSED,
		"physical touch should collapse the floating module once",
	)
	preview.gui_input.emit(emulated_mouse)
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		WorkspaceSurface.Placement.COLLAPSED,
		"emulated mouse press from the same touch must not immediately restore it",
	)

	preview.gui_input.emit(touch)
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		WorkspaceSurface.Placement.FLOATING,
		"second physical touch should restore the floating module once",
	)
	preview.gui_input.emit(emulated_mouse)
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		WorkspaceSurface.Placement.FLOATING,
		"emulated mouse press must not immediately collapse the restored float",
	)

	var bounds := surface.get_floating_bounds()
	check_true(
		surface.dock_module(
			Builtins.PREVIEW_ID, WorkspaceDockLayout.DockZone.BOTTOM, 1, Vector2(220.0, 140.0)
		),
		"legacy Bottom request should reposition Preview as a bottom-snapped float",
	)
	var bottom_rect := surface.get_floating_rect(Builtins.PREVIEW_ID)
	check_almost_eq(
		bottom_rect.end.y,
		bounds.end.y,
		0.01,
		"bottom snap must end at the editor area above Timeline",
	)
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		WorkspaceSurface.Placement.FLOATING,
		"bottom-snapped Preview must still be floating",
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
	check_true(
		first_store.save_current_layout(false), "collapsed layout should persist to ConfigFile"
	)
	_free_fixture(first)

	var second := _make_live_fixture(config, false)
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
		check_true(
			content.visible,
			"expanding after restart should reveal the original content even if legacy Preview starts hidden"
		)
	_free_fixture(second)


func test_tools_workspace_contract_is_a_compact_two_column_sidebar() -> void:
	var definitions := Builtins.create_definitions()
	var tools_definition: WorkspaceModuleDefinition
	for definition in definitions:
		if definition.module_id == Builtins.TOOLS_ID:
			tools_definition = definition
			break
	check_true(tools_definition != null, "Tools definition must exist")
	check_eq(
		tools_definition.minimum_size.x,
		104.0,
		"Tools sidebar should shrink to the two compact tool/config columns",
	)
	check_eq(
		tools_definition.preferred_size.x,
		108.0,
		"Tools sidebar should default to the compact no-horizontal-scroll width",
	)
	check_eq(
		tools_definition.maximum_size.x,
		120.0,
		"Tools sidebar should remain narrow instead of regaining large side padding",
	)
	var ui_scene := FileAccess.get_file_as_string("res://src/UI/UI.tscn")
	check_has(
		ui_scene,
		"custom_minimum_size = Vector2(56, 0)",
		"legacy LeftPanelContainer must fit inside the compact right column",
	)


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
	check_eq(
		tools.horizontal_scroll_mode,
		ScrollContainer.SCROLL_MODE_DISABLED,
		"Tools should wrap to the Workspace width instead of hiding buttons horizontally"
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
	var column := tools.get_node("PanelContainer/ToolButtons") as VBoxContainer
	check_true(column != null, "Tools should use one vertical ToolButtons column")
	check_eq(
		column.size_flags_horizontal,
		Control.SIZE_EXPAND_FILL,
		"Tool button column should use the available window width"
	)
	var button_scene := FileAccess.get_file_as_string("res://src/UI/ToolsPanel/ToolButton.tscn")
	check_has(
		button_scene,
		"custom_minimum_size = Vector2(32, 32)",
		"left-column tool buttons should be enlarged to 32px",
	)
	check_has(
		button_scene,
		"offset_left = -14.0",
		"tool icons should expand with the larger button while keeping a small inset",
	)
	tools.free()


func test_workspace_chrome_has_no_pop_out_and_keeps_multi_edge_resize_targets() -> void:
	var fixture := _make_live_fixture()
	var manager := fixture["manager"] as WorkspaceModuleManager
	var surface := fixture["surface"] as WorkspaceSurface
	var preview := manager.get_instance(Builtins.PREVIEW_ID)
	preview.apply_visual_theme(VisualTheme.new(), &"floating")
	check_true(
		preview.is_header_drag_point(Vector2(8.0, 8.0)),
		"floating header should remain directly draggable",
	)
	check_true(
		preview.is_collapse_point(Vector2(preview.size.x - 8.0, 8.0)),
		"header trailing edge should still expose collapse",
	)
	check_true(
		not preview.is_float_point(Vector2(preview.size.x - 42.0, 8.0)),
		"live floating panels must not expose the obsolete Pop-out target",
	)
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		WorkspaceSurface.Placement.FLOATING,
		"Preview must remain floating while resize handles are active",
	)
	check_eq(
		preview.get_resize_edges(Vector2(2.0, 120.0)),
		WorkspaceModule.ResizeEdge.LEFT,
		"floating panel should expose a left-edge resize target",
	)
	check_eq(
		preview.get_resize_edges(Vector2(preview.size.x - 2.0, 120.0)),
		WorkspaceModule.ResizeEdge.RIGHT,
		"floating panel should expose a right-edge resize target",
	)
	check_eq(
		preview.get_resize_edges(Vector2(preview.size.x * 0.5, 2.0)),
		WorkspaceModule.ResizeEdge.TOP,
		"floating panel should expose a top-edge resize target",
	)
	check_eq(
		preview.get_resize_edges(Vector2(preview.size.x * 0.5, preview.size.y - 2.0)),
		WorkspaceModule.ResizeEdge.BOTTOM,
		"floating panel should expose a bottom-edge resize target",
	)
	check_eq(
		preview.get_resize_edges(Vector2(2.0, preview.size.y - 2.0)),
		WorkspaceModule.ResizeEdge.LEFT | WorkspaceModule.ResizeEdge.BOTTOM,
		"lower-left corner should combine horizontal and vertical resize",
	)
	check_eq(
		preview.get_resize_edges(preview.size - Vector2(2.0, 2.0)),
		WorkspaceModule.ResizeEdge.RIGHT | WorkspaceModule.ResizeEdge.BOTTOM,
		"lower-right corner should combine horizontal and vertical resize",
	)
	_free_fixture(fixture)


func test_timeline_bottom_bar_is_full_width_without_moving_side_docks_to_screen_edge() -> void:
	var fixture := _make_live_fixture()
	var root := fixture["root"] as Control
	var host := fixture["host"] as WorkspaceDockHost
	tree.root.add_child(root)
	await tree.process_frame
	await tree.process_frame

	check_almost_eq(host.position.x, 0.0, 0.01, "Workspace host should span the full editor width")
	check_almost_eq(
		host.size.x, root.size.x, 0.01, "Workspace host should span the full editor width"
	)
	check_almost_eq(host.get_side_inset(), 8.0, 0.01, "side docks should retain the 8px inset")
	var left_rect: Rect2 = host.get_zone_rects()[WorkspaceDockLayout.DockZone.LEFT]
	var bottom_rect: Rect2 = host.get_zone_rects()[WorkspaceDockLayout.DockZone.BOTTOM]
	check_almost_eq(left_rect.position.x, 8.0, 0.01, "left dock should keep its visual inset")
	check_almost_eq(bottom_rect.position.x, 0.0, 0.01, "bottom bar must touch the left edge")
	check_almost_eq(
		bottom_rect.size.x, root.size.x, 0.01, "bottom bar must touch both screen edges"
	)

	tree.root.remove_child(root)
	_free_fixture(fixture)


func test_touch_workspace_drag_and_resize_capture_on_press_before_child_gui() -> void:
	var interaction_src := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceInteractionController.gd"
	)
	check_true(
		not interaction_src.contains("TOUCH_LONG_PRESS_MS"),
		"Workspace touch dragging must not depend on a long-press timer",
	)
	check_true(
		interaction_src.contains("_try_capture_workspace_resize(touch)"),
		"global input must attempt edge resize before child GUI can swallow the press",
	)
	check_true(
		interaction_src.contains("_try_capture_workspace_header_drag(touch)"),
		"global input must capture normal header drag on the initial touch press",
	)
	check_true(
		interaction_src.contains(
			"_begin_drag(module_id, _viewport_point_to_host(event.position), event.index)"
		),
		"header capture must open the drag transaction immediately on press",
	)
	check_true(
		interaction_src.contains(
			"_begin_resize(\n\t\tmodule_id,\n\t\t_viewport_point_to_host(event.position)"
		),
		"edge capture must open the resize transaction immediately on press",
	)

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

	var preview := manager.get_instance(Builtins.PREVIEW_ID)
	preview.apply_visual_theme(VisualTheme.new(), &"floating")
	var local_header_point := Vector2(20.0, preview.get_header_height() * 0.5)
	var viewport_point := preview.get_global_transform_with_canvas() * local_header_point
	var hit := interaction._top_workspace_module_at(viewport_point)
	check_eq(
		hit.get("module_id", &"") as StringName,
		Builtins.PREVIEW_ID,
		"global press hit-test must resolve the Workspace module without child GUI propagation",
	)
	check_eq(
		hit.get("module") as WorkspaceModule,
		preview,
		"global press hit-test must preserve the exact managed module identity",
	)

	tree.root.remove_child(root)
	_free_fixture(fixture)


func test_timeline_toolbar_has_direct_vertical_resize_intent_on_ipad() -> void:
	check_true(
		Interaction.timeline_header_resize_intent(Vector2(1.0, -8.0)),
		"a short vertical toolbar drag should resize without a long press",
	)
	check_true(
		not Interaction.timeline_header_resize_intent(Vector2(10.0, -2.0)),
		"horizontal toolbar movement must not be stolen as vertical resize",
	)
	var interaction_src := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceInteractionController.gd"
	)
	check_has(
		interaction_src,
		"_try_capture_timeline_header_resize",
		"Timeline resize must be recognized across the full Workspace header",
	)
	check_has(
		interaction_src,
		"WorkspaceModule.ResizeEdge.TOP",
		"Bottom Timeline drag must reuse the existing top-edge resize path",
	)


func test_timeline_position_is_locked_but_top_edge_height_resize_remains_available() -> void:
	var fixture := _make_live_fixture()
	var root := fixture["root"] as Control
	var manager := fixture["manager"] as WorkspaceModuleManager
	var surface := fixture["surface"] as WorkspaceSurface
	var host := fixture["host"] as WorkspaceDockHost
	tree.root.add_child(root)
	await tree.process_frame
	await tree.process_frame

	var timeline := manager.get_instance(Builtins.TIMELINE_ID) as WorkspaceModule
	check_true(
		not timeline.is_position_adjustment_enabled(),
		"Timeline migration must disable position adjustment",
	)
	check_true(
		not timeline.is_header_drag_point(Vector2(24.0, timeline.get_header_height() * 0.5)),
		"Timeline header must not start a Workspace move",
	)
	check_true(
		not timeline.is_float_point(
			Vector2(timeline.size.x - WorkspaceModule.INTERACTION_TARGET_SIZE * 1.5, 8.0)
		),
		"Timeline must hide and disable the pop-out position control",
	)
	check_eq(
		surface.get_docked_resize_edges(Builtins.TIMELINE_ID, Vector2(timeline.size.x * 0.5, 2.0)),
		WorkspaceModule.ResizeEdge.TOP,
		"Bottom Timeline must keep its top-edge height resize target",
	)
	check_eq(
		host.layout.get_module_size(Builtins.TIMELINE_ID).y,
		220.0,
		"Animation mode default Workspace height should be slightly taller",
	)

	tree.root.remove_child(root)
	_free_fixture(fixture)


func test_timeline_is_the_only_fixed_bottom_dock_and_cannot_float() -> void:
	var fixture := _make_live_fixture()
	var root := fixture["root"] as Control
	var main_canvas := fixture["main_canvas"] as Control
	var manager := fixture["manager"] as WorkspaceModuleManager
	var host := fixture["host"] as WorkspaceDockHost
	var surface := fixture["surface"] as WorkspaceSurface
	tree.root.add_child(root)
	await tree.process_frame
	await tree.process_frame

	var timeline := manager.get_instance(Builtins.TIMELINE_ID)
	var canvas_rect := Rect2(main_canvas.position, main_canvas.size)
	check_eq(
		surface.get_module_placement(Builtins.TIMELINE_ID),
		WorkspaceSurface.Placement.DOCKED,
		"Timeline must remain the one fixed live Workspace panel",
	)
	check_eq(
		host.layout.get_module_zone(Builtins.TIMELINE_ID),
		WorkspaceDockLayout.DockZone.BOTTOM,
		"Timeline must occupy the real Bottom Dock",
	)
	check_true(
		host.layout.is_module_region_fill(Builtins.TIMELINE_ID),
		"Timeline Bottom Dock must remain full-width Region Fill",
	)
	check_true(
		surface.float_module(Builtins.TIMELINE_ID, Rect2(180.0, 420.0, 760.0, 180.0)),
		"legacy float requests should normalize back into the fixed Timeline dock",
	)
	await tree.process_frame
	check_eq(
		surface.get_module_placement(Builtins.TIMELINE_ID),
		WorkspaceSurface.Placement.DOCKED,
		"Timeline must still be DOCKED after a float request",
	)
	check_eq(
		timeline.get_parent(),
		host.get_zone_host(WorkspaceDockLayout.DockZone.BOTTOM),
		"Timeline must remain parented by the Bottom Dock",
	)
	check_true(
		not surface.begin_module_drag(Builtins.TIMELINE_ID, Vector2(300.0, 440.0)),
		"fixed Timeline must not start a floating drag transaction",
	)
	check_eq(
		Rect2(main_canvas.position, main_canvas.size),
		canvas_rect,
		"fixed Bottom Timeline must continue overlaying the full-background Canvas",
	)

	tree.root.remove_child(root)
	_free_fixture(fixture)


func test_timeline_bottom_region_uses_integrated_bar_visual_state() -> void:
	var fixture := _make_live_fixture()
	var root := fixture["root"] as Control
	var manager := fixture["manager"] as WorkspaceModuleManager
	var surface := fixture["surface"] as WorkspaceSurface
	var theme_controller := ThemeController.new()
	root.add_child(theme_controller)
	check_true(
		theme_controller.setup(manager, surface),
		"theme controller should initialize for Timeline visual-state validation",
	)
	var source_theme := Theme.new()
	source_theme.default_font = ThemeDB.fallback_font
	source_theme.default_font_size = ThemeDB.fallback_font_size
	check_true(
		theme_controller.refresh(source_theme, Color("2b2b2b"), Color("8aa0df")),
		"theme refresh should apply Workspace visual states",
	)
	var timeline := manager.get_instance(Builtins.TIMELINE_ID) as WorkspaceModule
	check_eq(
		timeline.get_visual_state(),
		&"bottom_bar",
		"docked Bottom Region Timeline should use the integrated bottom-bar visual state",
	)
	check_eq(
		timeline.get_theme_constant(&"margin_left"),
		0,
		"integrated Timeline should not retain card-like left padding",
	)
	check_eq(
		timeline.get_theme_constant(&"margin_right"),
		0,
		"integrated Timeline should not retain card-like right padding",
	)
	_free_fixture(fixture)


func test_right_edge_snap_keeps_floating_chrome_resize_and_no_pop_out() -> void:
	var fixture := _make_live_fixture()
	var root := fixture["root"] as Control
	var manager := fixture["manager"] as WorkspaceModuleManager
	var host := fixture["host"] as WorkspaceDockHost
	var surface := fixture["surface"] as WorkspaceSurface
	var theme_controller := ThemeController.new()
	root.add_child(theme_controller)
	check_true(theme_controller.setup(manager, surface), "theme controller should initialize")
	check_true(
		theme_controller.refresh(Theme.new(), Color("2b2b2b"), Color("8aa0df")),
		"theme controller should resolve Workspace chrome",
	)
	tree.root.add_child(root)
	await tree.process_frame
	await tree.process_frame

	var preview := manager.get_instance(Builtins.PREVIEW_ID)
	var start_rect := surface.get_floating_rect(Builtins.PREVIEW_ID)
	check_true(
		surface.begin_module_drag(Builtins.PREVIEW_ID, start_rect.position + Vector2(12.0, 12.0)),
		"floating Preview drag should begin",
	)
	var bounds := surface.get_floating_bounds()
	var candidate := surface.update_module_drag(
		Vector2(bounds.end.x - 12.0, bounds.position.y + start_rect.size.y * 0.5)
	)
	check_eq(
		int(candidate.get("placement", WorkspaceSurface.Placement.NONE)),
		WorkspaceSurface.Placement.FLOATING,
		"edge snap must remain a floating placement",
	)
	check_eq(
		int(candidate.get("zone", WorkspaceDockLayout.DockZone.NONE)),
		WorkspaceDockLayout.DockZone.NONE,
		"edge snap must never claim a real dock zone",
	)
	check_true(surface.commit_module_drag(), "right-edge floating snap should commit")
	await tree.process_frame

	var snapped := surface.get_floating_rect(Builtins.PREVIEW_ID)
	check_almost_eq(snapped.end.x, bounds.end.x, 0.01, "right edge should snap to editor bounds")
	check_eq(
		host.layout.get_module_zone(Builtins.PREVIEW_ID),
		WorkspaceDockLayout.DockZone.NONE,
		"snapped Preview must remain outside DockLayout",
	)
	check_eq(preview.get_visual_state(), &"floating", "snapped Preview keeps floating chrome")
	check_true(
		not preview.is_float_point(Vector2(preview.size.x - 42.0, 8.0)),
		"snapped floating panel must not expose a Pop-out button",
	)

	var resize_start := snapped
	check_true(
		(
			surface
			. resize_floating_rect(
				Builtins.PREVIEW_ID,
				resize_start,
				Vector2(-40.0, 32.0),
				WorkspaceModule.ResizeEdge.LEFT | WorkspaceModule.ResizeEdge.BOTTOM,
			)
		),
		"snapped floating panel must remain resizable",
	)
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		WorkspaceSurface.Placement.FLOATING,
		"resize must not convert a snapped float into a dock",
	)

	tree.root.remove_child(root)
	_free_fixture(fixture)


func test_palette_and_color_picker_share_one_workspace_panel_in_vertical_order() -> void:
	var ids := Builtins.get_live_panel_ids()
	check_true(ids.has(Builtins.PALETTE_ID), "combined Palette panel must remain a live module")
	check_true(
		not ids.has(Builtins.COLOR_PICKER_ID),
		"Color Picker must not remain an independent live Workspace module"
	)

	var fixture := _make_live_fixture()
	var manager := fixture["manager"] as WorkspaceModuleManager
	var surface := fixture["surface"] as WorkspaceSurface
	var legacy_palette := fixture["legacy_palette"] as Control
	var legacy_color_picker := fixture["legacy_color_picker"] as Control
	var module := manager.get_instance(Builtins.PALETTE_ID)
	var content := module.get_content() as VBoxContainer
	check_true(content != null, "Palette Workspace module must own a combined vertical container")
	check_eq(content.name, &"Palette & Color", "combined runtime panel must expose one identity")
	check_eq(
		content.get_child_count(), 3, "combined panel should contain two sections and separator"
	)
	check_eq(
		content.get_child(0),
		legacy_palette,
		"existing Palette control must be preserved as the upper section"
	)
	check_true(content.get_child(1) is HSeparator, "merged sections must have a visual separator")
	check_eq(
		content.get_child(2),
		legacy_color_picker,
		"existing Color Picker control must be preserved as the lower section"
	)
	check_eq(
		surface.get_module_placement(Builtins.PALETTE_ID),
		WorkspaceSurface.Placement.FLOATING,
		"combined panel should participate as a snapped floating Workspace panel"
	)
	check_eq(
		fixture["host"].layout.get_module_zone(Builtins.PALETTE_ID),
		WorkspaceDockLayout.DockZone.NONE,
		"fresh layouts must not place Palette & Color in a real dock"
	)
	check_true(
		manager.get_definition(Builtins.COLOR_PICKER_ID) == null,
		"legacy Color Picker ID must not create a second Workspace shell"
	)
	_free_fixture(fixture)

	var scene_source := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/PaletteColorPanel.tscn"
	)
	check_true(
		scene_source.find('name="Palettes"') < scene_source.find('name="Color Picker"'),
		"scene-backed combined module must also keep Palette above Color Picker"
	)
	var migration_source := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceEditorMigration.gd"
	)
	check_true(
		migration_source.contains("_restore_palette_color_merge()"),
		"runtime merge must remain transactionally reversible"
	)


func test_left_tool_options_merge_after_stable_tool_startup() -> void:
	var ids := Builtins.get_live_panel_ids()
	check_true(ids.has(Builtins.TOOLS_ID), "Tools must remain a live Workspace module")
	check_true(
		not ids.has(Builtins.LEFT_TOOL_OPTIONS_ID),
		"Left Tool Options must no longer exist as an independent Workspace module"
	)

	var tools_scene := FileAccess.get_file_as_string("res://src/UI/ToolsPanel/Tools.tscn")
	check_true(
		tools_scene.contains('[node name="Tools" type="ScrollContainer"'),
		"Tools must preserve its original startup root"
	)
	check_true(
		tools_scene.contains('[node name="PanelContainer" type="PanelContainer" parent="."'),
		"Tools palette must keep its original startup parent"
	)
	check_true(
		not tools_scene.contains("LeftPanelContainer"),
		"Tools scene must not embed tool options before runtime migration"
	)

	var ui_scene := FileAccess.get_file_as_string("res://src/UI/UI.tscn")
	check_true(
		ui_scene.contains(
			'[node name="Left Tool Options" type="ScrollContainer" parent="DockableContainer"'
		),
		"legacy startup shell must retain Left Tool Options until tools initialize"
	)
	check_true(
		ui_scene.contains('parent="DockableContainer/Left Tool Options"'),
		"legacy shell must retain the original LeftPanelContainer path"
	)

	var fixture := _make_live_fixture(null, true, false)
	var manager := fixture["manager"] as WorkspaceModuleManager
	var migration := fixture["migration"] as WorkspaceEditorMigration
	var legacy := fixture["legacy"] as DockableContainer
	var tools_module := manager.get_instance(Builtins.TOOLS_ID)
	var tools_root := tools_module.get_content() as ScrollContainer
	var left_options := fixture["left_tool_options"] as ScrollContainer
	var left_panel := fixture["left_panel"] as MarginContainer
	check_eq(
		left_options.get_parent(),
		legacy,
		"Left Tool Options must remain in the legacy startup shell until startup completes"
	)
	check_true(
		tools_root.get_node_or_null(^"MergedToolsContent") == null,
		"Workspace setup must not mutate the Tools hierarchy during startup"
	)
	check_true(
		migration.merge_left_tool_options_after_startup(),
		"post-startup migration should merge the already initialized controls"
	)
	var merged := tools_root.get_node_or_null(^"MergedToolsContent") as HBoxContainer
	check_true(merged != null, "post-startup merge should create one two-column Tools row")
	check_eq(
		left_options.get_parent(),
		merged,
		"existing Left Tool Options control must move into Tools only after migration"
	)
	check_eq(
		left_panel.get_parent(),
		left_options,
		"current tool option host identity and parent must remain unchanged"
	)
	check_eq(
		tools_root.get_node_or_null(^"PanelContainer"),
		null,
		"palette should leave the root only after migration"
	)
	var tools_column := merged.get_node_or_null(^"PanelContainer") as PanelContainer
	check_true(tools_column != null, "existing tool palette should become the left column")
	check_eq(
		tools_column.custom_minimum_size.x,
		WorkspaceEditorMigration.TOOL_PALETTE_WIDTH,
		"tool-button column should be only wide enough for the 32px tool buttons",
	)
	check_eq(
		tools_column.size_flags_horizontal,
		Control.SIZE_SHRINK_BEGIN,
		"tool-button column must not consume spare horizontal width",
	)
	check_eq(
		left_options.custom_minimum_size.x,
		WorkspaceEditorMigration.TOOL_OPTIONS_WIDTH,
		"tool-options column should keep the matching compact configuration width",
	)
	check_eq(
		left_options.size_flags_stretch_ratio,
		1.0,
		"remaining few pixels should go to the configuration column",
	)
	check_true(
		merged.get_node_or_null(^"ToolOptionsSeparator") is VSeparator,
		"two-column Tools should use a vertical separator",
	)
	check_eq(
		tools_root.horizontal_scroll_mode,
		ScrollContainer.SCROLL_MODE_DISABLED,
		"merged Tools must never require horizontal dragging",
	)
	check_eq(
		left_options.horizontal_scroll_mode,
		ScrollContainer.SCROLL_MODE_DISABLED,
		"configuration options must fit without their own horizontal scrollbar",
	)
	check_eq(
		tools_root.vertical_scroll_mode,
		ScrollContainer.SCROLL_MODE_AUTO,
		"outer Tools should retain vertical scrolling when tool content is tall",
	)
	check_eq(
		left_options.vertical_scroll_mode,
		ScrollContainer.SCROLL_MODE_DISABLED,
		"nested Left Tool Options must not compete with the outer vertical scroll",
	)
	_free_fixture(fixture)

	var migration_source := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceEditorMigration.gd"
	)
	check_true(
		migration_source.contains("merge_left_tool_options_after_startup()"),
		"Workspace migration must expose an explicit post-startup merge"
	)
	check_true(
		migration_source.contains("_restore_merged_tools()"),
		"runtime merge must remain transactionally reversible"
	)
	check_true(
		migration_source.contains("Tools.tool_changed.connect(_on_tools_header_tool_changed)"),
		"Tools header must follow the active left tool in real time",
	)
	check_true(
		migration_source.contains("tools_module.set_header_title_override(tr(tool.display_name))"),
		"active tool name must move into the Workspace header",
	)
	check_true(
		not migration_source.contains("Builtins.LEFT_TOOL_OPTIONS_ID"),
		"default Workspace layout must not place Left Tool Options independently"
	)


func test_timeline_header_controls_remain_attached_to_fixed_bottom_bar() -> void:
	var fixture := _make_live_fixture()
	var root := fixture["root"] as Control
	var manager := fixture["manager"] as WorkspaceModuleManager
	var surface := fixture["surface"] as WorkspaceSurface
	tree.root.add_child(root)
	await tree.process_frame
	await tree.process_frame

	var timeline := manager.get_instance(Builtins.TIMELINE_ID)
	var accessory := timeline.get_header_accessory() as TimelineHeaderControls
	check_true(accessory != null, "fixed Timeline should retain its combined header controls")
	check_eq(
		surface.get_module_placement(Builtins.TIMELINE_ID),
		WorkspaceSurface.Placement.DOCKED,
		"Timeline header controls must belong to the fixed Bottom Dock",
	)
	check_true(
		not timeline.is_position_adjustment_enabled(),
		"fixed Timeline header must not expose panel movement",
	)
	check_true(
		not timeline.is_float_point(
			Vector2(timeline.size.x - WorkspaceModule.INTERACTION_TARGET_SIZE * 1.5, 8.0)
		),
		"fixed Timeline must not expose a Pop-out target",
	)

	tree.root.remove_child(root)
	_free_fixture(fixture)


func test_timeline_header_combines_global_options_undo_redo_and_frame_mark() -> void:
	var ids := Builtins.get_live_panel_ids()
	check_true(
		not ids.has(Builtins.GLOBAL_TOOL_OPTIONS_ID),
		"Global Tool Options must no longer exist as an independent Workspace module"
	)
	var migration_source := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceEditorMigration.gd"
	)
	check_true(
		migration_source.contains("TIMELINE_HEADER_CONTROLS_SCENE.instantiate()"),
		"live migration must instantiate the combined Timeline header controls"
	)
	check_true(
		migration_source.contains("timeline.set_header_accessory(header_controls)"),
		"combined Timeline controls must attach through the Workspace header accessory contract"
	)
	var module_source := FileAccess.get_file_as_string("res://src/UI/Workspace/WorkspaceModule.gd")
	check_true(
		module_source.contains("get_header_accessory_rect().has_point(local_point)"),
		"header accessory controls must be excluded from normal module drag"
	)

	var fixture := _make_live_fixture()
	var root := fixture["root"] as Control
	var manager := fixture["manager"] as WorkspaceModuleManager
	var surface := fixture["surface"] as WorkspaceSurface
	tree.root.add_child(root)
	await tree.process_frame
	await tree.process_frame
	var timeline := manager.get_instance(Builtins.TIMELINE_ID)
	var accessory := timeline.get_header_accessory() as TimelineHeaderControls
	check_true(accessory != null, "Timeline must own a live header accessory")
	timeline.apply_visual_theme(VisualTheme.new(), &"docked")
	check_eq(
		accessory.name,
		&"TimelineHeaderControls",
		"Timeline header accessory must be the combined iPad command row"
	)
	check_true(
		accessory.global_tool_options != null,
		"existing Global Tool Options must remain managed by the combined row",
	)
	check_true(accessory.undo_button != null, "Timeline header must expose Undo")
	check_true(accessory.redo_button != null, "Timeline header must expose Redo")
	check_true(
		accessory.frame_mark != null, "Timeline header must expose the current/total frame display"
	)
	check_true(
		accessory.get_parent() is Node2D,
		"header controls must live in the Workspace header overlay, not Timeline content"
	)
	check_true(timeline.get_header_height() >= 36.0, "Timeline header must fit the command row")
	var accessory_rect := timeline.get_header_accessory_rect()
	check_true(
		accessory_rect.end.x <= timeline.size.x - WorkspaceModule.INTERACTION_TARGET_SIZE,
		"position-locked Timeline must right-align controls before the Collapse action"
	)
	check_true(
		not timeline.is_header_drag_point(accessory_rect.get_center()),
		"touching a Timeline command must never begin the normal module drag path"
	)
	check_true(surface.collapse_module(Builtins.TIMELINE_ID), "Timeline should collapse")
	timeline.apply_visual_theme(VisualTheme.new(), &"collapsed")
	check_true(timeline.is_content_collapsed(), "Timeline body should collapse")
	check_true(
		timeline.get_header_accessory() == accessory and accessory.visible,
		"Timeline command row must remain visible while Timeline body is collapsed"
	)
	tree.root.remove_child(root)
	_free_fixture(fixture)

	var options_scene := FileAccess.get_file_as_string(
		"res://src/UI/GlobalToolOptions/GlobalToolOptions.tscn"
	)
	var options_script := FileAccess.get_file_as_string(
		"res://src/UI/GlobalToolOptions/GlobalToolOptions.gd"
	)
	check_true(
		options_scene.contains("custom_minimum_size = Vector2(256, 36)"),
		"Global Tool Options should keep its compact single-row width inside the combined row"
	)
	check_true(
		options_script.contains("grid_container.columns = 8"),
		"all eight Global Tool Options controls must remain on one header row"
	)


func test_top_bar_keeps_only_menu_and_projects_commands() -> void:
	var scene_source := FileAccess.get_file_as_string(
		"res://src/UI/TopMenuContainer/TopMenuContainer.tscn"
	)
	check_true(
		scene_source.contains('name="MainMenuButton"'), "Main Menu must remain in the top bar"
	)
	check_true(scene_source.contains('name="ReturnHome"'), "Projects must remain in the top bar")
	for removed_name in [
		"TopLabels",
		"RotationSlider",
		"ZoomSlider",
		"CursorPosition",
		"QuickAccessButtons",
		"Save",
		"Copy",
		"Cut",
		"Paste",
		"Delete",
		"Shift",
		"Ctrl",
		"Alt",
		"CurrentFrame",
		"CurrentFrameMark",
	]:
		check_true(
			not scene_source.contains('name="%s"' % removed_name),
			"%s must no longer occupy the editor top bar" % removed_name,
		)
	var camera_source := FileAccess.get_file_as_string("res://src/UI/Canvas/CanvasCamera.gd")
	check_true(
		camera_source.contains('get_node_or_null("%RotationSlider")'),
		"Canvas rotation must tolerate the removed legacy slider"
	)
	check_true(
		camera_source.contains('get_node_or_null("%ZoomSlider")'),
		"Canvas zoom must tolerate the removed legacy slider"
	)
	var interaction_source := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceInteractionController.gd"
	)
	check_true(
		interaction_source.contains("was_timeline_resize_candidate"),
		"a light tap on Timeline Undo/Redo must be allowed to reach GUI release"
	)


func test_live_module_catalog_keeps_main_canvas_outside_workspace_modules() -> void:
	var ids := Builtins.get_live_panel_ids()
	check_true(ids.has(Builtins.PREVIEW_ID), "Preview should be a live Workspace module")
	check_true(ids.has(Builtins.PALETTE_ID), "Palette should be a live Workspace module")
	check_true(
		not ids.has(Builtins.COLOR_PICKER_ID),
		"Color Picker should be represented by the merged Palette module"
	)
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


func test_canvas_rulers_stop_at_document_bounds_and_label_actual_size() -> void:
	var migration_source := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceEditorMigration.gd"
	)
	check_true(
		migration_source.contains(
			"horizontal_ruler.size = Vector2(maxf(0.0, canvas_rect.size.x), horizontal_height)"
		),
		"horizontal ruler width must match the document screen bounds"
	)
	check_true(
		migration_source.contains(
			"vertical_ruler.size = Vector2(vertical_width, maxf(0.0, canvas_rect.size.y))"
		),
		"vertical ruler height must match the document screen bounds"
	)
	check_true(
		migration_source.contains("_ruler_project.resized.connect(_on_document_resized)"),
		"ruler bounds must refresh when the document is resized or cropped"
	)

	var horizontal_source := FileAccess.get_file_as_string(
		"res://src/UI/Canvas/Rulers/HorizontalRuler.gd"
	)
	check_true(
		horizontal_source.contains("var start_index := maxi(0, ceili(first.x))"),
		"horizontal ruler must not draw negative-axis ticks"
	)
	check_true(
		horizontal_source.contains("document_end_index := floori(float(proj_size.x) / tick_step)"),
		"horizontal ruler ticks must stop at document width"
	)
	check_true(
		horizontal_source.contains(
			"_draw_document_end(font, transform, proj_size.x, origin_offset)"
		),
		"horizontal ruler must force an endpoint size label"
	)
	check_true(
		horizontal_source.contains("text_server.format_number(str(document_width))"),
		"horizontal endpoint label must show the actual document width"
	)

	var vertical_source := FileAccess.get_file_as_string(
		"res://src/UI/Canvas/Rulers/VerticalRuler.gd"
	)
	check_true(
		vertical_source.contains("var start_index := maxi(0, ceili(first.y))"),
		"vertical ruler must not draw negative-axis ticks"
	)
	check_true(
		vertical_source.contains("document_end_index := floori(float(proj_size.y) / tick_step)"),
		"vertical ruler ticks must stop at document height"
	)
	check_true(
		vertical_source.contains("_draw_document_end(font, transform, proj_size.y)"),
		"vertical ruler must force an endpoint size label"
	)
	check_true(
		vertical_source.contains("text_server.format_number(str(document_height))"),
		"vertical endpoint label must show the actual document height"
	)


func test_full_background_canvas_gates_tools_to_document_but_keeps_selection_outside() -> void:
	var tools_source := FileAccess.get_file_as_string("res://src/Autoload/Tools.gd")
	check_true(
		tools_source.contains("Rect2i(Vector2i.ZERO, project.size).has_point(position)"),
		"tool routing must distinguish the actual document rectangle from the full background Canvas"
	)
	check_true(
		tools_source.contains("slot.tool_node is BaseSelectionTool"),
		"selection tools must explicitly retain outside-document input"
	)
	check_true(
		(
			tools_source.contains("and can_start_tool_at(position, MOUSE_BUTTON_LEFT)")
			and tools_source.contains("and can_start_tool_at(position, MOUSE_BUTTON_RIGHT)")
		),
		"ordinary left/right tool presses must be gated before draw_start"
	)
	check_true(
		tools_source.contains("Ordinary tools stop at the last valid document point"),
		"ordinary strokes must stop when they exit document bounds"
	)
	check_true(
		(
			tools_source.contains("should_show_tool_at(position, MOUSE_BUTTON_LEFT)")
			and tools_source.contains("should_show_tool_at(position, MOUSE_BUTTON_RIGHT)")
		),
		"indicator and tool preview rendering must use the same document-bound policy"
	)

	var canvas_source := FileAccess.get_file_as_string("res://src/UI/Canvas/Canvas.gd")
	check_true(
		(
			canvas_source.contains("Tools.should_show_tool_at(pixel, MOUSE_BUTTON_LEFT)")
			and canvas_source.contains("Tools.should_show_tool_at(pixel, MOUSE_BUTTON_RIGHT)")
		),
		"cursor tool icons must disappear outside the document for ordinary tools"
	)

	var adapter_source := FileAccess.get_file_as_string(
		"res://src/InputAdapter/CanvasInputAdapter.gd"
	)
	check_true(
		(
			adapter_source.contains("_viewport_position_can_start_primary_tool")
			and adapter_source.contains("Tools.can_start_tool_at")
		),
		"iPad Pencil/finger acquisition must honor the same document-bound tool policy"
	)
	check_true(
		adapter_source.contains("Tools.is_position_inside_document"),
		"adapter color sampling must not act on the expanded background outside the document"
	)
	check_true(
		adapter_source.contains("_eligible_direct_touch_ids().size() >= 2"),
		"an outside first finger must remain available for two-finger Canvas navigation"
	)


func test_preview_touch_navigation_reuses_canvas_math_without_zoom_slider() -> void:
	var scene_source := FileAccess.get_file_as_string(
		"res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.tscn"
	)
	var preview_source := FileAccess.get_file_as_string(
		"res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.gd"
	)
	var adapter_source := FileAccess.get_file_as_string(
		"res://src/InputAdapter/CanvasInputAdapter.gd"
	)
	check_true(
		not scene_source.contains("PreviewZoomSlider"),
		"Preview should no longer expose the legacy zoom slider"
	)
	check_true(
		scene_source.contains('groups=["CanvasTouchBlockers"]'),
		"Preview content should block touch-through into the full-background Main Canvas"
	)
	check_true(
		(
			preview_source.contains("InputEventScreenTouch")
			and preview_source.contains("InputEventScreenDrag")
		),
		"Preview should own raw two-finger touch navigation on iOS"
	)
	check_true(
		(
			preview_source.contains("NAVIGATION.navigation_pair_geometry")
			and preview_source.contains("NAVIGATION.navigation_zoom_from_ratio")
			and preview_source.contains("NAVIGATION.navigation_offset_for_anchor")
		),
		"Preview should reuse the Canvas navigation geometry, zoom and anchored-pan math"
	)
	check_true(
		(
			adapter_source.contains("CANVAS_TOUCH_BLOCKER_GROUP")
			and adapter_source.contains("get_nodes_in_group(CANVAS_TOUCH_BLOCKER_GROUP)")
		),
		"Main Canvas touch arbitration should reject touches that begin over Preview"
	)


func test_managed_editor_removes_project_tabs_and_their_canvas_dead_strip() -> void:
	var migration_source := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceEditorMigration.gd"
	)
	check_has(
		migration_source,
		"_single_project_editor = STORAGE_POLICY.uses_managed_project_storage()",
		"managed iPad editor must explicitly select the single-project chrome policy",
	)
	check_has(
		migration_source,
		"project_tabs.visible = false",
		"managed single-project editor must not render the legacy project TabBar",
	)
	check_has(
		migration_source,
		"_project_tabs_height = 0.0",
		"removing project tabs must also remove their reserved Canvas input strip",
	)
