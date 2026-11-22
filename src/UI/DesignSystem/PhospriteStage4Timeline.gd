class_name PhospriteStage4Timeline
extends RefCounted

## Paints timeline controls and swaps in Q-version pixel icons; owns no state.
const Tokens := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")
const Stage4 := preload("res://src/UI/DesignSystem/PhospriteStage4Chrome.gd")
const QIcons := preload("res://src/UI/DesignSystem/PhospriteQIcons.gd")

const LEGACY_TEX_META := &"phosprite_legacy_timeline_tex"
const LEGACY_MOD_META := &"phosprite_legacy_timeline_mod"
const LEGACY_FLT_META := &"phosprite_legacy_timeline_flt"
const LEGACY_EXP_META := &"phosprite_legacy_timeline_exp"
const LEGACY_STR_META := &"phosprite_legacy_timeline_str"
const Q_ACTIVE_META := &"phosprite_q_icon_active"

const BUTTON_ICON_MAP := {
	"AddLayer": &"new_item",
	"RemoveLayer": &"remove_item",
	"MoveUpLayer": &"move_up",
	"MoveDownLayer": &"move_down",
	"CloneLayer": &"copy_item",
	"MergeDownLayer": &"merge_down",
	"LayerFX": &"effects",
	"KeyframeTimelineButton": &"more_tools",
	"AddFrame": &"new_item",
	"DeleteFrame": &"remove_item",
	"CopyFrame": &"copy_item",
	"MoveFrameLeft": &"prev_frame",
	"MoveFrameRight": &"next_frame",
	"FirstFrame": &"step_first",
	"PreviousFrame": &"prev_frame",
	"PlayBackwards": &"play_backwards",
	"PlayForward": &"play",
	"NextFrame": &"next_frame",
	"LastFrame": &"step_last",
	"OnionSkinning": &"onion_skin",
}

static var _clean_layer_icons: Dictionary = {}
static var _flat_empty_style := StyleBoxEmpty.new()
static var _flat_hover_styles: Dictionary = {}


static func apply(timeline: Control) -> void:
	if not is_instance_valid(timeline) or not timeline.is_node_ready():
		return
	var mode := Stage4.active_mode()
	Stage4.style_panel(timeline, mode)
	for panel_name in ["LayerTools", "AnimationTools"]:
		var panel := timeline.find_child(panel_name, true, false) as Control
		Stage4.style_panel(panel, Tokens.LEGACY)
	for group_name in ["LayerButtons", "AnimationButtons"]:
		var group := timeline.find_child(group_name, true, false)
		if group == null:
			continue
		for child in group.find_children("*", "Button", true, false):
			var button := child as Button
			if button.name == &"AddLayerList":
				_style_add_layer_dropdown(button, mode)
				continue
			Stage4.style_button(button, mode)
			_apply_button_q_icon(button, mode)
	var blend_modes := timeline.find_child("BlendModes", true, false) as OptionButton
	Stage4.style_option(blend_modes, mode)
	var global_defaults := {
		"GlobalVisibilityButton": &"eye_open",
		"GlobalLockButton": &"lock_open",
		"GlobalExpandButton": &"group_expanded",
	}
	for gname in global_defaults:
		var gbtn := timeline.find_child(gname, true, false) as BaseButton
		if gbtn != null:
			style_flat_layer_button(gbtn, mode)
			if (
				mode != Tokens.LEGACY
				and gbtn.get_child_count() > 0
				and gbtn.get_child(0) is TextureRect
			):
				apply_layer_icon(gbtn.get_child(0) as TextureRect, global_defaults[gname], mode)


