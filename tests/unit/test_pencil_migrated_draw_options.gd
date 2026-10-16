extends "res://tests/test_base.gd"

const PENCIL_SCENE := preload("res://src/Tools/DesignTools/Pencil.tscn")
const GLOBAL_OPTIONS_SCENE := preload("res://src/UI/GlobalToolOptions/GlobalToolOptions.tscn")


func test_pencil_owns_the_three_migrated_draw_controls() -> void:
	var pencil := PENCIL_SCENE.instantiate()
	var pressure := pencil.get_node_or_null(^"PressureSettings") as Button
	var perfect := pencil.get_node_or_null(^"PixelPerfect") as CheckBox
	var transparent := pencil.get_node_or_null(^"TransparentOnly") as CheckBox
	check_true(pressure != null, "Pencil has the Dynamics/pressure settings entry")
	check_true(perfect != null, "Pencil has the Pixel Perfect switch")
	check_true(transparent != null, "Pencil has the Transparent Only switch")
	if pressure != null and perfect != null and transparent != null:
		check_eq(pressure.get_parent(), pencil, "pressure follows Pencil's vertical layout")
		check_eq(perfect.get_parent(), pencil, "perfect follows Pencil's vertical layout")
		check_eq(transparent.get_parent(), pencil, "transparent follows Pencil's vertical layout")
		check_true(pressure.get_index() < perfect.get_index(), "pressure is above Perfect")
		check_true(perfect.get_index() < transparent.get_index(), "Perfect is above Transparent")
	pencil.free()


func test_timeline_hides_only_three_moved_controls_and_keeps_dynamics_panel() -> void:
	var global_options := GLOBAL_OPTIONS_SCENE.instantiate()
	var controls := global_options.get_node("ScrollContainer/CenterContainer/GridContainer")
	for name in ["PixelPerfect", "AlphaLock", "Dynamics"]:
		var control := controls.get_node(name) as Control
		check_true(not control.visible, "%s is removed from the timeline header" % name)
	for name in ["Horizontal", "Vertical", "DiagonalXY", "DiagonalXMinusY", "MirrorOptions"]:
		var control := controls.get_node(name) as Control
		check_true(control.visible, "%s mirror control remains visible" % name)
	check_eq(controls.columns, 5, "timeline mirror strip is compact")
	check_true(global_options.get_node_or_null(^"DynamicsPanel") != null, "Dynamics dialog remains")
	global_options.free()


func test_migrated_buttons_preserve_canonical_tool_modes_and_shortcuts() -> void:
	var pencil := FileAccess.get_file_as_string("res://src/Tools/DesignTools/Pencil.gd")
	var global_options := FileAccess.get_file_as_string(
		"res://src/UI/GlobalToolOptions/GlobalToolOptions.gd"
	)
	check_has(pencil, 'options.get("pixel_perfect")', "Pencil delegates Perfect to source")
	check_has(pencil, 'options.get("alpha_lock")', "Pencil delegates Alpha Lock to source")
	check_has(pencil, 'options.call(&"show_dynamics_at", $PressureSettings)', "existing Dynamics")
	check_has(
		pencil, "set_pressed_no_signal(Tools.pixel_perfect)", "shared Perfect state is synced"
	)
	check_has(
		pencil, "set_pressed_no_signal(Tools.alpha_locked)", "shared Alpha Lock state is synced"
	)
	check_has(
		global_options, 'event.is_action_pressed(&"pixel_perfect")', "Perfect shortcut remains"
	)
	check_has(global_options, 'event.is_action_pressed(&"alpha_lock")', "Alpha shortcut remains")
	check_has(global_options, "dynamics_panel.popup_on_parent", "original Dynamics panel remains")
