class_name ProjectGallery
extends Control

signal project_open_requested(path: String)
signal new_project_requested
signal import_requested
signal exit_multiselect_requested
signal project_renamed(old_path: String, new_path: String, new_name: String)
signal projects_deleted(paths: PackedStringArray)
signal reveal_in_files_requested(path: String)
signal export_projects_requested(paths: PackedStringArray)

const StoragePolicy := preload("res://src/PlatformServices/StoragePolicy.gd")
const ProjectLibraryScript := preload("res://src/ProjectLibrary/ProjectLibrary.gd")
const GestureResolverScript := preload(
	"res://src/UI/ProjectGallery/ProjectCardGestureResolver.gd"
)
const CARD_SCENE := preload("res://src/UI/ProjectGallery/ProjectGalleryCard.tscn")

const LANDSCAPE_COLUMNS := 6
const PORTRAIT_COLUMNS := 4
const GRID_SIDE_MARGIN := 32.0
const GRID_SEPARATION := 16.0
const THUMBNAIL_PRELOAD_MARGIN := 96.0

enum ActionMenuId { RENAME = 1, DUPLICATE, DELETE, EXPORT, REVEAL }

var library: ProjectLibrary
var entries: Array[ProjectLibraryEntry] = []
var refresh_count := 0
var scroll_reset_count := 0
var multiselect_mode := false

var _cards: Array[ProjectGalleryCard] = []
var _selected_paths: Dictionary = {}
var _gesture_resolver := GestureResolverScript.new()
var _action_path := ""
var _rename_source_path := ""
var _pending_delete_paths := PackedStringArray()
var _delete_was_multiselect := false

@onready var scroll_container := %ProjectScroll as ScrollContainer
@onready var grid := %ProjectGrid as GridContainer
@onready var empty_state := %EmptyState as Label
@onready var exit_multiselect_button := %ExitMultiSelect as Button
@onready var project_action_menu := %ProjectActionMenu as PopupMenu
@onready var batch_action_menu := %BatchActionMenu as PopupMenu
@onready var rename_dialog := %RenameProjectDialog as ConfirmationDialog
@onready var rename_edit := %RenameProjectEdit as LineEdit
@onready var delete_dialog := %DeleteProjectsDialog as ConfirmationDialog


func _ready() -> void:
	if library == null:
		library = ProjectLibraryScript.new(StoragePolicy.PROJECTS_DIRECTORY)
	if not resized.is_connected(_on_gallery_resized):
		resized.connect(_on_gallery_resized)
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	var vertical_scroll := scroll_container.get_v_scroll_bar()
	if not vertical_scroll.value_changed.is_connected(_on_scroll_changed):
		vertical_scroll.value_changed.connect(_on_scroll_changed)
	if not project_action_menu.id_pressed.is_connected(_on_project_action_pressed):
		project_action_menu.id_pressed.connect(_on_project_action_pressed)
	if not batch_action_menu.id_pressed.is_connected(_on_batch_action_pressed):
		batch_action_menu.id_pressed.connect(_on_batch_action_pressed)
	if not rename_dialog.confirmed.is_connected(_on_rename_confirmed):
		rename_dialog.confirmed.connect(_on_rename_confirmed)
	if not rename_dialog.canceled.is_connected(_on_rename_canceled):
		rename_dialog.canceled.connect(_on_rename_canceled)
	if not delete_dialog.confirmed.is_connected(_on_delete_confirmed):
		delete_dialog.confirmed.connect(_on_delete_confirmed)
	if not delete_dialog.canceled.is_connected(_on_delete_canceled):
		delete_dialog.canceled.connect(_on_delete_canceled)
	call_deferred("_update_layout")


func _process(_delta: float) -> void:
	if not visible:
		return
	_consume_gesture_actions(_gesture_resolver.poll(Time.get_ticks_msec()))


func configure(directory := StoragePolicy.PROJECTS_DIRECTORY) -> void:
	library = ProjectLibraryScript.new(directory)


func refresh() -> Array[ProjectLibraryEntry]:
	if library == null:
		library = ProjectLibraryScript.new(StoragePolicy.PROJECTS_DIRECTORY)
	entries = library.scan(false)
	refresh_count += 1
	_prune_selection()
	_rebuild_cards()
	return entries


func reset_scroll_position() -> void:
	scroll_container.scroll_horizontal = 0
	scroll_container.scroll_vertical = 0
	scroll_reset_count += 1
	call_deferred("_load_visible_thumbnails")


