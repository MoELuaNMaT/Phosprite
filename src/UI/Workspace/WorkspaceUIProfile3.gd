class_name WorkspaceUIProfile3
extends Node

## Procreate-inspired presentation for UI profile 3.
##
## Profile 3 keeps the existing editor/tool state authoritative and only changes
## how it is presented: Preview defaults to the upper-left, standalone Tools and
## Palette workspace modules are parked, all first-level tools live in the top-right
## taskbar, and a persistent floating options panel follows the active tool.

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
	&"LineTool",
	&"CurveTool",
	&"RectangleTool",
	&"EllipseTool",
	&"IsometricBoxTool",
]
const TASK_BUTTON_SIZE := Vector2(38.0, 38.0)
const FAMILY_BUTTON_SIZE := Vector2(42.0, 38.0)
const POPUP_GAP := 6.0
const OPTIONS_WIDTH := 620.0
const OPTIONS_MIN_HEIGHT := 112.0
const OPTIONS_MAX_HEIGHT := 380.0
const PALETTE_POPUP_SIZE := Vector2(320.0, 460.0)
const PREVIEW_MARGIN := Vector2(8.0, 8.0)
const SELECTED_TOOL_TINT := Color(0.45, 0.78, 1.0, 1.0)
const UNSELECTED_TOOL_TINT := Color.WHITE

var ui_root: Control
var left_tool_options: ScrollContainer
var surface: WorkspaceSurface

var active := false

var _tool_buttons: Node
var _taskbar: HBoxContainer
var _brush_button: Button
var _eraser_button: Button
var _color_button: Button
var _color_indicator: Control
var _toolbar_sources: Dictionary = {}

var _options_popup: PanelContainer
var _options_root: VBoxContainer
var _tool_title: Label
var _family_row: HBoxContainer
var _family_buttons: Dictionary = {}
var _options_host: MarginContainer

var _palette_popup: PanelContainer
var _palette_content: Control

var _original_left_options_state: Dictionary = {}
var _horizontalized_tool: BaseTool
var _last_active_tool := &""


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
	set_process_input(false)
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
	_options_popup.visible = true
	_last_active_tool = _current_left_tool_name()
	_refresh_taskbar()
	_refresh_config_panel()
	return true


func deactivate() -> void:
	active = false
	if Global.headless_test_mode:
		return
	if is_instance_valid(_palette_popup):
		_palette_popup.visible = false
	if is_instance_valid(_options_popup):
		_options_popup.visible = false
	_set_current_options_horizontal(false)
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
	if not _build_toolbar_tools():
		return false
	_create_options_panel()
	if not _create_palette_popup():
		return false
	_connect_runtime_signals()
	return true


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
	return true


func _build_toolbar_tools() -> bool:
	if not is_instance_valid(_tool_buttons) or not is_instance_valid(_taskbar):
		return false
	for child in _tool_buttons.get_children():
		var source := child as BaseButton
		if source == null:
			continue
		var tool_name := StringName(source.name)
		if is_primary_tool(tool_name):
			continue
		var proxy := _make_toolbar_proxy(source)
		_taskbar.add_child(proxy)
		_toolbar_sources[proxy] = source

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
	_taskbar.add_child(_color_button)
	_color_button.add_child(_color_indicator)
	_color_indicator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_brush_button = _make_primary_button(BRUSH_TOOL, "Brush")
	_eraser_button = _make_primary_button(ERASER_TOOL, "Eraser")
	_taskbar.add_child(_brush_button)
	_taskbar.add_child(_eraser_button)
	return true


func _make_toolbar_proxy(source: BaseButton) -> Button:
	var tool_name := StringName(source.name)
	var button := Button.new()
	button.name = StringName("Profile3_" + String(tool_name))
	button.custom_minimum_size = TASK_BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.flat = true
	button.toggle_mode = true
	button.expand_icon = true
	button.icon_max_width = int(TASK_BUTTON_SIZE.x - 8.0)
	button.tooltip_text = source.tooltip_text
	button.icon = _source_icon(source)
	button.pressed.connect(_on_toolbar_tool_pressed.bind(button, source))
	return button


func _make_primary_button(tool_name: StringName, tooltip: String) -> Button:
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
	button.pressed.connect(_on_primary_button_pressed.bind(tool_name))
	return button


