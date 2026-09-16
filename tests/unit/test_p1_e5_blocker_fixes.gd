extends "res://tests/test_base.gd"

const MANAGER := preload("res://src/UI/Timeline/TimelinePanelTouchManager.gd")
const MANAGER_SOURCE := "res://src/UI/Timeline/TimelinePanelTouchManager.gd"
const PIXEL_CEL_SOURCE := "res://src/Classes/Cels/PixelCel.gd"


class FakeTimeline:
	extends Control
	var tag_container: Control


func test_e5_fix_scripts_parse_cleanly() -> void:
	for path in [MANAGER_SOURCE, PIXEL_CEL_SOURCE]:
		var script := GDScript.new()
		script.source_code = FileAccess.get_file_as_string(path)
		check_eq(script.reload(), OK, "%s must compile after the E5 blocker fixes" % path)


func test_adjacent_tag_edges_prefer_the_tag_body_under_the_finger() -> void:
	var manager := MANAGER.new()
	var timeline := FakeTimeline.new()
	var container := Control.new()
	var tag_a := Control.new()
	var tag_b := Control.new()
	add_child(timeline)
	timeline.tag_container = container
	timeline.add_child(container)
	container.add_child(tag_a)
	container.add_child(tag_b)
	tag_a.position = Vector2(0.0, 0.0)
	tag_a.size = Vector2(100.0, 32.0)
	tag_b.position = Vector2(100.0, 0.0)
	tag_b.size = Vector2(50.0, 32.0)
	manager.set("_timeline", timeline)

	var a_target: Dictionary = manager.call("_find_tag_resize_target", Vector2(98.0, 16.0))
	var b_target: Dictionary = manager.call("_find_tag_resize_target", Vector2(102.0, 16.0))
	check_eq(a_target.get("tag_ui"), tag_a, "touching inside A must resize A's right edge")
	check_eq(
		b_target.get("tag_ui"),
		tag_b,
		"touching inside B must resize B's left edge even when the 44 pt hit zones overlap",
	)

	manager.free()
	timeline.queue_free()


func test_tag_resize_suppresses_ios_emulated_mouse_without_disabling_physical_pointer() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(
		src,
		"event is InputEventMouse and event.device == -1",
		"Tag Finger resize must suppress only iOS mouse emulation",
	)
	check_has(
		src,
		"_find_tag_resize_target(event.position)",
		"mouse emulation must only be suppressed over a Tag resize edge",
	)


func test_unlink_with_fresh_texture_detaches_both_image_and_texture_identity() -> void:
	var base_image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	var linked_image := ImageExtended.new()
	linked_image.copy_from_custom(base_image, false)
	var cel_a := PixelCel.new(linked_image)
	var cel_b := PixelCel.new()

	cel_b.set_content(cel_a.get_content(), cel_a.image_texture)
	check_true(cel_b.get_content() == cel_a.get_content(), "linked cels must share image content")
	check_true(cel_b.image_texture == cel_a.image_texture, "linked cels must share texture identity")

	var detached_content = cel_b.copy_content()
	cel_b.set_content(detached_content, ImageTexture.new())
	check_true(cel_b.get_content() != cel_a.get_content(), "Unlink must deep-copy pixel content")
	check_true(cel_b.image_texture != cel_a.image_texture, "Unlink must detach texture identity too")
	cel_b.image.set_pixel(0, 0, Color.RED)
	check_true(
		cel_a.image.get_pixel(0, 0) != Color.RED,
		"drawing into an unlinked cel must not mutate the remaining linked image branch",
	)


func test_rotation_reapplies_mobile_safe_area_when_window_size_changes() -> void:
	var src := FileAccess.get_file_as_string(MANAGER_SOURCE)
	check_has(
		src,
		"window.size_changed.connect(_on_window_size_changed)",
		"iPad runtime rotation must subscribe to Window.size_changed",
	)
	check_has(
		src,
		'Global.control.call_deferred("set_mobile_fullscreen_safe_area")',
		"a new portrait/landscape window size must recompute the Main safe-area geometry",
	)
