extends "res://tests/test_base.gd"

const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")


func test_live_timeline_header_uses_main_theme_in_both_modes() -> void:
	var scene := tree.current_scene
	check_true(scene != null, "test needs the live editor")
	if scene == null:
		return
	var manager := scene.find_child("WorkspaceManager", true, false) as WorkspaceModuleManager
	check_true(manager != null, "live Workspace must exist")
	if manager == null:
		return
	var timeline_module := manager.get_instance(Builtins.TIMELINE_ID) as WorkspaceModule
	check_true(timeline_module != null, "Timeline Workspace module must exist")
	if timeline_module == null:
		return
	var accessory := timeline_module.get_header_accessory()
	check_true(accessory != null, "Timeline header controls must be installed")
	if accessory == null:
		return
	var frame_label := accessory.find_child("FrameLabel", true, false) as Label
	var mark := accessory.find_child("CurrentFrameMark", true, false) as Label
	var mode_button := accessory.find_child("ModeSwitch", true, false) as Button
	check_true(
		frame_label != null and mark != null and mode_button != null,
		"mode switch and current frame display must remain present"
	)
	if frame_label == null or mark == null or mode_button == null:
		return
	var editor_theme := Global.control.theme
	check_eq(accessory.theme, editor_theme, "Node2D overlay must use editor Theme")
	check_eq(
		frame_label.get_theme_default_font(),
		editor_theme.default_font,
		"label uses CJK-capable app font"
	)
	check_eq(
		mark.get_theme_default_font(), editor_theme.default_font, "frame counter uses app font"
	)
	check_eq(
		mode_button.get_theme_default_font(), editor_theme.default_font, "view switch uses app font"
	)

	var timeline := Global.animation_timeline as AnimationTimeline
	var saved_mode := timeline.get_timeline_mode()
	for next_mode in [
		AnimationTimeline.TimelineMode.SINGLE_FRAME,
		AnimationTimeline.TimelineMode.ANIMATION,
	]:
		timeline.set_timeline_mode(next_mode, false)
		await tree.process_frame
		check_eq(accessory.theme, editor_theme, "switching timeline modes must keep font chain")
		check_true(mode_button.text.length() > 0, "mode switch must show its mode label")
		check_eq(
			mark.text,
			(
				"%d/%d"
				% [Global.current_project.current_frame + 1, Global.current_project.frames.size()]
			),
			"frame display must use plain decimal indices"
		)
	timeline.set_timeline_mode(saved_mode, false)


func test_timeline_share_export_button_is_fixed_and_uses_existing_export_action() -> void:
	var scene := tree.current_scene
	if scene == null:
		return
	var manager := scene.find_child("WorkspaceManager", true, false) as WorkspaceModuleManager
	check_true(manager != null, "Timeline Workspace manager must exist")
	if manager == null:
		return
	var timeline_module := manager.get_instance(Builtins.TIMELINE_ID) as WorkspaceModule
	check_true(timeline_module != null, "Timeline Workspace module must exist")
	if timeline_module == null:
		return
	var accessory := timeline_module.get_header_accessory() as TimelineHeaderControls
	check_true(accessory != null, "Timeline header accessory must exist")
	if accessory == null:
		return
	var share_button := accessory.find_child("ShareExport", true, false) as Button
	check_true(share_button != null, "Share / Export button must be restored")
	if share_button == null:
		return
	check_eq(share_button.get_parent(), accessory, "Export must stay outside overflow content")
	check_true(share_button.visible, "Export remains visible in the animation header")
	check_true(share_button.icon != null, "Export has its own share icon")
	check_true(
		share_button.pressed.is_connected(Callable(accessory, "_on_share_export_pressed")),
		"Export is connected to its click handler"
	)
	var initial_width := accessory.get_available_width()
	accessory.set_available_width(190.0)
	check_eq(share_button.get_parent(), accessory, "Export stays fixed when the header is narrow")
	check_true(share_button.visible, "Export remains visible when other actions overflow")
	accessory.set_available_width(initial_width)

	var source := FileAccess.get_file_as_string("res://src/UI/Workspace/TimelineHeaderControls.gd")
	check_has(
		source,
		"Global.top_menu_container.file_menu_id_pressed(Global.FileMenu.EXPORT_AS)",
		"Export must reuse the editor Export As entry and iOS share pipeline"
	)
