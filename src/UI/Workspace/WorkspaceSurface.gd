class_name WorkspaceSurface
extends Node

## P2-C placement controller layered on top of the deterministic P2-B dock host.
##
## The surface owns transient floating/collapsed state while WorkspaceDockLayout
## remains a pure four-zone dock model. Persistence is layered on by P2-D and
## existing editor panels remain untouched until P2-G.

signal module_docked(module_id: StringName, zone: int, index: int)
signal module_floated(module_id: StringName, rect: Rect2)
signal module_collapsed(module_id: StringName)
signal module_peek_changed(module_id: StringName, peeking: bool)
signal module_restored(module_id: StringName, placement: int)
signal module_cleared(module_id: StringName)
signal surface_preview_changed(candidate: Dictionary)
signal surface_drag_finished(module_id: StringName, committed: bool)

enum Placement {
	NONE,
	DOCKED,
	FLOATING,
	COLLAPSED,
}

const PREVIEW_COLOR := Color(1.0, 1.0, 1.0, 0.14)
const REGION_TARGET_HYSTERESIS := 48.0
const FLOATING_SNAP_DISTANCE := 24.0
const FLOATING_SNAP_MARGIN := 8.0

enum FloatingSnapEdge {
	NONE = 0,
	LEFT = 1,
	RIGHT = 2,
	TOP = 4,
	BOTTOM = 8,
}

var manager: WorkspaceModuleManager
var dock_host: WorkspaceDockHost

var _floating_layer: Control
var _peek_layer: Control
var _context_hidden_layer: Control
var _preview: ColorRect
var _placements: Dictionary = {}
var _floating_rects: Dictionary = {}
var _last_floating_rects: Dictionary = {}
var _collapsed_restore: Dictionary = {}
var _peeking: Dictionary = {}
var _drag_module_id: StringName = &""
var _drag_origin: Dictionary = {}
var _drag_candidate: Dictionary = {}
var _drag_started_from_dock := false
var _drag_pointer_offset := Vector2.ZERO
var _floating_snap_policy_enabled := false
var _fixed_dock_zones: Dictionary = {}
var _floating_anchors: Dictionary = {}


func setup(module_manager: WorkspaceModuleManager, existing_dock_host: WorkspaceDockHost) -> bool:
	if module_manager == null or existing_dock_host == null or manager != null:
		return false
	if existing_dock_host.manager != module_manager or existing_dock_host.layout == null:
		return false
	manager = module_manager
	dock_host = existing_dock_host
	_ensure_layers()
	return true


func configure_floating_snap_policy(fixed_dock_zones: Dictionary) -> void:
	_floating_snap_policy_enabled = true
	_fixed_dock_zones.clear()
	for raw_id: Variant in fixed_dock_zones:
		var module_id := raw_id as StringName
		var zone := int(fixed_dock_zones[raw_id])
		if dock_host != null and dock_host.layout != null and dock_host.layout.is_valid_zone(zone):
			_fixed_dock_zones[module_id] = zone


func is_fixed_dock_module(module_id: StringName) -> bool:
	return _floating_snap_policy_enabled and _fixed_dock_zones.has(module_id)


func get_floating_bounds() -> Rect2:
	if dock_host == null:
		return Rect2()
	var bounds := dock_host.get_content_rect()
	if not bounds.has_area():
		bounds = Rect2(Vector2.ZERO, dock_host.size)
	var margin := 0.0
	if _floating_snap_policy_enabled:
		margin = minf(
			FLOATING_SNAP_MARGIN,
			minf(bounds.size.x, bounds.size.y) * 0.25,
		)
	return Rect2(
		bounds.position + Vector2.ONE * margin,
		Vector2(
			maxf(0.0, bounds.size.x - margin * 2.0),
			maxf(0.0, bounds.size.y - margin * 2.0),
		),
	)


func refresh_floating_bounds() -> void:
	if not _is_ready():
		return
	for module_id in _floating_rects.keys():
		if get_module_placement(module_id) != Placement.FLOATING:
			continue
		var current := get_floating_rect(module_id)
		if not current.has_area():
			continue
		var anchored := _apply_saved_anchor(module_id, current)
		var rect := _constrain_floating_rect(module_id, anchored, false)
		if rect == current:
			continue
		_apply_floating_rect(module_id, rect)
		_floating_rects[module_id] = rect
		_last_floating_rects[module_id] = rect


func park_module(module_id: StringName) -> bool:
	if not _is_ready() or not is_instance_valid(_context_hidden_layer):
		return false
	var module := manager.get_instance(module_id)
	if module == null:
		return false
	var placement := get_module_placement(module_id)
	if placement == Placement.COLLAPSED:
		if is_peeking(module_id) and not end_peek(module_id):
			return false
		if module.is_content_collapsed():
			module.set_content_collapsed(false)
		var restore: Dictionary = _collapsed_restore.get(module_id, {})
		placement = int(restore.get("placement", Placement.NONE))
	if placement == Placement.DOCKED:
		if dock_host.layout.get_module_zone(module_id) != WorkspaceDockLayout.DockZone.NONE:
			if not dock_host.undock_module(module_id):
				return false
	elif placement == Placement.FLOATING:
		var floating_rect := get_floating_rect(module_id)
		if floating_rect.has_area():
			_last_floating_rects[module_id] = floating_rect
		if module.get_parent() != null and not manager.unmount_module(module_id):
			return false
	elif module.get_parent() != null and module.get_parent() != _context_hidden_layer:
		if not manager.unmount_module(module_id):
			return false

	if module.get_parent() != _context_hidden_layer:
		if manager.mount_module(module_id, _context_hidden_layer) == null:
			return false
	if module.get_lifecycle_state() == WorkspaceModule.LifecycleState.MOUNTED:
		if not manager.activate_module(module_id):
			return false

	_placements.erase(module_id)
	_floating_rects.erase(module_id)
	_floating_anchors.erase(module_id)
	_collapsed_restore.erase(module_id)
	_peeking.erase(module_id)
	module_cleared.emit(module_id)
	return true


