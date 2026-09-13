extends Node

## Temporary P1-B0 iOS input instrumentation.
##
## This probe is injected only into the iOS CI checkout. It passively records raw
## Godot input events without accepting or rewriting them, so the existing editor
## behavior remains the source of truth for the evidence run.

const SHARE_SERVICE := preload("res://src/PlatformServices/ShareService.gd")
const LOG_DIRECTORY := "user://Projects"
const LOG_PATH := "user://Projects/p1b_input_probe.jsonl"
const PROBE_SCHEMA := 1
const RELEVANT_ACTIONS := [
	&"activate_left_tool",
	&"activate_right_tool",
	&"pan",
	&"zoom_in",
	&"zoom_out",
	&"rotate_left",
	&"rotate_right",
]
const TESTS := [
	"Finger tap: tap the canvas 3 times with one finger.",
	"Finger drag: make 1 continuous drag on the canvas with one finger.",
	"Two-finger pan: pan the canvas for about 2 seconds.",
	"Pinch zoom: pinch in, then pinch out once.",
	"Pencil tap: tap the canvas 3 times with Apple Pencil.",
	"Pencil stroke: draw 1 continuous stroke with Apple Pencil.",
	"Pencil pressure: draw 1 stroke from light pressure to firm pressure.",
	"Pencil + finger: keep a Pencil stroke active while touching/moving 1 finger.",
	"Pencil + two fingers: keep Pencil on canvas, then do a two-finger pan/pinch.",
]

var _log_file: FileAccess
var _sequence := 0
var _started_ticks_ms := 0
var _test_index := 0
var _instruction_label: Label
var _status_label: Label


func _ready() -> void:
	if OS.get_name() != "iOS":
		queue_free()
		return
	_build_overlay()
	_reset_probe()


func _input(event: InputEvent) -> void:
	var record := _event_to_record(event)
	if record.is_empty():
		return
	_write_record(record)


func _notification(what: int) -> void:
	if _log_file == null:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_write_record({"kind": "lifecycle", "state": "paused"})
		NOTIFICATION_APPLICATION_RESUMED:
			_write_record({"kind": "lifecycle", "state": "resumed"})
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_write_record({"kind": "lifecycle", "state": "focus_out"})
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_write_record({"kind": "lifecycle", "state": "focus_in"})


func _exit_tree() -> void:
	if _log_file != null:
		_write_record({"kind": "session_end"})
		_log_file.close()
		_log_file = null


func _reset_probe() -> void:
	if _log_file != null:
		_log_file.close()
		_log_file = null
	DirAccess.make_dir_recursive_absolute(LOG_DIRECTORY)
	_log_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if _log_file == null:
		_set_status("LOG OPEN FAILED: %s" % error_string(FileAccess.get_open_error()))
		return
	_sequence = 0
	_started_ticks_ms = Time.get_ticks_msec()
	_test_index = 0
	_write_record(
		{
			"kind": "session_start",
			"schema": PROBE_SCHEMA,
			"unix_ms": int(Time.get_unix_time_from_system() * 1000.0),
			"engine": Engine.get_version_info().get("string", "unknown"),
			"os": OS.get_name(),
			"touchscreen_available": DisplayServer.is_touchscreen_available(),
			"screen_size": _vector_to_array(Vector2(DisplayServer.screen_get_size())),
			"log_path": LOG_PATH,
			"globalized_path": ProjectSettings.globalize_path(LOG_PATH),
		}
	)
	_begin_current_test()
	_set_status("Recording. Log: Projects/p1b_input_probe.jsonl")


func _advance_test() -> void:
	if _log_file == null:
		return
	if _test_index < TESTS.size():
		_write_record(
			{
				"kind": "test_end",
				"test_index": _test_index + 1,
				"instruction": TESTS[_test_index],
			}
		)
	_test_index += 1
	if _test_index < TESTS.size():
		_begin_current_test()
		_set_status("Recording test %d/%d" % [_test_index + 1, TESTS.size()])
	else:
		_write_record({"kind": "probe_complete", "test_count": TESTS.size()})
		_instruction_label.text = "All tests complete. Tap Share Log and save/send the JSONL file."
		_set_status("Complete. Share the log now.")


func _begin_current_test() -> void:
	_instruction_label.text = "%d/%d  %s" % [_test_index + 1, TESTS.size(), TESTS[_test_index]]
	_write_record(
		{
			"kind": "test_begin",
			"test_index": _test_index + 1,
			"instruction": TESTS[_test_index],
		}
	)


