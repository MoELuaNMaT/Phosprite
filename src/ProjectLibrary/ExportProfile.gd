class_name ExportProfile
extends RefCounted

const SERIALIZED_KEYS := [
	"file_name",
	"file_format",
	"export_directory_path",
	"current_tab",
	"export_json",
	"split_layers",
	"sheet_layers_as_separate_files",
	"crop_mode",
	"erase_unselected_area",
	"orientation",
	"lines_count",
	"frame_current_tag",
	"export_layers",
	"direction",
	"repeat_count",
	"resize",
	"save_quality",
	"interpolation",
	"include_tag_in_filename",
	"new_dir_for_each_frame_tag",
	"number_of_digits",
	"separator_character",
]

var file_name := "untitled"
var file_format := Export.FileFormat.PNG
var export_directory_path := ""
var directory_path: String:
	get:
		return export_directory_path
	set(value):
		export_directory_path = value

var current_tab := Export.ExportTab.IMAGE
var export_json := false
var split_layers := false
var sheet_layers_as_separate_files := false
var crop_mode := Export.CropMode.NONE
var erase_unselected_area := false
var orientation := Export.Orientation.COLUMNS
var lines_count := 1
var frame_current_tag := Export.ExportFrames.ALL_FRAMES
var export_layers := Export.VISIBLE_LAYERS
var number_of_frames := 1
var direction := Export.AnimationDirection.FORWARD
var repeat_count := 0
var resize := 100
var save_quality := 0.75
var interpolation := Image.INTERPOLATE_NEAREST
var include_tag_in_filename := false
var new_dir_for_each_frame_tag := false
var number_of_digits := 4
var separator_character := "_"


static func capture(project: Project) -> ExportProfile:
	var profile := ExportProfile.new()
	if project != null and project.export_profile != null:
		profile.copy_from(project.export_profile)
	return profile


func apply_to(project: Project) -> void:
	if project == null:
		return
	if project.export_profile == null:
		project.export_profile = ExportProfile.new()
	project.export_profile.copy_from(self)


func copy_from(other: ExportProfile) -> void:
	if other == null:
		return
	for key in SERIALIZED_KEYS:
		set(key, other.get(key))
	number_of_frames = other.number_of_frames


func serialize() -> Dictionary:
	var data := {}
	for key in SERIALIZED_KEYS:
		data[key] = var_to_str(get(key))
	return data


func deserialize(data: Dictionary) -> void:
	for key in SERIALIZED_KEYS:
		if not data.has(key):
			continue
		var default_value = get(key)
		var raw_value = data[key]
		var value = raw_value
		if raw_value is String:
			if default_value is String and not (
				raw_value.begins_with('"') and raw_value.ends_with('"')
			):
				value = raw_value
			else:
				value = str_to_var(raw_value)
		if typeof(default_value) == typeof(value):
			set(key, value)
