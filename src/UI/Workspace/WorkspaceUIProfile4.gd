class_name WorkspaceUIProfile4
extends Node

## Aseprite-like U-shaped workspace. Reuses all live editor widgets; only their
## Workspace placements, resize rules and presentation change in UI4.
const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const Stage4 := preload("res://src/UI/DesignSystem/PhospriteStage4Chrome.gd")
const Tokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")
const LEFT_WIDTH := 236.0
const RIGHT_WIDTH := Builtins.TOOL_SIDEBAR_WIDTH
const TIMELINE_HEIGHT := 224.0
const PREVIEW_HEIGHT := 184.0
const PREVIEW_OFFSET := Vector2(14.0, 14.0)
const SPLIT_MIN := 0.2
const SPLIT_MAX := 0.85
const SPLIT_GRAB_HEIGHT := 20.0
const PREVIEW_SPLIT_GRAB_HEIGHT := 26.0
const PREVIEW_MIN_HEIGHT := 112.0
const PALETTE_MIN_HEIGHT := 240.0

var ui_root: Control
var surface: WorkspaceSurface
var active := false

var _tools_width_state: Dictionary = {}
var _palette_width_state: Dictionary = {}
var _preview_width_state: Dictionary = {}
var _module_position_states: Dictionary = {}
var _palette_stretch_state := Vector2(-1.0, -1.0)
var _palette_root: Control
var _palette_content: Control
var _picker_content: Control
var _split_handle: Control
var _split_drag_mouse := false
var _split_drag_touch := -1
var _preview_split_handle: Control
var _preview_split_drag_mouse := false
var _preview_split_drag_touch := -1
var _preview_split_start_y := 0.0
var _preview_split_start_height := 0.0
var _preview_split_transient_store: WorkspaceLayoutStore


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
	_end_preview_split_drag()
	_preview_split_drag_mouse = false
	_preview_split_drag_touch = -1
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
	_restore_preview_width()


func refresh_after_tools_ready() -> bool:
	if not active:
		return true
	return activate()


func enforce_workspace() -> bool:
	if not active or surface == null:
		return true
	var has_preview := surface.manager.has_instance(Builtins.PREVIEW_ID)
	if has_preview:
		if not _place_fixed_module(
			Builtins.PREVIEW_ID,
			WorkspaceDockLayout.DockZone.LEFT,
			Vector2(LEFT_WIDTH, PREVIEW_HEIGHT),
			0,
			false
		):
			return false
	if not _place_fixed_module(
		Builtins.PALETTE_ID,
		WorkspaceDockLayout.DockZone.LEFT,
		Vector2(LEFT_WIDTH, 500.0),
		1 if has_preview else 0,
		true
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
	if surface.manager.has_instance(Builtins.PREVIEW_ID):
		var placement := surface.get_module_placement(Builtins.PREVIEW_ID)
		if placement == WorkspaceSurface.Placement.COLLAPSED:
			if not surface.restore_module(Builtins.PREVIEW_ID):
				return false
		return _place_fixed_module(
			Builtins.PREVIEW_ID,
			WorkspaceDockLayout.DockZone.LEFT,
			Vector2(LEFT_WIDTH, PREVIEW_HEIGHT),
			0,
			false
		)
	return true


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
	var preview_definition := manager.get_definition(Builtins.PREVIEW_ID)
	if preview_definition != null:
		if _preview_width_state.is_empty():
			_preview_width_state = {
				"minimum": preview_definition.minimum_size.x,
				"preferred": preview_definition.preferred_size.x,
				"maximum": preview_definition.maximum_size.x,
			}
		preview_definition.minimum_size.x = 156.0
		preview_definition.preferred_size.x = LEFT_WIDTH
		preview_definition.maximum_size.x = 440.0
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
				Builtins.PREVIEW_ID: WorkspaceDockLayout.DockZone.LEFT,
				Builtins.PALETTE_ID: WorkspaceDockLayout.DockZone.LEFT,
				Builtins.TOOLS_ID: WorkspaceDockLayout.DockZone.RIGHT,
			}
		)
	)
	for module_id in [
		Builtins.PREVIEW_ID, Builtins.PALETTE_ID, Builtins.TOOLS_ID, Builtins.TIMELINE_ID
	]:
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


