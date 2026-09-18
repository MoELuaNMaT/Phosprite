class_name WorkspaceDockHost
extends Control

## Runtime host for the limited Top/Left/Right/Bottom dock system.
##
## In P2-G the host becomes live above the central Canvas. Empty host space is
## mouse-transparent; occupied docks reserve geometry around the Canvas while a
## separate edge snap band keeps empty zones discoverable during drag.

signal module_docked(module_id: StringName, zone: int, index: int)
signal dock_preview_changed(candidate: Dictionary)
signal dock_drag_finished(module_id: StringName, committed: bool)
signal layout_geometry_changed(content_rect: Rect2)

const EMPTY_ZONE_EXTENT := 56.0
const EDGE_DOCK_TARGET_EXTENT := 72.0
const PREVIEW_COLOR := Color(1.0, 1.0, 1.0, 0.18)

var manager: WorkspaceModuleManager
var layout: WorkspaceDockLayout

var _zone_hosts: Dictionary = {}
var _preview: ColorRect
var _drag_module_id: StringName = &""
var _drag_candidate: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_structure()


func setup(module_manager: WorkspaceModuleManager) -> bool:
	if module_manager == null or manager != null:
		return false
	manager = module_manager
	layout = WorkspaceDockLayout.new()
	if not layout.configure(manager):
		layout = null
		manager = null
		return false
	_layout_zones()
	return true


func dock_module(
	module_id: StringName,
	zone: int,
	index: int = -1,
	requested_size: Vector2 = Vector2.ZERO,
	context: Dictionary = {},
	region_fill: bool = false
) -> bool:
	if manager == null or layout == null or not layout.can_dock_module(module_id):
		return false
	if not layout.is_valid_zone(zone):
		return false

	var module := manager.get_instance(module_id)
	if module == null:
		module = manager.create_module(module_id, context)
	if module == null:
		return false
	if module.get_lifecycle_state() == WorkspaceModule.LifecycleState.DISPOSED:
		return false

	var old_zone := layout.get_module_zone(module_id)
	var old_index := layout.get_module_index(module_id)
	var old_size := layout.get_module_size(module_id)
	var old_region_fill := layout.is_module_region_fill(module_id)
	var old_host := module.get_parent() as Control
	var was_active := module.get_lifecycle_state() == WorkspaceModule.LifecycleState.ACTIVE

	if not layout.place_module(module_id, zone, index):
		return false
	if not layout.set_module_region_fill(module_id, region_fill):
		_restore_layout(module_id, old_zone, old_index, old_size, old_region_fill)
		return false
	var resolved_size := requested_size
	if region_fill:
		resolved_size = _region_fill_requested_size(module_id, zone, requested_size)
	if resolved_size != Vector2.ZERO and not layout.set_module_size(module_id, resolved_size):
		_restore_layout(module_id, old_zone, old_index, old_size, old_region_fill)
		return false

	var target_host := _zone_hosts[zone] as Control
	if module.get_parent() != target_host:
		if was_active and not manager.deactivate_module(module_id):
			_restore_layout(module_id, old_zone, old_index, old_size, old_region_fill)
			return false
		if module.get_lifecycle_state() == WorkspaceModule.LifecycleState.MOUNTED:
			if not manager.unmount_module(module_id):
				_restore_layout(module_id, old_zone, old_index, old_size, old_region_fill)
				if was_active:
					manager.activate_module(module_id)
				return false
		if manager.mount_module(module_id, target_host, context) == null:
			_rollback_mount(
				module_id, old_zone, old_index, old_size, old_region_fill, old_host, was_active
			)
			return false
		if was_active or old_zone == WorkspaceDockLayout.DockZone.NONE:
			if not manager.activate_module(module_id):
				manager.unmount_module(module_id)
				_rollback_mount(
					module_id, old_zone, old_index, old_size, old_region_fill, old_host, was_active
				)
				return false

	_apply_module_size(module_id)
	_sync_zone_order(zone)
	if old_zone != WorkspaceDockLayout.DockZone.NONE and old_zone != zone:
		_sync_zone_order(old_zone)
	_layout_zones()
	module_docked.emit(module_id, zone, layout.get_module_index(module_id))
	return true


