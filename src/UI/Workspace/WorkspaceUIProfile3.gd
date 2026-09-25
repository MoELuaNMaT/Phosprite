class_name WorkspaceUIProfile3
extends Node

## Procreate-inspired presentation for UI profile 3.
##
## Profile 3 keeps the existing editor/tool state authoritative and only changes
## how it is presented: Preview defaults to the upper-left, standalone Tools and
## Palette workspace modules are parked, and the top-right taskbar exposes Brush,
## Eraser, Other Tools, and the current color.

const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")

const BRUSH_TOOL := &"Pencil"
const ERASER_TOOL := &"Eraser"
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
const TASK_BUTTON_SIZE := Vector2(38.0, 38.0)
const POPUP_GAP := 6.0
const OPTIONS_WIDTH := 300.0
const OPTIONS_MIN_HEIGHT := 100.0
const OPTIONS_MAX_HEIGHT := 360.0
const TOOLS_POPUP_WIDTH := 252.0
const TOOLS_POPUP_HEIGHT := 300.0
const PALETTE_POPUP_SIZE := Vector2(320.0, 460.0)
const PREVIEW_MARGIN := Vector2(8.0, 8.0)

var ui_root: Control
var left_tool_options: ScrollContainer
var surface: WorkspaceSurface

var active := false

var _tool_buttons: Node
var _taskbar: HBoxContainer
var _brush_button: Button
var _eraser_button: Button
var _other_button: Button
var _color_button: Button
var _color_indicator: Control

var _options_popup: PanelContainer
var _options_host: MarginContainer
var _other_popup: PanelContainer
var _other_grid: GridContainer
var _palette_popup: PanelContainer
var _palette_content: Control

var _other_sources: Dictionary = {}
var _original_left_options_state: Dictionary = {}


static func is_primary_tool(tool_name: StringName) -> bool:
	return tool_name == BRUSH_TOOL or tool_name == ERASER_TOOL


func setup(
	root: Control, left_options: ScrollContainer, workspace_surface: WorkspaceSurface
) -> bool:
	if ui_root != null or root == null or left_options == null or workspace_surface == null:
		return false
	ui_root = root
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
	_taskbar.visible = true
	_refresh_taskbar()
	return true


func deactivate() -> void:
	active = false
	if Global.headless_test_mode:
		return
	_close_all_popups()
	_restore_left_tool_options()
	if is_instance_valid(_taskbar):
		_taskbar.visible = false


func refresh_after_tools_ready() -> bool:
	if not active:
		return true
	return activate()


func enforce_workspace() -> bool:
	if not active or surface == null:
		return true
	for module_id in [
		Builtins.TOOLS_ID,
		Builtins.PALETTE_ID,
		Builtins.RIGHT_TOOL_OPTIONS_ID,
	]:
		if not surface.park_module(module_id):
			return false
	return true


func apply_initial_workspace() -> bool:
	if surface == null:
		return false
	if not enforce_workspace():
		return false
	var placement := surface.get_module_placement(Builtins.PREVIEW_ID)
	if placement == WorkspaceSurface.Placement.COLLAPSED:
		if not surface.restore_module(Builtins.PREVIEW_ID):
			return false
		placement = surface.get_module_placement(Builtins.PREVIEW_ID)

	var definition := surface.manager.get_definition(Builtins.PREVIEW_ID)
	if definition == null:
		return false
	var size := definition.get_constrained_preferred_size()
	if placement == WorkspaceSurface.Placement.FLOATING:
		var current := surface.get_floating_rect(Builtins.PREVIEW_ID)
		if current.has_area():
			size = current.size
	var bounds := surface.get_floating_bounds()
	var target := Rect2(bounds.position + PREVIEW_MARGIN, size)
	if placement == WorkspaceSurface.Placement.FLOATING:
		return surface.set_floating_rect(Builtins.PREVIEW_ID, target)
	return surface.float_module(Builtins.PREVIEW_ID, target)


func _dependencies_ready() -> bool:
	return is_instance_valid(left_tool_options) and is_instance_valid(Tools._tool_buttons)


