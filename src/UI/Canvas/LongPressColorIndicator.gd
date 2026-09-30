class_name LongPressColorIndicator
extends Node2D

## Screen-space progress ring for the iPad long-press color picker.
## The node lives under a CanvasLayer so its size is independent of canvas zoom/rotation.

enum State { HIDDEN, ARMING, ACTIVE, CANCELLING }

const RADIUS_PX := 44.0
const STROKE_WIDTH_PX := 6.0
const OUTLINE_EXTRA_PX := 3.0
const ARC_POINTS := 64

var _state := State.HIDDEN
var _progress := 0.0
var _elapsed := 0.0
var _duration := 0.0
var _cancel_start_progress := 0.0
var _initial_color := Color.WHITE
var _target_color := Color.WHITE


static func blend_ring_color(initial_color: Color, target_color: Color, progress: float) -> Color:
	# The visual must move from the palette color to the sampled color as the
	# acquisition ring fills, so progress weights the target (not the initial color).
	return initial_color.lerp(target_color, clampf(progress, 0.0, 1.0))


func _ready() -> void:
	visible = false
	set_process(false)


func begin(
	screen_position: Vector2, initial_color: Color, target_color: Color, duration_seconds: float
) -> void:
	position = screen_position
	_initial_color = initial_color
	_target_color = target_color
	_progress = 0.0
	_elapsed = 0.0
	_duration = maxf(duration_seconds, 0.001)
	_cancel_start_progress = 0.0
	_state = State.ARMING
	visible = true
	set_process(true)
	queue_redraw()


func update_pending_target(target_color: Color) -> void:
	if _state != State.ARMING:
		return
	_target_color = target_color
	queue_redraw()


func activate(screen_position: Vector2, sampled_color: Color) -> void:
	position = screen_position
	_initial_color = sampled_color
	_target_color = sampled_color
	_progress = 1.0
	_state = State.ACTIVE
	visible = true
	set_process(false)
	queue_redraw()


func update_active(screen_position: Vector2, sampled_color: Color) -> void:
	if _state != State.ACTIVE:
		return
	position = screen_position
	_initial_color = sampled_color
	_target_color = sampled_color
	_progress = 1.0
	queue_redraw()


func cancel(duration_seconds := 0.2) -> void:
	if _state == State.HIDDEN:
		return
	if _progress <= 0.0 or duration_seconds <= 0.0:
		dismiss()
		return
	_cancel_start_progress = _progress
	_elapsed = 0.0
	_duration = duration_seconds
	_state = State.CANCELLING
	set_process(true)
	queue_redraw()


func dismiss() -> void:
	_state = State.HIDDEN
	_progress = 0.0
	_elapsed = 0.0
	visible = false
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	match _state:
		State.ARMING:
			_elapsed += delta
			_progress = clampf(_elapsed / _duration, 0.0, 1.0)
			if _progress >= 1.0:
				# The adapter's long-press timer is authoritative for activation.
				# Keep the complete ring visible until that state transition arrives.
				set_process(false)
		State.CANCELLING:
			_elapsed += delta
			var t := clampf(_elapsed / maxf(_duration, 0.001), 0.0, 1.0)
			_progress = _cancel_start_progress * (1.0 - t)
			if t >= 1.0:
				dismiss()
				return
		_:
			set_process(false)
	queue_redraw()


func _draw() -> void:
	if _state == State.HIDDEN or _progress <= 0.0:
		return
	var start_angle := -PI * 0.5
	var end_angle := start_angle + TAU * _progress
	var ring_color := blend_ring_color(_initial_color, _target_color, _progress)
	# Alpha is forced opaque for legibility; RGB still communicates transparent sampled colors.
	ring_color.a = 1.0
	draw_arc(
		Vector2.ZERO,
		RADIUS_PX,
		start_angle,
		end_angle,
		ARC_POINTS,
		Color(0.0, 0.0, 0.0, 0.35),
		STROKE_WIDTH_PX + OUTLINE_EXTRA_PX,
		true
	)
	draw_arc(
		Vector2.ZERO,
		RADIUS_PX,
		start_angle,
		end_angle,
		ARC_POINTS,
		ring_color,
		STROKE_WIDTH_PX,
		true
	)
