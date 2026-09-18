extends "res://tests/test_base.gd"

const ADAPTER := preload("res://src/InputAdapter/CanvasInputAdapter.gd")
const ADAPTER_SOURCE := "res://src/InputAdapter/CanvasInputAdapter.gd"
const TOOL_BUTTONS := preload("res://src/UI/ToolsPanel/ToolButtons.gd")
const TOOL_BUTTONS_SOURCE := "res://src/UI/ToolsPanel/ToolButtons.gd"
const TOOLS_SOURCE := "res://src/Autoload/Tools.gd"
const COLOR_PICKER_SOURCE := "res://src/Tools/UtilityTools/ColorPicker.gd"
const COLOR_SAMPLING_SOURCE := "res://src/Tools/UtilityTools/ColorSampling.gd"
const UI_COLOR_PICKER_SOURCE := "res://src/UI/ColorPickers/ColorPicker.gd"
const CURVE_TOOL_SOURCE := "res://src/Tools/DesignTools/CurveTool.gd"


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
		"_sample_active_color(canvas, current, COLOR_SAMPLING.TOP_COLOR)",
		"long press must sample without temporarily switching the selected tool"
	)
	check_true(
		not ("undo_redo.undo" in src),
		"long-press disambiguation must not mutate first and repair the result through Undo"
	)


func test_pending_long_press_hides_normal_pixel_preview() -> void:
	var src := FileAccess.get_file_as_string(ADAPTER_SOURCE)
	var start_pending := src.find("func _start_pending_content")
	var start_timeout := src.find("func _try_begin_long_press", start_pending)
	check_true(
		start_pending >= 0 and start_timeout > start_pending, "adapter must expose pending content"
	)
	if start_pending >= 0 and start_timeout > start_pending:
		var body := src.substr(start_pending, start_timeout - start_pending)
		check_has(
			body,
			"canvas.set_adapter_tool_preview_active(false)",
			"pending/long-press acquisition must not leave the last drawing-cell preview visible"
		)
		check_true(
			not ("set_adapter_tool_preview_active(true)" in body),
			"normal pixel preview must start only after the gesture commits to drawing"
		)


func test_long_press_targets_the_selected_color_slot() -> void:
	var src := FileAccess.get_file_as_string(ADAPTER_SOURCE)
	check_has(
		src,
		"var target_button := Tools.picking_color_for",
		"temporary picking must follow the color slot selected in the color UI"
	)
	check_has(
		src,
		"COLOR_SAMPLING.pick_color(Vector2i(canvas_position.floor()), target_button, mode)",
		"the selected left/right target must reach the shared sampler explicitly"
	)
	check_true(
		not ("func _sample_primary_color" in src),
		"temporary picking must not have a Primary-only sampling path"
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
			"_sample_active_color(canvas, screen_position, COLOR_SAMPLING.TOP_COLOR)",
			"long-press release must sample the final lift position even without a final drag event"
		)