func is_module_parked(module_id: StringName) -> bool:
	var module := manager.get_instance(module_id) if manager != null else null
	return module != null and module.get_parent() == _context_hidden_layer


func dock_module(
	module_id: StringName,
	zone: int,
	index: int = -1,
	requested_size: Vector2 = Vector2.ZERO,
	context: Dictionary = {},
	region_fill: bool = false
) -> bool:
	if not _is_ready() or not dock_host.layout.is_valid_zone(zone):
		return false
	if _floating_snap_policy_enabled:
		if is_fixed_dock_module(module_id):
			zone = int(_fixed_dock_zones[module_id])
			index = 0
			region_fill = true
		else:
			if not _can_float(module_id):
				return false
			return float_module(
				module_id,
				_legacy_dock_to_floating_rect(module_id, zone, index, requested_size),
				context,
			)
	if not dock_host.layout.can_dock_module(module_id):
		return false
	if get_module_placement(module_id) == Placement.COLLAPSED and is_peeking(module_id):
		if not end_peek(module_id):
			return false

	var previous_placement := get_module_placement(module_id)
	var previous_rect := get_floating_rect(module_id)
	if previous_placement == Placement.FLOATING and previous_rect.has_area():
		_last_floating_rects[module_id] = previous_rect
	var module := manager.get_instance(module_id)
	if module != null and module.get_parent() == _floating_layer:
		if not manager.unmount_module(module_id):
			return false

	if not dock_host.dock_module(module_id, zone, index, requested_size, context, region_fill):
		if previous_placement == Placement.FLOATING:
			_restore_floating_parent(module_id, previous_rect, context)
		return false

	_placements[module_id] = Placement.DOCKED
	_floating_rects.erase(module_id)
	_collapsed_restore.erase(module_id)
	_peeking.erase(module_id)
	module_docked.emit(module_id, zone, dock_host.layout.get_module_index(module_id))
	return true


func float_module(module_id: StringName, requested_rect: Rect2, context: Dictionary = {}) -> bool:
	if not _is_ready():
		return false
	if is_fixed_dock_module(module_id):
		var fixed_zone := int(_fixed_dock_zones[module_id])
		return dock_module(module_id, fixed_zone, 0, requested_rect.size, context, true)
	if not _can_float(module_id):
		return false
	if get_module_placement(module_id) == Placement.COLLAPSED and is_peeking(module_id):
		if not end_peek(module_id):
			return false

	var module := manager.create_module(module_id, context)
	if module == null:
		return false
	var old_dock := _capture_dock_state(module_id)
	var current_zone := dock_host.layout.get_module_zone(module_id)
	if current_zone != WorkspaceDockLayout.DockZone.NONE:
		if not dock_host.undock_module(module_id):
			return false
	elif module.get_parent() != null and module.get_parent() != _floating_layer:
		if not manager.unmount_module(module_id):
			return false

	if module.get_parent() != _floating_layer:
		if manager.mount_module(module_id, _floating_layer, context) == null:
			_restore_dock_after_failed_float(module_id, old_dock, context)
			return false
		if not manager.activate_module(module_id):
			manager.unmount_module(module_id)
			_restore_dock_after_failed_float(module_id, old_dock, context)
			return false
	elif module.get_lifecycle_state() == WorkspaceModule.LifecycleState.MOUNTED:
		if not manager.activate_module(module_id):
			return false

	var rect := _constrain_floating_rect(module_id, requested_rect)
	_apply_floating_rect(module_id, rect)
	_placements[module_id] = Placement.FLOATING
	_floating_rects[module_id] = rect
	_last_floating_rects[module_id] = rect
	_floating_anchors[module_id] = _detect_snap_edges(rect)
	_collapsed_restore.erase(module_id)
	_peeking.erase(module_id)
	module_floated.emit(module_id, rect)
	return true


func collapse_module(module_id: StringName) -> bool:
	if not _is_ready() or not _can_collapse(module_id):
		return false
	var placement := get_module_placement(module_id)
	if placement != Placement.DOCKED and placement != Placement.FLOATING:
		return false

	var module := manager.get_instance(module_id)
	if module == null:
		return false
	if placement == Placement.DOCKED:
		var zone := dock_host.layout.get_module_zone(module_id)
		if (
			zone == WorkspaceDockLayout.DockZone.NONE
			or module.get_parent() != dock_host.get_zone_host(zone)
		):
			return false
	elif module.get_parent() != _floating_layer:
		return false

	var restore := _capture_restore_state(module_id, placement)
	module.set_content_collapsed(true)
	_placements[module_id] = Placement.COLLAPSED
	_floating_rects.erase(module_id)
	_collapsed_restore[module_id] = restore
	_peeking.erase(module_id)

	if placement == Placement.FLOATING:
		_apply_floating_collapsed_rect(module_id, restore.get("rect", Rect2()) as Rect2)
	else:
		dock_host.refresh_layout_geometry()

	module_collapsed.emit(module_id)
	return true


