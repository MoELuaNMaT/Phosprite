class_name WorkspaceUIProfile2
extends Node

## UI Profile 2 presentation layer.
##
## This controller never owns tool state. It presents proxy buttons backed by the
## existing Tools/ToolButtons runtime, and temporarily reparents the existing
## Left Tool Options control. Leaving profile 2 restores the original Workspace
## tree so the other UI profiles remain untouched.

const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")

const PRIMARY_TOOLS: Array[StringName] = [&"Pencil", &"Eraser", &"Move", &"Bucket"]
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
const TOOL_BUTTON_SIZE := Vector2(36.0, 36.0)
const PRIMARY_OPTIONS_MIN_HEIGHT := 84.0
const TOP_OPTIONS_WIDTH := 300.0
const TOP_OPTIONS_MIN_HEIGHT := 100.0
const TOP_OPTIONS_MAX_HEIGHT := 360.0
const POPUP_GAP := 4.0

var ui_root: Control
var palette_root: VBoxContainer
var left_tool_options: ScrollContainer
var surface: WorkspaceSurface

var active := false

var _tool_buttons: Node
var _palette_tool_section: VBoxContainer
var _primary_row: HBoxContainer
var _primary_options_host: PanelContainer
var _top_tools_host: HBoxContainer
var _options_popup: PanelContainer
var _popup_options_host: MarginContainer
var _button_group := ButtonGroup.new()
var _primary_proxies: Dictionary = {}
var _top_proxies: Dictionary = {}
var _source_by_proxy: Dictionary = {}
var _original_left_options_state: Dictionary = {}
var _popup_anchor: BaseButton
var _pending_popup_anchor: BaseButton


static func is_primary_tool(tool_name: StringName) -> bool:
	return tool_name in PRIMARY_TOOLS


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
	_palette_tool_section.visible = true
	_top_tools_host.visible = true
	_refresh_proxy_visuals()
	_sync_options_location()
	return true


func deactivate() -> void:
	active = false
	_pending_popup_anchor = null
	_popup_anchor = null
	if Global.headless_test_mode:
		return
	_hide_options_popup()
	_restore_left_tool_options()
	if is_instance_valid(_palette_tool_section):
		_palette_tool_section.visible = false
	if is_instance_valid(_top_tools_host):
		_top_tools_host.visible = false


func refresh_after_tools_ready() -> bool:
	if not active:
		return true
	return activate()


func enforce_workspace() -> bool:
	if not active or surface == null:
		return true
	return surface.park_module(Builtins.TOOLS_ID)


func _dependencies_ready() -> bool:
	return (
		is_instance_valid(palette_root)
		and is_instance_valid(left_tool_options)
		and is_instance_valid(Tools._tool_buttons)
	)


func _ensure_presentation() -> bool:
	if is_instance_valid(_palette_tool_section) and is_instance_valid(_top_tools_host):
		return true
	if not _dependencies_ready():
		return false
	_tool_buttons = Tools._tool_buttons
	if not _capture_left_options_state():
		return false
	if not _create_palette_tool_section():
		return false
	if not _create_top_tools_host():
		return false
	_create_options_popup()
	_connect_runtime_signals()
	return _build_proxy_buttons()


func _capture_left_options_state() -> bool:
	if not _original_left_options_state.is_empty():
		return true
	var parent := left_tool_options.get_parent()
	if parent == null:
		return false
	_original_left_options_state = {
		"parent": parent,
		"index": left_tool_options.get_index(),
		"visible": left_tool_options.visible,
		"size_flags_horizontal": left_tool_options.size_flags_horizontal,
		"size_flags_vertical": left_tool_options.size_flags_vertical,
		"stretch_ratio": left_tool_options.size_flags_stretch_ratio,
		"custom_minimum_size": left_tool_options.custom_minimum_size,
		"horizontal_scroll_mode": left_tool_options.horizontal_scroll_mode,
		"vertical_scroll_mode": left_tool_options.vertical_scroll_mode,
	}
	return true


