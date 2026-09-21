class_name ExportProfile
extends RefCounted

var file_format := Export.FileFormat.PNG
var export_directory_path := ""
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
	profile.file_format = project.file_format
	profile.export_directory_path = project.export_directory_path
	profile.current_tab = Export.current_tab
	profile.export_json = Export.export_json
	profile.split_layers = Export.split_layers
	profile.sheet_layers_as_separate_files = Export.sheet_layers_as_separate_files
	profile.crop_mode = Export.crop_mode
	profile.erase_unselected_area = Export.erase_unselected_area
	profile.orientation = Export.orientation
	profile.lines_count = Export.lines_count
	profile.frame_current_tag = Export.frame_current_tag
	profile.export_layers = Export.export_layers
	profile.direction = Export.direction
	profile.repeat_count = Export.repeat_count
	profile.resize = Export.resize
	profile.save_quality = Export.save_quality
	profile.interpolation = Export.interpolation
	profile.include_tag_in_filename = Export.include_tag_in_filename
	profile.new_dir_for_each_frame_tag = Export.new_dir_for_each_frame_tag
	profile.number_of_digits = Export.number_of_digits
	profile.separator_character = Export.separator_character
	return profile


func apply_to(project: Project) -> void:
	project.file_format = file_format
	project.export_directory_path = export_directory_path
	Export.current_tab = current_tab
	Export.export_json = export_json
	Export.split_layers = split_layers
	Export.sheet_layers_as_separate_files = sheet_layers_as_separate_files
	Export.crop_mode = crop_mode
	Export.erase_unselected_area = erase_unselected_area
	Export.orientation = orientation
	Export.lines_count = lines_count
	Export.frame_current_tag = frame_current_tag
	Export.export_layers = export_layers
	Export.direction = direction
	Export.repeat_count = repeat_count
	Export.resize = resize
	Export.save_quality = save_quality
	Export.interpolation = interpolation
	Export.include_tag_in_filename = include_tag_in_filename
	Export.new_dir_for_each_frame_tag = new_dir_for_each_frame_tag
	Export.number_of_digits = number_of_digits
	Export.separator_character = separator_character
