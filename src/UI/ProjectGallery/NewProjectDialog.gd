class_name NewProjectDialog
extends ConfirmationDialog

signal create_requested(canvas_size: Vector2i)

const ProjectFactoryScript := preload("res://src/ProjectLibrary/ProjectFactory.gd")

enum PresetRatio {
	SQUARE,
	FOUR_THREE,
	SIXTEEN_NINE,
	CUSTOM,
}

var selected_size := ProjectFactoryScript.DEFAULT_SIZE
var active_ratio := PresetRatio.SQUARE
var _ratio_group := ButtonGroup.new()

@onready var preset_selector := %PresetSelector as OptionButton
@onready var square_ratio := %SquareRatio as Button
@onready var four_three_ratio := %FourThreeRatio as Button
@onready var sixteen_nine_ratio := %SixteenNineRatio as Button
@onready var custom_ratio := %CustomRatio as Button
@onready var width_value := %WidthValue as SpinBox
@onready var height_value := %HeightValue as SpinBox


func _ready() -> void:
	_ratio_group.allow_unpress = false
	for button: Button in [square_ratio, four_three_ratio, sixteen_nine_ratio]:
		button.button_group = _ratio_group
	square_ratio.set_pressed_no_signal(true)

	square_ratio.pressed.connect(_on_ratio_pressed.bind(PresetRatio.SQUARE))
	four_three_ratio.pressed.connect(_on_ratio_pressed.bind(PresetRatio.FOUR_THREE))
	sixteen_nine_ratio.pressed.connect(_on_ratio_pressed.bind(PresetRatio.SIXTEEN_NINE))

	_rebuild_preset_selector()
	_apply_size(ProjectFactoryScript.DEFAULT_SIZE)


func popup_for_new_project() -> void:
	popup_with_size(ProjectFactoryScript.DEFAULT_SIZE)


func popup_with_size(initial_size: Vector2i) -> void:
	var matching_ratio := ratio_for_preset_size(initial_size)
	_set_active_ratio(PresetRatio.SQUARE if matching_ratio < 0 else matching_ratio)
	_apply_size(initial_size)
	popup_centered_clamped()


static func ratio_for_preset_size(canvas_size: Vector2i) -> int:
	for ratio in [PresetRatio.SQUARE, PresetRatio.FOUR_THREE, PresetRatio.SIXTEEN_NINE]:
		if presets_for_ratio(ratio).has(canvas_size):
			return ratio
	return -1


static func presets_for_ratio(ratio: int) -> Array[Vector2i]:
	match ratio:
		PresetRatio.SQUARE:
			return ProjectFactoryScript.SQUARE_PRESETS
		PresetRatio.FOUR_THREE:
			return ProjectFactoryScript.FOUR_THREE_PRESETS
		PresetRatio.SIXTEEN_NINE:
			return ProjectFactoryScript.SIXTEEN_NINE_PRESETS
		_:
			return []


func _set_active_ratio(ratio: int) -> void:
	active_ratio = ratio
	square_ratio.set_pressed_no_signal(ratio == PresetRatio.SQUARE)
	four_three_ratio.set_pressed_no_signal(ratio == PresetRatio.FOUR_THREE)
	sixteen_nine_ratio.set_pressed_no_signal(ratio == PresetRatio.SIXTEEN_NINE)
	_rebuild_preset_selector()


func _rebuild_preset_selector() -> void:
	preset_selector.clear()
	for preset: Vector2i in presets_for_ratio(active_ratio):
		preset_selector.add_item("%d × %d" % [preset.x, preset.y])
	_sync_preset_selection()


func _sync_preset_selection() -> void:
	var presets := presets_for_ratio(active_ratio)
	for index in presets.size():
		if presets[index] == selected_size:
			preset_selector.select(index)
			return
	preset_selector.select(-1)


func _apply_size(canvas_size: Vector2i, update_inputs := true) -> void:
	selected_size = Vector2i(
		clampi(canvas_size.x, 1, ProjectFactoryScript.MAX_CANVAS_SIDE),
		clampi(canvas_size.y, 1, ProjectFactoryScript.MAX_CANVAS_SIDE)
	)
	if update_inputs:
		width_value.set_value_no_signal(selected_size.x)
		height_value.set_value_no_signal(selected_size.y)
	_sync_preset_selection()


func _on_ratio_pressed(ratio: int) -> void:
	_set_active_ratio(ratio)


func _on_preset_item_selected(index: int) -> void:
	var presets := presets_for_ratio(active_ratio)
	if index < 0 or index >= presets.size():
		return
	_apply_size(presets[index])


func _on_width_value_changed(value: float) -> void:
	_apply_size(Vector2i(int(value), selected_size.y), false)


func _on_height_value_changed(value: float) -> void:
	_apply_size(Vector2i(selected_size.x, int(value)), false)


func _on_confirmed() -> void:
	create_requested.emit(selected_size)
