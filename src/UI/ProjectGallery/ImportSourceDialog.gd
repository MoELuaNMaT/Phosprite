class_name ImportSourceDialog
extends PopupPanel

signal files_requested
signal photos_requested
signal dismissed

var _choice_made := false


func _ready() -> void:
	popup_hide.connect(_on_popup_hide)


func popup_for_import() -> void:
	_choice_made = false
	popup_centered()


func _on_files_pressed() -> void:
	_choice_made = true
	files_requested.emit()
	hide()


func _on_photos_pressed() -> void:
	_choice_made = true
	photos_requested.emit()
	hide()


func _on_popup_hide() -> void:
	if not _choice_made:
		dismissed.emit()