func peek_module(module_id: StringName) -> bool:
	if (
		not _is_ready()
		or get_module_placement(module_id) != Placement.COLLAPSED
		or is_in_place_collapsed(module_id)
	):
		return false
	if is_peeking(module_id):
		return true
	var module := manager.get_instance(module_id)
	if module == null or module.get_parent() != null:
		return false
	if manager.mount_module(module_id, _peek_layer) == null:
		return false
	if not manager.activate_module(module_id):
		manager.unmount_module(module_id)
		return false

	var definition := manager.get_definition(module_id)
	var restore: Dictionary = _collapsed_restore.get(module_id, {})
	var peek_rect := _peek_rect_for_restore(module_id, restore)
	module.custom_minimum_size = definition.minimum_size
	module.position = peek_rect.position
	module.size = peek_rect.size
	module.move_to_front()
	_peeking[module_id] = true
	module_peek_changed.emit(module_id, true)
	return true


func end_peek(module_id: StringName) -> bool:
	if not is_peeking(module_id):
		return false
	var module := manager.get_instance(module_id)
	if module == null or module.get_parent() != _peek_layer:
		_peeking.erase(module_id)
		return false
	if not manager.unmount_module(module_id):
		return false
	_peeking.erase(module_id)
	module_peek_changed.emit(module_id, false)
	return true


func restore_module(module_id: StringName) -> bool:
	if not _is_ready() or get_module_placement(module_id) != Placement.COLLAPSED:
		return false
	var restore: Dictionary = (_collapsed_restore.get(module_id, {}) as Dictionary).duplicate(true)
	if restore.is_empty():
		return false
	if is_peeking(module_id) and not end_peek(module_id):
		return false

	var module := manager.get_instance(module_id)
	if module == null or not module.is_content_collapsed():
		return false

	var restore_placement := int(restore.get("placement", Placement.NONE))
	if restore_placement == Placement.DOCKED:
		var zone := int(restore.get("zone", WorkspaceDockLayout.DockZone.NONE))
		if (
			dock_host.layout.get_module_zone(module_id) != zone
			or module.get_parent() != dock_host.get_zone_host(zone)
		):
			return false
		module.set_content_collapsed(false)
		if not dock_host.set_module_size(module_id, restore.get("size", Vector2.ZERO) as Vector2):
			module.set_content_collapsed(true)
			dock_host.refresh_layout_geometry()
			return false
		_placements[module_id] = Placement.DOCKED
		_floating_rects.erase(module_id)
	elif restore_placement == Placement.FLOATING:
		if module.get_parent() != _floating_layer:
			return false
		var rect := _constrain_floating_rect(module_id, restore.get("rect", Rect2()) as Rect2)
		module.set_content_collapsed(false)
		_apply_floating_rect(module_id, rect)
		_placements[module_id] = Placement.FLOATING
		_floating_rects[module_id] = rect
		_floating_anchors[module_id] = _detect_snap_edges(rect)
	else:
		return false

	_collapsed_restore.erase(module_id)
	_peeking.erase(module_id)
	module_restored.emit(module_id, restore_placement)
	return true


func set_floating_rect(module_id: StringName, requested_rect: Rect2) -> bool:
	if get_module_placement(module_id) != Placement.FLOATING:
		return false
	var rect := _constrain_floating_rect(module_id, requested_rect)
	_apply_floating_rect(module_id, rect)
	_floating_rects[module_id] = rect
	_last_floating_rects[module_id] = rect
	_floating_anchors[module_id] = _detect_snap_edges(rect)
	module_floated.emit(module_id, rect)
	return true


func resize_floating_rect(
	module_id: StringName, start_rect: Rect2, delta: Vector2, resize_edges: int
) -> bool:
	if get_module_placement(module_id) != Placement.FLOATING:
		return false
	var definition := manager.get_definition(module_id) if manager != null else null
	if definition == null or not start_rect.has_area():
		return false

	var requested_size := start_rect.size
	if resize_edges & WorkspaceModule.ResizeEdge.LEFT:
		requested_size.x = start_rect.size.x - delta.x
	elif resize_edges & WorkspaceModule.ResizeEdge.RIGHT:
		requested_size.x = start_rect.size.x + delta.x
	if resize_edges & WorkspaceModule.ResizeEdge.TOP:
		requested_size.y = start_rect.size.y - delta.y
	elif resize_edges & WorkspaceModule.ResizeEdge.BOTTOM:
		requested_size.y = start_rect.size.y + delta.y

	var target_size := definition.get_constrained_size(requested_size)
	var bounds := get_floating_bounds()
	if bounds.size.x > 0.0:
		target_size.x = minf(target_size.x, bounds.size.x)
	if bounds.size.y > 0.0:
		target_size.y = minf(target_size.y, bounds.size.y)

	var target_position := start_rect.position
	if resize_edges & WorkspaceModule.ResizeEdge.LEFT:
		target_position.x = start_rect.end.x - target_size.x
	if resize_edges & WorkspaceModule.ResizeEdge.TOP:
		target_position.y = start_rect.end.y - target_size.y
	var rect := Rect2(target_position, target_size)
	return set_floating_rect(module_id, rect)


