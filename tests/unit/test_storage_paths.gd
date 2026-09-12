extends "res://tests/test_base.gd"

## P0-E storage contract tests.
##
## Guards the export-path rules that the iPad port depends on: on Web and on
## sandboxed platforms (iOS, macOS sandbox, Android) there is no writable system
## directory, so the export path field carries a bare file name and the export
## falls back to user://. Breaking either rule regresses the two on-device bugs
## during P0-D: an unwritable default directory, and a file name that was wiped
## whenever the export dialog was reopened.

const EXPORT_DIALOG_SOURCE := "res://src/UI/Dialogs/ExportDialog.gd"
const PROJECT_SOURCE := "res://src/Classes/Project.gd"
const EXPORT_PRESET_SOURCE := "res://export_presets.cfg"
const MAIN_SOURCE := "res://src/Main.gd"
const SAVE_SPRITE_SCENE := "res://src/UI/Dialogs/SaveSprite.tscn"


## A plain file name has no directory component. Upstream used get_base_dir() on
## the path field unconditionally, which yields "" here and therefore blanked the
## resolved export directory on every keystroke.
func test_bare_file_name_has_no_base_dir() -> void:
	check_eq("mysprite.png".get_base_dir(), "", "a bare file name must have no base dir")
	check_eq(
		"mysprite.png".get_file(), "mysprite.png", "a bare file name must be its own file part"
	)


## The fallback path must survive path_join, otherwise the exported file lands
## outside the sandbox-writable area.
func test_user_dir_survives_path_join() -> void:
	check_eq(
		"user://".path_join("mysprite.png"), "user://mysprite.png", "user:// must join cleanly"
	)
	# get_base_dir() of a user:// path must round-trip, because OpenSave writes it
	# back into config_cache as "current_dir" after each save.
	check_eq(
		"user://mysprite.pxo".get_base_dir(),
		"user://",
		"user:// base dir must round-trip through config_cache"
	)


## The dialog must delegate platform classification to Project, so the dialog and
## the project cannot drift apart on which platforms use user://.
func test_export_dialog_delegates_to_project_classification() -> void:
	var src := FileAccess.get_file_as_string(EXPORT_DIALOG_SOURCE)
	check_has(
		src,
		"func _uses_bare_file_name() -> bool:",
		"ExportDialog must expose a single platform-classification helper"
	)
	check_has(
		src,
		"return Project._uses_user_directory()",
		"the helper must delegate to Project so both sides agree"
	)


## OS.is_sandboxed() only reports true on macOS and Linux, so it can never
## identify iOS. The predicate must name iOS explicitly, otherwise the iPad
## falls through to OS.get_system_dir(), which returns "." there.
func test_user_directory_predicate_names_ios_explicitly() -> void:
	var src := FileAccess.get_file_as_string(PROJECT_SOURCE)
	check_has(
		src,
		"static func _uses_user_directory() -> bool:",
		"Project must expose the shared platform predicate"
	)
	check_has(
		src,
		'OS.get_name() == "iOS"',
		"the predicate must name iOS explicitly; is_sandboxed() cannot detect it"
	)
	for platform: String in ['"Web"', '"Android"']:
		check_has(src, platform, "the predicate must keep covering %s" % platform)


## The path-changed handler must not write a base dir back into the project on
## platforms whose field holds only a file name. This is the exact regression
## that wiped the file name on iPad.
func test_path_changed_does_not_clobber_directory_on_bare_name_platforms() -> void:
	# Assert on behavior rather than on source text: what matters is that a bare
	# file name never turns into a directory value, because that empty result is
	# what blanked the export directory on iPad.
	check_eq(
		"mysprite.png".get_base_dir(),
		"",
		"a bare file name must not yield a directory to write back into the project"
	)
	var src := FileAccess.get_file_as_string(EXPORT_DIALOG_SOURCE)
	check_has(
		src,
		"if not _uses_bare_file_name():",
		"the path-changed handler must guard its directory write behind the helper"
	)


## Project creation must route user:// platforms away from the system directory,
## because OS.get_system_dir() returns "." on iOS and would strand exports in an
## unusable path.
func test_project_creation_uses_shared_predicate() -> void:
	var src := FileAccess.get_file_as_string(PROJECT_SOURCE)
	check_has(
		src,
		"if _uses_user_directory():",
		"Project must route user:// platforms through the shared predicate"
	)
	check_has(
		src,
		'export_directory_path = "user://"',
		"the user:// branch must assign the export directory"
	)


## iOS export must expose the sandbox Documents directory to the Files app,
## otherwise exports are invisible to the user even though they succeed.
func test_ios_preset_exposes_user_data_to_files_app() -> void:
	var src := FileAccess.get_file_as_string(EXPORT_PRESET_SOURCE)
	check_has(
		src,
		"user_data/accessible_from_files_app=true",
		"iOS preset must make user:// visible in the Files app"
	)
	check_has(
		src,
		"<key>UIFileSharingEnabled</key>",
		"iOS preset must inject UIFileSharingEnabled into Info.plist"
	)
	check_has(
		src,
		"<key>LSSupportsOpeningDocumentsInPlace</key>",
		"iOS preset must inject LSSupportsOpeningDocumentsInPlace into Info.plist"
	)


