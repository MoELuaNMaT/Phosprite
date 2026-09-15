extends "res://tests/test_base.gd"

const CONFIG := preload("res://src/InputAdapter/TouchGestureConfig.gd")
const RECOGNIZER := preload("res://src/InputAdapter/TouchGestureRecognizer.gd")
const OWNERSHIP := preload("res://src/InputAdapter/TouchPointerOwnership.gd")


func test_default_thresholds_are_centralized_and_copyable() -> void:
	var config := CONFIG.new()
	check_almost_eq(
		config.tap_slop_px, 12.0, 0.00001, "tap slop must use the D0 provisional default"
	)
	check_almost_eq(
		config.drag_threshold_px,
		12.0,
		0.00001,
		"drag acquisition must use the D0 provisional default"
	)
	check_eq(config.long_press_duration_msec, 450, "long press must use the D0 provisional default")
	check_eq(config.double_tap_interval_msec, 300, "double tap interval must be centralized")
	check_almost_eq(
		config.double_tap_distance_px, 20.0, 0.00001, "double tap distance must be centralized"
	)

	var copy := config.duplicate_config()
	copy.tap_slop_px = 7.0
	check_almost_eq(
		config.tap_slop_px, 12.0, 0.00001, "runtime tuning copies must not mutate shared defaults"
	)
	check_almost_eq(copy.tap_slop_px, 7.0, 0.00001, "runtime tuning copies must remain editable")


func test_single_tap_waits_for_double_tap_window_before_commit() -> void:
	var recognizer := RECOGNIZER.new()
	check_eq(
		recognizer.begin(1, Vector2(20, 30), 0).size(), 0, "touch begin must not commit a gesture"
	)
	check_eq(
		recognizer.release(1, Vector2(25, 32), 100).size(),
		0,
		"first tap must wait for double-tap disambiguation"
	)
	check_true(
		recognizer.has_pending_tap(), "first tap must remain pending inside the double-tap window"
	)
	check_eq(
		recognizer.advance_time(400).size(),
		0,
		"tap stays pending through the configured interval boundary"
	)
	var events := recognizer.advance_time(401)
	check_eq(events.size(), 1, "expired double-tap window must commit exactly one tap")
	check_eq(events[0]["gesture"], RECOGNIZER.Gesture.TAP, "expired candidate must become TAP")
	check_eq(events[0]["position"], Vector2(25, 32), "tap must retain its release position")
	check_true(not recognizer.has_pending_tap(), "committed tap must clear the pending candidate")


func test_drag_acquisition_cancels_tap_and_has_explicit_lifecycle() -> void:
	var recognizer := RECOGNIZER.new()
	recognizer.begin(3, Vector2.ZERO, 0)
	check_eq(
		recognizer.move(3, Vector2(6, 2), 10).size(),
		0,
		"sub-threshold movement must remain undecided"
	)
	var start_events := recognizer.move(3, Vector2(12, 0), 20)
	check_eq(start_events.size(), 1, "crossing drag threshold must emit one acquisition event")
	check_eq(
		start_events[0]["gesture"],
		RECOGNIZER.Gesture.DRAG_START,
		"threshold crossing must emit DRAG_START"
	)
	check_true(recognizer.is_dragging(3), "pointer must stay in dragging state after acquisition")
	var update_events := recognizer.move(3, Vector2(18, 4), 30)
	check_eq(update_events.size(), 1, "subsequent drag motion must emit one update")
	check_eq(
		update_events[0]["gesture"],
		RECOGNIZER.Gesture.DRAG_UPDATE,
		"active drag must emit DRAG_UPDATE"
	)
	var end_events := recognizer.release(3, Vector2(20, 5), 40)
	check_eq(end_events.size(), 1, "drag release must emit one end event")
	check_eq(
		end_events[0]["gesture"], RECOGNIZER.Gesture.DRAG_END, "drag release must emit DRAG_END"
	)
	check_true(not recognizer.is_tracking(3), "drag release must clear pointer state")
	check_true(not recognizer.has_pending_tap(), "a drag must never leave a delayed tap behind")


func test_motion_past_tap_slop_without_drag_is_not_reinterpreted_as_tap() -> void:
	var config := CONFIG.new()
	config.tap_slop_px = 10.0
	config.drag_threshold_px = 20.0
	var recognizer := RECOGNIZER.new(config)
	recognizer.begin(4, Vector2.ZERO, 0)
	check_eq(
		recognizer.move(4, Vector2(15, 0), 100).size(),
		0,
		"mid-band movement must not fabricate a drag"
	)
	check_eq(
		recognizer.advance_time(500).size(), 0, "movement past tap slop must invalidate long press"
	)
	check_eq(
		recognizer.release(4, Vector2(15, 0), 550).size(),
		0,
		"invalidated contact must not become a tap"
	)
	check_true(not recognizer.has_pending_tap(), "invalidated contact must leave no pending tap")


