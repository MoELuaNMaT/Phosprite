extends "res://tests/test_base.gd"

const TOP_MENU := preload("res://src/UI/TopMenuContainer/TopMenuContainer.gd")
const PREVIEW_SCENE := preload("res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.tscn")
const ICON_ROOT := "res://assets/graphics/ui/tabler/"


func test_ipad_topbar_uses_equal_size_buttons_and_original_effects_menu() -> void:
	var menu := TOP_MENU.new()
	var row := HBoxContainer.new()
	var home := Button.new()
	var settings := MenuButton.new()
	var bar := MenuBar.new()
	var effects := PopupMenu.new()
	effects.name = &"Effects"
	bar.add_child(effects)
	row.add_child(home)
	row.add_child(settings)
	row.add_child(bar)
	menu.add_child(row)
	menu.set("return_home_button", home)
	menu.set("settings_button", settings)
	menu.set("menu_bar", bar)
	menu.set("effects_menu", effects)

	menu._set_ipad_topbar_icons(true)
	var fx := row.get_node_or_null("EffectsIconButton") as Button
	check_true(is_instance_valid(fx), "Effects uses a real button")
	check_eq(row.get_theme_constant("separation"), 4, "all topbar gaps are equal")
	for button in [home, settings, fx]:
		if not is_instance_valid(button):
			continue
		check_eq(button.text, "", "topbar button has no visible text")
		check_eq(button.custom_minimum_size, Vector2(32, 32), "topbar target is 32 square")
		check_true(button.icon != null, "topbar icon exists")
	check_eq(bar.get_menu_count(), 1, "the original MenuBar still owns Effects")
	check_eq(bar.get_menu_popup(0), effects, "FX has no duplicate popup")
	if is_instance_valid(fx):
		check_true(
			fx.pressed.is_connected(Callable(menu, "_on_effects_icon_button_pressed")),
			"FX button opens the original Effects popup",
		)

	menu._set_ipad_topbar_icons(false)
	check_true(not row.has_theme_constant_override("separation"), "desktop spacing is restored")
	check_true(home.icon == null, "desktop Projects restores its text mode")
	check_true(settings.icon == null, "desktop Settings restores its text mode")
	if is_instance_valid(fx):
		check_true(not fx.visible, "FX icon button hides outside iPad editor")
	menu.free()


func test_preview_buttons_keep_icon_and_short_label_in_same_control() -> void:
	var preview := PREVIEW_SCENE.instantiate()
	var captions := {
		"CenterCanvasButton": "Ctr",
		"MirrorViewButton": "Flip",
		"ShowGridButton": "Grid",
		"ShowPixelGridButton": "Px",
		"AddReferenceButton": "Ref",
		"GrayscaleButton": "BW",
	}
	var flow := preview.get_node("VBox/Animation/PreviewViewButtons") as HFlowContainer
	check_true(flow != null, "view buttons preserve the wrapping container")
	for name in captions:
		var button := flow.get_node(name) as Button
		check_true(button != null, "%s exists" % name)
		if button == null:
			continue
		check_eq(button.text, captions[name], "%s has a compact caption" % name)
		check_true(button.icon != null, "%s keeps its vector icon" % name)
		check_eq(
			button.vertical_icon_alignment,
			VERTICAL_ALIGNMENT_TOP,
			"%s renders its caption under the icon" % name
		)
		check_eq(button.icon_alignment, HORIZONTAL_ALIGNMENT_CENTER, "%s icon is centered" % name)
		check_eq(button.custom_minimum_size, Vector2(32, 44), "%s target is 32 by 44" % name)
		check_eq(button.get_theme_font_size("font_size"), 9, "caption uses the small type size")
		check_true(not button.tooltip_text.is_empty(), "%s preserves its full tooltip" % name)
		var font := button.get_theme_font("font")
		for locale in ["zh_CN", "zh_TW"]:
			var translation := load("res://Translations/%s.po" % locale) as Translation
			var caption := String(translation.get_message(captions[name]))
			var caption_width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			check_true(
				caption_width <= 20.0,
				"%s %s caption stays within its 20 px icon" % [locale, name],
			)
	preview.free()


func test_icon_pack_license_and_files_are_bundled() -> void:
	check_file_exists(ICON_ROOT + "LICENSE.txt", "Tabler MIT license must ship with app")
	for name in [
		"folders",
		"settings",
		"wand",
		"focus-centered",
		"flip-horizontal",
		"grid-3x3",
		"grid-4x4",
		"photo-plus",
		"palette-off",
	]:
		check_file_exists(ICON_ROOT + name + ".svg", "%s icon is local" % name)
