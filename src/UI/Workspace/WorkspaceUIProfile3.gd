class_name WorkspaceUIProfile3
extends Node

## Procreate-inspired presentation for UI profile 3.
##
## Profile 3 keeps the existing editor/tool state authoritative and only changes
## how it is presented: Preview defaults to the upper-left, standalone Tools and
## Palette workspace modules are parked, all first-level tools live in the top-right
## taskbar. The left strip is reserved for Pencil/Eraser size and opacity;
## tapping any top-right tool opens its complete Workspace tool options.

const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const Tokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")
const Chrome := preload("res://src/UI/DesignSystem/PhospriteStage2Chrome.gd")
const PixelStyle := preload("res://src/UI/DesignSystem/PhospritePixelStyle.gd")
const Stage3 := preload("res://src/UI/DesignSystem/PhospriteStage3Controls.gd")
const CLOSE_Q_ICON := preload("res://assets/graphics/q_icons/chrome/window_close.png")
const QIcons := preload("res://src/UI/DesignSystem/PhospriteQIcons.gd")
const Draw := preload("res://src/UI/DesignSystem/PhospriteDraw.gd")
const Stage4 := preload("res://src/UI/DesignSystem/PhospriteStage4Chrome.gd")

const BRUSH_TOOL := &"Pencil"
const ERASER_TOOL := &"Eraser"
const SELECTION_TOOLBAR_REP := &"RectSelect"
const SHAPE_TOOLBAR_REP := &"LineTool"
const IOS_REMOVED_TOOLS: Array[StringName] = [&"Text", &"Zoom", &"Pan", &"Shading"]
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
const FAMILY_BUTTON_SIZE := Vector2(34.0, 32.0)
const POPUP_GAP := 6.0
const PALETTE_POPUP_SIZE := Vector2(320.0, 460.0)
const PREVIEW_MARGIN := Vector2(124.0, 8.0)
const QUICK_BAR_X := 8.0
const QUICK_BAR_MIN_Y := 68.0
const QUICK_BAR_WIDTH := 100.0
const QUICK_MARGIN := 8.0
const QUICK_CLEARANCE := 8.0
const QUICK_EXCLUSION_ID := &"ui3.quick_controls"
const QUICK_MIN_VISIBLE_HEIGHT := 104.0
const QUICK_SLIDER_HEIGHT := 106.0
const PALETTE_HEADER_HEIGHT := 36.0
const TOOL_OPTIONS_MARGIN := Vector2(8.0, 8.0)
const OPTIONS_CONTENT_PADDING := Vector2(22.0, 72.0)
const OPTIONS_MAX_VIEWPORT_RATIO := 0.82
const SELECTED_TOOL_TINT := Color(0.45, 0.78, 1.0, 1.0)
const UNSELECTED_TOOL_TINT := Color.WHITE

static var _ui3_panel_cache: Dictionary = {}
static var _ui3_slider_cache: Dictionary = {}

var ui_root: Control
var left_tool_options: ScrollContainer
var surface: WorkspaceSurface

var active := false

var _tool_buttons: Node
var _taskbar: HBoxContainer
var _taskbar_island: PanelContainer
var _taskbar_scroller: ScrollContainer
var _brush_button: Button
var _eraser_button: Button
var _color_button: Button
var _color_indicator: Control
var _toolbar_sources: Dictionary = {}

var _quick_bar: PanelContainer
var _quick_title: Label
var _quick_scroll: ScrollContainer
var _quick_controls: VBoxContainer
var _quick_bindings: Array[Dictionary] = []
var _quick_has_controls := false
var _quick_pixel_mode: StringName = Tokens.LEGACY
var _quick_swatch_left: Button
var _quick_swatch_right: Button
var _quick_hud: PanelContainer
var _quick_hud_label: Label
var _quick_hud_preview: Control
var _quick_hud_value := 1.0
var _quick_hud_size_mode := false
var _quick_hud_generation := 0
var _quick_slider_dragging := false
var _advanced_open := false

var _options_module: WorkspaceModule
var _family_row: HFlowContainer
var _family_buttons: Dictionary = {}
var _options_separator: HSeparator
var _options_host: MarginContainer
var _options_last_rect := Rect2()
var _options_resizing := false
var _options_size_source: BaseTool

var _palette_popup: PanelContainer
var _palette_content: Control
var _palette_header: PanelContainer
var _palette_header_label: Label
var _palette_close_button: Button
var _palette_pinned := false
var _palette_dragging := false
var _palette_drag_origin := Vector2.ZERO
var _palette_drag_start := Vector2.ZERO
var _palette_drag_touch_index := -1
var _palette_last_touch_msec := -1000

var _original_left_options_state: Dictionary = {}
var _compacted_tool: BaseTool
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
	set_process_input(true)
	# The quick bar is made visible by the selected tool only after its
	# safe placement and size have been calculated.
	# Keep tool nodes mounted and active while the optional full panel is hidden.
	if not _advanced_open and not surface.is_module_parked(Builtins.UI3_TOOL_OPTIONS_ID):
		if not _ensure_options_module_placement():
			return false
		_hide_advanced_panel()
	elif _advanced_open and not _ensure_options_module_placement():
		return false
	_set_ui3_module_chrome_visible(false)
	_last_active_tool = _current_left_tool_name()
	_refresh_taskbar()
	_refresh_config_panel()
	_refresh_stage3_visuals()
	return true


func deactivate() -> void:
	active = false
	set_process_input(false)
	if Global.headless_test_mode:
		return
	if is_instance_valid(_palette_popup):
		_palette_popup.visible = false
	_palette_pinned = false
	_palette_dragging = false
	_hide_quick_hud()
	_hide_advanced_panel()
	_disconnect_options_size_source()
	_advanced_open = false
	_set_ui3_module_chrome_visible(true)
	_set_current_options_compact(false)
	_clear_quick_bindings()
	if is_instance_valid(_quick_bar):
		_quick_bar.visible = false
	_set_quick_reservation(Rect2())
	_restore_left_tool_options()
	if surface != null and surface.manager.has_instance(Builtins.UI3_TOOL_OPTIONS_ID):
		surface.park_module(Builtins.UI3_TOOL_OPTIONS_ID)
	if is_instance_valid(_taskbar):
		_taskbar.visible = false
	if is_instance_valid(_taskbar_island):
		_taskbar_island.visible = false


func refresh_after_tools_ready() -> bool:
	if not active:
		return true
	return activate()


func _set_ui3_module_chrome_visible(visible: bool) -> void:
	if surface == null or surface.manager == null:
		return
	for module_id in [Builtins.TOOLS_ID, Builtins.PALETTE_ID, Builtins.UI3_TOOL_OPTIONS_ID]:
		var module := surface.manager.get_instance(module_id)
		if module != null:
			# The optional settings window keeps its own drag header; tool
			# palette overlays stay chrome-free in the Procreate profile.
			module.set_header_chrome_visible(visible or module_id == Builtins.UI3_TOOL_OPTIONS_ID)


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
		if current.has_area() and current.size.y >= 180.0 and current.size.x >= 260.0:
			size = current.size
	var bounds := surface.get_floating_bounds()
	var margin := (
		Vector2(72.0, PREVIEW_MARGIN.y) if Chrome.active_mode() != Tokens.LEGACY else PREVIEW_MARGIN
	)
	var target := Rect2(bounds.position + margin, size)
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
	if not _ensure_options_module():
		return false
	if not _create_palette_popup():
		return false
	if not _create_quick_bar():
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

	# Only pixel-themed UI3 shows the right panel island. The scroll host
	# protects the 590pt split viewport without dropping source tool actions.
	_taskbar_island = PanelContainer.new()
	_taskbar_island.name = &"UI3TopRightIsland"
	_taskbar_island.visible = false
	_taskbar_island.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_taskbar_island)
	_taskbar_scroller = ScrollContainer.new()
	_taskbar_scroller.name = &"UI3TopRightScroller"
	_taskbar_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_taskbar_scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_taskbar_scroller.custom_minimum_size = Vector2(120.0, TASK_BUTTON_SIZE.y)
	_taskbar_scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_taskbar_scroller.mouse_filter = Control.MOUSE_FILTER_PASS
	_taskbar_island.add_child(_taskbar_scroller)
	return true


