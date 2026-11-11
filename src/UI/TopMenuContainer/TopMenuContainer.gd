extends Panel

signal return_home_requested

enum ColorModes { RGBA, INDEXED }

const DOCS_URL := "https://github.com/MoELuaNMaT/Phosprite#readme"
const ISSUES_URL := "https://github.com/MoELuaNMaT/Phosprite/issues"
const SUPPORT_URL := "https://www.patreon.com/OramaInteractive"
# gdlint: ignore=max-line-length
const CHANGELOG_URL := "https://github.com/MoELuaNMaT/Phosprite/releases"
const EXTERNAL_LINK_ICON := preload("res://assets/graphics/misc/external_link.svg")
const PIXELORAMA_ICON := preload("res://assets/graphics/icons/icon_16x16.png")
const HEART_ICON := preload("res://assets/graphics/misc/heart.svg")
const PROJECTS_TOPBAR_ICON := preload("res://assets/graphics/ui/tabler/folders.svg")
const SETTINGS_TOPBAR_ICON := preload("res://assets/graphics/ui/tabler/settings.svg")
const EFFECTS_TOPBAR_ICON := preload("res://assets/graphics/ui/tabler/wand.svg")
const TOPBAR_ICON_BUTTON_SIZE := Vector2(32, 32)

var recent_projects := []
var selected_layout := 0
var can_save := true
var tile_mode_submenu := PopupMenu.new()
var selection_modify_submenu := PopupMenu.new()
var color_mode_submenu := PopupMenu.new()
var snap_to_submenu := PopupMenu.new()
var panels_submenu := PopupMenu.new()
var layouts_submenu := PopupMenu.new()
var recent_projects_submenu := PopupMenu.new()
var effects_transform_submenu := PopupMenu.new()
var effects_color_submenu := PopupMenu.new()
var effects_procedural_submenu := PopupMenu.new()
var effects_blur_submenu := PopupMenu.new()
var effects_loaded_submenu: PopupMenu
var ui_layout_button: MenuButton
var settings_button: MenuButton
var ui_menu: PopupMenu

# Dialogs
var new_image_dialog := Dialog.new("res://src/UI/Dialogs/CreateNewImage.tscn")
var project_properties_dialog := Dialog.new("res://src/UI/Dialogs/ProjectProperties.tscn")
var preferences_dialog := Dialog.new("res://src/Preferences/PreferencesDialog.tscn")
var modify_selection := Dialog.new("res://src/UI/Dialogs/ModifySelection.tscn")
var offset_image_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/OffsetScaleImage.tscn")
var scale_image_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/ScaleImage.tscn")
var resize_canvas_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/ResizeCanvas.tscn")
var mirror_image_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/FlipImageDialog.tscn")
var rotate_image_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/RotateImage.tscn")
var isometric_image_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/flat_to_isometric.tscn")
var invert_colors_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/InvertColorsDialog.tscn")
var desaturate_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/DesaturateDialog.tscn")
var outline_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/OutlineDialog.tscn")
var drop_shadow_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/DropShadowDialog.tscn")
var hsv_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/HSVDialog.tscn")
var adjust_brightness_saturation_dialog := Dialog.new(
	"res://src/UI/Dialogs/ImageEffects/BrightnessContrastDialog.tscn"
)
var color_curves_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/ColorCurvesDialog.tscn")
var gaussian_blur_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/GaussianBlur.tscn")
var gradient_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/GradientDialog.tscn")
var gradient_map_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/GradientMapDialog.tscn")
var palettize_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/PalettizeDialog.tscn")
var pixelize_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/PixelizeDialog.tscn")
var posterize_dialog := Dialog.new("res://src/UI/Dialogs/ImageEffects/Posterize.tscn")
var loaded_effect_dialogs: Array[Dialog] = []
var last_applied_effect: Window
var window_opacity_dialog := Dialog.new("res://src/UI/Dialogs/WindowOpacityDialog.tscn")
var about_dialog := Dialog.new("res://src/UI/Dialogs/AboutDialog.tscn")
var backup_dialog := Dialog.new("res://src/UI/Dialogs/BackupRestoreDialog.tscn")
var _effects_icon_button: Button
var _compact_edit_menu: PopupMenu
var _compact_view_menu: PopupMenu
var _ipad_settings_populated := false
var _ipad_project_actions: PopupMenu
var _ipad_canvas_actions: PopupMenu
var _ipad_workspace_actions: PopupMenu
var _ipad_ui_actions: PopupMenu
var _ipad_panels_actions: PopupMenu
var _ipad_layouts_actions: PopupMenu
var _ipad_snap_actions: PopupMenu
var _ipad_tile_actions: PopupMenu

@onready var main := $"../.." as Control
@onready var main_ui := main.find_child("DockableContainer") as DockableContainer
@onready var ui_elements := main_ui.get_children()
@onready var main_menu_button: MenuButton = $MarginContainer/HBoxContainer/MainMenuButton
@onready var menu_bar: MenuBar = $MarginContainer/HBoxContainer/MenuBar
@onready var file_menu := $MarginContainer/HBoxContainer/MenuBar/File as PopupMenu
@onready var edit_menu := $MarginContainer/HBoxContainer/MenuBar/Edit as PopupMenu
@onready var select_menu := $MarginContainer/HBoxContainer/MenuBar/Select as PopupMenu
@onready var project_menu := $MarginContainer/HBoxContainer/MenuBar/Project as PopupMenu
@onready var desktop_ui_menu := $MarginContainer/HBoxContainer/MenuBar/UI as PopupMenu
@onready var effects_menu := $MarginContainer/HBoxContainer/MenuBar/Effects as PopupMenu
@onready var view_menu := $MarginContainer/HBoxContainer/MenuBar/View as PopupMenu
@onready var window_menu := $MarginContainer/HBoxContainer/MenuBar/Window as PopupMenu
@onready var help_menu := $MarginContainer/HBoxContainer/MenuBar/Help as PopupMenu
@onready var undo_history_dialog := $UndoHistoryDialog as AcceptDialog
@onready var add_layout_confirmation := $AddLayoutConfirmation as ConfirmationDialog
@onready var delete_layout_confirmation := $DeleteLayoutConfirmation as ConfirmationDialog
@onready var layout_name_line_edit := %LayoutName as LineEdit
@onready var layout_from_option_button := %LayoutFrom as OptionButton
@onready var return_home_button := %ReturnHome as Button


class Dialog:
	## This class is used to help with lazy loading dialog scenes in order to
	## reduce Pixelorama's initial loading time, by only loading each dialog
	## scene when it's actually needed.
	var scene_path := ""
	var node: Window

	func _init(_scene_path: String) -> void:
		scene_path = _scene_path

	func popup(dialog_size := Vector2i.ZERO) -> void:
		if not is_instance_valid(node):
			instantiate_scene()
		node.popup_centered_clamped(dialog_size)
		var is_file_dialog := node is FileDialog
		Global.dialog_open(true, is_file_dialog)

	func instantiate_scene() -> void:
		var scene := load(scene_path)
		if not scene is PackedScene:
			return
		node = scene.instantiate()
		if is_instance_valid(node):
			Global.control.get_node("Dialogs").add_child(node)


func _ready() -> void:
	ui_menu = desktop_ui_menu
	handle_main_menu_collapse()
	main.save_file_dialog_opened.connect(func(opened: bool): can_save = not opened)
	Global.collapse_main_menu_changed.connect(handle_main_menu_collapse)
	Global.project_about_to_switch.connect(_on_project_about_to_switch)
	Global.project_switched.connect(_on_project_switched)
	OpenSave.shader_copied.connect(_load_shader_file)
	_setup_file_menu()
	_setup_edit_menu()
	_setup_view_menu()
	_setup_window_menu()
	_setup_project_menu()
	_setup_effects_menu()
	_setup_select_menu()
	_setup_help_menu()
	# Fill the copy layout from option button with the default layouts
	for layout in Global.default_layouts:
		layout_from_option_button.add_item(layout.resource_path.get_basename().get_file())


func set_return_home_visible(should_show: bool) -> void:
	return_home_button.visible = should_show
	if not should_show:
		# Restore the normal MenuBar layout when leaving the iPad editor.
		_apply_ipad_topbar_visibility()
		if is_instance_valid(ui_layout_button):
			ui_layout_button.visible = false
		if is_instance_valid(settings_button):
			settings_button.visible = false
		_detach_settings_project_menu()
		ui_menu = desktop_ui_menu
		handle_main_menu_collapse()
		return
	_ensure_ui_layout_button()
	_ensure_settings_button()
	if not is_instance_valid(ui_layout_button) or not is_instance_valid(settings_button):
		return
	ui_menu = ui_layout_button.get_popup()
	settings_button.visible = true
	if OS.get_name() == "iOS":
		ui_layout_button.visible = false
		_setup_ipad_settings_menu()
	else:
		ui_layout_button.visible = true
		_attach_settings_project_menu()
	var row := return_home_button.get_parent()
	if row == null:
		return
	_apply_ipad_topbar_visibility()
	_arrange_topbar_menu_buttons()


func _ensure_ui_layout_button() -> void:
	if is_instance_valid(ui_layout_button):
		return
	var row := return_home_button.get_parent()
	if row == null:
		return
	ui_layout_button = MenuButton.new()
	ui_layout_button.name = &"UILayoutButton"
	ui_layout_button.focus_mode = Control.FOCUS_ALL
	ui_layout_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ui_layout_button.text = "UI"
	row.add_child(ui_layout_button)
	ui_menu = ui_layout_button.get_popup()


