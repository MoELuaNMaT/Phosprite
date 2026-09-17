extends Panel

const UI_TRANSPARENCY_SHADER := preload("uid://bwtsxcdoe2ps1")
const WORKSPACE_MANAGER_SCRIPT := preload("res://src/UI/Workspace/WorkspaceModuleManager.gd")
const WORKSPACE_BUILTINS := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const WORKSPACE_DOCK_HOST_SCRIPT := preload("res://src/UI/Workspace/WorkspaceDockHost.gd")
const WORKSPACE_SURFACE_SCRIPT := preload("res://src/UI/Workspace/WorkspaceSurface.gd")
const WORKSPACE_LAYOUT_STORE_SCRIPT := preload("res://src/UI/Workspace/WorkspaceLayoutStore.gd")

var shader_disabled := false
var transparency_material: ShaderMaterial
var workspace_manager: WorkspaceModuleManager
var workspace_dock_host: WorkspaceDockHost
var workspace_surface: WorkspaceSurface
var workspace_layout_store: WorkspaceLayoutStore

@onready var dockable_container: DockableContainer = $DockableContainer
@onready var main_canvas_container := find_child("Main Canvas") as Container
@onready var right_tool_options: ScrollContainer = $"DockableContainer/Right Tool Options"
@onready var tiles: TileSetPanel = $DockableContainer/Tiles
@onready var object_tree_3d: PanelContainer = $DockableContainer/"3D Object Tree"


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
	if Global.single_tool_mode:
		dockable_container.set_control_hidden.call_deferred(right_tool_options, true)
	dockable_container.set_control_hidden.call_deferred(tiles, true)
	dockable_container.set_control_hidden.call_deferred(object_tree_3d, true)


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

	workspace_layout_store = WORKSPACE_LAYOUT_STORE_SCRIPT.new()
	workspace_layout_store.name = "WorkspaceLayoutStore"
	add_child(workspace_layout_store)
	var workspace_preset_dir := Global.LAYOUT_DIR.path_join("workspace")
	if not workspace_layout_store.setup(
		workspace_surface, Global.config_cache, Global.CONFIG_PATH, workspace_preset_dir
	):
		push_error("Failed to initialize the P2-D Workspace Layout Store")
		return
	workspace_layout_store.restore_current_layout.call_deferred()


func _on_cel_switched() -> void:
	var cel := Global.current_project.get_current_cel()
	dockable_container.set_control_hidden(tiles, cel is not CelTileMap)
	dockable_container.set_control_hidden(object_tree_3d, cel is not Cel3D)


func _on_single_tool_mode_changed(mode: bool) -> void:
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