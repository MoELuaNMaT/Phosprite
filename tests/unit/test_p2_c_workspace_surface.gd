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
	var manager = workspace["manager"]
	var host = workspace["host"]
	var surface = workspace["surface"]
	manager.destroy_all_modules()
	surface.free()
	host.free()
	manager.free()


func test_float_preserves_instance_and_detaches_from_dock_model() -> void:
	var workspace := _make_workspace()
	var manager = workspace["manager"]
	var host = workspace["host"]
	var surface = workspace["surface"]

	check_true(
		surface.dock_module(Builtins.PREVIEW_ID, DockLayout.DockZone.LEFT),
		"Preview should start docked"
	)
	var preview := manager.get_instance(Builtins.PREVIEW_ID)
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
	var manager = workspace["manager"]
	var host = workspace["host"]
	var surface = workspace["surface"]

	check_true(
		surface.float_module(Builtins.PREVIEW_ID, Rect2(420.0, 180.0, 320.0, 220.0)),
		"Preview should start floating"
	)
	var preview := manager.get_instance(Builtins.PREVIEW_ID)
	check_true(
		surface.begin_module_drag(Builtins.PREVIEW_ID, Vector2(500.0, 220.0)),
		"floating module drag should begin"
	)
	var left_rect: Rect2 = host.get_zone_rects()[DockLayout.DockZone.LEFT]
	var candidate := surface.update_module_drag(left_rect.get_center())
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


func test_collapse_peek_and_restore_preserve_docked_placement() -> void:
	var workspace := _make_workspace()
	var manager = workspace["manager"]
	var host = workspace["host"]
	var surface = workspace["surface"]

	check_true(
		surface.dock_module(
			Builtins.PREVIEW_ID, DockLayout.DockZone.RIGHT, 0, Vector2(300.0, 180.0)
		),
		"Preview should dock before collapse"
	)
	var preview := manager.get_instance(Builtins.PREVIEW_ID)
	check_true(surface.collapse_module(Builtins.PREVIEW_ID), "docked Preview should collapse")
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		Surface.Placement.COLLAPSED,
		"collapsed module should enter COLLAPSED placement"
	)
	check_eq(preview.get_parent(), null, "collapsed module should be unmounted")
	check_eq(
		host.layout.get_module_zone(Builtins.PREVIEW_ID),
		DockLayout.DockZone.NONE,
		"collapsed module should not occupy a dock slot"
	)

	var restore := surface.get_restore_state(Builtins.PREVIEW_ID)
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

	check_true(surface.peek_module(Builtins.PREVIEW_ID), "collapsed module should support Peek")
	check_true(surface.is_peeking(Builtins.PREVIEW_ID), "Peek state should be reported")
	check_eq(
		preview.get_parent(),
		surface.get_peek_layer(),
		"Peek should temporarily mount the same instance in the peek layer"
	)
	check_true(surface.end_peek(Builtins.PREVIEW_ID), "Peek should close without restoring")
	check_eq(preview.get_parent(), null, "ending Peek should return module to collapsed state")

	check_true(surface.restore_module(Builtins.PREVIEW_ID), "collapsed module should restore")
	check_eq(
		manager.get_instance(Builtins.PREVIEW_ID),
		preview,
		"Collapse/Peek/Restore must preserve the managed instance"
	)
	check_eq(
		host.layout.get_module_zone(Builtins.PREVIEW_ID),
		DockLayout.DockZone.RIGHT,
		"Restore should return Preview to its previous dock"
	)
	check_eq(
		host.layout.get_module_size(Builtins.PREVIEW_ID),
		Vector2(300.0, 180.0),
		"Restore should recover the previous dock size"
	)
	_free_workspace(workspace)


func test_collapse_restores_floating_rect_and_honors_capabilities() -> void:
	var workspace := _make_workspace()
	var manager = workspace["manager"]
	var surface = workspace["surface"]
	var floating_rect := Rect2(500.0, 240.0, 340.0, 240.0)

	check_true(
		surface.float_module(Builtins.PALETTE_ID, floating_rect), "Palette should become floating"
	)
	var palette := manager.get_instance(Builtins.PALETTE_ID)
	var palette_content := palette.get_content()
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
		palette.size.y,
		palette.get_header_height(),
		"floating collapse should shrink to header height"
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
