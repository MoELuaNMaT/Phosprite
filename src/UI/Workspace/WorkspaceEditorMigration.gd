class_name WorkspaceEditorMigration
extends Node

## P2-G bridge from Pixelorama's legacy DockableContainer to the live Workspace.
##
## Migration is transactional at startup: every expected live panel is resolved
## before any node is adopted. The central Main Canvas is not a Workspace Module;
## it remains the stable editing surface and is fitted into the rectangle left by
## occupied Top/Left/Right/Bottom docks.

signal migration_completed
signal panel_visibility_changed(module_id: StringName, visible: bool)

const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")

const WORKSPACE_SIDE_MARGIN := 8.0

const DEFAULT_LAYOUT := [
	{
		"id": Builtins.GLOBAL_TOOL_OPTIONS_ID,
		"zone": WorkspaceDockLayout.DockZone.TOP,
		"index": 0,
		"size": Vector2(280.0, 140.0),
	},
	{
		"id": Builtins.PALETTE_ID,
		"zone": WorkspaceDockLayout.DockZone.TOP,
		"index": 1,
		"size": Vector2(280.0, 140.0),
	},
	{
		"id": Builtins.TOOLS_ID,
		"zone": WorkspaceDockLayout.DockZone.LEFT,
		"index": 0,
		"size": Vector2(180.0, 220.0),
	},
	{
		"id": Builtins.LEFT_TOOL_OPTIONS_ID,
		"zone": WorkspaceDockLayout.DockZone.LEFT,
		"index": 1,
		"size": Vector2(180.0, 180.0),
	},
	{
		"id": Builtins.PREVIEW_ID,
		"zone": WorkspaceDockLayout.DockZone.RIGHT,
		"index": 0,
		"size": Vector2(280.0, 110.0),
	},
	{
		"id": Builtins.COLOR_PICKER_ID,
		"zone": WorkspaceDockLayout.DockZone.RIGHT,
		"index": 1,
		"size": Vector2(280.0, 200.0),
	},
	{
		"id": Builtins.RIGHT_TOOL_OPTIONS_ID,
		"zone": WorkspaceDockLayout.DockZone.RIGHT,
		"index": 2,
		"size": Vector2(280.0, 140.0),
	},
	{
		"id": Builtins.TIMELINE_ID,
		"zone": WorkspaceDockLayout.DockZone.BOTTOM,
		"index": 0,
		"size": Vector2(760.0, 180.0),
	},
]

var ui_root: Control
var legacy_container: DockableContainer
var manager: WorkspaceModuleManager
var surface: WorkspaceSurface
var dock_host: WorkspaceDockHost
var layout_store: WorkspaceLayoutStore
var main_canvas: Control
var live := false

var _original_panel_state: Dictionary = {}
var _context_restore: Dictionary = {}
var _main_canvas_state: Dictionary = {}
var _legacy_mouse_filter := Control.MOUSE_FILTER_STOP
var _legacy_visible := true
var _legacy_processing := true
var _previous_autosave_enabled := true
var _zen_mode := false


func setup(
	root: Control,
	legacy: DockableContainer,
	module_manager: WorkspaceModuleManager,
	workspace_surface: WorkspaceSurface,
	store: WorkspaceLayoutStore
) -> bool:
	if (
		live
		or root == null
		or legacy == null
		or module_manager == null
		or workspace_surface == null
	):
		return false
	if store == null or workspace_surface.manager != module_manager:
		return false
	ui_root = root
	legacy_container = legacy
	manager = module_manager
	surface = workspace_surface
	dock_host = surface.dock_host
	layout_store = store
	if dock_host == null:
		_clear_setup()
		return false
	return _migrate_live_editor()


func get_panel_ids() -> Array[StringName]:
	return Builtins.get_live_panel_ids()


func get_panel_name(module_id: StringName) -> String:
	var definition := manager.get_definition(module_id) if manager != null else null
	return definition.get_resolved_display_name() if definition != null else String(module_id)


func is_panel_visible(module_id: StringName) -> bool:
	if not live:
		return false
	var placement := surface.get_module_placement(module_id)
	return (
		placement == WorkspaceSurface.Placement.DOCKED
		or placement == WorkspaceSurface.Placement.FLOATING
	)


