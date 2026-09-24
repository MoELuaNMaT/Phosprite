extends "res://tests/test_base.gd"

const Definition := preload("res://src/UI/Workspace/WorkspaceModuleDefinition.gd")
const Manager := preload("res://src/UI/Workspace/WorkspaceModuleManager.gd")
const DockHost := preload("res://src/UI/Workspace/WorkspaceDockHost.gd")
const Surface := preload("res://src/UI/Workspace/WorkspaceSurface.gd")
const PREVIEW_SCENE_PATH := "res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.tscn"


func test_floating_rect_respects_definition_and_workspace_bounds() -> void:
	var manager := Manager.new()
	var host := DockHost.new()
	var surface := Surface.new()
	var definition := Definition.new()
	definition.module_id = &"test.constrained"
	definition.display_name = "Constrained"
	definition.content_scene = load(PREVIEW_SCENE_PATH)
	definition.minimum_size = Vector2(200.0, 150.0)
	definition.preferred_size = Vector2(300.0, 200.0)
	definition.maximum_size = Vector2(400.0, 300.0)
	check_true(manager.register_definition(definition), "definition should register")

	host.size = Vector2(1200.0, 800.0)
	check_true(host.setup(manager), "dock host should initialize")
	check_true(surface.setup(manager, host), "surface should initialize")
	check_true(
		surface.float_module(
			definition.module_id, Rect2(Vector2(-40.0, 790.0), Vector2(20.0, 900.0))
		),
		"constrained module should float"
	)
	check_eq(
		surface.get_floating_rect(definition.module_id),
		Rect2(Vector2(0.0, 500.0), Vector2(200.0, 300.0)),
		"floating rect should clamp size and stay inside the workspace"
	)

	manager.destroy_all_modules()
	surface.free()
	host.free()
	manager.free()
