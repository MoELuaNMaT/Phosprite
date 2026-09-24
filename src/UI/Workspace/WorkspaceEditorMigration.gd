class_name WorkspaceEditorMigration
extends Node

## P2-G bridge from Pixelorama's legacy DockableContainer to the live Workspace.
##
## Migration is transactional at startup: every expected live panel is resolved
## before any node is adopted. The central Main Canvas is not a Workspace Module;
## it remains the stable editing surface beneath Workspace chrome. Docked and
## floating modules overlay the Canvas instead of carving space out of it.

signal migration_completed
signal panel_visibility_changed(module_id: StringName, visible: bool)

const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const STORAGE_POLICY := preload("res://src/PlatformServices/StoragePolicy.gd")
const TIMELINE_HEADER_CONTROLS_SCENE := preload(
	"res://src/UI/Workspace/TimelineHeaderControls.tscn"
)

const WORKSPACE_SIDE_MARGIN := 8.0
const TOOL_PALETTE_WIDTH := 40.0
const TOOL_OPTIONS_WIDTH := 60.0

const DEFAULT_LAYOUT := [
	{
		"id": Builtins.TIMELINE_ID,
		"zone": WorkspaceDockLayout.DockZone.BOTTOM,
		"index": 0,
		"size": Vector2(760.0, 220.0),
		"region_fill": true,
	},
	{
		"id": Builtins.TOOLS_ID,
		"zone": WorkspaceDockLayout.DockZone.LEFT,
		"index": 0,
		"size": Vector2(108.0, 400.0),
	},
	{
		"id": Builtins.PREVIEW_ID,
		"zone": WorkspaceDockLayout.DockZone.RIGHT,
		"index": 0,
		"size": Vector2(280.0, 110.0),
	},
	{
		"id": Builtins.PALETTE_ID,
		"zone": WorkspaceDockLayout.DockZone.RIGHT,
		"index": 1,
		"size": Vector2(300.0, 360.0),
	},
	{
		"id": Builtins.RIGHT_TOOL_OPTIONS_ID,
		"zone": WorkspaceDockLayout.DockZone.RIGHT,
		"index": 2,
		"size": Vector2(280.0, 140.0),
	},
]

var ui_root: Control
var legacy_container: DockableContainer
var manager: WorkspaceModuleManager
var surface: WorkspaceSurface
var dock_host: WorkspaceDockHost
var layout_store: WorkspaceLayoutStore
var main_canvas: Control
var project_tabs: Control
var viewport_container: Control
var horizontal_ruler: Control
var vertical_ruler: Control
var canvas_camera: CanvasCamera
var live := false

var _ruler_overlay: Control
var _ruler_project: Project
var _left_tool_options: ScrollContainer
var _merged_tools_content: HBoxContainer
var _merged_tools_separator: VSeparator
var _left_tool_options_state: Dictionary = {}
var _tools_palette_state: Dictionary = {}
var _palette_color_root: VBoxContainer
var _palette_color_separator: HSeparator
var _palette_color_states: Dictionary = {}
var _tools_root_vertical_scroll_mode := ScrollContainer.SCROLL_MODE_AUTO
var _tools_root_horizontal_scroll_mode := ScrollContainer.SCROLL_MODE_AUTO
var _left_tool_options_vertical_scroll_mode := ScrollContainer.SCROLL_MODE_AUTO
var _left_tool_options_horizontal_scroll_mode := ScrollContainer.SCROLL_MODE_AUTO
var _original_panel_state: Dictionary = {}
var _context_restore: Dictionary = {}
var _main_canvas_state: Dictionary = {}
var _chrome_states: Dictionary = {}
var _project_tabs_height := 0.0
var _legacy_mouse_filter := Control.MOUSE_FILTER_STOP
var _legacy_visible := true
var _legacy_processing := true
var _previous_autosave_enabled := true
var _zen_mode := false
var _single_project_editor := false
var _timeline_height_restore_generation := 0
var _active_ui_profile := 1


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
	_single_project_editor = STORAGE_POLICY.uses_managed_project_storage()
	if dock_host == null:
		_clear_setup()
		return false
	surface.configure_floating_snap_policy(
		{Builtins.TIMELINE_ID: WorkspaceDockLayout.DockZone.BOTTOM}
	)
	return _migrate_live_editor()


func get_panel_ids() -> Array[StringName]:
	return Builtins.get_live_panel_ids()


func get_panel_name(module_id: StringName) -> String:
	var definition := manager.get_definition(module_id) if manager != null else null
	return definition.get_resolved_display_name() if definition != null else String(module_id)


func get_ui_profile() -> int:
	return _active_ui_profile


func activate_ui_profile(profile_id: int) -> bool:
	if profile_id < 1 or profile_id > WorkspaceLayoutStore.LAYOUT_SLOT_COUNT:
		return false
	# This is the stable implementation switch point for future UI variants.
	# Profiles currently share the same live Workspace implementation; later
	# profiles may recompose modules or route to profile-specific controls here.
	_active_ui_profile = profile_id
	return true


