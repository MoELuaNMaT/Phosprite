class_name WorkspaceDockLayout
extends RefCounted

## Deterministic four-zone dock layout model for P2-B.
##
## The model owns only dock placement, order, and requested module size. It does
## not implement floating, collapsing, persistence, or editor-module migration;
## those belong to later P2 stages.

signal module_placed(module_id: StringName, zone: int, index: int)
signal module_removed(module_id: StringName, previous_zone: int)
signal module_size_changed(module_id: StringName, size: Vector2)

enum DockZone {
	NONE = -1,
	TOP = 0,
	LEFT = 1,
	RIGHT = 2,
	BOTTOM = 3,
}

const VALID_ZONES: Array[int] = [
	DockZone.TOP,
	DockZone.LEFT,
	DockZone.RIGHT,
	DockZone.BOTTOM,
]

var _manager: WorkspaceModuleManager
var _zone_modules: Dictionary = {
	DockZone.TOP: [],
	DockZone.LEFT: [],
	DockZone.RIGHT: [],
	DockZone.BOTTOM: [],
}
var _module_zones: Dictionary = {}
var _module_sizes: Dictionary = {}
var _module_region_fill: Dictionary = {}  # Full-edge drops expand along the dock's primary axis.


func configure(manager: WorkspaceModuleManager) -> bool:
	if manager == null or _manager != null:
		return false
	_manager = manager
	return true


func is_configured() -> bool:
	return _manager != null


func is_valid_zone(zone: int) -> bool:
	return VALID_ZONES.has(zone)


func can_dock_module(module_id: StringName) -> bool:
	if _manager == null:
		return false
	var definition := _manager.get_definition(module_id)
	return definition != null and definition.can_dock


func place_module(module_id: StringName, zone: int, index: int = -1) -> bool:
	if not is_valid_zone(zone) or not can_dock_module(module_id):
		return false

	var previous_zone := get_module_zone(module_id)
	if previous_zone != DockZone.NONE:
		var previous_modules: Array = _zone_modules[previous_zone]
		previous_modules.erase(module_id)

	var target_modules: Array = _zone_modules[zone]
	var resolved_index := target_modules.size()
	if index >= 0:
		resolved_index = clampi(index, 0, target_modules.size())
	target_modules.insert(resolved_index, module_id)
	_module_zones[module_id] = zone

	if not _module_sizes.has(module_id):
		_module_sizes[module_id] = get_default_module_size(module_id)

	module_placed.emit(module_id, zone, resolved_index)
	return true


func remove_module(module_id: StringName) -> bool:
	var previous_zone := get_module_zone(module_id)
	if previous_zone == DockZone.NONE:
		return false
	var modules: Array = _zone_modules[previous_zone]
	modules.erase(module_id)
	_module_zones.erase(module_id)
	_module_sizes.erase(module_id)
	_module_region_fill.erase(module_id)
	module_removed.emit(module_id, previous_zone)
	return true


func get_module_zone(module_id: StringName) -> int:
	return int(_module_zones.get(module_id, DockZone.NONE))


func get_module_index(module_id: StringName) -> int:
	var zone := get_module_zone(module_id)
	if zone == DockZone.NONE:
		return -1
	return (_zone_modules[zone] as Array).find(module_id)


func get_modules(zone: int) -> Array[StringName]:
	var result: Array[StringName] = []
	if not is_valid_zone(zone):
		return result
	for module_id: StringName in _zone_modules[zone]:
		result.append(module_id)
	return result


func get_all_docked_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for zone in VALID_ZONES:
		result.append_array(get_modules(zone))
	return result


func set_module_size(module_id: StringName, requested_size: Vector2) -> bool:
	if get_module_zone(module_id) == DockZone.NONE or _manager == null:
		return false
	var definition := _manager.get_definition(module_id)
	if definition == null:
		return false
	var constrained := definition.get_constrained_size(requested_size)
	_module_sizes[module_id] = constrained
	module_size_changed.emit(module_id, constrained)
	return true


func get_module_size(module_id: StringName) -> Vector2:
	if _module_sizes.has(module_id):
		return _module_sizes[module_id] as Vector2
	return get_default_module_size(module_id)


func set_module_region_fill(module_id: StringName, enabled: bool) -> bool:
	if get_module_zone(module_id) == DockZone.NONE:
		return false
	_module_region_fill[module_id] = enabled
	return true


func is_module_region_fill(module_id: StringName) -> bool:
	return bool(_module_region_fill.get(module_id, false))


func get_default_module_size(module_id: StringName) -> Vector2:
	if _manager == null:
		return Vector2.ZERO
	var definition := _manager.get_definition(module_id)
	if definition == null:
		return Vector2.ZERO
	return definition.get_constrained_preferred_size()


func clear() -> void:
	for zone in VALID_ZONES:
		(_zone_modules[zone] as Array).clear()
	_module_zones.clear()
	_module_sizes.clear()
	_module_region_fill.clear()


static func zone_name(zone: int) -> StringName:
	match zone:
		DockZone.TOP:
			return &"top"
		DockZone.LEFT:
			return &"left"
		DockZone.RIGHT:
			return &"right"
		DockZone.BOTTOM:
			return &"bottom"
		_:
			return &"none"
