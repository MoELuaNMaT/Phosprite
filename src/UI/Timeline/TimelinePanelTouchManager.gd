extends Node

const IOS_TOUCH_TARGET_PX := 44.0
const IOS_FPS_TARGET_WIDTH := 88.0
const IOS_TOOLBAR_SEPARATION := 4
const TAG_EDGE_TOUCH_PX := 22.0
const TAG_DRAG_FROM := 1
const TAG_DRAG_TO := 2
const ANIMATION_BUTTONS_PATH := (
	"TimelineContainer/TimelineButtons/VBoxContainer/AnimationToolsScrollContainer/"
	+ "AnimationTools/MarginContainer/AnimationButtons"
)
const FRAME_BUTTONS_PATH := ANIMATION_BUTTONS_PATH + "/FrameButtons"
const PLAYBACK_BUTTONS_PATH := ANIMATION_BUTTONS_PATH + "/PlaybackButtons"
const LOOP_BUTTONS_PATH := ANIMATION_BUTTONS_PATH + "/LoopButtons"

var _timeline: Control
var _frame_buttons: HBoxContainer
var _playback_buttons: HBoxContainer
var _loop_buttons: HBoxContainer
var _add_frame: Button
var _delete_frame: Button
var _copy_frame: Button
var _move_frame_left: Button
var _move_frame_right: Button
var _first_frame: Button
var _previous_frame: Button
var _play_backwards: Button
var _play_forward: Button
var _next_frame: Button
var _last_frame: Button
var _timeline_settings: Button
var _onion_skinning: Button
var _loop_animation: Button
var _fps_value: Control
var _new_tag_button: Button
var _import_tag_button: Button

var _tag_resize_touch := -1
var _tag_resize_ui: Control
var _tag_resize_side := 0
var _tag_resize_preview: AnimationTag
var _tag_resize_origin_x := 0.0


func _ready() -> void:
	if OS.get_name() != "iOS":
		set_process_input(false)
		queue_free()
		return
	var window := get_window()
	if is_instance_valid(window) and not window.size_changed.is_connected(_on_window_size_changed):
		window.size_changed.connect(_on_window_size_changed)
	call_deferred("_install_ios_timeline_toolbar")


func _exit_tree() -> void:
	var window := get_window()
	if is_instance_valid(window) and window.size_changed.is_connected(_on_window_size_changed):
		window.size_changed.disconnect(_on_window_size_changed)


func _input(event: InputEvent) -> void:
	if not is_instance_valid(_timeline):
		return
	# Direct iPad touch is handled by the enlarged Tag edge zones below. iOS also emits
	# a synthetic mouse event for the same finger. Suppress that emulated mouse only when
	# it lands on a Tag resize edge so the native 8 px ResizeFrom/ResizeTo buttons cannot
	# start a second resize transaction for the same physical gesture. Physical pointer
	# devices keep their native mouse path (the project uses device != -1 for that case).
	if event is InputEventMouse and event.device == -1:
		if not _find_tag_resize_target(event.position).is_empty():
			get_viewport().set_input_as_handled()
			return
	if event is InputEventScreenTouch:
		_handle_tag_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_tag_screen_drag(event as InputEventScreenDrag)


func _on_window_size_changed() -> void:
	# Main.set_mobile_fullscreen_safe_area() intentionally pins MenuAndUI to the current
	# iOS safe-area rectangle. Re-run it whenever iPadOS changes the window geometry so
	# rotation does not leave the old landscape/portrait rectangle surrounded by blank UI.
	if (
		is_instance_valid(Global.control)
		and Global.control.has_method("set_mobile_fullscreen_safe_area")
	):
		Global.control.call_deferred("set_mobile_fullscreen_safe_area")


