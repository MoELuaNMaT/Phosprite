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


func test_ui3_floating_exclusion_prevents_preview_drag_resize_and_restore_overlap() -> void:
	var manager := Manager.new()
	var host := DockHost.new()
	var surface := Surface.new()
	check_true(manager.register_definition(_preview_definition()), "Preview definition registers")
	host.size = Vector2(1100.0, 760.0)
	check_true(host.setup(manager), "dock host initializes")
	check_true(surface.setup(manager, host), "surface initializes")
	var fixed := Rect2(Vector2(8.0, 68.0), Vector2(100.0, 410.0))
	surface.set_floating_exclusion_rect(&"ui3.quick_controls", fixed.grow(8.0))
	check_true(
		surface.float_module(&"test.preview", Rect2(Vector2(10.0, 110.0), Vector2(328.0, 220.0))),
		"Preview can be floated while the strip is reserved"
	)
	var initial := surface.get_floating_rect(&"test.preview")
	check_true(not initial.intersects(fixed), "initial Preview cannot cover the fixed strip")
	check_true(initial.position.x >= fixed.end.x, "Preview moves to the right of the strip")
	check_true(
		surface.set_floating_rect(
			&"test.preview", Rect2(Vector2(0.0, 140.0), Vector2(328.0, 220.0))
		),
		"moving Preview against the strip commits a constrained rectangle"
	)
	var after_drag := surface.get_floating_rect(&"test.preview")
	check_true(not after_drag.intersects(fixed), "dragged Preview cannot overlap fixed controls")
	check_eq(after_drag.position.x, initial.position.x, "repeated drag does not push Preview away")
	check_true(
		surface.resize_floating_rect(
			&"test.preview", after_drag, Vector2(-120.0, 0.0), WorkspaceModule.ResizeEdge.LEFT
		),
		"left resize commits"
	)
	check_true(
		not surface.get_floating_rect(&"test.preview").intersects(fixed),
		"resizing Preview cannot overlap the quick controls"
	)
	# Returning from a different UI profile releases the reservation.
	surface.set_floating_exclusion_rect(&"ui3.quick_controls", Rect2())
	check_true(
		surface.set_floating_rect(
			&"test.preview", Rect2(Vector2(0.0, 140.0), Vector2(328.0, 220.0))
		),
		"normal floating placement remains available outside UI3"
	)
	check_eq(
		surface.get_floating_rect(&"test.preview").position.x, 0.0,
		"UI1/UI4 do not inherit UI3's reserved region"
	)
	surface.set_floating_exclusion_rect(&"ui3.quick_controls", fixed.grow(8.0))
	check_true(
		not surface.get_floating_rect(&"test.preview").intersects(fixed),
		"enabling UI3 repairs existing Preview overlap"
	)
	manager.destroy_all_modules()
	surface.free()
	host.free()
	manager.free()


func test_floating_exclusion_handles_oversized_preview_without_overlap() -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(1000.0, 600.0))
	var fixed := Rect2(Vector2(8.0, 68.0), Vector2(100.0, 460.0))
	var exclusions: Array[Rect2] = [fixed.grow(8.0)]
	var requested := Rect2(Vector2(0.0, 100.0), Vector2(970.0, 340.0))
	var rect := Surface.avoid_floating_exclusions(
		requested, bounds, exclusions, Vector2(160.0, 110.0)
	)
	check_true(not rect.intersects(fixed), "oversized window also stays outside the fixed strip")
	check_true(rect.size.x < requested.size.x, "only the impossible dimension is reduced")
	check_true(rect.size.x >= 160.0, "window never shrinks below its minimum width")
	check_true(bounds.encloses(rect), "constrained Preview remains inside the Workspace")


func _preview_definition() -> Definition:
	var definition := Definition.new()
	definition.module_id = &"test.preview"
	definition.display_name = "Preview"
	definition.content_scene = load(PREVIEW_SCENE_PATH)
	definition.minimum_size = Vector2(160.0, 110.0)
	definition.preferred_size = Vector2(328.0, 220.0)
	definition.maximum_size = Vector2(1200.0, 900.0)
	return definition
