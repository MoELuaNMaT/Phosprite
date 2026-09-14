extends FlowContainer

const TOUCH_TAP_SLOP_PX := 12.0
const TOUCH_FILTER_META := &"phosprite_touch_mouse_filter"
const IOS_SELECTION_MENU_LONG_PRESS_SECONDS := 0.45
const IOS_SELECTION_RECENT_SECTION := "preferences"
const IOS_SELECTION_RECENT_KEY := "ios_recent_selection_tool"
const IOS_SELECTION_DEFAULT := &"RectSelect"
const IOS_SELECTION_TOOLS := [
	&"ColorSelect",
	&"EllipseSelect",
	&"Lasso",
	&"MagicWand",
	&"PaintSelect",
	&"PolygonSelect",
	&"RectSelect",
]

var pen_inverted := false
## Fixes tools accidentally being switched through shortcuts when user types on a line edit.
var _ignore_shortcuts := false
## Direct-touch taps are resolved here instead of depending on touch-to-mouse emulation.
var _touch_tool_candidates: Dictionary = {}
var _touch_ui_mode := false
var _ios_selection_family_button: BaseButton
var _ios_selection_menu: PopupMenu
var _ios_selection_recent_tool := IOS_SELECTION_DEFAULT
var _ios_selection_touch_generation := 0


static func is_ios_selection_tool(tool_name: StringName) -> bool:
	return tool_name in IOS_SELECTION_TOOLS


static func normalize_ios_recent_selection_tool(value: Variant) -> StringName:
	var tool_name := StringName(str(value))
	return tool_name if is_ios_selection_tool(tool_name) else IOS_SELECTION_DEFAULT


func _ready() -> void:
	# Ensure to only call _input() if the cursor is inside the main canvas viewport
	Global.main_viewport.mouse_entered.connect(func(): _ignore_shortcuts = false)
	Global.main_viewport.mouse_exited.connect(func(): _ignore_shortcuts = true)
	if OS.get_name() == "iOS":
		# Tools performs a final visibility pass after its own startup awaits. Re-assert the
		# compact Selection family at the actual application-open boundary, not only here.
		if not Global.pixelorama_opened.is_connected(_on_ios_pixelorama_opened):
			Global.pixelorama_opened.connect(_on_ios_pixelorama_opened)
		call_deferred("_install_ios_selection_family")


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
		_ios_selection_touch_generation += 1
		var is_selection_family := _is_ios_selection_family_button(button)
		_touch_tool_candidates[event.index] = {
			"tool_name": StringName(button.name),
			"origin": event.position,
			"cancelled": false,
			"selection_family": is_selection_family,
			"menu_opened": false,
			"generation": _ios_selection_touch_generation,
		}
		if is_selection_family:
			var timer := get_tree().create_timer(IOS_SELECTION_MENU_LONG_PRESS_SECONDS)
			timer.timeout.connect(
				_try_open_ios_selection_menu.bind(event.index, _ios_selection_touch_generation)
			)
		return true

	if not _touch_tool_candidates.has(event.index):
		return false
	var candidate: Dictionary = _touch_tool_candidates[event.index]
	_touch_tool_candidates.erase(event.index)
	_enter_touch_tool_ui()
	get_viewport().gui_cancel_drag()
	if bool(candidate.get("cancelled", false)):
		return true
	if bool(candidate.get("selection_family", false)) and bool(candidate.get("menu_opened", false)):
		return true
	if Vector2(candidate["origin"]).distance_to(event.position) > TOUCH_TAP_SLOP_PX:
		return true
	var released_over := _tool_button_at(event.position)
	if not is_instance_valid(released_over) or released_over.name != candidate["tool_name"]:
		return true

	# Direct touch currently activates the Primary slot. The Primary/Secondary data model
	# remains unchanged; D1 deliberately does not define how a future touch UI switches slots.
	if bool(candidate.get("selection_family", false)):
		_activate_ios_selection_tool(_ios_selection_recent_tool)
	else:
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
	_sync_ios_selection_family_visual()


func _install_ios_selection_family() -> void:
	await get_tree().process_frame
	if OS.get_name() != "iOS" or not Tools.tools.has(String(IOS_SELECTION_DEFAULT)):
		return
	_ios_selection_family_button = Tools.tools[String(IOS_SELECTION_DEFAULT)].button_node
	if not is_instance_valid(_ios_selection_family_button):
		return
	_ios_selection_recent_tool = normalize_ios_recent_selection_tool(
		Global.config_cache.get_value(
			IOS_SELECTION_RECENT_SECTION, IOS_SELECTION_RECENT_KEY, IOS_SELECTION_DEFAULT
		)
	)
	_ios_selection_menu = PopupMenu.new()
	_ios_selection_menu.name = "SelectionFamilyMenu"
	for index in IOS_SELECTION_TOOLS.size():
		var tool_name: StringName = IOS_SELECTION_TOOLS[index]
		var tool: Tools.Tool = Tools.tools[String(tool_name)]
		_ios_selection_menu.add_icon_item(tool.icon, tr(tool.display_name), index)
	_ios_selection_menu.id_pressed.connect(_on_ios_selection_menu_id_pressed)
	get_parent().add_child(_ios_selection_menu)
	if not Tools.tool_changed.is_connected(_on_ios_tool_changed):
		Tools.tool_changed.connect(_on_ios_tool_changed)
	if not Global.single_tool_mode_changed.is_connected(_on_ios_single_tool_mode_changed):
		Global.single_tool_mode_changed.connect(_on_ios_single_tool_mode_changed)
	if not Global.cel_switched.is_connected(_on_ios_cel_switched):
		Global.cel_switched.connect(_on_ios_cel_switched)
	_sync_ios_selection_family_visual()


