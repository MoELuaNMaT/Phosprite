extends Node

enum TouchTargetKind { NONE, CEL, FRAME }

const IOS_TOUCH_TAP_SLOP_PX := 12.0
const IOS_TOUCH_DOUBLE_TAP_MSEC := 350
const IOS_MULTI_SELECT_WIDTH := 72.0
const IOS_MULTI_SELECT_HEIGHT := 44.0
const IOS_TOUCH_MOUSE_FILTER_META := &"phosprite_timeline_touch_mouse_filter"
const FRAME_BUTTONS_PATH := (
	"TimelineContainer/TimelineButtons/VBoxContainer/AnimationToolsScrollContainer/"
	+ "AnimationTools/MarginContainer/AnimationButtons/FrameButtons"
)
const FRAME_MENU_REMOVE := 1
const FRAME_MENU_MOVE_LEFT := 3
const FRAME_MENU_MOVE_RIGHT := 4
const FRAME_MENU_REVERSE := 7

var _timeline: Control
var _multi_select_button: Button
var _touch_candidates: Dictionary = {}
var _suppressed_controls: Array[Control] = []
var _last_tap_msec := -1
var _last_tap_position := Vector2.INF
var _last_tap_key := ""


func _ready() -> void:
	if OS.get_name() != "iOS":
		set_process_input(false)
		queue_free()
		return
	call_deferred("_install_ios_timeline_selection")


func _exit_tree() -> void:
	_restore_pointer_timeline_ui()


func _input(event: InputEvent) -> void:
	if not _is_ready_for_touch():
		return
	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)
	elif (event is InputEventMouseMotion or event is InputEventMouseButton) and event.device != -1:
		_restore_pointer_timeline_ui()


func _install_ios_timeline_selection() -> void:
	_timeline = get_parent() as Control
	if not is_instance_valid(_timeline):
		return
	var frame_buttons := _timeline.get_node_or_null(FRAME_BUTTONS_PATH) as HBoxContainer
	if not is_instance_valid(frame_buttons):
		return
	_multi_select_button = Button.new()
	_multi_select_button.name = "TimelineMultiSelectButton"
	_multi_select_button.text = tr("Select")
	_multi_select_button.tooltip_text = tr("Toggle Timeline multi-select mode")
	_multi_select_button.toggle_mode = true
	_multi_select_button.custom_minimum_size = Vector2(
		IOS_MULTI_SELECT_WIDTH, IOS_MULTI_SELECT_HEIGHT
	)
	_multi_select_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_multi_select_button.toggled.connect(_on_multi_select_toggled)
	frame_buttons.add_child(_multi_select_button)
	frame_buttons.move_child(_multi_select_button, 0)
	if not Global.project_about_to_switch.is_connected(_on_project_about_to_switch):
		Global.project_about_to_switch.connect(_on_project_about_to_switch)
	if not Global.project_switched.is_connected(_on_project_switched):
		Global.project_switched.connect(_on_project_switched)


func _handle_screen_touch(event: InputEventScreenTouch) -> bool:
	if event.canceled:
		_touch_candidates.erase(event.index)
		_reset_last_tap()
		return false

	if event.pressed:
		var target_data := _find_touch_target(event.position)
		if target_data.is_empty():
			return false
		var target := target_data.get("control") as Control
		_suppress_synthetic_mouse(target)
		_touch_candidates[event.index] = {
			"origin": event.position,
			"target": target,
			"kind": int(target_data.get("kind", TouchTargetKind.NONE)),
			"cancelled": false,
		}
		return true

	if not _touch_candidates.has(event.index):
		return false
	var candidate: Dictionary = _touch_candidates[event.index]
	_touch_candidates.erase(event.index)
	if bool(candidate.get("cancelled", false)):
		return false
	var origin: Vector2 = candidate.get("origin", event.position)
	if origin.distance_to(event.position) > IOS_TOUCH_TAP_SLOP_PX:
		_reset_last_tap()
		return false
	var target := candidate.get("target") as Control
	if not is_instance_valid(target):
		return false
	var kind := int(candidate.get("kind", TouchTargetKind.NONE))
	var tap_key := _touch_target_key(kind, target)
	if _register_tap(tap_key, event.position):
		_show_existing_context_menu(kind, target, event.position)
	else:
		_apply_touch_selection(kind, target)
	get_viewport().set_input_as_handled()
	return true


