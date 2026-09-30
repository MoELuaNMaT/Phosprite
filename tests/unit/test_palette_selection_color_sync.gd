extends "res://tests/test_base.gd"

const PALETTE_GRID := preload("res://src/Palette/PaletteGrid.gd")
const PALETTE_GRID_SOURCE := "res://src/Palette/PaletteGrid.gd"


func _make_grid() -> PaletteGrid:
	var grid := PALETTE_GRID.new() as PaletteGrid
	var palette := Palette.new("SelectionSync", 4, 1)
	palette.add_color(Color.RED, 0)
	palette.add_color(Color.BLUE, 1)
	palette.add_color(Color.GREEN, 2)
	grid.current_palette = palette
	return grid


func test_palette_index_never_overrides_active_color_mismatch() -> void:
	var grid := _make_grid()
	check_eq(
		grid.call("_find_exact_color_index", Color.BLUE, 0),
		1,
		"a sampled palette index must be ignored when that swatch color differs from the active color",
	)
	grid.free()


func test_palette_selection_requires_exact_color_equality() -> void:
	var grid := _make_grid()
	var near_red := Color(1.0, 0.0, 0.0, 1.0)
	near_red.r -= 0.0001
	check_eq(
		grid.call("_find_exact_color_index", near_red, -1),
		-1,
		"a merely approximate palette color must not remain selected",
	)
	check_eq(
		grid.call("_find_exact_color_index", Color.RED, -1),
		0,
		"an exactly identical active color must select its palette swatch",
	)
	grid.free()


func test_matching_palette_index_is_only_a_duplicate_color_preference() -> void:
	var grid := _make_grid()
	grid.current_palette.add_color(Color.RED, 3)
	check_eq(
		grid.call("_find_exact_color_index", Color.RED, 3),
		3,
		"when duplicate exact colors exist, a matching supplied index may choose the intended duplicate",
	)
	grid.free()


func test_color_change_path_clears_selection_when_no_exact_match_exists() -> void:
	var source := FileAccess.get_file_as_string(PALETTE_GRID_SOURCE)
	check_has(
		source,
		"var matching_index := _find_exact_color_index(target_color, preferred_index)",
		"palette selection must be derived from exact active-color matching",
	)
	check_has(
		source,
		"unselect_swatch(mouse_button, selected_index)",
		"a non-matching active color must remove the old palette highlight",
	)
	check_true(
		not source.contains("target_color.is_equal_approx(swatches[color_ind].color)"),
		"approximate color equality must not keep a palette swatch selected",
	)
	check_true(
		not source.contains("target_color.to_html() == swatches[color_ind].color.to_html()"),
		"8-bit HTML equality must not substitute for exact Color equality",
	)
