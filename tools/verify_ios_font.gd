extends SceneTree

## Export-time glyph validation. Unlike desktop CI, this runs after the real
## iOS packaging workflow has fetched and imported the bundled OTF.
const FONT_STACK := preload("res://src/UI/DesignSystem/PhospriteUIFont.gd")
const ROBOTO := preload("res://assets/fonts/Roboto-Regular.ttf")


func _init() -> void:
	_verify.call_deferred()


func _verify() -> void:
	var font := FONT_STACK.load_bundled_cjk()
	if font == null:
		push_error("[PHOSPRITE-FONT-VERIFY] missing bundled iOS font")
		quit(1)
		return
	if not FONT_STACK.bundled_supports_basic_ui_text():
		push_error("[PHOSPRITE-FONT-VERIFY] bundled font lacks core UI glyphs")
		quit(1)
		return
	var combined := FONT_STACK.compose_font(ROBOTO, font, null)
	if combined == null or combined.fallbacks.is_empty() or combined.fallbacks[0] != font:
		push_error("[PHOSPRITE-FONT-VERIFY] font fallback chain is not installed")
		quit(1)
		return
	for sample in ["Phosprite", "项目", "圖層", "かな", "한글", "64 × 64"]:
		for i in sample.length():
			if not combined.has_char(sample.unicode_at(i)):
				push_error("[PHOSPRITE-FONT-VERIFY] missing glyph in '%s'" % sample)
				quit(1)
				return
	print("[PHOSPRITE-FONT-VERIFY] PASS: bundled CJK, Latin and numeric glyphs")
	quit(0)
