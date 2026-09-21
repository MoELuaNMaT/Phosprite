extends "res://tests/test_base.gd"

const ADAPTER := preload("res://src/InputAdapter/CanvasInputAdapter.gd")
const ADAPTER_SOURCE := "res://src/InputAdapter/CanvasInputAdapter.gd"
const CANVAS_SOURCE := "res://src/UI/Canvas/Canvas.gd"
const CAMERA_SOURCE := "res://src/UI/Canvas/CanvasCamera.gd"
const INDICATORS_SOURCE := "res://src/UI/Canvas/Indicators.gd"
const IOS_WORKFLOW_SOURCE := "res://.github/workflows/ios-build.yml"
const NATIVE_SOURCE := "res://ios/pointer_identity_src/phosprite_pointer_identity.mm"
const NATIVE_HEADER := "res://ios/pointer_identity_src/phosprite_pointer_identity.h"
const GDIP_SOURCE := "res://ios/pointer_identity_src/PhospritePointerIdentity.gdip"


func test_pencil_priority_is_default_policy() -> void:
	check_eq(
		ADAPTER.DEFAULT_FINGER_POLICY,
		ADAPTER.FingerPolicy.PENCIL_PRIORITY,
		"Pencil Priority must be the P1-B default"
	)


func test_direct_content_policy_matrix() -> void:
	check_true(
		ADAPTER.direct_content_allowed(ADAPTER.FingerPolicy.UNRESTRICTED, false),
		"unrestricted mode must allow finger content when Pencil is inactive"
	)
	check_true(
		not ADAPTER.direct_content_allowed(ADAPTER.FingerPolicy.FINGER_NAVIGATION_ONLY, false),
		"navigation-only mode must never let direct touch edit content"
	)
	check_true(
		ADAPTER.direct_content_allowed(ADAPTER.FingerPolicy.PENCIL_PRIORITY, false),
		"Pencil Priority must allow finger content while Pencil does not own content"
	)
	check_true(
		not ADAPTER.direct_content_allowed(ADAPTER.FingerPolicy.PENCIL_PRIORITY, true),
		"active Pencil ownership must suppress direct content in Pencil Priority"
	)
	check_true(
		not ADAPTER.direct_content_allowed(ADAPTER.FingerPolicy.UNRESTRICTED, true),
		"active Pencil ownership must suppress direct content even in unrestricted mode"
	)


func test_direct_content_can_upgrade_to_two_finger_navigation() -> void:
	check_true(
		ADAPTER.direct_content_navigation_takeover_allowed(
			ADAPTER.PointerKind.DIRECT, false, false, 2
		),
		"a direct-touch content stroke must yield to a newly formed two-finger pair"
	)
	check_true(
		not ADAPTER.direct_content_navigation_takeover_allowed(
			ADAPTER.PointerKind.DIRECT, false, false, 1
		),
		"one direct touch alone must stay content instead of self-promoting to navigation"
	)
	check_true(
		not ADAPTER.direct_content_navigation_takeover_allowed(
			ADAPTER.PointerKind.PENCIL, false, false, 2
		),
		"Pencil content must never be promoted into a finger navigation pair"
	)
	check_true(
		not ADAPTER.direct_content_navigation_takeover_allowed(
			ADAPTER.PointerKind.DIRECT, true, false, 2
		),
		"active Pencil ownership must block direct-touch navigation takeover"
	)
	check_true(
		not ADAPTER.direct_content_navigation_takeover_allowed(
			ADAPTER.PointerKind.DIRECT, false, true, 3
		),
		"an existing navigation pair must not be replaced by an additional finger"
	)


func test_viewport_bounds_use_local_subviewport_coordinates() -> void:
	check_true(
		ADAPTER.viewport_position_inside_size(Vector2.ZERO, Vector2(980, 700)),
		"the top-left SubViewport pixel must remain a valid canvas input position",
	)
	check_true(
		ADAPTER.viewport_position_inside_size(Vector2(979, 699), Vector2(980, 700)),
		"the final visible SubViewport pixel must remain addressable",
	)
	check_true(
		not ADAPTER.viewport_position_inside_size(Vector2(20, -1), Vector2(980, 700)),
		"negative local Y must be rejected instead of compensating for editor chrome",
	)


