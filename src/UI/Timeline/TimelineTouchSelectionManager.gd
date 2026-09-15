extends Node

enum TouchTargetKind { NONE, CEL, FRAME }

const IOS_TOUCH_TAP_SLOP_PX := 12.0
const IOS_TOUCH_DOUBLE_TAP_MSEC := 350
const IOS_TOUCH_REORDER_HOLD_MSEC := 450
const IOS_MULTI_SELECT_WIDTH := 72.0
const IOS_MULTI_SELECT_HEIGHT := 44.0
const IOS_TOUCH_MOUSE_FILTER_META := &"phosprite_timeline_touch_mouse_filter"
const AUTO_SCROLL_MIN_SPEED := 90.0
const AUTO_SCROLL_MAX_SPEED := 520.0
const AUTO_SCROLL_RAMP_PX := 72.0
const PREVIEW_OPACITY := 0.88
const SOURCE_OUTLINE_INSET_PX := 4.0
const SOURCE_OUTLINE_DASH_PX := 3.0
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
var _last_tap_selection_snapshot: Dictionary = {}
var _active_reorder_touch := -1
var _reorder_kind := TouchTargetKind.NONE
var _reorder_data: Array = []
var _reorder_source: Control
var _reorder_preview: Control
var _source_outline: Control
var _drop_target: Control
var _drop_local_position := Vector2.ZERO
var _managed_horizontal_scroll := 0.0
var _managed_vertical_scroll := 0.0


func _ready() -> void:
	if OS.get_name() != "iOS":
		set_process_input(false)
		set_process(false)
		queue_free()
		return
	set_process(false)
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


func _process(delta: float) -> void:
	if _active_reorder_touch < 0:
		set_process(false)
		return
	if not _touch_candidates.has(_active_reorder_touch):
		_finish_reorder()
		return
	var candidate: Dictionary = _touch_candidates[_active_reorder_touch]
	if not bool(candidate.get("reordering", false)):
		_finish_reorder()
		return
	var screen_position: Vector2 = candidate.get("position", Vector2.ZERO)
	_update_reorder_feedback(screen_position, delta)


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
		var was_reordering := false
		if _touch_candidates.has(event.index):
			var canceled_candidate: Dictionary = _touch_candidates[event.index]
			was_reordering = bool(canceled_candidate.get("reordering", false))
			_touch_candidates.erase(event.index)
		if was_reordering or event.index == _active_reorder_touch:
			_finish_reorder()
			get_viewport().set_input_as_handled()
		_reset_last_tap()
		return was_reordering

	if event.pressed:
		var target_data := _find_touch_target(event.position)
		if target_data.is_empty():
			return false
		var target := target_data.get("control") as Control
		_suppress_synthetic_mouse(target)
		_touch_candidates[event.index] = {
			"origin": event.position,
			"position": event.position,
			"pressed_msec": Time.get_ticks_msec(),
			"target": target,
			"kind": int(target_data.get("kind", TouchTargetKind.NONE)),
			"cancelled": false,
			"reordering": false,
		}
		return true

	if not _touch_candidates.has(event.index):
		return false
	var candidate: Dictionary = _touch_candidates[event.index]
	if bool(candidate.get("reordering", false)):
		candidate["position"] = event.position
		_touch_candidates[event.index] = candidate
		_update_reorder_feedback(event.position, 0.0)
		_commit_reorder_if_valid()
		_touch_candidates.erase(event.index)
		_finish_reorder()
		get_viewport().set_input_as_handled()
		return true

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
		# Single taps stay immediate. A confirmed double tap restores the exact
		# pre-first-tap selection/focus state before opening the existing menu.
		_restore_last_tap_selection_snapshot()
		_show_existing_context_menu(kind, target, event.position)
		_reset_last_tap()
	else:
		_last_tap_selection_snapshot = _capture_selection_snapshot()
		_apply_touch_selection(kind, target)
	get_viewport().set_input_as_handled()
	return true


func _handle_screen_drag(event: InputEventScreenDrag) -> bool:
	if not _touch_candidates.has(event.index):
		return false
	var candidate: Dictionary = _touch_candidates[event.index]
	if bool(candidate.get("cancelled", false)):
		return false
	candidate["position"] = event.position
	if bool(candidate.get("reordering", false)):
		_touch_candidates[event.index] = candidate
		_update_reorder_feedback(event.position, 0.0)
		get_viewport().set_input_as_handled()
		return true

	var pressed_msec := int(candidate.get("pressed_msec", Time.get_ticks_msec()))
	var held_msec := Time.get_ticks_msec() - pressed_msec
	if held_msec >= IOS_TOUCH_REORDER_HOLD_MSEC:
		_touch_candidates[event.index] = candidate
		if _begin_reorder(event.index, event.position):
			get_viewport().set_input_as_handled()
			return true

	var origin: Vector2 = candidate.get("origin", event.position)
	if origin.distance_to(event.position) > IOS_TOUCH_TAP_SLOP_PX:
		candidate["cancelled"] = true
		_touch_candidates[event.index] = candidate
		_reset_last_tap()
		# Before long-press ownership, movement belongs to the existing Timeline scroll views.
		return false
	_touch_candidates[event.index] = candidate
	return true