func get_docked_resize_edges(module_id: StringName, local_point: Vector2) -> int:
	if get_module_placement(module_id) != Placement.DOCKED or dock_host == null:
		return WorkspaceModule.ResizeEdge.NONE
	var module := manager.get_instance(module_id)
	if module == null or module.is_content_collapsed():
		return WorkspaceModule.ResizeEdge.NONE
	var hit := WorkspaceModule.RESIZE_EDGE_HIT_SIZE
	var zone := dock_host.layout.get_module_zone(module_id)
	var region_fill := dock_host.layout.is_module_region_fill(module_id)
	var edges := WorkspaceModule.ResizeEdge.NONE
	match zone:
		WorkspaceDockLayout.DockZone.BOTTOM:
			if local_point.y <= hit:
				edges |= WorkspaceModule.ResizeEdge.TOP
			if not region_fill and local_point.x >= module.size.x - hit:
				edges |= WorkspaceModule.ResizeEdge.RIGHT
		WorkspaceDockLayout.DockZone.TOP:
			if local_point.y >= module.size.y - hit:
				edges |= WorkspaceModule.ResizeEdge.BOTTOM
			if not region_fill and local_point.x >= module.size.x - hit:
				edges |= WorkspaceModule.ResizeEdge.RIGHT
		WorkspaceDockLayout.DockZone.LEFT:
			if local_point.x >= module.size.x - hit:
				edges |= WorkspaceModule.ResizeEdge.RIGHT
			if not region_fill and local_point.y >= module.size.y - hit:
				edges |= WorkspaceModule.ResizeEdge.BOTTOM
		WorkspaceDockLayout.DockZone.RIGHT:
			if local_point.x <= hit:
				edges |= WorkspaceModule.ResizeEdge.LEFT
			if not region_fill and local_point.y >= module.size.y - hit:
				edges |= WorkspaceModule.ResizeEdge.BOTTOM
	return edges


func resize_docked_module(
	module_id: StringName, start_size: Vector2, delta: Vector2, resize_edges: int
) -> bool:
	if get_module_placement(module_id) != Placement.DOCKED or dock_host == null:
		return false
	var requested := start_size
	if resize_edges & WorkspaceModule.ResizeEdge.TOP:
		requested.y = start_size.y - delta.y
	elif resize_edges & WorkspaceModule.ResizeEdge.BOTTOM:
		requested.y = start_size.y + delta.y
	if resize_edges & WorkspaceModule.ResizeEdge.LEFT:
		requested.x = start_size.x - delta.x
	elif resize_edges & WorkspaceModule.ResizeEdge.RIGHT:
		requested.x = start_size.x + delta.x
	return dock_host.set_module_size(module_id, requested)


func float_from_dock(module_id: StringName) -> bool:
	if get_module_placement(module_id) != Placement.DOCKED or not _can_float(module_id):
		return false
	var module := manager.get_instance(module_id)
	var definition := manager.get_definition(module_id)
	if module == null or definition == null or module.is_content_collapsed():
		return false

	var rect := _last_floating_rects.get(module_id, Rect2()) as Rect2
	if not rect.has_area():
		var position := module.position
		var parent := module.get_parent() as Control
		if parent != null:
			position += parent.position
		rect = Rect2(position, definition.get_constrained_preferred_size())
	return float_module(module_id, rect)


func clear_module_placement(module_id: StringName) -> bool:
	if not _is_ready():
		return false
	if _drag_module_id == module_id:
		cancel_module_drag()
	var placement := get_module_placement(module_id)
	if placement == Placement.NONE:
		_placements.erase(module_id)
		_floating_rects.erase(module_id)
		_floating_anchors.erase(module_id)
		_collapsed_restore.erase(module_id)
		_peeking.erase(module_id)
		return true
	if is_peeking(module_id) and not end_peek(module_id):
		return false

	if placement == Placement.DOCKED:
		if dock_host.layout.get_module_zone(module_id) != WorkspaceDockLayout.DockZone.NONE:
			if not dock_host.undock_module(module_id):
				return false
	elif placement == Placement.FLOATING:
		var module := manager.get_instance(module_id)
		if module != null and module.get_parent() != null:
			if not manager.unmount_module(module_id):
				return false
	elif placement == Placement.COLLAPSED:
		var module := manager.get_instance(module_id)
		var restore: Dictionary = _collapsed_restore.get(module_id, {})
		var restore_placement := int(restore.get("placement", Placement.NONE))
		if module != null and module.is_content_collapsed():
			module.set_content_collapsed(false)
		if restore_placement == Placement.DOCKED:
			if dock_host.layout.get_module_zone(module_id) != WorkspaceDockLayout.DockZone.NONE:
				if not dock_host.undock_module(module_id):
					return false
		elif module != null and module.get_parent() != null:
			if not manager.unmount_module(module_id):
				return false

	_placements.erase(module_id)
	_floating_rects.erase(module_id)
	_floating_anchors.erase(module_id)
	_collapsed_restore.erase(module_id)
	_peeking.erase(module_id)
	module_cleared.emit(module_id)
	return true


