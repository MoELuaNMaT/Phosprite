extends "res://tests/test_base.gd"

const E1_E2_MANAGER_SOURCE := "res://src/UI/Timeline/TimelineTouchSelectionManager.gd"
const E3_E4_MANAGER_SOURCE := "res://src/UI/Timeline/TimelinePanelTouchManager.gd"
const TAG_UI_SOURCE := "res://src/UI/Timeline/AnimationTagUI.gd"
const FINAL_GATE_DOC := "res://docs/p1_e5_timeline_final_gate_zh.md"


func test_e5_both_timeline_touch_managers_parse_cleanly() -> void:
	for path in [E1_E2_MANAGER_SOURCE, E3_E4_MANAGER_SOURCE]:
		var script := GDScript.new()
		script.source_code = FileAccess.get_file_as_string(path)
		check_eq(script.reload(), OK, "%s must compile for the final Timeline gate" % path)


func test_e5_touch_ownership_remains_separated_between_e1_e2_and_e3_e4() -> void:
	var selection_src := FileAccess.get_file_as_string(E1_E2_MANAGER_SOURCE)
	var panel_src := FileAccess.get_file_as_string(E3_E4_MANAGER_SOURCE)
	check_true(
		not ("TimelinePanelTouchManager" in selection_src),
		"E1/E2 selection-reorder manager must not depend on the E3/E4 panel manager",
	)
	check_true(
		not ("TimelineTouchSelectionManager" in panel_src),
		"E3/E4 panel manager must not take ownership of E1/E2 selection-reorder",
	)
	check_true(
		not ("undo_redo" in selection_src),
		"E1/E2 touch adapter must keep native controls as transaction owners",
	)
	check_true(
		not ('&"animation_tags"' in panel_src),
		"E3/E4 touch adapter must keep AnimationTagUI as the Tag transaction owner",
	)


func test_e5_tag_resize_keeps_the_stale_target_safety_guard() -> void:
	var src := FileAccess.get_file_as_string(TAG_UI_SOURCE)
	var lookup_pos := src.find("var tag_id := Global.current_project.animation_tags.find(tag)")
	var guard_pos := src.find("if tag_id < 0 or tag_id >= new_animation_tags.size():", lookup_pos)
	var write_pos := src.find("new_animation_tags[tag_id].from = value", guard_pos)
	check_true(lookup_pos >= 0, "Tag resize must resolve the live Tag identity")
	check_true(guard_pos > lookup_pos, "stale Tag identity must be rejected before writing")
	check_true(write_pos > guard_pos, "Tag resize must only write after stale-target validation")


func test_e5_final_gate_document_covers_the_required_continuous_workflow() -> void:
	check_file_exists(FINAL_GATE_DOC, "E5 must ship one target-iPad final-gate checklist")
	var src := FileAccess.get_file_as_string(FINAL_GATE_DOC)
	for required_case in [
		"单选 / 多选",
		"长按 reorder",
		"Frame Duration",
		"Tag resize",
		"近邻 / 重叠 Tag",
		"Link → Unlink",
		"Onion Skin",
		"Undo / Redo",
		"横屏",
		"竖屏",
	]:
		check_has(src, required_case, "E5 final gate must cover %s" % required_case)
