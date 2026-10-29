extends "res://tests/test_base.gd"


func test_new_pixel_layer_inherits_project_outline_and_switching_layers_keeps_state() -> void:
	var project := Global.current_project
	check_true(is_instance_valid(project), "editor must have an active project")
	if not is_instance_valid(project) or project.frames.is_empty():
		return

	var old_enabled := project.auto_outline_enabled
	var old_color := project.auto_outline_color
	var old_width := project.auto_outline_width
	var old_diagonals := project.auto_outline_diagonals
	var old_changed := project.has_changed
	var old_layer := project.current_layer
	var new_layer := PixelLayer.new(project, "Auto Outline test layer")
	new_layer.index = project.layers.size()
	var new_index := new_layer.index

	# Set project-wide mode FIRST, then create the layer, matching the iPad bug.
	project.set_auto_outline_settings(Color.BLACK, 1, false)
	project.auto_outline_enabled = true
	project.layers.append(new_layer)
	for frame in project.frames:
		frame.cels.append(new_layer.new_empty_cel())
	project.order_layers()

	var cel := project.frames[project.current_frame].cels[new_index] as PixelCel
	check_true(cel != null, "new pixel layer has a drawable cel")
	if cel != null:
		var source := cel.get_image()
		source.set_pixel(3, 3, Color.RED)
		var outlined := new_layer.display_effects(cel)
		check_eq(outlined.get_pixel(3, 3), Color.RED, "new layer keeps its painted pixel")
		check_eq(outlined.get_pixel(2, 3), Color.BLACK, "new layer is automatically outlined")
		check_eq(source.get_pixel(2, 3).a, 0.0, "rendering does not change source pixels")

		new_layer.effects_enabled = false
		var disabled_local_effects := new_layer.display_effects(cel)
		check_eq(
			disabled_local_effects.get_pixel(2, 3),
			Color.BLACK,
			"project outline does not depend on local layer effect switch"
		)
		new_layer.effects_enabled = true

	project.change_cel(project.current_frame, new_index)
	check_true(project.auto_outline_enabled, "new selected layer retains project checkbox state")
	project.change_cel(project.current_frame, old_layer)
	check_true(project.auto_outline_enabled, "switching back retains project checkbox state")

	var metadata := project.serialize()
	check_true(bool(metadata.get("auto_outline_enabled", false)), "enabled state is saved")
	check_eq(metadata.get("auto_outline_color"), Color.BLACK.to_html(), "outline color is saved")
	check_eq(int(metadata.get("auto_outline_width", 0)), 1, "outline width is saved")

	project.auto_outline_enabled = false
	if cel != null:
		var without_outline := new_layer.display_effects(cel)
		check_eq(without_outline.get_pixel(2, 3).a, 0.0, "project toggle disables all outlines")

	project.current_layer = old_layer
	project.layers.remove_at(new_index)
	for frame in project.frames:
		frame.cels.remove_at(new_index)
	project.order_layers()
	project.set_auto_outline_settings(old_color, old_width, old_diagonals)
	project.auto_outline_enabled = old_enabled
	project.has_changed = old_changed
