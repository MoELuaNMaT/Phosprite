class_name ProjectCardGestureResolver
extends RefCounted

enum ActionKind { SINGLE_TAP, LONG_PRESS }

const LONG_PRESS_MSEC := 1000

var _pressed_path := ""
var _pressed_since_msec := -1
var _pressed_position := Vector2.ZERO
var _long_press_emitted := false


func pointer_down(path: String, position: Vector2, now_msec: int) -> Array[Dictionary]:
	if path.is_empty():
		return []
	_clear_press()
	_pressed_path = path
	_pressed_since_msec = now_msec
	_pressed_position = position
	_long_press_emitted = false
	return []


func pointer_up(path: String, position: Vector2, now_msec: int) -> Array[Dictionary]:
	var actions := poll(now_msec)
	if path.is_empty() or path != _pressed_path:
		_clear_press()
		return actions
	if _long_press_emitted:
		_clear_press()
		return actions

	# Single tap resolves immediately on release. There is intentionally no
	# double-tap window: opening a project must never wait for another gesture.
	actions.append(_action(ActionKind.SINGLE_TAP, path, position))
	_clear_press()
	return actions


func pointer_cancel(path := "") -> void:
	if path.is_empty() or path == _pressed_path:
		_clear_press()


func poll(now_msec: int) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if (
		not _pressed_path.is_empty()
		and not _long_press_emitted
		and _pressed_since_msec >= 0
		and now_msec - _pressed_since_msec >= LONG_PRESS_MSEC
	):
		_long_press_emitted = true
		actions.append(_action(ActionKind.LONG_PRESS, _pressed_path, _pressed_position))
	return actions


func reset() -> void:
	_clear_press()


func _action(kind: ActionKind, path: String, position: Vector2) -> Dictionary:
	return {"kind": kind, "path": path, "position": position}


func _clear_press() -> void:
	_pressed_path = ""
	_pressed_since_msec = -1
	_pressed_position = Vector2.ZERO
	_long_press_emitted = false
