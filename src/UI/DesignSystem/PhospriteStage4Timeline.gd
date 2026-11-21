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
				tex_rect.modulate = Color.WHITE
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
			tex_rect.set_meta(Q_ACTIVE_META, true)
			tex_rect.texture = q_tex
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			tex_rect.modulate = Color(1.0, 1.0, 1.0, 0.5 if button.disabled else 1.0)
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
		tex_rect.remove_meta(Q_ACTIVE_META)
