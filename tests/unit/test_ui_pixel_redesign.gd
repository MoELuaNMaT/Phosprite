extends "res://tests/test_base.gd"

const Tokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")
const QIcons := preload("res://src/UI/DesignSystem/PhospriteQIcons.gd")
const ThemeBridge := preload("res://src/UI/DesignSystem/PhospriteThemeBridge.gd")


func test_all_79_q_icons_import_and_scale_nearest() -> void:
	var total := (
		QIcons.TOOL_PATHS.size() + QIcons.STANDARD_PATHS.size() + QIcons.COMPACT_PATHS.size()
	)
	check_eq(total, 79, "Q icon registry covers all 79 manifest icons")

	for tool_name in QIcons.TOOL_PATHS:
		var tex := QIcons.tool_icon(tool_name)
		check_true(tex != null, "tool icon loads: %s" % tool_name)
		if tex != null:
			check_eq(tex.get_size(), Vector2(32, 32), "tool icon 2x scaled to 32x32")

	for std_id in QIcons.STANDARD_PATHS:
		var tex := QIcons.standard_icon(std_id)
		check_true(tex != null, "standard icon loads: %s" % std_id)
		if tex != null:
			check_eq(tex.get_size(), Vector2(32, 32), "standard icon 2x scaled to 32x32")

	for cmp_id in QIcons.COMPACT_PATHS:
		var tex := QIcons.compact_icon(cmp_id)
		check_true(tex != null, "compact icon loads: %s" % cmp_id)
		if tex != null:
			check_eq(tex.get_size(), Vector2(24, 24), "compact icon 2x scaled to 24x24")


func test_theme_bridge_applies_pixel_styleboxes_and_preserves_fonts() -> void:
	check_eq(Global.pixel_ui_unit, 2, "default pixel UI unit is 2px for crisp stepped chrome")
	for mode in [Tokens.SUNNY, Tokens.TWILIGHT]:
		var t := Theme.new()
		ThemeBridge.apply_to_theme(t, mode, 2)
		check_true(
			t.get_stylebox(&"normal", &"Button") is StyleBoxTexture,
			"Button normal uses pixel nine-slice"
		)
		check_true(
			t.get_stylebox(&"panel", &"PopupMenu") is StyleBoxTexture,
			"PopupMenu panel uses pixel nine-slice"
		)
		check_true(
			t.get_stylebox(&"normal", &"LineEdit") is StyleBoxTexture,
			"LineEdit normal uses pixel nine-slice"
		)
		check_true(
			t.get_icon(&"checked", &"CheckBox") is ImageTexture,
			"CheckBox checked uses pixel ImageTexture"
		)
		check_true(
			t.get_icon(&"grabber", &"HSlider") is ImageTexture,
			"HSlider grabber uses pixel ImageTexture"
		)
		check_true(not t.has_font(&"font", &"Button"), "ThemeBridge never overrides CJK font")


func test_workspace_profiles_are_independent_without_animation_desk_label() -> void:
	for po_path in ["res://Translations/zh_CN.po", "res://Translations/zh_TW.po"]:
		var text := FileAccess.get_file_as_string(po_path)
		check_true(not text.contains("动画工作台"), "zh_CN removes Animation Workspace label")
		check_true(not text.contains("動畫工作台"), "zh_TW removes Animation Workspace label")
		check_true(text.contains("U-Frame Dock"), "translations include U-Frame Dock profile")
