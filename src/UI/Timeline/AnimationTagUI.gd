extends Control

enum Drag { NONE, FROM, TO }

const Stage4 := preload("res://src/UI/DesignSystem/PhospriteStage4Chrome.gd")
const PhospriteTokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")

var tag: AnimationTag
var dragging_tag: AnimationTag
var dragged_initial := 0
var is_dragging := Drag.NONE

@onready var line_2d := $Line2D as Line2D
@onready var tag_properties := (
	Global.control.find_child("TagProperties") as ConfirmationDialog
	if is_instance_valid(Global.control)
	else null
)


func _enter_tree() -> void:
	if not Themes.theme_switched.is_connected(_apply_tag_chrome):
		Themes.theme_switched.connect(_apply_tag_chrome)


func _exit_tree() -> void:
	if Themes.theme_switched.is_connected(_apply_tag_chrome):
		Themes.theme_switched.disconnect(_apply_tag_chrome)


func _ready() -> void:
	if not is_instance_valid(tag):
		return
	$Button.text = tag.name
	_apply_tag_chrome()
	update_position_and_size()


func _resolved_range_line_color() -> Color:
	var mode := Stage4.active_mode()
	if mode != PhospriteTokens.LEGACY:
		return PhospriteTokens.color(mode, &"accent_primary")
	return tag.color if is_instance_valid(tag) else Color("#E85D3F")


func _apply_tag_chrome() -> void:
	if not is_node_ready() or not is_instance_valid(line_2d):
		return
	var mode := Stage4.active_mode()
	var pixel := mode != PhospriteTokens.LEGACY
	var line_color := _resolved_range_line_color()
	line_2d.default_color = line_color
	line_2d.width = 2.0 if pixel else 1.0
	var btn := get_node_or_null(^"Button") as Button
	if btn != null and is_instance_valid(tag):
		btn.modulate = Color.WHITE if pixel else tag.color
		if pixel:
			for col_name in [
				&"font_color",
				&"font_hover_color",
				&"font_pressed_color",
				&"font_focus_color",
			]:
				btn.add_theme_color_override(col_name, line_color)
		else:
			for col_name in [
				&"font_color",
				&"font_hover_color",
				&"font_pressed_color",
				&"font_focus_color",
			]:
				if btn.has_theme_color_override(col_name):
					btn.remove_theme_color_override(col_name)


func update_position_and_size(from_tag := tag) -> void:
	if not is_instance_valid(line_2d) or not is_instance_valid(Global.animation_timeline):
		return
	position = from_tag.get_position()
	custom_minimum_size.x = from_tag.get_minimum_size()
	size.x = custom_minimum_size.x
	var point_2 := line_2d.get_point_position(2)
	var point_3 := line_2d.get_point_position(3)
	point_2.x = custom_minimum_size.x
	point_3.x = custom_minimum_size.x
	line_2d.set_point_position(2, point_2)
	line_2d.set_point_position(3, point_3)


func _on_button_pressed() -> void:
	var tag_id := Global.current_project.animation_tags.find(tag)
	tag_properties.show_dialog(Rect2i(), tag_id, true)


func _resize_tag(resize: Drag, value: int) -> void:
	var new_animation_tags: Array[AnimationTag] = []
	# Loop through the tags to create new classes for them, so that they won't be the same
	# as Global.current_project.animation_tags's classes. Needed for undo/redo to work properly.
	for frame_tag in Global.current_project.animation_tags:
		new_animation_tags.append(frame_tag.duplicate())

	var tag_id := Global.current_project.animation_tags.find(tag)
	# On iOS, one physical touch may also produce a mouse-emulation callback. The first resize
	# commit replaces animation_tags with duplicated resources, so a second callback from the old
	# Tag UI can hold a stale resource reference. Array.find() then returns -1; negative Array
	# indices are valid, so using it would resize an unrelated Tag at the end of the array.
	if tag_id < 0 or tag_id >= new_animation_tags.size():
		return
	if resize == Drag.FROM:
		if new_animation_tags[tag_id].from == value:
			return
		new_animation_tags[tag_id].from = value
	elif resize == Drag.TO:
		if new_animation_tags[tag_id].to == value:
			return
		new_animation_tags[tag_id].to = value
	else:
		return

	# Handle Undo/Redo
	Global.current_project.undo_redo.create_action("Resize Frame Tag")
	Global.current_project.undo_redo.add_do_method(Global.general_redo)
	Global.current_project.undo_redo.add_undo_method(Global.general_undo)
	Global.current_project.undo_redo.add_do_property(
		Global.current_project, &"animation_tags", new_animation_tags
	)
	Global.current_project.undo_redo.add_undo_property(
		Global.current_project, &"animation_tags", Global.current_project.animation_tags
	)
	Global.current_project.undo_redo.commit_action()


func _on_resize_from_gui_input(event: InputEvent) -> void:
	var cel_size: int = Global.animation_timeline.cel_size
	if event is InputEventMouseButton:
		if event.pressed:
			is_dragging = Drag.FROM
			dragging_tag = tag.duplicate()
			dragged_initial = global_position.x
		else:
			if is_dragging != Drag.FROM or not is_instance_valid(dragging_tag):
				return
			_resize_tag(is_dragging, dragging_tag.from)
			is_dragging = Drag.NONE
			dragging_tag = null
	elif event is InputEventMouseMotion:
		if is_dragging == Drag.FROM:
			var dragged_offset := snappedi(event.global_position.x, cel_size)
			var diff := roundi(float(dragged_offset - dragged_initial) / cel_size)
			dragging_tag.from = clampi(tag.from + diff, 1, tag.to)
			update_position_and_size(dragging_tag)


func _on_resize_to_gui_input(event: InputEvent) -> void:
	var cel_size: int = Global.animation_timeline.cel_size
	if event is InputEventMouseButton:
		if event.pressed:
			is_dragging = Drag.TO
			dragging_tag = tag.duplicate()
			dragged_initial = global_position.x + size.x
		else:
			if is_dragging != Drag.TO or not is_instance_valid(dragging_tag):
				return
			_resize_tag(is_dragging, dragging_tag.to)
			is_dragging = Drag.NONE
			dragging_tag = null
	elif event is InputEventMouseMotion:
		if is_dragging == Drag.TO:
			var dragged_offset := snappedi(event.global_position.x, cel_size)
			var diff := roundi(float(dragged_offset - dragged_initial) / cel_size)
			dragging_tag.to = clampi(tag.to + diff, tag.from, Global.current_project.frames.size())
			update_position_and_size(dragging_tag)
