extends "res://tests/test_base.gd"

const StoragePolicy := preload("res://src/PlatformServices/StoragePolicy.gd")
const RecoveryStore := preload("res://src/ProjectLibrary/ProjectRecoveryStore.gd")
const ProjectFactoryScript := preload("res://src/ProjectLibrary/ProjectFactory.gd")

const TEST_ROOT := "user://p3_e_new_project_tests"
const BLOCKER_PATH := "user://p3_e_new_project_blocker"

var _main: Control
var _baseline_project_count := 0
var _baseline_current_index := 0


func teardown() -> void:
	if is_instance_valid(_main):
		_main.project_save_coordinator.configure(false, StoragePolicy.PROJECTS_DIRECTORY, false)
		_cleanup_added_projects()
		_main.project_gallery_root.configure(StoragePolicy.PROJECTS_DIRECTORY)
		_main.app_shell_controller.configure(
			false,
			_main.editor_root,
			_main.project_gallery_root,
			_main.project_recovery_dialog,
			_main.project_save_coordinator,
			_main.new_project_dialog
		)
	_remove_tree(TEST_ROOT)
	if FileAccess.file_exists(BLOCKER_PATH):
		DirAccess.remove_absolute(BLOCKER_PATH)


func test_new_project_dialog_reopens_with_synced_64_by_64_default() -> void:
	_prepare_main()
	if _main == null:
		return
	var dialog := _main.new_project_dialog as NewProjectDialog
	dialog.width_value.value = 123
	dialog.height_value.value = 45
	dialog.popup_for_new_project()

	check_eq(
		dialog.selected_size,
		Vector2i(64, 64),
		"each P3-E New Project session must reset its selected size to 64x64",
	)
	check_eq(
		int(dialog.width_value.value),
		64,
		"reopened New Project width input must match the 64x64 default",
	)
	check_eq(
		int(dialog.height_value.value),
		64,
		"reopened New Project height input must match the 64x64 default",
	)
	dialog.hide()


func test_new_project_dialog_preset_selector_and_custom_inputs_stay_synchronized() -> void:
	_prepare_main()
	if _main == null:
		return
	var dialog := _main.new_project_dialog as NewProjectDialog
	dialog.popup_for_new_project()

	check_eq(dialog.active_ratio, NewProjectDialog.PresetRatio.SQUARE, "default ratio must be 1:1")
	check_eq(dialog.preset_selector.item_count, 6, "1:1 dropdown must contain six size tiers")
	check_eq(
		dialog.preset_selector.get_item_text(dialog.preset_selector.selected),
		"64 × 64",
		"default 64x64 must be selected in the 1:1 dropdown",
	)

	dialog.preset_selector.item_selected.emit(3)
	check_eq(
		dialog.selected_size,
		Vector2i(128, 128),
		"choosing the fourth 1:1 tier must update the authoritative size",
	)

	dialog.four_three_ratio.pressed.emit()
	check_eq(
		dialog.active_ratio,
		NewProjectDialog.PresetRatio.FOUR_THREE,
		"4:3 tab must switch the dropdown dataset",
	)
	check_eq(dialog.preset_selector.item_count, 6, "4:3 dropdown must contain six size tiers")
	check_eq(
		dialog.selected_size,
		Vector2i(171, 128),
		"ratio switch must preserve the selected preset tier",
	)
	check_eq(dialog.preset_selector.selected, 3, "4:3 switch must keep the fourth preset selected")
	check_eq(int(dialog.width_value.value), 171, "ratio switch must update Width")
	check_eq(int(dialog.height_value.value), 128, "ratio switch must update Height")

	dialog.sixteen_nine_ratio.pressed.emit()
	check_eq(
		dialog.selected_size,
		Vector2i(228, 128),
		"16:9 switch must map the fourth tier to 228x128",
	)
	check_eq(dialog.preset_selector.selected, 3, "16:9 switch must keep the fourth preset selected")

	dialog.width_value.value = 230
	check_eq(dialog.selected_size, Vector2i(230, 128), "manual Width must update selected size")
	check_eq(
		dialog.preset_selector.selected,
		-1,
		"manual non-preset dimensions must clear the stale dropdown selection",
	)
	dialog.square_ratio.pressed.emit()
	check_eq(
		dialog.selected_size,
		Vector2i(230, 128),
		"ratio switch must preserve manual custom dimensions when no preset tier is selected",
	)
	check_eq(
		dialog.preset_selector.selected,
		-1,
		"manual custom dimensions must remain unselected after changing ratio tabs",
	)
	check_true(dialog.custom_ratio.disabled, "reserved Custom preset tab must stay disabled")
	dialog.hide()


