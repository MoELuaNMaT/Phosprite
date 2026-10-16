extends "res://tests/test_base.gd"

const TopMenuScript := preload("res://src/UI/TopMenuContainer/TopMenuContainer.gd")


func test_compact_main_menu_moves_project_and_preferences_into_settings() -> void:
	var menu := TopMenuScript.new()
	var button := MenuButton.new()
	var bar := MenuBar.new()
	var row := HBoxContainer.new()
	var home := Button.new()
	row.add_child(button)
	row.add_child(bar)
	row.add_child(home)
	menu.add_child(row)
	menu.set("main_menu_button", button)
	menu.set("menu_bar", bar)
	menu.set("return_home_button", home)
	var names := ["File", "Edit", "Select", "Project", "UI", "Effects", "View", "Window", "Help"]
	var original: Dictionary = {}
	for name in names:
		var popup := PopupMenu.new()
		popup.name = name
		bar.add_child(popup)
		original[name] = popup
	menu.set("file_menu", original["File"])
	menu.set("edit_menu", original["Edit"])
	menu.set("select_menu", original["Select"])
	menu.set("project_menu", original["Project"])
	menu.set("desktop_ui_menu", original["UI"])
	var edit := original["Edit"] as PopupMenu
	edit.add_item("Undo", Global.EditMenu.UNDO)
	edit.add_item("Redo", Global.EditMenu.REDO)
	edit.add_item("Undo History", Global.EditMenu.UNDO_HISTORY)
	edit.add_item("Copy", Global.EditMenu.COPY)
	edit.add_item("New Brush", Global.EditMenu.NEW_BRUSH)
	edit.add_item("Preferences", Global.EditMenu.PREFERENCES)
	edit.set_item_disabled(edit.get_item_index(Global.EditMenu.NEW_BRUSH), true)

	var was_collapsed := Global.collapse_main_menu
	Global.collapse_main_menu = true
	menu.handle_main_menu_collapse()
	var popup := button.get_popup()
	check_eq(popup.item_count, names.size() - 3, "main menu omits File, Select and Project")
	var visible_names: Array[String] = []
	for i in popup.item_count:
		visible_names.append(popup.get_item_text(i))
	check_true(not "File" in visible_names, "File entry is absent")
	check_true(not "Select" in visible_names, "Select entry is absent")
	check_true(not "Project" in visible_names, "Project entry is absent")
	check_true("Edit" in visible_names, "Edit entry remains")
	check_true("Help" in visible_names, "other sections remain")
	var compact := menu.get("_compact_edit_menu") as PopupMenu
	check_true(compact != null, "Edit menu has a compact view")
	if compact != null:
		check_eq(compact.item_count, 3, "only Undo and Redo are omitted")
		check_eq(compact.get_item_id(0), Global.EditMenu.UNDO_HISTORY, "Undo History stays")
		check_eq(compact.get_item_id(1), Global.EditMenu.COPY, "Copy stays")
		check_eq(compact.get_item_id(2), Global.EditMenu.NEW_BRUSH, "New Brush stays")
		check_true(compact.is_item_disabled(2), "item disabled state follows original")
		edit.set_item_disabled(edit.get_item_index(Global.EditMenu.NEW_BRUSH), false)
		menu.call("_sync_compact_edit_menu", compact)
		check_true(not compact.is_item_disabled(2), "compact state follows source updates")
	check_eq(edit.item_count, 6, "original Edit menu and shortcuts are intact")
	check_eq(original["File"].get_parent(), bar, "File menu stays live but offscreen")
	check_eq(edit.get_parent(), bar, "original Edit menu stays live but offscreen")
	check_eq(original["Select"].get_parent(), bar, "Select menu stays live for shortcuts")
	check_true(compact.get_item_index(Global.EditMenu.PREFERENCES) == -1, "Preferences is absent from compact Edit")

	menu.set_return_home_visible(true)
	var ui_button := menu.get("ui_layout_button") as MenuButton
	var settings := menu.get("settings_button") as MenuButton
	check_true(is_instance_valid(settings), "Settings button is created")
	check_true(is_instance_valid(ui_button), "existing UI button remains")
	if is_instance_valid(settings) and is_instance_valid(ui_button):
		check_eq(settings.get_index(), ui_button.get_index() + 1, "Settings is to the right of UI")
		var settings_popup := settings.get_popup()
		check_eq(settings_popup.item_count, 2, "Settings has Project and Preferences")
		check_eq(
			settings_popup.get_item_submenu_node(0),
			original["Project"],
			"Settings reuses the original Project menu and nested actions",
		)
		check_eq(
			settings_popup.get_item_id(1),
			Global.EditMenu.PREFERENCES,
			"Preferences uses existing Edit handler ID",
		)
		check_true(
			settings_popup.id_pressed.is_connected(Callable(menu, "edit_menu_id_pressed")),
			"Preferences uses the original dialog handler",
		)
		menu.set_return_home_visible(true)
		check_eq(settings_popup.item_count, 2, "reentry does not duplicate Settings items")
	menu.set_return_home_visible(false)
	check_eq(original["Project"].get_parent(), bar, "Project returns after leaving editor")
	check_true(not settings.visible, "Settings only appears in editor")

	Global.collapse_main_menu = false
	menu.handle_main_menu_collapse()
	check_eq(bar.get_child_count(), names.size(), "expanded menu restores original items")
	check_eq(bar.get_child(0), original["File"], "File order is preserved for desktop")
	check_eq(bar.get_child(1), edit, "Edit order is preserved for desktop")
	check_eq(bar.get_child(2), original["Select"], "Select returns in original desktop order")
	check_eq(bar.get_child(3), original["Project"], "Project menu restores desktop order")
	check_eq(button.get_popup().item_count, 0, "compact popup is removed on expansion")
	Global.collapse_main_menu = was_collapsed
	menu.free()


func test_quick_access_save_undo_redo_handlers_are_still_wired() -> void:
	var shortcuts := FileAccess.get_file_as_string(
		"res://src/UI/TopMenuContainer/quick_access_buttons.gd"
	)
	check_has(shortcuts, "Global.FileMenu.SAVE", "Save quick action remains functional")
	check_has(shortcuts, "Global.EditMenu.UNDO", "Undo button remains functional")
	check_has(shortcuts, "Global.EditMenu.REDO", "Redo button remains functional")
