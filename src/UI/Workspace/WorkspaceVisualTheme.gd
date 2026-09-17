class_name WorkspaceVisualTheme
extends RefCounted

## Semantic visual palette and style resources for Workspace chrome.
##
## The palette is derived from Pixelorama's active Theme plus the current
## base/accent/contrast preferences. Workspace code consumes semantic states
## instead of hard-coded application colors.

signal changed

const HEADER_HEIGHT := 28.0
const CONTENT_PADDING := 6.0
const BORDER_WIDTH := 1
const FLOATING_BORDER_WIDTH := 2
const CORNER_RADIUS := 4

var surface_color := Color("2b2b2b")
var elevated_color := Color("323232")
var header_color := Color("353535")
var border_color := Color("555555")
var accent_color := Color("8aa0df")
var text_color := Color.WHITE
var muted_text_color := Color("b0b0b0")
var preview_color := Color(1.0, 1.0, 1.0, 0.18)
var shadow_color := Color(0.0, 0.0, 0.0, 0.28)

var default_font: Font = ThemeDB.fallback_font
var default_font_size := ThemeDB.fallback_font_size

var _module_styles: Dictionary = {}
var _header_styles: Dictionary = {}


func refresh(source_theme: Theme, base: Color, accent: Color, contrast := 0.3) -> bool:
	if source_theme == null:
		return false

	var resolved_surface := _resolve_surface_color(source_theme, base)
	var resolved_text := _resolve_text_color(source_theme, resolved_surface)
	var resolved_accent := _resolve_accent_color(source_theme, accent)
	var direction := Color.WHITE if resolved_surface.get_luminance() < 0.5 else Color.BLACK
	var contrast_amount := clampf(0.06 + contrast * 0.12, 0.04, 0.22)

	surface_color = resolved_surface
	elevated_color = resolved_surface.lerp(direction, contrast_amount * 0.55)
	header_color = resolved_surface.lerp(direction, contrast_amount)
	border_color = resolved_surface.lerp(resolved_text, clampf(0.18 + contrast * 0.22, 0.18, 0.42))
	accent_color = resolved_accent
	text_color = resolved_text
	muted_text_color = resolved_text.lerp(resolved_surface, 0.38)
	preview_color = Color(resolved_accent, 0.22)
	shadow_color = Color(0.0, 0.0, 0.0, 0.32 if resolved_surface.get_luminance() < 0.5 else 0.18)
	default_font = (
		source_theme.default_font if source_theme.default_font != null else ThemeDB.fallback_font
	)
	default_font_size = (
		source_theme.default_font_size
		if source_theme.default_font_size > 0
		else ThemeDB.fallback_font_size
	)

	_rebuild_styles()
	changed.emit()
	return true


func get_module_style(state: StringName) -> StyleBoxFlat:
	var style := _module_styles.get(state) as StyleBoxFlat
	if style == null:
		style = _module_styles.get(&"docked") as StyleBoxFlat
	return style


func get_header_style(state: StringName) -> StyleBoxFlat:
	var style := _header_styles.get(state) as StyleBoxFlat
	if style == null:
		style = _header_styles.get(&"docked") as StyleBoxFlat
	return style


func _rebuild_styles() -> void:
	_module_styles.clear()
	_header_styles.clear()

	_module_styles[&"none"] = _make_module_style(surface_color, border_color, BORDER_WIDTH)
	_module_styles[&"docked"] = _make_module_style(surface_color, border_color, BORDER_WIDTH)
	_module_styles[&"floating"] = _make_module_style(
		elevated_color, accent_color.lerp(border_color, 0.25), FLOATING_BORDER_WIDTH
	)
	_module_styles[&"peek"] = _make_module_style(
		elevated_color, accent_color, FLOATING_BORDER_WIDTH
	)
	_module_styles[&"collapsed"] = _make_module_style(header_color, border_color, BORDER_WIDTH)

	_header_styles[&"none"] = _make_header_style(header_color)
	_header_styles[&"docked"] = _make_header_style(header_color)
	_header_styles[&"floating"] = _make_header_style(header_color.lerp(accent_color, 0.12))
	_header_styles[&"peek"] = _make_header_style(header_color.lerp(accent_color, 0.2))
	_header_styles[&"collapsed"] = _make_header_style(header_color)


func _make_module_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
	style.shadow_color = shadow_color
	style.shadow_size = 3 if width == FLOATING_BORDER_WIDTH else 0
	return style


func _make_header_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.content_margin_left = CONTENT_PADDING
	style.content_margin_right = CONTENT_PADDING
	return style


func _resolve_surface_color(source_theme: Theme, fallback: Color) -> Color:
	for theme_type in [&"PanelContainer", &"Panel"]:
		if source_theme.has_stylebox(&"panel", theme_type):
			var style := source_theme.get_stylebox(&"panel", theme_type)
			if style is StyleBoxFlat:
				return Color((style as StyleBoxFlat).bg_color, 1.0)
	if fallback.a > 0.0:
		return Color(fallback, 1.0)
	return surface_color


func _resolve_text_color(source_theme: Theme, fallback_surface: Color) -> Color:
	if source_theme.has_color(&"font_color", &"Label"):
		return source_theme.get_color(&"font_color", &"Label")
	return Color.WHITE if fallback_surface.get_luminance() < 0.5 else Color.BLACK


func _resolve_accent_color(source_theme: Theme, fallback: Color) -> Color:
	if fallback.a > 0.0:
		return Color(fallback, 1.0)
	if source_theme.has_stylebox(&"pressed", &"Button"):
		var style := source_theme.get_stylebox(&"pressed", &"Button")
		if style is StyleBoxFlat:
			return Color((style as StyleBoxFlat).border_color, 1.0)
	return accent_color