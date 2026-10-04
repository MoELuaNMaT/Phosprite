extends "res://tests/test_base.gd"

const LINE_TOOL_SOURCE := "res://src/Tools/DesignTools/LineTool.gd"
const MEASUREMENTS_SOURCE := "res://src/UI/Canvas/Measurements.gd"


func test_line_tool_drives_measurement_overlay_lifecycle() -> void:
	var line_tool := FileAccess.get_file_as_string(LINE_TOOL_SOURCE)
	check_has(
		line_tool,
		"Global.canvas.measurements.update_line_measurement(_start, _dest)",
		"line drag must update the pixel-length overlay",
	)
	check_has(
		line_tool,
		"Global.canvas.measurements.clear_line_measurement()",
		"line completion or cancellation must clear the overlay",
	)


func test_line_measurement_stays_screen_offset_and_text_upright() -> void:
	var measurements := FileAccess.get_file_as_string(MEASUREMENTS_SOURCE)
	check_has(
		measurements,
		"var length_px := roundi(line_length)",
		"line length must be displayed as an integer pixel count",
	)
	check_has(
		measurements,
		"LINE_MEASUREMENT_OFFSET_SCREEN := 18.0",
		"dimension UI must keep a stable screen-space offset from the line",
	)
	check_has(
		measurements,
		"draw_set_transform(Vector2.ZERO, -viewport_rotation, Vector2.ONE / canvas_zoom)",
		"measurement text must counter-rotate so glyphs remain upright",
	)
