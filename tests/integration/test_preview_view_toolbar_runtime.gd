extends "res://tests/test_base.gd"

const PREVIEW_SCENE := preload("res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.tscn")


func test_preview_view_toolbar_wraps_with_window_width() -> void:
	var preview := PREVIEW_SCENE.instantiate() as PanelContainer
	tree.root.add_child(preview)
	var toolbar := preview.get_node_or_null("%PreviewViewButtons") as HFlowContainer
	check_true(toolbar != null, "Preview contains a wrapping view toolbar")
	if toolbar == null:
		preview.queue_free()
		return
	for name in [
		"CenterCanvasButton",
		"MirrorViewButton",
		"ShowGridButton",
		"ShowPixelGridButton",
		"GrayscaleButton",
	]:
		var button := toolbar.get_node_or_null(name) as Button
		check_true(button != null, "%s lives beside Grayscale" % name)
	preview.size = Vector2(720, 210)
	await tree.process_frame
	await tree.process_frame
	var wide_lines := toolbar.get_line_count()
	preview.size = Vector2(220, 210)
	await tree.process_frame
	await tree.process_frame
	check_true(toolbar.get_line_count() > wide_lines, "narrow Preview wraps toolbar to extra rows")
	preview.queue_free()


func test_preview_view_switches_follow_shared_modes() -> void:
	var original_mirror := Global.mirror_view
	var original_grid := Global.draw_grid
	var original_pixel_grid := Global.draw_pixel_grid
	var preview := PREVIEW_SCENE.instantiate() as PanelContainer
	tree.root.add_child(preview)
	var mirror := preview.get_node("%MirrorViewButton") as Button
	var grid := preview.get_node("%ShowGridButton") as Button
	var pixel_grid := preview.get_node("%ShowPixelGridButton") as Button
	Global.mirror_view = true
	Global.draw_grid = true
	Global.draw_pixel_grid = false
	Global.preview_view_controls_changed.emit()
	check_true(mirror.button_pressed, "Mirror reflects the shared canvas view")
	check_true(grid.button_pressed, "Grid reflects the shared canvas view")
	check_true(not pixel_grid.button_pressed, "Pixel Grid reflects the shared canvas view")
	Global.mirror_view = false
	Global.draw_grid = false
	Global.draw_pixel_grid = true
	Global.preview_view_controls_changed.emit()
	check_true(not mirror.button_pressed, "Mirror can return to off")
	check_true(not grid.button_pressed, "Grid can return to off")
	check_true(pixel_grid.button_pressed, "Pixel Grid can return to on")
	Global.mirror_view = original_mirror
	Global.draw_grid = original_grid
	Global.draw_pixel_grid = original_pixel_grid
	Global.preview_view_controls_changed.emit()
	preview.queue_free()


func test_preview_actions_reuse_existing_view_handlers() -> void:
	var source := FileAccess.get_file_as_string(
		"res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.gd"
	)
	for action in [
		"Global.ViewMenu.CENTER_CANVAS",
		"Global.ViewMenu.MIRROR_VIEW",
		"Global.ViewMenu.SHOW_GRID",
		"Global.ViewMenu.SHOW_PIXEL_GRID",
	]:
		check_has(source, "view_menu_id_pressed(%s)" % action, "Preview reuses %s" % action)
