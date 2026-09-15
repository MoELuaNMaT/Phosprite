extends "res://tests/test_base.gd"

const FEEDBACK_SOURCE := "res://src/Palette/PaletteReorderTouchFeedback.gd"
const PALETTE_GRID_SOURCE := "res://src/Palette/PaletteGrid.gd"
const PALETTE_PANEL_SCENE := "res://src/Palette/PalettePanel.tscn"


func test_reorder_feedback_reuses_existing_palette_grid_ownership() -> void:
	var src := FileAccess.get_file_as_string(FEEDBACK_SOURCE)
	var grid := FileAccess.get_file_as_string(PALETTE_GRID_SOURCE)
	check_has(
		src,
		"palette_grid._ios_touch_candidates",
		"reorder feedback must observe the existing PaletteGrid touch candidate state",
	)
	check_has(
		src,
		'candidate.get("reordering", false)',
		"feedback may activate only after PaletteGrid has acquired reorder ownership",
	)
	check_true(
		not ("swatch_dropped.emit" in src),
		"feedback must never create a second Palette drop transaction path",
	)
	check_has(
		grid,
		"swatch_dropped.emit(palette_index, target_index)",
		"the original PaletteGrid drop transaction remains authoritative",
	)


func test_reorder_preview_follows_the_active_touch() -> void:
	var src := FileAccess.get_file_as_string(FEEDBACK_SOURCE)
	check_has(
		src,
		"var preview := PaletteSwatch.new()",
		"reorder acquisition should create a visible swatch preview",
	)
	check_has(
		src,
		"_preview.global_position = screen_position - _preview.size * 0.5",
		"the drag preview must stay centered under the user's current touch position",
	)
	check_has(
		src,
		"_clear_preview()",
		"reorder feedback must clean up the transient preview after the gesture",
	)


func test_reorder_scroll_is_relative_to_palette_visible_bounds() -> void:
	var src := FileAccess.get_file_as_string(FEEDBACK_SOURCE)
	check_has(
		src,
		"var visible_rect := scroll_container.get_global_rect()",
		"edge scrolling must use the Palette ScrollContainer visible bounds",
	)
	check_has(
		src,
		"screen_position.y < visible_rect.position.y",
		"auto-scroll may move upward only after the finger crosses the top boundary",
	)
	check_has(
		src,
		"screen_position.y > visible_rect.end.y",
		"auto-scroll may move downward only after the finger crosses the bottom boundary",
	)
	check_has(
		src,
		"scroll_container.scroll_vertical = int(round(_managed_scroll))",
		"inside the visible area reorder ownership must hold the Palette scroll position still",
	)
	check_has(
		src,
		"signf(overflow) * speed * delta",
		"outside the visible area scrolling must follow the boundary-overflow direction",
	)


func test_reorder_feedback_is_wired_only_as_palette_ui_support() -> void:
	var scene := FileAccess.get_file_as_string(PALETTE_PANEL_SCENE)
	check_has(
		scene,
		"PaletteReorderTouchFeedback.gd",
		"PalettePanel must instantiate the iOS reorder feedback helper",
	)
	check_has(
		scene,
		'[node name="PaletteReorderTouchFeedback" type="Node" parent="."]',
		"reorder feedback should remain a non-visual support node outside Palette model state",
	)
