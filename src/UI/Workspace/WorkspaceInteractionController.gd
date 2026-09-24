class_name WorkspaceInteractionController
extends Node

const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")

## Live P2-G interaction bridge for Workspace chrome.
##
## Mouse and touch users drag normal Workspace headers immediately. Touch capture
## starts on press at the Workspace level, before child controls can swallow motion.
## Collapse and resize targets live only inside Workspace chrome and never cover
## the central Canvas input surface.

const TOUCH_DIRECT_DRAG_DISTANCE := 4.0
const TIMELINE_HORIZONTAL_CANCEL_DISTANCE := 12.0
const TIMELINE_DIRECT_RESIZE_DISTANCE := 6.0
const TIMELINE_VERTICAL_INTENT_RATIO := 1.15
const TRAY_MARGIN := 8.0
const TRAY_BUTTON_MIN_HEIGHT := 32.0

var manager: WorkspaceModuleManager
var surface: WorkspaceSurface
var dock_host: WorkspaceDockHost

var _tray: HBoxContainer
var _bound_modules: Dictionary = {}

var _drag_module_id: StringName = &""
var _drag_touch_index := -1

var _resize_module_id: StringName = &""
var _resize_touch_index := -1
var _resize_start_pointer := Vector2.ZERO
var _resize_start_rect := Rect2()
var _resize_start_size := Vector2.ZERO
var _resize_edges := WorkspaceModule.ResizeEdge.NONE
var _resize_is_docked := false
var _resize_timeline_mode := -1
var _resize_timeline_project: Project

var _pending_touch_module_id: StringName = &""
var _pending_touch_index := -1
var _pending_touch_start_pointer := Vector2.ZERO
var _pending_touch_can_drag := false


func setup(module_manager: WorkspaceModuleManager, workspace_surface: WorkspaceSurface) -> bool:
	if module_manager == null or workspace_surface == null or manager != null:
		return false
	if workspace_surface.manager != module_manager or workspace_surface.dock_host == null:
		return false
	manager = module_manager
	surface = workspace_surface
	dock_host = surface.dock_host
	manager.module_created.connect(_on_module_created)
	surface.module_collapsed.connect(_on_module_placement_changed)
	surface.module_restored.connect(_on_module_restored)
	surface.module_cleared.connect(_on_module_cleared)
	dock_host.module_docked.connect(_on_module_docked)
	dock_host.layout_geometry_changed.connect(_on_layout_geometry_changed)
	_create_tray()
	for module_id in manager.get_registered_ids():
		var module := manager.get_instance(module_id)
		if module != null:
			_bind_module(module_id, module)
	_refresh_tray()
	return true


func get_tray() -> HBoxContainer:
	return _tray


func _input(event: InputEvent) -> void:
	if _is_emulated_pointer_event(event):
		return
	if not _has_captured_interaction() and event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _try_capture_workspace_resize(touch):
				return
			if _try_capture_timeline_header_resize(touch):
				return
			if _try_capture_workspace_header_drag(touch):
				return
	if not _has_captured_interaction():
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var pointer := _viewport_point_to_host(motion.position)
		if _resize_module_id != &"" and _resize_touch_index == -1:
			_update_resize(pointer)
			get_viewport().set_input_as_handled()
		elif _drag_module_id != &"" and _drag_touch_index == -1:
			surface.update_module_drag(pointer)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
			var pointer := _viewport_point_to_host(button.position)
			if _resize_module_id != &"" and _resize_touch_index == -1:
				_update_resize(pointer)
				_finish_resize()
				get_viewport().set_input_as_handled()
			elif _drag_module_id != &"" and _drag_touch_index == -1:
				surface.update_module_drag(pointer)
				surface.commit_module_drag()
				_clear_drag()
				get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		_handle_captured_screen_drag(event as InputEventScreenDrag)
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			_handle_captured_screen_release(touch)


func _is_emulated_pointer_event(event: InputEvent) -> bool:
	if event.device != InputEvent.DEVICE_ID_EMULATION:
		return false
	return (
		event is InputEventMouseButton
		or event is InputEventMouseMotion
		or event is InputEventScreenTouch
		or event is InputEventScreenDrag
	)


