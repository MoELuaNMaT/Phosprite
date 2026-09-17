extends "res://tests/test_base.gd"

const CanvasVisualPolicy := preload("res://src/UI/Canvas/CanvasVisualPolicy.gd")


func _make_theme(panel_color: Color, text_color: Color) -> Theme:
	var source_theme := Theme.new()
	var panel := StyleBoxFlat.new()
	panel.bg_color = panel_color
	source_theme.set_stylebox(&"panel", &"PanelContainer", panel)
	source_theme.set_color(&"font_color", &"Label", text_color)
	return source_theme


func test_document_checker_contract_is_one_canvas_pixel() -> void:
	check_eq(
		CanvasVisualPolicy.DOCUMENT_CHECKER_SIZE,
		1.0,
		"one transparency checker cell must equal one document pixel"
	)
	var source := FileAccess.get_file_as_string("res://src/UI/Nodes/TransparentChecker.gd")
	check_true(
		source.contains("document_pixel_mode := self == Global.transparent_checker"),
		"only the main document checker should opt into document-pixel mode"
	)
	check_true(
		source.contains("CanvasVisualPolicy.DOCUMENT_CHECKER_SIZE if document_pixel_mode"),
		"main Canvas checker must consume the one-pixel policy"
	)
	check_true(
		source.contains("true if document_pixel_mode else Global.checker_follow_scale"),
		"document checker must zoom with Canvas pixels while previews retain their preference"
	)


func test_pixel_grid_keeps_outer_boundary_single_owned() -> void:
	var source := FileAccess.get_file_as_string("res://src/UI/Canvas/PixelGrid.gd")
	check_true(
		source.contains("floori(target_rect.position.x) + 1"),
		"pixel grid must begin inside the document boundary on X"
	)
	check_true(
		source.contains("floori(target_rect.position.y) + 1"),
		"pixel grid must begin inside the document boundary on Y"
	)
	check_true(
		source.contains("CanvasVisualPolicy.PIXEL_GRID_ALPHA_FACTOR"),
		"pixel grid should use the shared subordinate visual weight"
	)
	check_true(
		CanvasVisualPolicy.PIXEL_GRID_ALPHA_FACTOR > 0.0
		and CanvasVisualPolicy.PIXEL_GRID_ALPHA_FACTOR < 1.0,
		"pixel grid must stay visible while remaining subordinate to the boundary"
	)


func test_canvas_theme_colors_adapt_to_dark_and_light_surfaces() -> void:
	var dark_theme := _make_theme(Color("24272d"), Color("f2f4f8"))
	var light_theme := _make_theme(Color("edf1f5"), Color("1d2329"))
	var dark_backdrop := CanvasVisualPolicy.resolve_backdrop_color(dark_theme)
	var light_backdrop := CanvasVisualPolicy.resolve_backdrop_color(light_theme)
	var dark_boundary := CanvasVisualPolicy.resolve_boundary_color(dark_theme)
	var light_boundary := CanvasVisualPolicy.resolve_boundary_color(light_theme)

	check_true(
		dark_backdrop.get_luminance() < light_backdrop.get_luminance(),
		"Canvas backdrop should follow application theme luminance"
	)
	check_true(
		dark_boundary.get_luminance() > dark_backdrop.get_luminance(),
		"dark-theme document boundary should separate from its backdrop"
	)
	check_true(
		light_boundary.get_luminance() < light_backdrop.get_luminance(),
		"light-theme document boundary should separate from its backdrop"
	)


func test_canvas_scene_mounts_backdrop_and_boundary_without_input_capture() -> void:
	var scene_source := FileAccess.get_file_as_string("res://src/UI/Canvas/Canvas.tscn")
	var viewport_source := FileAccess.get_file_as_string("res://src/UI/ViewportContainer.gd")
	check_true(
		scene_source.contains("[node name=\"CanvasBoundary\" type=\"Node2D\" parent=\".\"]"),
		"Canvas scene should own an explicit document boundary"
	)
	check_true(
		viewport_source.contains("backdrop_layer.layer = -100"),
		"Canvas backdrop must stay behind document rendering"
	)
	check_true(
		viewport_source.contains("_canvas_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE"),
		"visual backdrop must never capture Canvas input"
	)
