extends "res://tests/test_base.gd"

const ANIMATION_GESTURES := preload("res://src/UI/Timeline/LayerTouchAdapter.gd")
const SINGLE_FRAME_CARD := preload("res://src/UI/Timeline/SingleFrameLayerCard.gd")
const ANIMATION_SOURCE := "res://src/UI/Timeline/LayerTouchAdapter.gd"
const SINGLE_FRAME_CARD_SOURCE := "res://src/UI/Timeline/SingleFrameLayerCard.gd"
const SINGLE_FRAME_STRIP_SOURCE := "res://src/UI/Timeline/SingleFrameLayerStrip.gd"
const LAYER_SOURCE := "res://src/UI/Timeline/LayerButton.gd"


func test_animation_layer_swipes_require_horizontal_direction_and_no_hold() -> void:
	check_true(
		ANIMATION_GESTURES._is_layer_selection_swipe(Vector2(35, 4), 100),
		"right swipe selects a layer",
	)
	check_true(
		ANIMATION_GESTURES._is_layer_selection_swipe(Vector2(-35, 4), 100),
		"left swipe also selects a layer",
	)
	check_true(
		not ANIMATION_GESTURES._is_layer_selection_swipe(Vector2(8, 40), 100),
		"vertical scrolling cannot toggle animation layers",
	)
	check_true(
		not ANIMATION_GESTURES._is_layer_selection_swipe(Vector2(20, 2), 100),
		"short pointer jitter cannot toggle layers",
	)
	check_true(
		not ANIMATION_GESTURES._is_layer_selection_swipe(Vector2(35, 10), 450),
		"long hold followed by movement stays reserved for layer reorder",
	)


func test_single_frame_swipe_requires_downward_movement() -> void:
	check_true(
		SINGLE_FRAME_CARD._is_downward_selection_swipe(Vector2(3, 34)),
		"downward swipe toggles a single-frame card",
	)
	check_true(
		not SINGLE_FRAME_CARD._is_downward_selection_swipe(Vector2(3, -34)),
		"upward movement cannot toggle a card",
	)
	check_true(
		not SINGLE_FRAME_CARD._is_downward_selection_swipe(Vector2(35, 5)),
		"horizontal scrolling remains available",
	)
	check_true(
		not SINGLE_FRAME_CARD._is_downward_selection_swipe(Vector2(2, 20)),
		"short jitter cannot enter multi-selection",
	)
	check_true(
		not SINGLE_FRAME_CARD._is_downward_selection_swipe(Vector2(30, 30)),
		"diagonal drags do not incorrectly toggle cards",
	)


func test_animation_swipe_selection_uses_shared_layer_model_and_resets_on_tap() -> void:
	var source := FileAccess.get_file_as_string(ANIMATION_SOURCE)
	check_has(
		source,
		"_main_button.get_global_rect().has_point",
		"swipes are limited to layer-name buttons"
	)
	check_has(source, '"swipe_selected": false', "gesture initially owns no selection change")
	check_has(source, 'candidate["swipe_selected"] = true', "a swipe is consumed only once")
	check_has(
		source, "project.set_meta(LAYER_SWIPE_MULTI_META, true)", "first swipe starts additive mode"
	)
	check_has(
		source, "project.selected_cels.clear()", "first swipe ignores unrelated focus selection"
	)
	check_has(
		source, "project.selected_cels.erase([frame, layer_index])", "reswipe deselects the layer"
	)
	check_has(
		source, "project.selected_cels.append(frame_layer)", "swipes add layers across frames"
	)
	check_has(
		source, "project.remove_meta(LAYER_SWIPE_MULTI_META)", "a normal tap exits swipe selection"
	)
	check_has(source, "Global.cel_switched.emit()", "empty selection updates the button visuals")
	check_has(source, 'candidate.get("menu_opened", false)', "long-press popups remain active")
	check_has(source, "_build_layer_drag_data", "existing hold-and-drag behavior remains")


func test_single_frame_swipe_selection_preserves_long_press_batch_context() -> void:
	var card := FileAccess.get_file_as_string(SINGLE_FRAME_CARD_SOURCE)
	var strip := FileAccess.get_file_as_string(SINGLE_FRAME_STRIP_SOURCE)
	check_has(card, "signal swipe_selection(layer_index: int)", "cards expose down-swipe selection")
	check_has(card, "pointer_cancel.emit(layer_index)", "swipe consumes long-press recognition")
	check_has(
		strip, "card.swipe_selection.connect(_on_card_swipe_selection)", "strip receives swipes"
	)
	check_has(strip, "set_multiselect_mode(true)", "first down swipe starts multi-selection")
	check_has(strip, "_toggle_layer_in_multiselect(layer_index)", "repeat down swipe toggles")
	check_has(strip, "set_multiselect_mode(false)", "single tap exits multi-selection")
	check_has(strip, "_select_only_layer(layer_index)", "single tap selects only its target")
	check_has(strip, "layer_context_menu.popup_on_parent", "hold opens batch context menu")
	check_has(strip, "_selected_layer_indices()", "context actions use the selected layer batch")


func test_clipping_mask_context_action_updates_every_selected_layer() -> void:
	var source := FileAccess.get_file_as_string(LAYER_SOURCE)
	check_has(
		source,
		"for selected_index in _get_layer_indices():",
		"clipping mask applies to all swipe-selected layers",
	)
	check_has(source, "update_global_layer_buttons()", "all selected layer icons refresh")
