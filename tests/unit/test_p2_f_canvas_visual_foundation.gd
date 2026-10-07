extends "res://tests/test_base.gd"

const CanvasVisualPolicy := preload("res://src/UI/Canvas/CanvasVisualPolicy.gd")


func _make_theme(panel_color: Color, text_color: Color) -> Theme:
	var source_theme := Theme.new()
	var panel := StyleBoxFlat.new()
	panel.bg_color = panel_color
	source_theme.set_stylebox(&"panel", &"PanelContainer", panel)
	source_theme.set_color(&"font_color", &"Label", text_color)
	return source_theme


func test_document_checker_contract_uses_canvas_and_preview_cell_sizes() -> void:
	check_eq(
		CanvasVisualPolicy.DOCUMENT_CHECKER_SIZE,
		2.0,
		"Main Canvas transparency checker cells must cover 2x2 document pixels"
	)
	var source := FileAccess.get_file_as_string("res://src/UI/Nodes/TransparentChecker.gd")
	check_true(
		source.contains("var is_main_document_checker := self == Global.transparent_checker"),
		"main Canvas should identify its document checker explicitly"
	)
	check_true(
		source.contains(
			"var document_pixel_mode := is_main_document_checker or sync_to_document_pixels"
		),
		"previews should be able to opt into the same document-pixel checker mode"
	)
	check_true(
		source.contains("if is_main_document_checker:"),
		"only Main Canvas may fan out checker refreshes; Preview opt-in must not recurse"
	)
	check_true(
		source.contains("document_checker_size if document_pixel_mode"),
		"document-pixel checkers must consume their configured document-space cell size"
	)
	check_true(
		source.contains("true if document_pixel_mode else Global.checker_follow_scale"),
		"document-pixel checkers must zoom with their Canvas pixels"
	)
	var preview_scene := FileAccess.get_file_as_string(
		"res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.tscn"
	)
	check_true(
		preview_scene.contains("sync_to_document_pixels = true"),
		"Canvas Preview checker must stay locked to document pixels"
	)
	check_true(
		preview_scene.contains("document_checker_size = 8.0"),
		"Canvas Preview checker cells must cover 8x8 document pixels"
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
		(
			CanvasVisualPolicy.PIXEL_GRID_ALPHA_FACTOR > 0.0
			and CanvasVisualPolicy.PIXEL_GRID_ALPHA_FACTOR < 1.0
		),
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
		scene_source.contains('[node name="CanvasBoundary" type="Node2D" parent="."]'),
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


func test_preview_footer_exposes_synced_grayscale_toggle() -> void:
	var preview_scene := FileAccess.get_file_as_string(
		"res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.tscn"
	)
	var preview_source := FileAccess.get_file_as_string(
		"res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.gd"
	)
	var global_source := FileAccess.get_file_as_string("res://src/Autoload/Global.gd")
	var top_menu_source := FileAccess.get_file_as_string(
		"res://src/UI/TopMenuContainer/TopMenuContainer.gd"
	)
	check_has(
		preview_scene,
		'[node name="GrayscaleButton" type="Button" parent="VBox/Animation"',
		"Preview footer must expose a dedicated grayscale toggle",
	)
	check_has(
		preview_scene,
		"toggle_mode = true",
		"Preview grayscale control must visually stay pressed while grayscale view is active",
	)
	check_has(
		preview_source,
		"Global.greyscale_view = button_pressed",
		"Preview grayscale toggle must write the shared editor grayscale state",
	)
	check_has(
		preview_source,
		"Global.greyscale_view_changed.connect(_on_greyscale_view_changed)",
		"Preview button must follow grayscale changes made from other entry points",
	)
	check_has(
		preview_source,
		"grayscale_button.set_pressed_no_signal(enabled)",
		"external grayscale changes must synchronize the Preview button without recursive toggles",
	)
	check_has(
		global_source,
		'control.find_child("GreyscaleVision", true, false)',
		"the shared grayscale state must still control the existing canvas grayscale overlay",
	)
	check_has(
		global_source,
		"top_menu_container.view_menu.set_item_checked(ViewMenu.GREYSCALE_VIEW, value)",
		"the shared grayscale state must keep the View menu checkmark synchronized",
	)
	check_has(
		global_source,
		"greyscale_view_changed.emit(value)",
		"the shared grayscale state must notify secondary UI entry points",
	)
	check_has(
		top_menu_source,
		"Global.greyscale_view = !Global.greyscale_view",
		"the existing View menu must continue toggling the same shared grayscale state",
	)


func test_canvas_no_longer_renders_floating_tool_icons() -> void:
	var main_scene := FileAccess.get_file_as_string("res://src/Main.tscn")
	var main_source := FileAccess.get_file_as_string("res://src/Main.gd")
	var canvas_source := FileAccess.get_file_as_string("res://src/UI/Canvas/Canvas.gd")
	var preferences_source := FileAccess.get_file_as_string(
		"res://src/Preferences/PreferencesDialog.gd"
	)
	var preferences_scene := FileAccess.get_file_as_string(
		"res://src/Preferences/PreferencesDialog.tscn"
	)
	check_true(
		not main_scene.contains('[node name="LeftCursor" type="Sprite2D"'),
		"the main editor scene must not mount a floating left-tool cursor icon",
	)
	check_true(
		not main_scene.contains('[node name="RightCursor" type="Sprite2D"'),
		"the main editor scene must not mount a floating right-tool cursor icon",
	)
	check_true(
		not main_source.contains("left_cursor.position = get_global_mouse_position()"),
		"editor input must no longer move a floating left-tool icon beside the pointer",
	)
	check_true(
		not main_source.contains("right_cursor.position = get_global_mouse_position()"),
		"editor input must no longer move a floating right-tool icon beside the pointer",
	)
	check_true(
		not canvas_source.contains("Global.control.left_cursor.visible"),
		"Canvas must not toggle a left tool icon during pointer or touch interaction",
	)
	check_true(
		not canvas_source.contains("Global.control.right_cursor.visible"),
		"Canvas must not toggle a right tool icon during pointer or touch interaction",
	)
	check_true(
		not preferences_source.contains('"show_left_tool_icon"'),
		"Preferences must not expose a switch for the removed left tool icon",
	)
	check_true(
		not preferences_source.contains('"show_right_tool_icon"'),
		"Preferences must not expose a switch for the removed right tool icon",
	)
	check_true(
		not preferences_scene.contains("Show left tool icon"),
		"the removed left tool icon must not leave a dead Preferences row",
	)
	check_true(
		not preferences_scene.contains("Show right tool icon"),
		"the removed right tool icon must not leave a dead Preferences row",
	)


func test_preview_grayscale_state_controls_preview_render_layer() -> void:
	var preview_source := FileAccess.get_file_as_string("res://src/UI/Canvas/CanvasPreview.gd")
	var container_source := FileAccess.get_file_as_string(
		"res://src/UI/CanvasPreviewContainer/CanvasPreviewContainer.gd"
	)
	var global_source := FileAccess.get_file_as_string("res://src/Autoload/Global.gd")
	var blend_shader := FileAccess.get_file_as_string("res://src/Shaders/BlendLayers.gdshader")
	check_has(
		blend_shader,
		"uniform bool greyscale_view = false;",
		"Preview grayscale must be implemented in the actual layer-compositing shader",
	)
	check_has(
		blend_shader,
		"result_color.rgb = vec3(luminance);",
		"Preview grayscale must replace the final RGB output",
	)
	check_has(
		global_source,
		'(canvas.material as ShaderMaterial).set_shader_parameter(&"greyscale_view", value)',
		"the shared Canvas compositing material must receive the global grayscale state",
	)
	check_has(
		preview_source,
		"func _enter_tree() -> void:",
		"CanvasPreview must reconnect shared state after Workspace reparenting",
	)
	check_has(
		preview_source,
		"Global.greyscale_view_changed.connect(_on_greyscale_view_changed)",
		"CanvasPreview must observe grayscale state on every tree entry",
	)
	check_has(
		preview_source,
		'animation_material.set_shader_parameter(&"greyscale_view", enabled)',
		"animated Preview frames must switch grayscale together with the main Canvas",
	)
	check_has(
		container_source,
		"func _enter_tree() -> void:",
		"the Preview footer must reconnect its UI synchronization after Workspace reparenting",
	)
