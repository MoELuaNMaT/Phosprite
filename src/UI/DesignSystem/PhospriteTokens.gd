class_name PhospriteTokens
extends RefCounted

## Semantic palette, 4-tier surface ladder (S0-S3), pixel stroke unit (1U = 2dp),
## and dynamic UX motion constants for Phosprite Warm Cartridge UI chrome.
## Keep these colors separate from user artwork and from legacy Pixelorama themes.

const LEGACY := &"legacy"
const SUNNY := &"sunny_cream"
const TWILIGHT := &"twilight_berry"

const TIER_L := &"L"
const TIER_M := &"M"
const TIER_S := &"S"

## Global Pixel Stroke Unit (1U = 2 logical px = 4 physical px on iPad Retina)
const PIXEL_STROKE_UNIT := 2

## Unified Spacing Scale (4px base grid)
const SPACE_XXS := 2
const SPACE_XS := 4
const SPACE_SM := 8
const SPACE_MD := 12
const SPACE_LG := 16
const SPACE_XL := 24

## Unified Typography Scale (Fusion Pixel 12px Proportional + Noto CJK Fallback)
const FONT_BRAND := 24
const FONT_TITLE := 14
const FONT_CARD_TITLE := 12
const FONT_BODY := 12
const FONT_META := 11
const FONT_CAPTION := 10

## Unified Bar & Control Dimensions
const GALLERY_TOPBAR_HEIGHT := 56
const EDITOR_TOPBAR_HEIGHT := 48
const BUTTON_HEIGHT_MD := 36
const BUTTON_HEIGHT_SM := 34
const TOPBAR_ICON_BTN_SIZE := 36
const ICON_SIZE_COMPACT := 16

## Dynamic UX Interaction Physics (adapted from open-claude-ui)
const MOTION_HAPTIC_SNAP_SEC := 0.07
const MOTION_GEOMETRIC_BITE_SEC := 0.12
const MOTION_PANEL_SPRING_SEC := 0.24
const POINTER_DEADZONE_PX := 4.0

