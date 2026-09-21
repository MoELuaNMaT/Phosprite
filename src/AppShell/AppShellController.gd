class_name AppShellController
extends Node

signal mode_changed(mode: Mode)
signal files_import_source_requested
signal photos_import_source_requested
signal import_flow_finished(success: bool)

enum Mode { GALLERY, EDITOR }
enum NewProjectPurpose { NONE, BLANK, IMPORT_LAYER }

const Entry := preload("res://src/ProjectLibrary/ProjectLibraryEntry.gd")
const RecoveryStore := preload("res://src/ProjectLibrary/ProjectRecoveryStore.gd")
const ProjectFactoryScript := preload("res://src/ProjectLibrary/ProjectFactory.gd")
const ProjectImportServiceScript := preload("res://src/ProjectLibrary/ProjectImportService.gd")
const CanvasSizeResolverScript := preload("res://src/ProjectLibrary/CanvasSizeResolver.gd")

var managed_mode := false
var mode := Mode.EDITOR
var editor_root: Control
var gallery_root: ProjectGallery
var recovery_dialog: ConfirmationDialog
var new_project_dialog: NewProjectDialog
var import_source_dialog: ImportSourceDialog
var image_import_mode_dialog: ImageImportModeDialog
var save_coordinator: ProjectSaveCoordinator
var import_service: ProjectImportService

var pending_recovery_uuid := ""
var pending_recovery_path := ""
var pending_import_path := ""
var pending_import_image: Image
var pending_import_enter_editor := true
var pending_new_project_purpose := NewProjectPurpose.NONE


func configure(
	enabled: bool,
	editor: Control,
	gallery: ProjectGallery,
	dialog: ConfirmationDialog,
	coordinator: ProjectSaveCoordinator,
	new_project_panel: NewProjectDialog = null,
	import_source_panel: ImportSourceDialog = null,
	image_mode_panel: ImageImportModeDialog = null
) -> void:
	managed_mode = enabled
	editor_root = editor
	gallery_root = gallery
	recovery_dialog = dialog
	new_project_dialog = new_project_panel
	import_source_dialog = import_source_panel
	image_import_mode_dialog = image_mode_panel
	save_coordinator = coordinator
	if import_service == null:
		import_service = ProjectImportServiceScript.new()
	import_service.configure(save_coordinator, save_coordinator.projects_directory)
	_connect_gallery()
	_connect_recovery_dialog()
	_connect_new_project_dialog()
	_connect_import_dialogs()
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
	if not gallery_root.new_project_requested.is_connected(_on_new_project_requested):
		gallery_root.new_project_requested.connect(_on_new_project_requested)
	if not gallery_root.import_requested.is_connected(_on_import_requested):
		gallery_root.import_requested.connect(_on_import_requested)


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


func _connect_new_project_dialog() -> void:
	if not is_instance_valid(new_project_dialog):
		return
	if not new_project_dialog.create_requested.is_connected(_on_new_project_create_requested):
		new_project_dialog.create_requested.connect(_on_new_project_create_requested)
	if not new_project_dialog.canceled.is_connected(_on_new_project_canceled):
		new_project_dialog.canceled.connect(_on_new_project_canceled)


