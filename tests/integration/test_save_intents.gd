extends "res://tests/test_base.gd"

## P0-E save-intent integration test.
##
## Runs against the live editor scene, because every assertion here depends on
## Main: which branch a save takes, whether a dialog opened, and whether the tabs
## and the File menu were released again. The unit suite next door can only read
## the source; this suite proves the behaviour.
##
## The direct-save mechanism is exercised for real, but the platform gate that
## routes iPadOS into it cannot be: `uses_managed_project_storage()` is false on the
## development platform, so the gate itself is covered by source assertions and by
## a policy check. On an iPad build the same call writes into user://Projects.

const POLICY_SOURCE := "res://src/PlatformServices/StoragePolicy.gd"
const MANAGED_DIRECTORY := "user://Projects"

## Files this suite may create; removed after every test so a run leaves no state.
var _created_paths: Array[String] = []


## Removes the files the suite wrote, so repeated runs start from a clean slate.
func teardown() -> void:
	for path: String in _created_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_created_paths.clear()


## Returns the editor scene's Main node, or null when the runner did not load it.
func _main() -> Node:
	return null if tree == null else tree.current_scene


## Returns the SaveIntent enum of Main without depending on how a dynamic property
## lookup resolves enums on an engine-typed reference.
func _intents(main: Node) -> Dictionary:
	var constants: Dictionary = main.get_script().get_script_constant_map()
	return constants["SaveIntent"]


## Counts how often the editor announced a save dialog.
func _connect_dialog_counter(main: Node, counter: Array) -> void:
	main.save_file_dialog_opened.connect(func(opened: bool): counter.append(opened))


## A project that already has a path is overwritten where it lies: no dialog, and
## therefore no dialog lifecycle and no disabled UI.
func test_save_reuses_an_existing_path() -> void:
	var main := _main()
	check_true(main != null, "runner must load the editor scene")
	if main == null:
		return
	var project: Project = Global.current_project
	var path := "user://phosprite_save_reuses_path.pxo"
	_created_paths.append(path)
	project.save_path = path
	project.name = "phosprite_save_reuses_path"

	var events: Array = []
	_connect_dialog_counter(main, events)
	main.call("request_save", _intents(main)["SAVE"], project)

	check_file_exists(path, "saving a project that has a path must write to that path")
	check_eq(events, [], "reusing a path must not announce a dialog")
	check_eq(
		main.save_sprite_dialog.visible, false, "reusing a path must not leave a dialog visible"
	)
	check_eq(
		Global.tabs.is_tab_disabled(0), false, "tabs must stay usable after a dialog-less save"
	)
	check_eq(Global.top_menu_container.get("can_save"), true, "the File menu must stay usable")
	project.save_path = ""


## A project with no path on a platform that has no managed storage asks the user
## for one, and the lifecycle stays paired: the dialog is announced, and cancelling
## it releases the UI again.
func test_first_save_asks_for_a_location_and_releases_it() -> void:
	var main := _main()
	check_true(main != null, "runner must load the editor scene")
	if main == null:
		return
	var policy: GDScript = load(POLICY_SOURCE)
	check_eq(
		policy.uses_managed_project_storage(), OS.get_name() == "iOS", "only iPadOS manages storage"
	)
	if policy.uses_managed_project_storage():
		return  # This half of the behaviour is only reachable off-device.
	var project: Project = Global.current_project
	project.save_path = ""

	var events: Array = []
	_connect_dialog_counter(main, events)
	main.call("request_save", _intents(main)["SAVE"], project)

	check_eq(events, [true], "a first save without managed storage must open the dialog")
	check_eq(Global.tabs.is_tab_disabled(0), true, "an open save dialog must disable the tabs")
	check_eq(
		Global.top_menu_container.get("can_save"), false, "an open save dialog must lock the menu"
	)

	# The window hides itself before it emits `canceled`; run both halves so the
	# test leaves the dialog state exactly as production does.
	main.save_sprite_dialog.hide()
	main._on_save_sprite_canceled()
	check_eq(events, [true, false], "cancelling must announce that the dialog is gone")
	check_eq(Global.tabs.is_tab_disabled(0), false, "cancelling must release the tabs")
	check_eq(Global.top_menu_container.get("can_save"), true, "cancelling must release the menu")


