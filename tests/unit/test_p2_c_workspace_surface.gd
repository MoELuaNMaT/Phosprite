extends "res://tests/test_base.gd"

const Definition := preload("res://src/UI/Workspace/WorkspaceModuleDefinition.gd")
const Manager := preload("res://src/UI/Workspace/WorkspaceModuleManager.gd")
const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const DockLayout := preload("res://src/UI/Workspace/WorkspaceDockLayout.gd")
const DockHost := preload("res://src/UI/Workspace/WorkspaceDockHost.gd")
const Surface := preload("res://src/UI/Workspace/WorkspaceSurface.gd")
const PREVIEW_SCENE_PATH := "res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.tscn"


func _make_workspace() -> Dictionary:
	var manager := Manager.new()
	var host := DockHost.new()
	var surface := Surface.new()
	Builtins.register_defaults(manager)
	host.size = Vector2(1200.0, 800.0)
	check_true(host.setup(manager), "dock host should initialize")
	check_true(surface.setup(manager, host), "surface should initialize over the dock host")
	return {"manager": manager, "host": host, "surface": surface}


func _free_workspace(workspace: Dictionary) -> void:
	var manager: WorkspaceModuleManager = workspace["manager"]
	var host: WorkspaceDockHost = workspace["host"]
	var surface: WorkspaceSurface = workspace["surface"]
	manager.destroy_all_modules()
	surface.free()
	host.free()
	manager.free()


func test_float_preserves_instance_and_detaches_from_dock_model() -> void:
	var workspace := _make_workspace()
	var manager: WorkspaceModuleManager = workspace["manager"]
	var host: WorkspaceDockHost = workspace["host"]
	var surface: WorkspaceSurface = workspace["surface"]

	check_true(
		surface.dock_module(Builtins.PREVIEW_ID, DockLayout.DockZone.LEFT),
		"Preview should start docked"
	)
	var preview: WorkspaceModule = manager.get_instance(Builtins.PREVIEW_ID)
	check_true(
		surface.float_module(Builtins.PREVIEW_ID, Rect2(420.0, 180.0, 360.0, 260.0)),
		"docked Preview should become floating"
	)
	check_eq(
		manager.get_instance(Builtins.PREVIEW_ID),
		preview,
		"Dock to Float must preserve the managed module instance"
	)
	check_eq(
		host.layout.get_module_zone(Builtins.PREVIEW_ID),
		DockLayout.DockZone.NONE,
		"floating modules must leave the P2-B dock model"
	)
	check_eq(
		preview.get_parent(),
		surface.get_floating_layer(),
		"floating module should be parented by the floating layer"
	)
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		Surface.Placement.FLOATING,
		"surface placement should report FLOATING"
	)
	check_eq(
		surface.get_floating_rect(Builtins.PREVIEW_ID),
		Rect2(420.0, 180.0, 360.0, 260.0),
		"requested floating bounds should be retained when already valid"
	)
	_free_workspace(workspace)


func test_floating_drag_snaps_back_to_dock_edge() -> void:
	var workspace := _make_workspace()
	var manager: WorkspaceModuleManager = workspace["manager"]
	var host: WorkspaceDockHost = workspace["host"]
	var surface: WorkspaceSurface = workspace["surface"]

	check_true(
		surface.float_module(Builtins.PREVIEW_ID, Rect2(420.0, 180.0, 320.0, 220.0)),
		"Preview should start floating"
	)
	var preview: WorkspaceModule = manager.get_instance(Builtins.PREVIEW_ID)
	check_true(
		surface.begin_module_drag(Builtins.PREVIEW_ID, Vector2(500.0, 220.0)),
		"floating module drag should begin"
	)
	var left_rect: Rect2 = host.get_zone_rects()[DockLayout.DockZone.LEFT]
	var candidate: Dictionary = surface.update_module_drag(left_rect.get_center())
	check_true(bool(candidate.get("valid", false)), "left edge should resolve a valid target")
	check_eq(
		int(candidate.get("placement", Surface.Placement.NONE)),
		Surface.Placement.DOCKED,
		"edge target should resolve to DOCKED"
	)
	check_eq(
		int(candidate.get("zone", DockLayout.DockZone.NONE)),
		DockLayout.DockZone.LEFT,
		"left edge should resolve the left dock"
	)
	check_true(surface.get_preview_rect().has_area(), "edge snap should expose a preview")
	check_true(surface.commit_module_drag(), "edge snap should commit")
	check_eq(
		manager.get_instance(Builtins.PREVIEW_ID),
		preview,
		"Float to Dock must preserve the managed instance"
	)
	check_eq(
		host.layout.get_module_zone(Builtins.PREVIEW_ID),
		DockLayout.DockZone.LEFT,
		"committed edge snap should place Preview in the left dock"
	)
	_free_workspace(workspace)


