class_name TimelineHeaderControls
extends HBoxContainer

const ITEM_SEPARATION := 4.0
const OVERFLOW_POPUP_MIN_WIDTH := 160.0
const OVERFLOW_POPUP_MAX_WIDTH := 320.0

var text_server := TextServerManager.get_primary_interface()
var _available_width := INF
var _applying_overflow := false
var _managed_items: Array[Control] = []
var _item_widths: Dictionary = {}

@onready var inline_row := %InlineRow as HBoxContainer
@onready var global_tool_options := %GlobalToolOptions as Control
@onready var separator := %Separator as VSeparator
@onready var undo_button := %Undo as Button
@onready var redo_button := %Redo as Button
@onready var frame_group := %FrameGroup as HBoxContainer
@onready var frame_mark := %CurrentFrameMark as Label
@onready var overflow_button := %OverflowButton as Button
@onready var mode_switch_button := %ModeSwitch as Button
@onready var overflow_panel := %OverflowPanel as PopupPanel
@onready var overflow_content := %OverflowContent as VBoxContainer


func _ready() -> void:
	undo_button.pressed.connect(_on_undo_pressed)
	redo_button.pressed.connect(_on_redo_pressed)
	overflow_button.pressed.connect(_on_overflow_pressed)
	mode_switch_button.toggled.connect(_on_mode_switch_toggled)
	if (
		is_instance_valid(Global.animation_timeline)
		and not Global.animation_timeline.timeline_mode_changed.is_connected(
			_on_timeline_mode_changed
		)
	):
		Global.animation_timeline.timeline_mode_changed.connect(_on_timeline_mode_changed)
	_managed_items = [global_tool_options, undo_button, redo_button, frame_group]
	for item in _managed_items:
		_item_widths[item] = item.get_combined_minimum_size().x
	if not Global.project_switched.is_connected(_update_frame_mark):
		Global.project_switched.connect(_update_frame_mark)
	if not Global.cel_switched.is_connected(_update_frame_mark):
		Global.cel_switched.connect(_update_frame_mark)
	_update_frame_mark()
	_sync_mode_switch()
	_apply_overflow_layout()


func _exit_tree() -> void:
	if Global.project_switched.is_connected(_update_frame_mark):
		Global.project_switched.disconnect(_update_frame_mark)
	if Global.cel_switched.is_connected(_update_frame_mark):
		Global.cel_switched.disconnect(_update_frame_mark)
	if (
		is_instance_valid(Global.animation_timeline)
		and Global.animation_timeline.timeline_mode_changed.is_connected(_on_timeline_mode_changed)
	):
		Global.animation_timeline.timeline_mode_changed.disconnect(_on_timeline_mode_changed)


func set_available_width(width: float) -> void:
	_available_width = maxf(0.0, width)
	if is_node_ready():
		_apply_overflow_layout()


func get_available_width() -> float:
	return _available_width


func has_overflow() -> bool:
	return overflow_button.visible


func _apply_overflow_layout() -> void:
	if _applying_overflow or not is_instance_valid(inline_row):
		return
	_applying_overflow = true
	if overflow_panel.visible:
		overflow_panel.hide()

	var all_items: Array[Control] = []
	all_items.assign(_managed_items)
	var all_width := _inline_width(all_items)
	var keep_inline: Array[Control] = []
	var fixed_right_width := mode_switch_button.get_combined_minimum_size().x + ITEM_SEPARATION
	var content_width := maxf(0.0, _available_width - fixed_right_width)
	var needs_overflow := all_width > content_width

	if not needs_overflow:
		keep_inline = all_items
	else:
		var overflow_width := overflow_button.get_combined_minimum_size().x
		var budget := maxf(0.0, content_width - overflow_width - ITEM_SEPARATION)
		# Preserve the commands that are most useful during animation work.
		# The large Global Tool Options group overflows first on narrow windows.
		var priority: Array[Control] = [undo_button, redo_button, frame_group, global_tool_options]
		for item in priority:
			var candidate: Array[Control] = []
			candidate.assign(keep_inline)
			candidate.append(item)
			if _inline_width(candidate) <= budget:
				keep_inline.append(item)

	for item in _managed_items:
		_move_item(item, inline_row if keep_inline.has(item) else overflow_content)

	_restore_item_order(inline_row)
	_restore_item_order(overflow_content)
	var global_inline := keep_inline.has(global_tool_options)
	var other_inline := keep_inline.size() > (1 if global_inline else 0)
	separator.visible = global_inline and other_inline
	overflow_button.visible = needs_overflow
	overflow_button.disabled = not needs_overflow
	queue_sort()
	update_minimum_size()
	_applying_overflow = false


