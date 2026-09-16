class_name WorkspaceModuleDefinition
extends Resource

## Stable metadata and capability contract for a workspace module.
##
## A zero maximum on either axis means that axis is unbounded. P2-A only
## declares capabilities; later P2 stages decide where/how modules are docked,
## floated, collapsed, resized, and persisted.

const ALLOWED_ID_CHARACTERS := "abcdefghijklmnopqrstuvwxyz0123456789._-"

@export_group("Identity")
@export var module_id: StringName = &""
@export var display_name := ""
@export var content_scene: PackedScene

@export_group("Size Constraints")
@export var minimum_size := Vector2(120.0, 80.0)
@export var preferred_size := Vector2(280.0, 220.0)
@export var maximum_size := Vector2.ZERO

@export_group("Capabilities")
@export var can_dock := true
@export var can_float := true
@export var can_collapse := true


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var id_text := String(module_id)
	if not _is_valid_module_id(id_text):
		errors.append(
			"module_id must be lowercase and use only a-z, 0-9, '.', '_' or '-': %s" % id_text
		)
	if content_scene == null:
		errors.append("content_scene is required for workspace module '%s'" % id_text)
	if minimum_size.x < 0.0 or minimum_size.y < 0.0:
		errors.append("minimum_size cannot contain negative values")
	if preferred_size.x < 0.0 or preferred_size.y < 0.0:
		errors.append("preferred_size cannot contain negative values")
	if maximum_size.x < 0.0 or maximum_size.y < 0.0:
		errors.append("maximum_size cannot contain negative values")
	if maximum_size.x > 0.0 and maximum_size.x < minimum_size.x:
		errors.append("maximum_size.x cannot be smaller than minimum_size.x")
	if maximum_size.y > 0.0 and maximum_size.y < minimum_size.y:
		errors.append("maximum_size.y cannot be smaller than minimum_size.y")
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()


func get_constrained_size(requested_size: Vector2) -> Vector2:
	var constrained := Vector2(
		maxf(requested_size.x, minimum_size.x),
		maxf(requested_size.y, minimum_size.y)
	)
	if maximum_size.x > 0.0:
		constrained.x = minf(constrained.x, maximum_size.x)
	if maximum_size.y > 0.0:
		constrained.y = minf(constrained.y, maximum_size.y)
	return constrained


func get_constrained_preferred_size() -> Vector2:
	return get_constrained_size(preferred_size)


func get_resolved_display_name() -> String:
	if not display_name.strip_edges().is_empty():
		return display_name
	return String(module_id)


func _is_valid_module_id(id_text: String) -> bool:
	if id_text.is_empty():
		return false
	for index in range(id_text.length()):
		if ALLOWED_ID_CHARACTERS.find(id_text.substr(index, 1)) == -1:
			return false
	return true
