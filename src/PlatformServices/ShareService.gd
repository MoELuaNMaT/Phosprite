extends RefCounted

## iOS share-export policy and bridge.
##
## Phosprite keeps Pixelorama's exporter as the source of truth for rendering and
## encoding. On iOS the finished artifact is written into a short-lived directory
## under user:// and this service hands its absolute sandbox path to SharePlugin.
## No native implementation lives in Phosprite itself; the iOS build pins the
## MIT-licensed godot-mobile-plugins/godot-share v5.2 binary.

const PLUGIN_SINGLETON_NAME := "SharePlugin"
const STAGING_DIRECTORY := "user://.share_export"


class ShareCompletionGate:
	extends RefCounted

	signal finished(success: bool)

	var plugin: Object
	var done := false

	func bind(target: Object) -> void:
		plugin = target
		plugin.connect(&"share_completed", _on_completed)
		plugin.connect(&"share_canceled", _on_canceled)
		plugin.connect(&"share_failed", _on_failed)

	func _on_completed(_activity_type: String) -> void:
		_finish(true)

	func _on_canceled() -> void:
		_finish(false)

	func _on_failed(_message: String) -> void:
		_finish(false)

	func _finish(success: bool) -> void:
		if done:
			return
		done = true
		_disconnect_all()
		finished.emit(success)

	func _disconnect_all() -> void:
		if plugin == null:
			return
		if plugin.is_connected(&"share_completed", _on_completed):
			plugin.disconnect(&"share_completed", _on_completed)
		if plugin.is_connected(&"share_canceled", _on_canceled):
			plugin.disconnect(&"share_canceled", _on_canceled)
		if plugin.is_connected(&"share_failed", _on_failed):
			plugin.disconnect(&"share_failed", _on_failed)


static func is_share_export_platform() -> bool:
	return OS.get_name() == "iOS"


## Removes artifacts from the previous share and leaves a clean staging folder.
## The folder itself stays alive so Export.export_processed_images() can validate
## it before producing the next artifact.
static func reset_staging_directory() -> Error:
	var err := _clear_directory(STAGING_DIRECTORY)
	if err != OK:
		return err
	if DirAccess.dir_exists_absolute(STAGING_DIRECTORY):
		return OK
	return DirAccess.make_dir_recursive_absolute(STAGING_DIRECTORY)


## Returns every staged file whose extension matches [param extension].
## Tag-based exports can create subdirectories, so discovery is recursive.
static func find_staged_files(extension: String) -> PackedStringArray:
	var normalized := extension.to_lower()
	if normalized.begins_with("."):
		normalized = normalized.trim_prefix(".")
	var files := PackedStringArray()
	_collect_files(STAGING_DIRECTORY, normalized, files)
	return files


## Opens the native iOS share sheet for one already-written artifact.
## The plugin consumes a physical sandbox path, not Godot's user:// URI.
static func share_file(
	path: String, title := "Phosprite Export", subject := "", content := ""
) -> bool:
	var plugin := _share_plugin_for_path(path)
	if plugin == null:
		return false
	_call_share(plugin, path, title, subject, content)
	return true


static func share_file_and_wait(
	path: String, title := "Phosprite Export", subject := "", content := ""
) -> bool:
	var plugin := _share_plugin_for_path(path)
	if plugin == null:
		return false
	if not (
		plugin.has_signal("share_completed")
		and plugin.has_signal("share_canceled")
		and plugin.has_signal("share_failed")
	):
		push_error("%s does not expose share completion signals" % PLUGIN_SINGLETON_NAME)
		return false
	var gate := ShareCompletionGate.new()
	gate.bind(plugin)
	_call_share(plugin, path, title, subject, content)
	return await gate.finished


static func _share_plugin_for_path(path: String) -> Object:
	if not FileAccess.file_exists(path):
		push_error("Share export artifact does not exist: %s" % path)
		return null
	if not Engine.has_singleton(PLUGIN_SINGLETON_NAME):
		push_error("%s singleton is not available" % PLUGIN_SINGLETON_NAME)
		return null
	var plugin := Engine.get_singleton(PLUGIN_SINGLETON_NAME)
	if plugin == null or not plugin.has_method("share"):
		push_error("%s does not expose share()" % PLUGIN_SINGLETON_NAME)
		return null
	return plugin


static func _call_share(
	plugin: Object, path: String, title: String, subject: String, content: String
) -> void:
	(
		plugin
		. call(
			"share",
			{
				"title": title,
				"subject": subject,
				"content": content,
				"file_path": ProjectSettings.globalize_path(path),
				"mime_type": mime_type_for_path(path),
			}
		)
	)


static func mime_type_for_path(path: String) -> String:
	match path.get_extension().to_lower():
		"png":
			return "image/png"
		"webp":
			return "image/webp"
		"jpg", "jpeg":
			return "image/jpeg"
		"exr":
			return "image/x-exr"
		"gif":
			return "image/gif"
		"apng":
			return "image/apng"
		"mp4":
			return "video/mp4"
		"avi":
			return "video/x-msvideo"
		"ogv":
			return "video/ogg"
		"mkv":
			return "video/x-matroska"
		"webm":
			return "video/webm"
		_:
			return "application/octet-stream"


static func _clear_directory(path: String) -> Error:
	if not DirAccess.dir_exists_absolute(path):
		return OK
	var dir := DirAccess.open(path)
	if dir == null:
		return DirAccess.get_open_error()
	for file: String in dir.get_files():
		var err := dir.remove(file)
		if err != OK:
			return err
	for child_name: String in dir.get_directories():
		var child_path := path.path_join(child_name)
		var err := _clear_directory(child_path)
		if err != OK:
			return err
		err = DirAccess.remove_absolute(ProjectSettings.globalize_path(child_path))
		if err != OK:
			return err
	return OK


static func _collect_files(path: String, extension: String, out: PackedStringArray) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file: String in dir.get_files():
		if extension.is_empty() or file.get_extension().to_lower() == extension:
			out.append(path.path_join(file))
	for child_name: String in dir.get_directories():
		_collect_files(path.path_join(child_name), extension, out)
