extends "res://tests/test_base.gd"

const TopMenuScript := preload("res://src/UI/TopMenuContainer/TopMenuContainer.gd")
const PENCIL_SCENE := preload("res://src/Tools/DesignTools/Pencil.tscn")


func test_compact_topbar_exposes_full_effects_view_window_help_and_only_edit_in_main_menu() -> void:
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
	for name in ["File", "Edit", "Select", "Project", "UI", "Effects", "View", "Window", "Help"]:
		var field := "desktop_ui_menu" if name == "UI" else name.to_lower() + "_menu"
		menu.set(field, original[name])

	var edit := original["Edit"] as PopupMenu
	edit.add_item("Undo", Global.EditMenu.UNDO)
	edit.add_item("Redo", Global.EditMenu.REDO)
	edit.add_item("Undo History", Global.EditMenu.UNDO_HISTORY)
	edit.add_item("Copy", Global.EditMenu.COPY)
	edit.add_item("Preferences", Global.EditMenu.PREFERENCES)
	var view := original["View"] as PopupMenu
	view.add_check_item("Show Grid", Global.ViewMenu.SHOW_GRID)
	view.add_item("Center Canvas", Global.ViewMenu.CENTER_CANVAS)
	view.set_item_checked(0, true)
	var effects := original["Effects"] as PopupMenu
	effects.add_item("Effect", 3)
	var window := original["Window"] as PopupMenu
	window.add_check_item("Panels", 7)
	var help := original["Help"] as PopupMenu
	help.add_item("About", 9)

	var was_collapsed := Global.collapse_main_menu
	Global.collapse_main_menu = true
	menu.handle_main_menu_collapse()
	check_true(button.visible, "Main Menu remains visible")
	check_true(bar.visible, "top-level menu bar stays visible in compact mode")
	check_eq(button.get_popup().item_count, 1, "Main Menu only keeps Edit")
	check_eq(button.get_popup().get_item_text(0), "Edit", "Edit stays in Main Menu")

	for index in bar.get_menu_count():
		var original_popup := bar.get_menu_popup(index)
		var must_show := original_popup in [effects, view, window, help]
		check_eq(
			bar.is_menu_hidden(index),
			not must_show,
			"%s top-level visibility matches the editor layout" % original_popup.name
		)
	for popup in [effects, view, window, help]:
		check_eq(popup.get_parent(), bar, "full source menu remains in the MenuBar")
	check_true(view.is_item_checked(0), "View keeps its live check state")
	check_eq(view.item_count, 2, "View has all its original commands")

	var compact := menu.get("_compact_edit_menu") as PopupMenu
	check_true(is_instance_valid(compact), "compact Edit menu exists")
	if is_instance_valid(compact):
		check_eq(compact.item_count, 1, "compact Edit hides undo and preferences")
		check_eq(compact.get_item_id(0), Global.EditMenu.COPY, "Copy stays in compact Edit")
		check_eq(compact.get_item_index(Global.EditMenu.NEW_BRUSH), -1, "New Brush moved")

	menu.set_return_home_visible(true)
	var ui_button := menu.get("ui_layout_button") as MenuButton
	var settings := menu.get("settings_button") as MenuButton
	check_true(is_instance_valid(settings), "Settings button is created")
	check_true(is_instance_valid(ui_button), "standalone UI button exists")
	if is_instance_valid(settings) and is_instance_valid(ui_button):
		check_eq(home.get_index(), button.get_index() + 1, "Projects follows Main Menu")
		check_eq(ui_button.get_index(), home.get_index() + 1, "UI follows Projects")
		check_eq(settings.get_index(), ui_button.get_index() + 1, "Settings follows UI")
		check_eq(bar.get_index(), settings.get_index() + 1, "four menus follow Settings")
		var settings_popup := settings.get_popup()
		check_eq(settings_popup.item_count, 2, "Settings retains Project and Preferences")
		check_eq(
			settings_popup.get_item_submenu_node(0),
			original["Project"],
			"Settings reuses Project rather than copying it"
		)
		check_eq(
			settings_popup.get_item_id(1),
			Global.EditMenu.PREFERENCES,
			"Settings retains stable Preferences command ID"
		)
	menu.set_return_home_visible(false)
	check_eq(original["Project"].get_parent(), bar, "Project returns to source bar")

	Global.collapse_main_menu = false
	menu.handle_main_menu_collapse()
	check_true(not button.visible, "Main Menu hides in desktop mode")
	check_eq(bar.get_menu_count(), names.size(), "desktop restores all original menus")
	for index in bar.get_menu_count():
		check_true(not bar.is_menu_hidden(index), "desktop menus are not hidden")
	check_eq(bar.get_child(0), original["File"], "desktop File order is unchanged")
	check_eq(bar.get_child(1), edit, "desktop Edit order is unchanged")
	check_eq(button.get_popup().item_count, 0, "compact Edit submenu is removed")

	Global.collapse_main_menu = was_collapsed
	menu.free()


func test_new_brush_removed_from_edit_but_keeps_command_id_and_pencil_entry() -> void:
	var menu_source := FileAccess.get_file_as_string(
		"res://src/UI/TopMenuContainer/TopMenuContainer.gd"
	)
	var pencil_source := FileAccess.get_file_as_string("res://src/Tools/DesignTools/Pencil.gd")
	var pencil := PENCIL_SCENE.instantiate()
	var new_brush := pencil.get_node_or_null(^"Brush/NewBrush") as Button
	check_true(is_instance_valid(new_brush), "Pencil has New Brush near its brush controls")
	if is_instance_valid(new_brush):
		check_eq(new_brush.get_parent().name, &"Brush", "New Brush is grouped with brush")
		check_true(new_brush.disabled, "New Brush requires a selection")
	check_has(menu_source, 'if item != "New Brush":', "the Edit menu omits New Brush")
	check_has(
		menu_source, "i += 1", "the original Edit command ID sequence is kept for all other items"
	)
	check_has(pencil_source, "Global.canvas.selection.new_brush()", "Pencil reuses brush action")
	check_has(
		pencil_source,
		"project.selection_changed.connect(_sync_new_brush_button)",
		"Pencil updates button when the selection changes"
	)
	pencil.free()


func test_quick_access_save_undo_redo_handlers_are_still_wired() -> void:
	var shortcuts := FileAccess.get_file_as_string(
		"res://src/UI/TopMenuContainer/quick_access_buttons.gd"
	)
	check_has(shortcuts, "Global.FileMenu.SAVE", "Save quick action remains functional")
	check_has(shortcuts, "Global.EditMenu.UNDO", "Undo button remains functional")
	check_has(shortcuts, "Global.EditMenu.REDO", "Redo button remains functional")