## Warm Paper (Light Mode — S0 #3D3B38 / S1 #E5E0D6 / S2 #F2EFE9 / S3 #FCFBF7)
const SUNNY_COLORS := {
	# Core 4-tier surface ladder & semantic tokens
	"panel_surface": "#F2EFE9",
	"well_surface": "#E5E0D6",
	"elevated_surface": "#FCFBF7",
	"outline_ink": "#2C2A29",
	"text_primary": "#242220",
	"text_muted": "#6E685F",
	"text_on_accent": "#FFFFFF",
	"pixel_shadow": "#C9C2B6",
	"accent_primary": "#E85D3F",
	"accent_secondary": "#3A6EA5",
	"accent_soft": "#FDE6DF",
	"accent_selected_surface": "#FFF4F0",
	"accent_cta_coral": "#E85D3F",
	"accent_cta_coral_hover": "#D94F33",
	"border_subtle": "#C9C2B6",
	"checkbox_border": "#2C2A29",
	"danger_primary": "#C93B2B",
	"danger_soft": "#FCE4E1",
	# Warm Cartridge Gallery & TopBar tokens (zero purple clash)
	"gallery_ground": "#EAE5DC",
	"gallery_thumb_bg": "#3D3B38",
	"gallery_thumb_selected_bg": "#47433E",
	"gallery_title_text": "#242220",
	"gallery_meta_text": "#6E685F",
	"canvas_backdrop": "#3D3B38",
	"topbar_surface": "#E5E0D6",
	"topbar_highlight": "#F5F2EB",
	"topbar_shade": "#C9C2B6",
	"topbar_border": "#2C2A29",
	"topbar_cast_shadow": "#D6CFC3",
	"topbar_text": "#242220",
	"topbar_btn_surface": "#F5F2EB",
	"topbar_btn_text": "#242220",
	"topbar_btn_border": "#2C2A29",
	"topbar_btn_hover": "#FCFBF7",
	"topbar_btn_shadow": "#2C2A29",
	"topbar_pill_surface": "#DCD6CA",
	"topbar_pill_inner_shadow": "#C9C2B6",
	"topbar_pill_inner_light": "#F5F2EB",
	"topbar_pill_text": "#242220",
	# Legacy aliases retained only for backward-compatible callers
	"floppy_ink": "#2C2A29",
	"floppy_shell": "#F2EFE9",
	"floppy_shell_light": "#FCFBF7",
	"floppy_shell_shade": "#D6CFC3",
	"floppy_shell_selected": "#FFF4F0",
	"floppy_shell_selected_light": "#FFFFFF",
	"floppy_shell_selected_shade": "#E85D3F",
	"floppy_shadow": "#C9C2B6",
	"floppy_shadow_selected": "#E85D3F",
	"floppy_shutter": "#E5E0D6",
	"floppy_shutter_light": "#F5F2EB",
	"floppy_shutter_shade": "#C9C2B6",
	"floppy_shutter_selected": "#FDE6DF",
	"floppy_shutter_selected_light": "#FFF4F0",
	"floppy_shutter_selected_shade": "#E85D3F",
	"floppy_shutter_slot": "#D6CFC3",
	"floppy_shutter_slot_shadow": "#B5AEA2",
	"floppy_shutter_slot_light": "#F2EFE9",
	"floppy_label": "#FCFBF7",
	"floppy_label_inner_shadow": "#E5E0D6",
	"floppy_label_inner_light": "#FFFFFF",
	"floppy_label_stripe": "#E85D3F",
	"floppy_label_stripe_light": "#F2856D",
	"floppy_label_stripe_shade": "#B83E25",
	"floppy_label_stripe_selected": "#3A6EA5",
	"floppy_label_stripe_selected_light": "#6192C4",
	"floppy_label_stripe_selected_shade": "#264E78",
	"floppy_notch": "#C9C2B6",
}

## Dark Cartridge (Dark Mode — S0 #171615 / S1 #1C1A18 / S2 #242220 / S3 #2C2926)
const TWILIGHT_COLORS := {
	# Core 4-tier surface ladder & semantic tokens (de-dilated #EDE9E0 text)
	"panel_surface": "#242220",
	"well_surface": "#1C1A18",
	"elevated_surface": "#2C2926",
	"outline_ink": "#0E0D0C",
	"text_primary": "#EDE9E0",
	"text_muted": "#A39C92",
	"text_on_accent": "#171615",
	"pixel_shadow": "#0E0D0C",
	"accent_primary": "#F06D4F",
	"accent_secondary": "#5B93CC",
	"accent_soft": "#3A241E",
	"accent_selected_surface": "#36221C",
	"accent_cta_coral": "#F06D4F",
	"accent_cta_coral_hover": "#FF8266",
	"border_subtle": "#3A3632",
	"checkbox_border": "#A39C92",
	"danger_primary": "#E5534B",
	"danger_soft": "#3D1F1E",
	# Dark Cartridge Gallery & TopBar tokens
	"gallery_ground": "#1B1917",
	"gallery_thumb_bg": "#171615",
	"gallery_thumb_selected_bg": "#2B221F",
	"gallery_title_text": "#EDE9E0",
	"gallery_meta_text": "#A39C92",
	"canvas_backdrop": "#171615",
	"topbar_surface": "#1C1A18",
	"topbar_highlight": "#2C2926",
	"topbar_shade": "#0E0D0C",
	"topbar_border": "#0E0D0C",
	"topbar_cast_shadow": "#0E0D0C",
	"topbar_text": "#EDE9E0",
	"topbar_btn_surface": "#2C2926",
	"topbar_btn_text": "#EDE9E0",
	"topbar_btn_border": "#0E0D0C",
	"topbar_btn_hover": "#36322E",
	"topbar_btn_shadow": "#0E0D0C",
	"topbar_pill_surface": "#171615",
	"topbar_pill_inner_shadow": "#0E0D0C",
	"topbar_pill_inner_light": "#3A3632",
	"topbar_pill_text": "#EDE9E0",
	# Legacy aliases retained only for backward-compatible callers
	"floppy_ink": "#0E0D0C",
	"floppy_shell": "#242220",
	"floppy_shell_light": "#36322E",
	"floppy_shell_shade": "#171615",
	"floppy_shell_selected": "#3A241E",
	"floppy_shell_selected_light": "#4D3129",
	"floppy_shell_selected_shade": "#F06D4F",
	"floppy_shadow": "#0E0D0C",
	"floppy_shadow_selected": "#F06D4F",
	"floppy_shutter": "#2C2926",
	"floppy_shutter_light": "#3A3632",
	"floppy_shutter_shade": "#171615",
	"floppy_shutter_selected": "#3A241E",
	"floppy_shutter_selected_light": "#4D3129",
	"floppy_shutter_selected_shade": "#F06D4F",
	"floppy_shutter_slot": "#171615",
	"floppy_shutter_slot_shadow": "#0E0D0C",
	"floppy_shutter_slot_light": "#2C2926",
	"floppy_label": "#1C1A18",
	"floppy_label_inner_shadow": "#0E0D0C",
	"floppy_label_inner_light": "#2C2926",
	"floppy_label_stripe": "#F06D4F",
	"floppy_label_stripe_light": "#FF8C73",
	"floppy_label_stripe_shade": "#B8442A",
	"floppy_label_stripe_selected": "#5B93CC",
	"floppy_label_stripe_selected_light": "#84B2E0",
	"floppy_label_stripe_selected_shade": "#3A6EA5",
	"floppy_notch": "#1C1A18",
}

