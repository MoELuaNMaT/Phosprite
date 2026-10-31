extends "res://tests/test_base.gd"

const TOP_MENU := preload("res://src/UI/TopMenuContainer/TopMenuContainer.gd")


func test_ipad_topbar_keeps_only_project_effects_and_settings() -> void:
	var source := FileAccess.get_file_as_string("res://src/UI/TopMenuContainer/TopMenuContainer.gd")
	check_has(source, 'OS.get_name() == "iOS"', "iPad-only layout gate is retained")
	check_has(source, "main_menu_button.visible = false", "iPad Main Menu is hidden")
	check_has(source, "ui_layout_button.visible = false", "iPad UI menu uses Settings")
	check_has(
		source,
		"menu_bar.set_menu_hidden(index, menu_bar.get_menu_popup(index) != effects_menu)",
		"only Effects remains visible from the original MenuBar on iPad",
	)
	check_has(source, 'tr("More Settings…")', "advanced settings remain reachable")
	check_has(
		source,
		'popup.add_item(tr("More Settings…"), Global.EditMenu.PREFERENCES)',
		"Preferences ID is preserved"
	)
	check_has(
		source,
		"edit_actions.id_pressed.connect(edit_menu_id_pressed)",
		"Edit commands remain reachable"
	)


func test_ipad_workspace_quick_menu_forwards_to_live_source_commands() -> void:
	var source := FileAccess.get_file_as_string("res://src/UI/TopMenuContainer/TopMenuContainer.gd")
	for action in [
		"ui_menu.id_pressed.emit(id)",
		"panels_submenu.id_pressed.emit(id)",
		"layouts_submenu.id_pressed.emit(id)",
		"snap_to_submenu.id_pressed.emit(id)",
		"tile_mode_submenu.id_pressed.emit(id)",
		"window_menu.id_pressed.emit(id)",
	]:
		check_has(source, action, "Settings forwards to original command handlers")


func test_ipad_mirrored_popup_tracks_checks_and_disabled_items() -> void:
	var menu := TOP_MENU.new()
	var source := PopupMenu.new()
	var mirrored := PopupMenu.new()
	source.add_check_item("Enabled", 7)
	source.set_item_checked(0, true)
	source.add_radio_check_item("Profile", 8)
	source.set_item_disabled(1, true)
	source.add_separator()
	source.add_item("Action", 11)
	menu._copy_ipad_source_menu(source, mirrored)
	check_eq(mirrored.item_count, source.item_count, "no source commands are dropped")
	check_eq(mirrored.get_item_id(0), 7, "check item keeps command ID")
	check_true(mirrored.is_item_checked(0), "check state is copied")
	check_true(mirrored.is_item_disabled(1), "disabled state is copied")
	check_true(mirrored.is_item_separator(2), "separator is preserved")
	check_eq(mirrored.get_item_id(3), 11, "action ID is preserved")
	mirrored.free()
	source.free()
	menu.free()


func test_ipad_preferences_organize_categories_without_reparenting_settings() -> void:
	var source := FileAccess.get_file_as_string("res://src/Preferences/PreferencesDialog.gd")
	for section in [
		"CurrentProjectSettings",
		"Canvas & Display",
		"Workspace & Panels",
		"Tools & Input",
		"Animation & Layers",
		"Interface & Appearance",
		"Files & Backup",
		"Advanced & System",
		"Help & About",
	]:
		check_has(source, section, "iPad category is implemented")
	check_has(source, '["Tools", "Selection", "Shortcuts"]', "mouse cursor settings are excluded")
	check_has(source, "_hide_ipad_desktop_only_controls()", "desktop-only controls are filtered")
	check_has(source, "pref.node_path", "original preference save paths remain stable")
