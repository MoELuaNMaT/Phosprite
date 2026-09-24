extends "res://tests/test_base.gd"

const MAGIC_WAND_SCENE := "res://src/Tools/SelectionTools/MagicWand.tscn"
const MAGIC_WAND_SOURCE := "res://src/Tools/SelectionTools/MagicWand.gd"
const BASE_SELECTION_SOURCE := "res://src/Tools/BaseSelectionTool.gd"
const BASE_SELECTION_SCENE := "res://src/Tools/BaseSelectionTool.tscn"
const TOOLS_SOURCE := "res://src/Autoload/Tools.gd"
const TOOL_BUTTONS_SOURCE := "res://src/UI/ToolsPanel/ToolButtons.gd"
const CROP_SOURCE := "res://src/Tools/UtilityTools/CropTool.gd"
const ERASER_SCENE := "res://src/Tools/DesignTools/Eraser.tscn"
const ERASER_SOURCE := "res://src/Tools/DesignTools/Eraser.gd"
const BASE_TOOL_SCENE := "res://src/Tools/BaseTool.tscn"
const BUCKET_SCENE := "res://src/Tools/DesignTools/Bucket.tscn"


func test_all_selection_tools_share_four_exclusive_mode_buttons_and_magic_wand_name() -> void:
	var tools_source := FileAccess.get_file_as_string(TOOLS_SOURCE)
	var base_scene := FileAccess.get_file_as_string(BASE_SELECTION_SCENE)
	var base_source := FileAccess.get_file_as_string(BASE_SELECTION_SOURCE)
	var wand_scene := FileAccess.get_file_as_string(MAGIC_WAND_SCENE)
	var wand_source := FileAccess.get_file_as_string(MAGIC_WAND_SOURCE)

	check_has(
		tools_source,
		'"Magic Wand"',
		"Magic Wand must keep its original tool name instead of Color Selection",
	)
	check_true(
		not tools_source.contains('"Color Selection"'),
		"Magic Wand registry entry must no longer use the temporary Color Selection name",
	)
	check_has(
		base_scene,
		'[sub_resource type="ButtonGroup" id="ButtonGroup_modes"]',
		"selection modes must share a dedicated ButtonGroup in the base scene",
	)
	check_has(
		base_scene,
		'[node name="Modes" type="OptionButton" parent="." index="4" unique_id=1993262786]\nvisible = false',
		"the inherited selection mode dropdown must be hidden",
	)
	for button_name in ["Replace", "Add", "Subtract", "Intersect"]:
		check_has(
			base_scene,
			'[node name="%s" type="Button" parent="ModeButtons"' % button_name,
			"selection mode %s must be a shared base button" % button_name,
		)
	check_eq(
		base_scene.count('button_group = SubResource("ButtonGroup_modes")'),
		4,
		"all four shared selection buttons must remain mutually exclusive",
	)
	check_has(
		base_source,
		"button.set_pressed_no_signal(index == _mode_selected)",
		"persisted selection mode must restore the pressed shared button",
	)
	check_has(
		base_source,
		"_mode_selected = clampi(index, Mode.DEFAULT, Mode.INTERSECT)",
		"shared mode buttons must write through the existing selection mode state",
	)
	check_true(
		not wand_scene.contains('[node name="ModeButtons"'),
		"Magic Wand must not retain a tool-specific mode-button copy",
	)
	check_true(
		not wand_source.contains("func _on_mode_button_pressed"),
		"Magic Wand logic must delegate shared mode state to BaseSelectionTool",
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

func test_tool_name_moves_out_of_options_and_bucket_label_is_compact() -> void:
	var base_scene := FileAccess.get_file_as_string(BASE_TOOL_SCENE)
	check_has(
		base_scene,
		'[node name="Label" type="Label" parent="." unique_id=236766783]\nvisible = false',
		"tool options must not repeat the active tool name below the Workspace header",
	)
	var bucket_scene := FileAccess.get_file_as_string(BUCKET_SCENE)
	check_has(
		bucket_scene,
		'text = "Across Layers"',
		"Bucket merged-layer fill option should use the compact Across Layers label",
	)
	var zh_cn := FileAccess.get_file_as_string("res://Translations/zh_CN.po")
	check_has(
		zh_cn,
		'msgid "Across Layers"\nmsgstr "跨图层"',
		"Simplified Chinese Bucket UI must display the requested three-character label",
	)
