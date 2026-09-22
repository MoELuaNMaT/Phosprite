extends "res://tests/test_base.gd"

const TIMELINE_SOURCE := "res://src/UI/Timeline/AnimationTimeline.gd"
const TIMELINE_SCENE := "res://src/UI/Timeline/AnimationTimeline.tscn"
const HEADER_SOURCE := "res://src/UI/Workspace/TimelineHeaderControls.gd"
const HEADER_SCENE := "res://src/UI/Workspace/TimelineHeaderControls.tscn"
const STRIP_SOURCE := "res://src/UI/Timeline/SingleFrameLayerStrip.gd"
const STRIP_SCENE := "res://src/UI/Timeline/SingleFrameLayerStrip.tscn"
const CARD_SOURCE := "res://src/UI/Timeline/SingleFrameLayerCard.gd"
const CARD_SCENE := "res://src/UI/Timeline/SingleFrameLayerCard.tscn"


func test_timeline_exposes_two_persistent_display_modes() -> void:
	var source := FileAccess.get_file_as_string(TIMELINE_SOURCE)
	var scene := FileAccess.get_file_as_string(TIMELINE_SCENE)
	check_has(
		source,
		"enum TimelineMode { ANIMATION, SINGLE_FRAME }",
		"Timeline must expose explicit animation and single-frame modes",
	)
	check_has(
		source,
		'Global.config_cache.set_value("timeline", "display_mode", timeline_mode)',
		"Timeline mode must persist independently of project data",
	)
	check_has(
		source,
		"timeline_container.visible = timeline_mode == TimelineMode.ANIMATION",
		"Animation mode must keep the existing timeline intact",
	)
	check_has(
		source,
		"single_frame_layer_strip.visible = timeline_mode == TimelineMode.SINGLE_FRAME",
		"Single-frame mode must swap only the Timeline presentation",
	)
	check_has(
		scene,
		'[node name="SingleFrameLayerStrip" parent="." instance=ExtResource("32_single")]',
		"single-frame view must live beside the existing TimelineContainer",
	)


func test_single_frame_mode_stops_active_animation() -> void:
	var source := FileAccess.get_file_as_string(TIMELINE_SOURCE)
	check_has(
		source,
		"if next_mode == TimelineMode.SINGLE_FRAME and is_animation_running:",
		"single-frame mode must not leave animation playback running behind the layer strip",
	)
	check_has(
		source,
		"play_forward.button_pressed = false",
		"forward animation must be stoppable when entering single-frame mode",
	)
	check_has(
		source,
		"play_backwards.button_pressed = false",
		"reverse animation must be stoppable when entering single-frame mode",
	)


func test_mode_switch_is_fixed_on_timeline_header_right_side() -> void:
	var scene := FileAccess.get_file_as_string(HEADER_SCENE)
	var source := FileAccess.get_file_as_string(HEADER_SOURCE)
	var overflow_pos := scene.find('[node name="OverflowButton"')
	var mode_pos := scene.find('[node name="ModeSwitch"')
	check_true(
		overflow_pos >= 0 and mode_pos > overflow_pos,
		"mode switch must be placed to the right of the responsive overflow button",
	)
	check_has(scene, "toggle_mode = true", "mode switch must toggle both views directly")
	check_has(scene, 'text = "Animation"', "Animation must be the default visible mode label")
	check_has(
		source,
		"fixed_right_width := mode_switch_button.get_combined_minimum_size().x",
		"responsive overflow must reserve width for the mode switch instead of hiding it",
	)
	var mode_managed := "_managed_items = [global_tool_options, undo_button, redo_button, frame_group, mode_switch_button]"
	check_true(
		not source.contains(mode_managed),
		"mode switch must not become an overflow-managed command",
	)


func test_single_frame_layer_strip_is_horizontal_and_keeps_add_layer_at_tail() -> void:
	var scene := FileAccess.get_file_as_string(STRIP_SCENE)
	var source := FileAccess.get_file_as_string(STRIP_SOURCE)
	check_has(scene, '[node name="LayerScroll" type="ScrollContainer"', "layer view must scroll")
	check_has(scene, "vertical_scroll_mode = 0", "single-frame layer view must scroll horizontally")
	check_has(
		scene,
		'[node name="LayerRow" type="HBoxContainer"',
		"single-frame layers must use a horizontal thumbnail row",
	)
	check_has(
		scene,
		"custom_minimum_size = Vector2(104, 104)",
		"new-layer control must be a fixed square button",
	)
	check_has(
		source,
		"var layer_index := project.layers.size() - 1 - visual_index",
		"horizontal order must preserve the existing top-to-bottom visual layer order",
	)
	check_has(
		source,
		"layer_row.move_child(card, layer_row.get_child_count() - 2)",
		"every layer card must remain immediately before the trailing new-layer button",
	)
	check_has(
		source,
		"Global.animation_timeline.add_default_pixel_layer()",
		"tail button must reuse the existing undoable pixel-layer creation path",
	)


func test_single_frame_cards_show_fixed_square_checkerboard_thumbnails() -> void:
	var scene := FileAccess.get_file_as_string(CARD_SCENE)
	var source := FileAccess.get_file_as_string(CARD_SOURCE)
	check_has(
		scene,
		"offset_right = 98.0",
		"thumbnail width must remain fixed inside the layer card",
	)
	check_has(
		scene,
		"offset_bottom = 98.0",
		"thumbnail height must equal its width",
	)
	check_has(
		scene,
		'path="res://src/UI/Nodes/TransparentChecker.tscn"',
		"every layer thumbnail must expose transparent pixels through the checkerboard",
	)
	check_has(scene, "texture_filter = 1", "layer preview must use nearest-neighbor filtering")
	check_has(
		scene,
		"stretch_mode = 5",
		"layer image must preserve aspect ratio and fit its long edge inside the square preview",
	)
	check_has(scene, "clip_text = true", "layer name must remain a single clipped line")
	check_has(
		source,
		"preview_texture.texture = _cel.image_texture",
		"thumbnail must reuse the current frame cel texture rather than render duplicate image data",
	)
	check_has(
		source,
		"_cel.texture_changed.connect(_on_cel_texture_changed)",
		"thumbnail must update live when drawing changes the current cel texture",
	)


func test_single_frame_layer_selection_never_changes_the_current_frame() -> void:
	var source := FileAccess.get_file_as_string(CARD_SOURCE)
	check_has(
		source,
		"project.selected_cels.append([project.current_frame, layer_index])",
		"single-frame card selection must remain bound to the current frame",
	)
	check_has(
		source,
		"project.change_cel(-1, layer_index)",
		"layer cards must change only the layer and preserve the active frame",
	)
