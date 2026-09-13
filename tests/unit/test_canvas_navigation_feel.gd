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


func test_rotation_plumbing_exists_but_stays_disabled_by_default() -> void:
	check_true(
		not ADAPTER.TWO_FINGER_ROTATION_ENABLED,
		"P1-C2 must not enable two-finger rotation in production"
	)
	var geometry := ADAPTER.navigation_pair_geometry(Vector2.ZERO, Vector2.RIGHT)
	check_almost_eq(float(geometry["angle"]), 0.0, 0.00001, "pair geometry must expose angle")
	var disabled_target := ADAPTER.navigation_target_angle(0.25, 0.0, PI / 3.0, false)
	check_almost_eq(
		disabled_target, 0.25, 0.00001, "disabled rotation must preserve the camera baseline angle"
	)
	var enabled_target := ADAPTER.navigation_target_angle(0.25, 0.0, PI / 3.0, true)
	check_almost_eq(
		enabled_target,
		0.25 + PI / 3.0,
		0.00001,
		"the reserved rotation degree of freedom must follow pair-angle delta when enabled"
	)


func test_replacement_pair_resets_c2_activation_state() -> void:
	var adapter := ADAPTER.new()
	adapter._touches = {
		1: {"kind": ADAPTER.PointerKind.DIRECT, "position": Vector2.ZERO, "suppressed": false},
		2:
		{"kind": ADAPTER.PointerKind.DIRECT, "position": Vector2(10.0, 0.0), "suppressed": false},
		3:
		{"kind": ADAPTER.PointerKind.DIRECT, "position": Vector2(20.0, 0.0), "suppressed": false},
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
