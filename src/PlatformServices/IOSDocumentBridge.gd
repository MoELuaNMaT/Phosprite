class_name IOSDocumentBridge
extends Node

const SINGLETON_NAME := &"PhospriteNativeDocuments"

var app_shell: AppShellController
var native_bridge: Object
var active := false

var _pending_paths := PackedStringArray()
var _busy := false
var _current_temp_path := ""


func configure(shell: AppShellController) -> void:
	app_shell = shell
	if not is_instance_valid(app_shell):
		return
	if not app_shell.files_import_source_requested.is_connected(_on_files_source_requested):
		app_shell.files_import_source_requested.connect(_on_files_source_requested)
	if not app_shell.photos_import_source_requested.is_connected(_on_photos_source_requested):
		app_shell.photos_import_source_requested.connect(_on_photos_source_requested)
	if not app_shell.import_flow_finished.is_connected(_on_import_flow_finished):
		app_shell.import_flow_finished.connect(_on_import_flow_finished)


func _ready() -> void:
	if OS.get_name() == "iOS" and Engine.has_singleton(SINGLETON_NAME):
		native_bridge = Engine.get_singleton(SINGLETON_NAME)
	set_process(false)


func start() -> void:
	active = true
	set_process(native_bridge != null)
	call_deferred("_drain_next")


func _process(_delta: float) -> void:
	if not active or native_bridge == null:
		return
	while int(native_bridge.get_pending_event_count()) > 0:
		var event: Dictionary = native_bridge.pop_event()
		_handle_native_event(event)


func enqueue_import_paths(paths: PackedStringArray) -> void:
	for path in paths:
		if not path.is_empty():
			_pending_paths.append(path)
	call_deferred("_drain_next")


func reveal_in_files(path: String) -> bool:
	if native_bridge == null or path.is_empty():
		return false
	return bool(native_bridge.reveal_in_files(ProjectSettings.globalize_path(path)))


func _handle_native_event(event: Dictionary) -> void:
	var event_type := str(event.get("type", ""))
	if event_type == "paths":
		var paths: PackedStringArray = event.get("paths", PackedStringArray())
		enqueue_import_paths(paths)
	elif event_type == "error":
		var message := str(event.get("message", ""))
		if not message.is_empty():
			Global.popup_error(message)


func _drain_next() -> void:
	if not active or _busy or _pending_paths.is_empty() or not is_instance_valid(app_shell):
		return
	_busy = true
	_current_temp_path = _pending_paths[0]
	_pending_paths.remove_at(0)
	var enter_editor := _pending_paths.is_empty()
	app_shell.handoff_import_path(_current_temp_path, enter_editor)


func _on_import_flow_finished(_success: bool) -> void:
	if not _busy:
		return
	if native_bridge != null and not _current_temp_path.is_empty():
		native_bridge.cleanup_temp_file(_current_temp_path)
	_current_temp_path = ""
	_busy = false
	call_deferred("_drain_next")


func _on_files_source_requested() -> void:
	if native_bridge == null or not bool(native_bridge.present_document_picker()):
		Global.popup_error(tr("The iOS document picker is unavailable."))


func _on_photos_source_requested() -> void:
	if native_bridge == null or not bool(native_bridge.present_photo_picker()):
		Global.popup_error(tr("The iOS photo picker is unavailable."))