func set_panel_visible(module_id: StringName, visible: bool) -> bool:
	if not live or not manager.has_definition(module_id):
		return false
	var placement := surface.get_module_placement(module_id)
	var changed := false
	if visible:
		if placement == WorkspaceSurface.Placement.COLLAPSED:
			changed = surface.restore_module(module_id)
		elif placement == WorkspaceSurface.Placement.NONE:
			changed = _dock_default(module_id)
		else:
			return true
	else:
		if (
			placement == WorkspaceSurface.Placement.DOCKED
			or placement == WorkspaceSurface.Placement.FLOATING
		):
			changed = surface.collapse_module(module_id)
		elif placement == WorkspaceSurface.Placement.COLLAPSED:
			return true
		else:
			return true
	if changed:
		panel_visibility_changed.emit(module_id, visible)
	return changed


func set_context_panel_visible(module_id: StringName, visible: bool) -> bool:
	if not live or not manager.has_definition(module_id):
		return false
	var placement := surface.get_module_placement(module_id)
	if visible:
		if placement != WorkspaceSurface.Placement.NONE:
			return true
		if _context_restore.has(module_id):
			var restored := _restore_state(module_id, _context_restore[module_id] as Dictionary)
			if restored:
				_context_restore.erase(module_id)
				panel_visibility_changed.emit(module_id, true)
			return restored
		var docked := _dock_default(module_id)
		if docked:
			panel_visibility_changed.emit(module_id, true)
		return docked

	if placement == WorkspaceSurface.Placement.NONE:
		return true
	_context_restore[module_id] = _capture_state(module_id)
	if not surface.clear_module_placement(module_id):
		_context_restore.erase(module_id)
		return false
	panel_visibility_changed.emit(module_id, false)
	return true


func reset_default_layout() -> bool:
	if not live:
		return false
	_context_restore.clear()
	for module_id in get_panel_ids():
		if not surface.clear_module_placement(module_id):
			return false
	if not _apply_default_entries(_default_ids()):
		return false
	_sync_content_visibility_from_placements()
	_update_main_canvas_rect()
	return layout_store.save_current_layout()


func set_zen_mode(enabled: bool) -> void:
	if not live or _zen_mode == enabled:
		return
	_zen_mode = enabled
	dock_host.visible = not enabled
	_update_main_canvas_rect()


func is_zen_mode() -> bool:
	return _zen_mode


func _migrate_live_editor() -> bool:
	main_canvas = legacy_container.get_node_or_null(^"Main Canvas") as Control
	if main_canvas == null:
		_clear_setup()
		return false

	var resolved: Dictionary = {}
	for module_id in get_panel_ids():
		var node_name := Builtins.get_live_panel_node_name(module_id)
		var panel := legacy_container.get_node_or_null(NodePath(node_name)) as Control
		if panel == null:
			_clear_setup()
			return false
		resolved[module_id] = panel

	_capture_original_state(resolved)
	_previous_autosave_enabled = layout_store.autosave_enabled
	layout_store.autosave_enabled = false
	legacy_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var adopted: Array[StringName] = []
	for module_id: StringName in resolved:
		var panel := resolved[module_id] as Control
		if manager.adopt_module(module_id, panel, {"live_editor": true}) == null:
			_rollback_adoption(adopted)
			layout_store.autosave_enabled = _previous_autosave_enabled
			_restore_legacy_shell()
			_clear_setup()
			return false
		adopted.append(module_id)

	legacy_container.remove_child(main_canvas)
	ui_root.add_child(main_canvas)
	main_canvas.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var dock_index := dock_host.get_index()
	ui_root.move_child(main_canvas, maxi(0, dock_index))

	dock_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dock_host.offset_left = WORKSPACE_SIDE_MARGIN
	dock_host.offset_right = -WORKSPACE_SIDE_MARGIN
	dock_host.visible = true
	dock_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not dock_host.layout_geometry_changed.is_connected(_on_layout_geometry_changed):
		dock_host.layout_geometry_changed.connect(_on_layout_geometry_changed)

	legacy_container.visible = false
	legacy_container.set_process(false)
	live = true

	var saved_ids := _saved_layout_ids()
	var restored := layout_store.restore_current_layout()
	var layout_ready := false
	if restored:
		var missing_defaults: Array[StringName] = []
		for module_id in _default_ids():
			if not saved_ids.has(module_id):
				missing_defaults.append(module_id)
		layout_ready = _apply_default_entries(missing_defaults)
	else:
		layout_ready = _apply_default_entries(_default_ids())

	if not layout_ready:
		_rollback_live_migration()
		return false

	_sync_content_visibility_from_placements()
	_update_main_canvas_rect()
	layout_store.autosave_enabled = _previous_autosave_enabled
	if not layout_store.save_current_layout():
		_rollback_live_migration()
		return false
	migration_completed.emit()
	return true


