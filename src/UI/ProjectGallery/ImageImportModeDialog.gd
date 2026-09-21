class_name ImageImportModeDialog
extends PopupPanel

signal layer_requested
signal reference_requested


func popup_for_image() -> void:
	popup_centered()


func _on_layer_pressed() -> void:
	hide()
	layer_requested.emit()


func _on_reference_pressed() -> void:
	hide()
	reference_requested.emit()