func _build_toolbar_tools() -> bool:
	if not is_instance_valid(_tool_buttons) or not is_instance_valid(_taskbar):
		return false
	for child in _tool_buttons.get_children():
		var source := child as BaseButton
		if source == null:
			continue
		var tool_name := StringName(source.name)
		if (
			is_primary_tool(tool_name)
			or tool_name in IOS_REMOVED_TOOLS
			or (tool_name in SELECTION_TOOLS and tool_name != SELECTION_TOOLBAR_REP)
			or (tool_name in SHAPE_TOOLS and tool_name != SHAPE_TOOLBAR_REP)
		):
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
	_color_indicator.draw.connect(_draw_color_indicator)
	_color_button.add_child(_color_indicator)
	_color_indicator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_brush_button = _make_primary_button(BRUSH_TOOL, "Brush")
	_eraser_button = _make_primary_button(ERASER_TOOL, "Eraser")
	_taskbar.add_child(_brush_button)
	_taskbar.add_child(_eraser_button)
	_taskbar.add_child(_color_button)
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
	if Tools.tools.has(String(tool_name)):
		var tool: Tools.Tool = Tools.tools[String(tool_name)]
		button.icon = tool.icon
	button.pressed.connect(_on_primary_button_pressed.bind(tool_name))
	return button


func _ensure_options_module() -> bool:
	if surface == null or surface.manager == null:
		return false
	_options_module = surface.manager.get_instance(Builtins.UI3_TOOL_OPTIONS_ID)
	if not is_instance_valid(_options_module):
		_options_module = surface.manager.create_module(Builtins.UI3_TOOL_OPTIONS_ID)
	if not is_instance_valid(_options_module):
		return false
	# This popup uses the existing tool controls, with content-driven size.
	# Do not inherit the narrow UI1 tool-column padding.
	_options_module.set_horizontal_content_padding_override(0)
	var content := _options_module.get_content()
	if not is_instance_valid(content):
		return false
	_family_row = content.get_node_or_null(^"FamilyChooser") as HFlowContainer
	_options_separator = content.get_node_or_null(^"OptionsSeparator") as HSeparator
	_options_host = content.get_node_or_null(^"OptionsHost") as MarginContainer
	return (
		is_instance_valid(_family_row)
		and is_instance_valid(_options_separator)
		and is_instance_valid(_options_host)
	)


func _ensure_options_module_placement() -> bool:
	if not _ensure_options_module():
		return false
	var placement := surface.get_module_placement(Builtins.UI3_TOOL_OPTIONS_ID)
	# Unfold saved UI3 windows before removing their titlebar and collapse control.
	if placement == WorkspaceSurface.Placement.COLLAPSED:
		if not surface.restore_module(Builtins.UI3_TOOL_OPTIONS_ID):
			return false
		placement = surface.get_module_placement(Builtins.UI3_TOOL_OPTIONS_ID)
	if placement == WorkspaceSurface.Placement.FLOATING:
		var definition := surface.manager.get_definition(Builtins.UI3_TOOL_OPTIONS_ID)
		if definition == null:
			return false
		var current_rect := surface.get_floating_rect(Builtins.UI3_TOOL_OPTIONS_ID)
		var constrained_size := definition.get_constrained_size(current_rect.size)
		if constrained_size != current_rect.size:
			current_rect.size = constrained_size
			return surface.set_floating_rect(Builtins.UI3_TOOL_OPTIONS_ID, current_rect)
		return true
	if placement == WorkspaceSurface.Placement.DOCKED:
		return true
	var rect := _options_last_rect
	if not rect.has_area():
		var definition := surface.manager.get_definition(Builtins.UI3_TOOL_OPTIONS_ID)
		if definition == null:
			return false
		var size := definition.get_constrained_preferred_size()
		var bounds := surface.get_floating_bounds()
		rect = Rect2(
			Vector2(
				bounds.end.x - size.x - TOOL_OPTIONS_MARGIN.x,
				bounds.position.y + TOOL_OPTIONS_MARGIN.y
			),
			size,
		)
	return surface.float_module(Builtins.UI3_TOOL_OPTIONS_ID, rect)


func _capture_options_module_state() -> void:
	if surface == null:
		return
	var placement := surface.get_module_placement(Builtins.UI3_TOOL_OPTIONS_ID)
	if placement == WorkspaceSurface.Placement.FLOATING:
		_options_last_rect = surface.get_floating_rect(Builtins.UI3_TOOL_OPTIONS_ID)
	elif placement == WorkspaceSurface.Placement.COLLAPSED:
		var restore := surface.get_restore_state(Builtins.UI3_TOOL_OPTIONS_ID)
		if (
			int(restore.get("placement", WorkspaceSurface.Placement.NONE))
			== WorkspaceSurface.Placement.FLOATING
		):
			_options_last_rect = restore.get("rect", Rect2()) as Rect2


func _create_palette_popup() -> bool:
	var content := Builtins.PALETTE_SCENE.instantiate()
	if not content is Control:
		if content != null:
			content.free()
		return false

	_palette_popup = PanelContainer.new()
	_palette_popup.name = &"UIProfile3PalettePopup"
	_palette_popup.add_to_group(&"phosprite_ui3_palette_popup")
	_palette_popup.visible = false
	_palette_popup.z_index = 1001
	_palette_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_palette_popup.custom_minimum_size = PALETTE_POPUP_SIZE
	ui_root.add_child(_palette_popup)

	# The actual Palette & Color scene is reused. Only its presentation gains
	# an optional 36px drag header in the two Phosprite themes.
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override(&"separation", 0)
	_palette_popup.add_child(stack)
	_palette_header = PanelContainer.new()
	_palette_header.name = &"UI3PaletteTearOffHeader"
	_palette_header.custom_minimum_size.y = PALETTE_HEADER_HEIGHT
	_palette_header.mouse_filter = Control.MOUSE_FILTER_STOP
	_palette_header.gui_input.connect(_on_palette_header_input)
	stack.add_child(_palette_header)
	var hdr_margin := MarginContainer.new()
	hdr_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_margin.add_theme_constant_override(&"margin_left", 8)
	hdr_margin.add_theme_constant_override(&"margin_right", 6)
	hdr_margin.add_theme_constant_override(&"margin_top", 2)
	hdr_margin.add_theme_constant_override(&"margin_bottom", 2)
	_palette_header.add_child(hdr_margin)
	var heading_row := HBoxContainer.new()
	heading_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_margin.add_child(heading_row)
	_palette_header_label = Label.new()
	_palette_header_label.text = tr("Palette & Color")
	_palette_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_palette_header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_palette_header_label.add_theme_font_size_override(&"font_size", 12)
	_palette_header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading_row.add_child(_palette_header_label)
	_palette_close_button = Button.new()
	_palette_close_button.name = &"ClosePinnedPalette"
	var close_image := CLOSE_Q_ICON.get_image().get_region(Rect2i(2, 2, 12, 12))
	close_image.resize(16, 16, Image.INTERPOLATE_NEAREST)
	_palette_close_button.icon = ImageTexture.create_from_image(close_image)
	_palette_close_button.expand_icon = false
	_palette_close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_palette_close_button.tooltip_text = tr("Close")
	_palette_close_button.custom_minimum_size = Vector2(24.0, 24.0)
	_palette_close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_palette_close_button.pressed.connect(_close_palette_popup)
	heading_row.add_child(_palette_close_button)

	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override(&"margin_left", 8)
	margin.add_theme_constant_override(&"margin_top", 8)
	margin.add_theme_constant_override(&"margin_right", 8)
	margin.add_theme_constant_override(&"margin_bottom", 8)
	stack.add_child(margin)
	_palette_content = content as Control
	_palette_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_palette_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_palette_content)
	_palette_header.visible = false
	return true


## Tear-off windows obey the same fixed-capsule exclusion as Preview.
## Moving the color card must never move the left capsule out of position.
func _constrain_stage3_palette_position(position: Vector2) -> Vector2:
	if not is_instance_valid(_palette_popup) or not is_instance_valid(_quick_bar):
		return position
	if not _quick_bar.visible or not _quick_bar.get_rect().has_area():
		return position
	var target := Rect2(position, _palette_popup.size)
	var exclusion := _quick_bar.get_global_rect().grow(QUICK_CLEARANCE)
	var parent_transform := ui_root.get_global_transform_with_canvas().affine_inverse()
	var bounds := Rect2(parent_transform * exclusion.position, exclusion.size)
	if not target.intersects(bounds):
		return position
	var clear_x := bounds.end.x
	if clear_x + target.size.x <= ui_root.size.x:
		return Vector2(clear_x, position.y)
	return position


