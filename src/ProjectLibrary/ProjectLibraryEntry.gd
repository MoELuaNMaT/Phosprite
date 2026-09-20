class_name ProjectLibraryEntry
extends RefCounted

enum HealthState { OK, CORRUPTED }

var path := ""
var uuid := ""
var canvas_size := Vector2i.ZERO
var modified_time := 0
var thumbnail: Image
var health_state := HealthState.OK
var has_pending_recovery := false


func _init(project_path := "") -> void:
	path = project_path
