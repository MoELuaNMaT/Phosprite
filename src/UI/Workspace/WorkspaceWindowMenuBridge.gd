class_name WorkspaceWindowMenuBridge
extends Node

## Reuses the existing Window/Panels/Layouts UI while routing live P2-G state
## through Workspace instead of DockableContainer/DockableLayout.

const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const LAYOUT_ADD_ID := 1000
const LAYOUT_DELETE_ID := 1001
const LAYOUT_RESET_ID := 1002
const CURRENT_WORKSPACE := "__current_workspace__"

var top_menu: Control
var migration: WorkspaceEditorMigration
var store: WorkspaceLayoutStore
var manager: WorkspaceModuleManager
var surface: WorkspaceSurface

var window_menu: PopupMenu
var panels_submenu: PopupMenu
var layouts_submenu: PopupMenu
var add_layout_confirmation: ConfirmationDialog
var delete_layout_confirmation: ConfirmationDialog
var layout_name_line_edit: LineEdit
var layout_from_option_button: OptionButton

var _selected_preset := CURRENT_WORKSPACE
var _preset_ids: Dictionary = {}
var _setup_complete := false


func setup(
	menu_root: Control, editor_migration: WorkspaceEditorMigration, layout_store: WorkspaceLayoutStore
) -> bool:
	if _setup_complete or menu_root == null or editor_migration == null or layout_store == null:
		return false
	if not editor_migration.live or editor_migration.surface == null:
		return false
	top_menu = menu_root
	migration = editor_migration
	store = layout_store
	manager = migration.manager
	surface = migration.surface
	if not _resolve_controls():
		_clear_setup()
		return false
	_disconnect_legacy_handlers()
	_connect_workspace_handlers()
	_rebuild_panels_menu()
	_rebuild_layouts_menu()
	_prepare_layout_dialog()
	_set_moveable_panels_indicator()
	_setup_complete = true
	return true


func refresh() -> void:
	if not _setup_complete:
		return
	_rebuild_panels_menu()
	_rebuild_layouts_menu()


func _resolve_controls() -> bool:
	window_menu = top_menu.get("window_menu") as PopupMenu
	panels_submenu = top_menu.get("panels_submenu") as PopupMenu
	layouts_submenu = top_menu.get("layouts_submenu") as PopupMenu
	add_layout_confirmation = top_menu.get("add_layout_confirmation") as ConfirmationDialog
	delete_layout_confirmation = top_menu.get("delete_layout_confirmation") as ConfirmationDialog
	layout_name_line_edit = top_menu.get("layout_name_line_edit") as LineEdit
	layout_from_option_button = top_menu.get("layout_from_option_button") as OptionButton
	return (
		window_menu != null
		and panels_submenu != null
		and layouts_submenu != null
		and add_layout_confirmation != null
		and delete_layout_confirmation != null
		and layout_name_line_edit != null
		and layout_from_option_button != null
	)


func _disconnect_legacy_handlers() -> void:
	_disconnect_if_connected(window_menu.id_pressed, Callable(top_menu, "window_menu_id_pressed"))
	_disconnect_if_connected(
		panels_submenu.id_pressed, Callable(top_menu, "_panels_submenu_id_pressed")
	)
	_disconnect_if_connected(
		layouts_submenu.id_pressed, Callable(top_menu, "_layouts_submenu_id_pressed")
	)
	_disconnect_if_connected(
		add_layout_confirmation.confirmed,
		Callable(top_menu, "_on_add_layout_confirmation_confirmed")
	)
	_disconnect_if_connected(
		delete_layout_confirmation.confirmed,
		Callable(top_menu, "_on_delete_layout_confirmation_confirmed")
	)
	for connection: Dictionary in Global.pixelorama_opened.get_connections():
		var callable := connection.get("callable") as Callable
		if (
			callable.is_valid()
			and callable.get_object() == top_menu
			and callable.get_method() == &"set_layout"
		):
			Global.pixelorama_opened.disconnect(callable)