func begin_module_drag(module_id: StringName, pointer: Vector2 = Vector2.ZERO) -> bool:
	if not _is_ready() or _drag_module_id != &"":
		return false
	if is_fixed_dock_module(module_id):
		return false
	var placement := get_module_placement(module_id)
	if placement != Placement.DOCKED and placement != Placement.FLOATING:
		return false
	if placement == Placement.FLOATING and not _can_float(module_id):
		return false

	_drag_module_id = module_id
	_drag_origin = _capture_restore_state(module_id, placement)
	_drag_candidate = {}
	_drag_started_from_dock = placement == Placement.DOCKED
	if _drag_started_from_dock:
		if not dock_host.begin_module_drag(module_id):
			_clear_drag_state()
			return false
		var module := manager.get_instance(module_id)
		var parent := module.get_parent() as Control if module != null else null
		if module != null and parent != null:
			var module_origin := parent.position + module.position
			var local_offset := pointer - module_origin
			_drag_pointer_offset = Vector2(
				clampf(local_offset.x, 0.0, module.size.x),
				clampf(local_offset.y, 0.0, module.size.y)
			)
		else:
			_drag_pointer_offset = dock_host.layout.get_module_size(module_id) * 0.5
	else:
		var rect := get_floating_rect(module_id)
		if rect.has_point(pointer):
			_drag_pointer_offset = pointer - rect.position
		else:
			_drag_pointer_offset = rect.size * 0.5
	_hide_surface_preview()
	return true


func update_module_drag(pointer: Vector2) -> Dictionary:
	if _drag_module_id == &"":
		return _invalid_candidate()
	if _floating_snap_policy_enabled and not is_fixed_dock_module(_drag_module_id):
		_drag_candidate = _floating_candidate_for_pointer(pointer)
	else:
		var dock_candidate := _dock_candidate_for_pointer(pointer)
		if bool(dock_candidate.get("valid", false)):
			_drag_candidate = dock_candidate
		else:
			_drag_candidate = _floating_candidate_for_pointer(pointer)
	_show_surface_candidate(_drag_candidate)
	surface_preview_changed.emit(_drag_candidate.duplicate(true))
	return _drag_candidate.duplicate(true)


func commit_module_drag() -> bool:
	if _drag_module_id == &"":
		return false
	var module_id := _drag_module_id
	var candidate := _drag_candidate.duplicate(true)
	if _drag_started_from_dock:
		dock_host.cancel_module_drag()

	var committed := false
	if bool(candidate.get("valid", false)):
		var placement := int(candidate.get("placement", Placement.NONE))
		if placement == Placement.DOCKED:
			committed = dock_module(
				module_id,
				int(candidate.get("zone", WorkspaceDockLayout.DockZone.NONE)),
				int(candidate.get("index", -1)),
				_get_drag_size(module_id),
				{},
				StringName(candidate.get("target_kind", &"none")) == &"region"
			)
		elif placement == Placement.FLOATING:
			committed = float_module(module_id, candidate.get("rect", Rect2()) as Rect2)
	_finish_drag(committed)
	return committed


func cancel_module_drag() -> void:
	if _drag_module_id == &"":
		return
	if _drag_started_from_dock:
		dock_host.cancel_module_drag()
	_finish_drag(false)


func get_module_placement(module_id: StringName) -> int:
	if _placements.has(module_id):
		return int(_placements[module_id])
	if dock_host != null and dock_host.layout != null:
		if dock_host.layout.get_module_zone(module_id) != WorkspaceDockLayout.DockZone.NONE:
			return Placement.DOCKED
	return Placement.NONE


func get_floating_rect(module_id: StringName) -> Rect2:
	return _floating_rects.get(module_id, Rect2()) as Rect2


func get_restore_state(module_id: StringName) -> Dictionary:
	return (_collapsed_restore.get(module_id, {}) as Dictionary).duplicate(true)


func is_peeking(module_id: StringName) -> bool:
	return bool(_peeking.get(module_id, false))


func is_floating_collapsed(module_id: StringName) -> bool:
	if get_module_placement(module_id) != Placement.COLLAPSED:
		return false
	var restore: Dictionary = _collapsed_restore.get(module_id, {})
	if int(restore.get("placement", Placement.NONE)) != Placement.FLOATING:
		return false
	var module := manager.get_instance(module_id) if manager != null else null
	return module != null and module.get_parent() == _floating_layer


func is_in_place_collapsed(module_id: StringName) -> bool:
	if get_module_placement(module_id) != Placement.COLLAPSED:
		return false
	var module := manager.get_instance(module_id) if manager != null else null
	return module != null and module.is_content_collapsed() and module.get_parent() != null


func get_floating_layer() -> Control:
	return _floating_layer


func get_peek_layer() -> Control:
	return _peek_layer


