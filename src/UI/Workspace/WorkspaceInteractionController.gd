class_name WorkspaceInteractionController
extends Node

## Live P2-G interaction bridge for Workspace chrome.
##
## Mouse users drag headers immediately. Touch users must hold a header briefly
## before the panel starts moving so a normal tap does not relocate the layout.
## Collapse and resize targets live only inside Workspace chrome and never cover
## the central Canvas input surface.

const TOUCH_LONG_PRESS_MS := 350
const TOUCH_CANCEL_DISTANCE := 12.0
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

var _pending_touch_module_id: StringName = &""
var _pending_touch_index := -1
var _pending_touch_started_ms := 0
var _pending_touch_start_pointer := Vector2.ZERO
var _pending_touch_travel := 0.0


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
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton, module_id, module)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion, module_id, module)
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch, module_id, module)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag, module_id, module)


func _handle_mouse_button(
	event: InputEventMouseButton, module_id: StringName, module: WorkspaceModule
) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var pointer := _module_point_to_host(module, event.position)
	if event.pressed:
		_raise_floating_module(module_id, module)
		if module.is_collapse_point(event.position):
			if surface.collapse_module(module_id):
				_refresh_tray()
			module.accept_event()
			return
		if module.is_resize_point(event.position):
			if _begin_resize(module_id, pointer, -1):
				module.accept_event()
			return
		if module.is_header_drag_point(event.position):
			if _begin_drag(module_id, pointer, -1):
				module.accept_event()
			return
	else:
		if _resize_module_id == module_id and _resize_touch_index == -1:
			_finish_resize()
			module.accept_event()
			return
		if _drag_module_id == module_id and _drag_touch_index == -1:
			surface.update_module_drag(pointer)
			surface.commit_module_drag()
			_clear_drag()
			module.accept_event()


func _handle_mouse_motion(
	event: InputEventMouseMotion, module_id: StringName, module: WorkspaceModule
) -> void:
	var pointer := _module_point_to_host(module, event.position)
	if _resize_module_id == module_id and _resize_touch_index == -1:
		_update_resize(pointer)
		module.accept_event()
		return
	if _drag_module_id == module_id and _drag_touch_index == -1:
		surface.update_module_drag(pointer)
		module.accept_event()


func _handle_screen_touch(
	event: InputEventScreenTouch, module_id: StringName, module: WorkspaceModule
) -> void:
	var pointer := _module_point_to_host(module, event.position)
	if event.pressed:
		_raise_floating_module(module_id, module)
		if module.is_collapse_point(event.position):
			if surface.collapse_module(module_id):
				_refresh_tray()
			module.accept_event()
			return
		if module.is_resize_point(event.position):
			if _begin_resize(module_id, pointer, event.index):
				module.accept_event()
			return
		if module.is_header_drag_point(event.position):
			_pending_touch_module_id = module_id
			_pending_touch_index = event.index
			_pending_touch_started_ms = Time.get_ticks_msec()
			_pending_touch_start_pointer = pointer
			_pending_touch_travel = 0.0
			module.accept_event()
			return
	else:
		if _resize_module_id == module_id and _resize_touch_index == event.index:
			_finish_resize()
			module.accept_event()
			return
		if _drag_module_id == module_id and _drag_touch_index == event.index:
			surface.update_module_drag(pointer)
			surface.commit_module_drag()
			_clear_drag()
			module.accept_event()
			return
		if _pending_touch_module_id == module_id and _pending_touch_index == event.index:
			_clear_pending_touch()
			module.accept_event()