func undock_module(module_id: StringName) -> bool:
	if manager == null or layout == null:
		return false
	if layout.get_module_zone(module_id) == WorkspaceDockLayout.DockZone.NONE:
		return false
	if not manager.unmount_module(module_id):
		return false
	if not layout.remove_module(module_id):
		return false
	_layout_zones()
	return true


func set_module_size(module_id: StringName, requested_size: Vector2) -> bool:
	if layout == null or not layout.set_module_size(module_id, requested_size):
		return false
	_apply_module_size(module_id)
	_layout_zones()
	return true


func set_preview_color(color: Color) -> void:
	if is_instance_valid(_preview):
		_preview.color = color


func begin_module_drag(module_id: StringName) -> bool:
	if layout == null or layout.get_module_zone(module_id) == WorkspaceDockLayout.DockZone.NONE:
		return false
	_drag_module_id = module_id
	_drag_candidate = {}
	_preview.visible = false
	return true


func update_module_drag(pointer: Vector2) -> Dictionary:
	if _drag_module_id == &"" or layout == null:
		return _invalid_candidate()
	_drag_candidate = WorkspaceDockDragResolver.resolve(
		_drag_module_id,
		pointer,
		get_zone_rects(),
		_collect_module_rects(),
		layout,
		get_edge_snap_rects(),
		Rect2(Vector2.ZERO, size)
	)
	_show_candidate(_drag_candidate)
	dock_preview_changed.emit(_drag_candidate.duplicate(true))
	return _drag_candidate.duplicate(true)


func commit_module_drag() -> bool:
	if _drag_module_id == &"":
		return false
	var module_id := _drag_module_id
	var candidate := _drag_candidate.duplicate(true)
	var committed := false
	if bool(candidate.get("valid", false)):
		committed = dock_module(
			module_id,
			int(candidate.get("zone", WorkspaceDockLayout.DockZone.NONE)),
			int(candidate.get("index", -1)),
			layout.get_module_size(module_id),
			{},
			StringName(candidate.get("target_kind", &"none")) == &"region"
		)
	_finish_drag(committed)
	return committed


func cancel_module_drag() -> void:
	if _drag_module_id == &"":
		return
	_finish_drag(false)


func get_zone_host(zone: int) -> Control:
	return _zone_hosts.get(zone) as Control


func get_zone_rects() -> Dictionary:
	var top_h := _zone_extent(WorkspaceDockLayout.DockZone.TOP)
	var bottom_h := _zone_extent(WorkspaceDockLayout.DockZone.BOTTOM)
	var left_w := _zone_extent(WorkspaceDockLayout.DockZone.LEFT)
	var right_w := _zone_extent(WorkspaceDockLayout.DockZone.RIGHT)
	var middle_y := top_h
	var middle_h := maxf(0.0, size.y - top_h - bottom_h)
	return {
		WorkspaceDockLayout.DockZone.TOP: Rect2(0.0, 0.0, size.x, maxf(top_h, EMPTY_ZONE_EXTENT)),
		WorkspaceDockLayout.DockZone.LEFT:
		Rect2(0.0, middle_y, maxf(left_w, EMPTY_ZONE_EXTENT), middle_h),
		WorkspaceDockLayout.DockZone.RIGHT:
		Rect2(
			maxf(0.0, size.x - maxf(right_w, EMPTY_ZONE_EXTENT)),
			middle_y,
			maxf(right_w, EMPTY_ZONE_EXTENT),
			middle_h
		),
		WorkspaceDockLayout.DockZone.BOTTOM:
		Rect2(
			0.0,
			maxf(0.0, size.y - maxf(bottom_h, EMPTY_ZONE_EXTENT)),
			size.x,
			maxf(bottom_h, EMPTY_ZONE_EXTENT)
		),
	}


func get_edge_snap_rects() -> Dictionary:
	var extent_x := minf(EDGE_DOCK_TARGET_EXTENT, size.x)
	var extent_y := minf(EDGE_DOCK_TARGET_EXTENT, size.y)
	return {
		WorkspaceDockLayout.DockZone.TOP: Rect2(0.0, 0.0, size.x, extent_y),
		WorkspaceDockLayout.DockZone.LEFT: Rect2(0.0, 0.0, extent_x, size.y),
		WorkspaceDockLayout.DockZone.RIGHT:
		Rect2(maxf(0.0, size.x - extent_x), 0.0, extent_x, size.y),
		WorkspaceDockLayout.DockZone.BOTTOM:
		Rect2(0.0, maxf(0.0, size.y - extent_y), size.x, extent_y),
	}


