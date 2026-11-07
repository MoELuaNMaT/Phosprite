extends "res://tests/test_base.gd"


func test_phosprite_catalog_translates_core_ipad_ui() -> void:
	for locale in ["zh_CN", "zh_TW"]:
		var translation := load("res://Translations/%s.po" % locale) as Translation
		check_true(translation != null, "%s translation must load" % locale)
		if translation == null:
			continue
		for source in [
			"Multi-Select",
			"New Project",
			"Single frame",
			"Switch to single-frame layer view",
			"Palette & Color",
			"Auto Outline",
			"More Settings…",
			"Shortcut profile:",
			"Preview",
			"Animation Timeline",
			"Ctr",
			"Flip",
			"Grid",
			"Px",
			"Ref",
			"BW",
		]:
			var translated := String(translation.get_message(source))
			check_true(
				not translated.is_empty() and translated != source,
				"%s translation missing for %s" % [locale, source],
			)


func test_formatted_messages_keep_printf_placeholders() -> void:
	for locale in ["zh_CN", "zh_TW"]:
		var translation := load("res://Translations/%s.po" % locale) as Translation
		check_true(translation != null, "%s translation available" % locale)
		if translation == null:
			continue
		for source in [
			"%d projects deleted.",
			"Could not rename this project. Error code %s (%s)",
		]:
			var translated := String(translation.get_message(source))
			check_eq(
				translated.count("%d"),
				source.count("%d"),
				"%s preserves integer placeholders" % locale,
			)
			check_eq(
				translated.count("%s"),
				source.count("%s"),
				"%s preserves string placeholders" % locale,
			)


func test_dynamic_timeline_and_gallery_update_for_locale_changes() -> void:
	var timeline := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/TimelineHeaderControls.gd"
	)
	check_has(timeline, "NOTIFICATION_TRANSLATION_CHANGED", "timeline responds to locale")
	check_has(timeline, 'tr("Single frame")', "timeline mode uses translation")
	var gallery := FileAccess.get_file_as_string("res://src/UI/ProjectGallery/ProjectGallery.gd")
	check_has(gallery, "NOTIFICATION_TRANSLATION_CHANGED", "gallery responds to locale")


func test_workspace_headers_translate_resolved_names_without_mutating_ids() -> void:
	var workspace_source := FileAccess.get_file_as_string(
		"res://src/UI/Workspace/WorkspaceModule.gd"
	)
	check_has(
		workspace_source,
		"return tr(title)",
		"Workspace titles are translated when they are displayed",
	)
	check_has(
		workspace_source,
		"NOTIFICATION_TRANSLATION_CHANGED",
		"workspace header redraws when language changes",
	)
	var preview_definition := WorkspaceModuleDefinition.new()
	preview_definition.module_id = &"preview"
	preview_definition.display_name = "Preview"
	var preview := WorkspaceModule.new()
	preview.definition = preview_definition
	check_eq(
		preview.get_header_display_title(), preview.tr("Preview"),
		"Preview header goes through TranslationServer",
	)
	var timeline_definition := WorkspaceModuleDefinition.new()
	timeline_definition.module_id = &"animation_timeline"
	timeline_definition.display_name = "Animation Timeline"
	preview.definition = timeline_definition
	check_eq(
		preview.get_header_display_title(), preview.tr("Animation Timeline"),
		"Animation Timeline header goes through TranslationServer",
	)
	check_eq(
		timeline_definition.module_id,
		&"animation_timeline",
		"translated title does not alter stable workspace identifier",
	)
	preview.free()