func _restore_preview_width() -> void:
	if _preview_width_state.is_empty() or surface == null:
		return
	var definition := surface.manager.get_definition(Builtins.PREVIEW_ID)
	if definition != null:
		definition.minimum_size.x = float(_preview_width_state["minimum"])
		definition.preferred_size.x = float(_preview_width_state["preferred"])
		definition.maximum_size.x = float(_preview_width_state["maximum"])
	_preview_width_state.clear()


func _place_fixed_module(
	module_id: StringName,
	zone: int,
	default_size: Vector2,
	index: int = 0,
	region_fill: bool = true
) -> bool:
	var placement := surface.get_module_placement(module_id)
	if placement == WorkspaceSurface.Placement.DOCKED:
		if (
			surface.dock_host.layout.get_module_zone(module_id) == zone
			and surface.dock_host.layout.is_module_region_fill(module_id) == region_fill
		):
			# UI4 may restore an older snapshot saved with a wider tool sidebar.
			# Reapply the fixed width even when no dock transition is necessary.
			if module_id == Builtins.TOOLS_ID:
				var current_size := surface.dock_host.layout.get_module_size(module_id)
				if not is_equal_approx(current_size.x, RIGHT_WIDTH):
					current_size.x = RIGHT_WIDTH
					if not surface.dock_host.set_module_size(module_id, current_size):
						return false
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
	# Preserve height for Timeline and Preview; height of Palette/Tools is container-driven.
	if module_id == Builtins.PREVIEW_ID:
		current_size = Vector2(LEFT_WIDTH, _saved_preview_height())
	elif module_id == Builtins.PALETTE_ID:
		current_size.x = LEFT_WIDTH
	elif module_id == Builtins.TOOLS_ID:
		current_size.x = RIGHT_WIDTH
	elif module_id == Builtins.TIMELINE_ID and current_size.y <= 0.0:
		current_size.y = TIMELINE_HEIGHT
	if not surface.dock_module(module_id, zone, index, current_size, {}, region_fill):
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
		float(Global.config_cache.get_value("ui4", "palette_split_ratio", 0.54)),
		SPLIT_MIN,
		SPLIT_MAX
	)
	_set_split_ratio(ratio, false)
	_ensure_split_handle()
	_ensure_preview_split_handle()
	# Foreground/background swatches are now shared by all three profiles.
	# The ColorPicker places them in its own sampler row.


func _restore_live_palette_presentation() -> void:
	if is_instance_valid(_split_handle):
		_split_handle.queue_free()
	_split_handle = null
	if is_instance_valid(_preview_split_handle):
		_preview_split_handle.queue_free()
	_preview_split_handle = null
	if is_instance_valid(_palette_content) and is_instance_valid(_picker_content):
		if _palette_stretch_state.x >= 0.0:
			_palette_content.size_flags_stretch_ratio = _palette_stretch_state.x
			_picker_content.size_flags_stretch_ratio = _palette_stretch_state.y
	_palette_stretch_state = Vector2(-1.0, -1.0)
	_palette_root = null
	_palette_content = null
	_picker_content = null


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
	_split_handle.add_to_group(&"phosprite_ui4_split_handles")
	_split_handle.z_index = 4
	_split_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_split_handle.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	surface.dock_host.add_child(_split_handle)
	_split_handle.gui_input.connect(_on_split_handle_input)
	_split_handle.draw.connect(_draw_stage4_split_handle)
	if not Themes.theme_switched.is_connected(_refresh_stage4_split_handle):
		Themes.theme_switched.connect(_refresh_stage4_split_handle)
	if not Global.pixel_ui_unit_changed.is_connected(_refresh_stage4_split_handle):
		Global.pixel_ui_unit_changed.connect(_refresh_stage4_split_handle)
	if not _palette_content.resized.is_connected(_update_split_handle):
		_palette_content.resized.connect(_update_split_handle)
	if not _palette_root.resized.is_connected(_update_split_handle):
		_palette_root.resized.connect(_update_split_handle)
	if not surface.dock_host.resized.is_connected(_update_split_handle):
		surface.dock_host.resized.connect(_update_split_handle)
	_update_split_handle.call_deferred()


func _refresh_stage4_split_handle() -> void:
	if is_instance_valid(_split_handle):
		_split_handle.queue_redraw()
	if is_instance_valid(_preview_split_handle):
		_preview_split_handle.queue_redraw()