func _has_captured_interaction() -> bool:
	return _drag_module_id != &"" or _resize_module_id != &"" or _pending_touch_module_id != &""


static func touch_direct_drag_intent(delta: Vector2) -> bool:
	return delta.length() >= TOUCH_DIRECT_DRAG_DISTANCE


static func timeline_header_resize_intent(delta: Vector2) -> bool:
	var vertical := absf(delta.y)
	var horizontal := absf(delta.x)
	return (
		vertical >= TIMELINE_DIRECT_RESIZE_DISTANCE
		and vertical >= horizontal * TIMELINE_VERTICAL_INTENT_RATIO
	)


func _try_capture_workspace_resize(event: InputEventScreenTouch) -> bool:
	var hit := _top_workspace_module_at(event.position)
	if hit.is_empty():
		return false
	var module_id := hit.get("module_id", &"") as StringName
	var module := hit.get("module") as WorkspaceModule
	var local_point := hit.get("local_point", Vector2.ZERO) as Vector2
	if module == null:
		return false
	var resize_edges := module.get_resize_edges(local_point)
	if resize_edges == WorkspaceModule.ResizeEdge.NONE:
		resize_edges = surface.get_docked_resize_edges(module_id, local_point)
	if resize_edges == WorkspaceModule.ResizeEdge.NONE:
		return false
	_raise_floating_module(module_id, module)
	if not _begin_resize(
		module_id,
		_viewport_point_to_host(event.position),
		event.index,
		resize_edges,
	):
		return false
	get_viewport().set_input_as_handled()
	return true


func _try_capture_workspace_header_drag(event: InputEventScreenTouch) -> bool:
	var hit := _top_workspace_module_at(event.position)
	if hit.is_empty():
		return false
	var module_id := hit.get("module_id", &"") as StringName
	var module := hit.get("module") as WorkspaceModule
	var local_point := hit.get("local_point", Vector2.ZERO) as Vector2
	if module == null or not module.is_header_drag_point(local_point):
		return false
	_raise_floating_module(module_id, module)
	if not _begin_drag(module_id, _viewport_point_to_host(event.position), event.index):
		return false
	get_viewport().set_input_as_handled()
	return true


func _top_workspace_module_at(viewport_point: Vector2) -> Dictionary:
	if manager == null or surface == null:
		return {}
	var best: Dictionary = {}
	var best_layer := -1
	var best_index := -1
	for module_id in manager.get_registered_ids():
		var module := manager.get_instance(module_id)
		if module == null or not module.is_visible_in_tree():
			continue
		var placement := surface.get_module_placement(module_id)
		if placement == WorkspaceSurface.Placement.NONE:
			continue
		var local_point := (
			module.get_global_transform_with_canvas().affine_inverse() * viewport_point
		)
		if not module.get_visual_rect().has_point(local_point):
			continue
		var layer_priority := 1
		if (
			placement == WorkspaceSurface.Placement.FLOATING
			or (
				placement == WorkspaceSurface.Placement.COLLAPSED
				and module.get_parent() == surface.get_floating_layer()
			)
		):
			layer_priority = 2
		var tree_index := module.get_index()
		if layer_priority < best_layer:
			continue
		if layer_priority == best_layer and tree_index <= best_index:
			continue
		best_layer = layer_priority
		best_index = tree_index
		best = {
			"module_id": module_id,
			"module": module,
			"local_point": local_point,
		}
	return best


func _try_capture_timeline_header_resize(event: InputEventScreenTouch) -> bool:
	if OS.get_name() != "iOS" or manager == null or surface == null or dock_host == null:
		return false
	if _has_captured_interaction():
		return false
	var module := manager.get_instance(Builtins.TIMELINE_ID)
	if module == null or module.is_content_collapsed():
		return false
	if (
		surface.get_module_placement(Builtins.TIMELINE_ID) != WorkspaceSurface.Placement.DOCKED
		or (
			dock_host.layout.get_module_zone(Builtins.TIMELINE_ID)
			!= WorkspaceDockLayout.DockZone.BOTTOM
		)
		or not dock_host.layout.is_module_region_fill(Builtins.TIMELINE_ID)
	):
		return false
	var local_point := module.get_global_transform_with_canvas().affine_inverse() * event.position
	var header_rect := Rect2(Vector2.ZERO, Vector2(module.size.x, module.get_header_height()))
	if not header_rect.has_point(local_point):
		return false
	if module.is_collapse_point(local_point) or module.is_float_point(local_point):
		return false
	_pending_touch_module_id = Builtins.TIMELINE_ID
	_pending_touch_index = event.index
	_pending_touch_start_pointer = _viewport_point_to_host(event.position)
	_pending_touch_can_drag = module.is_header_drag_point(local_point)
	return true


