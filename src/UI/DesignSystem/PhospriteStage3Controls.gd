class_name PhospriteStage3Controls
extends RefCounted

## Stage 3 is a view over existing Pencil/Eraser ValueSliders.
## Never change stored brush values, tool-unit conventions, or undo semantics.
const TOKENS := preload("res://src/UI/DesignSystem/PhospriteTokens.gd")

const CAPSULE_WIDTH := 48.0
const TRACK_WIDTH := 14.0
const TRACK_HEIGHT := 106.0
const HUD_GAP := 16.0
const HUD_DISMISS_SECONDS := 0.18
const TEAR_OFF_DISTANCE := 24.0
const FINE_FRACTION := 0.55
const FINE_UPPER_SIZE := 16.0


## Normalized finger position -> source brush pixels. Keep 1..16 in
## the first 55% of the track; the remaining 45% eases toward the actual
## tool maximum. A larger image brush range is never silently truncated.
static func size_from_position(position: float, minimum: float, maximum: float) -> float:
	if maximum <= minimum:
		return minimum
	var t := clampf(position, 0.0, 1.0)
	if maximum <= FINE_UPPER_SIZE or minimum >= FINE_UPPER_SIZE:
		return roundf(lerpf(minimum, maximum, t))
	var split_value := clampf(FINE_UPPER_SIZE, minimum, maximum)
	if t <= FINE_FRACTION:
		return roundf(lerpf(minimum, split_value, t / FINE_FRACTION))
	var tail := (t - FINE_FRACTION) / (1.0 - FINE_FRACTION)
	return roundf(lerpf(split_value, maximum, tail * tail))


## Exact inverse for externally edited tool sizes. Used only for display;
## source Range continues to be authoritative.
static func position_from_size(value: float, minimum: float, maximum: float) -> float:
	if maximum <= minimum:
		return 0.0
	var current := clampf(value, minimum, maximum)
	if maximum <= FINE_UPPER_SIZE or minimum >= FINE_UPPER_SIZE:
		return (current - minimum) / (maximum - minimum)
	var split_value := clampf(FINE_UPPER_SIZE, minimum, maximum)
	if current <= split_value:
		return FINE_FRACTION * (current - minimum) / (split_value - minimum)
	return (
		FINE_FRACTION
		+ (1.0 - FINE_FRACTION) * sqrt((current - split_value) / (maximum - split_value))
	)


## Do not apply pixel-size mapping to percentage-based/image brushes, or to
## Tools that permit sub-pixel values. Those retain their native Range mapping.
static func supports_pixel_size_mapping(
	minimum: float, maximum: float, step: float, suffix: String
) -> bool:
	return suffix == "px" and minimum <= 1.0 and maximum >= 16.0 and step >= 1.0


static func popup_position(
	origin: Vector2, delta: Vector2, popup_size: Vector2, screen: Vector2
) -> Vector2:
	var available := Vector2(maxf(0.0, screen.x - popup_size.x), maxf(0.0, screen.y - popup_size.y))
	var target := origin + delta
	return Vector2(clampf(target.x, 0.0, available.x), clampf(target.y, 0.0, available.y))


static func should_pin_popup(delta: Vector2) -> bool:
	return delta.length() >= TEAR_OFF_DISTANCE
