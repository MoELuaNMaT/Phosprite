extends "res://tests/test_base.gd"

const SHARE_SERVICE := preload("res://src/PlatformServices/ShareService.gd")
const EXPORT_DIALOG_SOURCE := "res://src/UI/Dialogs/ExportDialog.gd"
const IOS_WORKFLOW_SOURCE := "res://.github/workflows/ios-build.yml"
const THIRD_PARTY_NOTICE := "res://THIRD_PARTY_NOTICES.md"


func test_share_service_mime_types() -> void:
	check_eq(
		SHARE_SERVICE.mime_type_for_path("user://.share_export/sprite.png"),
		"image/png",
		"PNG must use the native image MIME type"
	)
	check_eq(
		SHARE_SERVICE.mime_type_for_path("user://.share_export/anim.gif"),
		"image/gif",
		"GIF must use the native image MIME type"
	)
	check_eq(
		SHARE_SERVICE.mime_type_for_path("user://.share_export/movie.webm"),
		"video/webm",
		"WebM must use the native video MIME type"
	)


func test_share_export_waits_for_animated_artifact() -> void:
	var src := FileAccess.get_file_as_string(EXPORT_DIALOG_SOURCE)
	check_has(
		src,
		"Export.gif_export_thread.wait_to_finish()",
		"iOS Share Export must wait for the GIF/APNG worker before sharing"
	)
	check_has(
		src,
		"SHARE_SERVICE.find_staged_files",
		"iOS Share Export must resolve the finished artifact from staging"
	)
	check_has(
		src,
		"SHARE_SERVICE.share_file",
		"the finished artifact must be handed to the native share bridge"
	)


func test_share_export_hides_filesystem_destination_ui() -> void:
	var src := FileAccess.get_file_as_string(EXPORT_DIALOG_SOURCE)
	check_has(src, "path_button.hide()", "iOS must not expose the Browse destination button")
	check_has(
		src, 'file_path_label.text = tr("File name:")', "iOS must label the field as a file name"
	)
	check_has(
		src,
		"if SHARE_SERVICE.is_share_export_platform():\n\t\treturn",
		"the path picker handler must be inert on iOS"
	)


func test_ios_ci_pins_share_plugin_release() -> void:
	var workflow := FileAccess.get_file_as_string(IOS_WORKFLOW_SOURCE)
	check_has(workflow, "SHARE_PLUGIN_VERSION: 5.2", "iOS CI must pin the Godot Share version")
	check_has(
		workflow,
		"3bcc46dd250532067345812bc03d3e43d4013f3ffe08354217225b0affedb77f",
		"iOS CI must verify the published v5.2 release checksum"
	)
	check_has(workflow, "plugins/SharePlugin=true", "the iOS export preset must enable SharePlugin")
	check_has(
		workflow,
		"SharePlugin.release.xcframework",
		"CI must require the native release iOS framework before exporting"
	)
	check_has(
		workflow,
		"SharePlugin.debug.xcframework",
		"CI must verify the native debug iOS framework shipped by the release"
	)


func test_godot_share_mit_notice_is_retained() -> void:
	check_file_exists(THIRD_PARTY_NOTICE, "the third-party license notice must be present")
	var notice := FileAccess.get_file_as_string(THIRD_PARTY_NOTICE)
	check_has(notice, "Godot Share Plugin v5.2", "the pinned dependency must be identified")
	check_has(notice, "MIT", "the dependency license must be recorded")
	check_has(
		notice,
		"Copyright (c) 2025 Godot Engine Community SDK Integrations",
		"the upstream copyright notice must be retained"
	)