func sync_workspace_content_visibility() -> void:
	if not live:
		return
	_sync_content_visibility_from_placements()
	_update_main_canvas_rect()


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

	if placement == WorkspaceSurface.Placement.NONE and surface.is_module_parked(module_id):
		return true
	_context_restore[module_id] = _capture_state(module_id)
	if not surface.park_module(module_id):
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


func merge_left_tool_options_after_startup() -> bool:
	if not live:
		return false
	if is_instance_valid(_merged_tools_content):
		return true
	if not _merge_left_tool_options_into_tools():
		return false
	if dock_host != null:
		dock_host.refresh_layout_geometry()
	return true


func _migrate_live_editor() -> bool:
	main_canvas = legacy_container.get_node_or_null(^"Main Canvas") as Control
	_left_tool_options = legacy_container.get_node_or_null(^"Left Tool Options") as ScrollContainer
	var legacy_palette := legacy_container.get_node_or_null(^"Palettes") as Control
	var legacy_color_picker := legacy_container.get_node_or_null(^"Color Picker") as Control
	if (
		main_canvas == null
		or _left_tool_options == null
		or legacy_palette == null
		or legacy_color_picker == null
	):
		_clear_setup()
		return false

	var resolved: Dictionary = {}
	for module_id in get_panel_ids():
		if module_id == Builtins.PALETTE_ID:
			continue
		var node_name := Builtins.get_live_panel_node_name(module_id)
		var panel := legacy_container.get_node_or_null(NodePath(node_name)) as Control
		if panel == null:
			_clear_setup()
			return false
		resolved[module_id] = panel
	if not _merge_palette_and_color_picker(legacy_palette, legacy_color_picker):
		_clear_setup()
		return false
	resolved[Builtins.PALETTE_ID] = _palette_color_root

	_capture_original_state(resolved)
	_previous_autosave_enabled = layout_store.autosave_enabled
	layout_store.autosave_enabled = false
	legacy_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var adopted: Array[StringName] = []
	for module_id: StringName in resolved:
		var panel := resolved[module_id] as Control
		if manager.adopt_module(module_id, panel, {"live_editor": true}) == null:
			_rollback_adoption(adopted)
			_restore_palette_color_merge()
			layout_store.autosave_enabled = _previous_autosave_enabled
			_restore_legacy_shell()
			_clear_setup()
			return false
		adopted.append(module_id)

	if not _attach_timeline_header_options():
		_rollback_adoption(adopted)
		_restore_palette_color_merge()
		layout_store.autosave_enabled = _previous_autosave_enabled
		_restore_legacy_shell()
		_clear_setup()
		return false

	legacy_container.remove_child(main_canvas)
	ui_root.add_child(main_canvas)
	main_canvas.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var dock_index := dock_host.get_index()
	ui_root.move_child(main_canvas, maxi(0, dock_index))
	_prepare_canvas_chrome()

	dock_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dock_host.offset_left = 0.0
	dock_host.offset_top = _project_tabs_height
	dock_host.offset_right = 0.0
	dock_host.set_side_inset(WORKSPACE_SIDE_MARGIN)
	dock_host.visible = true
	dock_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not dock_host.layout_geometry_changed.is_connected(_on_layout_geometry_changed):
		dock_host.layout_geometry_changed.connect(_on_layout_geometry_changed)
	if not ui_root.resized.is_connected(_on_workspace_resized):
		ui_root.resized.connect(_on_workspace_resized)

	legacy_container.visible = false
	legacy_container.set_process(false)
	live = true
	_active_ui_profile = layout_store.get_active_layout_slot()

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
	if not _bind_timeline_workspace_state():
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


func _merge_palette_and_color_picker(palette: Control, color_picker: Control) -> bool:
	if is_instance_valid(_palette_color_root):
		return true
	if palette == null or color_picker == null:
		return false
	var palette_parent := palette.get_parent()
	var picker_parent := color_picker.get_parent()
	if palette_parent == null or picker_parent != palette_parent:
		return false

	_palette_color_states = {
		"palette":
		{
			"node": palette,
			"parent": palette_parent,
			"index": palette.get_index(),
			"visible": palette.visible,
			"size_flags_horizontal": palette.size_flags_horizontal,
			"size_flags_vertical": palette.size_flags_vertical,
			"stretch_ratio": palette.size_flags_stretch_ratio,
		},
		"picker":
		{
			"node": color_picker,
			"parent": picker_parent,
			"index": color_picker.get_index(),
			"visible": color_picker.visible,
			"size_flags_horizontal": color_picker.size_flags_horizontal,
			"size_flags_vertical": color_picker.size_flags_vertical,
			"stretch_ratio": color_picker.size_flags_stretch_ratio,
		},
	}
	var insert_index := mini(palette.get_index(), color_picker.get_index())
	palette_parent.remove_child(palette)
	picker_parent.remove_child(color_picker)

	_palette_color_root = VBoxContainer.new()
	_palette_color_root.name = Builtins.get_live_panel_node_name(Builtins.PALETTE_ID)
	_palette_color_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_palette_color_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_palette_color_root.add_theme_constant_override(&"separation", 0)
	palette_parent.add_child(_palette_color_root)
	palette_parent.move_child(
		_palette_color_root, mini(insert_index, palette_parent.get_child_count() - 1)
	)

	palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette.size_flags_stretch_ratio = 0.9
	_palette_color_root.add_child(palette)

	_palette_color_separator = HSeparator.new()
	_palette_color_separator.name = &"PaletteColorSeparator"
	_palette_color_root.add_child(_palette_color_separator)

	color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	color_picker.size_flags_stretch_ratio = 1.1
	_palette_color_root.add_child(color_picker)
	return true