func _handle_captured_screen_drag(event: InputEventScreenDrag) -> void:
	var pointer := _viewport_point_to_host(event.position)
	if _resize_module_id != &"" and _resize_touch_index == event.index:
		_update_resize(pointer)
		get_viewport().set_input_as_handled()
		return
	if _drag_module_id != &"" and _drag_touch_index == event.index:
		surface.update_module_drag(pointer)
		get_viewport().set_input_as_handled()
		return
	if _pending_touch_module_id == &"" or _pending_touch_index != event.index:
		return

	var delta := pointer - _pending_touch_start_pointer
	if _pending_touch_module_id == Builtins.TIMELINE_ID:
		if timeline_header_resize_intent(delta):
			var module_id := _pending_touch_module_id
			var start_pointer := _pending_touch_start_pointer
			var touch_index := _pending_touch_index
			_clear_pending_touch()
			if _begin_resize(module_id, start_pointer, touch_index, WorkspaceModule.ResizeEdge.TOP):
				_update_resize(pointer)
			get_viewport().set_input_as_handled()
			return
		if not _pending_touch_can_drag:
			if (
				absf(delta.x) > TIMELINE_HORIZONTAL_CANCEL_DISTANCE
				and absf(delta.x) > absf(delta.y)
			):
				_clear_pending_touch()
			return
	if not touch_direct_drag_intent(delta):
		get_viewport().set_input_as_handled()
		return

	var module_id := _pending_touch_module_id
	var start_pointer := _pending_touch_start_pointer
	var touch_index := _pending_touch_index
	var can_drag := _pending_touch_can_drag
	_clear_pending_touch()
	if can_drag and _begin_drag(module_id, start_pointer, touch_index):
		surface.update_module_drag(pointer)
	get_viewport().set_input_as_handled()


func _handle_captured_screen_release(event: InputEventScreenTouch) -> void:
	var pointer := _viewport_point_to_host(event.position)
	if _resize_module_id != &"" and _resize_touch_index == event.index:
		_update_resize(pointer)
		_finish_resize()
		get_viewport().set_input_as_handled()
		return
	if _drag_module_id != &"" and _drag_touch_index == event.index:
		surface.update_module_drag(pointer)
		surface.commit_module_drag()
		_clear_drag()
		get_viewport().set_input_as_handled()
		return
	if _pending_touch_module_id != &"" and _pending_touch_index == event.index:
		var was_timeline_resize_candidate := _pending_touch_module_id == Builtins.TIMELINE_ID
		_clear_pending_touch()
		if not was_timeline_resize_candidate:
			get_viewport().set_input_as_handled()


func _on_module_created(module_id: StringName, module: WorkspaceModule) -> void:
	_bind_module(module_id, module)


func _bind_module(module_id: StringName, module: WorkspaceModule) -> void:
	if module == null or _bound_modules.has(module_id):
		return
	module.mouse_filter = Control.MOUSE_FILTER_STOP
	var callable := _on_module_gui_input.bind(module_id, module)
	if not module.gui_input.is_connected(callable):
		module.gui_input.connect(callable)
	_bound_modules[module_id] = true


func _on_module_gui_input(
	event: InputEvent, module_id: StringName, module: WorkspaceModule
) -> void:
	if _is_emulated_pointer_event(event):
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton, module_id, module)
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch, module_id, module)


