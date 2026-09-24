extends BaseTool

enum { TOP_COLOR, CURRENT_LAYER }

const COLOR_SAMPLING := preload("res://src/Tools/UtilityTools/ColorSampling.gd")

var _prev_mode := 0
var _color_slot := 0
var _mode := 0


func _ready() -> void:
	super._ready()
	if not Global.cel_switched.is_connected(_on_cel_switched):
		Global.cel_switched.connect(_on_cel_switched)
	if not Global.project_about_to_switch.is_connected(_on_project_about_to_switch):
		Global.project_about_to_switch.connect(_on_project_about_to_switch)
	if not Global.project_switched.is_connected(_on_project_switched):
		Global.project_switched.connect(_on_project_switched)
	if OS.get_name() == "iOS":
		_color_slot = 0
		$ColorPicker/Label.hide()
		$ColorPicker/Options.hide()
		$ColorPicker/Options.selected = 0
	_sync_extract_mode_buttons()
	_apply_canvas_layer_preview()


func _exit_tree() -> void:
	_clear_canvas_layer_preview()
	if Global.cel_switched.is_connected(_on_cel_switched):
		Global.cel_switched.disconnect(_on_cel_switched)
	if Global.project_about_to_switch.is_connected(_on_project_about_to_switch):
		Global.project_about_to_switch.disconnect(_on_project_about_to_switch)
	if Global.project_switched.is_connected(_on_project_switched):
		Global.project_switched.disconnect(_on_project_switched)


func _input(event: InputEvent) -> void:
	if OS.get_name() == "iOS":
		return
	var options: OptionButton = $ColorPicker/Options

	if event.is_action_pressed("change_tool_mode"):
		_prev_mode = options.selected
	if event.is_action("change_tool_mode"):
		options.selected = _prev_mode ^ 1
		_color_slot = options.selected
	if event.is_action_released("change_tool_mode"):
		options.selected = _prev_mode
		_color_slot = options.selected


func _on_Options_item_selected(id: int) -> void:
	_color_slot = id
	update_config()
	save_config()


func _on_ExtractFrom_item_selected(index: int) -> void:
	_set_extract_mode(index)


func _on_extract_mode_button_pressed(index: int) -> void:
	_set_extract_mode(index)


func _set_extract_mode(index: int) -> void:
	_mode = clampi(index, TOP_COLOR, CURRENT_LAYER)
	update_config()
	save_config()


func get_config() -> Dictionary:
	var color_slot := 0 if OS.get_name() == "iOS" else _color_slot
	return {"color_slot": color_slot, "mode": _mode}


func set_config(config: Dictionary) -> void:
	_color_slot = 0 if OS.get_name() == "iOS" else config.get("color_slot", _color_slot)
	_mode = clampi(int(config.get("mode", _mode)), TOP_COLOR, CURRENT_LAYER)


func update_config() -> void:
	$ColorPicker/Options.selected = _color_slot
	$ColorPicker/ExtractFrom.selected = _mode
	_sync_extract_mode_buttons()
	_apply_canvas_layer_preview()


func _sync_extract_mode_buttons() -> void:
	var buttons := $ColorPicker/ExtractModeButtons.get_children()
	for index in buttons.size():
		var button := buttons[index] as BaseButton
		if button != null:
			button.set_pressed_no_signal(index == _mode)


func _apply_canvas_layer_preview() -> void:
	if not is_instance_valid(Global.canvas):
		return
	if _mode == CURRENT_LAYER and Global.current_project != null:
		Global.canvas.set_preview_only_layer(Global.current_project.current_layer, self)
	else:
		Global.canvas.clear_preview_only_layer(self)


func _clear_canvas_layer_preview() -> void:
	if is_instance_valid(Global.canvas):
		Global.canvas.clear_preview_only_layer(self)


func _on_cel_switched() -> void:
	if _mode == CURRENT_LAYER:
		_apply_canvas_layer_preview()


func _on_project_about_to_switch() -> void:
	_clear_canvas_layer_preview()


func _on_project_switched() -> void:
	if _mode == CURRENT_LAYER:
		_apply_canvas_layer_preview()


func draw_start(pos: Vector2i) -> void:
	super.draw_start(pos)
	_pick_color(pos)


func draw_move(pos: Vector2i) -> void:
	super.draw_move(pos)
	_pick_color(pos)


func draw_end(pos: Vector2i) -> void:
	super.draw_end(pos)


func _pick_color(pos: Vector2i) -> void:
	var button := (
		MOUSE_BUTTON_LEFT if OS.get_name() == "iOS" or _color_slot == 0 else MOUSE_BUTTON_RIGHT
	)
	COLOR_SAMPLING.pick_color(pos, button, _mode)