func _install_ios_timeline_toolbar() -> void:
	_timeline = get_parent() as Control
	if not is_instance_valid(_timeline):
		return
	_frame_buttons = _timeline.get_node_or_null(FRAME_BUTTONS_PATH) as HBoxContainer
	_playback_buttons = _timeline.get_node_or_null(PLAYBACK_BUTTONS_PATH) as HBoxContainer
	_loop_buttons = _timeline.get_node_or_null(LOOP_BUTTONS_PATH) as HBoxContainer
	if not is_instance_valid(_frame_buttons):
		return
	if not is_instance_valid(_playback_buttons) or not is_instance_valid(_loop_buttons):
		return

	_add_frame = _frame_buttons.get_node_or_null("AddFrame") as Button
	_delete_frame = _frame_buttons.get_node_or_null("DeleteFrame") as Button
	_copy_frame = _frame_buttons.get_node_or_null("CopyFrame") as Button
	_move_frame_left = _frame_buttons.get_node_or_null("MoveFrameLeft") as Button
	_move_frame_right = _frame_buttons.get_node_or_null("MoveFrameRight") as Button
	_first_frame = _playback_buttons.get_node_or_null("FirstFrame") as Button
	_previous_frame = _playback_buttons.get_node_or_null("PreviousFrame") as Button
	_play_backwards = _playback_buttons.get_node_or_null("PlayBackwards") as Button
	_play_forward = _playback_buttons.get_node_or_null("PlayForward") as Button
	_next_frame = _playback_buttons.get_node_or_null("NextFrame") as Button
	_last_frame = _playback_buttons.get_node_or_null("LastFrame") as Button
	_timeline_settings = _loop_buttons.get_node_or_null("TimelineSettingsButton") as Button
	_onion_skinning = _loop_buttons.get_node_or_null("OnionSkinning") as Button
	_loop_animation = _loop_buttons.get_node_or_null("LoopAnim") as Button
	_fps_value = _loop_buttons.get_node_or_null("FPSValue") as Control
	if not _all_toolbar_nodes_valid():
		return

	_configure_touch_geometry()
	_build_tag_buttons()
	if not Global.cel_switched.is_connected(_on_timeline_state_changed):
		Global.cel_switched.connect(_on_timeline_state_changed)
	if not Global.project_switched.is_connected(_on_timeline_state_changed):
		Global.project_switched.connect(_on_timeline_state_changed)
	call_deferred("_sync_action_states")


func _all_toolbar_nodes_valid() -> bool:
	return (
		is_instance_valid(_add_frame)
		and is_instance_valid(_delete_frame)
		and is_instance_valid(_copy_frame)
		and is_instance_valid(_move_frame_left)
		and is_instance_valid(_move_frame_right)
		and is_instance_valid(_first_frame)
		and is_instance_valid(_previous_frame)
		and is_instance_valid(_play_backwards)
		and is_instance_valid(_play_forward)
		and is_instance_valid(_next_frame)
		and is_instance_valid(_last_frame)
		and is_instance_valid(_timeline_settings)
		and is_instance_valid(_onion_skinning)
		and is_instance_valid(_loop_animation)
		and is_instance_valid(_fps_value)
	)


func _configure_touch_geometry() -> void:
	_frame_buttons.add_theme_constant_override("separation", IOS_TOOLBAR_SEPARATION)
	_playback_buttons.add_theme_constant_override("separation", IOS_TOOLBAR_SEPARATION)
	_loop_buttons.add_theme_constant_override("separation", IOS_TOOLBAR_SEPARATION)

	for button in [
		_add_frame,
		_delete_frame,
		_previous_frame,
		_play_backwards,
		_play_forward,
		_next_frame,
		_onion_skinning,
		_loop_animation,
	]:
		button.custom_minimum_size = Vector2(IOS_TOUCH_TARGET_PX, IOS_TOUCH_TARGET_PX)
	_fps_value.custom_minimum_size = Vector2(IOS_FPS_TARGET_WIDTH, IOS_TOUCH_TARGET_PX)

	# Preserve the desktop controls and their business handlers, but use gestures
	# and Frame/Cel long-press menus on iPad instead of the overflow popup.
	_copy_frame.hide()
	_move_frame_left.hide()
	_move_frame_right.hide()
	_first_frame.hide()
	_last_frame.hide()
	_timeline_settings.custom_minimum_size = Vector2(IOS_TOUCH_TARGET_PX, IOS_TOUCH_TARGET_PX)