func _handle_mouse_button(
	event: InputEventMouseButton, module_id: StringName, module: WorkspaceModule
) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var pointer := _module_point_to_host(module, event.position)
	_raise_floating_module(module_id, module)
	if module.is_collapse_point(event.position):
		if _toggle_module_collapse(module_id):
			_refresh_tray()
		module.accept_event()
		return
	if module.is_float_point(event.position):
		if surface.float_from_dock(module_id):
			module.accept_event()
		return
	var resize_edges := module.get_resize_edges(event.position)
	if resize_edges == WorkspaceModule.ResizeEdge.NONE:
		resize_edges = surface.get_docked_resize_edges(module_id, event.position)
	if resize_edges != WorkspaceModule.ResizeEdge.NONE:
		if _begin_resize(module_id, pointer, -1, resize_edges):
			module.accept_event()
		return
	if module.is_header_drag_point(event.position):
		if _begin_drag(module_id, pointer, -1):
			module.accept_event()


func _handle_screen_touch(
	event: InputEventScreenTouch, module_id: StringName, module: WorkspaceModule
) -> void:
	if not event.pressed:
		return
	var pointer := _module_point_to_host(module, event.position)
	_raise_floating_module(module_id, module)
	if module.is_collapse_point(event.position):
		if _toggle_module_collapse(module_id):
			_refresh_tray()
		module.accept_event()
		return
	if module.is_float_point(event.position):
		if surface.float_from_dock(module_id):
			module.accept_event()
		return
	var resize_edges := module.get_resize_edges(event.position)
	if resize_edges == WorkspaceModule.ResizeEdge.NONE:
		resize_edges = surface.get_docked_resize_edges(module_id, event.position)
	if resize_edges != WorkspaceModule.ResizeEdge.NONE:
		if _begin_resize(module_id, pointer, event.index, resize_edges):
			module.accept_event()
		return
	if module.is_header_drag_point(event.position):
		if _begin_drag(module_id, pointer, event.index):
			module.accept_event()


func _begin_drag(module_id: StringName, pointer: Vector2, touch_index: int) -> bool:
	if _drag_module_id != &"" or _resize_module_id != &"":
		return false
	var module := manager.get_instance(module_id) if manager != null else null
	if module != null and not module.is_position_adjustment_enabled():
		return false
	if not surface.begin_module_drag(module_id, pointer):
		return false
	_drag_module_id = module_id
	_drag_touch_index = touch_index
	return true


func _clear_drag() -> void:
	_drag_module_id = &""
	_drag_touch_index = -1


func _begin_resize(
	module_id: StringName, pointer: Vector2, touch_index: int, resize_edges: int
) -> bool:
	if _resize_module_id != &"" or _drag_module_id != &"":
		return false
	if resize_edges == WorkspaceModule.ResizeEdge.NONE:
		return false
	var placement := surface.get_module_placement(module_id)
	if (
		placement != WorkspaceSurface.Placement.FLOATING
		and placement != WorkspaceSurface.Placement.DOCKED
	):
		return false
	_resize_module_id = module_id
	_resize_touch_index = touch_index
	_resize_start_pointer = pointer
	_resize_edges = resize_edges
	_resize_is_docked = placement == WorkspaceSurface.Placement.DOCKED
	_resize_timeline_mode = -1
	_resize_timeline_project = null
	if module_id == Builtins.TIMELINE_ID and is_instance_valid(Global.animation_timeline):
		_resize_timeline_mode = Global.animation_timeline.get_timeline_mode()
		_resize_timeline_project = Global.current_project
	if _resize_is_docked:
		_resize_start_size = dock_host.layout.get_module_size(module_id)
		return _resize_start_size != Vector2.ZERO
	var rect := surface.get_floating_rect(module_id)
	if not rect.has_area():
		_finish_resize()
		return false
	_resize_start_rect = rect
	return true


func _update_resize(pointer: Vector2) -> void:
	if _resize_module_id == &"":
		return
	var delta := pointer - _resize_start_pointer
	if _resize_is_docked:
		surface.resize_docked_module(_resize_module_id, _resize_start_size, delta, _resize_edges)
	else:
		surface.resize_floating_rect(_resize_module_id, _resize_start_rect, delta, _resize_edges)


