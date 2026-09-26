class_name TouchUIBehavior
extends Node

## Central iPad GUI policy for touch-first interaction.
##
## Normal GUI Controls still use Godot's touch-to-mouse emulation. This node keeps
## the emulated pointer from leaking desktop hover tooltips or button focus rings
## into direct-touch interaction, while restoring normal hover semantics when a
## real mouse or trackpad is used.

const TOOLTIP_META := &"phosprite_touch_original_tooltip"
const TOUCH_BIND_META := &"phosprite_touch_ui_bound"

var enabled := false
var _tree: SceneTree
var _ui_root: Node
var _touch_ui_mode := false


func setup(scene_tree: SceneTree, ui_root: Node, force_enabled := false) -> bool:
	if scene_tree == null or ui_root == null or _tree != null:
		return false
	_tree = scene_tree
	_ui_root = ui_root
	enabled = force_enabled or OS.get_name() == "iOS"
	if not enabled:
		return true
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
		_enter_touch_ui_mode()
		call_deferred(&"_suppress_hovered_tooltip")
		if not (event as InputEventScreenTouch).pressed:
			call_deferred(&"_release_touch_button_focus")
		return
	if (
		(event is InputEventMouseMotion or event is InputEventMouseButton)
		and event.device != InputEvent.DEVICE_ID_EMULATION
	):
		_restore_pointer_ui_mode()


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
	if not enabled or not _is_in_ui_scope(node):
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
