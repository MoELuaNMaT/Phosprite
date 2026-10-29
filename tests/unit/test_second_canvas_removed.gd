extends "res://tests/test_base.gd"

const BUILTINS := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const UI_SCENE := preload("res://src/UI/UI.tscn")
const MANAGER := preload("res://src/UI/Workspace/WorkspaceModuleManager.gd")
const DOCK_HOST := preload("res://src/UI/Workspace/WorkspaceDockHost.gd")
const SURFACE := preload("res://src/UI/Workspace/WorkspaceSurface.gd")
const STORE := preload("res://src/UI/Workspace/WorkspaceLayoutStore.gd")


func test_editor_scene_no_longer_contains_secondary_canvas_viewport() -> void:
	var editor := UI_SCENE.instantiate()
	check_true(
		editor.get_node_or_null(^"DockableContainer/Second Canvas") == null,
		"Second Canvas must not be instantiated in the editor"
	)
	check_true(
		editor.get_node_or_null(
			^"DockableContainer/Main Canvas/ViewportandVerticalRuler/SubViewportContainer"
		) != null,
		"the original main canvas must remain"
	)
	check_true(
		editor.get_node_or_null(^"DockableContainer/Canvas Preview") != null,
		"the separate Preview panel must remain"
	)
	editor.free()


func test_workspace_does_not_register_or_expose_second_canvas() -> void:
	var manager := MANAGER.new()
	check_true(BUILTINS.register_defaults(manager), "Workspace built-ins register")
	check_true(not manager.has_definition(&"second_canvas"), "Second Canvas cannot be created")
	check_true(
		not BUILTINS.get_live_panel_ids().has(&"second_canvas"),
		"Second Canvas is not part of the Window > Panels menu"
	)
	check_eq(
		BUILTINS.get_live_panel_node_name(BUILTINS.PREVIEW_ID),
		"Canvas Preview",
		"Preview keeps its independent identity"
	)
	check_true(manager.has_definition(BUILTINS.PREVIEW_ID), "Preview remains registered")
	manager.free()


func test_old_layout_presets_have_no_second_canvas_reference() -> void:
	for path in ["res://assets/layouts/Default.tres", "res://assets/layouts/Tallscreen.tres"]:
		var content := FileAccess.get_file_as_string(path)
		check_true(not content.contains("Second Canvas"), "old layout no longer lists Second Canvas")
		check_true(content.contains("Main Canvas"), "main canvas remains in layout")
		check_true(content.contains("Canvas Preview"), "Preview remains in layout")


func test_old_saved_workspace_snapshot_safely_ignores_second_canvas() -> void:
	var manager := MANAGER.new()
	check_true(BUILTINS.register_defaults(manager), "register built-in Workspace modules")
	var host := DOCK_HOST.new()
	host.size = Vector2(1000.0, 700.0)
	check_true(host.setup(manager), "dock host initializes")
	var surface := SURFACE.new()
	check_true(surface.setup(manager, host), "Workspace surface initializes")
	var store := STORE.new()
	check_true(store.setup(surface, ConfigFile.new()), "layout store initializes")
	store.autosave_enabled = false
	var snapshot := store.capture_snapshot()
	(snapshot["modules"] as Array).append(
		{"id": "second_canvas", "placement": "floating", "rect": [50.0, 60.0, 250.0, 180.0]}
	)
	check_true(store.apply_snapshot(snapshot), "old snapshots must not break Workspace restore")
	check_true(not manager.has_instance(&"second_canvas"), "removed canvas stays uninstantiated")
	check_true(manager.has_definition(BUILTINS.PREVIEW_ID), "Preview survives layout restore")
	store.free()
	manager.destroy_all_modules()
	surface.free()
	host.free()
	manager.free()
