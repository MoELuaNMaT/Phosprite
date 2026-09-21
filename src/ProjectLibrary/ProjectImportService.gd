class_name ProjectImportService
extends RefCounted

enum ImageMode { LAYER, REFERENCE }
enum ImportKind { UNKNOWN, PXO, ASEPRITE, IMAGE }

const StoragePolicy := preload("res://src/PlatformServices/StoragePolicy.gd")
const ProjectFactoryScript := preload("res://src/ProjectLibrary/ProjectFactory.gd")
const ProjectLibraryScript := preload("res://src/ProjectLibrary/ProjectLibrary.gd")
const ProjectIdentityScript := preload("res://src/ProjectLibrary/ProjectIdentity.gd")
const CanvasSizeResolverScript := preload("res://src/ProjectLibrary/CanvasSizeResolver.gd")

const IMAGE_EXTENSIONS := PackedStringArray(
	[
		"png",
		"bmp",
		"hdr",
		"jpg",
		"jpeg",
		"svg",
		"tga",
		"webp",
		"exr",
	]
)

var save_coordinator: ProjectSaveCoordinator
var projects_directory := StoragePolicy.PROJECTS_DIRECTORY
var last_error := ""


func configure(
	coordinator: ProjectSaveCoordinator, directory := StoragePolicy.PROJECTS_DIRECTORY
) -> void:
	save_coordinator = coordinator
	projects_directory = directory


func classify_path(source_path: String) -> ImportKind:
	var extension := source_path.get_extension().to_lower()
	if extension == StoragePolicy.PROJECT_EXTENSION.trim_prefix("."):
		return ImportKind.PXO
	if extension in ["ase", "aseprite"]:
		return ImportKind.ASEPRITE
	if extension in IMAGE_EXTENSIONS:
		return ImportKind.IMAGE
	return ImportKind.UNKNOWN


func load_image(source_path: String) -> Image:
	last_error = ""
	if not FileAccess.file_exists(source_path):
		last_error = "Source file does not exist."
		return null
	var image := Image.load_from_file(source_path)
	if not is_instance_valid(image) or image.is_empty():
		last_error = "Image could not be decoded."
		return null
	return image


func import_pxo(source_path: String) -> Project:
	last_error = ""
	if not _prepare_import_directory():
		return null
	if not FileAccess.file_exists(source_path):
		last_error = "Source project does not exist."
		return null

	var source_name := source_path.uri_decode().get_file().get_basename()
	var reserved_uuids := _managed_uuid_set()
	var target_path := ProjectFactoryScript.make_unique_project_path(
		source_name, projects_directory
	)
	var copy_error := DirAccess.copy_absolute(source_path, target_path)
	if copy_error != OK:
		last_error = "Project copy failed: %s" % error_string(copy_error)
		return null

	var previous_index := Global.current_project_index
	var project_count := Global.projects.size()
	OpenSave.open_pxo_file(target_path, false, false)
	var project := _capture_imported_project(project_count)
	if project == null:
		DirAccess.remove_absolute(target_path)
		last_error = "Copied PXO could not be opened."
		return null

	_avoid_managed_uuid_collision(project, reserved_uuids)
	project.name = target_path.get_file().get_basename()
	project.file_name = project.name
	project.has_changed = true
	if not save_coordinator.flush_project(project, "import_pxo", target_path):
		_rollback_import(project, target_path, previous_index)
		last_error = "Managed PXO commit failed."
		return null
	return project


func import_aseprite(source_path: String) -> Project:
	last_error = ""
	if not _prepare_import_directory():
		return null
	if not FileAccess.file_exists(source_path):
		last_error = "Aseprite source does not exist."
		return null

	var previous_index := Global.current_project_index
	var project_count := Global.projects.size()
	AsepriteParser.open_aseprite_file(source_path)
	var project := _capture_imported_project(project_count)
	if project == null:
		last_error = "Aseprite file could not be parsed."
		return null

	var target_path := ProjectFactoryScript.make_unique_project_path(
		source_path.uri_decode().get_file().get_basename(), projects_directory
	)
	project.name = target_path.get_file().get_basename()
	project.file_name = project.name
	project.has_changed = true
	if not save_coordinator.flush_project(project, "import_aseprite", target_path):
		_rollback_import(project, target_path, previous_index)
		last_error = "Converted Aseprite project could not be committed."
		return null
	return project


