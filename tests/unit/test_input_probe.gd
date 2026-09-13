extends "res://tests/test_base.gd"

const PROBE_SOURCE := "res://src/PlatformServices/InputProbe.gd"
const IOS_WORKFLOW_SOURCE := "res://.github/workflows/ios-build.yml"


func test_input_probe_contract() -> void:
	check_file_exists(PROBE_SOURCE, "the temporary P1-B0 probe must be present")
	var src := FileAccess.get_file_as_string(PROBE_SOURCE)
	check_has(
		src,
		'const LOG_PATH := "user://Projects/p1b_input_probe.jsonl"',
		"the B0 evidence log must have a fixed managed-project path"
	)
	check_has(src, "InputEventScreenTouch", "the probe must capture native touch begin/end")
	check_has(src, "InputEventScreenDrag", "the probe must capture native touch drag data")
	check_has(src, "InputEventMouseButton", "the probe must capture synthesized/real mouse buttons")
	check_has(src, "InputEventMouseMotion", "the probe must capture mouse/stylus motion data")
	check_has(src, "InputEventMagnifyGesture", "the probe must capture pinch gestures")
	check_has(src, "InputEventPanGesture", "the probe must capture pan gestures")
	check_has(
		src, "SHARE_SERVICE.share_file", "the iPad log must be retrievable through Share Sheet"
	)


func test_ios_ci_injects_probe_only_into_ios_checkout() -> void:
	var workflow := FileAccess.get_file_as_string(IOS_WORKFLOW_SOURCE)
	check_has(
		workflow,
		'InputProbe="*res://src/PlatformServices/InputProbe.gd"',
		"the unsigned iOS evidence build must autoload the temporary probe"
	)
	var project := FileAccess.get_file_as_string("res://project.godot")
	check_not_has(
		project,
		'InputProbe="*res://src/PlatformServices/InputProbe.gd"',
		"the temporary B0 probe must not alter ordinary desktop/runtime project configuration"
	)
