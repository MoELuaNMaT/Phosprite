extends "res://tests/test_base.gd"

const MAIN_SOURCE := "res://src/Main.gd"
const SHELL_SOURCE := "res://src/AppShell/AppShellController.gd"
const GALLERY_SOURCE := "res://src/UI/ProjectGallery/ProjectGallery.gd"
const TOP_MENU_SOURCE := "res://src/UI/TopMenuContainer/TopMenuContainer.gd"
const TOP_MENU_SCENE := "res://src/UI/TopMenuContainer/TopMenuContainer.tscn"
const MAIN_SCENE := "res://src/Main.tscn"


func test_p3_c_ios_startup_routes_to_gallery_without_legacy_startup_ui() -> void:
	var main_src := FileAccess.get_file_as_string(MAIN_SOURCE)
	check_has(
		main_src,
		"var managed_storage := STORAGE_POLICY.uses_managed_project_storage()",
		"P3-C startup must resolve the managed iPad policy once",
	)
	check_has(
		main_src,
		"not managed_storage\n\t\tand Global.session_crashed_last_time()",
		"legacy global crash recovery must be gated away from managed iPad startup",
	)
	check_has(
		main_src,
		"if not managed_storage and Global.open_last_project:",
		"managed iPad startup must not auto-open the previous project",
	)
	check_has(
		main_src,
		"if managed_storage:\n\t\tapp_shell_controller.startup()",
		"managed iPad startup must enter the App Shell Gallery path",
	)
	check_has(
		main_src,
		"else:\n\t\t_show_splash_screen()",
		"desktop startup must retain the legacy splash path",
	)


func test_p3_c_shell_has_only_gallery_and_editor_runtime_states() -> void:
	var shell_src := FileAccess.get_file_as_string(SHELL_SOURCE)
	check_has(
		shell_src,
		"enum Mode { GALLERY, EDITOR }",
		"P3-C App Shell must expose exactly the planned Gallery/Editor states",
	)
	check_has(
		shell_src,
		"editor_root.visible = mode == Mode.EDITOR",
		"Editor visibility must be owned by the App Shell state",
	)
	check_has(
		shell_src,
		"gallery_root.visible = mode == Mode.GALLERY",
		"Gallery visibility must be owned by the App Shell state",
	)
	check_has(
		shell_src,
		"save_coordinator.flush_before_leaving_editor()",
		"returning Home must pass the P3-B blocking save gate",
	)
	check_has(
		shell_src,
		"gallery_root.refresh()",
		"entering Gallery must rescan the managed project library",
	)
	check_has(
		shell_src,
		"gallery_root.reset_scroll_position()",
		"entering Gallery from Editor must reset the future Gallery scroll position",
	)


func test_p3_c_recovery_is_project_scoped_and_cancel_is_non_destructive() -> void:
	var shell_src := FileAccess.get_file_as_string(SHELL_SOURCE)
	check_has(
		shell_src,
		"if entry.has_pending_recovery:",
		"recovery prompt must be reached from the selected ProjectLibraryEntry",
	)
	check_has(
		shell_src,
		"_show_recovery_prompt(entry)",
		"opening the affected project must own recovery presentation",
	)
	check_has(
		shell_src,
		"RecoveryStore.restore_to_project(project_uuid, project_path)",
		"Restore must replace only the selected project's formal file",
	)
	check_has(
		shell_src,
		"RecoveryStore.discard(project_uuid)",
		"Discard must target only the selected project's recovery slot",
	)
	check_has(
		shell_src,
		"# Cancel is intentionally non-destructive.",
		"closing the recovery prompt must not silently discard recovery",
	)


func test_p3_c_gallery_remains_a_shell_api_before_p3_d_visual_grid() -> void:
	var gallery_src := FileAccess.get_file_as_string(GALLERY_SOURCE)
	var main_scene := FileAccess.get_file_as_string(MAIN_SCENE)
	check_has(
		gallery_src,
		"signal project_open_requested(path: String)",
		"P3-C Gallery shell must expose a project-open request for P3-D cards",
	)
	check_has(
		gallery_src,
		"entries = library.scan(",
		"Gallery refresh must continue consuming the P3-A Project Library",
	)
	check_has(
		gallery_src,
		"func reset_scroll_position() -> void:",
		"P3-C must freeze the scroll-reset handoff API for P3-D",
	)
	check_has(
		main_scene,
		'path="res://src/UI/ProjectGallery/ProjectGallery.tscn"',
		"Main must host the Project Gallery shell alongside the Editor",
	)


func test_p3_c_editor_home_entry_is_ios_only_at_runtime() -> void:
	var main_src := FileAccess.get_file_as_string(MAIN_SOURCE)
	var menu_src := FileAccess.get_file_as_string(TOP_MENU_SOURCE)
	var menu_scene := FileAccess.get_file_as_string(TOP_MENU_SCENE)
	check_has(
		main_src,
		"top_menu_container.set_return_home_visible(managed_storage)",
		"Main must expose the return-home control only for managed iPad storage",
	)
	check_has(
		menu_src,
		"signal return_home_requested",
		"the Editor chrome must expose a shell navigation signal",
	)
	check_has(
		menu_scene,
		'text = "Projects"',
		"P3-C must provide the minimal return-to-Projects affordance",
	)
	check_has(
		menu_scene,
		"visible = false",
		"the new shell navigation affordance must default hidden for desktop",
	)
