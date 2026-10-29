extends "res://tests/test_base.gd"

const PENCIL_SOURCE := "res://src/Tools/DesignTools/Pencil.gd"
const OPTIONS_SOURCE := "res://src/Tools/DesignTools/Pencil.tscn"
const OUTLINE_SHADER := "res://src/Shaders/Effects/AutoOutline.gdshader"


func test_auto_outline_is_a_persisted_layer_effect_not_direct_brush_pixels() -> void:
	var pencil := FileAccess.get_file_as_string(PENCIL_SOURCE)
	check_has(pencil, "AUTO_OUTLINE_SHADER", "Pencil uses a separate outline shader")
	check_has(pencil, "LayerEffect.new(", "Pencil creates the native persistent effect")
	check_has(pencil, "layer.effects.append(effect)", "effect is stored with its source layer")
	check_has(
		pencil,
		"add_undo_method(func(): layer.effects.erase(effect))",
		"adding an effect is undoable"
	)
	check_has(pencil, 'add_do_property(effect, "enabled", enabled)', "effect toggle is undoable")
	check_has(
		pencil, "Global.cel_switched.connect(_sync_auto_outline_ui)", "settings follow layers"
	)
	check_has(
		pencil, "Global.project_switched.connect(_sync_auto_outline_ui)", "settings follow projects"
	)


func test_pencil_configuration_exposes_outline_options() -> void:
	var scene := FileAccess.get_file_as_string(OPTIONS_SOURCE)
	check_has(scene, 'name="AutoOutline"', "Pencil has a dedicated outline toggle")
	check_has(scene, 'name="AutoOutlineSettings"', "outline settings have their own group")
	check_has(scene, 'name="Color" type="ColorPickerButton"', "outline color is editable")
	check_has(scene, "max_value = 4.0", "outline width is capped")
	check_has(scene, 'name="Shape" type="OptionButton"', "neighbor mode is selectable")
	var pencil := FileAccess.get_file_as_string(PENCIL_SOURCE)
	check_has(pencil, 'config["auto_outline_color"]', "color default is retained")
	check_has(pencil, 'config["auto_outline_width"]', "width default is retained")
	check_has(pencil, 'config["auto_outline_diagonals"]', "neighbor default is retained")


func test_outline_uses_a_safe_nondestructive_render_path() -> void:
	var shader := FileAccess.get_file_as_string(OUTLINE_SHADER)
	var image_effect := FileAccess.get_file_as_string(
		"res://src/Classes/ShaderImageEffect.gd"
	)
	var renderer := FileAccess.get_file_as_string(
		"res://src/Classes/AutoOutlineRenderer.gd"
	)
	check_has(shader, "COLOR0 = texture(source_texture0, UV);", "GPU fallback copies pixels")
	check_has(image_effect, "AutoOutlineRenderer.apply(img, params)", "CPU renderer is selected")
	check_has(renderer, "var original_alpha := PackedByteArray()", "source alpha is immutable")
	check_has(renderer, "image.set_pixel(nx, ny, color)", "only the outline pixels are changed")
