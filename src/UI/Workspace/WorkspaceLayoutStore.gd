class_name WorkspaceLayoutStore
extends Node

## Versioned persistence and named presets for the Workspace layout system.
##
## The current layout is stored in the application's existing ConfigFile while
## named Workspace presets live below the existing layouts directory in their
## own subdirectory. P2-G also uses transient updates for context-driven panel
## visibility changes that must not overwrite the user's chosen layout.

signal current_layout_saved(snapshot: Dictionary)
signal preset_saved(preset_name: String)
signal preset_loaded(preset_name: String)
signal preset_deleted(preset_name: String)

const SCHEMA_VERSION := 1
const CONFIG_SECTION := "workspace"
const CONFIG_STATE_KEY := "layout_state"
const PRESET_SECTION := "workspace_layout"
const PRESET_STATE_KEY := "state"
const PRESET_NAME_KEY := "display_name"
const PRESET_EXTENSION := ".workspace.cfg"
const INVALID_PRESET_NAME_CHARACTERS := '/\\:*?"<>|'

var surface: WorkspaceSurface
var manager: WorkspaceModuleManager
var config_cache: ConfigFile
var config_path := ""
var preset_directory := ""
var autosave_enabled := true

var _applying_snapshot := false
var _autosave_queued := false
var _transient_update_depth := 0


func setup(
	workspace_surface: WorkspaceSurface,
	config: ConfigFile,
	current_config_path := "",
	presets_path := ""
) -> bool:
	if workspace_surface == null or config == null or surface != null:
		return false
	if workspace_surface.manager == null or workspace_surface.dock_host == null:
		return false

	surface = workspace_surface
	manager = surface.manager
	config_cache = config
	config_path = current_config_path
	preset_directory = presets_path
	if not preset_directory.is_empty():
		var error := DirAccess.make_dir_recursive_absolute(preset_directory)
		if error != OK and error != ERR_ALREADY_EXISTS:
			_clear_setup_state()
			return false
	_connect_layout_signals()
	return true


func capture_snapshot() -> Dictionary:
	var modules: Array[Dictionary] = []
	if surface == null or manager == null:
		return {"schema_version": SCHEMA_VERSION, "modules": modules}
	for module_id in manager.get_registered_ids():
		modules.append(_capture_module(module_id))
	return {"schema_version": SCHEMA_VERSION, "modules": modules}


func apply_snapshot(snapshot: Dictionary) -> bool:
	if not _validate_snapshot(snapshot):
		return false
	var rollback := capture_snapshot()
	_applying_snapshot = true
	var applied := _apply_snapshot_unchecked(snapshot)
	if not applied:
		_apply_snapshot_unchecked(rollback)
	_applying_snapshot = false
	_autosave_queued = false
	return applied


func save_current_layout(flush_to_disk := true) -> bool:
	if config_cache == null:
		return false
	var snapshot := capture_snapshot()
	config_cache.set_value(CONFIG_SECTION, CONFIG_STATE_KEY, snapshot)
	if flush_to_disk and not config_path.is_empty():
		var error := config_cache.save(config_path)
		if error != OK:
			return false
	current_layout_saved.emit(snapshot.duplicate(true))
	return true


func restore_current_layout() -> bool:
	if config_cache == null:
		return false
	if not config_cache.has_section_key(CONFIG_SECTION, CONFIG_STATE_KEY):
		return false
	var value: Variant = config_cache.get_value(CONFIG_SECTION, CONFIG_STATE_KEY)
	if not value is Dictionary:
		return false
	return apply_snapshot(value as Dictionary)


func begin_transient_update() -> void:
	if _transient_update_depth == 0 and _autosave_queued:
		_autosave_queued = false
		save_current_layout()
	_transient_update_depth += 1


func end_transient_update() -> void:
	if _transient_update_depth <= 0:
		return
	_transient_update_depth -= 1


