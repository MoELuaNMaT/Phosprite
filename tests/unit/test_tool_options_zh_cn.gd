extends "res://tests/test_base.gd"


func test_simplified_chinese_tool_options_have_short_translations() -> void:
	var translation := load("res://Translations/zh_CN.po") as Translation
	check_true(translation != null, "Simplified Chinese catalog must load")
	if translation == null:
		return
	var cases := {
		"Tool Options": "工具选项",
		"Brush": "笔刷",
		"Opacity": "不透明度",
		"Dither": "抖动",
		"Pattern": "图案",
		"Pattern:": "图案：",
		"Coverage": "覆盖率",
		"Coverage:": "覆盖率：",
		"Fill area": "填充范围",
		"Fill with": "填充方式",
		"Selected color": "当前颜色",
		"Tolerance": "容差",
		"Offset X": "水平偏移",
		"Offset Y": "垂直偏移",
		"Shape": "形状",
		"Dithering pattern": "抖动图案",
		"Intersection of selections": "与选区取交集",
		"Top Color": "顶部颜色",
		"Current Layer": "当前图层",
		"From other tool": "沿用其他工具颜色",
		"Fit to frame": "适应画布",
		"Amount:": "强度：",
		"Value:": "明度：",
		"Select grid boxes": "按网格选取",
	}
	for source: String in cases:
		check_eq(
			String(translation.get_message(source)),
			str(cases[source]),
			"Tool Options translation: " + source,
		)


func test_tool_options_dynamic_labels_request_translation() -> void:
	var profile := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceUIProfile3.gd"
	)
	check_has(profile, 'tr("Tool Options")', "UI3 title must respect active locale")
	var gradient := FileAccess.get_file_as_string(
		"res://src/Tools/DesignTools/Gradient.gd"
	)
	check_has(
		gradient, "tooltip_text = tr(String(names[index]))", "Gradient mode tips must translate"
	)
	var selection := FileAccess.get_file_as_string(
		"res://src/Tools/BaseSelectionTool.gd"
	)
	check_has(selection, '$Modes.add_item(tr("Replace selection"))', "Selection menus translate")
