class_name ProjectGallery
extends Control

signal project_open_requested(path: String)
signal new_project_requested
signal import_requested
signal exit_multiselect_requested
signal project_renamed(old_path: String, new_path: String, new_name: String)
signal projects_deleted(paths: PackedStringArray)
signal reveal_in_files_requested(path: String)
signal export_projects_requested(paths: PackedStringArray)

enum ActionMenuId { RENAME = 1, DUPLICATE, DELETE, EXPORT, REVEAL }

const StoragePolicy := preload("res://src/PlatformServices/StoragePolicy.gd")
const ProjectLibraryScript := preload("res://src/ProjectLibrary/ProjectLibrary.gd")
const GestureResolverScript := preload("res://src/UI/ProjectGallery/ProjectCardGestureResolver.gd")
const CARD_SCENE := preload("res://src/UI/ProjectGallery/ProjectGalleryCard.tscn")
const Tokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")
const Chrome := preload("res://src/UI/DesignSystem/PhospriteStage2Chrome.gd")
const Icons := preload("res://src/UI/DesignSystem/PhospriteStage2Icons.gd")

const LANDSCAPE_COLUMNS := 6
const PORTRAIT_COLUMNS := 4
const GRID_SIDE_MARGIN := 24.0
const GRID_SEPARATION := 18.0
const THUMBNAIL_PRELOAD_MARGIN := 96.0
const REFLOW_DURATION := 0.18
const FEEDBACK_DURATION := 2.4
const FEEDBACK_NORMAL_COLOR := Color(0.65, 0.68, 0.74, 1.0)
const FEEDBACK_ERROR_COLOR := Color(1.0, 0.45, 0.42, 1.0)

var library: ProjectLibrary
var entries: Array[ProjectLibraryEntry] = []
var refresh_count := 0
var scroll_reset_count := 0
var reflow_animation_count := 0
var multiselect_mode := false

var _cards: Array[ProjectGalleryCard] = []
var _selected_paths: Dictionary = {}
var _gesture_resolver := GestureResolverScript.new()
var _action_path := ""
var _rename_source_path := ""
var _pending_delete_paths := PackedStringArray()
var _delete_was_multiselect := false
var _current_columns := 0
var _last_layout_width := -1.0
var _layout_generation := 0
var _scroll_layout_generation := 0
var _pending_scroll_fraction := -1.0
var _reflow_gate_tween: Tween
var _interaction_locks: Dictionary = {}
var _popover_anchor_path := ""
var _popover_anchor_fraction := Vector2(0.5, 0.5)
var _popover_menu: PopupMenu
var _feedback_generation := 0
var _stage2_mode: StringName = Tokens.LEGACY
var _stage2_legacy: Dictionary = {}
var _selection_status_pill: PanelContainer
var _selection_status_label: Label
var _batch_duplicate_button: Button
var _batch_export_button: Button
var _batch_delete_button: Button

@onready var background := $Background as ColorRect
@onready var top_bar := $Shell/TopBar as PanelContainer
@onready var top_bar_margin := $Shell/TopBar/Margin as MarginContainer
@onready var top_bar_row := $Shell/TopBar/Margin/Row as HBoxContainer
@onready var top_bar_spacer := $Shell/TopBar/Margin/Row/Spacer as Control
@onready var brand_icon := $Shell/TopBar/Margin/Row/Brand/Icon as TextureRect
@onready var brand_wordmark := $Shell/TopBar/Margin/Row/Brand/Wordmark as Label
@onready var content_margin := $Shell/ProjectScroll/ContentMargin as MarginContainer
@onready var empty_title := $Shell/ProjectScroll/ContentMargin/Content/EmptyState/Title as Label
@onready var empty_hint := $Shell/ProjectScroll/ContentMargin/Content/EmptyState/Hint as Label
@onready var scroll_container := %ProjectScroll as ScrollContainer
@onready var grid := %ProjectGrid as GridContainer
@onready var empty_state := %EmptyState as Control
@onready var feedback_banner := %FeedbackBanner as Label
@onready var import_button := %Import as Button
@onready var new_button := %New as Button
@onready var multiselect_button := %MultiSelect as Button
@onready var build_identity_label := %BuildIdentity as Label
@onready var project_action_menu := %ProjectActionMenu as PopupMenu
@onready var batch_action_menu := %BatchActionMenu as PopupMenu
@onready var rename_dialog := %RenameProjectDialog as ConfirmationDialog
@onready var rename_edit := %RenameProjectEdit as LineEdit
@onready var delete_dialog := %DeleteProjectsDialog as ConfirmationDialog


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_sync_multiselect_button_presentation()
		if _stage2_mode != Tokens.LEGACY:
			import_button.text = tr("Import")
			new_button.text = tr("New")
			_sync_multiselect_toolbar()