func test_new_project_dialog_blocks_oversized_canvas_without_allocating_project() -> void:
	_prepare_main()
	if _main == null:
		return
	var dialog := _main.new_project_dialog as NewProjectDialog
	dialog.popup_for_new_project()
	dialog.width_value.value = 16384
	dialog.height_value.value = 16384

	check_eq(
		dialog.selected_size,
		Vector2i(16384, 16384),
		"custom inputs must keep the user's requested dimensions visible for correction",
	)
	check_true(dialog.size_warning.visible, "oversized canvas must show an inline warning")
	check_true(dialog.get_ok_button().disabled, "Create must be disabled for an unsafe total area")

	dialog.height_value.value = 1024
	check_true(
		not dialog.size_warning.visible,
		"warning must clear immediately when the total pixel count returns within budget",
	)
	check_true(
		not dialog.get_ok_button().disabled,
		"Create must re-enable for a 16384x1024 canvas within the total-pixel budget",
	)
	dialog.hide()

	_reset_root()
	_configure_managed(TEST_ROOT)
	var project_count_before := Global.projects.size()
	var tab_count_before := Global.tabs.tab_count
	check_true(
		not _main.app_shell_controller.create_new_project(Vector2i(16384, 16384)),
		"business entry must reject an unsafe canvas even when UI validation is bypassed",
	)
	check_eq(
		Global.projects.size(),
		project_count_before,
		"rejected oversized creation must not append a transient Project",
	)
	check_eq(
		Global.tabs.tab_count,
		tab_count_before,
		"rejected oversized creation must not append a transient tab",
	)


func test_new_project_is_saved_before_editor_and_blank_canvas_is_transparent() -> void:
	_prepare_main()
	if _main == null:
		return
	_reset_root()
	_configure_managed(TEST_ROOT)

	check_true(
		_main.app_shell_controller.create_new_project(Vector2i(85, 64)),
		"P3-E should create and commit a valid 4:3 project",
	)
	check_eq(
		_main.app_shell_controller.mode,
		AppShellController.Mode.EDITOR,
		"successful first save must transition Gallery to Editor",
	)
	check_eq(
		Global.projects.size(),
		1,
		"managed Editor must keep only the newly created runtime Project",
	)
	check_eq(
		Global.tabs.tab_count,
		1,
		"legacy runtime must retain only one logical tab even though managed UI hides the TabBar",
	)

	var project := Global.current_project
	check_eq(project.size, Vector2i(85, 64), "new Project must keep the selected preset size")
	check_eq(project.palettes.size(), 3, "new Project must contain the three starter palettes")
	check_true(project.palettes.has("Endesga 32"), "new Project must contain Endesga 32")
	check_true(project.palettes.has("Resurrect 64"), "new Project must contain Resurrect 64")
	check_true(project.palettes.has("Lospec500"), "new Project must contain Lospec500")
	check_eq(
		project.project_current_palette_name,
		"Endesga 32",
		"new Project should initially select the first starter palette",
	)
	check_eq(
		project.get_meta(AnimationTimeline.TIMELINE_MODE_META, -1),
		AnimationTimeline.TimelineMode.SINGLE_FRAME,
		"new managed projects must persist Single frame as their initial Timeline mode",
	)
	check_eq(
		(Global.animation_timeline as AnimationTimeline).get_timeline_mode(),
		AnimationTimeline.TimelineMode.SINGLE_FRAME,
		"new projects must enter the Editor in Single-frame Timeline mode",
	)
	check_true(
		project.name.begins_with("未命名_"),
		"new Project must use the timestamped untitled display name",
	)
	check_true(
		project.save_path.begins_with(TEST_ROOT + "/"),
		"new Project must be committed into managed Projects storage before Editor",
	)
	check_file_exists(project.save_path, "successful P3-E creation must leave a formal PXO")
	check_true(
		RecoveryStore.validate_snapshot(project.save_path, project.project_uuid),
		"formal PXO must validate against the new Project UUID",
	)
	check_true(
		not project.has_changed, "successful first commit must clear the new Project dirty bit"
	)
	check_true(
		not RecoveryStore.has_pending_recovery(project.project_uuid),
		"successful first commit must not leave a recovery candidate behind",
	)

	var image := project.frames[0].cels[0].get_image()
	check_eq(
		image.get_pixel(0, 0).a,
		0.0,
		"P3-E blank project must start transparent with no fill/background option",
	)


