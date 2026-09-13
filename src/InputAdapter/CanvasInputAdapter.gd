class_name CanvasInputAdapter
extends RefCounted

## iPad-first input arbitration for the canvas.
##
## Physical input is normalized here before it reaches the legacy left/right tool slots.
## Individual tools must not need to know whether an event came from Pencil, finger or mouse.

enum PointerKind { UNKNOWN, PENCIL, DIRECT, INDIRECT }
enum FingerPolicy { UNRESTRICTED, FINGER_NAVIGATION_ONLY, PENCIL_PRIORITY }

const POINTER_IDENTITY_SINGLETON := &"PhospritePointerIdentity"
const PREFERENCE_SECTION := "preferences"
const FINGER_POLICY_KEY := "finger_policy"
const DEFAULT_FINGER_POLICY := FingerPolicy.PENCIL_PRIORITY
const TWO_FINGER_EPSILON := 0.01

# P1-C2 uses small acquisition-only dead zones. Once a degree of freedom activates,
# navigation is direct from the fixed pair baseline: no inertia, no smoothing tween
# and no incremental accumulation from the previous drag event.
const NAVIGATION_PAN_DEAD_ZONE_PX := 0.75
const NAVIGATION_PINCH_DEAD_ZONE_FRACTION := 0.005
const TWO_FINGER_ROTATION_ENABLED := false

var _touches: Dictionary = {}
var _content_touch_id := -1
var _pencil_touch_id := -1
var _navigation_ids := PackedInt32Array()
var _navigation_baseline_centroid := Vector2.ZERO
var _navigation_baseline_distance := 0.0
var _navigation_baseline_pair_angle := 0.0
var _navigation_baseline_zoom := Vector2.ONE
var _navigation_baseline_offset := Vector2.ZERO
var _navigation_baseline_camera_angle := 0.0
var _navigation_anchor_canvas := Vector2.ZERO
var _navigation_camera_baseline_valid := false
var _navigation_pan_active := false
var _navigation_pinch_active := false
# Kept as pair-begin snapshots for P1-C1 compatibility/debugging. C2 never accumulates from them.
var _last_navigation_centroid := Vector2.ZERO
var _last_navigation_distance := 0.0
var _finger_policy := DEFAULT_FINGER_POLICY
var _initialized := false


func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	_finger_policy = int(
		Global.config_cache.get_value(PREFERENCE_SECTION, FINGER_POLICY_KEY, DEFAULT_FINGER_POLICY)
	)
	if _finger_policy < FingerPolicy.UNRESTRICTED or _finger_policy > FingerPolicy.PENCIL_PRIORITY:
		_finger_policy = DEFAULT_FINGER_POLICY


func is_enabled() -> bool:
	return OS.get_name() == "iOS"


func handle_event(canvas: Node2D, event: InputEvent) -> bool:
	if not is_enabled():
		return false
	if not _initialized:
		initialize()

	if event is InputEventScreenTouch:
		_handle_touch(canvas, event as InputEventScreenTouch)
		return true
	if event is InputEventScreenDrag:
		_handle_drag(canvas, event as InputEventScreenDrag)
		return true
	if event is InputEventGesture:
		# iPad navigation is derived from raw ScreenTouch/ScreenDrag. Do not let an
		# additional gesture event cancel an active tool, double-navigate or move the cursor.
		return true
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		# Godot marks touch-generated mouse events with DEVICE_ID_EMULATION (-1).
		# Filter them only on the Canvas path; GUI Controls keep the global setting.
		return _is_emulated_touch_mouse(event)
	return false


