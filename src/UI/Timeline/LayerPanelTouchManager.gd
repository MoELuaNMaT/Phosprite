extends Node

enum LayerAction { MOVE_UP = 2000, MOVE_DOWN, DUPLICATE, MERGE_DOWN, EFFECTS }

const IOS_TOUCH_TARGET_PX := 44.0
const IOS_ADD_LAYER_TARGET_WIDTH := IOS_TOUCH_TARGET_PX * 2.0
const IOS_LAYER_TOOLBAR_SEPARATION := 4
const LAYER_BUTTONS_PATH := "TimelineContainer/TimelineButtons/LayerTools/MarginContainer/LayerSettingsContainer/LayerButtons"

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
var _actions_menu: MenuButton


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
	_build_actions_menu()
	if not Global.cel_switched.is_connected(_on_layer_state_changed):
		Global.cel_switched.connect(_on_layer_state_changed)
	if not Global.project_switched.is_connected(_on_layer_state_changed):
		Global.project_switched.connect(_on_layer_state_changed)
	call_deferred("_sync_action_states")


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
	_add_layer.custom_minimum_size = Vector2(IOS_ADD_LAYER_TARGET_WIDTH, IOS_TOUCH_TARGET_PX)
	_remove_layer.custom_minimum_size = Vector2(IOS_TOUCH_TARGET_PX, IOS_TOUCH_TARGET_PX)
	_keyframe_timeline.custom_minimum_size = Vector2(IOS_TOUCH_TARGET_PX, IOS_TOUCH_TARGET_PX)

	# AddLayer keeps its existing split behavior: the left half adds a Pixel Layer and the
	# right half opens the existing layer-type popup. Both halves become 44 pt touch targets.
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

	# Low-frequency Layer operations move into one touch-sized menu on iPad. The original
	# Buttons remain in the scene as the single source of disabled state and desktop shortcuts.
	_move_up_layer.hide()
	_move_down_layer.hide()
	_clone_layer.hide()
	_merge_down_layer.hide()
	_layer_fx.hide()


func _build_actions_menu() -> void:
	_actions_menu = MenuButton.new()
	_actions_menu.name = "LayerActionsMenu"
	_actions_menu.text = "⋯"
	_actions_menu.tooltip_text = tr("Layer actions")
	_actions_menu.custom_minimum_size = Vector2(IOS_TOUCH_TARGET_PX, IOS_TOUCH_TARGET_PX)
	_actions_menu.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_layer_buttons.add_child(_actions_menu)
	_layer_buttons.move_child(_actions_menu, _keyframe_timeline.get_index())
	var popup := _actions_menu.get_popup()
	popup.add_item(tr("Move layer up"), LayerAction.MOVE_UP)
	popup.add_item(tr("Move layer down"), LayerAction.MOVE_DOWN)
	popup.add_separator()
	popup.add_item(tr("Duplicate layer"), LayerAction.DUPLICATE)
	popup.add_item(tr("Merge down"), LayerAction.MERGE_DOWN)
	popup.add_item(tr("Layer effects"), LayerAction.EFFECTS)
	popup.id_pressed.connect(_on_action_pressed)
	popup.about_to_popup.connect(_sync_action_states)


func _on_layer_state_changed() -> void:
	call_deferred("_sync_action_states")


func _sync_action_states() -> void:
	if not is_instance_valid(_actions_menu) or not _all_toolbar_nodes_valid():
		return
	var popup := _actions_menu.get_popup()
	_set_action_disabled(popup, LayerAction.MOVE_UP, _move_up_layer.disabled)
	_set_action_disabled(popup, LayerAction.MOVE_DOWN, _move_down_layer.disabled)
	_set_action_disabled(popup, LayerAction.DUPLICATE, _clone_layer.disabled)
	_set_action_disabled(popup, LayerAction.MERGE_DOWN, _merge_down_layer.disabled)
	_set_action_disabled(popup, LayerAction.EFFECTS, _layer_fx.disabled)


func _set_action_disabled(popup: PopupMenu, id: int, disabled: bool) -> void:
	var item_index := popup.get_item_index(id)
	if item_index >= 0:
		popup.set_item_disabled(item_index, disabled)


func _on_action_pressed(id: int) -> void:
	if not is_instance_valid(_timeline):
		return
	match id:
		LayerAction.MOVE_UP:
			if not _move_up_layer.disabled:
				_timeline.call("change_layer_order", true)
		LayerAction.MOVE_DOWN:
			if not _move_down_layer.disabled:
				_timeline.call("change_layer_order", false)
		LayerAction.DUPLICATE:
			if not _clone_layer.disabled:
				_timeline.call("_on_CloneLayer_pressed")
		LayerAction.MERGE_DOWN:
			if not _merge_down_layer.disabled:
				_timeline.call("_on_MergeDownLayer_pressed")
		LayerAction.EFFECTS:
			if not _layer_fx.disabled:
				_timeline.call("_on_layer_fx_pressed")
	call_deferred("_sync_action_states")