func _create_palette_tool_section() -> bool:
	var color_picker := palette_root.get_node_or_null(^"Color Picker") as Control
	if color_picker == null:
		return false

	_palette_tool_section = VBoxContainer.new()
	_palette_tool_section.name = &"UIProfile2PaletteTools"
	_palette_tool_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_palette_tool_section.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_palette_tool_section.add_theme_constant_override(&"separation", 4)
	palette_root.add_child(_palette_tool_section)
	palette_root.move_child(_palette_tool_section, color_picker.get_index())

	_primary_row = HBoxContainer.new()
	_primary_row.name = &"PrimaryTools"
	_primary_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_primary_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_primary_row.add_theme_constant_override(&"separation", 4)
	_palette_tool_section.add_child(_primary_row)

	_primary_options_host = PanelContainer.new()
	_primary_options_host.name = &"PrimaryToolOptions"
	_primary_options_host.custom_minimum_size = Vector2(0.0, PRIMARY_OPTIONS_MIN_HEIGHT)
	_primary_options_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_primary_options_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_palette_tool_section.add_child(_primary_options_host)

	var separator := HSeparator.new()
	separator.name = &"Profile2PaletteColorSeparator"
	_palette_tool_section.add_child(separator)
	return true


func _create_top_tools_host() -> bool:
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

	_top_tools_host = HBoxContainer.new()
	_top_tools_host.name = &"UIProfile2TopTools"
	_top_tools_host.size_flags_horizontal = Control.SIZE_SHRINK_END
	_top_tools_host.alignment = BoxContainer.ALIGNMENT_END
	_top_tools_host.add_theme_constant_override(&"separation", 2)
	row.add_child(_top_tools_host)
	row.move_child(_top_tools_host, row.get_child_count() - 1)
	return true


func _create_options_popup() -> void:
	_options_popup = PanelContainer.new()
	_options_popup.name = &"UIProfile2ToolOptionsPopup"
	_options_popup.visible = false
	_options_popup.z_index = 1000
	_options_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(_options_popup)

	_popup_options_host = MarginContainer.new()
	_popup_options_host.name = &"OptionsHost"
	_popup_options_host.add_theme_constant_override(&"margin_left", 8)
	_popup_options_host.add_theme_constant_override(&"margin_top", 8)
	_popup_options_host.add_theme_constant_override(&"margin_right", 8)
	_popup_options_host.add_theme_constant_override(&"margin_bottom", 8)
	_options_popup.add_child(_popup_options_host)


func _build_proxy_buttons() -> bool:
	for tool_name in PRIMARY_TOOLS:
		var source := _source_button(tool_name)
		if source == null:
			return false
		var proxy := _make_proxy_button(source)
		_primary_row.add_child(proxy)
		_primary_proxies[tool_name] = proxy

	for child in _tool_buttons.get_children():
		var source := child as BaseButton
		if source == null:
			continue
		var tool_name := StringName(source.name)
		if is_primary_tool(tool_name):
			continue
		var proxy := _make_proxy_button(source)
		_top_tools_host.add_child(proxy)
		_top_proxies[tool_name] = proxy
	return true


func _make_proxy_button(source: BaseButton) -> Button:
	var proxy := Button.new()
	proxy.name = StringName("Profile2_" + String(source.name))
	proxy.custom_minimum_size = TOOL_BUTTON_SIZE
	proxy.focus_mode = Control.FOCUS_NONE
	proxy.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	proxy.flat = true
	proxy.toggle_mode = true
	proxy.button_group = _button_group
	proxy.tooltip_text = source.tooltip_text
	proxy.expand_icon = true
	proxy.icon_max_width = int(TOOL_BUTTON_SIZE.x - 8.0)
	proxy.icon = _source_icon(source)
	proxy.pressed.connect(_on_proxy_pressed.bind(proxy, source))
	_source_by_proxy[proxy] = source
	return proxy


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


