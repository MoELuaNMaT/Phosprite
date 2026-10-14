extends "res://tests/test_base.gd"

const COLOR_SCENE := preload("res://src/UI/ColorPickers/ColorPicker.tscn")


func test_color_option_editor_uses_separate_staged_picker_and_explicit_close() -> void:
	var source := FileAccess.get_file_as_string("res://src/UI/ColorPickers/ColorPicker.gd")
	var scene := FileAccess.get_file_as_string("res://src/UI/ColorPickers/ColorPicker.tscn")
	check_has(scene, 'signal="pressed"', "color swatch is a button, not a toggle")
	check_true(
		not scene.contains('method="_on_expand_button_toggled"'),
		"inline color option expansion must be removed",
	)
	check_has(source, "func _open_color_options_popup()", "separate editor is created")
	check_has(source, "_color_options_picker = ColorPicker.new()", "staging owns its own picker")
	check_has(
		source, "_color_options_picker.color_modes_visible = true", "popup exposes RGB/HSV modes"
	)
	check_has(source, "_color_options_picker.sliders_visible = true", "popup exposes sliders")
	check_has(source, "_color_options_picker.hex_visible = true", "popup exposes HEX")
	check_has(source, "func _on_staged_color_changed(color: Color)", "preview listens to staging")
	check_has(
		source, "_color_preview_after.color = _color_preview_staged", "right half previews edits"
	)
	check_has(
		source,
		"_color_preview_before.color = _color_preview_original",
		"left half retains original"
	)
	check_has(
		source, "close_button.pressed.connect(_close_color_options_popup)", "only Close applies"
	)
	check_has(
		source,
		"Tools.assign_color(applied_color, target_slot, false)",
		"Close commits to captured slot"
	)
	check_true(
		not source.contains("color_picker.sliders_visible = toggled_on"),
		"embedded picker never expands"
	)


func test_staged_color_preview_ignores_external_canvas_changes() -> void:
	var editor := COLOR_SCENE.instantiate()
	check_true(editor != null, "shared ColorPicker scene loads")
	if editor == null:
		return
	# Test the isolated state transition without triggering global tool signal wiring:
	# staged updates must only modify the preview, not the actual Tools slot.
	editor._color_preview_before = ColorRect.new()
	editor._color_preview_after = ColorRect.new()
	editor._color_options_open = true
	editor._color_preview_original = Color.RED
	editor._color_preview_staged = Color.RED
	editor._on_staged_color_changed(Color.BLUE)
	check_eq(editor._color_preview_original, Color.RED, "opening color remains unchanged")
	check_eq(editor._color_preview_staged, Color.BLUE, "candidate color changes independently")
	check_eq(editor._color_preview_before.color, Color.RED, "left swatch retains old color")
	check_eq(editor._color_preview_after.color, Color.BLUE, "right swatch is the new candidate")
	# A simulated unrelated canvas color update is not a staging event.
	editor._update_color_preview_button()
	check_eq(editor._color_preview_staged, Color.BLUE, "external updates cannot clear candidate")
	editor._color_options_open = false
	editor.free()
