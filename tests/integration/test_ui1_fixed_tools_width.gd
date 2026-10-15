extends "res://tests/test_base.gd"

const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const Migration := preload("res://src/UI/Workspace/WorkspaceEditorMigration.gd")


func test_ui1_tools_width_is_fixed_and_other_profiles_keep_resize_range() -> void:
	var manager := WorkspaceModuleManager.new()
	check_true(Builtins.register_defaults(manager), "built-in modules register")
	var tools_definition := manager.get_definition(Builtins.TOOLS_ID)
	check_true(tools_definition != null, "Tools module definition exists")
	if tools_definition == null:
		manager.free()
		return

	check_eq(
		Migration.TOOL_OPTIONS_WIDTH,
		BaseTool.MODE_ICON_BUTTON_SIZE + 2.0 * 12.0,
		"Mode icon plus symmetric padding determines configuration column width"
	)
	var original_min := tools_definition.minimum_size.x
	var original_preferred := tools_definition.preferred_size.x
	var original_max := tools_definition.maximum_size.x
	var migration := Migration.new()
	migration.manager = manager
	migration._configure_ui1_tools_fixed_width(true)
	check_eq(
		tools_definition.minimum_size.x,
		Migration.UI1_TOOLS_FIXED_WIDTH,
		"UI1 minimum width equals fixed compact width",
	)
	check_eq(
		tools_definition.preferred_size.x,
		Migration.UI1_TOOLS_FIXED_WIDTH,
		"UI1 preferred width equals fixed compact width",
	)
	check_eq(
		tools_definition.maximum_size.x,
		Migration.UI1_TOOLS_FIXED_WIDTH,
		"UI1 maximum width equals fixed compact width",
	)
	check_true(tools_definition.is_horizontal_resize_locked(), "UI1 horizontal resize disabled")
	check_eq(
		tools_definition.get_constrained_size(Vector2(250.0, 300.0)).x,
		Migration.UI1_TOOLS_FIXED_WIDTH,
		"saved wide Tools width is clamped on UI1 restoration",
	)
	migration._configure_ui1_tools_fixed_width(false)
	check_eq(tools_definition.minimum_size.x, original_min, "UI2/UI3 minimum width restored")
	check_eq(
		tools_definition.preferred_size.x, original_preferred, "UI2/UI3 preferred width restored"
	)
	check_eq(tools_definition.maximum_size.x, original_max, "UI2/UI3 maximum width restored")
	check_true(
		not tools_definition.is_horizontal_resize_locked(), "UI2/UI3 keep horizontal resizing"
	)
	migration.free()
	manager.free()


func test_ui1_tools_lock_removes_horizontal_hits_but_preserves_vertical_hits() -> void:
	var definition := WorkspaceModuleDefinition.new()
	definition.module_id = &"ui1_resize_test"
	definition.uses_external_content = true
	definition.minimum_size = Vector2(136.0, 80.0)
	definition.preferred_size = Vector2(136.0, 160.0)
	definition.maximum_size = Vector2(136.0, 0.0)
	var module := WorkspaceModule.new()
	var content := Control.new()
	check_true(module.configure_existing(definition, content), "fixed-width tool module loads")
	module.size = Vector2(136.0, 160.0)
	module.apply_visual_theme(WorkspaceVisualTheme.new(), &"floating")
	check_eq(
		module.get_resize_edges(Vector2(2.0, 80.0)),
		WorkspaceModule.ResizeEdge.NONE,
		"left edge is not a horizontal resize target",
	)
	check_eq(
		module.get_resize_edges(Vector2(134.0, 80.0)),
		WorkspaceModule.ResizeEdge.NONE,
		"right edge is not a horizontal resize target",
	)
	var lower_edge := module.get_resize_edges(Vector2(68.0, 158.0))
	check_true(
		(lower_edge & WorkspaceModule.ResizeEdge.BOTTOM) != 0,
		"bottom edge still resizes Tools height",
	)
	module.release_external_content()
	module.free()
	content.free()
