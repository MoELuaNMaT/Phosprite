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

var _touches: Dictionary = {}
var _content_touch_id := -1
var _pencil_touch_id := -1
var _navigation_ids := PackedInt32Array()
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

	if _content_touch_id == -1 and direct_content_allowed(_finger_policy, false):
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


func _try_begin_navigation() -> void:
	# Navigation never coexists with active content ownership. In particular, Pencil
	# takes exclusive canvas ownership and suppresses held direct touches until release.
	if _pencil_touch_id != -1 or _content_touch_id != -1:
		return
	var direct_ids := PackedInt32Array()
	for id: int in _touches:
		var state: Dictionary = _touches[id]
		if int(state["kind"]) == PointerKind.DIRECT and not bool(state["suppressed"]):
			direct_ids.append(id)
	if direct_ids.size() < 2:
		return
	direct_ids.sort()
	_navigation_ids = PackedInt32Array([direct_ids[0], direct_ids[1]])
	_rebase_navigation()


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
	if valid_ids.size() < 2:
		_clear_navigation()
		_try_begin_navigation()
		return
	_navigation_ids = valid_ids
	var points := _navigation_points()
	_last_navigation_centroid = (points[0] + points[1]) * 0.5
	_last_navigation_distance = points[0].distance_to(points[1])


func _update_navigation() -> void:
	if _navigation_ids.size() != 2:
		return
	var camera := Global.camera as CanvasCamera
	if not is_instance_valid(camera):
		return
	var points := _navigation_points()
	var centroid := (points[0] + points[1]) * 0.5
	var distance := points[0].distance_to(points[1])
	var centroid_delta := centroid - _last_navigation_centroid
	if not centroid_delta.is_zero_approx():
		camera.offset -= centroid_delta.rotated(camera.camera_angle) / camera.zoom
		camera.update_transparent_checker_offset()
	if _last_navigation_distance > TWO_FINGER_EPSILON and distance > TWO_FINGER_EPSILON:
		var scale_factor := distance / _last_navigation_distance
		if not is_equal_approx(scale_factor, 1.0):
			camera.zoom_camera(log(scale_factor) * 8.0, centroid)
	_last_navigation_centroid = centroid
	_last_navigation_distance = distance


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