func _create_options_panel() -> void:
	_options_popup = PanelContainer.new()
	_options_popup.name = &"UIProfile3ToolOptionsPanel"
	_options_popup.visible = false
	_options_popup.z_index = 1000
	_options_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(_options_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 10)
	margin.add_theme_constant_override(&"margin_top", 8)
	margin.add_theme_constant_override(&"margin_right", 10)
	margin.add_theme_constant_override(&"margin_bottom", 8)
	_options_popup.add_child(margin)

	_options_root = VBoxContainer.new()
	_options_root.name = &"ToolOptionsRoot"
	_options_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options_root.add_theme_constant_override(&"separation", 6)
	margin.add_child(_options_root)

	_tool_title = Label.new()
	_tool_title.name = &"ActiveToolTitle"
	_tool_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_options_root.add_child(_tool_title)

	_family_row = HBoxContainer.new()
	_family_row.name = &"FamilyChooser"
	_family_row.visible = false
	_family_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_family_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_family_row.add_theme_constant_override(&"separation", 4)
	_options_root.add_child(_family_row)

	var separator := HSeparator.new()
	separator.name = &"OptionsSeparator"
	_options_root.add_child(separator)

	_options_host = MarginContainer.new()
	_options_host.name = &"OptionsHost"
	_options_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_options_root.add_child(_options_host)


func _create_palette_popup() -> bool:
	var content := Builtins.PALETTE_SCENE.instantiate()
	if not content is Control:
		if content != null:
			content.free()
		return false

	_palette_popup = PanelContainer.new()
	_palette_popup.name = &"UIProfile3PalettePopup"
	_palette_popup.visible = false
	_palette_popup.z_index = 1001
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


func _source_icon(source: BaseButton) -> Texture2D:
	var icon_node := source.get_node_or_null(^"ToolIcon") as TextureRect
	if icon_node != null:
		return icon_node.texture
	var name := String(source.name)
	if Tools.tools.has(name):
		var tool: Tools.Tool = Tools.tools[name]
		return tool.icon
	return null


func _on_primary_button_pressed(tool_name: StringName) -> void:
	if not active:
		return
	if _current_left_tool_name() != tool_name:
		Tools.assign_tool(String(tool_name), MOUSE_BUTTON_LEFT)
		Tools.prev_tool_names[MOUSE_BUTTON_LEFT] = ""
	_refresh_taskbar.call_deferred()
	_refresh_config_panel.call_deferred()


func _on_toolbar_tool_pressed(_proxy: BaseButton, source: BaseButton) -> void:
	if not active or not is_instance_valid(source):
		return
	var target := StringName(source.name)
	if _is_selection_family_source(source):
		target = _family_recent_tool(true)
	elif _is_shape_family_source(source):
		target = _family_recent_tool(false)
	if target == &"" or not Tools.tools.has(String(target)):
		return
	if _current_left_tool_name() != target:
		Tools.assign_tool(String(target), MOUSE_BUTTON_LEFT)
		Tools.prev_tool_names[MOUSE_BUTTON_LEFT] = ""
	_refresh_taskbar.call_deferred()
	_refresh_config_panel.call_deferred()


func _on_family_tool_pressed(tool_name: StringName) -> void:
	if not active or not Tools.tools.has(String(tool_name)):
		return
	if _current_left_tool_name() != tool_name:
		Tools.assign_tool(String(tool_name), MOUSE_BUTTON_LEFT)
		Tools.prev_tool_names[MOUSE_BUTTON_LEFT] = ""
	_refresh_taskbar.call_deferred()
	_refresh_config_panel.call_deferred()


func _on_color_button_pressed() -> void:
	if not active:
		return
	if is_instance_valid(_palette_popup) and _palette_popup.visible:
		_palette_popup.visible = false
		return
	_place_popup_below(_palette_popup, _color_button, PALETTE_POPUP_SIZE)