func _on_proxy_pressed(proxy: BaseButton, source: BaseButton) -> void:
	if not active or not is_instance_valid(source) or not is_instance_valid(_tool_buttons):
		return
	var tool_name := StringName(source.name)
	if is_primary_tool(tool_name):
		_pending_popup_anchor = null
		_hide_options_popup()
		_tool_buttons.call(&"_on_tool_pressed", source)
		_move_options_to_primary.call_deferred()
		return

	var was_same_anchor := _popup_anchor == proxy and is_instance_valid(_options_popup)
	var popup_was_visible := was_same_anchor and _options_popup.visible
	_pending_popup_anchor = proxy
	_tool_buttons.call(&"_on_tool_pressed", source)
	if popup_was_visible:
		_pending_popup_anchor = null
		_hide_options_popup()
	else:
		_show_requested_top_options.call_deferred(proxy)


func _move_options_to_primary() -> void:
	if not active or not is_instance_valid(_primary_options_host):
		return
	_hide_options_popup()
	_reparent_left_options(_primary_options_host)
	left_tool_options.custom_minimum_size = Vector2(0.0, PRIMARY_OPTIONS_MIN_HEIGHT)
	left_tool_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_tool_options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_tool_options.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_tool_options.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	left_tool_options.visible = true
	_refresh_proxy_visuals()


func _show_requested_top_options(proxy: BaseButton) -> void:
	if not active or _pending_popup_anchor != proxy or not is_instance_valid(proxy):
		return
	_pending_popup_anchor = null
	if not _has_left_tool_options():
		_hide_options_popup()
		return
	_popup_anchor = proxy
	_reparent_left_options(_popup_options_host)
	left_tool_options.custom_minimum_size = Vector2(TOP_OPTIONS_WIDTH - 16.0, 0.0)
	left_tool_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_tool_options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_tool_options.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_tool_options.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	left_tool_options.visible = true

	var desired_height := clampf(
		left_tool_options.get_combined_minimum_size().y + 16.0,
		TOP_OPTIONS_MIN_HEIGHT,
		TOP_OPTIONS_MAX_HEIGHT
	)
	_options_popup.size = Vector2(TOP_OPTIONS_WIDTH, desired_height)
	var below := proxy.get_global_rect().end + Vector2(-proxy.size.x, POPUP_GAP)
	var local_position := ui_root.get_global_transform_with_canvas().affine_inverse() * below
	var max_x := maxf(0.0, ui_root.size.x - _options_popup.size.x)
	var max_y := maxf(0.0, ui_root.size.y - _options_popup.size.y)
	_options_popup.position = Vector2(
		clampf(local_position.x, 0.0, max_x), clampf(local_position.y, 0.0, max_y)
	)
	_options_popup.visible = true
	_options_popup.move_to_front()
	_refresh_proxy_visuals()


func _sync_options_location() -> void:
	var active_tool := _current_left_tool_name()
	if is_primary_tool(active_tool):
		_move_options_to_primary()
	elif is_instance_valid(_options_popup):
		_hide_options_popup()
		_reparent_left_options(_popup_options_host)


func _hide_options_popup() -> void:
	if is_instance_valid(_options_popup):
		_options_popup.visible = false
	_popup_anchor = null


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


func _reparent_left_options(parent: Node) -> void:
	if parent == null or not is_instance_valid(left_tool_options):
		return
	if left_tool_options.get_parent() == parent:
		return
	if left_tool_options.get_parent() != null:
		left_tool_options.get_parent().remove_child(left_tool_options)
	parent.add_child(left_tool_options)