func _source_icon(source: BaseButton) -> Texture2D:
	if Chrome.active_mode() != Tokens.LEGACY:
		var q_tex := QIcons.tool_icon_1x(StringName(source.name))
		if q_tex != null:
			return q_tex
	var icon_node := source.get_node_or_null(^"ToolIcon") as TextureRect
	if icon_node != null:
		return icon_node.texture
	var name := String(source.name)
	if Tools.tools.has(name):
		var tool: Tools.Tool = Tools.tools[name]
		return tool.icon
	return null


func _on_primary_button_pressed(tool_name: StringName) -> void:
	_select_tool_and_toggle_options(tool_name)


func _on_toolbar_tool_pressed(_proxy: BaseButton, source: BaseButton) -> void:
	if not active or not is_instance_valid(source):
		return
	var target := StringName(source.name)
	var selection_family := _is_selection_family_source(source)
	var shape_family := _is_shape_family_source(source)
	if selection_family:
		target = _family_recent_tool(true)
	elif shape_family:
		target = _family_recent_tool(false)
	# Folded icons toggle their actual tool chooser only when already selected.
	# Other icons keep the existing tool-settings toggle behavior.
	if (
		(selection_family or shape_family)
		and _source_represents_tool(source, _current_left_tool_name())
		and is_instance_valid(_tool_buttons)
	):
		_tool_buttons.call("toggle_ios_family_menu", selection_family, _proxy)
		_refresh_taskbar.call_deferred()
		return
	_select_tool_and_toggle_options(target)


## The top-right tool icon is the only entry into complete tool settings.
## Selecting a different tool opens its settings; tapping the selected icon
## again closes them. This leaves the canvas clear when settings are not needed.
func _select_tool_and_toggle_options(tool_name: StringName) -> void:
	if not active or not Tools.tools.has(String(tool_name)):
		return
	var already_selected := _current_left_tool_name() == tool_name
	if not already_selected:
		Tools.assign_tool(String(tool_name), MOUSE_BUTTON_LEFT)
		Tools.prev_tool_names[MOUSE_BUTTON_LEFT] = ""
		if not is_primary_tool(tool_name) and is_instance_valid(_quick_bar):
			_quick_bar.visible = false
	_refresh_taskbar.call_deferred()
	_refresh_config_panel.call_deferred()
	if already_selected and _advanced_open:
		_hide_advanced_panel()
	else:
		# Refresh the original BaseTool controls first, then show their panel.
		_show_advanced_panel.call_deferred()


func _on_family_tool_pressed(tool_name: StringName) -> void:
	if not active or not Tools.tools.has(String(tool_name)):
		return
	if _current_left_tool_name() != tool_name:
		Tools.assign_tool(String(tool_name), MOUSE_BUTTON_LEFT)
		Tools.prev_tool_names[MOUSE_BUTTON_LEFT] = ""
	_refresh_taskbar.call_deferred()
	_refresh_config_panel.call_deferred()


func _on_color_button_pressed() -> void:
	if not active or not is_instance_valid(_palette_popup):
		return
	if _palette_popup.visible:
		if _palette_pinned:
			_palette_popup.move_to_front()
		else:
			_palette_popup.visible = false
		return
	_palette_pinned = false
	_update_palette_pin_visual()
	_place_popup_below(_palette_popup, _color_button, PALETTE_POPUP_SIZE)


func _close_palette_popup() -> void:
	_palette_pinned = false
	_palette_dragging = false
	if is_instance_valid(_palette_popup):
		_palette_popup.visible = false
	_update_palette_pin_visual()


func _update_palette_pin_visual() -> void:
	if not is_instance_valid(_palette_header):
		return
	var pixel := _quick_pixel_mode != Tokens.LEGACY
	_palette_header.visible = pixel
	_palette_close_button.visible = pixel and _palette_pinned
	_palette_header_label.text = tr("Palette & Color")


## The header is a grip, not a second color editor. Holding and dragging
## >=24px converts a temporary popup to an independent movable window.
## Source color values and palette selections remain on the original scene.
func _on_palette_header_input(event: InputEvent) -> void:
	if not active or _quick_pixel_mode == Tokens.LEGACY:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_palette_last_touch_msec = Time.get_ticks_msec()
		if touch.pressed and not _palette_dragging:
			_begin_palette_drag(_palette_header.get_global_transform_with_canvas() * touch.position)
			_palette_drag_touch_index = touch.index
		elif not touch.pressed and _palette_drag_touch_index == touch.index:
			_palette_dragging = false
			_palette_drag_touch_index = -1
		_palette_header.accept_event()
	elif event is InputEventScreenDrag and _palette_dragging:
		var drag := event as InputEventScreenDrag
		if drag.index != _palette_drag_touch_index:
			return
		_move_palette_drag(_palette_header.get_global_transform_with_canvas() * drag.position)
		_palette_header.accept_event()
	elif event is InputEventMouseButton:
		if Time.get_ticks_msec() - _palette_last_touch_msec < 500:
			return
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_begin_palette_drag(_palette_header.get_global_transform_with_canvas() * mouse.position)
		else:
			_palette_dragging = false
		_palette_header.accept_event()
	elif event is InputEventMouseMotion and _palette_dragging and _palette_drag_touch_index < 0:
		var motion := event as InputEventMouseMotion
		_move_palette_drag(_palette_header.get_global_transform_with_canvas() * motion.position)
		_palette_header.accept_event()


func _begin_palette_drag(pointer: Vector2) -> void:
	if not is_instance_valid(_palette_popup):
		return
	_palette_dragging = true
	_palette_drag_origin = _palette_popup.position
	_palette_drag_start = pointer


func _move_palette_drag(pointer: Vector2) -> void:
	if not _palette_dragging or not is_instance_valid(_palette_popup):
		return
	var delta := pointer - _palette_drag_start
	if not _palette_pinned and not Stage3.should_pin_popup(delta):
		return
	if not _palette_pinned:
		_palette_pinned = true
		_update_palette_pin_visual()
	_palette_popup.position = _constrain_stage3_palette_position(
		Stage3.popup_position(_palette_drag_origin, delta, _palette_popup.size, ui_root.size)
	)
	_palette_popup.move_to_front()


func _refresh_config_panel() -> void:
	if not active or not _ensure_options_module() or not is_instance_valid(_options_host):
		return
	var current := _current_left_tool_name()
	_options_module.set_header_title_override(
		"%s · %s" % [tr("Tool Options"), _tool_display_name(current)]
	)
	_refresh_family_row(current)
	_set_current_options_compact(false)
	_reparent_left_options(_options_host)

	var has_options := _has_left_tool_options()
	left_tool_options.custom_minimum_size = Vector2.ZERO
	left_tool_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_tool_options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_tool_options.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_tool_options.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	left_tool_options.visible = has_options
	_options_host.visible = has_options
	_options_separator.visible = _family_row.visible and has_options
	_bind_options_size_source()
	if _advanced_open:
		_resize_advanced_to_content.call_deferred()
	_refresh_quick_bar(current)


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
		var pixel_mode := Chrome.active_mode()
		button.flat = pixel_mode == Tokens.LEGACY
		button.toggle_mode = true
		var q_tex := QIcons.tool_icon_1x(tool_name) if pixel_mode != Tokens.LEGACY else null
		button.expand_icon = q_tex == null
		button.icon = q_tex if q_tex != null else tool.icon
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
	var global_target := anchor.get_global_rect().end + Vector2(-desired_size.x, POPUP_GAP)
	var local_target := ui_root.get_global_transform_with_canvas().affine_inverse() * global_target
	popup.position = Vector2(
		clampf(local_target.x, 0.0, maxf(0.0, ui_root.size.x - desired_size.x)),
		clampf(local_target.y, 0.0, maxf(0.0, ui_root.size.y - desired_size.y)),
	)
	popup.visible = true
	popup.move_to_front()