func _restore_palette_color_merge() -> void:
	if not is_instance_valid(_palette_color_root) or _palette_color_states.is_empty():
		return
	var entries: Array[Dictionary] = []
	for key in ["palette", "picker"]:
		var state := _palette_color_states.get(key, {}) as Dictionary
		if state.is_empty():
			continue
		var node := state.get("node") as Control
		if node != null and node.get_parent() != null:
			node.get_parent().remove_child(node)
		entries.append(state)
	if _palette_color_root.get_parent() != null:
		_palette_color_root.get_parent().remove_child(_palette_color_root)
	_palette_color_root.free()
	_palette_color_root = null
	_palette_color_separator = null

	entries.sort_custom(
		func(a: Dictionary, b: Dictionary): return int(a["index"]) < int(b["index"])
	)
	for state in entries:
		var node := state.get("node") as Control
		var parent := state.get("parent") as Node
		if node == null or parent == null:
			continue
		parent.add_child(node)
		parent.move_child(node, mini(int(state.get("index", 0)), parent.get_child_count() - 1))
		node.visible = bool(state.get("visible", true))
		node.size_flags_horizontal = int(state.get("size_flags_horizontal", Control.SIZE_FILL))
		node.size_flags_vertical = int(state.get("size_flags_vertical", Control.SIZE_FILL))
		node.size_flags_stretch_ratio = float(state.get("stretch_ratio", 1.0))
	_palette_color_states.clear()


func _update_top_edge_snap_band() -> void:
	if dock_host == null or ui_root == null:
		return
	var shell := ui_root.get_parent()
	var top_menu := (
		shell.get_node_or_null(^"TopMenuContainer") as Control if shell != null else null
	)
	if top_menu == null:
		return
	var menu_height := maxf(0.0, top_menu.size.y)
	dock_host.set_top_edge_snap_band(-(_project_tabs_height + menu_height), menu_height)


func _merge_left_tool_options_into_tools() -> bool:
	var tools_module := manager.get_instance(Builtins.TOOLS_ID)
	if tools_module == null or not tools_module.get_content() is ScrollContainer:
		return false
	var tools_root := tools_module.get_content() as ScrollContainer
	var palette := tools_root.get_node_or_null(^"PanelContainer") as PanelContainer
	if palette == null or not is_instance_valid(_left_tool_options):
		return false
	var left_panel := _left_tool_options.get_node_or_null(^"LeftPanelContainer") as Control
	if left_panel == null:
		return false
	if not Global.headless_test_mode:
		if (
			not is_instance_valid(Tools._tool_buttons)
			or not Tools._panels.has(MOUSE_BUTTON_LEFT)
			or Tools._panels[MOUSE_BUTTON_LEFT] != left_panel
			or not Tools._slots.has(MOUSE_BUTTON_LEFT)
			or not Tools._slots.has(MOUSE_BUTTON_RIGHT)
			or not is_instance_valid(Tools._slots[MOUSE_BUTTON_LEFT].tool_node)
			or not is_instance_valid(Tools._slots[MOUSE_BUTTON_RIGHT].tool_node)
		):
			return false
	var left_parent := _left_tool_options.get_parent()
	if left_parent == null:
		return false

	_tools_palette_state = {
		"parent": palette.get_parent(),
		"index": palette.get_index(),
		"size_flags_horizontal": palette.size_flags_horizontal,
		"size_flags_vertical": palette.size_flags_vertical,
		"stretch_ratio": palette.size_flags_stretch_ratio,
		"custom_minimum_size": palette.custom_minimum_size,
	}
	_left_tool_options_state = {
		"parent": left_parent,
		"index": _left_tool_options.get_index(),
		"visible": _left_tool_options.visible,
		"size_flags_horizontal": _left_tool_options.size_flags_horizontal,
		"size_flags_vertical": _left_tool_options.size_flags_vertical,
		"stretch_ratio": _left_tool_options.size_flags_stretch_ratio,
		"custom_minimum_size": _left_tool_options.custom_minimum_size,
	}
	_tools_root_vertical_scroll_mode = tools_root.vertical_scroll_mode
	_tools_root_horizontal_scroll_mode = tools_root.horizontal_scroll_mode
	_left_tool_options_vertical_scroll_mode = _left_tool_options.vertical_scroll_mode
	_left_tool_options_horizontal_scroll_mode = _left_tool_options.horizontal_scroll_mode

	tools_root.remove_child(palette)
	_merged_tools_content = HBoxContainer.new()
	_merged_tools_content.name = &"MergedToolsContent"
	_merged_tools_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_merged_tools_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_merged_tools_content.add_theme_constant_override(&"separation", 0)
	tools_root.add_child(_merged_tools_content)

	palette.custom_minimum_size.x = TOOL_PALETTE_WIDTH
	palette.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette.size_flags_stretch_ratio = 0.0
	_merged_tools_content.add_child(palette)
	_merged_tools_separator = VSeparator.new()
	_merged_tools_separator.name = &"ToolOptionsSeparator"
	_merged_tools_content.add_child(_merged_tools_separator)

	left_parent.remove_child(_left_tool_options)
	_left_tool_options.custom_minimum_size.x = TOOL_OPTIONS_WIDTH
	_left_tool_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_tool_options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left_tool_options.size_flags_stretch_ratio = 1.0
	_left_tool_options.visible = true
	_merged_tools_content.add_child(_left_tool_options)
	_left_tool_options.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left_tool_options.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tools_root.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tools_root.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_bind_tools_header_title(tools_module)
	return true