func _is_ios_selection_family_button(button: BaseButton) -> bool:
	return (
		is_instance_valid(_ios_selection_family_button) and button == _ios_selection_family_button
	)


func _try_open_ios_selection_menu(touch_id: int, generation: int) -> void:
	if not _touch_tool_candidates.has(touch_id) or not is_instance_valid(_ios_selection_menu):
		return
	var candidate: Dictionary = _touch_tool_candidates[touch_id]
	if (
		int(candidate.get("generation", -1)) != generation
		or bool(candidate.get("cancelled", false))
		or not bool(candidate.get("selection_family", false))
	):
		return
	candidate["menu_opened"] = true
	_touch_tool_candidates[touch_id] = candidate
	var family_rect := _ios_selection_family_button.get_global_rect()
	_ios_selection_menu.position = Vector2i(
		family_rect.position + Vector2(family_rect.size.x + 4.0, 0.0)
	)
	_ios_selection_menu.popup()


func _on_ios_selection_menu_id_pressed(id: int) -> void:
	if id < 0 or id >= IOS_SELECTION_TOOLS.size():
		return
	_activate_ios_selection_tool(IOS_SELECTION_TOOLS[id])


func _activate_ios_selection_tool(tool_name: StringName) -> void:
	var normalized := normalize_ios_recent_selection_tool(tool_name)
	_set_ios_selection_recent_tool(normalized)
	Tools.assign_tool(String(normalized), MOUSE_BUTTON_LEFT)
	Tools.prev_tool_names[MOUSE_BUTTON_LEFT] = ""
	_sync_ios_selection_family_visual()


func _set_ios_selection_recent_tool(tool_name: StringName) -> void:
	var normalized := normalize_ios_recent_selection_tool(tool_name)
	if _ios_selection_recent_tool == normalized:
		return
	_ios_selection_recent_tool = normalized
	Global.config_cache.set_value(
		IOS_SELECTION_RECENT_SECTION, IOS_SELECTION_RECENT_KEY, String(_ios_selection_recent_tool)
	)
	var error := Global.config_cache.save(Global.CONFIG_PATH)
	if error != OK:
		push_warning("Could not save recent Selection tool: %s" % error_string(error))


func _on_ios_tool_changed(tool_name: String, button: int) -> void:
	if OS.get_name() != "iOS":
		return
	var selection_name := StringName(tool_name)
	if button == MOUSE_BUTTON_LEFT and is_ios_selection_tool(selection_name):
		_set_ios_selection_recent_tool(selection_name)
	_sync_ios_selection_family_visual()


func _on_ios_pixelorama_opened() -> void:
	call_deferred("_sync_ios_selection_family_visual")


func _on_ios_cel_switched() -> void:
	# Tools may change button visibility when the active layer type changes. Run after
	# those listeners and keep the seven Selection children represented by one entry.
	call_deferred("_sync_ios_selection_family_visual")


func _on_ios_single_tool_mode_changed(_mode: bool) -> void:
	call_deferred("_sync_ios_selection_family_visual")


func _sync_ios_selection_family_visual() -> void:
	if OS.get_name() != "iOS" or not is_instance_valid(_ios_selection_family_button):
		return
	for tool_name in IOS_SELECTION_TOOLS:
		var tool: Tools.Tool = Tools.tools[String(tool_name)]
		if not is_instance_valid(tool.button_node):
			continue
		tool.button_node.visible = tool_name == IOS_SELECTION_DEFAULT
	var recent_tool: Tools.Tool = Tools.tools[String(_ios_selection_recent_tool)]
	var icon := _ios_selection_family_button.get_node("ToolIcon") as TextureRect
	icon.texture = recent_tool.icon
	if not _touch_ui_mode:
		_ios_selection_family_button.tooltip_text = "Selection: %s" % tr(recent_tool.display_name)
	var left_name := StringName()
	var right_name := StringName()
	if (
		Tools._slots.has(MOUSE_BUTTON_LEFT)
		and is_instance_valid(Tools._slots[MOUSE_BUTTON_LEFT].tool_node)
	):
		left_name = StringName(Tools._slots[MOUSE_BUTTON_LEFT].tool_node.name)
	if (
		Tools._slots.has(MOUSE_BUTTON_RIGHT)
		and is_instance_valid(Tools._slots[MOUSE_BUTTON_RIGHT].tool_node)
	):
		right_name = StringName(Tools._slots[MOUSE_BUTTON_RIGHT].tool_node.name)
	var left_background := _ios_selection_family_button.get_node("BackgroundLeft") as NinePatchRect
	var right_background := (
		_ios_selection_family_button.get_node("BackgroundRight") as NinePatchRect
	)
	left_background.visible = is_ios_selection_tool(left_name)
	if Global.single_tool_mode:
		right_background.visible = false
		left_background.anchor_right = 1.0
	else:
		right_background.visible = is_ios_selection_tool(right_name)
		left_background.anchor_right = 0.5
	_ios_selection_family_button.queue_redraw()


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
