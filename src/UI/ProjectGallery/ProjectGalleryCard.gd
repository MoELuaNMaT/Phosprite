class_name ProjectGalleryCard
extends PanelContainer

signal pointer_down(path: String, position: Vector2, timestamp_msec: int)
signal pointer_up(path: String, position: Vector2, timestamp_msec: int)
signal pointer_cancel(path: String)

const Entry := preload("res://src/ProjectLibrary/ProjectLibraryEntry.gd")
const Tokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")
const Chrome := preload("res://src/UI/DesignSystem/PhospriteStage2Chrome.gd")
const DRAG_CANCEL_DISTANCE := 24.0
const SYNTHETIC_MOUSE_SUPPRESSION_MSEC := 500
const SYNTHETIC_MOUSE_SUPPRESSION_DISTANCE := 32.0
const STATUS_NORMAL_COLOR := Color(0.721569, 0.733333, 0.756863, 1.0)
const STATUS_ERROR_COLOR := Color(1.0, 0.45, 0.42, 1.0)

var entry: ProjectLibraryEntry
var thumbnail_loaded := false
var selected := false
var multiselect_active := false
var interaction_enabled := true
var _pointer_active := false
var _pointer_origin := Vector2.ZERO
var _last_touch_msec := -1
var _last_touch_position := Vector2.ZERO
var _pixel_mode: StringName = Tokens.LEGACY
var _display_title := ""
var _legacy_styles: Dictionary = {}
var _legacy_colors: Dictionary = {}
var _legacy_thumbnail_filter := CanvasItem.TEXTURE_FILTER_PARENT_NODE
var _empty_style := StyleBoxEmpty.new()
var _tight_label_style := StyleBoxEmpty.new()

@onready var visual_root := %VisualRoot as Control
@onready var content_box := $VisualRoot/Content as VBoxContainer
@onready var info_block := %InfoBlock as VBoxContainer
@onready var thumbnail_frame := %ThumbnailFrame as Control
@onready var title_strip := %ProjectTitleStrip as PanelContainer
@onready var title_label := %ProjectTitle as Label
@onready var thumbnail_rect := %Thumbnail as TextureRect
@onready var thumbnail_status := %ThumbnailStatus as Label
@onready var metadata_box := %Metadata as VBoxContainer
@onready var size_label := %CanvasSize as Label
@onready var modified_label := %ModifiedTime as Label
@onready var selection_outline := %SelectionOutline as Panel
@onready var selection_check := %SelectionCheck as Label
@onready var selection_badge := %SelectionBadge as PanelContainer
@onready var selection_badge_mark := %SelectionBadgeMark as Label


func _ready() -> void:
	for style in [_empty_style, _tight_label_style]:
		style.content_margin_left = 0.0
		style.content_margin_top = 0.0
		style.content_margin_right = 0.0
		style.content_margin_bottom = 0.0
	_legacy_thumbnail_filter = thumbnail_rect.texture_filter
	_legacy_styles = {
		"card": get_theme_stylebox(&"panel"),
		"thumbnail": thumbnail_frame.get_theme_stylebox(&"panel"),
		"selection": selection_outline.get_theme_stylebox(&"panel"),
	}
	_legacy_colors = {
		"size": size_label.get_theme_color(&"font_color"),
		"modified": modified_label.get_theme_color(&"font_color"),
		"title_check": selection_check.get_theme_color(&"font_color"),
	}


func set_display_title(value: String) -> void:
	_display_title = value
	if is_instance_valid(title_label):
		title_label.text = value


func set_multiselect_mode(enabled: bool) -> void:
	multiselect_active = enabled
	_sync_stage2_selection()


