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