## UI3 is a view over existing tool options, not a second set of preferences.
## The original BaseDrawTool/selection nodes continue to save their own values.
func _create_quick_bar() -> bool:
	if ui_root == null:
		return false
	_quick_bar = PanelContainer.new()
	_quick_bar.name = &"UIProfile3QuickControls"
	_quick_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_quick_bar.visible = false
	_quick_bar.custom_minimum_size = Vector2(QUICK_BAR_WIDTH, 0.0)
	# Keep docked Timeline and floating Workspace modules above the quick
	# strip. A high z_index on the quick strip previously hid advanced options.
	var parent: Control = ui_root
	if surface != null and is_instance_valid(surface.dock_host):
		parent = surface.dock_host
	parent.add_child(_quick_bar)
	if surface != null and parent == surface.dock_host:
		var floating_layer := surface.get_floating_layer()
		if is_instance_valid(floating_layer):
			parent.move_child(_quick_bar, floating_layer.get_index())

	var padding := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		padding.add_theme_constant_override(StringName("margin_" + side), 6)
	_quick_bar.add_child(padding)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	padding.add_child(column)
	_quick_title = Label.new()
	_quick_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quick_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_quick_title)
	_quick_scroll = ScrollContainer.new()
	_quick_scroll.name = &"QuickOptionsScroll"
	_quick_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_quick_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_quick_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quick_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_quick_scroll)
	_quick_controls = VBoxContainer.new()
	_quick_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quick_controls.add_theme_constant_override(&"separation", 8)
	_quick_scroll.add_child(_quick_controls)

	# HUD is not a floating Workspace window. It is a noninteractive paint
	# overlay beside the fixed capsule and never takes over a pointer gesture.
	_quick_hud = PanelContainer.new()
	_quick_hud.name = &"UI3BrushPixelHUD"
	_quick_hud.visible = false
	_quick_hud.z_index = 10
	_quick_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quick_hud.custom_minimum_size = Vector2(124.0, 112.0)
	parent.add_child(_quick_hud)
	if surface != null and parent == surface.dock_host:
		var overlay := surface.get_floating_layer()
		if is_instance_valid(overlay):
			parent.move_child(_quick_hud, overlay.get_index())
	var hud_column := VBoxContainer.new()
	hud_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_column.add_theme_constant_override(&"separation", 2)
	_quick_hud.add_child(hud_column)
	_quick_hud_label = Label.new()
	_quick_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quick_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quick_hud_label.add_theme_font_size_override(&"font_size", 20)
	hud_column.add_child(_quick_hud_label)
	_quick_hud_preview = Control.new()
	_quick_hud_preview.custom_minimum_size = Vector2(76, 64)
	_quick_hud_preview.clip_contents = true
	_quick_hud_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quick_hud_preview.draw.connect(_draw_quick_hud_preview)
	hud_column.add_child(_quick_hud_preview)
	return true


## The Workspace content rect excludes the docked Timeline, including
## project-specific Timeline height changes. The quick strip lives in host
## coordinates, not in the full-screen UI root's coordinates.
func _quick_safe_bounds() -> Rect2:
	if not is_instance_valid(_quick_bar):
		return Rect2()
	var parent := _quick_bar.get_parent() as Control
	if parent == null:
		return Rect2()
	if surface != null and parent == surface.dock_host:
		return surface.dock_host.get_content_rect()
	return Rect2(Vector2.ZERO, parent.size)


## Always anchor the Pencil/Eraser strip at its own left-side position.
## Floating Workspace windows must avoid this area; they never move the strip.
static func find_quick_rect(bounds: Rect2, desired_size: Vector2) -> Rect2:
	if not bounds.has_area():
		return Rect2()
	var position := Vector2(
		maxf(bounds.position.x + QUICK_MARGIN, QUICK_BAR_X),
		maxf(bounds.position.y + QUICK_MARGIN, QUICK_BAR_MIN_Y)
	)
	var available := bounds.end - position - Vector2.ONE * QUICK_MARGIN
	var size := Vector2(
		minf(desired_size.x, maxf(0.0, available.x)), minf(desired_size.y, maxf(0.0, available.y))
	)
	if size.x <= 0.0 or size.y <= 0.0:
		return Rect2()
	return Rect2(position, size)


func _set_quick_reservation(rect: Rect2) -> void:
	if surface == null:
		return
	# Workspace rectangles use DockHost-local coordinates, as does the bar.
	surface.set_floating_exclusion_rect(
		QUICK_EXCLUSION_ID, rect.grow(QUICK_CLEARANCE) if rect.has_area() else Rect2()
	)


func _place_quick_bar() -> void:
	if not is_instance_valid(_quick_bar) or not is_instance_valid(_quick_controls):
		return
	if not active or not _quick_has_controls:
		_quick_bar.visible = false
		_set_quick_reservation(Rect2())
		return
	var bounds := _quick_safe_bounds()
	if not bounds.has_area():
		_quick_bar.visible = false
		_set_quick_reservation(Rect2())
		return
	var title_height := (
		_quick_title.get_combined_minimum_size().y + 6.0 if _quick_title.visible else 0.0
	)
	var natural_height := (
		_quick_controls.get_combined_minimum_size().y
		+ title_height
		+ (22.0 if _quick_pixel_mode != Tokens.LEGACY else 24.0)
	)
	var requested_width := (
		Stage3.CAPSULE_WIDTH if _quick_pixel_mode != Tokens.LEGACY else QUICK_BAR_WIDTH
	)
	var desired := Vector2(requested_width, maxf(QUICK_MIN_VISIBLE_HEIGHT, natural_height))
	var rect := find_quick_rect(bounds, desired)
	if not rect.has_area() or rect.size.y < QUICK_MIN_VISIBLE_HEIGHT:
		_quick_bar.visible = false
		_set_quick_reservation(Rect2())
		return
	_quick_bar.position = rect.position
	_quick_bar.size = rect.size
	_quick_bar.visible = true
	if is_instance_valid(_quick_hud) and _quick_hud.visible:
		_position_quick_hud()
	_set_quick_reservation(rect)


func _clear_quick_bindings() -> void:
	for binding in _quick_bindings:
		var source := binding.get("source") as Range
		var callback := binding.get("callback") as Callable
		if is_instance_valid(source) and source.value_changed.is_connected(callback):
			source.value_changed.disconnect(callback)
	_quick_bindings.clear()
	_quick_swatch_left = null
	_quick_swatch_right = null
	_hide_quick_hud()
	if is_instance_valid(_quick_controls):
		for child in _quick_controls.get_children():
			_quick_controls.remove_child(child)
			child.queue_free()


func _refresh_quick_bar(tool_name: StringName) -> void:
	if not is_instance_valid(_quick_controls):
		return
	_clear_quick_bindings()
	_quick_has_controls = false
	_quick_bar.visible = false
	if not is_primary_tool(tool_name):
		_set_quick_reservation(Rect2())
		return
	_quick_pixel_mode = Chrome.active_mode()
	var pixel_theme := _quick_pixel_mode != Tokens.LEGACY
	_quick_title.text = _tool_display_name(tool_name)
	_quick_title.visible = not pixel_theme
	var tool := _current_tool_options()
	if tool == null:
		return
	if pixel_theme:
		_add_stage3_quick_slider(tool, ^"Brush/BrushSize", tr("Size"), true)
		_add_stage3_color_swatches()
		_add_stage3_quick_slider(
			tool, ^"Opacity" if tool_name == BRUSH_TOOL else ^"OpacitySlider", tr("Opacity"), false
		)
	else:
		_add_quick_slider(tool, ^"Brush/BrushSize", tr("Size"), true)
		_add_quick_slider(
			tool, ^"Opacity" if tool_name == BRUSH_TOOL else ^"OpacitySlider", tr("Opacity"), false
		)
	_quick_has_controls = _quick_controls.get_child_count() > 0
	_place_quick_bar()
	# Tool option controls can finish sizing on the next layout frame.
	_place_quick_bar.call_deferred()