func handoff_import_path(source_path: String, enter_editor := true) -> bool:
	if not managed_mode or import_service == null:
		import_flow_finished.emit(false)
		return false
	_clear_pending_import()
	pending_import_enter_editor = enter_editor
	match import_service.classify_path(source_path):
		ProjectImportService.ImportKind.PXO:
			var project := import_service.import_pxo(source_path)
			var success := _finish_managed_import(project, source_path, enter_editor)
			import_flow_finished.emit(success)
			return success
		ProjectImportService.ImportKind.ASEPRITE:
			var project := import_service.import_aseprite(source_path)
			var success := _finish_managed_import(project, source_path, enter_editor)
			import_flow_finished.emit(success)
			return success
		ProjectImportService.ImportKind.IMAGE:
			var image := import_service.load_image(source_path)
			if image == null:
				_report_import_failure(source_path)
				import_flow_finished.emit(false)
				return false
			pending_import_path = source_path
			pending_import_image = image
			if not is_instance_valid(image_import_mode_dialog):
				_report_import_failure(source_path)
				_clear_pending_import()
				import_flow_finished.emit(false)
				return false
			Global.dialog_open(true)
			image_import_mode_dialog.popup_for_image()
			return true
		_:
			Global.popup_error(
				tr("This file type is not supported by the Project Gallery import pipeline.")
			)
			import_flow_finished.emit(false)
			return false


func _connect_import_dialogs() -> void:
	if is_instance_valid(import_source_dialog):
		if not import_source_dialog.files_requested.is_connected(_on_files_source_requested):
			import_source_dialog.files_requested.connect(_on_files_source_requested)
		if not import_source_dialog.photos_requested.is_connected(_on_photos_source_requested):
			import_source_dialog.photos_requested.connect(_on_photos_source_requested)
		if not import_source_dialog.dismissed.is_connected(_on_import_source_dismissed):
			import_source_dialog.dismissed.connect(_on_import_source_dismissed)
	if is_instance_valid(image_import_mode_dialog):
		if not image_import_mode_dialog.layer_requested.is_connected(_on_image_layer_requested):
			image_import_mode_dialog.layer_requested.connect(_on_image_layer_requested)
		if not image_import_mode_dialog.reference_requested.is_connected(
			_on_image_reference_requested
		):
			image_import_mode_dialog.reference_requested.connect(_on_image_reference_requested)
		if not image_import_mode_dialog.dismissed.is_connected(_on_image_mode_dismissed):
			image_import_mode_dialog.dismissed.connect(_on_image_mode_dismissed)


func create_new_project(canvas_size: Vector2i) -> bool:
	if not managed_mode or not is_instance_valid(save_coordinator):
		return false
	var project_name := ProjectFactoryScript.make_untitled_name()
	var target_path := ProjectFactoryScript.make_unique_project_path(
		project_name, save_coordinator.projects_directory
	)
	var project := ProjectFactoryScript.create_blank_project(project_name, canvas_size)
	Global.projects.append(project)
	project.has_changed = true

	if not save_coordinator.flush_project(project, "new_project", target_path):
		_rollback_uncommitted_project(project, target_path)
		return false

	var project_index := Global.projects.find(project)
	if project_index < 0:
		_rollback_uncommitted_project(project, target_path)
		return false
	Global.tabs.current_tab = project_index
	if Global.current_project_index != project_index:
		_rollback_uncommitted_project(project, target_path)
		return false
	show_editor()
	return true


func _rollback_uncommitted_project(project: Project, target_path: String) -> void:
	var project_index := Global.projects.find(project)
	if project_index >= 0 and project_index < Global.tabs.tab_count:
		Global.tabs.remove_tab(project_index)
	save_coordinator.forget_project(project, true)
	project.remove()
	if FileAccess.file_exists(target_path):
		DirAccess.remove_absolute(target_path)


func _on_new_project_requested() -> void:
	if not managed_mode or not is_instance_valid(new_project_dialog):
		return
	_clear_pending_import()
	pending_new_project_purpose = NewProjectPurpose.BLANK
	Global.dialog_open(true)
	new_project_dialog.popup_for_new_project()


func _on_import_requested() -> void:
	if not managed_mode or not is_instance_valid(import_source_dialog):
		return
	_clear_pending_import()
	Global.dialog_open(true)
	import_source_dialog.popup_for_import()


func _on_files_source_requested() -> void:
	Global.dialog_open(false)
	files_import_source_requested.emit()


func _on_photos_source_requested() -> void:
	Global.dialog_open(false)
	photos_import_source_requested.emit()