func find_entry(path: String) -> ProjectLibraryEntry:
	var normalized := _normalized_path(path)
	for entry: ProjectLibraryEntry in entries:
		if _normalized_path(entry.path) == normalized:
			return entry
	return null


func request_open(path: String) -> void:
	project_open_requested.emit(path)


func set_multiselect_mode(enabled: bool) -> void:
	multiselect_mode = enabled
	exit_multiselect_button.visible = enabled
	_gesture_resolver.reset()
	project_action_menu.hide()
	batch_action_menu.hide()
	if not enabled:
		_selected_paths.clear()
	_sync_card_selection()


func get_selected_paths() -> PackedStringArray:
	var selected := PackedStringArray()
	for entry: ProjectLibraryEntry in entries:
		if _selected_paths.has(_normalized_path(entry.path)):
			selected.append(entry.path)
	return selected


func rename_project(path: String, new_name: String) -> Dictionary:
	var result := library.rename_project(path, new_name)
	if not bool(result.get("ok", false)):
		return result
	var new_path := str(result.get("path", path))
	var final_name := str(result.get("name", new_name))
	_replace_selected_path(path, new_path)
	project_renamed.emit(path, new_path, final_name)
	refresh()
	return result


func duplicate_projects(paths: PackedStringArray) -> Dictionary:
	var created := PackedStringArray()
	var errors: Array[Dictionary] = []
	for path in paths:
		var result := library.duplicate_project(path)
		if bool(result.get("ok", false)):
			created.append(str(result.get("path", "")))
		else:
			errors.append({"path": path, "error": int(result.get("error", FAILED))})
	if not created.is_empty():
		refresh()
	return {"created": created, "errors": errors}


func delete_projects(paths: PackedStringArray) -> Dictionary:
	var deleted := PackedStringArray()
	var errors: Array[Dictionary] = []
	for path in paths:
		var entry := find_entry(path)
		var project_uuid := "" if entry == null else entry.uuid
		var error := library.delete_project(path, project_uuid)
		if error == OK:
			deleted.append(path)
			_selected_paths.erase(_normalized_path(path))
		else:
			errors.append({"path": path, "error": error})
	if not deleted.is_empty():
		projects_deleted.emit(deleted)
		refresh()
	return {"deleted": deleted, "errors": errors}


func _rebuild_cards() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	_cards.clear()

	for entry: ProjectLibraryEntry in entries:
		var card := CARD_SCENE.instantiate() as ProjectGalleryCard
		if card == null:
			continue
		grid.add_child(card)
		card.bind(entry)
		card.set_selected(_selected_paths.has(_normalized_path(entry.path)))
		card.pointer_down.connect(_on_card_pointer_down)
		card.pointer_up.connect(_on_card_pointer_up)
		card.pointer_cancel.connect(_on_card_pointer_cancel)
		_cards.append(card)

	empty_state.visible = entries.is_empty()
	call_deferred("_update_layout")
	call_deferred("_load_visible_thumbnails")


func _update_layout() -> void:
	if not is_instance_valid(grid) or not is_instance_valid(scroll_container):
		return
	var columns := LANDSCAPE_COLUMNS if size.x >= size.y else PORTRAIT_COLUMNS
	grid.columns = columns
	var available_width := maxf(scroll_container.size.x - GRID_SIDE_MARGIN * 2.0, 1.0)
	var separators := GRID_SEPARATION * float(columns - 1)
	var card_width := maxf(floorf((available_width - separators) / float(columns)), 72.0)
	for card: ProjectGalleryCard in _cards:
		card.set_card_width(card_width)
	call_deferred("_load_visible_thumbnails")


func _load_visible_thumbnails() -> void:
	if not visible or library == null or not is_instance_valid(scroll_container):
		return
	var visible_rect := scroll_container.get_global_rect().grow(THUMBNAIL_PRELOAD_MARGIN)
	for card: ProjectGalleryCard in _cards:
		if card.thumbnail_loaded or card.entry == null:
			continue
		if not visible_rect.intersects(card.get_global_rect()):
			continue
		card.set_thumbnail(library.load_thumbnail(card.entry))


