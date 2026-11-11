extends "res://tests/test_base.gd"

const Profile3 := preload("res://src/UI/Workspace/WorkspaceUIProfile3.gd")
const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")


func test_quick_strip_never_crosses_timeline_safe_boundary() -> void:
	var content := Rect2(Vector2(8.0, 0.0), Vector2(1184.0, 510.0))
	var long_selection := Vector2(100.0, 780.0)
	var rect := Profile3.find_quick_rect(content, long_selection)
	check_true(rect.has_area(), "long selection controls keep a visible strip")
	check_eq(rect.position, Vector2(16.0, 68.0), "left controls have an invariant anchor")
	check_true(rect.end.y <= content.end.y, "strip does not cover the docked Timeline")
	check_true(rect.size.y < long_selection.y, "long tool controls require scrolling")


func test_quick_strip_remains_fixed_when_preview_moves() -> void:
	var available := Rect2(Vector2(8.0, 0.0), Vector2(1100.0, 510.0))
	var rect := Profile3.find_quick_rect(available, Vector2(100.0, 400.0))
	check_eq(rect.position, Vector2(16.0, 68.0), "left strip keeps its own anchor")
	check_eq(
		Profile3.find_quick_rect(available, Vector2(100.0, 400.0)),
		rect,
		"Preview movement cannot relocate the fixed strip"
	)


func test_quick_strip_scroll_and_float_panels_on_top() -> void:
	var root := Control.new()
	root.size = Vector2(1100.0, 800.0)
	tree.root.add_child(root)
	var manager := WorkspaceModuleManager.new()
	root.add_child(manager)
	check_true(Builtins.register_defaults(manager), "workspace modules register")
	var dock := WorkspaceDockHost.new()
	root.add_child(dock)
	dock.size = Vector2(1100.0, 720.0)
	check_true(dock.setup(manager), "dock host initializes")
	var surface := WorkspaceSurface.new()
	root.add_child(surface)
	check_true(surface.setup(manager, dock), "Workspace surface initializes")
	var left := ScrollContainer.new()
	root.add_child(left)
	var profile := Profile3.new()
	root.add_child(profile)
	check_true(profile.setup(root, left, surface), "profile has Workspace coordinates")
	check_true(profile._create_quick_bar(), "quick bar builds")
	check_eq(profile._quick_bar.get_parent(), dock, "quick bar belongs to Workspace host")
	check_true(
		profile._quick_bar.get_index() < surface.get_floating_layer().get_index(),
		"floating settings must render above the quick strip",
	)
	check_eq(
		profile._quick_bar.find_child("MoreToolOptions", true, false),
		null,
		"left strip contains only Pencil/Eraser controls, not another options entry",
	)
	check_eq(
		profile._quick_scroll.vertical_scroll_mode,
		ScrollContainer.SCROLL_MODE_AUTO,
		"the quick bar scrolls when controls exceed its safe height",
	)
	root.queue_free()
	await tree.process_frame


func test_timeline_layout_changes_trigger_quick_relayout() -> void:
	var source := FileAccess.get_file_as_string("res://src/UI/Workspace/WorkspaceUIProfile3.gd")
	check_has(
		source,
		"surface.dock_host.layout_geometry_changed.connect(_on_quick_layout_changed)",
		"Timeline resizing must update quick-strip available area",
	)
	check_true(
		not source.contains("_on_quick_floating_changed"),
		"floating-window movement must not reposition the quick strip",
	)
	check_has(
		source,
		"surface.set_floating_exclusion_rect(",
		"UI3 declares reserved space to the floating-window constraint system",
	)
	check_true(
		not source.contains("_quick_bar.z_index = 50"),
		"quick-strip draw order must not hide Tool Settings",
	)


func test_live_timeline_height_limits_actual_quick_panel() -> void:
	var root := Control.new()
	root.size = Vector2(920.0, 640.0)
	tree.root.add_child(root)
	var manager := WorkspaceModuleManager.new()
	root.add_child(manager)
	check_true(Builtins.register_defaults(manager), "all Workspace definitions register")
	var host := WorkspaceDockHost.new()
	root.add_child(host)
	host.size = root.size
	check_true(host.setup(manager), "Workspace host initializes")
	var surface := WorkspaceSurface.new()
	root.add_child(surface)
	check_true(surface.setup(manager, host), "Workspace surface initializes")
	check_true(
		host.layout.place_module(Builtins.TIMELINE_ID, WorkspaceDockLayout.DockZone.BOTTOM, 0),
		"Timeline occupies the bottom dock",
	)
	check_true(
		host.layout.set_module_size(Builtins.TIMELINE_ID, Vector2(880.0, 270.0)),
		"Timeline height is set",
	)
	host.refresh_layout_geometry()
	var profile := Profile3.new()
	root.add_child(profile)
	var source := ScrollContainer.new()
	root.add_child(source)
	check_true(profile.setup(root, source, surface), "profile uses live Workspace geometry")
	check_true(profile._create_quick_bar(), "left touch bar exists")
	profile.active = true
	profile._quick_has_controls = true
	profile._quick_title.text = "Selection"
	for index in 18:
		var control := Button.new()
		control.text = "Mode %d" % index
		control.custom_minimum_size = Vector2(56.0, 30.0)
		profile._quick_controls.add_child(control)
	await tree.process_frame
	profile._place_quick_bar()
	check_eq(
		profile._quick_bar.position.y, 68.0, "Timeline resizing does not move the fixed anchor"
	)
	var content := host.get_content_rect()
	check_true(
		profile._quick_bar.get_rect().end.y <= content.end.y,
		"long quick bar does not overlap actual docked Timeline",
	)
	check_true(
		profile._quick_bar.size.y < profile._quick_controls.get_combined_minimum_size().y,
		"long quick controls use internal scrolling",
	)
	check_true(profile._quick_bar.visible, "quick bar remains accessible")
	check_true(
		profile._quick_scroll.get_global_rect().end.y <= profile._quick_bar.get_global_rect().end.y,
		"scrolling Pencil/Eraser controls stay within the visible strip",
	)
	root.queue_free()
	await tree.process_frame
