extends Container

signal color_options_toggled(expanded: bool)

const TOUCH_TOOLTIP_META := &"phosprite_touch_tooltip"
const TOUCH_MOUSE_FILTER_META := &"phosprite_touch_mouse_filter"
const TOUCH_TAP_SLOP_PX := 12.0
const SETTINGS_ICON := preload("res://assets/graphics/misc/settings.svg")

## The HBoxContainer parent of the picker shapes.
var shapes_container: HBoxContainer
## The internal control node of the HSV Rectangle of the [ColorPicker] node.
var hsv_rectangle: Control
## The internal control node of the HSV Wheel of the [ColorPicker] node.
var hsv_wheel: Control
## The internal control node of the VHS Circle of the [ColorPicker] node.
var vhs_circle: Control
## The internal control node of OKHSL VHS Circle of the [ColorPicker] node.
var okhsl_circle: Control
## The internal control node of the OK HS Rectangle of the [ColorPicker] node.
var ok_hs_rectangle: Control
## The internal control node of the OK HL Rectangle of the [ColorPicker] node.
var ok_hl_rectangle: Control
## The internal swatches button of the [ColorPicker] node.
## Used to ensure that swatches are always invisible.
var swatches_button: HBoxContainer
## The internal container for the color sliders of the [ColorPicker] node.
var color_slider_types_hbox: HBoxContainer
var color_sliders_grid: GridContainer
var _skip_color_picker_update := false
var _screen_sampler_button: BaseButton
var _touch_color_ui_mode := false
var _touch_color_candidates: Dictionary = {}
var _ios_screen_sampler_armed := false

# The numeric popup edits the selected foreground/background tool slot LIVE.
# Its CanvasLayer is outside the Palette and Color VBox layout.
var _color_options_layer: CanvasLayer
var _color_options_popup: PanelContainer
var _color_options_picker: ColorPicker
var _syncing_popup_color := false
var _color_options_open := false

@onready var color_picker := %ColorPicker as ColorPicker
@onready var color_buttons := %ColorButtons as HBoxContainer
@onready var left_color_button := %LeftColorButton as Button
@onready var right_color_button := %RightColorButton as Button
@onready
var color_switch := $ScrollContainer/VerticalContainer/ColorButtons/ColorSwitch as TextureButton
@onready var left_color_rect := %LeftColorRect as ColorRect
@onready var right_color_rect := %RightColorRect as ColorRect
@onready var average_color := %AverageColor as ColorRect
@onready var expand_button: Button = $ScrollContainer/VerticalContainer/ExpandButton

@onready var _mm_change_hue: Keychain.MouseMovementInputAction = (
	Keychain.actions[&"mm_color_change_hue"] as Keychain.MouseMovementInputAction
)
@onready var _mm_change_sat: Keychain.MouseMovementInputAction = (
	Keychain.actions[&"mm_color_change_saturation"] as Keychain.MouseMovementInputAction
)
@onready var _mm_change_value: Keychain.MouseMovementInputAction = (
	Keychain.actions[&"mm_color_change_value"] as Keychain.MouseMovementInputAction
)
@onready var _mm_change_alpha: Keychain.MouseMovementInputAction = (
	Keychain.actions[&"mm_color_change_alpha"] as Keychain.MouseMovementInputAction
)