func test_floating_resize_supports_left_right_bottom_and_lower_corners() -> void:
	var workspace := _make_workspace()
	var surface: WorkspaceSurface = workspace["surface"]
	check_true(
		surface.float_module(Builtins.PREVIEW_ID, Rect2(300.0, 180.0, 360.0, 240.0)),
		"Preview should float before resize validation",
	)

	var start := surface.get_floating_rect(Builtins.PREVIEW_ID)
	check_true(
		surface.resize_floating_rect(
			Builtins.PREVIEW_ID, start, Vector2(80.0, 0.0), WorkspaceModule.ResizeEdge.LEFT
		),
		"left edge resize should commit",
	)
	var left_rect := surface.get_floating_rect(Builtins.PREVIEW_ID)
	check_almost_eq(left_rect.end.x, start.end.x, 0.01, "left resize must preserve the right edge")
	check_almost_eq(left_rect.size.x, start.size.x - 80.0, 0.01, "left resize should change width")

	check_true(surface.set_floating_rect(Builtins.PREVIEW_ID, start), "reset floating rect")
	check_true(
		surface.resize_floating_rect(
			Builtins.PREVIEW_ID, start, Vector2(90.0, 0.0), WorkspaceModule.ResizeEdge.RIGHT
		),
		"right edge resize should commit",
	)
	var right_rect := surface.get_floating_rect(Builtins.PREVIEW_ID)
	check_eq(right_rect.position, start.position, "right resize must keep top-left anchored")
	check_almost_eq(
		right_rect.size.x, start.size.x + 90.0, 0.01, "right resize should change width"
	)

	check_true(surface.set_floating_rect(Builtins.PREVIEW_ID, start), "reset floating rect")
	check_true(
		surface.resize_floating_rect(
			Builtins.PREVIEW_ID, start, Vector2(0.0, 70.0), WorkspaceModule.ResizeEdge.BOTTOM
		),
		"bottom edge resize should commit",
	)
	var bottom_rect := surface.get_floating_rect(Builtins.PREVIEW_ID)
	check_eq(bottom_rect.position, start.position, "bottom resize must keep top edge anchored")
	check_almost_eq(
		bottom_rect.size.y, start.size.y + 70.0, 0.01, "bottom resize should change height"
	)

	check_true(surface.set_floating_rect(Builtins.PREVIEW_ID, start), "reset floating rect")
	var left_bottom := WorkspaceModule.ResizeEdge.LEFT | WorkspaceModule.ResizeEdge.BOTTOM
	check_true(
		surface.resize_floating_rect(Builtins.PREVIEW_ID, start, Vector2(70.0, 60.0), left_bottom),
		"lower-left corner should resize both axes",
	)
	var lower_left_rect := surface.get_floating_rect(Builtins.PREVIEW_ID)
	check_almost_eq(
		lower_left_rect.end.x, start.end.x, 0.01, "lower-left resize must preserve right edge"
	)
	check_almost_eq(
		lower_left_rect.size.y,
		start.size.y + 60.0,
		0.01,
		"lower-left resize should change height",
	)

	check_true(surface.set_floating_rect(Builtins.PREVIEW_ID, start), "reset floating rect")
	var right_bottom := WorkspaceModule.ResizeEdge.RIGHT | WorkspaceModule.ResizeEdge.BOTTOM
	check_true(
		surface.resize_floating_rect(Builtins.PREVIEW_ID, start, Vector2(70.0, 60.0), right_bottom),
		"lower-right corner should resize both axes",
	)
	var lower_right_rect := surface.get_floating_rect(Builtins.PREVIEW_ID)
	check_eq(
		lower_right_rect.position, start.position, "lower-right resize must keep top-left anchored"
	)
	check_almost_eq(
		lower_right_rect.size.x,
		start.size.x + 70.0,
		0.01,
		"lower-right resize should change width",
	)
	check_almost_eq(
		lower_right_rect.size.y,
		start.size.y + 60.0,
		0.01,
		"lower-right resize should change height",
	)
	_free_workspace(workspace)


