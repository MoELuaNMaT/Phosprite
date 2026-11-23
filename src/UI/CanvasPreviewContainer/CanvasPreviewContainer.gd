extends PanelContainer

const NAVIGATION := preload("res://src/InputAdapter/CanvasInputAdapter.gd")
const Stage4 := preload("res://src/UI/DesignSystem/PhospriteStage4Chrome.gd")
const PhospriteTokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")

static var _preview_bg_styles: Dictionary = {}
static var _arrow_up_icon: ImageTexture
static var _arrow_down_icon: ImageTexture

var _preview_touches: Dictionary = {}
var _navigation_ids := PackedInt32Array()
var _baseline_centroid := Vector2.ZERO
var _baseline_distance := 0.0
var _baseline_zoom := Vector2.ONE
var _baseline_offset := Vector2.ZERO
var _baseline_angle := 0.0
var _anchor_canvas := Vector2.ZERO
var _pan_active := false
var _pinch_active := false
var _reference_import_menu: PopupMenu
var _controls_expanded := true
var _controls_divider: ColorRect
var _controls_toggle_row: HBoxContainer
var _controls_toggle_button: Button
var _last_drawer_height := 42.0
var _last_adapted_project_id := -1
var _pending_reconcile_token := 0

@onready
var preview_viewport_container := $VBox/HBox/PreviewViewportContainer as SubViewportContainer
@onready var canvas_preview := $"%CanvasPreview" as Node2D
@onready var camera := $"%CameraPreview" as CanvasCamera
@onready var grayscale_button := $"%GrayscaleButton" as Button
@onready var add_reference_button := $"%AddReferenceButton" as Button
@onready var mirror_view_button := $"%MirrorViewButton" as Button
@onready var show_grid_button := $"%ShowGridButton" as Button
@onready var show_pixel_grid_button := $"%ShowPixelGridButton" as Button
@onready var start_frame := $"%StartFrame" as ValueSlider
@onready var end_frame := $"%EndFrame" as ValueSlider
@onready var animation_bar := $VBox/Animation as HBoxContainer
@onready var preview_vbox := $VBox as VBoxContainer


func _enter_tree() -> void:
	if not Global.greyscale_view_changed.is_connected(_on_greyscale_view_changed):
		Global.greyscale_view_changed.connect(_on_greyscale_view_changed)
	if not Global.preview_view_controls_changed.is_connected(_sync_view_controls):
		Global.preview_view_controls_changed.connect(_sync_view_controls)
	if not Global.project_created.is_connected(_on_project_created):
		Global.project_created.connect(_on_project_created)
	if not Global.project_switched.is_connected(_on_project_switched):
		Global.project_switched.connect(_on_project_switched)
	if not Themes.theme_switched.is_connected(_refresh_preview_pixel_chrome):
		Themes.theme_switched.connect(_refresh_preview_pixel_chrome)
	if not Global.pixel_ui_unit_changed.is_connected(_refresh_preview_pixel_chrome):
		Global.pixel_ui_unit_changed.connect(_refresh_preview_pixel_chrome)
	# _ready() is not guaranteed to run when UI3 reuses and reparents the Preview.
	_on_greyscale_view_changed(Global.greyscale_view)
	_sync_view_controls()
	_apply_controls_expanded_state.call_deferred()
	_refresh_preview_pixel_chrome.call_deferred()
	_connect_preview_camera_zoom.call_deferred()


func _ready() -> void:
	_ensure_collapsible_controls_ui()
	_apply_controls_expanded_state()
	_on_greyscale_view_changed(Global.greyscale_view)
	_sync_view_controls()
	_connect_preview_camera_zoom()
	_schedule_initial_canvas_adaptation()
	if OS.get_name() == "iOS":
		_reference_import_menu = PopupMenu.new()
		_reference_import_menu.add_item(tr("Files"), 0)
		_reference_import_menu.add_item(tr("Photos"), 1)
		add_child(_reference_import_menu)
		_reference_import_menu.id_pressed.connect(_on_reference_import_source_selected)


