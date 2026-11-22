extends "res://tests/test_base.gd"

const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const Interaction := preload("res://src/UI/Workspace/WorkspaceInteractionController.gd")


func test_timeline_full_header_drag_and_palm_rejection_gates() -> void:
	var definition := WorkspaceModuleDefinition.new()
	definition.module_id = Builtins.TIMELINE_ID
	definition.uses_external_content = true
	definition.can_collapse = true
	definition.minimum_size = Vector2(320.0, 140.0)
	definition.preferred_size = Vector2(640.0, 220.0)
	var timeline := WorkspaceModule.new()
	var content := Control.new()
	check_true(timeline.configure_existing(definition, content), "timeline module loads")
	timeline.size = Vector2(640.0, 220.0)
	timeline.apply_visual_theme(WorkspaceVisualTheme.new(), &"docked")

	check_true(
		timeline.is_timeline_header_resize_point(
			Vector2(180.0, timeline.get_header_height() * 0.5)
		),
		"Timeline header blank bar should allow direct height resize",
	)
	check_true(
		not timeline.is_timeline_header_resize_point(
			Vector2(timeline.size.x - 8.0, timeline.get_header_height() * 0.5)
		),
		"Timeline header collapse button must not be stolen as resize",
	)
	check_true(
		Interaction.timeline_touch_allowed_for_resize(
			CanvasInputAdapter.PointerKind.PENCIL, 50.0, true
		),
		"Apple Pencil always bypasses palm and cooldown locks",
	)
	check_true(
		not Interaction.timeline_touch_allowed_for_resize(
			CanvasInputAdapter.PointerKind.DIRECT, 14.0, true
		),
		"finger/palm touch is rejected while Pencil is active or in 500ms cooldown",
	)
	check_true(
		not Interaction.timeline_touch_allowed_for_resize(
			CanvasInputAdapter.PointerKind.DIRECT, 40.0, false
		),
		"large-radius palm contact (>35pt) is rejected",
	)
	check_true(
		Interaction.timeline_touch_allowed_for_resize(
			CanvasInputAdapter.PointerKind.DIRECT, 16.0, false
		),
		"normal fingertip outside Pencil cooldown is allowed",
	)
	check_true(
		Interaction.timeline_header_resize_intent_for_pointer(Vector2(1.0, -6.0), true, 400),
		"Apple Pencil triggers resize after 6px vertical motion",
	)
	check_true(
		not Interaction.timeline_header_resize_intent_for_pointer(Vector2(1.0, -10.0), false, 80),
		"finger requires 16px vertical intent",
	)
	check_true(
		not Interaction.timeline_header_resize_intent_for_pointer(Vector2(1.0, -20.0), false, 300),
		"resting palm (>250ms before drifting) is rejected",
	)
	check_true(
		Interaction.timeline_header_resize_intent_for_pointer(Vector2(2.0, -18.0), false, 120),
		"deliberate quick vertical finger drag triggers resize",
	)

	timeline.release_external_content()
	timeline.free()
	content.free()
