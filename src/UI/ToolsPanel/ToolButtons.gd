extends FlowContainer

const TOUCH_TAP_SLOP_PX := 12.0
const TOUCH_FILTER_META := &"phosprite_touch_mouse_filter"
const IOS_SELECTION_MENU_LONG_PRESS_SECONDS := 0.45
const IOS_SELECTION_RECENT_SECTION := "preferences"
const IOS_SELECTION_RECENT_KEY := "ios_recent_selection_tool"
const IOS_SELECTION_DEFAULT := &"RectSelect"
const IOS_SELECTION_INSTALL_MAX_RETRIES := 8
const IOS_SELECTION_TOOLS := [
	&"ColorSelect",
	&"EllipseSelect",
	&"Lasso",
	&"MagicWand",
	&"PaintSelect",
	&"PolygonSelect",
	&"RectSelect",
]
const IOS_SHAPE_MENU_LONG_PRESS_SECONDS := 0.45
const IOS_SHAPE_RECENT_SECTION := "preferences"
const IOS_SHAPE_RECENT_KEY := "ios_recent_shape_tool"
const IOS_SHAPE_DEFAULT := &"LineTool"
const IOS_SHAPE_INSTALL_MAX_RETRIES := 8
const IOS_SHAPE_TOOLS := [
	&"LineTool",
	&"CurveTool",
	&"RectangleTool",
	&"EllipseTool",
	&"IsometricBoxTool",
]
const IOS_TOOLBAR_REMOVED_TOOLS := [&"Text", &"Zoom", &"Pan"]
const IOS_TOOLBAR_REMOVAL_INSTALL_MAX_RETRIES := 8
const FAMILY_DISCLOSURE_INDICATOR_NAME := &"FamilyDisclosureIndicator"
const FAMILY_DISCLOSURE_INDICATOR_SIZE := 8.0
const FAMILY_DISCLOSURE_INDICATOR_MARGIN := 1.0

var pen_inverted := false
## Fixes tools accidentally being switched through shortcuts when user types on a line edit.
var _ignore_shortcuts := false
## Direct-touch taps are resolved here instead of depending on touch-to-mouse emulation.
var _touch_tool_candidates: Dictionary = {}
var _touch_ui_mode := false
var _ios_selection_family_button: BaseButton
var _ios_selection_hidden_buttons: Node
var _ios_selection_menu: PopupMenu
var _ios_selection_recent_tool := IOS_SELECTION_DEFAULT
var _ios_selection_touch_generation := 0
var _ios_selection_install_retry_count := 0
var _ios_shape_family_button: BaseButton
var _ios_shape_hidden_buttons: Node
var _ios_shape_menu: PopupMenu
var _ios_shape_recent_tool := IOS_SHAPE_DEFAULT
var _ios_shape_install_retry_count := 0
var _ios_toolbar_removed_buttons: Node
var _ios_toolbar_removal_install_retry_count := 0


static func is_ios_selection_tool(tool_name: StringName) -> bool:
	return tool_name in IOS_SELECTION_TOOLS


static func normalize_ios_recent_selection_tool(value: Variant) -> StringName:
	var tool_name := StringName(str(value))
	return tool_name if is_ios_selection_tool(tool_name) else IOS_SELECTION_DEFAULT


static func is_ios_shape_tool(tool_name: StringName) -> bool:
	return tool_name in IOS_SHAPE_TOOLS


static func normalize_ios_recent_shape_tool(value: Variant) -> StringName:
	var tool_name := StringName(str(value))
	return tool_name if is_ios_shape_tool(tool_name) else IOS_SHAPE_DEFAULT


static func is_ios_toolbar_removed_tool(tool_name: StringName) -> bool:
	return tool_name in IOS_TOOLBAR_REMOVED_TOOLS