## Editor-only settings live alongside the separate Projects and UI buttons.
## Reparent the actual Project popup rather than copying its commands, so
## Color Mode, project-specific disabled states and keyboard shortcuts stay live.
func _ensure_settings_button() -> void:
	if is_instance_valid(settings_button):
		return
	var row := return_home_button.get_parent()
	if row == null:
		return
	settings_button = MenuButton.new()
	settings_button.name = &"EditorSettingsButton"
	settings_button.focus_mode = Control.FOCUS_ALL
	settings_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	settings_button.text = tr("Settings")
	row.add_child(settings_button)
	var popup := settings_button.get_popup()
	popup.id_pressed.connect(edit_menu_id_pressed)


func _attach_settings_project_menu() -> void:
	if not is_instance_valid(settings_button) or not is_instance_valid(project_menu):
		return
	var popup := settings_button.get_popup()
	if project_menu.get_parent() == popup:
		return
	var parent := project_menu.get_parent()
	if parent is PopupMenu:
		var old_popup := parent as PopupMenu
		for index in range(old_popup.item_count - 1, -1, -1):
			if old_popup.get_item_submenu_node(index) == project_menu:
				old_popup.remove_item(index)
	if parent != null:
		parent.remove_child(project_menu)
	popup.add_submenu_node_item(tr("Project"), project_menu)
	popup.add_item(tr("Preferences"), Global.EditMenu.PREFERENCES)


## Keep original MenuBar nodes and command IDs alive for shortcuts and extensions.
## Only the editor's iPad presentation is compacted; desktop menus are unchanged.
func _is_ipad_editor() -> bool:
	return OS.get_name() == "iOS" and return_home_button.visible


func _apply_ipad_topbar_visibility() -> void:
	var ipad_editor := _is_ipad_editor()
	_set_effects_menu_vertical_alignment(ipad_editor)
	_set_ipad_topbar_icons(ipad_editor)
	menu_bar.visible = not ipad_editor
	if not ipad_editor:
		return
	main_menu_button.visible = false
	if is_instance_valid(ui_layout_button):
		ui_layout_button.visible = false
	for index in menu_bar.get_menu_count():
		menu_bar.set_menu_hidden(index, menu_bar.get_menu_popup(index) != effects_menu)


## MenuBar draws its menu text at the top of its own bounds. Button and
## MenuButton center theirs. Center the compact Effects MenuBar vertically
## without replacing the original PopupMenu, shortcuts or action handlers.
func _set_effects_menu_vertical_alignment(ipad_editor: bool) -> void:
	if not is_instance_valid(menu_bar):
		return
	menu_bar.size_flags_vertical = (
		Control.SIZE_SHRINK_CENTER if ipad_editor else Control.SIZE_FILL
	)


## iPad uses three real 32 px buttons. A separate Effects button opens the
## original PopupMenu, so its commands and shortcut handlers stay unchanged.
## Never use spaces as a MenuBar icon placeholder: font metrics change its width.
func _set_ipad_topbar_icons(ipad_editor: bool) -> void:
	if not is_instance_valid(menu_bar) or not is_instance_valid(return_home_button):
		return
	var row := return_home_button.get_parent() as HBoxContainer
	if row != null:
		if ipad_editor:
			row.add_theme_constant_override(&"separation", 4)
		else:
			row.remove_theme_constant_override(&"separation")
	return_home_button.text = "" if ipad_editor else tr("Projects")
	return_home_button.icon = PROJECTS_TOPBAR_ICON if ipad_editor else null
	return_home_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return_home_button.flat = ipad_editor
	return_home_button.custom_minimum_size = (
		TOPBAR_ICON_BUTTON_SIZE if ipad_editor else Vector2.ZERO
	)
	if is_instance_valid(settings_button):
		settings_button.text = "" if ipad_editor else tr("Settings")
		settings_button.icon = SETTINGS_TOPBAR_ICON if ipad_editor else null
		settings_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		settings_button.flat = ipad_editor
		settings_button.tooltip_text = tr("Settings") if ipad_editor else ""
		settings_button.custom_minimum_size = (
			TOPBAR_ICON_BUTTON_SIZE if ipad_editor else Vector2.ZERO
		)
	menu_bar.custom_minimum_size = Vector2.ZERO
	if ipad_editor:
		_ensure_effects_icon_button()
	if is_instance_valid(_effects_icon_button):
		_effects_icon_button.visible = ipad_editor
		_effects_icon_button.tooltip_text = tr("Effects")


func _ensure_effects_icon_button() -> void:
	if is_instance_valid(_effects_icon_button):
		return
	var row := return_home_button.get_parent() as HBoxContainer
	if row == null:
		return
	_effects_icon_button = Button.new()
	_effects_icon_button.name = &"EffectsIconButton"
	_effects_icon_button.custom_minimum_size = TOPBAR_ICON_BUTTON_SIZE
	_effects_icon_button.focus_mode = Control.FOCUS_NONE
	_effects_icon_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_effects_icon_button.flat = true
	_effects_icon_button.icon = EFFECTS_TOPBAR_ICON
	_effects_icon_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effects_icon_button.tooltip_text = tr("Effects")
	_effects_icon_button.pressed.connect(_on_effects_icon_button_pressed)
	row.add_child(_effects_icon_button)


func _on_effects_icon_button_pressed() -> void:
	if not is_instance_valid(_effects_icon_button) or not is_instance_valid(effects_menu):
		return
	var popup_position := _effects_icon_button.global_position
	popup_position.y += _effects_icon_button.size.y
	effects_menu.popup_on_parent(Rect2i(Vector2i(popup_position), Vector2i.ONE))


func _new_ipad_submenu(parent: PopupMenu, title: String) -> PopupMenu:
	var submenu := PopupMenu.new()
	submenu.name = StringName("iPadSettings%d" % parent.get_child_count())
	submenu.hide_on_checkable_item_selection = false
	parent.add_child(submenu)
	parent.add_submenu_node_item(title, submenu)
	return submenu


func _setup_ipad_settings_menu() -> void:
	if _ipad_settings_populated:
		return
	var popup := settings_button.get_popup()
	_ipad_project_actions = _new_ipad_submenu(popup, tr("Project Operations"))
	for entry in [
		[Global.ProjectMenu.PROJECT_PROPERTIES, "Project Properties"],
		[Global.ProjectMenu.RESIZE_CANVAS, "Resize Canvas"],
		[Global.ProjectMenu.SCALE_IMAGE, "Scale Image"],
		[Global.ProjectMenu.CROP_TO_SELECTION, "Crop to Selection"],
		[Global.ProjectMenu.CROP_TO_CONTENT, "Crop to Content"],
	]:
		_ipad_project_actions.add_item(tr(entry[1]), entry[0])
	_ipad_project_actions.id_pressed.connect(project_menu_id_pressed)

	_ipad_canvas_actions = _new_ipad_submenu(popup, tr("Canvas Aids"))
	_ipad_canvas_actions.add_check_item(tr("Show Rulers"), Global.ViewMenu.SHOW_RULERS)
	_ipad_canvas_actions.add_check_item(tr("Show Guides"), Global.ViewMenu.SHOW_GUIDES)
	_ipad_canvas_actions.id_pressed.connect(view_menu_id_pressed)
	_ipad_snap_actions = _new_ipad_submenu(_ipad_canvas_actions, tr("Snap To"))
	_ipad_tile_actions = _new_ipad_submenu(_ipad_canvas_actions, tr("Tile Mode"))
	_ipad_snap_actions.id_pressed.connect(_forward_ipad_snap)
	_ipad_tile_actions.id_pressed.connect(_forward_ipad_tile)

	_ipad_workspace_actions = _new_ipad_submenu(popup, tr("Workspace"))
	_ipad_ui_actions = _new_ipad_submenu(_ipad_workspace_actions, tr("UI Layout"))
	_ipad_panels_actions = _new_ipad_submenu(_ipad_workspace_actions, tr("Panels"))
	_ipad_layouts_actions = _new_ipad_submenu(_ipad_workspace_actions, tr("Layout Presets"))
	_ipad_ui_actions.id_pressed.connect(_forward_ipad_ui)
	_ipad_panels_actions.id_pressed.connect(_forward_ipad_panels)
	# A submenu can remain open after a check action. Refresh its checkmarks
	# without rebuilding the active PopupMenu or moving the touch target.
	_ipad_panels_actions.about_to_popup.connect(_sync_ipad_panel_checkmarks)
	_ipad_layouts_actions.id_pressed.connect(_forward_ipad_layouts)

	var edit_actions := _new_ipad_submenu(popup, tr("Edit Actions"))
	for entry in [
		[Global.EditMenu.COPY, "Copy"],
		[Global.EditMenu.CUT, "Cut"],
		[Global.EditMenu.PASTE, "Paste"],
		[Global.EditMenu.PASTE_IN_PLACE, "Paste in Place"],
		[Global.EditMenu.PASTE_FROM_CLIPBOARD, "Paste from Clipboard"],
		[Global.EditMenu.DELETE, "Delete"],
	]:
		edit_actions.add_item(tr(entry[1]), entry[0])
	edit_actions.id_pressed.connect(edit_menu_id_pressed)
	popup.add_separator()
	popup.add_item(tr("More Settings…"), Global.EditMenu.PREFERENCES)
	popup.about_to_popup.connect(_sync_ipad_settings_menu)
	_ipad_workspace_actions.about_to_popup.connect(_sync_ipad_settings_menu)
	_ipad_canvas_actions.about_to_popup.connect(_sync_ipad_settings_menu)
	_ipad_settings_populated = true
	_sync_ipad_settings_menu()


