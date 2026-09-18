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

enum ResizeEdge {
	NONE = 0,
	LEFT = 1,
	RIGHT = 2,
	BOTTOM = 4,
	TOP = 8,
}

const INTERACTION_TARGET_SIZE := 28.0
const RESIZE_EDGE_HIT_SIZE := 18.0

var definition: WorkspaceModuleDefinition
var content: Control
var lifecycle_state := LifecycleState.CREATED

var _context: Dictionary = {}
var _host: Control
var _visual_theme: WorkspaceVisualTheme
var _visual_state: StringName = &"none"
var _content_is_external := false
var _content_collapsed := false
var _content_visible_before_collapse := true
var _minimum_size_before_collapse := Vector2.ZERO
var _vertical_size_flags_before_collapse := Control.SIZE_FILL


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
	if not _can_configure(module_definition):
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
	if _content_collapsed:
		set_content_collapsed(false)
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


func set_content_collapsed(collapsed: bool) -> void:
	if _content_collapsed == collapsed:
		return
	if collapsed:
		_minimum_size_before_collapse = custom_minimum_size
		_vertical_size_flags_before_collapse = size_flags_vertical
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		if is_instance_valid(content):
			_content_visible_before_collapse = content.visible
			content.visible = false
		custom_minimum_size = Vector2(_minimum_size_before_collapse.x, get_header_height())
	else:
		custom_minimum_size = _minimum_size_before_collapse
		_minimum_size_before_collapse = Vector2.ZERO
		size_flags_vertical = _vertical_size_flags_before_collapse
		if is_instance_valid(content):
			content.visible = _content_visible_before_collapse
	_content_collapsed = collapsed
	if _visual_theme != null:
		apply_visual_theme(_visual_theme, _visual_state)
	update_minimum_size()
	queue_redraw()


func is_content_collapsed() -> bool:
	return _content_collapsed


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


func get_header_height() -> float:
	return _visual_theme.HEADER_HEIGHT if _visual_theme != null else INTERACTION_TARGET_SIZE


func get_visual_rect() -> Rect2:
	var visual_height := get_header_height() if _content_collapsed else size.y
	return Rect2(Vector2.ZERO, Vector2(size.x, visual_height))


func _has_point(point: Vector2) -> bool:
	return get_visual_rect().has_point(point)


func is_header_drag_point(local_point: Vector2) -> bool:
	if local_point.y < 0.0 or local_point.y > get_header_height():
		return false
	return not is_collapse_point(local_point) and not is_float_point(local_point)


func is_collapse_point(local_point: Vector2) -> bool:
	if definition == null or not definition.can_collapse:
		return false
	return (
		Rect2(
			Vector2(maxf(0.0, size.x - INTERACTION_TARGET_SIZE), 0.0),
			Vector2(INTERACTION_TARGET_SIZE, get_header_height())
		)
		. has_point(local_point)
	)


func is_float_point(local_point: Vector2) -> bool:
	if (
		definition == null
		or not definition.can_float
		or _visual_state != &"docked"
		or _content_collapsed
	):
		return false
	var left := maxf(0.0, size.x - INTERACTION_TARGET_SIZE * 2.0)
	return (
		Rect2(Vector2(left, 0.0), Vector2(INTERACTION_TARGET_SIZE, get_header_height()))
		. has_point(local_point)
	)


func get_resize_edges(local_point: Vector2) -> int:
	if _visual_state != &"floating" or _content_collapsed:
		return ResizeEdge.NONE
	if not get_visual_rect().has_point(local_point):
		return ResizeEdge.NONE
	var edges := ResizeEdge.NONE
	if local_point.x <= RESIZE_EDGE_HIT_SIZE:
		edges |= ResizeEdge.LEFT
	elif local_point.x >= size.x - RESIZE_EDGE_HIT_SIZE:
		edges |= ResizeEdge.RIGHT
	if local_point.y >= size.y - RESIZE_EDGE_HIT_SIZE:
		edges |= ResizeEdge.BOTTOM
	return edges


func is_resize_point(local_point: Vector2) -> bool:
	return get_resize_edges(local_point) != ResizeEdge.NONE


