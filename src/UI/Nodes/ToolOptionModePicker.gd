class_name ToolOptionModePicker
extends RefCounted

## Compact presentation for an existing mutually exclusive Button group.
## The original buttons and their signals remain in the scene, so saved
## settings, shortcuts, and mode-change callbacks keep their old behavior.
## Only the presentation is replaced by one icon and a click-open popup.

var _host: Control
var _get_index: Callable
var _on_select: Callable
var _source_buttons: Array[Button] = []
var _choices: Array[Button] = []
var _trigger: Button
var _popup: PopupPanel
var _grid: GridContainer


func _init(host: Control, get_index: Callable, on_select: Callable) -> void:
	_host = host
	_get_index = get_index
	_on_select = on_select
	for child in _host.get_children():
		if child is Button:
			_source_buttons.append(child as Button)
	if _source_buttons.is_empty():
		return
	for source in _source_buttons:
		source.hide()

	_trigger = Button.new()
	_trigger.name = &"ModeTrigger"
	_trigger.custom_minimum_size = Vector2(36, 36)
	_trigger.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_trigger.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_trigger.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trigger.expand_icon = true
	_trigger.focus_mode = Control.FOCUS_NONE
	_host.add_child(_trigger)
	_trigger.pressed.connect(_toggle_popup)

	_popup = PopupPanel.new()
	_popup.name = &"ModeChoicesPopup"
	_host.add_child(_popup)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 8)
	margin.add_theme_constant_override(&"margin_right", 8)
	margin.add_theme_constant_override(&"margin_top", 8)
	margin.add_theme_constant_override(&"margin_bottom", 8)
	_popup.add_child(margin)
	_grid = GridContainer.new()
	_grid.columns = mini(4, _source_buttons.size())
	_grid.add_theme_constant_override(&"h_separation", 6)
	_grid.add_theme_constant_override(&"v_separation", 6)
	margin.add_child(_grid)

	for index in _source_buttons.size():
		var original := _source_buttons[index]
		var choice := Button.new()
		choice.custom_minimum_size = Vector2(44, 44)
		choice.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		choice.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		choice.icon = original.icon
		choice.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		choice.expand_icon = true
		choice.tooltip_text = original.tooltip_text
		if choice.icon == null:
			choice.text = original.text
		choice.toggle_mode = true
		choice.focus_mode = Control.FOCUS_NONE
		choice.pressed.connect(_select_choice.bind(index))
		_grid.add_child(choice)
		_choices.append(choice)
	sync()


func sync() -> void:
	if not is_instance_valid(_trigger) or _source_buttons.is_empty():
		return
	var index := clampi(int(_get_index.call()), 0, _source_buttons.size() - 1)
	var source := _source_buttons[index]
	_trigger.icon = source.icon
	_trigger.text = source.text if source.icon == null else ""
	_trigger.tooltip_text = (
		source.tooltip_text if not source.tooltip_text.is_empty() else source.text
	)
	for choice_index in _choices.size():
		_choices[choice_index].set_pressed_no_signal(choice_index == index)


func _toggle_popup() -> void:
	if not is_instance_valid(_popup):
		return
	if _popup.visible:
		_popup.hide()
		return
	sync()
	var columns_count := mini(4, _choices.size())
	var rows_count := ceili(float(_choices.size()) / float(columns_count))
	var desired := Vector2i(
		columns_count * 44 + (columns_count - 1) * 6 + 16,
		rows_count * 44 + (rows_count - 1) * 6 + 16
	)
	var viewport_size := _host.get_viewport().get_visible_rect().size
	var popup_size := Vector2i(
		mini(desired.x, maxi(1, roundi(viewport_size.x) - 16)),
		mini(desired.y, maxi(1, roundi(viewport_size.y) - 16))
	)
	var trigger_rect := _trigger.get_global_rect()
	var pos := Vector2i(trigger_rect.position)
	pos.x += roundi(trigger_rect.size.x) + 6
	if pos.x + popup_size.x > roundi(viewport_size.x) - 8:
		pos.x = roundi(trigger_rect.position.x) - popup_size.x - 6
	pos.x = clampi(pos.x, 8, maxi(8, roundi(viewport_size.x) - popup_size.x - 8))
	pos.y = clampi(pos.y, 8, maxi(8, roundi(viewport_size.y) - popup_size.y - 8))
	_popup.popup_on_parent(Rect2i(pos, popup_size))


func _select_choice(index: int) -> void:
	if is_instance_valid(_popup):
		_popup.hide()
	_on_select.call(index)
	sync()
