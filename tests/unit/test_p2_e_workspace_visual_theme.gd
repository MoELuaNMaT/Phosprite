extends "res://tests/test_base.gd"

const Manager := preload("res://src/UI/Workspace/WorkspaceModuleManager.gd")
const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const DockLayout := preload("res://src/UI/Workspace/WorkspaceDockLayout.gd")
const DockHost := preload("res://src/UI/Workspace/WorkspaceDockHost.gd")
const Surface := preload("res://src/UI/Workspace/WorkspaceSurface.gd")
const VisualTheme := preload("res://src/UI/Workspace/WorkspaceVisualTheme.gd")
const ThemeController := preload("res://src/UI/Workspace/WorkspaceThemeController.gd")


func _make_source_theme(panel_color: Color, font_color: Color) -> Theme:
	var source_theme := Theme.new()
	var panel := StyleBoxFlat.new()
	panel.bg_color = panel_color
	source_theme.set_stylebox(&"panel", &"PanelContainer", panel)
	source_theme.set_color(&"font_color", &"Label", font_color)
	source_theme.default_font = ThemeDB.fallback_font
	source_theme.default_font_size = 16
	return source_theme


func _make_workspace() -> Dictionary:
	var manager := Manager.new()
	var host := DockHost.new()
	var surface := Surface.new()
	var controller := ThemeController.new()
	Builtins.register_defaults(manager)
	host.size = Vector2(1200.0, 800.0)
	check_true(host.setup(manager), "dock host should initialize")
	check_true(surface.setup(manager, host), "surface should initialize")
	check_true(controller.setup(manager, surface), "theme controller should initialize")
	return {
		"manager": manager,
		"host": host,
		"surface": surface,
		"controller": controller,
	}


func _free_workspace(workspace: Dictionary) -> void:
	var manager = workspace["manager"]
	var host = workspace["host"]
	var surface = workspace["surface"]
	var controller = workspace["controller"]
	controller.free()
	manager.destroy_all_modules()
	surface.free()
	host.free()
	manager.free()


func test_visual_theme_derives_from_active_application_theme() -> void:
	var workspace_theme := VisualTheme.new()
	var dark_theme := _make_source_theme(Color("20242a"), Color("f2f4f8"))
	var accent := Color("7997e8")
	check_true(
		workspace_theme.refresh(dark_theme, Color("20242a"), accent, 0.35),
		"dark source theme should refresh"
	)
	check_eq(
		workspace_theme.surface_color,
		Color("20242a"),
		"Workspace surface should inherit the application's panel color"
	)
	check_eq(workspace_theme.text_color, Color("f2f4f8"), "Workspace should inherit label text")
	check_eq(workspace_theme.accent_color, accent, "Workspace should inherit active accent")
	check_eq(
		workspace_theme.get_module_style(&"docked").border_width_left,
		VisualTheme.BORDER_WIDTH,
		"docked chrome should use the normal border"
	)
	check_eq(
		workspace_theme.get_module_style(&"floating").border_width_left,
		VisualTheme.FLOATING_BORDER_WIDTH,
		"floating chrome should use the elevated border"
	)

	var dark_header := workspace_theme.header_color
	var light_theme := _make_source_theme(Color("e7edf3"), Color("1e2329"))
	check_true(
		workspace_theme.refresh(light_theme, Color("e7edf3"), Color("4b5f96"), 0.3),
		"light source theme should refresh"
	)
	check_eq(
		workspace_theme.surface_color,
		Color("e7edf3"),
		"light theme should replace the Workspace surface color"
	)
	check_true(
		not workspace_theme.header_color.is_equal_approx(dark_header),
		"semantic chrome colors should change when the application theme changes"
	)


func test_controller_tracks_placement_and_preserves_module_identity() -> void:
	var workspace := _make_workspace()
	var manager = workspace["manager"]
	var surface = workspace["surface"]
	var controller = workspace["controller"]
	var source_theme := _make_source_theme(Color("282c33"), Color("f0f2f5"))
	check_true(
		controller.refresh(source_theme, Color("282c33"), Color("8ca5ef"), 0.3),
		"controller should accept the active theme"
	)

	check_true(
		surface.dock_module(Builtins.PREVIEW_ID, DockLayout.DockZone.LEFT), "Preview should dock"
	)
	var preview := manager.get_instance(Builtins.PREVIEW_ID)
	var content := preview.get_content()
	check_eq(preview.get_visual_state(), &"docked", "docked module should use docked chrome")

	check_true(
		surface.float_module(Builtins.PREVIEW_ID, Rect2(420.0, 180.0, 340.0, 240.0)),
		"Preview should float"
	)
	check_eq(
		manager.get_instance(Builtins.PREVIEW_ID), preview, "theme chrome must preserve identity"
	)
	check_eq(preview.get_content(), content, "theme chrome must preserve the original content root")
	check_eq(preview.get_visual_state(), &"floating", "floating module should use floating chrome")

	check_true(surface.collapse_module(Builtins.PREVIEW_ID), "Preview should collapse")
	check_eq(
		preview.get_visual_state(), &"collapsed", "collapsed module should retain collapsed state"
	)
	check_true(surface.peek_module(Builtins.PREVIEW_ID), "collapsed Preview should Peek")
	check_eq(preview.get_visual_state(), &"peek", "Peek should use elevated peek chrome")
	check_true(surface.end_peek(Builtins.PREVIEW_ID), "Peek should close")
	check_eq(
		preview.get_visual_state(), &"collapsed", "ending Peek should recover collapsed chrome"
	)
	_free_workspace(workspace)


func test_theme_refresh_updates_both_snap_previews() -> void:
	var workspace := _make_workspace()
	var host = workspace["host"]
	var controller = workspace["controller"]
	var source_theme := _make_source_theme(Color("30343c"), Color.WHITE)
	var accent := Color("9ab1f4")
	check_true(
		controller.refresh(source_theme, Color("30343c"), accent, 0.3),
		"controller should refresh previews"
	)
	var expected := controller.visual_theme.preview_color
	var dock_preview := host.get_node(^"DockSnapPreview") as ColorRect
	var surface_preview := host.get_node(^"WorkspaceSurfacePreview") as ColorRect
	check_eq(dock_preview.color, expected, "dock snap preview should use Workspace accent")
	check_eq(surface_preview.color, expected, "floating snap preview should use the same accent")
	_free_workspace(workspace)