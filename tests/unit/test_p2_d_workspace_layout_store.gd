extends "res://tests/test_base.gd"

const Definition := preload("res://src/UI/Workspace/WorkspaceModuleDefinition.gd")
const Manager := preload("res://src/UI/Workspace/WorkspaceModuleManager.gd")
const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const DockLayout := preload("res://src/UI/Workspace/WorkspaceDockLayout.gd")
const DockHost := preload("res://src/UI/Workspace/WorkspaceDockHost.gd")
const Surface := preload("res://src/UI/Workspace/WorkspaceSurface.gd")
const Store := preload("res://src/UI/Workspace/WorkspaceLayoutStore.gd")
const PREVIEW_SCENE_PATH := "res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.tscn"
const TEST_PRESET_DIR := "user://p2_d_workspace_layout_presets_test"
const TEST_CONFIG_PATH := "user://p2_d_workspace_layout_config_test.ini"


func _make_workspace() -> Dictionary:
	_cleanup_test_files()
	var manager := Manager.new()
	var host := DockHost.new()
	var surface := Surface.new()
	var store := Store.new()
	Builtins.register_defaults(manager)

	var extra := Definition.new()
	extra.module_id = &"test.extra"
	extra.display_name = "Extra"
	extra.content_scene = load(PREVIEW_SCENE_PATH)
	check_true(manager.register_definition(extra), "extra test module should register")

	host.size = Vector2(1200.0, 800.0)
	check_true(host.setup(manager), "dock host should initialize")
	check_true(surface.setup(manager, host), "surface should initialize")
	check_true(
		store.setup(surface, ConfigFile.new(), TEST_CONFIG_PATH, TEST_PRESET_DIR),
		"layout store should initialize"
	)
	store.autosave_enabled = false
	return {"manager": manager, "host": host, "surface": surface, "store": store}


func _free_workspace(workspace: Dictionary) -> void:
	var store = workspace["store"]
	var manager = workspace["manager"]
	var host = workspace["host"]
	var surface = workspace["surface"]
	store.free()
	manager.destroy_all_modules()
	surface.free()
	host.free()
	manager.free()
	_cleanup_test_files()


func _cleanup_test_files() -> void:
	if FileAccess.file_exists(TEST_CONFIG_PATH):
		DirAccess.remove_absolute(TEST_CONFIG_PATH)
	if not DirAccess.dir_exists_absolute(TEST_PRESET_DIR):
		return
	for file_name in DirAccess.get_files_at(TEST_PRESET_DIR):
		DirAccess.remove_absolute(TEST_PRESET_DIR.path_join(file_name))
	DirAccess.remove_absolute(TEST_PRESET_DIR)