func _begin_reorder(touch_index: int, screen_position: Vector2) -> bool:
	if _active_reorder_touch >= 0 or not _touch_candidates.has(touch_index):
		return false
	var candidate: Dictionary = _touch_candidates[touch_index]
	var source := candidate.get("target") as Control
	var kind := int(candidate.get("kind", TouchTargetKind.NONE))
	if not is_instance_valid(source) or kind == TouchTargetKind.NONE:
		return false
	_prepare_source_selection_for_reorder(kind, source)
	var data := _build_reorder_data(kind, source)
	if data.size() < 2:
		return false
	candidate["reordering"] = true
	candidate["position"] = screen_position
	_touch_candidates[touch_index] = candidate
	_active_reorder_touch = touch_index
	_reorder_kind = kind
	_reorder_data = data
	_reorder_source = source
	_reset_last_tap()
	_capture_managed_scroll()
	_create_reorder_preview(source)
	_create_source_outline(source)
	set_process(true)
	_update_reorder_feedback(screen_position, 0.0)
	return true


func _prepare_source_selection_for_reorder(kind: int, source: Control) -> void:
	var project := Global.current_project
	Global.transform_content_confirmed.emit()
	if kind == TouchTargetKind.CEL:
		var frame := int(source.get("frame"))
		var layer := int(source.get("layer"))
		var frame_layer := [frame, layer]
		if not project.selected_cels.has(frame_layer):
			project.selected_cels.clear()
			project.selected_cels.append(frame_layer)
			project.change_cel(frame, layer)
		return
	if kind == TouchTargetKind.FRAME:
		var frame := int(source.get("frame"))
		var frame_is_selected := false
		for frame_layer in project.selected_cels:
			if int(frame_layer[0]) == frame:
				frame_is_selected = true
				break
		if not frame_is_selected:
			project.selected_cels.clear()
			project.selected_cels.append([frame, project.current_layer])
			project.change_cel(frame, project.current_layer)


func _build_reorder_data(kind: int, source: Control) -> Array:
	var data = null
	if kind == TouchTargetKind.CEL and source.has_method("_build_cel_drag_data"):
		# The third payload field explicitly disables Ctrl/Cmd-forced Swap for Finger drag.
		data = source.call("_build_cel_drag_data", false)
	elif kind == TouchTargetKind.FRAME and source.has_method("_build_frame_drag_data"):
		data = source.call("_build_frame_drag_data", false)
	return data if typeof(data) == TYPE_ARRAY else []


func _commit_reorder_if_valid() -> void:
	if not is_instance_valid(_drop_target) or _reorder_data.is_empty():
		return
	var target := _drop_target
	var local_position := _drop_local_position
	target.call("_drop_data", local_position, _reorder_data)


func _update_reorder_feedback(screen_position: Vector2, delta: float) -> void:
	_update_preview_position(screen_position)
	_update_managed_scroll(screen_position, delta)
	_update_drop_target(screen_position)
	_hold_managed_scroll_inside_visible_area(screen_position)


func _update_drop_target(screen_position: Vector2) -> void:
	_drop_target = null
	_drop_local_position = Vector2.ZERO
	if not is_instance_valid(_timeline):
		_clear_drop_highlight()
		return
	var horizontal_rect := _horizontal_visible_rect()
	if not horizontal_rect.has_point(screen_position):
		_clear_drop_highlight()
		return
	if _reorder_kind == TouchTargetKind.CEL:
		var vertical_rect := _vertical_visible_rect()
		if not vertical_rect.has_point(screen_position):
			_clear_drop_highlight()
			return
	var target := _find_drop_control(_reorder_kind, screen_position)
	if not is_instance_valid(target):
		_clear_drop_highlight()
		return
	var local_position := screen_position - target.get_global_rect().position
	if bool(target.call("_can_drop_data", local_position, _reorder_data)):
		_drop_target = target
		_drop_local_position = local_position
		return
	_clear_drop_highlight()


