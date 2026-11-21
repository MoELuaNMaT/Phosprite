class_name Brushes
extends Popup

signal brush_selected(brush)
signal brush_removed(brush)
# Keep the existing numeric values stable because brush type is persisted in tool config.
enum { PIXEL, CIRCLE, FILLED_CIRCLE, FILE, RANDOM_FILE, CUSTOM, HOLLOW_SQUARE }

const BrushShapes := preload("res://src/Tools/BrushShapeGenerator.gd")
const DEFAULT_ICON_SIZE := 9


class Brush:
	var type: int
	var image: Image
	var random := []
	var index: int


func _ready() -> void:
	var container := (
		get_node("Background/Brushes/Categories/DefaultBrushContainer") as GridContainer
	)
	container.columns = 4
	_add_default_brush(
		container,
		PIXEL,
		BrushShapes.Shape.FILLED_SQUARE,
		"Square brush",
	)
	_add_default_brush(
		container,
		HOLLOW_SQUARE,
		BrushShapes.Shape.HOLLOW_SQUARE,
		"Hollow square brush",
	)
	_add_default_brush(
		container,
		FILLED_CIRCLE,
		BrushShapes.Shape.FILLED_CIRCLE,
		"Filled circle brush",
	)
	_add_default_brush(
		container,
		CIRCLE,
		BrushShapes.Shape.HOLLOW_CIRCLE,
		"Hollow circle brush",
	)
	if not about_to_popup.is_connected(_sync_category_visibility):
		about_to_popup.connect(_sync_category_visibility)
	_sync_category_visibility()


func _sync_category_visibility() -> void:
	var cats := get_node_or_null("Background/Brushes/Categories")
	if cats == null:
		return
	var is_ios := OS.get_name() == "iOS"
	var proj_container := cats.get_node_or_null("ProjectBrushContainer") as Control
	var proj_label := cats.get_node_or_null("ProjectLabel") as Control
	var file_container := cats.get_node_or_null("FileBrushContainer") as Control
	var file_label := cats.get_node_or_null("FileLabel") as Control
	var rand_container := cats.get_node_or_null("RandomFileBrushContainer") as Control
	var rand_label := cats.get_node_or_null("RandomFileLabel") as Control
	var default_label := cats.get_node_or_null("Label") as Control
	var has_proj := proj_container != null and proj_container.get_child_count() > 0
	var has_file := not is_ios and file_container != null and file_container.get_child_count() > 0
	var has_rand := not is_ios and rand_container != null and rand_container.get_child_count() > 0
	if proj_container != null:
		proj_container.visible = has_proj
	if proj_label != null:
		proj_label.visible = has_proj
	if file_container != null:
		file_container.visible = has_file
	if file_label != null:
		file_label.visible = has_file
	if rand_container != null:
		rand_container.visible = has_rand
	if rand_label != null:
		rand_label.visible = has_rand
	if default_label != null:
		default_label.visible = has_proj or has_file or has_rand
	if not has_proj and not has_file and not has_rand:
		size = Vector2i(176, 56)


func _add_default_brush(
	container: Container, type: int, shape: BrushShapes.Shape, tooltip: String
) -> void:
	var image := BrushShapes.create_preview_image(shape, DEFAULT_ICON_SIZE)
	var button := Brushes.create_button(image)
	button.brush.type = type
	button.tooltip_text = tooltip
	container.add_child(button)
	button.brush.index = button.get_index()
	if is_instance_valid(Global.brushes_popup):
		Global.brushes_popup._sync_category_visibility()


func select_brush(brush: Brush) -> void:
	brush_selected.emit(brush)
	hide()


static func get_default_brush() -> Brush:
	var brush := Brush.new()
	brush.type = PIXEL
	brush.index = 0
	return brush


static func create_button(image: Image) -> Node:
	var button: BaseButton = preload("res://src/UI/Buttons/BrushButton.tscn").instantiate()
	var tex := ImageTexture.create_from_image(image)
	button.get_node("BrushTexture").texture = tex
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


