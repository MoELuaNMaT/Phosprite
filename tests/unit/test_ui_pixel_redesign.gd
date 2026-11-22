extends "res://tests/test_base.gd"

const Tokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")
const PixelStyle := preload("res://src/UI/DesignSystem/PhospritePixelStyle.gd")
const Stage2 := preload("res://src/UI/DesignSystem/PhospriteStage2Chrome.gd")
const Stage4 := preload("res://src/UI/DesignSystem/PhospriteStage4Chrome.gd")
const QIcons := preload("res://src/UI/DesignSystem/PhospriteQIcons.gd")
const ThemeBridge := preload("res://src/UI/DesignSystem/PhospriteThemeBridge.gd")
const CanvasPolicy := preload("res://src/UI/Canvas/CanvasVisualPolicy.gd")
const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")
const Manager := preload("res://src/UI/Workspace/WorkspaceModuleManager.gd")
const DockHost := preload("res://src/UI/Workspace/WorkspaceDockHost.gd")
const Surface := preload("res://src/UI/Workspace/WorkspaceSurface.gd")


class ThemeCounterButton:
	extends Button
	var theme_notifications := 0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_THEME_CHANGED:
			theme_notifications += 1


func test_all_79_q_icons_import_and_scale_nearest() -> void:
	var total := (
		QIcons.TOOL_PATHS.size() + QIcons.STANDARD_PATHS.size() + QIcons.COMPACT_PATHS.size()
	)
	check_eq(total, 79, "Q icon registry covers all 79 manifest icons")
	check_true(QIcons.tool_icon(&"Gradient") != null, "Gradient tool resolves directly")
	check_true(QIcons.tool_icon(&"GradientTool") != null, "GradientTool alias also resolves")

	for tool_name in QIcons.TOOL_PATHS:
		var tex := QIcons.tool_icon(tool_name)
		check_true(tex != null, "tool icon loads: %s" % tool_name)
		if tex != null:
			check_eq(tex.get_size(), Vector2(32, 32), "tool icon 2x scaled to 32x32")

	for std_id in QIcons.STANDARD_PATHS:
		var tex := QIcons.standard_icon(std_id)
		var tex_1x := QIcons.standard_icon_1x(std_id)
		check_true(tex != null and tex_1x != null, "standard icon loads: %s" % std_id)
		if tex != null and tex_1x != null:
			check_eq(tex.get_size(), Vector2(32, 32), "standard icon 2x scaled to 32x32")
			check_eq(tex_1x.get_size(), Vector2(16, 16), "standard icon 1x stays 16x16")

	for cmp_id in QIcons.COMPACT_PATHS:
		var tex := QIcons.compact_icon(cmp_id)
		var tex_1x := QIcons.compact_icon_1x(cmp_id)
		check_true(tex != null and tex_1x != null, "compact icon loads: %s" % cmp_id)
		if tex != null and tex_1x != null:
			check_eq(tex.get_size(), Vector2(24, 24), "compact icon 2x scaled to 24x24")
			check_eq(tex_1x.get_size(), Vector2(12, 12), "compact icon 1x stays 12x12")


func test_theme_bridge_applies_pixel_styleboxes_without_nested_panel_borders() -> void:
	check_eq(Global.pixel_ui_unit, 2, "default pixel UI unit is 2px for crisp stepped chrome")
	for mode in [Tokens.SUNNY, Tokens.TWILIGHT]:
		var t := Theme.new()
		ThemeBridge.apply_to_theme(t, mode, 2)
		check_true(
			t.get_stylebox(&"normal", &"Button") is StyleBoxTexture,
			"Button normal uses pixel nine-slice"
		)
		check_true(
			t.get_stylebox(&"panel", &"PopupMenu") is StyleBoxTexture,
			"PopupMenu panel uses pixel nine-slice"
		)
		check_true(
			t.get_stylebox(&"panel", &"PanelContainer") is StyleBoxFlat,
			"Inner PanelContainer stays flat to prevent nested frames and dark backdrop fallback"
		)
		check_eq(
			CanvasPolicy.resolve_backdrop_color(t),
			Tokens.color(mode, &"canvas_backdrop"),
			"Canvas backdrop resolves to semantic token for %s" % mode
		)
		check_true(
			t.get_stylebox(&"normal", &"LineEdit") is StyleBoxTexture,
			"LineEdit normal uses pixel nine-slice"
		)
		check_true(
			t.get_icon(&"checked", &"CheckBox") is ImageTexture,
			"CheckBox checked uses pixel ImageTexture"
		)
		check_true(
			t.get_icon(&"grabber", &"HSlider") is ImageTexture,
			"HSlider grabber uses pixel ImageTexture"
		)
		check_eq(
			t.get_icon(&"arrow", &"OptionButton").get_size(),
			Vector2(12, 12),
			"OptionButton arrow uses compact 12x12 pixel chevron"
		)
		check_true(not t.has_font(&"font", &"Button"), "ThemeBridge never overrides CJK font")


