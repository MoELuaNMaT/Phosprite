extends "res://tests/test_base.gd"

const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const Profile4 := preload("res://src/UI/Workspace/WorkspaceUIProfile4.gd")
const Migration := preload("res://src/UI/Workspace/WorkspaceEditorMigration.gd")


func test_ui4_has_independent_version_and_custom_layout_slot() -> void:
	var migration := Migration.new()
	check_eq(migration.get_ui_profile_implementation_version(4), 1, "UI4 versioned separately")
	check_true(migration.has_ui_profile_custom_composition(4), "UI4 must not inherit UI2/3 layouts")
	migration.free()


func test_ui4_fixed_u_frame_geometry_and_resize_rules() -> void:
	var root := Control.new()
	root.size = Vector2(1200.0, 800.0)
	tree.root.add_child(root)
	var manager := WorkspaceModuleManager.new()
	root.add_child(manager)
	check_true(Builtins.register_defaults(manager), "workspace modules register")
	for module_id in [
		Builtins.PALETTE_ID,
		Builtins.TOOLS_ID,
		Builtins.TIMELINE_ID,
		Builtins.RIGHT_TOOL_OPTIONS_ID,
	]:
		var content: Control
		if module_id == Builtins.PALETTE_ID:
			var palette_root := VBoxContainer.new()
			var swatches := Control.new()
			swatches.name = &"Palettes"
			swatches.size_flags_vertical = Control.SIZE_EXPAND_FILL
			palette_root.add_child(swatches)
			var picker := Control.new()
			picker.name = &"Color Picker"
			picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
			palette_root.add_child(picker)
			content = palette_root
		else:
			content = Control.new()
		check_true(
			manager.adopt_module(module_id, content) != null,
			"runtime panel adopted: " + String(module_id)
		)
	var dock_host := WorkspaceDockHost.new()
	root.add_child(dock_host)
	dock_host.size = root.size
	check_true(dock_host.setup(manager), "dock host setup")
	var surface := WorkspaceSurface.new()
	root.add_child(surface)
	check_true(surface.setup(manager, dock_host), "surface setup")
	var ui4 := Profile4.new()
	root.add_child(ui4)
	check_true(ui4.setup(root, surface), "UI4 setup")
	check_true(ui4.activate(), "UI4 activates existing panels")
	await tree.process_frame

	check_true(dock_host.u_frame_layout_enabled, "UI4 geometry selected")
	var tools_definition := manager.get_definition(Builtins.TOOLS_ID)
	check_eq(
		tools_definition.get_constrained_size(Vector2(240.0, 360.0)).x,
		Migration.UI1_TOOLS_FIXED_WIDTH,
		"UI4 Tools width stays identical for every selected tool",
	)
	check_true(tools_definition.is_horizontal_resize_locked(), "UI4 width cannot expand by drag")
	var left := dock_host._zone_hosts[WorkspaceDockLayout.DockZone.LEFT] as Control
	var right := dock_host._zone_hosts[WorkspaceDockLayout.DockZone.RIGHT] as Control
	var bottom := dock_host._zone_hosts[WorkspaceDockLayout.DockZone.BOTTOM] as Control
	check_eq(left.position.y, 0.0, "left palette begins at workspace top")
	check_eq(left.size.y, dock_host.size.y, "left palette extends to bottom of screen")
	check_eq(bottom.position.x, left.position.x + left.size.x, "timeline starts at palette edge")
	check_eq(bottom.position.y, right.position.y + right.size.y, "right tools end at timeline")
	check_eq(
		bottom.size.x,
		dock_host.size.x - bottom.position.x - dock_host.get_side_inset(),
		"timeline fills the bottom space to the right",
	)

	for module_id in [Builtins.PALETTE_ID, Builtins.TOOLS_ID, Builtins.TIMELINE_ID]:
		var module := manager.get_instance(module_id)
		check_eq(
			surface.get_module_placement(module_id),
			WorkspaceSurface.Placement.DOCKED,
			"UI4 pane is fixed dock: " + String(module_id)
		)
		check_true(not module.is_position_adjustment_enabled(), "fixed panel cannot move")

	var old_left_width := left.size.x
	var left_module := manager.get_instance(Builtins.PALETTE_ID)
	var left_hit := surface.get_docked_resize_edges(
		Builtins.PALETTE_ID, Vector2(left_module.size.x - 2.0, 68.0)
	)
	check_true(
		(left_hit & WorkspaceModule.ResizeEdge.RIGHT) != 0,
		"left palette right edge is resizable",
	)
	check_true(
		surface.resize_docked_module(
			Builtins.PALETTE_ID,
			dock_host.layout.get_module_size(Builtins.PALETTE_ID),
			Vector2(38.0, 0.0),
			WorkspaceModule.ResizeEdge.RIGHT
		),
		"right edge resize succeeds"
	)
	check_true(left.size.x > old_left_width, "left palette width changes")
	check_eq(bottom.position.x, left.position.x + left.size.x, "timeline follows left resize")

	var timeline_height := bottom.size.y
	check_true(
		surface.resize_docked_module(
			Builtins.TIMELINE_ID,
			dock_host.layout.get_module_size(Builtins.TIMELINE_ID),
			Vector2(0.0, -36.0),
			WorkspaceModule.ResizeEdge.TOP
		),
		"bottom bar top edge resize succeeds"
	)
	check_true(bottom.size.y > timeline_height, "timeline height changes independently")
	check_eq(left.size.y, dock_host.size.y, "left height stays full after timeline resize")

	# Simulate a portrait-size iPad: no U-frame panel should intrude into another.
	root.size = Vector2(768.0, 720.0)
	dock_host.size = root.size
	await tree.process_frame
	var timeline_module := manager.get_instance(Builtins.TIMELINE_ID)
	var tools_module := manager.get_instance(Builtins.TOOLS_ID)
	check_true(
		timeline_module.size.x <= bottom.size.x + 1.0,
		"portrait timeline must shrink to available width instead of overflowing",
	)
	check_true(
		tools_module.size.y <= right.size.y + 1.0,
		"portrait right tools must stop at timeline top edge",
	)
	check_eq(left.size.y, dock_host.size.y, "portrait palette still spans full height")
	check_eq(right.size.x, Migration.UI1_TOOLS_FIXED_WIDTH, "portrait Tools retains fixed width")

	ui4.deactivate()
	check_true(not dock_host.u_frame_layout_enabled, "UI4 geometry disabled on exit")
	check_true(
		manager.get_instance(Builtins.PALETTE_ID).is_position_adjustment_enabled(),
		"legacy palette positioning restored"
	)
	manager.destroy_all_modules()
	root.free()
