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
	check_true(trigger != null, "one compact icon trigger replaces the source row")
	check_true(popup != null, "mode choices are presented in a separate popup")
	check_true(not first.visible and not second.visible, "original buttons are kept but hidden")
	if trigger != null:
		check_eq(trigger.icon, first.icon, "trigger shows the saved current mode")
		check_eq(trigger.tooltip_text, first.tooltip_text, "tooltip identifies active mode")
	_test_mode_index = 1
	picker.sync()
	if trigger != null:
		check_eq(trigger.icon, second.icon, "trigger updates when configuration changes")
		check_eq(trigger.tooltip_text, second.tooltip_text, "tooltip updates with active mode")
	host.free()
