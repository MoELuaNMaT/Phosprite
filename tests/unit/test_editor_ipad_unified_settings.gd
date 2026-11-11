extends "res://tests/test_base.gd"

const TOP_MENU := preload("res://src/UI/TopMenuContainer/TopMenuContainer.gd")


func test_ipad_effects_menu_matches_project_and_settings_vertical_alignment() -> void:
	var menu := TOP_MENU.new()
	var bar := MenuBar.new()
	menu.set("menu_bar", bar)
	menu._set_effects_menu_vertical_alignment(true)
	check_eq(
		bar.size_flags_vertical,
		Control.SIZE_SHRINK_CENTER,
		"iPad Effects menu is centered in the same topbar row as Projects and Settings",
	)
	menu._set_effects_menu_vertical_alignment(false)
	check_eq(
		bar.size_flags_vertical,
		Control.SIZE_FILL,
		"non-iPad layouts preserve the original MenuBar fill behavior",
	)
	bar.free()
	menu.free()


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


func test_ipad_workspace_panel_checkmarks_follow_actions_immediately() -> void:
	var menu := TOP_MENU.new()
	var original := PopupMenu.new()
	var mirror := PopupMenu.new()
	original.add_check_item("Preview", 0)
	original.add_check_item("Timeline", 1)
	original.set_item_checked(1, true)
	menu.set("panels_submenu", original)
	menu.set("_ipad_panels_actions", mirror)
	menu.set("_ipad_settings_populated", true)
	menu._copy_ipad_source_menu(original, mirror)
	# Represent the source Window bridge, which accepts a click and updates
	# the authoritative menu check state before the iPad mirror is updated.
	original.id_pressed.connect(
		func(id: int) -> void:
			var i := original.get_item_index(id)
			original.set_item_checked(i, not original.is_item_checked(i))
	)
	menu._forward_ipad_panels(0)
	check_true(mirror.is_item_checked(0), "opening Preview checks the menu immediately")
	menu._forward_ipad_panels(0)
	check_true(not mirror.is_item_checked(0), "closing Preview clears the check immediately")
	check_true(mirror.is_item_checked(1), "unrelated Timeline checkmark stays enabled")
	# A different Workspace entry point can change visibility without a menu tap.
	original.set_item_checked(1, false)
	menu._on_ipad_panel_visibility_changed(&"timeline", false)
	check_true(not mirror.is_item_checked(1), "external Workspace change updates the mirror")
	original.set_item_checked(1, true)
	menu._sync_ipad_panel_checkmarks()
	check_true(mirror.is_item_checked(1), "opening the submenu reads the latest source")
	original.free()
	mirror.free()
	menu.free()


func test_ipad_workspace_panel_signal_is_wired_after_bridge_and_profiles_refresh() -> void:
	var ui_source := FileAccess.get_file_as_string("res://src/UI/UI.gd")
	check_has(
		ui_source,
		'Callable(menu_root, "_on_ipad_panel_visibility_changed")',
		"source Workspace signals update the visible iPad menu",
	)
	check_has(
		ui_source,
		'top.call_deferred(&"_sync_ipad_settings_menu")',
		"UI layout switches refresh the panel menu checkmarks",
	)
	var top_source := FileAccess.get_file_as_string(
		"res://src/UI/TopMenuContainer/TopMenuContainer.gd"
	)
	check_has(
		top_source,
		"_ipad_panels_actions.about_to_popup.connect(_sync_ipad_panel_checkmarks)",
		"opening Panels refreshes checks without rebuilding an open submenu",
	)


func test_zen_mode_removed_without_shifting_fullscreen_command() -> void:
	var top_source := FileAccess.get_file_as_string(
		"res://src/UI/TopMenuContainer/TopMenuContainer.gd"
	)
	var bridge_source := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceWindowMenuBridge.gd"
	)
	var migration_source := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceEditorMigration.gd"
	)
	var global_source := FileAccess.get_file_as_string("res://src/Autoload/Global.gd")
	check_true(
		not top_source.contains('tr("Zen Mode")'),
		"iPad Workspace submenu does not expose Zen Mode"
	)
	check_true(
		not top_source.contains('"Zen Mode":'),
		"desktop Window menu does not expose Zen Mode"
	)
	check_true(not top_source.contains("_toggle_zen_mode"), "legacy Zen Mode handler is removed")
	check_true(
		not bridge_source.contains("set_zen_mode"),
		"live Workspace bridge has no Zen Mode action"
	)
	check_true(
		not migration_source.contains("func set_zen_mode"),
		"Workspace no longer hides the dock host through Zen Mode"
	)
	check_true(
		not global_source.contains('&"zen_mode":'),
		"removed action has no keyboard shortcut"
	)
	check_eq(Global.WindowMenu.FULLSCREEN_MODE, 5, "Fullscreen keeps its stable command ID")
	check_has(
		top_source, "Global.WindowMenu.FULLSCREEN_MODE: [",
		"Window menu constructs the fullscreen entry by its explicit ID"
	)
	check_has(
		top_source, "window_menu.get_item_index(Global.WindowMenu.FULLSCREEN_MODE)",
		"fullscreen checkmark uses the actual menu index after removing Zen Mode"
	)
	check_has(
		top_source, "_setup_panels_submenu(item)",
		"normal panel visibility menu remains available"
	)
