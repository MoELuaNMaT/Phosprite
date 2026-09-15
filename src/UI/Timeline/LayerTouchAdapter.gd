class_name LayerTouchAdapter
extends Node

const IOS_TOUCH_TAP_SLOP_PX := 12.0
const IOS_TOUCH_DOUBLE_TAP_MSEC := 350
const IOS_TOUCH_REORDER_HOLD_MSEC := 450
const IOS_TOUCH_MOUSE_FILTER_META := &"phosprite_layer_touch_mouse_filter"
const AUTO_SCROLL_MIN_SPEED := 90.0
const AUTO_SCROLL_MAX_SPEED := 520.0
const AUTO_SCROLL_RAMP_PX := 72.0
const PREVIEW_OPACITY := 0.88
const SOURCE_OUTLINE_INSET_PX := 4.0
const SOURCE_OUTLINE_DASH_PX := 3.0
const RENAME_MENU_ID := 1000

var _layer_button: LayerButton
var _main_button: Button
var _popup_menu: PopupMenu
var _ios_touch_candidates: Dictionary = {}
var _ios_touch_ui_mode := false
var _ios_last_tap_msec := -1
var _ios_last_tap_position := Vector2.INF
var _active_reorder_touch := -1
var _managed_scroll := 0.0
var _reorder_data: Array = []
var _reorder_preview: Control = null
var _source_outline: Control = null
var _drop_target: Control = null
var _drop_local_position := Vector2.ZERO


func _ready() -> void:
	if OS.get_name() != "iOS":
		set_process_input(false)
		set_process(false)
		return
	set_process(false)
	call_deferred("_install_ios_layer_touch")


func _exit_tree() -> void:
	_finish_reorder()


func _input(event: InputEvent) -> void:
	if not _is_ready_for_touch() or not _layer_button.is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if _active_rename_owns_touch(touch):
			return
		_handle_ios_layer_touch(touch)
	elif event is InputEventScreenDrag:
		_handle_ios_layer_drag(event as InputEventScreenDrag)
	elif (event is InputEventMouseMotion or event is InputEventMouseButton) and event.device != -1:
		_restore_pointer_layer_ui()


func _process(delta: float) -> void:
	if _active_reorder_touch < 0:
		set_process(false)
		return
	if not _ios_touch_candidates.has(_active_reorder_touch):
		_finish_reorder()
		return
	var candidate: Dictionary = _ios_touch_candidates[_active_reorder_touch]
	if not bool(candidate.get("reordering", false)):
		_finish_reorder()
		return
	var screen_position: Vector2 = candidate.get("position", Vector2.ZERO)
	_update_reorder_feedback(screen_position, delta)


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


func _active_rename_owns_touch(event: InputEventScreenTouch) -> bool:
	if not event.pressed or not _layer_button.line_edit.visible:
		return false
	if _layer_button.line_edit.get_global_rect().has_point(event.position):
		return true
	# Hiding the iOS keyboard does not release LineEdit focus. The next direct touch outside
	# the editor must do so explicitly, allowing the existing focus_exited rename transaction
	# to commit before that same touch continues into the rest of the UI.
	_layer_button.line_edit.release_focus()
	return false


func _handle_ios_layer_touch(event: InputEventScreenTouch) -> bool:
	if event.canceled:
		var was_reordering := false
		if _ios_touch_candidates.has(event.index):
			var canceled_candidate: Dictionary = _ios_touch_candidates[event.index]
			was_reordering = bool(canceled_candidate.get("reordering", false))
			_ios_touch_candidates.erase(event.index)
		if was_reordering or event.index == _active_reorder_touch:
			_finish_reorder()
			get_viewport().set_input_as_handled()
		return was_reordering

	if event.pressed:
		if not _main_button.get_global_rect().has_point(event.position):
			return false
		_enter_ios_touch_layer_ui()
		_ios_touch_candidates[event.index] = {
			"origin": event.position,
			"position": event.position,
			"pressed_msec": Time.get_ticks_msec(),
			"cancelled": false,
			"reordering": false,
		}
		return true

	if not _ios_touch_candidates.has(event.index):
		return false
	var candidate: Dictionary = _ios_touch_candidates[event.index]
	if bool(candidate.get("reordering", false)):
		candidate["position"] = event.position
		_ios_touch_candidates[event.index] = candidate
		_update_reorder_feedback(event.position, 0.0)
		_commit_reorder_if_valid()
		_ios_touch_candidates.erase(event.index)
		_finish_reorder()
		get_viewport().set_input_as_handled()
		return true

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
	candidate["position"] = event.position
	if bool(candidate.get("reordering", false)):
		_ios_touch_candidates[event.index] = candidate
		_update_reorder_feedback(event.position, 0.0)
		get_viewport().set_input_as_handled()
		return true

	var pressed_msec: int = int(candidate.get("pressed_msec", Time.get_ticks_msec()))
	var held_msec := Time.get_ticks_msec() - pressed_msec
	if held_msec >= IOS_TOUCH_REORDER_HOLD_MSEC:
		_ios_touch_candidates[event.index] = candidate
		_begin_reorder(event.index, event.position)
		get_viewport().set_input_as_handled()
		return true

	var origin: Vector2 = candidate.get("origin", event.position)
	if origin.distance_to(event.position) > IOS_TOUCH_TAP_SLOP_PX:
		candidate["cancelled"] = true
		_ios_touch_candidates[event.index] = candidate
		_reset_ios_last_tap()
		# Before reorder ownership, vertical movement belongs to the Timeline ScrollContainer.
		return false
	_ios_touch_candidates[event.index] = candidate
	return true


