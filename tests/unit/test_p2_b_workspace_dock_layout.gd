extends "res://tests/test_base.gd"

const Definition := preload("res://src/UI/Workspace/WorkspaceModuleDefinition.gd")
const Manager := preload("res://src/UI/Workspace/WorkspaceModuleManager.gd")
const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const DockLayout := preload("res://src/UI/Workspace/WorkspaceDockLayout.gd")
const DockResolver := preload("res://src/UI/Workspace/WorkspaceDockDragResolver.gd")
const DockHost := preload("res://src/UI/Workspace/WorkspaceDockHost.gd")
const PREVIEW_SCENE_PATH := "res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.tscn"


func test_layout_moves_and_reorders_modules_across_four_zones() -> void:
	var manager := Manager.new()
	var layout := DockLayout.new()
	Builtins.register_defaults(manager)
	check_true(layout.configure(manager), "dock layout should accept the workspace manager")

	check_true(
		layout.place_module(Builtins.PREVIEW_ID, DockLayout.DockZone.LEFT),
		"Preview should dock on the left"
	)
	check_true(
		layout.place_module(Builtins.PALETTE_ID, DockLayout.DockZone.LEFT),
		"Palette should dock on the left"
	)
	check_eq(
		layout.get_modules(DockLayout.DockZone.LEFT),
		[Builtins.PREVIEW_ID, Builtins.PALETTE_ID],
		"left dock should preserve insertion order"
	)

	check_true(
		layout.place_module(Builtins.PALETTE_ID, DockLayout.DockZone.LEFT, 0),
		"Palette should reorder within the left dock"
	)
	check_eq(
		layout.get_modules(DockLayout.DockZone.LEFT),
		[Builtins.PALETTE_ID, Builtins.PREVIEW_ID],
		"same-zone placement should deterministically reorder modules"
	)

	for zone in [
		DockLayout.DockZone.TOP,
		DockLayout.DockZone.RIGHT,
		DockLayout.DockZone.BOTTOM,
	]:
		check_true(
			layout.place_module(Builtins.PREVIEW_ID, zone),
			"Preview should move to dock zone %s" % DockLayout.zone_name(zone)
		)
		check_eq(
			layout.get_module_zone(Builtins.PREVIEW_ID),
			zone,
			"layout should record the current dock zone"
		)

	check_eq(
		layout.get_modules(DockLayout.DockZone.LEFT),
		[Builtins.PALETTE_ID],
		"moving Preview away should remove it from the previous dock"
	)
	manager.free()


func test_layout_clamps_size_and_rejects_non_dockable_modules() -> void:
	var manager := Manager.new()
	var layout := DockLayout.new()
	Builtins.register_defaults(manager)

	var fixed := Definition.new()
	fixed.module_id = &"test.fixed"
	fixed.display_name = "Fixed"
	fixed.content_scene = load(PREVIEW_SCENE_PATH)
	fixed.minimum_size = Vector2(100.0, 80.0)
	fixed.preferred_size = Vector2(180.0, 120.0)
	fixed.maximum_size = Vector2(300.0, 200.0)
	fixed.can_dock = false
	check_true(manager.register_definition(fixed), "test module definition should register")
	check_true(layout.configure(manager), "dock layout should configure")
	check_true(
		not layout.place_module(fixed.module_id, DockLayout.DockZone.TOP),
		"modules that declare can_dock=false must be rejected"
	)

	check_true(
		layout.place_module(Builtins.PREVIEW_ID, DockLayout.DockZone.RIGHT),
		"Preview should dock before its size is changed"
	)
	check_true(
		layout.set_module_size(Builtins.PREVIEW_ID, Vector2(10.0, 20.0)),
		"docked module size should be settable"
	)
	check_eq(
		layout.get_module_size(Builtins.PREVIEW_ID),
		Vector2(220.0, 110.0),
		"requested dock size should obey the module minimum"
	)
	manager.free()


