class_name TouchGestureRecognizer
extends RefCounted

const GestureConfig := preload("res://src/InputAdapter/TouchGestureConfig.gd")

enum Gesture {
	NONE,
	TAP,
	DOUBLE_TAP,
	LONG_PRESS,
	DRAG_START,
	DRAG_UPDATE,
	DRAG_END,
	CANCEL,
}

var config: TouchGestureConfig
var _pointers: Dictionary = {}
var _pending_tap: Dictionary = {}


func _init(custom_config: TouchGestureConfig = null) -> void:
	config = custom_config.duplicate_config() if custom_config != null else GestureConfig.new()


## Begins tracking a raw touch pointer. Timestamps are supplied by the caller so
## recognition stays deterministic in unit tests and independent from frame rate.
func begin(pointer_id: int, position: Vector2, timestamp_msec: int) -> Array[Dictionary]:
	var events := _flush_expired_pending_tap(timestamp_msec)
	if pointer_id < 0:
		return events
	if _pointers.has(pointer_id):
		events.append_array(cancel(pointer_id, timestamp_msec))
	_pointers[pointer_id] = {
		"origin": position,
		"position": position,
		"started_msec": timestamp_msec,
		"dragging": false,
		"long_press_emitted": false,
		"tap_eligible": true,
	}
	return events


## Updates a tracked pointer and emits drag acquisition/update when movement
## crosses the configured threshold. Movement beyond tap slop invalidates tap
## and long-press recognition even when drag acquisition is configured farther out.
func move(pointer_id: int, position: Vector2, timestamp_msec: int) -> Array[Dictionary]:
	var events := _flush_expired_pending_tap(timestamp_msec)
	if not _pointers.has(pointer_id):
		return events

	var state: Dictionary = _pointers[pointer_id]
	state["position"] = position
	var distance := (position - (state["origin"] as Vector2)).length()
	if distance > config.tap_slop_px:
		state["tap_eligible"] = false

	if bool(state["long_press_emitted"]):
		_pointers[pointer_id] = state
		return events

	if bool(state["dragging"]):
		_pointers[pointer_id] = state
		events.append(_make_event(Gesture.DRAG_UPDATE, pointer_id, state, timestamp_msec))
		return events

	if distance >= config.drag_threshold_px:
		# A second contact that becomes a drag can no longer complete a double tap,
		# so the previous pending tap is safe to commit immediately.
		_flush_pending_tap_into(events)
		state["dragging"] = true
		state["tap_eligible"] = false
		_pointers[pointer_id] = state
		events.append(_make_event(Gesture.DRAG_START, pointer_id, state, timestamp_msec))
		return events

	_pointers[pointer_id] = state
	return events


## Releases a pointer. Single taps are deliberately deferred until the double-
## tap window expires; callers should feed time through advance_time().
func release(pointer_id: int, position: Vector2, timestamp_msec: int) -> Array[Dictionary]:
	var events := _flush_expired_pending_tap(timestamp_msec)
	if not _pointers.has(pointer_id):
		return events

	var state: Dictionary = _pointers[pointer_id]
	state["position"] = position
	var distance := (position - (state["origin"] as Vector2)).length()
	if distance > config.tap_slop_px:
		state["tap_eligible"] = false

	if bool(state["dragging"]):
		events.append(_make_event(Gesture.DRAG_END, pointer_id, state, timestamp_msec))
		_pointers.erase(pointer_id)
		return events

	if distance >= config.drag_threshold_px:
		_flush_pending_tap_into(events)
		state["tap_eligible"] = false
		state["dragging"] = true
		events.append(_make_event(Gesture.DRAG_START, pointer_id, state, timestamp_msec))
		events.append(_make_event(Gesture.DRAG_END, pointer_id, state, timestamp_msec))
		_pointers.erase(pointer_id)
		return events

	# A long press may already have fired from advance_time() while the contact
	# remained down. Releasing it is terminal and must never create a tap candidate.
	if bool(state["long_press_emitted"]):
		_pointers.erase(pointer_id)
		return events

	var elapsed := maxi(0, timestamp_msec - int(state["started_msec"]))
	if bool(state["tap_eligible"]) and elapsed >= config.long_press_duration_msec:
		_flush_pending_tap_into(events)
		state["long_press_emitted"] = true
		events.append(_make_event(Gesture.LONG_PRESS, pointer_id, state, timestamp_msec))
		_pointers.erase(pointer_id)
		return events

	if not bool(state["tap_eligible"]):
		_pointers.erase(pointer_id)
		return events

	_commit_tap_candidate(pointer_id, state, timestamp_msec, events)
	_pointers.erase(pointer_id)
	return events


