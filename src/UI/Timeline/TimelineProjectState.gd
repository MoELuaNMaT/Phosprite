class_name TimelineProjectState
extends RefCounted

const HEIGHT_SECTION := "timeline_project_heights"
const MODE_SECTION := "timeline_project_modes"
const HEIGHT_META := &"phosprite_timeline_workspace_heights"
const MODE_META := &"phosprite_timeline_mode"
const ANIMATION_MODE := 0
const SINGLE_FRAME_MODE := 1


static func get_mode(project: Object, fallback: int, min_mode: int, max_mode: int) -> int:
	if project == null:
		return fallback
	if project.has_meta(MODE_META):
		return clampi(int(project.get_meta(MODE_META)), min_mode, max_mode)
	var project_uuid := _project_uuid(project)
	if project_uuid.is_empty():
		return fallback
	var cached_mode: Variant = Global.config_cache.get_value(MODE_SECTION, project_uuid, -1)
	if int(cached_mode) < min_mode or int(cached_mode) > max_mode:
		return fallback
	var resolved := int(cached_mode)
	project.set_meta(MODE_META, resolved)
	return resolved


static func store_mode(project: Object, mode: int, min_mode: int, max_mode: int) -> void:
	if project == null:
		return
	var resolved := clampi(mode, min_mode, max_mode)
	project.set_meta(MODE_META, resolved)
	var project_uuid := _project_uuid(project)
	if project_uuid.is_empty():
		return
	Global.config_cache.set_value(MODE_SECTION, project_uuid, resolved)
	_save_config("mode")


static func get_height(project: Object, mode: int, default_height: float) -> float:
	if project == null:
		return default_height
	var key := _height_key(mode)
	var project_state := project.get_meta(HEIGHT_META, {}) as Dictionary
	if project_state.has(key):
		return maxf(float(project_state[key]), 1.0)
	var project_uuid := _project_uuid(project)
	if project_uuid.is_empty():
		return default_height
	var cached_state := (
		Global.config_cache.get_value(HEIGHT_SECTION, project_uuid, {}) as Dictionary
	)
	if not cached_state.has(key):
		return default_height
	var cached_height := maxf(float(cached_state[key]), 1.0)
	project_state = project_state.duplicate(true)
	project_state[key] = cached_height
	project.set_meta(HEIGHT_META, project_state)
	return cached_height


static func store_height(project: Object, mode: int, height: float) -> void:
	if project == null or height <= 0.0:
		return
	var key := _height_key(mode)
	var project_state := project.get_meta(HEIGHT_META, {}) as Dictionary
	project_state = project_state.duplicate(true)
	project_state[key] = height
	project.set_meta(HEIGHT_META, project_state)
	var project_uuid := _project_uuid(project)
	if project_uuid.is_empty():
		return
	var cached_state := (
		Global.config_cache.get_value(HEIGHT_SECTION, project_uuid, {}) as Dictionary
	)
	cached_state = cached_state.duplicate(true)
	cached_state[key] = height
	Global.config_cache.set_value(HEIGHT_SECTION, project_uuid, cached_state)
	_save_config("height")


static func _height_key(mode: int) -> String:
	return "single_frame" if mode == 1 else "animation"


static func _project_uuid(project: Object) -> String:
	return str(project.get("project_uuid"))


static func _save_config(state_kind: String) -> void:
	var save_error := Global.config_cache.save(Global.CONFIG_PATH)
	if save_error != OK:
		push_warning(
			(
				"Could not persist Timeline project %s cache: %s"
				% [state_kind, error_string(save_error)]
			)
		)


static func initialize_new_project(project: Object) -> void:
	if project == null:
		return
	project.set_meta(MODE_META, SINGLE_FRAME_MODE)
