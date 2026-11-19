extends "res://tests/test_base.gd"

const Tokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")
const Chrome := preload("res://src/UI/DesignSystem/PhospriteStage2Chrome.gd")
const Icons := preload("res://src/UI/DesignSystem/PhospriteStage2Icons.gd")
const CardScene := preload("res://src/UI/ProjectGallery/ProjectGalleryCard.tscn")

const ICON_PATHS := {
	&"gallery": "res://assets/graphics/q_icons/top/back_gallery.png",
	&"settings": "res://assets/graphics/q_icons/top/settings_gear.png",
	&"effects": "res://assets/graphics/q_icons/top/effects_fx.png",
	&"new": "res://assets/graphics/q_icons/gallery/new_plus.png",
	&"import": "res://assets/graphics/q_icons/gallery/import_folder.png",
	&"multi_select": "res://assets/graphics/q_icons/gallery/multi_select.png",
	&"ui1": "res://assets/graphics/q_icons/layout/profile_ui1.png",
	&"ui3": "res://assets/graphics/q_icons/layout/profile_ui3.png",
	&"ui4": "res://assets/graphics/q_icons/layout/profile_ui4.png",
}


func test_chibi_icons_keep_exact_integer_pixel_grid() -> void:
	for id in ICON_PATHS:
		var path: String = ICON_PATHS[id]
		check_file_exists(path, "Stage 2 source icon exists")
		var original := load(path) as Texture2D
		check_true(original != null, "Godot imports the source PNG")
		if original == null:
			continue
		check_eq(original.get_size(), Vector2(20, 20), "source icon is exactly 20px")
		var icon := Icons.icon(id)
		check_true(icon != null, "icon registry resolves every high-frequency control")
		if icon == null:
			continue
		check_eq(icon.get_size(), Vector2(32, 32), "icon is integer 2x scaled")
		check_eq(Icons.icon(id), icon, "icon is cached and reused")
		var image := icon.get_image()
		for y in range(0, 32, 2):
			for x in range(0, 32, 2):
				var cell := image.get_pixel(x, y)
				check_eq(image.get_pixel(x + 1, y), cell, "horizontal pair remains nearest")
				check_eq(image.get_pixel(x, y + 1), cell, "vertical pair remains nearest")
				check_eq(image.get_pixel(x + 1, y + 1), cell, "2x grid is not blurred")


func test_stage2_styles_opt_in_and_clear_without_touching_font_or_selection() -> void:
	for mode in [Tokens.SUNNY, Tokens.TWILIGHT]:
		var button := Button.new()
		button.text = "新建"
		var original_minimum := Vector2(40.0, 40.0)
		button.custom_minimum_size = original_minimum
		var style := Chrome.make_panel(mode, Tokens.TIER_L, &"panel_surface", true)
		check_true(style is StyleBoxTexture, "Stage 2 uses pixel nine-slice")
		Chrome.style_button(button, mode)
		check_true(button.has_theme_stylebox_override(&"normal"), "opted-in button has style")
		check_true(button.has_theme_stylebox_override(&"pressed"), "pressed style present")
		check_eq(button.custom_minimum_size, original_minimum, "chrome does not resize touches")
		check_eq(button.text, "新建", "styles do not replace translated strings")
		check_true(not button.has_theme_font_override(&"font"), "preserves global CJK fallback")
		Chrome.clear_button(button)
		check_true(
			not button.has_theme_stylebox_override(&"normal"),
			"switch back to a legacy theme clears pixel styling"
		)
		button.free()


func test_gallery_card_legacy_is_unchanged_and_phosprite_title_is_opt_in() -> void:
	var card := CardScene.instantiate() as ProjectGalleryCard
	tree.root.add_child(card)
	check_true(card != null, "Gallery card scene remains valid")
	if card == null:
		return
	card.set_display_title("Example Sprite")
	card.apply_stage2_theme(Tokens.LEGACY)
	check_true(not card.title_strip.visible, "old themes keep existing no-title gallery")
	card.set_selected(true)
	check_true(card.selection_outline.visible, "legacy multiselect remains visible")
	card.apply_stage2_theme(Tokens.SUNNY)
	check_true(card.title_strip.visible, "Sunny Cream shows the 28px title strip")
	check_eq(card.title_label.text, "Example Sprite", "title is not rewritten by theme")
	check_true(card.get_theme_stylebox(&"panel") is StyleBoxTexture, "new pixel card shell")
	check_true(card.selection_outline.visible, "multiselect survives theme change")
	card.apply_stage2_theme(Tokens.TWILIGHT)
	check_true(card.title_strip.visible, "Twilight Berry also shows the title strip")
	card.apply_stage2_theme(Tokens.LEGACY)
	check_true(not card.title_strip.visible, "reverting restores old card layout")
	check_true(card.selection_outline.visible, "selection survives revert")
	card.free()


func test_stage2_gallery_keeps_all_original_action_handlers() -> void:
	var source := FileAccess.get_file_as_string("res://src/UI/ProjectGallery/ProjectGallery.gd")
	for key in [
		"_on_import_pressed",
		"_on_new_project_pressed",
		"_on_multiselect_pressed",
		"multiselect_button.text = tr(\"Exit Multi-Select\") if enabled else tr(\"Multi-Select\")",
		"const LANDSCAPE_COLUMNS := 6",
		"const PORTRAIT_COLUMNS := 4",
	]:
		check_has(source, key, "Gallery preserves preexisting action and orientation")
	var menu := FileAccess.get_file_as_string("res://src/UI/TopMenuContainer/TopMenuContainer.gd")
	check_has(menu, "_forward_ipad_ui(id - STAGE2_PROFILE_ID_BASE)", "UI profile uses same transaction")
	check_has(menu, "edit_menu_id_pressed(id)", "Settings still forwards old command IDs")
	var preferences := FileAccess.get_file_as_string("res://src/Preferences/PreferencesDialog.gd")
	check_has(preferences, "_ipad_change_ui_profile_id", "visual profile buttons use existing UI menu")
