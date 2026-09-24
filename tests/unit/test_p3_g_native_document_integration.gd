extends "res://tests/test_base.gd"


func test_p3_g_native_bridge_contract_and_security_scope() -> void:
	var native_src := FileAccess.get_file_as_string(
		"res://ios/native_documents_src/phosprite_native_documents.mm"
	)
	var bridge_src := FileAccess.get_file_as_string(
		"res://src/PlatformServices/IOSDocumentBridge.gd"
	)
	var shell_src := FileAccess.get_file_as_string("res://src/AppShell/AppShellController.gd")
	var workflow := FileAccess.get_file_as_string("res://.github/workflows/ios-build.yml")

	check_has(
		native_src,
		"UIDocumentPickerViewController",
		"P3-G Files import must use the native iOS document picker",
	)
	check_has(
		native_src,
		"picker.allowsMultipleSelection = YES",
		"P3-G Files picker must support native multi-selection",
	)
	check_has(
		native_src,
		"PHPickerViewController",
		"P3-G Photos import must use the native iOS photo picker",
	)
	check_has(
		native_src,
		"configuration.selectionLimit = 0",
		"P3-G Photos picker must allow native multi-selection",
	)
	check_has(
		native_src,
		"CGImageGetWidth(p_image.CGImage)",
		(
			"Photos import must derive temporary PNG dimensions from source pixels "
			+ "rather than UIImage points"
		),
	)
	check_has(
		native_src,
		"format.scale = 1.0",
		"Photos import renderer must not multiply pixel-art dimensions by the Retina screen scale",
	)
	check_has(
		native_src,
		"startAccessingSecurityScopedResource",
		"external Files URLs must enter a security-scoped access window",
	)
	check_has(
		native_src,
		"stopAccessingSecurityScopedResource",
		"external Files URLs must always release security-scoped access after sandbox copy",
	)
	check_has(
		native_src,
		"NSFileCoordinator",
		"external document copy-in must use coordinated file access",
	)
	check_has(
		native_src,
		"scene:openURLContexts:",
		"warm scene Open In must be captured on iOS 14+",
	)
	check_has(
		native_src,
		"scene:willConnectToSession:options:",
		"cold-launch document URLs must be captured before Godot startup finishes",
	)
	check_has(
		native_src,
		'@"open_in"',
		"Files Open In events must enter the same native event queue",
	)
	check_has(
		native_src,
		'@"shareddocuments://"',
		"P3-G must expose the iOS Files reveal capability",
	)
	check_has(
		bridge_src,
		"app_shell.handoff_import_path(_current_temp_path, enter_editor)",
		"native inputs must reuse the P3-F business handoff instead of duplicating import logic",
	)
	check_has(
		bridge_src,
		"native_bridge.cleanup_temp_file(_current_temp_path)",
		"temporary native copies must be released after each business import flow completes",
	)
	check_has(
		shell_src,
		"signal import_flow_finished(success: bool)",
		"AppShell must tell the native queue when an async image decision has fully completed",
	)
	check_has(
		workflow,
		"plugin=phosprite_native_documents",
		"iOS CI must compile the P3-G native plugin against the pinned Godot version",
	)
	check_has(
		workflow,
		"grep -q 'PhospriteNativeDocuments'",
		"iOS CI must verify the P3-G plugin is embedded in the Xcode export",
	)


func test_p3_g_ios_document_types_and_files_visibility_contract() -> void:
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")

	check_has(
		presets,
		"com.phosprite.project",
		"PXO must be declared as a Phosprite-owned iOS document type",
	)
	check_has(
		presets,
		"com.phosprite.import.aseprite",
		"ASE/ASEPRITE must be declared as an imported iOS document type",
	)
	check_has(
		presets,
		"<string>public.image</string>",
		"supported images must advertise Phosprite as an iOS editor target",
	)
	check_has(
		presets,
		"<key>CFBundleDocumentTypes</key>",
		"Files Open In requires CFBundleDocumentTypes declarations",
	)
	check_has(
		presets,
		"<key>UIFileSharingEnabled</key><true/>",
		"managed Projects must remain visible from the iOS Files app",
	)
	check_has(
		presets,
		"<key>LSSupportsOpeningDocumentsInPlace</key><true/>",
		"iOS document integration must keep opening-documents-in-place enabled",
	)
	check_has(
		presets,
		"user_data/accessible_from_files_app=true",
		"Godot iOS export must expose the app Documents folder to Files",
	)
	check_has(
		presets,
		'application/min_ios_version="14.0"',
		"P3-G native APIs are locked to the existing iOS 14 minimum",
	)


func test_p3_g_does_not_move_p3_f_business_logic_into_native_code() -> void:
	var native_src := FileAccess.get_file_as_string(
		"res://ios/native_documents_src/phosprite_native_documents.mm"
	)
	check_true(
		not native_src.contains("ZIPPacker"),
		"native bridge must not implement PXO persistence",
	)
	check_true(
		not native_src.contains("AsepriteParser"),
		"native bridge must not duplicate ASE conversion",
	)
	check_true(
		not native_src.contains("CanvasSizeResolver"),
		"native bridge must not own image canvas policy",
	)
	check_true(
		not native_src.contains("ProjectSaveCoordinator"),
		"native bridge must not bypass P3-B managed persistence",
	)
