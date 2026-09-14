extends BaseTool

const COLOR_SAMPLING := preload("res://src/Tools/UtilityTools/ColorSampling.gd")

enum { TOP_COLOR, CURRENT_LAYER }

var _prev_mode := 0
var _color_slot := 0
var _mode := 0


func _input(event: InputEvent) -> void:
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
	_mode = index
	update_config()
	save_config()


func get_config() -> Dictionary:
	return {"color_slot": _color_slot, "mode": _mode}


func set_config(config: Dictionary) -> void:
	_color_slot = config.get("color_slot", _color_slot)
	_mode = config.get("mode", _mode)


func update_config() -> void:
	$ColorPicker/Options.selected = _color_slot
	$ColorPicker/ExtractFrom.selected = _mode


func draw_start(pos: Vector2i) -> void:
	super.draw_start(pos)
	_pick_color(pos)


func draw_move(pos: Vector2i) -> void:
	super.draw_move(pos)
	_pick_color(pos)


func draw_end(pos: Vector2i) -> void:
	super.draw_end(pos)


func _pick_color(pos: Vector2i) -> void:
	var button := MOUSE_BUTTON_LEFT if _color_slot == 0 else MOUSE_BUTTON_RIGHT
	COLOR_SAMPLING.pick_color(pos, button, _mode)