func _find_drop_control(kind: int, screen_position: Vector2) -> Control:
	if kind == TouchTargetKind.FRAME:
		var frame_hbox := _timeline.get("frame_hbox") as HBoxContainer
		if not is_instance_valid(frame_hbox):
			return null
		for child in frame_hbox.get_children():
			var frame_button := child as Control
			if (
				is_instance_valid(frame_button)
				and frame_button.is_visible_in_tree()
				and frame_button.get_global_rect().has_point(screen_position)
			):
				return frame_button
		return null
	if kind == TouchTargetKind.CEL:
		var cel_vbox := _timeline.get("cel_vbox") as VBoxContainer
		if not is_instance_valid(cel_vbox):
			return null
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
					return cel_button
	return null


func _capture_managed_scroll() -> void:
	var frame_scroll_bar := _frame_scroll_bar()
	if is_instance_valid(frame_scroll_bar):
		_managed_horizontal_scroll = float(frame_scroll_bar.value)
	var timeline_scroll := _timeline_scroll()
	if is_instance_valid(timeline_scroll):
		_managed_vertical_scroll = float(timeline_scroll.scroll_vertical)


func _update_managed_scroll(screen_position: Vector2, delta: float) -> void:
	_update_horizontal_scroll(screen_position, delta)
	if _reorder_kind == TouchTargetKind.CEL:
		_update_vertical_scroll(screen_position, delta)


func _update_horizontal_scroll(screen_position: Vector2, delta: float) -> void:
	var scroll_bar := _frame_scroll_bar()
	var visible_rect := _horizontal_visible_rect()
	if not is_instance_valid(scroll_bar) or visible_rect.size == Vector2.ZERO:
		return
	var overflow := 0.0
	if screen_position.x < visible_rect.position.x:
		overflow = screen_position.x - visible_rect.position.x
	elif screen_position.x > visible_rect.end.x:
		overflow = screen_position.x - visible_rect.end.x
	if is_zero_approx(overflow):
		scroll_bar.value = _managed_horizontal_scroll
		return
	var strength := clampf(absf(overflow) / AUTO_SCROLL_RAMP_PX, 0.0, 1.0)
	var speed := lerpf(AUTO_SCROLL_MIN_SPEED, AUTO_SCROLL_MAX_SPEED, strength)
	_managed_horizontal_scroll += signf(overflow) * speed * delta
	var max_scroll := maxf(scroll_bar.min_value, scroll_bar.max_value - scroll_bar.page)
	_managed_horizontal_scroll = clampf(
		_managed_horizontal_scroll, scroll_bar.min_value, max_scroll
	)
	scroll_bar.value = _managed_horizontal_scroll


func _update_vertical_scroll(screen_position: Vector2, delta: float) -> void:
	var scroll := _timeline_scroll()
	if not is_instance_valid(scroll):
		return
	var visible_rect := _vertical_visible_rect()
	var overflow := 0.0
	if screen_position.y < visible_rect.position.y:
		overflow = screen_position.y - visible_rect.position.y
	elif screen_position.y > visible_rect.end.y:
		overflow = screen_position.y - visible_rect.end.y
	if is_zero_approx(overflow):
		scroll.scroll_vertical = int(round(_managed_vertical_scroll))
		return
	var strength := clampf(absf(overflow) / AUTO_SCROLL_RAMP_PX, 0.0, 1.0)
	var speed := lerpf(AUTO_SCROLL_MIN_SPEED, AUTO_SCROLL_MAX_SPEED, strength)
	_managed_vertical_scroll += signf(overflow) * speed * delta
	var scroll_bar := scroll.get_v_scroll_bar()
	var max_scroll := maxf(0.0, scroll_bar.max_value - scroll_bar.page)
	_managed_vertical_scroll = clampf(_managed_vertical_scroll, 0.0, max_scroll)
	scroll.scroll_vertical = int(round(_managed_vertical_scroll))


func _hold_managed_scroll_inside_visible_area(screen_position: Vector2) -> void:
	var horizontal_rect := _horizontal_visible_rect()
	var frame_scroll_bar := _frame_scroll_bar()
	if is_instance_valid(frame_scroll_bar) and horizontal_rect.has_point(screen_position):
		# Native _can_drop_data() calls ensure_control_visible(); touch reorder owns scroll now.
		frame_scroll_bar.value = _managed_horizontal_scroll
	if _reorder_kind != TouchTargetKind.CEL:
		return
	var vertical_rect := _vertical_visible_rect()
	var timeline_scroll := _timeline_scroll()
	if is_instance_valid(timeline_scroll) and vertical_rect.has_point(screen_position):
		timeline_scroll.scroll_vertical = int(round(_managed_vertical_scroll))


