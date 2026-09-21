class_name ImportSourceDialog
extends PopupPanel

signal files_requested
signal photos_requested


func popup_for_import() -> void:
	popup_centered()


func _on_files_pressed() -> void:
	hide()
	files_requested.emit()


func _on_photos_pressed() -> void:
	hide()
	photos_requested.emit()