func _ready() -> void:
	_capture_stage2_legacy()
	if not Themes.theme_switched.is_connected(_refresh_stage2_theme):
		Themes.theme_switched.connect(_refresh_stage2_theme)
	if not Global.pixel_ui_unit_changed.is_connected(_refresh_stage2_theme):
		Global.pixel_ui_unit_changed.connect(_refresh_stage2_theme)
	_refresh_stage2_theme()
	_configure_build_identity()
	if library == null:
		library = ProjectLibraryScript.new(StoragePolicy.PROJECTS_DIRECTORY)
	if not resized.is_connected(_on_gallery_resized):
		resized.connect(_on_gallery_resized)
	var window := get_window()
	if is_instance_valid(window) and not window.size_changed.is_connected(_on_gallery_resized):
		window.size_changed.connect(_on_gallery_resized)
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	var vertical_scroll := scroll_container.get_v_scroll_bar()
	if not vertical_scroll.value_changed.is_connected(_on_scroll_changed):
		vertical_scroll.value_changed.connect(_on_scroll_changed)
	if not project_action_menu.id_pressed.is_connected(_on_project_action_pressed):
		project_action_menu.id_pressed.connect(_on_project_action_pressed)
	if not batch_action_menu.id_pressed.is_connected(_on_batch_action_pressed):
		batch_action_menu.id_pressed.connect(_on_batch_action_pressed)
	if not rename_dialog.confirmed.is_connected(_on_rename_confirmed):
		rename_dialog.confirmed.connect(_on_rename_confirmed)
	if not rename_dialog.canceled.is_connected(_on_rename_canceled):
		rename_dialog.canceled.connect(_on_rename_canceled)
	if not delete_dialog.confirmed.is_connected(_on_delete_confirmed):
		delete_dialog.confirmed.connect(_on_delete_confirmed)
	if not delete_dialog.canceled.is_connected(_on_delete_canceled):
		delete_dialog.canceled.connect(_on_delete_canceled)
	if not project_action_menu.popup_hide.is_connected(_on_popover_hidden):
		project_action_menu.popup_hide.connect(_on_popover_hidden)
	if not batch_action_menu.popup_hide.is_connected(_on_popover_hidden):
		batch_action_menu.popup_hide.connect(_on_popover_hidden)
	call_deferred("_update_layout")


## Preserve old gallery appearance byte-for-byte when a legacy/custom preset
## is selected. Stage 2 never modifies the global Theme or project records.
func _capture_stage2_legacy() -> void:
	_stage2_legacy = {
		"ground": background.color,
		"brand_icon_filter": brand_icon.texture_filter,
		"brand_icon_size": brand_icon.custom_minimum_size,
		"topbar": top_bar.get_theme_stylebox(&"panel"),
		"topbar_min": top_bar.custom_minimum_size,
		"wordmark": brand_wordmark.get_theme_color(&"font_color"),
		"build": build_identity_label.get_theme_color(&"font_color"),
		"empty_title": empty_title.get_theme_color(&"font_color"),
		"empty_hint": empty_hint.get_theme_color(&"font_color"),
		"feedback": feedback_banner.get_theme_color(&"font_color"),
		"import_min": import_button.custom_minimum_size,
		"new_min": new_button.custom_minimum_size,
		"select_min": multiselect_button.custom_minimum_size,
	}


func _ensure_multiselect_toolbar() -> void:
	if is_instance_valid(_selection_status_pill):
		return
	_selection_status_pill = PanelContainer.new()
	_selection_status_pill.name = &"SelectionStatusPill"
	_selection_status_pill.visible = false
	_selection_status_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_selection_status_label = Label.new()
	_selection_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_selection_status_pill.add_child(_selection_status_label)

	_batch_duplicate_button = _make_batch_button(&"BatchDuplicate", ActionMenuId.DUPLICATE)
	_batch_export_button = _make_batch_button(&"BatchExport", ActionMenuId.EXPORT)
	_batch_delete_button = _make_batch_button(&"BatchDelete", ActionMenuId.DELETE)

	for node: Control in [
		_selection_status_pill,
		_batch_duplicate_button,
		_batch_export_button,
		_batch_delete_button,
	]:
		top_bar_row.add_child(node)


func _make_batch_button(node_name: StringName, action_id: int) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.visible = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_batch_action_pressed.bind(action_id))
	return btn


func _order_action_buttons_unified() -> void:
	var spacer_idx := top_bar_spacer.get_index()
	var cursor := spacer_idx + 1
	if is_instance_valid(_selection_status_pill):
		for node: Control in [
			_selection_status_pill,
			_batch_duplicate_button,
			_batch_export_button,
			_batch_delete_button,
		]:
			if node.get_parent() == top_bar_row:
				top_bar_row.move_child(node, cursor)
				cursor += 1
	for btn: Button in [multiselect_button, import_button, new_button]:
		if btn.get_parent() != top_bar_row:
			btn.reparent(top_bar_row)
		top_bar_row.move_child(btn, cursor)
		cursor += 1


func _sync_multiselect_button_presentation() -> void:
	if not is_instance_valid(multiselect_button):
		return
	var title := tr("Exit Multi-Select") if multiselect_mode else tr("Multi-Select")
	multiselect_button.text = title
	multiselect_button.tooltip_text = title if _stage2_mode != Tokens.LEGACY else ""
	if _stage2_mode != Tokens.LEGACY:
		Chrome.style_button_variant(
			multiselect_button, _stage2_mode, &"active" if multiselect_mode else &"secondary", true
		)
		var shadow_px := 0.0
		multiselect_button.custom_minimum_size.y = (36.0 if multiselect_mode else 36.0)
	_sync_multiselect_toolbar()


