class_name WorkspaceUIProfile3
extends Node

## UI Profile 3: Procreate-inspired compact editor chrome.
##
## The profile owns presentation only. Tool/color state remains in the existing
## Tools runtime. Pencil/Eraser proxy the real tool buttons, the remaining live
## toolbar buttons are exposed through a temporary folded menu, and the existing
## Palette & Color / Left Tool Options controls are temporarily reparented into
## popups. Leaving profile 3 restores every borrowed control to its original tree.

const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")

const PRIMARY_TOOLS: Array[StringName] = [&"Pencil", &"Eraser"]
const SELECTION_TOOLS: Array[StringName] = [
	&"ColorSelect",
	&"EllipseSelect",
	&"Lasso",
	&"MagicWand",
	&"PaintSelect",
	&"PolygonSelect",
	&"RectSelect",
]
const SHAPE_TOOLS: Array[StringName] = [
	&"LineTool", &"CurveTool", &"RectangleTool", &"EllipseTool", &"IsometricBoxTool"
]
const PREVIEW_RECT := Rect2(0.0, 0.0, 280.0, 160.0)
const TOP_TOOL_SIZE := Vector2(28.0, 28.0)
const MENU_TOOL_SIZE := Vector2(40.0, 40.0)
const OPTIONS_WIDTH := 320.0
const OPTIONS_MIN_HEIGHT := 120.0
const OPTIONS_MAX_HEIGHT := 420.0
const TOOLS_MENU_SIZE := Vector2(320.0, 360.0)
const PALETTE_POPUP_SIZE := Vector2(340.0, 440.0)
const POPUP_GAP := 4.0

var ui_root: Control
var palette_root: VBoxContainer
var left_tool_options: ScrollContainer
var surface: WorkspaceSurface

var active := false

var _tool_buttons: Node
var _toolbar_host: HBoxContainer
var _pencil_button: Button
var _eraser_button: Button
var _other_tools_button: Button
var _color_button: Button
var _tool_entry_group := ButtonGroup.new()

var _options_popup: PanelContainer
var _options_host: MarginContainer
var _tools_popup: PanelContainer
var _tools_flow: HFlowContainer
var _palette_popup: PanelContainer
var _palette_host: MarginContainer

var _other_proxies: Dictionary = {}
var _source_by_proxy: Dictionary = {}
var _original_left_options_state: Dictionary = {}
var _original_palette_state: Dictionary = {}


static func is_primary_tool(tool_name: StringName) -> bool:
	return tool_name in PRIMARY_TOOLS


static func is_workspace_embedded_module(module_id: StringName) -> bool:
	return module_id == Builtins.TOOLS_ID or module_id == Builtins.PALETTE_ID


func setup(
	root: Control,
	combined_palette_root: VBoxContainer,
	left_options: ScrollContainer,
	workspace_surface: WorkspaceSurface
) -> bool:
	if (
		ui_root != null
		or root == null
		or combined_palette_root == null
		or left_options == null
		or workspace_surface == null
	):
		return false
	ui_root = root
	palette_root = combined_palette_root
	left_tool_options = left_options
	surface = workspace_surface
	set_process_input(true)
	return true


func activate() -> bool:
	active = true
	if Global.headless_test_mode:
		return true
	if not _dependencies_ready():
		return true
	if not _ensure_presentation():
		return false
	_toolbar_host.visible = true
	_refresh_visuals()
	return true


func deactivate() -> void:
	active = false
	if Global.headless_test_mode:
		return
	_hide_all_popups()
	_restore_left_tool_options()
	_restore_palette_root()
	if is_instance_valid(_toolbar_host):
		_toolbar_host.visible = false


func refresh_after_tools_ready() -> bool:
	if not active:
		return true
	return activate()


func enforce_workspace() -> bool:
	if not active or surface == null:
		return true
	if not surface.park_module(Builtins.TOOLS_ID):
		return false
	if not surface.park_module(Builtins.PALETTE_ID):
		return false
	return surface.float_module(Builtins.PREVIEW_ID, PREVIEW_RECT)


func _dependencies_ready() -> bool:
	return (
		is_instance_valid(palette_root)
		and is_instance_valid(left_tool_options)
		and is_instance_valid(Tools._tool_buttons)
	)


func _ensure_presentation() -> bool:
	if is_instance_valid(_toolbar_host):
		return true
	if not _dependencies_ready():
		return false
	_tool_buttons = Tools._tool_buttons
	if not _capture_borrowed_control_states():
		return false
	if not _create_toolbar():
		return false
	_create_popups()
	_build_other_tool_menu()
	_connect_runtime_signals()
	return true