func _refresh_config_panel() -> void:
	if (
		not active
		or not is_instance_valid(_options_popup)
		or not is_instance_valid(_options_host)
		or not is_instance_valid(_taskbar)
	):
		return
	var current := _current_left_tool_name()
	_tool_title.text = _tool_display_name(current)
	_refresh_family_row(current)
	_set_current_options_horizontal(true)
	_reparent_left_options(_options_host)

	var has_options := _has_left_tool_options()
	left_tool_options.custom_minimum_size = Vector2(OPTIONS_WIDTH - 20.0, 0.0)
	left_tool_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_tool_options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_tool_options.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	left_tool_options.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_tool_options.visible = has_options

	var body_height := 0.0
	if has_options:
		body_height = left_tool_options.get_combined_minimum_size().y
	var family_height := FAMILY_BUTTON_SIZE.y + 6.0 if _family_row.visible else 0.0
	var height := clampf(
		44.0 + family_height + body_height,
		OPTIONS_MIN_HEIGHT,
		OPTIONS_MAX_HEIGHT,
	)
	_place_popup_below(_options_popup, _taskbar, Vector2(OPTIONS_WIDTH, height))


func _refresh_family_row(current: StringName) -> void:
	for child in _family_row.get_children():
		child.queue_free()
	_family_buttons.clear()

	var family: Array[StringName] = []
	if current in SELECTION_TOOLS:
		family = SELECTION_TOOLS
	elif current in SHAPE_TOOLS:
		family = SHAPE_TOOLS
	_family_row.visible = not family.is_empty()
	if family.is_empty():
		return

	for tool_name in family:
		if not Tools.tools.has(String(tool_name)):
			continue
		var tool: Tools.Tool = Tools.tools[String(tool_name)]
		var button := Button.new()
		button.name = StringName("Family_" + String(tool_name))
		button.custom_minimum_size = FAMILY_BUTTON_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.flat = true
		button.toggle_mode = true
		button.expand_icon = true
		button.icon_max_width = int(FAMILY_BUTTON_SIZE.y - 8.0)
		button.icon = tool.icon
		button.tooltip_text = tr(tool.display_name)
		var selected := tool_name == current
		button.button_pressed = selected
		_apply_tool_button_highlight(button, selected)
		button.pressed.connect(_on_family_tool_pressed.bind(tool_name))
		_family_row.add_child(button)
		_family_buttons[tool_name] = button


func _tool_display_name(tool_name: StringName) -> String:
	var key := String(tool_name)
	if Tools.tools.has(key):
		var tool: Tools.Tool = Tools.tools[key]
		return tr(tool.display_name)
	return String(tool_name)


func _place_popup_below(popup: Control, anchor: Control, desired_size: Vector2) -> void:
	if popup == null or anchor == null:
		return
	popup.size = desired_size
	var global_target := (
		anchor.get_global_rect().end + Vector2(-desired_size.x, POPUP_GAP)
	)
	var local_target := ui_root.get_global_transform_with_canvas().affine_inverse() * global_target
	popup.position = Vector2(
		clampf(local_target.x, 0.0, maxf(0.0, ui_root.size.x - desired_size.x)),
		clampf(local_target.y, 0.0, maxf(0.0, ui_root.size.y - desired_size.y)),
	)
	popup.visible = true
	popup.move_to_front()


func _set_current_options_horizontal(enabled: bool) -> void:
	if not enabled:
		if is_instance_valid(_horizontalized_tool):
			_horizontalized_tool.set_horizontal_option_layout(false)
			_horizontalized_tool = null
		return
	var current := _current_tool_options()
	if current == null:
		return
	if is_instance_valid(_horizontalized_tool) and _horizontalized_tool != current:
		_horizontalized_tool.set_horizontal_option_layout(false)
	current.set_horizontal_option_layout(true)
	_horizontalized_tool = current


func _current_tool_options() -> BaseTool:
	if not is_instance_valid(left_tool_options):
		return null
	var panel := left_tool_options.get_node_or_null(^"LeftPanelContainer") as Control
	if panel == null or panel.get_child_count() == 0:
		return null
	return panel.get_child(panel.get_child_count() - 1) as BaseTool


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
		mini(int(_original_left_options_state.get("index", 0)), parent.get_child_count() - 1),
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
	if is_instance_valid(ui_root) and not ui_root.resized.is_connected(_on_workspace_resized):
		ui_root.resized.connect(_on_workspace_resized)