func test_snapshot_round_trip_preserves_all_workspace_placements() -> void:
	var workspace := _make_workspace()
	var manager = workspace["manager"]
	var host = workspace["host"]
	var surface = workspace["surface"]
	var store = workspace["store"]

	check_true(
		surface.dock_module(
			Builtins.PREVIEW_ID, DockLayout.DockZone.LEFT, 0, Vector2(300.0, 180.0)
		),
		"Preview should dock before capture"
	)
	check_true(
		surface.float_module(Builtins.PALETTE_ID, Rect2(500.0, 220.0, 340.0, 240.0)),
		"Palette should float before capture"
	)
	check_true(
		surface.dock_module(&"test.extra", DockLayout.DockZone.RIGHT, 0, Vector2(280.0, 190.0)),
		"extra module should dock before collapse"
	)
	check_true(surface.collapse_module(&"test.extra"), "extra module should collapse")

	var preview := manager.get_instance(Builtins.PREVIEW_ID)
	var palette := manager.get_instance(Builtins.PALETTE_ID)
	var extra := manager.get_instance(&"test.extra")
	var snapshot := store.capture_snapshot()

	check_true(
		surface.float_module(Builtins.PREVIEW_ID, Rect2(50.0, 50.0, 360.0, 260.0)),
		"Preview should mutate away from snapshot"
	)
	check_true(
		surface.dock_module(Builtins.PALETTE_ID, DockLayout.DockZone.TOP),
		"Palette should mutate away from snapshot"
	)
	check_true(surface.restore_module(&"test.extra"), "collapsed extra should temporarily restore")
	check_true(
		surface.float_module(&"test.extra", Rect2(100.0, 100.0, 300.0, 220.0)),
		"extra should mutate away from snapshot"
	)

	check_true(store.apply_snapshot(snapshot), "captured snapshot should apply")
	check_eq(manager.get_instance(Builtins.PREVIEW_ID), preview, "Preview identity must survive")
	check_eq(manager.get_instance(Builtins.PALETTE_ID), palette, "Palette identity must survive")
	check_eq(manager.get_instance(&"test.extra"), extra, "extra identity must survive")
	check_eq(
		host.layout.get_module_zone(Builtins.PREVIEW_ID),
		DockLayout.DockZone.LEFT,
		"Preview should return to left dock"
	)
	check_eq(
		host.layout.get_module_size(Builtins.PREVIEW_ID),
		Vector2(300.0, 180.0),
		"Preview dock size should round-trip"
	)
	check_eq(
		surface.get_module_placement(Builtins.PALETTE_ID),
		Surface.Placement.FLOATING,
		"Palette should return to floating"
	)
	check_eq(
		surface.get_floating_rect(Builtins.PALETTE_ID),
		Rect2(500.0, 220.0, 340.0, 240.0),
		"Palette floating rect should round-trip"
	)
	check_eq(
		surface.get_module_placement(&"test.extra"),
		Surface.Placement.COLLAPSED,
		"extra should return to collapsed"
	)
	var restore := surface.get_restore_state(&"test.extra")
	check_eq(
		int(restore.get("zone", DockLayout.DockZone.NONE)),
		DockLayout.DockZone.RIGHT,
		"collapsed restore zone should round-trip"
	)
	check_eq(
		restore.get("size", Vector2.ZERO),
		Vector2(280.0, 190.0),
		"collapsed restore size should round-trip"
	)
	_free_workspace(workspace)


func test_snapshot_round_trip_preserves_region_fill_dock_semantics() -> void:
	var workspace := _make_workspace()
	var host = workspace["host"]
	var surface = workspace["surface"]
	var store = workspace["store"]

	check_true(
		surface.dock_module(
			Builtins.PREVIEW_ID,
			DockLayout.DockZone.BOTTOM,
			0,
			Vector2(360.0, 180.0),
			{},
			true,
		),
		"Preview should enter Bottom Dock with Region Fill before capture",
	)
	check_true(
		host.layout.is_module_region_fill(Builtins.PREVIEW_ID),
		"Region Fill should be active before capture",
	)
	var snapshot := store.capture_snapshot()

	check_true(
		surface.dock_module(
			Builtins.PREVIEW_ID,
			DockLayout.DockZone.RIGHT,
			0,
			Vector2(280.0, 180.0),
		),
		"Preview should mutate to a fixed right-dock slot",
	)
	check_true(
		not host.layout.is_module_region_fill(Builtins.PREVIEW_ID),
		"normal slot docking should clear Region Fill",
	)

	check_true(store.apply_snapshot(snapshot), "Region Fill snapshot should restore")
	check_eq(
		host.layout.get_module_zone(Builtins.PREVIEW_ID),
		DockLayout.DockZone.BOTTOM,
		"snapshot should recover Bottom Dock",
	)
	check_true(
		host.layout.is_module_region_fill(Builtins.PREVIEW_ID),
		"snapshot should recover Region Fill semantics",
	)
	_free_workspace(workspace)


func test_none_state_clears_existing_placement_and_unknown_modules_are_ignored() -> void:
	var workspace := _make_workspace()
	var surface = workspace["surface"]
	var store = workspace["store"]
	var snapshot := store.capture_snapshot()
	var modules: Array = snapshot["modules"]
	(
		modules
		. append(
			{
				"id": "extension.missing",
				"placement": "floating",
				"rect": [10.0, 10.0, 200.0, 160.0],
			}
		)
	)

	check_true(
		surface.dock_module(Builtins.PREVIEW_ID, DockLayout.DockZone.BOTTOM),
		"Preview should be placed after the NONE snapshot"
	)
	check_true(store.apply_snapshot(snapshot), "snapshot with unknown module should still apply")
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		Surface.Placement.NONE,
		"NONE snapshot entry should clear a later placement"
	)
	check_eq(
		workspace["manager"].get_instance(Builtins.PREVIEW_ID).get_parent(),
		null,
		"clearing placement should unmount without destroying the instance"
	)
	_free_workspace(workspace)