func _restore_merged_tools() -> void:
	if (
		not is_instance_valid(_left_tool_options)
		or not is_instance_valid(_merged_tools_content)
		or _left_tool_options_state.is_empty()
	):
		return
	var tools_module := manager.get_instance(Builtins.TOOLS_ID) if manager != null else null
	var tools_root := (
		tools_module.get_content() as ScrollContainer
		if tools_module != null and tools_module.get_content() is ScrollContainer
		else null
	)
	var palette := (
		_merged_tools_content.get_node_or_null(^"PanelContainer") as PanelContainer
		if is_instance_valid(_merged_tools_content)
		else null
	)

	if _left_tool_options.get_parent() != null:
		_left_tool_options.get_parent().remove_child(_left_tool_options)
	var left_parent := _left_tool_options_state.get("parent") as Node
	if left_parent != null:
		left_parent.add_child(_left_tool_options)
		left_parent.move_child(
			_left_tool_options,
			mini(int(_left_tool_options_state.get("index", 0)), left_parent.get_child_count() - 1)
		)
	_left_tool_options.visible = bool(_left_tool_options_state.get("visible", true))
	_left_tool_options.size_flags_horizontal = int(
		_left_tool_options_state.get("size_flags_horizontal", Control.SIZE_FILL)
	)
	_left_tool_options.size_flags_vertical = int(
		_left_tool_options_state.get("size_flags_vertical", Control.SIZE_FILL)
	)
	_left_tool_options.size_flags_stretch_ratio = float(
		_left_tool_options_state.get("stretch_ratio", 1.0)
	)
	_left_tool_options.custom_minimum_size = (
		_left_tool_options_state.get("custom_minimum_size", Vector2(72.0, 72.0)) as Vector2
	)

	if palette != null:
		_merged_tools_content.remove_child(palette)
		var palette_parent := _tools_palette_state.get("parent") as Node
		if palette_parent != null:
			palette_parent.add_child(palette)
			palette_parent.move_child(
				palette,
				mini(
					int(_tools_palette_state.get("index", 0)), palette_parent.get_child_count() - 1
				)
			)
		palette.size_flags_horizontal = int(
			_tools_palette_state.get("size_flags_horizontal", Control.SIZE_EXPAND_FILL)
		)
		palette.size_flags_vertical = int(
			_tools_palette_state.get("size_flags_vertical", Control.SIZE_EXPAND_FILL)
		)
		palette.size_flags_stretch_ratio = float(_tools_palette_state.get("stretch_ratio", 1.0))
		palette.custom_minimum_size = (
			_tools_palette_state.get("custom_minimum_size", Vector2.ZERO) as Vector2
		)

	_unbind_tools_header_title()
	if is_instance_valid(_merged_tools_separator):
		_merged_tools_separator.queue_free()
	_merged_tools_separator = null
	if is_instance_valid(_merged_tools_content):
		_merged_tools_content.queue_free()
	_merged_tools_content = null
	if tools_root != null:
		tools_root.horizontal_scroll_mode = _tools_root_horizontal_scroll_mode
		tools_root.vertical_scroll_mode = _tools_root_vertical_scroll_mode
	if is_instance_valid(_left_tool_options):
		_left_tool_options.horizontal_scroll_mode = _left_tool_options_horizontal_scroll_mode
		_left_tool_options.vertical_scroll_mode = _left_tool_options_vertical_scroll_mode


