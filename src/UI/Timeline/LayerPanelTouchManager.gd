extends Node

const IOS_TOUCH_TARGET_PX := 44.0
const IOS_ADD_LAYER_TARGET_WIDTH := IOS_TOUCH_TARGET_PX * 2.0
const IOS_LAYER_TOOLBAR_SEPARATION := 4
const LAYER_BUTTONS_PATH := (
	"TimelineContainer/TimelineButtons/LayerTools/"
	+ "MarginContainer/LayerSettingsContainer/LayerButtons"
)

var _timeline: Control
var _layer_buttons: HBoxContainer
var _add_layer: Button
var _add_layer_list: MenuButton
var _remove_layer: Button
var _move_up_layer: Button
var _move_down_layer: Button
var _clone_layer: Button
var _merge_down_layer: Button
var _layer_fx: Button
var _keyframe_timeline: Button


func _ready() -> void:
	if OS.get_name() != "iOS":
		queue_free()
		return
	call_deferred("_install_ios_layer_toolbar")


func _install_ios_layer_toolbar() -> void:
	_timeline = get_parent() as Control
	if not is_instance_valid(_timeline):
		return
	_layer_buttons = _timeline.get_node_or_null(LAYER_BUTTONS_PATH) as HBoxContainer
	if not is_instance_valid(_layer_buttons):
		return
	_add_layer = _layer_buttons.get_node_or_null("AddLayer") as Button
	_add_layer_list = _layer_buttons.get_node_or_null("AddLayer/AddLayerList") as MenuButton
	if not is_instance_valid(_add_layer_list):
		# TimelinePanelTouchManager can already have detached the dropdown
		# into a standalone compact layer-type button.
		_add_layer_list = _layer_buttons.get_node_or_null("AddLayerList") as MenuButton
	_remove_layer = _layer_buttons.get_node_or_null("RemoveLayer") as Button
	_move_up_layer = _layer_buttons.get_node_or_null("MoveUpLayer") as Button
	_move_down_layer = _layer_buttons.get_node_or_null("MoveDownLayer") as Button
	_clone_layer = _layer_buttons.get_node_or_null("CloneLayer") as Button
	_merge_down_layer = _layer_buttons.get_node_or_null("MergeDownLayer") as Button
	_layer_fx = _layer_buttons.get_node_or_null("LayerFX") as Button
	_keyframe_timeline = _layer_buttons.get_node_or_null("KeyframeTimelineButton") as Button
	if not _all_toolbar_nodes_valid():
		return

	_configure_touch_geometry()


func _all_toolbar_nodes_valid() -> bool:
	return (
		is_instance_valid(_add_layer)
		and is_instance_valid(_add_layer_list)
		and is_instance_valid(_remove_layer)
		and is_instance_valid(_move_up_layer)
		and is_instance_valid(_move_down_layer)
		and is_instance_valid(_clone_layer)
		and is_instance_valid(_merge_down_layer)
		and is_instance_valid(_layer_fx)
		and is_instance_valid(_keyframe_timeline)
	)


func _configure_touch_geometry() -> void:
	_layer_buttons.add_theme_constant_override("separation", IOS_LAYER_TOOLBAR_SEPARATION)
	_remove_layer.custom_minimum_size = Vector2(IOS_TOUCH_TARGET_PX, IOS_TOUCH_TARGET_PX)
	_keyframe_timeline.custom_minimum_size = Vector2(IOS_TOUCH_TARGET_PX, IOS_TOUCH_TARGET_PX)

	if _add_layer_list.get_parent() == _add_layer:
		# Preserve the original split button until the compact toolbar
		# reparenting occurs; whichever bootstrap runs first is valid.
		_add_layer.custom_minimum_size = Vector2(IOS_ADD_LAYER_TARGET_WIDTH, IOS_TOUCH_TARGET_PX)
		_add_layer_list.custom_minimum_size = Vector2(IOS_TOUCH_TARGET_PX, IOS_TOUCH_TARGET_PX)
		_add_layer_list.offset_left = -IOS_TOUCH_TARGET_PX
		_add_layer_list.offset_top = -IOS_TOUCH_TARGET_PX * 0.5
		_add_layer_list.offset_right = 0.0
		_add_layer_list.offset_bottom = IOS_TOUCH_TARGET_PX * 0.5
		var add_icon := _add_layer.get_node_or_null("TextureRect") as TextureRect
		if is_instance_valid(add_icon):
			add_icon.offset_left = 11.0
			add_icon.offset_top = -11.0
			add_icon.offset_right = 33.0
			add_icon.offset_bottom = 11.0
	else:
		_add_layer.custom_minimum_size = Vector2(IOS_TOUCH_TARGET_PX, IOS_TOUCH_TARGET_PX)

	# Keep the original Buttons for disabled state and desktop shortcuts.
	# iPad uses each layer's long-press context menu for these operations.
	_move_up_layer.hide()
	_move_down_layer.hide()
	_clone_layer.hide()
	_merge_down_layer.hide()
	_layer_fx.hide()