func _sync_ipad_settings_menu() -> void:
	if not _ipad_settings_populated:
		return
	for item_id in [Global.ViewMenu.SHOW_RULERS, Global.ViewMenu.SHOW_GUIDES]:
		var index := _ipad_canvas_actions.get_item_index(item_id)
		_ipad_canvas_actions.set_item_checked(
			index, view_menu.is_item_checked(view_menu.get_item_index(item_id))
		)
	var crop_index := _ipad_project_actions.get_item_index(Global.ProjectMenu.CROP_TO_SELECTION)
	_ipad_project_actions.set_item_disabled(
		crop_index,
		project_menu.is_item_disabled(
			project_menu.get_item_index(Global.ProjectMenu.CROP_TO_SELECTION)
		)
	)
	_copy_ipad_source_menu(ui_menu, _ipad_ui_actions)
	_copy_ipad_source_menu(panels_submenu, _ipad_panels_actions)
	_sync_ipad_panel_checkmarks()
	_copy_ipad_source_menu(layouts_submenu, _ipad_layouts_actions)
	_copy_ipad_source_menu(snap_to_submenu, _ipad_snap_actions)
	_copy_ipad_source_menu(tile_mode_submenu, _ipad_tile_actions)


func _copy_ipad_source_menu(source: PopupMenu, destination: PopupMenu) -> void:
	if source == null or destination == null:
		return
	destination.clear()
	for i in source.item_count:
		var id := source.get_item_id(i)
		var title := source.get_item_text(i)
		if source.is_item_separator(i):
			destination.add_separator(title, id)
		elif source.is_item_radio_checkable(i):
			destination.add_radio_check_item(title, id)
		elif source.is_item_checkable(i):
			destination.add_check_item(title, id)
		else:
			destination.add_item(title, id)
		var target := destination.item_count - 1
		destination.set_item_checked(target, source.is_item_checked(i))
		destination.set_item_disabled(target, source.is_item_disabled(i))


## The original Window bridge owns actual panel visibility.
## The iPad submenu is only a visual mirror and must never own a second state.
func _sync_ipad_panel_checkmarks() -> void:
	if not _ipad_settings_populated or not is_instance_valid(_ipad_panels_actions):
		return
	for i in _ipad_panels_actions.item_count:
		if _ipad_panels_actions.is_item_separator(i):
			continue
		var original := panels_submenu.get_item_index(_ipad_panels_actions.get_item_id(i))
		if original < 0:
			continue
		_ipad_panels_actions.set_item_checked(i, panels_submenu.is_item_checked(original))
		_ipad_panels_actions.set_item_disabled(i, panels_submenu.is_item_disabled(original))


func _on_ipad_panel_visibility_changed(_module_id: StringName, _visible: bool) -> void:
	_sync_ipad_panel_checkmarks()


func _forward_ipad_ui(id: int) -> void:
	ui_menu.id_pressed.emit(id)


func _forward_ipad_panels(id: int) -> void:
	panels_submenu.id_pressed.emit(id)
	# id_pressed runs the bridge synchronously; reflect the confirmed result,
	# including rejected changes, before the user taps the checkbox again.
	_sync_ipad_panel_checkmarks()


func _forward_ipad_layouts(id: int) -> void:
	layouts_submenu.id_pressed.emit(id)


func _forward_ipad_snap(id: int) -> void:
	snap_to_submenu.id_pressed.emit(id)


func _forward_ipad_tile(id: int) -> void:
	tile_mode_submenu.id_pressed.emit(id)


func _detach_settings_project_menu() -> void:
	if not is_instance_valid(settings_button) or not is_instance_valid(project_menu):
		return
	var popup := settings_button.get_popup()
	if project_menu.get_parent() != popup:
		return
	for index in range(popup.item_count - 1, -1, -1):
		popup.remove_item(index)
	popup.remove_child(project_menu)
	menu_bar.add_child(project_menu)
	menu_bar.move_child(project_menu, mini(3, menu_bar.get_child_count() - 1))


func _on_return_home_pressed() -> void:
	return_home_requested.emit()


