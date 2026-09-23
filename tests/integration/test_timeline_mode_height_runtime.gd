extends "res://tests/test_base.gd"

const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const ProjectFactoryScript := preload("res://src/ProjectLibrary/ProjectFactory.gd")


func test_real_bottom_timeline_restores_distinct_mode_heights_without_manual_store() -> void:
	check_true(tree != null, "integration suite should receive the SceneTree")
	var scene := tree.current_scene
	check_true(scene != null, "editor scene should be loaded")
	if scene == null:
		return

	var manager := scene.find_child("WorkspaceManager", true, false) as WorkspaceModuleManager
	var dock_host := scene.find_child("WorkspaceDockHost", true, false) as WorkspaceDockHost
	var surface := scene.find_child("WorkspaceSurface", true, false) as WorkspaceSurface
	var timeline := Global.animation_timeline as AnimationTimeline
	var project := Global.current_project
	check_true(manager != null, "real editor must expose WorkspaceManager")
	check_true(dock_host != null, "real editor must expose WorkspaceDockHost")
	check_true(surface != null, "real editor must expose WorkspaceSurface")
	check_true(timeline != null, "real editor must expose AnimationTimeline")
	check_true(project != null, "real editor must expose a current Project")
	if manager == null or dock_host == null or surface == null or timeline == null or project == null:
		return

	# Headless editor startup can stop before UI.gd creates its normal interaction controller.
	# Attach one against the real Workspace objects so the test still exercises the actual
	# begin/update/finish resize transaction instead of writing sizes directly.
	var interaction := WorkspaceInteractionController.new()
	interaction.name = "TimelineHeightTestInteraction"
	scene.add_child(interaction)
	check_true(
		interaction.setup(manager, surface),
		"test interaction controller must bind to the real Workspace",
	)

	var original_mode := timeline.get_timeline_mode()
	var original_size := dock_host.layout.get_module_size(Builtins.TIMELINE_ID)
	var original_uuid := project.project_uuid
	var had_height_meta := project.has_meta(AnimationTimeline.TIMELINE_HEIGHT_META)
	var original_height_meta: Variant = project.get_meta(AnimationTimeline.TIMELINE_HEIGHT_META, {})
	var had_mode_meta := project.has_meta(AnimationTimeline.TIMELINE_MODE_META)
	var original_mode_meta: Variant = project.get_meta(AnimationTimeline.TIMELINE_MODE_META, 0)
	var test_uuid := "timeline-runtime-height-integration"
	var had_height_cache := Global.config_cache.has_section_key(
		AnimationTimeline.TIMELINE_HEIGHT_SECTION, test_uuid
	)
	var original_height_cache: Variant = Global.config_cache.get_value(
		AnimationTimeline.TIMELINE_HEIGHT_SECTION, test_uuid, {}
	)
	var had_mode_cache := Global.config_cache.has_section_key(
		AnimationTimeline.TIMELINE_MODE_SECTION, test_uuid
	)
	var original_mode_cache: Variant = Global.config_cache.get_value(
		AnimationTimeline.TIMELINE_MODE_SECTION, test_uuid, -1
	)

	project.project_uuid = test_uuid
	project.remove_meta(AnimationTimeline.TIMELINE_HEIGHT_META)
	project.remove_meta(AnimationTimeline.TIMELINE_MODE_META)
	Global.config_cache.erase_section_key(AnimationTimeline.TIMELINE_HEIGHT_SECTION, test_uuid)
	Global.config_cache.erase_section_key(AnimationTimeline.TIMELINE_MODE_SECTION, test_uuid)

	timeline.set_timeline_mode(AnimationTimeline.TimelineMode.ANIMATION, false)
	await tree.process_frame

	var resize_origin := Vector2(400.0, 300.0)
	var animation_start_size := dock_host.layout.get_module_size(Builtins.TIMELINE_ID)
	check_true(
		interaction._begin_resize(
			Builtins.TIMELINE_ID, resize_origin, -1, WorkspaceModule.ResizeEdge.TOP
		),
		"test must enter the real Timeline resize transaction in Animation mode",
	)
	interaction._update_resize(resize_origin + Vector2(0.0, animation_start_size.y - 318.0))
	interaction._finish_resize()
	check_eq(
		timeline.get_saved_workspace_height(AnimationTimeline.TimelineMode.ANIMATION, project),
		318.0,
		"Animation drag release must persist against the Animation height slot",
	)

	timeline.set_timeline_mode(AnimationTimeline.TimelineMode.SINGLE_FRAME)
	var stale_animation_size := dock_host.layout.get_module_size(Builtins.TIMELINE_ID)
	stale_animation_size.y = 318.0
	dock_host.call_deferred(&"set_module_size", Builtins.TIMELINE_ID, stale_animation_size)
	await tree.process_frame
	await tree.process_frame
	check_eq(
		dock_host.layout.get_module_size(Builtins.TIMELINE_ID).y,
		AnimationTimeline.DEFAULT_SINGLE_FRAME_WORKSPACE_HEIGHT,
		"post-layout reconciliation must defeat late Animation geometry after switching to Single frame",
	)
	var module := manager.get_instance(Builtins.TIMELINE_ID) as WorkspaceModule
	check_almost_eq(
		module.size.y,
		AnimationTimeline.DEFAULT_SINGLE_FRAME_WORKSPACE_HEIGHT,
		0.01,
		"visible Single-frame Timeline must end at its own restored height",
	)

	var single_start_size := dock_host.layout.get_module_size(Builtins.TIMELINE_ID)
	check_true(
		interaction._begin_resize(
			Builtins.TIMELINE_ID, resize_origin, -1, WorkspaceModule.ResizeEdge.TOP
		),
		"test must enter the real Timeline resize transaction in Single-frame mode",
	)
	interaction._update_resize(resize_origin + Vector2(0.0, single_start_size.y - 196.0))
	interaction._finish_resize()
	check_eq(
		timeline.get_saved_workspace_height(AnimationTimeline.TimelineMode.SINGLE_FRAME, project),
		196.0,
		"Single-frame drag release must persist against the Single-frame height slot",
	)

	timeline.set_timeline_mode(AnimationTimeline.TimelineMode.ANIMATION)
	var stale_single_size := dock_host.layout.get_module_size(Builtins.TIMELINE_ID)
	stale_single_size.y = 196.0
	dock_host.call_deferred(&"set_module_size", Builtins.TIMELINE_ID, stale_single_size)
	await tree.process_frame
	await tree.process_frame
	check_eq(
		dock_host.layout.get_module_size(Builtins.TIMELINE_ID).y,
		318.0,
		"returning to Animation must restore its original independent height after final layout",
	)
	check_almost_eq(
		module.size.y,
		318.0,
		0.01,
		"visible Animation Timeline must end at its own restored height",
	)
	check_eq(
		timeline.get_saved_workspace_height(AnimationTimeline.TimelineMode.ANIMATION, project),
		318.0,
		"Single-frame resize and mode switching must not overwrite Animation's saved height",
	)

	timeline.set_timeline_mode(AnimationTimeline.TimelineMode.SINGLE_FRAME)
	await tree.process_frame
	await tree.process_frame
	check_eq(
		dock_host.layout.get_module_size(Builtins.TIMELINE_ID).y,
		196.0,
		"returning to Single frame must restore its independently saved height",
	)

	timeline.set_timeline_mode(original_mode, false)
	await tree.process_frame
	dock_host.set_module_size(Builtins.TIMELINE_ID, original_size)
	interaction.queue_free()
	project.project_uuid = original_uuid
	if had_height_meta:
		project.set_meta(AnimationTimeline.TIMELINE_HEIGHT_META, original_height_meta)
	else:
		project.remove_meta(AnimationTimeline.TIMELINE_HEIGHT_META)
	if had_mode_meta:
		project.set_meta(AnimationTimeline.TIMELINE_MODE_META, original_mode_meta)
	else:
		project.remove_meta(AnimationTimeline.TIMELINE_MODE_META)
	if had_height_cache:
		Global.config_cache.set_value(
			AnimationTimeline.TIMELINE_HEIGHT_SECTION, test_uuid, original_height_cache
		)
	else:
		Global.config_cache.erase_section_key(AnimationTimeline.TIMELINE_HEIGHT_SECTION, test_uuid)
	if had_mode_cache:
		Global.config_cache.set_value(
			AnimationTimeline.TIMELINE_MODE_SECTION, test_uuid, original_mode_cache
		)
	else:
		Global.config_cache.erase_section_key(AnimationTimeline.TIMELINE_MODE_SECTION, test_uuid)


