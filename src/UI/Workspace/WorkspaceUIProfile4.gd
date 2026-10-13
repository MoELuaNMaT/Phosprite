class_name WorkspaceUIProfile4
extends Node

## Aseprite-like U-shaped workspace. Reuses all live editor widgets; only their
## Workspace placements, resize rules and presentation change in UI4.
const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const LEFT_WIDTH := 176.0
const RIGHT_WIDTH := 112.0
const TIMELINE_HEIGHT := 224.0
const PREVIEW_OFFSET := Vector2(18.0, 18.0)
const SPLIT_MIN := 0.2
const SPLIT_MAX := 0.85
const SPLIT_GRAB_HEIGHT := 18.0

var ui_root: Control
var surface: WorkspaceSurface
var active := false

var _tools_width_state: Dictionary = {}
var _palette_width_state: Dictionary = {}
var _module_position_states: Dictionary = {}
var _palette_stretch_state := Vector2(-1.0, -1.0)
var _palette_root: Control
var _palette_content: Control
var _picker_content: Control
var _split_handle: Control
var _split_drag_mouse := false
var _split_drag_touch := -1


func setup(root: Control, workspace_surface: WorkspaceSurface) -> bool:
	if ui_root != null or root == null or workspace_surface == null:
		return false
	ui_root = root
	surface = workspace_surface
	return true


func activate() -> bool:
	if surface == null or surface.dock_host == null:
		return false
	active = true
	_configure_fixed_layout()
	if not enforce_workspace():
		return false
	if not Global.headless_test_mode:
		_apply_live_palette_presentation()
	return true


func deactivate() -> void:
	if not active:
		return
	active = false
	_split_drag_mouse = false
	_split_drag_touch = -1
	_restore_live_palette_presentation()
	if surface != null and surface.dock_host != null:
		surface.dock_host.set_u_frame_layout(false)
		surface.configure_floating_snap_policy(
			{Builtins.TIMELINE_ID: WorkspaceDockLayout.DockZone.BOTTOM}
		)
	for id_variant in _module_position_states:
		var module_id := id_variant as StringName
		var module := surface.manager.get_instance(module_id) if surface != null else null
		if module != null:
			module.set_position_adjustment_enabled(bool(_module_position_states[id_variant]))
	_module_position_states.clear()
	_restore_tools_width()
	_restore_palette_width()


func refresh_after_tools_ready() -> bool:
	if not active:
		return true
	return activate()


func enforce_workspace() -> bool:
	if not active or surface == null:
		return true
	if not _place_fixed_module(
		Builtins.PALETTE_ID, WorkspaceDockLayout.DockZone.LEFT, Vector2(LEFT_WIDTH, 500.0)
	):
		return false
	if not _place_fixed_module(
		Builtins.TOOLS_ID, WorkspaceDockLayout.DockZone.RIGHT, Vector2(RIGHT_WIDTH, 500.0)
	):
		return false
	if not _place_fixed_module(
		Builtins.TIMELINE_ID, WorkspaceDockLayout.DockZone.BOTTOM, Vector2(760.0, TIMELINE_HEIGHT)
	):
		return false
	if not surface.park_module(Builtins.RIGHT_TOOL_OPTIONS_ID):
		return false
	return true


func apply_initial_workspace() -> bool:
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
	var preview_size := definition.get_constrained_preferred_size()
	if placement == WorkspaceSurface.Placement.FLOATING:
		var current := surface.get_floating_rect(Builtins.PREVIEW_ID)
		if current.has_area():
			preview_size = current.size
	var bounds := surface.get_floating_bounds()
	var target := Rect2(
		Vector2(
			bounds.end.x - preview_size.x - PREVIEW_OFFSET.x, bounds.position.y + PREVIEW_OFFSET.y
		),
		preview_size
	)
	if placement == WorkspaceSurface.Placement.FLOATING:
		return surface.set_floating_rect(Builtins.PREVIEW_ID, target)
	return surface.float_module(Builtins.PREVIEW_ID, target)


