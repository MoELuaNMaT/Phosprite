extends "res://tests/test_base.gd"

const PALETTE_GRID := preload("res://src/Palette/PaletteGrid.gd")
const PALETTE_GRID_SOURCE := "res://src/Palette/PaletteGrid.gd"
const PALETTE_PANEL_SOURCE := "res://src/Palette/PalettePanel.gd"
const PALETTE_SWATCH_SOURCE := "res://src/Palette/PaletteSwatch.gd"
const PALETTES_SOURCE := "res://src/Autoload/Palettes.gd"


func test_palette_touch_routes_through_existing_primary_secondary_target() -> void:
	var src := FileAccess.get_file_as_string(PALETTE_GRID_SOURCE)
	check_has(src, 'OS.get_name() == "iOS"', "D3 touch routing must remain iOS-only")
	check_has(
		src,
		"Tools.picking_color_for == MOUSE_BUTTON_RIGHT",
		"touch Palette actions must reuse the existing active color target"
	)
	check_has(
		src,
		"swatch_pressed.emit(active_button, palette_index)",
		"touch swatch selection must enter the existing PalettePanel signal path"
	)
	check_true(
		not ("active_palette_slot" in src),
		"D3 must not create a parallel Primary/Secondary state model"
	)


func test_palette_touch_add_delete_reuse_existing_panel_handlers() -> void:
	var grid := FileAccess.get_file_as_string(PALETTE_GRID_SOURCE)
	var panel := FileAccess.get_file_as_string(PALETTE_PANEL_SOURCE)
	check_has(
		grid,
		"panel._on_AddColor_gui_input(event)",
		"touch Add Color must reuse the existing add-color transaction path"
	)
	check_has(
		grid,
		"panel._on_DeleteColor_gui_input(event)",
		"touch Delete Color must reuse the existing delete-color transaction path"
	)
	check_has(
		panel,
		"Tools.get_assigned_color(event.button_index)",
		"the shared Add Color handler must still resolve colors from the selected slot"
	)
	check_has(
		panel,
		"current_palette_get_selected_color_index(\n\t\t\t\tevent.button_index",
		"the shared Delete Color handler must still resolve the selected index by slot"
	)


func test_palette_touch_double_tap_edits_existing_swatch_path() -> void:
	var src := FileAccess.get_file_as_string(PALETTE_GRID_SOURCE)
	check_eq(
		PALETTE_GRID.IOS_TOUCH_DOUBLE_TAP_MSEC,
		350,
		"Palette touch editing must use the approved bounded double-tap window"
	)
	check_has(
		src,
		"_register_ios_palette_tap",
		"touch swatches need explicit direct-touch double-tap recognition"
	)
	check_has(
		src,
		"swatch_double_clicked.emit",
		"double tap must reuse the existing swatch edit signal instead of a parallel editor"
	)
	check_has(
		src,
		"_ios_last_tap_nonempty",
		"an empty-slot fill must not accidentally become an immediate edit double tap"
	)


func test_palette_touch_reorder_is_long_hold_and_scroll_safe() -> void:
	var src := FileAccess.get_file_as_string(PALETTE_GRID_SOURCE)
	check_eq(
		PALETTE_GRID.IOS_TOUCH_REORDER_HOLD_MSEC,
		450,
		"Palette reordering must require a deliberate long hold before drag"
	)
	check_eq(
		PALETTE_GRID.IOS_TOUCH_TAP_SLOP_PX,
		12.0,
		"Palette scrolling/tap arbitration must keep the established 12 px touch slop"
	)
	check_has(
		src,
		"candidate[\"cancelled\"] = true",
		"movement before the long hold must cancel the Palette tap/reorder candidate"
	)
	check_has(
		src,
		"get_viewport().set_input_as_handled()",
		"only an acquired reorder drag should take ownership away from scrolling"
	)
	check_has(
		src,
		"swatch_dropped.emit(palette_index, target_index)",
		"touch reorder must reuse the existing Palette drop transaction"
	)


func test_palette_touch_suppresses_synthetic_mouse_without_breaking_pointer_input() -> void:
	var src := FileAccess.get_file_as_string(PALETTE_GRID_SOURCE)
	check_has(
		src,
		"IOS_TOUCH_MOUSE_FILTER_META",
		"touch mode must preserve the original Palette mouse filters"
	)
	check_has(
		src,
		"control.mouse_filter = Control.MOUSE_FILTER_IGNORE",
		"direct touch-owned controls must suppress duplicate synthesized mouse activation"
	)
	check_has(
		src,
		"event.device != -1",
		"a real pointer event must restore normal mouse/trackpad Palette behavior"
	)
	check_has(
		src,
		"_restore_pointer_palette_ui()",
		"pointer restoration must be explicit instead of permanently changing desktop semantics"
	)


func test_palette_touch_targets_improve_ipad_hit_size_without_forcing_desktop_layout() -> void:
	var src := FileAccess.get_file_as_string(PALETTE_GRID_SOURCE)
	check_eq(
		PALETTE_GRID.IOS_DEFAULT_SWATCH_SIZE,
		Vector2(32, 32),
		"fresh iPad installs should use the approved denser 32 px Palette swatch default"
	)
	check_eq(
		PALETTE_GRID.IOS_TOUCH_TARGET_SIZE,
		44.0,
		"Palette toolbar controls should reach the 44 pt touch target on iPad"
	)
	check_has(
		src,
		'Global.config_cache.get_value("palettes", "swatch_size", default_swatch_size)',
		"a saved user swatch-size preference must remain authoritative"
	)
	check_has(
		src,
		"if not control is OptionButton",
		"the Palette selector must keep its expanding width while receiving the larger height"
	)


func test_secondary_selection_and_drag_keep_existing_left_right_palette_model() -> void:
	var swatch := FileAccess.get_file_as_string(PALETTE_SWATCH_SOURCE)
	var palettes := FileAccess.get_file_as_string(PALETTES_SOURCE)
	check_has(
		swatch,
		"show_left_highlight or show_right_highlight",
		"touch-capable native drag must accept a selected Secondary swatch as well as Primary"
	)
	check_has(
		palettes,
		"var left_selected_color := -1",
		"D3 must preserve the existing Primary selected-index field"
	)
	check_has(
		palettes,
		"var right_selected_color := -1",
		"D3 must preserve the existing Secondary selected-index field"
	)
	check_has(
		palettes,
		"Tools.assign_color(color, mouse_button, true",
		"Palette selection must keep the existing indexed-color assignment boundary"
	)
