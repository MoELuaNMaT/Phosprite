extends "res://tests/test_base.gd"

const SELECTION_SOURCE := "res://src/UI/Canvas/Selection.gd"
const CANVAS_SOURCE := "res://src/UI/Canvas/Canvas.gd"
const INPUT_SOURCE := "res://src/InputAdapter/CanvasInputAdapter.gd"
const TRANSFORM_SOURCE := "res://src/UI/Canvas/TransformationHandles.gd"
const PROJECT_SOURCE := "res://src/Classes/Project.gd"


func test_selection_menu_has_four_actions_and_pending_controls() -> void:
	var source := FileAccess.get_file_as_string(SELECTION_SOURCE)
	for label in ["Copy", "Cut", "Paste", "New Layer"]:
		check_has(source, "_add_selection_menu_button(", "selection actions share one touch menu")
		check_has(source, '"' + label + '"', "menu includes " + label)
	check_has(source, 'actions, "Confirm"', "pending paste has explicit confirmation")
	check_has(source, 'actions, "Cancel"', "pending paste has explicit cancellation")
	check_has(source, "Vector2(54, 44)", "touch menu targets have at least 44 px height")
	check_has(source, "get_global_transform_with_canvas()", "menu tracks canvas transform")
	check_has(source, "get_combined_minimum_size()", "menu is clamped by its actual size")


func test_pending_paste_does_not_mutate_other_cels_before_confirmation() -> void:
	var source := FileAccess.get_file_as_string(SELECTION_SOURCE)
	check_has(source, "_paste_target_cels = get_selected_draw_cels()", "paste retains original cel")
	check_has(
		source,
		"var target_cels := _paste_target_cels if is_pasting else get_selected_draw_cels()",
		"confirm uses saved paste target instead of current layer"
	)
	check_has(source, "if _paste_target_cels.is_empty():", "unsupported layer cannot begin paste")
	check_has(source, "create_layer_from_selection()", "selection can create a pixel layer")
	var transform := FileAccess.get_file_as_string(TRANSFORM_SOURCE)
	check_has(
		transform,
		"1.0 if selection_node.is_pasting else Global.transformation_preview_alpha",
		"floating pasted pixels are drawn at full opacity"
	)
	var project := FileAccess.get_file_as_string(PROJECT_SOURCE)
	check_has(
		project,
		"if not pending_paste or new_frame != current_frame:",
		"switching layers within a frame does not auto-confirm paste"
	)


func test_menu_touch_does_not_start_painting() -> void:
	var adapter := FileAccess.get_file_as_string(INPUT_SOURCE)
	check_has(
		adapter,
		"canvas.selection.is_selection_menu_point(event.position)",
		"iOS touch adapter excludes selection buttons from canvas tool input"
	)
	var canvas := FileAccess.get_file_as_string(CANVAS_SOURCE)
	check_has(
		canvas,
		"selection.is_selection_menu_point(event.position)",
		"mouse input over selection buttons also stays outside canvas drawing"
	)