func _sync_multiselect_toolbar() -> void:
	var themed := _stage2_mode != Tokens.LEGACY
	if not is_instance_valid(_selection_status_pill):
		if not themed:
			import_button.visible = true
			new_button.visible = true
		return
	var show_batch := themed and multiselect_mode
	_selection_status_pill.visible = show_batch
	_batch_duplicate_button.visible = show_batch
	_batch_export_button.visible = show_batch
	_batch_delete_button.visible = show_batch
	import_button.visible = not show_batch
	new_button.visible = not show_batch
	if not show_batch:
		return

	var selected := get_selected_paths()
	var count := selected.size()
	var healthy := _selected_all_healthy()
	var unlocked := _interaction_locks.is_empty()
	if count == 0:
		_selection_status_label.text = tr("Select")
	else:
		_selection_status_label.text = "%d" % count
		var locale := TranslationServer.get_locale().to_lower()
		if locale.begins_with("zh"):
			_selection_status_label.text = "已选 %d 项" % count
		else:
			_selection_status_label.text = "%d selected" % count

	_batch_duplicate_button.text = tr("Duplicate")
	_batch_export_button.text = tr("Export")
	_batch_delete_button.text = tr("Delete")
	_batch_duplicate_button.disabled = (not unlocked) or (not healthy)
	_batch_export_button.disabled = (not unlocked) or (not healthy)
	_batch_delete_button.disabled = (not unlocked) or selected.is_empty()


func _refresh_stage2_theme() -> void:
	if not is_node_ready() or _stage2_legacy.is_empty():
		return
	var mode := Chrome.active_mode()
	_stage2_mode = mode
	var themed := mode != Tokens.LEGACY
	if not themed:
		background.color = _stage2_legacy["ground"]
		brand_icon.texture_filter = int(_stage2_legacy["brand_icon_filter"])
		brand_icon.custom_minimum_size = _stage2_legacy["brand_icon_size"]
		top_bar.custom_minimum_size = _stage2_legacy["topbar_min"]
		top_bar.add_theme_stylebox_override(&"panel", _stage2_legacy["topbar"])
		brand_wordmark.add_theme_color_override(&"font_color", _stage2_legacy["wordmark"])
		build_identity_label.add_theme_color_override(&"font_color", _stage2_legacy["build"])
		empty_title.add_theme_color_override(&"font_color", _stage2_legacy["empty_title"])
		empty_hint.add_theme_color_override(&"font_color", _stage2_legacy["empty_hint"])
		feedback_banner.add_theme_color_override(&"font_color", _stage2_legacy["feedback"])
		for button in [import_button, new_button, multiselect_button]:
			Chrome.clear_button(button)
			button.remove_theme_font_size_override(&"font_size")
		import_button.icon = null
		new_button.icon = null
		multiselect_button.icon = null
		import_button.text = tr("Import")
		new_button.text = tr("New")
		import_button.custom_minimum_size = _stage2_legacy["import_min"]
		new_button.custom_minimum_size = _stage2_legacy["new_min"]
		multiselect_button.custom_minimum_size = _stage2_legacy["select_min"]
		import_button.visible = true
		new_button.visible = true
		if is_instance_valid(_selection_status_pill):
			_selection_status_pill.visible = false
			_batch_duplicate_button.visible = false
			_batch_export_button.visible = false
			_batch_delete_button.visible = false
	else:
		_ensure_multiselect_toolbar()
		_order_action_buttons_unified()

		brand_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Source brand art is 16px: render at an exact 2x (32px).
		brand_icon.custom_minimum_size = Vector2(32.0, 32.0)
		background.color = Tokens.color(mode, &"gallery_ground")

		# Full-width edge-docked TopBar: 0px outer corners, no drop shadow, crisp bottom divider
		top_bar.custom_minimum_size = Vector2(0.0, 58.0)
		top_bar.add_theme_stylebox_override(&"panel", Chrome.make_topbar_style(mode))
		top_bar_margin.add_theme_constant_override(&"margin_left", Tokens.SPACE_XL)
		top_bar_margin.add_theme_constant_override(&"margin_right", Tokens.SPACE_XL)
		top_bar_margin.add_theme_constant_override(&"margin_top", 10)
		top_bar_margin.add_theme_constant_override(&"margin_bottom", 10)
		top_bar_row.add_theme_constant_override(&"separation", Tokens.SPACE_SM)

		content_margin.add_theme_constant_override(&"margin_left", Tokens.SPACE_XL)
		content_margin.add_theme_constant_override(&"margin_right", Tokens.SPACE_XL)
		content_margin.add_theme_constant_override(&"margin_top", 24)
		content_margin.add_theme_constant_override(&"margin_bottom", 36)
		grid.add_theme_constant_override(&"h_separation", 18)
		grid.add_theme_constant_override(&"v_separation", 18)

		var foreground := Tokens.color(mode, &"text_primary")
		var muted := Tokens.color(mode, &"text_muted")
		brand_wordmark.add_theme_color_override(&"font_color", Tokens.color(mode, &"topbar_text"))
		brand_wordmark.add_theme_font_size_override(&"font_size", Tokens.FONT_BRAND)
		build_identity_label.add_theme_color_override(
			&"font_color", Tokens.color(mode, &"topbar_pill_surface")
		)
		build_identity_label.add_theme_font_size_override(&"font_size", Tokens.FONT_CAPTION)
		empty_title.add_theme_color_override(&"font_color", foreground)
		empty_hint.add_theme_color_override(&"font_color", muted)
		feedback_banner.add_theme_color_override(&"font_color", muted)

		# Unified right-side action group: Multi-Select, Import, New (CTA)
		var btn_h := 36.0
		for button: Button in [multiselect_button, import_button, new_button]:
			button.custom_minimum_size = Vector2(0.0, btn_h)
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			button.expand_icon = false
			button.add_theme_font_size_override(
				&"font_size", Tokens.FONT_CARD_TITLE if button == new_button else Tokens.FONT_BODY
			)
		Chrome.style_button_variant(import_button, mode, &"secondary", true)
		Chrome.style_button_variant(new_button, mode, &"cta", true)
		Chrome.style_button_variant(
			multiselect_button, mode, &"active" if multiselect_mode else &"secondary", true
		)

		# Crisp 16x16 (exact 1x) pixel icons inside 38px text+icon buttons
		import_button.icon = Icons.icon_1x(&"import")
		multiselect_button.icon = Icons.icon_1x(&"multi_select")
		new_button.icon = Icons.icon_1x(&"new")
		import_button.text = tr("Import")
		import_button.tooltip_text = tr("Import")
		new_button.text = tr("New")
		new_button.tooltip_text = tr("New")

		# Selection mode status pill & inline batch actions
		_selection_status_pill.add_theme_stylebox_override(
			&"panel", Chrome.make_recessed_topbar_pill(mode, 12.0, 6.0)
		)
		_selection_status_label.add_theme_color_override(
			&"font_color", Tokens.color(mode, &"topbar_pill_text")
		)
		_selection_status_label.add_theme_font_size_override(&"font_size", Tokens.FONT_META)

		for batch_btn: Button in [
			_batch_duplicate_button, _batch_export_button, _batch_delete_button
		]:
			batch_btn.custom_minimum_size = Vector2(0.0, btn_h)
			batch_btn.add_theme_font_size_override(&"font_size", Tokens.FONT_BODY)
		Chrome.style_button_variant(_batch_duplicate_button, mode, &"subtle", true)
		Chrome.style_button_variant(_batch_export_button, mode, &"subtle", true)
		Chrome.style_button_variant(_batch_delete_button, mode, &"danger", true)

	_sync_multiselect_button_presentation()
	for card: ProjectGalleryCard in _cards:
		card.apply_stage2_theme(mode)
		card.set_multiselect_mode(multiselect_mode)
	call_deferred("_update_layout")


