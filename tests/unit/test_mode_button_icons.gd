extends "res://tests/test_base.gd"

const ICONS := "res://assets/graphics/mode_icons/mdi/"
const MODE_PICKER := preload("res://src/UI/Nodes/ToolOptionModePicker.gd")

var _test_mode_index := 0


func _check_mode_buttons(scene_path: String, expected: Dictionary) -> void:
	var packed := load(scene_path) as PackedScene
	check_true(packed != null, "tool options scene must load: " + scene_path)
	if packed == null:
		return
	var options := packed.instantiate()
	check_true(options != null, "tool options scene must instantiate: " + scene_path)
	if options == null:
		return
	for path: String in expected:
		var button := options.get_node_or_null(path) as Button
		check_true(button != null, "mode button must exist: " + path)
		if button == null:
			continue
		check_eq(button.text, "", "mode button must be icon-only: " + path)
		check_true(button.icon != null, "icon asset must load: " + path)
		if button.icon != null:
			check_eq(
				button.icon.resource_path,
				ICONS + str(expected[path]) + ".svg",
				"mode must use the approved MDI icon: " + path
			)
		check_eq(
			button.icon_alignment,
			HORIZONTAL_ALIGNMENT_CENTER,
			"mode icon must be horizontally centered: " + path
		)
		check_true(button.expand_icon, "mode icon must fit compact Tool Options: " + path)
		check_eq(button.custom_minimum_size, Vector2(32, 32), "mode button must be 1:1: " + path)
		check_eq(
			button.size_flags_horizontal,
			Control.SIZE_SHRINK_CENTER,
			"mode button must not stretch in Tool Options: " + path
		)
		check_true(
			not button.tooltip_text.is_empty(), "mode must retain accessible tooltip: " + path
		)
		check_true(button.toggle_mode, "mode must remain toggleable: " + path)
		check_true(button.button_group != null, "mode group must stay exclusive: " + path)
		check_true(
			button.pressed.get_connections().size() > 0,
			"mode must keep its original click handler: " + path
		)
	options.free()


func test_selection_icon_mapping() -> void:
	_check_mode_buttons(
		"res://src/Tools/BaseSelectionTool.tscn",
		{
			"ModeButtons/Replace": "selection",
			"ModeButtons/Add": "vector-union",
			"ModeButtons/Subtract": "selection-remove",
			"ModeButtons/Intersect": "vector-intersection",
		}
	)


func test_color_picker_icon_mapping() -> void:
	_check_mode_buttons(
		"res://src/Tools/UtilityTools/ColorPicker.tscn",
		{
			"ColorPicker/ExtractModeButtons/TopColor": "layers-triple",
			"ColorPicker/ExtractModeButtons/CurrentLayer": "layers",
		}
	)


func test_bucket_fill_area_icon_mapping() -> void:
	_check_mode_buttons(
		"res://src/Tools/DesignTools/Bucket.tscn",
		{
			"FillAreaOptions/SimilarArea": "selection-search",
			"FillAreaOptions/SimilarColors": "palette-swatch",
			"FillAreaOptions/WholeSelection": "select-all",
		}
	)


func test_mode_buttons_keep_square_geometry_in_wide_column() -> void:
	var cases := {
		"res://src/Tools/BaseSelectionTool.tscn":
		[
			"ModeButtons/Replace",
			"ModeButtons/Add",
			"ModeButtons/Subtract",
			"ModeButtons/Intersect",
		],
		"res://src/Tools/UtilityTools/ColorPicker.tscn":
		[
			"ColorPicker/ExtractModeButtons/TopColor",
			"ColorPicker/ExtractModeButtons/CurrentLayer",
		],
		"res://src/Tools/DesignTools/Bucket.tscn":
		[
			"FillAreaOptions/SimilarArea",
			"FillAreaOptions/SimilarColors",
			"FillAreaOptions/WholeSelection",
		],
	}
	for scene_path: String in cases:
		var options := (load(scene_path) as PackedScene).instantiate() as BaseTool
		options.prepare_stacked_option_layout()
		var wide_column := VBoxContainer.new()
		wide_column.custom_minimum_size = Vector2(220, 0)
		tree.root.add_child(wide_column)
		var buttons: Array[Button] = []
		for path: String in cases[scene_path]:
			var button := options.get_node(path) as Button
			button.owner = null
			button.get_parent().remove_child(button)
			wide_column.add_child(button)
			buttons.append(button)
		await tree.process_frame
		for button in buttons:
			check_almost_eq(
				button.size.x,
				button.size.y,
				0.01,
				"icon mode buttons must remain square in a wide UI3 Tool Options column"
			)
			check_true(
				button.size.x < 54.0,
				"icon mode buttons must not retain the old wide text-button minimum"
			)
		wide_column.queue_free()
		options.free()
		await tree.process_frame


func test_bucket_fill_source_icon_mapping() -> void:
	_check_mode_buttons(
		"res://src/Tools/DesignTools/Bucket.tscn",
		{
			"FillWithOptions/SelectedColor": "palette-swatch",
			"FillWithOptions/Pattern": "checkerboard",
		}
	)


