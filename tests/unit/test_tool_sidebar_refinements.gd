extends "res://tests/test_base.gd"

const MAGIC_WAND_SCENE := "res://src/Tools/SelectionTools/MagicWand.tscn"
const MAGIC_WAND_SOURCE := "res://src/Tools/SelectionTools/MagicWand.gd"
const BASE_SELECTION_SOURCE := "res://src/Tools/BaseSelectionTool.gd"
const TOOLS_SOURCE := "res://src/Autoload/Tools.gd"
const TOOL_BUTTONS_SOURCE := "res://src/UI/ToolsPanel/ToolButtons.gd"
const CROP_SOURCE := "res://src/Tools/UtilityTools/CropTool.gd"
const ERASER_SCENE := "res://src/Tools/DesignTools/Eraser.tscn"
const ERASER_SOURCE := "res://src/Tools/DesignTools/Eraser.gd"


func test_color_selection_replaces_mode_dropdown_with_four_exclusive_buttons() -> void:
	var tools_source := FileAccess.get_file_as_string(TOOLS_SOURCE)
	var scene := FileAccess.get_file_as_string(MAGIC_WAND_SCENE)
	var source := FileAccess.get_file_as_string(MAGIC_WAND_SOURCE)
	var base_source := FileAccess.get_file_as_string(BASE_SELECTION_SOURCE)

	check_has(
		tools_source,
		'"Color Selection"',
		"Magic Wand should be presented as Color Selection in the tool UI",
	)
	check_has(scene, '[sub_resource type="ButtonGroup" id="ButtonGroup_modes"]')
	check_has(scene, '[node name="Modes" parent="." index="4"]\nvisible = false')
	for button_name in ["Replace", "Add", "Subtract", "Intersect"]:
		check_has(
			scene,
			'[node name="%s" type="Button" parent="ModeButtons"' % button_name,
			"Color Selection mode %s must be a dedicated button" % button_name,
		)
	check_eq(
		scene.count('button_group = SubResource("ButtonGroup_modes")'),
		4,
		"all four mode buttons must share one ButtonGroup for mutual exclusion",
	)
	check_has(
		source,
		"button.set_pressed_no_signal(index == _mode_selected)",
		"persisted selection mode must restore the pressed button",
	)
	check_has(
		source,
		"_mode_selected = clampi(index, Mode.DEFAULT, Mode.INTERSECT)",
		"mode buttons must write back through the existing selection mode state",
	)
	check_has(
		base_source,
		'visible_controls.append(&"ModeButtons")',
		"iOS compact selection options must expose the new vertical mode buttons",
	)


func test_crop_sidebar_has_no_configuration_and_applies_on_release() -> void:
	var source := FileAccess.get_file_as_string(CROP_SOURCE)
	check_has(
		source,
		'if control.name in [&"ColorRect", &"Label"]',
		"Crop must leave only the tool identity visible in the options column",
	)
	check_has(
		source,
		"control.hide()",
		"all Crop configuration controls must be hidden from the sidebar",
	)
	check_has(
		source,
		"if not _drag_changed:",
		"a tap without a crop drag must not apply a stale crop rectangle",
	)
	check_has(
		source,
		"_crop.apply()",
		"Crop must commit on drag release after removing the Apply button from the UI",
	)


func test_eraser_uses_percent_opacity_and_removes_density() -> void:
	var scene := FileAccess.get_file_as_string(ERASER_SCENE)
	var source := FileAccess.get_file_as_string(ERASER_SOURCE)
	check_has(scene, "max_value = 100.0", "Eraser opacity must cap at 100 percent")
	check_has(scene, "value = 100.0", "Eraser opacity should default to 100 percent")
	check_has(scene, 'suffix = "%"', "Eraser opacity control must display a percent suffix")
	check_has(
		source,
		"_strength = clampf(value / 100.0, 0.0, 1.0)",
		"Eraser percent UI must normalize to the existing 0-1 strength channel",
	)
	check_has(
		source,
		"$OpacitySlider.value = _strength * 100.0",
		"stored Eraser strength must restore back to the percent UI",
	)
	check_has(
		source,
		'config.erase("brush_density")',
		"Eraser must stop persisting inherited Density",
	)
	check_has(
		source,
		"_brush_density = 100",
		"stale Eraser Density config must no longer affect drawing",
	)
	check_has(
		source,
		"$DensityValueSlider.visible = false",
		"Eraser Density must stay hidden after brush/config refreshes",
	)


func test_shading_is_removed_from_ios_toolbar() -> void:
	var source := FileAccess.get_file_as_string(TOOL_BUTTONS_SOURCE)
	check_has(
		source,
		'const IOS_TOOLBAR_REMOVED_TOOLS := [&"Text", &"Zoom", &"Pan", &"Shading"]',
		"Shading must be part of the iOS toolbar removal set",
	)
