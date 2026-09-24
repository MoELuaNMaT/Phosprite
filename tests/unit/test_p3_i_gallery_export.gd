extends "res://tests/test_base.gd"

const DIALOG_SOURCE := "res://src/UI/Dialogs/ExportDialog.gd"
const COORDINATOR_SOURCE := "res://src/ProjectLibrary/ProjectExportCoordinator.gd"
const OPEN_SAVE_SOURCE := "res://src/Autoload/OpenSave.gd"
const SHARE_SOURCE := "res://src/PlatformServices/ShareService.gd"


func test_p3_i_export_dialog_can_target_gallery_project() -> void:
	var src := FileAccess.get_file_as_string(DIALOG_SOURCE)
	check_has(
		src,
		"func configure_for_project(project: Project, profile_only := false)",
		"Gallery export must explicitly configure ExportDialog for a project",
	)
	check_has(
		src,
		"func _target_project() -> Project:",
		"ExportDialog must resolve its configured project instead of assuming the Editor project",
	)
	check_has(
		src,
		"gallery_profile_confirmed.emit(EXPORT_PROFILE.capture(project))",
		"batch export must snapshot one ExportProfile from the configured dialog",
	)
	check_has(
		src,
		"return Global.current_project",
		"Editor export must retain Global.current_project as the unconfigured fallback",
	)
	check_has(
		src,
		"Export.process_animation(project)",
		"configured preview processing must use the resolved target project",
	)


func test_p3_i_batch_coordinator_is_serial_and_uses_each_project_basename() -> void:
	var src := FileAccess.get_file_as_string(COORDINATOR_SOURCE)
	check_has(
		src,
		"var success := await _export_one(project)",
		"batch export must await each project before moving to the next",
	)
	check_has(
		src,
		"project.file_name = path.get_file().get_basename()",
		"batch output basename must come from each managed project",
	)
	check_has(
		src,
		"Export.processed_images.clear()",
		"batch export must clear processed_images between projects",
	)
	check_has(
		src,
		"Export.blended_frames.clear()",
		"batch export must clear blended_frames between projects",
	)
	check_has(
		src,
		"OpenSave.open_pxo_file(path, false, false, true)",
		"unopened Gallery projects must use transient PXO loading",
	)


func test_p3_i_transient_loading_and_share_wait_contract() -> void:
	var open_save := FileAccess.get_file_as_string(OPEN_SAVE_SOURCE)
	var share := FileAccess.get_file_as_string(SHARE_SOURCE)
	check_has(
		open_save,
		"replace_empty := true, transient := false",
		"PXO loading must expose an opt-in transient mode",
	)
	check_has(
		open_save,
		"if not transient:\n\t\t\tGlobal.tabs.current_tab",
		"transient export loads must not switch the active Editor tab",
	)
	check_has(
		open_save,
		"if not transient:\n\t\tsave_project_to_recent_list(path)",
		"transient export loads must not pollute recent projects",
	)
	check_has(
		share,
		"static func share_file_and_wait(",
		"batch iOS export must have an awaitable Share Sheet bridge",
	)
	check_has(
		share,
		'plugin.has_signal("share_completed")',
		"batch sharing must wait for native completion",
	)
	check_has(
		share,
		'plugin.has_signal("share_canceled")',
		"batch sharing must observe native cancellation",
	)
	check_has(
		share,
		'plugin.has_signal("share_failed")',
		"batch sharing must observe native failure",
	)
