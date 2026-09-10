extends "res://tests/test_base.gd"

## P0-C palette model tests.
##
## `Palette` is a plain RefCounted with no UI or Global dependency, which makes
## it the cheapest place to defend the .pxo palette payload contract: the JSON
## shape written by `serialize()` and consumed by `deserialize()`.

const SAMPLE_W := 4
const SAMPLE_H = 2


## Builds a palette with a known sparse colour layout for round-trip checks.
func _make_palette() -> Palette:
	var palette := Palette.new("RoundTrip", SAMPLE_W, SAMPLE_H, "comment text")
	palette.add_color(Color(1, 0, 0, 1), 0)
	palette.add_color(Color(0, 1, 0, 1), 3)
	palette.add_color(Color(0, 0, 1, 0.5), 5)
	return palette


func test_serialize_shape_is_stable() -> void:
	var palette := _make_palette()
	var data: Dictionary = JSON.parse_string(palette.serialize())
	check_true(data != null, "palette serialize() must produce valid JSON")
	for key: String in ["comment", "colors", "width", "height"]:
		check_true(data.has(key), "serialized palette must keep the '%s' key" % key)
	check_eq(data["width"], SAMPLE_W, "palette width must round-trip")
	check_eq(data["height"], SAMPLE_H, "palette height must round-trip")
	check_eq(data["comment"], "comment text", "palette comment must round-trip")


func test_serialize_does_not_embed_empty_slot_placeholder() -> void:
	# Empty slots are expressed as missing dictionary keys. Writing a string
	# placeholder here would silently change the upstream .pxo palette format.
	var palette := _make_palette()
	var json := palette.serialize()
	check_true(
		not json.contains("PixeloramaEmptySlot"),
		"palette JSON must express empty slots as absent keys, not placeholders"
	)


func test_round_trip_preserves_colors() -> void:
	var original := _make_palette()
	var restored := Palette.new()
	restored.deserialize(original.serialize())

	check_eq(restored.width, original.width, "width must survive round-trip")
	check_eq(restored.height, original.height, "height must survive round-trip")
	check_eq(restored.comment, original.comment, "comment must survive round-trip")
	check_eq(restored.colors.size(), original.colors.size(), "colour count must survive round-trip")

	for index: int in original.colors:
		check_true(restored.colors.has(index), "colour index %d must survive round-trip" % index)
		if restored.colors.has(index):
			var expected: Color = original.colors[index].color
			var actual: Color = restored.colors[index].color
			check_true(
				actual.is_equal_approx(expected),
				"colour at index %d must survive round-trip" % index
			)


func test_round_trip_preserves_sparse_layout() -> void:
	var original := _make_palette()
	var restored := Palette.new()
	restored.deserialize(original.serialize())

	# Index 1 was never assigned and must stay absent, not become a black slot.
	check_true(
		not restored.colors.has(1), "unassigned palette slots must stay absent after round-trip"
	)
	check_true(restored.colors.has(0), "assigned slot 0 must survive round-trip")
	check_true(restored.colors.has(5), "assigned slot 5 must survive round-trip")


func test_add_and_remove_color_updates_sparse_map() -> void:
	var palette := Palette.new("Ops", 4, 2)
	palette.add_color(Color.RED, 2)
	check_true(palette.colors.has(2), "add_color must register the slot")

	palette.remove_color(2)
	check_true(not palette.colors.has(2), "remove_color must clear the slot")
