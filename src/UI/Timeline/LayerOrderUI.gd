extends RefCounted

## Layer order changes must not free LayerButton nodes during touch or UndoRedo.
## Match each model layer to its existing row and cel container by object identity.


static func capture(timeline: AnimationTimeline, project: Project) -> Dictionary:
	if not is_instance_valid(timeline) or not is_instance_valid(project):
		return {}
	var count := project.layers.size()
	if (
		timeline.layer_vbox.get_child_count() != count
		or timeline.cel_vbox.get_child_count() != count
	):
		push_error("Cannot capture layer order: Timeline rows do not match the project")
		return {}
	var rows := {}
	for model_index in count:
		var visual_index := count - 1 - model_index
		var layer_row := timeline.layer_vbox.get_child(visual_index) as LayerButton
		var cel_row := timeline.cel_vbox.get_child(visual_index) as HBoxContainer
		if not is_instance_valid(layer_row) or not is_instance_valid(cel_row):
			push_error("Cannot capture layer order: missing Timeline row")
			return {}
		if layer_row.layer_index != model_index:
			push_error("Cannot capture layer order: stale Timeline layer index")
			return {}
		rows[project.layers[model_index]] = [layer_row, cel_row]
	return rows


static func restore(timeline: AnimationTimeline, project: Project, rows: Dictionary) -> void:
	var count := project.layers.size()
	if not is_instance_valid(timeline) or rows.size() != count:
		push_error("Cannot restore layer order: incomplete Timeline snapshot")
		return
	# Check every reference before changing either row container.
	for layer in project.layers:
		if not rows.has(layer):
			push_error("Cannot restore layer order: layer identity changed")
			return
		var pair: Array = rows[layer]
		if pair.size() != 2 or not is_instance_valid(pair[0]) or not is_instance_valid(pair[1]):
			push_error("Cannot restore layer order: Timeline row was released")
			return

	# Both containers have the opposite order of the model layer array.
	# Moving from visual index zero upward keeps earlier destinations stable.
	for visual_index in count:
		var layer := project.layers[count - 1 - visual_index]
		var pair: Array = rows[layer]
		timeline.layer_vbox.move_child(pair[0], visual_index)
		timeline.cel_vbox.move_child(pair[1], visual_index)
	for model_index in count:
		var layer_row: LayerButton = rows[project.layers[model_index]][0]
		layer_row.layer_index = model_index
		layer_row.refresh_ancestor_color_sources()
	timeline.update_layer_expanded_status()
	timeline.update_global_layer_buttons()
