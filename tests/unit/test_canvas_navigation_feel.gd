extends "res://tests/test_base.gd"

const ADAPTER := preload("res://src/InputAdapter/CanvasInputAdapter.gd")
const ADAPTER_SOURCE := "res://src/InputAdapter/CanvasInputAdapter.gd"


func test_navigation_dead_zones_are_small_and_independent() -> void:
	check_true(
		not ADAPTER.navigation_pan_exceeds_dead_zone(Vector2.ZERO, Vector2(0.5, 0.4)),
		"sub-pixel centroid jitter must stay below the pan acquisition threshold"
	)
	check_true(
		ADAPTER.navigation_pan_exceeds_dead_zone(Vector2.ZERO, Vector2(1.0, 0.0)),
		"a deliberate one-point pan must activate immediately"
	)
	check_true(
		not ADAPTER.navigation_pinch_exceeds_dead_zone(100.0, 100.4),
		"sub-half-percent distance jitter must not activate pinch"
	)
	check_true(
		ADAPTER.navigation_pinch_exceeds_dead_zone(100.0, 100.6),
		"a deliberate pinch above the small acquisition threshold must activate"
	)
	check_true(
		ADAPTER.navigation_pinch_exceeds_dead_zone(100.0, 99.4),
		"pinch-in must use the same multiplicative threshold as pinch-out"
	)


func test_navigation_zoom_uses_fixed_baseline_ratio_and_respects_limits() -> void:
	var continuous := ADAPTER.navigation_zoom_from_ratio(
		Vector2(2.0, 2.0), 1.5, false, Vector2(0.01, 0.01), Vector2(500.0, 500.0)
	)
	check_almost_eq(continuous.x, 3.0, 0.00001, "continuous pinch must be baseline zoom * ratio")
	check_almost_eq(continuous.y, 3.0, 0.00001, "zoom must remain uniform")

	var clamped := ADAPTER.navigation_zoom_from_ratio(
		Vector2(2.0, 2.0), 1000.0, false, Vector2(0.01, 0.01), Vector2(500.0, 500.0)
	)
	check_eq(clamped, Vector2(500.0, 500.0), "pinch must respect CanvasCamera max zoom")

	var integer := ADAPTER.navigation_zoom_from_ratio(
		Vector2(3.0, 3.0), 1.2, true, Vector2(0.01, 0.01), Vector2(500.0, 500.0)
	)
	check_eq(integer, Vector2(4.0, 4.0), "integer zoom preference must quantize direct pinch")


func test_combined_pan_and_pinch_preserve_the_pair_anchor() -> void:
	var viewport_size := Vector2(1024.0, 768.0)
	var baseline_centroid := Vector2(420.0, 300.0)
	var baseline_zoom := Vector2(2.0, 2.0)
	var baseline_offset := Vector2(64.0, 48.0)
	var camera_angle := 0.23
	var anchor := ADAPTER.screen_to_canvas_point(
		baseline_centroid, viewport_size, baseline_zoom, baseline_offset, camera_angle
	)

	var current_centroid := Vector2(486.0, 344.0)
	var target_zoom := ADAPTER.navigation_zoom_from_ratio(
		baseline_zoom, 1.35, false, Vector2(0.01, 0.01), Vector2(500.0, 500.0)
	)
	var target_offset := ADAPTER.navigation_offset_for_anchor(
		anchor, current_centroid, viewport_size, target_zoom, camera_angle
	)
	var round_trip := ADAPTER.screen_to_canvas_point(
		current_centroid, viewport_size, target_zoom, target_offset, camera_angle
	)
	check_true(
		round_trip.distance_to(anchor) < 0.0001,
		"combined pan+pinch must keep the original Canvas anchor under the current centroid"
	)


func test_twist_cannot_rotate_ipad_canvas() -> void:
	var src := FileAccess.get_file_as_string(ADAPTER_SOURCE)
	check_true(
		not ("two_finger_rotation_enabled" in src),
		"a saved rotation preference must not restore canvas rotation"
	)
	check_true(
		not ("TwoFingerRotationCheckBox" in src),
		"iPad preferences must not re-enable touch rotation"
	)
	var start := src.find("func _update_navigation()")
	var ending := src.find("func _navigation_geometry()", start)
	var update_code := src.substr(start, ending - start)
	check_true(
		not ("camera.camera_angle =" in update_code),
		"two-finger navigation must never rotate the canvas"
	)
	check_has(
		update_code,
		"_navigation_baseline_camera_angle",
		"pan and pinch must retain a fixed camera angle"
	)


