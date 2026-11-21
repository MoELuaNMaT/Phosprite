class_name PhospriteTokens
extends RefCounted

## Opt-in semantic palette & unified design-system tokens for Phosprite pixel UI chrome.
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

## Unified Spacing Scale (4px base grid)
const SPACE_XXS := 2
const SPACE_XS := 4
const SPACE_SM := 8
const SPACE_MD := 12
const SPACE_LG := 16
const SPACE_XL := 24

## Unified Typography Scale (CJK & Latin balanced; never overrides font resource)
const FONT_BRAND := 20
const FONT_TITLE := 15
const FONT_CARD_TITLE := 13
const FONT_BODY := 13
const FONT_META := 11
const FONT_CAPTION := 10

## Unified Bar & Control Dimensions
const GALLERY_TOPBAR_HEIGHT := 68
const EDITOR_TOPBAR_HEIGHT := 48
const BUTTON_HEIGHT_MD := 40
const BUTTON_HEIGHT_SM := 34
const ICON_SIZE_COMPACT := 16

const SUNNY_COLORS := {
	# Core preserved contract tokens
	"panel_surface": "#FAF8F3",
	"well_surface": "#F3ECF0",
	"outline_ink": "#282C40",
	"text_primary": "#282C40",
	"text_muted": "#675D8F",
	"text_on_accent": "#FFFFFF",
	"pixel_shadow": "#B6DAFF",
	"accent_primary": "#4BA3FF",
	"accent_soft": "#C9ACE0",
	"accent_selected_surface": "#EBF4FF",
	"accent_cta_coral": "#FF7597",
	"accent_cta_coral_hover": "#FF8CA8",
	"border_subtle": "#6E6296",
	"checkbox_border": "#5D528A",
	"danger_primary": "#E54D66",
	"danger_soft": "#FFE6EC",
	# Dreamy Pastel Neo-Y2K Gallery & 3D Beveled Floppy Disk tokens
	"gallery_ground": "#DCDCE6",
	"gallery_thumb_bg": "#F6F5FA",
	"gallery_thumb_selected_bg": "#E3F0FF",
	"gallery_title_text": "#282C40",
	"gallery_meta_text": "#5E627A",
	"canvas_backdrop": "#4B4752",
	"topbar_surface": "#7A74F0",
	"topbar_highlight": "#A5A0FF",
	"topbar_shade": "#5851C9",
	"topbar_border": "#2A214A",
	"topbar_cast_shadow": "#CBC3F7",
	"topbar_text": "#FFFFFF",
	"topbar_btn_surface": "#6761DC",
	"topbar_btn_text": "#FFFFFF",
	"topbar_btn_border": "#9691FA",
	"topbar_btn_hover": "#5A54CF",
	"topbar_btn_shadow": "#4740A8",
	"topbar_pill_surface": "#5C55C9",
	"topbar_pill_inner_shadow": "#453EA6",
	"topbar_pill_inner_light": "#938DFC",
	"topbar_pill_text": "#FFFFFF",
	"floppy_ink": "#2A214A",
	"floppy_shell": "#CFC6FF",
	"floppy_shell_light": "#EFEBFF",
	"floppy_shell_shade": "#A89CEB",
	"floppy_shell_selected": "#66B3FF",
	"floppy_shell_selected_light": "#B3DCFF",
	"floppy_shell_selected_shade": "#3B82D6",
	"floppy_shadow": "#B5AAED",
	"floppy_shadow_selected": "#4478D9",
	"floppy_shutter": "#F7F4FF",
	"floppy_shutter_light": "#FFFFFF",
	"floppy_shutter_shade": "#D4CCF2",
	"floppy_shutter_selected": "#EAF5FF",
	"floppy_shutter_selected_light": "#FFFFFF",
	"floppy_shutter_selected_shade": "#B3D6FA",
	"floppy_shutter_slot": "#BDB2F2",
	"floppy_shutter_slot_shadow": "#8D80CF",
	"floppy_shutter_slot_light": "#E5E0FF",
	"floppy_label": "#FFFDF7",
	"floppy_label_inner_shadow": "#E6E0D1",
	"floppy_label_inner_light": "#FFFFFF",
	"floppy_label_stripe": "#FF85A6",
	"floppy_label_stripe_light": "#FFB5C9",
	"floppy_label_stripe_shade": "#DB5E82",
	"floppy_label_stripe_selected": "#459EFF",
	"floppy_label_stripe_selected_light": "#8FC7FF",
	"floppy_label_stripe_selected_shade": "#2A77CF",
	"floppy_notch": "#B5AAEB",
}