func _exit_tree() -> void:
	if Global.greyscale_view_changed.is_connected(_on_greyscale_view_changed):
		Global.greyscale_view_changed.disconnect(_on_greyscale_view_changed)
	if Global.preview_view_controls_changed.is_connected(_sync_view_controls):
		Global.preview_view_controls_changed.disconnect(_sync_view_controls)
	if Global.project_created.is_connected(_on_project_created):
		Global.project_created.disconnect(_on_project_created)
	if Global.project_switched.is_connected(_on_project_switched):
		Global.project_switched.disconnect(_on_project_switched)
	if Themes.theme_switched.is_connected(_refresh_preview_pixel_chrome):
		Themes.theme_switched.disconnect(_refresh_preview_pixel_chrome)
	if Global.pixel_ui_unit_changed.is_connected(_refresh_preview_pixel_chrome):
		Global.pixel_ui_unit_changed.disconnect(_refresh_preview_pixel_chrome)
	if is_instance_valid(camera) and camera.zoom_changed.is_connected(_sync_preview_zoom_header):
		camera.zoom_changed.disconnect(_sync_preview_zoom_header)


func _input(event: InputEvent) -> void:
	if OS.get_name() != "iOS" or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		_handle_preview_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_preview_drag(event as InputEventScreenDrag)


func _gui_input(event: InputEvent) -> void:
	var checker: ColorRect = $VBox/HBox/PreviewViewportContainer/SubViewport/TransparentChecker
	if event is InputEventMouseButton:
		var mouse_pos := checker.get_local_mouse_position()
		if (
			mouse_pos.x >= 0
			and mouse_pos.y >= 0
			and mouse_pos.x <= checker.size.x
			and mouse_pos.y <= checker.size.y
		):
			if event.double_click:
				if canvas_preview.mode == canvas_preview.Mode.SPRITESHEET:
					var sprite_sheet_idx = canvas_preview.frame_index
					var x: int = sprite_sheet_idx % canvas_preview.h_frames
					var y: int = sprite_sheet_idx / canvas_preview.v_frames
					mouse_pos += Vector2(x, y) * checker.size
				Global.camera.offset = mouse_pos


func _handle_preview_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if not preview_viewport_container.get_global_rect().has_point(event.position):
			return
		_preview_touches[event.index] = _preview_local_position(event.position)
		_try_begin_preview_navigation()
	else:
		if not _preview_touches.has(event.index):
			return
		_preview_touches.erase(event.index)
		if event.index in _navigation_ids:
			_rebase_preview_navigation()
	get_viewport().set_input_as_handled()


func _handle_preview_drag(event: InputEventScreenDrag) -> void:
	if not _preview_touches.has(event.index):
		return
	_preview_touches[event.index] = _preview_local_position(event.position)
	if _navigation_ids.size() < 2:
		_try_begin_preview_navigation()
	if event.index in _navigation_ids:
		_update_preview_navigation()
	get_viewport().set_input_as_handled()


func _preview_local_position(screen_position: Vector2) -> Vector2:
	return (
		preview_viewport_container.get_global_transform_with_canvas().affine_inverse()
		* screen_position
	)


func _try_begin_preview_navigation() -> void:
	if _navigation_ids.size() == 2 or _preview_touches.size() < 2:
		return
	var ids := PackedInt32Array()
	for touch_id: int in _preview_touches:
		ids.append(touch_id)
	ids.sort()
	_navigation_ids = PackedInt32Array([ids[0], ids[1]])
	_capture_preview_navigation_baseline()


func _capture_preview_navigation_baseline() -> void:
	if _navigation_ids.size() != 2:
		return
	var geometry := _preview_navigation_geometry()
	_baseline_centroid = geometry["centroid"]
	_baseline_distance = float(geometry["distance"])
	_baseline_zoom = camera.zoom
	_baseline_offset = camera.offset
	_baseline_angle = camera.camera_angle
	_anchor_canvas = NAVIGATION.screen_to_canvas_point(
		_baseline_centroid,
		preview_viewport_container.size,
		_baseline_zoom,
		_baseline_offset,
		_baseline_angle
	)
	_pan_active = false
	_pinch_active = false


func _rebase_preview_navigation() -> void:
	_navigation_ids.clear()
	_pan_active = false
	_pinch_active = false
	_try_begin_preview_navigation()