func _ready() -> void:
	# Ensure to only call _input() if the cursor is inside the main canvas viewport
	Global.main_viewport.mouse_entered.connect(func(): _ignore_shortcuts = false)
	Global.main_viewport.mouse_exited.connect(func(): _ignore_shortcuts = true)
	if OS.get_name() == "iOS":
		# Installation is transactional: until all seven runtime buttons exist, D1's normal
		# toolbar remains untouched. Once installed, the six child buttons are moved out of
		# the generic toolbar container so later availability refreshes cannot expose them.
		if not Global.pixelorama_opened.is_connected(_on_ios_pixelorama_opened):
			Global.pixelorama_opened.connect(_on_ios_pixelorama_opened)
		call_deferred("_install_ios_selection_family")
		call_deferred("_install_ios_shape_family")
		call_deferred("_install_ios_toolbar_removals")


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
		var t: Tools.Tool = Tools.tools[tool_name]
		var tool_button := t.button_node
		var tool_visible := is_instance_valid(tool_button) and tool_button.visible
		if (
			OS.get_name() == "iOS"
			and is_ios_selection_tool(StringName(tool_name))
			and is_instance_valid(_ios_selection_family_button)
		):
			tool_visible = _ios_selection_family_button.visible
		elif (
			OS.get_name() == "iOS"
			and is_ios_shape_tool(StringName(tool_name))
			and is_instance_valid(_ios_shape_family_button)
		):
			tool_visible = _ios_shape_family_button.visible
		elif OS.get_name() == "iOS" and is_ios_toolbar_removed_tool(StringName(tool_name)):
			tool_visible = _is_tool_available_on_current_layer(t)
		if not tool_visible:
			continue
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
		var is_shape_family := _is_ios_shape_family_button(button)
		_touch_tool_candidates[event.index] = {
			"tool_name": StringName(button.name),
			"origin": event.position,
			"cancelled": false,
			"selection_family": is_selection_family,
			"shape_family": is_shape_family,
			"menu_opened": false,
			"generation": _ios_selection_touch_generation,
		}
		if is_selection_family:
			var timer := get_tree().create_timer(IOS_SELECTION_MENU_LONG_PRESS_SECONDS)
			timer.timeout.connect(
				_try_open_ios_selection_menu.bind(event.index, _ios_selection_touch_generation)
			)
		elif is_shape_family:
			var timer := get_tree().create_timer(IOS_SHAPE_MENU_LONG_PRESS_SECONDS)
			timer.timeout.connect(
				_try_open_ios_shape_menu.bind(event.index, _ios_selection_touch_generation)
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
	if (
		(
			bool(candidate.get("selection_family", false))
			or bool(candidate.get("shape_family", false))
		)
		and bool(candidate.get("menu_opened", false))
	):
		return true
	if Vector2(candidate["origin"]).distance_to(event.position) > TOUCH_TAP_SLOP_PX:
		return true
	var released_over := _tool_button_at(event.position)
	if not is_instance_valid(released_over) or released_over.name != candidate["tool_name"]:
		return true

	# Do not mutate the active Tool Options tree while the ScreenTouch event is still
	# traversing the GUI. A responsive HFlow exposes many more direct touch targets than
	# the old narrow toolbar, which made re-entrant tool replacement much easier to hit.
	# Commit the exact validated button after the current input dispatch finishes.
	call_deferred(
		"_commit_touch_tool_activation",
		StringName(candidate["tool_name"]),
		bool(candidate.get("selection_family", false)),
		bool(candidate.get("shape_family", false)),
		int(candidate.get("generation", -1))
	)
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
	var scroll_container := _get_tools_scroll_container()
	if (
		is_instance_valid(scroll_container)
		and not scroll_container.get_global_rect().has_point(screen_position)
	):
		return null
	for child in get_children():
		var button := child as BaseButton
		if (
			not is_instance_valid(button)
			or not button.is_visible_in_tree()
			or button.get_parent() != self
			or not Tools.tools.has(String(button.name))
		):
			continue
		var viewport_rect := button.get_global_rect()
		if is_instance_valid(scroll_container):
			viewport_rect = scroll_container.get_global_rect()
		if is_visible_tool_touch(button.get_global_rect(), viewport_rect, screen_position):
			return button
	return null


static func is_visible_tool_touch(
	button_rect: Rect2, viewport_rect: Rect2, screen_position: Vector2
) -> bool:
	var visible_rect := button_rect.intersection(viewport_rect)
	return visible_rect.has_area() and visible_rect.has_point(screen_position)


func _get_tools_scroll_container() -> ScrollContainer:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			return ancestor as ScrollContainer
		ancestor = ancestor.get_parent()
	return null


func _commit_touch_tool_activation(
	tool_name: StringName, selection_family: bool, shape_family: bool, generation: int
) -> void:
	if generation != _ios_selection_touch_generation:
		return
	if selection_family:
		if not is_instance_valid(_ios_selection_family_button):
			return
		_activate_ios_selection_tool(_ios_selection_recent_tool)
		return
	if shape_family:
		if not is_instance_valid(_ios_shape_family_button):
			return
		_activate_ios_shape_tool(_ios_shape_recent_tool)
		return
	var key := String(tool_name)
	if not Tools.tools.has(key):
		return
	var tool: Tools.Tool = Tools.tools[key]
	var button := tool.button_node
	if (
		not is_instance_valid(button)
		or button.get_parent() != self
		or not button.is_visible_in_tree()
	):
		return
	Tools.assign_tool(key, MOUSE_BUTTON_LEFT)
	Tools.prev_tool_names[MOUSE_BUTTON_LEFT] = ""


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
	_sync_ios_shape_family_visual()


func _is_tool_available_on_current_layer(tool: Tools.Tool) -> bool:
	if Global.current_project == null or Global.current_project.layers.is_empty():
		return true
	var layer := Global.current_project.layers[Global.current_project.current_layer]
	return tool.layer_types.is_empty() or layer.get_layer_type() in tool.layer_types


func _ensure_family_disclosure_indicator(button: BaseButton) -> void:
	if not is_instance_valid(button):
		return
	var existing := button.get_node_or_null(NodePath(String(FAMILY_DISCLOSURE_INDICATOR_NAME)))
	if existing is Control:
		(existing as Control).queue_redraw()
		return
	var indicator := Control.new()
	indicator.name = FAMILY_DISCLOSURE_INDICATOR_NAME
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.focus_mode = Control.FOCUS_NONE
	indicator.z_index = 100
	indicator.anchor_left = 1.0
	indicator.anchor_top = 1.0
	indicator.anchor_right = 1.0
	indicator.anchor_bottom = 1.0
	indicator.offset_left = -(FAMILY_DISCLOSURE_INDICATOR_SIZE + FAMILY_DISCLOSURE_INDICATOR_MARGIN)
	indicator.offset_top = -(FAMILY_DISCLOSURE_INDICATOR_SIZE + FAMILY_DISCLOSURE_INDICATOR_MARGIN)
	indicator.offset_right = -FAMILY_DISCLOSURE_INDICATOR_MARGIN
	indicator.offset_bottom = -FAMILY_DISCLOSURE_INDICATOR_MARGIN
	indicator.draw.connect(_draw_family_disclosure_indicator.bind(indicator))
	button.add_child(indicator)
	indicator.queue_redraw()


func _draw_family_disclosure_indicator(indicator: Control) -> void:
	if not is_instance_valid(indicator):
		return
	var edge := indicator.size - Vector2.ONE
	var points := PackedVector2Array(
		[
			Vector2(1.0, edge.y),
			Vector2(edge.x, edge.y),
			Vector2(edge.x, 1.0),
		]
	)
	indicator.draw_colored_polygon(points, Color(1.0, 1.0, 1.0, 0.96))
	var outline := PackedVector2Array([points[0], points[1], points[2], points[0]])
	indicator.draw_polyline(outline, Color(0.0, 0.0, 0.0, 0.9), 1.0, false)


func _ios_selection_buttons_ready() -> bool:
	for tool_name in IOS_SELECTION_TOOLS:
		if not Tools.tools.has(String(tool_name)):
			return false
		var tool: Tools.Tool = Tools.tools[String(tool_name)]
		if not is_instance_valid(tool.button_node) or tool.button_node.get_parent() != self:
			return false
	return true


func _install_ios_selection_family() -> void:
	if OS.get_name() != "iOS":
		return
	if is_instance_valid(_ios_selection_family_button):
		_sync_ios_selection_family_visual()
		return
	if not _ios_selection_buttons_ready():
		if _ios_selection_install_retry_count < IOS_SELECTION_INSTALL_MAX_RETRIES:
			_ios_selection_install_retry_count += 1
			await get_tree().process_frame
			call_deferred("_install_ios_selection_family")
		return

	_ios_selection_install_retry_count = 0
	_ios_selection_family_button = Tools.tools[String(IOS_SELECTION_DEFAULT)].button_node
	_ensure_family_disclosure_indicator(_ios_selection_family_button)
	_ios_selection_recent_tool = normalize_ios_recent_selection_tool(
		Global.config_cache.get_value(
			IOS_SELECTION_RECENT_SECTION, IOS_SELECTION_RECENT_KEY, IOS_SELECTION_DEFAULT
		)
	)
	_detach_ios_selection_children()

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


func _detach_ios_selection_children() -> void:
	if not is_instance_valid(_ios_selection_hidden_buttons):
		_ios_selection_hidden_buttons = Node.new()
		_ios_selection_hidden_buttons.name = "IOSSelectionHiddenButtons"
		get_parent().add_child(_ios_selection_hidden_buttons)
	for tool_name in IOS_SELECTION_TOOLS:
		if tool_name == IOS_SELECTION_DEFAULT:
			continue
		var tool: Tools.Tool = Tools.tools[String(tool_name)]
		var button := tool.button_node
		if button.get_parent() == self:
			remove_child(button)
			_ios_selection_hidden_buttons.add_child(button)
		button.visible = false


func _ios_shape_buttons_ready() -> bool:
	for tool_name in IOS_SHAPE_TOOLS:
		if not Tools.tools.has(String(tool_name)):
			return false
		var tool: Tools.Tool = Tools.tools[String(tool_name)]
		if not is_instance_valid(tool.button_node) or tool.button_node.get_parent() != self:
			return false
	return true


func _install_ios_shape_family() -> void:
	if OS.get_name() != "iOS":
		return
	if is_instance_valid(_ios_shape_family_button):
		_sync_ios_shape_family_visual()
		return
	if not _ios_shape_buttons_ready():
		if _ios_shape_install_retry_count < IOS_SHAPE_INSTALL_MAX_RETRIES:
			_ios_shape_install_retry_count += 1
			await get_tree().process_frame
			call_deferred("_install_ios_shape_family")
		return

	_ios_shape_install_retry_count = 0
	_ios_shape_family_button = Tools.tools[String(IOS_SHAPE_DEFAULT)].button_node
	_ensure_family_disclosure_indicator(_ios_shape_family_button)
	_ios_shape_recent_tool = normalize_ios_recent_shape_tool(
		Global.config_cache.get_value(
			IOS_SHAPE_RECENT_SECTION, IOS_SHAPE_RECENT_KEY, IOS_SHAPE_DEFAULT
		)
	)
	_detach_ios_shape_children()

	_ios_shape_menu = PopupMenu.new()
	_ios_shape_menu.name = "ShapeFamilyMenu"
	for index in IOS_SHAPE_TOOLS.size():
		var tool_name: StringName = IOS_SHAPE_TOOLS[index]
		var tool: Tools.Tool = Tools.tools[String(tool_name)]
		_ios_shape_menu.add_icon_item(tool.icon, tr(tool.display_name), index)
	_ios_shape_menu.id_pressed.connect(_on_ios_shape_menu_id_pressed)
	get_parent().add_child(_ios_shape_menu)

	if not Tools.tool_changed.is_connected(_on_ios_tool_changed):
		Tools.tool_changed.connect(_on_ios_tool_changed)
	if not Global.single_tool_mode_changed.is_connected(_on_ios_single_tool_mode_changed):
		Global.single_tool_mode_changed.connect(_on_ios_single_tool_mode_changed)
	if not Global.cel_switched.is_connected(_on_ios_cel_switched):
		Global.cel_switched.connect(_on_ios_cel_switched)
	_sync_ios_shape_family_visual()


func _detach_ios_shape_children() -> void:
	if not is_instance_valid(_ios_shape_hidden_buttons):
		_ios_shape_hidden_buttons = Node.new()
		_ios_shape_hidden_buttons.name = "IOSShapeHiddenButtons"
		get_parent().add_child(_ios_shape_hidden_buttons)
	for tool_name in IOS_SHAPE_TOOLS:
		if tool_name == IOS_SHAPE_DEFAULT:
			continue
		var tool: Tools.Tool = Tools.tools[String(tool_name)]
		var button := tool.button_node
		if button.get_parent() == self:
			remove_child(button)
			_ios_shape_hidden_buttons.add_child(button)
			button.visible = false


func _ios_toolbar_removed_buttons_ready() -> bool:
	for tool_name in IOS_TOOLBAR_REMOVED_TOOLS:
		if not Tools.tools.has(String(tool_name)):
			return false
		var tool: Tools.Tool = Tools.tools[String(tool_name)]
		if not is_instance_valid(tool.button_node) or tool.button_node.get_parent() != self:
			return false
	return true


func _install_ios_toolbar_removals() -> void:
	if OS.get_name() != "iOS":
		return
	if is_instance_valid(_ios_toolbar_removed_buttons):
		return
	if not _ios_toolbar_removed_buttons_ready():
		if _ios_toolbar_removal_install_retry_count < IOS_TOOLBAR_REMOVAL_INSTALL_MAX_RETRIES:
			_ios_toolbar_removal_install_retry_count += 1
			await get_tree().process_frame
			call_deferred("_install_ios_toolbar_removals")
		return

	_ios_toolbar_removal_install_retry_count = 0
	_ios_toolbar_removed_buttons = Node.new()
	_ios_toolbar_removed_buttons.name = "IOSToolbarRemovedButtons"
	get_parent().add_child(_ios_toolbar_removed_buttons)
	for tool_name in IOS_TOOLBAR_REMOVED_TOOLS:
		var tool: Tools.Tool = Tools.tools[String(tool_name)]
		var button := tool.button_node
		remove_child(button)
		_ios_toolbar_removed_buttons.add_child(button)
		button.visible = false


func _is_ios_shape_family_button(button: BaseButton) -> bool:
	return is_instance_valid(_ios_shape_family_button) and button == _ios_shape_family_button


func _is_ios_selection_family_button(button: BaseButton) -> bool:
	return (
		is_instance_valid(_ios_selection_family_button) and button == _ios_selection_family_button
	)


func _try_open_ios_shape_menu(touch_id: int, generation: int) -> void:
	if not _touch_tool_candidates.has(touch_id) or not is_instance_valid(_ios_shape_menu):
		return
	var candidate: Dictionary = _touch_tool_candidates[touch_id]
	if (
		int(candidate.get("generation", -1)) != generation
		or bool(candidate.get("cancelled", false))
		or not bool(candidate.get("shape_family", false))
	):
		return
	candidate["menu_opened"] = true
	_touch_tool_candidates[touch_id] = candidate
	var family_rect := _ios_shape_family_button.get_global_rect()
	_ios_shape_menu.position = Vector2i(
		family_rect.position + Vector2(family_rect.size.x + 4.0, 0.0)
	)
	_ios_shape_menu.popup()


func _on_ios_shape_menu_id_pressed(id: int) -> void:
	if id < 0 or id >= IOS_SHAPE_TOOLS.size():
		return
	_activate_ios_shape_tool(IOS_SHAPE_TOOLS[id])


func _activate_ios_shape_tool(tool_name: StringName) -> void:
	var normalized := normalize_ios_recent_shape_tool(tool_name)
	_set_ios_shape_recent_tool(normalized)
	Tools.assign_tool(String(normalized), MOUSE_BUTTON_LEFT)
	Tools.prev_tool_names[MOUSE_BUTTON_LEFT] = ""
	_sync_ios_shape_family_visual()


func _set_ios_shape_recent_tool(tool_name: StringName) -> void:
	var normalized := normalize_ios_recent_shape_tool(tool_name)
	if _ios_shape_recent_tool == normalized:
		return
	_ios_shape_recent_tool = normalized
	Global.config_cache.set_value(
		IOS_SHAPE_RECENT_SECTION, IOS_SHAPE_RECENT_KEY, String(_ios_shape_recent_tool)
	)
	var error := Global.config_cache.save(Global.CONFIG_PATH)
	if error != OK:
		push_warning("Could not save recent Shape tool: %s" % error_string(error))


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
	if button == MOUSE_BUTTON_LEFT and is_ios_shape_tool(selection_name):
		_set_ios_shape_recent_tool(selection_name)
	_sync_ios_selection_family_visual()
	_sync_ios_shape_family_visual()


func _on_ios_pixelorama_opened() -> void:
	# Covers startup orders where ToolButtons becomes ready before Tools creates all buttons.
	call_deferred("_install_ios_selection_family")
	call_deferred("_install_ios_shape_family")
	call_deferred("_install_ios_toolbar_removals")


func _on_ios_cel_switched() -> void:
	call_deferred("_sync_ios_selection_family_visual")
	call_deferred("_sync_ios_shape_family_visual")


func _on_ios_single_tool_mode_changed(_mode: bool) -> void:
	call_deferred("_sync_ios_selection_family_visual")
	call_deferred("_sync_ios_shape_family_visual")


func _sync_ios_selection_family_visual() -> void:
	if OS.get_name() != "iOS" or not is_instance_valid(_ios_selection_family_button):
		return
	for tool_name in IOS_SELECTION_TOOLS:
		if tool_name == IOS_SELECTION_DEFAULT:
			continue
		var tool: Tools.Tool = Tools.tools[String(tool_name)]
		if not is_instance_valid(tool.button_node):
			continue
		tool.button_node.visible = false
		var child_left := tool.button_node.get_node("BackgroundLeft") as NinePatchRect
		var child_right := tool.button_node.get_node("BackgroundRight") as NinePatchRect
		child_left.visible = false
		child_right.visible = false
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


func _sync_ios_shape_family_visual() -> void:
	if OS.get_name() != "iOS" or not is_instance_valid(_ios_shape_family_button):
		return
	for tool_name in IOS_SHAPE_TOOLS:
		if tool_name == IOS_SHAPE_DEFAULT:
			continue
		var tool: Tools.Tool = Tools.tools[String(tool_name)]
		if not is_instance_valid(tool.button_node):
			continue
		tool.button_node.visible = false
		var child_left := tool.button_node.get_node("BackgroundLeft") as NinePatchRect
		var child_right := tool.button_node.get_node("BackgroundRight") as NinePatchRect
		child_left.visible = false
		child_right.visible = false
	var recent_tool: Tools.Tool = Tools.tools[String(_ios_shape_recent_tool)]
	var icon := _ios_shape_family_button.get_node("ToolIcon") as TextureRect
	icon.texture = recent_tool.icon
	if not _touch_ui_mode:
		_ios_shape_family_button.tooltip_text = "Shapes: %s" % tr(recent_tool.display_name)
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
	var left_background := _ios_shape_family_button.get_node("BackgroundLeft") as NinePatchRect
	var right_background := _ios_shape_family_button.get_node("BackgroundRight") as NinePatchRect
	left_background.visible = is_ios_shape_tool(left_name)
	if Global.single_tool_mode:
		right_background.visible = false
		left_background.anchor_right = 1.0
	else:
		right_background.visible = is_ios_shape_tool(right_name)
		left_background.anchor_right = 0.5
	_ios_shape_family_button.queue_redraw()


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
		var tool_name := String(tool_pressed.name)
		if OS.get_name() == "iOS" and _is_ios_selection_family_button(tool_pressed):
			tool_name = String(_ios_selection_recent_tool)
		elif OS.get_name() == "iOS" and _is_ios_shape_family_button(tool_pressed):
			tool_name = String(_ios_shape_recent_tool)
		Tools.assign_tool(tool_name, button)
