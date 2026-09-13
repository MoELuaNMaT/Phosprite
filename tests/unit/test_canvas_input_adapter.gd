extends "res://tests/test_base.gd"

const ADAPTER := preload("res://src/InputAdapter/CanvasInputAdapter.gd")
const ADAPTER_SOURCE := "res://src/InputAdapter/CanvasInputAdapter.gd"
const CANVAS_SOURCE := "res://src/UI/Canvas/Canvas.gd"
const CAMERA_SOURCE := "res://src/UI/Canvas/CanvasCamera.gd"
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


func test_adapter_owns_ios_touch_and_multitouch_navigation() -> void:
	var src := FileAccess.get_file_as_string(ADAPTER_SOURCE)
	check_has(src, "InputEventScreenTouch", "adapter must consume raw iOS touch begin/end")
	check_has(src, "InputEventScreenDrag", "adapter must consume raw iOS touch movement")
	check_has(src, "_try_begin_navigation", "adapter must arbitrate two-finger navigation")
	check_has(src, "_begin_pencil_ownership", "adapter must give Pencil explicit canvas ownership")
	check_has(
		src,
		"_suppress_direct_touches_until_release",
		"Pencil takeover must suppress held direct touches until their release"
	)
	check_has(
		src,
		"_pencil_touch_id != -1 or _content_touch_id != -1",
		"two-finger navigation must not coexist with active Pencil or content ownership"
	)
	check_has(
		src,
		'state["suppressed"] = true',
		"direct touches beginning during Pencil ownership must stay suppressed"
	)
	check_has(
		src,
		"return event.device == -1",
		"Canvas must filter Godot DEVICE_ID_EMULATION touch-to-mouse duplicates"
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
