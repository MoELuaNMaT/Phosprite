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
	check_has(source, "_color_options_picker.sampler_visible = false", "popup omits eyedropper")
	check_has(
		source, "func _configure_staged_color_options_picker() -> bool:", "staged picker is compact"
	)
	check_has(source, "_color_options_picker.hex_visible = false", "mode popup omits HEX row")
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


func test_staged_editor_hides_visual_color_palette_but_keeps_numeric_controls() -> void:
	var editor := COLOR_SCENE.instantiate()
	var picker := ColorPicker.new()
	picker.color_modes_visible = true
	picker.sliders_visible = true
	picker.hex_visible = false
	picker.sampler_visible = false
	picker.presets_visible = false
	tree.root.add_child(picker)
	await tree.process_frame
	editor._color_options_picker = picker
	check_true(
		editor._configure_staged_color_options_picker(), "native picker modes can be isolated"
	)
	var margin := picker.get_child(0, true) as MarginContainer
	check_true(margin != null, "native ColorPicker margin exists")
	if margin != null:
		var column := margin.get_child(0, true) as VBoxContainer
		check_true(column != null, "native ColorPicker column exists")
		if column != null:
			var color_shape := column.get_child(0, true) as Control
			var sampler := column.get_child(1, true) as Control
			var mode_row := column.get_child(2, true) as Control
			var sliders := column.get_child(3, true) as Control
			check_true(not color_shape.visible, "upper HSV rectangle or wheel is not in popup")
			check_true(not sampler.visible, "color sampler row is not in popup")
			check_true(mode_row.visible, "RGB HSV RAW color mode selector remains available")
			check_true(sliders.visible, "color values and sliders remain available")
	picker.free()
	editor._color_options_picker = null
	editor.free()


func test_opening_numeric_popup_does_not_shrink_main_color_picker_or_palette() -> void:
	# Reproduce the shared Palette and Color vertical stretch relationship.
	var palette_and_color := VBoxContainer.new()
	palette_and_color.size = Vector2(320.0, 700.0)
	tree.root.add_child(palette_and_color)
	var palette := Control.new()
	palette.custom_minimum_size = Vector2(80.0, 40.0)
	palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette.size_flags_stretch_ratio = 0.9
	palette_and_color.add_child(palette)
	palette_and_color.add_child(HSeparator.new())
	var editor := COLOR_SCENE.instantiate()
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.size_flags_stretch_ratio = 1.1
	palette_and_color.add_child(editor)
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	var visual_picker := editor.color_picker as ColorPicker
	var palette_size_before := palette.size
	var picker_size_before := visual_picker.size
	var editor_size_before: Vector2 = editor.size
	editor._open_color_options_popup()
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	check_true(editor.is_color_options_expanded(), "options editor is open")
	check_eq(palette.size, palette_size_before, "opening options must not resize the main palette")
	check_eq(
		visual_picker.size,
		picker_size_before,
		"opening options must not resize the main color wheel or rectangle",
	)
	check_eq(editor.size, editor_size_before, "opening options must not shrink the embedded picker")
	var popup_rect: Rect2 = editor._color_options_popup.get_global_rect()
	var panel_rect := palette_and_color.get_global_rect()
	check_true(
		not popup_rect.intersects(panel_rect),
		"separate color options must not cover the original Palette and Color panel",
	)
	editor._close_color_options_popup()
	await tree.process_frame
	check_eq(editor.size, editor_size_before, "closing the popup must not resize the picker")
	palette_and_color.free()