static func _style_add_layer_dropdown(button: Button, mode: StringName) -> void:
	var tex_rect := button.get_node_or_null(^"TextureRect") as TextureRect
	if mode != Tokens.LEGACY:
		Stage4.restore_button(button)
		button.flat = true
		if tex_rect != null:
			if not tex_rect.has_meta(LEGACY_TEX_META):
				tex_rect.set_meta(LEGACY_TEX_META, tex_rect.texture)
				tex_rect.set_meta(LEGACY_MOD_META, tex_rect.modulate)
				tex_rect.set_meta(LEGACY_FLT_META, tex_rect.texture_filter)
				tex_rect.set_meta(LEGACY_EXP_META, tex_rect.expand_mode)
				tex_rect.set_meta(LEGACY_STR_META, tex_rect.stretch_mode)
			var chev := QIcons.compact_icon_1x(&"chevron_down")
			if chev != null:
				tex_rect.set_meta(Q_ACTIVE_META, true)
				tex_rect.texture = chev
				tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
				tex_rect.modulate = Stage4.icon_tint_for_button(mode, button)
				tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		button.flat = false
		_restore_tex_rect(tex_rect)


static func _apply_button_q_icon(button: Button, mode: StringName) -> void:
	if not is_instance_valid(button):
		return
	var icon_id: StringName = BUTTON_ICON_MAP.get(String(button.name), &"")
	if icon_id == &"":
		return
	var tex_rect := button.get_node_or_null(^"TextureRect") as TextureRect
	if tex_rect == null:
		return
	if mode != Tokens.LEGACY:
		if not tex_rect.has_meta(LEGACY_TEX_META):
			tex_rect.set_meta(LEGACY_TEX_META, tex_rect.texture)
			tex_rect.set_meta(LEGACY_MOD_META, tex_rect.modulate)
			tex_rect.set_meta(LEGACY_FLT_META, tex_rect.texture_filter)
			tex_rect.set_meta(LEGACY_EXP_META, tex_rect.expand_mode)
			tex_rect.set_meta(LEGACY_STR_META, tex_rect.stretch_mode)
		var q_tex := QIcons.standard_icon_1x(icon_id)
		if q_tex != null:
			if not tex_rect.has_meta(&"phosprite_legacy_timeline_offsets"):
				(
					tex_rect
					. set_meta(
						&"phosprite_legacy_timeline_offsets",
						[
							tex_rect.offset_left,
							tex_rect.offset_top,
							tex_rect.offset_right,
							tex_rect.offset_bottom,
						],
					)
				)
			tex_rect.set_meta(Q_ACTIVE_META, true)
			tex_rect.texture = q_tex
			tex_rect.offset_left = -10.0
			tex_rect.offset_top = -10.0
			tex_rect.offset_right = 10.0
			tex_rect.offset_bottom = 10.0
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			tex_rect.modulate = Stage4.icon_tint_for_button(mode, button)
			tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		_restore_tex_rect(tex_rect)


static func _restore_tex_rect(tex_rect: TextureRect) -> void:
	if tex_rect != null and tex_rect.has_meta(LEGACY_TEX_META):
		tex_rect.texture = tex_rect.get_meta(LEGACY_TEX_META) as Texture2D
		tex_rect.modulate = tex_rect.get_meta(LEGACY_MOD_META) as Color
		tex_rect.texture_filter = int(tex_rect.get_meta(LEGACY_FLT_META))
		tex_rect.expand_mode = int(tex_rect.get_meta(LEGACY_EXP_META))
		tex_rect.stretch_mode = int(tex_rect.get_meta(LEGACY_STR_META))
		tex_rect.remove_meta(LEGACY_TEX_META)
		tex_rect.remove_meta(LEGACY_MOD_META)
		tex_rect.remove_meta(LEGACY_FLT_META)
		tex_rect.remove_meta(LEGACY_EXP_META)
		tex_rect.remove_meta(LEGACY_STR_META)
		if tex_rect.has_meta(&"phosprite_legacy_timeline_offsets"):
			var offs: Array = tex_rect.get_meta(&"phosprite_legacy_timeline_offsets")
			if offs.size() == 4:
				tex_rect.offset_left = float(offs[0])
				tex_rect.offset_top = float(offs[1])
				tex_rect.offset_right = float(offs[2])
				tex_rect.offset_bottom = float(offs[3])
			tex_rect.remove_meta(&"phosprite_legacy_timeline_offsets")
		tex_rect.remove_meta(Q_ACTIVE_META)