func _capture_borrowed_control_states() -> bool:
	if _original_left_options_state.is_empty():
		var options_parent := left_tool_options.get_parent()
		if options_parent == null:
			return false
		_original_left_options_state = _capture_control_state(left_tool_options, options_parent)

	if _original_palette_state.is_empty():
		var palette_parent := palette_root.get_parent()
		if palette_parent == null:
			return false
		_original_palette_state = _capture_control_state(palette_root, palette_parent)
	return true


func _capture_control_state(control: Control, parent: Node) -> Dictionary:
	return {
		"parent": parent,
		"index": control.get_index(),
		"visible": control.visible,
		"size_flags_horizontal": control.size_flags_horizontal,
		"size_flags_vertical": control.size_flags_vertical,
		"stretch_ratio": control.size_flags_stretch_ratio,
		"custom_minimum_size": control.custom_minimum_size,
	}


func _create_toolbar() -> bool:
	var top_menu := Global.top_menu_container as Control
	if not is_instance_valid(top_menu):
		var scene := get_tree().current_scene
		top_menu = (
			scene.find_child("TopMenuContainer", true, false) as Control if scene != null else null
		)
	if top_menu == null:
		return false
	var row := top_menu.get_node_or_null(^"MarginContainer/HBoxContainer") as HBoxContainer
	if row == null:
		return false

	_toolbar_host = HBoxContainer.new()
	_toolbar_host.name = &"UIProfile3ProcreateTools"
	_toolbar_host.size_flags_horizontal = Control.SIZE_SHRINK_END
	_toolbar_host.alignment = BoxContainer.ALIGNMENT_END
	_toolbar_host.add_theme_constant_override(&"separation", 4)
	row.add_child(_toolbar_host)
	row.move_child(_toolbar_host, row.get_child_count() - 1)

	_pencil_button = _make_primary_button(&"Pencil")
	_eraser_button = _make_primary_button(&"Eraser")
	if _pencil_button == null or _eraser_button == null:
		return false
	_toolbar_host.add_child(_pencil_button)
	_toolbar_host.add_child(_eraser_button)

	_other_tools_button = Button.new()
	_other_tools_button.name = &"OtherTools"
	_other_tools_button.custom_minimum_size = Vector2(56.0, TOP_TOOL_SIZE.y)
	_other_tools_button.focus_mode = Control.FOCUS_NONE
	_other_tools_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_other_tools_button.flat = true
	_other_tools_button.toggle_mode = true
	_other_tools_button.button_group = _tool_entry_group
	_other_tools_button.text = tr("Tools")
	_other_tools_button.tooltip_text = tr("Other tools")
	_other_tools_button.pressed.connect(_on_other_tools_pressed)
	_toolbar_host.add_child(_other_tools_button)

	_color_button = Button.new()
	_color_button.name = &"CurrentColor"
	_color_button.custom_minimum_size = TOP_TOOL_SIZE
	_color_button.focus_mode = Control.FOCUS_NONE
	_color_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_color_button.tooltip_text = tr("Palette & Color")
	_color_button.pressed.connect(_on_color_pressed)
	_toolbar_host.add_child(_color_button)
	return true


func _make_primary_button(tool_name: StringName) -> Button:
	var source := _source_button(tool_name)
	if source == null:
		return null
	var button := Button.new()
	button.name = StringName("Profile3_" + String(tool_name))
	button.custom_minimum_size = TOP_TOOL_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.flat = true
	button.toggle_mode = true
	button.button_group = _tool_entry_group
	button.expand_icon = true
	button.icon_max_width = int(TOP_TOOL_SIZE.x - 8.0)
	button.icon = _source_icon(source)
	button.tooltip_text = source.tooltip_text
	button.pressed.connect(_on_primary_pressed.bind(tool_name, button))
	return button