func test_adapter_does_not_subtract_editor_origin_from_ios_input() -> void:
	var adapter := FileAccess.get_file_as_string(ADAPTER_SOURCE)
	var canvas := FileAccess.get_file_as_string(CANVAS_SOURCE)
	check_true(
		not adapter.contains("screen_to_viewport_point"),
		"iOS Canvas events are already SubViewport-local and must not subtract the toolbar origin",
	)
	check_true(
		not adapter.contains("main_viewport_position"),
		"all adapter coordinate consumers must use the event's SubViewport-local position directly",
	)
	check_has(
		adapter,
		"viewport_position_inside_size(viewport_position, Global.main_viewport.size)",
		"canvas acquisition must use a zero-origin local SubViewport rectangle",
	)
	check_has(
		canvas,
		"func handle_adapter_tool_event(viewport_position: Vector2, event: InputEvent) -> void:",
		"tool dispatch must accept the already-local SubViewport coordinate",
	)


func test_navigation_pair_geometry_uses_centroid_and_distance() -> void:
	var geometry := ADAPTER.navigation_pair_geometry(Vector2.ZERO, Vector2(6, 8))
	check_eq(geometry["centroid"], Vector2(3, 4), "pair centroid must be the two-touch midpoint")
	check_eq(geometry["distance"], 10.0, "pair distance must be measured between both touches")


func test_navigation_pair_baseline_is_pair_scoped_and_rebased_on_replacement() -> void:
	var adapter := ADAPTER.new()
	adapter._touches = {
		1: {"kind": ADAPTER.PointerKind.DIRECT, "position": Vector2.ZERO, "suppressed": false},
		2: {"kind": ADAPTER.PointerKind.DIRECT, "position": Vector2(6, 8), "suppressed": false},
		3: {"kind": ADAPTER.PointerKind.DIRECT, "position": Vector2(8, 0), "suppressed": false},
	}
	adapter._begin_navigation_pair(PackedInt32Array([1, 2]))
	check_eq(
		adapter._navigation_baseline_centroid,
		Vector2(3, 4),
		"a new pair must capture its own centroid baseline"
	)
	check_eq(
		adapter._navigation_baseline_distance,
		10.0,
		"a new pair must capture its own distance baseline"
	)

	var first_state: Dictionary = adapter._touches[1]
	first_state["position"] = Vector2(2, 0)
	adapter._touches[1] = first_state
	adapter._rebase_navigation()
	check_eq(
		adapter._navigation_baseline_centroid,
		Vector2(3, 4),
		"the same active pair must keep its original pair-level baseline"
	)
	check_eq(
		adapter._navigation_baseline_distance,
		10.0,
		"moving the same pair must not silently redefine its baseline"
	)

	adapter._touches.erase(2)
	adapter._rebase_navigation()
	check_eq(
		adapter._navigation_ids,
		PackedInt32Array([1, 3]),
		"a waiting direct touch may replace a released pair member"
	)
	check_eq(
		adapter._navigation_baseline_centroid,
		Vector2(5, 0),
		"a replacement pair must establish a fresh centroid baseline"
	)
	check_eq(
		adapter._navigation_baseline_distance,
		6.0,
		"a replacement pair must establish a fresh distance baseline"
	)
	check_eq(
		adapter._last_navigation_centroid,
		adapter._navigation_baseline_centroid,
		"replacement must begin with zero navigation delta"
	)
	check_eq(
		adapter._last_navigation_distance,
		adapter._navigation_baseline_distance,
		"replacement must begin with zero scale delta"
	)


