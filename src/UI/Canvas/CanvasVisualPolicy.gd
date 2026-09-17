class_name CanvasVisualPolicy
extends RefCounted

## Visual constants and theme-derived colors shared by the Canvas presentation layer.
## Gameplay, document pixels, and editor input must never depend on this policy.

const DOCUMENT_CHECKER_SIZE := 1.0
const PIXEL_GRID_ALPHA_FACTOR := 0.55
const BORDER_MIX := 0.38


static func resolve_surface_color(source_theme: Theme, fallback := Color("2b2b2b")) -> Color:
	if source_theme != null:
		for theme_type in [&"PanelContainer", &"Panel"]:
			if source_theme.has_stylebox(&"panel", theme_type):
				var style := source_theme.get_stylebox(&"panel", theme_type)
				if style is StyleBoxFlat:
					return Color((style as StyleBoxFlat).bg_color, 1.0)
	return Color(fallback, 1.0)


static func resolve_text_color(source_theme: Theme, surface: Color) -> Color:
	if source_theme != null and source_theme.has_color(&"font_color", &"Label"):
		return Color(source_theme.get_color(&"font_color", &"Label"), 1.0)
	return Color.WHITE if surface.get_luminance() < 0.5 else Color.BLACK


static func resolve_backdrop_color(source_theme: Theme, fallback := Color("2b2b2b")) -> Color:
	var surface := resolve_surface_color(source_theme, fallback)
	var depth := 0.16 if surface.get_luminance() < 0.5 else 0.08
	return Color(surface.lerp(Color.BLACK, depth), 1.0)


static func resolve_boundary_color(source_theme: Theme, fallback := Color("2b2b2b")) -> Color:
	var surface := resolve_surface_color(source_theme, fallback)
	var text := resolve_text_color(source_theme, surface)
	var boundary := surface.lerp(text, BORDER_MIX)
	boundary.a = 0.9
	return boundary
