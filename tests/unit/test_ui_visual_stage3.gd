extends "res://tests/test_base.gd"

const Stage3 := preload("res://src/UI/DesignSystem/PhospriteStage3Controls.gd")
const Profile3 := preload("res://src/UI/Workspace/WorkspaceUIProfile3.gd")
const Builtins := preload("res://src/UI/Workspace/WorkspaceBuiltinModules.gd")


func test_ui3_size_curve_is_continuous_and_preserves_both_endpoints() -> void:
	check_eq(Stage3.CAPSULE_WIDTH, 48.0, "new capsule has exact width")
	check_eq(Stage3.TRACK_WIDTH, 14.0, "vertical rail remains narrow")
	check_eq(Stage3.size_from_position(0.0, 1.0, 128.0), 1.0, "minimum size is one pixel")
	check_eq(
		Stage3.size_from_position(0.55, 1.0, 128.0), 16.0,
		"first 55% reaches 16 pixels"
	)
	check_eq(Stage3.size_from_position(1.0, 1.0, 128.0), 128.0, "128px endpoint preserved")
	for size_value in [1.0, 2.0, 8.0, 16.0, 17.0, 32.0, 64.0, 128.0]:
		var position := Stage3.position_from_size(size_value, 1.0, 128.0)
		var actual := Stage3.size_from_position(position, 1.0, 128.0)
		check_almost_eq(actual, size_value, 0.51, "curve maps source pixel size reversibly")
	check_eq(
		Stage3.size_from_position(1.0, 1.0, 256.0), 256.0,
		"larger existing brush configurations must not be truncated"
	)
	check_true(
		not Stage3.supports_pixel_size_mapping(0, 100, 0.01, "%"),
		"percent-based and fine-step tools must keep their native size mapping"
	)


func test_color_tearoff_has_real_threshold_and_clamps_to_editor_bounds() -> void:
	check_true(
		not Stage3.should_pin_popup(Vector2(23.0, 0.0)),
		"ordinary color-card tap and small finger drift remain temporary"
	)
	check_true(Stage3.should_pin_popup(Vector2(24.0, 0.0)), "24px drag pins popup")
	check_eq(
		Stage3.popup_position(
			Vector2(40.0, 30.0), Vector2(-100.0, 600.0),
			Vector2(320.0, 460.0), Vector2(700.0, 800.0)
		),
		Vector2(0.0, 340.0),
		"tear-off remains fully visible in the viewport"
	)


func test_ui3_hud_does_not_replace_real_slider_or_workspace_exclusion() -> void:
	var root := Control.new()
	root.size = Vector2(900.0, 700.0)
	tree.root.add_child(root)
	var manager := WorkspaceModuleManager.new()
	root.add_child(manager)
	check_true(Builtins.register_defaults(manager), "workspace module definitions exist")
	var dock := WorkspaceDockHost.new()
	root.add_child(dock)
	dock.size = root.size
	check_true(dock.setup(manager), "workspace host is ready")
	var surface := WorkspaceSurface.new()
	root.add_child(surface)
	check_true(surface.setup(manager, dock), "workspace surface is ready")
	var left := ScrollContainer.new()
	root.add_child(left)
	var profile := Profile3.new()
	root.add_child(profile)
	check_true(profile.setup(root, left, surface), "profile has original tool source")
	check_true(profile._create_quick_bar(), "existing quick strip creates")
	check_true(is_instance_valid(profile._quick_hud), "separate 180ms preview HUD exists")
	check_eq(profile._quick_hud.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"HUD never captures drawing input")
	check_true(
		profile._quick_bar.get_index() < surface.get_floating_layer().get_index(),
		"fixed quick bar remains below real floating-window layer"
	)
	check_has(
		FileAccess.get_file_as_string("res://src/UI/Workspace/WorkspaceUIProfile3.gd"),
		"surface.set_floating_exclusion_rect(",
		"Preview and other Workspace windows must continue to avoid the capsule"
	)
	root.queue_free()
	await tree.process_frame


func test_stage3_visual_controls_keep_original_source_ranges_and_no_new_tool_state() -> void:
	var src := FileAccess.get_file_as_string("res://src/UI/Workspace/WorkspaceUIProfile3.gd")
	check_has(src, "source.value = (", "size curve writes through the original tool Range")
	check_has(src, "source.value_changed.connect(callback)", "external brush size changes sync")
	check_has(src, "Tools.swap_color()", "swatches reuse original Tool color switching")
	check_has(src, "PALETTE_HEADER_HEIGHT := 36.0", "tear-off uses dedicated 36px header")
	check_has(src, "_palette_pinned", "temporary and pinned palette are separate states")
	check_has(src, "_on_palette_header_input", "existing palette has the only tear-off grip")
	check_has(src, "Stage3.HUD_DISMISS_SECONDS", "preview hides 180ms after slider release")
	check_has(src, "_set_quick_reservation(rect)", "capsule still reserves floating exclusion")