func _finish_resize() -> void:
	if _resize_module_id == Builtins.TIMELINE_ID and is_instance_valid(Global.animation_timeline):
		var final_height := 0.0
		if _resize_is_docked:
			final_height = dock_host.layout.get_module_size(_resize_module_id).y
		else:
			final_height = surface.get_floating_rect(_resize_module_id).size.y
		if final_height > 0.0:
			var mode: int = (
				_resize_timeline_mode
				if _resize_timeline_mode >= 0
				else Global.animation_timeline.get_timeline_mode()
			)
			var project: Project = (
				_resize_timeline_project
				if is_instance_valid(_resize_timeline_project)
				else Global.current_project
			)
			Global.animation_timeline.store_workspace_height(final_height, mode, project)
	_resize_module_id = &""
	_resize_touch_index = -1
	_resize_start_pointer = Vector2.ZERO
	_resize_start_rect = Rect2()
	_resize_start_size = Vector2.ZERO
	_resize_edges = WorkspaceModule.ResizeEdge.NONE
	_resize_is_docked = false
	_resize_timeline_mode = -1
	_resize_timeline_project = null


func _clear_pending_touch() -> void:
	_pending_touch_module_id = &""
	_pending_touch_index = -1
	_pending_touch_start_pointer = Vector2.ZERO
	_pending_touch_can_drag = false


func _module_point_to_host(module: WorkspaceModule, local_point: Vector2) -> Vector2:
	var viewport_point := module.get_global_transform_with_canvas() * local_point
	return _viewport_point_to_host(viewport_point)


func _viewport_point_to_host(viewport_point: Vector2) -> Vector2:
	return dock_host.get_global_transform_with_canvas().affine_inverse() * viewport_point


func _raise_floating_module(module_id: StringName, module: WorkspaceModule) -> void:
	if (
		surface.get_module_placement(module_id) != WorkspaceSurface.Placement.FLOATING
		and not surface.is_floating_collapsed(module_id)
	):
		return
	if module.get_parent() == surface.get_floating_layer():
		module.move_to_front()


func _toggle_module_collapse(module_id: StringName) -> bool:
	if surface.get_module_placement(module_id) == WorkspaceSurface.Placement.COLLAPSED:
		return surface.restore_module(module_id)
	return surface.collapse_module(module_id)


func _create_tray() -> void:
	_tray = HBoxContainer.new()
	_tray.name = &"WorkspaceCollapsedTray"
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock_host.add_child(_tray)
	_tray.visible = false
	_tray.move_to_front()


func _refresh_tray() -> void:
	if _tray == null:
		return
	for child in _tray.get_children():
		child.queue_free()
	# P2-G collapse is always in-place. The legacy bottom restore tray must stay hidden.
	_tray.visible = false


func _layout_tray() -> void:
	if _tray == null or not _tray.visible or dock_host == null:
		return
	var minimum := _tray.get_combined_minimum_size()
	_tray.size = minimum
	_tray.position = Vector2(
		maxf(TRAY_MARGIN, (dock_host.size.x - minimum.x) * 0.5),
		maxf(TRAY_MARGIN, dock_host.size.y - minimum.y - TRAY_MARGIN)
	)
	_tray.move_to_front()


func _on_tray_mouse_entered(module_id: StringName) -> void:
	surface.peek_module(module_id)


func _on_tray_mouse_exited(module_id: StringName) -> void:
	if surface.is_peeking(module_id):
		surface.end_peek(module_id)


func _on_tray_pressed(module_id: StringName) -> void:
	if surface.is_peeking(module_id):
		surface.end_peek(module_id)
	if surface.restore_module(module_id):
		_refresh_tray()


func _on_module_placement_changed(_module_id: StringName) -> void:
	_refresh_tray()


func _on_module_restored(_module_id: StringName, _placement: int) -> void:
	_refresh_tray()


func _on_module_cleared(_module_id: StringName) -> void:
	_refresh_tray()


func _on_module_docked(_module_id: StringName, _zone: int, _index: int) -> void:
	_refresh_tray()


func _on_layout_geometry_changed(_content_rect: Rect2) -> void:
	_layout_tray.call_deferred()