func test_pop_out_restores_last_floating_rect_and_releases_dock_extent() -> void:
	var workspace := _make_workspace()
	var host: WorkspaceDockHost = workspace["host"]
	var surface: WorkspaceSurface = workspace["surface"]
	var remembered := Rect2(320.0, 220.0, 360.0, 240.0)
	check_true(
		surface.float_module(Builtins.PREVIEW_ID, remembered),
		"Preview should first establish a floating rect",
	)
	check_true(
		(
			surface
			. dock_module(
				Builtins.PREVIEW_ID,
				DockLayout.DockZone.BOTTOM,
				0,
				Vector2(360.0, 180.0),
			)
		),
		"Preview should dock at the bottom before pop-out",
	)
	var docked_content_height := host.get_content_rect().size.y
	check_true(surface.float_from_dock(Builtins.PREVIEW_ID), "dock header pop-out should float")
	check_eq(
		surface.get_floating_rect(Builtins.PREVIEW_ID),
		remembered,
		"pop-out should restore the module's last floating bounds",
	)
	check_eq(
		host.layout.get_module_zone(Builtins.PREVIEW_ID),
		DockLayout.DockZone.NONE,
		"pop-out must remove the module from dock layout geometry",
	)
	check_true(
		host.get_content_rect().size.y > docked_content_height,
		"releasing Bottom Dock must return its height to the central Canvas",
	)
	_free_workspace(workspace)


