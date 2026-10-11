extends "res://tests/test_base.gd"

const ICONS := "res://assets/graphics/mode_icons/mdi/"


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
