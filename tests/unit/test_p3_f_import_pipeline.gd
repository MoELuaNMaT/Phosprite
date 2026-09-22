extends "res://tests/test_base.gd"

const Resolver := preload("res://src/ProjectLibrary/CanvasSizeResolver.gd")
const ImportService := preload("res://src/ProjectLibrary/ProjectImportService.gd")
const AsepriteParserScript := preload("res://src/Classes/SoftwareParsers/AsepriteParser.gd")


func test_p3_f_canvas_size_resolver_uses_nearest_family_and_preserves_orientation() -> void:
	check_eq(
		Resolver.resolve(Vector2i(60, 40)),
		Vector2i(67, 50),
		"60x40 should choose the nearest 4:3 family and first containing preset",
	)
	check_eq(
		Resolver.resolve(Vector2i(40, 60)),
		Vector2i(50, 67),
		"portrait imports must swap the selected family preset orientation",
	)
	check_eq(
		Resolver.resolve(Vector2i(900, 500)),
		Vector2i(910, 512),
		"wide images should resolve into the 16:9 family",
	)
	check_eq(
		Resolver.resolve(Vector2i(1000, 1000)),
		Vector2i(256, 256),
		"images that exceed every family preset must use the exact 256x256 fallback",
	)
	check_eq(
		Resolver.resolve(Vector2i.ZERO),
		Vector2i(256, 256),
		"invalid source dimensions must use the exact 256x256 fallback",
	)


func test_p3_f_layer_and_reference_fit_contract() -> void:
	check_eq(
		Resolver.fit_layer_size(Vector2i(20, 10), Vector2i(64, 64)),
		Vector2i(20, 10),
		"smaller layer images must stay at 1:1 instead of being upscaled",
	)
	check_eq(
		Resolver.centered_offset(Vector2i(20, 10), Vector2i(64, 64)),
		Vector2i(22, 27),
		"1:1 layer images must be centered",
	)
	check_eq(
		Resolver.fit_layer_size(Vector2i(128, 64), Vector2i(64, 64)),
		Vector2i(64, 32),
		"oversized layer images must uniformly downfit",
	)
	check_eq(
		Resolver.centered_offset(Vector2i(64, 32), Vector2i(64, 64)),
		Vector2i(0, 16),
		"downfit layer images must remain centered",
	)
	check_eq(
		Resolver.reference_scale(Vector2i(128, 64), Vector2i(64, 64)),
		0.5,
		"reference import must use a uniform fit transform without resampling source pixels",
	)
	check_eq(
		Resolver.reference_position(Vector2i(128, 64), Vector2i(64, 64), 0.5),
		Vector2(0, 16),
		"reference import transform must center the fitted source",
	)


func test_aseprite_signed_short_coordinates_preserve_negative_offsets() -> void:
	check_eq(
		AsepriteParserScript.signed_16(0xFFFF),
		-1,
		"Aseprite SHORT value 0xFFFF must decode to -1 instead of 65535",
	)
	check_eq(
		AsepriteParserScript.signed_16(0x8000),
		-32768,
		"Aseprite SHORT minimum must retain its signed value",
	)
	check_eq(
		AsepriteParserScript.signed_16(0x7FFF),
		32767,
		"positive Aseprite SHORT values must remain unchanged",
	)
	var parser_src := FileAccess.get_file_as_string(
		"res://src/Classes/SoftwareParsers/AsepriteParser.gd"
	)
	check_has(
		parser_src,
		"var x_pos := signed_16(ase_file.get_16())",
		"cel X must use signed SHORT decoding so negative offsets remain on-canvas",
	)
	check_has(
		parser_src,
		"var y_pos := signed_16(ase_file.get_16())",
		"cel Y must use signed SHORT decoding so negative offsets remain on-canvas",
	)
	check_has(
		parser_src,
		"cel.z_index = signed_16(ase_file.get_16())",
		"cel z-index must preserve the signed Aseprite field",
	)


