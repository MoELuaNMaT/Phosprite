extends "res://tests/test_base.gd"

const ADAPTER := preload("res://src/InputAdapter/CanvasInputAdapter.gd")
const ADAPTER_SOURCE := "res://src/InputAdapter/CanvasInputAdapter.gd"
const CANVAS_SOURCE := "res://src/UI/Canvas/Canvas.gd"
const CAMERA_SOURCE := "res://src/UI/Canvas/CanvasCamera.gd"
const IOS_WORKFLOW_SOURCE := "res://.github/workflows/ios-build.yml"
const NATIVE_SOURCE := "res://ios/pointer_identity_src/phosprite_pointer_identity.mm"
const GDIP_SOURCE := "res://ios/pointer_identity_src/PhospritePointerIdentity.gdip"


func test_pencil_priority_is_default_policy() -> void:
	check_eq(
		ADAPTER.DEFAULT_FINGER_POLICY,
		ADAPTER.FingerPolicy.PENCIL_PRIORITY,
		"Pencil Priority must be the P1-B default"
	)


func test_direct_content_policy_matrix() -> void:
	check_true(
		ADAPTER.direct_content_allowed(ADAPTER.FingerPolicy.UNRESTRICTED, false, false),
		"unrestricted mode must allow finger content when Pencil is inactive"
	)
	check_true(
		not ADAPTER.direct_content_allowed(
			ADAPTER.FingerPolicy.FINGER_NAVIGATION_ONLY, false, false
		),
		"navigation-only mode must never let direct touch edit content"
	)
	check_true(
		ADAPTER.direct_content_allowed(ADAPTER.FingerPolicy.PENCIL_PRIORITY, false, false),
		"Pencil Priority keeps finger editing available before Pencil has been used"
	)
	check_true(
		not ADAPTER.direct_content_allowed(ADAPTER.FingerPolicy.PENCIL_PRIORITY, true, false),
		"Pencil Priority must reserve content for Pencil after a Pencil session is known"
	)
	check_true(
		not ADAPTER.direct_content_allowed(ADAPTER.FingerPolicy.UNRESTRICTED, false, true),
		"active Pencil ownership must suppress direct content even in unrestricted mode"
	)


func test_adapter_owns_ios_touch_and_multitouch_navigation() -> void:
	var src := FileAccess.get_file_as_string(ADAPTER_SOURCE)
	check_has(src, "InputEventScreenTouch", "adapter must consume raw iOS touch begin/end")
	check_has(src, "InputEventScreenDrag", "adapter must consume raw iOS touch movement")
	check_has(src, "_try_begin_navigation", "adapter must arbitrate two-finger navigation")
	check_has(src, "_begin_pencil_ownership", "adapter must give Pencil explicit content ownership")
	check_has(src, 'state["suppressed"] = true', "active direct touches must be suppressible")
	check_has(src, "EMULATED_MOUSE_GRACE_MSEC", "touch-to-mouse duplicates must be filtered")
	check_has(src, "PALM_RADIUS_HINT", "UIKit contact radius may be used only as an early hint")


func test_existing_tools_remain_behind_canvas_adapter_boundary() -> void:
	var canvas := FileAccess.get_file_as_string(CANVAS_SOURCE)
	var camera := FileAccess.get_file_as_string(CAMERA_SOURCE)
	check_has(canvas, "_input_adapter.handle_event(self, event)", "Canvas must route iOS input first")
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


func test_native_bridge_only_supplies_pointer_identity() -> void:
	check_file_exists(NATIVE_SOURCE, "the thin iOS pointer identity bridge must be present")
	check_file_exists(GDIP_SOURCE, "the iOS plugin descriptor must be present")
	var native := FileAccess.get_file_as_string(NATIVE_SOURCE)
	check_has(native, "UITouchTypePencil", "native bridge must use UIKit's formal Pencil identity")
	check_has(native, "UITouchTypeDirect", "native bridge must preserve direct-touch identity")
	check_has(native, "getTouchIDForTouch:", "bridge must reuse Godot's already assigned touch index")
	check_has(native, "touch.majorRadius", "bridge may expose UIKit contact radius as a hint")
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
