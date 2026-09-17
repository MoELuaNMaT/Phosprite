class_name WorkspaceModule
extends MarginContainer

## Runtime wrapper for workspace content.
##
## The module owns one content Control and exposes a single lifecycle for the
## layout system. Scene-backed modules instantiate their content; P2-G live
## migration can instead adopt an existing editor Control without rebuilding it.

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
var _visual_theme: WorkspaceVisualTheme
var _visual_state: StringName = &"none"
var _content_is_external := false


func configure(module_definition: WorkspaceModuleDefinition) -> bool:
	if not _can_configure(module_definition) or module_definition.uses_external_content:
		return false
	var instance := module_definition.content_scene.instantiate()
	if not instance is Control:
		push_error(
			"Workspace module '%s' content root must inherit Control" % module_definition.module_id
		)
		instance.free()
		return false
	return _configure_content(module_definition, instance as Control, false)


func configure_existing(
	module_definition: WorkspaceModuleDefinition, existing_content: Control
) -> bool:
	if not _can_configure(module_definition) or not module_definition.uses_external_content:
		return false
	if not is_instance_valid(existing_content):
		return false
	return _configure_content(module_definition, existing_content, true)


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
	_visual_theme = null
	return true


func release_external_content() -> Control:
	if not _content_is_external or not is_instance_valid(content):
		return null
	if lifecycle_state == LifecycleState.ACTIVE:
		deactivate()
	if lifecycle_state == LifecycleState.MOUNTED:
		unmount()
	if lifecycle_state != LifecycleState.INITIALIZED and lifecycle_state != LifecycleState.CREATED:
		return null
	var released := content
	if released.get_parent() == self:
		remove_child(released)
	content = null
	_content_is_external = false
	return released


func get_module_id() -> StringName:
	if definition == null:
		return &""
	return definition.module_id


func get_content() -> Control:
	return content


func is_external_content() -> bool:
	return _content_is_external


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


func apply_visual_theme(workspace_theme: WorkspaceVisualTheme, state: StringName) -> void:
	_visual_theme = workspace_theme
	_visual_state = state
	if _visual_theme == null:
		_remove_visual_margins()
		queue_redraw()
		return
	var padding := int(_visual_theme.CONTENT_PADDING)
	add_theme_constant_override(&"margin_left", padding)
	add_theme_constant_override(
		&"margin_top", int(_visual_theme.HEADER_HEIGHT + _visual_theme.CONTENT_PADDING)
	)
	add_theme_constant_override(&"margin_right", padding)
	add_theme_constant_override(&"margin_bottom", padding)
	queue_redraw()


func get_visual_state() -> StringName:
	return _visual_state


func _draw() -> void:
	if _visual_theme == null:
		return
	var module_style := _visual_theme.get_module_style(_visual_state)
	var header_style := _visual_theme.get_header_style(_visual_state)
	if module_style != null:
		draw_style_box(module_style, Rect2(Vector2.ZERO, size))
	var header_rect := Rect2(0.0, 0.0, size.x, _visual_theme.HEADER_HEIGHT)
	if header_style != null:
		draw_style_box(header_style, header_rect)
	draw_line(
		Vector2(0.0, _visual_theme.HEADER_HEIGHT),
		Vector2(size.x, _visual_theme.HEADER_HEIGHT),
		_visual_theme.border_color,
		1.0
	)
	var title: String
	if definition != null:
		title = definition.get_resolved_display_name()
	else:
		title = String(name)
	var baseline := _visual_theme.HEADER_HEIGHT * 0.5 + _visual_theme.default_font_size * 0.35
	draw_string(
		_visual_theme.default_font,
		Vector2(_visual_theme.CONTENT_PADDING + 1.0, baseline),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		maxf(0.0, size.x - (_visual_theme.CONTENT_PADDING + 1.0) * 2.0),
		_visual_theme.default_font_size,
		_visual_theme.text_color
	)


func _can_configure(module_definition: WorkspaceModuleDefinition) -> bool:
	if definition != null or lifecycle_state != LifecycleState.CREATED:
		return false
	if module_definition == null:
		return false
	var validation_errors := module_definition.get_validation_errors()
	if not validation_errors.is_empty():
		push_error("Invalid workspace module definition: %s" % "; ".join(validation_errors))
		return false
	return true


func _configure_content(
	module_definition: WorkspaceModuleDefinition, instance: Control, is_external: bool
) -> bool:
	definition = module_definition
	content = instance
	_content_is_external = is_external
	if content.get_parent() != null:
		content.get_parent().remove_child(content)
	name = module_definition.get_resolved_display_name()
	custom_minimum_size = module_definition.minimum_size
	size = module_definition.get_constrained_preferred_size()
	add_child(content)
	return true


func _remove_visual_margins() -> void:
	for constant_name in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		remove_theme_constant_override(constant_name)


func _notify_content(method: StringName, arguments: Array) -> void:
	if is_instance_valid(content) and content.has_method(method):
		content.callv(method, arguments)


func _set_lifecycle_state(new_state: int) -> void:
	if lifecycle_state == new_state:
		return
	var previous_state := lifecycle_state
	lifecycle_state = new_state
	lifecycle_changed.emit(get_module_id(), previous_state, lifecycle_state)