func _capture_original_state(resolved: Dictionary) -> void:
	for module_id: StringName in resolved:
		var panel := resolved[module_id] as Control
		_original_panel_state[module_id] = {
			"parent": panel.get_parent(),
			"index": panel.get_index(),
			"visible": panel.visible,
		}
	_main_canvas_state = {
		"parent": main_canvas.get_parent(),
		"index": main_canvas.get_index(),
		"visible": main_canvas.visible,
		"anchor_left": main_canvas.anchor_left,
		"anchor_top": main_canvas.anchor_top,
		"anchor_right": main_canvas.anchor_right,
		"anchor_bottom": main_canvas.anchor_bottom,
		"offset_left": main_canvas.offset_left,
		"offset_top": main_canvas.offset_top,
		"offset_right": main_canvas.offset_right,
		"offset_bottom": main_canvas.offset_bottom,
	}
	_legacy_mouse_filter = legacy_container.mouse_filter
	_legacy_visible = legacy_container.visible
	_legacy_processing = legacy_container.is_processing()


func _rollback_live_migration() -> void:
	layout_store.autosave_enabled = false
	for module_id in get_panel_ids():
		if surface.get_module_placement(module_id) != WorkspaceSurface.Placement.NONE:
			surface.clear_module_placement(module_id)
	var adopted := get_panel_ids()
	_rollback_adoption(adopted)
	_restore_main_canvas()
	_restore_legacy_shell()
	dock_host.visible = false
	if dock_host.layout_geometry_changed.is_connected(_on_layout_geometry_changed):
		dock_host.layout_geometry_changed.disconnect(_on_layout_geometry_changed)
	live = false
	layout_store.autosave_enabled = _previous_autosave_enabled


func _rollback_adoption(adopted: Array[StringName]) -> void:
	var reverse_ids := adopted.duplicate()
	reverse_ids.reverse()
	for module_id in reverse_ids:
		var panel := manager.release_adopted_module(module_id)
		if panel == null:
			continue
		var state: Dictionary = _original_panel_state.get(module_id, {})
		var parent := state.get("parent") as Node
		if parent == null:
			continue
		parent.add_child(panel)
		parent.move_child(panel, mini(int(state.get("index", 0)), parent.get_child_count() - 1))
		panel.visible = bool(state.get("visible", true))


func _restore_main_canvas() -> void:
	if main_canvas == null or _main_canvas_state.is_empty():
		return
	if main_canvas.get_parent() != null:
		main_canvas.get_parent().remove_child(main_canvas)
	var parent := _main_canvas_state.get("parent") as Node
	if parent == null:
		return
	parent.add_child(main_canvas)
	parent.move_child(
		main_canvas, mini(int(_main_canvas_state.get("index", 0)), parent.get_child_count() - 1)
	)
	main_canvas.anchor_left = float(_main_canvas_state.get("anchor_left", 0.0))
	main_canvas.anchor_top = float(_main_canvas_state.get("anchor_top", 0.0))
	main_canvas.anchor_right = float(_main_canvas_state.get("anchor_right", 0.0))
	main_canvas.anchor_bottom = float(_main_canvas_state.get("anchor_bottom", 0.0))
	main_canvas.offset_left = float(_main_canvas_state.get("offset_left", 0.0))
	main_canvas.offset_top = float(_main_canvas_state.get("offset_top", 0.0))
	main_canvas.offset_right = float(_main_canvas_state.get("offset_right", 0.0))
	main_canvas.offset_bottom = float(_main_canvas_state.get("offset_bottom", 0.0))
	main_canvas.visible = bool(_main_canvas_state.get("visible", true))


func _restore_legacy_shell() -> void:
	if legacy_container == null:
		return
	legacy_container.mouse_filter = _legacy_mouse_filter
	legacy_container.visible = _legacy_visible
	legacy_container.set_process(_legacy_processing)


func _sync_content_visibility_from_placements() -> void:
	for module_id in get_panel_ids():
		var module := manager.get_instance(module_id)
		if module == null or module.get_content() == null:
			continue
		var placement := surface.get_module_placement(module_id)
		module.get_content().visible = (
			placement == WorkspaceSurface.Placement.DOCKED
			or placement == WorkspaceSurface.Placement.FLOATING
		)