func _ensure_presentation() -> bool:
	if is_instance_valid(_taskbar):
		return true
	_tool_buttons = Tools._tool_buttons
	if not _capture_left_options_state():
		return false
	if not _create_taskbar():
		return false
	_create_options_popup()
	_create_other_tools_popup()
	if not _create_palette_popup():
		return false
	_connect_runtime_signals()
	return _build_other_tools()


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


func _create_taskbar() -> bool:
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

	_taskbar = HBoxContainer.new()
	_taskbar.name = &"UIProfile3Taskbar"
	_taskbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_taskbar.alignment = BoxContainer.ALIGNMENT_END
	_taskbar.add_theme_constant_override(&"separation", 3)
	row.add_child(_taskbar)
	row.move_child(_taskbar, row.get_child_count() - 1)

	_brush_button = _make_icon_button(BRUSH_TOOL, "Brush")
	_eraser_button = _make_icon_button(ERASER_TOOL, "Eraser")
	_other_button = Button.new()
	_other_button.name = &"OtherTools"
	_other_button.custom_minimum_size = TASK_BUTTON_SIZE
	_other_button.focus_mode = Control.FOCUS_NONE
	_other_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_other_button.flat = true
	_other_button.toggle_mode = true
	_other_button.text = "•••"
	_other_button.tooltip_text = "Other Tools"
	_other_button.pressed.connect(_on_other_button_pressed)

	_color_button = Button.new()
	_color_button.name = &"CurrentColor"
	_color_button.custom_minimum_size = TASK_BUTTON_SIZE
	_color_button.focus_mode = Control.FOCUS_NONE
	_color_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_color_button.flat = true
	_color_button.tooltip_text = "Palette & Color"
	_color_button.pressed.connect(_on_color_button_pressed)
	_color_indicator = Control.new()
	_color_indicator.name = &"ColorCircle"
	_color_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_indicator.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE
	)
	_color_indicator.draw.connect(_draw_color_indicator)

	for button in [_brush_button, _eraser_button, _other_button, _color_button]:
		_taskbar.add_child(button)
	_color_button.add_child(_color_indicator)
	return true


func _make_icon_button(tool_name: StringName, tooltip: String) -> Button:
	var button := Button.new()
	button.name = StringName("Profile3_" + String(tool_name))
	button.custom_minimum_size = TASK_BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.flat = true
	button.toggle_mode = true
	button.tooltip_text = tooltip
	button.expand_icon = true
	button.icon_max_width = int(TASK_BUTTON_SIZE.x - 8.0)
	if Tools.tools.has(String(tool_name)):
		var tool: Tools.Tool = Tools.tools[String(tool_name)]
		button.icon = tool.icon
	button.pressed.connect(_on_primary_button_pressed.bind(tool_name, button))
	return button


func _create_options_popup() -> void:
	_options_popup = PanelContainer.new()
	_options_popup.name = &"UIProfile3ToolOptionsPopup"
	_options_popup.visible = false
	_options_popup.z_index = 1000
	_options_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(_options_popup)

	_options_host = MarginContainer.new()
	_options_host.add_theme_constant_override(&"margin_left", 8)
	_options_host.add_theme_constant_override(&"margin_top", 8)
	_options_host.add_theme_constant_override(&"margin_right", 8)
	_options_host.add_theme_constant_override(&"margin_bottom", 8)
	_options_popup.add_child(_options_host)


func _create_other_tools_popup() -> void:
	_other_popup = PanelContainer.new()
	_other_popup.name = &"UIProfile3OtherToolsPopup"
	_other_popup.visible = false
	_other_popup.z_index = 1000
	_other_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(_other_popup)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(TOOLS_POPUP_WIDTH, TOOLS_POPUP_HEIGHT)
	_other_popup.add_child(scroll)

	_other_grid = GridContainer.new()
	_other_grid.name = &"OtherToolsGrid"
	_other_grid.columns = 4
	_other_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_other_grid.add_theme_constant_override(&"h_separation", 4)
	_other_grid.add_theme_constant_override(&"v_separation", 4)
	scroll.add_child(_other_grid)