func apply_visual_theme(workspace_theme: WorkspaceVisualTheme, state: StringName) -> void:
	_visual_theme = workspace_theme
	_visual_state = state
	if _visual_theme == null:
		_remove_visual_margins()
		queue_redraw()
		return
	var padding := int(_visual_theme.CONTENT_PADDING)
	if state == &"collapsed" and _content_collapsed:
		add_theme_constant_override(&"margin_left", 0)
		add_theme_constant_override(&"margin_top", int(_visual_theme.HEADER_HEIGHT))
		add_theme_constant_override(&"margin_right", 0)
		add_theme_constant_override(&"margin_bottom", 0)
	else:
		var bottom_margin := padding
		if state == &"floating":
			bottom_margin = maxi(padding, int(INTERACTION_TARGET_SIZE))
		add_theme_constant_override(&"margin_left", padding)
		add_theme_constant_override(
			&"margin_top", int(_visual_theme.HEADER_HEIGHT + _visual_theme.CONTENT_PADDING)
		)
		add_theme_constant_override(&"margin_right", padding)
		add_theme_constant_override(&"margin_bottom", bottom_margin)
	queue_redraw()


func get_visual_state() -> StringName:
	return _visual_state


func _draw() -> void:
	if _visual_theme == null:
		return
	var module_style := _visual_theme.get_module_style(_visual_state)
	var header_style := _visual_theme.get_header_style(_visual_state)
	if module_style != null:
		draw_style_box(module_style, get_visual_rect())
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
	var header_actions_width := INTERACTION_TARGET_SIZE
	if (
		definition != null
		and definition.can_float
		and _visual_state == &"docked"
		and not _content_collapsed
	):
		header_actions_width += INTERACTION_TARGET_SIZE
	var title_width := maxf(
		0.0, size.x - (_visual_theme.CONTENT_PADDING + 1.0) * 2.0 - header_actions_width
	)
	draw_string(
		_visual_theme.default_font,
		Vector2(_visual_theme.CONTENT_PADDING + 1.0, baseline),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		title_width,
		_visual_theme.default_font_size,
		_visual_theme.text_color
	)
	_draw_float_affordance()
	_draw_collapse_affordance()
	_draw_resize_affordance()


func _draw_float_affordance() -> void:
	if (
		definition == null
		or not definition.can_float
		or _visual_theme == null
		or _visual_state != &"docked"
		or _content_collapsed
	):
		return
	var center := Vector2(size.x - INTERACTION_TARGET_SIZE * 1.5, _visual_theme.HEADER_HEIGHT * 0.5)
	var rect_size := Vector2(9.0, 7.0)
	var rect := Rect2(center - rect_size * 0.5 + Vector2(-1.5, 1.5), rect_size)
	draw_rect(rect, _visual_theme.muted_text_color, false, 1.2)
	draw_line(
		center + Vector2(-1.0, -1.0),
		center + Vector2(4.0, -6.0),
		_visual_theme.muted_text_color,
		1.2
	)
	draw_line(
		center + Vector2(4.0, -6.0),
		center + Vector2(4.0, -2.0),
		_visual_theme.muted_text_color,
		1.2
	)
	draw_line(
		center + Vector2(4.0, -6.0),
		center + Vector2(0.0, -6.0),
		_visual_theme.muted_text_color,
		1.2
	)


func _draw_collapse_affordance() -> void:
	if definition == null or not definition.can_collapse or _visual_theme == null:
		return
	var center := Vector2(size.x - INTERACTION_TARGET_SIZE * 0.5, _visual_theme.HEADER_HEIGHT * 0.5)
	var half := 4.0
	var direction := -1.0 if _content_collapsed else 1.0
	draw_line(
		center + Vector2(-half, 0.0),
		center + Vector2(0.0, half * direction),
		_visual_theme.muted_text_color,
		1.5
	)
	draw_line(
		center + Vector2(0.0, half * direction),
		center + Vector2(half, 0.0),
		_visual_theme.muted_text_color,
		1.5
	)


func _draw_resize_affordance() -> void:
	if _visual_state != &"floating" or _visual_theme == null or _content_collapsed:
		return
	var right_corner := size - Vector2(6.0, 6.0)
	var left_corner := Vector2(6.0, size.y - 6.0)
	for offset in [0.0, 5.0, 10.0]:
		draw_line(
			right_corner - Vector2(offset, 0.0),
			right_corner - Vector2(0.0, offset),
			_visual_theme.muted_text_color,
			1.0
		)
		draw_line(
			left_corner + Vector2(offset, 0.0),
			left_corner + Vector2(0.0, -offset),
			_visual_theme.muted_text_color,
			1.0
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
