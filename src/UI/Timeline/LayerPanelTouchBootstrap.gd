extends Node

const LAYER_PANEL_TOUCH_MANAGER := preload("res://src/UI/Timeline/LayerPanelTouchManager.gd")
const IOS_SIDE_TOUCH_WIDTH := 44.0
const IOS_SIDE_CONTROL_SLOTS := 3.0
const PANEL_MANAGER_NAME := "LayerPanelTouchManager"


func _ready() -> void:
	if OS.get_name() != "iOS":
		return
	call_deferred("_install_ios_layer_panel_touch")


func _install_ios_layer_panel_touch() -> void:
	var layer_button := get_parent() as Control
	if not is_instance_valid(layer_button):
		return
	var side_container := layer_button.get_node_or_null("HBoxContainer") as HBoxContainer
	if is_instance_valid(side_container):
		side_container.custom_minimum_size.x = IOS_SIDE_TOUCH_WIDTH * IOS_SIDE_CONTROL_SLOTS
	for node_name in ["VisibilityButton", "LockButton", "LinkButton", "ExpandButton"]:
		var button := layer_button.get_node_or_null("HBoxContainer/" + node_name) as Control
		if is_instance_valid(button):
			# Keep the row height governed by Timeline cel_size, but give each direct action
			# a full finger-width target instead of the desktop 28 px slot.
			button.custom_minimum_size.x = IOS_SIDE_TOUCH_WIDTH

	var timeline := Global.animation_timeline
	if not is_instance_valid(timeline):
		await get_tree().process_frame
		timeline = Global.animation_timeline
	if not is_instance_valid(timeline) or timeline.has_node(PANEL_MANAGER_NAME):
		return
	var manager := LAYER_PANEL_TOUCH_MANAGER.new() as Node
	manager.name = PANEL_MANAGER_NAME
	timeline.add_child(manager)
