extends "res://tests/test_base.gd"

const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")


func test_real_bottom_timeline_restores_distinct_mode_heights() -> void:
	check_true(tree != null, "integration suite should receive the SceneTree")
	var scene := tree.current_scene
	check_true(scene != null, "editor scene should be loaded")
	if scene == null:
		return

	var manager := scene.find_child("WorkspaceManager", true, false) as WorkspaceModuleManager
	var dock_host := scene.find_child("WorkspaceDockHost", true, false) as WorkspaceDockHost
	var migration := (
		scene.find_child("WorkspaceEditorMigration", true, false) as WorkspaceEditorMigration
	)
	var timeline := Global.animation_timeline as AnimationTimeline
	var project := Global.current_project
	check_true(manager != null, "real editor must expose WorkspaceManager")
	check_true(dock_host != null, "real editor must expose WorkspaceDockHost")
	check_true(migration != null, "real editor must expose WorkspaceEditorMigration")
	check_true(timeline != null, "real editor must expose AnimationTimeline")
	check_true(project != null, "real editor must expose a current Project")
	if (
		manager == null
		or dock_host == null
		or migration == null
		or timeline == null
		or project == null
	):
		return

	var module := manager.get_instance(Builtins.TIMELINE_ID) as WorkspaceModule
	check_true(module != null, "Timeline Workspace module must exist")
	if module == null:
		return

	var original_mode := timeline.get_timeline_mode()
	var original_size := dock_host.layout.get_module_size(Builtins.TIMELINE_ID)
	var had_meta := project.has_meta(AnimationTimeline.TIMELINE_HEIGHT_META)
	var original_meta: Variant = project.get_meta(AnimationTimeline.TIMELINE_HEIGHT_META, {})
	var original_uuid := project.project_uuid
	var test_uuid := "timeline-runtime-height-integration"
	var had_cache := Global.config_cache.has_section_key(
		AnimationTimeline.TIMELINE_HEIGHT_SECTION, test_uuid
	)
	var original_cache: Variant = Global.config_cache.get_value(
		AnimationTimeline.TIMELINE_HEIGHT_SECTION, test_uuid, {}
	)
	project.project_uuid = test_uuid
	project.remove_meta(AnimationTimeline.TIMELINE_HEIGHT_META)
	Global.config_cache.erase_section_key(AnimationTimeline.TIMELINE_HEIGHT_SECTION, test_uuid)

	timeline.set_timeline_mode(AnimationTimeline.TimelineMode.ANIMATION)
	await tree.process_frame
	await tree.process_frame

	var animation_size := dock_host.layout.get_module_size(Builtins.TIMELINE_ID)
	animation_size.y = 318.0
	check_true(
		dock_host.set_module_size(Builtins.TIMELINE_ID, animation_size),
		"test must be able to resize real Bottom Timeline",
	)
	migration._store_current_timeline_height(AnimationTimeline.TimelineMode.ANIMATION)
	timeline.store_workspace_height(184.0, AnimationTimeline.TimelineMode.SINGLE_FRAME, project)

	timeline.set_timeline_mode(AnimationTimeline.TimelineMode.SINGLE_FRAME)
	await tree.process_frame
	await tree.process_frame
	check_eq(
		dock_host.layout.get_module_size(Builtins.TIMELINE_ID).y,
		184.0,
		"switching to Single frame must restore that mode's project height",
	)

	var single_size := dock_host.layout.get_module_size(Builtins.TIMELINE_ID)
	single_size.y = 196.0
	check_true(
		dock_host.set_module_size(Builtins.TIMELINE_ID, single_size),
		"test must be able to resize Single-frame Bottom Timeline",
	)
	migration._store_current_timeline_height(AnimationTimeline.TimelineMode.SINGLE_FRAME)

	timeline.set_timeline_mode(AnimationTimeline.TimelineMode.ANIMATION)
	await tree.process_frame
	await tree.process_frame
	check_eq(
		dock_host.layout.get_module_size(Builtins.TIMELINE_ID).y,
		318.0,
		"returning to Animation must restore the height saved before leaving it",
	)

	timeline.set_timeline_mode(AnimationTimeline.TimelineMode.SINGLE_FRAME)
	await tree.process_frame
	await tree.process_frame
	check_eq(
		dock_host.layout.get_module_size(Builtins.TIMELINE_ID).y,
		196.0,
		"returning to Single frame must restore its independently saved height",
	)

	timeline.set_timeline_mode(original_mode)
	await tree.process_frame
	dock_host.set_module_size(Builtins.TIMELINE_ID, original_size)
	project.project_uuid = original_uuid
	if had_meta:
		project.set_meta(AnimationTimeline.TIMELINE_HEIGHT_META, original_meta)
	else:
		project.remove_meta(AnimationTimeline.TIMELINE_HEIGHT_META)
	if had_cache:
		Global.config_cache.set_value(
			AnimationTimeline.TIMELINE_HEIGHT_SECTION, test_uuid, original_cache
		)
	else:
		Global.config_cache.erase_section_key(AnimationTimeline.TIMELINE_HEIGHT_SECTION, test_uuid)
