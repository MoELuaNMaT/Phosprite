extends "res://tests/test_base.gd"


const TopMenuScript := preload("res://src/UI/TopMenuContainer/TopMenuContainer.gd")


func test_compact_main_menu_hides_file_undo_redo_without_removing_commands() -> void:
	var menu := TopMenuScript.new()
	var button := MenuButton.new()
	var bar := MenuBar.new()
	menu.add_child(button)
	menu.add_child(bar)
	menu.set("main_menu_button", button)
	menu.set("menu_bar", bar)
	var names := ["File", "Edit", "Select", "Project", "UI", "Effects", "View", "Window", "Help"]
	var original: Dictionary = {}
	for name in names:
		var popup := PopupMenu.new()
		popup.name = name
		bar.add_child(popup)
		original[name] = popup
	menu.set("file_menu", original["File"])
	menu.set("edit_menu", original["Edit"])
	var edit := original["Edit"] as PopupMenu
	edit.add_item("Undo", Global.EditMenu.UNDO)
	edit.add_item("Redo", Global.EditMenu.REDO)
	edit.add_item("Undo History", Global.EditMenu.UNDO_HISTORY)
	edit.add_item("Copy", Global.EditMenu.COPY)
	edit.add_item("New Brush", Global.EditMenu.NEW_BRUSH)
	edit.set_item_disabled(edit.get_item_index(Global.EditMenu.NEW_BRUSH), true)

	var was_collapsed := Global.collapse_main_menu
	Global.collapse_main_menu = true
	menu.handle_main_menu_collapse()
	var popup := button.get_popup()
	check_eq(popup.item_count, names.size() - 1, "main menu omits File")
	var visible_names: Array[String] = []
	for i in popup.item_count:
		visible_names.append(popup.get_item_text(i))
	check_true(not "File" in visible_names, "File entry is absent")
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
	check_eq(edit.item_count, 5, "original Edit menu and shortcuts are intact")
	check_eq(original["File"].get_parent(), bar, "File menu stays live but offscreen")
	check_eq(edit.get_parent(), bar, "original Edit menu stays live but offscreen")

	Global.collapse_main_menu = false
	menu.handle_main_menu_collapse()
	check_eq(bar.get_child_count(), names.size(), "expanded menu restores original items")
	check_eq(bar.get_child(0), original["File"], "File order is preserved for desktop")
	check_eq(bar.get_child(1), edit, "Edit order is preserved for desktop")
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
