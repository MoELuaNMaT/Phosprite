extends "res://tests/test_base.gd"

const CARD_SCENE := preload("res://src/UI/ProjectGallery/ProjectGalleryCard.tscn")

const GALLERY_SOURCE := "res://src/UI/ProjectGallery/ProjectGallery.gd"
const GALLERY_SCENE := "res://src/UI/ProjectGallery/ProjectGallery.tscn"
const CARD_SOURCE := "res://src/UI/ProjectGallery/ProjectGalleryCard.gd"
const CARD_SCENE_SOURCE := "res://src/UI/ProjectGallery/ProjectGalleryCard.tscn"
const SHELL_SOURCE := "res://src/AppShell/AppShellController.gd"


func test_p3_j_reflow_contract_uses_visual_root_and_interaction_lock() -> void:
	var gallery_src := FileAccess.get_file_as_string(GALLERY_SOURCE)
	var card_src := FileAccess.get_file_as_string(CARD_SOURCE)
	var card_scene := FileAccess.get_file_as_string(CARD_SCENE_SOURCE)

	check_has(card_scene, 'name="VisualRoot"', "cards must expose a dedicated visual FLIP root")
	check_has(
		gallery_src,
		"old_rects[_normalized_path(card.entry.path)] = card.get_global_rect()",
		"orientation reflow must capture pre-layout card rects",
	)
	check_has(
		gallery_src,
		"columns != _current_columns",
		"reflow animation must only run across the 6/4 orientation boundary",
	)
	check_has(
		gallery_src,
		'set_interaction_locked(&"reflow", true)',
		"touch input must lock while visuals interpolate from old to new layout",
	)
	check_has(
		card_src,
		"visual_root.position = old_rect.position - new_rect.position",
		"FLIP translation must begin from the old card position",
	)
	check_has(
		card_src,
		'tween_property(visual_root, "scale", Vector2.ONE, duration)',
		"FLIP scale must settle at the new layout size",
	)


func test_p3_j_popover_scroll_empty_and_feedback_contract() -> void:
	var gallery_src := FileAccess.get_file_as_string(GALLERY_SOURCE)
	var gallery_scene := FileAccess.get_file_as_string(GALLERY_SCENE)
	var card_src := FileAccess.get_file_as_string(CARD_SOURCE)

	check_has(
		gallery_src,
		"_popover_anchor_fraction",
		"action popovers must retain their anchor within the tapped card",
	)
	check_has(
		gallery_src,
		'call_deferred("_place_open_popover")',
		"popover position must be recomputed after scrolling/resizing",
	)
	check_has(
		gallery_src,
		'call_deferred("_apply_scroll_top_after_layout", scroll_reset_count)',
		"Gallery return must re-assert scroll-to-top after container layout",
	)
	check_has(
		gallery_scene,
		'text = "Create a new project or import artwork to get started."',
		"empty Gallery must explain the next available actions",
	)
	check_has(
		gallery_scene,
		'name="FeedbackBanner"',
		"Gallery must expose inline operation feedback",
	)
	check_has(
		card_src,
		'tr("Loading preview…")',
		"healthy cards must expose thumbnail loading feedback",
	)
	check_has(
		card_src,
		'tr("Preview unavailable")',
		"thumbnail decode failures must have a visible error state",
	)


func test_p3_j_app_shell_transition_contract() -> void:
	var shell_src := FileAccess.get_file_as_string(SHELL_SOURCE)
	check_has(
		shell_src,
		"const MODE_TRANSITION_DURATION := 0.16",
		"Gallery/Editor transitions must have one bounded motion duration",
	)
	check_has(
		shell_src,
		'tween_property(target, "modulate:a", 1.0, MODE_TRANSITION_DURATION)',
		"mode entry must fade the destination root in",
	)
	check_has(
		shell_src,
		'tween_property(target, "position", base_position, MODE_TRANSITION_DURATION)',
		"mode entry must settle the destination root from a small offset",
	)
	check_has(
		shell_src,
		'gallery_root.set_interaction_locked(&"mode_transition", animate)',
		"Gallery touch must stay locked until its entry transition completes",
	)


func test_project_card_reflow_transform_returns_to_identity() -> void:
	var card := CARD_SCENE.instantiate() as ProjectGalleryCard
	check_true(card != null, "P3-J card scene must instantiate")
	if card == null:
		return
	tree.root.add_child(card)
	card.position = Vector2(120, 80)
	card.size = Vector2(200, 254)
	await tree.process_frame

	var new_rect := card.get_global_rect()
	var old_rect := Rect2(new_rect.position - Vector2(40, 24), new_rect.size * 0.75)
	card.prepare_reflow(old_rect)
	check_true(
		card.visual_root.position.distance_to(Vector2.ZERO) > 1.0,
		"prepared FLIP visual must start away from its new layout origin",
	)
	check_true(
		card.visual_root.scale.distance_to(Vector2.ONE) > 0.01,
		"prepared FLIP visual must start from the old/new size ratio",
	)

	var tween := card.play_reflow(1.0)
	check_true(tween != null, "card reflow must return its tween for deterministic stepping")
	if tween != null:
		tween.custom_step(1.0)
	check_true(
		card.visual_root.position.distance_to(Vector2.ZERO) < 0.01,
		"FLIP translation must finish at identity",
	)
	check_true(
		card.visual_root.scale.distance_to(Vector2.ONE) < 0.01,
		"FLIP scale must finish at identity",
	)
	card.queue_free()