func _on_import_source_dismissed() -> void:
	Global.dialog_open(false)


func _on_image_layer_requested() -> void:
	if pending_import_image == null or pending_import_path.is_empty():
		_clear_pending_import()
		Global.dialog_open(false)
		import_flow_finished.emit(false)
		return
	pending_new_project_purpose = NewProjectPurpose.IMPORT_LAYER
	var inferred_size := CanvasSizeResolverScript.resolve(pending_import_image.get_size())
	new_project_dialog.popup_with_size(inferred_size)


func _on_image_reference_requested() -> void:
	if pending_import_image == null or pending_import_path.is_empty():
		_clear_pending_import()
		Global.dialog_open(false)
		import_flow_finished.emit(false)
		return
	var source_path := pending_import_path
	var image := pending_import_image
	var enter_editor := pending_import_enter_editor
	var canvas_size := CanvasSizeResolverScript.resolve(image.get_size())
	var project := import_service.import_image(
		source_path, image, ProjectImportService.ImageMode.REFERENCE, canvas_size
	)
	_clear_pending_import()
	Global.dialog_open(false)
	var success := _finish_managed_import(project, source_path, enter_editor)
	import_flow_finished.emit(success)


func _on_image_mode_dismissed() -> void:
	_clear_pending_import()
	Global.dialog_open(false)
	import_flow_finished.emit(false)


func _on_new_project_create_requested(canvas_size: Vector2i) -> void:
	Global.dialog_open(false)
	if pending_new_project_purpose == NewProjectPurpose.IMPORT_LAYER:
		var source_path := pending_import_path
		var image := pending_import_image
		var enter_editor := pending_import_enter_editor
		var project := import_service.import_image(
			source_path, image, ProjectImportService.ImageMode.LAYER, canvas_size
		)
		_clear_pending_import()
		pending_new_project_purpose = NewProjectPurpose.NONE
		var success := _finish_managed_import(project, source_path, enter_editor)
		import_flow_finished.emit(success)
		return
	pending_new_project_purpose = NewProjectPurpose.NONE
	create_new_project(canvas_size)


func _on_new_project_canceled() -> void:
	var canceled_import := pending_new_project_purpose == NewProjectPurpose.IMPORT_LAYER
	if canceled_import:
		_clear_pending_import()
	pending_new_project_purpose = NewProjectPurpose.NONE
	Global.dialog_open(false)
	if canceled_import:
		import_flow_finished.emit(false)


func _finish_managed_import(project: Project, source_path: String, enter_editor := true) -> bool:
	if project == null:
		_report_import_failure(source_path)
		return false
	var project_index := Global.projects.find(project)
	if project_index < 0:
		_report_import_failure(source_path)
		return false
	if not enter_editor:
		return true
	Global.tabs.current_tab = project_index
	if Global.current_project_index != project_index:
		_report_import_failure(source_path)
		return false
	show_editor()
	return true


func _report_import_failure(source_path: String) -> void:
	var detail := ""
	if import_service != null:
		detail = import_service.last_error
	var file_name := source_path.uri_decode().get_file()
	if detail.is_empty():
		Global.popup_error(tr("Could not import '%s'.") % file_name)
	else:
		Global.popup_error(tr("Could not import '%s'. %s") % [file_name, detail])


func _clear_pending_import() -> void:
	pending_import_path = ""
	pending_import_image = null
	pending_import_enter_editor = true
	if pending_new_project_purpose == NewProjectPurpose.IMPORT_LAYER:
		pending_new_project_purpose = NewProjectPurpose.NONE


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
			tr("Could not restore this project. Error code %s (%s)") % [error, error_string(error)]
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
			tr("Could not discard recovery data. Error code %s (%s)") % [error, error_string(error)]
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
	if (
		Global.current_project == null
		or _normalized_path(Global.current_project.save_path) != _normalized_path(path)
	):
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
