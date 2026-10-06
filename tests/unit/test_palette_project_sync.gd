extends "res://tests/test_base.gd"

const PALETTES_SOURCE := "res://src/Autoload/Palettes.gd"
const PANEL_SOURCE := "res://src/Palette/PalettePanel.gd"
const PANEL_SCENE := "res://src/Palette/PalettePanel.tscn"
const EDIT_DIALOG_SOURCE := "res://src/Palette/EditPaletteDialog.gd"
const GRID_SOURCE := "res://src/Palette/PaletteGrid.gd"
const SWATCH_SOURCE := "res://src/Palette/PaletteSwatch.gd"


func test_normal_palette_edits_are_project_local_and_sync_is_explicit() -> void:
	var palettes := FileAccess.get_file_as_string(PALETTES_SOURCE)
	var panel := FileAccess.get_file_as_string(PANEL_SOURCE)
	var dialog := FileAccess.get_file_as_string(EDIT_DIALOG_SOURCE)
	check_has(
		panel,
		"project_palette.source_palette_name = palette.name",
		"editing a shared palette must remember its source before creating a project-local copy",
	)
	check_has(
		dialog,
		"saved.emit(name_input.text, comment_input.text, width_input.value, height_input.value, false)",
		"ordinary palette property edits must remain project-local",
	)
	check_has(
		palettes,
		"func sync_project_palette_to_global",
		"shared palette files must only be overwritten through an explicit sync path",
	)
	check_has(
		palettes,
		'shared_palette.source_palette_name = ""',
		"the synchronized global palette must not serialize itself as a project override",
	)


func test_compact_palette_header_hides_legacy_edit_buttons() -> void:
	var scene := FileAccess.get_file_as_string(PANEL_SCENE)
	for node_name in ["AddColor", "DeleteColor", "Sort", "LockGrid"]:
		var marker := '[node name="%s"' % node_name
		var start := scene.find(marker)
		check_true(start >= 0, "palette scene must still contain %s for compatibility" % node_name)
		if start < 0:
			continue
		var tail := scene.substr(start)
		var next_node := tail.find("\n[node ", 1)
		var block := tail if next_node < 0 else tail.substr(0, next_node)
		check_has(
			block,
			"visible = false",
			"%s must stay hidden in the compact palette header" % node_name
		)


func test_empty_slot_confirmation_and_drag_out_delete_are_shared_across_inputs() -> void:
	var panel := FileAccess.get_file_as_string(PANEL_SOURCE)
	var grid := FileAccess.get_file_as_string(GRID_SOURCE)
	var swatch := FileAccess.get_file_as_string(SWATCH_SOURCE)
	check_has(
		panel,
		"palette_grid.pending_empty_palette_index == index",
		"an empty slot must require a second activation before inserting the active color",
	)
	check_has(
		grid,
		"swatch_dragged_outside.emit(palette_index)",
		"iPad reorder release outside the palette must emit the shared deletion request",
	)
	check_has(
		swatch,
		"dragged_outside.emit(index)",
		"mouse or trackpad native drag must emit the same deletion request when released outside",
	)


func test_empty_slot_confirmation_survives_same_color_sync_and_rebuild() -> void:
	var grid := FileAccess.get_file_as_string(GRID_SOURCE)
	var panel := FileAccess.get_file_as_string(PANEL_SOURCE)
	check_has(
		grid,
		"var pending_empty_mouse_button := -1",
		"pending empty-slot state must remember which color target initiated it",
	)
	check_has(
		grid,
		"var pending_empty_color := Color.TRANSPARENT",
		"pending empty-slot state must snapshot the active color",
	)
	check_has(
		grid,
		"_restore_pending_empty_highlight()",
		"rebuilding Palette swatches must restore a still-valid pending target",
	)
	check_has(
		grid,
		"target_color != pending_empty_color",
		"same-color notifications must not silently clear an empty-slot confirmation",
	)
	check_has(
		panel,
		"palette_grid.set_pending_empty_swatch(index, mouse_button, new_color)",
		"first tap must store the complete confirmation state",
	)
	check_has(
		panel,
		"palette_grid.pending_empty_color == new_color",
		"second tap may add only the exact color that was originally confirmed",
	)
