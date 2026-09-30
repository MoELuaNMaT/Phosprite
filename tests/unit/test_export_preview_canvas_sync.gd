extends "res://tests/test_base.gd"

const EXPORT_DIALOG := preload("res://src/UI/Dialogs/ExportDialog.gd")
const CanvasVisualPolicy := preload("res://src/UI/Canvas/CanvasVisualPolicy.gd")
const EXPORT_DIALOG_SOURCE := "res://src/UI/Dialogs/ExportDialog.gd"
const EXPORT_DIALOG_SCENE := "res://src/UI/Dialogs/ExportDialog.tscn"


func test_export_preview_rect_preserves_document_aspect_ratio() -> void:
	var wide := EXPORT_DIALOG._fit_preview_rect(Vector2(300, 200), Vector2i(64, 32))
	check_true(
		wide.size.is_equal_approx(Vector2(300, 150)),
		"a 64x32 export canvas must display as 2:1 instead of stretching across the preview panel",
	)
	check_true(
		wide.position.is_equal_approx(Vector2(0, 25)),
		"the fitted export canvas must stay centered in the available preview area",
	)

	var tall := EXPORT_DIALOG._fit_preview_rect(Vector2(300, 200), Vector2i(32, 64))
	check_true(
		tall.size.is_equal_approx(Vector2(100, 200)),
		"a 32x64 export canvas must display as 1:2",
	)
	check_true(
		tall.position.is_equal_approx(Vector2(100, 0)),
		"portrait export canvases must remain centered instead of being tiled or stretched",
	)


func test_export_checker_uses_same_document_pixel_cell_size_as_main_canvas() -> void:
	var fitted_size := Vector2(300, 150)
	var document_size := Vector2i(64, 32)
	var cell_size: float = EXPORT_DIALOG._preview_checker_cell_size(fitted_size, document_size)
	var expected := CanvasVisualPolicy.DOCUMENT_CHECKER_SIZE * (300.0 / 64.0)
	check_true(
		is_equal_approx(cell_size, expected),
		"export preview checker cells must scale from the same 2x2 document-pixel rule as Canvas",
	)


func test_export_checker_is_owned_by_each_preview_surface() -> void:
	var source := FileAccess.get_file_as_string(EXPORT_DIALOG_SOURCE)
	var scene := FileAccess.get_file_as_string(EXPORT_DIALOG_SCENE)
	check_has(
		source,
		"var checker := TRANSPARENT_CHECKER.new() as TransparentChecker",
		"each export preview must create its own checker layer",
	)
	check_has(
		source,
		"checker.position = display_rect.position",
		"checker bounds must start at the real displayed canvas bounds",
	)
	check_has(
		source,
		"checker.size = display_rect.size",
		"checker bounds must exactly match the real displayed canvas size",
	)
	check_has(
		source,
		"preview.position = display_rect.position",
		"image and checker must share the same origin",
	)
	check_has(
		source,
		"preview.size = display_rect.size",
		"image and checker must share the same fitted dimensions",
	)
	check_true(
		not scene.contains(
			'[node name="TransparentChecker" parent="VBoxContainer/VSplitContainer/PreviewPanel"'
		),
		"the export dialog must not restore the old panel-wide tiled checker",
	)