func _connect_workspace_handlers() -> void:
	window_menu.id_pressed.connect(_on_window_menu_id_pressed)
	panels_submenu.id_pressed.connect(_on_panels_submenu_id_pressed)
	layouts_submenu.id_pressed.connect(_on_layouts_submenu_id_pressed)
	add_layout_confirmation.confirmed.connect(_on_add_layout_confirmed)
	delete_layout_confirmation.confirmed.connect(_on_delete_layout_confirmed)
	migration.panel_visibility_changed.connect(_on_panel_visibility_changed)
	store.preset_saved.connect(_on_preset_changed)
	store.preset_deleted.connect(_on_preset_changed)
	store.preset_loaded.connect(_on_preset_loaded)


func _disconnect_if_connected(signal_object: Signal, callable: Callable) -> void:
	if signal_object.is_connected(callable):
		signal_object.disconnect(callable)


func _on_window_menu_id_pressed(id: int) -> void:
	match id:
		Global.WindowMenu.MOVABLE_PANELS:
			_set_moveable_panels_indicator()
		Global.WindowMenu.ZEN_MODE:
			var enabled := not migration.is_zen_mode()
			migration.set_zen_mode(enabled)
			var main_node := top_menu.get("main") as Node
			var tabs := main_node.find_child("TabsContainer") as Control if main_node != null else null
			if tabs != null:
				tabs.visible = not enabled
			window_menu.set_item_checked(Global.WindowMenu.ZEN_MODE, enabled)
		_:
			top_menu.call(&"window_menu_id_pressed", id)


func _set_moveable_panels_indicator() -> void:
	window_menu.set_item_checked(Global.WindowMenu.MOVABLE_PANELS, true)
	window_menu.set_item_disabled(Global.WindowMenu.MOVABLE_PANELS, true)
	window_menu.set_item_tooltip(
		Global.WindowMenu.MOVABLE_PANELS, tr("Workspace panels are always moveable")
	)


func _rebuild_panels_menu() -> void:
	panels_submenu.clear()
	panels_submenu.hide_on_checkable_item_selection = false
	for module_id in migration.get_panel_ids():
		if module_id == Builtins.TILES_ID or module_id == Builtins.OBJECT_TREE_3D_ID:
			continue
		var item_id := panels_submenu.item_count
		panels_submenu.add_check_item(migration.get_panel_name(module_id), item_id)
		var index := panels_submenu.get_item_index(item_id)
		panels_submenu.set_item_metadata(index, module_id)
		panels_submenu.set_item_checked(index, migration.is_panel_visible(module_id))


func _on_panels_submenu_id_pressed(id: int) -> void:
	if migration.is_zen_mode():
		return
	var index := panels_submenu.get_item_index(id)
	if index < 0:
		return
	var module_id := panels_submenu.get_item_metadata(index) as StringName
	if module_id == &"":
		return
	var was_visible := panels_submenu.is_item_checked(index)
	var target_visible := not was_visible
	if migration.set_panel_visible(module_id, target_visible):
		panels_submenu.set_item_checked(index, target_visible)


func _on_panel_visibility_changed(module_id: StringName, visible: bool) -> void:
	for index in panels_submenu.item_count:
		if panels_submenu.get_item_metadata(index) as StringName == module_id:
			panels_submenu.set_item_checked(index, visible)
			return


func _rebuild_layouts_menu() -> void:
	layouts_submenu.clear()
	layouts_submenu.hide_on_checkable_item_selection = false
	_preset_ids.clear()
	layouts_submenu.add_radio_check_item(tr("Default"), 0)
	layouts_submenu.set_item_metadata(0, "")
	var next_id := 1
	for preset_name in store.list_presets():
		layouts_submenu.add_radio_check_item(preset_name, next_id)
		var index := layouts_submenu.get_item_index(next_id)
		layouts_submenu.set_item_metadata(index, preset_name)
		_preset_ids[next_id] = preset_name
		next_id += 1
	layouts_submenu.add_separator()
	layouts_submenu.add_item(tr("Add Layout"), LAYOUT_ADD_ID)
	layouts_submenu.add_item(_delete_label(), LAYOUT_DELETE_ID)
	layouts_submenu.add_item(_reset_label(), LAYOUT_RESET_ID)
	_sync_layout_selection()