func _inline_width(items: Array[Control]) -> float:
	if items.is_empty():
		return 0.0
	var width := 0.0
	for item in items:
		width += float(_item_widths.get(item, item.get_combined_minimum_size().x))
	width += ITEM_SEPARATION * maxf(0.0, float(items.size() - 1))
	if items.has(global_tool_options) and items.size() > 1:
		width += separator.get_combined_minimum_size().x + ITEM_SEPARATION * 2.0
	return width


func _move_item(item: Control, target: Node) -> void:
	if item.get_parent() == target:
		return
	var parent := item.get_parent()
	if parent != null:
		parent.remove_child(item)
	target.add_child(item)


func _restore_item_order(parent: Node) -> void:
	var index := 0
	for item in _managed_items:
		if item.get_parent() != parent:
			continue
		parent.move_child(item, index)
		index += 1
	if parent == inline_row and separator.get_parent() == inline_row:
		var global_index := (
			global_tool_options.get_index()
			if global_tool_options.get_parent() == inline_row
			else -1
		)
		if global_index >= 0:
			inline_row.move_child(separator, global_index + 1)


func _on_overflow_pressed() -> void:
	if not overflow_button.visible:
		return
	var content_size := overflow_content.get_combined_minimum_size()
	var popup_width := clampf(
		content_size.x + 12.0, OVERFLOW_POPUP_MIN_WIDTH, OVERFLOW_POPUP_MAX_WIDTH
	)
	var popup_height := maxf(44.0, content_size.y + 12.0)
	overflow_panel.size = Vector2i(ceili(popup_width), ceili(popup_height))
	var popup_position := (
		overflow_button.global_position
		+ Vector2(overflow_button.size.x - popup_width, overflow_button.size.y)
	)
	overflow_panel.popup_on_parent(Rect2i(Vector2i(popup_position.round()), overflow_panel.size))


func _on_mode_switch_toggled(single_frame: bool) -> void:
	if not is_instance_valid(Global.animation_timeline):
		return
	var mode := (
		AnimationTimeline.TimelineMode.SINGLE_FRAME
		if single_frame
		else AnimationTimeline.TimelineMode.ANIMATION
	)
	Global.animation_timeline.set_timeline_mode(mode)


func _on_timeline_mode_changed(_mode: int) -> void:
	_sync_mode_switch()
	_apply_overflow_layout()


func _sync_mode_switch() -> void:
	if not is_instance_valid(Global.animation_timeline):
		mode_switch_button.set_pressed_no_signal(false)
		mode_switch_button.text = "Animation"
		return
	var single_frame: bool = (
		Global.animation_timeline.get_timeline_mode() == AnimationTimeline.TimelineMode.SINGLE_FRAME
	)
	mode_switch_button.set_pressed_no_signal(single_frame)
	mode_switch_button.text = "Single frame" if single_frame else "Animation"
	mode_switch_button.tooltip_text = (
		"Switch to animation timeline" if single_frame else "Switch to single-frame layer view"
	)


func _on_undo_pressed() -> void:
	if Global.current_project != null:
		Global.current_project.commit_undo()


func _on_redo_pressed() -> void:
	if Global.current_project != null:
		Global.current_project.commit_redo()


func _update_frame_mark() -> void:
	var project := Global.current_project
	if project == null:
		frame_mark.text = "-/-"
		return
	var current_frame := text_server.format_number(str(project.current_frame + 1))
	var frame_count := text_server.format_number(str(project.frames.size()))
	frame_mark.text = "%s/%s" % [current_frame, frame_count]
