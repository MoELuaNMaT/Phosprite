class_name ProjectCardGestureResolver
extends RefCounted

enum ActionKind { SINGLE_TAP, DOUBLE_TAP, LONG_PRESS }

const DOUBLE_TAP_WINDOW_MSEC := 300
const LONG_PRESS_MSEC := 1000

var _pressed_path := ""
var _pressed_since_msec := -1
var _pressed_position := Vector2.ZERO
var _press_consumed := false
var _long_press_emitted := false
var _double_tap_pending := false

var _pending_single_path := ""
var _pending_single_deadline_msec := -1
var _pending_single_position := Vector2.ZERO


func pointer_down(path: String, position: Vector2, now_msec: int) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if path.is_empty():
		return poll(now_msec)

	if not _pressed_path.is_empty():
		_clear_press()

	# The second down owns the exact 300 ms boundary. Polling first would resolve
	# the pending single at the same timestamp and make a legal boundary double tap
	# impossible.
	if (
		_pending_single_path == path
		and _pending_single_deadline_msec >= 0
		and now_msec <= _pending_single_deadline_msec
	):
		# Do not emit while the originating Button is still physically pressed.
		# Opening a PopupMenu here steals the second release and leaves the card's
		# native pressed/hover draw state latched on iPad.
		_clear_pending_single()
		_pressed_path = path
		_pressed_since_msec = now_msec
		_pressed_position = position
		_press_consumed = false
		_long_press_emitted = false
		_double_tap_pending = true
		return actions

	actions.append_array(poll(now_msec))
	if not _pending_single_path.is_empty():
		actions.append(
			_action(ActionKind.SINGLE_TAP, _pending_single_path, _pending_single_position)
		)
		_clear_pending_single()

	_pressed_path = path
	_pressed_since_msec = now_msec
	_pressed_position = position
	_press_consumed = false
	_long_press_emitted = false
	return actions


func pointer_up(path: String, position: Vector2, now_msec: int) -> Array[Dictionary]:
	var actions := poll(now_msec)
	if path.is_empty() or path != _pressed_path:
		_clear_press()
		return actions
	if _double_tap_pending:
		actions.append(_action(ActionKind.DOUBLE_TAP, path, position))
		_clear_press()
		return actions
	if _press_consumed or _long_press_emitted:
		_clear_press()
		return actions

	_pending_single_path = path
	_pending_single_position = position
	_pending_single_deadline_msec = now_msec + DOUBLE_TAP_WINDOW_MSEC
	_clear_press()
	return actions


func pointer_cancel(path := "") -> void:
	if path.is_empty() or path == _pressed_path:
		_clear_press()


func poll(now_msec: int) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if (
		not _pressed_path.is_empty()
		and not _press_consumed
		and not _long_press_emitted
		and not _double_tap_pending
		and _pressed_since_msec >= 0
		and now_msec - _pressed_since_msec >= LONG_PRESS_MSEC
	):
		_long_press_emitted = true
		_press_consumed = true
		actions.append(_action(ActionKind.LONG_PRESS, _pressed_path, _pressed_position))

	if (
		not _pending_single_path.is_empty()
		and _pending_single_deadline_msec >= 0
		and now_msec >= _pending_single_deadline_msec
	):
		actions.append(
			_action(ActionKind.SINGLE_TAP, _pending_single_path, _pending_single_position)
		)
		_clear_pending_single()
	return actions


func reset() -> void:
	_clear_press()
	_clear_pending_single()


func _action(kind: ActionKind, path: String, position: Vector2) -> Dictionary:
	return {"kind": kind, "path": path, "position": position}


func _clear_press() -> void:
	_pressed_path = ""
	_pressed_since_msec = -1
	_pressed_position = Vector2.ZERO
	_press_consumed = false
	_long_press_emitted = false
	_double_tap_pending = false


func _clear_pending_single() -> void:
	_pending_single_path = ""
	_pending_single_deadline_msec = -1
	_pending_single_position = Vector2.ZERO
