class_name WorkspaceBuiltinModules
extends RefCounted

## Stable built-in IDs used by layout persistence from P2-D onward.
##
## Preview and the combined Palette + Color Picker remain scene-backed so they can
## be created independently. P2-G adds stable IDs for the rest of the live editor
## panels; those definitions expect Workspace to adopt the already-running controls.

const PREVIEW_ID := &"preview"
const PALETTE_ID := &"palette"
const TOOLS_ID := &"tools"
const SECOND_CANVAS_ID := &"second_canvas"
const TIMELINE_ID := &"animation_timeline"
## Retained only so persisted pre-merge layouts can be recognized as legacy data.
## Color Picker now lives inside the Palette Workspace module.
const COLOR_PICKER_ID := &"color_picker"
## Retained only so persisted pre-merge layouts can be recognized as legacy data.
## Global Tool Options now lives inside Animation Timeline's toolbar and is not a Workspace module.
const GLOBAL_TOOL_OPTIONS_ID := &"global_tool_options"
## Retained only so persisted pre-merge layouts can be recognized as legacy data.
## Left Tool Options now lives inside the Tools content and is not a Workspace module.
const LEFT_TOOL_OPTIONS_ID := &"left_tool_options"
const RIGHT_TOOL_OPTIONS_ID := &"right_tool_options"
const TILES_ID := &"tiles"
const OBJECT_TREE_3D_ID := &"object_tree_3d"
const REFERENCE_IMAGES_ID := &"reference_images"
const PERSPECTIVE_EDITOR_ID := &"perspective_editor"
const RECORDER_ID := &"recorder"
const UI3_TOOL_OPTIONS_ID := &"ui3_tool_options"

const PREVIEW_SCENE := preload("res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.tscn")
const PALETTE_SCENE := preload("res://src/UI/Workspace/PaletteColorPanel.tscn")
const UI3_TOOL_OPTIONS_SCENE := preload("res://src/UI/Workspace/UI3ToolOptionsContent.tscn")

const LIVE_PANEL_NODE_NAMES := {
	TOOLS_ID: "Tools",
	SECOND_CANVAS_ID: "Second Canvas",
	TIMELINE_ID: "Animation Timeline",
	PREVIEW_ID: "Canvas Preview",
	RIGHT_TOOL_OPTIONS_ID: "Right Tool Options",
	PALETTE_ID: "Palette & Color",
	TILES_ID: "Tiles",
	OBJECT_TREE_3D_ID: "3D Object Tree",
	REFERENCE_IMAGES_ID: "Reference Images",
	PERSPECTIVE_EDITOR_ID: "Perspective Editor",
	RECORDER_ID: "Recorder",
}


static func register_defaults(manager: WorkspaceModuleManager) -> bool:
	return manager.register_definitions(create_definitions())


static func create_definitions() -> Array[WorkspaceModuleDefinition]:
	var definitions: Array[WorkspaceModuleDefinition] = []

	var preview := WorkspaceModuleDefinition.new()
	preview.module_id = PREVIEW_ID
	preview.display_name = "Preview"
	preview.content_scene = PREVIEW_SCENE
	preview.minimum_size = Vector2(220.0, 110.0)
	preview.preferred_size = Vector2(328.0, 220.0)
	preview.can_dock = true
	preview.can_float = true
	preview.can_collapse = true
	definitions.append(preview)

	var palette := WorkspaceModuleDefinition.new()
	palette.module_id = PALETTE_ID
	palette.display_name = "Palette & Color"
	palette.content_scene = PALETTE_SCENE
	palette.minimum_size = Vector2(220.0, 180.0)
	palette.preferred_size = Vector2(300.0, 360.0)
	palette.can_dock = true
	palette.can_float = true
	palette.can_collapse = true
	definitions.append(palette)

	var ui3_tool_options := WorkspaceModuleDefinition.new()
	ui3_tool_options.module_id = UI3_TOOL_OPTIONS_ID
	ui3_tool_options.display_name = "Tool Options"
	ui3_tool_options.content_scene = UI3_TOOL_OPTIONS_SCENE
	ui3_tool_options.minimum_size = Vector2(280.0, 120.0)
	ui3_tool_options.preferred_size = Vector2(620.0, 220.0)
	ui3_tool_options.maximum_size = Vector2(780.0, 420.0)
	ui3_tool_options.can_dock = false
	ui3_tool_options.can_float = true
	ui3_tool_options.can_collapse = true
	definitions.append(ui3_tool_options)

	var tools := _external(TOOLS_ID, "Tools", Vector2(168.0, 220.0), Vector2(176.0, 520.0))
	tools.maximum_size = Vector2(260.0, 0.0)
	definitions.append(tools)
	definitions.append(
		_external(SECOND_CANVAS_ID, "Second Canvas", Vector2(260.0, 180.0), Vector2(420.0, 300.0))
	)
	definitions.append(
		_external(TIMELINE_ID, "Animation Timeline", Vector2(360.0, 160.0), Vector2(760.0, 240.0))
	)
	definitions.append(
		_external(
			RIGHT_TOOL_OPTIONS_ID,
			"Right Tool Options",
			Vector2(160.0, 140.0),
			Vector2(220.0, 260.0)
		)
	)
	definitions.append(_external(TILES_ID, "Tiles", Vector2(220.0, 160.0), Vector2(280.0, 280.0)))
	definitions.append(
		_external(OBJECT_TREE_3D_ID, "3D Object Tree", Vector2(220.0, 160.0), Vector2(280.0, 280.0))
	)
	definitions.append(
		_external(
			REFERENCE_IMAGES_ID, "Reference Images", Vector2(220.0, 160.0), Vector2(300.0, 260.0)
		)
	)
	definitions.append(
		_external(
			PERSPECTIVE_EDITOR_ID,
			"Perspective Editor",
			Vector2(260.0, 180.0),
			Vector2(420.0, 300.0)
		)
	)
	definitions.append(
		_external(RECORDER_ID, "Recorder", Vector2(220.0, 140.0), Vector2(300.0, 220.0))
	)

	return definitions


static func get_live_panel_node_name(module_id: StringName) -> String:
	return String(LIVE_PANEL_NODE_NAMES.get(module_id, ""))


static func get_live_panel_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for module_id: StringName in LIVE_PANEL_NODE_NAMES:
		ids.append(module_id)
	return ids


static func _external(
	module_id: StringName, display_name: String, minimum_size: Vector2, preferred_size: Vector2
) -> WorkspaceModuleDefinition:
	var definition := WorkspaceModuleDefinition.new()
	definition.module_id = module_id
	definition.display_name = display_name
	definition.uses_external_content = true
	definition.minimum_size = minimum_size
	definition.preferred_size = preferred_size
	definition.can_dock = true
	definition.can_float = true
	definition.can_collapse = true
	return definition
