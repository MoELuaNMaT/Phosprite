extends "res://tests/test_base.gd"

const ADAPTER := preload("res://src/InputAdapter/CanvasInputAdapter.gd")
const ADAPTER_SOURCE := "res://src/InputAdapter/CanvasInputAdapter.gd"
const TOOL_BUTTONS_SOURCE := "res://src/UI/ToolsPanel/ToolButtons.gd"
const COLOR_PICKER_SOURCE := "res://src/Tools/UtilityTools/ColorPicker.gd"
const COLOR_SAMPLING_SOURCE := "res://src/Tools/UtilityTools/ColorSampling.gd"


func test_color_picker_bypasses_long_press_arbitration() -> void:
	check_true(
		not ADAPTER.should_defer_finger_content_for_long_press(&"ColorPicker"),
		"selected Color Picker must begin immediately so finger Tap/Drag picks normally"
	)
	check_true(
		ADAPTER.should_defer_finger_content_for_long_press(&"Pencil"),
		"ordinary Primary tools must defer the first finger stroke for long-press arbitration"
	)


func test_long_press_slop_is_acquisition_only() -> void:
	check_true(
		not ADAPTER.long_press_motion_exceeds_slop(Vector2.ZERO, Vector2(6, 6)),
		"small touch jitter must remain eligible for long press"
	)
	check_true(
		ADAPTER.long_press_motion_exceeds_slop(
			Vector2.ZERO, Vector2(ADAPTER.FINGER_LONG_PRESS_SLOP_PX, 0)
		),
		"crossing the slop must commit the gesture to the normal Primary tool"
	)


func test_long_press_does_not_draw_then_undo() -> void:
	var src := FileAccess.get_file_as_string(ADAPTER_SOURCE)
	check_has(src, '"content_pending": false', "finger content needs an explicit pending state")
	check_has(
		src,
		"create_timer(FINGER_LONG_PRESS_SECONDS)",
		"long press must resolve while a stationary finger is still held"
	)
	check_has(
		src,
		"_dispatch_content_press(canvas, screen_position)",
		"normal drawing must still cross the existing tool-event boundary"
	)
	check_has(
		src,
		"_sample_primary_color(canvas, current)",
		"long press must sample without temporarily switching the selected tool"
	)
	check_true(
		not ("undo_redo.undo" in src),
		"long-press disambiguation must not mutate first and repair the result through Undo"
	)


func test_long_press_timer_is_bound_to_exact_touch_contact() -> void:
	var src := FileAccess.get_file_as_string(ADAPTER_SOURCE)
	check_has(src, "_touch_generation += 1", "each touch begin needs a new contact generation")
	check_has(
		src,
		'"generation": _touch_generation',
		"the captured touch state must retain its contact generation"
	)
	check_has(
		src,
		"_try_begin_long_press.bind(canvas, touch_id, generation)",
		"the delayed timeout must capture the exact contact generation"
	)
	check_has(
		src,
		'int(state.get("generation", -1)) != generation',
		"a stale timeout must not activate after iOS reuses a touch index"
	)


func test_long_press_release_samples_the_lift_position() -> void:
	var src := FileAccess.get_file_as_string(ADAPTER_SOURCE)
	var end_content := src.find("func _end_content")
	var dispatch_motion := src.find("func _dispatch_motion", end_content)
	check_true(
		end_content >= 0 and dispatch_motion > end_content, "adapter must expose _end_content"
	)
	if end_content >= 0 and dispatch_motion > end_content:
		var body := src.substr(end_content, dispatch_motion - end_content)
		check_has(
			body,
			"_sample_primary_color(canvas, screen_position)",
			"long-press release must sample the final lift position even without a final drag event"
		)


func test_tool_buttons_use_native_touch_and_clear_touch_hover_state() -> void:
	var src := FileAccess.get_file_as_string(TOOL_BUTTONS_SOURCE)
	check_has(src, "InputEventScreenTouch", "tool selection must consume direct touch")
	check_has(src, "InputEventScreenDrag", "tool taps must cancel when the finger drags away")
	check_has(
		src,
		"Control.MOUSE_FILTER_IGNORE",
		"touch mode must stop synthetic mouse hit-testing from leaving a hover state"
	)
	check_has(src, 'button.tooltip_text = ""', "touch mode must suppress delayed tooltips")
	check_has(
		src,
		"event.device != -1",
		"only a physical mouse/trackpad event may restore desktop hover semantics"
	)
	check_has(
		src,
		"MOUSE_BUTTON_LEFT",
		"direct touch must operate the current Primary slot without deleting Secondary state"
	)


func test_color_picker_and_long_press_share_sampling_model() -> void:
	var picker := FileAccess.get_file_as_string(COLOR_PICKER_SOURCE)
	var sampling := FileAccess.get_file_as_string(COLOR_SAMPLING_SOURCE)
	check_has(
		picker,
		"COLOR_SAMPLING.pick_color(pos, button, _mode)",
		"normal Color Picker Tap/Drag must use the shared sampler"
	)
	check_has(
		sampling,
		"target_button: int",
		"sampling must keep Primary/Secondary as an explicit target instead of a gesture assumption"
	)
	check_has(
		sampling,
		"Tools.assign_color(color, target_button, false, palette_index)",
		"shared sampling must update the requested color slot directly"
	)
	check_true(
		not ("assign_tool" in sampling),
		"temporary sampling must not switch or replace either selected tool"
	)
