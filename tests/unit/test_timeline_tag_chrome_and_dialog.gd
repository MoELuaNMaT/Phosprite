extends "res://tests/test_base.gd"

const TAG_UI_SCENE := preload("res://src/UI/Timeline/AnimationTagUI.tscn")
const TAG_PROPERTIES_SCENE := preload("res://src/UI/Timeline/TagProperties.tscn")
const Stage4 := preload("res://src/UI/DesignSystem/PhospriteStage4Chrome.gd")
const PhospriteTokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")


func test_animation_tag_range_line_uses_project_orange_accent() -> void:
	var mode := Stage4.active_mode()
	var tag_ui := TAG_UI_SCENE.instantiate() as Control
	var tag := AnimationTag.new("Walk", Color.WHITE, 1, 3)
	tag_ui.tag = tag
	tree.root.add_child(tag_ui)
	var line := tag_ui.get_node("Line2D") as Line2D
	if mode != PhospriteTokens.LEGACY:
		var expected := PhospriteTokens.color(mode, &"accent_primary")
		check_eq(
			line.default_color,
			expected,
			"timeline tag range line uses project orange accent instead of white",
		)
		check_almost_eq(line.width, 2.0, 0.01, "pixel mode tag range line uses 2px width")
	else:
		check_eq(line.default_color, Color.WHITE, "legacy mode keeps tag color")
	tag_ui.queue_free()


func test_tag_properties_does_not_auto_focus_name_input() -> void:
	var source := FileAccess.get_file_as_string("res://src/UI/Timeline/TagProperties.gd")
	check_true(
		source.find("name_line_edit.grab_focus()") == -1,
		"TagProperties no longer auto-focuses NameLineEdit on open",
	)
	var dialog := TAG_PROPERTIES_SCENE.instantiate() as ConfirmationDialog
	tree.root.add_child(dialog)
	dialog.show_dialog(Rect2i(), 0, false, PackedInt32Array([0]))
	var name_edit := dialog.get_node("GridContainer/NameLineEdit") as LineEdit
	check_true(
		not name_edit.has_focus(),
		"opening TagProperties does not automatically focus name input",
	)
	var mode := Stage4.active_mode()
	if mode != PhospriteTokens.LEGACY:
		var picker := dialog.get_node("GridContainer/ColorPickerButton") as ColorPickerButton
		check_eq(
			picker.color,
			PhospriteTokens.color(mode, &"accent_primary"),
			"new tag defaults to project orange accent color",
		)
	dialog.hide()
	dialog.queue_free()


func test_animation_tag_span_aligns_exactly_to_frame_range() -> void:
	var tag := AnimationTag.new("Run", Color.WHITE, 2, 4)
	var expected_cel := (
		Global.animation_timeline.cel_size if is_instance_valid(Global.animation_timeline) else 36
	)
	var pos := tag.get_position()
	var width := tag.get_minimum_size()
	if (
		is_instance_valid(Global.animation_timeline)
		and is_instance_valid(Global.animation_timeline.frame_hbox)
		and Global.animation_timeline.frame_hbox.get_child_count() >= 4
	):
		var start_btn := Global.animation_timeline.frame_hbox.get_child(1) as Control
		var end_btn := Global.animation_timeline.frame_hbox.get_child(3) as Control
		if start_btn.size.x > 0.0 and end_btn.size.x > 0.0:
			check_almost_eq(
				pos.x, start_btn.position.x + 1.0, 0.5, "tag left edge matches start frame"
			)
			check_almost_eq(
				float(width),
				(end_btn.position.x + end_btn.size.x) - start_btn.position.x - 2.0,
				1.0,
				"tag width spans exact frame range",
			)
	else:
		check_almost_eq(pos.x, float(expected_cel + 1), 0.5, "fallback left edge matches frame 2")
		check_eq(width, 3 * expected_cel - 2, "fallback width spans 3 frames with 1px inset")
	var tl_source := FileAccess.get_file_as_string("res://src/Classes/AnimationTag.gd")
	check_has(
		tl_source,
		"var unscrolled_frame_x := frame_hbox.global_position.x + scroll_x",
		"TagSpacer aligns directly to unscrolled FrameHBox global X",
	)
	check_has(
		tl_source,
		"hbox.custom_minimum_size.x = spacer_w + frame_hbox.size.x + extra_right",
		"TagScroll HBoxContainer width includes TagSpacer plus FrameHBox width",
	)
