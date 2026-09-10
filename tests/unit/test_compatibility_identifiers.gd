extends "res://tests/test_base.gd"

## P0-C compatibility contract tests.
##
## These guard the identifiers Phosprite must keep byte-compatible with
## upstream Pixelorama so that .pxo projects, GPL palettes and third-party
## extensions keep working. They assert against source text on purpose: the
## contract is "this literal exists", and a refactor that renames it is
## exactly the regression being defended against.

const PROJECT_SOURCE := "res://src/Classes/Project.gd"
const OPENSAVE_SOURCE := "res://src/Autoload/OpenSave.gd"
const PALETTES_SOURCE := "res://src/Autoload/Palettes.gd"
const EXTENSIONS_API_SOURCE := "res://src/Autoload/ExtensionsApi.gd"
const GLOBAL_SOURCE := "res://src/Autoload/Global.gd"
const HANDLE_EXTENSIONS_SOURCE := "res://src/HandleExtensions.gd"


func test_pxo_pixelorama_version_key_preserved() -> void:
	var src := FileAccess.get_file_as_string(PROJECT_SOURCE)
	check_has(
		src,
		'"pixelorama_version"',
		".pxo projects must keep serializing the legacy pixelorama_version key"
	)


func test_pxo_mimetype_entry_preserved() -> void:
	var src := FileAccess.get_file_as_string(OPENSAVE_SOURCE)
	check_has(
		src,
		"application/x-pixelorama",
		".pxo archive must keep the upstream application/x-pixelorama mimetype"
	)


func test_gpl_empty_slot_literal_preserved() -> void:
	var src := FileAccess.get_file_as_string(PALETTES_SOURCE)
	check_has(
		src, "PixeloramaEmptySlot", "GPL palette exchange must keep the PixeloramaEmptySlot literal"
	)


func test_gpl_empty_slot_write_and_read_sites_exist() -> void:
	var src := FileAccess.get_file_as_string(PALETTES_SOURCE)
	# The literal has to survive on both sides of the round-trip, otherwise
	# palettes exported by Phosprite lose their empty slots when re-imported.
	check_has(
		src,
		'var comment: String = "PixeloramaEmptySlot"',
		"GPL export must write the empty-slot marker"
	)
	check_has(
		src, 'color_data[3] == "PixeloramaEmptySlot"', "GPL import must match the empty-slot marker"
	)


func test_extension_api_pixelorama_identifiers_preserved() -> void:
	var src := FileAccess.get_file_as_string(EXTENSIONS_API_SOURCE)
	for identifier: String in [
		"get_pixelorama_version",
		"signal_pixelorama_opened",
		"signal_pixelorama_about_to_close",
	]:
		check_has(src, identifier, "Extensions API must keep %s" % identifier)


func test_global_pixelorama_signals_preserved() -> void:
	var src := FileAccess.get_file_as_string(GLOBAL_SOURCE)
	for signal_name: String in ["signal pixelorama_opened", "signal pixelorama_about_to_close"]:
		check_has(src, signal_name, "Global must keep %s" % signal_name)


func test_extension_manifest_api_key_preserved() -> void:
	var src := FileAccess.get_file_as_string(HANDLE_EXTENSIONS_SOURCE)
	check_has(
		src,
		"supported_api_versions",
		"third-party extension manifests must keep supported_api_versions"
	)
