class_name AnimationTag
extends RefCounted
## A class for frame tag properties
##
## A tag indicates an animation of your sprite. Using several tags you can organize different
## animations of your sprite.[br]
## Here is an example of how a new tag may be created ([b]without[/b] any undo-redo functionality)
##[codeblock]
##func create_tag(tag_name: StringName, color: Color, from: int, to: int):
##    var tags_list = Global.current_project.animation_tags.duplicate()
##    var new_tag = AnimationTag.new(tag_name, color, from, to)
##    tags_list.append(new_tag)
##    # now make it the new animation_tags (so that the setter is called to update UI)
##    Global.current_project.animation_tags = tags_list
## [/codeblock]
## Here is an example of how a new tag may be created ([b]with[/b] undo-redo functionality)
## [codeblock]
##func create_tag(tag_name: StringName, color: Color, from: int, to: int):
##    var new_animation_tags: Array[AnimationTag] = []
##    # Loop through the tags to create new classes for them, so that they won't be the same
##    # as Global.current_project.animation_tags's classes. Needed for undo/redo to work properly.
##    for tag in Global.current_project.animation_tags:
##        new_animation_tags.append(tag.duplicate())
##
##    new_animation_tags.append(AnimationTag.new(tag_name, color, from, to))
##
##    # Handle Undo/Redo
##    Global.current_project.undo_redo.create_action("Adding a Tag")
##    Global.current_project.undo_redo.add_do_method(Global.general_redo)
##    Global.current_project.undo_redo.add_undo_method(Global.general_undo)
##    Global.current_project.undo_redo.add_do_property(
##        Global.current_project, "animation_tags", new_animation_tags
##    )
##    Global.current_project.undo_redo.add_undo_property(
##        Global.current_project, "animation_tags", Global.current_project.animation_tags
##    )
##    Global.current_project.undo_redo.commit_action()
## [/codeblock]

const CEL_SEPARATION := 0

var name: String  ## Name of tag
var color: Color  ## Color of tag
var from: int  ## First frame number in the tag (first frame in timeline is numbered 1)
var to: int  ## First frame number in the tag (first frame in timeline is numbered 1)
var user_data := ""  ## User defined data, set in the tag properties.


## Class Constructor (used as [code]AnimationTag.new(name, color, from, to)[/code])
func _init(_name: String, _color: Color, _from: int, _to: int) -> void:
	name = _name
	color = _color
	from = _from
	to = _to


func serialize() -> Dictionary:
	var dict := {"name": name, "color": color.to_html(), "from": from, "to": to}
	if not user_data.is_empty():
		dict["user_data"] = user_data
	return dict


func duplicate() -> AnimationTag:
	var new_tag := AnimationTag.new(name, color, from, to)
	new_tag.user_data = user_data
	return new_tag


func get_size() -> int:
	return to - from + 1


func has_frame(index: int) -> bool:
	return from <= (index + 1) and (index + 1) <= to


func frames_array() -> Array:
	return range(from - 1, to)


func _frame_span_metrics() -> Vector2:
	var timeline := Global.animation_timeline
	if is_instance_valid(timeline) and is_instance_valid(timeline.frame_hbox):
		var frame_hbox := timeline.frame_hbox
		var from_idx := from - 1
		var to_idx := to - 1
		if from_idx >= 0 and to_idx >= from_idx and to_idx < frame_hbox.get_child_count():
			var start_btn := frame_hbox.get_child(from_idx) as Control
			var end_btn := frame_hbox.get_child(to_idx) as Control
			if (
				is_instance_valid(start_btn)
				and is_instance_valid(end_btn)
				and start_btn.size.x > 0.0
				and end_btn.size.x > 0.0
			):
				var left_x := start_btn.position.x + 1.0
				var right_x := end_btn.position.x + end_btn.size.x - 1.0
				return Vector2(left_x, maxf(4.0, right_x - left_x))
	var cel_w: int = timeline.cel_size if is_instance_valid(timeline) else 36
	var tag_base_size := cel_w + CEL_SEPARATION
	return Vector2(
		float((from - 1) * tag_base_size + 1), float(maxi(4, get_size() * tag_base_size - 2))
	)


func get_position() -> Vector2:
	return Vector2(_frame_span_metrics().x, 1.0)


func get_minimum_size() -> int:
	return roundi(_frame_span_metrics().y)


static func sync_tag_scroll_alignment(
	tag_scroll: ScrollContainer,
	tag_spacer: Control,
	tag_container: Control,
	frame_hbox: Control,
	frame_scroll: Control,
	frame_scroll_bar: HScrollBar
) -> void:
	if not is_instance_valid(tag_scroll) or not is_instance_valid(frame_hbox):
		return
	var scroll_x := frame_scroll_bar.value if is_instance_valid(frame_scroll_bar) else 0.0
	var unscrolled_frame_x := frame_hbox.global_position.x + scroll_x
	var spacer_w := maxf(0.0, unscrolled_frame_x - tag_scroll.global_position.x)
	if is_instance_valid(tag_spacer):
		tag_spacer.custom_minimum_size.x = spacer_w
	if is_instance_valid(tag_container):
		tag_container.custom_minimum_size = Vector2(
			frame_hbox.size.x, tag_container.custom_minimum_size.y
		)
	var frame_view_w := frame_scroll.size.x if is_instance_valid(frame_scroll) else 0.0
	var extra_right := maxf(0.0, tag_scroll.size.x - spacer_w - frame_view_w)
	var hbox := tag_scroll.get_child(0) as Control if tag_scroll.get_child_count() > 0 else null
	if is_instance_valid(hbox):
		hbox.custom_minimum_size.x = spacer_w + frame_hbox.size.x + extra_right
	tag_scroll.scroll_horizontal = roundi(scroll_x)
	if is_instance_valid(tag_container):
		for tag_c: Control in tag_container.get_children():
			if tag_c.has_method(&"update_position_and_size"):
				tag_c.call(&"update_position_and_size")


static func sync_timeline_tag_scroll(timeline: Node) -> void:
	if not is_instance_valid(timeline):
		return
	sync_tag_scroll_alignment(
		timeline.get("tag_scroll_container") as ScrollContainer,
		timeline.get("tag_spacer") as Control,
		timeline.get("tag_container") as Control,
		timeline.get("frame_hbox") as Control,
		timeline.get("frame_scroll_container") as Control,
		timeline.get("frame_scroll_bar") as HScrollBar,
	)
