class_name WorkspaceDockDragResolver
extends RefCounted

## Pure drag-target resolver for the limited P2-B four-zone layout.
##
## Callers provide zone rectangles and the currently rendered module rectangles.
## A pointer outside all four zones intentionally resolves to invalid instead of
## creating a floating panel; floating is P2-C scope.

const PREVIEW_GAP := 4.0


static func resolve(
	module_id: StringName,
	pointer: Vector2,
	zone_rects: Dictionary,
	module_rects: Dictionary,
	layout: WorkspaceDockLayout
) -> Dictionary:
	if layout == null or not layout.can_dock_module(module_id):
		return _invalid_result()

	var zone := _find_zone(pointer, zone_rects)
	if zone == WorkspaceDockLayout.DockZone.NONE:
		return _invalid_result()

	var entries := _filtered_entries(module_id, module_rects.get(zone, []))
	var insert_index := _find_insertion_index(pointer, zone, entries)
	var zone_rect: Rect2 = zone_rects.get(zone, Rect2())
	var module_size := layout.get_module_size(module_id)
	if layout.get_module_zone(module_id) == WorkspaceDockLayout.DockZone.NONE:
		module_size = layout.get_default_module_size(module_id)
	var preview_rect := _make_preview_rect(zone_rect, zone, entries, insert_index, module_size)

	return {
		"valid": true,
		"zone": zone,
		"index": insert_index,
		"preview_rect": preview_rect,
	}


static func _find_zone(pointer: Vector2, zone_rects: Dictionary) -> int:
	for zone in WorkspaceDockLayout.VALID_ZONES:
		if not zone_rects.has(zone):
			continue
		var rect: Rect2 = zone_rects[zone]
		if rect.has_point(pointer):
			return zone
	return WorkspaceDockLayout.DockZone.NONE


static func _filtered_entries(module_id: StringName, raw_entries: Variant) -> Array:
	var entries: Array = []
	if not raw_entries is Array:
		return entries
	for raw_entry: Variant in raw_entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		if StringName(entry.get("module_id", &"")) == module_id:
			continue
		if not entry.has("rect") or not entry["rect"] is Rect2:
			continue
		entries.append(entry)
	return entries


static func _find_insertion_index(pointer: Vector2, zone: int, entries: Array) -> int:
	var horizontal := (
		zone == WorkspaceDockLayout.DockZone.TOP or zone == WorkspaceDockLayout.DockZone.BOTTOM
	)
	var pointer_axis := pointer.x if horizontal else pointer.y
	for index in range(entries.size()):
		var rect: Rect2 = entries[index]["rect"]
		var midpoint := rect.get_center().x if horizontal else rect.get_center().y
		if pointer_axis < midpoint:
			return index
	return entries.size()


static func _make_preview_rect(
	zone_rect: Rect2, zone: int, entries: Array, insert_index: int, module_size: Vector2
) -> Rect2:
	if zone_rect.size.x <= 0.0 or zone_rect.size.y <= 0.0:
		return Rect2()

	var horizontal := (
		zone == WorkspaceDockLayout.DockZone.TOP or zone == WorkspaceDockLayout.DockZone.BOTTOM
	)
	if horizontal:
		var width := minf(maxf(module_size.x, 1.0), zone_rect.size.x)
		var x := zone_rect.position.x
		if not entries.is_empty():
			if insert_index <= 0:
				var first: Rect2 = entries[0]["rect"]
				x = first.position.x
			elif insert_index >= entries.size():
				var last: Rect2 = entries[entries.size() - 1]["rect"]
				x = last.end.x + PREVIEW_GAP
			else:
				var previous: Rect2 = entries[insert_index - 1]["rect"]
				x = previous.end.x + PREVIEW_GAP
		x = clampf(x, zone_rect.position.x, maxf(zone_rect.position.x, zone_rect.end.x - width))
		return Rect2(Vector2(x, zone_rect.position.y), Vector2(width, zone_rect.size.y))

	var height := minf(maxf(module_size.y, 1.0), zone_rect.size.y)
	var y := zone_rect.position.y
	if not entries.is_empty():
		if insert_index <= 0:
			var first: Rect2 = entries[0]["rect"]
			y = first.position.y
		elif insert_index >= entries.size():
			var last: Rect2 = entries[entries.size() - 1]["rect"]
			y = last.end.y + PREVIEW_GAP
		else:
			var previous: Rect2 = entries[insert_index - 1]["rect"]
			y = previous.end.y + PREVIEW_GAP
	y = clampf(y, zone_rect.position.y, maxf(zone_rect.position.y, zone_rect.end.y - height))
	return Rect2(Vector2(zone_rect.position.x, y), Vector2(zone_rect.size.x, height))


static func _invalid_result() -> Dictionary:
	return {
		"valid": false,
		"zone": WorkspaceDockLayout.DockZone.NONE,
		"index": -1,
		"preview_rect": Rect2(),
	}