func _configure_fixed_layout() -> void:
	var manager := surface.manager
	var palette_definition := manager.get_definition(Builtins.PALETTE_ID)
	if palette_definition != null:
		if _palette_width_state.is_empty():
			_palette_width_state = {
				"minimum": palette_definition.minimum_size.x,
				"preferred": palette_definition.preferred_size.x,
				"maximum": palette_definition.maximum_size.x,
			}
		palette_definition.minimum_size.x = 156.0
		palette_definition.preferred_size.x = LEFT_WIDTH
		palette_definition.maximum_size.x = 440.0
	var tools_definition := manager.get_definition(Builtins.TOOLS_ID)
	if tools_definition != null:
		if _tools_width_state.is_empty():
			_tools_width_state = {
				"minimum": tools_definition.minimum_size.x,
				"preferred": tools_definition.preferred_size.x,
				"maximum": tools_definition.maximum_size.x,
			}
		# UI1 and UI4 share the same fixed tool-plus-options width for every tool.
		tools_definition.minimum_size.x = RIGHT_WIDTH
		tools_definition.preferred_size.x = RIGHT_WIDTH
		tools_definition.maximum_size.x = RIGHT_WIDTH
	surface.dock_host.set_u_frame_layout(true)
	(
		surface
		. configure_floating_snap_policy(
			{
				Builtins.TIMELINE_ID: WorkspaceDockLayout.DockZone.BOTTOM,
				Builtins.PALETTE_ID: WorkspaceDockLayout.DockZone.LEFT,
				Builtins.TOOLS_ID: WorkspaceDockLayout.DockZone.RIGHT,
			}
		)
	)
	for module_id in [Builtins.PALETTE_ID, Builtins.TOOLS_ID, Builtins.TIMELINE_ID]:
		var module := manager.get_instance(module_id)
		if module != null:
			if not _module_position_states.has(module_id):
				_module_position_states[module_id] = module.is_position_adjustment_enabled()
			module.set_position_adjustment_enabled(false)


func _restore_tools_width() -> void:
	if _tools_width_state.is_empty() or surface == null:
		return
	var definition := surface.manager.get_definition(Builtins.TOOLS_ID)
	if definition != null:
		definition.minimum_size.x = float(_tools_width_state["minimum"])
		definition.preferred_size.x = float(_tools_width_state["preferred"])
		definition.maximum_size.x = float(_tools_width_state["maximum"])
	_tools_width_state.clear()


func _restore_palette_width() -> void:
	if _palette_width_state.is_empty() or surface == null:
		return
	var definition := surface.manager.get_definition(Builtins.PALETTE_ID)
	if definition != null:
		definition.minimum_size.x = float(_palette_width_state["minimum"])
		definition.preferred_size.x = float(_palette_width_state["preferred"])
		definition.maximum_size.x = float(_palette_width_state["maximum"])
	_palette_width_state.clear()


func _place_fixed_module(module_id: StringName, zone: int, default_size: Vector2) -> bool:
	var placement := surface.get_module_placement(module_id)
	if placement == WorkspaceSurface.Placement.DOCKED:
		if (
			surface.dock_host.layout.get_module_zone(module_id) == zone
			and surface.dock_host.layout.is_module_region_fill(module_id)
		):
			var module := surface.manager.get_instance(module_id)
			if module != null:
				module.set_position_adjustment_enabled(false)
			return true
	var current_size := default_size
	# A layout imported from UI1 must not impose its old floating palette width.
	# An existing UI4 dock keeps its own size because that state was restored above.
	if module_id == Builtins.TIMELINE_ID:
		if placement == WorkspaceSurface.Placement.DOCKED:
			current_size = surface.dock_host.layout.get_module_size(module_id)
		elif placement == WorkspaceSurface.Placement.FLOATING:
			var timeline_rect := surface.get_floating_rect(module_id)
			if timeline_rect.has_area():
				current_size.y = timeline_rect.size.y
	# Preserve height for Timeline; height of the two side panels is container-driven.
	if module_id == Builtins.PALETTE_ID:
		current_size.x = LEFT_WIDTH
	elif module_id == Builtins.TOOLS_ID:
		current_size.x = RIGHT_WIDTH
	elif module_id == Builtins.TIMELINE_ID and current_size.y <= 0.0:
		current_size.y = TIMELINE_HEIGHT
	if not surface.dock_module(module_id, zone, 0, current_size, {}, true):
		return false
	var module := surface.manager.get_instance(module_id)
	if module != null:
		module.set_position_adjustment_enabled(false)
	return true


func _apply_live_palette_presentation() -> void:
	if not active:
		return
	var module := surface.manager.get_instance(Builtins.PALETTE_ID)
	if module == null:
		return
	var root := module.get_content()
	if root == null:
		return
	var palette := root.get_node_or_null(^"Palettes") as Control
	var picker := root.get_node_or_null(^"Color Picker") as Control
	if palette == null or picker == null:
		return
	_palette_root = root
	_palette_content = palette
	_picker_content = picker
	if _palette_stretch_state.x < 0.0:
		_palette_stretch_state = Vector2(
			palette.size_flags_stretch_ratio, picker.size_flags_stretch_ratio
		)
	var ratio := clampf(
		float(Global.config_cache.get_value("ui4", "palette_split_ratio", 0.68)),
		SPLIT_MIN,
		SPLIT_MAX
	)
	_set_split_ratio(ratio, false)
	_ensure_split_handle()
	_show_color_buttons_when_ready.call_deferred()


func _show_color_buttons_when_ready() -> void:
	# ColorPicker._ready hides this row after its first process frame.
	# Re-enable it only once that initialization has finished.
	await get_tree().process_frame
	if active:
		_set_color_button_visibility(true)


