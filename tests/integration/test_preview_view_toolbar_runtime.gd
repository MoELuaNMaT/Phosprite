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


func test_preview_adaptive_height_matches_canvas_aspect_ratio() -> void:
	var preview_script := load("res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.gd")
	var h_square: float = preview_script.compute_adaptive_module_height(
		Vector2(64.0, 64.0), 236.0, 8.0, 120.0, 110.0, 520.0
	)
	var h_4_3: float = preview_script.compute_adaptive_module_height(
		Vector2(320.0, 240.0), 236.0, 8.0, 120.0, 110.0, 520.0
	)
	var h_3_4: float = preview_script.compute_adaptive_module_height(
		Vector2(240.0, 320.0), 236.0, 8.0, 120.0, 110.0, 520.0
	)
	check_almost_eq(h_square, 228.0 + 120.0, 1.0, "1:1 canvas produces 1:1 preview viewport height")
	check_almost_eq(
		h_4_3, roundf(228.0 * 0.75 + 120.0), 1.0, "4:3 canvas scales preview viewport to 4:3"
	)
	check_almost_eq(
		h_3_4, roundf(228.0 * (4.0 / 3.0) + 120.0), 1.0, "3:4 canvas scales preview viewport to 3:4"
	)
	var h_extreme_tall: float = preview_script.compute_adaptive_module_height(
		Vector2(32.0, 512.0), 236.0, 8.0, 120.0, 110.0, 480.0
	)
	check_almost_eq(h_extreme_tall, 480.0, 0.5, "extreme portrait canvas clamps to max height")

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
		surface.float_module(WorkspaceBuiltinModules.PREVIEW_ID, Rect2(120.0, 80.0, 328.0, 220.0)),
		"preview floats on surface",
	)
	await tree.process_frame
	await tree.process_frame
	var module := manager.get_instance(WorkspaceBuiltinModules.PREVIEW_ID)
	var preview := module.get_content() as PanelContainer
	check_true(preview.adapt_size_to_canvas(Vector2(64.0, 64.0), true), "1:1 adaptation applies")
	await tree.process_frame
	await tree.process_frame
	var vp_square: Vector2 = preview.preview_viewport_container.size
	check_almost_eq(vp_square.y, vp_square.x, 6.0, "1:1 canvas yields square preview viewport")
	var zoom_square: Vector2 = preview.camera.zoom
	check_true(
		64.0 * zoom_square.x <= vp_square.x + 1.0 and 64.0 * zoom_square.y <= vp_square.y + 1.0,
		"1:1 canvas fits completely inside preview viewport",
	)
	check_true(preview.adapt_size_to_canvas(Vector2(320.0, 240.0), true), "4:3 adaptation applies")
	await tree.process_frame
	await tree.process_frame
	var vp_4_3: Vector2 = preview.preview_viewport_container.size
	check_almost_eq(vp_4_3.y, vp_4_3.x * 0.75, 6.0, "4:3 canvas yields 4:3 preview viewport")
	var zoom_4_3: Vector2 = preview.camera.zoom
	check_true(
		320.0 * zoom_4_3.x <= vp_4_3.x + 1.0 and 240.0 * zoom_4_3.y <= vp_4_3.y + 1.0,
		"4:3 canvas fits completely inside preview viewport",
	)
	root.queue_free()
	manager.free()


func test_ui4_preview_bottom_fold_pushes_palette_down_without_squeezing_viewport() -> void:
	var profile4_script: GDScript = load("res://src/UI/Workspace/WorkspaceUIProfile4.gd")
	var root := Control.new()
	root.size = Vector2(1180.0, 820.0)
	tree.root.add_child(root)
	var manager := WorkspaceModuleManager.new()
	root.add_child(manager)
	check_true(WorkspaceBuiltinModules.register_defaults(manager), "builtins register")
	var preview_content := PREVIEW_SCENE.instantiate() as PanelContainer
	check_true(
		manager.adopt_module(WorkspaceBuiltinModules.PREVIEW_ID, preview_content) != null,
		"preview adopted",
	)
	var palette_root := VBoxContainer.new()
	var swatches := Control.new()
	swatches.name = &"Palettes"
	swatches.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette_root.add_child(swatches)
	var picker := Control.new()
	picker.name = &"Color Picker"
	picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette_root.add_child(picker)
	check_true(
		manager.adopt_module(WorkspaceBuiltinModules.PALETTE_ID, palette_root) != null,
		"palette adopted",
	)
	for module_id in [
		WorkspaceBuiltinModules.TOOLS_ID,
		WorkspaceBuiltinModules.TIMELINE_ID,
		WorkspaceBuiltinModules.RIGHT_TOOL_OPTIONS_ID,
	]:
		check_true(
			manager.adopt_module(module_id, Control.new()) != null,
			"adopted: " + String(module_id),
		)
	var dock_host := WorkspaceDockHost.new()
	root.add_child(dock_host)
	dock_host.size = root.size
	check_true(dock_host.setup(manager), "dock host setup")
	var surface := WorkspaceSurface.new()
	surface.name = "WorkspaceSurface"
	root.add_child(surface)
	check_true(surface.setup(manager, dock_host), "surface setup")
	var ui4 := profile4_script.new()
	root.add_child(ui4)
	check_true(ui4.setup(root, surface), "UI4 setup")
	check_true(ui4.activate(), "UI4 activates")
	ui4._apply_live_palette_presentation()
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame

	var palette_module := manager.get_instance(WorkspaceBuiltinModules.PALETTE_ID)
	var toggle_btn := (
		preview_content.get_node_or_null(
			"VBox/PreviewControlsToggleRow/PreviewControlsToggleButton"
		)
		as Button
	)
	check_true(toggle_btn != null, "fold toggle button exists")
	# Touching the bottom fold button must NOT be intercepted by the preview-palette split handle.
	var toggle_center := toggle_btn.get_global_transform_with_canvas() * (toggle_btn.size * 0.5)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = toggle_center
	ui4._input(touch)
	check_eq(
		ui4._preview_split_drag_touch,
		-1,
		"preview split handle does not hijack taps on the fold toggle button",
	)

	var initial_vp_h: float = preview_content.preview_viewport_container.size.y
	var initial_palette_y := palette_module.position.y
	preview_content.set_controls_expanded(false)
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	var collapsed_vp_h: float = preview_content.preview_viewport_container.size.y
	var collapsed_palette_y := palette_module.position.y
	check_true(
		toggle_btn.icon == preview_content._triangle_icon(false),
		"collapsed fold arrow points downward",
	)
	check_true(
		collapsed_palette_y < initial_palette_y - 20.0,
		"collapsing preview controls pulls Palette & Color upward",
	)
	check_almost_eq(
		collapsed_vp_h,
		initial_vp_h,
		4.0,
		"collapsing in UI4 keeps preview viewport height stable",
	)

	preview_content.set_controls_expanded(true)
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	var expanded_vp_h: float = preview_content.preview_viewport_container.size.y
	var expanded_palette_y := palette_module.position.y
	check_true(
		toggle_btn.icon == preview_content._triangle_icon(true),
		"expanded fold arrow points upward",
	)
	check_true(
		expanded_palette_y > collapsed_palette_y + 20.0,
		"expanding preview controls pushes Palette & Color downward",
	)
	check_almost_eq(
		expanded_vp_h,
		collapsed_vp_h,
		4.0,
		"expanding in UI4 does not squeeze preview viewport upward",
	)
	root.queue_free()