func _draw_stage4_split_handle() -> void:
	if not is_instance_valid(_split_handle):
		return
	var mode := Stage4.active_mode()
	if mode == Tokens.LEGACY:
		return
	var sz := _split_handle.size
	var mid_y := roundf(sz.y * 0.5)
	var line_col := Tokens.color(mode, &"border_subtle")
	line_col.a = 0.45
	_split_handle.draw_line(Vector2(8.0, mid_y), Vector2(sz.x - 8.0, mid_y), line_col, 1.0)
	var pill_w := 32.0
	var pill_h := 6.0
	var pill_rect := Rect2(
		Vector2((sz.x - pill_w) * 0.5, mid_y - pill_h * 0.5), Vector2(pill_w, pill_h)
	)
	_split_handle.draw_rect(pill_rect, Tokens.color(mode, &"panel_surface"))
	var dot_col := Tokens.color(mode, &"text_muted")
	var cx := roundi(sz.x * 0.5)
	var cy := roundi(mid_y)
	for dot_index in range(-1, 2):
		var x := cx + dot_index * 7 - 1
		_split_handle.draw_rect(Rect2i(x, cy - 1, 3, 2), dot_col)


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


func _saved_preview_height() -> float:
	var saved := float(Global.config_cache.get_value("ui4", "preview_height", PREVIEW_HEIGHT))
	return clampf(saved, PREVIEW_MIN_HEIGHT, 480.0)


func _ensure_preview_split_handle() -> void:
	if not is_instance_valid(surface.dock_host):
		return
	if is_instance_valid(_preview_split_handle):
		_update_preview_split_handle.call_deferred()
		return
	var preview_module := surface.manager.get_instance(Builtins.PREVIEW_ID)
	var palette_module := surface.manager.get_instance(Builtins.PALETTE_ID)
	if preview_module == null or palette_module == null:
		return
	_preview_split_handle = Control.new()
	_preview_split_handle.name = &"UI4PreviewPaletteSplitHandle"
	_preview_split_handle.add_to_group(&"phosprite_ui4_split_handles")
	_preview_split_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_preview_split_handle.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	_preview_split_handle.z_index = 5
	surface.dock_host.add_child(_preview_split_handle)
	_preview_split_handle.gui_input.connect(_on_preview_split_input)
	_preview_split_handle.draw.connect(_draw_preview_split_handle)
	if not preview_module.resized.is_connected(_update_preview_split_handle):
		preview_module.resized.connect(_update_preview_split_handle)
	if not preview_module.visibility_changed.is_connected(_update_preview_split_handle):
		preview_module.visibility_changed.connect(_update_preview_split_handle)
	if not palette_module.resized.is_connected(_update_preview_split_handle):
		palette_module.resized.connect(_update_preview_split_handle)
	if not palette_module.visibility_changed.is_connected(_update_preview_split_handle):
		palette_module.visibility_changed.connect(_update_preview_split_handle)
	if not surface.dock_host.resized.is_connected(_update_preview_split_handle):
		surface.dock_host.resized.connect(_update_preview_split_handle)
	_update_preview_split_handle.call_deferred()


func _draw_preview_split_handle() -> void:
	if not is_instance_valid(_preview_split_handle):
		return
	var mode := Stage4.active_mode()
	if mode == Tokens.LEGACY:
		return
	var sz := _preview_split_handle.size
	var mid_y := 8.0
	var dot_col := Tokens.color(mode, &"text_muted")
	var cx := roundi(sz.x * 0.5)
	var cy := roundi(mid_y)
	var pill_w := 34.0
	var pill_h := 6.0
	var pill_col := Tokens.color(mode, &"accent_soft")
	pill_col.a = 0.92
	_preview_split_handle.draw_rect(
		Rect2(Vector2((sz.x - pill_w) * 0.5, mid_y - pill_h * 0.5), Vector2(pill_w, pill_h)),
		pill_col
	)
	for dot_index in range(-1, 2):
		var x := cx + dot_index * 7 - 1
		_preview_split_handle.draw_rect(Rect2i(x, cy - 1, 3, 2), dot_col)


