extends "res://tests/test_base.gd"

## Regression for an iPad crash when the bottom of two layers is moved above
## the other layer. Reorder must not destroy either LayerTouchAdapter at all.


func test_two_layer_bottom_to_top_reorder_survives_touch_release() -> void:
	var project := Global.current_project
	var timeline := Global.animation_timeline as AnimationTimeline
	check_true(project != null, "integration runner must have an active project")
	check_true(timeline != null, "integration runner must have a real Animation Timeline")
	if project == null or timeline == null:
		return
	check_eq(project.layers.size(), 1, "reorder fixture requires the initial single layer")
	if project.layers.size() != 1 or project.frames.is_empty():
		return

	var bottom_layer := project.layers[0]
	var original_current := project.current_layer
	var top_layer := PixelLayer.new(project, "Drop lifetime fixture")
	top_layer.index = 1
	var top_cels := []
	for frame in project.frames:
		top_cels.append(top_layer.new_empty_cel())
	project.add_layers([top_layer], PackedInt32Array([1]), [top_cels])
	await tree.process_frame

	var source_row := timeline.layer_vbox.get_child(1) as LayerButton
	var target_row := timeline.layer_vbox.get_child(0) as LayerButton
	var source_touch := source_row.get_node_or_null("LayerTouchAdapter") as LayerTouchAdapter
	check_true(source_touch != null, "the bottom layer must own the touch adapter")
	if source_touch == null:
		project.remove_layers(PackedInt32Array([1]))
		return
	var bottom_cel := project.frames[0].cels[0]
	var top_cel := project.frames[0].cels[1]

	# Reproduce the touch release path. The adapter clears its payload
	# immediately after committing; the source must remain alive throughout.
	source_touch.set("_drop_target", target_row.main_button)
	source_touch.set("_drop_local_position", Vector2(1.0, -1.0))
	source_touch.set("_reorder_data", ["Layer", PackedInt32Array([0]), false])
	source_touch.call("_commit_reorder_if_valid")
	source_touch.call("_finish_reorder")

	check_eq(
		project.layers[0], bottom_layer, "release must not mutate the stack in the input callback"
	)
	check_eq(project.layers[1], top_layer, "drop must be pending until the input call completes")

	await tree.process_frame
	check_eq(project.layers[0], top_layer, "lower layer must move above the original upper layer")
	check_eq(project.layers[1], bottom_layer, "moved layer must retain its identity")
	check_eq(project.frames[0].cels[0], top_cel, "upper cel must move with its layer")
	check_eq(project.frames[0].cels[1], bottom_cel, "bottom cel must move with its layer")
	check_true(is_instance_valid(source_row), "source row must survive reorder")
	check_true(is_instance_valid(source_touch), "source touch adapter must survive reorder")
	check_eq(
		timeline.layer_vbox.get_child(0), source_row, "source row must move without replacement"
	)
	check_eq(timeline.layer_vbox.get_child(1), target_row, "target row must stay alive")
	check_eq(source_row.layer_index, 1, "source row must track its new model index")
	check_eq(target_row.layer_index, 0, "target row must track its new model index")

	project.undo_redo.undo()
	check_eq(project.layers[0], bottom_layer, "Undo must restore the original bottom layer")
	check_eq(project.layers[1], top_layer, "Undo must restore the original upper layer")
	check_eq(timeline.layer_vbox.get_child(1), source_row, "Undo must preserve source row identity")
	project.undo_redo.redo()
	check_eq(project.layers[1], bottom_layer, "Redo must restore the reordered stack")
	check_eq(timeline.layer_vbox.get_child(0), source_row, "Redo must reuse source row")
	project.undo_redo.undo()
	check_eq(project.layers[1], top_layer, "final Undo must return to the fixture stack")

	# Remove only the fixture layer and restore the original selection.
	project.remove_layers(PackedInt32Array([1]))
	project.change_cel(-1, original_current)
	await tree.process_frame
	check_eq(project.layers.size(), 1, "reorder test must leave the editor with one layer")


func test_two_layer_swap_keeps_layer_rows_and_cel_rows() -> void:
	var project := Global.current_project
	var timeline := Global.animation_timeline as AnimationTimeline
	check_eq(project.layers.size(), 1, "swap fixture needs the initial single layer")
	if project.layers.size() != 1:
		return

	var bottom_layer := project.layers[0]
	var top_layer := PixelLayer.new(project, "Swap lifetime fixture")
	top_layer.index = 1
	var top_cels := []
	for frame in project.frames:
		top_cels.append(top_layer.new_empty_cel())
	project.add_layers([top_layer], PackedInt32Array([1]), [top_cels])
	await tree.process_frame

	var bottom_row := timeline.layer_vbox.get_child(1)
	var top_row := timeline.layer_vbox.get_child(0)
	var bottom_cel_row := timeline.cel_vbox.get_child(1)
	var top_cel_row := timeline.cel_vbox.get_child(0)
	var a := {
		"from": [0],
		"to": [1],
		"to_parents": [null],
	}
	var b := {
		"from": [1],
		"to": [0],
		"to_parents": [null],
	}

	project.swap_layers(a, b)
	check_eq(project.layers[0], top_layer, "swap must move the upper model layer down")
	check_eq(project.layers[1], bottom_layer, "swap must move the lower model layer up")
	check_eq(timeline.layer_vbox.get_child(0), bottom_row, "swap must preserve bottom row")
	check_eq(timeline.layer_vbox.get_child(1), top_row, "swap must preserve top row")
	check_eq(timeline.cel_vbox.get_child(0), bottom_cel_row, "swap must preserve bottom cels")
	check_eq(timeline.cel_vbox.get_child(1), top_cel_row, "swap must preserve top cels")

	project.swap_layers(a, b)
	check_eq(project.layers[0], bottom_layer, "reverse swap must restore bottom layer")
	check_eq(project.layers[1], top_layer, "reverse swap must restore top layer")
	check_eq(timeline.layer_vbox.get_child(1), bottom_row, "reverse swap must preserve row")
	project.remove_layers(PackedInt32Array([1]))
	project.change_cel(-1, 0)
	await tree.process_frame
	check_eq(project.layers.size(), 1, "swap test must leave one layer")