static func _make_crisp_layer_icon(kind: StringName, mode: StringName) -> ImageTexture:
	var key := "%s|%s" % [kind, mode]
	if _clean_layer_icons.has(key):
		return _clean_layer_icons[key] as ImageTexture
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var ink := Tokens.color(mode, &"text_primary")
	var muted := Tokens.color(mode, &"text_muted")
	var accent := Tokens.color(mode, &"accent_primary")
	var lilac := Tokens.color(mode, &"accent_soft")
	var gold := Color("#F2B84B") if mode == Tokens.SUNNY else Color("#FFD166")

	var pattern: Array[String] = []
	var palette := {"#": ink, "m": muted, "a": accent, "l": lilac, "g": gold, "w": Color.WHITE}
	match kind:
		&"eye_open":
			pattern = [
				"................",
				"................",
				"................",
				".....######.....",
				"...##llllll##...",
				"..#ll##aa##ll#..",
				".#ll#awwwwa#ll#.",
				".#l#a#a##a#a#l#.",
				".#l#a#a##a#a#l#.",
				".#ll#a#aa#a#ll#.",
				"..#ll##aa##ll#..",
				"...##llllll##...",
				".....######.....",
				"................",
				"................",
				"................",
			]
		&"eye_closed":
			pattern = [
				"................",
				"................",
				"................",
				"................",
				"................",
				"..m..........m..",
				"...mm......mm...",
				"....mmmmmmmm....",
				".....m.mm.m.....",
				"....m..mm..m....",
				"................",
				"................",
				"................",
				"................",
				"................",
				"................",
			]
		&"lock_closed":
			pattern = [
				"................",
				".....######.....",
				"....#......#....",
				"....#......#....",
				"....#......#....",
				"...##########...",
				"...#gggggggg#...",
				"...#gg####gg#...",
				"...#gg####gg#...",
				"...#ggg##ggg#...",
				"...#ggg##ggg#...",
				"...#gggggggg#...",
				"...##########...",
				"................",
				"................",
				"................",
			]
		&"lock_open":
			pattern = [
				"................",
				".......#####....",
				"......m.....m...",
				"......m.....m...",
				"......m.........",
				"...mmmmmmmmmm...",
				"...m........m...",
				"...m...mm...m...",
				"...m...mm...m...",
				"...m...mm...m...",
				"...m........m...",
				"...mmmmmmmmmm...",
				"................",
				"................",
				"................",
				"................",
			]
		&"cel_linked":
			pattern = [
				"................",
				"................",
				"................",
				"................",
				"..#####..#####..",
				".#aaaaa##aaaaa#.",
				".#a...####...a#.",
				".#a..######..a#.",
				".#a...####...a#.",
				".#aaaaa##aaaaa#.",
				"..#####..#####..",
				"................",
				"................",
				"................",
				"................",
				"................",
			]
		&"cel_unlinked":
			pattern = [
				"................",
				"................",
				"................",
				"................",
				"..mmmm....mmmm..",
				".m....m..m....m.",
				".m............m.",
				".m....m..m....m.",
				".m............m.",
				".m....m..m....m.",
				"..mmmm....mmmm..",
				"................",
				"................",
				"................",
				"................",
				"................",
			]
		&"group_expanded":
			pattern = [
				"................",
				"................",
				"..#####.........",
				".#lllll#........",
				".#lllll#######..",
				".#llllllllllll#.",
				".#llllllllllll#.",
				".#ll########ll#.",
				".#ll#llllll#ll#.",
				".#ll#llllll#ll#.",
				".#ll########ll#.",
				"..############..",
				"................",
				"................",
				"................",
				"................",
			]
		&"group_collapsed":
			pattern = [
				"................",
				"................",
				"..mmmmm.........",
				".m.....m........",
				".m.....mmmmmmm..",
				".m............m.",
				".m............m.",
				".m............m.",
				".m............m.",
				".m............m.",
				".m............m.",
				"..mmmmmmmmmmmm..",
				"................",
				"................",
				"................",
				"................",
			]
	for y in range(mini(16, pattern.size())):
		var row: String = pattern[y]
		for x in range(mini(16, row.length())):
			var ch := row[x]
			if palette.has(ch):
				img.set_pixel(x, y, palette[ch])
	var tex := ImageTexture.create_from_image(img)
	_clean_layer_icons[key] = tex
	return tex