func install_preferences_ui(scene_root: Node) -> void:
	if not is_enabled() or not is_instance_valid(scene_root):
		return
	var preferences_dialog := scene_root.find_child("PreferencesDialog", true, false)
	if not is_instance_valid(preferences_dialog):
		return
	var options := preferences_dialog.find_child("ToolOptions", true, false) as GridContainer
	if not is_instance_valid(options) or options.has_node("FingerPolicyLabel"):
		return

	var label := Label.new()
	label.name = "FingerPolicyLabel"
	label.text = "Finger input mode"
	label.tooltip_text = "Controls whether direct touch can edit the canvas when using iPad."
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Preferences uses a three-column grid after it inserts restore buttons. This spacer keeps
	# the P1-B preference aligned while persisting through the same config cache as other prefs.
	var spacer := Control.new()
	spacer.name = "FingerPolicySpacer"

	var option := OptionButton.new()
	option.name = "FingerPolicyOptionButton"
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	option.tooltip_text = (
		"Unrestricted allows direct touch editing. Navigation only reserves fingers for canvas "
		+ "navigation. Pencil priority allows finger editing while Pencil is idle. While Pencil "
		+ "owns the canvas, direct touches are ignored until they are released."
	)
	option.add_item("Unrestricted", FingerPolicy.UNRESTRICTED)
	option.add_item("Finger navigation only", FingerPolicy.FINGER_NAVIGATION_ONLY)
	option.add_item("Pencil priority", FingerPolicy.PENCIL_PRIORITY)
	option.select(option.get_item_index(_finger_policy))
	option.item_selected.connect(_on_finger_policy_selected.bind(option))

	options.add_child(label)
	options.add_child(spacer)
	options.add_child(option)


func reset(canvas: Node2D) -> void:
	if _content_touch_id != -1:
		_cancel_active_tool()
	_content_touch_id = -1
	_pencil_touch_id = -1
	_touches.clear()
	_clear_navigation()
	_clear_pointer_identity_pending()
	if is_instance_valid(canvas):
		canvas.set_adapter_tool_preview_active(false)
		canvas.queue_redraw()


static func direct_content_allowed(policy: int, pencil_active: bool) -> bool:
	if pencil_active:
		return false
	match policy:
		FingerPolicy.UNRESTRICTED:
			return true
		FingerPolicy.FINGER_NAVIGATION_ONLY:
			return false
		FingerPolicy.PENCIL_PRIORITY:
			return true
	return false


static func direct_content_navigation_takeover_allowed(
	content_kind: int, pencil_active: bool, navigation_active: bool, direct_touch_count: int
) -> bool:
	return (
		content_kind == PointerKind.DIRECT
		and not pencil_active
		and not navigation_active
		and direct_touch_count >= 2
	)


static func navigation_pair_geometry(
	first_position: Vector2, second_position: Vector2
) -> Dictionary:
	var delta := second_position - first_position
	return {
		"centroid": (first_position + second_position) * 0.5,
		"distance": delta.length(),
		"angle": delta.angle(),
	}


static func navigation_scale_ratio(baseline_distance: float, current_distance: float) -> float:
	if baseline_distance <= TWO_FINGER_EPSILON or current_distance <= TWO_FINGER_EPSILON:
		return 1.0
	return current_distance / baseline_distance


static func navigation_pan_exceeds_dead_zone(
	baseline_centroid: Vector2, current_centroid: Vector2
) -> bool:
	return baseline_centroid.distance_to(current_centroid) >= NAVIGATION_PAN_DEAD_ZONE_PX


static func navigation_pinch_exceeds_dead_zone(
	baseline_distance: float, current_distance: float
) -> bool:
	var ratio := navigation_scale_ratio(baseline_distance, current_distance)
	var upper_ratio := 1.0 + NAVIGATION_PINCH_DEAD_ZONE_FRACTION
	return ratio >= upper_ratio or ratio <= 1.0 / upper_ratio


static func navigation_zoom_from_ratio(
	baseline_zoom: Vector2,
	scale_ratio: float,
	integer_zoom: bool,
	zoom_out_max: Vector2,
	zoom_in_max: Vector2
) -> Vector2:
	var target_scalar := baseline_zoom.x * maxf(scale_ratio, TWO_FINGER_EPSILON)
	if integer_zoom:
		target_scalar = maxf(1.0, roundf(target_scalar))
	target_scalar = clampf(target_scalar, zoom_out_max.x, zoom_in_max.x)
	return Vector2.ONE * target_scalar


