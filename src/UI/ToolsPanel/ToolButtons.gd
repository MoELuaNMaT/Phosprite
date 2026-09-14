extends FlowContainer

const TOUCH_TAP_SLOP_PX := 12.0
const TOUCH_FILTER_META := &"phosprite_touch_mouse_filter"

var pen_inverted := false
## Fixes tools accidentally being switched through shortcuts when user types on a line edit.
var _ignore_shortcuts := false
## Direct-touch taps are resolved here instead of depending on touch-to-mouse emulation.
var _touch_tool_candidates: Dictionary = {}
var _touch_ui_mode := false


func _ready() -> void:
	# Ensure to only call _input() if the cursor is inside the main canvas viewport
	Global.main_viewport.mouse_entered.connect(func(): _ignore_shortcuts = false)
	Global.main_viewport.mouse_exited.connect(func(): _ignore_shortcuts = true)


func _input(event: InputEvent) -> void:
	if OS.get_name() == "iOS":
		if event is InputEventScreenTouch:
			if _handle_tool_touch(event as InputEventScreenTouch):
				get_viewport().set_input_as_handled()
			return
		if event is InputEventScreenDrag:
			if _handle_tool_drag(event as InputEventScreenDrag):
				get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion:
		# DEVICE_ID_EMULATION (-1) is the synthetic mouse stream produced by touch.
		# It must not restore a hover/tooltip immediately after a tool was tapped.
		if event.device != -1:
			_restore_pointer_tool_ui()
		pen_inverted = event.pen_inverted
		return
	if event is InputEventMouseButton and event.device != -1:
		_restore_pointer_tool_ui()
	if not Global.can_draw:
		return
	if get_tree().current_scene.is_writing_text:
		return
	for action in ["undo", "redo"]:
		if event.is_action_pressed(action):
			return
	var tool_activated := (
		Input.is_action_pressed(&"activate_left_tool")
		or Input.is_action_pressed(&"activate_right_tool")
	)

	for tool_name in Tools.tools:  # Handle tool shortcuts
		if not get_node(tool_name).visible:
			continue
		var t: Tools.Tool = Tools.tools[tool_name]
		var right_tool_shortcut := "right_" + t.shortcut + "_tool"
		if not Global.single_tool_mode and InputMap.has_action(right_tool_shortcut):
			if event.is_action_pressed(right_tool_shortcut, false, true) and not _ignore_shortcuts:
				# Shortcut for right button (with Alt)
				Tools.assign_tool(t.name, MOUSE_BUTTON_RIGHT)
				Tools.prev_tool_names[MOUSE_BUTTON_RIGHT] = ""
				return
		var left_tool_shortcut := "left_" + t.shortcut + "_tool"
		if InputMap.has_action(left_tool_shortcut):
			if event.is_action_pressed(left_tool_shortcut, false, true) and not _ignore_shortcuts:
				# Shortcut for left button
				Tools.assign_tool(t.name, MOUSE_BUTTON_LEFT)
				Tools.prev_tool_names[MOUSE_BUTTON_LEFT] = ""
				return

		var quick_tool_shortcut := "quick_" + t.shortcut + "_tool"
		if InputMap.has_action(quick_tool_shortcut) and not Tools.has_selection_tool():
			if (
				event.is_action_pressed(quick_tool_shortcut, false, true)
				and not tool_activated
				and not _ignore_shortcuts
			):
				Tools.quick_assign_tool(t.name, MOUSE_BUTTON_LEFT)
				Tools.quick_assign_tool(t.name, MOUSE_BUTTON_RIGHT)
				return
			if event.is_action_released(quick_tool_shortcut):
				Tools.quick_assign_tool_revert(MOUSE_BUTTON_RIGHT)
				Tools.quick_assign_tool_revert(MOUSE_BUTTON_LEFT)
				return