func _share_log() -> void:
	if _log_file == null:
		_set_status("No log file is open.")
		return
	_write_record({"kind": "share_requested"})
	_log_file.flush()
	if SHARE_SERVICE.share_file(
		LOG_PATH,
		"Phosprite P1-B0 Input Probe",
		"P1-B0 input probe log",
		"Raw iPad input evidence for Phosprite P1-B0."
	):
		_set_status("Share Sheet opened. Save/send p1b_input_probe.jsonl.")
	else:
		_set_status("Share failed. Log remains at Projects/p1b_input_probe.jsonl")


func _event_to_record(event: InputEvent) -> Dictionary:
	var data := {
		"kind": "event",
		"class": event.get_class(),
		"device": event.device,
		"as_text": event.as_text(),
	}
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		data["index"] = touch.index
		data["position"] = _vector_to_array(touch.position)
		data["pressed"] = touch.pressed
		data["canceled"] = touch.canceled
		data["double_tap"] = touch.double_tap
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		data["index"] = drag.index
		data["position"] = _vector_to_array(drag.position)
		data["relative"] = _vector_to_array(drag.relative)
		data["screen_relative"] = _vector_to_array(drag.screen_relative)
		data["velocity"] = _vector_to_array(drag.velocity)
		data["screen_velocity"] = _vector_to_array(drag.screen_velocity)
		data["pressure"] = drag.pressure
		data["tilt"] = _vector_to_array(drag.tilt)
		data["pen_inverted"] = drag.pen_inverted
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		data["position"] = _vector_to_array(button.position)
		data["global_position"] = _vector_to_array(button.global_position)
		data["button_index"] = button.button_index
		data["button_mask"] = button.button_mask
		data["pressed"] = button.pressed
		data["canceled"] = button.canceled
		data["double_click"] = button.double_click
		data["factor"] = button.factor
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		data["position"] = _vector_to_array(motion.position)
		data["global_position"] = _vector_to_array(motion.global_position)
		data["relative"] = _vector_to_array(motion.relative)
		data["screen_relative"] = _vector_to_array(motion.screen_relative)
		data["velocity"] = _vector_to_array(motion.velocity)
		data["screen_velocity"] = _vector_to_array(motion.screen_velocity)
		data["button_mask"] = motion.button_mask
		data["pressure"] = motion.pressure
		data["tilt"] = _vector_to_array(motion.tilt)
		data["pen_inverted"] = motion.pen_inverted
	elif event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		data["position"] = _vector_to_array(magnify.position)
		data["factor"] = magnify.factor
	elif event is InputEventPanGesture:
		var pan := event as InputEventPanGesture
		data["position"] = _vector_to_array(pan.position)
		data["delta"] = _vector_to_array(pan.delta)
	else:
		return {}

	if event is InputEventWithModifiers:
		var modified := event as InputEventWithModifiers
		data["modifiers"] = {
			"alt": modified.alt_pressed,
			"shift": modified.shift_pressed,
			"ctrl": modified.ctrl_pressed,
			"meta": modified.meta_pressed,
		}
	data["actions"] = _matched_actions(event)
	return data


func _matched_actions(event: InputEvent) -> Array[Dictionary]:
	var matched: Array[Dictionary] = []
	for action: StringName in RELEVANT_ACTIONS:
		if not event.is_action(action):
			continue
		(
			matched
			. append(
				{
					"name": String(action),
					"pressed": event.is_action_pressed(action),
					"released": event.is_action_released(action),
				}
			)
		)
	return matched


func _write_record(record: Dictionary) -> void:
	if _log_file == null:
		return
	record["seq"] = _sequence
	record["t_ms"] = Time.get_ticks_msec() - _started_ticks_ms
	_sequence += 1
	_log_file.store_line(JSON.stringify(record))
	_log_file.flush()


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "P1B0InputProbeOverlay"
	layer.layer = 1000
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(430, 0)
	layer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title := Label.new()
	title.text = "P1-B0 Input Probe"
	box.add_child(title)

	_instruction_label = Label.new()
	_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction_label.custom_minimum_size = Vector2(400, 0)
	box.add_child(_instruction_label)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	box.add_child(controls)

	var next_button := Button.new()
	next_button.text = "Next Test"
	next_button.pressed.connect(_advance_test)
	controls.add_child(next_button)

	var reset_button := Button.new()
	reset_button.text = "Reset"
	reset_button.pressed.connect(_reset_probe)
	controls.add_child(reset_button)

	var share_button := Button.new()
	share_button.text = "Share Log"
	share_button.pressed.connect(_share_log)
	controls.add_child(share_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(400, 0)
	box.add_child(_status_label)


func _set_status(text: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = text


static func _vector_to_array(value: Vector2) -> Array:
	return [value.x, value.y]
