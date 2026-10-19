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
	check_true(
		policy.setup(tree, host, true), "touch UI policy should initialize in forced test mode"
	)
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
	# Even a device-0 mouse event can be synthesized just after a touch.
	policy._input(physical_motion)
	check_true(policy.is_touch_ui_mode(), "touch-down must prevent synthetic device-0 hover")
	var touch_release := InputEventScreenTouch.new()
	touch_release.pressed = false
	policy._input(touch_release)
	policy._input(physical_motion)
	check_true(policy.is_touch_ui_mode(), "immediate post-touch device-0 hover stays suppressed")
	policy._last_touch_event_msec -= POLICY.TOUCH_POINTER_GRACE_MSEC + 1
	policy._input(physical_motion)
	check_true(not policy.is_touch_ui_mode(), "real pointer motion restores after touch grace")
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


func test_global_shortcut_hints_are_disabled_without_removing_keyboard_bindings() -> void:
	var host := Control.new()
	tree.root.add_child(host)
	var button := Button.new()
	button.tooltip_text = "Delete frame"
	var shortcut := Shortcut.new()
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_DELETE
	key_event.shift_pressed = true
	shortcut.events = [key_event]
	button.shortcut = shortcut
	host.add_child(button)

	var policy := POLICY.new()
	host.add_child(policy)
	check_true(policy.setup(tree, host, true), "touch-enabled policy installs")
	check_true(not button.shortcut_in_tooltip, "Shift+Delete cannot become a tooltip")
	check_eq(button.shortcut, shortcut, "keyboard shortcut is still bound to button")
	check_eq(button.tooltip_text, "Delete frame", "desktop explanation remains intact")

	var dynamic := Button.new()
	dynamic.shortcut = shortcut
	host.add_child(dynamic)
	check_true(not dynamic.shortcut_in_tooltip, "new buttons inherit global shortcut suppression")

	var touch_press := InputEventScreenTouch.new()
	touch_press.pressed = true
	policy._input(touch_press)
	check_eq(button.tooltip_text, "", "touch additionally hides descriptive tooltip")
	check_true(not button.shortcut_in_tooltip, "touch cannot synthesize shortcut-only tooltip")
	host.queue_free()
	await tree.process_frame


func test_shortcut_hints_are_globally_disabled_even_on_desktop() -> void:
	var host := Control.new()
	tree.root.add_child(host)
	var button := Button.new()
	button.tooltip_text = "Add a frame"
	host.add_child(button)
	var policy := POLICY.new()
	host.add_child(policy)
	check_true(policy.setup(tree, host, false), "desktop policy installs globally")
	check_true(not button.shortcut_in_tooltip, "desktop button shortcut labels hidden")
	check_eq(button.tooltip_text, "Add a frame", "desktop descriptions remain available")
	host.queue_free()
	await tree.process_frame


func test_touch_pointer_grace_blocks_ghost_hover_without_blocking_real_mouse() -> void:
	check_true(
		not POLICY.should_restore_pointer_mode(0, true, 1000, 700),
		"mouse event cannot restore hover while a finger is down",
	)
	check_true(
		not POLICY.should_restore_pointer_mode(0, false, 1100, 1000),
		"post-touch device-0 mouse event is treated as synthetic",
	)
	check_true(
		not POLICY.should_restore_pointer_mode(InputEvent.DEVICE_ID_EMULATION, false, 2000, 1000),
		"explicitly emulated input never restores hover",
	)
	check_true(
		POLICY.should_restore_pointer_mode(0, false, 1600, 1000),
		"real mouse movement after the grace period restores hover",
	)
	check_true(
		POLICY.should_restore_pointer_mode(0, false, 1000, -1),
		"mouse-only use restores hover immediately",
	)
