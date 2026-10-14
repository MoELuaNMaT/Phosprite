extends "res://tests/test_base.gd"

const COLOR_PICKER_SCENE := "res://src/UI/ColorPickers/ColorPicker.tscn"
const COLOR_PICKER_SOURCE := "res://src/UI/ColorPickers/ColorPicker.gd"
const PALETTE_COLOR_SCENE := "res://src/UI/Workspace/PaletteColorPanel.tscn"
const PALETTE_COLOR_SOURCE := "res://src/UI/Workspace/PaletteColorPanel.gd"
const PALETTE_PANEL_SOURCE := "res://src/Palette/PalettePanel.gd"


func test_color_picker_removes_legacy_color_row_from_ui_only() -> void:
	var scene := FileAccess.get_file_as_string(COLOR_PICKER_SCENE)
	var source := FileAccess.get_file_as_string(COLOR_PICKER_SOURCE)
	check_has(
		scene,
		'[node name="ColorButtons" type="HBoxContainer" parent="ScrollContainer/VerticalContainer"',
		"legacy color controls must remain in the scene for their existing logic",
	)
	check_has(
		scene,
		"visible = false",
		"the legacy left/right/swap/default/average color row must be hidden in the combined UI",
	)
	check_has(
		source,
		"_screen_sampler_button.visible = false",
		"screen sampling logic must remain but its old picker-row button must be hidden",
	)
	check_true(
		not source.contains("sampler_cont.add_child(color_buttons)"),
		"hidden legacy color buttons must no longer be moved into the visible sampler row",
	)
	check_true(
		not source.contains("hex_cont.remove_child(hex_edit)"),
		"the old hex editor must no longer be moved into the compact sampler row",
	)
	for handler in [
		"_on_left_color_button_toggled",
		"_on_ColorSwitch_pressed",
		"_on_ColorDefaults_pressed",
		"_on_ios_screen_sampler_pressed",
	]:
		check_has(
			source,
			handler,
			"removing picker chrome must not remove the underlying color-control logic",
		)


func test_color_settings_and_both_swatches_live_in_native_sampler_row() -> void:
	var source := FileAccess.get_file_as_string("res://src/UI/ColorPickers/ColorPicker.gd")
	check_has(
		source,
		"expand_button.reparent(sampler_cont)",
		"square settings toggle belongs to the native sampler row",
	)
	check_has(
		source,
		"left_color_button.reparent(sampler_cont)",
		"left tool color occupies a distinct slot in the same row",
	)
	check_has(
		source,
		"right_color_button.reparent(sampler_cont)",
		"right tool color occupies a distinct slot in the same row",
	)
	check_has(
		source,
		"expand_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN",
		"settings button stays square rather than spanning the row",
	)


func test_palette_color_panel_uses_real_draggable_split_container() -> void:
	var scene := FileAccess.get_file_as_string(PALETTE_COLOR_SCENE)
	var source := FileAccess.get_file_as_string(PALETTE_COLOR_SOURCE)
	check_has(
		scene,
		'[node name="PaletteColorPanel" type="VSplitContainer"]',
		"Palette & Color must use a real vertical split container",
	)
	check_true(
		not scene.contains('node name="SectionSeparator"'),
		"the old passive separator must be replaced by the draggable split",
	)
	check_has(
		source,
		"dragged.connect(_on_split_dragged)",
		"mouse/pointer splitter dragging must persist the chosen boundary",
	)
	check_has(
		scene,
		"touch_dragger_enabled = true",
		"iPad must use Godot 4.6's native touch-friendly split dragger",
	)
	check_has(
		scene,
		"theme_override_constants/minimum_grab_thickness = 12",
		"the visual separator must have a larger invisible touch hit target",
	)
	check_has(
		source,
		"split_offsets = offsets",
		"automatic and manual split state must use the current Godot 4.6 split-offset API",
	)


func test_expanded_color_options_compacts_palette_to_last_used_swatch_row() -> void:
	var split_source := FileAccess.get_file_as_string(PALETTE_COLOR_SOURCE)
	var palette_source := FileAccess.get_file_as_string(PALETTE_PANEL_SOURCE)
	check_has(
		split_source,
		"palettes.get_used_color_content_height()",
		"expanded Color options must derive its boundary from actual Palette content",
	)
	check_has(
		split_source,
		"_normal_palette_height = palettes.size.y",
		"opening Color options must remember the normal Palette height for restoration",
	)
	check_has(
		split_source,
		"_restore_normal_palette_split",
		"closing Color options must restore the normal Palette allocation",
	)
	check_has(
		palette_source,
		"for swatch in palette_grid.swatches:",
		"Palette compact height must inspect rendered swatches rather than theoretical palette rows",
	)
	check_has(
		palette_source,
		"or swatch.empty",
		"empty trailing swatches must not extend the automatic Palette boundary",
	)
	check_has(
		palette_source,
		"last_color_bottom = maxf(last_color_bottom, swatch.position.y + swatch.size.y)",
		"the automatic boundary must end immediately below the final non-empty swatch row",
	)
