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
		"AddReferenceButton",
	]:
		var button := toolbar.get_node_or_null(name) as Button
		check_true(button != null, "%s lives beside Grayscale" % name)
	check_true(
		preview.is_controls_expanded(), "Preview controls start expanded below the preview viewport"
	)
	var divider := preview.get_node_or_null("VBox/PreviewControlsDivider") as ColorRect
	var toggle_btn := (
		preview.get_node_or_null("VBox/PreviewControlsToggleRow/PreviewControlsToggleButton")
		as Button
	)
	check_true(divider != null and divider.visible, "thin divider separates preview and toolbar")
	check_true(toggle_btn != null, "triangle fold toggle sits at the bottom of Preview")
	preview.size = Vector2(720, 210)
	await tree.process_frame
	var expanded_height := preview.size.y
	preview.set_controls_expanded(false)
	check_true(not preview.is_controls_expanded(), "Preview controls collapse on demand")
	check_true(preview.size.y < expanded_height, "collapsing shrinks Preview height from bottom")
	preview.set_controls_expanded(true)
	check_true(preview.is_controls_expanded(), "Preview controls re-expand downward")
	check_true(preview.size.y > expanded_height - 1.0, "re-expanding restores Preview height")
	preview.size = Vector2(720, 210)
	await tree.process_frame
	await tree.process_frame
	var wide_lines := toolbar.get_line_count()
	preview.size = Vector2(220, 210)
	await tree.process_frame
	await tree.process_frame
	check_true(toolbar.get_line_count() > wide_lines, "narrow Preview wraps toolbar to extra rows")
	check_true(
		(toolbar.get_node_or_null("AddReferenceButton") as Button).pressed.is_connected(
			Callable(preview, "_on_add_reference_pressed")
		),
		"Add Reference button is connected to the import action"
	)
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


func test_preview_bottom_fold_expands_floating_module_downward_without_squeezing_viewport() -> void:
	var root := Control.new()
	root.size = Vector2(1280.0, 800.0)
	var manager := WorkspaceModuleManager.new()
	var host := WorkspaceDockHost.new()
	host.size = Vector2(1280.0, 800.0)
	var surface := WorkspaceSurface.new()
	surface.name = "WorkspaceSurface"
	root.add_child(host)
	root.add_child(surface)
	var preview_def := WorkspaceBuiltinModules.create_definitions()[0]
	check_true(manager.register_definition(preview_def), "preview definition registers")
	check_true(host.setup(manager), "dock host initializes")
	check_true(surface.setup(manager, host), "workspace surface initializes")
	tree.root.add_child(root)
	check_true(
		surface.float_module(WorkspaceBuiltinModules.PREVIEW_ID, Rect2(120.0, 80.0, 320.0, 220.0)),
		"preview floats on surface",
	)
	await tree.process_frame
	await tree.process_frame
	var module := manager.get_instance(WorkspaceBuiltinModules.PREVIEW_ID)
	var preview := module.get_content() as PanelContainer
	var expanded_rect := surface.get_floating_rect(WorkspaceBuiltinModules.PREVIEW_ID)
	var expanded_vp_h: float = preview.preview_viewport_container.size.y
	preview.set_controls_expanded(false)
	await tree.process_frame
	await tree.process_frame
	var collapsed_rect := surface.get_floating_rect(WorkspaceBuiltinModules.PREVIEW_ID)
	var collapsed_vp_h: float = preview.preview_viewport_container.size.y
	check_almost_eq(
		collapsed_rect.position.y,
		expanded_rect.position.y,
		0.5,
		"collapsing keeps preview top edge anchored",
	)
	check_true(
		collapsed_rect.size.y < expanded_rect.size.y - 20.0,
		"collapsing shrinks floating preview window height",
	)
	check_almost_eq(
		collapsed_vp_h,
		expanded_vp_h,
		2.0,
		"collapsing preserves preview viewport height",
	)
	preview.set_controls_expanded(true)
	await tree.process_frame
	await tree.process_frame
	var reexpanded_rect := surface.get_floating_rect(WorkspaceBuiltinModules.PREVIEW_ID)
	var reexpanded_vp_h: float = preview.preview_viewport_container.size.y
	check_almost_eq(
		reexpanded_rect.position.y,
		collapsed_rect.position.y,
		0.5,
		"expanding downward keeps preview top edge anchored",
	)
	check_true(
		reexpanded_rect.size.y > collapsed_rect.size.y + 20.0,
		"expanding grows floating preview window downward",
	)
	check_almost_eq(
		reexpanded_vp_h,
		collapsed_vp_h,
		2.0,
		"expanding downward does not squeeze preview viewport upward",
	)
	root.queue_free()
	manager.free()
