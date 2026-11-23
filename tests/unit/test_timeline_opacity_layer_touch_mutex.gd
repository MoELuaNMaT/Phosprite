extends "res://tests/test_base.gd"

const ADAPTER_SCRIPT := preload("res://src/UI/Timeline/LayerTouchAdapter.gd")


class FakeTimeline:
	extends Panel
	var timeline_scroll: ScrollContainer
	var opacity_slider: ValueSlider
	var layer_header_container: Control


func test_layer_touch_adapter_clips_to_timeline_scroll_and_yields_to_opacity_slider() -> void:
	var src := FileAccess.get_file_as_string("res://src/UI/Timeline/LayerTouchAdapter.gd")
	check_has(
		src,
		"if _is_blocked_by_header_or_slider(event.position):",
		"LayerTouchAdapter rejects touches on OpacitySlider or LayerHeaderContainer",
	)
	check_has(
		src,
		"if not _is_touch_inside_visible_layer_row(event.position):",
		"LayerTouchAdapter clips hit-testing to visible TimelineScroll bounds",
	)
	check_has(
		src,
		"if _is_opacity_slider_active():",
		"LayerTouchAdapter cancels drag candidate while OpacitySlider is sliding",
	)

	var tsm_src := FileAccess.get_file_as_string(
		"res://src/UI/Timeline/TimelineTouchSelectionManager.gd"
	)
	check_has(
		tsm_src,
		"if not is_instance_valid(_timeline) or _is_blocked_by_opacity_or_header(screen_position):",
		"TimelineTouchSelectionManager yields to OpacitySlider and LayerHeaderContainer",
	)

	var original_timeline := Global.animation_timeline
	var fake_timeline := FakeTimeline.new()
	fake_timeline.size = Vector2(400.0, 220.0)
	tree.root.add_child(fake_timeline)

	var header := Control.new()
	header.position = Vector2(0.0, 0.0)
	header.size = Vector2(200.0, 38.0)
	fake_timeline.add_child(header)
	var slider := ValueSlider.new()
	slider.position = Vector2(4.0, 4.0)
	slider.size = Vector2(180.0, 29.0)
	header.add_child(slider)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0.0, 38.0)
	scroll.size = Vector2(200.0, 120.0)
	fake_timeline.add_child(scroll)

	var main_btn := Button.new()
	main_btn.position = Vector2(0.0, 10.0)
	main_btn.size = Vector2(200.0, 40.0)
	fake_timeline.add_child(main_btn)

	fake_timeline.timeline_scroll = scroll
	fake_timeline.opacity_slider = slider
	fake_timeline.layer_header_container = header
	Global.animation_timeline = fake_timeline

	var adapter := ADAPTER_SCRIPT.new()
	adapter._main_button = main_btn
	fake_timeline.add_child(adapter)

	check_true(
		adapter._is_blocked_by_header_or_slider(Vector2(60.0, 18.0)),
		"touch directly on OpacitySlider is blocked",
	)
	check_true(
		not adapter._is_touch_inside_visible_layer_row(Vector2(60.0, 18.0)),
		"scrolled-out portion of layer row above TimelineScroll is clipped out",
	)
	check_true(
		adapter._is_touch_inside_visible_layer_row(Vector2(60.0, 45.0)),
		"visible portion of layer row inside TimelineScroll remains hittable",
	)
	slider.state = ValueSlider.SLIDING
	check_true(
		adapter._is_blocked_by_header_or_slider(Vector2(60.0, 45.0)),
		"active OpacitySlider drag blocks layer row touch even below header",
	)

	Global.animation_timeline = original_timeline
	fake_timeline.queue_free()
