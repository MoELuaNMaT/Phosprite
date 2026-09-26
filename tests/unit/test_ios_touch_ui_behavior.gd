extends "res://tests/test_base.gd"

const POLICY := preload("res://src/InputAdapter/TouchUIBehavior.gd")
const MAIN_SOURCE := "res://src/Main.gd"


func test_touch_mode_suppresses_tooltips_and_restores_for_real_pointer() -> void:
	var host := Control.new()
	tree.root.add_child(host)

	var button := Button.new()
	button.tooltip_text = "Desktop hint"
	host.add_child(button)

	var policy := POLICY.new()
	host.add_child(policy)
	check_true(policy.setup(tree, host, true), "touch UI policy should initialize in forced test mode")
	check_eq(button.tooltip_text, "Desktop hint", "pointer mode should preserve desktop tooltip")

	var touch_press := InputEventScreenTouch.new()
	touch_press.pressed = true
	policy._input(touch_press)
	check_true(policy.is_touch_ui_mode(), "direct touch must switch the GUI into touch mode")
	check_eq(button.tooltip_text, "", "touch mode must suppress existing hover tooltips")

	var dynamic := Button.new()
	dynamic.tooltip_text = "Dynamic hint"
	host.add_child(dynamic)
	check_eq(dynamic.tooltip_text, "", "controls added during touch mode must suppress tooltips")

	var emulated_motion := InputEventMouseMotion.new()
	emulated_motion.device = InputEvent.DEVICE_ID_EMULATION
	policy._input(emulated_motion)
	check_true(
		policy.is_touch_ui_mode(),
		"touch-generated mouse motion must not restore desktop hover semantics",
	)
	check_eq(button.tooltip_text, "", "synthetic mouse motion must leave tooltips suppressed")

	var physical_motion := InputEventMouseMotion.new()
	physical_motion.device = 0
	policy._input(physical_motion)
	check_true(not policy.is_touch_ui_mode(), "real pointer motion must restore pointer mode")
	check_eq(button.tooltip_text, "Desktop hint", "real pointer must restore original tooltip")
	check_eq(dynamic.tooltip_text, "Dynamic hint", "dynamic tooltip must restore for real pointer")

	host.queue_free()
	await tree.process_frame


func test_touch_release_clears_button_focus_only() -> void:
	var host := Control.new()
	tree.root.add_child(host)

	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	host.add_child(button)

	var policy := POLICY.new()
	host.add_child(policy)
	check_true(policy.setup(tree, host, true), "touch UI policy should initialize")

	button.grab_focus()
	check_true(button.has_focus(), "fixture button must begin focused")

	var touch_release := InputEventScreenTouch.new()
	touch_release.pressed = false
	policy._input(touch_release)
	await tree.process_frame
	check_true(not button.has_focus(), "touch release must clear desktop-style Button focus")

	host.queue_free()
	await tree.process_frame


func test_main_installs_global_touch_ui_policy() -> void:
	var source := FileAccess.get_file_as_string(MAIN_SOURCE)
	check_has(
		source,
		'const TOUCH_UI_BEHAVIOR := preload("res://src/InputAdapter/TouchUIBehavior.gd")',
		"Main must own the shared iPad touch UI behavior",
	)
	check_has(
		source,
		"touch_ui_behavior.setup(get_tree(), self)",
		"touch UI behavior must cover the full application UI tree",
	)
