class_name TouchGestureConfig
extends RefCounted

## Shared, provisional thresholds for touch gesture recognition.
##
## D0 deliberately centralizes these values without making them user preferences.
## They are tuning defaults for real-device iteration, not product UX guarantees.
const DEFAULT_TAP_SLOP_PX := 12.0
const DEFAULT_DRAG_THRESHOLD_PX := 12.0
const DEFAULT_LONG_PRESS_DURATION_MSEC := 450
const DEFAULT_DOUBLE_TAP_INTERVAL_MSEC := 300
const DEFAULT_DOUBLE_TAP_DISTANCE_PX := 20.0

var tap_slop_px := DEFAULT_TAP_SLOP_PX
var drag_threshold_px := DEFAULT_DRAG_THRESHOLD_PX
var long_press_duration_msec := DEFAULT_LONG_PRESS_DURATION_MSEC
var double_tap_interval_msec := DEFAULT_DOUBLE_TAP_INTERVAL_MSEC
var double_tap_distance_px := DEFAULT_DOUBLE_TAP_DISTANCE_PX


func duplicate_config() -> TouchGestureConfig:
	var copy := TouchGestureConfig.new()
	copy.tap_slop_px = tap_slop_px
	copy.drag_threshold_px = drag_threshold_px
	copy.long_press_duration_msec = long_press_duration_msec
	copy.double_tap_interval_msec = double_tap_interval_msec
	copy.double_tap_distance_px = double_tap_distance_px
	return copy