func _handle_tool_touch(event: InputEventScreenTouch) -> bool:
	if not Global.can_draw or get_tree().current_scene.is_writing_text:
		return false
	if event.pressed:
		var button := _tool_button_at(event.position)
		if not is_instance_valid(button):
			return false
		_enter_touch_tool_ui()
		get_viewport().gui_cancel_drag()
		_touch_tool_candidates[event.index] = {
			"tool_name": StringName(button.name),
			"origin": event.position,
			"cancelled": false,
		}
		return true

	if not _touch_tool_candidates.has(event.index):
		return false
	var candidate: Dictionary = _touch_tool_candidates[event.index]
	_touch_tool_candidates.erase(event.index)
	_enter_touch_tool_ui()
	get_viewport().gui_cancel_drag()
	if bool(candidate.get("cancelled", false)):
		return true
	if Vector2(candidate["origin"]).distance_to(event.position) > TOUCH_TAP_SLOP_PX:
		return true
	var released_over := _tool_button_at(event.position)
	if not is_instance_valid(released_over) or released_over.name != candidate["tool_name"]:
		return true

	# Direct touch currently activates the Primary slot. The Primary/Secondary data model
	# remains unchanged; D1 deliberately does not define how a future touch UI switches slots.
	Tools.assign_tool(String(candidate["tool_name"]), MOUSE_BUTTON_LEFT)
	Tools.prev_tool_names[MOUSE_BUTTON_LEFT] = ""
	return true


func _handle_tool_drag(event: InputEventScreenDrag) -> bool:
	if not _touch_tool_candidates.has(event.index):
		return false
	_enter_touch_tool_ui()
	get_viewport().gui_cancel_drag()
	var candidate: Dictionary = _touch_tool_candidates[event.index]
	if Vector2(candidate["origin"]).distance_to(event.position) > TOUCH_TAP_SLOP_PX:
		# Keep ownership until release. Dropping the candidate here lets later synthetic
		# mouse motion escape into the legacy UI and exposes the selected-tool cursor icon.
		candidate["cancelled"] = true
		_touch_tool_candidates[event.index] = candidate
	return true


func _tool_button_at(screen_position: Vector2) -> BaseButton:
	for child in get_children():
		var button := child as BaseButton
		if not is_instance_valid(button) or not button.visible:
			continue
		if button.get_global_rect().has_point(screen_position):
			return button
	return null


func _set_touch_mouse_filter(control: Control, disabled: bool) -> void:
	if not control.has_meta(TOUCH_FILTER_META):
		control.set_meta(TOUCH_FILTER_META, control.mouse_filter)
	if disabled:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		control.mouse_filter = int(control.get_meta(TOUCH_FILTER_META, Control.MOUSE_FILTER_PASS))
	for child in control.get_children():
		if child is Control:
			_set_touch_mouse_filter(child as Control, disabled)


func _enter_touch_tool_ui() -> void:
	_touch_ui_mode = true
	get_viewport().gui_cancel_drag()
	for child in get_children():
		var button := child as BaseButton
		if not is_instance_valid(button):
			continue
		# Keep synthetic mouse hit-testing disabled after touch. This removes both the
		# sticky hover state and delayed tooltip without changing global GUI emulation.
		button.tooltip_text = ""
		_set_touch_mouse_filter(button, true)
		button.release_focus()
		button.queue_redraw()
	# Pixelorama's custom tool cursor is the icon that otherwise appears to be dragged
	# out of the toolbar. Touching the tool palette must leave no pointer preview behind.
	if is_instance_valid(Global.canvas):
		Global.canvas.set_adapter_tool_preview_active(false)


func _restore_pointer_tool_ui() -> void:
	if not _touch_ui_mode:
		return
	_touch_ui_mode = false
	_touch_tool_candidates.clear()
	for child in get_children():
		var button := child as BaseButton
		if not is_instance_valid(button):
			continue
		_set_touch_mouse_filter(button, false)
		if Tools.tools.has(String(button.name)):
			button.tooltip_text = Tools.tools[String(button.name)].generate_hint_tooltip()
		button.queue_redraw()


func _on_tool_pressed(tool_pressed: BaseButton) -> void:
	var button := MOUSE_BUTTON_LEFT
	if not Global.single_tool_mode:
		button = (
			MOUSE_BUTTON_RIGHT
			if (
				Input.is_action_just_released("right_mouse")
				or (pen_inverted and Input.is_action_just_released("left_mouse"))
			)
			else button
		)
	if button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		Tools.assign_tool(tool_pressed.name, button)
