class_name TimelineHeaderControls
extends HBoxContainer

const ITEM_SEPARATION := 4.0
const OVERFLOW_POPUP_MIN_WIDTH := 160.0
const OVERFLOW_POPUP_MAX_WIDTH := 320.0
const Tokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")
const Stage4 := preload("res://src/UI/DesignSystem/PhospriteStage4Chrome.gd")
const QIcons := preload("res://src/UI/DesignSystem/PhospriteQIcons.gd")
const LEGACY_ICON_META := &"phosprite_legacy_header_icon"
const LEGACY_EXPAND_META := &"phosprite_legacy_header_expand"

var _available_width := INF
var _applying_overflow := false
var _managed_items: Array[Control] = []
var _item_widths: Dictionary = {}

@onready var inline_row := %InlineRow as HBoxContainer
@onready var global_tool_options := %GlobalToolOptions as Control
@onready var separator := %Separator as VSeparator
@onready var undo_button := %Undo as Button
@onready var redo_button := %Redo as Button
@onready var undo_history_button := %UndoHistory as Button
@onready var frame_group := %FrameGroup as HBoxContainer
@onready var frame_mark := %CurrentFrameMark as Label
@onready var overflow_button := %OverflowButton as Button
@onready var share_export_button := %ShareExport as Button
@onready var mode_switch_button := %ModeSwitch as Button
@onready var overflow_panel := %OverflowPanel as PopupPanel
@onready var overflow_content := %OverflowContent as VBoxContainer


func _notification(what: int) -> void:
	if (
		(what == NOTIFICATION_TRANSLATION_CHANGED or what == NOTIFICATION_THEME_CHANGED)
		and is_node_ready()
	):
		_sync_mode_switch()
		_refresh_item_widths()
		_apply_overflow_layout()


func _ready() -> void:
	if get_theme_constant(&"separation") != 6:
		add_theme_constant_override(&"separation", 6)
	undo_button.pressed.connect(_on_undo_pressed)
	redo_button.pressed.connect(_on_redo_pressed)
	undo_history_button.pressed.connect(_on_undo_history_pressed)
	overflow_button.pressed.connect(_on_overflow_pressed)
	share_export_button.pressed.connect(_on_share_export_pressed)
	mode_switch_button.toggled.connect(_on_mode_switch_toggled)
	if OS.get_name() == "iOS":
		share_export_button.custom_minimum_size = Vector2(44.0, 44.0)
	var timeline := Global.animation_timeline as AnimationTimeline
	if (
		is_instance_valid(timeline)
		and not timeline.timeline_mode_changed.is_connected(_on_timeline_mode_changed)
	):
		timeline.timeline_mode_changed.connect(_on_timeline_mode_changed)
	_managed_items = [
		global_tool_options, undo_button, redo_button, undo_history_button, frame_group
	]
	_refresh_item_widths()
	_connect_live_signals()
	_update_frame_mark()
	_refresh_phosprite_chrome()
	_sync_mode_switch()
	_apply_overflow_layout()


func _enter_tree() -> void:
	_connect_live_signals()
	if is_node_ready():
		_refresh_phosprite_chrome()


func _connect_live_signals() -> void:
	if not Global.project_switched.is_connected(_on_project_switched):
		Global.project_switched.connect(_on_project_switched)
	if not Global.cel_switched.is_connected(_update_frame_mark):
		Global.cel_switched.connect(_update_frame_mark)
	if not Themes.theme_switched.is_connected(_refresh_phosprite_chrome):
		Themes.theme_switched.connect(_refresh_phosprite_chrome)
	if not Global.pixel_ui_unit_changed.is_connected(_refresh_phosprite_chrome):
		Global.pixel_ui_unit_changed.connect(_refresh_phosprite_chrome)


func _exit_tree() -> void:
	if Global.project_switched.is_connected(_on_project_switched):
		Global.project_switched.disconnect(_on_project_switched)
	if Global.cel_switched.is_connected(_update_frame_mark):
		Global.cel_switched.disconnect(_update_frame_mark)
	if Themes.theme_switched.is_connected(_refresh_phosprite_chrome):
		Themes.theme_switched.disconnect(_refresh_phosprite_chrome)
	if Global.pixel_ui_unit_changed.is_connected(_refresh_phosprite_chrome):
		Global.pixel_ui_unit_changed.disconnect(_refresh_phosprite_chrome)
	var timeline := Global.animation_timeline as AnimationTimeline
	if (
		is_instance_valid(timeline)
		and timeline.timeline_mode_changed.is_connected(_on_timeline_mode_changed)
	):
		timeline.timeline_mode_changed.disconnect(_on_timeline_mode_changed)


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
	# Export must remain reachable even when every other command overflows.
	var fixed_right_width := (
		mode_switch_button.get_combined_minimum_size().x
		+ share_export_button.get_combined_minimum_size().x
		+ ITEM_SEPARATION * 2.0
	)
	var content_width := maxf(0.0, _available_width - fixed_right_width)
	var needs_overflow := all_width > content_width

	if not needs_overflow:
		keep_inline = all_items
	else:
		var overflow_width := overflow_button.get_combined_minimum_size().x
		var budget := maxf(0.0, content_width - overflow_width - ITEM_SEPARATION)
		# Preserve the commands that are most useful during animation work.
		# The large Global Tool Options group overflows first on narrow windows.
		var priority: Array[Control] = [
			undo_button, redo_button, undo_history_button, frame_group, global_tool_options
		]
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