func _consume_gesture_actions(actions: Array[Dictionary]) -> void:
	for action: Dictionary in actions:
		var path := str(action.get("path", ""))
		if path.is_empty() or find_entry(path) == null:
			continue
		var kind := int(action.get("kind", -1))
		var position: Vector2 = action.get("position", Vector2.ZERO)
		match kind:
			GestureResolverScript.ActionKind.SINGLE_TAP:
				_on_resolved_single_tap(path)
			GestureResolverScript.ActionKind.DOUBLE_TAP:
				_on_resolved_double_tap(path, position)
			GestureResolverScript.ActionKind.LONG_PRESS:
				_on_resolved_long_press(path)


func _on_resolved_single_tap(path: String) -> void:
	if multiselect_mode:
		_set_path_selected(path, not _selected_paths.has(_normalized_path(path)))
		return
	project_open_requested.emit(path)


func _on_resolved_double_tap(path: String, position: Vector2) -> void:
	if multiselect_mode:
		var selected := get_selected_paths()
		if selected.is_empty():
			return
		_show_batch_action_menu(position)
		return
	_show_project_action_menu(path, position)


func _on_resolved_long_press(path: String) -> void:
	if not multiselect_mode:
		set_multiselect_mode(true)
	_set_path_selected(path, true)


func _show_project_action_menu(path: String, position: Vector2) -> void:
	var entry := find_entry(path)
	if entry == null:
		return
	_action_path = path
	project_action_menu.clear()
	if entry.health_state == ProjectLibraryEntry.HealthState.OK:
		project_action_menu.add_item(tr("Rename"), ActionMenuId.RENAME)
		project_action_menu.add_item(tr("Duplicate"), ActionMenuId.DUPLICATE)
		project_action_menu.add_item(tr("Delete"), ActionMenuId.DELETE)
		project_action_menu.add_separator()
		project_action_menu.add_item(tr("Export"), ActionMenuId.EXPORT)
		project_action_menu.add_item(tr("Reveal in Files"), ActionMenuId.REVEAL)
	else:
		project_action_menu.add_item(tr("Delete"), ActionMenuId.DELETE)
		project_action_menu.add_item(tr("Reveal in Files"), ActionMenuId.REVEAL)
	_popup_near(project_action_menu, position)


func _show_batch_action_menu(position: Vector2) -> void:
	batch_action_menu.clear()
	if _selected_all_healthy():
		batch_action_menu.add_item(tr("Duplicate"), ActionMenuId.DUPLICATE)
	batch_action_menu.add_item(tr("Delete"), ActionMenuId.DELETE)
	if _selected_all_healthy():
		batch_action_menu.add_item(tr("Export"), ActionMenuId.EXPORT)
	_popup_near(batch_action_menu, position)


