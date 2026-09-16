extends "res://tests/test_base.gd"

const TAG_UI_SOURCE := "res://src/UI/Timeline/AnimationTagUI.gd"


func test_stale_tag_reference_cannot_index_an_unrelated_tag() -> void:
	var src := FileAccess.get_file_as_string(TAG_UI_SOURCE)
	var lookup_pos := src.find("var tag_id := Global.current_project.animation_tags.find(tag)")
	var guard_pos := src.find("if tag_id < 0 or tag_id >= new_animation_tags.size():", lookup_pos)
	var from_write_pos := src.find("new_animation_tags[tag_id].from = value", guard_pos)
	var to_write_pos := src.find("new_animation_tags[tag_id].to = value", guard_pos)
	check_true(lookup_pos >= 0, "resize must resolve the live Tag identity before writing")
	check_true(guard_pos > lookup_pos, "stale/missing Tag identity must be rejected")
	check_true(from_write_pos > guard_pos, "FROM resize must only write after the stale-target guard")
	check_true(to_write_pos > guard_pos, "TO resize must only write after the stale-target guard")


func test_unowned_mouse_release_cannot_commit_a_resize() -> void:
	var src := FileAccess.get_file_as_string(TAG_UI_SOURCE)
	check_has(
		src,
		"if is_dragging != Drag.FROM or not is_instance_valid(dragging_tag):",
		"FROM release without a matching live drag must be ignored",
	)
	check_has(
		src,
		"if is_dragging != Drag.TO or not is_instance_valid(dragging_tag):",
		"TO release without a matching live drag must be ignored",
	)