func _bind_tools_header_title(tools_module: WorkspaceModule) -> void:
	if not Tools.tool_changed.is_connected(_on_tools_header_tool_changed):
		Tools.tool_changed.connect(_on_tools_header_tool_changed)
	_sync_tools_header_title(tools_module)


func _unbind_tools_header_title() -> void:
	if Tools.tool_changed.is_connected(_on_tools_header_tool_changed):
		Tools.tool_changed.disconnect(_on_tools_header_tool_changed)
	if manager == null:
		return
	var tools_module := manager.get_instance(Builtins.TOOLS_ID)
	if tools_module != null:
		tools_module.clear_header_title_override()


func _sync_tools_header_title(tools_module: WorkspaceModule = null) -> void:
	if tools_module == null and manager != null:
		tools_module = manager.get_instance(Builtins.TOOLS_ID)
	if tools_module == null or not Tools._slots.has(MOUSE_BUTTON_LEFT):
		return
	var slot: Tools.Slot = Tools._slots[MOUSE_BUTTON_LEFT]
	if not is_instance_valid(slot.tool_node):
		return
	_set_tools_header_title(String(slot.tool_node.name), tools_module)


func _on_tools_header_tool_changed(tool_name: String, button: int) -> void:
	if button != MOUSE_BUTTON_LEFT:
		return
	_set_tools_header_title(tool_name)


func _set_tools_header_title(tool_name: String, tools_module: WorkspaceModule = null) -> void:
	if not Tools.tools.has(tool_name):
		return
	if tools_module == null and manager != null:
		tools_module = manager.get_instance(Builtins.TOOLS_ID)
	if tools_module == null:
		return
	var tool: Tools.Tool = Tools.tools[tool_name]
	tools_module.set_header_title_override(tr(tool.display_name))


func _attach_timeline_header_options() -> bool:
	var timeline := manager.get_instance(Builtins.TIMELINE_ID)
	if timeline == null:
		return false
	var controls := TIMELINE_HEADER_CONTROLS_SCENE.instantiate()
	if not controls is Control:
		if controls != null:
			controls.free()
		return false
	var header_controls := controls as Control
	if not timeline.set_header_accessory(header_controls):
		header_controls.free()
		return false
	timeline.set_position_adjustment_enabled(false)
	return true


func _bind_timeline_workspace_state() -> bool:
	var module := manager.get_instance(Builtins.TIMELINE_ID)
	if module == null:
		return false
	module.set_position_adjustment_enabled(false)
	var timeline := module.get_content() as AnimationTimeline
	if timeline == null:
		timeline = Global.animation_timeline as AnimationTimeline
	if timeline == null:
		return true
	if not timeline.timeline_mode_changing.is_connected(_on_timeline_mode_changing):
		timeline.timeline_mode_changing.connect(_on_timeline_mode_changing)
	if not timeline.timeline_mode_changed.is_connected(_on_timeline_mode_changed):
		timeline.timeline_mode_changed.connect(_on_timeline_mode_changed)
	if not Global.project_about_to_switch.is_connected(_on_timeline_project_about_to_switch):
		Global.project_about_to_switch.connect(_on_timeline_project_about_to_switch)
	if not Global.project_switched.is_connected(_on_timeline_project_switched):
		Global.project_switched.connect(_on_timeline_project_switched)
	_restore_timeline_height(timeline.get_timeline_mode())
	return true


func _unbind_timeline_workspace_state() -> void:
	var module := manager.get_instance(Builtins.TIMELINE_ID) if manager != null else null
	var timeline := (
		(
			module.get_content() as AnimationTimeline
			if module != null and module.get_content() is AnimationTimeline
			else Global.animation_timeline
		)
		as AnimationTimeline
	)
	if timeline != null:
		if timeline.timeline_mode_changing.is_connected(_on_timeline_mode_changing):
			timeline.timeline_mode_changing.disconnect(_on_timeline_mode_changing)
		if timeline.timeline_mode_changed.is_connected(_on_timeline_mode_changed):
			timeline.timeline_mode_changed.disconnect(_on_timeline_mode_changed)
	if Global.project_about_to_switch.is_connected(_on_timeline_project_about_to_switch):
		Global.project_about_to_switch.disconnect(_on_timeline_project_about_to_switch)
	if Global.project_switched.is_connected(_on_timeline_project_switched):
		Global.project_switched.disconnect(_on_timeline_project_switched)


func _on_timeline_mode_changing(from_mode: int, _to_mode: int) -> void:
	_store_current_timeline_height(from_mode)


func _on_timeline_mode_changed(mode: int) -> void:
	_restore_timeline_height(mode)
	_schedule_timeline_height_reconcile(mode)


func _on_timeline_project_about_to_switch() -> void:
	var timeline := Global.animation_timeline as AnimationTimeline
	if timeline != null:
		_store_current_timeline_height(timeline.get_timeline_mode())


func _on_timeline_project_switched() -> void:
	call_deferred("_restore_current_project_timeline_height")