static func style_flat_layer_button(button: BaseButton, mode: StringName) -> void:
	if not is_instance_valid(button):
		return
	if mode == Tokens.LEGACY:
		Stage4.restore_button(button as Button)
		return
	var btn := button as Button
	if btn == null:
		return
	var hover := _flat_hover_styles.get(mode) as StyleBoxFlat
	if hover == null:
		hover = StyleBoxFlat.new()
		hover.bg_color = Color(Tokens.color(mode, &"accent_soft"), 0.55)
		hover.corner_radius_top_left = 4
		hover.corner_radius_top_right = 4
		hover.corner_radius_bottom_right = 4
		hover.corner_radius_bottom_left = 4
		hover.anti_aliasing = false
		_flat_hover_styles[mode] = hover
	if not btn.flat:
		btn.flat = true
	if btn.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for st in [&"normal", &"disabled", &"focus"]:
		if (
			not btn.has_theme_stylebox_override(st)
			or btn.get_theme_stylebox(st) != _flat_empty_style
		):
			btn.add_theme_stylebox_override(st, _flat_empty_style)
	for st in [&"hover", &"pressed", &"hover_pressed"]:
		if not btn.has_theme_stylebox_override(st) or btn.get_theme_stylebox(st) != hover:
			btn.add_theme_stylebox_override(st, hover)


static func apply_layer_icon(tex_rect: TextureRect, kind: StringName, mode: StringName) -> void:
	if not is_instance_valid(tex_rect) or mode == Tokens.LEGACY:
		return
	var tex := _make_crisp_layer_icon(kind, mode)
	if tex != null:
		tex_rect.set_meta(Q_ACTIVE_META, true)
		tex_rect.set_meta(&"phosprite_precolored_icon", true)
		tex_rect.texture = tex
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		tex_rect.modulate = Color.WHITE
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func sync_global_layer_buttons(
	btns: Array[Button], flags: Array[bool], mode: StringName
) -> void:
	for btn in btns:
		style_flat_layer_button(btn, mode)
	apply_layer_icon(
		btns[0].get_child(0) as TextureRect, &"eye_open" if flags[0] else &"eye_closed", mode
	)
	apply_layer_icon(
		btns[1].get_child(0) as TextureRect, &"lock_closed" if flags[1] else &"lock_open", mode
	)
	apply_layer_icon(
		btns[2].get_child(0) as TextureRect,
		&"group_expanded" if flags[2] else &"group_collapsed",
		mode
	)


static func set_playback_button_icon(
	button: Button, q_icon_id: StringName, legacy_png: String
) -> void:
	if not is_instance_valid(button) or button.get_child_count() == 0:
		return
	var tex_rect := button.get_child(0) as TextureRect
	if tex_rect == null:
		return
	var mode := Stage4.active_mode()
	if mode != Tokens.LEGACY:
		var q_tex := QIcons.standard_icon_1x(q_icon_id)
		if q_tex != null:
			tex_rect.set_meta(Q_ACTIVE_META, true)
			tex_rect.texture = q_tex
			tex_rect.offset_left = -10.0
			tex_rect.offset_top = -10.0
			tex_rect.offset_right = 10.0
			tex_rect.offset_bottom = 10.0
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			tex_rect.modulate = Stage4.icon_tint_for_button(mode, button)
			tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			return
	Global.change_button_texturerect(tex_rect, legacy_png)
