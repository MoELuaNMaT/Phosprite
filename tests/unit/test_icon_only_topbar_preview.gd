extends "res://tests/test_base.gd"

const TOP_MENU := preload("res://src/UI/TopMenuContainer/TopMenuContainer.gd")
const PREVIEW_SCENE := preload("res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.tscn")
const ICON_ROOT := "res://assets/graphics/ui/tabler/"


func test_ipad_topbar_uses_icons_without_replacing_effects_menu() -> void:
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
	check_eq(home.text, "", "Projects button is icon-only")
	check_eq(settings.text, "", "Settings button is icon-only")
	check_true(home.icon != null, "Projects icon exists")
	check_true(settings.icon != null, "Settings icon exists")
	check_eq(home.custom_minimum_size, Vector2(32, 32), "Projects target is 32 square")
	check_eq(settings.custom_minimum_size, Vector2(32, 32), "Settings target is 32 square")
	check_eq(bar.get_menu_count(), 1, "Effects remains the original MenuBar item")
	check_eq(bar.get_menu_popup(0), effects, "Effects menu is not copied")
	check_true(bar.get_menu_title(0).strip_edges().is_empty(), "Effects text is hidden")
	check_eq(bar.custom_minimum_size, Vector2(32, 32), "Effects fits topbar height")
	var overlay := bar.get_node_or_null("EffectsIconOverlay") as TextureRect
	check_true(is_instance_valid(overlay), "Effects icon overlay exists")
	if is_instance_valid(overlay):
		check_eq(
			overlay.mouse_filter,
			Control.MOUSE_FILTER_IGNORE,
			"Effects icon must not intercept taps",
		)
		check_true(overlay.texture != null, "Effects icon texture exists")

	menu._set_ipad_topbar_icons(false)
	check_eq(bar.get_menu_title(0), "Effects", "desktop menu title is restored")
	check_true(home.icon == null, "desktop Projects button restores its text mode")
	check_true(settings.icon == null, "desktop Settings button restores its text mode")
	if is_instance_valid(overlay):
		check_true(not overlay.visible, "Effects icon overlay hides outside iPad editor")
	menu.free()


func test_preview_view_controls_are_consistent_icon_only_buttons() -> void:
	var preview := PREVIEW_SCENE.instantiate()
	var button_names := [
		"CenterCanvasButton",
		"MirrorViewButton",
		"ShowGridButton",
		"ShowPixelGridButton",
		"AddReferenceButton",
		"GrayscaleButton",
	]
	var flow := preview.get_node("VBox/Animation/PreviewViewButtons") as HFlowContainer
	check_true(flow != null, "view buttons preserve the wrapping container")
	for button_name in button_names:
		var button := flow.get_node(button_name) as Button
		check_true(button != null, "%s exists" % button_name)
		if button == null:
			continue
		check_eq(button.text, "", "%s has no visible text" % button_name)
		check_true(button.icon != null, "%s has an imported vector icon" % button_name)
		check_eq(
			button.icon_alignment,
			HORIZONTAL_ALIGNMENT_CENTER,
			"%s icon is horizontally centered" % button_name
		)
		check_eq(
			button.custom_minimum_size, Vector2(32, 32), "%s target is 32 square" % button_name
		)
		check_true(not button.tooltip_text.is_empty(), "%s keeps a localized tooltip" % button_name)
	check_eq(
		preview.get_node("VBox/Animation/PlayButton").custom_minimum_size,
		Vector2(32, 32),
		"play control uses the same height as the preview actions",
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