## The gallery displays the identity of the app actually running on the iPad.
## Build metadata is stamped into project.godot by the iOS CI job before export.
## Never infer the installed version from a downloaded IPA or a saved session.
static func ios_build_label(run_number: String, commit: String) -> String:
	if run_number.is_empty() or commit.is_empty():
		return ""
	return "Build %s · %s" % [run_number, commit.substr(0, 7)]


func _configure_build_identity() -> void:
	build_identity_label.visible = false
	if OS.get_name() != "iOS":
		return
	var run_number := str(ProjectSettings.get_setting("application/config/ios_build_number", ""))
	var commit := str(ProjectSettings.get_setting("application/config/ios_build_commit", ""))
	var label_text := ios_build_label(run_number, commit)
	if label_text.is_empty():
		return
	build_identity_label.text = label_text
	build_identity_label.tooltip_text = "iOS build %s / commit %s" % [run_number, commit]
	build_identity_label.visible = true
	print("[PHOSPRITE-BUILD] iOS build %s / commit %s" % [run_number, commit])


func _process(_delta: float) -> void:
	if not visible:
		return
	var expected_columns := columns_for_viewport_size(_current_orientation_size())
	var layout_width := _current_layout_width()
	if expected_columns != _current_columns or absf(layout_width - _last_layout_width) > 0.5:
		_update_layout()
	_consume_gesture_actions(_gesture_resolver.poll(Time.get_ticks_msec()))


static func columns_for_viewport_size(viewport_size: Vector2) -> int:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return LANDSCAPE_COLUMNS
	return LANDSCAPE_COLUMNS if viewport_size.x >= viewport_size.y else PORTRAIT_COLUMNS


static func normalized_scroll_fraction(
	value: float, min_value: float, max_value: float, page: float
) -> float:
	var scroll_span := maxf(max_value - page - min_value, 0.0)
	if scroll_span <= 0.0:
		return 0.0
	return clampf((value - min_value) / scroll_span, 0.0, 1.0)


static func scroll_value_for_fraction(
	fraction: float, min_value: float, max_value: float, page: float
) -> float:
	var scroll_span := maxf(max_value - page - min_value, 0.0)
	return min_value + scroll_span * clampf(fraction, 0.0, 1.0)


func _current_orientation_size() -> Vector2:
	# The Gallery is laid out inside Main's mobile safe-area shell. Window.size is
	# not an authoritative layout size on iPad after a sensor rotation: it may
	# update before/after the safe-area Control or remain in a different scale.
	# Always prefer the Control that actually owns the card grid.
	if size.x > 0.0 and size.y > 0.0:
		return size
	if is_instance_valid(scroll_container) and scroll_container.size.x > 0.0:
		return scroll_container.size
	var window := get_window()
	return Vector2(window.size) if is_instance_valid(window) else Vector2.ZERO


static func effective_layout_width(
	shell_width: float, scroll_width: float, viewport_width: float
) -> float:
	var width := INF
	for candidate in [shell_width, scroll_width, viewport_width]:
		if candidate > 0.0:
			width = minf(width, candidate)
	return 0.0 if is_inf(width) else width


func _current_layout_width() -> float:
	var scroll_width := scroll_container.size.x if is_instance_valid(scroll_container) else 0.0
	var viewport_width := get_viewport_rect().size.x
	return effective_layout_width(size.x, scroll_width, viewport_width)


func configure(directory := StoragePolicy.PROJECTS_DIRECTORY) -> void:
	library = ProjectLibraryScript.new(directory)