func test_pan_and_pinch_keep_fixed_canvas_orientation() -> void:
	var viewport_size := Vector2(1024.0, 768.0)
	var centroid := Vector2(420.0, 300.0)
	var zoom := Vector2(2.0, 2.0)
	var offset := Vector2(64.0, 48.0)
	var baseline_angle := 0.23
	var anchor := ADAPTER.screen_to_canvas_point(
		centroid, viewport_size, zoom, offset, baseline_angle
	)
	var new_centroid := Vector2(486.0, 344.0)
	var target_zoom := ADAPTER.navigation_zoom_from_ratio(
		zoom, 1.35, false, Vector2(0.01, 0.01), Vector2(500.0, 500.0)
	)
	var new_offset := ADAPTER.navigation_offset_for_anchor(
		anchor, new_centroid, viewport_size, target_zoom, baseline_angle
	)
	var restored_anchor := ADAPTER.screen_to_canvas_point(
		new_centroid, viewport_size, target_zoom, new_offset, baseline_angle
	)
	check_true(
		restored_anchor.distance_to(anchor) < 0.0001,
		"pan and pinch must preserve the Canvas anchor without changing angle"
	)


func test_replacement_pair_resets_navigation_baseline() -> void:
	var adapter := ADAPTER.new()
	adapter._touches = {
		1: {"kind": ADAPTER.PointerKind.DIRECT, "position": Vector2.ZERO, "suppressed": false},
		2:
		{"kind": ADAPTER.PointerKind.DIRECT, "position": Vector2(10.0, 0.0), "suppressed": false},
		3:
		{"kind": ADAPTER.PointerKind.DIRECT, "position": Vector2(0.0, 20.0), "suppressed": false},
	}
	adapter._begin_navigation_pair(PackedInt32Array([1, 2]))
	adapter._navigation_pan_active = true
	adapter._navigation_pinch_active = true
	adapter._touches.erase(2)
	adapter._rebase_navigation()
	check_eq(
		adapter._navigation_ids,
		PackedInt32Array([1, 3]),
		"replacement must establish a new navigation pair"
	)
	check_true(not adapter._navigation_pan_active, "replacement must reset pan acquisition")
	check_true(not adapter._navigation_pinch_active, "replacement must reset pinch acquisition")
	check_almost_eq(
		adapter._navigation_baseline_distance,
		20.0,
		0.00001,
		"replacement must establish a fresh pair-distance baseline"
	)


func test_runtime_path_is_baseline_driven_and_has_no_touch_tween() -> void:
	var src := FileAccess.get_file_as_string(ADAPTER_SOURCE)
	check_has(src, "_navigation_anchor_canvas", "runtime must retain the fixed Canvas anchor")
	check_has(
		src,
		"navigation_offset_for_anchor",
		"runtime must solve camera offset from the pair anchor instead of accumulating deltas"
	)
	check_true(
		not ("centroid - _last_navigation_centroid" in src),
		"P1-C2 must not reintroduce previous-event pan accumulation"
	)
	check_true(
		not ("camera.zoom_camera(" in src),
		"continuous two-finger pinch must bypass Pixelorama's tweened wheel zoom path"
	)
	check_true(
		not ("Global.smooth_zoom" in src),
		"continuous touch navigation must not add preference-driven smoothing latency"
	)


func test_legacy_rotation_preference_is_not_read_or_exposed() -> void:
	var src := FileAccess.get_file_as_string(ADAPTER_SOURCE)
	check_true(
		not ("TWO_FINGER_ROTATION_KEY" in src),
		"obsolete saved rotation preference must not affect iPad navigation"
	)
	check_true(
		not ("_install_two_finger_rotation_preference" in src),
		"disabled rotation must not be exposed as a user setting"
	)
	check_has(
		src,
		"_install_finger_policy_preference(options)",
		"finger drawing policy must remain available"
	)
