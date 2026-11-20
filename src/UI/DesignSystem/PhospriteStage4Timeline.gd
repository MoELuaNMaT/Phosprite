class_name PhospriteStage4Timeline
extends RefCounted

## Paints existing timeline controls; owns no input or project state.
const Stage4 := preload("res://src/UI/DesignSystem/PhospriteStage4Chrome.gd")


static func apply(timeline: Control) -> void:
	if not is_instance_valid(timeline) or not timeline.is_node_ready():
		return
	var mode := Stage4.active_mode()
	Stage4.style_panel(timeline, mode)
	for panel_name in ["LayerTools", "AnimationTools"]:
		var panel := timeline.find_child(panel_name, true, false) as Control
		Stage4.style_panel(panel, mode)
	for group_name in ["LayerButtons", "AnimationButtons"]:
		var group := timeline.find_child(group_name, true, false)
		if group == null:
			continue
		for child in group.find_children("*", "Button", true, false):
			Stage4.style_button(child as Button, mode)
	var blend_modes := timeline.find_child("BlendModes", true, false) as OptionButton
	Stage4.style_option(blend_modes, mode)
