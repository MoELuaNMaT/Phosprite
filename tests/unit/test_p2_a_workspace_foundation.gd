extends "res://tests/test_base.gd"

const Definition := preload("res://src/UI/Workspace/WorkspaceModuleDefinition.gd")
const Module := preload("res://src/UI/Workspace/WorkspaceModule.gd")
const Manager := preload("res://src/UI/Workspace/WorkspaceModuleManager.gd")
const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const PREVIEW_SCENE_PATH := "res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.tscn"
const PALETTE_SCENE_PATH := "res://src/Palette/PalettePanel.tscn"


func test_definition_contract_and_size_constraints() -> void:
	var definition := Definition.new()
	definition.module_id = &"test.module"
	definition.display_name = "Test Module"
	definition.content_scene = load(PREVIEW_SCENE_PATH)
	definition.minimum_size = Vector2(100.0, 80.0)
	definition.preferred_size = Vector2(240.0, 180.0)
	definition.maximum_size = Vector2(400.0, 300.0)
	definition.can_dock = true
	definition.can_float = false
	definition.can_collapse = true

	check_true(definition.is_valid(), "a complete module definition should validate")
	check_eq(
		definition.get_constrained_size(Vector2(10.0, 600.0)),
		Vector2(100.0, 300.0),
		"size constraints should clamp both axes"
	)
	check_true(definition.can_dock, "dock capability should be declared")
	check_true(not definition.can_float, "float capability should be declared")
	check_true(definition.can_collapse, "collapse capability should be declared")


func test_builtin_preview_and_palette_are_registered() -> void:
	var manager := Manager.new()
	check_true(Builtins.register_defaults(manager), "built-in module registration should succeed")
	var ids := manager.get_registered_ids()

	check_has(ids, Builtins.PREVIEW_ID, "Preview should have a stable workspace module ID")
	check_has(ids, Builtins.PALETTE_ID, "Palette should have a stable workspace module ID")
	check_eq(
		manager.get_definition(Builtins.PREVIEW_ID).content_scene.resource_path,
		PREVIEW_SCENE_PATH,
		"Preview should keep using the existing Preview scene"
	)
	check_eq(
		manager.get_definition(Builtins.PALETTE_ID).content_scene.resource_path,
		PALETTE_SCENE_PATH,
		"Palette should keep using the existing Palette scene"
	)
	manager.free()


func test_manager_creates_preview_and_palette_as_independent_modules() -> void:
	var manager := Manager.new()
	Builtins.register_defaults(manager)
	var preview := manager.create_module(Builtins.PREVIEW_ID)
	var palette := manager.create_module(Builtins.PALETTE_ID)

	check_true(preview != null, "Preview should be creatable as a Workspace Module")
	check_true(palette != null, "Palette should be creatable as a Workspace Module")
	check_ne(preview, palette, "Preview and Palette should be independent module instances")
	check_eq(preview.get_content().name, "CanvasPreviewContainer", "Preview content should instantiate")
	check_eq(palette.get_content().name, "PalettePanel", "Palette content should instantiate")
	check_eq(
		preview.get_lifecycle_state(),
		Module.LifecycleState.INITIALIZED,
		"created modules should finish the initialize lifecycle step"
	)
	check_eq(
		manager.create_module(Builtins.PREVIEW_ID),
		preview,
		"module ID should identify one managed instance"
	)
	manager.destroy_all_modules()
	manager.free()


func test_manager_drives_mount_activate_unmount_and_destroy_lifecycle() -> void:
	var manager := Manager.new()
	var host := Control.new()
	Builtins.register_defaults(manager)
	var preview := manager.create_module(Builtins.PREVIEW_ID)

	check_eq(
		manager.mount_module(Builtins.PREVIEW_ID, host),
		preview,
		"manager should mount an initialized module"
	)
	check_eq(preview.get_parent(), host, "mounted module should belong to the requested host")
	check_eq(
		preview.get_lifecycle_state(),
		Module.LifecycleState.MOUNTED,
		"mount should update the lifecycle state"
	)
	check_true(manager.activate_module(Builtins.PREVIEW_ID), "manager should activate a mounted module")
	check_eq(
		preview.get_lifecycle_state(),
		Module.LifecycleState.ACTIVE,
		"activate should update the lifecycle state"
	)
	check_true(manager.unmount_module(Builtins.PREVIEW_ID), "manager should unmount an active module")
	check_eq(preview.get_parent(), null, "unmounted module should be detached from its host")
	check_eq(
		preview.get_lifecycle_state(),
		Module.LifecycleState.INITIALIZED,
		"unmount should return the module to initialized state"
	)
	check_true(manager.destroy_module(Builtins.PREVIEW_ID), "manager should destroy a managed module")
	check_true(
		not manager.has_instance(Builtins.PREVIEW_ID),
		"destroyed module should be removed from the manager"
	)

	host.free()
	manager.free()