func _on_tool_changed(_tool_name: String, button: int) -> void:
	if not active or button != MOUSE_BUTTON_LEFT:
		return
	_last_active_tool = _current_left_tool_name()
	_refresh_taskbar.call_deferred()
	_refresh_config_panel.call_deferred()


func _on_color_changed(_color_info: Dictionary, button: int) -> void:
	if active and button == MOUSE_BUTTON_LEFT and is_instance_valid(_color_indicator):
		_color_indicator.queue_redraw()


func _on_context_changed() -> void:
	if active:
		_refresh_taskbar.call_deferred()
		_refresh_config_panel.call_deferred()


func _on_single_tool_mode_changed(_enabled: bool) -> void:
	if active:
		_refresh_taskbar.call_deferred()
		_refresh_config_panel.call_deferred()


func _on_workspace_resized() -> void:
	if active:
		_refresh_config_panel.call_deferred()
		if is_instance_valid(_palette_popup) and _palette_popup.visible:
			_place_popup_below(_palette_popup, _color_button, PALETTE_POPUP_SIZE)


func _refresh_taskbar() -> void:
	if not active or Global.headless_test_mode:
		return
	var current := _current_left_tool_name()
	for key in _toolbar_sources:
		var proxy := key as Button
		var source := _toolbar_sources[key] as BaseButton
		if not is_instance_valid(proxy) or not is_instance_valid(source):
			continue
		proxy.visible = source.visible
		proxy.icon = _source_icon(source)
		proxy.tooltip_text = source.tooltip_text
		var selected := _source_represents_tool(source, current)
		proxy.button_pressed = selected
		_apply_tool_button_highlight(proxy, selected)

	if is_instance_valid(_brush_button):
		var source := _source_button(BRUSH_TOOL)
		_brush_button.visible = source == null or source.visible
		var brush_selected := current == BRUSH_TOOL
		_brush_button.button_pressed = brush_selected
		_apply_tool_button_highlight(_brush_button, brush_selected)
	if is_instance_valid(_eraser_button):
		var source := _source_button(ERASER_TOOL)
		_eraser_button.visible = source == null or source.visible
		var eraser_selected := current == ERASER_TOOL
		_eraser_button.button_pressed = eraser_selected
		_apply_tool_button_highlight(_eraser_button, eraser_selected)
	if is_instance_valid(_color_indicator):
		_color_indicator.queue_redraw()


func _source_button(tool_name: StringName) -> BaseButton:
	if not Tools.tools.has(String(tool_name)):
		return null
	var tool: Tools.Tool = Tools.tools[String(tool_name)]
	return tool.button_node


func _apply_tool_button_highlight(button: BaseButton, selected: bool) -> void:
	if not is_instance_valid(button):
		return
	button.modulate = SELECTED_TOOL_TINT if selected else UNSELECTED_TOOL_TINT


func _source_represents_tool(source: BaseButton, active_tool: StringName) -> bool:
	if StringName(source.name) == active_tool:
		return true
	if _is_selection_family_source(source):
		return active_tool in SELECTION_TOOLS
	if _is_shape_family_source(source):
		return active_tool in SHAPE_TOOLS
	return false


func _is_selection_family_source(source: BaseButton) -> bool:
	if not is_instance_valid(_tool_buttons):
		return false
	var family := _tool_buttons.get("_ios_selection_family_button") as BaseButton
	return is_instance_valid(family) and source == family


func _is_shape_family_source(source: BaseButton) -> bool:
	if not is_instance_valid(_tool_buttons):
		return false
	var family := _tool_buttons.get("_ios_shape_family_button") as BaseButton
	return is_instance_valid(family) and source == family


func _family_recent_tool(selection_family: bool) -> StringName:
	if not is_instance_valid(_tool_buttons):
		return &""
	var property := "_ios_selection_recent_tool" if selection_family else "_ios_shape_recent_tool"
	var value := StringName(str(_tool_buttons.get(property)))
	if selection_family:
		return value if value in SELECTION_TOOLS else SELECTION_TOOLS[0]
	return value if value in SHAPE_TOOLS else SHAPE_TOOLS[0]


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
		center,
		radius + 2.0,
		0.0,
		TAU,
		32,
		Color(0.0, 0.0, 0.0, 0.7),
		1.0,
		true,
	)
