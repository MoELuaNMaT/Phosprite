extends RefCounted

## A small durable breadcrumb for native iPad crashes that stop GDScript before it
## can print a stack trace. No project name, document path, or user data is stored.
const TRACE_PATH := "user://editor_entry_phase.txt"
const IDLE := "idle"
const STABLE := "editor_stable"


static func record(phase: String) -> void:
	if OS.get_name() != "iOS":
		return
	var file := FileAccess.open(TRACE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(phase)
	file.flush()


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
	return phase