func test_collapse_and_restore_keep_docked_panel_in_place() -> void:
	var workspace := _make_workspace()
	var manager: WorkspaceModuleManager = workspace["manager"]
	var host: WorkspaceDockHost = workspace["host"]
	var surface: WorkspaceSurface = workspace["surface"]

	check_true(
		surface.dock_module(
			Builtins.PREVIEW_ID, DockLayout.DockZone.RIGHT, 0, Vector2(300.0, 180.0)
		),
		"Preview should dock before collapse"
	)
	var preview: WorkspaceModule = manager.get_instance(Builtins.PREVIEW_ID)
	var preview_content: Control = preview.get_content()
	var original_parent := preview.get_parent()
	var original_position := preview.position

	check_true(surface.collapse_module(Builtins.PREVIEW_ID), "docked Preview should collapse")
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		Surface.Placement.COLLAPSED,
		"collapsed module should enter COLLAPSED placement"
	)
	check_eq(
		preview.get_parent(),
		original_parent,
		"docked collapse must keep the module mounted in the same dock host"
	)
	check_eq(
		host.layout.get_module_zone(Builtins.PREVIEW_ID),
		DockLayout.DockZone.RIGHT,
		"docked collapse must retain the original dock slot"
	)
	check_eq(preview.position, original_position, "collapsed docked header should stay in place")
	check_true(not preview_content.visible, "docked collapse should hide only panel content")
	check_eq(
		preview.get_visual_rect().size.y,
		preview.get_header_height(),
		"docked collapse should expose only the title bar"
	)

	var restore: Dictionary = surface.get_restore_state(Builtins.PREVIEW_ID)
	check_eq(
		int(restore.get("zone", DockLayout.DockZone.NONE)),
		DockLayout.DockZone.RIGHT,
		"collapse should remember the previous dock zone"
	)
	check_eq(
		restore.get("size", Vector2.ZERO),
		Vector2(300.0, 180.0),
		"collapse should remember the previous dock size"
	)
	check_true(
		not surface.peek_module(Builtins.PREVIEW_ID),
		"in-place collapse should not detach into the legacy Peek/Tray path"
	)

	check_true(surface.restore_module(Builtins.PREVIEW_ID), "collapsed module should restore")
	check_eq(
		manager.get_instance(Builtins.PREVIEW_ID),
		preview,
		"Collapse/Restore must preserve the managed instance"
	)
	check_eq(
		preview.get_parent(),
		original_parent,
		"restore must expand in the same dock parent without remounting"
	)
	check_eq(
		preview.position, original_position, "restore should not jump through the top-left origin"
	)
	check_true(preview_content.visible, "restore should reveal the same panel content")
	check_eq(
		host.layout.get_module_zone(Builtins.PREVIEW_ID),
		DockLayout.DockZone.RIGHT,
		"Restore should retain the original dock"
	)
	check_eq(
		host.layout.get_module_size(Builtins.PREVIEW_ID),
		Vector2(300.0, 180.0),
		"Restore should recover the previous dock size"
	)
	_free_workspace(workspace)


func test_real_dock_containers_shrink_collapsed_module_height_in_every_zone() -> void:
	var workspace := _make_workspace()
	var manager: WorkspaceModuleManager = workspace["manager"]
	var host: WorkspaceDockHost = workspace["host"]
	var surface: WorkspaceSurface = workspace["surface"]
	tree.root.add_child(host)
	await tree.process_frame
	await tree.process_frame

	var cases := [
		{
			"zone": DockLayout.DockZone.TOP,
			"first": &"test.collapse.top.first",
			"second": &"test.collapse.top.second",
		},
		{
			"zone": DockLayout.DockZone.LEFT,
			"first": &"test.collapse.left.first",
			"second": &"test.collapse.left.second",
		},
		{
			"zone": DockLayout.DockZone.RIGHT,
			"first": &"test.collapse.right.first",
			"second": &"test.collapse.right.second",
		},
		{
			"zone": DockLayout.DockZone.BOTTOM,
			"first": &"test.collapse.bottom.first",
			"second": &"test.collapse.bottom.second",
		},
	]

	for entry: Dictionary in cases:
		var first_id := entry["first"] as StringName
		var second_id := entry["second"] as StringName
		for module_id in [first_id, second_id]:
			var definition := Definition.new()
			definition.module_id = module_id
			definition.display_name = String(module_id)
			definition.uses_external_content = true
			definition.minimum_size = Vector2(120.0, 80.0)
			definition.preferred_size = Vector2(220.0, 140.0)
			check_true(manager.register_definition(definition), "test module should register")
			check_true(
				manager.adopt_module(module_id, Control.new()) != null,
				"test module should adopt simple content"
			)

		var zone := int(entry["zone"])
		check_true(
			surface.dock_module(first_id, zone, 0, Vector2(220.0, 140.0)),
			"first module should dock"
		)
		check_true(
			surface.dock_module(second_id, zone, 1, Vector2(220.0, 140.0)),
			"second module should dock beside the collapse target"
		)
		await tree.process_frame
		await tree.process_frame

		var first: WorkspaceModule = manager.get_instance(first_id)
		var original_parent := first.get_parent()
		var original_position := first.position
		check_true(
			first.size.y > first.get_header_height(),
			"expanded docked module should be taller than its header"
		)

		check_true(surface.collapse_module(first_id), "docked module should collapse")
		await tree.process_frame
		await tree.process_frame
		check_eq(first.get_parent(), original_parent, "collapse must preserve the dock parent")
		check_almost_eq(
			first.position.x, original_position.x, 0.01, "collapse must preserve x position"
		)
		check_almost_eq(
			first.position.y, original_position.y, 0.01, "collapse must preserve y position"
		)
		check_almost_eq(
			first.size.y,
			first.get_header_height(),
			0.01,
			"real Container-assigned height must shrink to the title bar"
		)

		check_true(surface.restore_module(first_id), "collapsed docked module should restore")
		await tree.process_frame
		await tree.process_frame
		check_almost_eq(first.size.y, 140.0, 0.01, "restore should recover requested height")

		check_true(surface.clear_module_placement(first_id), "first module should clear")
		check_true(surface.clear_module_placement(second_id), "second module should clear")
		await tree.process_frame

	tree.root.remove_child(host)
	_free_workspace(workspace)