func get_preview_rect() -> Rect2:
	if is_instance_valid(_preview) and _preview.visible:
		return Rect2(_preview.position, _preview.size)
	if dock_host != null:
		return dock_host.get_preview_rect()
	return Rect2()


static func placement_name(placement: int) -> StringName:
	match placement:
		Placement.DOCKED:
			return &"docked"
		Placement.FLOATING:
			return &"floating"
		Placement.COLLAPSED:
			return &"collapsed"
		_:
			return &"none"


func _ensure_layers() -> void:
	if is_instance_valid(_floating_layer):
		return
	_floating_layer = Control.new()
	_floating_layer.name = "WorkspaceFloatingLayer"
	_floating_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock_host.add_child(_floating_layer)
	_floating_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_peek_layer = Control.new()
	_peek_layer.name = "WorkspacePeekLayer"
	_peek_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock_host.add_child(_peek_layer)
	_peek_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_context_hidden_layer = Control.new()
	_context_hidden_layer.name = "WorkspaceContextHiddenLayer"
	_context_hidden_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_context_hidden_layer.visible = false
	dock_host.add_child(_context_hidden_layer)
	_context_hidden_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_preview = ColorRect.new()
	_preview.name = "WorkspaceSurfacePreview"
	_preview.color = PREVIEW_COLOR
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.visible = false
	dock_host.add_child(_preview)
	_preview.move_to_front()


func _capture_dock_state(module_id: StringName) -> Dictionary:
	if dock_host.layout.get_module_zone(module_id) == WorkspaceDockLayout.DockZone.NONE:
		return {}
	return {
		"zone": dock_host.layout.get_module_zone(module_id),
		"index": dock_host.layout.get_module_index(module_id),
		"size": dock_host.layout.get_module_size(module_id),
		"region_fill": dock_host.layout.is_module_region_fill(module_id),
	}


func _capture_restore_state(module_id: StringName, placement: int) -> Dictionary:
	if placement == Placement.DOCKED:
		var dock_state := _capture_dock_state(module_id)
		dock_state["placement"] = Placement.DOCKED
		return dock_state
	if placement == Placement.FLOATING:
		return {
			"placement": Placement.FLOATING,
			"rect": get_floating_rect(module_id),
		}
	return {}


func _dock_candidate_for_pointer(pointer: Vector2) -> Dictionary:
	var raw: Dictionary
	if _drag_started_from_dock:
		raw = dock_host.update_module_drag(pointer)
	else:
		raw = WorkspaceDockDragResolver.resolve(
			_drag_module_id,
			pointer,
			dock_host.get_zone_rects(),
			_collect_dock_module_rects(),
			dock_host.layout,
			dock_host.get_edge_snap_rects(),
			Rect2(Vector2.ZERO, dock_host.size)
		)
	raw = _stabilize_region_candidate(pointer, raw)
	if bool(raw.get("valid", false)):
		raw["placement"] = Placement.DOCKED
		return raw
	return _invalid_candidate()


func _stabilize_region_candidate(pointer: Vector2, candidate: Dictionary) -> Dictionary:
	if StringName(candidate.get("target_kind", &"none")) == &"region":
		return candidate
	if StringName(_drag_candidate.get("target_kind", &"none")) != &"region":
		return candidate
	var previous_zone := int(_drag_candidate.get("zone", WorkspaceDockLayout.DockZone.NONE))
	if not dock_host.layout.is_valid_zone(previous_zone):
		return candidate
	var sticky_rect: Rect2 = dock_host.get_edge_snap_rects().get(previous_zone, Rect2())
	var hysteresis := (
		0.0 if previous_zone == WorkspaceDockLayout.DockZone.TOP else REGION_TARGET_HYSTERESIS
	)
	sticky_rect = sticky_rect.grow(hysteresis)
	if not sticky_rect.has_point(pointer):
		return candidate
	var retained := _drag_candidate.duplicate(true)
	retained["valid"] = true
	retained["placement"] = Placement.DOCKED
	return retained


func _collect_dock_module_rects() -> Dictionary:
	var result: Dictionary = {}
	for zone in WorkspaceDockLayout.VALID_ZONES:
		var entries: Array = []
		var host := dock_host.get_zone_host(zone)
		for module_id in dock_host.layout.get_modules(zone):
			var module := manager.get_instance(module_id)
			if module == null or module.get_parent() != host:
				continue
			var entry := {
				"module_id": module_id,
				"rect": Rect2(host.position + module.position, module.size),
			}
			entries.append(entry)
		result[zone] = entries
	return result


func _floating_candidate_for_pointer(pointer: Vector2) -> Dictionary:
	if not _can_float(_drag_module_id):
		return _invalid_candidate()
	var rect := Rect2(pointer - _drag_pointer_offset, _get_drag_size(_drag_module_id))
	rect = _constrain_floating_rect(_drag_module_id, rect)
	return {
		"valid": true,
		"placement": Placement.FLOATING,
		"zone": WorkspaceDockLayout.DockZone.NONE,
		"index": -1,
		"rect": rect,
		"preview_rect": rect,
		"snap_edges": _detect_snap_edges(rect),
	}