func test_adapter_owns_ios_touch_and_multitouch_navigation() -> void:
	var src := FileAccess.get_file_as_string(ADAPTER_SOURCE)
	check_has(src, "InputEventScreenTouch", "adapter must consume raw iOS touch begin/end")
	check_has(src, "InputEventScreenDrag", "adapter must consume raw iOS touch movement")
	check_has(src, "_try_begin_navigation", "adapter must arbitrate two-finger navigation")
	check_has(
		src,
		"_try_promote_direct_content_to_navigation",
		"a second direct touch must be able to upgrade direct content into navigation"
	)
	check_has(src, "_begin_navigation_pair", "navigation must have an explicit pair lifecycle")
	check_has(
		src,
		"_navigation_baseline_centroid",
		"navigation must retain a pair-level centroid baseline"
	)
	check_has(
		src,
		"_navigation_baseline_distance",
		"navigation must retain a pair-level distance baseline"
	)
	check_has(src, "_begin_pencil_ownership", "adapter must give Pencil explicit canvas ownership")
	check_has(
		src,
		"_suppress_direct_touches_until_release",
		"Pencil takeover must suppress held direct touches until their release"
	)
	check_has(
		src,
		"_pencil_touch_id != -1 or _content_touch_id != -1 or _navigation_ids.size() == 2",
		"new navigation acquisition must not coexist with Pencil, content or an existing pair"
	)
	check_has(
		src,
		'state["suppressed"] = true',
		"direct touches beginning during Pencil ownership must stay suppressed"
	)
	check_has(
		src,
		"Once a navigation pair owns the canvas, additional fingers stay unowned.",
		"an additional finger must not steal content ownership from an active pair"
	)
	check_has(
		src,
		"return event.device == -1",
		"Canvas must filter Godot DEVICE_ID_EMULATION touch-to-mouse duplicates"
	)


func test_touch_tool_preview_follows_content_ownership_lifecycle() -> void:
	var adapter := FileAccess.get_file_as_string(ADAPTER_SOURCE)
	var canvas := FileAccess.get_file_as_string(CANVAS_SOURCE)
	var indicators := FileAccess.get_file_as_string(INDICATORS_SOURCE)

	check_has(
		adapter,
		"canvas.set_adapter_tool_preview_active(true)",
		"touch content begin must explicitly show the tool preview"
	)
	check_has(
		adapter,
		"canvas.set_adapter_tool_preview_active(false)",
		"touch content end/reset must explicitly hide the tool preview"
	)
	check_has(
		canvas,
		"func should_draw_tool_indicator() -> bool:",
		"Canvas must expose the touch-aware indicator visibility contract"
	)
	check_has(
		canvas,
		"_sync_tool_cursor_visibility(active)",
		"the same touch lifecycle must drive the floating tool icon visibility"
	)
	check_has(
		indicators,
		"canvas.should_draw_tool_indicator()",
		"the blue pixel indicator must stop drawing after touch content ends"
	)


func test_physical_pointer_can_restore_legacy_hover_preview() -> void:
	var canvas := FileAccess.get_file_as_string(CANVAS_SOURCE)
	check_has(
		canvas,
		"event.device != -1",
		"touch-emulated mouse must not restore the PC-style hover preview"
	)
	check_has(
		canvas,
		"activate_legacy_pointer_preview()",
		"a physical mouse/trackpad event must be able to restore legacy hover semantics"
	)


func test_pointer_identity_never_uses_pressure_tilt_or_contact_radius() -> void:
	var src := FileAccess.get_file_as_string(ADAPTER_SOURCE)
	check_true(
		not ("PALM_RADIUS_HINT" in src),
		"contact radius must not classify or reject a direct touch in production arbitration"
	)
	check_true(
		not ("major_radius" in src),
		"UIKit contact radius metadata must not participate in Canvas arbitration"
	)
	check_true(
		not ("_drag_looks_like_pencil" in src),
		"drag pressure/tilt must never reclassify a touch as Pencil"
	)
	check_true(
		not ("identity_verified" in src),
		"adapter must not retain a heuristic identity fallback path"
	)
	check_has(
		src,
		"Pointer identity is decided only at touch begin by the native UITouch.type bridge.",
		"the formal pointer identity boundary must remain explicit"
	)


