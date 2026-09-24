class_name ImageImportModeDialog
extends PopupPanel

signal layer_requested
signal reference_requested
signal dismissed

var _choice_made := false


func _ready() -> void:
	popup_hide.connect(_on_popup_hide)


func popup_for_image() -> void:
	_choice_made = false
	popup_centered()


func _on_layer_pressed() -> void:
	_choice_made = true
	layer_requested.emit()
	hide()


func _on_reference_pressed() -> void:
	_choice_made = true
	reference_requested.emit()
	hide()


func _on_popup_hide() -> void:
	if not _choice_made:
		dismissed.emit()