## Detection anchor colors (must match Themes.gd registration verbatim)
const SUNNY_DETECT_BASE := "#F2EFE9"
const SUNNY_DETECT_ACCENT := "#E85D3F"
const TWILIGHT_DETECT_BASE := "#242220"
const TWILIGHT_DETECT_ACCENT := "#F06D4F"


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
	if (
		base.is_equal_approx(Color(SUNNY_DETECT_BASE))
		and accent.is_equal_approx(Color(SUNNY_DETECT_ACCENT))
	):
		return SUNNY
	if (
		base.is_equal_approx(Color(TWILIGHT_DETECT_BASE))
		and accent.is_equal_approx(Color(TWILIGHT_DETECT_ACCENT))
	):
		return TWILIGHT
	return LEGACY


static func tier_size(tier: StringName, pixel_unit := 1) -> int:
	var extra := (clampi(pixel_unit, 1, 3) - 1) * 4
	match tier:
		TIER_L:
			return 24 + extra
		TIER_M:
			return 20 + extra
		TIER_S:
			return 16 + extra
		_:
			return 0


static func tier_texture_margin(tier: StringName, pixel_unit := 1) -> int:
	var extra := (clampi(pixel_unit, 1, 3) - 1) * 2
	match tier:
		TIER_L:
			return 10 + extra
		TIER_M:
			return 7 + extra
		TIER_S:
			return 5 + extra
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


static func corner_cutoffs(tier: StringName, pixel_unit := 1) -> PackedInt32Array:
	var unit := clampi(pixel_unit, 1, 3)
	var base: PackedInt32Array
	match tier:
		TIER_L:
			base = PackedInt32Array([2, 1])
		TIER_M:
			base = PackedInt32Array([1])
		TIER_S:
			base = PackedInt32Array([1])
		_:
			return PackedInt32Array()
	if unit == 1:
		return base
	var scaled := PackedInt32Array()
	for cutoff in base:
		for _repeat in range(unit):
			scaled.append(cutoff * unit)
	return scaled