func test_failed_first_save_rolls_back_project_tab_and_stays_in_gallery() -> void:
	_prepare_main()
	if _main == null:
		return
	_remove_tree(TEST_ROOT)
	if FileAccess.file_exists(BLOCKER_PATH):
		DirAccess.remove_absolute(BLOCKER_PATH)
	var blocker := FileAccess.open(BLOCKER_PATH, FileAccess.WRITE)
	check_true(blocker != null, "failure fixture must create a file where a directory is required")
	if blocker == null:
		return
	blocker.store_string("block")
	blocker.close()

	_configure_managed(BLOCKER_PATH)
	var count_before := Global.projects.size()
	var tabs_before := Global.tabs.tab_count
	var current_before := Global.current_project

	check_true(
		not _main.app_shell_controller.create_new_project(Vector2i(64, 64)),
		"initial save failure must reject the New Project transition",
	)
	check_eq(
		Global.projects.size(),
		count_before,
		"failed first save must remove the transient Project",
	)
	check_eq(
		Global.tabs.tab_count,
		tabs_before,
		"failed first save must remove the transient editor tab",
	)
	check_true(
		Global.current_project == current_before,
		"failed first save must leave the previous current Project untouched",
	)
	check_eq(
		_main.app_shell_controller.mode,
		AppShellController.Mode.GALLERY,
		"failed first save must leave the user in Project Gallery",
	)


func _prepare_main() -> void:
	_main = tree.current_scene
	check_true(_main != null, "runner must load Main before the P3-E integration tests")
	if _main == null:
		return
	_baseline_project_count = Global.projects.size()
	_baseline_current_index = Global.current_project_index


func _configure_managed(directory: String) -> void:
	_main.project_save_coordinator.configure(true, directory, false)
	_main.project_gallery_root.configure(directory)
	_main.app_shell_controller.configure(
		true,
		_main.editor_root,
		_main.project_gallery_root,
		_main.project_recovery_dialog,
		_main.project_save_coordinator,
		_main.new_project_dialog
	)
	_main.app_shell_controller.show_gallery(false)


func _cleanup_added_projects() -> void:
	Global.tabs.set_block_signals(true)
	for index in range(Global.projects.size() - 1, -1, -1):
		var project := Global.projects[index]
		if not (
			project.save_path.begins_with(TEST_ROOT) or project.save_path.begins_with(BLOCKER_PATH)
		):
			continue
		if index < Global.tabs.tab_count:
			Global.tabs.remove_tab(index)
		project.remove()
	Global.tabs.set_block_signals(false)
	if Global.projects.is_empty():
		var replacement := ProjectFactoryScript.create_blank_project(
			tr("untitled"), ProjectFactoryScript.DEFAULT_SIZE
		)
		Global.projects.append(replacement)
	if Global.projects.size() > 0:
		Global.current_project_index = mini(_baseline_current_index, Global.projects.size() - 1)
		if Global.current_project_index < Global.tabs.tab_count:
			Global.tabs.current_tab = Global.current_project_index


func _reset_root() -> void:
	_remove_tree(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(TEST_ROOT)


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for directory in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(directory))
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
