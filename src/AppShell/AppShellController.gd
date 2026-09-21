class_name AppShellController
extends Node

signal mode_changed(mode: Mode)

enum Mode { GALLERY, EDITOR }

const Entry := preload("res://src/ProjectLibrary/ProjectLibraryEntry.gd")
const RecoveryStore := preload("res://src/ProjectLibrary/ProjectRecoveryStore.gd")

var managed_mode := false
var mode := Mode.EDITOR
var editor_root: Control
var gallery_root: ProjectGallery
var recovery_dialog: ConfirmationDialog
var save_coordinator: ProjectSaveCoordinator

var pending_recovery_uuid := ""
var pending_recovery_path := ""


func configure(
	enabled: bool,
	editor: Control,
	gallery: ProjectGallery,
	dialog: ConfirmationDialog,
	coordinator: ProjectSaveCoordinator
) -> void:
	managed_mode = enabled
	editor_root = editor
	gallery_root = gallery
	recovery_dialog = dialog
	save_coordinator = coordinator
	_connect_gallery()
	_connect_recovery_dialog()
	if managed_mode:
		_set_mode(Mode.GALLERY)
	else:
		_set_mode(Mode.EDITOR)


func startup() -> void:
	if managed_mode:
		show_gallery(true)
	else:
		_set_mode(Mode.EDITOR)


func is_gallery() -> bool:
	return mode == Mode.GALLERY


func show_gallery(refresh := true) -> bool:
	if not managed_mode:
		return false
	if refresh and is_instance_valid(gallery_root):
		gallery_root.refresh()
		gallery_root.reset_scroll_position()
	_set_mode(Mode.GALLERY)
	return true


func show_editor() -> void:
	_set_mode(Mode.EDITOR)


func return_home() -> bool:
	if not managed_mode:
		return false
	if is_instance_valid(save_coordinator) and not save_coordinator.flush_before_leaving_editor():
		return false
	return show_gallery(true)


func open_project_path(path: String) -> bool:
	if not managed_mode:
		OpenSave.handle_loading_file(path)
		return true
	var existing_index := _find_open_project(path)
	if existing_index >= 0:
		Global.current_project_index = existing_index
		if Global.current_project_index != existing_index:
			return false
		show_editor()
		return true
	if not is_instance_valid(gallery_root):
		return false
	var entry := gallery_root.find_entry(path)
	if entry == null:
		gallery_root.refresh()
		entry = gallery_root.find_entry(path)
	if entry == null:
		return false
	if entry.health_state != Entry.HealthState.OK:
		Global.popup_error(tr("This project could not be opened because its file is corrupted."))
		return false
	if entry.has_pending_recovery:
		_show_recovery_prompt(entry)
		return false
	return _open_formal_project(entry.path)


func _connect_gallery() -> void:
	if not is_instance_valid(gallery_root):
		return
	if not gallery_root.project_open_requested.is_connected(open_project_path):
		gallery_root.project_open_requested.connect(open_project_path)


func _connect_recovery_dialog() -> void:
	if not is_instance_valid(recovery_dialog):
		return
	if not recovery_dialog.confirmed.is_connected(_on_restore_requested):
		recovery_dialog.confirmed.connect(_on_restore_requested)
	if not recovery_dialog.custom_action.is_connected(_on_recovery_custom_action):
		recovery_dialog.custom_action.connect(_on_recovery_custom_action)
	if not recovery_dialog.canceled.is_connected(_on_recovery_canceled):
		recovery_dialog.canceled.connect(_on_recovery_canceled)
	if not recovery_dialog.has_meta("p3_discard_button"):
		recovery_dialog.add_button(tr("Discard"), false, "Discard")
		recovery_dialog.set_meta("p3_discard_button", true)


func _show_recovery_prompt(entry: ProjectLibraryEntry) -> void:
	pending_recovery_uuid = entry.uuid
	pending_recovery_path = entry.path
	recovery_dialog.dialog_text = tr(
		"Phosprite found recovery data for this project. Restore it before opening the project?"
	)
	Global.dialog_open(true)
	recovery_dialog.popup_centered_clamped()


func _on_restore_requested() -> void:
	var project_uuid := pending_recovery_uuid
	var project_path := pending_recovery_path
	if project_uuid.is_empty() or project_path.is_empty():
		_clear_pending_recovery()
		Global.dialog_open(false)
		return
	var error := RecoveryStore.restore_to_project(project_uuid, project_path)
	if error != OK:
		Global.popup_error(
			tr("Could not restore this project. Error code %s (%s)")
			% [error, error_string(error)]
		)
		Global.dialog_open(false)
		return
	_clear_pending_recovery()
	Global.dialog_open(false)
	_open_formal_project(project_path)


func _on_recovery_custom_action(action: StringName) -> void:
	if action != &"Discard":
		return
	var project_uuid := pending_recovery_uuid
	var project_path := pending_recovery_path
	if project_uuid.is_empty() or project_path.is_empty():
		_clear_pending_recovery()
		Global.dialog_open(false)
		return
	var error := RecoveryStore.discard(project_uuid)
	if error != OK:
		Global.popup_error(
			tr("Could not discard recovery data. Error code %s (%s)")
			% [error, error_string(error)]
		)
		Global.dialog_open(false)
		return
	_clear_pending_recovery()
	recovery_dialog.hide()
	Global.dialog_open(false)
	_open_formal_project(project_path)


func _on_recovery_canceled() -> void:
	# Cancel is intentionally non-destructive. The same project must ask again next time.
	_clear_pending_recovery()
	Global.dialog_open(false)


func _open_formal_project(path: String) -> bool:
	OpenSave.open_pxo_file(path)
	if Global.current_project == null or _normalized_path(Global.current_project.save_path) != _normalized_path(path):
		return false
	show_editor()
	return true


func _find_open_project(path: String) -> int:
	var normalized := _normalized_path(path)
	for index in Global.projects.size():
		var project := Global.projects[index]
		if _normalized_path(project.save_path) == normalized:
			return index
	return -1


func _set_mode(next_mode: Mode) -> void:
	mode = next_mode
	if is_instance_valid(editor_root):
		editor_root.visible = mode == Mode.EDITOR
	if is_instance_valid(gallery_root):
		gallery_root.visible = mode == Mode.GALLERY
	mode_changed.emit(mode)


func _clear_pending_recovery() -> void:
	pending_recovery_uuid = ""
	pending_recovery_path = ""


func _normalized_path(path: String) -> String:
	if path.is_empty():
		return ""
	return ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()