func test_pixel_styles_cache_textures_keep_non_negative_margins_and_are_idempotent() -> void:
	var a := PixelStyle.make_style(
		Tokens.TIER_M, Color("F2EFE9"), Color("2C2A29"), Color("C9C2B6"), true, 2
	)
	var b := PixelStyle.make_style(
		Tokens.TIER_M, Color("F2EFE9"), Color("2C2A29"), Color("C9C2B6"), true, 2
	)
	check_eq(a.texture, b.texture, "identical pixel style keys reuse cached ImageTexture")
	var p := PixelStyle.make_style(
		Tokens.TIER_M, Color("E85D3F"), Color("2C2A29"), Color("C9C2B6"), false, 2, true
	)
	check_true(p.content_margin_right >= 0.0, "pressed right margin is never negative")
	check_true(p.content_margin_bottom >= 0.0, "pressed bottom margin is never negative")
	check_almost_eq(
		a.content_margin_left + a.content_margin_right,
		p.content_margin_left + p.content_margin_right,
		0.01,
		"normal and pressed horizontal margins have identical span"
	)

	for state in [&"normal", &"hover", &"pressed", &"disabled", &"focus", &"well"]:
		var st := Stage4.button_style(Tokens.SUNNY, state)
		check_true(st.content_margin_left >= 0.0, "Stage4 %s left >= 0" % state)
		check_true(st.content_margin_top >= 0.0, "Stage4 %s top >= 0" % state)
		check_true(st.content_margin_right >= 0.0, "Stage4 %s right >= 0" % state)
		check_true(st.content_margin_bottom >= 0.0, "Stage4 %s bottom >= 0" % state)

	check_eq(
		Stage2.make_shell(Tokens.SUNNY, Tokens.TIER_L, &"panel_surface"),
		Stage2.make_shell(Tokens.SUNNY, Tokens.TIER_L, &"panel_surface"),
		"Stage2 make_shell returns cached StyleBoxTexture instance"
	)

	var btn := ThemeCounterButton.new()
	tree.root.add_child(btn)
	Stage4.style_button(btn, Tokens.SUNNY)
	btn.theme_notifications = 0
	Stage4.style_button(btn, Tokens.SUNNY)
	check_eq(
		btn.theme_notifications,
		0,
		"re-applying Stage4 style_button is idempotent and emits zero NOTIFICATION_THEME_CHANGED"
	)
	btn.free()


func test_floating_module_drag_moves_window_in_real_time_and_restores_on_cancel() -> void:
	var manager := Manager.new()
	var host := DockHost.new()
	var surface := Surface.new()
	Builtins.register_defaults(manager)
	host.size = Vector2(1194.0, 834.0)
	check_true(host.setup(manager), "dock host initializes")
	check_true(surface.setup(manager, host), "surface initializes")
	surface.configure_floating_snap_policy({})

	var initial := Rect2(200.0, 120.0, 320.0, 220.0)
	check_true(surface.float_module(Builtins.PREVIEW_ID, initial), "Preview starts floating")
	var preview := manager.get_instance(Builtins.PREVIEW_ID)
	check_true(
		surface.begin_module_drag(Builtins.PREVIEW_ID, Vector2(220.0, 134.0)),
		"floating drag begins"
	)
	var candidate := surface.update_module_drag(Vector2(520.0, 314.0))
	var expected_pos := (candidate.get("rect", Rect2()) as Rect2).position
	check_almost_eq(
		preview.position.x,
		expected_pos.x,
		0.01,
		"floating window X follows pointer immediately during drag"
	)
	check_almost_eq(
		preview.position.y,
		expected_pos.y,
		0.01,
		"floating window Y follows pointer immediately during drag"
	)
	check_true(
		not surface.get_preview_rect().has_area(),
		"live floating drag hides redundant ghost rectangle"
	)
	surface.cancel_module_drag()
	check_eq(
		preview.position,
		initial.position,
		"canceling a live floating drag restores original window position"
	)

	manager.destroy_all_modules()
	surface.free()
	host.free()
	manager.free()


func test_workspace_profiles_are_independent_without_animation_desk_label() -> void:
	for po_path in ["res://Translations/zh_CN.po", "res://Translations/zh_TW.po"]:
		var text := FileAccess.get_file_as_string(po_path)
		check_true(not text.contains("动画工作台"), "zh_CN removes Animation Workspace label")
		check_true(not text.contains("動畫工作台"), "zh_TW removes Animation Workspace label")
		check_true(text.contains("U-Frame Dock"), "translations include U-Frame Dock profile")


func test_topbar_timeline_and_dock_host_pixel_contracts() -> void:
	var top_src := FileAccess.get_file_as_string(
		"res://src/UI/TopMenuContainer/TopMenuContainer.gd"
	)
	check_has(
		top_src,
		"return_home_button.custom_minimum_size = Vector2(36, 36)",
		"Gallery button matches 36x36 uniform icon-only topbar keycap"
	)
	var tl_src := FileAccess.get_file_as_string(
		"res://src/UI/DesignSystem/PhospriteStage4Timeline.gd"
	)
	check_has(
		tl_src,
		"_style_add_layer_dropdown",
		"AddLayerList split dropdown stays flat inside AddLayer"
	)
	check_eq(
		DockHost.timeline_height_limit(32.0, 160.0),
		INF,
		"sub-minimum dummy window height does not prematurely clamp timeline height"
	)
