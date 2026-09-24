class_name WorkspaceUIProfileController
extends Node

## Owns the four top-level UI profile slots.
##
## A profile is intentionally broader than a Workspace preset: each slot has its
## own persisted Workspace snapshot and also passes through
## WorkspaceEditorMigration.activate_ui_profile(), which is the extension point
## for future profile-specific UI implementations.

signal profile_changed(profile_id: int)

var menu: PopupMenu
var migration: WorkspaceEditorMigration
var store: WorkspaceLayoutStore

var _setup_complete := false


func setup(
	ui_menu: PopupMenu,
	editor_migration: WorkspaceEditorMigration,
	layout_store: WorkspaceLayoutStore
) -> bool:
	if _setup_complete or ui_menu == null or editor_migration == null or layout_store == null:
		return false
	if not editor_migration.live or editor_migration.layout_store != layout_store:
		return false

	menu = ui_menu
	migration = editor_migration
	store = layout_store
	if not migration.activate_ui_profile(store.get_active_layout_slot()):
		_clear_setup()
		return false

	menu.clear()
	for profile_id in range(1, WorkspaceLayoutStore.LAYOUT_SLOT_COUNT + 1):
		menu.add_radio_check_item(str(profile_id), profile_id)
	menu.id_pressed.connect(_on_menu_id_pressed)
	_sync_menu()
	_setup_complete = true
	return true


func switch_profile(profile_id: int) -> bool:
	if not _setup_complete or profile_id < 1 or profile_id > WorkspaceLayoutStore.LAYOUT_SLOT_COUNT:
		return false
	var previous_profile := store.get_active_layout_slot()
	if profile_id == previous_profile:
		_sync_menu()
		return true

	if not store.flush_pending_autosave():
		return false
	var rollback_snapshot := store.capture_snapshot()
	var seed_snapshot := store.get_layout_slot_snapshot(previous_profile)
	if seed_snapshot.is_empty():
		seed_snapshot = rollback_snapshot.duplicate(true)

	if not migration.activate_ui_profile(profile_id):
		return false
	if not store.set_active_layout_slot(profile_id):
		migration.activate_ui_profile(previous_profile)
		return false

	var applied := false
	if store.has_layout_slot(profile_id):
		applied = store.restore_current_layout()
	else:
		# A never-used slot starts as a copy of the profile the user came from,
		# then becomes independent as soon as it is saved.
		applied = store.apply_snapshot(seed_snapshot)

	if applied:
		migration.sync_workspace_content_visibility()
		applied = store.save_current_layout()

	if not applied:
		migration.activate_ui_profile(previous_profile)
		store.set_active_layout_slot(previous_profile)
		store.apply_snapshot(rollback_snapshot)
		migration.sync_workspace_content_visibility()
		store.save_current_layout()
		_sync_menu()
		return false

	_sync_menu()
	profile_changed.emit(profile_id)
	return true


func _on_menu_id_pressed(profile_id: int) -> void:
	switch_profile(profile_id)


func _sync_menu() -> void:
	if menu == null or store == null:
		return
	var active_profile := store.get_active_layout_slot()
	for index in menu.item_count:
		var item_id := menu.get_item_id(index)
		menu.set_item_checked(index, item_id == active_profile)


func _clear_setup() -> void:
	menu = null
	migration = null
	store = null
	_setup_complete = false