func _begin_reorder(touch_index: int, screen_position: Vector2) -> void:
	if _active_reorder_touch >= 0 or not _ios_touch_candidates.has(touch_index):
		return
	if not _main_button.button_pressed:
		_select_layer_for_touch()
	var data: Array = _main_button.call("_build_layer_drag_data")
	if data.size() < 2:
		return
	# Touch reorder always means Move/Reparent. Desktop Ctrl/Cmd drag keeps its native Swap mode.
	data.append(false)
	var candidate: Dictionary = _ios_touch_candidates[touch_index]
	candidate["reordering"] = true
	candidate["position"] = screen_position
	_ios_touch_candidates[touch_index] = candidate
	_active_reorder_touch = touch_index
	_reorder_data = data
	_reset_ios_last_tap()
	var scroll := _timeline_scroll()
	if is_instance_valid(scroll):
		_managed_scroll = float(scroll.scroll_vertical)
	_create_reorder_preview()
	_create_source_outline()
	set_process(true)
	_update_reorder_feedback(screen_position, 0.0)


func _commit_reorder_if_valid() -> void:
	if not is_instance_valid(_drop_target) or _reorder_data.is_empty():
		return
	_drop_target.call("_drop_data", _drop_local_position, _reorder_data)


func _update_reorder_feedback(screen_position: Vector2, delta: float) -> void:
	_update_preview_position(screen_position)
	_update_managed_scroll(screen_position, delta)
	_update_drop_target(screen_position)
	_hold_managed_scroll_inside_visible_area(screen_position)


func _update_drop_target(screen_position: Vector2) -> void:
	_drop_target = null
	_drop_local_position = Vector2.ZERO
	var timeline := Global.animation_timeline
	var scroll := _timeline_scroll()
	if not is_instance_valid(timeline) or not is_instance_valid(scroll):
		_clear_drop_highlight()
		return
	var layer_vbox := timeline.layer_vbox as Control
	if not is_instance_valid(layer_vbox):
		_clear_drop_highlight()
		return
	var visible_layer_rect := layer_vbox.get_global_rect().intersection(scroll.get_global_rect())
	if not visible_layer_rect.has_point(screen_position):
		_clear_drop_highlight()
		return
	for child in layer_vbox.get_children():
		var layer_control := child as Control
		if not is_instance_valid(layer_control) or not layer_control.is_visible_in_tree():
			continue
		if not layer_control.get_global_rect().has_point(screen_position):
			continue
		var target_main := layer_control.get_node_or_null("LayerMainButton") as Control
		if not is_instance_valid(target_main):
			break
		var local_position := screen_position - target_main.get_global_rect().position
		if bool(target_main.call("_can_drop_data", local_position, _reorder_data)):
			_drop_target = target_main
			_drop_local_position = local_position
			return
		break
	_clear_drop_highlight()