static func add_file_brush(images: Array, hint := "") -> void:
	var button := create_button(images[0])
	button.brush.type = FILE if images.size() == 1 else RANDOM_FILE
	button.brush.image = images[0]
	button.brush.random = images
	button.tooltip_text = hint
	var container
	if button.brush.type == RANDOM_FILE:
		container = Global.brushes_popup.get_node(
			"Background/Brushes/Categories/RandomFileBrushContainer"
		)
	else:
		container = Global.brushes_popup.get_node(
			"Background/Brushes/Categories/FileBrushContainer"
		)
	container.add_child(button)
	button.brush.index = button.get_index()


static func add_project_brush(image: Image, hint := "") -> void:
	var button := create_button(image)
	button.brush.type = CUSTOM
	button.brush.image = image
	button.tooltip_text = hint
	var container = Global.brushes_popup.get_node(
		"Background/Brushes/Categories/ProjectBrushContainer"
	)
	container.add_child(button)
	button.brush.index = button.get_index()
	container.visible = true
	Global.brushes_popup.get_node("Background/Brushes/Categories/ProjectLabel").visible = true


static func clear_project_brush() -> void:
	var container = Global.brushes_popup.get_node(
		"Background/Brushes/Categories/ProjectBrushContainer"
	)
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
		Global.brushes_popup.brush_removed.emit(child.brush)


func get_brush(type: int, index: int) -> Brush:
	var container = get_node("Background/Brushes/Categories/DefaultBrushContainer")
	if type in [PIXEL, CIRCLE, FILLED_CIRCLE, HOLLOW_SQUARE]:
		for child in container.get_children():
			if child.brush.type == type:
				return child.brush
		return Brushes.get_default_brush()

	match type:
		CUSTOM:
			container = get_node("Background/Brushes/Categories/ProjectBrushContainer")
		FILE:
			container = get_node("Background/Brushes/Categories/FileBrushContainer")
		RANDOM_FILE:
			container = get_node("Background/Brushes/Categories/RandomFileBrushContainer")

	var brush := Brushes.get_default_brush()
	if index < container.get_child_count():
		brush = container.get_child(index).brush
	return brush


func remove_brush(brush_button: Node) -> void:
	brush_removed.emit(brush_button.brush)

	var project := Global.current_project
	var undo_brushes: Array = project.brushes.duplicate()
	project.brushes.erase(brush_button.brush.image)

	if project.brushes.size() == 0:
		var container = Global.brushes_popup.get_node(
			"Background/Brushes/Categories/ProjectBrushContainer"
		)
		container.visible = false
		Global.brushes_popup.get_node("Background/Brushes/Categories/ProjectLabel").visible = false

	project.undo_redo.create_action("Delete Custom Brush")
	project.undo_redo.add_do_property(project, "brushes", project.brushes)
	project.undo_redo.add_undo_property(project, "brushes", undo_brushes)
	project.undo_redo.add_do_method(redo_custom_brush.bind(brush_button))
	project.undo_redo.add_undo_method(undo_custom_brush.bind(brush_button))
	project.undo_redo.add_undo_reference(brush_button)
	project.undo_redo.commit_action()


func undo_custom_brush(brush_button: BaseButton = null) -> void:
	Global.general_undo()
	var action_name := Global.current_project.undo_redo.get_current_action_name()
	if action_name == "Delete Custom Brush":
		$Background/Brushes/Categories/ProjectBrushContainer.add_child(brush_button)
		$Background/Brushes/Categories/ProjectBrushContainer.move_child(
			brush_button, brush_button.brush.index
		)
		brush_button.get_node("DeleteButton").visible = false


func redo_custom_brush(brush_button: BaseButton = null) -> void:
	Global.general_redo()
	var action_name := Global.current_project.undo_redo.get_current_action_name()
	if action_name == "Delete Custom Brush":
		$Background/Brushes/Categories/ProjectBrushContainer.remove_child(brush_button)
