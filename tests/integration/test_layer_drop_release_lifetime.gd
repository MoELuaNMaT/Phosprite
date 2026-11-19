extends "res://tests/test_base.gd"

## Regression for an iPad crash when the bottom of two layers is moved above
## the other layer. Layer removal synchronously frees LayerTouchAdapter, so a
## drop must never perform the removal inside its touch-release callback.


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
	
	# Reproduce the exact touch release path. The adapter clears the payload
	# immediately after committing, and its parent is freed during the move.
	source_touch.set("_drop_target", target_row.main_button)
	source_touch.set("_drop_local_position", Vector2(1.0, -1.0))
	source_touch.set("_reorder_data", ["Layer", PackedInt32Array([0]), false])
	source_touch.call("_commit_reorder_if_valid")
	source_touch.call("_finish_reorder")

	check_eq(project.layers[0], bottom_layer, "release must not mutate the stack in the input callback")
	check_eq(project.layers[1], top_layer, "drop must be pending until the input call completes")

	await tree.process_frame
	check_eq(project.layers[0], top_layer, "lower layer must move above the original upper layer")
	check_eq(project.layers[1], bottom_layer, "moved layer must retain its identity")
	check_eq(project.frames[0].cels[0], top_cel, "upper cel must move with its layer")
	check_eq(project.frames[0].cels[1], bottom_cel, "bottom cel must move with its layer")
	check_true(not is_instance_valid(source_row), "old source UI must be released after input completion")

	project.undo_redo.undo()
	check_eq(project.layers[0], bottom_layer, "Undo must restore the original bottom layer")
	check_eq(project.layers[1], top_layer, "Undo must restore the original upper layer")
	project.undo_redo.redo()
	check_eq(project.layers[1], bottom_layer, "Redo must restore the reordered stack")
	project.undo_redo.undo()
	check_eq(project.layers[1], top_layer, "final Undo must return to the fixture stack")

	# Remove only the fixture layer and restore the original selection.
	project.remove_layers(PackedInt32Array([1]))
	project.change_cel(-1, original_current)
	await tree.process_frame
	check_eq(project.layers.size(), 1, "reorder test must leave the editor with one layer")