func _update_managed_scroll(screen_position: Vector2, delta: float) -> void:
	var scroll := _timeline_scroll()
	if not is_instance_valid(scroll):
		return
	var visible_rect := scroll.get_global_rect()
	var overflow := 0.0
	if screen_position.y < visible_rect.position.y:
		overflow = screen_position.y - visible_rect.position.y
	elif screen_position.y > visible_rect.end.y:
		overflow = screen_position.y - visible_rect.end.y
	if is_zero_approx(overflow):
		# Reorder owns the gesture now. Keep the Timeline still while the finger remains inside.
		scroll.scroll_vertical = int(round(_managed_scroll))
		return
	var strength := clampf(absf(overflow) / AUTO_SCROLL_RAMP_PX, 0.0, 1.0)
	var speed := lerpf(AUTO_SCROLL_MIN_SPEED, AUTO_SCROLL_MAX_SPEED, strength)
	_managed_scroll += signf(overflow) * speed * delta
	var scroll_bar := scroll.get_v_scroll_bar()
	var max_scroll := maxf(0.0, scroll_bar.max_value - scroll_bar.page)
	_managed_scroll = clampf(_managed_scroll, 0.0, max_scroll)
	scroll.scroll_vertical = int(round(_managed_scroll))


func _hold_managed_scroll_inside_visible_area(screen_position: Vector2) -> void:
	var scroll := _timeline_scroll()
	if not is_instance_valid(scroll):
		return
	var visible_rect := scroll.get_global_rect()
	if screen_position.y >= visible_rect.position.y and screen_position.y <= visible_rect.end.y:
		# Existing _can_drop_data() may call ensure_control_visible(). Touch reorder deliberately
		# overrides that while the finger is inside, so only edge overflow scrolls the Timeline.
		scroll.scroll_vertical = int(round(_managed_scroll))


func _create_reorder_preview() -> void:
	_clear_reorder_preview()
	if _reorder_data.size() < 2:
		return
	var layers: PackedInt32Array = _reorder_data[1]
	var preview := VBoxContainer.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1.0, 1.0, 1.0, PREVIEW_OPACITY)
	preview.z_index = 4096
	for i in layers.size():
		var button := Button.new()
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.custom_minimum_size = _main_button.size
		button.theme = Global.control.theme
		button.text = Global.current_project.layers[layers[-1 - i]].name
		preview.add_child(button)
	get_tree().root.add_child(preview)
	_reorder_preview = preview


func _update_preview_position(screen_position: Vector2) -> void:
	if not is_instance_valid(_reorder_preview):
		return
	_reorder_preview.global_position = screen_position - _main_button.size * 0.5


func _create_source_outline() -> void:
	_clear_source_outline()
	var outline := Control.new()
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.z_index = 64
	_main_button.add_child(outline)
	outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outline.draw.connect(_draw_source_outline.bind(outline))
	outline.queue_redraw()
	_source_outline = outline


func _draw_source_outline(outline: Control) -> void:
	var inset := SOURCE_OUTLINE_INSET_PX
	var top_left := Vector2(inset, inset)
	var top_right := Vector2(outline.size.x - inset, inset)
	var bottom_left := Vector2(inset, outline.size.y - inset)
	var bottom_right := Vector2(outline.size.x - inset, outline.size.y - inset)
	var edges := [
		[top_left, top_right],
		[top_right, bottom_right],
		[bottom_right, bottom_left],
		[bottom_left, top_left],
	]
	for edge in edges:
		outline.draw_dashed_line(
			edge[0], edge[1], Color(0.0, 0.0, 0.0, 0.85), 3.0, SOURCE_OUTLINE_DASH_PX
		)
		outline.draw_dashed_line(
			edge[0], edge[1], Color(1.0, 1.0, 1.0, 0.95), 1.0, SOURCE_OUTLINE_DASH_PX
		)


func _finish_reorder() -> void:
	_active_reorder_touch = -1
	_reorder_data.clear()
	_drop_target = null
	_drop_local_position = Vector2.ZERO
	set_process(false)
	_clear_drop_highlight()
	_clear_reorder_preview()
	_clear_source_outline()


func _clear_drop_highlight() -> void:
	if is_instance_valid(Global.animation_timeline):
		Global.animation_timeline.drag_highlight.hide()


func _clear_reorder_preview() -> void:
	if is_instance_valid(_reorder_preview):
		_reorder_preview.queue_free()
	_reorder_preview = null


func _clear_source_outline() -> void:
	if is_instance_valid(_source_outline):
		_source_outline.queue_free()
	_source_outline = null


func _timeline_scroll() -> ScrollContainer:
	if not is_instance_valid(Global.animation_timeline):
		return null
	return Global.animation_timeline.timeline_scroll as ScrollContainer


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
	_finish_reorder()
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