func _restore_live_palette_presentation() -> void:
	if is_instance_valid(_split_handle):
		_split_handle.queue_free()
	_split_handle = null
	if is_instance_valid(_palette_content) and is_instance_valid(_picker_content):
		if _palette_stretch_state.x >= 0.0:
			_palette_content.size_flags_stretch_ratio = _palette_stretch_state.x
			_picker_content.size_flags_stretch_ratio = _palette_stretch_state.y
	_set_color_button_visibility(false)
	_palette_stretch_state = Vector2(-1.0, -1.0)
	_palette_root = null
	_palette_content = null
	_picker_content = null


func _set_color_button_visibility(enabled: bool) -> void:
	# Existing two tool slots are the foreground/background colors. Do not fork their state.
	if not is_instance_valid(_picker_content) or (enabled and not active):
		return
	var colors := (
		_picker_content.get_node_or_null(^"ScrollContainer/VerticalContainer/ColorButtons")
		as HBoxContainer
	)
	if colors == null:
		return
	colors.visible = enabled
	var switch_button := colors.get_node_or_null(^"ColorSwitch") as Control
	if switch_button != null:
		switch_button.visible = false
	var auxiliary := colors.get_node_or_null(^"ColorButtonsVertical") as Control
	if auxiliary != null:
		auxiliary.visible = false
	if enabled:
		var left := colors.get_node_or_null(^"LeftColorButton") as BaseButton
		var right := colors.get_node_or_null(^"RightColorButton") as BaseButton
		if left != null and right != null:
			left.set_pressed_no_signal(Tools.picking_color_for == MOUSE_BUTTON_LEFT)
			right.set_pressed_no_signal(Tools.picking_color_for == MOUSE_BUTTON_RIGHT)


func _set_split_ratio(ratio: float, persist: bool) -> void:
	if not is_instance_valid(_palette_content) or not is_instance_valid(_picker_content):
		return
	var clamped := clampf(ratio, SPLIT_MIN, SPLIT_MAX)
	_palette_content.size_flags_stretch_ratio = clamped
	_picker_content.size_flags_stretch_ratio = 1.0 - clamped
	if persist:
		Global.config_cache.set_value("ui4", "palette_split_ratio", clamped)
	_update_split_handle.call_deferred()


func _ensure_split_handle() -> void:
	if is_instance_valid(_split_handle) or not is_instance_valid(surface.dock_host):
		return
	_split_handle = Control.new()
	_split_handle.name = &"UI4PaletteSplitHandle"
	_split_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_split_handle.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	surface.dock_host.add_child(_split_handle)
	_split_handle.gui_input.connect(_on_split_handle_input)
	if not _palette_content.resized.is_connected(_update_split_handle):
		_palette_content.resized.connect(_update_split_handle)
	if not _palette_root.resized.is_connected(_update_split_handle):
		_palette_root.resized.connect(_update_split_handle)
	if not surface.dock_host.resized.is_connected(_update_split_handle):
		surface.dock_host.resized.connect(_update_split_handle)
	_update_split_handle.call_deferred()


func _update_split_handle() -> void:
	if not active or not is_instance_valid(_split_handle):
		return
	if not is_instance_valid(_palette_content) or not is_instance_valid(_palette_root):
		return
	var host := surface.dock_host
	var global_edge := (
		_palette_content.get_global_transform_with_canvas() * Vector2(0.0, _palette_content.size.y)
	)
	var host_point := host.get_global_transform_with_canvas().affine_inverse() * global_edge
	_split_handle.position = host_point - Vector2(0.0, SPLIT_GRAB_HEIGHT * 0.5)
	_split_handle.size = Vector2(_palette_root.size.x, SPLIT_GRAB_HEIGHT)


func _on_split_handle_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_split_drag_mouse = button.pressed
			_split_handle.accept_event()
	elif event is InputEventMouseMotion and _split_drag_mouse:
		_adjust_split((event as InputEventMouseMotion).relative.y)
		_split_handle.accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _split_drag_touch == -1:
			_split_drag_touch = touch.index
		elif not touch.pressed and _split_drag_touch == touch.index:
			_split_drag_touch = -1
		_split_handle.accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _split_drag_touch:
			_adjust_split(drag.relative.y)
			_split_handle.accept_event()


func _adjust_split(delta_y: float) -> void:
	if not is_instance_valid(_palette_root) or _palette_root.size.y <= 0.0:
		return
	var old_ratio := (
		_palette_content.size_flags_stretch_ratio
		/ maxf(
			0.001,
			_palette_content.size_flags_stretch_ratio + _picker_content.size_flags_stretch_ratio
		)
	)
	_set_split_ratio(old_ratio + delta_y / _palette_root.size.y, true)