const TWILIGHT_COLORS := {
	# Core preserved contract tokens
	"panel_surface": "#262A40",
	"well_surface": "#1E2133",
	"outline_ink": "#10121C",
	"text_primary": "#F5F2FF",
	"text_muted": "#A9A0CE",
	"text_on_accent": "#FFFFFF",
	"pixel_shadow": "#0F111B",
	"accent_primary": "#58A6FF",
	"accent_soft": "#3D3066",
	"accent_selected_surface": "#293B6B",
	"accent_cta_coral": "#FF7597",
	"accent_cta_coral_hover": "#FF8CA8",
	"border_subtle": "#4B4278",
	"checkbox_border": "#A9A0CE",
	"danger_primary": "#FF6B81",
	"danger_soft": "#4A2236",
	# Dreamy Twilight Berry Gallery & 3D Beveled Floppy Disk tokens
	"gallery_ground": "#171526",
	"gallery_thumb_bg": "#24213B",
	"gallery_thumb_selected_bg": "#22345E",
	"gallery_title_text": "#F5F3FF",
	"gallery_meta_text": "#9D96C2",
	"canvas_backdrop": "#181524",
	"topbar_surface": "#3D3075",
	"topbar_highlight": "#6251A8",
	"topbar_shade": "#281E52",
	"topbar_border": "#100C22",
	"topbar_cast_shadow": "#100C21",
	"topbar_text": "#FAF8FF",
	"topbar_btn_surface": "#2D2259",
	"topbar_btn_text": "#F5F2FF",
	"topbar_btn_border": "#574899",
	"topbar_btn_hover": "#403375",
	"topbar_btn_shadow": "#16102E",
	"topbar_pill_surface": "#241B4A",
	"topbar_pill_inner_shadow": "#150F30",
	"topbar_pill_inner_light": "#4D3F87",
	"topbar_pill_text": "#D9D0FF",
	"floppy_ink": "#0E0A1F",
	"floppy_shell": "#372C66",
	"floppy_shell_light": "#5A4B99",
	"floppy_shell_shade": "#241B47",
	"floppy_shell_selected": "#3B78F5",
	"floppy_shell_selected_light": "#7BB0FF",
	"floppy_shell_selected_shade": "#224EB5",
	"floppy_shadow": "#0D091C",
	"floppy_shadow_selected": "#1D3685",
	"floppy_shutter": "#4C3F85",
	"floppy_shutter_light": "#7060B3",
	"floppy_shutter_shade": "#32285C",
	"floppy_shutter_selected": "#2B4C9E",
	"floppy_shutter_selected_light": "#4E78D6",
	"floppy_shutter_selected_shade": "#1B3370",
	"floppy_shutter_slot": "#211942",
	"floppy_shutter_slot_shadow": "#120D29",
	"floppy_shutter_slot_light": "#413573",
	"floppy_label": "#201A3B",
	"floppy_label_inner_shadow": "#130E26",
	"floppy_label_inner_light": "#332B59",
	"floppy_label_stripe": "#FF759E",
	"floppy_label_stripe_light": "#FFA6C1",
	"floppy_label_stripe_shade": "#CC4B74",
	"floppy_label_stripe_selected": "#5EC2FF",
	"floppy_label_stripe_selected_light": "#9EDDFF",
	"floppy_label_stripe_selected_shade": "#338CC7",
	"floppy_notch": "#221B42",
}

## Legacy detection anchor colors (must match Themes.gd registration verbatim)
const SUNNY_DETECT_BASE := "#FAF8F3"
const SUNNY_DETECT_ACCENT := "#4BA3FF"
const TWILIGHT_DETECT_BASE := "#262A40"
const TWILIGHT_DETECT_ACCENT := "#58A6FF"


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


## Opaque corner cut lengths, counted row by row from the nearest edge.
## Wider UI pixels use integer-aligned stair steps. Internal texture padding
## grows with each step, but the UI Control rect and content margins do not.
## The 3px L-tier uses 14px top and bottom slices: exactly a 28px title bar.
static func corner_cutoffs(tier: StringName, pixel_unit := 1) -> PackedInt32Array:
	var unit := clampi(pixel_unit, 1, 3)
	match tier:
		TIER_L:
			match unit:
				2:
					return PackedInt32Array([8, 8, 4, 4, 2, 2, 0])
				3:
					return PackedInt32Array([6, 6, 6, 3, 3, 3, 0])
			return PackedInt32Array([7, 4, 2, 1, 1, 0])
		TIER_M:
			match unit:
				2:
					return PackedInt32Array([4, 4, 2, 2, 0])
				3:
					return PackedInt32Array([3, 3, 3, 0])
			return PackedInt32Array([4, 2, 1, 0])
		TIER_S:
			match unit:
				2:
					return PackedInt32Array([4, 4, 2, 2, 0])
				3:
					return PackedInt32Array([3, 3, 3, 0])
			return PackedInt32Array([3, 1, 0])
		_:
			return PackedInt32Array()