func test_curve_mode_icon_mapping() -> void:
	_check_mode_buttons(
		"res://src/Tools/DesignTools/CurveTool.tscn",
		{
			"BezierOptions/BezierMode/Chained": "vector-polyline",
			"BezierOptions/BezierMode/Single": "vector-bezier",
		}
	)


func _get_test_mode_index() -> int:
	return _test_mode_index


func _set_test_mode_index(index: int) -> void:
	_test_mode_index = index


func test_compact_mode_picker_tracks_current_mode_and_keeps_original_buttons() -> void:
	_test_mode_index = 0
	var host := VBoxContainer.new()
	var first := Button.new()
	first.name = "First"
	first.icon = load(ICONS + "selection.svg")
	first.tooltip_text = "Replace selection"
	host.add_child(first)
	var second := Button.new()
	second.name = "Second"
	second.icon = load(ICONS + "vector-union.svg")
	second.tooltip_text = "Add to selection"
	host.add_child(second)

	var picker := MODE_PICKER.new(
		host, Callable(self, "_get_test_mode_index"), Callable(self, "_set_test_mode_index")
	)
	var trigger := host.get_node_or_null(^"ModeTrigger") as Button
	var popup := host.get_node_or_null(^"ModeChoicesPopup") as PopupPanel
	check_true(trigger != null, "one centered icon+caption trigger replaces the source row")
	check_true(popup != null, "mode choices are presented in a separate popup")
	check_true(not first.visible and not second.visible, "original buttons are kept but hidden")
	if trigger != null:
		check_eq(trigger.icon, first.icon, "trigger shows the saved current mode")
		check_eq(trigger.text, "Replace", "unmapped modes use a readable tooltip fallback")
		check_eq(trigger.custom_minimum_size, Vector2(32, 48), "labeled mode triggers stay narrow")
		check_eq(trigger.vertical_icon_alignment, VERTICAL_ALIGNMENT_TOP, "mode icon is above its caption")
		check_eq(trigger.size_flags_horizontal, Control.SIZE_SHRINK_CENTER, "trigger stays centered in panel")
		check_eq(trigger.tooltip_text, first.tooltip_text, "tooltip identifies active mode")
	_test_mode_index = 1
	picker.sync()
	if trigger != null:
		check_eq(trigger.icon, second.icon, "trigger updates when configuration changes")
		check_eq(trigger.text, "Add", "active mode updates its visible caption")
		check_eq(trigger.tooltip_text, second.tooltip_text, "tooltip updates with active mode")
	host.free()


func test_compact_mode_picker_shows_short_labels_on_popup_choices() -> void:
	var host := VBoxContainer.new()
	for mode_name in ["SimilarArea", "SimilarColors", "WholeSelection"]:
		var button := Button.new()
		button.name = mode_name
		button.icon = load(ICONS + "select-all.svg")
		button.tooltip_text = mode_name
		host.add_child(button)
	var picker := MODE_PICKER.new(
		host, Callable(self, "_get_test_mode_index"), Callable(self, "_set_test_mode_index")
	)
	var trigger := host.get_node_or_null(^"ModeTrigger") as Button
	var popup := host.get_node_or_null(^"ModeChoicesPopup") as PopupPanel
	var grid := popup.get_child(0).get_child(0) as GridContainer
	check_true(trigger != null, "mode trigger exists")
	if trigger != null:
		check_eq(trigger.text, "Area", "active mode has a concise label below the icon")
	check_eq(grid.get_child_count(), 3, "popup retains all three original modes")
	for index in 3:
		var choice := grid.get_child(index) as Button
		check_eq(choice.text, ["Area", "Colors", "All"][index], "popup labels identify each mode")
		check_eq(choice.vertical_icon_alignment, VERTICAL_ALIGNMENT_TOP, "popup icon sits above caption")
		check_true(choice.custom_minimum_size.y >= 54, "popup label has vertical room")
	_test_mode_index = 2
	picker.sync()
	if trigger != null:
		check_eq(trigger.text, "All", "current-mode caption updates without rebuilding popup")
	host.free()


func test_zoom_crop_and_pencil_icon_actions_match_preview_caption_layout() -> void:
	var cases := {
		"res://src/Tools/UtilityTools/Zoom.tscn": {"FitToFrame": "Fit", "100%": "100%"},
		"res://src/Tools/UtilityTools/CropTool.tscn": {"Apply": "Apply"},
		"res://src/Tools/DesignTools/Pencil.tscn": {"PressureSettings": "Pressure"},
	}
	for scene_path: String in cases:
		var options := (load(scene_path) as PackedScene).instantiate()
		for node_path: String in cases[scene_path]:
			var button := options.get_node(node_path) as Button
			check_eq(button.text, cases[scene_path][node_path], "icon action has a visible caption")
			check_eq(button.vertical_icon_alignment, VERTICAL_ALIGNMENT_TOP, "icon is above caption")
			check_eq(button.get_theme_font_size(&"font_size"), 9, "caption matches Preview font")
			check_eq(button.custom_minimum_size.y, 48.0, "caption has dedicated height")
			check_eq(button.size_flags_horizontal, Control.SIZE_SHRINK_CENTER, "button is centered")
		options.free()
