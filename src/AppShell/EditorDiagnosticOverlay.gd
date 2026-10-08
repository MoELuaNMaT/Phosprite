extends CanvasLayer

## iPad-only diagnostic controls that remain accessible without Mac/Xcode.
## Never reads a project file or changes the Workspace's persisted layout.
const TRACE := preload("res://src/AppShell/EditorEntryTrace.gd")

var shell: AppShellController
var _mode_picker: OptionButton
var _status: Label
var _home_button: Button


func setup(controller: AppShellController) -> void:
	shell = controller
	layer = 102
	_build_controls()
	if is_instance_valid(shell):
		shell.mode_changed.connect(_refresh)
	_refresh()
	_refresh.call_deferred()


func _build_controls() -> void:
	var panel := PanelContainer.new()
	panel.name = &"iPadDiagnosticControls"
	add_child(panel)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 14.0
	panel.offset_right = 590.0
	panel.offset_top = -206.0
	panel.offset_bottom = -40.0

	var margin := MarginContainer.new()
	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Phosprite iPad 闪退诊断版"
	title.add_theme_font_size_override(&"font_size", 18)
	column.add_child(title)

	var mode_row := HBoxContainer.new()
	column.add_child(mode_row)
	var mode_label := Label.new()
	mode_label.text = "测试模式："
	mode_row.add_child(mode_label)
	_mode_picker = OptionButton.new()
	_mode_picker.custom_minimum_size = Vector2(340.0, 42.0)
	for i in TRACE.MODE_LABELS.size():
		_mode_picker.add_item(_localized_mode_name(i), i)
	_mode_picker.select(shell.diagnostic_mode)
	_mode_picker.item_selected.connect(_on_mode_selected)
	mode_row.add_child(_mode_picker)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 24.0
	column.add_child(_status)

	var actions := HBoxContainer.new()
	column.add_child(actions)
	var copy := Button.new()
	copy.text = "复制诊断记录"
	copy.custom_minimum_size.y = 42.0
	copy.pressed.connect(_copy_report)
	actions.add_child(copy)
	_home_button = Button.new()
	_home_button.text = "返回项目库"
	_home_button.custom_minimum_size.y = 42.0
	_home_button.pressed.connect(_return_home)
	actions.add_child(_home_button)

	var hint := Label.new()
	hint.text = "完整记录：文件 App > 我的 iPad > Phosprite > Projects > Phosprite-Diagnostic.txt"
	hint.add_theme_font_size_override(&"font_size", 12)
	column.add_child(hint)


func _localized_mode_name(mode: int) -> String:
	match mode:
		0:
			return "0 正常模式（对照）"
		1:
			return "1 关闭 Preview"
		2:
			return "2 关闭 Timeline"
		3:
			return "3 关闭 Canvas 渲染"
		4:
			return "4 关闭 Workspace 窗口"
		5:
			return "5 仅显示空编辑器"
		6:
			return "6 关闭界面过渡动画"
	return "未知模式"


func _on_mode_selected(index: int) -> void:
	if not is_instance_valid(shell):
		return
	shell.set_diagnostic_mode(index)
	_refresh()


func _refresh(_mode: int = -1) -> void:
	if not is_instance_valid(_status) or not is_instance_valid(shell):
		return
	var last_interrupted := "无"
	var lines := TRACE.recent_report().split("\n")
	for i in range(lines.size() - 1, -1, -1):
		if lines[i].contains("INTERRUPTED: "):
			last_interrupted = lines[i].get_slice("INTERRUPTED: ", 1)
			break
	_status.text = "上次中断：%s | 当前：%s" % [
		last_interrupted,
		"项目库" if shell.is_gallery() else "编辑器",
	]
	_home_button.disabled = shell.is_gallery()


func _copy_report() -> void:
	var report := TRACE.recent_report()
	DisplayServer.clipboard_set("Phosprite iPad diagnostic\n" + report)
	_status.text = "已复制到剪贴板，可直接粘贴发到对话中。"


func _return_home() -> void:
	if is_instance_valid(shell):
		shell.return_home()
