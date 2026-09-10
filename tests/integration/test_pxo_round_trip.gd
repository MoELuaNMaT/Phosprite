extends "res://tests/test_base.gd"

## P0-C .pxo round-trip integration test.
##
## Unlike the unit suites, this exercises the real editor scene. tests/runner.gd
## instantiates Main.tscn and bootstraps a project before running this suite, so
## Global.current_project and the UI nodes it depends on are already live here.
## This is the storage contract the P0 Gate rests on: it proves serialization and
## deserialization agree end to end on a real .pxo archive.

# Written under user:// so the test never touches the user's real project files.
const ROUND_TRIP_PATH := "user://phosprite_roundtrip_test.pxo"


## Removes the temporary archive created by the round-trip.
func teardown() -> void:
	if FileAccess.file_exists(ROUND_TRIP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ROUND_TRIP_PATH))


func test_editor_project_is_bootstrapped() -> void:
	check_true(Global.current_project != null, "runner must bootstrap a current project")
	check_true(Global.tabs != null, "editor scene must provide the project tab bar")
	check_true(Global.canvas != null, "editor scene must provide the canvas")


func test_pxo_round_trip_preserves_project_data() -> void:
	var project: Project = Global.current_project
	check_true(project != null, "runner must bootstrap a current project")
	if project == null:
		return

	# Give the project distinctive data so a mismatch cannot pass by accident.
	var target_size := Vector2i(37, 19)
	project.size = target_size
	project.name = "roundtrip"

	var pixel_color := Color(0.25, 0.5, 0.75, 1.0)
	var image := Image.create(target_size.x, target_size.y, false, Image.FORMAT_RGBA8)
	image.fill(pixel_color)

	var cel := project.layers[0].get_cel(0) as PixelCel
	check_true(cel != null, "default project must expose a pixel cel to draw into")
	if cel == null:
		return
	cel.get_image().blit_rect(image, Rect2i(Vector2i.ZERO, target_size), Vector2i.ZERO)

	var saved: bool = OpenSave.save_pxo_file(ROUND_TRIP_PATH, false, false, project)
	check_true(saved, ".pxo save must succeed")
	check_file_exists(ROUND_TRIP_PATH, ".pxo archive must exist on disk after saving")
	if not saved:
		return

	# Open the archive back into the running editor and read the restored state.
	OpenSave.open_pxo_file(ROUND_TRIP_PATH)
	await tree.process_frame

	var reopened: Project = Global.current_project
	check_true(reopened != null, "opening .pxo must yield a project")
	if reopened == null:
		return

	check_eq(reopened.size.x, target_size.x, "restored project width must match the saved one")
	check_eq(reopened.size.y, target_size.y, "restored project height must match the saved one")

	var restored_cel := reopened.layers[0].get_cel(0) as PixelCel
	check_true(restored_cel != null, "restored project must expose its pixel cel")
	if restored_cel == null:
		return

	var restored_pixel := restored_cel.get_image().get_pixel(3, 3)
	check_true(
		restored_pixel.is_equal_approx(pixel_color),
		"restored pixel colour must match what was saved (got %s)" % restored_pixel
	)