func test_existing_tools_remain_behind_canvas_adapter_boundary() -> void:
	var canvas := FileAccess.get_file_as_string(CANVAS_SOURCE)
	var camera := FileAccess.get_file_as_string(CAMERA_SOURCE)
	check_has(
		canvas, "_input_adapter.handle_event(self, event)", "Canvas must route iOS input first"
	)
	check_has(
		canvas,
		"Tools.handle_draw(pixel, event)",
		"normalized input must still execute through existing Pixelorama tools"
	)
	check_has(
		camera,
		'OS.get_name() == "iOS"',
		"legacy CanvasCamera gesture handling must be gated on iOS"
	)
	check_has(camera, "InputEventScreenDrag", "raw iOS touch must not double-route through camera")


func test_raw_ios_events_are_consumed_before_visual_cursor_update() -> void:
	var canvas := FileAccess.get_file_as_string(CANVAS_SOURCE)
	var adapter := FileAccess.get_file_as_string(ADAPTER_SOURCE)
	var adapter_route := canvas.find("_input_adapter.handle_event(self, event)")
	var cursor_update := canvas.find("current_pixel = get_local_mouse_position()")
	check_true(adapter_route >= 0, "Canvas must expose the adapter route")
	check_true(cursor_update >= 0, "Canvas must expose the legacy visual cursor update")
	check_true(
		adapter_route < cursor_update,
		"raw iOS touch/gesture must be consumed before legacy visual cursor tracking"
	)
	check_has(adapter, "if event is InputEventScreenTouch:", "raw touch must be consumed")
	check_has(adapter, "if event is InputEventScreenDrag:", "raw drag must be consumed")
	check_has(adapter, "if event is InputEventGesture:", "raw gesture must be consumed")


func test_native_bridge_only_supplies_pointer_identity() -> void:
	check_file_exists(NATIVE_SOURCE, "the thin iOS pointer identity bridge must be present")
	check_file_exists(NATIVE_HEADER, "the thin iOS pointer identity header must be present")
	check_file_exists(GDIP_SOURCE, "the iOS plugin descriptor must be present")
	var native := FileAccess.get_file_as_string(NATIVE_SOURCE)
	var header := FileAccess.get_file_as_string(NATIVE_HEADER)
	check_has(native, "UITouchTypePencil", "native bridge must use UIKit's formal Pencil identity")
	check_has(native, "UITouchTypeDirect", "native bridge must preserve direct-touch identity")
	check_has(
		native, "getTouchIDForTouch:", "bridge must reuse Godot's already assigned touch index"
	)
	check_has(
		native,
		"touch.majorRadius",
		"bridge may expose UIKit contact radius as metadata without using it for arbitration"
	)
	check_has(
		header,
		"bool has_begin_info[MAX_TOUCHES]",
		"each touch id must keep only its latest begin identity instead of a stale queue"
	)
	check_true(
		native.find("bridge->enqueue_begin_info") < native.find("original_touches_began(p_self"),
		"identity must be published before Godot can dispatch the ScreenTouch event"
	)
	check_true(
		not ("touch_drag(" in native), "native bridge must not implement Godot drawing movement"
	)
	check_true(not ("Tools" in native), "native bridge must not know about Phosprite tools")


func test_ios_ci_builds_bridge_against_exact_godot_version() -> void:
	var workflow := FileAccess.get_file_as_string(IOS_WORKFLOW_SOURCE)
	check_has(workflow, "GODOT_VERSION: 4.6.3", "iOS bridge must follow the frozen Godot version")
	check_has(
		workflow,
		'--branch "${GODOT_VERSION}-stable"',
		"CI must obtain headers from the exact Godot stable tag"
	)
	check_has(
		workflow,
		'Path(os.environ["RUNNER_TEMP"])',
		"quoted Python heredoc must read RUNNER_TEMP from the environment"
	)
	check_has(
		workflow,
		'target_path="${BUILD_ROOT}/bin/"',
		"upstream SConstruct target_path must retain its trailing separator"
	)
	check_has(
		workflow,
		"plugins/PhospritePointerIdentity=true",
		"the production iOS export must enable Pointer Identity"
	)
	check_has(
		workflow,
		"PhospritePointerIdentity.xcframework",
		"CI must build and verify the native plugin framework"
	)
	check_true(
		not ('InputProbe="*res://src/PlatformServices/InputProbe.gd"' in workflow),
		"the temporary B0 evidence probe must not ship in the P1-B runtime"
	)