func _apply_default_entries(module_ids: Array[StringName]) -> bool:
	for entry in DEFAULT_LAYOUT:
		var module_id := entry.get("id", &"") as StringName
		if not module_ids.has(module_id):
			continue
		var module := manager.get_instance(module_id)
		if module != null and module.get_content() != null:
			module.get_content().visible = true
		if not surface.dock_module(
			module_id,
			int(entry.get("zone", WorkspaceDockLayout.DockZone.NONE)),
			int(entry.get("index", -1)),
			entry.get("size", Vector2.ZERO) as Vector2
		):
			return false
	return true


func _dock_default(module_id: StringName) -> bool:
	for entry in DEFAULT_LAYOUT:
		if entry.get("id", &"") as StringName != module_id:
			continue
		var module := manager.get_instance(module_id)
		if module != null and module.get_content() != null:
			module.get_content().visible = true
		return surface.dock_module(
			module_id,
			int(entry.get("zone", WorkspaceDockLayout.DockZone.NONE)),
			int(entry.get("index", -1)),
			entry.get("size", Vector2.ZERO) as Vector2
		)

	var definition := manager.get_definition(module_id)
	if definition == null:
		return false
	var module := manager.get_instance(module_id)
	if module != null and module.get_content() != null:
		module.get_content().visible = true
	return surface.dock_module(
		module_id,
		WorkspaceDockLayout.DockZone.RIGHT,
		-1,
		definition.get_constrained_preferred_size()
	)


func _capture_state(module_id: StringName) -> Dictionary:
	var placement := surface.get_module_placement(module_id)
	if placement == WorkspaceSurface.Placement.DOCKED:
		return {
			"placement": WorkspaceSurface.Placement.DOCKED,
			"zone": dock_host.layout.get_module_zone(module_id),
			"index": dock_host.layout.get_module_index(module_id),
			"size": dock_host.layout.get_module_size(module_id),
		}
	if placement == WorkspaceSurface.Placement.FLOATING:
		return {
			"placement": WorkspaceSurface.Placement.FLOATING,
			"rect": surface.get_floating_rect(module_id),
		}
	if placement == WorkspaceSurface.Placement.COLLAPSED:
		return {
			"placement": WorkspaceSurface.Placement.COLLAPSED,
			"restore": surface.get_restore_state(module_id),
		}
	return {"placement": WorkspaceSurface.Placement.NONE}


func _restore_state(module_id: StringName, state: Dictionary) -> bool:
	var placement := int(state.get("placement", WorkspaceSurface.Placement.NONE))
	if placement == WorkspaceSurface.Placement.DOCKED:
		return surface.dock_module(
			module_id,
			int(state.get("zone", WorkspaceDockLayout.DockZone.RIGHT)),
			int(state.get("index", -1)),
			state.get("size", Vector2.ZERO) as Vector2
		)
	if placement == WorkspaceSurface.Placement.FLOATING:
		return surface.float_module(module_id, state.get("rect", Rect2()) as Rect2)
	if placement == WorkspaceSurface.Placement.COLLAPSED:
		var restore := state.get("restore", {}) as Dictionary
		if not _restore_state(module_id, restore):
			return false
		return surface.collapse_module(module_id)
	return _dock_default(module_id)


func _saved_layout_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if layout_store.config_cache == null:
		return ids
	if not layout_store.config_cache.has_section_key(
		WorkspaceLayoutStore.CONFIG_SECTION, WorkspaceLayoutStore.CONFIG_STATE_KEY
	):
		return ids
	var value: Variant = layout_store.config_cache.get_value(
		WorkspaceLayoutStore.CONFIG_SECTION, WorkspaceLayoutStore.CONFIG_STATE_KEY, {}
	)
	if not value is Dictionary:
		return ids
	for raw_entry: Variant in (value as Dictionary).get("modules", []):
		if raw_entry is Dictionary:
			ids.append(StringName(str((raw_entry as Dictionary).get("id", ""))))
	return ids


func _default_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry in DEFAULT_LAYOUT:
		ids.append(entry.get("id", &"") as StringName)
	return ids


func _on_layout_geometry_changed(_content_rect: Rect2) -> void:
	_update_main_canvas_rect()


func _update_main_canvas_rect() -> void:
	if not live or main_canvas == null or dock_host == null:
		return
	var content_rect := Rect2(Vector2.ZERO, dock_host.size)
	if not _zen_mode:
		content_rect = dock_host.get_content_rect()
	main_canvas.position = dock_host.position + content_rect.position
	main_canvas.size = content_rect.size


func _clear_setup() -> void:
	ui_root = null
	legacy_container = null
	manager = null
	surface = null
	dock_host = null
	layout_store = null
	main_canvas = null
	_original_panel_state.clear()
	_context_restore.clear()
	_main_canvas_state.clear()
	live = false
