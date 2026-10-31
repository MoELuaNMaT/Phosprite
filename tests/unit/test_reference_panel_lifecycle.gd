extends "res://tests/test_base.gd"


func test_reference_panel_uses_hidden_context_state() -> void:
	var migration := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceEditorMigration.gd"
	)
	var interactions := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceInteractionController.gd"
	)
	var ui := FileAccess.get_file_as_string("res://src/UI/UI.gd")
	check_has(migration, "module_id == Builtins.REFERENCE_IMAGES_ID", "reference panel has own policy")
	check_has(migration, "return set_context_panel_visible(module_id, visible)", "panel is parked")
	check_has(interactions, "editor_migration.set_panel_visible(module_id, false)", "header hides instead of collapsing")
	check_has(ui, "OpenSave.reference_image_imported.connect", "successful imports reveal the panel")
	check_has(ui, "reference_image_removed.connect", "removing the last reference hides the panel")
	check_has(ui, "Global.project_switched.connect(_sync_reference_panel_visibility)", "visibility follows project")


func test_reference_import_uses_editor_not_gallery() -> void:
	var main := FileAccess.get_file_as_string("res://src/Main.gd")
	var bridge := FileAccess.get_file_as_string("res://src/PlatformServices/IOSDocumentBridge.gd")
	var native := FileAccess.get_file_as_string(
		"res://ios/native_documents_src/phosprite_native_documents.mm"
	)
	check_has(main, "request_reference_image_import(use_photos", "Preview has a dedicated import path")
	check_has(bridge, "func _import_reference_paths", "iPad imports into active references")
	check_has(bridge, "Global.current_project == _reference_import_project", "iPad does not target another project")
	check_has(bridge, 'event_type == "picker_finished"', "native picker state resets")
	check_has(native, 'enqueue_picker_finished_on_main(@"files")', "Files reports completion or cancellation")
	check_has(native, 'enqueue_picker_finished_on_main(@"photos")', "Photos reports completion or cancellation")
