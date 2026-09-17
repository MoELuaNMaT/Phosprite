class_name WorkspaceThemeController
extends Node

## Applies WorkspaceVisualTheme to runtime modules and placement surfaces.

var manager: WorkspaceModuleManager
var surface: WorkspaceSurface
var visual_theme := WorkspaceVisualTheme.new()


func setup(module_manager: WorkspaceModuleManager, workspace_surface: WorkspaceSurface) -> bool:
	if module_manager == null or workspace_surface == null or manager != null:
		return false
	if workspace_surface.manager != module_manager:
		return false
	manager = module_manager
	surface = workspace_surface
	manager.module_created.connect(_on_module_created)
	surface.module_floated.connect(_on_module_floated)
	surface.module_collapsed.connect(_on_module_collapsed)
	surface.module_peek_changed.connect(_on_module_peek_changed)
	surface.module_restored.connect(_on_module_restored)
	surface.module_cleared.connect(_on_module_cleared)
	surface.dock_host.module_docked.connect(_on_module_docked)
	return true


func refresh(source_theme: Theme, base: Color, accent: Color, contrast := 0.3) -> bool:
	if manager == null or surface == null:
		return false
	if not visual_theme.refresh(source_theme, base, accent, contrast):
		return false
	surface.set_preview_color(visual_theme.preview_color)
	for module_id in manager.get_registered_ids():
		_apply_module(module_id)
	return true


func _on_module_created(module_id: StringName, _module: WorkspaceModule) -> void:
	_apply_module(module_id)


func _on_module_docked(module_id: StringName, _zone: int, _index: int) -> void:
	_apply_module(module_id)


func _on_module_floated(module_id: StringName, _rect: Rect2) -> void:
	_apply_module(module_id)


func _on_module_collapsed(module_id: StringName) -> void:
	_apply_module(module_id)


func _on_module_peek_changed(module_id: StringName, _peeking: bool) -> void:
	_apply_module(module_id)


func _on_module_restored(module_id: StringName, _placement: int) -> void:
	_apply_module(module_id)


func _on_module_cleared(module_id: StringName) -> void:
	_apply_module(module_id)


func _apply_module(module_id: StringName) -> void:
	var module := manager.get_instance(module_id) if manager != null else null
	if module == null:
		return
	var state := _visual_state_for(module_id)
	module.apply_visual_theme(visual_theme, state)


func _visual_state_for(module_id: StringName) -> StringName:
	if surface == null:
		return &"none"
	if surface.is_peeking(module_id):
		return &"peek"
	match surface.get_module_placement(module_id):
		WorkspaceSurface.Placement.DOCKED:
			return &"docked"
		WorkspaceSurface.Placement.FLOATING:
			return &"floating"
		WorkspaceSurface.Placement.COLLAPSED:
			return &"collapsed"
		_:
			return &"none"
