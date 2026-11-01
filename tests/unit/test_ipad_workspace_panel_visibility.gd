extends "res://tests/test_base.gd"

const BUILTINS := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const FIXTURE := preload("res://tests/unit/test_p2_g_live_workspace_migration.gd")


func test_settings_visibility_parks_entire_floating_window_and_restores_position() -> void:
	var harness := FIXTURE.new()
	var fixture := harness._make_live_fixture()
	var migration := fixture["migration"] as WorkspaceEditorMigration
	var surface := fixture["surface"] as WorkspaceSurface
	var manager := fixture["manager"] as WorkspaceModuleManager
	var id := BUILTINS.PREVIEW_ID
	var module := manager.get_instance(id)
	var original := surface.get_floating_rect(id)
	check_true(migration.is_panel_visible(id), "floating window initially checked")
	check_true(migration.set_panel_visible(id, false), "uncheck hides full window")
	check_eq(surface.get_module_placement(id), WorkspaceSurface.Placement.NONE, "no placement remains")
	check_true(surface.is_module_parked(id), "entire module moved to invisible host")
	check_true(not module.is_content_collapsed(), "hide must not fold the content")
	check_true(not migration.is_panel_visible(id), "hidden window is unchecked")
	check_true(migration.set_panel_visible(id, true), "recheck restores window")
	check_eq(surface.get_module_placement(id), WorkspaceSurface.Placement.FLOATING, "floating placement recovered")
	check_eq(surface.get_floating_rect(id), original, "restores its previous position and size")
	check_true(migration.is_panel_visible(id), "restored window is checked")
	harness._free_fixture(fixture)
	harness.free()


func test_settings_hide_differs_from_header_collapse_and_reopens_expanded() -> void:
	var harness := FIXTURE.new()
	var fixture := harness._make_live_fixture()
	var migration := fixture["migration"] as WorkspaceEditorMigration
	var surface := fixture["surface"] as WorkspaceSurface
	var manager := fixture["manager"] as WorkspaceModuleManager
	var id := BUILTINS.PREVIEW_ID
	var module := manager.get_instance(id)
	var original := surface.get_floating_rect(id)
	check_true(surface.collapse_module(id), "header arrow folds content")
	check_true(module.is_content_collapsed(), "header fold preserves collapse state")
	check_true(migration.is_panel_visible(id), "collapsed header still counts as shown")
	check_true(migration.set_panel_visible(id, false), "Settings hides folded header too")
	check_eq(surface.get_module_placement(id), WorkspaceSurface.Placement.NONE, "header is removed")
	check_true(surface.is_module_parked(id), "folded module is fully hidden")
	check_true(migration.set_panel_visible(id, true), "Settings shows the window again")
	check_eq(surface.get_module_placement(id), WorkspaceSurface.Placement.FLOATING, "floating restored")
	check_true(not module.is_content_collapsed(), "reopened window is expanded")
	check_eq(surface.get_floating_rect(id), original, "collapsed window retains its geometry")
	harness._free_fixture(fixture)
	harness.free()


func test_settings_visibility_parks_and_restores_docked_timeline() -> void:
	var harness := FIXTURE.new()
	var fixture := harness._make_live_fixture()
	var migration := fixture["migration"] as WorkspaceEditorMigration
	var surface := fixture["surface"] as WorkspaceSurface
	var id := BUILTINS.TIMELINE_ID
	check_true(migration.is_panel_visible(id), "Timeline is docked and checked")
	check_true(migration.set_panel_visible(id, false), "Timeline checkbox hides entire dock")
	check_eq(surface.get_module_placement(id), WorkspaceSurface.Placement.NONE, "dock removed")
	check_true(surface.is_module_parked(id), "Timeline header no longer on screen")
	check_true(migration.set_panel_visible(id, true), "Timeline checkbox restores dock")
	check_eq(surface.get_module_placement(id), WorkspaceSurface.Placement.DOCKED, "dock recovers")
	harness._free_fixture(fixture)
	harness.free()


func test_ipad_panel_checkbox_targets_module_state_not_old_menu_toggle() -> void:
	var source := FileAccess.get_file_as_string("res://src/Preferences/PreferencesDialog.gd")
	check_has(source, "migration.set_panel_visible(module_id, enabled)", "checkbox invokes visibility")
	check_has(source, "migration.is_panel_visible(module_id)", "checkbox reads real module state")
	check_has(source, 'set_meta(&"module_id", module_id)', "module identity survives menu rebuild")
	check_has(source, "panel_visibility_changed.connect", "external panel changes synchronize checkbox")
