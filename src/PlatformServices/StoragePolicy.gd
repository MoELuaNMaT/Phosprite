extends RefCounted

## Platform policy for where `.pxo` project files live.
##
## iPadOS gives an app no user-navigable file system, so the desktop model of
## "Save As into a directory the user picked" cannot work there: it confronts the
## user with the sandbox path (`/private/...`) and with Unix directories the Files
## app never shows. On iOS Phosprite therefore owns project storage: it chooses a
## path inside its own documents directory and writes there. The file stays an
## ordinary `.pxo` that the Files app can still reach.
##
## This is a pure policy helper: no autoload, no mutable state, and no reading of
## `Global`. Every function that needs a project receives it as an argument,
## because the project being saved is not always the current one; quitting saves
## background projects one at a time.

## Directory holding the project files Phosprite manages itself.
const PROJECTS_DIRECTORY := "user://Projects"
const PROJECT_EXTENSION := ".pxo"
## Name used when a project has no display name left after sanitising.
const FALLBACK_NAME := "untitled"


## Whether project files are allocated by the app instead of being chosen by the
## user through a file system dialog.
static func uses_managed_project_storage() -> bool:
	return OS.get_name() == "iOS"


## Creates the managed project directory when it is missing. Callers must report a
## failure and abort the save: falling back to another directory would put the
## project where the user cannot find it.
static func ensure_projects_directory() -> Error:
	if DirAccess.dir_exists_absolute(PROJECTS_DIRECTORY):
		return OK
	return DirAccess.make_dir_recursive_absolute(PROJECTS_DIRECTORY)


## Returns the path a project without one should be saved to: its display name
## reduced to a legal file name, made unique against the projects already stored.
static func make_initial_project_path(project: Project) -> String:
	var base_name := project.name.validate_filename()
	if base_name.ends_with(PROJECT_EXTENSION):
		# A project already named "sprite.pxo" must not become "sprite.pxo.pxo".
		base_name = base_name.trim_suffix(PROJECT_EXTENSION)
	if base_name.is_empty():
		base_name = FALLBACK_NAME
	return _unique_project_path(base_name)


## Appends an incrementing suffix until the candidate is free. The file system is
## the only source of truth here: no registry or manifest can go stale against it.
static func _unique_project_path(base_name: String) -> String:
	var path := PROJECTS_DIRECTORY.path_join(base_name + PROJECT_EXTENSION)
	var index := 2
	while FileAccess.file_exists(path):
		path = PROJECTS_DIRECTORY.path_join("%s_%d%s" % [base_name, index, PROJECT_EXTENSION])
		index += 1
	return path