func _restore_current_project_timeline_height() -> void:
	var timeline := Global.animation_timeline as AnimationTimeline
	if timeline != null:
		var mode := timeline.get_timeline_mode()
		_restore_timeline_height(mode)
		_schedule_timeline_height_reconcile(mode)


func _schedule_timeline_height_reconcile(mode: int) -> void:
	_timeline_height_restore_generation += 1
	var generation := _timeline_height_restore_generation
	var project := Global.current_project
	_restore_timeline_height_after_layout.call_deferred(mode, project, generation)


func _restore_timeline_height_after_layout(mode: int, project: Project, generation: int) -> void:
	await get_tree().process_frame
	if generation != _timeline_height_restore_generation or project != Global.current_project:
		return
	var timeline := Global.animation_timeline as AnimationTimeline
	if timeline == null or timeline.get_timeline_mode() != mode:
		return
	_restore_timeline_height(mode)


func _store_current_timeline_height(mode: int) -> void:
	var timeline := Global.animation_timeline as AnimationTimeline
	if timeline == null:
		return
	var height := _get_timeline_workspace_height()
	if height > 0.0:
		timeline.store_workspace_height(height, mode)


func _restore_timeline_height(mode: int) -> void:
	var timeline := Global.animation_timeline as AnimationTimeline
	if timeline == null:
		return
	_set_timeline_workspace_height(timeline.get_saved_workspace_height(mode))


func _get_timeline_workspace_height() -> float:
	if surface == null or dock_host == null or manager == null:
		return 0.0
	var placement := surface.get_module_placement(Builtins.TIMELINE_ID)
	if placement == WorkspaceSurface.Placement.DOCKED:
		var docked_size := dock_host.layout.get_module_size(Builtins.TIMELINE_ID)
		if docked_size.y > 0.0:
			return docked_size.y
	elif placement == WorkspaceSurface.Placement.FLOATING:
		var floating_rect := surface.get_floating_rect(Builtins.TIMELINE_ID)
		if floating_rect.size.y > 0.0:
			return floating_rect.size.y
	var module := manager.get_instance(Builtins.TIMELINE_ID)
	return module.size.y if module != null else 0.0


func _set_timeline_workspace_height(height: float) -> bool:
	if height <= 0.0 or surface == null or dock_host == null or manager == null:
		return false
	var placement := surface.get_module_placement(Builtins.TIMELINE_ID)
	if placement == WorkspaceSurface.Placement.DOCKED:
		var current_size := dock_host.layout.get_module_size(Builtins.TIMELINE_ID)
		if current_size == Vector2.ZERO:
			var module := manager.get_instance(Builtins.TIMELINE_ID)
			if module == null:
				return false
			current_size = module.size
		current_size.y = height
		return dock_host.set_module_size(Builtins.TIMELINE_ID, current_size)
	if placement == WorkspaceSurface.Placement.FLOATING:
		var rect := surface.get_floating_rect(Builtins.TIMELINE_ID)
		if not rect.has_area():
			return false
		rect.size.y = height
		return surface.set_floating_rect(Builtins.TIMELINE_ID, rect)
	return false


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
	_unbind_timeline_workspace_state()
	layout_store.autosave_enabled = false
	for module_id in get_panel_ids():
		if surface.get_module_placement(module_id) != WorkspaceSurface.Placement.NONE:
			surface.clear_module_placement(module_id)
	var adopted := get_panel_ids()
	_restore_merged_tools()
	_rollback_adoption(adopted)
	_restore_palette_color_merge()
	_restore_canvas_chrome()
	_restore_main_canvas()
	_restore_legacy_shell()
	dock_host.visible = false
	if dock_host.layout_geometry_changed.is_connected(_on_layout_geometry_changed):
		dock_host.layout_geometry_changed.disconnect(_on_layout_geometry_changed)
	if ui_root != null and ui_root.resized.is_connected(_on_workspace_resized):
		ui_root.resized.disconnect(_on_workspace_resized)
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
			entry.get("size", Vector2.ZERO) as Vector2,
			{},
			bool(entry.get("region_fill", false))
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
			entry.get("size", Vector2.ZERO) as Vector2,
			{},
			bool(entry.get("region_fill", false))
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
			"region_fill": dock_host.layout.is_module_region_fill(module_id),
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
			state.get("size", Vector2.ZERO) as Vector2,
			{},
			bool(state.get("region_fill", false))
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
	var snapshot := layout_store.get_layout_slot_snapshot(layout_store.get_active_layout_slot())
	if snapshot.is_empty():
		return ids
	for raw_entry: Variant in snapshot.get("modules", []):
		if raw_entry is Dictionary:
			ids.append(StringName(str((raw_entry as Dictionary).get("id", ""))))
	return ids


func _default_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry in DEFAULT_LAYOUT:
		ids.append(entry.get("id", &"") as StringName)
	return ids


func _on_layout_geometry_changed(_content_rect: Rect2) -> void:
	# Timeline is the only true dock. Floating edge anchors follow its top edge
	# whenever the fixed bottom bar changes height.
	if surface != null:
		surface.refresh_floating_bounds()
	_update_canvas_chrome_geometry.call_deferred()