## Set by the Gallery, never by project serialization. Legacy palettes keep
## their preexisting scene resources. The image itself remains untouched.
func apply_stage2_theme(mode: StringName) -> void:
	if not is_node_ready():
		return
	_pixel_mode = mode
	var is_pixel := mode != Tokens.LEGACY
	title_strip.visible = is_pixel
	if not is_pixel:
		thumbnail_rect.texture_filter = _legacy_thumbnail_filter
		add_theme_stylebox_override(&"panel", _legacy_styles["card"])
		thumbnail_frame.add_theme_stylebox_override(&"panel", _legacy_styles["thumbnail"])
		selection_outline.add_theme_stylebox_override(&"panel", _legacy_styles["selection"])
		size_label.add_theme_color_override(&"font_color", _legacy_colors["size"])
		modified_label.add_theme_color_override(&"font_color", _legacy_colors["modified"])
		selection_check.add_theme_color_override(&"font_color", _legacy_colors["title_check"])
		selection_check.visible = selected
		selection_badge.visible = false
		title_strip.remove_theme_stylebox_override(&"panel")
		title_label.remove_theme_color_override(&"font_color")
		for label in [title_label, size_label, modified_label]:
			label.remove_theme_stylebox_override(&"normal")
			label.remove_theme_font_size_override(&"font_size")
		content_box.offset_left = 8.0
		content_box.offset_top = 8.0
		content_box.offset_right = -8.0
		content_box.offset_bottom = -8.0
		content_box.add_theme_constant_override(&"separation", 8)
		info_block.add_theme_constant_override(&"separation", 2)
		metadata_box.add_theme_constant_override(&"separation", 2)
	else:
		# Clean minimal grid item: zero outer tile chrome, transparent square preview on top,
		# project name + dimensions + timestamp tightly stacked below.
		content_box.offset_left = 0.0
		content_box.offset_top = 0.0
		content_box.offset_right = 0.0
		content_box.offset_bottom = 0.0
		content_box.add_theme_constant_override(&"separation", Tokens.SPACE_XS)
		info_block.add_theme_constant_override(&"separation", 1)
		metadata_box.add_theme_constant_override(&"separation", 0)

		# Only the thumbnail image is pixel-filtered. UI text remains antialiased.
		thumbnail_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		title_label.add_theme_font_size_override(&"font_size", 14)
		size_label.add_theme_font_size_override(&"font_size", 12)
		modified_label.add_theme_font_size_override(&"font_size", 11)
		for label in [title_label, size_label, modified_label]:
			label.add_theme_stylebox_override(&"normal", _tight_label_style)
		title_strip.add_theme_stylebox_override(&"panel", _empty_style)
		selection_check.visible = false
	_sync_stage2_selection()


func _sync_stage2_selection() -> void:
	if not is_node_ready():
		return
	if _pixel_mode == Tokens.LEGACY:
		selection_check.visible = selected
		selection_badge.visible = false
		return

	# Keep outer card container visually transparent (no heavy tile/card shell) while retaining
	# a StyleBoxTexture resource for theme-contract compatibility.
	var clear_shell := PhospritePixelStyle.make_style(
		Tokens.TIER_S, Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT, false, 1
	)
	if clear_shell != null:
		clear_shell.content_margin_left = 0.0
		clear_shell.content_margin_top = 0.0
		clear_shell.content_margin_right = 0.0
		clear_shell.content_margin_bottom = 0.0
		add_theme_stylebox_override(&"panel", clear_shell)

	# Transparent preview well so transparent pixel canvases show their true alpha against
	# the gallery ground instead of a forced white card backing; crisp accent outline on select.
	var unit := clampi(Global.pixel_ui_unit, 1, 3)
	var frame_border := (
		Tokens.color(_pixel_mode, &"accent_primary") if selected else Color.TRANSPARENT
	)
	var frame_style := PhospritePixelStyle.make_style(
		Tokens.TIER_M, Color.TRANSPARENT, frame_border, Color.TRANSPARENT, false, unit
	)
	if frame_style != null:
		frame_style.content_margin_left = 4.0
		frame_style.content_margin_top = 4.0
		frame_style.content_margin_right = 4.0
		frame_style.content_margin_bottom = 4.0
		thumbnail_frame.add_theme_stylebox_override(&"panel", frame_style)

	# Clean light typography underneath the preview against the darker gallery background
	title_label.add_theme_color_override(
		&"font_color",
		(
			Tokens.color(_pixel_mode, &"accent_primary")
			if selected
			else Tokens.color(_pixel_mode, &"gallery_title_text")
		)
	)
	size_label.add_theme_color_override(
		&"font_color", Tokens.color(_pixel_mode, &"gallery_meta_text")
	)
	modified_label.add_theme_color_override(
		&"font_color", Tokens.color(_pixel_mode, &"gallery_meta_text")
	)

	selection_outline.add_theme_stylebox_override(&"panel", _empty_style)
	selection_check.visible = false

	# Clean checkbox badge inside top-right corner of preview frame during select mode
	var show_checkbox := multiselect_active or selected
	selection_badge.visible = show_checkbox
	if show_checkbox:
		var badge_bg := &"accent_primary" if selected else &"gallery_thumb_bg"
		var badge_border := &"accent_primary" if selected else &"gallery_meta_text"
		selection_badge.add_theme_stylebox_override(
			&"panel",
			Chrome.make_shell(_pixel_mode, Tokens.TIER_S, badge_bg, false, badge_border, &"")
		)
		selection_badge_mark.visible = selected
		selection_badge_mark.add_theme_color_override(
			&"font_color", Tokens.color(_pixel_mode, &"text_on_accent")
		)