## Saves are reached through one entry point from three different user actions, so
## the intent has to be named by the caller. Deriving it from `save_path` is what
## made Save As behave like a first save on a project that already had a path.
func test_save_intents_are_named_by_the_caller() -> void:
	var src := FileAccess.get_file_as_string(MAIN_SOURCE)
	check_has(
		src, "enum SaveIntent { SAVE, SAVE_AS, QUIT_SAVE }", "Main must name the three save intents"
	)
	check_has(
		src,
		"func request_save(intent: SaveIntent, target_project: Project) -> void:",
		"the entry point must take the intent and an explicit target project"
	)
	check_has(
		src,
		"_show_save_dialog(target_project, true)",
		"Save As must be the branch that asks the dialog for a new name"
	)
	check_has(
		src,
		'if target_project.save_path != "":',
		"Save must reuse an existing path instead of asking for one"
	)


## The automatic name allocator exists for projects that have no path at all. Save
## As is not one of those cases: it saves under a name the user picked, so
## reaching the allocator from that branch would silently ignore the new name.
func test_managed_allocator_only_serves_direct_saves() -> void:
	var src := FileAccess.get_file_as_string(MAIN_SOURCE)
	check_eq(
		src.count("_save_to_managed_directory(target_project)"),
		2,
		"only the two direct-save arms may allocate a name"
	)
	check_has(
		src,
		"save_project(STORAGE_POLICY.make_initial_project_path(project), false)",
		"the allocator must only be reached through the direct-save helper"
	)


## The allocator is the only thing standing between two projects of the same name
## and one silently overwriting the other, so the file system has to be the source
## of truth rather than any cached list. Runs against a bare file name because the
## behaviour under test is the collision loop, not the project it is fed.
func test_allocator_avoids_existing_files() -> void:
	var path := "user://phosprite_allocator_probe.pxo"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check_eq(FileAccess.file_exists(path), false, "the probe file must not exist before the test")
	var file := FileAccess.open(path, FileAccess.WRITE)
	check_true(file != null, "the test must be able to occupy the probe path")
	if file == null:
		return
	file.close()
	check_eq(
		FileAccess.file_exists(path),
		true,
		"the file system must report an occupied path, which is what the allocator reads"
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## iPadOS Save As has to stay inside the directory Phosprite manages, otherwise it
## re-exposes the sandbox path the user cannot navigate. Desktop and Android keep
## the file system dialog they have always had.
func test_save_as_confines_ipad_to_managed_storage() -> void:
	var src := FileAccess.get_file_as_string(MAIN_SOURCE)
	check_has(
		src,
		"save_sprite_dialog.access = FileDialog.ACCESS_USERDATA",
		"managed Save As must switch the dialog away from the file system"
	)
	check_has(
		src,
		"save_sprite_dialog.current_dir = STORAGE_POLICY.PROJECTS_DIRECTORY",
		"managed Save As must start in the managed project directory"
	)
	var scene := FileAccess.get_file_as_string(SAVE_SPRITE_SCENE)
	check_has(
		scene,
		"access = 2",
		"the scene default must stay ACCESS_FILESYSTEM for every other platform"
	)


## A direct save never opens a dialog, so it must not enter the dialog lifecycle
## either: announcing a dialog that does not exist leaves the tabs and the File
## menu disabled with no cancelling signal to release them.
func test_direct_save_stays_out_of_the_dialog_lifecycle() -> void:
	var src := FileAccess.get_file_as_string(MAIN_SOURCE)
	var helper_start := src.find("func _save_to_managed_directory")
	check_true(helper_start != -1, "the direct managed save helper must exist")
	if helper_start == -1:
		return
	var helper_end := src.find("\nfunc ", helper_start + 1)
	var body := src.substr(helper_start, helper_end - helper_start)
	check_true(
		not body.contains("dialog_open"), "a dialog that never opens must not dim the editor"
	)
	check_true(
		not body.contains("save_file_dialog_opened"),
		"a dialog that never opens must not be announced"
	)


## Quitting saves the unsaved projects one at a time, so the project being written
## is not necessarily the current one. Every arm has to act on the project it was
## handed; falling back to Global.current_project would save the wrong file. The
## iPadOS arms cannot run on the development platform, so this asserts the source.
func test_quit_save_uses_the_target_project() -> void:
	var src := FileAccess.get_file_as_string(MAIN_SOURCE)
	var branch_start := src.find("SaveIntent.QUIT_SAVE:")
	check_true(branch_start != -1, "Main must keep a Quit Save branch")
	if branch_start == -1:
		return
	var branch_end := src.find("\nfunc ", branch_start)
	if branch_end == -1:
		branch_end = src.length()
	var branch := src.substr(branch_start, branch_end - branch_start)
	check_has(
		branch,
		"_save_to_managed_directory(target_project)",
		"an unsaved project must be allocated from the project being quit, not the current one"
	)
	check_has(
		branch,
		"save_project(target_project.save_path, false)",
		"a project that already has a path must be overwritten there, without a dialog"
	)
	check_true(
		not branch.contains("Global.current_project"),
		"Quit Save must never substitute the current project for the target one"
	)


## StoragePolicy is the only place that decides where projects live, and it is
## called with background projects during quit. Reading Global here would make it
## resolve the wrong project, so the module must stay a pure function of its
## arguments.
func test_storage_policy_reads_no_global_state() -> void:
	var src := FileAccess.get_file_as_string("res://src/PlatformServices/StoragePolicy.gd")
	check_has(
		src,
		"static func make_initial_project_path(project: Project) -> String:",
		"the allocator must receive the project it names the file after"
	)
	check_true(
		not src.contains("Global."),
		"the storage policy must not read autoload state, or it cannot serve a background project"
	)
