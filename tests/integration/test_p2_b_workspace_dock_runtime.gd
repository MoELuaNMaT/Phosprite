extends "res://tests/test_base.gd"


func test_editor_bootstraps_live_workspace_after_p2_g_migration() -> void:
	check_true(tree != null, "integration suite should receive the SceneTree")
	var scene := tree.current_scene
	check_true(scene != null, "editor scene should be loaded for integration tests")
	if scene == null:
		return

	var manager := scene.find_child("WorkspaceManager", true, false)
	var dock_host := scene.find_child("WorkspaceDockHost", true, false)
	var migration := scene.find_child("WorkspaceEditorMigration", true, false)
	var legacy := scene.find_child("DockableContainer", true, false)
	check_true(manager != null, "editor should expose the P2-A WorkspaceManager")
	check_true(dock_host != null, "editor should expose the P2-B WorkspaceDockHost")
	check_true(migration != null, "editor should expose the P2-G live migration bridge")
	check_true(legacy != null, "legacy DockableContainer should remain available as fallback")
	if manager == null or dock_host == null or migration == null or legacy == null:
		return

	check_eq(
		dock_host.manager,
		manager,
		"dock host should be configured with the editor WorkspaceManager"
	)
	check_true(
		dock_host.layout != null and dock_host.layout.is_configured(),
		"dock host should own a configured four-zone layout model"
	)
	check_true(dock_host.visible, "P2-G should activate the live WorkspaceDockHost")
	check_eq(
		dock_host.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"Workspace shell must stay input-through so the central Canvas keeps input ownership"
	)
	check_true(migration.live, "P2-G startup migration should complete before the editor becomes live")
	check_true(not legacy.visible, "legacy DockableContainer should be hidden after live migration")