func _popup_near(menu: PopupMenu, position: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	var x := clampi(roundi(position.x), 0, maxi(roundi(viewport_size.x) - 1, 0))
	var y := clampi(roundi(position.y), 0, maxi(roundi(viewport_size.y) - 1, 0))
	menu.position = Vector2i(x, y)
	menu.popup()


func _selected_all_healthy() -> bool:
	var selected := get_selected_paths()
	if selected.is_empty():
		return false
	for path in selected:
		var entry := find_entry(path)
		if entry == null or entry.health_state != ProjectLibraryEntry.HealthState.OK:
			return false
	return true


func _set_path_selected(path: String, value: bool) -> void:
	var normalized := _normalized_path(path)
	if value:
		_selected_paths[normalized] = path
	else:
		_selected_paths.erase(normalized)
	_sync_card_selection()


func _sync_card_selection() -> void:
	for card: ProjectGalleryCard in _cards:
		if card.entry == null:
			continue
		card.set_selected(_selected_paths.has(_normalized_path(card.entry.path)))


func _prune_selection() -> void:
	var valid_paths: Dictionary = {}
	for entry: ProjectLibraryEntry in entries:
		valid_paths[_normalized_path(entry.path)] = true
	for normalized in _selected_paths.keys():
		if not valid_paths.has(normalized):
			_selected_paths.erase(normalized)


func _replace_selected_path(old_path: String, new_path: String) -> void:
	var old_normalized := _normalized_path(old_path)
	if not _selected_paths.has(old_normalized):
		return
	_selected_paths.erase(old_normalized)
	_selected_paths[_normalized_path(new_path)] = new_path


func _on_card_pointer_down(path: String, position: Vector2, timestamp_msec: int) -> void:
	_consume_gesture_actions(_gesture_resolver.pointer_down(path, position, timestamp_msec))


func _on_card_pointer_up(path: String, position: Vector2, timestamp_msec: int) -> void:
	_consume_gesture_actions(_gesture_resolver.pointer_up(path, position, timestamp_msec))


func _on_card_pointer_cancel(path: String) -> void:
	_gesture_resolver.pointer_cancel(path)


func _on_project_action_pressed(id: int) -> void:
	if _action_path.is_empty():
		return
	match id:
		ActionMenuId.RENAME:
			_begin_rename(_action_path)
		ActionMenuId.DUPLICATE:
			_report_action_errors(duplicate_projects(PackedStringArray([_action_path])))
		ActionMenuId.DELETE:
			_begin_delete(PackedStringArray([_action_path]), false)
		ActionMenuId.EXPORT:
			export_projects_requested.emit(PackedStringArray([_action_path]))
		ActionMenuId.REVEAL:
			reveal_in_files_requested.emit(_action_path)


func _on_batch_action_pressed(id: int) -> void:
	var selected := get_selected_paths()
	if selected.is_empty():
		return
	match id:
		ActionMenuId.DUPLICATE:
			_report_action_errors(duplicate_projects(selected))
		ActionMenuId.DELETE:
			_begin_delete(selected, true)
		ActionMenuId.EXPORT:
			export_projects_requested.emit(selected)


func _begin_rename(path: String) -> void:
	var entry := find_entry(path)
	if entry == null or entry.health_state != ProjectLibraryEntry.HealthState.OK:
		return
	_rename_source_path = path
	rename_edit.text = path.get_file().get_basename()
	rename_edit.select_all()
	Global.dialog_open(true)
	rename_dialog.popup_centered(Vector2i(420, 150))
	rename_edit.grab_focus()


func _on_rename_confirmed() -> void:
	var source_path := _rename_source_path
	_rename_source_path = ""
	Global.dialog_open(false)
	if source_path.is_empty():
		return
	var result := rename_project(source_path, rename_edit.text)
	if bool(result.get("ok", false)):
		return
	var error := int(result.get("error", FAILED))
	if error == ERR_ALREADY_EXISTS:
		Global.popup_error(tr("A project with this name already exists."))
	elif error == ERR_INVALID_PARAMETER:
		Global.popup_error(tr("Project names cannot be empty or contain unsupported characters."))
	else:
		Global.popup_error(
			tr("Could not rename this project. Error code %s (%s)")
			% [error, error_string(error)]
		)


func _on_rename_canceled() -> void:
	_rename_source_path = ""
	Global.dialog_open(false)


func _begin_delete(paths: PackedStringArray, from_multiselect: bool) -> void:
	if paths.is_empty():
		return
	_pending_delete_paths = paths.duplicate()
	_delete_was_multiselect = from_multiselect
	if paths.size() == 1:
		delete_dialog.dialog_text = tr("Permanently delete this project? This cannot be undone.")
	else:
		delete_dialog.dialog_text = (
			tr("Permanently delete %d projects? This cannot be undone.") % paths.size()
		)
	Global.dialog_open(true)
	delete_dialog.popup_centered_clamped()


func _on_delete_confirmed() -> void:
	var paths := _pending_delete_paths.duplicate()
	var was_multiselect := _delete_was_multiselect
	_pending_delete_paths.clear()
	_delete_was_multiselect = false
	Global.dialog_open(false)
	var result := delete_projects(paths)
	_report_action_errors(result)
	if was_multiselect:
		set_multiselect_mode(false)


func _on_delete_canceled() -> void:
	_pending_delete_paths.clear()
	_delete_was_multiselect = false
	Global.dialog_open(false)


func _report_action_errors(result: Dictionary) -> void:
	var errors: Array = result.get("errors", [])
	if errors.is_empty():
		return
	Global.popup_error(tr("One or more project operations could not be completed."))


func _on_gallery_resized() -> void:
	call_deferred("_update_layout")


func _on_scroll_changed(_value: float) -> void:
	call_deferred("_load_visible_thumbnails")


func _on_visibility_changed() -> void:
	if not visible:
		_gesture_resolver.reset()
		project_action_menu.hide()
		batch_action_menu.hide()


func _on_new_project_pressed() -> void:
	new_project_requested.emit()


func _on_import_pressed() -> void:
	import_requested.emit()


func _on_exit_multiselect_pressed() -> void:
	set_multiselect_mode(false)
	exit_multiselect_requested.emit()


func _normalized_path(path: String) -> String:
	return ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()