func _handle_screen_drag(
	event: InputEventScreenDrag, module_id: StringName, module: WorkspaceModule
) -> void:
	var pointer := _module_point_to_host(module, event.position)
	if _resize_module_id == module_id and _resize_touch_index == event.index:
		_update_resize(pointer)
		module.accept_event()
		return
	if _drag_module_id == module_id and _drag_touch_index == event.index:
		surface.update_module_drag(pointer)
		module.accept_event()
		return
	if _pending_touch_module_id != module_id or _pending_touch_index != event.index:
		return

	_pending_touch_travel += event.relative.length()
	var elapsed := Time.get_ticks_msec() - _pending_touch_started_ms
	if elapsed < TOUCH_LONG_PRESS_MS:
		if _pending_touch_travel > TOUCH_CANCEL_DISTANCE:
			_clear_pending_touch()
		module.accept_event()
		return
	if _pending_touch_travel > TOUCH_CANCEL_DISTANCE:
		_clear_pending_touch()
		module.accept_event()
		return
	if _begin_drag(module_id, _pending_touch_start_pointer, event.index):
		surface.update_module_drag(pointer)
	_clear_pending_touch(false)
	module.accept_event()


func _begin_drag(module_id: StringName, pointer: Vector2, touch_index: int) -> bool:
	if _drag_module_id != &"" or _resize_module_id != &"":
		return false
	if not surface.begin_module_drag(module_id, pointer):
		return false
	_drag_module_id = module_id
	_drag_touch_index = touch_index
	return true


func _clear_drag() -> void:
	_drag_module_id = &""
	_drag_touch_index = -1


func _begin_resize(module_id: StringName, pointer: Vector2, touch_index: int) -> bool:
	if _resize_module_id != &"" or _drag_module_id != &"":
		return false
	if surface.get_module_placement(module_id) != WorkspaceSurface.Placement.FLOATING:
		return false
	var rect := surface.get_floating_rect(module_id)
	if not rect.has_area():
		return false
	_resize_module_id = module_id
	_resize_touch_index = touch_index
	_resize_start_pointer = pointer
	_resize_start_rect = rect
	return true


func _update_resize(pointer: Vector2) -> void:
	if _resize_module_id == &"":
		return
	var delta := pointer - _resize_start_pointer
	var rect := Rect2(_resize_start_rect.position, _resize_start_rect.size + delta)
	surface.set_floating_rect(_resize_module_id, rect)


func _finish_resize() -> void:
	_resize_module_id = &""
	_resize_touch_index = -1
	_resize_start_pointer = Vector2.ZERO
	_resize_start_rect = Rect2()


func _clear_pending_touch(clear_active_drag := true) -> void:
	_pending_touch_module_id = &""
	_pending_touch_index = -1
	_pending_touch_started_ms = 0
	_pending_touch_start_pointer = Vector2.ZERO
	_pending_touch_travel = 0.0
	if clear_active_drag:
		return


func _module_point_to_host(module: WorkspaceModule, local_point: Vector2) -> Vector2:
	var viewport_point := module.get_global_transform_with_canvas() * local_point
	return dock_host.get_global_transform_with_canvas().affine_inverse() * viewport_point


func _raise_floating_module(module_id: StringName, module: WorkspaceModule) -> void:
	if surface.get_module_placement(module_id) != WorkspaceSurface.Placement.FLOATING:
		return
	if module.get_parent() == surface.get_floating_layer():
		module.move_to_front()


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
	var collapsed_ids: Array[StringName] = []
	for module_id in manager.get_registered_ids():
		if surface.get_module_placement(module_id) == WorkspaceSurface.Placement.COLLAPSED:
			collapsed_ids.append(module_id)
	for module_id in collapsed_ids:
		var button := Button.new()
		button.text = manager.get_definition(module_id).get_resolved_display_name()
		button.tooltip_text = tr("Restore %s") % button.text
		button.custom_minimum_size.y = TRAY_BUTTON_MIN_HEIGHT
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_entered.connect(_on_tray_mouse_entered.bind(module_id))
		button.mouse_exited.connect(_on_tray_mouse_exited.bind(module_id))
		button.pressed.connect(_on_tray_pressed.bind(module_id))
		_tray.add_child(button)
	_tray.visible = not collapsed_ids.is_empty()
	_layout_tray.call_deferred()


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
