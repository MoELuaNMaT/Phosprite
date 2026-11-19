extends "res://tests/test_base.gd"

const Module := preload("res://src/UI/Workspace/WorkspaceModule.gd")


func test_header_overlay_retains_layout_but_inherits_active_ui_theme() -> void:
	var root := Control.new()
	root.name = &"TestUIThemeRoot"
	var initial_theme := Theme.new()
	initial_theme.default_font = load("res://assets/fonts/Roboto-Regular.ttf") as Font
	initial_theme.default_font_size = 16
	root.theme = initial_theme
	tree.root.add_child(root)

	var module := Module.new()
	module.size = Vector2(400, 220)
	root.add_child(module)
	var header := HBoxContainer.new()
	var label := Label.new()
	label.text = "Current frame: 1/1"
	var mode := Button.new()
	mode.text = "Single frame"
	header.add_child(label)
	header.add_child(mode)

	check_true(module.set_header_accessory(header), "header accessory must attach")
	check_true(header.get_parent() is Node2D, "header overlay keeps non-container layout")
	check_eq(header.theme, initial_theme, "header must get app theme across Node2D")
	check_eq(label.get_theme_default_font(), initial_theme.default_font, "frame label font")
	check_eq(mode.get_theme_default_font(), initial_theme.default_font, "mode button font")

	var replacement_theme := Theme.new()
	replacement_theme.default_font = ThemeDB.fallback_font
	replacement_theme.default_font_size = 19
	root.theme = replacement_theme
	Themes.theme_switched.emit()
	check_eq(header.theme, replacement_theme, "theme switches must update header theme")
	check_eq(label.get_theme_default_font(), replacement_theme.default_font, "label tracks theme")
	check_eq(mode.get_theme_default_font(), replacement_theme.default_font, "button tracks theme")
	check_eq(module.get_header_accessory(), header, "header identity must remain unchanged")

	root.free()


func test_header_controller_uses_ascii_indices_and_remeasures_on_theme_change() -> void:
	var script := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/TimelineHeaderControls.gd"
	)
	check_has(script, "str(project.current_frame + 1)", "frame index uses ASCII digits")
	check_has(script, "str(project.frames.size())", "frame count uses ASCII digits")
	check_true(
		not script.contains("text_server.format_number("),
		"numeric identifiers must not use locale-specific digits"
	)
	check_has(script, "NOTIFICATION_THEME_CHANGED", "font changes trigger layout remeasure")
	check_has(script, "_refresh_item_widths()", "frame label width is recomputed")
