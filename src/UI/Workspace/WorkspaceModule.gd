class_name WorkspaceModule
extends MarginContainer

## Runtime wrapper for workspace content.
##
## The wrapper deliberately contains no docking or visual-surface policy. It
## owns one content scene and exposes a single lifecycle that future layout
## systems can drive.

signal lifecycle_changed(module_id: StringName, previous_state: int, new_state: int)

enum LifecycleState {
	CREATED,
	INITIALIZED,
	MOUNTED,
	ACTIVE,
	DISPOSED,
}

var definition: WorkspaceModuleDefinition
var content: Control
var lifecycle_state := LifecycleState.CREATED

var _context: Dictionary = {}
var _host: Control


func configure(module_definition: WorkspaceModuleDefinition) -> bool:
	if definition != null or lifecycle_state != LifecycleState.CREATED:
		return false
	if module_definition == null:
		return false
	var validation_errors := module_definition.get_validation_errors()
	if not validation_errors.is_empty():
		push_error("Invalid workspace module definition: %s" % "; ".join(validation_errors))
		return false

	var instance := module_definition.content_scene.instantiate()
	if not instance is Control:
		push_error(
			"Workspace module '%s' content root must inherit Control" % module_definition.module_id
		)
		instance.free()
		return false

	definition = module_definition
	content = instance as Control
	name = module_definition.get_resolved_display_name()
	custom_minimum_size = module_definition.minimum_size
	size = module_definition.get_constrained_preferred_size()
	add_child(content)
	return true


func initialize(context: Dictionary = {}) -> bool:
	if definition == null or lifecycle_state != LifecycleState.CREATED:
		return false
	_context = context.duplicate(true)
	_set_lifecycle_state(LifecycleState.INITIALIZED)
	_notify_content(&"workspace_module_initialized", [self, _context])
	return true


func mount(host: Control) -> bool:
	if host == null or lifecycle_state != LifecycleState.INITIALIZED:
		return false
	if get_parent() != null:
		get_parent().remove_child(self)
	host.add_child(self)
	_host = host
	_set_lifecycle_state(LifecycleState.MOUNTED)
	_notify_content(&"workspace_module_mounted", [self, host])
	return true


func activate() -> bool:
	if lifecycle_state != LifecycleState.MOUNTED:
		return false
	_set_lifecycle_state(LifecycleState.ACTIVE)
	_notify_content(&"workspace_module_activated", [self])
	return true


func deactivate() -> bool:
	if lifecycle_state != LifecycleState.ACTIVE:
		return false
	_set_lifecycle_state(LifecycleState.MOUNTED)
	_notify_content(&"workspace_module_deactivated", [self])
	return true


func unmount() -> bool:
	if lifecycle_state == LifecycleState.ACTIVE:
		if not deactivate():
			return false
	if lifecycle_state != LifecycleState.MOUNTED:
		return false

	var previous_host := _host
	_notify_content(&"workspace_module_unmounting", [self, previous_host])
	if get_parent() != null:
		get_parent().remove_child(self)
	_host = null
	_set_lifecycle_state(LifecycleState.INITIALIZED)
	return true


func dispose() -> bool:
	if lifecycle_state == LifecycleState.DISPOSED:
		return false
	if lifecycle_state == LifecycleState.ACTIVE:
		deactivate()
	if lifecycle_state == LifecycleState.MOUNTED:
		unmount()
	_set_lifecycle_state(LifecycleState.DISPOSED)
	_notify_content(&"workspace_module_disposed", [self])
	_context.clear()
	_host = null
	return true


func get_module_id() -> StringName:
	if definition == null:
		return &""
	return definition.module_id


func get_content() -> Control:
	return content


func get_context() -> Dictionary:
	return _context.duplicate(true)


func get_host() -> Control:
	return _host


func get_lifecycle_state() -> int:
	return lifecycle_state


func get_constrained_size(requested_size: Vector2) -> Vector2:
	if definition == null:
		return requested_size
	return definition.get_constrained_size(requested_size)


func _notify_content(method: StringName, arguments: Array) -> void:
	if is_instance_valid(content) and content.has_method(method):
		content.callv(method, arguments)


func _set_lifecycle_state(new_state: int) -> void:
	if lifecycle_state == new_state:
		return
	var previous_state := lifecycle_state
	lifecycle_state = new_state
	lifecycle_changed.emit(get_module_id(), previous_state, lifecycle_state)