func _restore_left_tool_options() -> void:
	if _original_left_options_state.is_empty() or not is_instance_valid(left_tool_options):
		return
	var parent := _original_left_options_state.get("parent") as Node
	if parent == null:
		return
	_reparent_left_options(parent)
	parent.move_child(
		left_tool_options,
		mini(int(_original_left_options_state.get("index", 0)), parent.get_child_count() - 1)
	)
	left_tool_options.visible = bool(_original_left_options_state.get("visible", true))
	left_tool_options.size_flags_horizontal = int(
		_original_left_options_state.get("size_flags_horizontal", Control.SIZE_FILL)
	)
	left_tool_options.size_flags_vertical = int(
		_original_left_options_state.get("size_flags_vertical", Control.SIZE_FILL)
	)
	left_tool_options.size_flags_stretch_ratio = float(
		_original_left_options_state.get("stretch_ratio", 1.0)
	)
	left_tool_options.custom_minimum_size = (
		_original_left_options_state.get("custom_minimum_size", Vector2.ZERO) as Vector2
	)
	left_tool_options.horizontal_scroll_mode = int(
		_original_left_options_state.get("horizontal_scroll_mode", ScrollContainer.SCROLL_MODE_AUTO)
	)
	left_tool_options.vertical_scroll_mode = int(
		_original_left_options_state.get("vertical_scroll_mode", ScrollContainer.SCROLL_MODE_AUTO)
	)


func _connect_runtime_signals() -> void:
	if not Tools.tool_changed.is_connected(_on_tool_changed):
		Tools.tool_changed.connect(_on_tool_changed)
	if not Global.cel_switched.is_connected(_on_workspace_context_changed):
		Global.cel_switched.connect(_on_workspace_context_changed)
	if not Global.single_tool_mode_changed.is_connected(_on_single_tool_mode_changed):
		Global.single_tool_mode_changed.connect(_on_single_tool_mode_changed)


func _on_tool_changed(_tool_name: String, button: int) -> void:
	if not active or button != MOUSE_BUTTON_LEFT:
		return
	_refresh_proxy_visuals.call_deferred()
	var active_tool := _current_left_tool_name()
	if is_primary_tool(active_tool):
		_pending_popup_anchor = null
		_move_options_to_primary.call_deferred()


func _on_workspace_context_changed() -> void:
	if active:
		_refresh_proxy_visuals.call_deferred()


func _on_single_tool_mode_changed(_enabled: bool) -> void:
	if active:
		_refresh_proxy_visuals.call_deferred()


func _refresh_proxy_visuals() -> void:
	if not active or Global.headless_test_mode:
		return
	var active_tool := _current_left_tool_name()
	for key in _primary_proxies:
		var tool_name := key as StringName
		var proxy := _primary_proxies[key] as Button
		var source := _source_button(tool_name)
		if proxy == null or source == null:
			continue
		proxy.visible = source.visible
		proxy.icon = _source_icon(source)
		proxy.button_pressed = active_tool == tool_name

	for key in _top_proxies:
		var proxy := _top_proxies[key] as Button
		var source := _source_by_proxy.get(proxy) as BaseButton
		if proxy == null or source == null:
			continue
		proxy.visible = source.visible
		proxy.icon = _source_icon(source)
		proxy.tooltip_text = source.tooltip_text
		proxy.button_pressed = _source_represents_tool(source, active_tool)


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


func _current_left_tool_name() -> StringName:
	if not Tools._slots.has(MOUSE_BUTTON_LEFT):
		return &""
	var slot: Tools.Slot = Tools._slots[MOUSE_BUTTON_LEFT]
	if slot == null or not is_instance_valid(slot.tool_node):
		return &""
	return StringName(slot.tool_node.name)


func _input(event: InputEvent) -> void:
	if not active or not is_instance_valid(_options_popup) or not _options_popup.visible:
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
	if _options_popup.get_global_rect().has_point(position):
		return
	if is_instance_valid(_popup_anchor) and _popup_anchor.get_global_rect().has_point(position):
		return
	_hide_options_popup()