func save_preset(preset_name: String) -> bool:
	var normalized := preset_name.strip_edges()
	if not _is_valid_preset_name(normalized) or preset_directory.is_empty():
		return false
	var preset := ConfigFile.new()
	preset.set_value(PRESET_SECTION, PRESET_NAME_KEY, normalized)
	preset.set_value(PRESET_SECTION, PRESET_STATE_KEY, capture_snapshot())
	if preset.save(_preset_path(normalized)) != OK:
		return false
	preset_saved.emit(normalized)
	return true


func load_preset(preset_name: String) -> bool:
	var normalized := preset_name.strip_edges()
	if not _is_valid_preset_name(normalized) or preset_directory.is_empty():
		return false
	var preset := ConfigFile.new()
	if preset.load(_preset_path(normalized)) != OK:
		return false
	var value: Variant = preset.get_value(PRESET_SECTION, PRESET_STATE_KEY, {})
	if not value is Dictionary or not apply_snapshot(value as Dictionary):
		return false
	if not save_current_layout():
		return false
	preset_loaded.emit(normalized)
	return true


func delete_preset(preset_name: String) -> bool:
	var normalized := preset_name.strip_edges()
	if not _is_valid_preset_name(normalized) or preset_directory.is_empty():
		return false
	var path := _preset_path(normalized)
	if not FileAccess.file_exists(path):
		return false
	var directory := DirAccess.open(preset_directory)
	if directory == null or directory.remove(path.get_file()) != OK:
		return false
	preset_deleted.emit(normalized)
	return true


func preset_exists(preset_name: String) -> bool:
	var normalized := preset_name.strip_edges()
	return (
		_is_valid_preset_name(normalized)
		and not preset_directory.is_empty()
		and FileAccess.file_exists(_preset_path(normalized))
	)


func list_presets() -> PackedStringArray:
	var result := PackedStringArray()
	if preset_directory.is_empty() or not DirAccess.dir_exists_absolute(preset_directory):
		return result
	for file_name in DirAccess.get_files_at(preset_directory):
		if not file_name.ends_with(PRESET_EXTENSION):
			continue
		var preset := ConfigFile.new()
		if preset.load(preset_directory.path_join(file_name)) != OK:
			continue
		var display_name := str(preset.get_value(PRESET_SECTION, PRESET_NAME_KEY, "")).strip_edges()
		if _is_valid_preset_name(display_name):
			result.append(display_name)
	result.sort()
	return result


func _capture_module(module_id: StringName) -> Dictionary:
	var placement := surface.get_module_placement(module_id)
	var entry := {
		"id": String(module_id),
		"placement": String(WorkspaceSurface.placement_name(placement)),
	}
	match placement:
		WorkspaceSurface.Placement.DOCKED:
			entry["zone"] = String(
				WorkspaceDockLayout.zone_name(surface.dock_host.layout.get_module_zone(module_id))
			)
			entry["index"] = surface.dock_host.layout.get_module_index(module_id)
			entry["size"] = _vector_to_array(surface.dock_host.layout.get_module_size(module_id))
		WorkspaceSurface.Placement.FLOATING:
			entry["rect"] = _rect_to_array(surface.get_floating_rect(module_id))
		WorkspaceSurface.Placement.COLLAPSED:
			entry["restore"] = _encode_restore_state(surface.get_restore_state(module_id))
	return entry


func _apply_snapshot_unchecked(snapshot: Dictionary) -> bool:
	for module_id in manager.get_registered_ids():
		if not surface.clear_module_placement(module_id):
			return false

	var known_entries: Array[Dictionary] = []
	for raw_entry: Variant in snapshot.get("modules", []):
		if not raw_entry is Dictionary:
			continue
		var entry := raw_entry as Dictionary
		var module_id := StringName(str(entry.get("id", "")))
		if manager.has_definition(module_id):
			known_entries.append(entry)

	known_entries.sort_custom(_entry_apply_order)
	for entry in known_entries:
		if not _apply_module_entry(entry):
			return false
	return true


