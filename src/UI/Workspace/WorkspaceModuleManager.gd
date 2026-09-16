class_name WorkspaceModuleManager
extends Node

## Registry, factory, and lifecycle owner for Workspace Modules.
##
## P2-A keeps modules detached until an explicit mount call so registration and
## creation do not alter the existing editor layout. P2-B can provide dock hosts
## without changing this contract.

signal definition_registered(module_id: StringName)
signal module_created(module_id: StringName, module: WorkspaceModule)
signal module_destroyed(module_id: StringName)

var _definitions: Dictionary = {}
var _instances: Dictionary = {}


func register_definition(definition: WorkspaceModuleDefinition) -> bool:
	if definition == null:
		return false
	if not definition.is_valid():
		return false
	var module_id := definition.module_id
	if _definitions.has(module_id):
		return false
	_definitions[module_id] = definition
	definition_registered.emit(module_id)
	return true


func register_definitions(definitions: Array[WorkspaceModuleDefinition]) -> bool:
	var all_registered := true
	for definition in definitions:
		if not register_definition(definition):
			all_registered = false
	return all_registered


func unregister_definition(module_id: StringName) -> bool:
	if _instances.has(module_id):
		return false
	return _definitions.erase(module_id)


func has_definition(module_id: StringName) -> bool:
	return _definitions.has(module_id)


func get_definition(module_id: StringName) -> WorkspaceModuleDefinition:
	return _definitions.get(module_id) as WorkspaceModuleDefinition


func get_registered_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for module_id: StringName in _definitions:
		ids.append(module_id)
	ids.sort_custom(func(a: StringName, b: StringName): return String(a) < String(b))
	return ids


func create_module(module_id: StringName, context: Dictionary = {}) -> WorkspaceModule:
	var existing := get_instance(module_id)
	if existing != null:
		return existing

	var definition := get_definition(module_id)
	if definition == null:
		return null

	var module := WorkspaceModule.new()
	if not module.configure(definition):
		module.free()
		return null
	if not module.initialize(context):
		module.free()
		return null

	_instances[module_id] = module
	module_created.emit(module_id, module)
	return module


func has_instance(module_id: StringName) -> bool:
	return get_instance(module_id) != null


func get_instance(module_id: StringName) -> WorkspaceModule:
	var value: Variant = _instances.get(module_id)
	if not is_instance_valid(value):
		_instances.erase(module_id)
		return null
	return value as WorkspaceModule


func mount_module(
	module_id: StringName, host: Control, context: Dictionary = {}
) -> WorkspaceModule:
	var module := create_module(module_id, context)
	if module == null:
		return null
	if module.get_lifecycle_state() == WorkspaceModule.LifecycleState.INITIALIZED:
		if not module.mount(host):
			return null
	return module


func activate_module(module_id: StringName) -> bool:
	var module := get_instance(module_id)
	if module == null:
		return false
	if module.get_lifecycle_state() == WorkspaceModule.LifecycleState.ACTIVE:
		return true
	return module.activate()


func deactivate_module(module_id: StringName) -> bool:
	var module := get_instance(module_id)
	if module == null:
		return false
	if module.get_lifecycle_state() == WorkspaceModule.LifecycleState.MOUNTED:
		return true
	return module.deactivate()


func unmount_module(module_id: StringName) -> bool:
	var module := get_instance(module_id)
	if module == null:
		return false
	if module.get_lifecycle_state() == WorkspaceModule.LifecycleState.INITIALIZED:
		return true
	return module.unmount()


func destroy_module(module_id: StringName) -> bool:
	var module := get_instance(module_id)
	if module == null:
		return false
	_instances.erase(module_id)
	module.dispose()
	module.free()
	module_destroyed.emit(module_id)
	return true


func destroy_all_modules() -> void:
	var module_ids: Array[StringName] = []
	for module_id: StringName in _instances:
		module_ids.append(module_id)
	for module_id in module_ids:
		destroy_module(module_id)


func _exit_tree() -> void:
	destroy_all_modules()