func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED or not is_node_ready() or entry == null:
		return
	if entry.health_state == Entry.HealthState.CORRUPTED:
		_set_thumbnail_status(tr("Corrupted"), true)
		size_label.text = tr("Unreadable project")
	elif not thumbnail_loaded:
		_set_thumbnail_status(tr("Loading preview…"), false)
	elif thumbnail_rect.texture == null:
		_set_thumbnail_status(tr("Preview unavailable"), true)
	modified_label.text = _format_modified_time(entry.modified_time)


func bind(project_entry: ProjectLibraryEntry) -> void:
	entry = project_entry
	thumbnail_loaded = false
	thumbnail_rect.texture = null
	set_selected(false)
	if entry.health_state == Entry.HealthState.CORRUPTED:
		_set_thumbnail_status(tr("Corrupted"), true)
		size_label.text = tr("Unreadable project")
		modified_label.text = _format_modified_time(entry.modified_time)
		thumbnail_loaded = true
		return
	_set_thumbnail_status(tr("Loading preview…"), false)
	size_label.text = "%d × %d px" % [entry.canvas_size.x, entry.canvas_size.y]
	modified_label.text = _format_modified_time(entry.modified_time)


func set_card_width(card_width: float) -> void:
	var width := maxf(card_width, 1.0)
	if _pixel_mode == Tokens.LEGACY:
		var legacy_thumb := maxf(width - 16.0, 1.0)
		custom_minimum_size = Vector2(width, width + 54.0)
		thumbnail_frame.custom_minimum_size = Vector2(legacy_thumb, legacy_thumb)
		return
	# Clean grid item: 1:1 preview + 4px gap + tight title/size/time (~52px) = width + 58
	custom_minimum_size = Vector2(width, width + 58.0)
	thumbnail_frame.custom_minimum_size = Vector2(width, width)


func set_thumbnail(image: Image) -> void:
	thumbnail_loaded = true
	if image == null or image.is_empty():
		thumbnail_rect.texture = null
		_set_thumbnail_status(tr("Preview unavailable"), true)
		return
	thumbnail_rect.texture = ImageTexture.create_from_image(image)
	thumbnail_status.visible = false


func set_interaction_enabled(value: bool) -> void:
	interaction_enabled = value
	if not value:
		_pointer_active = false


func prepare_reflow(old_rect: Rect2) -> void:
	if not is_instance_valid(visual_root):
		return
	var new_rect := get_global_rect()
	if new_rect.size.x <= 0.0 or new_rect.size.y <= 0.0:
		return
	visual_root.position = old_rect.position - new_rect.position
	visual_root.scale = Vector2(
		maxf(old_rect.size.x / new_rect.size.x, 0.01), maxf(old_rect.size.y / new_rect.size.y, 0.01)
	)