func _handle_screen_drag(event: InputEventScreenDrag) -> bool:
	if not _touch_candidates.has(event.index):
		return false
	var candidate: Dictionary = _touch_candidates[event.index]
	if bool(candidate.get("cancelled", false)):
		return false
	var origin: Vector2 = candidate.get("origin", event.position)
	if origin.distance_to(event.position) > IOS_TOUCH_TAP_SLOP_PX:
		candidate["cancelled"] = true
		_touch_candidates[event.index] = candidate
		_reset_last_tap()
		# E1 never acquires drag ownership. Movement remains available to the existing
		# Timeline ScrollContainers; E2 will add long-press Frame/Cel reorder ownership.
		return false
	return true


func _find_touch_target(screen_position: Vector2) -> Dictionary:
	if not is_instance_valid(_timeline):
		return {}
	var frame_hbox := _timeline.get("frame_hbox") as HBoxContainer
	if is_instance_valid(frame_hbox):
		for child in frame_hbox.get_children():
			var frame_button := child as Control
			if (
				is_instance_valid(frame_button)
				and frame_button.is_visible_in_tree()
				and frame_button.get_global_rect().has_point(screen_position)
			):
				return {"kind": TouchTargetKind.FRAME, "control": frame_button}

	var cel_vbox := _timeline.get("cel_vbox") as VBoxContainer
	if is_instance_valid(cel_vbox):
		for row in cel_vbox.get_children():
			var cel_row := row as Control
			if not is_instance_valid(cel_row) or not cel_row.is_visible_in_tree():
				continue
			for child in cel_row.get_children():
				var cel_button := child as Control
				if (
					is_instance_valid(cel_button)
					and cel_button.is_visible_in_tree()
					and cel_button.get_global_rect().has_point(screen_position)
				):
					return {"kind": TouchTargetKind.CEL, "control": cel_button}
	return {}


func _apply_touch_selection(kind: int, target: Control) -> void:
	match kind:
		TouchTargetKind.CEL:
			_select_cel_for_touch(target)
		TouchTargetKind.FRAME:
			_select_frame_for_touch(target)


func _select_cel_for_touch(cel_button: Control) -> void:
	var project := Global.current_project
	var frame := int(cel_button.get("frame"))
	var layer := int(cel_button.get("layer"))
	var frame_layer := [frame, layer]
	if not _multi_select_enabled():
		project.selected_cels.clear()
		project.selected_cels.append(frame_layer)
		project.change_cel(frame, layer)
		return

	if project.selected_cels.has(frame_layer):
		if project.selected_cels.size() <= 1:
			project.change_cel(frame, layer)
			return
		project.selected_cels.erase(frame_layer)
		if project.current_frame == frame and project.current_layer == layer:
			var fallback: Array = project.selected_cels[0]
			project.change_cel(fallback[0], fallback[1])
		else:
			project.change_cel(project.current_frame, project.current_layer)
	else:
		project.selected_cels.append(frame_layer)
		project.change_cel(frame, layer)


func _select_frame_for_touch(frame_button: Control) -> void:
	var project := Global.current_project
	var frame := int(frame_button.get("frame"))
	if not _multi_select_enabled():
		project.selected_cels.clear()
		project.selected_cels.append([frame, project.current_layer])
		project.change_cel(frame, project.current_layer)
		return

	var frame_cels: Array = []
	var all_selected := true
	for layer in project.layers.size():
		var frame_layer := [frame, layer]
		frame_cels.append(frame_layer)
		if not project.selected_cels.has(frame_layer):
			all_selected = false

	if all_selected:
		for frame_layer in frame_cels:
			project.selected_cels.erase(frame_layer)
		if project.selected_cels.is_empty():
			project.selected_cels.append([frame, project.current_layer])
			project.change_cel(frame, project.current_layer)
		elif project.current_frame == frame:
			var fallback: Array = project.selected_cels[0]
			project.change_cel(fallback[0], fallback[1])
		else:
			project.change_cel(project.current_frame, project.current_layer)
	else:
		for frame_layer in frame_cels:
			if not project.selected_cels.has(frame_layer):
				project.selected_cels.append(frame_layer)
		project.change_cel(frame, project.current_layer)


