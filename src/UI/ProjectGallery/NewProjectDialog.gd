class_name NewProjectDialog
extends ConfirmationDialog

signal create_requested(canvas_size: Vector2i)

const ProjectFactoryScript := preload("res://src/ProjectLibrary/ProjectFactory.gd")

var selected_size := ProjectFactoryScript.DEFAULT_SIZE

@onready var current_size_label := %CurrentSize as Label
@onready var square_presets := %SquarePresets as HFlowContainer
@onready var four_three_presets := %FourThreePresets as HFlowContainer
@onready var sixteen_nine_presets := %SixteenNinePresets as HFlowContainer
@onready var width_value := %WidthValue as SpinBox
@onready var height_value := %HeightValue as SpinBox


func _ready() -> void:
	_build_preset_buttons(square_presets, ProjectFactoryScript.SQUARE_PRESETS)
	_build_preset_buttons(four_three_presets, ProjectFactoryScript.FOUR_THREE_PRESETS)
	_build_preset_buttons(sixteen_nine_presets, ProjectFactoryScript.SIXTEEN_NINE_PRESETS)
	_apply_size(ProjectFactoryScript.DEFAULT_SIZE)


func popup_for_new_project() -> void:
	popup_with_size(ProjectFactoryScript.DEFAULT_SIZE)


func popup_with_size(initial_size: Vector2i) -> void:
	_apply_size(initial_size)
	popup_centered_clamped()


func _build_preset_buttons(container: HFlowContainer, presets: Array[Vector2i]) -> void:
	for preset: Vector2i in presets:
		var button := Button.new()
		button.custom_minimum_size = Vector2(76, 38)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.text = "%d×%d" % [preset.x, preset.y]
		button.pressed.connect(_on_preset_pressed.bind(preset))
		container.add_child(button)


func _apply_size(canvas_size: Vector2i, update_inputs := true) -> void:
	selected_size = Vector2i(
		clampi(canvas_size.x, 1, ProjectFactoryScript.MAX_CANVAS_SIDE),
		clampi(canvas_size.y, 1, ProjectFactoryScript.MAX_CANVAS_SIDE)
	)
	if update_inputs:
		width_value.set_value_no_signal(selected_size.x)
		height_value.set_value_no_signal(selected_size.y)
	current_size_label.text = "%d × %d px" % [selected_size.x, selected_size.y]


func _on_preset_pressed(preset: Vector2i) -> void:
	_apply_size(preset)


func _on_width_value_changed(value: float) -> void:
	_apply_size(Vector2i(int(value), selected_size.y), false)


func _on_height_value_changed(value: float) -> void:
	_apply_size(Vector2i(selected_size.x, int(value)), false)


func _on_confirmed() -> void:
	create_requested.emit(selected_size)