func _input(event: InputEvent) -> void:
	# Workaround for https://github.com/Orama-Interactive/Pixelorama/issues/1070
	if event is InputEventMouseButton and event.pressed:
		file_menu.activate_item_by_event(event)
		edit_menu.activate_item_by_event(event)
		select_menu.activate_item_by_event(event)
		project_menu.activate_item_by_event(event)
		if ui_menu != null:
			ui_menu.activate_item_by_event(event)
		effects_menu.activate_item_by_event(event)
		view_menu.activate_item_by_event(event)
		window_menu.activate_item_by_event(event)
		help_menu.activate_item_by_event(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if is_node_ready():
			_apply_ipad_topbar_visibility()
		if Global.current_project != null:
			_update_file_menu_buttons(Global.current_project)


## Keep the four shared application menus in the header in compact mode.
## Their original PopupMenu nodes remain in the MenuBar, so signals,
## check states, shortcuts, effect submenus and Workspace Window bridge
## all continue to use the same authoritative menu objects.
func handle_main_menu_collapse() -> void:
	var popup := main_menu_button.get_popup()
	main_menu_button.visible = Global.collapse_main_menu
	menu_bar.visible = true
	if Global.collapse_main_menu:
		if not is_instance_valid(_compact_edit_menu):
			_compact_edit_menu = _create_compact_edit_menu()
			popup.add_submenu_node_item(tr("Edit"), _compact_edit_menu)
		for index in menu_bar.get_menu_count():
			var menu := menu_bar.get_menu_popup(index)
			menu_bar.set_menu_hidden(
				index, menu not in [effects_menu, view_menu, window_menu, help_menu]
			)
	else:
		for index in menu_bar.get_menu_count():
			menu_bar.set_menu_hidden(index, false)
		if is_instance_valid(_compact_edit_menu):
			for index in range(popup.item_count - 1, -1, -1):
				if popup.get_item_submenu_node(index) == _compact_edit_menu:
					popup.remove_item(index)
			if _compact_edit_menu.get_parent() != null:
				_compact_edit_menu.get_parent().remove_child(_compact_edit_menu)
			_compact_edit_menu.queue_free()
			_compact_edit_menu = null
	_apply_ipad_topbar_visibility()
	_arrange_topbar_menu_buttons()


func _arrange_topbar_menu_buttons() -> void:
	var row := return_home_button.get_parent()
	if row == null:
		return
	if _is_ipad_editor() and is_instance_valid(settings_button):
		row.move_child(return_home_button, 0)
		row.move_child(settings_button, 1)
		if is_instance_valid(_effects_icon_button):
			row.move_child(_effects_icon_button, 2)
		row.move_child(menu_bar, 3)
		return
	if (
		Global.collapse_main_menu
		and return_home_button.visible
		and is_instance_valid(ui_layout_button)
		and is_instance_valid(settings_button)
	):
		# Independent Effects / View / Window / Help menus follow editor buttons.
		row.move_child(
			return_home_button, mini(main_menu_button.get_index() + 1, row.get_child_count() - 1)
		)
		row.move_child(
			ui_layout_button, mini(return_home_button.get_index() + 1, row.get_child_count() - 1)
		)
		row.move_child(
			settings_button, mini(ui_layout_button.get_index() + 1, row.get_child_count() - 1)
		)
		row.move_child(menu_bar, mini(settings_button.get_index() + 1, row.get_child_count() - 1))
	else:
		row.move_child(menu_bar, mini(main_menu_button.get_index() + 1, row.get_child_count() - 1))


## Show only the non-duplicated Edit actions in the compact Main Menu.
## The original Edit popup is left intact for keyboard shortcuts and other callers.
func _create_compact_edit_menu() -> PopupMenu:
	var compact := PopupMenu.new()
	compact.name = &"CompactEditMenu"
	compact.id_pressed.connect(edit_menu_id_pressed)
	compact.about_to_popup.connect(_sync_compact_edit_menu.bind(compact))
	_sync_compact_edit_menu(compact)
	return compact


func _sync_compact_edit_menu(compact: PopupMenu) -> void:
	compact.clear()
	for index in edit_menu.item_count:
		var item_id := edit_menu.get_item_id(index)
		# Undo History is now in the Timeline header, next to Undo and Redo.
		if item_id in [Global.EditMenu.UNDO_HISTORY, Global.EditMenu.NEW_BRUSH]:
			continue
		if item_id in [Global.EditMenu.UNDO, Global.EditMenu.REDO, Global.EditMenu.PREFERENCES]:
			continue
		if edit_menu.is_item_separator(index):
			compact.add_separator(edit_menu.get_item_text(index), item_id)
		else:
			compact.add_item(edit_menu.get_item_text(index), item_id)
		var compact_index := compact.item_count - 1
		compact.set_item_disabled(compact_index, edit_menu.is_item_disabled(index))
		compact.set_item_metadata(compact_index, edit_menu.get_item_metadata(index))
		var icon := edit_menu.get_item_icon(index)
		if icon != null:
			compact.set_item_icon(compact_index, icon)


## Main Menu keeps a filtered View submenu. The full original remains live
## for shortcuts, source check states, and the desktop menu.
func _create_compact_view_menu() -> PopupMenu:
	var compact := PopupMenu.new()
	compact.name = &"CompactViewMenu"
	compact.id_pressed.connect(view_menu_id_pressed)
	compact.about_to_popup.connect(_sync_compact_view_menu.bind(compact))
	_sync_compact_view_menu(compact)
	return compact


func _sync_compact_view_menu(compact: PopupMenu) -> void:
	compact.clear()
	for child in compact.get_children():
		if child is PopupMenu:
			compact.remove_child(child)
			child.free()
	for index in view_menu.item_count:
		var item_id := view_menu.get_item_id(index)
		if (
			item_id
			in [
				Global.ViewMenu.CENTER_CANVAS,
				Global.ViewMenu.GREYSCALE_VIEW,
				Global.ViewMenu.MIRROR_VIEW,
				Global.ViewMenu.SHOW_GRID,
				Global.ViewMenu.SHOW_PIXEL_GRID,
				Global.ViewMenu.SHOW_MOUSE_GUIDES,
			]
		):
			continue
		var source_submenu := view_menu.get_item_submenu_node(index)
		if source_submenu != null:
			var sub := PopupMenu.new()
			sub.name = StringName("CompactViewSubmenu%d" % item_id)
			sub.hide_on_checkable_item_selection = source_submenu.hide_on_checkable_item_selection
			for subindex in source_submenu.item_count:
				var sub_id := source_submenu.get_item_id(subindex)
				var sub_text := source_submenu.get_item_text(subindex)
				if source_submenu.is_item_radio_checkable(subindex):
					sub.add_radio_check_item(sub_text, sub_id)
				elif source_submenu.is_item_checkable(subindex):
					sub.add_check_item(sub_text, sub_id)
				else:
					sub.add_item(sub_text, sub_id)
				sub.set_item_checked(subindex, source_submenu.is_item_checked(subindex))
				sub.set_item_disabled(subindex, source_submenu.is_item_disabled(subindex))
			if item_id == Global.ViewMenu.TILE_MODE:
				sub.id_pressed.connect(_tile_mode_submenu_id_pressed)
			elif item_id == Global.ViewMenu.SNAP_TO:
				sub.id_pressed.connect(_snap_to_submenu_id_pressed)
			compact.add_submenu_node_item(view_menu.get_item_text(index), sub, item_id)
		elif view_menu.is_item_separator(index):
			compact.add_separator(view_menu.get_item_text(index), item_id)
		elif view_menu.is_item_radio_checkable(index):
			compact.add_radio_check_item(view_menu.get_item_text(index), item_id)
		elif view_menu.is_item_checkable(index):
			compact.add_check_item(view_menu.get_item_text(index), item_id)
		else:
			compact.add_item(view_menu.get_item_text(index), item_id)
		var compact_index := compact.item_count - 1
		compact.set_item_checked(compact_index, view_menu.is_item_checked(index))
		compact.set_item_disabled(compact_index, view_menu.is_item_disabled(index))
		compact.set_item_metadata(compact_index, view_menu.get_item_metadata(index))
		var icon := view_menu.get_item_icon(index)
		if icon != null:
			compact.set_item_icon(compact_index, icon)


func _on_project_about_to_switch() -> void:
	var project := Global.current_project
	if project.selection_changed.is_connected(_on_project_selection_changed):
		project.selection_changed.disconnect(_on_project_selection_changed)


func _on_project_switched() -> void:
	var project := Global.current_project
	if not project.selection_changed.is_connected(_on_project_selection_changed):
		project.selection_changed.connect(_on_project_selection_changed)
	_on_project_selection_changed()
	_update_file_menu_buttons(project)
	for j in Tiles.MODE.values():
		tile_mode_submenu.set_item_checked(j, j == project.tiles.mode)
	_check_color_mode_submenu_item(project)


func _on_project_selection_changed() -> void:
	var project := Global.current_project
	var has_selection := project.has_selection
	var can_reselect := has_selection or project.prev_selection_map.is_invisible()
	select_menu.set_item_disabled(Global.SelectMenu.CLEAR, not has_selection)
	select_menu.set_item_disabled(Global.SelectMenu.RESELECT, can_reselect)
	project_menu.set_item_disabled(Global.ProjectMenu.CROP_TO_SELECTION, not has_selection)


func _update_file_menu_buttons(project: Project) -> void:
	if not is_instance_valid(file_menu):
		return
	if project.export_directory_path.is_empty():
		file_menu.set_item_text(Global.FileMenu.SAVE, tr("Save"))
	else:
		file_menu.set_item_text(Global.FileMenu.SAVE, tr("Save") + " %s" % project.file_name)
	if project.was_exported:
		var f_name := " %s" % (project.file_name + Export.file_format_string(project.file_format))
		if project.export_overwrite:
			file_menu.set_item_text(Global.FileMenu.EXPORT, tr("Overwrite") + f_name)
		else:
			file_menu.set_item_text(Global.FileMenu.EXPORT, tr("Export") + f_name)
	else:
		file_menu.set_item_text(Global.FileMenu.EXPORT, tr("Export"))


func _setup_file_menu() -> void:
	# Order as in FileMenu enum
	var file_menu_items := {
		"New...": "new_file",
		"Open...": "open_file",
		"Open last project...": "open_last_project",
		"Recent projects": "",
		"Save...": "save_file",
		"Save as...": "save_file_as",
		"Export...": "export_file",
		"Export as...": "export_file_as",
		"Quit": "quit",
	}
	var i := 0
	for item in file_menu_items:
		if item == "Recent projects":
			_setup_recent_projects_submenu(item)
		else:
			_set_menu_shortcut(file_menu_items[item], file_menu, i, item)
		i += 1

	file_menu.id_pressed.connect(file_menu_id_pressed)

	if OS.get_name() == "Web":
		file_menu.set_item_disabled(Global.FileMenu.OPEN_LAST_PROJECT, true)
		file_menu.set_item_disabled(Global.FileMenu.RECENT, true)


func _setup_recent_projects_submenu(item: String) -> void:
	recent_projects_submenu.name = "RecentProjectsPopupMenu"
	recent_projects = Global.config_cache.get_value("data", "recent_projects", [])
	recent_projects_submenu.id_pressed.connect(_on_recent_projects_submenu_id_pressed)
	update_recent_projects_submenu()

	file_menu.add_child(recent_projects_submenu)
	file_menu.add_submenu_item(item, recent_projects_submenu.get_name())


func update_recent_projects_submenu() -> void:
	var reversed_recent_projects := recent_projects.duplicate()
	reversed_recent_projects.reverse()
	for project in reversed_recent_projects:
		recent_projects_submenu.add_item(project.get_file())


func _setup_edit_menu() -> void:
	# Order as in Global.EditMenu enum
	var edit_menu_items := {
		"Undo": "undo",
		"Redo": "redo",
		"Undo History": "undo_history",
		"Copy": "copy",
		"Cut": "cut",
		"Paste": "paste",
		"Paste in Place": "paste_in_place",
		"Paste from Clipboard": "paste_from_clipboard",
		"Delete": "delete",
		"New Brush": "new_brush",
		"Preferences": "preferences"
	}
	var i := 0
	for item in edit_menu_items:
		var echo := false
		if item in ["Undo", "Redo"]:
			echo = true
		# Keep Global.EditMenu IDs stable even though New Brush now lives in Pencil.
		if item != "New Brush":
			_set_menu_shortcut(edit_menu_items[item], edit_menu, i, item, false, echo)
		i += 1
	edit_menu.id_pressed.connect(edit_menu_id_pressed)


func _setup_view_menu() -> void:
	# Order as in Global.ViewMenu enum
	var view_menu_items := {
		"Center Canvas": "center_canvas",
		"Tile Mode": "",
		"Tile Mode Offsets": "",
		"Grayscale View": &"grayscale_view",
		"Mirror View": "mirror_view",
		"Show Grid": "show_grid",
		"Show Pixel Grid": "show_pixel_grid",
		"Show Pixel Indices": "show_pixel_indices",
		"Show Rulers": "show_rulers",
		"Show Guides": "show_guides",
		"Show Mouse Guides": "",
		"Show Reference Images": "show_reference_images",
		"Display Layer Effects": &"display_layer_effects",
		"Snap To": "",
	}
	for i in view_menu_items.size():
		var item: String = view_menu_items.keys()[i]
		if item == "Tile Mode":
			_setup_tile_mode_submenu(item)
		elif item == "Snap To":
			_setup_snap_to_submenu(item)
		elif item == "Tile Mode Offsets":
			view_menu.add_item(item, i)
		elif item == "Center Canvas":
			_set_menu_shortcut(view_menu_items[item], view_menu, i, item)
		else:
			_set_menu_shortcut(view_menu_items[item], view_menu, i, item, true)
	view_menu.set_item_checked(Global.ViewMenu.SHOW_RULERS, true)
	view_menu.set_item_checked(Global.ViewMenu.SHOW_GUIDES, true)
	view_menu.set_item_checked(Global.ViewMenu.SHOW_REFERENCE_IMAGES, true)
	view_menu.set_item_checked(Global.ViewMenu.DISPLAY_LAYER_EFFECTS, true)
	view_menu.hide_on_checkable_item_selection = false
	view_menu.id_pressed.connect(view_menu_id_pressed)

	# Load settings from the config file
	var draw_grid: bool = Global.config_cache.get_value("view_menu", "draw_grid", Global.draw_grid)
	var draw_pixel_grid: bool = Global.config_cache.get_value(
		"view_menu", "draw_pixel_grid", Global.draw_pixel_grid
	)
	var show_pixel_indices: bool = Global.config_cache.get_value(
		"view_menu", "show_pixel_indices", Global.show_pixel_indices
	)
	var show_rulers: bool = Global.config_cache.get_value(
		"view_menu", "show_rulers", Global.show_rulers
	)
	var show_guides: bool = Global.config_cache.get_value(
		"view_menu", "show_guides", Global.show_guides
	)
	var show_mouse_guides: bool = Global.config_cache.get_value(
		"view_menu", "show_mouse_guides", Global.show_mouse_guides
	)
	var display_layer_effects: bool = Global.config_cache.get_value(
		"view_menu", "display_layer_effects", Global.display_layer_effects
	)
	var snap_to_rectangular_grid_boundary: bool = Global.config_cache.get_value(
		"view_menu", "snap_to_rectangular_grid_boundary", Global.snap_to_rectangular_grid_boundary
	)
	var snap_to_rectangular_grid_center: bool = Global.config_cache.get_value(
		"view_menu", "snap_to_rectangular_grid_center", Global.snap_to_rectangular_grid_center
	)
	var snap_to_guides: bool = Global.config_cache.get_value(
		"view_menu", "snap_to_guides", Global.snap_to_guides
	)
	var snap_to_perspective_guides: bool = Global.config_cache.get_value(
		"view_menu", "snap_to_perspective_guides", Global.snap_to_perspective_guides
	)
	if draw_grid != Global.draw_grid:
		_toggle_show_grid()
	if draw_pixel_grid != Global.draw_pixel_grid:
		_toggle_show_pixel_grid()
	if show_rulers != Global.show_rulers:
		_toggle_show_rulers()
	if show_guides != Global.show_guides:
		_toggle_show_guides()
	if show_mouse_guides != Global.show_mouse_guides:
		_toggle_show_mouse_guides()
	if show_pixel_indices != Global.show_pixel_indices:
		_toggle_show_pixel_indices()
	if display_layer_effects != Global.display_layer_effects:
		Global.display_layer_effects = display_layer_effects
	if snap_to_rectangular_grid_boundary != Global.snap_to_rectangular_grid_boundary:
		_snap_to_submenu_id_pressed(0)
	if snap_to_rectangular_grid_center != Global.snap_to_rectangular_grid_center:
		_snap_to_submenu_id_pressed(1)
	if snap_to_guides != Global.snap_to_guides:
		_snap_to_submenu_id_pressed(2)
	if snap_to_perspective_guides != Global.snap_to_perspective_guides:
		_snap_to_submenu_id_pressed(3)


func _setup_tile_mode_submenu(item: String) -> void:
	tile_mode_submenu.set_name("tile_mode_submenu")
	tile_mode_submenu.add_radio_check_item("None", Tiles.MODE.NONE)
	tile_mode_submenu.set_item_checked(Tiles.MODE.NONE, true)
	tile_mode_submenu.add_radio_check_item("Tiled In Both Axis", Tiles.MODE.BOTH)
	tile_mode_submenu.add_radio_check_item("Tiled In X Axis", Tiles.MODE.X_AXIS)
	tile_mode_submenu.add_radio_check_item("Tiled In Y Axis", Tiles.MODE.Y_AXIS)
	tile_mode_submenu.hide_on_checkable_item_selection = false

	tile_mode_submenu.id_pressed.connect(_tile_mode_submenu_id_pressed)
	view_menu.add_child(tile_mode_submenu)
	view_menu.add_submenu_item(item, tile_mode_submenu.get_name())


func _setup_snap_to_submenu(item: String) -> void:
	snap_to_submenu.set_name("snap_to_submenu")
	snap_to_submenu.add_check_item("Snap to Rectangular Grid Boundary")
	snap_to_submenu.add_check_item("Snap to Rectangular Grid Center")
	snap_to_submenu.add_check_item("Snap to Guides")
	snap_to_submenu.add_check_item("Snap to Perspective Guides")
	snap_to_submenu.id_pressed.connect(_snap_to_submenu_id_pressed)
	view_menu.add_child(snap_to_submenu)
	view_menu.add_submenu_item(item, snap_to_submenu.get_name())


func _setup_window_menu() -> void:
	# Keep explicit command IDs. Legacy window-menu ID 4 remains reserved,
	# so removing its entry must not change the Fullscreen command ID (5).
	var window_menu_items := {
		Global.WindowMenu.WINDOW_OPACITY: ["Window Opacity", ""],
		Global.WindowMenu.PANELS: ["Panels", ""],
		Global.WindowMenu.LAYOUTS: ["Layouts", ""],
		Global.WindowMenu.MOVABLE_PANELS: ["Moveable Panels", "moveable_panels"],
		Global.WindowMenu.FULLSCREEN_MODE: ["Fullscreen Mode", "toggle_fullscreen"],
	}
	for id in window_menu_items:
		var item := str(window_menu_items[id][0])
		var shortcut := str(window_menu_items[id][1])
		if item == "Panels":
			_setup_panels_submenu(item)
		elif item == "Layouts":
			_setup_layouts_submenu(item)
		elif item == "Window Opacity":
			window_menu.add_item(item, id)
		else:
			_set_menu_shortcut(shortcut, window_menu, id, item, true)
	window_menu.hide_on_checkable_item_selection = false
	window_menu.id_pressed.connect(window_menu_id_pressed)
	# Disable window opacity item if per pixel transparency is not allowed
	window_menu.set_item_disabled(
		Global.WindowMenu.WINDOW_OPACITY,
		!ProjectSettings.get_setting("display/window/per_pixel_transparency/allowed")
	)


func _setup_panels_submenu(item: String) -> void:
	panels_submenu.set_name("panels_submenu")
	panels_submenu.hide_on_checkable_item_selection = false
	for element in ui_elements:
		if element.name == "Tiles" or element.name == "3D Object Tree":
			continue
		var id := ui_elements.find(element)
		panels_submenu.add_check_item(element.name, id)
		var is_hidden: bool = main_ui.is_control_hidden(element)
		var index := panels_submenu.get_item_index(id)
		panels_submenu.set_item_checked(index, !is_hidden)

	panels_submenu.id_pressed.connect(_panels_submenu_id_pressed)
	window_menu.add_child(panels_submenu)
	window_menu.add_submenu_item(item, panels_submenu.get_name())


func _setup_layouts_submenu(item: String) -> void:
	layouts_submenu.hide_on_checkable_item_selection = false
	populate_layouts_submenu()

	layouts_submenu.id_pressed.connect(_layouts_submenu_id_pressed)
	window_menu.add_child(layouts_submenu)
	window_menu.add_submenu_node_item(item, layouts_submenu)

	var saved_layout: int = Global.config_cache.get_value("window", "layout", 0)
	# Wait for pixelorama to fully load up, then change the layout.
	Global.pixelorama_opened.connect(set_layout.bind(saved_layout))


func populate_layouts_submenu() -> void:
	layouts_submenu.clear()  # Does not do anything if it's called for the first time
	for layout in Global.layouts:
		var layout_name := layout.resource_path.get_basename().get_file()
		layouts_submenu.add_radio_check_item(layout_name)
	layouts_submenu.add_separator()
	layouts_submenu.add_item("Add Layout")
	layouts_submenu.add_item(tr("Delete %s") % "Default")
	layouts_submenu.add_item(tr("Reset %s") % "Default")


func _setup_project_menu() -> void:
	# Order as in Global.ProjectMenu enum
	var project_menu_items := {
		"Project Properties": "project_properties",
		"Color Mode": "",
		"Resize Canvas": "resize_canvas",
		"Scale Image": "scale_image",
		"Crop to Selection": "crop_to_selection",
		"Crop to Content": "crop_to_content",
	}
	for i in project_menu_items.size():
		var item: String = project_menu_items.keys()[i]
		if item == "Color Mode":
			_setup_color_mode_submenu(item)
		else:
			_set_menu_shortcut(project_menu_items[item], project_menu, i, item)
	project_menu.set_item_disabled(Global.ProjectMenu.CROP_TO_SELECTION, true)
	project_menu.id_pressed.connect(project_menu_id_pressed)


func _setup_color_mode_submenu(item: String) -> void:
	color_mode_submenu.set_name("color_mode_submenu")
	color_mode_submenu.add_radio_check_item("RGBA", ColorModes.RGBA)
	color_mode_submenu.set_item_checked(ColorModes.RGBA, true)
	color_mode_submenu.add_radio_check_item("Indexed", ColorModes.INDEXED)

	color_mode_submenu.id_pressed.connect(_color_mode_submenu_id_pressed)
	project_menu.add_child(color_mode_submenu)
	project_menu.add_submenu_item(item, color_mode_submenu.get_name())


func _setup_effects_menu() -> void:
	_set_menu_shortcut(&"reapply_last_effect", effects_menu, 0, "Re-apply last effect")
	effects_menu.set_item_disabled(0, true)
	_set_menu_shortcut(&"offset_image", effects_transform_submenu, 0, "Offset & Scale Image")
	_set_menu_shortcut(&"mirror_image", effects_transform_submenu, 1, "Mirror Image")
	_set_menu_shortcut(&"rotate_image", effects_transform_submenu, 2, "Rotate Image")
	_set_menu_shortcut(&"flat_to_isometric", effects_transform_submenu, 3, "Flat to Isometric")
	effects_transform_submenu.id_pressed.connect(_on_effects_transform_submenu_id_pressed)
	effects_menu.add_child(effects_transform_submenu)
	effects_menu.add_submenu_node_item("Transform", effects_transform_submenu)

	_set_menu_shortcut(&"invert_colors", effects_color_submenu, 0, "Invert Colors")
	_set_menu_shortcut(&"desaturation", effects_color_submenu, 1, "Desaturation")
	_set_menu_shortcut(&"adjust_hsv", effects_color_submenu, 2, "Adjust Hue/Saturation/Value")
	_set_menu_shortcut(
		&"adjust_brightness_contrast", effects_color_submenu, 3, "Adjust Brightness/Contrast"
	)
	_set_menu_shortcut(&"color_curves", effects_color_submenu, 4, "Color Curves")
	_set_menu_shortcut(&"palettize", effects_color_submenu, 5, "Palettize")
	_set_menu_shortcut(&"posterize", effects_color_submenu, 6, "Posterize")
	_set_menu_shortcut(&"gradient_map", effects_color_submenu, 7, "Gradient Map")
	effects_color_submenu.id_pressed.connect(_on_effects_color_submenu_id_pressed)
	effects_menu.add_child(effects_color_submenu)
	effects_menu.add_submenu_node_item("Color", effects_color_submenu)

	_set_menu_shortcut(&"outline", effects_procedural_submenu, 0, "Outline")
	_set_menu_shortcut(&"drop_shadow", effects_procedural_submenu, 1, "Drop Shadow")
	_set_menu_shortcut(&"gradient", effects_procedural_submenu, 2, "Gradient")
	effects_procedural_submenu.id_pressed.connect(_on_effects_procedural_submenu_id_pressed)
	effects_menu.add_child(effects_procedural_submenu)
	effects_menu.add_submenu_node_item("Procedural", effects_procedural_submenu)

	_set_menu_shortcut(&"pixelize", effects_blur_submenu, 0, "Pixelize")
	_set_menu_shortcut(&"gaussian_blur", effects_blur_submenu, 1, "Gaussian Blur")
	effects_blur_submenu.id_pressed.connect(_on_effects_blur_submenu_id_pressed)
	effects_menu.add_child(effects_blur_submenu)
	effects_menu.add_submenu_node_item("Blur", effects_blur_submenu)

	_setup_effects_loaded_submenu()
	effects_menu.id_pressed.connect(effects_menu_id_pressed)


func _setup_effects_loaded_submenu() -> void:
	if not DirAccess.dir_exists_absolute(OpenSave.SHADERS_DIRECTORY):
		DirAccess.make_dir_recursive_absolute(OpenSave.SHADERS_DIRECTORY)
	var shader_files := DirAccess.get_files_at(OpenSave.SHADERS_DIRECTORY)
	if shader_files.size() == 0:
		return
	for shader_file in shader_files:
		_load_shader_file(OpenSave.SHADERS_DIRECTORY.path_join(shader_file))


func _load_shader_file(file_path: String) -> void:
	var file := load(file_path)
	if file is not Shader:
		return
	var effect_name := file_path.get_file().get_basename()
	if not is_instance_valid(effects_loaded_submenu):
		effects_loaded_submenu = PopupMenu.new()
		effects_loaded_submenu.set_name("effects_loaded_submenu")
		effects_loaded_submenu.id_pressed.connect(_effects_loaded_submenu_id_pressed)
		effects_menu.add_child(effects_loaded_submenu)
		effects_menu.add_submenu_node_item("Loaded", effects_loaded_submenu)
	effects_loaded_submenu.add_item(effect_name)
	var effect_index := effects_loaded_submenu.item_count - 1
	effects_loaded_submenu.set_item_metadata(effect_index, file)
	loaded_effect_dialogs.append(Dialog.new("res://src/UI/Dialogs/ImageEffects/ShaderEffect.tscn"))


func _setup_select_menu() -> void:
	# Order as in Global.SelectMenu enum
	var select_menu_items := {
		"All": "select_all",
		"Clear": "clear_selection",
		"Reselect": "reselect",
		"Invert": "invert_selection",
		"Select cel area": "select_cel_area",
		"Wrap Strokes": "",
		"Modify": ""
	}
	for i in select_menu_items.size():
		var item: String = select_menu_items.keys()[i]
		if item == "Wrap Strokes":
			select_menu.add_check_item(item, i)
		elif item == "Modify":
			_setup_selection_modify_submenu(item)
		else:
			_set_menu_shortcut(select_menu_items[item], select_menu, i, item)
	select_menu.id_pressed.connect(select_menu_id_pressed)


func _setup_selection_modify_submenu(item: String) -> void:
	selection_modify_submenu.set_name("selection_modify_submenu")
	selection_modify_submenu.add_item("Expand")
	selection_modify_submenu.add_item("Shrink")
	selection_modify_submenu.add_item("Border")
	selection_modify_submenu.add_item("Center")
	selection_modify_submenu.id_pressed.connect(_selection_modify_submenu_id_pressed)
	select_menu.add_child(selection_modify_submenu)
	select_menu.add_submenu_item(item, selection_modify_submenu.get_name())


func _setup_help_menu() -> void:
	# Order as in Global.HelpMenu enum
	var help_menu_items := {
		"View Splash Screen": "view_splash_screen",
		"Online Docs": "open_docs",
		"Issue Tracker": "issue_tracker",
		"Restore Backup": &"",
		"Open Editor Data Folder": "open_editor_data_folder",
		"Changelog": "changelog",
		"About Phosprite": "about_pixelorama",
		"Support Pixelorama's Development": &"",
	}
	var i := 0
	for item in help_menu_items:
		var icon: Texture2D = null
		if (
			i == Global.HelpMenu.ONLINE_DOCS
			or i == Global.HelpMenu.ISSUE_TRACKER
			or i == Global.HelpMenu.CHANGELOG
		):
			icon = EXTERNAL_LINK_ICON
		if i == Global.HelpMenu.ABOUT_PIXELORAMA:
			icon = PIXELORAMA_ICON
		elif i == Global.HelpMenu.SUPPORT_PIXELORAMA:
			icon = HEART_ICON
		_set_menu_shortcut(help_menu_items[item], help_menu, i, item, false, false, icon)

		i += 1

	help_menu.id_pressed.connect(help_menu_id_pressed)


func _set_menu_shortcut(
	action: StringName,
	menu: PopupMenu,
	index: int,
	text: String,
	is_check := false,
	echo := false,
	icon: Texture2D = null
) -> void:
	if action.is_empty():
		if is_check:
			menu.add_check_item(text, index)
		else:
			menu.add_item(text, index)
	else:
		var shortcut := Shortcut.new()
		var event := InputEventAction.new()
		event.action = action
		shortcut.events.append(event)
		if is_check:
			menu.add_check_shortcut(shortcut, index)
		else:
			menu.add_shortcut(shortcut, index, false, echo)
		menu.set_item_text(menu.item_count - 1, text)
	if is_instance_valid(icon):
		menu.set_item_icon(index, icon)


func _handle_metadata(id: int, popup_menu: PopupMenu) -> void:
	# Used for extensions that want to add extra menu items
	var metadata = popup_menu.get_item_metadata(id)
	if metadata:
		if metadata is Object:
			if metadata.has_method(&"menu_item_clicked"):
				metadata.call(&"menu_item_clicked")


func _popup_dialog(dialog: Window, dialog_size := Vector2i.ZERO) -> void:
	dialog.popup_centered_clamped(dialog_size)
	var is_file_dialog := dialog is FileDialog
	Global.dialog_open(true, is_file_dialog)


func file_menu_id_pressed(id: int) -> void:
	if not can_save:
		return
	match id:
		Global.FileMenu.NEW:
			new_image_dialog.popup()
		Global.FileMenu.OPEN:
			_open_project_file()
		Global.FileMenu.OPEN_LAST_PROJECT:
			_on_open_last_project_file_menu_option_pressed()
		Global.FileMenu.SAVE:
			_save_project_file()
		Global.FileMenu.SAVE_AS:
			main.request_save(main.SaveIntent.SAVE_AS, Global.current_project)
		Global.FileMenu.EXPORT:
			_export_file()
		Global.FileMenu.EXPORT_AS:
			_popup_dialog(Global.export_dialog)
		Global.FileMenu.QUIT:
			main.show_quit_dialog()
		_:
			_handle_metadata(id, file_menu)


func _open_project_file() -> void:
	if OS.get_name() == "Web":
		Html5FileExchange.load_image()
	else:
		_popup_dialog(main.open_sprite_dialog)
		main.opensprite_file_selected = false


func _on_open_last_project_file_menu_option_pressed() -> void:
	if Global.config_cache.has_section_key("data", "last_project_path"):
		main.load_last_project()
	else:
		Global.popup_error("You haven't saved or opened any project in Pixelorama yet!")


func _save_project_file() -> void:
	if Global.current_project is ResourceProject:
		Global.current_project.resource_updated.emit(Global.current_project)
		if Global.current_project.has_changed:
			Global.current_project.has_changed = false
		Global.notification_label("Resource Updated")
		return
	# Main decides where the project goes: without a path the platform policy
	# picks the destination, and a project that already has one is overwritten.
	main.request_save(main.SaveIntent.SAVE, Global.current_project)


func _export_file() -> void:
	if Global.current_project.was_exported == false:
		_popup_dialog(Global.export_dialog)
	else:
		Export.external_export()


func _on_recent_projects_submenu_id_pressed(id: int) -> void:
	var reversed_recent_projects := recent_projects.duplicate()
	reversed_recent_projects.reverse()
	main.load_recent_project_file(reversed_recent_projects[id])


func edit_menu_id_pressed(id: int) -> void:
	match id:
		Global.EditMenu.UNDO:
			Global.current_project.commit_undo()
		Global.EditMenu.REDO:
			Global.current_project.commit_redo()
		Global.EditMenu.UNDO_HISTORY:
			undo_history_dialog.popup_centered_clamped()
		Global.EditMenu.COPY:
			Global.canvas.selection.copy()
		Global.EditMenu.CUT:
			Global.canvas.selection.cut()
		Global.EditMenu.PASTE:
			Global.canvas.selection.paste()
		Global.EditMenu.PASTE_IN_PLACE:
			Global.canvas.selection.paste(true)
		Global.EditMenu.PASTE_FROM_CLIPBOARD:
			if not DisplayServer.clipboard_has_image():
				var clipboard := DisplayServer.clipboard_get()
				if clipboard.begins_with("lospec-palette://"):
					Palettes.import_lospec_palette(clipboard)
			Global.canvas.selection.paste_from_clipboard()
		Global.EditMenu.DELETE:
			Global.canvas.selection.delete()
		Global.EditMenu.NEW_BRUSH:
			Global.canvas.selection.new_brush()
		Global.EditMenu.PREFERENCES:
			preferences_dialog.popup()
		_:
			_handle_metadata(id, edit_menu)


func view_menu_id_pressed(id: int) -> void:
	match id:
		Global.ViewMenu.CENTER_CANVAS:
			Global.camera.offset = Global.current_project.size / 2
		Global.ViewMenu.TILE_MODE_OFFSETS:
			_popup_dialog(get_tree().current_scene.tile_mode_offsets_dialog)
		Global.ViewMenu.GREYSCALE_VIEW:
			_toggle_greyscale_view()
		Global.ViewMenu.MIRROR_VIEW:
			_toggle_mirror_view()
		Global.ViewMenu.SHOW_GRID:
			_toggle_show_grid()
		Global.ViewMenu.SHOW_PIXEL_GRID:
			_toggle_show_pixel_grid()
		Global.ViewMenu.SHOW_RULERS:
			_toggle_show_rulers()
		Global.ViewMenu.SHOW_GUIDES:
			_toggle_show_guides()
		Global.ViewMenu.SHOW_MOUSE_GUIDES:
			_toggle_show_mouse_guides()
		Global.ViewMenu.SHOW_REFERENCE_IMAGES:
			Global.show_reference_images = not Global.show_reference_images
			view_menu.set_item_checked(
				Global.ViewMenu.SHOW_REFERENCE_IMAGES, Global.show_reference_images
			)
		Global.ViewMenu.SHOW_PIXEL_INDICES:
			_toggle_show_pixel_indices()
		Global.ViewMenu.DISPLAY_LAYER_EFFECTS:
			Global.display_layer_effects = not Global.display_layer_effects
		_:
			_handle_metadata(id, view_menu)

	Global.canvas.queue_redraw()


func window_menu_id_pressed(id: int) -> void:
	match id:
		Global.WindowMenu.WINDOW_OPACITY:
			window_opacity_dialog.popup()
		Global.WindowMenu.MOVABLE_PANELS:
			main_ui.hide_single_tab = not main_ui.hide_single_tab
			window_menu.set_item_checked(id, not main_ui.hide_single_tab)
		Global.WindowMenu.FULLSCREEN_MODE:
			_toggle_fullscreen()
		_:
			_handle_metadata(id, window_menu)


func _tile_mode_submenu_id_pressed(id: Tiles.MODE) -> void:
	Global.current_project.tiles.mode = id
	Global.transparent_checker.fit_rect(Global.current_project.tiles.get_bounding_rect())
	for i in Tiles.MODE.values():
		tile_mode_submenu.set_item_checked(i, i == id)
	Global.pixel_grid_updated.emit()
	Global.grid_updated.emit()
	Global.canvas.tile_mode.queue_redraw()
	get_tree().current_scene.tile_mode_offsets_dialog.change_mask()


func _selection_modify_submenu_id_pressed(id: int) -> void:
	modify_selection.popup()
	modify_selection.node.type = id


func _color_mode_submenu_id_pressed(id: ColorModes) -> void:
	var project := Global.current_project
	var old_color_mode := project.color_mode
	var redo_data := {}
	var undo_data := {}
	var pixel_cels: Array[BaseCel]
	# We need to do it this way because Godot
	# doesn't like casting typed arrays into other types.
	for cel in project.get_all_pixel_cels():
		pixel_cels.append(cel)
	project.serialize_cel_undo_data(pixel_cels, undo_data)
	# Change the color mode directly before undo/redo in order to affect the images,
	# so we can store them as redo data.
	if id == ColorModes.RGBA:
		project.color_mode = Image.FORMAT_RGBA8
	else:
		project.color_mode = Project.INDEXED_MODE
	var used_tilesets := project.update_tilemaps(undo_data, TileSetPanel.TileEditingMode.AUTO)
	var layers_to_update := PackedInt32Array()
	for l in Global.current_project.layers:
		if l is LayerTileMap:
			if l.tileset in used_tilesets:
				layers_to_update.append(l.index)
	project.serialize_cel_undo_data(pixel_cels, redo_data)
	project.undo_redo.create_action("Change color mode")
	var palette_in_focus = Palettes.current_palette
	if not palette_in_focus.is_project_palette and project.color_mode == Project.INDEXED_MODE:
		if Global.global_palettes_readonly:
			palette_in_focus = palette_in_focus.duplicate()
			Palettes.undo_redo_add_palette(palette_in_focus, false)
	project.undo_redo.add_do_property(project, "color_mode", project.color_mode)
	project.undo_redo.add_undo_property(project, "color_mode", old_color_mode)
	project.deserialize_cel_undo_data(redo_data, undo_data)
	# we may be on a different layer during undo/redo
	Global.current_project.undo_redo.add_do_property(
		Global.canvas, "mandatory_update_layers", layers_to_update
	)
	Global.current_project.undo_redo.add_undo_property(
		Global.canvas, "mandatory_update_layers", layers_to_update
	)
	project.undo_redo.add_do_method(_check_color_mode_submenu_item.bind(project))
	project.undo_redo.add_undo_method(_check_color_mode_submenu_item.bind(project))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()


func _check_color_mode_submenu_item(project: Project) -> void:
	color_mode_submenu.set_item_checked(ColorModes.RGBA, project.color_mode == Image.FORMAT_RGBA8)
	color_mode_submenu.set_item_checked(ColorModes.INDEXED, project.is_indexed())


func _snap_to_submenu_id_pressed(id: int) -> void:
	if id == 0:
		Global.snap_to_rectangular_grid_boundary = !Global.snap_to_rectangular_grid_boundary
		snap_to_submenu.set_item_checked(id, Global.snap_to_rectangular_grid_boundary)
	if id == 1:
		Global.snap_to_rectangular_grid_center = !Global.snap_to_rectangular_grid_center
		snap_to_submenu.set_item_checked(id, Global.snap_to_rectangular_grid_center)
	elif id == 2:
		Global.snap_to_guides = !Global.snap_to_guides
		snap_to_submenu.set_item_checked(id, Global.snap_to_guides)
	elif id == 3:
		Global.snap_to_perspective_guides = !Global.snap_to_perspective_guides
		snap_to_submenu.set_item_checked(id, Global.snap_to_perspective_guides)


func _effects_loaded_submenu_id_pressed(id: int) -> void:
	var dialog := loaded_effect_dialogs[id]
	if is_instance_valid(dialog.node):
		dialog.popup()
	else:
		dialog.instantiate_scene()
		var shader := effects_loaded_submenu.get_item_metadata(id) as Shader
		dialog.node.change_shader(shader, effects_loaded_submenu.get_item_text(id))
		dialog.popup()


func _panels_submenu_id_pressed(id: int) -> void:
	var index := panels_submenu.get_item_index(id)
	var element_visible := panels_submenu.is_item_checked(index)
	main_ui.set_control_hidden(ui_elements[id], element_visible)
	panels_submenu.set_item_checked(index, !element_visible)


func _layouts_submenu_id_pressed(id: int) -> void:
	var layout_count := Global.layouts.size()
	if id < layout_count:
		set_layout(id)
	elif id == layout_count + 1:
		layout_name_line_edit.text = "New layout"
		add_layout_confirmation.popup_centered_clamped()
	elif id == layout_count + 2:
		delete_layout_confirmation.popup_centered_clamped()
	elif id == layout_count + 3:
		Global.layouts[selected_layout].reset()


func set_layout(id: int) -> void:
	if Global.layouts.size() == 0:
		return
	if id >= Global.layouts.size():
		id = 0
	selected_layout = id
	var layout := Global.layouts[id]
	main_ui.layout = layout
	var layout_name := layout.resource_path.get_basename().get_file()
	layouts_submenu.set_item_text(layouts_submenu.item_count - 2, tr("Delete %s") % layout_name)
	layouts_submenu.set_item_text(layouts_submenu.item_count - 1, tr("Reset %s") % layout_name)
	layouts_submenu.set_item_disabled(
		layouts_submenu.item_count - 1, layout.layout_reset_path.is_empty()
	)
	for i in Global.layouts.size():
		layouts_submenu.set_item_checked(i, i == id)

	for i in ui_elements.size():
		var index := panels_submenu.get_item_index(i)
		var is_hidden := main_ui.is_control_hidden(ui_elements[i])
		panels_submenu.set_item_checked(index, !is_hidden)


func _on_add_layout_confirmation_confirmed() -> void:
	var file_name := layout_name_line_edit.text + ".tres"
	var path := Global.LAYOUT_DIR.path_join(file_name)
	var layout: DockableLayout
	if layout_from_option_button.selected == 0:
		layout = main.main_ui.layout.clone()
		layout.layout_reset_path = ""
	else:
		layout = Global.default_layouts[layout_from_option_button.selected - 1].clone()
	layout.resource_name = layout_name_line_edit.text
	layout.resource_path = path
	var err := ResourceSaver.save(layout, path)
	if err != OK:
		print(err)
		return
	Global.layouts.append(layout)
	# Save the layout every time it changes
	layout.save_on_change = true
	main.main_ui.layout = layout
	Global.layouts.sort_custom(
		func(a: DockableLayout, b: DockableLayout):
			return a.resource_path.get_file() < b.resource_path.get_file()
	)
	var layout_index := Global.layouts.find(layout)
	populate_layouts_submenu()
	set_layout(layout_index)


func _on_delete_layout_confirmation_confirmed() -> void:
	if Global.layouts.size() <= 1:  # Don't delete any layout if we only have one left.
		return
	var layout_name := Global.layouts[selected_layout].resource_path.get_basename().get_file()
	delete_layout_file(layout_name + ".tres")
	Global.layouts.remove_at(selected_layout)
	populate_layouts_submenu()
	set_layout(0)


func delete_layout_file(file_name: String) -> void:
	var dir := DirAccess.open(Global.LAYOUT_DIR)
	if not is_instance_valid(dir):
		return
	dir.remove(Global.LAYOUT_DIR.path_join(file_name))


func _on_add_layout_confirmation_visibility_changed() -> void:
	Global.dialog_open(add_layout_confirmation.visible)


func _on_delete_layout_confirmation_visibility_changed() -> void:
	Global.dialog_open(delete_layout_confirmation.visible)


func _toggle_greyscale_view() -> void:
	Global.greyscale_view = !Global.greyscale_view


func _toggle_mirror_view() -> void:
	Global.mirror_view = !Global.mirror_view
	var marching_ants_outline: Sprite2D = Global.canvas.selection.marching_ants_outline
	marching_ants_outline.scale.x = -marching_ants_outline.scale.x
	if Global.mirror_view:
		marching_ants_outline.position.x = (
			marching_ants_outline.position.x + Global.current_project.size.x
		)
	else:
		Global.canvas.selection.marching_ants_outline.position.x = 0
	Global.canvas.selection.queue_redraw()
	view_menu.set_item_checked(Global.ViewMenu.MIRROR_VIEW, Global.mirror_view)
	Global.preview_view_controls_changed.emit()


func _toggle_show_grid() -> void:
	Global.draw_grid = !Global.draw_grid
	view_menu.set_item_checked(Global.ViewMenu.SHOW_GRID, Global.draw_grid)
	Global.grid_updated.emit()
	Global.preview_view_controls_changed.emit()


func _toggle_show_pixel_grid() -> void:
	Global.draw_pixel_grid = !Global.draw_pixel_grid
	view_menu.set_item_checked(Global.ViewMenu.SHOW_PIXEL_GRID, Global.draw_pixel_grid)
	Global.pixel_grid_updated.emit()
	Global.preview_view_controls_changed.emit()


func _toggle_show_pixel_indices() -> void:
	Global.show_pixel_indices = !Global.show_pixel_indices
	view_menu.set_item_checked(Global.ViewMenu.SHOW_PIXEL_INDICES, Global.show_pixel_indices)


func _toggle_show_rulers() -> void:
	Global.show_rulers = !Global.show_rulers
	view_menu.set_item_checked(Global.ViewMenu.SHOW_RULERS, Global.show_rulers)


func _toggle_show_guides() -> void:
	Global.show_guides = !Global.show_guides
	view_menu.set_item_checked(Global.ViewMenu.SHOW_GUIDES, Global.show_guides)
	for guide in Global.canvas.get_children():
		if guide is Guide and guide in Global.current_project.guides:
			guide.visible = Global.show_guides
			if guide is SymmetryGuide:
				if guide.type == Guide.Types.HORIZONTAL:
					guide.visible = Global.show_x_symmetry_axis and Global.show_guides
				elif guide.type == Guide.Types.VERTICAL:
					guide.visible = Global.show_y_symmetry_axis and Global.show_guides
				elif guide.type == Guide.Types.XY:
					guide.visible = Global.show_xy_symmetry_axis and Global.show_guides
				elif guide.type == Guide.Types.X_MINUS_Y:
					guide.visible = Global.show_x_minus_y_symmetry_axis and Global.show_guides


func _toggle_show_mouse_guides() -> void:
	Global.show_mouse_guides = !Global.show_mouse_guides
	view_menu.set_item_checked(Global.ViewMenu.SHOW_MOUSE_GUIDES, Global.show_mouse_guides)
	if Global.show_mouse_guides:
		if Global.canvas.mouse_guide_container:
			Global.canvas.mouse_guide_container.get_child(0).queue_redraw()
			Global.canvas.mouse_guide_container.get_child(1).queue_redraw()


func _toggle_fullscreen() -> void:
	var is_fullscreen := (
		(get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN)
		or (get_window().mode == Window.MODE_FULLSCREEN)
	)
	get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if !is_fullscreen else Window.MODE_WINDOWED
	is_fullscreen = not is_fullscreen
	window_menu.set_item_checked(
		window_menu.get_item_index(Global.WindowMenu.FULLSCREEN_MODE), is_fullscreen
	)
	get_tree().current_scene.set_mobile_fullscreen_safe_area()


func project_menu_id_pressed(id: int) -> void:
	match id:
		Global.ProjectMenu.PROJECT_PROPERTIES:
			project_properties_dialog.popup()
		Global.ProjectMenu.SCALE_IMAGE:
			scale_image_dialog.popup()
		Global.ProjectMenu.CROP_TO_SELECTION:
			DrawingAlgos.crop_to_selection()
		Global.ProjectMenu.CROP_TO_CONTENT:
			DrawingAlgos.crop_to_content()
		Global.ProjectMenu.RESIZE_CANVAS:
			resize_canvas_dialog.popup()
		_:
			_handle_metadata(id, project_menu)


func effects_menu_id_pressed(id: int) -> void:
	if id == 0:  # Re-apply
		if is_instance_valid(last_applied_effect):
			if last_applied_effect.has_signal("confirmed"):
				last_applied_effect.confirmed.emit()
	_handle_metadata(id, effects_menu)


func _on_effects_transform_submenu_id_pressed(id: int) -> void:
	match id:
		0:
			offset_image_dialog.popup()
		1:
			mirror_image_dialog.popup()
		2:
			rotate_image_dialog.popup()
		3:
			isometric_image_dialog.popup()


func _on_effects_color_submenu_id_pressed(id: int) -> void:
	match id:
		0:
			invert_colors_dialog.popup()
		1:
			desaturate_dialog.popup()
		2:
			hsv_dialog.popup()
		3:
			adjust_brightness_saturation_dialog.popup()
		4:
			color_curves_dialog.popup()
		5:
			palettize_dialog.popup()
		6:
			posterize_dialog.popup()
		7:
			gradient_map_dialog.popup()


func _on_effects_procedural_submenu_id_pressed(id: int) -> void:
	match id:
		0:
			outline_dialog.popup()
		1:
			drop_shadow_dialog.popup()
		2:
			gradient_dialog.popup()


func _on_effects_blur_submenu_id_pressed(id: int) -> void:
	match id:
		0:
			pixelize_dialog.popup()
		1:
			gaussian_blur_dialog.popup()


func select_menu_id_pressed(id: int) -> void:
	match id:
		Global.SelectMenu.SELECT_ALL:
			Global.canvas.selection.select_all()
		Global.SelectMenu.CLEAR:
			Global.canvas.selection.clear_selection(true)
		Global.SelectMenu.RESELECT:
			Global.canvas.selection.reselect()
		Global.SelectMenu.INVERT:
			Global.canvas.selection.invert()
		Global.SelectMenu.SELECT_CEL_AREA:
			Global.canvas.selection.select_cel_rect()
		Global.SelectMenu.WRAP_STROKES:
			var state = select_menu.is_item_checked(id)
			SelectionNode.flag_tilemode = !state
			select_menu.set_item_checked(id, !state)
		_:
			_handle_metadata(id, select_menu)


func help_menu_id_pressed(id: int) -> void:
	match id:
		Global.HelpMenu.VIEW_SPLASH_SCREEN:
			_popup_dialog(get_tree().current_scene.splash_dialog)
		Global.HelpMenu.ONLINE_DOCS:
			OS.shell_open(DOCS_URL)
			SteamManager.set_achievement("ACH_ONLINE_DOCS")
		Global.HelpMenu.RESTORE_BACKUP:
			backup_dialog.popup()
		Global.HelpMenu.ISSUE_TRACKER:
			OS.shell_open(ISSUES_URL)
		Global.HelpMenu.OPEN_EDITOR_DATA_FOLDER:
			OS.shell_open(ProjectSettings.globalize_path("user://"))
		Global.HelpMenu.CHANGELOG:
			OS.shell_open(CHANGELOG_URL)
		Global.HelpMenu.ABOUT_PIXELORAMA:
			about_dialog.popup()
		Global.HelpMenu.SUPPORT_PIXELORAMA:
			OS.shell_open(SUPPORT_URL)
			SteamManager.set_achievement("ACH_SUPPORT_DEVELOPMENT")
		_:
			_handle_metadata(id, help_menu)