func _create_palette_popup() -> bool:
	var content := Builtins.PALETTE_SCENE.instantiate()
	if not content is Control:
		if content != null:
			content.free()
		return false

	_palette_popup = PanelContainer.new()
	_palette_popup.name = &"UIProfile3PalettePopup"
	_palette_popup.visible = false
	_palette_popup.z_index = 1000
	_palette_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_palette_popup.custom_minimum_size = PALETTE_POPUP_SIZE
	ui_root.add_child(_palette_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 8)
	margin.add_theme_constant_override(&"margin_top", 8)
	margin.add_theme_constant_override(&"margin_right", 8)
	margin.add_theme_constant_override(&"margin_bottom", 8)
	_palette_popup.add_child(margin)
	_palette_content = content as Control
	_palette_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_palette_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_palette_content)
	return true


func _build_other_tools() -> bool:
	if not is_instance_valid(_tool_buttons):
		return false
	for child in _tool_buttons.get_children():
		var source := child as BaseButton
		if source == null:
			continue
		var tool_name := StringName(source.name)
		if is_primary_tool(tool_name):
			continue
		var proxy := Button.new()
		proxy.name = StringName("Profile3Other_" + String(tool_name))
		proxy.custom_minimum_size = TASK_BUTTON_SIZE
		proxy.focus_mode = Control.FOCUS_NONE
		proxy.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		proxy.flat = true
		proxy.toggle_mode = true
		proxy.expand_icon = true
		proxy.icon_max_width = int(TASK_BUTTON_SIZE.x - 8.0)
		proxy.tooltip_text = source.tooltip_text
		proxy.icon = _source_icon(source)
		proxy.pressed.connect(_on_other_tool_pressed.bind(proxy, source))
		_other_grid.add_child(proxy)
		_other_sources[proxy] = source
	return true


func _source_icon(source: BaseButton) -> Texture2D:
	var icon_node := source.get_node_or_null(^"ToolIcon") as TextureRect
	if icon_node != null:
		return icon_node.texture
	var name := String(source.name)
	if Tools.tools.has(name):
		var tool: Tools.Tool = Tools.tools[name]
		return tool.icon
	return null


func _on_primary_button_pressed(tool_name: StringName, button: BaseButton) -> void:
	if not active:
		return
	var current := _current_left_tool_name()
	if current != tool_name:
		_close_all_popups()
		Tools.assign_tool(String(tool_name), MOUSE_BUTTON_LEFT)
		Tools.prev_tool_names[MOUSE_BUTTON_LEFT] = ""
		_refresh_taskbar.call_deferred()
		return
	button.button_pressed = true
	if is_instance_valid(_options_popup) and _options_popup.visible:
		_hide_options_popup()
	else:
		_close_all_popups()
		_show_options_popup.call_deferred(button)


func _on_other_button_pressed() -> void:
	if not active:
		return
	_other_button.button_pressed = not is_primary_tool(_current_left_tool_name())
	if is_instance_valid(_other_popup) and _other_popup.visible:
		_other_popup.visible = false
		return
	_close_all_popups()
	_refresh_other_tools()
	_place_popup_below(_other_popup, _other_button, Vector2(TOOLS_POPUP_WIDTH, TOOLS_POPUP_HEIGHT))


func _on_other_tool_pressed(_proxy: BaseButton, source: BaseButton) -> void:
	if not active or not is_instance_valid(source):
		return
	var current := _current_left_tool_name()
	var repeated := _source_represents_tool(source, current)
	_other_popup.visible = false
	_tool_buttons.call(&"_on_tool_pressed", source)
	if repeated:
		_show_options_popup.call_deferred(_other_button)
	else:
		_hide_options_popup()
	_refresh_taskbar.call_deferred()


func _on_color_button_pressed() -> void:
	if not active:
		return
	if is_instance_valid(_palette_popup) and _palette_popup.visible:
		_palette_popup.visible = false
		return
	_close_all_popups()
	_place_popup_below(_palette_popup, _color_button, PALETTE_POPUP_SIZE)


func _show_options_popup(anchor: BaseButton) -> void:
	if not active or not is_instance_valid(anchor):
		return
	if not _has_left_tool_options():
		return
	_reparent_left_options(_options_host)
	left_tool_options.custom_minimum_size = Vector2(OPTIONS_WIDTH - 16.0, 0.0)
	left_tool_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_tool_options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_tool_options.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_tool_options.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	left_tool_options.visible = true
	var height := clampf(
		left_tool_options.get_combined_minimum_size().y + 16.0,
		OPTIONS_MIN_HEIGHT,
		OPTIONS_MAX_HEIGHT
	)
	_place_popup_below(_options_popup, anchor, Vector2(OPTIONS_WIDTH, height))