## Save As is its own intent. A project that already has a path must still be asked
## for a new name, and the existing path must survive until a new one is chosen.
func test_save_as_does_not_reuse_the_existing_path() -> void:
	var main := _main()
	check_true(main != null, "runner must load the editor scene")
	if main == null:
		return
	var policy: GDScript = load(POLICY_SOURCE)
	if policy.uses_managed_project_storage():
		return  # Covered by the managed-storage branch on an iPad build.
	var project: Project = Global.current_project
	var existing_path := "user://phosprite_save_as_keeps_old_path.pxo"
	project.save_path = existing_path

	var events: Array = []
	_connect_dialog_counter(main, events)
	main.call("request_save", _intents(main)["SAVE_AS"], project)

	check_eq(events, [true], "Save As must open the dialog even when a path already exists")
	check_eq(
		project.save_path, existing_path, "Save As must not touch the path before it is chosen"
	)
	check_eq(
		FileAccess.file_exists(existing_path), false, "Save As must not overwrite the existing file"
	)

	main.save_sprite_dialog.hide()
	main._on_save_sprite_canceled()
	check_eq(events, [true, false], "cancelling Save As must release the UI")
	project.save_path = ""


## The direct save is what an iPad build runs for a first Save: it writes into the
## managed directory under an allocated name, without any dialog lifecycle, and a
## second save of the same name does not overwrite the first.
func test_direct_managed_save_writes_without_a_dialog() -> void:
	var main := _main()
	check_true(main != null, "runner must load the editor scene")
	if main == null:
		return
	var policy: GDScript = load(POLICY_SOURCE)
	check_eq(policy.ensure_projects_directory(), OK, "the managed directory must be creatable")

	var project: Project = Global.current_project
	project.save_path = ""
	project.name = "phosprite_direct_save"

	var events: Array = []
	_connect_dialog_counter(main, events)
	main.call("_save_to_managed_directory", project)

	var first_path: String = project.save_path
	_created_paths.append(first_path)
	check_true(
		first_path.begins_with(MANAGED_DIRECTORY),
		"a direct save must land in the managed directory"
	)
	check_file_exists(first_path, "a direct save must write the project file")
	check_eq(events, [], "a direct save must not announce a dialog")
	check_eq(Global.tabs.is_tab_disabled(0), false, "a direct save must leave the tabs usable")
	check_eq(
		Global.top_menu_container.get("can_save"), true, "a direct save must leave the menu usable"
	)

	# The same project saved again under no new path must not reuse the name.
	project.save_path = ""
	main.call("_save_to_managed_directory", project)
	var second_path: String = project.save_path
	_created_paths.append(second_path)
	check_ne(second_path, first_path, "a second direct save must not overwrite the first file")
	check_file_exists(first_path, "the first direct save must survive the second one")
	project.save_path = ""


## Quitting saves the projects that have unsaved changes one at a time, and those
## are not necessarily the project on screen. A mixed-up target would offer to
## write one project under another one's name, so the assertion is on which
## project reaches the dialog rather than on the source that passes it.
func test_quit_save_offers_the_project_being_quit() -> void:
	var main := _main()
	check_true(main != null, "runner must load the editor scene")
	if main == null:
		return
	var policy: GDScript = load(POLICY_SOURCE)
	if policy.uses_managed_project_storage():
		return  # On an iPad build the quit save writes directly; covered above.
	var current: Project = Global.current_project
	# A second project stands in for the background project a quit has to save. It
	# carries a distinct name because the dialog is seeded from the name of the
	# project it was handed, which is exactly what separates the two candidates.
	var target := Project.new([], "phosprite_quit_target", Vector2i(23, 11))
	Global.projects.append(target)

	var events: Array = []
	_connect_dialog_counter(main, events)
	main.changed_projects_on_quit.clear()
	main.changed_projects_on_quit.append(target)
	main.is_quitting_on_save = true
	main.call("request_save", _intents(main)["QUIT_SAVE"], target)

	check_eq(events, [true], "a quit save on this platform must ask for a location")
	check_eq(
		main.save_sprite_dialog.current_file,
		target.name + ".pxo",
		"the quit dialog must be seeded from the project being quit, not the visible one"
	)
	check_ne(
		main.save_sprite_dialog.current_file,
		current.name + ".pxo",
		"the visible project must not stand in for the background one"
	)

	# Cancelling ends the quit, which is what production does too: the save was
	# never confirmed, so the project stays open and the editor stays usable.
	main.save_sprite_dialog.hide()
	main._on_save_sprite_canceled()
	main.changed_projects_on_quit.clear()
	check_eq(events, [true, false], "cancelling the quit save must release the UI")
	check_eq(main.is_quitting_on_save, false, "cancelling must clear the quitting flag")

	# Drop the stand-in project so the tab bar and the project list are as they were.
	Global.tabs.remove_tab(Global.projects.size() - 1)
	target.remove()
