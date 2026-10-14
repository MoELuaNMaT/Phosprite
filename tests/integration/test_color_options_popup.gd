extends "res://tests/test_base.gd"

const COLOR_SCENE := preload("res://src/UI/ColorPickers/ColorPicker.tscn")


func test_color_options_use_live_foreground_background_and_toggle_button() -> void:
	var source := FileAccess.get_file_as_string("res://src/UI/ColorPickers/ColorPicker.gd")
	var scene := FileAccess.get_file_as_string("res://src/UI/ColorPickers/ColorPicker.tscn")
	check_has(source, "left_color_button.reparent(sampler_cont)", "left color reuses tool slot")
	check_has(source, "right_color_button.reparent(sampler_cont)", "right color reuses tool slot")
	check_has(source, "func _sync_active_color_buttons() -> void:", "selected slot is displayed")
	check_has(
		source, "Tools.assign_color(color, Tools.picking_color_for, false)", "popup edits live slot"
	)
	check_has(source, "func _sync_popup_to_active_slot() -> void:", "other picker syncs live")
	check_has(source, "func _close_color_options_popup() -> void:", "settings toggles off")
	check_has(source, 'expand_button.text = "⚙"', "settings control uses square icon")
	check_has(scene, "toggle_mode = true", "settings button toggles")
	check_true(
		not source.contains("_color_preview_staged"), "obsolete half-color staged preview removed"
	)
	check_true(
		not source.contains('close_button.text = "Close"'), "no explicit commit Close button"
	)
	check_true(
		not source.contains("_color_preview_original"), "old original color snapshot removed"
	)


func test_numeric_picker_excludes_wheel_but_includes_mode_sliders() -> void:
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
	check_true(editor._configure_staged_color_options_picker(), "native RGB HSV RAW modes isolated")
	var margin := picker.get_child(0, true) as MarginContainer
	check_true(margin != null, "native picker margin exists")
	if margin != null:
		var column := margin.get_child(0, true) as VBoxContainer
		if column != null:
			var shape := column.get_child(0, true) as Control
			var sampler := column.get_child(1, true) as Control
			var modes := column.get_child(2, true) as Control
			var sliders := column.get_child(3, true) as Control
			check_true(not shape.visible, "HSV wheel and rectangle hidden from numeric popup")
			check_true(not sampler.visible, "sampler row hidden from numeric popup")
			check_true(modes.visible, "RGB HSV RAW selector visible")
			check_true(sliders.visible, "numeric value sliders visible")
	picker.free()
	editor._color_options_picker = null
	editor.free()


func test_popup_preserves_palette_size_and_anchors_below_settings_button() -> void:
	var previous_slot := Tools.picking_color_for
	var inserted_slot := not Tools._slots.has(MOUSE_BUTTON_LEFT)
	var previous_color := Color.WHITE
	if inserted_slot:
		var slot := Tools.Slot.new("Left tool")
		slot.button = MOUSE_BUTTON_LEFT
		slot.color = Color.RED
		Tools._slots[MOUSE_BUTTON_LEFT] = slot
	else:
		previous_color = Tools._slots[MOUSE_BUTTON_LEFT].color
	Tools.picking_color_for = MOUSE_BUTTON_LEFT
	var panel := VBoxContainer.new()
	panel.size = Vector2(320.0, 700.0)
	tree.root.add_child(panel)
	var palette := Control.new()
	palette.custom_minimum_size = Vector2(80.0, 40.0)
	palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette.size_flags_stretch_ratio = 0.9
	panel.add_child(palette)
	panel.add_child(HSeparator.new())
	var editor := COLOR_SCENE.instantiate()
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.size_flags_stretch_ratio = 1.1
	panel.add_child(editor)
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	check_true(
		editor.left_color_button.get_parent() == editor.expand_button.get_parent(),
		"left color and settings are in the same stable control row",
	)
	check_true(
		editor.right_color_button.get_parent() == editor.expand_button.get_parent(),
		"right color and settings are in the same stable control row",
	)
	var palette_before: Vector2 = palette.size
	var picker_before: Vector2 = editor.color_picker.size
	var editor_before: Vector2 = editor.size
	editor._open_color_options_popup()
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	check_true(editor.is_color_options_expanded(), "settings popup opens")
	check_eq(palette.size, palette_before, "top palette dimensions unchanged")
	check_eq(editor.color_picker.size, picker_before, "native picker dimensions unchanged")
	check_eq(editor.size, editor_before, "Palette and Color section dimensions unchanged")
	if is_instance_valid(editor._color_options_popup):
		var popup_rect: Rect2 = editor._color_options_popup.get_global_rect()
		var button_rect: Rect2 = editor.expand_button.get_global_rect()
		check_true(
			popup_rect.position.y >= button_rect.end.y,
			"popup always opens below its settings button, never over it",
		)
	editor._on_expand_button_pressed()
	check_true(not editor.is_color_options_expanded(), "same settings button closes popup")
	await tree.process_frame
	check_eq(editor.size, editor_before, "closing popup never resizes original picker")
	panel.free()
	if inserted_slot:
		Tools._slots.erase(MOUSE_BUTTON_LEFT)
	else:
		Tools._slots[MOUSE_BUTTON_LEFT].color = previous_color
	Tools.picking_color_for = previous_slot


func test_numeric_adjustment_updates_selected_slot_without_closing_popup() -> void:
	var previous_slot := Tools.picking_color_for
	var previous_left := Tools._slots.get(MOUSE_BUTTON_LEFT)
	var previous_right := Tools._slots.get(MOUSE_BUTTON_RIGHT)
	for button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if not Tools._slots.has(button):
			var slot := Tools.Slot.new("Color test")
			slot.button = button
			slot.color = Color.WHITE
			Tools._slots[button] = slot
	Tools.picking_color_for = MOUSE_BUTTON_LEFT
	var left_before: Color = Tools._slots[MOUSE_BUTTON_LEFT].color
	var right_before: Color = Tools._slots[MOUSE_BUTTON_RIGHT].color
	var editor := COLOR_SCENE.instantiate()
	editor._color_options_open = true
	editor._on_popup_color_changed(Color(0.2, 0.4, 0.8, 1.0))
	check_eq(
		Tools._slots[MOUSE_BUTTON_LEFT].color,
		Color(0.2, 0.4, 0.8, 1.0),
		"color mode sliders immediately update selected foreground color",
	)
	check_eq(
		Tools._slots[MOUSE_BUTTON_RIGHT].color, right_before, "background color stays independent"
	)
	check_true(editor.is_color_options_expanded(), "popup stays open during live editing")
	Tools.picking_color_for = MOUSE_BUTTON_RIGHT
	editor._on_popup_color_changed(Color(0.7, 0.2, 0.1, 1.0))
	check_eq(
		Tools._slots[MOUSE_BUTTON_RIGHT].color,
		Color(0.7, 0.2, 0.1, 1.0),
		"switching the active color also switches popup editing target",
	)
	Tools._slots[MOUSE_BUTTON_LEFT].color = left_before
	Tools._slots[MOUSE_BUTTON_RIGHT].color = right_before
	editor._color_options_open = false
	editor.free()
	if previous_left == null:
		Tools._slots.erase(MOUSE_BUTTON_LEFT)
	if previous_right == null:
		Tools._slots.erase(MOUSE_BUTTON_RIGHT)
	Tools.picking_color_for = previous_slot