func import_image(
	source_path: String, image: Image, image_mode: ImageMode, canvas_size: Vector2i
) -> Project:
	last_error = ""
	if not _prepare_import_directory():
		return null
	if not is_instance_valid(image) or image.is_empty():
		last_error = "Image is empty."
		return null

	var project_name := source_path.uri_decode().get_file().get_basename()
	var target_path := ProjectFactoryScript.make_unique_project_path(
		project_name, projects_directory
	)
	var project := ProjectFactoryScript.create_blank_project(project_name, canvas_size)
	if image_mode == ImageMode.LAYER:
		_apply_image_layer(project, image, project_name)
	else:
		_apply_reference_image(project, image)

	Global.projects.append(project)
	project.has_changed = true
	if not save_coordinator.flush_project(project, "import_image", target_path):
		_rollback_import(project, target_path, Global.current_project_index)
		last_error = "Imported image project could not be committed."
		return null
	return project


func _apply_image_layer(project: Project, source_image: Image, layer_name: String) -> void:
	var fitted_size := CanvasSizeResolverScript.fit_layer_size(
		source_image.get_size(), project.size
	)
	var fitted := source_image.duplicate()
	if fitted.get_size() != fitted_size:
		fitted.resize(fitted_size.x, fitted_size.y, Image.INTERPOLATE_NEAREST)
	fitted.convert(project.get_image_format())

	var layer := project.layers[0] as PixelLayer
	layer.name = layer_name
	var cel := project.frames[0].cels[0] as PixelCel
	var destination := cel.get_image()
	destination.fill(Color.TRANSPARENT)
	var offset := CanvasSizeResolverScript.centered_offset(fitted_size, project.size)
	destination.blit_rect(fitted, Rect2i(Vector2i.ZERO, fitted_size), offset)
	cel.update_texture()


func _apply_reference_image(project: Project, source_image: Image) -> void:
	var reference := ReferenceImage.new()
	reference.project = project
	reference.create_from_image(source_image.duplicate())
	if not project.reference_images.has(reference):
		project.reference_images.append(reference)
	var scale_factor := CanvasSizeResolverScript.reference_scale(
		source_image.get_size(), project.size
	)
	reference.scale = Vector2.ONE * scale_factor
	reference.position = CanvasSizeResolverScript.reference_position(
		source_image.get_size(), project.size, scale_factor
	)


func _prepare_import_directory() -> bool:
	if save_coordinator == null:
		last_error = "Managed save coordinator is unavailable."
		return false
	if DirAccess.dir_exists_absolute(projects_directory):
		return true
	var error := DirAccess.make_dir_recursive_absolute(projects_directory)
	if error != OK:
		last_error = "Projects directory could not be created: %s" % error_string(error)
		return false
	return true


func _capture_imported_project(previous_count: int) -> Project:
	if Global.projects.size() <= previous_count:
		return null
	return Global.projects[Global.projects.size() - 1]


func _managed_uuid_set() -> Dictionary:
	var reserved: Dictionary = {}
	for entry: ProjectLibraryEntry in ProjectLibraryScript.new(projects_directory).scan(false):
		if not entry.uuid.is_empty():
			reserved[entry.uuid] = true
	return reserved


func _avoid_managed_uuid_collision(project: Project, reserved: Dictionary) -> void:
	if not reserved.has(project.project_uuid):
		return
	for _attempt in 16:
		var replacement := ProjectIdentityScript.generate_uuid()
		if not replacement.is_empty() and not reserved.has(replacement):
			project.project_uuid = replacement
			return


func _rollback_import(project: Project, target_path: String, previous_index: int) -> void:
	var project_index := Global.projects.find(project)
	var switch_guard := Global.project_switch_guard
	Global.project_switch_guard = Callable()
	if project_index >= 0 and project_index < Global.tabs.tab_count:
		if (
			Global.tabs.current_tab == project_index
			and previous_index >= 0
			and previous_index < Global.tabs.tab_count
			and previous_index != project_index
		):
			Global.tabs.current_tab = previous_index
		Global.tabs.remove_tab(project_index)
	Global.project_switch_guard = switch_guard
	save_coordinator.forget_project(project, true)
	project.remove()
	if FileAccess.file_exists(target_path):
		DirAccess.remove_absolute(target_path)
