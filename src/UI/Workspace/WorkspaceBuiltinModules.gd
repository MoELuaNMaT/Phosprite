class_name WorkspaceBuiltinModules
extends RefCounted

## Stable built-in IDs used by layout persistence from P2-D onward.

const PREVIEW_ID := &"preview"
const PALETTE_ID := &"palette"

const PREVIEW_SCENE := preload("res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.tscn")
const PALETTE_SCENE := preload("res://src/Palette/PalettePanel.tscn")


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
	palette.display_name = "Palette"
	palette.content_scene = PALETTE_SCENE
	palette.minimum_size = Vector2(180.0, 140.0)
	palette.preferred_size = Vector2(280.0, 300.0)
	palette.can_dock = true
	palette.can_float = true
	palette.can_collapse = true
	definitions.append(palette)

	return definitions