## Advances recognition without pointer motion. This is what commits delayed
## single taps and fires long press while a finger is still held down.
func advance_time(timestamp_msec: int) -> Array[Dictionary]:
	var events := _flush_expired_pending_tap(timestamp_msec)
	var pointer_ids: Array = _pointers.keys()
	pointer_ids.sort()
	for pointer_id_variant: Variant in pointer_ids:
		var pointer_id := int(pointer_id_variant)
		var state: Dictionary = _pointers[pointer_id]
		if bool(state["dragging"]) or bool(state["long_press_emitted"]):
			continue
		if not bool(state["tap_eligible"]):
			continue
		var elapsed := maxi(0, timestamp_msec - int(state["started_msec"]))
		if elapsed < config.long_press_duration_msec:
			continue
		_flush_pending_tap_into(events)
		state["long_press_emitted"] = true
		_pointers[pointer_id] = state
		events.append(_make_event(Gesture.LONG_PRESS, pointer_id, state, timestamp_msec))
	return events


func cancel(pointer_id: int, timestamp_msec: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not _pointers.has(pointer_id):
		return events
	var state: Dictionary = _pointers[pointer_id]
	events.append(_make_event(Gesture.CANCEL, pointer_id, state, timestamp_msec))
	_pointers.erase(pointer_id)
	return events


## Cancels every active contact and drops any delayed single tap. This is the
## interruption boundary for app focus loss, scene teardown, or higher-level
## gesture takeover; it must never leave a delayed action behind.
func cancel_all(timestamp_msec: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var pointer_ids: Array = _pointers.keys()
	pointer_ids.sort()
	for pointer_id_variant: Variant in pointer_ids:
		var pointer_id := int(pointer_id_variant)
		var state: Dictionary = _pointers[pointer_id]
		events.append(_make_event(Gesture.CANCEL, pointer_id, state, timestamp_msec))
	_pointers.clear()
	_pending_tap.clear()
	return events


func is_tracking(pointer_id: int) -> bool:
	return _pointers.has(pointer_id)


func is_dragging(pointer_id: int) -> bool:
	return _pointers.has(pointer_id) and bool((_pointers[pointer_id] as Dictionary)["dragging"])


func has_pending_tap() -> bool:
	return not _pending_tap.is_empty()


func active_pointer_count() -> int:
	return _pointers.size()


func _commit_tap_candidate(
	pointer_id: int, state: Dictionary, timestamp_msec: int, events: Array[Dictionary]
) -> void:
	if not _pending_tap.is_empty():
		var interval := timestamp_msec - int(_pending_tap["timestamp_msec"])
		var previous_position := _pending_tap["position"] as Vector2
		var within_interval := interval >= 0 and interval <= config.double_tap_interval_msec
		var within_distance := (
			previous_position.distance_to(state["position"] as Vector2)
			<= config.double_tap_distance_px
		)
		if within_interval and within_distance:
			events.append(_make_event(Gesture.DOUBLE_TAP, pointer_id, state, timestamp_msec))
			_pending_tap.clear()
			return
		_flush_pending_tap_into(events)

	_pending_tap = {
		"pointer_id": pointer_id,
		"position": state["position"],
		"origin": state["origin"],
		"timestamp_msec": timestamp_msec,
	}


func _flush_expired_pending_tap(timestamp_msec: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if _pending_tap.is_empty():
		return events
	if timestamp_msec - int(_pending_tap["timestamp_msec"]) <= config.double_tap_interval_msec:
		return events
	_flush_pending_tap_into(events)
	return events


func _flush_pending_tap_into(events: Array[Dictionary]) -> void:
	if _pending_tap.is_empty():
		return
	var state := {
		"origin": _pending_tap["origin"],
		"position": _pending_tap["position"],
	}
	events.append(
		_make_event(
			Gesture.TAP, int(_pending_tap["pointer_id"]), state, int(_pending_tap["timestamp_msec"])
		)
	)
	_pending_tap.clear()


static func _make_event(
	gesture: Gesture, pointer_id: int, state: Dictionary, timestamp_msec: int
) -> Dictionary:
	return {
		"gesture": gesture,
		"pointer_id": pointer_id,
		"origin": state.get("origin", Vector2.ZERO),
		"position": state.get("position", Vector2.ZERO),
		"timestamp_msec": timestamp_msec,
	}