static func screen_to_canvas_point(
	screen_position: Vector2,
	viewport_size: Vector2,
	zoom: Vector2,
	offset: Vector2,
	camera_angle: float
) -> Vector2:
	return offset + ((screen_position - viewport_size * 0.5) / zoom).rotated(camera_angle)


static func navigation_offset_for_anchor(
	anchor_canvas: Vector2,
	centroid: Vector2,
	viewport_size: Vector2,
	target_zoom: Vector2,
	camera_angle: float
) -> Vector2:
	return anchor_canvas - ((centroid - viewport_size * 0.5) / target_zoom).rotated(camera_angle)


static func navigation_target_angle(
	baseline_camera_angle: float,
	baseline_pair_angle: float,
	current_pair_angle: float,
	rotation_enabled: bool
) -> float:
	if not rotation_enabled:
		return baseline_camera_angle
	var pair_delta := wrapf(current_pair_angle - baseline_pair_angle, -PI, PI)
	return wrapf(baseline_camera_angle + pair_delta, -PI, PI)


func _handle_touch(canvas: Node2D, event: InputEventScreenTouch) -> void:
	if event.pressed:
		_begin_touch(canvas, event)
	else:
		_end_touch(canvas, event)


func _begin_touch(canvas: Node2D, event: InputEventScreenTouch) -> void:
	var info := _consume_pointer_info(event.index)
	var kind := int(info.get("kind", PointerKind.UNKNOWN))
	if kind == PointerKind.UNKNOWN:
		# The production iOS build supplies formal UITouch.type identity. Keeping
		# UNKNOWN as direct touch makes editor/development builds usable without it.
		kind = PointerKind.DIRECT
	var state := {
		"kind": kind,
		"position": event.position,
		"previous_position": event.position,
		"suppressed": false,
	}
	_touches[event.index] = state

	# A touch that does not acquire content ownership must not inherit a stale PC-style
	# hover preview from Godot's emulated mouse stream.
	if _content_touch_id == -1:
		canvas.set_adapter_tool_preview_active(false)

	if kind == PointerKind.PENCIL:
		_begin_pencil_ownership(canvas, event.index)
		_start_content(canvas, event.index, event.position)
		return
	if kind != PointerKind.DIRECT:
		return

	if _pencil_touch_id != -1:
		# Pencil has exclusive canvas ownership. A direct touch that begins during
		# that ownership stays suppressed until its own release; it is never revived mid-contact.
		state["suppressed"] = true
		_touches[event.index] = state
		return

	# Once a navigation pair owns the canvas, additional fingers stay unowned. They may
	# become a replacement member only after one of the active pair members is released.
	if _navigation_ids.size() == 2:
		return

	if _content_touch_id != -1:
		# In Unrestricted/Pencil Priority the first direct touch may legitimately begin
		# editing. A second direct touch upgrades that interaction to navigation by
		# cancelling (not committing) the in-progress tool operation and pairing both touches.
		_try_promote_direct_content_to_navigation(canvas)
		return

	if direct_content_allowed(_finger_policy, false):
		_start_content(canvas, event.index, event.position)
	else:
		_try_begin_navigation()


func _end_touch(canvas: Node2D, event: InputEventScreenTouch) -> void:
	var state: Dictionary = _touches.get(event.index, {})
	if state.is_empty():
		return

	if _content_touch_id == event.index:
		_end_content(canvas, event.index, event.position)
	if _pencil_touch_id == event.index:
		_pencil_touch_id = -1

	_touches.erase(event.index)
	if event.index in _navigation_ids:
		_rebase_navigation()