func _add_quick_slider(tool: BaseTool, path: NodePath, title: String, size_value: bool) -> void:
	var source := tool.get_node_or_null(path) as Range
	if source == null:
		return
	var group := VBoxContainer.new()
	group.add_theme_constant_override(&"separation", 2)
	_quick_controls.add_child(group)
	var caption := Label.new()
	caption.text = title
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	group.add_child(caption)
	var slider := VSlider.new()
	slider.custom_minimum_size = Vector2(44.0, QUICK_SLIDER_HEIGHT)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slider.min_value = source.min_value
	# Image brushes use a percentage convention; keep that tool's real unit.
	slider.max_value = maxf(source.max_value, 256.0 if size_value else 100.0)
	slider.step = maxf(source.step, 1.0)
	slider.value = source.value
	group.add_child(slider)
	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	group.add_child(value_label)
	var suffix := "px" if size_value else "%"
	if size_value and tool is BaseDrawTool:
		suffix = str((source as ValueSlider).suffix) if source is ValueSlider else "px"
	_update_quick_value_label(value_label, source.value, suffix)
	slider.value_changed.connect(_on_quick_slider_changed.bind(source))
	var callback := _on_quick_source_value_changed.bind(slider, value_label, suffix)
	source.value_changed.connect(callback)
	_quick_bindings.append({"source": source, "callback": callback})


## Only the opt-in Phosprite themes use the two-zone touch response.
## The user-visible slider is a proxy; the existing ValueSlider still owns
## configuration, persistence, redraw and tool-specific unit conversions.
func _add_stage3_quick_slider(tool: BaseTool, path: NodePath, title: String, is_size: bool) -> void:
	var source := tool.get_node_or_null(path) as Range
	if source == null:
		return
	var group := VBoxContainer.new()
	group.add_theme_constant_override(&"separation", 2)
	_quick_controls.add_child(group)
	var caption := Label.new()
	caption.text = title
	caption.tooltip_text = title
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override(&"font_size", 9)
	caption.add_theme_color_override(&"font_color", Tokens.color(_quick_pixel_mode, &"text_muted"))
	group.add_child(caption)
	var slider := VSlider.new()
	slider.name = StringName("CapsuleSize" if is_size else "CapsuleOpacity")
	slider.custom_minimum_size = Vector2(Stage3.TRACK_WIDTH, Stage3.TRACK_HEIGHT)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_stage3_vslider(slider, _quick_pixel_mode)
	group.add_child(slider)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", 10)
	label.add_theme_color_override(&"font_color", Tokens.color(_quick_pixel_mode, &"text_primary"))
	group.add_child(label)
	var suffix := "px" if is_size else "%"
	if is_size and source is ValueSlider:
		suffix = str((source as ValueSlider).suffix)
	var curve := (
		is_size
		and Stage3.supports_pixel_size_mapping(
			source.min_value, source.max_value, source.step, suffix
		)
	)
	if curve:
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.001
		slider.set_value_no_signal(
			Stage3.position_from_size(source.value, source.min_value, source.max_value)
		)
	else:
		slider.min_value = source.min_value
		slider.max_value = source.max_value
		slider.step = maxf(source.step, 0.001)
		slider.set_value_no_signal(source.value)
	_update_quick_value_label(label, source.value, suffix)
	slider.value_changed.connect(_on_stage3_slider_changed.bind(source, curve, is_size, suffix))
	slider.drag_started.connect(_on_stage3_slider_drag_started.bind(source, is_size, suffix))
	slider.drag_ended.connect(_on_stage3_slider_drag_ended)
	var callback := _on_stage3_source_value_changed.bind(
		slider, label, suffix, curve, source, is_size
	)
	source.value_changed.connect(callback)
	_quick_bindings.append({"source": source, "callback": callback})


func _on_stage3_slider_changed(
	value: float, source: Range, curve: bool, is_size: bool, suffix: String
) -> void:
	if not is_instance_valid(source):
		return
	source.value = (
		Stage3.size_from_position(value, source.min_value, source.max_value) if curve else value
	)
	if _quick_slider_dragging:
		_show_quick_hud(source.value, is_size, suffix)


func _on_stage3_source_value_changed(
	value: float,
	slider: VSlider,
	label: Label,
	suffix: String,
	curve: bool,
	source: Range,
	is_size: bool
) -> void:
	if not is_instance_valid(slider) or not is_instance_valid(label):
		return
	if curve and is_instance_valid(source):
		slider.set_value_no_signal(
			Stage3.position_from_size(value, source.min_value, source.max_value)
		)
	else:
		slider.set_value_no_signal(value)
	_update_quick_value_label(label, value, suffix)
	if _quick_slider_dragging:
		_show_quick_hud(value, is_size, suffix)


func _add_stage3_color_swatches() -> void:
	var spacer := MarginContainer.new()
	spacer.add_theme_constant_override(&"margin_top", 2)
	spacer.add_theme_constant_override(&"margin_bottom", 2)
	spacer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_quick_controls.add_child(spacer)
	var overlap := Control.new()
	overlap.name = &"UI3ColorOverlap"
	overlap.custom_minimum_size = Vector2(32.0, 28.0)
	overlap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	spacer.add_child(overlap)
	_quick_swatch_right = Button.new()
	_quick_swatch_right.name = &"SecondaryColor"
	_quick_swatch_right.position = Vector2(11, 0)
	_quick_swatch_right.custom_minimum_size = Vector2(20, 20)
	_quick_swatch_right.focus_mode = Control.FOCUS_NONE
	_quick_swatch_right.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_quick_swatch_right.tooltip_text = tr("Swap Colors")
	_quick_swatch_right.pressed.connect(_on_stage3_swap_colors)
	overlap.add_child(_quick_swatch_right)
	_quick_swatch_left = Button.new()
	_quick_swatch_left.name = &"PrimaryColor"
	_quick_swatch_left.position = Vector2(1, 7)
	_quick_swatch_left.custom_minimum_size = Vector2(20, 20)
	_quick_swatch_left.focus_mode = Control.FOCUS_NONE
	_quick_swatch_left.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_quick_swatch_left.tooltip_text = tr("Swap Colors")
	_quick_swatch_left.pressed.connect(_on_stage3_swap_colors)
	overlap.add_child(_quick_swatch_left)
	_update_stage3_swatches()


func _on_stage3_swap_colors() -> void:
	Tools.swap_color()
	_update_stage3_swatches()


func _update_stage3_swatches() -> void:
	if _quick_pixel_mode == Tokens.LEGACY:
		return
	for pair in [
		{"button": _quick_swatch_left, "side": MOUSE_BUTTON_LEFT},
		{"button": _quick_swatch_right, "side": MOUSE_BUTTON_RIGHT},
	]:
		var button := pair["button"] as Button
		if not is_instance_valid(button):
			continue
		var style := StyleBoxFlat.new()
		style.bg_color = Tools.get_assigned_color(pair["side"])
		style.border_color = (
			Tokens.color(_quick_pixel_mode, &"accent_primary")
			if pair["side"] == MOUSE_BUTTON_LEFT
			else Tokens.color(_quick_pixel_mode, &"border_subtle")
		)
		style.set_border_width_all(2 if pair["side"] == MOUSE_BUTTON_LEFT else 1)
		style.set_corner_radius_all(3)
		for state in [&"normal", &"hover", &"pressed", &"focus"]:
			button.add_theme_stylebox_override(state, style)


func _show_quick_hud(value: float, is_size: bool, suffix: String) -> void:
	if not active or _quick_pixel_mode == Tokens.LEGACY or not is_instance_valid(_quick_hud):
		return
	_quick_hud_generation += 1
	_quick_hud_value = value
	_quick_hud_size_mode = is_size and suffix == "px"
	_quick_hud_label.text = "%d%s" % [roundi(value), suffix]
	_quick_hud.visible = true
	_quick_hud_preview.queue_redraw()
	_position_quick_hud()


func _position_quick_hud() -> void:
	if not is_instance_valid(_quick_hud) or not is_instance_valid(_quick_bar):
		return
	var parent := _quick_hud.get_parent() as Control
	if parent == null:
		return
	var x := _quick_bar.position.x + _quick_bar.size.x + Stage3.HUD_GAP
	var y := _quick_bar.position.y + (_quick_bar.size.y - 112.0) * 0.5
	_quick_hud.position = Stage3.popup_position(
		Vector2(x, y), Vector2.ZERO, Vector2(124, 112), parent.size
	)