func _build_tag_buttons() -> void:
	_new_tag_button = Button.new()
	_new_tag_button.name = "TimelineNewTagButton"
	_new_tag_button.text = tr("New Tag")
	_new_tag_button.tooltip_text = tr("Create animation tag at the current frame")
	_new_tag_button.custom_minimum_size = Vector2(76.0, IOS_TOUCH_TARGET_PX)
	_new_tag_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_new_tag_button.pressed.connect(_on_new_tag_pressed)
	_frame_buttons.add_child(_new_tag_button)
	_frame_buttons.move_child(_new_tag_button, _delete_frame.get_index() + 1)

	_import_tag_button = Button.new()
	_import_tag_button.name = "TimelineImportTagButton"
	_import_tag_button.text = tr("Import Tag")
	_import_tag_button.tooltip_text = tr("Import an animation tag from an open project")
	_import_tag_button.custom_minimum_size = Vector2(92.0, IOS_TOUCH_TARGET_PX)
	_import_tag_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_import_tag_button.pressed.connect(_on_import_tag_pressed)
	_frame_buttons.add_child(_import_tag_button)
	_frame_buttons.move_child(_import_tag_button, _new_tag_button.get_index() + 1)


func _on_timeline_state_changed() -> void:
	call_deferred("_sync_tag_button_states")


func _sync_tag_button_states() -> void:
	if not is_instance_valid(_new_tag_button) or not is_instance_valid(_import_tag_button):
		return
	var has_frame := is_instance_valid(_current_frame_button())
	_new_tag_button.disabled = not has_frame
	_import_tag_button.disabled = not has_frame


func _on_new_tag_pressed() -> void:
	_call_current_frame_menu_action(5)


func _on_import_tag_pressed() -> void:
	_call_current_frame_menu_action(6)


func _call_current_frame_menu_action(id: int) -> void:
	var frame_button := _current_frame_button()
	if is_instance_valid(frame_button) and frame_button.has_method("_on_PopupMenu_id_pressed"):
		frame_button.call("_on_PopupMenu_id_pressed", id)


func _current_frame_button() -> Control:
	if not is_instance_valid(_timeline) or Global.current_project == null:
		return null
	var frame_hbox := _timeline.get("frame_hbox") as HBoxContainer
	var frame := Global.current_project.current_frame
	if not is_instance_valid(frame_hbox) or frame < 0 or frame >= frame_hbox.get_child_count():
		return null
	return frame_hbox.get_child(frame) as Control


func _handle_tag_screen_touch(event: InputEventScreenTouch) -> bool:
	if event.canceled:
		if event.index == _tag_resize_touch:
			_finish_tag_resize(false)
			get_viewport().set_input_as_handled()
			return true
		return false
	if event.pressed:
		if _tag_resize_touch >= 0:
			return false
		var target := _find_tag_resize_target(event.position)
		if target.is_empty():
			return false
		var tag_ui := target.get("tag_ui") as Control
		var side := int(target.get("side", 0))
		if not is_instance_valid(tag_ui) or side == 0:
			return false
		var source_tag = tag_ui.get("tag")
		if source_tag is not AnimationTag:
			return false
		_tag_resize_touch = event.index
		_tag_resize_ui = tag_ui
		_tag_resize_side = side
		_tag_resize_preview = source_tag.duplicate()
		var rect := tag_ui.get_global_rect()
		_tag_resize_origin_x = rect.position.x if side == TAG_DRAG_FROM else rect.end.x
		get_viewport().set_input_as_handled()
		return true
	if event.index != _tag_resize_touch:
		return false
	_update_tag_resize_preview(event.position.x)
	_finish_tag_resize(true)
	get_viewport().set_input_as_handled()
	return true