func _on_workspace_resized() -> void:
	_update_main_canvas_rect()
	_update_canvas_chrome_geometry.call_deferred()


func _update_main_canvas_rect() -> void:
	if not live or main_canvas == null or ui_root == null:
		return
	main_canvas.position = Vector2(0.0, _project_tabs_height)
	main_canvas.size = Vector2(ui_root.size.x, maxf(0.0, ui_root.size.y - _project_tabs_height))
	if project_tabs != null:
		project_tabs.position = Vector2.ZERO
		project_tabs.size = Vector2(ui_root.size.x, _project_tabs_height)
	if dock_host != null:
		dock_host.offset_top = _project_tabs_height
		_update_top_edge_snap_band()
	_update_canvas_chrome_geometry.call_deferred()


func _prepare_canvas_chrome() -> void:
	project_tabs = main_canvas.get_node_or_null(^"TabsContainer") as Control
	horizontal_ruler = main_canvas.get_node_or_null(^"HorizontalRuler") as Control
	var viewport_row := main_canvas.get_node_or_null(^"ViewportandVerticalRuler") as Control
	if viewport_row != null:
		viewport_container = viewport_row.get_node_or_null(^"SubViewportContainer") as Control
		vertical_ruler = viewport_row.get_node_or_null(^"VerticalRuler") as Control
	if viewport_container != null:
		canvas_camera = viewport_container.get_node_or_null(^"SubViewport/Camera2D") as CanvasCamera

	for control in [project_tabs, horizontal_ruler, vertical_ruler]:
		if control != null:
			_capture_chrome_state(control)

	if project_tabs != null:
		if _single_project_editor:
			# P3 managed storage owns one Editor project at a time. The legacy project
			# TabBar is both redundant and a source of a dead input strip above Canvas.
			project_tabs.visible = false
			project_tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_project_tabs_height = 0.0
		else:
			_project_tabs_height = maxf(
				32.0, maxf(project_tabs.size.y, project_tabs.get_combined_minimum_size().y)
			)
			_reparent_control(project_tabs, ui_root)
			project_tabs.set_anchors_preset(Control.PRESET_TOP_WIDE)
			project_tabs.position = Vector2.ZERO
			project_tabs.size = Vector2(ui_root.size.x, _project_tabs_height)
			project_tabs.z_index = 20

	if horizontal_ruler == null or vertical_ruler == null or viewport_container == null:
		return
	_ruler_overlay = Control.new()
	_ruler_overlay.name = &"CanvasRulerOverlay"
	_ruler_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ruler_overlay.clip_contents = true
	ui_root.add_child(_ruler_overlay)
	_ruler_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.move_child(
		_ruler_overlay, mini(main_canvas.get_index() + 1, ui_root.get_child_count() - 1)
	)
	_reparent_control(horizontal_ruler, _ruler_overlay)
	_reparent_control(vertical_ruler, _ruler_overlay)
	if horizontal_ruler.has_method(&"set_canvas_edge_overlay_mode"):
		horizontal_ruler.call(&"set_canvas_edge_overlay_mode", true)
	if vertical_ruler.has_method(&"set_canvas_edge_overlay_mode"):
		vertical_ruler.call(&"set_canvas_edge_overlay_mode", true)

	if not viewport_container.resized.is_connected(_update_canvas_chrome_geometry):
		viewport_container.resized.connect(_update_canvas_chrome_geometry)
	if canvas_camera != null:
		for signal_name in [&"zoom_changed", &"rotation_changed", &"offset_changed"]:
			if not canvas_camera.is_connected(signal_name, _update_canvas_chrome_geometry):
				canvas_camera.connect(signal_name, _update_canvas_chrome_geometry)
	if not Global.project_switched.is_connected(_on_canvas_project_switched):
		Global.project_switched.connect(_on_canvas_project_switched)
	_bind_ruler_project()


func _on_canvas_project_switched() -> void:
	_bind_ruler_project()
	_update_canvas_chrome_geometry()


func _bind_ruler_project() -> void:
	if (
		is_instance_valid(_ruler_project)
		and _ruler_project.resized.is_connected(_on_document_resized)
	):
		_ruler_project.resized.disconnect(_on_document_resized)
	_ruler_project = Global.current_project
	if (
		is_instance_valid(_ruler_project)
		and not _ruler_project.resized.is_connected(_on_document_resized)
	):
		_ruler_project.resized.connect(_on_document_resized)


func _on_document_resized() -> void:
	_update_canvas_chrome_geometry.call_deferred()