func test_aseprite_zlib_fallback_recovers_missing_adler32_only() -> void:
	var raw := PackedByteArray()
	for index in 4096:
		raw.append((index * 37 + 11) & 0xFF)

	var complete := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	check_true(complete.size() > 8, "fixture must produce a zlib stream with a trailer")
	var missing_checksum := complete.slice(0, complete.size() - 4)
	check_ne(
		missing_checksum.decompress(raw.size(), FileAccess.COMPRESSION_DEFLATE).size(),
		raw.size(),
		"Godot's strict decompressor must reject the checksum-less regression fixture",
	)
	check_eq(
		AsepriteParserScript.decompress_aseprite_payload(missing_checksum, raw.size()),
		raw,
		"Aseprite fallback must recover the complete deflate body when only Adler-32 is missing",
	)

	var body_truncated := missing_checksum.slice(0, missing_checksum.size() - 8)
	check_eq(
		AsepriteParserScript.decompress_aseprite_payload(body_truncated, raw.size()).size(),
		0,
		"fallback must reject a genuinely truncated deflate body",
	)
	check_eq(
		AsepriteParserScript.decompress_aseprite_payload(complete, raw.size()),
		raw,
		"standard complete zlib streams must retain their existing import path",
	)


func test_p3_f_supported_import_types_and_stage_boundaries() -> void:
	var service := ImportService.new()
	check_eq(
		service.classify_path("external/project.pxo"),
		ImportService.ImportKind.PXO,
		"PXO must route through managed copy-in",
	)
	check_eq(
		service.classify_path("external/project.ASEPRITE"),
		ImportService.ImportKind.ASEPRITE,
		"ASE/ASEPRITE detection must be case-insensitive",
	)
	for extension in ["png", "bmp", "hdr", "jpg", "jpeg", "svg", "tga", "webp", "exr"]:
		check_eq(
			service.classify_path("external/image." + extension),
			ImportService.ImportKind.IMAGE,
			"ordinary Pixelorama image formats must route through P3-F image import",
		)
	check_eq(
		service.classify_path("external/readme.txt"),
		ImportService.ImportKind.UNKNOWN,
		"unknown files must not silently enter the image path",
	)

	var shell_src := FileAccess.get_file_as_string("res://src/AppShell/AppShellController.gd")
	var service_src := FileAccess.get_file_as_string(
		"res://src/ProjectLibrary/ProjectImportService.gd"
	)
	var source_scene := FileAccess.get_file_as_string(
		"res://src/UI/ProjectGallery/ImportSourceDialog.tscn"
	)
	var mode_scene := FileAccess.get_file_as_string(
		"res://src/UI/ProjectGallery/ImageImportModeDialog.tscn"
	)

	check_has(source_scene, 'text = "文件"', "Import source popover must expose 文件")
	check_has(source_scene, 'text = "照片"', "Import source popover must expose 照片")
	check_has(mode_scene, 'text = "作为图层"', "image mode popover must expose 作为图层")
	check_has(mode_scene, 'text = "作为参考图"', "image mode popover must expose 作为参考图")
	check_has(
		shell_src,
		"signal files_import_source_requested",
		"P3-F must hand Files source selection to the future P3-G native bridge",
	)
	check_has(
		shell_src,
		"signal photos_import_source_requested",
		"P3-F must hand Photos source selection to the future P3-G native bridge",
	)
	check_has(
		shell_src,
		"func handoff_import_path(source_path: String",
		"P3-G may extend the handoff signature, but P3-F must retain one path-based business entry",
	)
	check_has(
		shell_src,
		"new_project_dialog.popup_with_size(source_size)",
		"image-as-layer must seed the project dialog from exact decoded source dimensions",
	)
	check_has(
		service_src,
		"DirAccess.copy_absolute(source_path, target_path)",
		"PXO import must copy into managed Projects instead of editing the external source",
	)
	check_has(
		service_src,
		"AsepriteParser.open_aseprite_file(source_path)",
		"ASE/ASEPRITE import must reuse the existing high-quality parser",
	)
	check_has(
		service_src,
		"if not AsepriteParser.open_aseprite_file(source_path):",
		"ASE import must fail instead of committing a project when cel decoding fails",
	)
	check_has(
		service_src,
		'save_coordinator.flush_project(project, "import_aseprite", target_path)',
		"ASE import must immediately convert into a managed PXO",
	)
	check_true(
		not source_scene.contains("FileDialog"),
		"P3-F must not implement the native Document Picker that belongs to P3-G",
	)
	check_true(
		not source_scene.contains("PhotoPicker"),
		"P3-F must not implement the native Photo Picker that belongs to P3-G",
	)
