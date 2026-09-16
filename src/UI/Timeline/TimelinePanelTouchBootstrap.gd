extends Node

const TIMELINE_PANEL_TOUCH_MANAGER := preload("res://src/UI/Timeline/TimelinePanelTouchManager.gd")
const PANEL_MANAGER_NAME := "TimelinePanelTouchManager"


func _ready() -> void:
	if OS.get_name() != "iOS":
		return
	call_deferred("_install_ios_timeline_panel_touch")


func _install_ios_timeline_panel_touch() -> void:
	var timeline := Global.animation_timeline
	if not is_instance_valid(timeline):
		await get_tree().process_frame
		timeline = Global.animation_timeline
	if not is_instance_valid(timeline) or timeline.has_node(PANEL_MANAGER_NAME):
		return
	var manager := TIMELINE_PANEL_TOUCH_MANAGER.new() as Node
	manager.name = PANEL_MANAGER_NAME
	timeline.add_child(manager)