func _update_canvas_chrome_geometry() -> void:
	if (
		not live
		or _ruler_overlay == null
		or viewport_container == null
		or canvas_camera == null
		or horizontal_ruler == null
		or vertical_ruler == null
	):
		return
	var viewport_origin := (
		_ruler_overlay.get_global_transform_with_canvas().affine_inverse()
		* viewport_container.get_global_transform_with_canvas().origin
	)
	var canvas_rect := _canvas_screen_rect()
	var horizontal_height := maxf(16.0, horizontal_ruler.get_combined_minimum_size().y)
	var vertical_width := maxf(16.0, vertical_ruler.get_combined_minimum_size().x)
	horizontal_ruler.position = (
		viewport_origin
		+ Vector2(canvas_rect.position.x, canvas_rect.position.y - horizontal_height)
	)
	horizontal_ruler.size = Vector2(maxf(0.0, canvas_rect.size.x), horizontal_height)
	vertical_ruler.position = (
		viewport_origin + Vector2(canvas_rect.position.x - vertical_width, canvas_rect.position.y)
	)
	vertical_ruler.size = Vector2(vertical_width, maxf(0.0, canvas_rect.size.y))
	horizontal_ruler.queue_redraw()
	vertical_ruler.queue_redraw()


func _canvas_screen_rect() -> Rect2:
	if viewport_container == null or canvas_camera == null:
		return Rect2()
	var zoom := canvas_camera.zoom.x
	var origin := (
		viewport_container.size / 2.0
		+ canvas_camera.offset.rotated(-canvas_camera.camera_angle) * -zoom
	)
	var project_size := Vector2(Global.current_project.size)
	var corners: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(project_size.x, 0.0),
		Vector2(0.0, project_size.y),
		project_size,
	]
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for corner: Vector2 in corners:
		var point: Vector2 = origin + corner.rotated(-canvas_camera.camera_angle) * zoom
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)


func _capture_chrome_state(control: Control) -> void:
	_chrome_states[control] = {
		"parent": control.get_parent(),
		"index": control.get_index(),
		"anchors":
		Vector4(
			control.anchor_left, control.anchor_top, control.anchor_right, control.anchor_bottom
		),
		"offsets":
		Vector4(
			control.offset_left, control.offset_top, control.offset_right, control.offset_bottom
		),
		"z_index": control.z_index,
		"visible": control.visible,
		"mouse_filter": control.mouse_filter,
	}


func _reparent_control(control: Control, parent: Node) -> void:
	if control.get_parent() != null:
		control.get_parent().remove_child(control)
	parent.add_child(control)


func _restore_canvas_chrome() -> void:
	if Global.project_switched.is_connected(_on_canvas_project_switched):
		Global.project_switched.disconnect(_on_canvas_project_switched)
	if (
		is_instance_valid(_ruler_project)
		and _ruler_project.resized.is_connected(_on_document_resized)
	):
		_ruler_project.resized.disconnect(_on_document_resized)
	_ruler_project = null
	if horizontal_ruler != null and horizontal_ruler.has_method(&"set_canvas_edge_overlay_mode"):
		horizontal_ruler.call(&"set_canvas_edge_overlay_mode", false)
	if vertical_ruler != null and vertical_ruler.has_method(&"set_canvas_edge_overlay_mode"):
		vertical_ruler.call(&"set_canvas_edge_overlay_mode", false)
	for control_variant in _chrome_states.keys():
		var control := control_variant as Control
		if control == null:
			continue
		var state := _chrome_states[control] as Dictionary
		var parent := state.get("parent") as Node
		if parent == null:
			continue
		_reparent_control(control, parent)
		parent.move_child(control, mini(int(state.get("index", 0)), parent.get_child_count() - 1))
		var anchors: Vector4 = state.get("anchors", Vector4.ZERO)
		var offsets: Vector4 = state.get("offsets", Vector4.ZERO)
		control.anchor_left = anchors.x
		control.anchor_top = anchors.y
		control.anchor_right = anchors.z
		control.anchor_bottom = anchors.w
		control.offset_left = offsets.x
		control.offset_top = offsets.y
		control.offset_right = offsets.z
		control.offset_bottom = offsets.w
		control.z_index = int(state.get("z_index", 0))
		control.visible = bool(state.get("visible", true))
		control.mouse_filter = int(state.get("mouse_filter", Control.MOUSE_FILTER_STOP))
	if is_instance_valid(_ruler_overlay):
		_ruler_overlay.queue_free()
	_ruler_overlay = null
	_chrome_states.clear()


func _clear_setup() -> void:
	if Tools.tool_changed.is_connected(_on_tools_header_tool_changed):
		Tools.tool_changed.disconnect(_on_tools_header_tool_changed)
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
	_chrome_states.clear()
	project_tabs = null
	viewport_container = null
	horizontal_ruler = null
	vertical_ruler = null
	canvas_camera = null
	_ruler_overlay = null
	_ruler_project = null
	_left_tool_options = null
	_merged_tools_content = null
	_merged_tools_separator = null
	_palette_color_root = null
	_palette_color_separator = null
	_palette_color_states.clear()
	_left_tool_options_state.clear()
	_tools_palette_state.clear()
	_project_tabs_height = 0.0
	_single_project_editor = false
	live = false