func _handle_tag_screen_drag(event: InputEventScreenDrag) -> bool:
	if event.index != _tag_resize_touch or not is_instance_valid(_tag_resize_ui):
		return false
	_update_tag_resize_preview(event.position.x)
	get_viewport().set_input_as_handled()
	return true


func _tag_resize_side_for_x(rect: Rect2, screen_x: float) -> int:
	var left_distance := absf(screen_x - rect.position.x)
	var right_distance := absf(screen_x - rect.end.x)
	var left_hit := left_distance <= TAG_EDGE_TOUCH_PX
	var right_hit := right_distance <= TAG_EDGE_TOUCH_PX
	if not left_hit and not right_hit:
		return 0
	if left_hit and right_hit:
		var center_margin := rect.size.x / 3.0
		var center_start := rect.position.x + center_margin
		var center_end := rect.end.x - center_margin
		if screen_x >= center_start and screen_x <= center_end:
			return 0
	return TAG_DRAG_FROM if left_distance <= right_distance else TAG_DRAG_TO


func _find_tag_resize_target(screen_position: Vector2) -> Dictionary:
	if not is_instance_valid(_timeline):
		return {}
	var tag_container := _timeline.get("tag_container") as Control
	if not is_instance_valid(tag_container):
		return {}
	var best_target: Dictionary = {}
	var best_distance := INF
	var best_inside_body := false
	for child in tag_container.get_children():
		var tag_ui := child as Control
		if not is_instance_valid(tag_ui) or not tag_ui.is_visible_in_tree():
			continue
		var rect := tag_ui.get_global_rect()
		if screen_position.y < rect.position.y or screen_position.y > rect.end.y:
			continue
		var side := _tag_resize_side_for_x(rect, screen_position.x)
		if side == 0:
			continue
		var edge_x := rect.position.x if side == TAG_DRAG_FROM else rect.end.x
		var distance := absf(screen_position.x - edge_x)
		var inside_body := screen_position.x >= rect.position.x and screen_position.x <= rect.end.x
		var is_better := best_target.is_empty() or distance < best_distance
		if not is_better and is_equal_approx(distance, best_distance):
			# Adjacent Tags can share the exact same boundary x. A touch slightly inside
			# Tag A should choose A's TO edge, while a touch slightly inside Tag B should
			# choose B's FROM edge instead of whichever child happens to be visited first.
			is_better = inside_body and not best_inside_body
		if is_better:
			best_target = {"tag_ui": tag_ui, "side": side}
			best_distance = distance
			best_inside_body = inside_body
	return best_target


func _update_tag_resize_preview(screen_x: float) -> void:
	if not is_instance_valid(_tag_resize_ui) or not is_instance_valid(_tag_resize_preview):
		return
	var source_tag = _tag_resize_ui.get("tag")
	if source_tag is not AnimationTag:
		return
	var cel_size := int(_timeline.get("cel_size"))
	if cel_size <= 0:
		return
	var diff := roundi((screen_x - _tag_resize_origin_x) / float(cel_size))
	if _tag_resize_side == TAG_DRAG_FROM:
		_tag_resize_preview.from = clampi(source_tag.from + diff, 1, source_tag.to)
	elif _tag_resize_side == TAG_DRAG_TO:
		_tag_resize_preview.to = clampi(
			source_tag.to + diff, source_tag.from, Global.current_project.frames.size()
		)
	_tag_resize_ui.call("update_position_and_size", _tag_resize_preview)


func _finish_tag_resize(commit: bool) -> void:
	if is_instance_valid(_tag_resize_ui):
		if commit and is_instance_valid(_tag_resize_preview):
			var value := (
				_tag_resize_preview.from
				if _tag_resize_side == TAG_DRAG_FROM
				else _tag_resize_preview.to
			)
			_tag_resize_ui.call("_resize_tag", _tag_resize_side, value)
		_tag_resize_ui.call("update_position_and_size")
	_tag_resize_touch = -1
	_tag_resize_ui = null
	_tag_resize_side = 0
	_tag_resize_preview = null
	_tag_resize_origin_x = 0.0