func test_collapse_restores_floating_rect_and_honors_capabilities() -> void:
	var workspace := _make_workspace()
	var manager: WorkspaceModuleManager = workspace["manager"]
	var surface: WorkspaceSurface = workspace["surface"]
	var floating_rect := Rect2(500.0, 240.0, 340.0, 240.0)

	check_true(
		surface.float_module(Builtins.PALETTE_ID, floating_rect), "Palette should become floating"
	)
	var palette: WorkspaceModule = manager.get_instance(Builtins.PALETTE_ID)
	var palette_content: Control = palette.get_content()
	check_true(surface.collapse_module(Builtins.PALETTE_ID), "floating Palette should collapse")
	check_true(
		surface.is_floating_collapsed(Builtins.PALETTE_ID),
		"floating collapse should remain an in-place floating title bar"
	)
	check_eq(
		palette.get_parent(),
		surface.get_floating_layer(),
		"floating collapse must keep the module in the floating layer"
	)
	check_true(not palette_content.visible, "floating collapse should hide only panel content")
	check_eq(palette.position, floating_rect.position, "floating collapse should keep its position")
	check_eq(palette.size.x, floating_rect.size.x, "floating collapse should keep its width")
	check_eq(
		palette.get_visual_rect().size.y,
		palette.get_header_height(),
		"floating collapse should expose only the header as its visual frame"
	)
	check_true(
		not palette.is_resize_point(
			Vector2(palette.size.x - 2.0, palette.get_header_height() - 2.0)
		),
		"floating collapse should disable its resize affordance"
	)
	check_true(surface.restore_module(Builtins.PALETTE_ID), "floating Palette should restore")
	check_true(palette_content.visible, "restoring the floating bar should reveal its content")
	check_eq(
		surface.get_module_placement(Builtins.PALETTE_ID),
		Surface.Placement.FLOATING,
		"Restore should recover FLOATING placement"
	)
	check_eq(
		surface.get_floating_rect(Builtins.PALETTE_ID),
		floating_rect,
		"Restore should recover the floating rectangle"
	)
	check_eq(
		manager.get_instance(Builtins.PALETTE_ID),
		palette,
		"floating collapse/restore must preserve the instance"
	)

	var restricted := Definition.new()
	restricted.module_id = &"test.restricted"
	restricted.display_name = "Restricted"
	restricted.content_scene = load(PREVIEW_SCENE_PATH)
	restricted.can_float = false
	restricted.can_collapse = false
	check_true(manager.register_definition(restricted), "restricted definition should register")
	check_true(
		surface.dock_module(restricted.module_id, DockLayout.DockZone.TOP),
		"restricted module may still dock"
	)
	check_true(
		not surface.float_module(restricted.module_id, Rect2(100.0, 100.0, 300.0, 200.0)),
		"can_float=false must reject floating"
	)
	check_true(
		not surface.collapse_module(restricted.module_id), "can_collapse=false must reject collapse"
	)
	_free_workspace(workspace)
