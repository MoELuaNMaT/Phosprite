extends "res://tests/test_base.gd"

const STACK := preload("res://src/UI/DesignSystem/PhospriteUIFont.gd")
const ROBOTO := preload("res://assets/fonts/Roboto-Regular.ttf")
const WORKFLOW := "res://.github/workflows/ios-build.yml"


func test_ui_font_composition_preserves_primary_and_prepends_cjk() -> void:
	var source: Font = ROBOTO
	var bundled := FontFile.new()
	var system := SystemFont.new()
	system.font_names = PackedStringArray(["PingFang SC"])

	var original_fallbacks := source.fallbacks.duplicate()
	var composed := STACK.compose_font(source, bundled, system)
	check_true(composed != source, "never mutate the selected font resource")
	check_true(composed is Font, "composed iOS font must remain a real Font")
	check_true(composed.fallbacks.size() >= 2, "CJK and platform fallback must both be present")
	check_eq(composed.fallbacks[0], bundled, "bundled CJK takes precedence over system lookup")
	check_has(composed.fallbacks, system, "system fallback remains a last resort")
	check_eq(source.fallbacks, original_fallbacks, "shared Roboto fallback list is unchanged")
	check_eq(
		composed.get_font_name(), source.get_font_name(), "selected Roboto face remains primary"
	)


func test_missing_primary_font_does_not_invent_glyphs() -> void:
	check_true(
		STACK.compose_font(null, FontFile.new(), SystemFont.new()) == null,
		"font helper must not silently choose a font unrelated to the selected theme"
	)
	check_eq(
		STACK.BUNDLED_CJK_PATH,
		"res://assets/fonts/NotoSansCJKsc-Regular.otf",
		"local preview and export must share one CJK resource path"
	)


func test_ios_ci_requires_font_download_validation_and_exported_fontdata() -> void:
	check_file_exists("res://tools/fetch_ios_font.sh", "pinned font downloader exists")
	check_file_exists("res://tools/verify_ios_font.gd", "actual glyph checks exist")
	check_file_exists("res://tools/verify_ios_pack_fonts.py", "PCK directory validation exists")
	check_file_exists(
		"res://assets/fonts/NotoSansCJKsc-License.txt", "open font license is in the repository"
	)
	var workflow := FileAccess.get_file_as_string(WORKFLOW)
	check_has(
		workflow,
		"bash tools/fetch_ios_font.sh",
		"font must be downloaded before Godot imports resources"
	)
	check_has(
		workflow,
		"res://tools/verify_ios_font.gd",
		"Godot checks actual CJK glyphs before iOS export"
	)
	check_has(
		workflow,
		"--script res://tools/verify_ios_font.gd -- --phosprite-test-runner",
		"font verification must use safe headless initialization, not the normal editor boot path"
	)
	check_has(
		workflow,
		"python3 tools/verify_ios_pack_fonts.py",
		"final archived IPA must have real imported fontdata"
	)
	check_has(
		workflow,
		"NotoSansCJKsc-License.txt",
		"Open Font License must be included beside the IPA's Godot pack"
	)
	check_has(
		workflow,
		'b"NotoSansCJKsc-Regular.otf"',
		"iOS export must reject a release with a missing CJK resource name"
	)
	var fetcher := FileAccess.get_file_as_string("res://tools/fetch_ios_font.sh")
	check_has(
		fetcher,
		"dc15562470b4f842321894787a0d066879ccff8b",
		"font source must be pinned to the reviewed Git blob"
	)