func _apply_module_entry(entry: Dictionary) -> bool:
	var module_id := StringName(str(entry.get("id", "")))
	var placement := str(entry.get("placement", "none"))
	match placement:
		"none":
			return true
		"docked":
			return surface.dock_module(
				module_id,
				_zone_from_name(str(entry.get("zone", "none"))),
				int(entry.get("index", -1)),
				_array_to_vector(entry.get("size", []))
			)
		"floating":
			return surface.float_module(module_id, _array_to_rect(entry.get("rect", [])))
		"collapsed":
			return _apply_collapsed_entry(module_id, entry.get("restore", {}) as Dictionary)
		_:
			return false


func _apply_collapsed_entry(module_id: StringName, restore: Dictionary) -> bool:
	var restore_placement := str(restore.get("placement", "none"))
	var placed := false
	if restore_placement == "docked":
		placed = surface.dock_module(
			module_id,
			_zone_from_name(str(restore.get("zone", "none"))),
			int(restore.get("index", -1)),
			_array_to_vector(restore.get("size", []))
		)
	elif restore_placement == "floating":
		placed = surface.float_module(module_id, _array_to_rect(restore.get("rect", [])))
	if not placed:
		return false
	var module := manager.get_instance(module_id)
	if module != null and module.get_content() != null:
		# A persisted collapsed entry represents a visible panel whose body is folded.
		# Some legacy panels (notably Canvas Preview) start hidden in UI.tscn, so seed
		# the expanded visibility before collapse records its restore state.
		module.get_content().visible = true
	return surface.collapse_module(module_id)


func _validate_snapshot(snapshot: Dictionary) -> bool:
	if int(snapshot.get("schema_version", -1)) != SCHEMA_VERSION:
		return false
	var raw_modules: Variant = snapshot.get("modules", null)
	if not raw_modules is Array:
		return false
	var seen: Dictionary = {}
	for raw_entry: Variant in raw_modules:
		if not raw_entry is Dictionary:
			return false
		var entry := raw_entry as Dictionary
		var module_id := StringName(str(entry.get("id", "")))
		if module_id == &"" or seen.has(module_id):
			return false
		seen[module_id] = true
		if not manager.has_definition(module_id):
			continue
		if not _validate_known_entry(module_id, entry):
			return false
	return true


func _validate_known_entry(module_id: StringName, entry: Dictionary) -> bool:
	var definition := manager.get_definition(module_id)
	var placement := str(entry.get("placement", "none"))
	match placement:
		"none":
			return true
		"docked":
			return (
				definition.can_dock
				and surface.dock_host.layout.is_valid_zone(
					_zone_from_name(str(entry.get("zone", "")))
				)
				and _is_vector_array(entry.get("size", null))
			)
		"floating":
			return definition.can_float and _is_rect_array(entry.get("rect", null))
		"collapsed":
			return (
				definition.can_collapse
				and _validate_restore_state(definition, entry.get("restore", {}))
			)
	return false


func _validate_restore_state(definition: WorkspaceModuleDefinition, raw_restore: Variant) -> bool:
	if not raw_restore is Dictionary:
		return false
	var restore := raw_restore as Dictionary
	var placement := str(restore.get("placement", "none"))
	if placement == "docked":
		return (
			definition.can_dock
			and surface.dock_host.layout.is_valid_zone(
				_zone_from_name(str(restore.get("zone", "")))
			)
			and _is_vector_array(restore.get("size", null))
		)
	if placement == "floating":
		return definition.can_float and _is_rect_array(restore.get("rect", null))
	return false


func _encode_restore_state(restore: Dictionary) -> Dictionary:
	var placement := int(restore.get("placement", WorkspaceSurface.Placement.NONE))
	if placement == WorkspaceSurface.Placement.DOCKED:
		return {
			"placement": "docked",
			"zone": String(WorkspaceDockLayout.zone_name(int(restore.get("zone", -1)))),
			"index": int(restore.get("index", -1)),
			"size": _vector_to_array(restore.get("size", Vector2.ZERO) as Vector2),
		}
	if placement == WorkspaceSurface.Placement.FLOATING:
		return {
			"placement": "floating",
			"rect": _rect_to_array(restore.get("rect", Rect2()) as Rect2),
		}
	return {"placement": "none"}