func get_content_rect() -> Rect2:
	var top_h := _zone_extent(WorkspaceDockLayout.DockZone.TOP)
	var bottom_h := _zone_extent(WorkspaceDockLayout.DockZone.BOTTOM)
	var left_w := _zone_extent(WorkspaceDockLayout.DockZone.LEFT)
	var right_w := _zone_extent(WorkspaceDockLayout.DockZone.RIGHT)
	return Rect2(
		Vector2(left_w, top_h),
		Vector2(maxf(0.0, size.x - left_w - right_w), maxf(0.0, size.y - top_h - bottom_h))
	)


func get_preview_rect() -> Rect2:
	if not _preview.visible:
		return Rect2()
	return Rect2(_preview.position, _preview.size)


func refresh_layout_geometry() -> void:
	_layout_zones()


func _ensure_structure() -> void:
	if not _zone_hosts.is_empty():
		return

	var top := HBoxContainer.new()
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	var bottom := HBoxContainer.new()
	top.name = "TopDock"
	left.name = "LeftDock"
	right.name = "RightDock"
	bottom.name = "BottomDock"

	_zone_hosts = {
		WorkspaceDockLayout.DockZone.TOP: top,
		WorkspaceDockLayout.DockZone.LEFT: left,
		WorkspaceDockLayout.DockZone.RIGHT: right,
		WorkspaceDockLayout.DockZone.BOTTOM: bottom,
	}
	for zone in WorkspaceDockLayout.VALID_ZONES:
		var host := _zone_hosts[zone] as Control
		host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(host)

	_preview = ColorRect.new()
	_preview.name = "DockSnapPreview"
	_preview.color = PREVIEW_COLOR
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.visible = false
	add_child(_preview)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not _zone_hosts.is_empty():
		_layout_zones()


func _layout_zones() -> void:
	if _zone_hosts.is_empty():
		return
	var top_h := _zone_extent(WorkspaceDockLayout.DockZone.TOP)
	var bottom_h := _zone_extent(WorkspaceDockLayout.DockZone.BOTTOM)
	var left_w := _zone_extent(WorkspaceDockLayout.DockZone.LEFT)
	var right_w := _zone_extent(WorkspaceDockLayout.DockZone.RIGHT)
	var middle_h := maxf(0.0, size.y - top_h - bottom_h)

	_set_host_rect(WorkspaceDockLayout.DockZone.TOP, Rect2(0.0, 0.0, size.x, top_h))
	_set_host_rect(
		WorkspaceDockLayout.DockZone.BOTTOM,
		Rect2(0.0, maxf(0.0, size.y - bottom_h), size.x, bottom_h)
	)
	_set_host_rect(WorkspaceDockLayout.DockZone.LEFT, Rect2(0.0, top_h, left_w, middle_h))
	_set_host_rect(
		WorkspaceDockLayout.DockZone.RIGHT,
		Rect2(maxf(0.0, size.x - right_w), top_h, right_w, middle_h)
	)
	layout_geometry_changed.emit(get_content_rect())


func _zone_extent(zone: int) -> float:
	if layout == null:
		return 0.0
	var module_ids := layout.get_modules(zone)
	if module_ids.is_empty():
		return 0.0
	var extent := 0.0
	for module_id in module_ids:
		var module_size := layout.get_module_size(module_id)
		var module := manager.get_instance(module_id) if manager != null else null
		if (
			module != null
			and module.is_content_collapsed()
			and (
				zone == WorkspaceDockLayout.DockZone.TOP
				or zone == WorkspaceDockLayout.DockZone.BOTTOM
			)
		):
			module_size.y = module.get_header_height()
		if zone == WorkspaceDockLayout.DockZone.TOP or zone == WorkspaceDockLayout.DockZone.BOTTOM:
			extent = maxf(extent, module_size.y)
		else:
			extent = maxf(extent, module_size.x)
	return extent