func test_tool_buttons_keep_touch_ownership_and_suppress_pointer_drag_preview() -> void:
	var src := FileAccess.get_file_as_string(TOOL_BUTTONS_SOURCE)
	check_has(src, "InputEventScreenTouch", "tool selection must consume direct touch")
	check_has(src, "InputEventScreenDrag", "tool taps must cancel when the finger drags away")
	check_has(
		src,
		'"cancelled": false',
		"a tool touch must keep explicit ownership until its matching release"
	)
	check_has(
		src,
		'candidate["cancelled"] = true',
		"dragging beyond tap slop must cancel selection without dropping touch ownership"
	)
	check_has(src, "get_viewport().gui_cancel_drag()", "touch must cancel any legacy GUI drag")
	check_has(
		src,
		"Global.canvas.set_adapter_tool_preview_active(false)",
		"touching the palette must hide Pixelorama's selected-tool pointer icon"
	)
	check_has(
		src,
		"TOUCH_FILTER_META",
		"touch mode must preserve and suppress nested Control mouse filters"
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


func test_adaptive_tool_grid_rejects_clipped_hits_and_defers_activation() -> void:
	var src := FileAccess.get_file_as_string(TOOL_BUTTONS_SOURCE)
	check_has(
		src,
		"_get_tools_scroll_container()",
		"adaptive Tools hit testing must know the visible ScrollContainer viewport"
	)
	check_has(
		src,
		"scroll_container.get_global_rect().has_point(screen_position)",
		"touches outside the visible Tools viewport must be rejected"
	)
	check_has(
		src,
		"visible_rect = visible_rect.intersection(scroll_container.get_global_rect())",
		"clipped/offscreen tool buttons must not remain touch targets"
	)
	check_has(
		src,
		'call_deferred(\n\t\t"_commit_touch_tool_activation"',
		"tool replacement must wait until the current ScreenTouch dispatch finishes"
	)
	check_has(
		src,
		"generation != _ios_selection_touch_generation",
		"stale deferred tool activations must not survive a newer touch"
	)


func test_curve_tool_clears_multistep_state_before_generic_exit_cleanup() -> void:
	var src := FileAccess.get_file_as_string(CURVE_TOOL_SOURCE)
	var exit_pos := src.find("func _exit_tree() -> void:")
	var cancel_pos := src.find("cancel_tool()", exit_pos)
	var super_pos := src.find("super()", cancel_pos)
	check_true(exit_pos >= 0, "Curve Tool needs explicit exit cleanup")
	check_true(
		cancel_pos > exit_pos,
		"Curve Tool must cancel its partially constructed curve before leaving the tree"
	)
	check_true(
		super_pos > cancel_pos,
		"generic BaseDrawTool exit cleanup must run only after Curve state is cleared"
	)


func test_adaptive_tool_grid_hit_math_rejects_clipped_and_blank_regions() -> void:
	var viewport := Rect2(100.0, 100.0, 120.0, 120.0)
	check_true(
		TOOL_BUTTONS.is_visible_tool_touch(
			Rect2(110.0, 110.0, 24.0, 24.0), viewport, Vector2(120.0, 120.0)
		),
		"fully visible tool buttons must remain tappable"
	)
	check_true(
		not TOOL_BUTTONS.is_visible_tool_touch(
			Rect2(110.0, 230.0, 24.0, 24.0), viewport, Vector2(120.0, 235.0)
		),
		"a button below the ScrollContainer viewport must not be tappable through clipping"
	)
	check_true(
		not TOOL_BUTTONS.is_visible_tool_touch(
			Rect2(205.0, 205.0, 24.0, 24.0), viewport, Vector2(224.0, 224.0)
		),
		"the clipped portion of a partially visible button must not remain a touch target"
	)
	check_true(
		not TOOL_BUTTONS.is_visible_tool_touch(
			Rect2(110.0, 110.0, 24.0, 24.0), viewport, Vector2(160.0, 160.0)
		),
		"blank HFlow space between visible tool buttons must not activate a tool"
	)


func test_tool_replacement_cancels_any_active_stroke_before_freeing_nodes() -> void:
	var src := FileAccess.get_file_as_string(TOOLS_SOURCE)
	var assign_pos := src.find("func assign_tool(")
	var set_tool_pos := src.find("func set_tool(", assign_pos + 1)
	check_true(assign_pos >= 0, "Tools must expose assign_tool")
	if assign_pos < 0:
		return
	var body := src.substr(assign_pos, set_tool_pos - assign_pos if set_tool_pos > assign_pos else 2400)
	check_has(
		body,
		"if not tools.has(tool_name) or not _slots.has(button) or not _panels.has(button):",
		"stale or invalid palette targets must be rejected before replacing a tool"
	)
	check_has(
		body,
		"active_slot.tool_node.cancel_tool()",
		"switching tools must explicitly cancel an active canvas interaction"
	)
	var cancel_pos := body.find("active_slot.tool_node.cancel_tool()")
	var remove_pos := body.find("panel.remove_child(slot.tool_node)")
	check_true(
		cancel_pos >= 0 and remove_pos > cancel_pos,
		"active interaction cancellation must happen before the old Tool Options node is detached"
	)


func test_color_picker_and_long_press_share_sampling_model() -> void:
	var picker := FileAccess.get_file_as_string(COLOR_PICKER_SOURCE)
	var sampling := FileAccess.get_file_as_string(COLOR_SAMPLING_SOURCE)
	check_has(
		picker,
		"COLOR_SAMPLING.pick_color(pos, button, _mode)",
		"normal Color Picker must keep the shared sampler for legacy pointer/Pencil input"
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


func test_direct_touch_color_picker_follows_active_color_slot() -> void:
	var src := FileAccess.get_file_as_string(ADAPTER_SOURCE)
	check_has(
		src,
		'_primary_tool_name() == &"ColorPicker"',
		"the selected Color Picker needs a direct-touch sampling path on iPad"
	)
	check_has(
		src,
		"_start_direct_color_pick",
		"Color Picker Tap/Drag must bypass mouse-button assumptions on direct touch"
	)
	check_has(
		src,
		"_primary_color_picker_mode()",
		"direct touch must preserve the Color Picker tool's extraction mode"
	)
	check_has(
		src,
		"var target_button := Tools.picking_color_for",
		"direct touch must update whichever left/right color slot is selected"
	)


func test_ios_screen_sampler_uses_canvas_sampling_instead_of_godot_screen_capture() -> void:
	var ui_src := FileAccess.get_file_as_string(UI_COLOR_PICKER_SOURCE)
	var adapter_src := FileAccess.get_file_as_string(ADAPTER_SOURCE)
	check_has(
		ui_src,
		'get_signal_connection_list(&"pressed")',
		"iOS must replace the built-in ColorPicker screen-sampler callback"
	)
	check_has(
		ui_src,
		"CanvasInputAdapter.request_touch_color_sample()",
		"the existing sampler button must arm one-shot Phosprite canvas sampling"
	)
	check_has(
		adapter_src,
		"_touch_color_sampler_requested",
		"the adapter must own the one-shot sampler state instead of DisplayServer screen pixels"
	)
	check_has(
		adapter_src,
		'"one_shot_color_pick": false',
		"one-shot sampling must be explicit touch state and disarm after the contact"
	)
	check_has(
		ui_src,
		"TOUCH_TOOLTIP_META",
		"left/right color controls and the sampler need touch-specific tooltip cleanup"
	)
	check_has(
		ui_src,
		'control.tooltip_text = ""',
		"touching color controls must not leave delayed desktop tooltips behind"
	)
