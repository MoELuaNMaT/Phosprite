class_name LayerTouchAdapter
extends Node

const IOS_TOUCH_TAP_SLOP_PX := 12.0
const IOS_TOUCH_DOUBLE_TAP_MSEC := 350
const IOS_TOUCH_MOUSE_FILTER_META := &"phosprite_layer_touch_mouse_filter"
const RENAME_MENU_ID := 1000

var _layer_button: LayerButton
var _main_button: Button
var _popup_menu: PopupMenu
var _ios_touch_candidates: Dictionary = {}
var _ios_touch_ui_mode := false
var _ios_last_tap_msec := -1
var _ios_last_tap_position := Vector2.INF


func _ready() -> void:
	if OS.get_name() != "iOS":
		set_process_input(false)
		return
	call_deferred("_install_ios_layer_touch")


func _input(event: InputEvent) -> void:
	if not _is_ready_for_touch() or not _layer_button.is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		_handle_ios_layer_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_ios_layer_drag(event as InputEventScreenDrag)
	elif (event is InputEventMouseMotion or event is InputEventMouseButton) and event.device != -1:
		_restore_pointer_layer_ui()


func _install_ios_layer_touch() -> void:
	_layer_button = get_parent() as LayerButton
	if not is_instance_valid(_layer_button):
		return
	_main_button = _layer_button.get_node_or_null("LayerMainButton") as Button
	_popup_menu = _layer_button.get_node_or_null("PopupMenu") as PopupMenu
	if not is_instance_valid(_main_button) or not is_instance_valid(_popup_menu):
		return
	if _popup_menu.get_item_index(RENAME_MENU_ID) == -1:
		_popup_menu.add_separator()
		_popup_menu.add_item(tr("Rename"), RENAME_MENU_ID)
	if not _popup_menu.id_pressed.is_connected(_on_popup_menu_id_pressed):
		_popup_menu.id_pressed.connect(_on_popup_menu_id_pressed)


func _handle_ios_layer_touch(event: InputEventScreenTouch) -> bool:
	if event.pressed:
		if not _main_button.get_global_rect().has_point(event.position):
			return false
		_enter_ios_touch_layer_ui()
		_ios_touch_candidates[event.index] = {
			"origin": event.position,
			"cancelled": false,
		}
		return true

	if not _ios_touch_candidates.has(event.index):
		return false
	var candidate: Dictionary = _ios_touch_candidates[event.index]
	_ios_touch_candidates.erase(event.index)
	if bool(candidate.get("cancelled", false)):
		return true
	var origin: Vector2 = candidate.get("origin", event.position)
	if origin.distance_to(event.position) > IOS_TOUCH_TAP_SLOP_PX:
		return true

	_select_layer_for_touch()
	if _register_ios_layer_tap(event.position):
		_popup_menu.popup_on_parent(Rect2(event.position, Vector2.ONE))
	get_viewport().set_input_as_handled()
	return true


func _handle_ios_layer_drag(event: InputEventScreenDrag) -> bool:
	if not _ios_touch_candidates.has(event.index):
		return false
	var candidate: Dictionary = _ios_touch_candidates[event.index]
	if bool(candidate.get("cancelled", false)):
		return false
	var origin: Vector2 = candidate.get("origin", event.position)
	if origin.distance_to(event.position) > IOS_TOUCH_TAP_SLOP_PX:
		candidate["cancelled"] = true
		_ios_touch_candidates[event.index] = candidate
		_reset_ios_last_tap()
		# D4-A deliberately does not claim the drag. The surrounding Timeline ScrollContainer
		# remains authoritative until D4-B adds the approved long-press reorder ownership.
		return false
	return true


func _select_layer_for_touch() -> void:
	Global.transform_content_confirmed.emit()
	_layer_button._select_current_layer()


func _register_ios_layer_tap(screen_position: Vector2) -> bool:
	var now := Time.get_ticks_msec()
	var is_double_tap := (
		_ios_last_tap_msec >= 0
		and now - _ios_last_tap_msec <= IOS_TOUCH_DOUBLE_TAP_MSEC
		and _ios_last_tap_position.distance_to(screen_position) <= IOS_TOUCH_TAP_SLOP_PX
	)
	if is_double_tap:
		_reset_ios_last_tap()
		return true
	_ios_last_tap_msec = now
	_ios_last_tap_position = screen_position
	return false


func _reset_ios_last_tap() -> void:
	_ios_last_tap_msec = -1
	_ios_last_tap_position = Vector2.INF


func _on_popup_menu_id_pressed(id: int) -> void:
	if id == RENAME_MENU_ID:
		_layer_button._show_rename_edit()


func _enter_ios_touch_layer_ui() -> void:
	_ios_touch_ui_mode = true
	if not _main_button.has_meta(IOS_TOUCH_MOUSE_FILTER_META):
		_main_button.set_meta(IOS_TOUCH_MOUSE_FILTER_META, _main_button.mouse_filter)
	_main_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_button.release_focus()


func _restore_pointer_layer_ui() -> void:
	if not _ios_touch_ui_mode:
		return
	_ios_touch_ui_mode = false
	_ios_touch_candidates.clear()
	_reset_ios_last_tap()
	if _main_button.has_meta(IOS_TOUCH_MOUSE_FILTER_META):
		_main_button.mouse_filter = int(_main_button.get_meta(IOS_TOUCH_MOUSE_FILTER_META))
		_main_button.remove_meta(IOS_TOUCH_MOUSE_FILTER_META)


func _is_ready_for_touch() -> bool:
	return (
		OS.get_name() == "iOS"
		and is_instance_valid(_layer_button)
		and is_instance_valid(_main_button)
		and is_instance_valid(_popup_menu)
	)