func _draw_quick_hud_preview() -> void:
	if not is_instance_valid(_quick_hud_preview):
		return
	var center := _quick_hud_preview.size * 0.5
	var mode := _quick_pixel_mode
	if mode == Tokens.LEGACY:
		return
	var outline := Tokens.color(mode, &"outline_ink")
	var fill := Tools.get_assigned_color(MOUSE_BUTTON_LEFT)
	# Keep actual pixel size; larger brushes are clipped by the preview
	# viewport, not falsely represented as a different brush size.
	var square := roundi(maxf(_quick_hud_value, 1.0)) if _quick_hud_size_mode else 12
	var rect := Rect2(
		Vector2(roundi(center.x - square * 0.5), roundi(center.y - square * 0.5)),
		Vector2(square, square)
	)
	_quick_hud_preview.draw_rect(rect.grow(1.0), outline)
	_quick_hud_preview.draw_rect(rect, fill)


func _hide_quick_hud() -> void:
	_quick_hud_generation += 1
	_quick_slider_dragging = false
	if is_instance_valid(_quick_hud):
		_quick_hud.visible = false


func _on_stage3_slider_drag_started(source: Range, is_size: bool, suffix: String) -> void:
	_quick_slider_dragging = true
	if is_instance_valid(source):
		_show_quick_hud(source.value, is_size, suffix)


func _on_stage3_slider_drag_ended(_value_changed: bool) -> void:
	_quick_slider_dragging = false
	_quick_hud_generation += 1
	var generation := _quick_hud_generation
	_hide_quick_hud_after_delay(generation)


func _hide_quick_hud_after_delay(generation: int) -> void:
	await get_tree().create_timer(Stage3.HUD_DISMISS_SECONDS).timeout
	if generation == _quick_hud_generation and is_instance_valid(_quick_hud):
		_quick_hud.visible = false


func _on_quick_slider_changed(value: float, source: Range) -> void:
	if is_instance_valid(source):
		source.value = value


func _on_quick_source_value_changed(
	value: float, slider: VSlider, value_label: Label, suffix: String
) -> void:
	if not is_instance_valid(slider) or not is_instance_valid(value_label):
		return
	if value > slider.max_value:
		slider.max_value = value
	slider.set_value_no_signal(value)
	_update_quick_value_label(value_label, value, suffix)


func _update_quick_value_label(label: Label, value: float, suffix: String) -> void:
	if suffix.contains("00"):
		label.text = "%d%%" % (roundi(value) * 100)
	else:
		label.text = "%d%s" % [roundi(value), suffix]


## Keep a usable touch width but derive the height from the visible
## configuration. Long lists scroll inside the existing ScrollContainer.
static func content_sized_options(
	tool_size: Vector2, family_height: float, bounds: Rect2, definition: WorkspaceModuleDefinition
) -> Vector2:
	if not bounds.has_area() or definition == null:
		return Vector2.ZERO
	var requested := Vector2(
		maxf(tool_size.x + OPTIONS_CONTENT_PADDING.x, definition.minimum_size.x),
		maxf(tool_size.y + family_height + OPTIONS_CONTENT_PADDING.y, definition.minimum_size.y)
	)
	var size := definition.get_constrained_size(requested)
	size.x = minf(size.x, bounds.size.x - TOOL_OPTIONS_MARGIN.x * 2.0)
	size.y = minf(size.y, floorf(bounds.size.y * OPTIONS_MAX_VIEWPORT_RATIO))
	return Vector2(maxf(0.0, size.x), maxf(0.0, size.y))


func _bind_options_size_source() -> void:
	var current := _current_tool_options()
	if current == _options_size_source:
		return
	_disconnect_options_size_source()
	_options_size_source = current
	if is_instance_valid(current):
		current.minimum_size_changed.connect(_on_tool_options_minimum_size_changed)


func _disconnect_options_size_source() -> void:
	if is_instance_valid(_options_size_source):
		if _options_size_source.minimum_size_changed.is_connected(
			_on_tool_options_minimum_size_changed
		):
			_options_size_source.minimum_size_changed.disconnect(
				_on_tool_options_minimum_size_changed
			)
	_options_size_source = null


func _on_tool_options_minimum_size_changed() -> void:
	if active and _advanced_open:
		_resize_advanced_to_content.call_deferred()


func _resize_advanced_to_content() -> void:
	if not active or not _advanced_open or _options_resizing or surface == null:
		return
	if (
		surface.get_module_placement(Builtins.UI3_TOOL_OPTIONS_ID)
		!= WorkspaceSurface.Placement.FLOATING
	):
		return
	var definition := surface.manager.get_definition(Builtins.UI3_TOOL_OPTIONS_ID)
	var tool := _current_tool_options()
	if definition == null or not is_instance_valid(tool):
		return
	var family_height := (
		_family_row.get_combined_minimum_size().y + 6.0
		if is_instance_valid(_family_row) and _family_row.visible
		else 0.0
	)
	var tool_size := tool.get_combined_minimum_size() if _has_left_tool_options() else Vector2.ZERO
	var desired := content_sized_options(
		tool_size, family_height, surface.get_floating_bounds(), definition
	)
	if desired.x < 1.0 or desired.y < 1.0:
		return
	var current := surface.get_floating_rect(Builtins.UI3_TOOL_OPTIONS_ID)
	if current.size.is_equal_approx(desired):
		return
	# Preserve the user's right edge when changing tool type. Ignore saved
	# 440px heights from the old layout.
	var target := Rect2(Vector2(current.end.x - desired.x, current.position.y), desired)
	_options_resizing = true
	surface.set_floating_rect(Builtins.UI3_TOOL_OPTIONS_ID, target)
	_options_resizing = false


## A tap on empty canvas dismisses this transient popup. Tools, other
## floating panels, the Timeline and the left sliders keep their own touch.
func _input(event: InputEvent) -> void:
	if not active or surface == null:
		return
	var dismiss_palette := (
		is_instance_valid(_palette_popup) and _palette_popup.visible and not _palette_pinned
	)
	if not _advanced_open and not dismiss_palette:
		return
	var pointer := Vector2.ZERO
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			return
		pointer = touch.position
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
			return
		pointer = click.position
	else:
		return
	if not _is_blank_canvas_point(pointer):
		return
	if dismiss_palette:
		_palette_popup.visible = false
	if _advanced_open:
		_hide_advanced_panel()
	# A dismissal tap must not create an accidental Pencil stroke.
	get_viewport().set_input_as_handled()


func _is_blank_canvas_point(pointer: Vector2) -> bool:
	if surface == null or surface.dock_host == null or not is_instance_valid(ui_root):
		return false
	var host := surface.dock_host
	var local := host.get_global_transform_with_canvas().affine_inverse() * pointer
	if not host.get_content_rect().has_point(local):
		return false
	if is_instance_valid(_taskbar) and _taskbar.get_global_rect().has_point(pointer):
		return false
	if is_instance_valid(_taskbar_island) and _taskbar_island.visible:
		if _taskbar_island.get_global_rect().has_point(pointer):
			return false
	if is_instance_valid(_palette_popup) and _palette_popup.visible:
		if _palette_popup.get_global_rect().has_point(pointer):
			return false
	if is_instance_valid(_quick_bar) and _quick_bar.visible:
		if _quick_bar.get_global_rect().has_point(pointer):
			return false
	for module_id in surface.manager.get_registered_ids():
		if surface.get_module_placement(module_id) != WorkspaceSurface.Placement.FLOATING:
			continue
		if surface.get_floating_rect(module_id).has_point(local):
			return false
	return true


func _show_advanced_panel() -> bool:
	if not active:
		return false
	if (
		not _has_left_tool_options()
		and not (is_instance_valid(_family_row) and _family_row.visible)
	):
		return false
	if not _ensure_options_module_placement():
		return false
	_advanced_open = true
	_resize_advanced_to_content()
	_resize_advanced_to_content.call_deferred()
	_relocate_advanced_if_over_quick_bar()
	_place_quick_bar()
	return true