func _ready() -> void:
	Tools.options_reset.connect(reset_options)
	Tools.color_changed.connect(update_color)
	_average(left_color_rect.color, right_color_rect.color)
	color_picker.color_mode = Global.config_cache.get_value(
		"color_picker", "color_mode", ColorPicker.MODE_RGB
	)
	color_picker.picker_shape = Global.config_cache.get_value(
		"color_picker", "picker_shape", ColorPicker.SHAPE_HSV_RECTANGLE
	)
	# Make changes to the UI of the color picker by modifying its internal children
	await get_tree().process_frame
	# The MarginContainer that contains all of the color picker nodes.
	var picker_margin_container := color_picker.get_child(0, true) as MarginContainer
	picker_margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var picker_vbox_container := picker_margin_container.get_child(0, true) as VBoxContainer

	shapes_container = picker_vbox_container.get_child(0, true)
	shapes_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shapes_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsv_rectangle = shapes_container.get_child(0, true) as Control
	hsv_rectangle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The HBoxContainer of the screen color picker, the color preview rectangle and the
	# button that lets users change the picker shape. It is visible because
	# color_picker.sampler_visible is set to true.
	# We are hiding the color preview rectangle, adding the hex LineEdit, the
	# left/right color buttons and the color switch, default and average buttons.
	var sampler_cont := picker_vbox_container.get_child(1, true) as HBoxContainer
	_screen_sampler_button = sampler_cont.get_child(0, true) as BaseButton
	if OS.get_name() == "iOS" and is_instance_valid(_screen_sampler_button):
		_install_ios_screen_sampler()
	# The two existing tool colors are the permanent foreground/background
	# swatches in all three UI profiles; keep the original tool slot wiring.
	if is_instance_valid(_screen_sampler_button):
		_screen_sampler_button.visible = false
	var color_texture_rect := sampler_cont.get_child(1, true) as TextureRect
	color_texture_rect.visible = false
	var shape_menu_button := sampler_cont.get_child(2, true) as MenuButton
	var shape_popup_menu := shape_menu_button.get_popup()
	shape_popup_menu.id_pressed.connect(_on_shape_popup_menu_id_pressed)
	color_buttons.visible = false
	# Move the existing left/right ButtonGroup controls beside a square settings
	# button. All of them stay in the native picker sampler row, so opening a
	# floating popup does not change the width/height of Palette and Color.
	expand_button.reparent(sampler_cont)
	sampler_cont.move_child(expand_button, 0)
	_install_color_settings_button()
	left_color_button.reparent(sampler_cont)
	right_color_button.reparent(sampler_cont)
	for button in [left_color_button, right_color_button]:
		button.visible = true
		button.custom_minimum_size = Vector2(32.0, 28.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sampler_cont.move_child(left_color_button, 1)
	sampler_cont.move_child(right_color_button, 2)
	# ColorRect nodes were designed for the old 42x32 buttons. Anchor them to
	# the live button bounds instead of keeping their old absolute 38x28 rects.
	_configure_tool_color_swatch(left_color_button, left_color_rect)
	_configure_tool_color_swatch(right_color_button, right_color_rect)
	_sync_active_color_buttons()

	color_slider_types_hbox = picker_vbox_container.get_child(2, true) as HBoxContainer
	color_slider_types_hbox.visible = false
	color_sliders_grid = picker_vbox_container.get_child(3, true) as GridContainer
	color_sliders_grid.visible = false
	swatches_button = picker_vbox_container.get_child(5, true).get_child(0, true) as HBoxContainer
	swatches_button.visible = false
	# The GridContainer that contains the swatch buttons. These are not visible in our case
	# but for some reason its h_separation needs to be set to a value larger than 4,
	# otherwise a weird bug occurs with the Recent Colors where, adding new colors
	# increases the size of the color buttons.
	var presets_container := (
		picker_vbox_container.get_child(5, true).get_child(2, true) as GridContainer
	)
	presets_container.add_theme_constant_override("h_separation", 5)
	color_picker.color_modes_visible = false
	color_picker.sliders_visible = false
	color_picker.presets_visible = false
	_on_shape_popup_menu_id_pressed(color_picker.picker_shape)
	_sync_active_color_buttons()


func is_color_options_expanded() -> bool:
	return _color_options_open


func _exit_tree() -> void:
	# The popup is independent of the picker layout and has no uncommitted color.
	if is_instance_valid(_color_options_layer):
		_color_options_layer.free()
	_color_options_layer = null
	_color_options_popup = null
	_color_options_picker = null


func _install_color_settings_button() -> void:
	expand_button.text = ""
	expand_button.icon = SETTINGS_ICON
	expand_button.expand_icon = true
	expand_button.toggle_mode = true
	expand_button.set_pressed_no_signal(false)
	expand_button.custom_minimum_size = Vector2(30.0, 30.0)
	expand_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	expand_button.tooltip_text = "RGB / HSV / RAW color settings"


func _configure_tool_color_swatch(button: Button, swatch: ColorRect) -> void:
	if not is_instance_valid(button) or not is_instance_valid(swatch):
		return
	swatch.set_anchors_preset(Control.PRESET_FULL_RECT)
	swatch.offset_left = 2.0
	swatch.offset_top = 2.0
	swatch.offset_right = -2.0
	swatch.offset_bottom = -2.0
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _sync_active_color_buttons() -> void:
	if not is_instance_valid(left_color_button) or not is_instance_valid(right_color_button):
		return
	left_color_button.set_pressed_no_signal(Tools.picking_color_for == MOUSE_BUTTON_LEFT)
	right_color_button.set_pressed_no_signal(Tools.picking_color_for == MOUSE_BUTTON_RIGHT)
	if Tools._slots.has(MOUSE_BUTTON_LEFT):
		left_color_rect.color = Tools._slots[MOUSE_BUTTON_LEFT].color
	if Tools._slots.has(MOUSE_BUTTON_RIGHT):
		right_color_rect.color = Tools._slots[MOUSE_BUTTON_RIGHT].color


func _sync_popup_to_active_slot() -> void:
	if not _color_options_open or not is_instance_valid(_color_options_picker):
		return
	if not Tools._slots.has(Tools.picking_color_for):
		return
	_syncing_popup_color = true
	_color_options_picker.color = Tools._slots[Tools.picking_color_for].color
	_syncing_popup_color = false


func _open_color_options_popup() -> void:
	if _color_options_open or not Tools._slots.has(Tools.picking_color_for):
		expand_button.set_pressed_no_signal(_color_options_open)
		return
	_color_options_open = true

	_color_options_layer = CanvasLayer.new()
	_color_options_layer.name = &"ColorOptionsLayer"
	_color_options_layer.layer = 100
	get_tree().root.add_child(_color_options_layer)
	_color_options_popup = PanelContainer.new()
	_color_options_popup.name = &"ColorOptionsPopup"
	# Numeric modes must be fully visible: no ScrollContainer or height clamp.
	_color_options_popup.custom_minimum_size = Vector2(270.0, 0.0)
	_color_options_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_color_options_popup.mouse_force_pass_scroll_events = false
	_color_options_popup.hide()
	_color_options_popup.add_to_group(&"phosprite_color_options_popup")
	_color_options_layer.add_child(_color_options_popup)
	_color_options_picker = ColorPicker.new()
	_color_options_picker.name = &"LiveColorOptionsPicker"
	_color_options_picker.custom_minimum_size = Vector2(270.0, 0.0)
	_color_options_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_options_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	_color_options_picker.color_modes_visible = true
	_color_options_picker.sliders_visible = true
	_color_options_picker.sampler_visible = false
	_color_options_picker.hex_visible = false
	_color_options_picker.presets_visible = false
	_color_options_picker.can_add_swatches = false
	_color_options_picker.color_mode = color_picker.color_mode
	_color_options_picker.color = Tools._slots[Tools.picking_color_for].color
	_color_options_popup.add_child(_color_options_picker)
	_color_options_picker.color_changed.connect(_on_popup_color_changed)
	_finalize_color_options_popup.call_deferred()
	expand_button.set_pressed_no_signal(true)
	color_options_toggled.emit(true)


func _configure_staged_color_options_picker() -> bool:
	if not is_instance_valid(_color_options_picker):
		return false
	var margin := _color_options_picker.get_child(0, true) as MarginContainer
	if margin == null:
		return false
	var columns := margin.get_child(0, true) as VBoxContainer
	if columns == null or columns.get_child_count(true) < 4:
		return false
	var color_shape := columns.get_child(0, true) as Control
	var sampler_row := columns.get_child(1, true) as Control
	if color_shape == null or sampler_row == null:
		return false
	color_shape.hide()
	sampler_row.hide()
	# The built-in color-mode selector and numeric sliders remain visible.
	# Lock typing in their SpinBox LineEdit children, but leave SpinBox itself
	# enabled so its increment/decrement arrows and slider controls still work.
	_lock_color_option_numeric_typing()
	return true


func _lock_color_option_numeric_typing() -> void:
	if not is_instance_valid(_color_options_picker):
		return
	for child in _color_options_picker.find_children("*", "SpinBox", true, false):
		var spinner := child as SpinBox
		if spinner == null:
			continue
		var edit := spinner.get_line_edit()
		if edit == null:
			continue
		edit.editable = false
		edit.focus_mode = Control.FOCUS_NONE


func _finalize_color_options_popup() -> void:
	await get_tree().process_frame
	if not _color_options_open or not is_instance_valid(_color_options_popup):
		return
	if not _configure_staged_color_options_picker():
		push_error("Color options editor could not hide the native palette controls")
		return
	# Let the numeric ColorPicker compute its actual full minimum height after
	# hiding the wheel. Never trim it with an overlay scroll viewport.
	_color_options_popup.reset_size()
	_position_color_options_popup()
	_color_options_popup.show()


func _position_color_options_popup() -> void:
	if not is_instance_valid(_color_options_popup):
		return
	var viewport_size := get_viewport_rect().size
	var button_rect := expand_button.get_global_rect()
	var natural_size := _color_options_popup.get_combined_minimum_size()
	var gap := 6.0
	# Keep every RGB/HSV/RAW slider in the panel; on a small viewport scale
	# the whole floating panel uniformly instead of adding scrolling/clipping.
	var width_scale := maxf(1.0, viewport_size.x - gap * 2.0) / maxf(1.0, natural_size.x)
	var height_scale := maxf(1.0, viewport_size.y - gap * 2.0) / maxf(1.0, natural_size.y)
	var ui_scale := minf(1.0, minf(width_scale, height_scale))
	_color_options_popup.scale = Vector2(ui_scale, ui_scale)
	var visible_size := natural_size * ui_scale
	# Prefer below the gear, then above. Only shift sideways when neither
	# vertical placement has room, so the toggle stays reachable.
	var popup_y := button_rect.end.y + gap
	var panel_rect := get_global_rect()
	var popup_x := clampf(
		panel_rect.position.x, gap, maxf(gap, viewport_size.x - visible_size.x - gap)
	)
	if popup_y + visible_size.y + gap > viewport_size.y:
		var above_y := button_rect.position.y - visible_size.y - gap
		if above_y >= gap:
			popup_y = above_y
		else:
			var right_of_panel := panel_rect.end.x + gap
			if right_of_panel + visible_size.x + gap <= viewport_size.x:
				popup_x = right_of_panel
			elif panel_rect.position.x >= visible_size.x + gap * 2.0:
				popup_x = panel_rect.position.x - visible_size.x - gap
			else:
				popup_x = clampf(
					button_rect.end.x + gap, gap, maxf(gap, viewport_size.x - visible_size.x - gap)
				)
			popup_y = clampf(
				button_rect.position.y - visible_size.y * 0.5,
				gap,
				maxf(gap, viewport_size.y - visible_size.y - gap)
			)
	_color_options_popup.position = Vector2(popup_x, popup_y)
	_color_options_popup.size = natural_size
	_color_options_popup.clip_contents = false


func _on_popup_color_changed(color: Color) -> void:
	if not _color_options_open or _syncing_popup_color:
		return
	if Tools._slots.has(Tools.picking_color_for):
		# Native ColorPicker events (not opening, leaving, or closing popup)
		# write immediately to the selected left/right slot.
		Tools.assign_color(color, Tools.picking_color_for, false)


func _close_color_options_popup() -> void:
	if not _color_options_open:
		return
	if is_instance_valid(_color_options_picker):
		color_picker.color_mode = _color_options_picker.color_mode
		Global.config_cache.set_value("color_picker", "color_mode", color_picker.color_mode)
	_color_options_open = false
	if is_instance_valid(_color_options_layer):
		_color_options_layer.queue_free()
	_color_options_layer = null
	_color_options_popup = null
	_color_options_picker = null
	expand_button.set_pressed_no_signal(false)
	color_options_toggled.emit(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(left_color_rect):
		_average(left_color_rect.color, right_color_rect.color)


func _input(event: InputEvent) -> void:
	if OS.get_name() == "iOS":
		if event is InputEventScreenTouch:
			_handle_color_control_touch(event as InputEventScreenTouch)
		elif event is InputEventScreenDrag:
			_handle_color_control_drag(event as InputEventScreenDrag)
		elif (
			(event is InputEventMouseMotion or event is InputEventMouseButton)
			and event.device != -1
		):
			_restore_pointer_color_ui()

	var hue_value: float = float(_mm_change_hue.get_action_distance(event))
	var sat_value: float = float(_mm_change_sat.get_action_distance(event))
	var value_value: float = float(_mm_change_value.get_action_distance(event))
	var alpha_value: float = float(_mm_change_alpha.get_action_distance(event))
	if (
		is_zero_approx(hue_value)
		and is_zero_approx(sat_value)
		and is_zero_approx(value_value)
		and is_zero_approx(alpha_value)
	):
		return
	var c: Color = Tools._slots[Tools.picking_color_for].color
	c.h += hue_value
	c.s += sat_value
	c.v += value_value
	c.a += alpha_value
	Tools.assign_color(c, Tools.picking_color_for, false)


func _install_ios_screen_sampler() -> void:
	# Godot's unsupported-platform fallback samples DisplayServer mouse/screen pixels.
	# On iPad that path can resolve to black, so keep the existing button/icon but route
	# it into Phosprite's canvas sampler instead.
	for connection: Dictionary in _screen_sampler_button.get_signal_connection_list(&"pressed"):
		var callback: Callable = connection.get("callable", Callable())
		if callback.is_valid() and _screen_sampler_button.is_connected(&"pressed", callback):
			_screen_sampler_button.disconnect(&"pressed", callback)
	_screen_sampler_button.pressed.connect(_on_ios_screen_sampler_pressed)


func _handle_color_control_touch(event: InputEventScreenTouch) -> bool:
	if event.pressed:
		var action := _color_control_action_at(event.position)
		if action.is_empty():
			return false
		_enter_touch_color_ui()
		_touch_color_candidates[event.index] = {
			"action": action,
			"origin": event.position,
			"cancelled": false,
		}
		return true

	if not _touch_color_candidates.has(event.index):
		return false
	var candidate: Dictionary = _touch_color_candidates[event.index]
	_touch_color_candidates.erase(event.index)
	if bool(candidate.get("cancelled", false)):
		return true
	if Vector2(candidate["origin"]).distance_to(event.position) > TOUCH_TAP_SLOP_PX:
		return true
	var released_action := _color_control_action_at(event.position)
	if released_action != StringName(candidate["action"]):
		return true
	_activate_touch_color_action(released_action)
	return true


func _handle_color_control_drag(event: InputEventScreenDrag) -> bool:
	if not _touch_color_candidates.has(event.index):
		return false
	var candidate: Dictionary = _touch_color_candidates[event.index]
	if Vector2(candidate["origin"]).distance_to(event.position) > TOUCH_TAP_SLOP_PX:
		candidate["cancelled"] = true
		_touch_color_candidates[event.index] = candidate
	return true


func _color_control_action_at(screen_position: Vector2) -> StringName:
	if (
		is_instance_valid(expand_button)
		and expand_button.is_visible_in_tree()
		and expand_button.get_global_rect().has_point(screen_position)
	):
		return &"settings"
	if (
		is_instance_valid(left_color_button)
		and left_color_button.is_visible_in_tree()
		and left_color_button.get_global_rect().has_point(screen_position)
	):
		return &"left"
	if (
		is_instance_valid(right_color_button)
		and right_color_button.is_visible_in_tree()
		and right_color_button.get_global_rect().has_point(screen_position)
	):
		return &"right"
	if (
		is_instance_valid(color_switch)
		and color_switch.is_visible_in_tree()
		and color_switch.get_global_rect().has_point(screen_position)
	):
		return &"swap"
	if (
		is_instance_valid(_screen_sampler_button)
		and _screen_sampler_button.is_visible_in_tree()
		and _screen_sampler_button.get_global_rect().has_point(screen_position)
	):
		return &"sampler"
	return &""


func _activate_touch_color_action(action: StringName) -> void:
	match action:
		&"settings":
			_on_expand_button_pressed()
		&"left":
			left_color_button.set_pressed_no_signal(true)
			right_color_button.set_pressed_no_signal(false)
			_on_left_color_button_toggled(true)
		&"right":
			left_color_button.set_pressed_no_signal(false)
			right_color_button.set_pressed_no_signal(true)
			_on_left_color_button_toggled(false)
		&"swap":
			_on_ColorSwitch_pressed()
		&"sampler":
			_on_ios_screen_sampler_pressed()


func _on_ios_screen_sampler_pressed() -> void:
	_ios_screen_sampler_armed = true
	if _screen_sampler_button.toggle_mode:
		_screen_sampler_button.set_pressed_no_signal(true)
	CanvasInputAdapter.request_touch_color_sample()
	_enter_touch_color_ui()
	if is_instance_valid(Global.canvas):
		Global.canvas.set_adapter_tool_preview_active(false)


func _touch_color_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if is_instance_valid(color_buttons):
		controls.append(color_buttons)
		for child in color_buttons.find_children("*", "Control", true, false):
			if child is Control:
				controls.append(child as Control)
	if is_instance_valid(_screen_sampler_button):
		controls.append(_screen_sampler_button)
	return controls


func _touch_interactive_color_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for control: Control in [
		expand_button, left_color_button, right_color_button, color_switch, _screen_sampler_button
	]:
		if is_instance_valid(control):
			controls.append(control)
	return controls


func _enter_touch_color_ui() -> void:
	_touch_color_ui_mode = true
	for control in _touch_color_controls():
		if not control.has_meta(TOUCH_TOOLTIP_META):
			control.set_meta(TOUCH_TOOLTIP_META, control.tooltip_text)
		control.tooltip_text = ""
		control.release_focus()
	for control in _touch_interactive_color_controls():
		if not control.has_meta(TOUCH_MOUSE_FILTER_META):
			control.set_meta(TOUCH_MOUSE_FILTER_META, control.mouse_filter)
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _restore_pointer_color_ui() -> void:
	if not _touch_color_ui_mode:
		return
	_touch_color_ui_mode = false
	_touch_color_candidates.clear()
	for control in _touch_color_controls():
		if control.has_meta(TOUCH_TOOLTIP_META):
			control.tooltip_text = String(control.get_meta(TOUCH_TOOLTIP_META, ""))
			control.remove_meta(TOUCH_TOOLTIP_META)
	for control in _touch_interactive_color_controls():
		if control.has_meta(TOUCH_MOUSE_FILTER_META):
			control.mouse_filter = int(control.get_meta(TOUCH_MOUSE_FILTER_META))
			control.remove_meta(TOUCH_MOUSE_FILTER_META)


func _on_color_picker_color_changed(color: Color) -> void:
	# Due to the decimal nature of the color values, some values get rounded off
	# unintentionally before entering this method.
	# Even though the decimal values change, the HTML code remains the same after the change.
	# So we're using this trick to convert the values back to how they are shown in
	# the color picker's UI.
	color = Color(color.to_html())
	_skip_color_picker_update = true
	# This was requested by Issue #54 on GitHub
	# Do it here instead of in Tools.assign_color in order to ensure that the
	# color picker's color value changes.
	var c: Color = Tools._slots[Tools.picking_color_for].color
	if color.a == 0:
		if color.r != c.r or color.g != c.g or color.b != c.b:
			color.a = 1
			color_picker.color.a = 1
	Tools.assign_color(color, Tools.picking_color_for, false)


func _on_shape_popup_menu_id_pressed(id: ColorPicker.PickerShapeType) -> void:
	Global.config_cache.set_value("color_picker", "picker_shape", color_picker.picker_shape)
	# All of this is needed so that the shape controls scale well when resized.
	# The internal AspectRatioContainer was removed in Godot 4.5 so we have to add our own
	# for the non-rectangular shapes.
	_hide_shape_controls()
	if id == ColorPicker.SHAPE_HSV_WHEEL:
		if is_instance_valid(hsv_wheel):
			hsv_wheel.get_parent().visible = true
		else:
			hsv_wheel = shapes_container.get_child(-1, true)
			_modify_color_shapes(hsv_wheel, false)
	elif id == ColorPicker.SHAPE_VHS_CIRCLE:
		if is_instance_valid(vhs_circle):
			vhs_circle.get_parent().visible = true
		else:
			vhs_circle = shapes_container.get_child(-2, true)
			_modify_color_shapes(vhs_circle, false)
	elif id == ColorPicker.SHAPE_OKHSL_CIRCLE:
		if is_instance_valid(okhsl_circle):
			okhsl_circle.get_parent().visible = true
		else:
			okhsl_circle = shapes_container.get_child(-2, true)
			_modify_color_shapes(okhsl_circle, false)
	elif id == ColorPicker.SHAPE_OK_HS_RECTANGLE and not is_instance_valid(ok_hs_rectangle):
		ok_hs_rectangle = shapes_container.get_child(-2, true)
		_modify_color_shapes(ok_hs_rectangle, true)
	elif id == ColorPicker.SHAPE_OK_HL_RECTANGLE and not is_instance_valid(ok_hl_rectangle):
		ok_hl_rectangle = shapes_container.get_child(-2, true)
		_modify_color_shapes(ok_hl_rectangle, true)


func _modify_color_shapes(node: Control, rectangle: bool) -> void:
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not rectangle:
		var aspect_ratio_container := AspectRatioContainer.new()
		aspect_ratio_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		aspect_ratio_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var node_index := node.get_index(true)
		shapes_container.remove_child(node)
		aspect_ratio_container.add_child(node)
		shapes_container.add_child(aspect_ratio_container)
		shapes_container.move_child(aspect_ratio_container, node_index)


func _hide_shape_controls() -> void:
	if is_instance_valid(hsv_wheel):
		hsv_wheel.get_parent().visible = false
	if is_instance_valid(vhs_circle):
		vhs_circle.get_parent().visible = false
	if is_instance_valid(okhsl_circle):
		okhsl_circle.get_parent().visible = false


func _on_left_color_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		Tools.picking_color_for = MOUSE_BUTTON_LEFT
		color_picker.color = left_color_rect.color
	else:
		Tools.picking_color_for = MOUSE_BUTTON_RIGHT
		color_picker.color = right_color_rect.color
	_average(left_color_rect.color, right_color_rect.color)
	_sync_active_color_buttons()
	_sync_popup_to_active_slot()


func reset_options() -> void:
	color_picker.color_mode = ColorPicker.MODE_RGB
	color_picker.picker_shape = ColorPicker.SHAPE_HSV_RECTANGLE
	if is_instance_valid(_color_options_picker):
		_color_options_picker.color_mode = ColorPicker.MODE_RGB


func update_color(color_info: Dictionary, button: int) -> void:
	var color = color_info.get("color", Color.WHITE)
	if Tools.picking_color_for == button and not _skip_color_picker_update:
		color_picker.color = color
	if button == MOUSE_BUTTON_RIGHT:
		right_color_rect.color = color
	else:
		left_color_rect.color = color
	_average(left_color_rect.color, right_color_rect.color)
	Global.config_cache.set_value("color_picker", "color_mode", color_picker.color_mode)
	Global.config_cache.set_value("color_picker", "picker_shape", color_picker.picker_shape)
	_skip_color_picker_update = false
	_sync_active_color_buttons()
	if button == Tools.picking_color_for:
		_sync_popup_to_active_slot()
	if _ios_screen_sampler_armed:
		_ios_screen_sampler_armed = false
		if is_instance_valid(_screen_sampler_button) and _screen_sampler_button.toggle_mode:
			_screen_sampler_button.set_pressed_no_signal(false)


func _on_ColorSwitch_pressed() -> void:
	Tools.swap_color()


func _on_ColorDefaults_pressed() -> void:
	Tools.default_color()


func _on_expand_button_pressed() -> void:
	if _color_options_open:
		_close_color_options_popup()
	else:
		_open_color_options_popup()


func _average(color_1: Color, color_2: Color) -> void:
	var average := (color_1 + color_2) / 2.0
	var copy_button := average_color.get_parent() as Control
	var tooltip := str(tr("Average Color:"), "\n#", average.to_html())
	if OS.get_name() == "iOS" and _touch_color_ui_mode:
		copy_button.set_meta(TOUCH_TOOLTIP_META, tooltip)
		copy_button.tooltip_text = ""
	else:
		copy_button.tooltip_text = tooltip
	average_color.color = average


func _on_CopyAverage_button_down() -> void:
	average_color.visible = false


func _on_CopyAverage_button_up() -> void:
	average_color.visible = true


func _on_copy_average_gui_input(event: InputEvent) -> void:
	if event.is_action_released(&"left_mouse"):
		Tools.assign_color(average_color.color, MOUSE_BUTTON_LEFT)
	elif event.is_action_released(&"right_mouse"):
		Tools.assign_color(average_color.color, MOUSE_BUTTON_RIGHT)