func _set_host_rect(zone: int, rect: Rect2) -> void:
	var host := _zone_hosts[zone] as Control
	host.position = rect.position
	host.size = rect.size


func _apply_module_size(module_id: StringName) -> void:
	var module := manager.get_instance(module_id) if manager != null else null
	if module == null or layout == null:
		return
	var target_size := layout.get_module_size(module_id)
	var zone := layout.get_module_zone(module_id)
	module.size_flags_horizontal = Control.SIZE_FILL
	module.size_flags_vertical = Control.SIZE_FILL
	if layout.is_module_region_fill(module_id):
		if zone == WorkspaceDockLayout.DockZone.TOP or zone == WorkspaceDockLayout.DockZone.BOTTOM:
			module.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elif (
			zone == WorkspaceDockLayout.DockZone.LEFT or zone == WorkspaceDockLayout.DockZone.RIGHT
		):
			module.size_flags_vertical = Control.SIZE_EXPAND_FILL
	module.custom_minimum_size = target_size
	module.size = target_size


func _region_fill_requested_size(
	module_id: StringName, zone: int, requested_size: Vector2
) -> Vector2:
	var definition := manager.get_definition(module_id) if manager != null else null
	if definition == null:
		return requested_size
	var size := requested_size
	if size == Vector2.ZERO:
		size = definition.get_constrained_preferred_size()
	if zone == WorkspaceDockLayout.DockZone.TOP or zone == WorkspaceDockLayout.DockZone.BOTTOM:
		size.x = definition.minimum_size.x
	elif zone == WorkspaceDockLayout.DockZone.LEFT or zone == WorkspaceDockLayout.DockZone.RIGHT:
		size.y = definition.minimum_size.y
	return size


func _sync_zone_order(zone: int) -> void:
	if layout == null:
		return
	var host := _zone_hosts[zone] as Control
	var module_ids := layout.get_modules(zone)
	for index in range(module_ids.size()):
		var module := manager.get_instance(module_ids[index])
		if module != null and module.get_parent() == host:
			host.move_child(module, index)


func _collect_module_rects() -> Dictionary:
	var result: Dictionary = {}
	if layout == null:
		return result
	for zone in WorkspaceDockLayout.VALID_ZONES:
		var entries: Array = []
		var host := _zone_hosts[zone] as Control
		for module_id in layout.get_modules(zone):
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


func _show_candidate(candidate: Dictionary) -> void:
	if not bool(candidate.get("valid", false)):
		_preview.visible = false
		return
	var rect: Rect2 = candidate.get("preview_rect", Rect2())
	_preview.position = rect.position
	_preview.size = rect.size
	_preview.visible = rect.size.x > 0.0 and rect.size.y > 0.0
	_preview.move_to_front()


func _finish_drag(committed: bool) -> void:
	var finished_id := _drag_module_id
	_drag_module_id = &""
	_drag_candidate = {}
	_preview.visible = false
	dock_drag_finished.emit(finished_id, committed)


func _rollback_mount(
	module_id: StringName,
	old_zone: int,
	old_index: int,
	old_size: Vector2,
	old_region_fill: bool,
	old_host: Control,
	was_active: bool
) -> void:
	_restore_layout(module_id, old_zone, old_index, old_size, old_region_fill)
	if old_zone == WorkspaceDockLayout.DockZone.NONE or old_host == null:
		return
	if manager.mount_module(module_id, old_host) == null:
		return
	if was_active:
		manager.activate_module(module_id)
	_apply_module_size(module_id)
	_sync_zone_order(old_zone)


func _restore_layout(
	module_id: StringName, old_zone: int, old_index: int, old_size: Vector2, old_region_fill: bool
) -> void:
	if old_zone == WorkspaceDockLayout.DockZone.NONE:
		layout.remove_module(module_id)
		return
	layout.place_module(module_id, old_zone, old_index)
	layout.set_module_size(module_id, old_size)
	layout.set_module_region_fill(module_id, old_region_fill)


func _invalid_candidate() -> Dictionary:
	return {
		"valid": false,
		"zone": WorkspaceDockLayout.DockZone.NONE,
		"index": -1,
		"preview_rect": Rect2(),
	}