func _sync_layout_selection() -> void:
	for index in layouts_submenu.item_count:
		var id := layouts_submenu.get_item_id(index)
		if id == LAYOUT_ADD_ID or id == LAYOUT_DELETE_ID or id == LAYOUT_RESET_ID:
			continue
		var name := str(layouts_submenu.get_item_metadata(index))
		layouts_submenu.set_item_checked(
			index, _selected_preset != CURRENT_WORKSPACE and name == _selected_preset
		)
	var delete_index := layouts_submenu.get_item_index(LAYOUT_DELETE_ID)
	if delete_index >= 0:
		layouts_submenu.set_item_disabled(delete_index, not _has_named_preset())
		layouts_submenu.set_item_text(delete_index, _delete_label())
	var reset_index := layouts_submenu.get_item_index(LAYOUT_RESET_ID)
	if reset_index >= 0:
		layouts_submenu.set_item_text(reset_index, _reset_label())


func _on_layouts_submenu_id_pressed(id: int) -> void:
	if id == LAYOUT_ADD_ID:
		layout_name_line_edit.text = tr("New layout")
		add_layout_confirmation.popup_centered_clamped()
		return
	if id == LAYOUT_DELETE_ID:
		if _has_named_preset():
			delete_layout_confirmation.popup_centered_clamped()
		return
	if id == LAYOUT_RESET_ID:
		_reset_selected_layout()
		return
	if id == 0:
		if migration.reset_default_layout():
			_selected_preset = ""
			_sync_content_visibility()
			_sync_layout_selection()
			_rebuild_panels_menu()
		return
	if not _preset_ids.has(id):
		return
	var preset_name := str(_preset_ids[id])
	if store.load_preset(preset_name):
		_selected_preset = preset_name
		_sync_content_visibility()
		_sync_layout_selection()
		_rebuild_panels_menu()


func _prepare_layout_dialog() -> void:
	layout_from_option_button.clear()
	layout_from_option_button.add_item(tr("Current Workspace"))
	layout_from_option_button.selected = 0
	layout_from_option_button.disabled = true


func _on_add_layout_confirmed() -> void:
	var preset_name := layout_name_line_edit.text.strip_edges()
	if preset_name.is_empty():
		return
	if store.save_preset(preset_name):
		_selected_preset = preset_name
		_rebuild_layouts_menu()


func _on_delete_layout_confirmed() -> void:
	if not _has_named_preset():
		return
	if store.delete_preset(_selected_preset):
		_selected_preset = CURRENT_WORKSPACE
		_rebuild_layouts_menu()


func _reset_selected_layout() -> void:
	var reset := false
	if not _has_named_preset():
		reset = migration.reset_default_layout()
		if reset:
			_selected_preset = ""
	else:
		reset = store.load_preset(_selected_preset)
	if reset:
		_sync_content_visibility()
		_sync_layout_selection()
		_rebuild_panels_menu()


func _sync_content_visibility() -> void:
	for module_id in migration.get_panel_ids():
		var module := manager.get_instance(module_id)
		if module == null or module.get_content() == null:
			continue
		module.get_content().visible = (
			surface.get_module_placement(module_id) != WorkspaceSurface.Placement.NONE
		)


func _has_named_preset() -> bool:
	return not _selected_preset.is_empty() and _selected_preset != CURRENT_WORKSPACE


func _delete_label() -> String:
	if not _has_named_preset():
		return tr("Delete Layout")
	return tr("Delete %s") % _selected_preset


func _reset_label() -> String:
	var display_name := tr("Default") if not _has_named_preset() else _selected_preset
	return tr("Reset %s") % display_name


func _on_preset_changed(_preset_name: String) -> void:
	_rebuild_layouts_menu()


func _on_preset_loaded(preset_name: String) -> void:
	_selected_preset = preset_name
	_sync_content_visibility()
	_sync_layout_selection()
	_rebuild_panels_menu()


func _clear_setup() -> void:
	top_menu = null
	migration = null
	store = null
	manager = null
	surface = null
