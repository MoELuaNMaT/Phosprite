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

	# Resize through the production path: assigning `size` directly leaves the cel
	# images at their old dimensions, a state the editor never produces, and the
	# saved archive then disagrees with itself about the canvas size.
	var target_size := Vector2i(37, 19)
	DrawingAlgos.resize_canvas(target_size.x, target_size.y, 0, 0)
	project.name = "roundtrip"

	# Byte-exact on purpose: .pxo stores 8 bits per channel, so a colour that is not
	# representable in a byte would come back quantised and the comparison would
	# have to be loosened to a tolerance instead of an equality.
	var pixel_color := Color8(63, 127, 191)

	# A frame holds one cel per layer, indexed the same way the layers are, so the
	# first layer's cel lives at the front of the first frame.
	var cel := project.frames[0].cels[0] as PixelCel
	check_true(cel != null, "default project must expose a pixel cel to draw into")
	if cel == null:
		return
	# Fill the cel at its own size; a smaller image would leave the rest of the cel
	# untouched and the pixel check could still pass at the wrong coordinates.
	var image := Image.create(target_size.x, target_size.y, false, Image.FORMAT_RGBA8)
	image.fill(pixel_color)
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

	var restored_cel := reopened.frames[0].cels[0] as PixelCel
	check_true(restored_cel != null, "restored project must expose its pixel cel")
	if restored_cel == null:
		return
	var restored_pixel := restored_cel.get_image().get_pixel(3, 3)
	check_true(
		restored_pixel.is_equal_approx(pixel_color),
		"restored pixel colour must match what was saved (got %s)" % restored_pixel
	)