func refresh() -> Array[ProjectLibraryEntry]:
	if library == null:
		library = ProjectLibraryScript.new(StoragePolicy.PROJECTS_DIRECTORY)
	entries = library.scan(false)
	refresh_count += 1
	_prune_selection()
	_rebuild_cards()
	return entries


func reset_scroll_position() -> void:
	_pending_scroll_fraction = -1.0
	_scroll_layout_generation += 1
	scroll_container.scroll_horizontal = 0
	scroll_container.scroll_vertical = 0
	scroll_reset_count += 1
	call_deferred("_apply_scroll_top_after_layout", scroll_reset_count)
	call_deferred("_load_visible_thumbnails")


func set_interaction_locked(reason: StringName, locked: bool) -> void:
	if locked:
		_interaction_locks[reason] = true
	else:
		_interaction_locks.erase(reason)
	_sync_interaction_state()


func show_feedback(message: String, is_error := false, duration := FEEDBACK_DURATION) -> void:
	_feedback_generation += 1
	var generation := _feedback_generation
	feedback_banner.text = message
	feedback_banner.visible = not message.is_empty()
	feedback_banner.add_theme_color_override(
		"font_color", FEEDBACK_ERROR_COLOR if is_error else FEEDBACK_NORMAL_COLOR
	)
	if duration <= 0.0 or message.is_empty():
		return
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(_hide_feedback_if_current.bind(generation))


func find_entry(path: String) -> ProjectLibraryEntry:
	var normalized := _normalized_path(path)
	for entry: ProjectLibraryEntry in entries:
		if _normalized_path(entry.path) == normalized:
			return entry
	return null


func request_open(path: String) -> void:
	project_open_requested.emit(path)


func set_multiselect_mode(enabled: bool) -> void:
	multiselect_mode = enabled
	# Preserve the explicit accessibility label before Stage-2 treatment.
	multiselect_button.text = tr("Exit Multi-Select") if enabled else tr("Multi-Select")
	_gesture_resolver.reset()
	_hide_popovers()
	if not enabled:
		_selected_paths.clear()
	_sync_multiselect_button_presentation()
	_sync_card_selection()


func get_selected_paths() -> PackedStringArray:
	var selected := PackedStringArray()
	for entry: ProjectLibraryEntry in entries:
		if _selected_paths.has(_normalized_path(entry.path)):
			selected.append(entry.path)
	return selected


func rename_project(path: String, new_name: String) -> Dictionary:
	var result := library.rename_project(path, new_name)
	if not bool(result.get("ok", false)):
		return result
	var new_path := str(result.get("path", path))
	var final_name := str(result.get("name", new_name))
	_replace_selected_path(path, new_path)
	project_renamed.emit(path, new_path, final_name)
	refresh()
	return result


func duplicate_projects(paths: PackedStringArray) -> Dictionary:
	var created := PackedStringArray()
	var errors: Array[Dictionary] = []
	for path in paths:
		var result := library.duplicate_project(path)
		if bool(result.get("ok", false)):
			created.append(str(result.get("path", "")))
		else:
			errors.append({"path": path, "error": int(result.get("error", FAILED))})
	if not created.is_empty():
		refresh()
	return {"created": created, "errors": errors}


func delete_projects(paths: PackedStringArray) -> Dictionary:
	var deleted := PackedStringArray()
	var errors: Array[Dictionary] = []
	for path in paths:
		var entry := find_entry(path)
		var project_uuid := "" if entry == null else entry.uuid
		var error := library.delete_project(path, project_uuid)
		if error == OK:
			deleted.append(path)
			_selected_paths.erase(_normalized_path(path))
		else:
			errors.append({"path": path, "error": error})
	if not deleted.is_empty():
		projects_deleted.emit(deleted)
		refresh()
	return {"deleted": deleted, "errors": errors}


func _rebuild_cards() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	_cards.clear()

	var untitled_number := 0
	for entry: ProjectLibraryEntry in entries:
		var card := CARD_SCENE.instantiate() as ProjectGalleryCard
		if card == null:
			continue
		grid.add_child(card)
		card.bind(entry)
		var display_name := entry.path.get_file().get_basename()
		if display_name.to_lower().begins_with("untitled_"):
			untitled_number += 1
			display_name = "%s %d" % [tr("Untitled"), untitled_number]
		card.set_display_title(display_name)
		card.apply_stage2_theme(_stage2_mode)
		card.set_multiselect_mode(multiselect_mode)
		card.set_selected(_selected_paths.has(_normalized_path(entry.path)))
		card.pointer_down.connect(_on_card_pointer_down)
		card.pointer_up.connect(_on_card_pointer_up)
		card.pointer_cancel.connect(_on_card_pointer_cancel)
		_cards.append(card)

	empty_state.visible = entries.is_empty()
	_sync_interaction_state()
	call_deferred("_update_layout")
	call_deferred("_load_visible_thumbnails")