func _show_existing_context_menu(kind: int, target: Control, screen_position: Vector2) -> void:
	var popup := target.get_node_or_null("PopupMenu") as PopupMenu
	if not is_instance_valid(popup):
		return
	if kind == TouchTargetKind.FRAME:
		_prepare_frame_popup(popup, int(target.get("frame")))
	popup.popup_on_parent(Rect2(screen_position, Vector2.ONE))


func _prepare_frame_popup(popup: PopupMenu, frame: int) -> void:
	var project := Global.current_project
	var single_frame := project.frames.size() == 1
	popup.set_item_disabled(FRAME_MENU_REMOVE, single_frame)
	popup.set_item_disabled(FRAME_MENU_MOVE_LEFT, single_frame or frame <= 0)
	popup.set_item_disabled(
		FRAME_MENU_MOVE_RIGHT, single_frame or frame >= project.frames.size() - 1
	)
	popup.set_item_disabled(FRAME_MENU_REVERSE, single_frame or project.selected_cels.size() <= 1)


func _touch_target_key(kind: int, target: Control) -> String:
	if kind == TouchTargetKind.CEL:
		return "cel:%s:%s" % [int(target.get("frame")), int(target.get("layer"))]
	if kind == TouchTargetKind.FRAME:
		return "frame:%s" % int(target.get("frame"))
	return ""


func _register_tap(tap_key: String, screen_position: Vector2) -> bool:
	var now := Time.get_ticks_msec()
	var is_double_tap := (
		_last_tap_msec >= 0
		and tap_key == _last_tap_key
		and now - _last_tap_msec <= IOS_TOUCH_DOUBLE_TAP_MSEC
		and _last_tap_position.distance_to(screen_position) <= IOS_TOUCH_TAP_SLOP_PX
	)
	if is_double_tap:
		_reset_last_tap()
		return true
	_last_tap_msec = now
	_last_tap_position = screen_position
	_last_tap_key = tap_key
	return false


func _suppress_synthetic_mouse(control: Control) -> void:
	if not is_instance_valid(control):
		return
	if not control.has_meta(IOS_TOUCH_MOUSE_FILTER_META):
		control.set_meta(IOS_TOUCH_MOUSE_FILTER_META, control.mouse_filter)
		_suppressed_controls.append(control)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.release_focus()


func _restore_pointer_timeline_ui() -> void:
	_touch_candidates.clear()
	_reset_last_tap()
	for control in _suppressed_controls:
		if not is_instance_valid(control):
			continue
		if control.has_meta(IOS_TOUCH_MOUSE_FILTER_META):
			control.mouse_filter = int(control.get_meta(IOS_TOUCH_MOUSE_FILTER_META))
			control.remove_meta(IOS_TOUCH_MOUSE_FILTER_META)
	_suppressed_controls.clear()


func _on_multi_select_toggled(_enabled: bool) -> void:
	_reset_last_tap()


func _on_project_about_to_switch() -> void:
	_restore_pointer_timeline_ui()


func _on_project_switched() -> void:
	if is_instance_valid(_multi_select_button):
		_multi_select_button.button_pressed = false
	_reset_last_tap()


func _multi_select_enabled() -> bool:
	return is_instance_valid(_multi_select_button) and _multi_select_button.button_pressed


func _reset_last_tap() -> void:
	_last_tap_msec = -1
	_last_tap_position = Vector2.INF
	_last_tap_key = ""


func _is_ready_for_touch() -> bool:
	return OS.get_name() == "iOS" and is_instance_valid(_timeline)