func _get_drag_size(module_id: StringName) -> Vector2:
	var placement := int(_drag_origin.get("placement", get_module_placement(module_id)))
	if placement == Placement.DOCKED:
		return (
			_drag_origin.get("size", dock_host.layout.get_default_module_size(module_id)) as Vector2
		)
	if placement == Placement.FLOATING:
		var rect := _drag_origin.get("rect", get_floating_rect(module_id)) as Rect2
		return rect.size
	return dock_host.layout.get_default_module_size(module_id)


func _constrain_floating_rect(
	module_id: StringName, requested_rect: Rect2, allow_snap: bool = true
) -> Rect2:
	var definition := manager.get_definition(module_id) if manager != null else null
	if definition == null:
		return requested_rect
	var requested_size := requested_rect.size
	if requested_size == Vector2.ZERO:
		requested_size = definition.get_constrained_preferred_size()
	var target_size := definition.get_constrained_size(requested_size)
	var bounds := get_floating_bounds()
	if not bounds.has_area():
		return Rect2(requested_rect.position, target_size)
	target_size.x = minf(target_size.x, bounds.size.x)
	target_size.y = minf(target_size.y, bounds.size.y)
	var rect := Rect2(requested_rect.position, target_size)
	if allow_snap:
		rect = _snap_floating_rect(rect, bounds)
	return _clamp_rect_to_bounds(rect, bounds)


func _snap_floating_rect(rect: Rect2, bounds: Rect2) -> Rect2:
	var snapped := rect
	var left_gap := absf(rect.position.x - bounds.position.x)
	var right_gap := absf(rect.end.x - bounds.end.x)
	var top_gap := absf(rect.position.y - bounds.position.y)
	var bottom_gap := absf(rect.end.y - bounds.end.y)
	if minf(left_gap, right_gap) <= FLOATING_SNAP_DISTANCE:
		if left_gap <= right_gap:
			snapped.position.x = bounds.position.x
		else:
			snapped.position.x = bounds.end.x - snapped.size.x
	if minf(top_gap, bottom_gap) <= FLOATING_SNAP_DISTANCE:
		if top_gap <= bottom_gap:
			snapped.position.y = bounds.position.y
		else:
			snapped.position.y = bounds.end.y - snapped.size.y
	return snapped


func _clamp_rect_to_bounds(rect: Rect2, bounds: Rect2) -> Rect2:
	var max_position := Vector2(
		maxf(bounds.position.x, bounds.end.x - rect.size.x),
		maxf(bounds.position.y, bounds.end.y - rect.size.y),
	)
	return Rect2(
		Vector2(
			clampf(rect.position.x, bounds.position.x, max_position.x),
			clampf(rect.position.y, bounds.position.y, max_position.y),
		),
		rect.size,
	)


func _detect_snap_edges(rect: Rect2) -> int:
	var bounds := get_floating_bounds()
	if not bounds.has_area() or not rect.has_area():
		return FloatingSnapEdge.NONE
	var edges := FloatingSnapEdge.NONE
	if is_equal_approx(rect.position.x, bounds.position.x):
		edges |= FloatingSnapEdge.LEFT
	elif is_equal_approx(rect.end.x, bounds.end.x):
		edges |= FloatingSnapEdge.RIGHT
	if is_equal_approx(rect.position.y, bounds.position.y):
		edges |= FloatingSnapEdge.TOP
	elif is_equal_approx(rect.end.y, bounds.end.y):
		edges |= FloatingSnapEdge.BOTTOM
	return edges


func _apply_saved_anchor(module_id: StringName, rect: Rect2) -> Rect2:
	var bounds := get_floating_bounds()
	if not bounds.has_area():
		return rect
	var edges := int(_floating_anchors.get(module_id, FloatingSnapEdge.NONE))
	var anchored := rect
	if edges & FloatingSnapEdge.LEFT:
		anchored.position.x = bounds.position.x
	elif edges & FloatingSnapEdge.RIGHT:
		anchored.position.x = bounds.end.x - anchored.size.x
	if edges & FloatingSnapEdge.TOP:
		anchored.position.y = bounds.position.y
	elif edges & FloatingSnapEdge.BOTTOM:
		anchored.position.y = bounds.end.y - anchored.size.y
	return anchored


func _legacy_dock_to_floating_rect(
	module_id: StringName, zone: int, index: int, requested_size: Vector2
) -> Rect2:
	var definition := manager.get_definition(module_id) if manager != null else null
	if definition == null:
		return Rect2()
	var size := requested_size
	if size == Vector2.ZERO:
		size = definition.get_constrained_preferred_size()
	size = definition.get_constrained_size(size)
	var bounds := get_floating_bounds()
	if bounds.has_area():
		size.x = minf(size.x, bounds.size.x)
		size.y = minf(size.y, bounds.size.y)
	var position := bounds.position
	match zone:
		WorkspaceDockLayout.DockZone.LEFT:
			position.x = bounds.position.x
			position.y = _legacy_cross_axis_position(bounds, size, index, false)
		WorkspaceDockLayout.DockZone.RIGHT:
			position.x = bounds.end.x - size.x
			position.y = _legacy_cross_axis_position(bounds, size, index, false)
		WorkspaceDockLayout.DockZone.TOP:
			position.y = bounds.position.y
			position.x = _legacy_cross_axis_position(bounds, size, index, true)
		WorkspaceDockLayout.DockZone.BOTTOM:
			position.y = bounds.end.y - size.y
			position.x = _legacy_cross_axis_position(bounds, size, index, true)
		_:
			position = bounds.position
	return _clamp_rect_to_bounds(Rect2(position, size), bounds)