func _update_layout() -> void:
	if not is_instance_valid(grid) or not is_instance_valid(scroll_container):
		return
	var columns := columns_for_viewport_size(_current_orientation_size())
	var should_reflow := visible and _current_columns > 0 and columns != _current_columns
	if should_reflow:
		_pending_scroll_fraction = _current_scroll_fraction()
	_scroll_layout_generation += 1
	var scroll_generation := _scroll_layout_generation
	var old_rects: Dictionary = {}
	if should_reflow:
		for card: ProjectGalleryCard in _cards:
			if card.entry != null:
				old_rects[_normalized_path(card.entry.path)] = card.get_global_rect()
		_gesture_resolver.reset()
		_hide_popovers()
		set_interaction_locked(&"reflow", true)

	_current_columns = columns
	grid.columns = columns
	var layout_width := _current_layout_width()
	_last_layout_width = layout_width
	var side_margin := GRID_SIDE_MARGIN if _stage2_mode != Tokens.LEGACY else 32.0
	var available_width := maxf(layout_width - side_margin * 2.0, 1.0)
	var separators := GRID_SEPARATION * float(columns - 1)
	# The ScrollContainer can retain its previous landscape width for a frame (or
	# longer on iPad safe-area rotation). Derive card geometry from the live shell
	# width and keep the Grid shrink-wrapped so stale parent width cannot expand it.
	var card_width := maxf(floorf((available_width - separators) / float(columns)), 1.0)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for card: ProjectGalleryCard in _cards:
		card.set_card_width(card_width)

	if should_reflow and not old_rects.is_empty():
		_layout_generation += 1
		var generation := _layout_generation
		get_tree().process_frame.connect(
			_start_reflow.bind(old_rects, generation), CONNECT_ONE_SHOT
		)
	elif should_reflow:
		set_interaction_locked(&"reflow", false)
	elif not _interaction_locks.has(&"reflow"):
		set_interaction_locked(&"reflow", false)
	if _pending_scroll_fraction >= 0.0:
		call_deferred("_restore_scroll_fraction_after_layout", scroll_generation)
	call_deferred("_load_visible_thumbnails")


func _current_scroll_fraction() -> float:
	var vertical_scroll := scroll_container.get_v_scroll_bar()
	return normalized_scroll_fraction(
		vertical_scroll.value,
		vertical_scroll.min_value,
		vertical_scroll.max_value,
		vertical_scroll.page
	)