func _place_popup_below(popup: Control, anchor: Control, desired_size: Vector2) -> void:
	if popup == null or anchor == null:
		return
	popup.size = desired_size
	var global_target := (
		anchor.get_global_rect().end + Vector2(-desired_size.x + anchor.size.x, POPUP_GAP)
	)
	var local_target := ui_root.get_global_transform_with_canvas().affine_inverse() * global_target
	popup.position = Vector2(
		clampf(local_target.x, 0.0, maxf(0.0, ui_root.size.x - desired_size.x)),
		clampf(local_target.y, 0.0, maxf(0.0, ui_root.size.y - desired_size.y))
	)
	popup.visible = true
	popup.move_to_front()


func _hide_options_popup() -> void:
	if is_instance_valid(_options_popup):
		_options_popup.visible = false


func _close_all_popups() -> void:
	for popup in [_options_popup, _other_popup, _palette_popup]:
		if is_instance_valid(popup):
			popup.visible = false


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
	if not Tools.color_changed.is_connected(_on_color_changed):
		Tools.color_changed.connect(_on_color_changed)
	if not Global.cel_switched.is_connected(_on_context_changed):
		Global.cel_switched.connect(_on_context_changed)
	if not Global.single_tool_mode_changed.is_connected(_on_single_tool_mode_changed):
		Global.single_tool_mode_changed.connect(_on_single_tool_mode_changed)


func _on_tool_changed(_tool_name: String, button: int) -> void:
	if active and button == MOUSE_BUTTON_LEFT:
		_refresh_taskbar.call_deferred()


func _on_color_changed(_color_info: Dictionary, button: int) -> void:
	if active and button == MOUSE_BUTTON_LEFT and is_instance_valid(_color_indicator):
		_color_indicator.queue_redraw()


func _on_context_changed() -> void:
	if active:
		_refresh_other_tools.call_deferred()
		_refresh_taskbar.call_deferred()


func _on_single_tool_mode_changed(_enabled: bool) -> void:
	if active:
		_refresh_taskbar.call_deferred()


func _refresh_taskbar() -> void:
	if not active or Global.headless_test_mode:
		return
	var current := _current_left_tool_name()
	if is_instance_valid(_brush_button):
		_brush_button.button_pressed = current == BRUSH_TOOL
	if is_instance_valid(_eraser_button):
		_eraser_button.button_pressed = current == ERASER_TOOL
	if is_instance_valid(_other_button):
		_other_button.button_pressed = not is_primary_tool(current)
	if is_instance_valid(_color_indicator):
		_color_indicator.queue_redraw()


func _refresh_other_tools() -> void:
	if not is_instance_valid(_other_grid):
		return
	var current := _current_left_tool_name()
	for key in _other_sources:
		var proxy := key as Button
		var source := _other_sources[key] as BaseButton
		if proxy == null or source == null:
			continue
		proxy.visible = source.visible
		proxy.icon = _source_icon(source)
		proxy.tooltip_text = source.tooltip_text
		proxy.button_pressed = _source_represents_tool(source, current)


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


func _draw_color_indicator() -> void:
	if not is_instance_valid(_color_indicator):
		return
	var radius := minf(_color_indicator.size.x, _color_indicator.size.y) * 0.30
	var center := _color_indicator.size * 0.5
	var color := Tools.get_assigned_color(MOUSE_BUTTON_LEFT)
	_color_indicator.draw_circle(center, radius + 2.0, Color(1.0, 1.0, 1.0, 0.9))
	_color_indicator.draw_circle(center, radius, color)
	_color_indicator.draw_arc(
		center, radius + 2.0, 0.0, TAU, 32, Color(0.0, 0.0, 0.0, 0.7), 1.0, true
	)


func _input(event: InputEvent) -> void:
	if not active:
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
	for popup in [_options_popup, _other_popup, _palette_popup]:
		if (
			is_instance_valid(popup)
			and popup.visible
			and popup.get_global_rect().has_point(position)
		):
			return
	if is_instance_valid(_taskbar) and _taskbar.get_global_rect().has_point(position):
		return
	_close_all_popups()