func test_current_layout_persists_through_existing_config_file() -> void:
	var workspace := _make_workspace()
	var surface = workspace["surface"]
	var store = workspace["store"]
	check_true(
		surface.float_module(Builtins.PREVIEW_ID, Rect2(420.0, 180.0, 320.0, 220.0)),
		"Preview should float before current-layout save"
	)
	check_true(store.save_current_layout(), "current layout should save to disk")

	var reloaded_config := ConfigFile.new()
	check_eq(reloaded_config.load(TEST_CONFIG_PATH), OK, "saved config should reload")
	check_true(
		reloaded_config.has_section_key(Store.CONFIG_SECTION, Store.CONFIG_STATE_KEY),
		"existing config.ini structure should contain workspace state"
	)

	check_true(
		surface.dock_module(Builtins.PREVIEW_ID, DockLayout.DockZone.TOP),
		"Preview should mutate after current-layout save"
	)
	check_true(store.restore_current_layout(), "saved current layout should restore")
	check_eq(
		surface.get_module_placement(Builtins.PREVIEW_ID),
		Surface.Placement.FLOATING,
		"current-layout restore should recover floating placement"
	)
	check_eq(
		surface.get_floating_rect(Builtins.PREVIEW_ID),
		Rect2(420.0, 180.0, 320.0, 220.0),
		"current-layout restore should recover floating bounds"
	)
	_free_workspace(workspace)


func test_named_presets_save_list_load_delete_and_validate_names() -> void:
	var workspace := _make_workspace()
	var surface = workspace["surface"]
	var store = workspace["store"]
	check_true(
		surface.dock_module(
			Builtins.PALETTE_ID, DockLayout.DockZone.RIGHT, 0, Vector2(260.0, 180.0)
		),
		"Palette should dock before preset save"
	)
	check_true(store.save_preset("Compact"), "named preset should save")
	check_true(store.preset_exists("Compact"), "saved preset should exist")
	check_true(store.list_presets().has("Compact"), "saved preset should be listed")
	check_true(not store.save_preset("../bad"), "path traversal preset names must be rejected")
	check_true(not store.save_preset("bad:name"), "platform-invalid preset names must be rejected")

	check_true(
		surface.float_module(Builtins.PALETTE_ID, Rect2(300.0, 200.0, 320.0, 220.0)),
		"Palette should mutate after preset save"
	)
	check_true(store.load_preset("Compact"), "named preset should load")
	check_eq(
		workspace["host"].layout.get_module_zone(Builtins.PALETTE_ID),
		DockLayout.DockZone.RIGHT,
		"preset load should recover dock zone"
	)
	check_eq(
		workspace["host"].layout.get_module_size(Builtins.PALETTE_ID),
		Vector2(260.0, 180.0),
		"preset load should recover dock size"
	)
	check_true(store.delete_preset("Compact"), "named preset should delete")
	check_true(not store.preset_exists("Compact"), "deleted preset should disappear")
	_free_workspace(workspace)


func test_future_schema_is_rejected_without_mutating_current_layout() -> void:
	var workspace := _make_workspace()
	var surface = workspace["surface"]
	var store = workspace["store"]
	check_true(
		surface.dock_module(Builtins.PREVIEW_ID, DockLayout.DockZone.LEFT),
		"Preview should start docked"
	)
	var unsupported := store.capture_snapshot()
	unsupported["schema_version"] = Store.SCHEMA_VERSION + 1
	check_true(not store.apply_snapshot(unsupported), "future schema must be rejected")
	check_eq(
		workspace["host"].layout.get_module_zone(Builtins.PREVIEW_ID),
		DockLayout.DockZone.LEFT,
		"rejected snapshot must not mutate the current layout"
	)
	_free_workspace(workspace)