func _restore_scroll_fraction_after_layout(generation: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if generation != _scroll_layout_generation or _pending_scroll_fraction < 0.0 or not visible:
		return
	var vertical_scroll := scroll_container.get_v_scroll_bar()
	scroll_container.scroll_vertical = roundi(
		scroll_value_for_fraction(
			_pending_scroll_fraction,
			vertical_scroll.min_value,
			vertical_scroll.max_value,
			vertical_scroll.page
		)
	)
	_pending_scroll_fraction = -1.0
	call_deferred("_load_visible_thumbnails")


func _load_visible_thumbnails() -> void:
	if not visible or library == null or not is_instance_valid(scroll_container):
		return
	var visible_rect := scroll_container.get_global_rect().grow(THUMBNAIL_PRELOAD_MARGIN)
	for card: ProjectGalleryCard in _cards:
		if card.thumbnail_loaded or card.entry == null:
			continue
		if not visible_rect.intersects(card.get_global_rect()):
			continue
		card.set_thumbnail(library.load_thumbnail(card.entry))


func _consume_gesture_actions(actions: Array[Dictionary]) -> void:
	for action: Dictionary in actions:
		var path := str(action.get("path", ""))
		if path.is_empty() or find_entry(path) == null:
			continue
		var kind := int(action.get("kind", -1))
		var position: Vector2 = action.get("position", Vector2.ZERO)
		match kind:
			GestureResolverScript.ActionKind.SINGLE_TAP:
				_on_resolved_single_tap(path)
			GestureResolverScript.ActionKind.LONG_PRESS:
				_on_resolved_long_press(path, position)


func _on_resolved_single_tap(path: String) -> void:
	if multiselect_mode:
		_set_path_selected(path, not _selected_paths.has(_normalized_path(path)))
		return
	project_open_requested.emit(path)


func _on_resolved_long_press(path: String, position: Vector2) -> void:
	# Long press owns the context-menu gesture. Cancel the originating card's
	# transient Button press before showing a PopupMenu so no pressed outline can
	# remain latched if the popup consumes the eventual finger release.
	_gesture_resolver.pointer_cancel(path)
	var card := _find_card(path)
	if card != null:
		card.clear_transient_press_state()
	if multiselect_mode:
		if not _selected_paths.has(_normalized_path(path)):
			_set_path_selected(path, true)
		if get_selected_paths().is_empty():
			return
		call_deferred("_show_batch_action_menu", position, path)
		return
	call_deferred("_show_project_action_menu", path, position)


func _show_project_action_menu(path: String, position: Vector2) -> void:
	var entry := find_entry(path)
	if entry == null:
		return
	_action_path = path
	project_action_menu.clear()
	if entry.health_state == ProjectLibraryEntry.HealthState.OK:
		project_action_menu.add_item(tr("Rename"), ActionMenuId.RENAME)
		project_action_menu.add_item(tr("Duplicate"), ActionMenuId.DUPLICATE)
		project_action_menu.add_item(tr("Delete"), ActionMenuId.DELETE)
		project_action_menu.add_separator()
		project_action_menu.add_item(tr("Export"), ActionMenuId.EXPORT)
		project_action_menu.add_item(tr("Reveal in Files"), ActionMenuId.REVEAL)
	else:
		project_action_menu.add_item(tr("Delete"), ActionMenuId.DELETE)
		project_action_menu.add_item(tr("Reveal in Files"), ActionMenuId.REVEAL)
	_popup_anchored(project_action_menu, path, position)


func _show_batch_action_menu(position: Vector2, anchor_path := "") -> void:
	batch_action_menu.clear()
	if _selected_all_healthy():
		batch_action_menu.add_item(tr("Duplicate"), ActionMenuId.DUPLICATE)
	batch_action_menu.add_item(tr("Delete"), ActionMenuId.DELETE)
	if _selected_all_healthy():
		batch_action_menu.add_item(tr("Export"), ActionMenuId.EXPORT)
	_popup_anchored(batch_action_menu, anchor_path, position)


func _popup_anchored(menu: PopupMenu, path: String, position: Vector2) -> void:
	var card := _find_card(path)
	if card == null:
		return
	var rect := card.get_global_rect()
	var local_anchor := position - rect.position
	_popover_anchor_fraction = Vector2(
		clampf(local_anchor.x / maxf(rect.size.x, 1.0), 0.0, 1.0),
		clampf(local_anchor.y / maxf(rect.size.y, 1.0), 0.0, 1.0)
	)
	_popover_anchor_path = path
	_popover_menu = menu
	_place_open_popover()
	menu.popup()
	call_deferred("_place_open_popover")


func _selected_all_healthy() -> bool:
	var selected := get_selected_paths()
	if selected.is_empty():
		return false
	for path in selected:
		var entry := find_entry(path)
		if entry == null or entry.health_state != ProjectLibraryEntry.HealthState.OK:
			return false
	return true


func _set_path_selected(path: String, value: bool) -> void:
	var normalized := _normalized_path(path)
	if value:
		_selected_paths[normalized] = path
	else:
		_selected_paths.erase(normalized)
	_sync_card_selection()
	_sync_multiselect_toolbar()


func _sync_card_selection() -> void:
	for card: ProjectGalleryCard in _cards:
		if card.entry == null:
			continue
		card.set_multiselect_mode(multiselect_mode)
		card.set_selected(_selected_paths.has(_normalized_path(card.entry.path)))


func _prune_selection() -> void:
	var valid_paths: Dictionary = {}
	for entry: ProjectLibraryEntry in entries:
		valid_paths[_normalized_path(entry.path)] = true
	for normalized in _selected_paths.keys():
		if not valid_paths.has(normalized):
			_selected_paths.erase(normalized)


func _replace_selected_path(old_path: String, new_path: String) -> void:
	var old_normalized := _normalized_path(old_path)
	if not _selected_paths.has(old_normalized):
		return
	_selected_paths.erase(old_normalized)
	_selected_paths[_normalized_path(new_path)] = new_path


func _on_card_pointer_down(path: String, position: Vector2, timestamp_msec: int) -> void:
	_consume_gesture_actions(_gesture_resolver.pointer_down(path, position, timestamp_msec))


func _on_card_pointer_up(path: String, position: Vector2, timestamp_msec: int) -> void:
	_consume_gesture_actions(_gesture_resolver.pointer_up(path, position, timestamp_msec))


func _on_card_pointer_cancel(path: String) -> void:
	_gesture_resolver.pointer_cancel(path)


func _on_project_action_pressed(id: int) -> void:
	if _action_path.is_empty():
		return
	match id:
		ActionMenuId.RENAME:
			_begin_rename(_action_path)
		ActionMenuId.DUPLICATE:
			var result := duplicate_projects(PackedStringArray([_action_path]))
			_report_action_errors(result)
			var errors: Array = result.get("errors", [])
			if errors.is_empty():
				show_feedback(tr("Project duplicated."))
		ActionMenuId.DELETE:
			_begin_delete(PackedStringArray([_action_path]), false)
		ActionMenuId.EXPORT:
			export_projects_requested.emit(PackedStringArray([_action_path]))
		ActionMenuId.REVEAL:
			reveal_in_files_requested.emit(_action_path)


func _on_batch_action_pressed(id: int) -> void:
	var selected := get_selected_paths()
	if selected.is_empty():
		return
	match id:
		ActionMenuId.DUPLICATE:
			var result := duplicate_projects(selected)
			_report_action_errors(result)
			var errors: Array = result.get("errors", [])
			if errors.is_empty():
				show_feedback(tr("%d projects duplicated.") % selected.size())
				set_multiselect_mode(false)
		ActionMenuId.DELETE:
			_begin_delete(selected, true)
		ActionMenuId.EXPORT:
			export_projects_requested.emit(selected)


func _begin_rename(path: String) -> void:
	var entry := find_entry(path)
	if entry == null or entry.health_state != ProjectLibraryEntry.HealthState.OK:
		return
	_rename_source_path = path
	rename_edit.text = path.get_file().get_basename()
	rename_edit.select_all()
	Global.dialog_open(true)
	rename_dialog.popup_centered(Vector2i(420, 150))
	rename_edit.grab_focus()


func _on_rename_confirmed() -> void:
	var source_path := _rename_source_path
	_rename_source_path = ""
	Global.dialog_open(false)
	if source_path.is_empty():
		return
	var result := rename_project(source_path, rename_edit.text)
	if bool(result.get("ok", false)):
		show_feedback(tr("Project renamed."))
		return
	var error := int(result.get("error", FAILED))
	if error == ERR_ALREADY_EXISTS:
		Global.popup_error(tr("A project with this name already exists."))
	elif error == ERR_INVALID_PARAMETER:
		Global.popup_error(tr("Project names cannot be empty or contain unsupported characters."))
	else:
		Global.popup_error(
			tr("Could not rename this project. Error code %s (%s)") % [error, error_string(error)]
		)


func _on_rename_canceled() -> void:
	_rename_source_path = ""
	Global.dialog_open(false)


func _begin_delete(paths: PackedStringArray, from_multiselect: bool) -> void:
	if paths.is_empty():
		return
	_pending_delete_paths = paths.duplicate()
	_delete_was_multiselect = from_multiselect
	if paths.size() == 1:
		delete_dialog.dialog_text = tr("Permanently delete this project? This cannot be undone.")
	else:
		delete_dialog.dialog_text = (
			tr("Permanently delete %d projects? This cannot be undone.") % paths.size()
		)
	Global.dialog_open(true)
	delete_dialog.popup_centered_clamped()


func _on_delete_confirmed() -> void:
	var paths := _pending_delete_paths.duplicate()
	var was_multiselect := _delete_was_multiselect
	_pending_delete_paths.clear()
	_delete_was_multiselect = false
	Global.dialog_open(false)
	var result := delete_projects(paths)
	_report_action_errors(result)
	var errors: Array = result.get("errors", [])
	if errors.is_empty():
		if paths.size() == 1:
			show_feedback(tr("Project deleted."))
		else:
			show_feedback(tr("%d projects deleted.") % paths.size())
	if was_multiselect:
		set_multiselect_mode(false)


func _on_delete_canceled() -> void:
	_pending_delete_paths.clear()
	_delete_was_multiselect = false
	Global.dialog_open(false)


func _report_action_errors(result: Dictionary) -> void:
	var errors: Array = result.get("errors", [])
	if errors.is_empty():
		return
	show_feedback(tr("One or more project operations could not be completed."), true)
	Global.popup_error(tr("One or more project operations could not be completed."))


func _on_gallery_resized() -> void:
	call_deferred("_update_layout")
	call_deferred("_place_open_popover")


func _on_scroll_changed(_value: float) -> void:
	call_deferred("_load_visible_thumbnails")
	call_deferred("_place_open_popover")


func _on_visibility_changed() -> void:
	if not visible:
		_gesture_resolver.reset()
		_hide_popovers()


func _on_new_project_pressed() -> void:
	new_project_requested.emit()


func _on_import_pressed() -> void:
	import_requested.emit()


func _on_multiselect_pressed() -> void:
	var was_multiselect := multiselect_mode
	set_multiselect_mode(not multiselect_mode)
	if was_multiselect:
		exit_multiselect_requested.emit()


func _start_reflow(old_rects: Dictionary, generation: int) -> void:
	if generation != _layout_generation or not visible:
		set_interaction_locked(&"reflow", false)
		return
	reflow_animation_count += 1
	for card: ProjectGalleryCard in _cards:
		if card.entry == null:
			continue
		var key := _normalized_path(card.entry.path)
		if old_rects.has(key):
			var old_rect: Rect2 = old_rects[key]
			card.prepare_reflow(old_rect)
			card.play_reflow(REFLOW_DURATION)
	if is_instance_valid(_reflow_gate_tween):
		_reflow_gate_tween.kill()
	_reflow_gate_tween = create_tween()
	_reflow_gate_tween.tween_interval(REFLOW_DURATION)
	_reflow_gate_tween.tween_callback(_finish_reflow.bind(generation))


func _finish_reflow(generation: int) -> void:
	if generation != _layout_generation:
		return
	for card: ProjectGalleryCard in _cards:
		card.reset_visual_transform()
	set_interaction_locked(&"reflow", false)
	_place_open_popover()


func _sync_interaction_state() -> void:
	var enabled := _interaction_locks.is_empty()
	if not enabled:
		_gesture_resolver.reset()
	import_button.disabled = not enabled
	new_button.disabled = not enabled
	multiselect_button.disabled = not enabled
	_sync_multiselect_toolbar()
	for card: ProjectGalleryCard in _cards:
		card.set_interaction_enabled(enabled)


func _find_card(path: String) -> ProjectGalleryCard:
	var normalized := _normalized_path(path)
	for card: ProjectGalleryCard in _cards:
		if card.entry != null and _normalized_path(card.entry.path) == normalized:
			return card
	return null


func _place_open_popover() -> void:
	if _popover_menu == null or _popover_anchor_path.is_empty():
		return
	var card := _find_card(_popover_anchor_path)
	if card == null:
		_hide_popovers()
		return
	var card_rect := card.get_global_rect()
	var visible_rect := scroll_container.get_global_rect()
	if not visible_rect.intersects(card_rect):
		_hide_popovers()
		return
	var anchor := card_rect.position + card_rect.size * _popover_anchor_fraction
	var viewport_size := get_viewport_rect().size
	var menu_size := Vector2(_popover_menu.size)
	var max_x := maxf(viewport_size.x - menu_size.x, 0.0)
	var max_y := maxf(viewport_size.y - menu_size.y, 0.0)
	_popover_menu.position = Vector2i(
		roundi(clampf(anchor.x, 0.0, max_x)), roundi(clampf(anchor.y, 0.0, max_y))
	)


func _hide_popovers() -> void:
	project_action_menu.hide()
	batch_action_menu.hide()
	_clear_popover_anchor()


func _on_popover_hidden() -> void:
	if not project_action_menu.visible and not batch_action_menu.visible:
		_clear_popover_anchor()


func _clear_popover_anchor() -> void:
	_popover_anchor_path = ""
	_popover_anchor_fraction = Vector2(0.5, 0.5)
	_popover_menu = null


func _apply_scroll_top_after_layout(generation: int) -> void:
	if generation != scroll_reset_count or not is_instance_valid(scroll_container):
		return
	scroll_container.scroll_horizontal = 0
	scroll_container.scroll_vertical = 0


func _hide_feedback_if_current(generation: int) -> void:
	if generation == _feedback_generation:
		feedback_banner.visible = false


func _normalized_path(path: String) -> String:
	return ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()
