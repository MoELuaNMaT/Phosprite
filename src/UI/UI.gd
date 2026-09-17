extends Panel

const UI_TRANSPARENCY_SHADER := preload("uid://bwtsxcdoe2ps1")
const WORKSPACE_MANAGER_SCRIPT := preload("res://src/UI/Workspace/WorkspaceModuleManager.gd")
const WORKSPACE_BUILTINS := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const WORKSPACE_DOCK_HOST_SCRIPT := preload("res://src/UI/Workspace/WorkspaceDockHost.gd")
const WORKSPACE_SURFACE_SCRIPT := preload("res://src/UI/Workspace/WorkspaceSurface.gd")
const WORKSPACE_LAYOUT_STORE_SCRIPT := preload("res://src/UI/Workspace/WorkspaceLayoutStore.gd")
const WORKSPACE_THEME_CONTROLLER_SCRIPT := preload(
	"res://src/UI/Workspace/WorkspaceThemeController.gd"
)
const WORKSPACE_EDITOR_MIGRATION_SCRIPT := preload(
	"res://src/UI/Workspace/WorkspaceEditorMigration.gd"
)
const WORKSPACE_INTERACTION_CONTROLLER_SCRIPT := preload(
	"res://src/UI/Workspace/WorkspaceInteractionController.gd"
)
const WORKSPACE_WINDOW_MENU_BRIDGE_SCRIPT := preload(
	"res://src/UI/Workspace/WorkspaceWindowMenuBridge.gd"
)

var shader_disabled := false
var transparency_material: ShaderMaterial
var workspace_manager: WorkspaceModuleManager
var workspace_dock_host: WorkspaceDockHost
var workspace_surface: WorkspaceSurface
var workspace_layout_store: WorkspaceLayoutStore
var workspace_theme_controller: WorkspaceThemeController
var workspace_migration: WorkspaceEditorMigration
var workspace_interaction_controller: WorkspaceInteractionController
var workspace_window_menu_bridge: WorkspaceWindowMenuBridge

@onready var dockable_container: DockableContainer = $DockableContainer
@onready var main_canvas_container := find_child("Main Canvas") as Container
@onready var right_tool_options: ScrollContainer = $"DockableContainer/Right Tool Options"
@onready var tiles: TileSetPanel = $DockableContainer/Tiles
@onready var object_tree_3d: PanelContainer = $"DockableContainer/3D Object Tree"


func _ready() -> void:
	_setup_workspace_foundation()
	Global.cel_switched.connect(_on_cel_switched)
	Global.single_tool_mode_changed.connect(_on_single_tool_mode_changed)
	if Global.window_transparency:
		transparency_material = ShaderMaterial.new()
		transparency_material.shader = UI_TRANSPARENCY_SHADER
		material = transparency_material
		main_canvas_container.property_list_changed.connect(_re_configure_shader)
		update_transparent_shader()
	await Global.pixelorama_opened
	_apply_context_panel_visibility()


func is_workspace_live() -> bool:
	return workspace_migration != null and workspace_migration.live


func _setup_workspace_foundation() -> void:
	workspace_manager = WORKSPACE_MANAGER_SCRIPT.new()
	workspace_manager.name = "WorkspaceManager"
	add_child(workspace_manager)
	if not WORKSPACE_BUILTINS.register_defaults(workspace_manager):
		push_error("Failed to register one or more built-in Workspace Modules")

	workspace_dock_host = WORKSPACE_DOCK_HOST_SCRIPT.new()
	workspace_dock_host.name = "WorkspaceDockHost"
	workspace_dock_host.visible = false
	workspace_dock_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(workspace_dock_host)
	workspace_dock_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not workspace_dock_host.setup(workspace_manager):
		push_error("Failed to initialize the P2-B Workspace Dock Host")
		return

	workspace_surface = WORKSPACE_SURFACE_SCRIPT.new()
	workspace_surface.name = "WorkspaceSurface"
	add_child(workspace_surface)
	if not workspace_surface.setup(workspace_manager, workspace_dock_host):
		push_error("Failed to initialize the P2-C Workspace Surface")
		return

	workspace_theme_controller = WORKSPACE_THEME_CONTROLLER_SCRIPT.new()
	workspace_theme_controller.name = "WorkspaceThemeController"
	add_child(workspace_theme_controller)
	if not workspace_theme_controller.setup(workspace_manager, workspace_surface):
		push_error("Failed to initialize the P2-E Workspace Theme Controller")
		return
	if not Themes.theme_switched.is_connected(_refresh_workspace_theme):
		Themes.theme_switched.connect(_refresh_workspace_theme)
	_refresh_workspace_theme()

	workspace_layout_store = WORKSPACE_LAYOUT_STORE_SCRIPT.new()
	workspace_layout_store.name = "WorkspaceLayoutStore"
	add_child(workspace_layout_store)
	var workspace_preset_dir := Global.LAYOUT_DIR.path_join("workspace")
	if not workspace_layout_store.setup(
		workspace_surface, Global.config_cache, Global.CONFIG_PATH, workspace_preset_dir
	):
		push_error("Failed to initialize the P2-D Workspace Layout Store")
		return

	workspace_migration = WORKSPACE_EDITOR_MIGRATION_SCRIPT.new()
	workspace_migration.name = "WorkspaceEditorMigration"
	add_child(workspace_migration)
	if not workspace_migration.setup(
		self, dockable_container, workspace_manager, workspace_surface, workspace_layout_store
	):
		push_error("P2-G live Workspace migration failed; keeping the legacy editor layout")
		return

	workspace_interaction_controller = WORKSPACE_INTERACTION_CONTROLLER_SCRIPT.new()
	workspace_interaction_controller.name = "WorkspaceInteractionController"
	add_child(workspace_interaction_controller)
	if not workspace_interaction_controller.setup(workspace_manager, workspace_surface):
		push_error("Failed to initialize P2-G Workspace interactions")
		return

	workspace_window_menu_bridge = WORKSPACE_WINDOW_MENU_BRIDGE_SCRIPT.new()
	workspace_window_menu_bridge.name = "WorkspaceWindowMenuBridge"
	add_child(workspace_window_menu_bridge)
	_refresh_workspace_theme()
	_setup_workspace_window_menu.call_deferred()