func _update_preview_navigation() -> void:
	if _navigation_ids.size() != 2:
		return
	var geometry := _preview_navigation_geometry()
	var centroid: Vector2 = geometry["centroid"]
	var distance := float(geometry["distance"])

	if not _pan_active:
		_pan_active = NAVIGATION.navigation_pan_exceeds_dead_zone(_baseline_centroid, centroid)
	if not _pinch_active:
		_pinch_active = NAVIGATION.navigation_pinch_exceeds_dead_zone(_baseline_distance, distance)

	var effective_centroid := _baseline_centroid
	if _pan_active:
		effective_centroid = centroid
	var scale_ratio := 1.0
	if _pinch_active:
		scale_ratio = NAVIGATION.navigation_scale_ratio(_baseline_distance, distance)

	var target_zoom := NAVIGATION.navigation_zoom_from_ratio(
		_baseline_zoom, scale_ratio, Global.integer_zoom, camera.zoom_out_max, camera.zoom_in_max
	)
	var target_offset := NAVIGATION.navigation_offset_for_anchor(
		_anchor_canvas,
		effective_centroid,
		preview_viewport_container.size,
		target_zoom,
		_baseline_angle
	)

	if not camera.zoom.is_equal_approx(target_zoom):
		camera.zoom = target_zoom
	if not camera.offset.is_equal_approx(target_offset):
		camera.offset = target_offset
	camera.update_transparent_checker_offset()


func _preview_navigation_geometry() -> Dictionary:
	var first: Vector2 = _preview_touches[_navigation_ids[0]]
	var second: Vector2 = _preview_touches[_navigation_ids[1]]
	return NAVIGATION.navigation_pair_geometry(first, second)


## The Reference Images panel opens only after an image is imported.
func _on_add_reference_pressed() -> void:
	if Global.current_project == null or not is_instance_valid(Global.control):
		return
	if OS.get_name() == "iOS":
		if is_instance_valid(_reference_import_menu):
			_reference_import_menu.popup_on_parent(
				Rect2i(Vector2i(add_reference_button.global_position), Vector2i.ONE)
			)
	else:
		Global.control.call(&"request_reference_image_import", false)


func _on_reference_import_source_selected(source: int) -> void:
	if is_instance_valid(Global.control):
		Global.control.call(&"request_reference_image_import", source == 1)


func is_controls_expanded() -> bool:
	return _controls_expanded


func set_controls_expanded(expanded: bool) -> void:
	_ensure_collapsible_controls_ui()
	if _controls_expanded == expanded:
		_apply_controls_expanded_state()
		return
	var target_viewport_h := (
		preview_viewport_container.size.y if is_instance_valid(preview_viewport_container) else 0.0
	)
	var previous := _controls_expanded
	var before_drawer_h := _measure_controls_drawer_height() if previous else 0.0
	if before_drawer_h > 0.0:
		_last_drawer_height = before_drawer_h
	_controls_expanded = expanded
	_apply_controls_expanded_state()
	var delta_y := (
		maxf(_last_drawer_height, _measure_controls_drawer_height())
		if expanded
		else -_last_drawer_height
	)
	_adjust_preview_height_downward(delta_y)
	_pending_reconcile_token += 1
	if target_viewport_h > 1.0:
		_reconcile_viewport_height.call_deferred(target_viewport_h, 2, _pending_reconcile_token)


func workspace_module_initialized(_module: WorkspaceModule, _context: Dictionary) -> void:
	_ensure_collapsible_controls_ui.call_deferred()


func workspace_module_mounted(_module: WorkspaceModule, _host: Control) -> void:
	_ensure_collapsible_controls_ui.call_deferred()
	_connect_preview_camera_zoom.call_deferred()
	_schedule_initial_canvas_adaptation()


static func format_zoom_label(zoom_scale: Vector2) -> String:
	var pct := zoom_scale.x * 100.0
	if pct <= 0.0:
		return ""
	if pct < 10.0:
		return "%.1f%%" % pct
	return "%d%%" % roundi(pct)


func _connect_preview_camera_zoom() -> void:
	if (
		is_instance_valid(camera)
		and not camera.zoom_changed.is_connected(_sync_preview_zoom_header)
	):
		camera.zoom_changed.connect(_sync_preview_zoom_header)
	_sync_preview_zoom_header()


func _sync_preview_zoom_header() -> void:
	var parent_module := get_parent() as WorkspaceModule
	if parent_module == null or not is_instance_valid(camera):
		return
	parent_module.set_header_subtitle(format_zoom_label(camera.zoom))


