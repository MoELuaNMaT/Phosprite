class_name ProjectExportCoordinator
extends Node

signal batch_progress(completed: int, total: int, path: String)
signal batch_finished(exported: PackedStringArray, failed: PackedStringArray)

const ShareService := preload("res://src/PlatformServices/ShareService.gd")

var export_dialog
var busy := false

var _paths := PackedStringArray()
var _batch_mode := false
var _preview_project: Project
var _preview_temporary := false


func configure(dialog: ConfirmationDialog) -> void:
	export_dialog = dialog
	if not is_instance_valid(export_dialog):
		return
	if not export_dialog.gallery_profile_confirmed.is_connected(_on_gallery_profile_confirmed):
		export_dialog.gallery_profile_confirmed.connect(_on_gallery_profile_confirmed)
	if not export_dialog.configured_export_finished.is_connected(_on_configured_export_finished):
		export_dialog.configured_export_finished.connect(_on_configured_export_finished)
	if not export_dialog.configured_export_canceled.is_connected(_on_configured_export_canceled):
		export_dialog.configured_export_canceled.connect(_on_configured_export_canceled)


func begin_export(paths: PackedStringArray) -> bool:
	if busy or paths.is_empty() or not is_instance_valid(export_dialog):
		return false
	_paths = paths.duplicate()
	_batch_mode = _paths.size() > 1
	var acquired := _acquire_project(_paths[0])
	_preview_project = acquired.get("project") as Project
	_preview_temporary = bool(acquired.get("temporary", false))
	if _preview_project == null:
		_reset_request()
		Global.popup_error(tr("Could not load the selected project for export."))
		return false

	busy = true
	export_dialog.configure_for_project(_preview_project, _batch_mode)
	Global.dialog_open(true)
	export_dialog.popup_centered_clamped()
	return true


func run_batch(paths: PackedStringArray, profile: ExportProfile) -> Dictionary:
	var exported := PackedStringArray()
	var failed := PackedStringArray()
	var completed := 0
	for path in paths:
		var acquired := _acquire_project(path)
		var project := acquired.get("project") as Project
		var temporary := bool(acquired.get("temporary", false))
		if project == null:
			failed.append(path)
			completed += 1
			batch_progress.emit(completed, paths.size(), path)
			continue

		profile.apply_to(project)
		project.file_name = path.get_file().get_basename()
		project.export_overwrite = false
		var success := await _export_one(project)
		if success:
			exported.append(path)
		else:
			failed.append(path)

		_release_project(project, temporary)
		_clear_export_cache()
		completed += 1
		batch_progress.emit(completed, paths.size(), path)

		if ShareService.is_share_export_platform() and not success:
			break

	_restore_editor_export_ui()
	return {"exported": exported, "failed": failed}


func _on_gallery_profile_confirmed(profile: ExportProfile) -> void:
	if not busy or not _batch_mode:
		return
	Global.dialog_open(false)
	_release_preview()
	export_dialog.clear_configured_project()
	var result := await run_batch(_paths, profile)
	var exported: PackedStringArray = result.get("exported", PackedStringArray())
	var failed: PackedStringArray = result.get("failed", PackedStringArray())
	if failed.is_empty():
		Global.notification_label(tr("%d projects exported") % exported.size())
	else:
		Global.popup_error(
			tr("%d project(s) exported; %d failed.") % [exported.size(), failed.size()]
		)
	batch_finished.emit(exported, failed)
	_reset_request()


func _on_configured_export_finished(success: bool, project: Project) -> void:
	if not busy or _batch_mode or project != _preview_project:
		return
	Global.dialog_open(false)
	var exported := PackedStringArray()
	var failed := PackedStringArray()
	if success:
		exported.append(_paths[0])
	else:
		failed.append(_paths[0])
	_release_preview()
	export_dialog.clear_configured_project()
	_restore_editor_export_ui()
	batch_finished.emit(exported, failed)
	_reset_request()


func _on_configured_export_canceled(project: Project) -> void:
	if not busy or project != _preview_project:
		return
	Global.dialog_open(false)
	_release_preview()
	export_dialog.clear_configured_project()
	_restore_editor_export_ui()
	batch_finished.emit(PackedStringArray(), _paths.duplicate())
	_reset_request()


func _export_one(project: Project) -> bool:
	_clear_export_cache()
	Export.cache_blended_frames(project)
	Export.process_data(project)

	var share_export := ShareService.is_share_export_platform()
	if share_export:
		if not _supports_single_share_artifact(project):
			Global.popup_error(
				tr(
					(
						"Batch Share Export requires one output file per project. "
						+ "Use an animated format or a spritesheet for multi-frame projects."
					)
				)
			)
			return false
		var staging_error := ShareService.reset_staging_directory()
		if staging_error != OK:
			Global.popup_error(
				tr("Could not prepare the Share Export folder. Error code %s (%s)")
				% [staging_error, error_string(staging_error)]
			)
			return false
		project.export_directory_path = ShareService.STAGING_DIRECTORY

	if not await Export.export_processed_images(false, export_dialog, project):
		return false
	if not share_export:
		return true

	while Export.gif_export_thread.is_alive():
		await get_tree().process_frame
	if Export.gif_export_thread.is_started():
		Export.gif_export_thread.wait_to_finish()

	var extension := Export.file_format_string(project.file_format, true)
	var artifacts := ShareService.find_staged_files(extension)
	if artifacts.size() != 1:
		Global.popup_error(
			tr("Share Export expected one finished file, but found %d.") % artifacts.size()
		)
		return false
	return await ShareService.share_file_and_wait(artifacts[0], tr("Phosprite Export"))


func _supports_single_share_artifact(project: Project) -> bool:
	return Export.is_single_file_format(project) or Export.processed_images.size() == 1


func _acquire_project(path: String) -> Dictionary:
	var normalized := _normalized_path(path)
	for project: Project in Global.projects:
		if _normalized_path(project.save_path) == normalized:
			return {"project": project, "temporary": false}

	var project := OpenSave.open_pxo_file(path, false, false, true)
	if project == null:
		return {"project": null, "temporary": false}
	return {"project": project, "temporary": true}


func _release_preview() -> void:
	_release_project(_preview_project, _preview_temporary)
	_preview_project = null
	_preview_temporary = false
	_clear_export_cache()


func _release_project(project: Project, temporary: bool) -> void:
	if project == null or not temporary:
		return
	var index := Global.projects.find(project)
	if index >= 0 and index < Global.tabs.get_tab_count():
		Global.tabs.remove_tab(index)
	project.remove()


func _restore_editor_export_ui() -> void:
	if is_instance_valid(Global.top_menu_container) and Global.current_project != null:
		Global.top_menu_container.call("_update_file_menu_buttons", Global.current_project)


func _clear_export_cache() -> void:
	Export.processed_images.clear()
	Export.blended_frames.clear()


func _reset_request() -> void:
	busy = false
	_paths.clear()
	_batch_mode = false
	_preview_project = null
	_preview_temporary = false


func _normalized_path(path: String) -> String:
	if path.is_empty():
		return ""
	return ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()
