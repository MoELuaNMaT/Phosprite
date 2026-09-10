extends "res://tests/test_base.gd"

## P0-C product identity tests.
##
## Guard the identity boundary established by PHOSPRITE_P0_CONTRACT_V3:
## Phosprite must present its own product name and user-data namespace while
## keeping upstream attribution and never reading the old Pixelorama user tree.

const PROJECT_GODOT := "res://project.godot"
const GLOBAL_SOURCE := "res://src/Autoload/Global.gd"
const MAIN_SCENE := "res://src/Main.tscn"


func test_project_metadata_is_phosprite() -> void:
	check_eq(
		ProjectSettings.get_setting("application/config/name"),
		"Phosprite",
		"application/config/name must be Phosprite"
	)


func test_user_data_namespace_is_phosprite() -> void:
	check_eq(
		ProjectSettings.get_setting("application/config/custom_user_dir_name"),
		"phosprite",
		"custom_user_dir_name must isolate Phosprite user data"
	)
	check_true(
		ProjectSettings.get_setting("application/config/use_custom_user_dir"),
		"use_custom_user_dir must stay enabled so data lands under its own folder"
	)


func test_user_data_root_is_not_pixelorama() -> void:
	var user_dir := ProjectSettings.globalize_path("user://")
	check_true(
		not user_dir.contains("/pixelorama") and not user_dir.contains("\\pixelorama"),
		"resolved user:// path must not contain the old pixelorama namespace (got %s)" % user_dir
	)
	check_has(
		user_dir,
		"phosprite",
		"resolved user:// path must contain the phosprite namespace (got %s)" % user_dir
	)


func test_home_subdir_constant_is_phosprite() -> void:
	var src := FileAccess.get_file_as_string(GLOBAL_SOURCE)
	check_has(
		src,
		'const HOME_SUBDIR_NAME := "phosprite"',
		"HOME_SUBDIR_NAME must resolve the writable user data folder to phosprite"
	)
	# The v1.2 layout model is kept: OS.get_data_dir() is the generic parent
	# and the product folder is appended. Removing this join would point the
	# writable folder at the whole OS data root.
	check_has(
		src,
		"OS.get_data_dir().path_join(HOME_SUBDIR_NAME)",
		"home_data_directory must keep appending HOME_SUBDIR_NAME to the OS data dir"
	)


func test_bundled_data_directory_is_preserved() -> void:
	var src := FileAccess.get_file_as_string(GLOBAL_SOURCE)
	check_has(
		src,
		'const CONFIG_SUBDIR_NAME := "pixelorama_data"',
		"bundled default assets must keep living in pixelorama_data"
	)


func test_product_name_constant_exists() -> void:
	var src := FileAccess.get_file_as_string(GLOBAL_SOURCE)
	check_has(
		src,
		'const PRODUCT_NAME := "Phosprite"',
		"runtime product name must be centralized in Global.PRODUCT_NAME"
	)


func test_steam_project_configuration_removed() -> void:
	var src := FileAccess.get_file_as_string(PROJECT_GODOT)
	check_true(
		not src.contains("[steam]"),
		"project.godot must not carry an active Steam product configuration"
	)
	check_true(
		not src.contains("2779170"), "project.godot must not reference the upstream Steam app id"
	)


func test_steam_manager_node_removed_from_main_scene() -> void:
	var src := FileAccess.get_file_as_string(MAIN_SCENE)
	check_true(
		not src.contains("SteamManager"),
		"Main.tscn must not instantiate SteamManager in the normal runtime"
	)
