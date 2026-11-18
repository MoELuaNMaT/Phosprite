class_name PhospriteTokens
extends RefCounted

## Opt-in semantic palette for Phosprite pixel UI chrome.
## Keep these colors separate from user artwork and from legacy Pixelorama themes.
##
## The stored strings match the production specification exactly. Convert them
## to Color only when needed, so no renderer modifies the user's paint pixels.

const LEGACY := &"legacy"
const SUNNY := &"sunny_cream"
const TWILIGHT := &"twilight_berry"

const TIER_L := &"L"
const TIER_M := &"M"
const TIER_S := &"S"

const SUNNY_COLORS := {
	"gallery_ground": "#F2F4F8",
	"canvas_backdrop": "#E4E8F0",
	"panel_surface": "#FAF8F3",
	"well_surface": "#ECEAE2",
	"outline_ink": "#282C40",
	"text_primary": "#282C40",
	"text_muted": "#5A627A",
	"pixel_shadow": "#B6DAFF",
	"accent_primary": "#4BA3FF",
	"accent_soft": "#DCEEFF",
	"accent_cta_coral": "#FF7863",
}

const TWILIGHT_COLORS := {
	"gallery_ground": "#1B1E2E",
	"canvas_backdrop": "#161826",
	"panel_surface": "#262A40",
	"well_surface": "#1E2133",
	"outline_ink": "#10121C",
	"text_primary": "#F2F4F8",
	"text_muted": "#9CA6C4",
	"pixel_shadow": "#0F111B",
	"accent_primary": "#58A6FF",
	"accent_soft": "#2E4366",
	"accent_cta_coral": "#FF806E",
}


static func get_palette(mode: StringName) -> Dictionary:
	match mode:
		SUNNY:
			return SUNNY_COLORS
		TWILIGHT:
			return TWILIGHT_COLORS
		_:
			return {}


static func color(mode: StringName, token: StringName) -> Color:
	var palette := get_palette(mode)
	var hex_value: String = palette.get(String(token), "")
	if hex_value.is_empty():
		push_warning("Unknown Phosprite color token '%s' in mode '%s'" % [token, mode])
		return Color.TRANSPARENT
	return Color(hex_value)


## The preset's unique (base, accent) pair is an opt-in signal.
## Other built-in and imported themes keep their existing visual treatment.
static func detect_mode(base: Color, accent: Color) -> StringName:
	for mode in [SUNNY, TWILIGHT]:
		if (
			base.is_equal_approx(color(mode, &"panel_surface"))
			and accent.is_equal_approx(color(mode, &"accent_primary"))
		):
			return mode
	return LEGACY


static func tier_size(tier: StringName) -> int:
	match tier:
		TIER_L:
			return 24
		TIER_M:
			return 20
		TIER_S:
			return 16
		_:
			return 0


static func tier_texture_margin(tier: StringName) -> int:
	match tier:
		TIER_L:
			return 10
		TIER_M:
			return 7
		TIER_S:
			return 5
		_:
			return 0


static func tier_content_margin(tier: StringName) -> int:
	match tier:
		TIER_L:
			return 8
		TIER_M:
			return 4
		TIER_S:
			return 2
		_:
			return 0


## Opaque corner cut lengths, counted row by row from the nearest edge.
## The design spec describes the row widths as R10 3-2-1-1, R6 2-1-1,
## and R4 2-1. These profiles are symmetrical and consist of whole pixels.
static func corner_cutoffs(tier: StringName) -> PackedInt32Array:
	match tier:
		TIER_L:
			return PackedInt32Array([7, 4, 2, 1, 1, 0])
		TIER_M:
			return PackedInt32Array([4, 2, 1, 0])
		TIER_S:
			return PackedInt32Array([3, 1, 0])
		_:
			return PackedInt32Array()
