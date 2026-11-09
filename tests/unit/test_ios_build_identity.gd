extends "res://tests/test_base.gd"

const GALLERY := preload("res://src/UI/ProjectGallery/ProjectGallery.tscn")
const GALLERY_SCRIPT := preload("res://src/UI/ProjectGallery/ProjectGallery.gd")


func test_gallery_shows_unique_short_build_identity_on_ios() -> void:
	check_eq(
		GALLERY_SCRIPT.ios_build_label("312", "abcdef0123456789"),
		"Build 312 · abcdef0",
		"the installed iPad build is identifiable by its run number and commit",
	)
	check_eq(
		GALLERY_SCRIPT.ios_build_label("", "abcdef0123456789"),
		"",
		"local or unstamped builds do not advertise a fake build ID",
	)
	check_eq(
		GALLERY_SCRIPT.ios_build_label("312", ""),
		"",
		"missing commit prevents an unverifiable version label",
	)
	var scene := GALLERY.instantiate() as ProjectGallery
	var label := scene.get_node_or_null("Shell/TopBar/Margin/Row/Brand/BuildIdentity") as Label
	check_true(label != null, "the project gallery owns a build ID label")
	if label != null:
		check_true(not label.visible, "no placeholder build ID appears in untagged editor")
	scene.free()


func test_ios_build_pipeline_stamps_and_checks_the_packaged_version() -> void:
	var workflow := FileAccess.get_file_as_string("res://.github/workflows/ios-build.yml")
	check_has(
		workflow,
		"BUILD_NUMBER: ${{ github.run_number }}",
		"each IPA receives a unique monotonically increasing build number",
	)
	check_has(
		workflow,
		"application/version=",
		"the iOS export preset receives the build number before export",
	)
	check_has(
		workflow,
		"config/ios_build_commit",
		"the actual commit is embedded in exported Godot project settings",
	)
	check_has(
		workflow,
		"Validate IPA identity after Xcode archive",
		"the archived app version must be checked before packaging",
	)
	check_has(
		workflow,
		"if sha not in data:",
		"the archived Godot PCK must include the same build commit",
	)
	check_has(
		workflow,
		"Obsolete Curve Tool diagnostic found in production scripts",
		"the obsolete crash popup cannot return without failing the iOS build",
	)