static func compute_adaptive_module_height(
	canvas_size: Vector2,
	module_width: float,
	horizontal_chrome: float,
	vertical_chrome: float,
	min_module_height: float,
	max_module_height: float
) -> float:
	var safe_min := maxf(min_module_height, 72.0 + maxf(0.0, vertical_chrome))
	var safe_max := maxf(safe_min, max_module_height)
	if canvas_size.x <= 0.0 or canvas_size.y <= 0.0 or module_width <= 0.0:
		return clampf(min_module_height, safe_min, safe_max)
	var viewport_w := maxf(64.0, module_width - maxf(0.0, horizontal_chrome))
	var ideal_viewport_h := viewport_w * (canvas_size.y / canvas_size.x)
	var desired_h := ideal_viewport_h + maxf(0.0, vertical_chrome)
	return clampf(roundf(desired_h), safe_min, safe_max)


func adapt_size_to_canvas(canvas_size: Vector2, force: bool = false) -> bool:
	if canvas_size.x <= 0.0 or canvas_size.y <= 0.0 or not is_inside_tree():
		return false
	if Global.current_project != null:
		var project_id := Global.current_project.get_instance_id()
		if not force and _last_adapted_project_id == project_id:
			return false
		_last_adapted_project_id = project_id
	var parent_module := get_parent() as WorkspaceModule
	var surface := _resolve_workspace_surface()
	if surface == null or parent_module == null or parent_module.definition == null:
		_fit_preview_camera_after_layout.call_deferred(canvas_size, 2)
		return false
	var module_id := parent_module.definition.module_id
	var placement := surface.get_module_placement(module_id)
	if (
		placement == WorkspaceSurface.Placement.COLLAPSED
		or placement == WorkspaceSurface.Placement.NONE
		or parent_module.is_content_collapsed()
	):
		return false
	var min_h := parent_module.definition.minimum_size.y
	var h_chrome := (
		maxf(0.0, parent_module.size.x - preview_viewport_container.size.x)
		if (
			parent_module.size.x > 1.0
			and is_instance_valid(preview_viewport_container)
			and preview_viewport_container.size.x > 1.0
		)
		else 8.0
	)
	var v_chrome := _measure_vertical_chrome(parent_module)
	var resized := false
	if placement == WorkspaceSurface.Placement.DOCKED and surface.dock_host != null:
		var zone := surface.dock_host.layout.get_module_zone(module_id)
		var region_fill := surface.dock_host.layout.is_module_region_fill(module_id)
		if (
			not region_fill
			and zone in [WorkspaceDockLayout.DockZone.LEFT, WorkspaceDockLayout.DockZone.RIGHT]
		):
			var cur_size := surface.dock_host.layout.get_module_size(module_id)
			var module_w := (
				parent_module.size.x
				if parent_module.size.x > 1.0
				else (cur_size.x if cur_size.x > 0.0 else parent_module.definition.preferred_size.x)
			)
			var zone_host := surface.dock_host.get_zone_host(zone)
			var max_h := _max_docked_preview_height(surface, module_id, zone_host, min_h)
			var target_h := compute_adaptive_module_height(
				canvas_size, module_w, h_chrome, v_chrome, min_h, max_h
			)
			var target_w := cur_size.x if cur_size.x > 0.0 else module_w
			surface.dock_host.set_module_size(module_id, Vector2(target_w, target_h))
			_persist_ui4_preview_height_if_applicable(surface, module_id, target_h)
			resized = true
	elif placement == WorkspaceSurface.Placement.FLOATING:
		var rect := surface.get_floating_rect(module_id)
		var module_w := (
			rect.size.x
			if rect.size.x > 1.0
			else parent_module.definition.get_constrained_preferred_size().x
		)
		var bounds := surface.get_floating_bounds()
		var max_h := maxf(
			min_h, minf(bounds.size.y * 0.62 if bounds.size.y > 0.0 else 460.0, 460.0)
		)
		var target_h := compute_adaptive_module_height(
			canvas_size, module_w, h_chrome, v_chrome, min_h, max_h
		)
		surface.set_floating_rect(module_id, Rect2(rect.position, Vector2(module_w, target_h)))
		resized = true
	_fit_preview_camera_after_layout.call_deferred(canvas_size, 2)
	return resized


func _on_project_created(project: Project) -> void:
	if project == null:
		return
	_last_adapted_project_id = -1
	adapt_size_to_canvas.call_deferred(project.size, true)