func _entry_apply_order(a: Dictionary, b: Dictionary) -> bool:
	var a_placement := str(a.get("placement", "none"))
	var b_placement := str(b.get("placement", "none"))
	var a_dock := a_placement == "docked"
	var b_dock := b_placement == "docked"
	if a_dock != b_dock:
		return a_dock
	if a_dock:
		var a_zone := _zone_from_name(str(a.get("zone", "none")))
		var b_zone := _zone_from_name(str(b.get("zone", "none")))
		if a_zone != b_zone:
			return a_zone < b_zone
		return int(a.get("index", -1)) < int(b.get("index", -1))
	return str(a.get("id", "")) < str(b.get("id", ""))


func _connect_layout_signals() -> void:
	surface.module_floated.connect(_on_module_floated)
	surface.module_collapsed.connect(_on_module_collapsed)
	surface.module_restored.connect(_on_module_restored)
	surface.module_cleared.connect(_on_module_cleared)
	surface.dock_host.module_docked.connect(_on_module_docked)
	surface.dock_host.layout.module_size_changed.connect(_on_module_size_changed)


func _on_module_floated(_module_id: StringName, _rect: Rect2) -> void:
	_queue_autosave()


func _on_module_collapsed(_module_id: StringName) -> void:
	_queue_autosave()


func _on_module_restored(_module_id: StringName, _placement: int) -> void:
	_queue_autosave()


func _on_module_cleared(_module_id: StringName) -> void:
	_queue_autosave()


func _on_module_docked(_module_id: StringName, _zone: int, _index: int) -> void:
	_queue_autosave()


func _on_module_size_changed(_module_id: StringName, _size: Vector2) -> void:
	_queue_autosave()


func _queue_autosave() -> void:
	if (
		not autosave_enabled
		or _applying_snapshot
		or _transient_update_depth > 0
		or _autosave_queued
	):
		return
	_autosave_queued = true
	call_deferred(&"_flush_queued_autosave")


func _flush_queued_autosave() -> void:
	_autosave_queued = false
	if autosave_enabled and not _applying_snapshot and _transient_update_depth == 0:
		save_current_layout()


func _preset_path(preset_name: String) -> String:
	return preset_directory.path_join(preset_name + PRESET_EXTENSION)


func _is_valid_preset_name(preset_name: String) -> bool:
	if preset_name.is_empty() or preset_name == "." or preset_name == "..":
		return false
	if preset_name.ends_with("."):
		return false
	for character in INVALID_PRESET_NAME_CHARACTERS:
		if preset_name.contains(character):
			return false
	return true


func _zone_from_name(zone_name: String) -> int:
	match zone_name:
		"top":
			return WorkspaceDockLayout.DockZone.TOP
		"left":
			return WorkspaceDockLayout.DockZone.LEFT
		"right":
			return WorkspaceDockLayout.DockZone.RIGHT
		"bottom":
			return WorkspaceDockLayout.DockZone.BOTTOM
	return WorkspaceDockLayout.DockZone.NONE


func _vector_to_array(value: Vector2) -> Array[float]:
	return [value.x, value.y]


func _array_to_vector(raw: Variant) -> Vector2:
	if not _is_vector_array(raw):
		return Vector2.ZERO
	var values := raw as Array
	return Vector2(float(values[0]), float(values[1]))


func _rect_to_array(value: Rect2) -> Array[float]:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


func _array_to_rect(raw: Variant) -> Rect2:
	if not _is_rect_array(raw):
		return Rect2()
	var values := raw as Array
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


func _is_vector_array(raw: Variant) -> bool:
	return raw is Array and (raw as Array).size() == 2


func _is_rect_array(raw: Variant) -> bool:
	return raw is Array and (raw as Array).size() == 4


func _clear_setup_state() -> void:
	surface = null
	manager = null
	config_cache = null
	config_path = ""
	preset_directory = ""
