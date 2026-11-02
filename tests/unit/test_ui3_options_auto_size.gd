extends "res://tests/test_base.gd"

const Profile3 := preload("res://src/UI/Workspace/WorkspaceUIProfile3.gd")
const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")


func test_content_sized_popup_is_short_for_small_tool_and_grows_for_long_options() -> void:
	var definition := WorkspaceModuleDefinition.new()
	definition.minimum_size = Vector2(208.0, 112.0)
	definition.preferred_size = Vector2(260.0, 220.0)
	definition.maximum_size = Vector2(360.0, 620.0)
	var safe := Rect2(Vector2.ZERO, Vector2(1024.0, 700.0))
	var short := Profile3.content_sized_options(Vector2(180.0, 60.0), 0.0, safe, definition)
	var long := Profile3.content_sized_options(Vector2(210.0, 700.0), 0.0, safe, definition)
	check_true(short.y < 220.0, "short tool opens below the previous fixed 440px height")
	check_true(long.y > short.y, "long visible option lists open a taller window")
	check_true(long.y <= 700.0 * Profile3.OPTIONS_MAX_VIEWPORT_RATIO,
		"long tool options scroll without crossing the Workspace safe bounds")
	check_true(short.x >= 208.0, "options remain wide enough for touch controls")
	var family := Profile3.content_sized_options(Vector2(180.0, 60.0), 42.0, safe, definition)
	check_true(family.y > short.y, "selection or shape tool families add their own height")


func test_content_size_obeys_small_ipad_canvas_without_covering_timeline() -> void:
	var definition := WorkspaceModuleDefinition.new()
	definition.minimum_size = Vector2(208.0, 112.0)
	definition.maximum_size = Vector2(360.0, 620.0)
	var safe := Rect2(Vector2(8.0, 0.0), Vector2(600.0, 280.0))
	var result := Profile3.content_sized_options(Vector2(350.0, 900.0), 36.0, safe, definition)
	check_true(result.x <= safe.size.x, "popup fits within available canvas width")
	check_true(result.y <= safe.size.y * Profile3.OPTIONS_MAX_VIEWPORT_RATIO,
		"popup leaves room for Timeline and canvas interactions")


func test_click_on_blank_canvas_closes_settings_but_not_inside_popup() -> void:
	var root := Control.new()
	root.size = Vector2(900.0, 640.0)
	tree.root.add_child(root)
	var manager := WorkspaceModuleManager.new()
	root.add_child(manager)
	check_true(Builtins.register_defaults(manager), "Workspace definitions register")
	var dock := WorkspaceDockHost.new()
	root.add_child(dock)
	dock.size = root.size
	check_true(dock.setup(manager), "Workspace dock host initializes")
	var surface := WorkspaceSurface.new()
	root.add_child(surface)
	check_true(surface.setup(manager, dock), "Workspace surface initializes")
	var left_options := ScrollContainer.new()
	root.add_child(left_options)
	var profile := Profile3.new()
	root.add_child(profile)
	check_true(profile.setup(root, left_options, surface), "UI3 profile initializes")
	check_true(
		surface.float_module(Builtins.UI3_TOOL_OPTIONS_ID, Rect2(500.0, 20.0, 260.0, 200.0)),
		"real settings module is open",
	)
	profile.active = true
	profile._advanced_open = true
	check_true(
		not profile._is_blank_canvas_point(Vector2(550.0, 60.0)),
		"taps inside Tool Options must never dismiss it",
	)
	check_true(profile._is_blank_canvas_point(Vector2(350.0, 300.0)),
		"empty canvas is a valid dismissal target")
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	outside.position = Vector2(350.0, 300.0)
	profile._input(outside)
	check_true(not profile._advanced_open, "blank canvas tap dismisses options")
	check_eq(
		surface.get_module_placement(Builtins.UI3_TOOL_OPTIONS_ID),
		WorkspaceSurface.Placement.NONE,
		"settings title and contents are fully parked",
	)
	root.queue_free()
	await tree.process_frame