func _update_preview_split_handle() -> void:
	if not active or not is_instance_valid(_preview_split_handle):
		return
	var preview_module := surface.manager.get_instance(Builtins.PREVIEW_ID)
	var palette_module := surface.manager.get_instance(Builtins.PALETTE_ID)
	if preview_module == null or palette_module == null:
		_preview_split_handle.visible = false
		return
	var visible_pair := (
		preview_module.is_visible_in_tree()
		and palette_module.is_visible_in_tree()
		and surface.get_module_placement(Builtins.PREVIEW_ID) == WorkspaceSurface.Placement.DOCKED
		and surface.get_module_placement(Builtins.PALETTE_ID) == WorkspaceSurface.Placement.DOCKED
	)
	_preview_split_handle.visible = visible_pair
	if not visible_pair:
		return
	var host := surface.dock_host
	var seam_global := palette_module.get_global_transform_with_canvas() * Vector2(0.0, 0.0)
	var seam_host := host.get_global_transform_with_canvas().affine_inverse() * seam_global
	var handle_w := maxf(40.0, palette_module.size.x - WorkspaceModule.INTERACTION_TARGET_SIZE)
	var header_h := palette_module.get_header_height()
	var top_pad := 6.0
	var handle_h := maxf(PREVIEW_SPLIT_GRAB_HEIGHT, top_pad + header_h)
	_preview_split_handle.position = Vector2(seam_host.x, seam_host.y - top_pad)
	_preview_split_handle.size = Vector2(handle_w, handle_h)
	_preview_split_handle.queue_redraw()


static func _handle_contains_viewport_point(handle: Control, viewport_pos: Vector2) -> bool:
	if not is_instance_valid(handle) or not handle.is_visible_in_tree():
		return false
	var local_pos: Vector2 = (
		handle.get_global_transform_with_canvas().affine_inverse() * viewport_pos
	)
	return Rect2(Vector2.ZERO, handle.size).has_point(local_pos)


func _viewport_y_to_host(viewport_pos: Vector2) -> float:
	if surface == null or not is_instance_valid(surface.dock_host):
		return viewport_pos.y
	return (surface.dock_host.get_global_transform_with_canvas().affine_inverse() * viewport_pos).y


func _resolve_layout_store() -> WorkspaceLayoutStore:
	var parent := get_parent()
	if parent != null:
		var candidate: Variant = parent.get(&"layout_store")
		if candidate is WorkspaceLayoutStore:
			return candidate as WorkspaceLayoutStore
	return null


func _begin_preview_split_drag(viewport_pos: Vector2) -> void:
	_preview_split_start_y = _viewport_y_to_host(viewport_pos)
	var cur := surface.dock_host.layout.get_module_size(Builtins.PREVIEW_ID)
	var start_h := cur.y if cur != Vector2.ZERO else _saved_preview_height()
	var preview_module := surface.manager.get_instance(Builtins.PREVIEW_ID)
	if preview_module != null and preview_module.size.y > 0.0:
		start_h = preview_module.size.y
	_preview_split_start_height = start_h
	_preview_split_transient_store = _resolve_layout_store()
	if _preview_split_transient_store != null:
		_preview_split_transient_store.begin_transient_update()


func _update_preview_split_drag(viewport_pos: Vector2) -> void:
	var delta_y := _viewport_y_to_host(viewport_pos) - _preview_split_start_y
	_set_preview_split_height(_preview_split_start_height + delta_y, false)


func _end_preview_split_drag() -> void:
	if surface != null and surface.dock_host != null:
		var preview_module := surface.manager.get_instance(Builtins.PREVIEW_ID)
		var cur := surface.dock_host.layout.get_module_size(Builtins.PREVIEW_ID)
		var final_h := cur.y if cur != Vector2.ZERO else _saved_preview_height()
		if preview_module != null and preview_module.size.y > 0.0:
			final_h = maxf(final_h, preview_module.size.y)
		Global.config_cache.set_value("ui4", "preview_height", final_h)
	if _preview_split_transient_store != null:
		var store := _preview_split_transient_store
		_preview_split_transient_store = null
		store.end_transient_update()
		store.save_current_layout()


func _on_preview_split_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed and not _preview_split_drag_mouse:
				_preview_split_drag_mouse = true
				_begin_preview_split_drag(button.global_position)
			elif not button.pressed and _preview_split_drag_mouse:
				_preview_split_drag_mouse = false
				_end_preview_split_drag()
			_preview_split_handle.accept_event()
	elif event is InputEventMouseMotion and _preview_split_drag_mouse:
		_update_preview_split_drag((event as InputEventMouseMotion).global_position)
		_preview_split_handle.accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not touch.canceled and _preview_split_drag_touch == -1:
			_preview_split_drag_touch = touch.index
			_begin_preview_split_drag(touch.position)
		elif (not touch.pressed or touch.canceled) and _preview_split_drag_touch == touch.index:
			_preview_split_drag_touch = -1
			_end_preview_split_drag()
		_preview_split_handle.accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _preview_split_drag_touch:
			_update_preview_split_drag(drag.position)
			_preview_split_handle.accept_event()