func _setup_workspace_window_menu() -> void:
	if not is_workspace_live() or workspace_window_menu_bridge == null:
		return
	var menu_root := Global.top_menu_container as Control
	if not is_instance_valid(menu_root):
		menu_root = get_tree().current_scene.find_child("TopMenuContainer") as Control
	if menu_root == null:
		push_error("P2-G could not resolve the existing Window menu")
		return
	if not workspace_window_menu_bridge.setup(
		menu_root, workspace_migration, workspace_layout_store
	):
		push_error("P2-G failed to bridge Window menus to Workspace")


func _refresh_workspace_theme() -> void:
	if workspace_theme_controller == null:
		return
	var source_theme := Global.control.theme if is_instance_valid(Global.control) else theme
	if source_theme == null:
		return
	workspace_theme_controller.refresh(
		source_theme,
		Global.theme_base_color,
		Global.theme_accent_color,
		Global.theme_color_contrast
	)


func _apply_context_panel_visibility() -> void:
	if not is_workspace_live():
		if Global.single_tool_mode:
			dockable_container.set_control_hidden.call_deferred(right_tool_options, true)
		dockable_container.set_control_hidden.call_deferred(tiles, true)
		dockable_container.set_control_hidden.call_deferred(object_tree_3d, true)
		return
	_on_single_tool_mode_changed(Global.single_tool_mode)
	_on_cel_switched()


func _on_cel_switched() -> void:
	var cel := Global.current_project.get_current_cel()
	if is_workspace_live():
		workspace_layout_store.begin_transient_update()
		workspace_migration.set_context_panel_visible(WORKSPACE_BUILTINS.TILES_ID, cel is CelTileMap)
		workspace_migration.set_context_panel_visible(
			WORKSPACE_BUILTINS.OBJECT_TREE_3D_ID, cel is Cel3D
		)
		workspace_layout_store.end_transient_update()
		return
	dockable_container.set_control_hidden(tiles, cel is not CelTileMap)
	dockable_container.set_control_hidden(object_tree_3d, cel is not Cel3D)


func _on_single_tool_mode_changed(mode: bool) -> void:
	if is_workspace_live():
		workspace_layout_store.begin_transient_update()
		workspace_migration.set_context_panel_visible(
			WORKSPACE_BUILTINS.RIGHT_TOOL_OPTIONS_ID, not mode
		)
		workspace_layout_store.end_transient_update()
		return
	dockable_container.set_control_hidden(right_tool_options, mode)


func _re_configure_shader() -> void:
	await get_tree().process_frame
	if get_window() != main_canvas_container.get_window():
		material = null
		shader_disabled = true
	else:
		if shader_disabled:
			material = transparency_material
			shader_disabled = false


func _on_main_canvas_item_rect_changed() -> void:
	update_transparent_shader()


func _on_main_canvas_visibility_changed() -> void:
	update_transparent_shader()


func update_transparent_shader() -> void:
	if not is_instance_valid(main_canvas_container) or not is_instance_valid(transparency_material):
		return
	# Works independently of the transparency feature
	var canvas_size: Vector2 = (main_canvas_container.size - Vector2.DOWN * 2) * Global.shrink
	transparency_material.set_shader_parameter("screen_resolution", get_viewport().size)
	transparency_material.set_shader_parameter(
		"position", main_canvas_container.global_position * Global.shrink
	)
	transparency_material.set_shader_parameter("size", canvas_size)
