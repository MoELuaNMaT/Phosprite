extends "res://tests/test_base.gd"

const PENCIL_SOURCE := "res://src/Tools/DesignTools/Pencil.gd"
const OPTIONS_SOURCE := "res://src/Tools/DesignTools/Pencil.tscn"
const OUTLINE_SHADER := "res://src/Shaders/Effects/AutoOutline.gdshader"


func test_auto_outline_toggle_is_project_scoped_not_layer_scoped() -> void:
	var pencil := FileAccess.get_file_as_string(PENCIL_SOURCE)
	var project := FileAccess.get_file_as_string("res://src/Classes/Project.gd")
	var layer := FileAccess.get_file_as_string("res://src/Classes/Layers/BaseLayer.gd")
	check_has(pencil, 'add_do_property(project, "auto_outline_enabled", enabled)', "undoable project toggle")
	check_has(pencil, "project.auto_outline_enabled", "checkbox reads the active project")
	check_has(pencil, "project.auto_outline_changed.connect(_sync_auto_outline_ui)", "UI reflects undo")
	check_has(pencil, "Global.project_switched.connect(_sync_auto_outline_ui)", "project selection")
	check_true(not pencil.contains("layer.effects.append(effect)"), "no per-layer effect creation")
	check_has(project, '"auto_outline_enabled": auto_outline_enabled', "enabled state saved per project")
	check_has(project, "auto_outline_enabled = bool(dict.get(", "enabled state restored per project")
	check_has(layer, "_apply_project_auto_outline(image)", "all layers use project settings")
	check_has(layer, "self is not PixelLayer", "non-pixel layers are not outlined")


func test_pencil_configuration_exposes_project_outline_options() -> void:
	var scene := FileAccess.get_file_as_string(OPTIONS_SOURCE)
	check_has(scene, 'name="AutoOutline"', "Pencil has a dedicated outline toggle")
	check_has(scene, 'name="AutoOutlineSettings"', "outline settings have their own group")
	check_has(scene, 'name="Color" type="ColorPickerButton"', "outline color is editable")
	check_has(scene, "max_value = 4.0", "outline width is capped")
	check_has(scene, 'name="Shape" type="OptionButton"', "neighbor mode is selectable")
	var project := FileAccess.get_file_as_string("res://src/Classes/Project.gd")
	check_has(project, '"auto_outline_color": auto_outline_color.to_html()', "color saved")
	check_has(project, '"auto_outline_width": auto_outline_width', "width saved")
	check_has(project, '"auto_outline_diagonals": auto_outline_diagonals', "shape saved")
	var pencil := FileAccess.get_file_as_string(PENCIL_SOURCE)
	check_true(
		not pencil.contains('config["auto_outline_color"]'),
		"project outline settings never leak into global tool defaults"
	)


func test_old_per_layer_outlines_are_migrated_to_project_settings() -> void:
	var project := FileAccess.get_file_as_string("res://src/Classes/Project.gd")
	check_has(project, 'effect.name != "Auto Outline"', "legacy effects are recognized")
	check_has(project, "layer.effects.erase(effect)", "old duplicate outlines are removed")


func test_outline_uses_a_safe_nondestructive_render_path() -> void:
	var shader := FileAccess.get_file_as_string(OUTLINE_SHADER)
	var image_effect := FileAccess.get_file_as_string("res://src/Classes/ShaderImageEffect.gd")
	var renderer := FileAccess.get_file_as_string("res://src/Classes/AutoOutlineRenderer.gd")
	check_has(shader, "COLOR0 = texture(source_texture0, UV);", "GPU fallback copies pixels")
	check_has(image_effect, "AutoOutlineRenderer.apply(img, params)", "CPU renderer is selected")
	check_has(renderer, "var original_alpha := PackedByteArray()", "source alpha is immutable")
	check_has(renderer, "image.set_pixel(nx, ny, color)", "only the outline pixels are changed")