func _on_project_switched() -> void:
	_sync_view_controls()
	if Global.current_project != null:
		adapt_size_to_canvas.call_deferred(Global.current_project.size, false)


func _schedule_initial_canvas_adaptation() -> void:
	if Global.headless_test_mode or Global.current_project == null:
		return
	if _last_adapted_project_id == Global.current_project.get_instance_id():
		return
	adapt_size_to_canvas.call_deferred(Global.current_project.size, false)


func _measure_vertical_chrome(parent_module: WorkspaceModule) -> float:
	if (
		parent_module != null
		and parent_module.size.y > 1.0
		and is_instance_valid(preview_viewport_container)
		and preview_viewport_container.size.y > 1.0
	):
		return maxf(0.0, parent_module.size.y - preview_viewport_container.size.y)
	var header_h := parent_module.get_header_height() if parent_module != null else 28.0
	var toggle_h := 24.0
	var drawer_h := _measure_controls_drawer_height() if _controls_expanded else 0.0
	return header_h + toggle_h + drawer_h + 6.0


func _fit_preview_camera_after_layout(canvas_size: Vector2, remaining_passes: int) -> void:
	if not is_inside_tree() or not is_instance_valid(camera):
		return
	if (
		is_instance_valid(preview_viewport_container)
		and preview_viewport_container.size.x > 1.0
		and preview_viewport_container.size.y > 1.0
	):
		camera.fit_to_frame(canvas_size)
	if remaining_passes > 1 and get_tree() != null:
		_fit_preview_camera_next_frame(canvas_size, remaining_passes - 1)