func _create_popups() -> void:
	_options_popup = _make_popup(&"UIProfile3ToolOptionsPopup")
	_options_host = _make_margin_host(_options_popup, &"OptionsHost")

	_tools_popup = _make_popup(&"UIProfile3OtherToolsPopup")
	var tools_margin := _make_margin_host(_tools_popup, &"ToolsHost")
	var scroll := ScrollContainer.new()
	scroll.name = &"Scroll"
	scroll.custom_minimum_size = TOOLS_MENU_SIZE - Vector2(16.0, 16.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tools_margin.add_child(scroll)
	_tools_flow = HFlowContainer.new()
	_tools_flow.name = &"OtherTools"
	_tools_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tools_flow.add_theme_constant_override(&"h_separation", 6)
	_tools_flow.add_theme_constant_override(&"v_separation", 6)
	scroll.add_child(_tools_flow)

	_palette_popup = _make_popup(&"UIProfile3PalettePopup")
	_palette_host = _make_margin_host(_palette_popup, &"PaletteHost")


func _make_popup(node_name: StringName) -> PanelContainer:
	var popup := PanelContainer.new()
	popup.name = node_name
	popup.visible = false
	popup.z_index = 1000
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(popup)
	return popup


func _make_margin_host(popup: PanelContainer, node_name: StringName) -> MarginContainer:
	var host := MarginContainer.new()
	host.name = node_name
	host.add_theme_constant_override(&"margin_left", 8)
	host.add_theme_constant_override(&"margin_top", 8)
	host.add_theme_constant_override(&"margin_right", 8)
	host.add_theme_constant_override(&"margin_bottom", 8)
	popup.add_child(host)
	return host


func _build_other_tool_menu() -> void:
	for child in _tool_buttons.get_children():
		var source := child as BaseButton
		if source == null or is_primary_tool(StringName(source.name)):
			continue
		var proxy := Button.new()
		proxy.name = StringName("Profile3Menu_" + String(source.name))
		proxy.custom_minimum_size = MENU_TOOL_SIZE
		proxy.focus_mode = Control.FOCUS_NONE
		proxy.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		proxy.flat = true
		proxy.toggle_mode = true
		proxy.expand_icon = true
		proxy.icon_max_width = int(MENU_TOOL_SIZE.x - 10.0)
		proxy.icon = _source_icon(source)
		proxy.tooltip_text = source.tooltip_text
		proxy.pressed.connect(_on_other_tool_selected.bind(proxy, source))
		_tools_flow.add_child(proxy)
		_other_proxies[StringName(source.name)] = proxy
		_source_by_proxy[proxy] = source


func _source_button(tool_name: StringName) -> BaseButton:
	if not Tools.tools.has(String(tool_name)):
		return null
	var tool: Tools.Tool = Tools.tools[String(tool_name)]
	return tool.button_node


func _source_icon(source: BaseButton) -> Texture2D:
	var icon_node := source.get_node_or_null(^"ToolIcon") as TextureRect
	if icon_node != null:
		return icon_node.texture
	var tool_name := String(source.name)
	if Tools.tools.has(tool_name):
		var tool: Tools.Tool = Tools.tools[tool_name]
		return tool.icon
	return null


func _on_primary_pressed(tool_name: StringName, anchor: BaseButton) -> void:
	if not active:
		return
	var current := _current_left_tool_name()
	if current != tool_name:
		_hide_all_popups()
		var source := _source_button(tool_name)
		if source != null and is_instance_valid(_tool_buttons):
			_tool_buttons.call(&"_on_tool_pressed", source)
		_refresh_visuals.call_deferred()
		return

	if is_instance_valid(_options_popup) and _options_popup.visible:
		_hide_options_popup()
		return
	_show_tool_options(anchor)


func _on_other_tools_pressed() -> void:
	if not active or not is_instance_valid(_other_tools_button):
		return
	if is_instance_valid(_tools_popup) and _tools_popup.visible:
		_hide_tools_popup()
		return
	_hide_all_popups()
	_refresh_visuals()
	_tools_popup.size = TOOLS_MENU_SIZE
	_position_popup(_tools_popup, _other_tools_button)
	_tools_popup.visible = true
	_tools_popup.move_to_front()


func _on_other_tool_selected(_proxy: BaseButton, source: BaseButton) -> void:
	if not active or not is_instance_valid(source) or not is_instance_valid(_tool_buttons):
		return
	_hide_tools_popup()
	_tool_buttons.call(&"_on_tool_pressed", source)
	_refresh_visuals.call_deferred()


func _on_color_pressed() -> void:
	if not active or not is_instance_valid(_color_button):
		return
	if is_instance_valid(_palette_popup) and _palette_popup.visible:
		_hide_palette_popup()
		return
	_hide_all_popups()
	_reparent_control(palette_root, _palette_host)
	palette_root.visible = true
	palette_root.custom_minimum_size = PALETTE_POPUP_SIZE - Vector2(16.0, 16.0)
	palette_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_palette_popup.size = PALETTE_POPUP_SIZE
	_position_popup(_palette_popup, _color_button)
	_palette_popup.visible = true
	_palette_popup.move_to_front()


func _show_tool_options(anchor: BaseButton) -> void:
	_hide_all_popups()
	if not _has_left_tool_options():
		return
	_reparent_control(left_tool_options, _options_host)
	left_tool_options.visible = true
	left_tool_options.custom_minimum_size = Vector2(OPTIONS_WIDTH - 16.0, 0.0)
	left_tool_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_tool_options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_tool_options.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_tool_options.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var desired_height := clampf(
		left_tool_options.get_combined_minimum_size().y + 16.0,
		OPTIONS_MIN_HEIGHT,
		OPTIONS_MAX_HEIGHT
	)
	_options_popup.size = Vector2(OPTIONS_WIDTH, desired_height)
	_position_popup(_options_popup, anchor)
	_options_popup.visible = true
	_options_popup.move_to_front()


func _position_popup(popup: Control, anchor: Control) -> void:
	if not is_instance_valid(popup) or not is_instance_valid(anchor):
		return
	var below := anchor.get_global_rect().end + Vector2(-popup.size.x + anchor.size.x, POPUP_GAP)
	var local_position := ui_root.get_global_transform_with_canvas().affine_inverse() * below
	var max_x := maxf(0.0, ui_root.size.x - popup.size.x)
	var max_y := maxf(0.0, ui_root.size.y - popup.size.y)
	popup.position = Vector2(
		clampf(local_position.x, 0.0, max_x), clampf(local_position.y, 0.0, max_y)
	)


func _hide_all_popups() -> void:
	_hide_options_popup()
	_hide_tools_popup()
	_hide_palette_popup()


func _hide_options_popup() -> void:
	if is_instance_valid(_options_popup):
		_options_popup.visible = false


func _hide_tools_popup() -> void:
	if is_instance_valid(_tools_popup):
		_tools_popup.visible = false


func _hide_palette_popup() -> void:
	if is_instance_valid(_palette_popup):
		_palette_popup.visible = false


func _has_left_tool_options() -> bool:
	if not is_instance_valid(left_tool_options):
		return false
	var panel := left_tool_options.get_node_or_null(^"LeftPanelContainer") as Control
	if panel == null or panel.get_child_count() == 0:
		return false
	var tool_node := panel.get_child(panel.get_child_count() - 1) as Control
	if tool_node == null:
		return false
	return tool_node.get_child_count() > 0 or tool_node.get_combined_minimum_size().y > 4.0


func _reparent_control(control: Control, parent: Node) -> void:
	if control == null or parent == null or control.get_parent() == parent:
		return
	if control.get_parent() != null:
		control.get_parent().remove_child(control)
	parent.add_child(control)


func _restore_left_tool_options() -> void:
	_restore_control(left_tool_options, _original_left_options_state)
	if is_instance_valid(left_tool_options) and not _original_left_options_state.is_empty():
		left_tool_options.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		left_tool_options.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


func _restore_palette_root() -> void:
	_restore_control(palette_root, _original_palette_state)


func _restore_control(control: Control, state: Dictionary) -> void:
	if control == null or state.is_empty():
		return
	var parent := state.get("parent") as Node
	if parent == null:
		return
	_reparent_control(control, parent)
	parent.move_child(control, mini(int(state.get("index", 0)), parent.get_child_count() - 1))
	control.visible = bool(state.get("visible", true))
	control.size_flags_horizontal = int(state.get("size_flags_horizontal", Control.SIZE_FILL))
	control.size_flags_vertical = int(state.get("size_flags_vertical", Control.SIZE_FILL))
	control.size_flags_stretch_ratio = float(state.get("stretch_ratio", 1.0))
	control.custom_minimum_size = state.get("custom_minimum_size", Vector2.ZERO) as Vector2


func _connect_runtime_signals() -> void:
	if not Tools.tool_changed.is_connected(_on_tool_changed):
		Tools.tool_changed.connect(_on_tool_changed)
	if not Tools.color_changed.is_connected(_on_color_changed):
		Tools.color_changed.connect(_on_color_changed)
	if not Global.cel_switched.is_connected(_on_context_changed):
		Global.cel_switched.connect(_on_context_changed)
	if not Global.single_tool_mode_changed.is_connected(_on_single_tool_mode_changed):
		Global.single_tool_mode_changed.connect(_on_single_tool_mode_changed)


func _on_tool_changed(_tool_name: String, button: int) -> void:
	if active and button == MOUSE_BUTTON_LEFT:
		_refresh_visuals.call_deferred()


func _on_color_changed(_color_info: Dictionary, button: int) -> void:
	if active and button == MOUSE_BUTTON_LEFT:
		_refresh_color_button.call_deferred()


func _on_context_changed() -> void:
	if active:
		_refresh_visuals.call_deferred()


func _on_single_tool_mode_changed(_enabled: bool) -> void:
	if active:
		_refresh_visuals.call_deferred()


func _refresh_visuals() -> void:
	if not active or Global.headless_test_mode:
		return
	var current := _current_left_tool_name()
	_pencil_button.button_pressed = current == &"Pencil"
	_eraser_button.button_pressed = current == &"Eraser"
	_other_tools_button.button_pressed = not is_primary_tool(current)

	var pencil_source := _source_button(&"Pencil")
	var eraser_source := _source_button(&"Eraser")
	if pencil_source != null:
		_pencil_button.visible = pencil_source.visible
		_pencil_button.icon = _source_icon(pencil_source)
	if eraser_source != null:
		_eraser_button.visible = eraser_source.visible
		_eraser_button.icon = _source_icon(eraser_source)

	for key in _other_proxies:
		var proxy := _other_proxies[key] as Button
		var source := _source_by_proxy.get(proxy) as BaseButton
		if proxy == null or source == null:
			continue
		proxy.visible = source.visible
		proxy.icon = _source_icon(source)
		proxy.tooltip_text = source.tooltip_text
		proxy.button_pressed = _source_represents_tool(source, current)
	_refresh_color_button()


func _source_represents_tool(source: BaseButton, active_tool: StringName) -> bool:
	if StringName(source.name) == active_tool:
		return true
	if not is_instance_valid(_tool_buttons):
		return false
	var selection_family := _tool_buttons.get("_ios_selection_family_button") as BaseButton
	if is_instance_valid(selection_family) and source == selection_family:
		return active_tool in SELECTION_TOOLS
	var shape_family := _tool_buttons.get("_ios_shape_family_button") as BaseButton
	if is_instance_valid(shape_family) and source == shape_family:
		return active_tool in SHAPE_TOOLS
	return false


func _refresh_color_button() -> void:
	if not is_instance_valid(_color_button):
		return
	var color := _current_left_color()
	var border := (
		Color(0.05, 0.05, 0.05, 0.85)
		if color.get_luminance() > 0.65
		else Color(1.0, 1.0, 1.0, 0.85)
	)
	for state_name in [&"normal", &"hover", &"pressed", &"focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.corner_radius_top_left = int(TOP_TOOL_SIZE.x * 0.5)
		style.corner_radius_top_right = int(TOP_TOOL_SIZE.x * 0.5)
		style.corner_radius_bottom_left = int(TOP_TOOL_SIZE.x * 0.5)
		style.corner_radius_bottom_right = int(TOP_TOOL_SIZE.x * 0.5)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = border
		_color_button.add_theme_stylebox_override(state_name, style)


func _current_left_tool_name() -> StringName:
	if not Tools._slots.has(MOUSE_BUTTON_LEFT):
		return &""
	var slot: Tools.Slot = Tools._slots[MOUSE_BUTTON_LEFT]
	if slot == null or not is_instance_valid(slot.tool_node):
		return &""
	return StringName(slot.tool_node.name)


func _current_left_color() -> Color:
	if not Tools._slots.has(MOUSE_BUTTON_LEFT):
		return Color.BLACK
	var slot: Tools.Slot = Tools._slots[MOUSE_BUTTON_LEFT]
	return slot.color if slot != null else Color.BLACK


func _input(event: InputEvent) -> void:
	if not active or not _any_popup_visible():
		return
	var pressed := false
	var position := Vector2.ZERO
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		pressed = touch.pressed
		position = touch.position
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		pressed = mouse.pressed
		position = mouse.position
	if not pressed:
		return

	for popup in [_options_popup, _tools_popup, _palette_popup]:
		if (
			is_instance_valid(popup)
			and popup.visible
			and popup.get_global_rect().has_point(position)
		):
			return
	for button in [_pencil_button, _eraser_button, _other_tools_button, _color_button]:
		if is_instance_valid(button) and button.get_global_rect().has_point(position):
			return
	_hide_all_popups()


func _any_popup_visible() -> bool:
	return (
		(is_instance_valid(_options_popup) and _options_popup.visible)
		or (is_instance_valid(_tools_popup) and _tools_popup.visible)
		or (is_instance_valid(_palette_popup) and _palette_popup.visible)
	)