func test_real_project_switch_updates_mode_and_single_frame_binding() -> void:
	check_true(tree != null, "integration suite should receive the SceneTree")
	var timeline := Global.animation_timeline as AnimationTimeline
	var project_a := Global.current_project
	check_true(timeline != null, "real editor must expose AnimationTimeline")
	check_true(project_a != null, "real editor must expose project A")
	if timeline == null or project_a == null:
		return

	var strip := timeline.single_frame_layer_strip
	var original_mode := timeline.get_timeline_mode()
	var original_index := Global.current_project_index
	var had_a_mode := project_a.has_meta(AnimationTimeline.TIMELINE_MODE_META)
	var original_a_mode: Variant = project_a.get_meta(AnimationTimeline.TIMELINE_MODE_META, 0)
	var had_a_height_meta := project_a.has_meta(AnimationTimeline.TIMELINE_HEIGHT_META)
	var original_a_height_meta: Variant = project_a.get_meta(
		AnimationTimeline.TIMELINE_HEIGHT_META, {}
	)
	var had_a_mode_cache := Global.config_cache.has_section_key(
		AnimationTimeline.TIMELINE_MODE_SECTION, project_a.project_uuid
	)
	var original_a_mode_cache: Variant = Global.config_cache.get_value(
		AnimationTimeline.TIMELINE_MODE_SECTION, project_a.project_uuid, -1
	)
	var had_a_height_cache := Global.config_cache.has_section_key(
		AnimationTimeline.TIMELINE_HEIGHT_SECTION, project_a.project_uuid
	)
	var original_a_height_cache: Variant = Global.config_cache.get_value(
		AnimationTimeline.TIMELINE_HEIGHT_SECTION, project_a.project_uuid, {}
	)

	timeline.store_project_timeline_mode(AnimationTimeline.TimelineMode.SINGLE_FRAME, project_a)
	timeline.set_timeline_mode(AnimationTimeline.TimelineMode.SINGLE_FRAME, false)
	strip.set_project(project_a)
	await tree.process_frame
	check_eq(
		strip.get("_bound_project"),
		project_a,
		"Single-frame strip must start bound to project A",
	)
	timeline.store_workspace_height(287.0, AnimationTimeline.TimelineMode.ANIMATION, project_a)

	var project_b := ProjectFactoryScript.create_blank_project(
		"timeline_project_b", Vector2i(32, 32)
	)
	check_true(project_b != null, "integration test must create project B")
	if project_b == null:
		return
	project_b.layers[0].name = "B layer"
	Global.projects.append(project_b)
	timeline.store_project_timeline_mode(AnimationTimeline.TimelineMode.ANIMATION, project_b)
	timeline.store_workspace_height(326.0, AnimationTimeline.TimelineMode.ANIMATION, project_b)
	timeline.store_workspace_height(377.0, AnimationTimeline.TimelineMode.SINGLE_FRAME, project_b)
	var project_b_index := Global.projects.find(project_b)

	Global.tabs.current_tab = project_b_index
	await tree.process_frame
	await tree.process_frame
	check_eq(Global.current_project, project_b, "project B must become the active project")
	check_eq(
		timeline.get_timeline_mode(),
		AnimationTimeline.TimelineMode.ANIMATION,
		"Timeline mode must follow project B instead of retaining project A's Single-frame mode",
	)
	check_eq(
		strip.get("_bound_project"),
		project_b,
		"hidden Single-frame strip must already be rebound to project B",
	)
	check_eq(
		timeline.get_saved_workspace_height(AnimationTimeline.TimelineMode.SINGLE_FRAME, project_b),
		377.0,
		"switching A Single-frame -> B Animation must not copy A height into B Single-frame",
	)

	timeline.set_timeline_mode(AnimationTimeline.TimelineMode.SINGLE_FRAME, false)
	await tree.process_frame
	check_eq(
		strip.get("_bound_project"),
		project_b,
		"opening Single frame after the switch must still show project B",
	)
	for child in strip.layer_row.get_children():
		if child is SingleFrameLayerCard:
			check_eq(
				child.get("_project"),
				project_b,
				"every visible Single-frame card must belong to project B",
			)

	# Return B to its persisted Animation mode before switching projects so the switch
	# exercises the opposite Animation -> Single-frame transition as well.
	timeline.set_timeline_mode(AnimationTimeline.TimelineMode.ANIMATION, false)
	await tree.process_frame
	Global.tabs.current_tab = original_index
	await tree.process_frame
	await tree.process_frame
	check_eq(Global.current_project, project_a, "cleanup must restore project A")
	check_eq(
		timeline.get_timeline_mode(),
		AnimationTimeline.TimelineMode.SINGLE_FRAME,
		"returning to project A must restore project A's own mode",
	)
	check_eq(
		strip.get("_bound_project"),
		project_a,
		"returning to project A must rebuild the strip against project A",
	)
	check_eq(
		timeline.get_saved_workspace_height(AnimationTimeline.TimelineMode.ANIMATION, project_a),
		287.0,
		"switching B Animation -> A Single-frame must not copy B height into A Animation",
	)

	var remove_index := Global.projects.find(project_b)
	if remove_index >= 0 and remove_index < Global.tabs.tab_count:
		Global.tabs.remove_tab(remove_index)
	project_b.remove()
	if had_a_mode:
		project_a.set_meta(AnimationTimeline.TIMELINE_MODE_META, original_a_mode)
	else:
		project_a.remove_meta(AnimationTimeline.TIMELINE_MODE_META)
	if had_a_height_meta:
		project_a.set_meta(AnimationTimeline.TIMELINE_HEIGHT_META, original_a_height_meta)
	else:
		project_a.remove_meta(AnimationTimeline.TIMELINE_HEIGHT_META)
	if had_a_mode_cache:
		Global.config_cache.set_value(
			AnimationTimeline.TIMELINE_MODE_SECTION, project_a.project_uuid, original_a_mode_cache
		)
	else:
		Global.config_cache.erase_section_key(
			AnimationTimeline.TIMELINE_MODE_SECTION, project_a.project_uuid
		)
	if had_a_height_cache:
		(
			Global
			. config_cache
			. set_value(
				AnimationTimeline.TIMELINE_HEIGHT_SECTION,
				project_a.project_uuid,
				original_a_height_cache,
			)
		)
	else:
		Global.config_cache.erase_section_key(
			AnimationTimeline.TIMELINE_HEIGHT_SECTION, project_a.project_uuid
		)
	Global.config_cache.erase_section_key(
		AnimationTimeline.TIMELINE_MODE_SECTION, project_b.project_uuid
	)
	Global.config_cache.erase_section_key(
		AnimationTimeline.TIMELINE_HEIGHT_SECTION, project_b.project_uuid
	)
	timeline.set_timeline_mode(original_mode, false, false)
