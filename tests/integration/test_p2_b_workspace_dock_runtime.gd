extends "res://tests/test_base.gd"


func test_editor_bootstraps_inert_workspace_dock_host() -> void:
	check_true(tree != null, "integration suite should receive the SceneTree")
	var scene := tree.current_scene
	check_true(scene != null, "editor scene should be loaded for integration tests")
	if scene == null:
		return

	var manager := scene.find_child("WorkspaceManager", true, false)
	var dock_host := scene.find_child("WorkspaceDockHost", true, false)
	check_true(manager != null, "editor should expose the P2-A WorkspaceManager")
	check_true(dock_host != null, "editor should bootstrap the P2-B WorkspaceDockHost")
	if manager == null or dock_host == null:
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
	check_true(
		not dock_host.visible,
		"P2-B runtime host must stay visually inert until editor modules migrate in P2-G"
	)