func _legacy_cross_axis_position(
	bounds: Rect2, size: Vector2, index: int, horizontal: bool
) -> float:
	var start := bounds.position.x if horizontal else bounds.position.y
	var end := bounds.end.x if horizontal else bounds.end.y
	var extent := size.x if horizontal else size.y
	if index <= 0:
		return start
	if index == 1:
		return end - extent
	return start + maxf(0.0, (end - start - extent) * 0.5)


func _apply_floating_rect(module_id: StringName, rect: Rect2) -> void:
	var module := manager.get_instance(module_id)
	var definition := manager.get_definition(module_id)
	if module == null or definition == null:
		return
	module.custom_minimum_size = definition.minimum_size
	module.position = rect.position
	module.size = rect.size
	module.move_to_front()
	_floating_layer.move_to_front()
	_peek_layer.move_to_front()
	_preview.move_to_front()


func _apply_floating_collapsed_rect(module_id: StringName, restore_rect: Rect2) -> void:
	var module := manager.get_instance(module_id)
	var definition := manager.get_definition(module_id)
	if module == null or definition == null:
		return
	var bounds := get_floating_bounds()
	var width := definition.get_constrained_size(restore_rect.size).x
	var header_height := module.get_header_height()
	if bounds.has_area():
		width = minf(width, bounds.size.x)
	var rect := Rect2(restore_rect.position, Vector2(width, header_height))
	rect = _apply_saved_anchor(module_id, rect)
	if bounds.has_area():
		rect = _clamp_rect_to_bounds(rect, bounds)
	module.custom_minimum_size = Vector2(minf(definition.minimum_size.x, width), header_height)
	module.position = rect.position
	module.size = rect.size
	module.move_to_front()
	_floating_layer.move_to_front()
	_peek_layer.move_to_front()
	_preview.move_to_front()


func _peek_rect_for_restore(module_id: StringName, restore: Dictionary) -> Rect2:
	var placement := int(restore.get("placement", Placement.NONE))
	if placement == Placement.FLOATING:
		return _constrain_floating_rect(module_id, restore.get("rect", Rect2()) as Rect2)
	var size := restore.get("size", dock_host.layout.get_default_module_size(module_id)) as Vector2
	return _constrain_floating_rect(module_id, Rect2(Vector2(12.0, 12.0), size))


func _restore_floating_parent(module_id: StringName, rect: Rect2, context: Dictionary = {}) -> void:
	if manager.mount_module(module_id, _floating_layer, context) == null:
		return
	if not manager.activate_module(module_id):
		manager.unmount_module(module_id)
		return
	_apply_floating_rect(module_id, rect)
	_placements[module_id] = Placement.FLOATING
	_floating_rects[module_id] = rect
	_floating_anchors[module_id] = _detect_snap_edges(rect)


func _restore_dock_after_failed_float(
	module_id: StringName, dock_state: Dictionary, context: Dictionary
) -> void:
	if dock_state.is_empty():
		return
	dock_host.dock_module(
		module_id,
		int(dock_state.get("zone", WorkspaceDockLayout.DockZone.NONE)),
		int(dock_state.get("index", -1)),
		dock_state.get("size", Vector2.ZERO) as Vector2,
		context,
		bool(dock_state.get("region_fill", false))
	)


func _show_surface_candidate(candidate: Dictionary) -> void:
	if not bool(candidate.get("valid", false)):
		_hide_surface_preview()
		return
	if (
		_drag_started_from_dock
		and int(candidate.get("placement", Placement.NONE)) == Placement.DOCKED
	):
		_preview.visible = false
		return
	var rect: Rect2 = candidate.get("preview_rect", Rect2()) as Rect2
	_preview.position = rect.position
	_preview.size = rect.size
	_preview.visible = rect.has_area()
	_preview.move_to_front()


func _hide_surface_preview() -> void:
	if is_instance_valid(_preview):
		_preview.visible = false


func _finish_drag(committed: bool) -> void:
	var module_id := _drag_module_id
	_clear_drag_state()
	surface_drag_finished.emit(module_id, committed)


func _clear_drag_state() -> void:
	_drag_module_id = &""
	_drag_origin = {}
	_drag_candidate = {}
	_drag_started_from_dock = false
	_drag_pointer_offset = Vector2.ZERO
	_hide_surface_preview()


func _can_float(module_id: StringName) -> bool:
	if manager == null or is_fixed_dock_module(module_id):
		return false
	var definition := manager.get_definition(module_id)
	return definition != null and definition.can_float


func _can_collapse(module_id: StringName) -> bool:
	if manager == null:
		return false
	var definition := manager.get_definition(module_id)
	return definition != null and definition.can_collapse


func _is_ready() -> bool:
	return manager != null and dock_host != null and dock_host.layout != null


func _invalid_candidate() -> Dictionary:
	return {
		"valid": false,
		"placement": Placement.NONE,
		"zone": WorkspaceDockLayout.DockZone.NONE,
		"index": -1,
		"preview_rect": Rect2(),
	}
