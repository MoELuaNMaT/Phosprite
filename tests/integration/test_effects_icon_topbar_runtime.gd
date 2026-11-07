extends "res://tests/test_base.gd"

const TOP_MENU_SCRIPT := preload("res://src/UI/TopMenuContainer/TopMenuContainer.gd")


func test_ipad_topbar_icons_have_equal_real_gaps_and_fx_popup_opens() -> void:
	var top := TOP_MENU_SCRIPT.new()
	var row := HBoxContainer.new()
	var home := Button.new()
	var settings := MenuButton.new()
	var bar := MenuBar.new()
	var effects := PopupMenu.new()
	effects.name = &"Effects"
	effects.add_item("Sample Effect", 1)
	bar.add_child(effects)
	row.add_child(home)
	row.add_child(settings)
	row.add_child(bar)
	top.set("return_home_button", home)
	top.set("settings_button", settings)
	top.set("menu_bar", bar)
	top.set("effects_menu", effects)
	row.size = Vector2(200, 32)
	tree.root.add_child(row)
	top._set_ipad_topbar_icons(true)
	var fx := row.get_node_or_null("EffectsIconButton") as Button
	check_true(fx != null, "FX is a real button in the topbar row")
	if fx == null:
		row.queue_free()
		top.free()
		return

	row.move_child(fx, 2)
	bar.visible = false
	await tree.process_frame
	await tree.process_frame
	var first_gap := settings.position.x - home.position.x - home.size.x
	var second_gap := fx.position.x - settings.position.x - settings.size.x
	check_almost_eq(first_gap, second_gap, 0.1, "three icon buttons have equal spacing")
	check_almost_eq(first_gap, 4.0, 0.1, "topbar spacing matches the 4 px spec")
	check_almost_eq(home.size.x, settings.size.x, 0.1, "Projects and Settings widths match")
	check_almost_eq(settings.size.x, fx.size.x, 0.1, "Settings and FX widths match")

	fx.pressed.emit()
	await tree.process_frame
	check_true(effects.visible, "the original Effects popup opens above a hidden MenuBar")
	effects.hide()
	top._set_ipad_topbar_icons(false)
	row.queue_free()
	top.free()