func test_long_press_fires_once_and_release_does_not_also_tap() -> void:
	var recognizer := RECOGNIZER.new()
	recognizer.begin(5, Vector2(40, 40), 0)
	check_eq(
		recognizer.advance_time(449).size(), 0, "long press must not fire before its threshold"
	)
	var hold_events := recognizer.advance_time(450)
	check_eq(hold_events.size(), 1, "long press threshold must emit exactly one event")
	check_eq(hold_events[0]["gesture"], RECOGNIZER.Gesture.LONG_PRESS, "hold must emit LONG_PRESS")
	check_eq(recognizer.advance_time(700).size(), 0, "long press must not repeat while still held")
	check_eq(
		recognizer.release(5, Vector2(40, 40), 800).size(),
		0,
		"releasing long press must not emit a tap"
	)
	check_true(
		not recognizer.has_pending_tap(), "long press release must not create a tap candidate"
	)


func test_fast_nearby_taps_commit_one_double_tap_without_single_taps() -> void:
	var recognizer := RECOGNIZER.new()
	recognizer.begin(1, Vector2(100, 100), 0)
	recognizer.release(1, Vector2(100, 100), 40)
	recognizer.begin(2, Vector2(108, 105), 120)
	var events := recognizer.release(2, Vector2(108, 105), 160)
	check_eq(events.size(), 1, "second qualifying tap must resolve the pending pair immediately")
	check_eq(
		events[0]["gesture"], RECOGNIZER.Gesture.DOUBLE_TAP, "qualifying pair must emit DOUBLE_TAP"
	)
	check_true(not recognizer.has_pending_tap(), "double tap must consume the pending first tap")
	check_eq(
		recognizer.advance_time(1000).size(), 0, "double tap must not leak a delayed single tap"
	)


func test_cancel_all_clears_active_contacts_and_delayed_actions() -> void:
	var recognizer := RECOGNIZER.new()
	recognizer.begin(7, Vector2.ZERO, 0)
	recognizer.release(7, Vector2.ZERO, 20)
	recognizer.begin(8, Vector2.ONE, 30)
	recognizer.begin(9, Vector2(2, 2), 40)
	check_true(recognizer.has_pending_tap(), "setup must contain a delayed tap")
	var events := recognizer.cancel_all(50)
	check_eq(events.size(), 2, "cancel-all must cancel every active contact")
	check_eq(
		events[0]["gesture"], RECOGNIZER.Gesture.CANCEL, "first active contact must be cancelled"
	)
	check_eq(
		events[1]["gesture"], RECOGNIZER.Gesture.CANCEL, "second active contact must be cancelled"
	)
	check_eq(recognizer.active_pointer_count(), 0, "cancel-all must clear active pointer state")
	check_true(not recognizer.has_pending_tap(), "cancel-all must discard delayed tap state")
	check_eq(recognizer.advance_time(1000).size(), 0, "cancelled delayed tap must never fire later")


func test_pointer_ownership_is_exclusive_and_releasable_by_owner() -> void:
	var ownership := OWNERSHIP.new()
	check_true(ownership.acquire(1, &"LayerPanel"), "first owner must acquire an unowned pointer")
	check_true(ownership.acquire(1, &"LayerPanel"), "same-owner acquisition must be idempotent")
	check_true(
		not ownership.acquire(1, &"Canvas"), "a competing owner must not steal an acquired pointer"
	)
	check_eq(ownership.owner_of(1), &"LayerPanel", "registry must report the authoritative owner")
	check_true(
		not ownership.release(1, &"Canvas"),
		"wrong owner must not release another surface's pointer"
	)
	check_true(
		ownership.release(1, &"LayerPanel"),
		"authoritative owner must be able to release its pointer"
	)
	check_true(not ownership.is_owned(1), "released pointer must become unowned")

	ownership.acquire(4, &"Palette")
	ownership.acquire(2, &"Palette")
	ownership.acquire(3, &"Canvas")
	check_eq(
		ownership.cancel_owner(&"Palette"),
		PackedInt32Array([2, 4]),
		"owner teardown must release all of its pointers deterministically"
	)
	check_true(ownership.is_owned_by(3, &"Canvas"), "cancelling one owner must not disturb another")
	var snapshot := ownership.cancel_all()
	check_eq(snapshot.size(), 1, "global interruption must return remaining ownership snapshot")
	check_eq(
		snapshot.get(3, &""),
		&"Canvas",
		"snapshot must preserve the previous owner for cancellation routing"
	)
	check_eq(ownership.active_count(), 0, "global interruption must clear all ownership")
