class_name TouchUIBehavior
extends Node

## Central iPad GUI policy for touch-first interaction.
##
## Phosprite intentionally keeps Godot's touch-to-mouse emulation enabled because
## normal GUI Controls still rely on it. On iPad that emulation must not leak
## desktop-only hover/focus affordances back into the touch UI.

var enabled := false
var _tree: SceneTree


func setup(scene_tree: SceneTree, force_enabled := false) -> bool:
	if scene_tree == null or _tree != null:
		return false
	_tree = scene_tree
	enabled = force_enabled or OS.get_name() == "iOS"
	if not enabled:
		return true
	if not _tree.node_added.is_connected(_on_node_added):
		_tree.node_added.connect(_on_node_added)
	_apply_to_subtree(_tree.root)
	return true


func _exit_tree() -> void:
	if _tree != null and _tree.node_added.is_connected(_on_node_added):
		_tree.node_added.disconnect(_on_node_added)
	_tree = null


func _input(event: InputEvent) -> void:
	if not enabled or not event is InputEventScreenTouch:
		return
	var touch := event as InputEventScreenTouch
	if touch.pressed:
		return
	call_deferred(&"_release_touch_button_focus")


func _on_node_added(node: Node) -> void:
	if not enabled or node == null:
		return
	_apply_to_node(node)
	call_deferred(&"_apply_to_node_if_valid", node)


func _apply_to_subtree(node: Node) -> void:
	if node == null:
		return
	_apply_to_node(node)
	for child in node.get_children():
		_apply_to_subtree(child)


func _apply_to_node_if_valid(node: Node) -> void:
	if is_instance_valid(node):
		_apply_to_node(node)


func _apply_to_node(node: Node) -> void:
	var control := node as Control
	if control == null:
		return
	if not control.tooltip_text.is_empty():
		control.tooltip_text = ""


func _release_touch_button_focus() -> void:
	if not enabled or _tree == null or _tree.root == null:
		return
	var focus_owner := _tree.root.gui_get_focus_owner()
	if focus_owner is BaseButton:
		(focus_owner as BaseButton).release_focus()