func _relocate_advanced_if_over_quick_bar() -> void:
	if surface == null or not is_instance_valid(_quick_bar) or not _quick_bar.visible:
		return
	if (
		surface.get_module_placement(Builtins.UI3_TOOL_OPTIONS_ID)
		!= WorkspaceSurface.Placement.FLOATING
	):
		return
	var rect := surface.get_floating_rect(Builtins.UI3_TOOL_OPTIONS_ID)
	if not rect.intersects(Rect2(_quick_bar.position, _quick_bar.size)):
		return
	var bounds := surface.get_floating_bounds()
	# Prefer the opposite side of the workspace. This also repairs saved
	# tool-panel layouts from the former 56px left-column implementation.
	var target := Rect2(
		Vector2(
			bounds.end.x - rect.size.x - TOOL_OPTIONS_MARGIN.x,
			bounds.position.y + TOOL_OPTIONS_MARGIN.y
		),
		rect.size
	)
	if not target.intersects(Rect2(_quick_bar.position, _quick_bar.size)):
		surface.set_floating_rect(Builtins.UI3_TOOL_OPTIONS_ID, target)


func _hide_advanced_panel() -> void:
	if surface == null:
		return
	_capture_options_module_state()
	if (
		surface.get_module_placement(Builtins.UI3_TOOL_OPTIONS_ID)
		!= WorkspaceSurface.Placement.NONE
	):
		surface.park_module(Builtins.UI3_TOOL_OPTIONS_ID)
	_advanced_open = false


func _set_current_options_compact(enabled: bool) -> void:
	if not enabled:
		if is_instance_valid(_compacted_tool):
			_compacted_tool.set_compact_option_layout(false)
			_compacted_tool = null
		return
	var current := _current_tool_options()
	if current == null:
		return
	if is_instance_valid(_compacted_tool) and _compacted_tool != current:
		_compacted_tool.set_compact_option_layout(false)
	current.set_compact_option_layout(true)
	_compacted_tool = current


func _current_tool_options() -> BaseTool:
	if not is_instance_valid(left_tool_options):
		return null
	var panel := left_tool_options.get_node_or_null(^"LeftPanelContainer") as Control
	if panel == null or panel.get_child_count() == 0:
		return null
	return panel.get_child(panel.get_child_count() - 1) as BaseTool


func _has_left_tool_options() -> bool:
	var tool_node := _current_tool_options()
	if tool_node == null:
		return false
	for child in tool_node.get_children():
		if child is not Control:
			continue
		var control := child as Control
		if control == tool_node.color_rect or control == tool_node.get_node_or_null(^"Label"):
			continue
		if control.visible:
			return true
	return false


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
	(
		parent
		. move_child(
			left_tool_options,
			mini(int(_original_left_options_state.get("index", 0)), parent.get_child_count() - 1),
		)
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
	if not Themes.theme_switched.is_connected(_on_stage3_theme_changed):
		Themes.theme_switched.connect(_on_stage3_theme_changed)
	if not Global.pixel_ui_unit_changed.is_connected(_on_stage3_theme_changed):
		Global.pixel_ui_unit_changed.connect(_on_stage3_theme_changed)
	if not Global.cel_switched.is_connected(_on_context_changed):
		Global.cel_switched.connect(_on_context_changed)
	if not Global.single_tool_mode_changed.is_connected(_on_single_tool_mode_changed):
		Global.single_tool_mode_changed.connect(_on_single_tool_mode_changed)
	if is_instance_valid(ui_root) and not ui_root.resized.is_connected(_on_workspace_resized):
		ui_root.resized.connect(_on_workspace_resized)
	if surface != null:
		if not surface.dock_host.layout_geometry_changed.is_connected(_on_quick_layout_changed):
			surface.dock_host.layout_geometry_changed.connect(_on_quick_layout_changed)


func _on_quick_layout_changed(_content_rect: Rect2) -> void:
	if active:
		_place_quick_bar.call_deferred()


func _on_tool_changed(_tool_name: String, button: int) -> void:
	if not active or button != MOUSE_BUTTON_LEFT:
		return
	_last_active_tool = _current_left_tool_name()
	_refresh_taskbar.call_deferred()
	_refresh_config_panel.call_deferred()


func _on_color_changed(_color_info: Dictionary, button: int) -> void:
	if not active:
		return
	if button == MOUSE_BUTTON_LEFT and is_instance_valid(_color_indicator):
		_color_indicator.queue_redraw()
	_update_stage3_swatches()
	if is_instance_valid(_quick_hud_preview) and _quick_hud.visible:
		_quick_hud_preview.queue_redraw()


func _on_context_changed() -> void:
	if active:
		_refresh_taskbar.call_deferred()
		_refresh_config_panel.call_deferred()


func _on_single_tool_mode_changed(_enabled: bool) -> void:
	if active:
		_refresh_taskbar.call_deferred()
		_refresh_config_panel.call_deferred()


func _on_stage3_theme_changed() -> void:
	if not active or not is_instance_valid(_quick_bar):
		return
	var updated := Chrome.active_mode()
	if updated != _quick_pixel_mode:
		_refresh_config_panel()
	_refresh_stage3_visuals()


## All stage-3 styling is restricted to the original UI3 presentation,
## not a second tool model. Legacy themes get their original 100px controls.
func _refresh_stage3_visuals() -> void:
	if not is_instance_valid(_quick_bar) or not is_instance_valid(_palette_popup):
		return
	var mode := Chrome.active_mode()
	_quick_pixel_mode = mode
	var pixel := mode != Tokens.LEGACY
	_sync_stage3_taskbar_island(pixel, mode)
	var margin := _quick_bar.get_child(0) as MarginContainer
	if margin != null:
		margin.add_theme_constant_override(&"margin_left", 4 if pixel else 6)
		margin.add_theme_constant_override(&"margin_right", 4 if pixel else 6)
		margin.add_theme_constant_override(&"margin_top", 8 if pixel else 6)
		margin.add_theme_constant_override(&"margin_bottom", 8 if pixel else 6)
	_quick_bar.custom_minimum_size.x = Stage3.CAPSULE_WIDTH if pixel else QUICK_BAR_WIDTH
	_quick_bar.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST if pixel else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	)
	if pixel:
		_quick_bar.add_theme_stylebox_override(
			&"panel", _make_ui3_card_style(mode, &"panel_surface", 6, true)
		)
		_palette_popup.add_theme_stylebox_override(
			&"panel", _make_ui3_card_style(mode, &"panel_surface", 6, true)
		)
		_palette_header.add_theme_stylebox_override(&"panel", _make_ui3_header_style(mode))
		_quick_hud.add_theme_stylebox_override(
			&"panel", _make_ui3_card_style(mode, &"panel_surface", 6, true)
		)
		Stage4.style_button(_palette_close_button, mode)
	else:
		# The legacy popup has no tear-off header or close control.
		# Clear the pinned state before hiding that control to avoid a
		# permanently open palette when switching theme presets.
		_palette_pinned = false
		_palette_dragging = false
		_palette_popup.visible = false
		_quick_bar.remove_theme_stylebox_override(&"panel")
		_palette_popup.remove_theme_stylebox_override(&"panel")
		_palette_header.remove_theme_stylebox_override(&"panel")
		_quick_hud.remove_theme_stylebox_override(&"panel")
		Chrome.clear_button(_palette_close_button)
		_hide_quick_hud()
	_update_palette_pin_visual()
	_update_stage3_swatches()
	if active:
		_place_quick_bar.call_deferred()


## Reparent only the presentation node. The existing proxy buttons and
## their original tool bindings stay mounted and stateful across profiles.
func _sync_stage3_taskbar_island(pixel: bool, _mode: StringName) -> void:
	if not is_instance_valid(_taskbar_island) or not is_instance_valid(_taskbar):
		return
	if pixel and active:
		if _taskbar.get_parent() != _taskbar_scroller:
			_taskbar.reparent(_taskbar_scroller)
		_taskbar_island.visible = true
		_taskbar.add_theme_constant_override(&"separation", 4)
		_taskbar_island.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_taskbar_scroller.custom_minimum_size = Vector2(120.0, 36.0)
		for child in _taskbar.get_children():
			if child is Button:
				var btn := child as Button
				btn.custom_minimum_size = Vector2(34.0, 34.0)
				btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_taskbar_island.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	else:
		var row := _taskbar_island.get_parent() as HBoxContainer
		if row != null and _taskbar.get_parent() != row:
			_taskbar.reparent(row)
			row.move_child(_taskbar, row.get_child_count() - 1)
		_taskbar.add_theme_constant_override(&"separation", 3)
		for child in _taskbar.get_children():
			if child is Button:
				(child as Button).custom_minimum_size = TASK_BUTTON_SIZE
		_taskbar_island.visible = false
		_taskbar_island.remove_theme_stylebox_override(&"panel")
	if active:
		_refresh_taskbar()


