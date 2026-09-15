class_name PaletteReorderTouchFeedback
extends Node

const AUTO_SCROLL_MIN_SPEED := 90.0
const AUTO_SCROLL_MAX_SPEED := 520.0
const AUTO_SCROLL_RAMP_PX := 72.0
const PREVIEW_OPACITY := 0.88

var _tracked_touches: Dictionary = {}
var _active_touch := -1
var _managed_scroll := 0.0
var _preview: PaletteSwatch = null
var _source_swatch: PaletteSwatch = null

@onready var palette_grid := (
	get_parent().get_node("PaletteVBoxContainer/ScrollContainer/PaletteGrid") as PaletteGrid
)
@onready var scroll_container := (
	get_parent().get_node("PaletteVBoxContainer/ScrollContainer") as ScrollContainer
)


func _ready() -> void:
	var ios := OS.get_name() == "iOS"
	set_process_input(ios)
	set_process(ios)


func _exit_tree() -> void:
	_finish_reorder_feedback()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_track_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_track_drag(event as InputEventScreenDrag)


func _process(delta: float) -> void:
	if _active_touch < 0:
		_try_begin_reorder_feedback()
	if _active_touch < 0:
		return
	if not _tracked_touches.has(_active_touch):
		_finish_reorder_feedback()
		return
	if not palette_grid._ios_touch_candidates.has(_active_touch):
		_finish_reorder_feedback()
		return
	var candidate: Dictionary = palette_grid._ios_touch_candidates[_active_touch]
	if not bool(candidate.get("reordering", false)):
		_finish_reorder_feedback()
		return
	var touch: Dictionary = _tracked_touches[_active_touch]
	var screen_position: Vector2 = touch.get("position", Vector2.ZERO)
	_update_preview_position(screen_position)
	_update_managed_scroll(screen_position, delta)


func _track_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		var palette_index := palette_grid._ios_palette_index_at(event.position)
		if palette_index < 0 or not palette_grid._ios_palette_index_has_color(palette_index):
			return
		_tracked_touches[event.index] = {
			"position": event.position,
			"start_scroll": float(scroll_container.scroll_vertical),
		}
		return
	_tracked_touches.erase(event.index)
	if event.index == _active_touch:
		_finish_reorder_feedback()


func _track_drag(event: InputEventScreenDrag) -> void:
	if not _tracked_touches.has(event.index):
		return
	var touch: Dictionary = _tracked_touches[event.index]
	touch["position"] = event.position
	_tracked_touches[event.index] = touch


func _try_begin_reorder_feedback() -> void:
	for touch_index in _tracked_touches:
		if not palette_grid._ios_touch_candidates.has(touch_index):
			continue
		var candidate: Dictionary = palette_grid._ios_touch_candidates[touch_index]
		if not bool(candidate.get("reordering", false)):
			continue
		_active_touch = int(touch_index)
		var touch: Dictionary = _tracked_touches[_active_touch]
		_managed_scroll = float(touch.get("start_scroll", scroll_container.scroll_vertical))
		_create_preview(int(candidate.get("palette_index", -1)))
		_update_preview_position(touch.get("position", Vector2.ZERO))
		return


func _create_preview(palette_index: int) -> void:
	_clear_preview()
	var grid_index := palette_grid.convert_palette_index_to_grid_index(palette_index)
	if grid_index < 0 or grid_index >= palette_grid.swatches.size():
		return
	var source := palette_grid.swatches[grid_index]
	if not is_instance_valid(source) or source.empty:
		return
	_source_swatch = source
	_source_swatch.show_dragging_outline = true
	var preview := PaletteSwatch.new()
	preview.color_index = source.color_index
	preview.set_swatch_size(source.size)
	preview.set_swatch_color(source.color)
	preview.empty = false
	preview.show_left_highlight = false
	preview.show_right_highlight = false
	preview.show_dragging_outline = false
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1.0, 1.0, 1.0, PREVIEW_OPACITY)
	preview.z_index = 4096
	get_tree().root.add_child(preview)
	_preview = preview


func _update_preview_position(screen_position: Vector2) -> void:
	if not is_instance_valid(_preview):
		return
	_preview.global_position = screen_position - _preview.size * 0.5


func _update_managed_scroll(screen_position: Vector2, delta: float) -> void:
	var visible_rect := scroll_container.get_global_rect()
	var overflow := 0.0
	if screen_position.y < visible_rect.position.y:
		overflow = screen_position.y - visible_rect.position.y
	elif screen_position.y > visible_rect.end.y:
		overflow = screen_position.y - visible_rect.end.y
	if is_zero_approx(overflow):
		# Reorder owns the gesture now. Hold the Palette still while the finger stays inside
		# its visible region, overriding any ScrollContainer drag/inertia already in flight.
		scroll_container.scroll_vertical = int(round(_managed_scroll))
		return
	var strength := clampf(absf(overflow) / AUTO_SCROLL_RAMP_PX, 0.0, 1.0)
	var speed := lerpf(AUTO_SCROLL_MIN_SPEED, AUTO_SCROLL_MAX_SPEED, strength)
	_managed_scroll += signf(overflow) * speed * delta
	var scroll_bar := scroll_container.get_v_scroll_bar()
	var max_scroll := maxf(0.0, scroll_bar.max_value - scroll_bar.page)
	_managed_scroll = clampf(_managed_scroll, 0.0, max_scroll)
	scroll_container.scroll_vertical = int(round(_managed_scroll))


func _finish_reorder_feedback() -> void:
	_active_touch = -1
	_clear_preview()


func _clear_preview() -> void:
	if is_instance_valid(_source_swatch):
		_source_swatch.show_dragging_outline = false
	_source_swatch = null
	if is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null
