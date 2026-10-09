extends RefCounted

## iPad-only crash breadcrumbs. Stores phase names and test mode, not project
## names, document paths, images, identifiers, or other user content.
const TRACE_PATH := "user://editor_entry_phase.txt"
const REPORT_PATH := "user://Projects/Phosprite-Diagnostic.txt"
const SETTINGS_PATH := "user://phosprite_diagnostic.ini"
const IDLE := "idle"
const STABLE := "editor_stable"
const MODE_LABELS := [
	"Normal",
	"No Preview",
	"No Timeline",
	"No Canvas",
	"No Workspace Chrome",
	"Empty Editor Shell",
	"No Transition Animation",
	"No DockHost Only",
	"No UI3 Taskbar Only",
	"No UI3 Tool Options",
	"No Floating Windows",
	"No Timeline Module",
	"No Docked Windows",
	"No Preview and Tool Options",
	"No Preview Viewport",
	"No Tool Options Content",
	"No Floating Custom Draw",
	"No Floating Module Content",
	"No Options Host",
	"No Options ScrollContainer",
	"No Active Tool Controls",
	"No Value Sliders",
	"No Option Labels",
	"No Compact Styling",
]


static func record(phase: String) -> void:
	if OS.get_name() != "iOS":
		return
	var file := FileAccess.open(TRACE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(phase)
	file.flush()
	_append_report(phase)


static func consume_interrupted_phase() -> String:
	if OS.get_name() != "iOS" or not FileAccess.file_exists(TRACE_PATH):
		return ""
	var file := FileAccess.open(TRACE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var phase := file.get_as_text().strip_edges()
	record(IDLE)
	if phase.is_empty() or phase == IDLE or phase == STABLE:
		return ""
	_append_report("INTERRUPTED: " + phase)
	return phase


static func load_test_mode() -> int:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return 0
	return clampi(int(config.get_value("ipad_diagnostic", "mode", 0)), 0, MODE_LABELS.size() - 1)


static func save_test_mode(mode: int) -> void:
	var config := ConfigFile.new()
	config.set_value("ipad_diagnostic", "mode", clampi(mode, 0, MODE_LABELS.size() - 1))
	config.save(SETTINGS_PATH)
	if OS.get_name() == "iOS":
		_append_report("MODE: " + MODE_LABELS[clampi(mode, 0, MODE_LABELS.size() - 1)])


## Diagnostic facts must not override the last editor-entry checkpoint.
static func note(message: String) -> void:
	if OS.get_name() == "iOS":
		_append_report("INFO: " + message)


static func recent_report() -> String:
	if not FileAccess.file_exists(REPORT_PATH):
		return "No diagnostic events recorded yet."
	var file := FileAccess.open(REPORT_PATH, FileAccess.READ)
	if file == null:
		return "Unable to read diagnostic report."
	return file.get_as_text()


static func _append_report(message: String) -> void:
	if DirAccess.make_dir_recursive_absolute("user://Projects") != OK:
		return
	var file := FileAccess.open(REPORT_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		return
	if file.get_length() > 65536:
		file.close()
		file = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
		if file == null:
			return
	else:
		file.seek_end()
	file.store_line("%s | %s" % [Time.get_datetime_string_from_system(), message])
	file.flush()