func _fit_preview_camera_next_frame(canvas_size: Vector2, remaining_passes: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.process_frame
	if is_inside_tree():
		_fit_preview_camera_after_layout(canvas_size, remaining_passes)


static func _triangle_icon(pointing_up: bool) -> ImageTexture:
	if pointing_up and _arrow_up_icon != null:
		return _arrow_up_icon
	if not pointing_up and _arrow_down_icon != null:
		return _arrow_down_icon
	var img := Image.create_empty(11, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for row in range(6):
		var inset := (5 - row) if pointing_up else row
		for x in range(inset, 11 - inset):
			img.set_pixel(x, row, Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	if pointing_up:
		_arrow_up_icon = tex
	else:
		_arrow_down_icon = tex
	return tex


func _ensure_collapsible_controls_ui() -> void:
	if not is_node_ready() or not is_instance_valid(preview_vbox):
		return
	if not is_instance_valid(_controls_divider):
		var divider := ColorRect.new()
		divider.name = "PreviewControlsDivider"
		divider.custom_minimum_size = Vector2(0.0, 1.0)
		divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_vbox.add_child(divider)
		if is_instance_valid(animation_bar):
			preview_vbox.move_child(divider, animation_bar.get_index())
		_controls_divider = divider
	if not is_instance_valid(_controls_toggle_row):
		var row := HBoxContainer.new()
		row.name = "PreviewControlsToggleRow"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		preview_vbox.add_child(row)
		_controls_toggle_row = row
	if not is_instance_valid(_controls_toggle_button):
		var btn := Button.new()
		btn.name = "PreviewControlsToggleButton"
		btn.toggle_mode = true
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.custom_minimum_size = Vector2(64.0, 22.0)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		btn.text = ""
		btn.toggled.connect(_on_controls_toggle_button_toggled)
		_controls_toggle_row.add_child(btn)
		_controls_toggle_button = btn
	_style_bottom_fold_controls(Stage4.active_mode())


func _style_bottom_fold_controls(mode: StringName) -> void:
	var pixel := mode != PhospriteTokens.LEGACY
	if is_instance_valid(_controls_divider):
		_controls_divider.color = (
			PhospriteTokens.color(mode, &"border_subtle") if pixel else Color(1.0, 1.0, 1.0, 0.16)
		)
	if not is_instance_valid(_controls_toggle_button):
		return
	var normal_col := (
		PhospriteTokens.color(mode, &"text_muted") if pixel else Color(0.76, 0.78, 0.82, 0.9)
	)
	var hover_col := (
		PhospriteTokens.color(mode, &"text_primary") if pixel else Color(0.95, 0.96, 0.98, 1.0)
	)
	var accent_col := PhospriteTokens.color(mode, &"accent_primary") if pixel else hover_col
	var pill_bg := StyleBoxFlat.new()
	pill_bg.bg_color = (
		PhospriteTokens.color(mode, &"well_surface") if pixel else Color(1.0, 1.0, 1.0, 0.06)
	)
	pill_bg.border_width_left = 1
	pill_bg.border_width_top = 1
	pill_bg.border_width_right = 1
	pill_bg.border_width_bottom = 1
	pill_bg.border_color = (
		PhospriteTokens.color(mode, &"border_subtle") if pixel else Color(1.0, 1.0, 1.0, 0.14)
	)
	pill_bg.content_margin_left = 8.0
	pill_bg.content_margin_right = 8.0
	pill_bg.content_margin_top = 2.0
	pill_bg.content_margin_bottom = 2.0
	pill_bg.anti_aliasing = false
	var pill_hover := pill_bg.duplicate() as StyleBoxFlat
	pill_hover.bg_color = (
		PhospriteTokens.color(mode, &"elevated_surface") if pixel else Color(1.0, 1.0, 1.0, 0.12)
	)
	for st in [&"normal", &"pressed", &"focus"]:
		_controls_toggle_button.add_theme_stylebox_override(st, pill_bg)
	for st in [&"hover", &"hover_pressed"]:
		_controls_toggle_button.add_theme_stylebox_override(st, pill_hover)
	_controls_toggle_button.add_theme_color_override(&"icon_normal_color", normal_col)
	_controls_toggle_button.add_theme_color_override(&"icon_pressed_color", normal_col)
	_controls_toggle_button.add_theme_color_override(&"icon_focus_color", normal_col)
	_controls_toggle_button.add_theme_color_override(&"icon_hover_color", hover_col)
	_controls_toggle_button.add_theme_color_override(&"icon_hover_pressed_color", accent_col)


func _on_controls_toggle_button_toggled(toggled_on: bool) -> void:
	set_controls_expanded(toggled_on)


func _measure_controls_drawer_height() -> float:
	if not is_instance_valid(animation_bar):
		return _last_drawer_height
	var bar_h := animation_bar.size.y
	if not animation_bar.visible or bar_h <= 1.0:
		bar_h = maxf(animation_bar.get_combined_minimum_size().y, 34.0)
	# Include 1px divider + VBox gap delta (expanded: 3*4=12px, collapsed: 1*2=2px -> +11px)
	return bar_h + 11.0


func _reconcile_viewport_height(
	expected_viewport_h: float, remaining_passes: int = 1, token: int = 0
) -> void:
	if token != 0 and token != _pending_reconcile_token:
		return
	if not is_instance_valid(preview_viewport_container) or not is_visible_in_tree():
		return
	var current_viewport_h := preview_viewport_container.size.y
	var diff := expected_viewport_h - current_viewport_h
	if absf(diff) >= 1.0:
		_adjust_preview_height_downward(diff)
	if _controls_expanded and is_instance_valid(animation_bar) and animation_bar.size.y > 1.0:
		_last_drawer_height = animation_bar.size.y + 11.0
	if is_instance_valid(camera):
		camera.update_transparent_checker_offset()
	if remaining_passes > 1 and is_inside_tree():
		_reconcile_viewport_height_next_frame(expected_viewport_h, remaining_passes - 1, token)


func _reconcile_viewport_height_next_frame(
	expected_viewport_h: float, remaining_passes: int, token: int
) -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.process_frame
	if is_inside_tree():
		_reconcile_viewport_height(expected_viewport_h, remaining_passes, token)


func _resolve_workspace_surface() -> WorkspaceSurface:
	var node: Node = get_parent()
	while node != null:
		var direct := node.get("workspace_surface") as WorkspaceSurface
		if is_instance_valid(direct):
			return direct
		var child_surface := node.get_node_or_null("WorkspaceSurface") as WorkspaceSurface
		if is_instance_valid(child_surface):
			return child_surface
		node = node.get_parent()
	if is_instance_valid(Global.control):
		var found := Global.control.find_child("WorkspaceSurface", true, false) as WorkspaceSurface
		if is_instance_valid(found):
			return found
	return null


func _max_docked_preview_height(
	surface: WorkspaceSurface, module_id: StringName, zone_host: Control, min_h: float
) -> float:
	var host_h := (
		zone_host.size.y if is_instance_valid(zone_host) and zone_host.size.y > 0.0 else 640.0
	)
	var zone := surface.dock_host.layout.get_module_zone(module_id)
	var zone_modules := surface.dock_host.layout.get_modules(zone)
	var sibling_reserve := 240.0 if zone_modules.size() > 1 else 0.0
	return maxf(min_h, host_h - sibling_reserve)


func _persist_ui4_preview_height_if_applicable(
	surface: WorkspaceSurface, module_id: StringName, target_h: float
) -> void:
	if surface == null or surface.dock_host == null:
		return
	if surface.dock_host.layout.get_module_zone(module_id) != WorkspaceDockLayout.DockZone.LEFT:
		return
	if surface.dock_host.layout.get_modules(WorkspaceDockLayout.DockZone.LEFT).size() <= 1:
		return
	if Global.config_cache != null:
		Global.config_cache.set_value("ui4", "preview_height", target_h)


func _adjust_preview_height_downward(delta_y: float) -> void:
	if absf(delta_y) < 0.5:
		return
	var parent_module := get_parent() as WorkspaceModule
	var surface := _resolve_workspace_surface()
	if surface != null and parent_module != null and parent_module.definition != null:
		var module_id := parent_module.definition.module_id
		var placement := surface.get_module_placement(module_id)
		var min_h := parent_module.definition.minimum_size.y
		if placement == WorkspaceSurface.Placement.FLOATING:
			var rect := surface.get_floating_rect(module_id)
			var target := Rect2(
				rect.position,
				Vector2(rect.size.x, maxf(min_h, rect.size.y + delta_y)),
			)
			surface.set_floating_rect(module_id, target)
			return
		if placement == WorkspaceSurface.Placement.DOCKED and surface.dock_host != null:
			var cur_size := surface.dock_host.layout.get_module_size(module_id)
			var base_h := parent_module.size.y if parent_module.size.y > 1.0 else cur_size.y
			if cur_size != Vector2.ZERO or base_h > 0.0:
				var zone := surface.dock_host.layout.get_module_zone(module_id)
				var zone_host := surface.dock_host.get_zone_host(zone)
				var max_h := _max_docked_preview_height(surface, module_id, zone_host, min_h)
				var target_w := cur_size.x if cur_size.x > 0.0 else parent_module.size.x
				var target_h := clampf(base_h + delta_y, min_h, max_h)
				surface.dock_host.set_module_size(module_id, Vector2(target_w, target_h))
				_persist_ui4_preview_height_if_applicable(surface, module_id, target_h)
				return
	size.y = maxf(custom_minimum_size.y, size.y + delta_y)


func _apply_controls_expanded_state() -> void:
	if not is_node_ready():
		return
	if is_instance_valid(_controls_divider):
		_controls_divider.visible = _controls_expanded
	if is_instance_valid(animation_bar):
		animation_bar.visible = _controls_expanded
	if is_instance_valid(preview_vbox):
		var sep := 4 if _controls_expanded else 2
		if preview_vbox.get_theme_constant(&"separation") != sep:
			preview_vbox.add_theme_constant_override(&"separation", sep)
	if is_instance_valid(_controls_toggle_button):
		_controls_toggle_button.set_pressed_no_signal(_controls_expanded)
		_controls_toggle_button.icon = _triangle_icon(_controls_expanded)
		_controls_toggle_button.tooltip_text = (
			tr("Hide preview controls") if _controls_expanded else tr("Show preview controls")
		)


func _get_preview_bg_style(mode: StringName) -> StyleBoxFlat:
	if _preview_bg_styles.has(mode):
		return _preview_bg_styles[mode] as StyleBoxFlat
	var style := StyleBoxFlat.new()
	style.bg_color = PhospriteTokens.color(mode, &"canvas_backdrop")
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	_preview_bg_styles[mode] = style
	return style


func _refresh_preview_pixel_chrome() -> void:
	if not is_node_ready():
		return
	_ensure_collapsible_controls_ui()
	_apply_controls_expanded_state()
	var mode := Stage4.active_mode()
	var pixel := mode != PhospriteTokens.LEGACY
	if pixel:
		var bg_style := _get_preview_bg_style(mode)
		if get_theme_stylebox(&"panel") != bg_style:
			add_theme_stylebox_override(&"panel", bg_style)
	elif has_theme_stylebox_override(&"panel"):
		remove_theme_stylebox_override(&"panel")
	_style_bottom_fold_controls(mode)
	if is_instance_valid(preview_viewport_container):
		preview_viewport_container.custom_minimum_size = (
			Vector2(0.0, 72.0) if pixel else Vector2.ZERO
		)
	var view_buttons := get_node_or_null(^"VBox/Animation/PreviewViewButtons") as HBoxContainer
	if view_buttons != null:
		var sep := 2 if pixel else 4
		if view_buttons.get_theme_constant(&"separation") != sep:
			view_buttons.add_theme_constant_override(&"separation", sep)
		for child in view_buttons.get_children():
			if child is Button:
				var btn := child as Button
				btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				btn.custom_minimum_size = Vector2(0.0, 34.0) if pixel else Vector2(0.0, 48.0)
				Stage4.style_button(btn, mode)


## Preview actions share the existing View menu handlers and global canvas state.
## The menu keeps its hidden original entries for keyboard shortcuts.
func _on_center_canvas_pressed() -> void:
	if Global.current_project != null:
		Global.top_menu_container.view_menu_id_pressed(Global.ViewMenu.CENTER_CANVAS)


func _on_mirror_view_toggled(enabled: bool) -> void:
	if Global.current_project != null and Global.mirror_view != enabled:
		Global.top_menu_container.view_menu_id_pressed(Global.ViewMenu.MIRROR_VIEW)
	_sync_view_controls()


func _on_show_grid_toggled(enabled: bool) -> void:
	if Global.current_project != null and Global.draw_grid != enabled:
		Global.top_menu_container.view_menu_id_pressed(Global.ViewMenu.SHOW_GRID)
	_sync_view_controls()


func _on_show_pixel_grid_toggled(enabled: bool) -> void:
	if Global.current_project != null and Global.draw_pixel_grid != enabled:
		Global.top_menu_container.view_menu_id_pressed(Global.ViewMenu.SHOW_PIXEL_GRID)
	_sync_view_controls()


func _sync_view_controls() -> void:
	if is_instance_valid(mirror_view_button):
		mirror_view_button.set_pressed_no_signal(Global.mirror_view)
	if is_instance_valid(show_grid_button):
		show_grid_button.set_pressed_no_signal(Global.draw_grid)
	if is_instance_valid(show_pixel_grid_button):
		show_pixel_grid_button.set_pressed_no_signal(Global.draw_pixel_grid)


func _on_GrayscaleButton_toggled(button_pressed: bool) -> void:
	if Global.greyscale_view != button_pressed:
		Global.greyscale_view = button_pressed


func _on_greyscale_view_changed(enabled: bool) -> void:
	if is_instance_valid(grayscale_button):
		grayscale_button.set_pressed_no_signal(enabled)


func _on_OptionButton_item_selected(index: int) -> void:
	canvas_preview.mode = index
	if index == 0:
		$VBox/Animation/VBoxContainer/Options.visible = false
		canvas_preview.transparent_checker.fit_rect(
			Rect2(Vector2.ZERO, Global.current_project.size)
		)
	else:
		$VBox/Animation/VBoxContainer/Options.visible = true
	canvas_preview.queue_redraw()


func _on_HFrames_value_changed(value: float) -> void:
	canvas_preview.h_frames = value
	var frames: int = canvas_preview.h_frames * canvas_preview.v_frames
	start_frame.max_value = frames
	end_frame.max_value = frames
	canvas_preview.queue_redraw()


func _on_VFrames_value_changed(value: float) -> void:
	canvas_preview.v_frames = value
	var frames: int = canvas_preview.h_frames * canvas_preview.v_frames
	start_frame.max_value = frames
	end_frame.max_value = frames
	canvas_preview.queue_redraw()


func _on_StartFrame_value_changed(value: float) -> void:
	canvas_preview.frame_index = value - 1
	canvas_preview.start_sprite_sheet_frame = value
	if end_frame.value < value:
		end_frame.value = value
	canvas_preview.queue_redraw()


func _on_EndFrame_value_changed(value: float) -> void:
	canvas_preview.end_sprite_sheet_frame = value
	if start_frame.value > value:
		start_frame.value = value
		canvas_preview.frame_index = value - 1
	canvas_preview.queue_redraw()


func _on_PreviewViewportContainer_mouse_entered() -> void:
	camera.set_process_input(true)


func _on_PreviewViewportContainer_mouse_exited() -> void:
	camera.set_process_input(false)