func _handle_drag(canvas: Node2D, event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		# A drag without a captured begin should not acquire editing ownership.
		return
	var state: Dictionary = _touches[event.index]
	state["previous_position"] = state["position"]
	state["position"] = event.position
	_touches[event.index] = state

	# Pointer identity is decided only at touch begin by the native UITouch.type bridge.
	# Pressure and tilt are payload for a verified Pencil stroke, never identity heuristics.
	if bool(state["suppressed"]):
		return
	if _content_touch_id == event.index:
		_dispatch_motion(canvas, event, int(state["kind"]))
		return
	if _pencil_touch_id != -1:
		return

	if _navigation_ids.size() < 2:
		_try_begin_navigation()
	if event.index in _navigation_ids:
		_update_navigation()


func _begin_pencil_ownership(canvas: Node2D, touch_id: int) -> void:
	_pencil_touch_id = touch_id

	# A finger content stroke is never retroactively converted to navigation. Pencil
	# explicitly preempts it; cancel through the existing Tool boundary, then owns content.
	if _content_touch_id != -1 and _content_touch_id != touch_id:
		_cancel_active_tool()
		_content_touch_id = -1

	# Pencil takes exclusive canvas ownership. Existing direct touches are suppressed
	# until each one is physically released, so a resting finger/palm cannot immediately
	# reacquire navigation when Pencil starts or stops.
	_suppress_direct_touches_until_release()
	_clear_navigation()
	if is_instance_valid(canvas):
		canvas.queue_redraw()


func _start_content(canvas: Node2D, touch_id: int, screen_position: Vector2) -> void:
	if _content_touch_id != -1 and _content_touch_id != touch_id:
		return
	_content_touch_id = touch_id
	_clear_navigation()
	canvas.set_adapter_tool_preview_active(true)
	var event := InputEventMouseButton.new()
	event.device = -1
	event.position = screen_position
	event.global_position = screen_position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	canvas.handle_adapter_tool_event(screen_position, event)


func _end_content(canvas: Node2D, touch_id: int, screen_position: Vector2) -> void:
	if _content_touch_id != touch_id:
		return
	var event := InputEventMouseButton.new()
	event.device = -1
	event.position = screen_position
	event.global_position = screen_position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = 0
	event.pressed = false
	canvas.handle_adapter_tool_event(screen_position, event)
	_content_touch_id = -1
	canvas.set_adapter_tool_preview_active(false)


func _dispatch_motion(canvas: Node2D, drag: InputEventScreenDrag, kind: int) -> void:
	var event := InputEventMouseMotion.new()
	event.device = -1
	event.position = drag.position
	event.global_position = drag.position
	event.relative = drag.relative
	event.screen_relative = drag.screen_relative
	event.velocity = drag.velocity
	event.screen_velocity = drag.screen_velocity
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressure = drag.pressure if kind == PointerKind.PENCIL else 1.0
	event.tilt = drag.tilt if kind == PointerKind.PENCIL else Vector2.ZERO
	event.pen_inverted = drag.pen_inverted if kind == PointerKind.PENCIL else false
	canvas.handle_adapter_tool_event(drag.position, event)


func _try_promote_direct_content_to_navigation(canvas: Node2D) -> bool:
	if _content_touch_id == -1 or not _touches.has(_content_touch_id):
		return false
	var direct_ids := _eligible_direct_touch_ids()
	var content_state: Dictionary = _touches[_content_touch_id]
	if not direct_content_navigation_takeover_allowed(
		int(content_state["kind"]),
		_pencil_touch_id != -1,
		_navigation_ids.size() == 2,
		direct_ids.size()
	):
		return false

	_cancel_active_tool()
	_content_touch_id = -1
	if is_instance_valid(canvas):
		canvas.set_adapter_tool_preview_active(false)
		canvas.queue_redraw()
	_begin_navigation_pair(PackedInt32Array([direct_ids[0], direct_ids[1]]))
	return true


func _try_begin_navigation() -> void:
	# Navigation never coexists with active content ownership. In particular, Pencil
	# takes exclusive canvas ownership and suppresses held direct touches until release.
	if _pencil_touch_id != -1 or _content_touch_id != -1 or _navigation_ids.size() == 2:
		return
	var direct_ids := _eligible_direct_touch_ids()
	if direct_ids.size() < 2:
		return
	_begin_navigation_pair(PackedInt32Array([direct_ids[0], direct_ids[1]]))


func _eligible_direct_touch_ids() -> PackedInt32Array:
	var direct_ids := PackedInt32Array()
	for id: int in _touches:
		var state: Dictionary = _touches[id]
		if int(state["kind"]) == PointerKind.DIRECT and not bool(state["suppressed"]):
			direct_ids.append(id)
	direct_ids.sort()
	return direct_ids


func _begin_navigation_pair(pair_ids: PackedInt32Array) -> void:
	if pair_ids.size() != 2:
		return
	if not _touches.has(pair_ids[0]) or not _touches.has(pair_ids[1]):
		return
	_navigation_ids = PackedInt32Array([pair_ids[0], pair_ids[1]])
	var geometry := _navigation_geometry()
	_set_navigation_geometry_baseline(geometry)
	_capture_navigation_camera_baseline()


func _set_navigation_geometry_baseline(geometry: Dictionary) -> void:
	_navigation_baseline_centroid = geometry["centroid"]
	_navigation_baseline_distance = geometry["distance"]
	_navigation_baseline_pair_angle = geometry["angle"]
	_last_navigation_centroid = _navigation_baseline_centroid
	_last_navigation_distance = _navigation_baseline_distance
	_navigation_pan_active = false
	_navigation_pinch_active = false


func _capture_navigation_camera_baseline() -> bool:
	var camera := Global.camera as CanvasCamera
	if not is_instance_valid(camera) or not is_instance_valid(camera.viewport_container):
		_navigation_camera_baseline_valid = false
		return false
	_navigation_baseline_zoom = camera.zoom
	_navigation_baseline_offset = camera.offset
	_navigation_baseline_camera_angle = camera.camera_angle
	_navigation_anchor_canvas = screen_to_canvas_point(
		_navigation_baseline_centroid,
		camera.viewport_container.size,
		_navigation_baseline_zoom,
		_navigation_baseline_offset,
		_navigation_baseline_camera_angle
	)
	_navigation_camera_baseline_valid = true
	return true


func _rebase_navigation() -> void:
	if _pencil_touch_id != -1 or _content_touch_id != -1:
		_clear_navigation()
		return
	var valid_ids := PackedInt32Array()
	for id: int in _navigation_ids:
		if _touches.has(id):
			var state: Dictionary = _touches[id]
			if int(state["kind"]) == PointerKind.DIRECT and not bool(state["suppressed"]):
				valid_ids.append(id)
	if valid_ids.size() == 2:
		# The same pair is still active; its pair-level baseline must remain unchanged.
		return
	_clear_navigation()
	_try_begin_navigation()


func _update_navigation() -> void:
	if _navigation_ids.size() != 2:
		return
	var camera := Global.camera as CanvasCamera
	if not is_instance_valid(camera) or not is_instance_valid(camera.viewport_container):
		return

	var geometry := _navigation_geometry()
	if not _navigation_camera_baseline_valid:
		# This is only a defensive fallback for a pair captured before the camera was ready.
		# Rebase to the current pair/camera and emit no transform on this frame.
		_set_navigation_geometry_baseline(geometry)
		_capture_navigation_camera_baseline()
		return

	var centroid: Vector2 = geometry["centroid"]
	var distance: float = geometry["distance"]
	if not _navigation_pan_active:
		_navigation_pan_active = navigation_pan_exceeds_dead_zone(
			_navigation_baseline_centroid, centroid
		)
	if not _navigation_pinch_active:
		_navigation_pinch_active = navigation_pinch_exceeds_dead_zone(
			_navigation_baseline_distance, distance
		)

	var effective_centroid := _navigation_baseline_centroid
	if _navigation_pan_active:
		effective_centroid = centroid
	var scale_ratio := 1.0
	if _navigation_pinch_active:
		scale_ratio = navigation_scale_ratio(_navigation_baseline_distance, distance)

	var target_angle := navigation_target_angle(
		_navigation_baseline_camera_angle,
		_navigation_baseline_pair_angle,
		float(geometry["angle"]),
		TWO_FINGER_ROTATION_ENABLED
	)
	var target_zoom := navigation_zoom_from_ratio(
		_navigation_baseline_zoom,
		scale_ratio,
		Global.integer_zoom,
		camera.zoom_out_max,
		camera.zoom_in_max
	)
	var target_offset := navigation_offset_for_anchor(
		_navigation_anchor_canvas,
		effective_centroid,
		camera.viewport_container.size,
		target_zoom,
		target_angle
	)

	# Continuous touch gestures must track the fingers directly. Pixelorama's mouse/wheel
	# smooth-zoom tween is intentionally bypassed here because it adds visible input latency.
	if not is_equal_approx(camera.camera_angle, target_angle):
		camera.camera_angle = target_angle
	if not camera.zoom.is_equal_approx(target_zoom):
		camera.zoom = target_zoom
	if not camera.offset.is_equal_approx(target_offset):
		camera.offset = target_offset
	camera.update_transparent_checker_offset()


func _navigation_geometry() -> Dictionary:
	var points := _navigation_points()
	return navigation_pair_geometry(points[0], points[1])


func _navigation_points() -> Array[Vector2]:
	var first: Dictionary = _touches[_navigation_ids[0]]
	var second: Dictionary = _touches[_navigation_ids[1]]
	return [first["position"], second["position"]]


func _suppress_direct_touches_until_release() -> void:
	for id: int in _touches:
		var state: Dictionary = _touches[id]
		if int(state["kind"]) != PointerKind.DIRECT:
			continue
		state["suppressed"] = true
		_touches[id] = state


func _clear_navigation() -> void:
	_navigation_ids.clear()
	_navigation_baseline_centroid = Vector2.ZERO
	_navigation_baseline_distance = 0.0
	_navigation_baseline_pair_angle = 0.0
	_navigation_baseline_zoom = Vector2.ONE
	_navigation_baseline_offset = Vector2.ZERO
	_navigation_baseline_camera_angle = 0.0
	_navigation_anchor_canvas = Vector2.ZERO
	_navigation_camera_baseline_valid = false
	_navigation_pan_active = false
	_navigation_pinch_active = false
	_last_navigation_centroid = Vector2.ZERO
	_last_navigation_distance = 0.0


func _consume_pointer_info(touch_id: int) -> Dictionary:
	if not Engine.has_singleton(POINTER_IDENTITY_SINGLETON):
		return {}
	var bridge := Engine.get_singleton(POINTER_IDENTITY_SINGLETON)
	var result: Variant = bridge.call("consume_begin_info", touch_id)
	return result if result is Dictionary else {}


func _clear_pointer_identity_pending() -> void:
	if not Engine.has_singleton(POINTER_IDENTITY_SINGLETON):
		return
	Engine.get_singleton(POINTER_IDENTITY_SINGLETON).call("clear_pending")


func _cancel_active_tool() -> void:
	var button := Tools.active_button
	if button == -1:
		return
	if Tools._slots.has(button) and is_instance_valid(Tools._slots[button].tool_node):
		Tools._slots[button].tool_node.cancel_tool()
	Tools.active_button = -1
	Tools.pen_inverted = false
	Tools.mouse_velocity = 0.0


func _on_finger_policy_selected(index: int, option: OptionButton) -> void:
	_finger_policy = option.get_item_id(index)
	Global.config_cache.set_value(PREFERENCE_SECTION, FINGER_POLICY_KEY, _finger_policy)
	var error := Global.config_cache.save(Global.CONFIG_PATH)
	if error != OK:
		push_warning("Could not save finger input mode: %s" % error_string(error))


func _is_emulated_touch_mouse(event: InputEvent) -> bool:
	return event.device == -1