func _horizontal_visible_rect() -> Rect2:
	if not is_instance_valid(_timeline):
		return Rect2()
	var body := _timeline.get("frame_scroll_container") as Control
	var frame_hbox := _timeline.get("frame_hbox") as HBoxContainer
	var body_rect := Rect2()
	var header_rect := Rect2()
	if is_instance_valid(body):
		body_rect = body.get_global_rect()
	if is_instance_valid(frame_hbox):
		var header_margin := frame_hbox.get_parent() as Control
		if is_instance_valid(header_margin):
			var header_container := header_margin.get_parent() as Control
			if is_instance_valid(header_container):
				header_rect = header_container.get_global_rect()
	if body_rect.size == Vector2.ZERO:
		return header_rect
	if header_rect.size == Vector2.ZERO:
		return body_rect
	return body_rect.merge(header_rect)


func _vertical_visible_rect() -> Rect2:
	var scroll := _timeline_scroll()
	if not is_instance_valid(scroll):
		return Rect2()
	return scroll.get_global_rect()


func _frame_scroll_bar() -> HScrollBar:
	if not is_instance_valid(_timeline):
		return null
	return _timeline.get("frame_scroll_bar") as HScrollBar


func _timeline_scroll() -> ScrollContainer:
	if not is_instance_valid(_timeline):
		return null
	return _timeline.get("timeline_scroll") as ScrollContainer


func _create_reorder_preview(source: Control) -> void:
	_clear_reorder_preview()
	var preview := Button.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.size = source.size
	preview.custom_minimum_size = source.size
	preview.theme = Global.control.theme
	preview.modulate = Color(1.0, 1.0, 1.0, PREVIEW_OPACITY)
	preview.z_index = 4096
	if _reorder_kind == TouchTargetKind.FRAME:
		preview.text = str(source.get("text"))
	elif _reorder_kind == TouchTargetKind.CEL:
		var source_texture := source.get_node_or_null("CelTexture") as TextureRect
		if is_instance_valid(source_texture):
			var texture_rect := TextureRect.new()
			texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.texture = source_texture.texture
			preview.add_child(texture_rect)
		var count := _reorder_data[1].size() if _reorder_data.size() >= 2 else 1
		if count > 1:
			preview.text = "×%d" % count
	get_tree().root.add_child(preview)
	_reorder_preview = preview


func _update_preview_position(screen_position: Vector2) -> void:
	if not is_instance_valid(_reorder_preview) or not is_instance_valid(_reorder_source):
		return
	_reorder_preview.global_position = screen_position - _reorder_source.size * 0.5


func _create_source_outline(source: Control) -> void:
	_clear_source_outline()
	var outline := Control.new()
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.z_index = 64
	source.add_child(outline)
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
	_reorder_kind = TouchTargetKind.NONE
	_reorder_data.clear()
	_reorder_source = null
	_drop_target = null
	_drop_local_position = Vector2.ZERO
	set_process(false)
	_clear_drop_highlight()
	_clear_reorder_preview()
	_clear_source_outline()


func _clear_drop_highlight() -> void:
	if is_instance_valid(_timeline):
		var drag_highlight := _timeline.get("drag_highlight") as Control
		if is_instance_valid(drag_highlight):
			drag_highlight.hide()


func _clear_reorder_preview() -> void:
	if is_instance_valid(_reorder_preview):
		_reorder_preview.queue_free()
	_reorder_preview = null


func _clear_source_outline() -> void:
	if is_instance_valid(_source_outline):
		_source_outline.queue_free()
	_source_outline = null


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


func _capture_selection_snapshot() -> Dictionary:
	var project := Global.current_project
	return {
		"selected_cels": project.selected_cels.duplicate(true),
		"current_frame": project.current_frame,
		"current_layer": project.current_layer,
	}


func _restore_last_tap_selection_snapshot() -> void:
	if _last_tap_selection_snapshot.is_empty():
		return
	var project := Global.current_project
	var selected_cels: Array = _last_tap_selection_snapshot.get("selected_cels", [])
	project.selected_cels.clear()
	for frame_layer in selected_cels:
		project.selected_cels.append(frame_layer)
	var frame := int(_last_tap_selection_snapshot.get("current_frame", project.current_frame))
	var layer := int(_last_tap_selection_snapshot.get("current_layer", project.current_layer))
	project.change_cel(frame, layer)


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
	_finish_reorder()
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
	_last_tap_selection_snapshot.clear()


func _is_ready_for_touch() -> bool:
	return OS.get_name() == "iOS" and is_instance_valid(_timeline)