func test_drag_resolver_returns_insert_position_and_snap_preview() -> void:
	var manager := Manager.new()
	var layout := DockLayout.new()
	Builtins.register_defaults(manager)
	layout.configure(manager)
	layout.place_module(Builtins.PREVIEW_ID, DockLayout.DockZone.LEFT)
	layout.place_module(Builtins.PALETTE_ID, DockLayout.DockZone.LEFT)

	var zone_rects := {
		DockLayout.DockZone.LEFT: Rect2(0.0, 0.0, 300.0, 700.0),
		DockLayout.DockZone.TOP: Rect2(300.0, 0.0, 700.0, 100.0),
		DockLayout.DockZone.RIGHT: Rect2(1000.0, 0.0, 300.0, 700.0),
		DockLayout.DockZone.BOTTOM: Rect2(300.0, 700.0, 700.0, 100.0),
	}
	var module_rects := {
		DockLayout.DockZone.LEFT:
		[
			{"module_id": Builtins.PREVIEW_ID, "rect": Rect2(0.0, 0.0, 300.0, 220.0)},
			{"module_id": Builtins.PALETTE_ID, "rect": Rect2(0.0, 220.0, 300.0, 300.0)},
		]
	}

	var candidate := DockResolver.resolve(
		Builtins.PREVIEW_ID, Vector2(120.0, 500.0), zone_rects, module_rects, layout
	)
	check_true(bool(candidate.get("valid", false)), "pointer inside a dock should resolve")
	check_eq(
		int(candidate.get("zone", DockLayout.DockZone.NONE)),
		DockLayout.DockZone.LEFT,
		"drag candidate should target the left dock"
	)
	check_eq(
		int(candidate.get("index", -1)),
		1,
		"dragging below Palette should insert Preview after Palette"
	)
	var preview_rect: Rect2 = candidate.get("preview_rect", Rect2())
	check_true(preview_rect.has_area(), "valid drag candidate should expose a snap preview rect")

	var outside := DockResolver.resolve(
		Builtins.PREVIEW_ID, Vector2(5000.0, 5000.0), zone_rects, module_rects, layout
	)
	check_true(
		not bool(outside.get("valid", true)),
		"P2-B must not create a floating target outside the four dock zones"
	)
	manager.free()


func test_dock_host_reparents_reorders_and_commits_cross_zone_drag() -> void:
	var manager := Manager.new()
	var host := DockHost.new()
	Builtins.register_defaults(manager)
	check_true(host.setup(manager), "dock host should initialize from the workspace manager")
	host.size = Vector2(1200.0, 800.0)

	check_true(
		host.dock_module(Builtins.PREVIEW_ID, DockLayout.DockZone.TOP),
		"Preview should mount in the top dock"
	)
	var preview := manager.get_instance(Builtins.PREVIEW_ID)
	check_eq(
		preview.get_parent(),
		host.get_zone_host(DockLayout.DockZone.TOP),
		"mounted module should be parented by its dock zone"
	)

	for zone in [DockLayout.DockZone.LEFT, DockLayout.DockZone.RIGHT, DockLayout.DockZone.BOTTOM]:
		check_true(
			host.dock_module(Builtins.PREVIEW_ID, zone),
			"Preview should move to %s without losing its instance" % DockLayout.zone_name(zone)
		)
		check_eq(
			manager.get_instance(Builtins.PREVIEW_ID),
			preview,
			"dock moves should preserve the managed WorkspaceModule instance"
		)
		check_eq(
			preview.get_parent(),
			host.get_zone_host(zone),
			"module parent should follow its current dock zone"
		)

	check_true(
		host.dock_module(Builtins.PALETTE_ID, DockLayout.DockZone.BOTTOM, 0),
		"Palette should insert before Preview in the bottom dock"
	)
	check_eq(
		host.layout.get_modules(DockLayout.DockZone.BOTTOM),
		[Builtins.PALETTE_ID, Builtins.PREVIEW_ID],
		"dock host should keep model order synchronized"
	)
	check_eq(
		host.get_zone_host(DockLayout.DockZone.BOTTOM).get_child(0),
		manager.get_instance(Builtins.PALETTE_ID),
		"rendered child order should match dock model order"
	)

	check_true(
		host.dock_module(Builtins.PREVIEW_ID, DockLayout.DockZone.LEFT),
		"Preview should move back to the left before drag testing"
	)
	check_true(host.begin_module_drag(Builtins.PREVIEW_ID), "docked module should begin a drag")
	var right_rect: Rect2 = host.get_zone_rects()[DockLayout.DockZone.RIGHT]
	var candidate := host.update_module_drag(right_rect.get_center())
	check_eq(
		int(candidate.get("zone", DockLayout.DockZone.NONE)),
		DockLayout.DockZone.RIGHT,
		"dragging over the right dock should produce a right-dock target"
	)
	check_true(host.get_preview_rect().has_area(), "dragging should expose the snap preview")
	check_true(host.commit_module_drag(), "valid drag target should commit")
	check_eq(
		host.layout.get_module_zone(Builtins.PREVIEW_ID),
		DockLayout.DockZone.RIGHT,
		"committed drag should move the module to the target dock"
	)
	check_true(
		not host.get_preview_rect().has_area(),
		"snap preview should clear after a drag transaction finishes"
	)

	manager.destroy_all_modules()
	host.free()
	manager.free()