func play_reflow(duration: float) -> Tween:
	if not is_instance_valid(visual_root):
		return null
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual_root, "position", Vector2.ZERO, duration)
	tween.tween_property(visual_root, "scale", Vector2.ONE, duration)
	return tween


func reset_visual_transform() -> void:
	if not is_instance_valid(visual_root):
		return
	visual_root.position = Vector2.ZERO
	visual_root.scale = Vector2.ONE


func clear_transient_press_state() -> void:
	_pointer_active = false
	release_focus()


static func should_suppress_mouse_after_touch(
	now_msec: int, last_touch_msec: int, mouse_position: Vector2, last_touch_position: Vector2
) -> bool:
	if last_touch_msec < 0:
		return false
	var elapsed := now_msec - last_touch_msec
	if elapsed < 0 or elapsed > SYNTHETIC_MOUSE_SUPPRESSION_MSEC:
		return false
	return mouse_position.distance_to(last_touch_position) <= SYNTHETIC_MOUSE_SUPPRESSION_DISTANCE


func set_selected(value: bool) -> void:
	selected = value
	if is_instance_valid(selection_outline):
		selection_outline.visible = value
	if is_instance_valid(selection_check):
		selection_check.visible = value and _pixel_mode == Tokens.LEGACY
	_sync_stage2_selection()


func _gui_input(event: InputEvent) -> void:
	if entry == null or not interaction_enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_remember_touch(touch.position)
		if touch.pressed:
			_begin_pointer(touch.position)
		else:
			_finish_pointer(touch.position)
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_remember_touch(drag.position)
		_maybe_cancel_pointer(drag.position)
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if should_suppress_mouse_after_touch(
			Time.get_ticks_msec(), _last_touch_msec, mouse_button.position, _last_touch_position
		):
			accept_event()
			return
		if mouse_button.pressed:
			_begin_pointer(mouse_button.position)
		else:
			_finish_pointer(mouse_button.position)
		return
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if (mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_maybe_cancel_pointer(mouse_motion.position)


func _remember_touch(local_position: Vector2) -> void:
	_last_touch_msec = Time.get_ticks_msec()
	_last_touch_position = local_position


func _begin_pointer(local_position: Vector2) -> void:
	_pointer_active = true
	_pointer_origin = local_position
	pointer_down.emit(entry.path, _to_global_position(local_position), Time.get_ticks_msec())


func _finish_pointer(local_position: Vector2) -> void:
	if not _pointer_active:
		return
	_pointer_active = false
	pointer_up.emit(entry.path, _to_global_position(local_position), Time.get_ticks_msec())


func _maybe_cancel_pointer(local_position: Vector2) -> void:
	if not _pointer_active or local_position.distance_to(_pointer_origin) <= DRAG_CANCEL_DISTANCE:
		return
	_pointer_active = false
	pointer_cancel.emit(entry.path)


func _to_global_position(local_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * local_position


func _set_thumbnail_status(message: String, is_error: bool) -> void:
	thumbnail_status.text = message
	thumbnail_status.visible = true
	thumbnail_status.add_theme_color_override(
		"font_color",
		(
			STATUS_ERROR_COLOR
			if is_error
			else (
				Tokens.color(_pixel_mode, &"text_muted")
				if _pixel_mode != Tokens.LEGACY
				else STATUS_NORMAL_COLOR
			)
		)
	)


func _format_modified_time(unix_time: int) -> String:
	if unix_time <= 0:
		return tr("Unknown date")
	var time_zone := Time.get_time_zone_from_system()
	var local_unix_time := unix_time + int(time_zone.get("bias", 0)) * 60
	var value := Time.get_datetime_dict_from_unix_time(local_unix_time)
	return (
		"%04d-%02d-%02d  %02d:%02d"
		% [
			int(value.get("year", 0)),
			int(value.get("month", 0)),
			int(value.get("day", 0)),
			int(value.get("hour", 0)),
			int(value.get("minute", 0)),
		]
	)
