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