func _adjust_preview_split(delta_y: float) -> void:
	if surface == null or surface.dock_host == null:
		return
	var cur := surface.dock_host.layout.get_module_size(Builtins.PREVIEW_ID)
	var base_h := cur.y if cur != Vector2.ZERO else _saved_preview_height()
	var preview_module := surface.manager.get_instance(Builtins.PREVIEW_ID)
	if preview_module != null and preview_module.size.y > 0.0:
		base_h = preview_module.size.y
	_set_preview_split_height(base_h + delta_y, true)


func _set_preview_split_height(target_h: float, persist: bool) -> void:
	if surface == null or surface.dock_host == null:
		return
	var left_host := surface.dock_host.get_zone_host(WorkspaceDockLayout.DockZone.LEFT)
	var cur := surface.dock_host.layout.get_module_size(Builtins.PREVIEW_ID)
	var cur_w := cur.x if cur != Vector2.ZERO else LEFT_WIDTH
	var max_h := maxf(
		PREVIEW_MIN_HEIGHT, (left_host.size.y if left_host != null else 640.0) - PALETTE_MIN_HEIGHT
	)
	var next_h := clampf(target_h, PREVIEW_MIN_HEIGHT, max_h)
	if cur != Vector2.ZERO and is_equal_approx(next_h, cur.y):
		return
	surface.dock_host.set_module_size(Builtins.PREVIEW_ID, Vector2(cur_w, next_h))
	if persist:
		Global.config_cache.set_value("ui4", "preview_height", next_h)
	_update_preview_split_handle.call_deferred()
	_update_split_handle.call_deferred()


func _input(event: InputEvent) -> void:
	if not active:
		return
	if (
		not _preview_split_drag_mouse
		and _preview_split_drag_touch < 0
		and not _split_drag_mouse
		and _split_drag_touch < 0
	):
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed and not touch.canceled:
				if _handle_contains_viewport_point(_preview_split_handle, touch.position):
					_preview_split_drag_touch = touch.index
					_begin_preview_split_drag(touch.position)
					get_viewport().set_input_as_handled()
					return
				if _handle_contains_viewport_point(_split_handle, touch.position):
					_split_drag_touch = touch.index
					get_viewport().set_input_as_handled()
					return
		elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				if _handle_contains_viewport_point(_preview_split_handle, mb.position):
					_preview_split_drag_mouse = true
					_begin_preview_split_drag(mb.position)
					get_viewport().set_input_as_handled()
					return
				if _handle_contains_viewport_point(_split_handle, mb.position):
					_split_drag_mouse = true
					get_viewport().set_input_as_handled()
					return
	if _preview_split_drag_mouse:
		if event is InputEventMouseMotion:
			_update_preview_split_drag((event as InputEventMouseMotion).position)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				_preview_split_drag_mouse = false
				_end_preview_split_drag()
				get_viewport().set_input_as_handled()
		return
	if _preview_split_drag_touch >= 0:
		if event is InputEventScreenDrag:
			var drag := event as InputEventScreenDrag
			if drag.index == _preview_split_drag_touch:
				_update_preview_split_drag(drag.position)
				get_viewport().set_input_as_handled()
		elif event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if (not touch.pressed or touch.canceled) and touch.index == _preview_split_drag_touch:
				_preview_split_drag_touch = -1
				_end_preview_split_drag()
				get_viewport().set_input_as_handled()
		return
	if _split_drag_mouse:
		if event is InputEventMouseMotion:
			_adjust_split((event as InputEventMouseMotion).relative.y)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				_split_drag_mouse = false
				get_viewport().set_input_as_handled()
		return
	if _split_drag_touch >= 0:
		if event is InputEventScreenDrag:
			var drag := event as InputEventScreenDrag
			if drag.index == _split_drag_touch:
				_adjust_split(drag.relative.y)
				get_viewport().set_input_as_handled()
		elif event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if not touch.pressed and touch.index == _split_drag_touch:
				_split_drag_touch = -1
				get_viewport().set_input_as_handled()