## Font changes alter translated label widths. Never keep stale Latin-only
## measurements after the parent Workspace theme is replaced.
func _refresh_item_widths() -> void:
	for item in _managed_items:
		_item_widths[item] = item.get_combined_minimum_size().x


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


func _on_project_switched() -> void:
	_update_frame_mark()
	call_deferred("_sync_mode_switch")


func _on_mode_switch_toggled(single_frame: bool) -> void:
	var timeline := Global.animation_timeline as AnimationTimeline
	if not is_instance_valid(timeline):
		return
	var mode := (
		AnimationTimeline.TimelineMode.SINGLE_FRAME
		if single_frame
		else AnimationTimeline.TimelineMode.ANIMATION
	)
	timeline.set_timeline_mode(mode)


func _on_timeline_mode_changed(_mode: int) -> void:
	_sync_mode_switch()
	_apply_overflow_layout()


func _sync_mode_switch() -> void:
	var timeline := Global.animation_timeline as AnimationTimeline
	if not is_instance_valid(timeline):
		mode_switch_button.set_pressed_no_signal(false)
		mode_switch_button.text = tr("Animation")
		return
	var single_frame: bool = (
		timeline.get_timeline_mode() == AnimationTimeline.TimelineMode.SINGLE_FRAME
	)
	mode_switch_button.set_pressed_no_signal(single_frame)
	mode_switch_button.text = tr("Single frame") if single_frame else tr("Animation")
	mode_switch_button.tooltip_text = (
		tr("Switch to animation timeline")
		if single_frame
		else tr("Switch to single-frame layer view")
	)


## The editor File menu owns export setup; on iPad ExportDialog then opens
## the native Share Sheet after encoding, so keep one export implementation.
func _on_share_export_pressed() -> void:
	if Global.current_project == null or not is_instance_valid(Global.top_menu_container):
		return
	Global.top_menu_container.file_menu_id_pressed(Global.FileMenu.EXPORT_AS)


func _on_undo_pressed() -> void:
	if Global.current_project != null:
		Global.current_project.commit_undo()


func _on_redo_pressed() -> void:
	if Global.current_project != null:
		Global.current_project.commit_redo()


func _on_undo_history_pressed() -> void:
	if Global.current_project == null or not is_instance_valid(Global.top_menu_container):
		return
	# Reuse the original Edit command and dialog, including its history navigation.
	Global.top_menu_container.edit_menu_id_pressed(Global.EditMenu.UNDO_HISTORY)


func _update_frame_mark() -> void:
	var project := Global.current_project
	if project == null:
		frame_mark.text = "-/-"
		return
	# Frame indices are machine-style identifiers, not localized quantities.
	# Keep their digits predictable even if the active locale uses other numerals.
	var current_frame := str(project.current_frame + 1)
	var frame_count := str(project.frames.size())
	frame_mark.text = "%s/%s" % [current_frame, frame_count]


func _refresh_phosprite_chrome() -> void:
	if not is_node_ready():
		return
	var mode := Stage4.active_mode()
	var icon_map := {
		undo_button: &"undo",
		redo_button: &"redo",
		undo_history_button: &"undo_history",
		share_export_button: &"export_share",
		overflow_button: &"more_overflow",
	}
	for button in [
		undo_button,
		redo_button,
		undo_history_button,
		overflow_button,
		share_export_button,
		mode_switch_button,
	]:
		if not is_instance_valid(button):
			continue
		Stage4.style_button(button, mode)
		if icon_map.has(button):
			if mode != Tokens.LEGACY:
				if not button.has_meta(LEGACY_ICON_META):
					button.set_meta(LEGACY_ICON_META, button.icon)
					button.set_meta(LEGACY_EXPAND_META, button.expand_icon)
				var q_tex := (
					QIcons.standard_icon(icon_map[button])
					if button == share_export_button and OS.get_name() == "iOS"
					else QIcons.standard_icon_1x(icon_map[button])
				)
				if q_tex != null:
					button.icon = q_tex
					button.expand_icon = false
				Stage4.set_q_icon_colors(button, true)
				if button == overflow_button:
					button.text = ""
			else:
				Stage4.set_q_icon_colors(button, false)
				if button.has_meta(LEGACY_ICON_META):
					button.icon = button.get_meta(LEGACY_ICON_META) as Texture2D
					button.expand_icon = bool(button.get_meta(LEGACY_EXPAND_META))
					button.remove_meta(LEGACY_ICON_META)
					button.remove_meta(LEGACY_EXPAND_META)
				if button == overflow_button:
					button.text = "…"
	_refresh_item_widths()
	_apply_overflow_layout()