func _on_workspace_resized() -> void:
	if active and is_instance_valid(_palette_popup) and _palette_popup.visible:
		if _palette_pinned:
			_palette_popup.position = _constrain_stage3_palette_position(
				Stage3.popup_position(
					_palette_popup.position, Vector2.ZERO, _palette_popup.size, ui_root.size
				)
			)
		else:
			_place_popup_below(_palette_popup, _color_button, PALETTE_POPUP_SIZE)
	_place_quick_bar.call_deferred()


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
		proxy.expand_icon = Chrome.active_mode() == Tokens.LEGACY
		proxy.tooltip_text = source.tooltip_text
		var selected := _source_represents_tool(source, current)
		proxy.button_pressed = selected
		_apply_tool_button_highlight(proxy, selected)

	var pixel_on := Chrome.active_mode() != Tokens.LEGACY
	if is_instance_valid(_brush_button):
		var source := _source_button(BRUSH_TOOL)
		_brush_button.visible = source == null or source.visible
		_brush_button.icon = (
			QIcons.tool_icon_1x(BRUSH_TOOL)
			if pixel_on
			else (_source_icon(source) if source != null else null)
		)
		_brush_button.expand_icon = not pixel_on
		var brush_selected := current == BRUSH_TOOL
		_brush_button.button_pressed = brush_selected
		_apply_tool_button_highlight(_brush_button, brush_selected)
	if is_instance_valid(_eraser_button):
		var source := _source_button(ERASER_TOOL)
		_eraser_button.visible = source == null or source.visible
		_eraser_button.icon = (
			QIcons.tool_icon_1x(ERASER_TOOL)
			if pixel_on
			else (_source_icon(source) if source != null else null)
		)
		_eraser_button.expand_icon = not pixel_on
		var eraser_selected := current == ERASER_TOOL
		_eraser_button.button_pressed = eraser_selected
		_apply_tool_button_highlight(_eraser_button, eraser_selected)
	if is_instance_valid(_color_button):
		if pixel_on:
			Chrome.style_button(_color_button, _quick_pixel_mode)
		else:
			Chrome.clear_button(_color_button)
			_color_button.flat = true
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
	if _quick_pixel_mode != Tokens.LEGACY and button is Button:
		var pixel_button := button as Button
		Stage4.style_button(pixel_button, _quick_pixel_mode)
		pixel_button.button_pressed = selected
		button.modulate = Color.WHITE
	else:
		if button is Button:
			Stage4.style_button(button as Button, Tokens.LEGACY)
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
	return is_instance_valid(source) and StringName(source.name) == SELECTION_TOOLBAR_REP


func _is_shape_family_source(source: BaseButton) -> bool:
	return is_instance_valid(source) and StringName(source.name) == SHAPE_TOOLBAR_REP


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
	if _quick_pixel_mode != Tokens.LEGACY:
		var side := mini(int(_color_indicator.size.x), int(_color_indicator.size.y)) - 8
		if side >= 12:
			var offset := Vector2(
				floorf((_color_indicator.size.x - side) * 0.5),
				floorf((_color_indicator.size.y - side) * 0.5)
			)
			_color_indicator.draw_set_transform(offset)
			Draw.draw_pixel_swatch_r4(
				_color_indicator,
				Vector2(side, side),
				Tools.get_assigned_color(MOUSE_BUTTON_LEFT),
				_quick_pixel_mode,
				false,
				false,
				false
			)
			_color_indicator.draw_set_transform(Vector2.ZERO)
		return
	var radius := minf(_color_indicator.size.x, _color_indicator.size.y) * 0.30
	var center := _color_indicator.size * 0.5
	var color := Tools.get_assigned_color(MOUSE_BUTTON_LEFT)
	_color_indicator.draw_circle(center, radius + 2.0, Color(1.0, 1.0, 1.0, 0.9))
	_color_indicator.draw_circle(center, radius, color)
	(
		_color_indicator
		. draw_arc(
			center,
			radius + 2.0,
			0.0,
			TAU,
			32,
			Color(0.0, 0.0, 0.0, 0.7),
			1.0,
			true,
		)
	)


func _make_ui3_card_style(
	mode: StringName, fill_role: StringName, radius: int, with_shadow: bool
) -> StyleBoxFlat:
	var key := "%s:%s:%d:%s" % [mode, fill_role, radius, str(with_shadow)]
	if _ui3_panel_cache.has(key):
		return _ui3_panel_cache[key] as StyleBoxFlat
	var style := StyleBoxFlat.new()
	style.bg_color = Tokens.color(mode, fill_role)
	style.border_color = Tokens.color(mode, &"border_subtle")
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	if with_shadow:
		style.shadow_color = Color(0.10, 0.08, 0.18, 0.18 if mode == Tokens.SUNNY else 0.34)
		style.shadow_size = 2
		style.shadow_offset = Vector2(0, 2)
	_ui3_panel_cache[key] = style
	return style


func _make_ui3_header_style(mode: StringName) -> StyleBoxFlat:
	var key := "hdr:%s" % mode
	if _ui3_panel_cache.has(key):
		return _ui3_panel_cache[key] as StyleBoxFlat
	var style := StyleBoxFlat.new()
	style.bg_color = Tokens.color(mode, &"accent_soft")
	style.border_color = Tokens.color(mode, &"border_subtle")
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	_ui3_panel_cache[key] = style
	return style


func _style_stage3_vslider(slider: VSlider, mode: StringName) -> void:
	if not is_instance_valid(slider) or mode == Tokens.LEGACY:
		return
	var cache_key := String(mode)
	var pack: Dictionary
	if _ui3_slider_cache.has(cache_key):
		pack = _ui3_slider_cache[cache_key] as Dictionary
	else:
		var track := StyleBoxFlat.new()
		track.bg_color = (Color("D8D0E4") if mode == Tokens.SUNNY else Color("3B3554"))
		track.border_color = Tokens.color(mode, &"border_subtle")
		track.set_border_width_all(1)
		track.set_corner_radius_all(3)
		track.content_margin_left = 3.0
		track.content_margin_right = 3.0

		var fill := StyleBoxFlat.new()
		fill.bg_color = Tokens.color(mode, &"accent_primary")
		fill.set_corner_radius_all(2)
		fill.content_margin_left = 3.0
		fill.content_margin_right = 3.0

		var grabber_img := Image.create(12, 10, false, Image.FORMAT_RGBA8)
		var border_col := (
			Tokens.color(mode, &"outline_ink") if mode == Tokens.SUNNY else Color("C8C2E6")
		)
		var face_col := Color("FFFFFF") if mode == Tokens.SUNNY else Color("E6E2F5")
		var lip_col := Color("C4BCE0") if mode == Tokens.SUNNY else Color("8A7FB5")
		for y in range(10):
			for x in range(12):
				var is_corner := (x == 0 or x == 11) and (y == 0 or y == 9)
				if is_corner:
					grabber_img.set_pixel(x, y, Color(0, 0, 0, 0))
				elif x == 0 or x == 11 or y == 0 or y == 9:
					grabber_img.set_pixel(x, y, border_col)
				elif y == 8:
					grabber_img.set_pixel(x, y, lip_col)
				else:
					grabber_img.set_pixel(x, y, face_col)
		var grabber_tex := ImageTexture.create_from_image(grabber_img)
		pack = {"track": track, "fill": fill, "grabber": grabber_tex}
		_ui3_slider_cache[cache_key] = pack

	slider.add_theme_stylebox_override(&"slider", pack["track"] as StyleBoxFlat)
	slider.add_theme_stylebox_override(&"grabber_area", pack["fill"] as StyleBoxFlat)
	slider.add_theme_stylebox_override(&"grabber_area_highlight", pack["fill"] as StyleBoxFlat)
	slider.add_theme_icon_override(&"grabber", pack["grabber"] as Texture2D)
	slider.add_theme_icon_override(&"grabber_highlight", pack["grabber"] as Texture2D)
