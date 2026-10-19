class_name TouchUIBehavior
extends Node

## Central iPad GUI policy for touch-first interaction.
##
## Godot can append a Shortcut to a BaseButton tooltip even when tooltip_text
## is empty. Disable shortcut hints throughout the UI on every platform, while
## retaining descriptive desktop tooltips. On iOS, also prevent touch-to-mouse
## emulation from leaking sticky hover tooltips or button focus rings. A genuine
## mouse/trackpad restores descriptive hover semantics after touch has settled.

const TOOLTIP_META := &"phosprite_touch_original_tooltip"
const TOUCH_BIND_META := &"phosprite_touch_ui_bound"
const TOUCH_POINTER_GRACE_MSEC := 500

var enabled := false
var _tree: SceneTree
var _ui_root: Node
var _touch_ui_mode := false
var _active_touches: Dictionary = {}
var _last_touch_event_msec := -1


func setup(scene_tree: SceneTree, ui_root: Node, force_enabled := false) -> bool:
	if scene_tree == null or ui_root == null or _tree != null:
		return false
	_tree = scene_tree
	_ui_root = ui_root
	enabled = force_enabled or OS.get_name() == "iOS"
	# Even desktop builds should not automatically append shortcut strings
	# to hover tooltips. The keyboard shortcuts themselves remain active.
	if not _tree.node_added.is_connected(_on_node_added):
		_tree.node_added.connect(_on_node_added)
	_bind_subtree(_ui_root)
	return true


func is_touch_ui_mode() -> bool:
	return _touch_ui_mode


func _exit_tree() -> void:
	if _tree != null and _tree.node_added.is_connected(_on_node_added):
		_tree.node_added.disconnect(_on_node_added)
	_tree = null
	_ui_root = null


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_last_touch_event_msec = Time.get_ticks_msec()
		if touch.pressed and not touch.canceled:
			_active_touches[touch.index] = true
		else:
			_active_touches.erase(touch.index)
		_enter_touch_ui_mode()
		call_deferred(&"_suppress_hovered_tooltip")
		if not touch.pressed or touch.canceled:
			call_deferred(&"_release_touch_button_focus")
		return
	if event is InputEventScreenDrag:
		_last_touch_event_msec = Time.get_ticks_msec()
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		if should_restore_pointer_mode(
			event.device,
			not _active_touches.is_empty(),
			Time.get_ticks_msec(),
			_last_touch_event_msec
		):
			_restore_pointer_ui_mode()


## Some platforms report a touch-generated mouse event as device 0 rather
## than DEVICE_ID_EMULATION. Treat nearby mouse events as ambiguous until
## the final touch is released and a short grace period has elapsed.
static func should_restore_pointer_mode(
	device_id: int, has_active_touch: bool, now_msec: int, last_touch_msec: int
) -> bool:
	if device_id == InputEvent.DEVICE_ID_EMULATION or has_active_touch:
		return false
	return last_touch_msec < 0 or now_msec - last_touch_msec > TOUCH_POINTER_GRACE_MSEC


func _enter_touch_ui_mode() -> void:
	if _touch_ui_mode:
		return
	_touch_ui_mode = true
	_suppress_subtree_tooltips(_ui_root)


func _restore_pointer_ui_mode() -> void:
	if not _touch_ui_mode:
		return
	_touch_ui_mode = false
	_restore_subtree_tooltips(_ui_root)


func _on_node_added(node: Node) -> void:
	if not _is_in_ui_scope(node):
		return
	_bind_subtree(node)


func _bind_subtree(node: Node) -> void:
	if node == null:
		return
	var control := node as Control
	if control != null:
		_bind_control(control)
	for child in node.get_children():
		_bind_subtree(child)


func _bind_control(control: Control) -> void:
	# BaseButton creates an additional tooltip for its Shortcut automatically.
	# This is distinct from Control.tooltip_text and must be disabled separately.
	if control is BaseButton:
		(control as BaseButton).shortcut_in_tooltip = false
	if not enabled:
		return
	if not control.has_meta(TOUCH_BIND_META):
		control.set_meta(TOUCH_BIND_META, true)
		control.mouse_entered.connect(_on_control_mouse_entered.bind(control))
	if _touch_ui_mode:
		_suppress_control_tooltip(control)


func _on_control_mouse_entered(control: Control) -> void:
	if enabled and _touch_ui_mode and is_instance_valid(control):
		_suppress_control_tooltip(control)


func _suppress_subtree_tooltips(node: Node) -> void:
	if node == null:
		return
	var control := node as Control
	if control != null:
		_suppress_control_tooltip(control)
	for child in node.get_children():
		_suppress_subtree_tooltips(child)


func _restore_subtree_tooltips(node: Node) -> void:
	if node == null:
		return
	var control := node as Control
	if control != null and control.has_meta(TOOLTIP_META):
		control.tooltip_text = str(control.get_meta(TOOLTIP_META, ""))
	for child in node.get_children():
		_restore_subtree_tooltips(child)


func _suppress_control_tooltip(control: Control) -> void:
	if not is_instance_valid(control) or control.tooltip_text.is_empty():
		return
	control.set_meta(TOOLTIP_META, control.tooltip_text)
	control.tooltip_text = ""


func _suppress_hovered_tooltip() -> void:
	if not enabled or not _touch_ui_mode:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var hovered := viewport.gui_get_hovered_control()
	while is_instance_valid(hovered):
		_suppress_control_tooltip(hovered)
		hovered = hovered.get_parent_control()


func _release_touch_button_focus() -> void:
	if not enabled or not _touch_ui_mode:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var focus_owner := viewport.gui_get_focus_owner()
	if focus_owner is BaseButton:
		(focus_owner as BaseButton).release_focus()


func _is_in_ui_scope(node: Node) -> bool:
	if node == null or not is_instance_valid(_ui_root):
		return false
	return node == _ui_root or _ui_root.is_ancestor_of(node)
