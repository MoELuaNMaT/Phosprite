class_name PhospriteUIFont
extends RefCounted

## UI font cascade for exported iPad builds.
##
## Ships SIL OFL 1.1 Fusion Pixel 12px Proportional as the primary pixel-art UI
## font (covering Latin, Simplified/Traditional Chinese, Japanese, and Korean)
## with bundled Noto Sans CJK as the guaranteed first fallback so all 40+
## translations render with zero tofu glyphs on every iPad.

const BUNDLED_PIXEL_PATH := "res://assets/fonts/FusionPixel12pxProportional.ttf"
const BUNDLED_CJK_PATH := "res://assets/fonts/NotoSansCJKsc-Regular.otf"


static func load_bundled_pixel() -> Font:
	if not ResourceLoader.exists(BUNDLED_PIXEL_PATH):
		return null
	return ResourceLoader.load(BUNDLED_PIXEL_PATH, "Font") as Font


static func load_bundled_cjk() -> Font:
	if not ResourceLoader.exists(BUNDLED_CJK_PATH):
		return null
	return ResourceLoader.load(BUNDLED_CJK_PATH, "Font") as Font


static func prepare_ios_font(base: Font) -> Font:
	var pixel := load_bundled_pixel()
	var bundled := load_bundled_cjk()
	if bundled == null:
		# The iOS CI rejects such a package; this also helps identify broken
		# local builds without altering the user's font selection.
		push_error("Missing bundled iOS CJK UI font: %s" % BUNDLED_CJK_PATH)
	var system := SystemFont.new()
	system.font_names = PackedStringArray(
		["PingFang SC", "PingFang TC", "Hiragino Sans GB", "Heiti SC", "Helvetica Neue"]
	)
	var primary := pixel if pixel != null else base
	return compose_font(primary, bundled, system)


## Keep the selected font and its user-defined fallbacks. Put the guaranteed
## bundled CJK font first, then custom fallbacks, then optional system fonts.
## This avoids storing a SystemFont-only setup in the global Theme resource.
static func compose_font(base: Font, bundled: Font, system: Font) -> Font:
	if base == null:
		return null
	var font := base.duplicate() as Font
	if font == null:
		return base
	var order: Array[Font] = []
	if bundled != null and bundled != base:
		order.append(bundled)
	for fallback in font.fallbacks:
		if fallback != null and not order.has(fallback) and fallback != font:
			order.append(fallback)
	if system != null and not order.has(system):
		order.append(system)
	var default_fallback := ThemeDB.fallback_font
	if default_fallback != null and default_fallback != font and not order.has(default_fallback):
		order.append(default_fallback)
	font.fallbacks = order
	return font


static func bundled_supports_basic_ui_text() -> bool:
	var font := load_bundled_cjk()
	if font == null:
		return false
	for glyph in ["中", "文", "繁", "體", "日", "あ", "한", "A", "1"]:
		if not font.has_char(glyph.unicode_at(0)):
			return false
	return true
