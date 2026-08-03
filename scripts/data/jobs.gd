extends Node
## The contracts on the city map.
##
## Each entry is one house: where it stands, what it looks like from the
## street, the room the player works in, and the brief they have to satisfy.
## Autoloaded as `Jobs`.
##
## Requirement kinds, all checked against a context the designer builds:
##   {"type": "item",        "id": "sofa", "count": 1}
##   {"type": "category",    "category": "Decor", "count": 2}
##   {"type": "total",       "count": 8}
##   {"type": "categories",  "count": 4}     distinct shops represented
##   {"type": "floor_color", "names": ["Concrete", "Slate"]}
##   {"type": "wall_color",  "names": ["Sage"]}
##   {"type": "no_overlap"}
## Any requirement may carry a "label" to override the generated wording.

## Paid on top of the fee when the final bill lands inside the client's budget.
const ON_BUDGET_BONUS := 0.25

const HOUSES: Array[Dictionary] = [
	{
		"id": "maple_studio",
		"short": "Maple Row",
		"name": "Maple Row Studio",
		"client": "Derya",
		"level": 1,
		"brief": "It is my first place and it is tiny. A bed I can actually sleep in, somewhere to put a lamp, and please make it feel like somebody lives here.",
		"room": {"w": 4.0, "d": 3.5, "h": 2.6},
		"budget": 950,
		"payout": 1300,
		"xp": 90,
		"map": {"pos": Vector2(-34, -27), "rot": 0.0},
		"style": {"body": Color(0.86, 0.80, 0.68), "roof": Color(0.52, 0.30, 0.26), "size": Vector3(5.5, 3.0, 5.5)},
		"requirements": [
			{"type": "item", "id": "bed_single", "count": 1},
			{"type": "item", "id": "nightstand", "count": 1},
			{"type": "total", "count": 5},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "harbour_lounge",
		"short": "Harbour Lounge",
		"name": "Harbour View Lounge",
		"client": "Kerem",
		"level": 1,
		"brief": "I host a lot. I want a proper sofa facing the window, a low table for coffee, and some greenery so the place is not just furniture.",
		"room": {"w": 5.5, "d": 4.5, "h": 2.7},
		"budget": 1300,
		"payout": 1750,
		"xp": 110,
		"map": {"pos": Vector2(-22, -27), "rot": 0.0},
		"style": {"body": Color(0.74, 0.80, 0.84), "roof": Color(0.30, 0.36, 0.44), "size": Vector3(6.5, 3.2, 6.0)},
		"requirements": [
			{"type": "item", "id": "sofa", "count": 1},
			{"type": "item", "id": "coffee_table", "count": 1},
			{"type": "category", "category": "Decor", "count": 2},
			{"type": "total", "count": 6},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "willow_reading",
		"short": "Willow Room",
		"name": "Willow Reading Room",
		"client": "Nil",
		"level": 1,
		"brief": "Books, a chair I can disappear into, and light to read by. Something calm on the walls — sage or linen, nothing loud.",
		"room": {"w": 4.5, "d": 4.0, "h": 2.6},
		"budget": 1350,
		"payout": 1850,
		"xp": 120,
		"map": {"pos": Vector2(-10, -27), "rot": 0.0},
		"style": {"body": Color(0.80, 0.84, 0.74), "roof": Color(0.42, 0.36, 0.28), "size": Vector3(6.0, 3.0, 5.5)},
		"requirements": [
			{"type": "item", "id": "bookshelf", "count": 2},
			{"type": "item", "id": "armchair", "count": 1},
			{"type": "item", "id": "floor_lamp", "count": 1},
			{"type": "wall_color", "names": ["Sage", "Linen"]},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "orchard_kitchen",
		"short": "Orchard Kitchen",
		"name": "Orchard Family Kitchen",
		"client": "Emre",
		"level": 2,
		"brief": "Four of us, one kitchen. Counters to work on, somewhere to wash up, and a fridge that fits a week's shopping. Hard floor, please.",
		"room": {"w": 5.0, "d": 4.0, "h": 2.7},
		"budget": 2300,
		"payout": 3200,
		"xp": 170,
		"map": {"pos": Vector2(10, -27), "rot": 0.0},
		"style": {"body": Color(0.88, 0.72, 0.55), "roof": Color(0.58, 0.28, 0.24), "size": Vector3(6.5, 3.2, 6.0)},
		"requirements": [
			{"type": "item", "id": "counter", "count": 2},
			{"type": "item", "id": "fridge", "count": 1},
			{"type": "item", "id": "sink_unit", "count": 1},
			{"type": "floor_color", "names": ["Concrete", "Chalk", "Slate"]},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "cedar_bathroom",
		"short": "Cedar Bathroom",
		"name": "Cedar Guest Bathroom",
		"client": "Zeynep",
		"level": 2,
		"brief": "Guests only, so it has to look sharp and work perfectly. Toilet, basin, a shower — and somewhere to hang a towel that is not the door.",
		"room": {"w": 3.5, "d": 3.0, "h": 2.5},
		"budget": 1550,
		"payout": 2150,
		"xp": 160,
		"map": {"pos": Vector2(22, -27), "rot": 0.0},
		"style": {"body": Color(0.78, 0.86, 0.90), "roof": Color(0.26, 0.44, 0.54), "size": Vector3(5.0, 3.0, 5.0)},
		"requirements": [
			{"type": "item", "id": "toilet", "count": 1},
			{"type": "item", "id": "basin", "count": 1},
			{"type": "item", "id": "shower", "count": 1},
			{"type": "item", "id": "towel_rail", "count": 1},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "rosewood_master",
		"short": "Rosewood Bedroom",
		"name": "Rosewood Master Bedroom",
		"client": "Selin",
		"level": 3,
		"brief": "The room I wake up in should not look like storage. A double bed, a wardrobe that swallows everything, a table on each side, and somewhere for the rest.",
		"room": {"w": 5.5, "d": 4.5, "h": 2.7},
		"budget": 2700,
		"payout": 3700,
		"xp": 210,
		"map": {"pos": Vector2(34, -27), "rot": 0.0},
		"style": {"body": Color(0.82, 0.70, 0.72), "roof": Color(0.44, 0.26, 0.32), "size": Vector3(6.5, 3.4, 6.0)},
		"requirements": [
			{"type": "item", "id": "bed_double", "count": 1},
			{"type": "item", "id": "wardrobe", "count": 1},
			{"type": "item", "id": "nightstand", "count": 2},
			{"type": "item", "id": "dresser", "count": 1},
			{"type": "total", "count": 8},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "pine_loft",
		"short": "Pine Loft",
		"name": "Pine Street Loft",
		"client": "Baran",
		"level": 3,
		"brief": "One big open room: sofa and television at one end, a table that seats four at the other. Make the two halves feel deliberate, not accidental.",
		"room": {"w": 7.0, "d": 5.5, "h": 2.9},
		"budget": 3700,
		"payout": 5100,
		"xp": 280,
		"map": {"pos": Vector2(-34, 27), "rot": 180.0},
		"style": {"body": Color(0.70, 0.66, 0.62), "roof": Color(0.28, 0.28, 0.32), "size": Vector3(7.5, 4.2, 6.5)},
		"requirements": [
			{"type": "item", "id": "sofa", "count": 1},
			{"type": "item", "id": "television", "count": 1},
			{"type": "item", "id": "dining_table", "count": 1},
			{"type": "item", "id": "chair", "count": 4},
			{"type": "categories", "count": 4},
			{"type": "total", "count": 14},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "ivy_suite",
		"short": "Ivy Suite",
		"name": "Ivy House Bathroom Suite",
		"client": "Melis",
		"level": 4,
		"brief": "The whole suite, done properly. A tub I can lie down in, the laundry hidden in here too, and a mirror I can actually get ready in front of.",
		"room": {"w": 4.5, "d": 3.5, "h": 2.6},
		"budget": 2750,
		"payout": 3800,
		"xp": 260,
		"map": {"pos": Vector2(-22, 27), "rot": 180.0},
		"style": {"body": Color(0.72, 0.82, 0.76), "roof": Color(0.24, 0.40, 0.34), "size": Vector3(5.5, 3.2, 5.5)},
		"requirements": [
			{"type": "item", "id": "bathtub", "count": 1},
			{"type": "item", "id": "toilet", "count": 1},
			{"type": "item", "id": "vanity_unit", "count": 1},
			{"type": "item", "id": "washing_machine", "count": 1},
			{"type": "item", "id": "towel_rail", "count": 2},
			{"type": "floor_color", "names": ["Chalk", "Concrete", "Sandstone"]},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "grand_avenue",
		"short": "Grand Avenue",
		"name": "Grand Avenue Apartment",
		"client": "Okan",
		"level": 4,
		"brief": "An entire flat in one room — sleeping, sitting, cooking, washing. I have seen it done well. Do not make it feel like a warehouse.",
		"room": {"w": 8.0, "d": 6.0, "h": 3.0},
		"budget": 5200,
		"payout": 7200,
		"xp": 360,
		"map": {"pos": Vector2(-10, 27), "rot": 180.0},
		"style": {"body": Color(0.64, 0.68, 0.76), "roof": Color(0.22, 0.26, 0.34), "size": Vector3(8.0, 5.4, 6.5)},
		"requirements": [
			{"type": "item", "id": "bed_double", "count": 1},
			{"type": "item", "id": "sofa", "count": 1},
			{"type": "item", "id": "fridge", "count": 1},
			{"type": "item", "id": "toilet", "count": 1},
			{"type": "categories", "count": 5},
			{"type": "total", "count": 18},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "corner_townhouse",
		"short": "Corner Townhouse",
		"name": "The Corner Townhouse",
		"client": "Ayla",
		"level": 5,
		"brief": "The showpiece. I want every room in the city represented in this one floor, and I want it to look like one person made every decision.",
		"room": {"w": 9.0, "d": 7.0, "h": 3.0},
		"budget": 7200,
		"payout": 10500,
		"xp": 500,
		"map": {"pos": Vector2(10, 27), "rot": 180.0},
		"style": {"body": Color(0.90, 0.86, 0.76), "roof": Color(0.48, 0.22, 0.20), "size": Vector3(8.5, 6.0, 7.0)},
		"requirements": [
			{"type": "categories", "count": 6},
			{"type": "total", "count": 24},
			{"type": "item", "id": "bathtub", "count": 1},
			{"type": "item", "id": "stove", "count": 1},
			{"type": "item", "id": "bed_double", "count": 1},
			{"type": "wall_color", "names": ["Harbour", "Storm", "Ink", "Blush"]},
			{"type": "no_overlap"},
		],
	},
]

var _by_id: Dictionary = {}


func _ready() -> void:
	for house in HOUSES:
		_by_id[house["id"]] = house


func all() -> Array[Dictionary]:
	return HOUSES


func get_job(house_id: String) -> Dictionary:
	return _by_id.get(house_id, {})


func bonus_for(house_id: String) -> int:
	var job := get_job(house_id)
	if job.is_empty():
		return 0
	return int(round(float(job["payout"]) * ON_BUDGET_BONUS))


## An estimate of what the required pieces alone will cost, shown in the brief
## so the player can judge whether they can afford to take the job on.
func minimum_outlay(house_id: String) -> int:
	var job := get_job(house_id)
	if job.is_empty():
		return 0
	var total := 0
	for req: Dictionary in job["requirements"]:
		if req.get("type", "") == "item":
			total += Catalog.price(req["id"]) * int(req.get("count", 1))
	return total


# ---------------------------------------------------------------- reporting

## Checks a brief against the room the player has built.
##
## `context` carries: items (an array of {id, tint, blocked}), room
## ({w, d, h, floor, wall}) and spend.
## Returns one dictionary per requirement: {label, met, have, need}.
func evaluate(house_id: String, context: Dictionary) -> Array[Dictionary]:
	var job := get_job(house_id)
	var out: Array[Dictionary] = []
	if job.is_empty():
		return out
	for req: Dictionary in job["requirements"]:
		out.append(_check(req, context))
	return out


static func all_met(results: Array[Dictionary]) -> bool:
	for result in results:
		if not result["met"]:
			return false
	return true


static func met_count(results: Array[Dictionary]) -> int:
	var count := 0
	for result in results:
		if result["met"]:
			count += 1
	return count


func _check(req: Dictionary, context: Dictionary) -> Dictionary:
	var items: Array = context.get("items", [])
	var room: Dictionary = context.get("room", {})
	var kind: String = str(req.get("type", ""))
	var need: int = int(req.get("count", 1))
	var have := 0
	var met := false
	var label := ""

	match kind:
		"item":
			var wanted: String = str(req["id"])
			for entry: Dictionary in items:
				if entry["id"] == wanted:
					have += 1
			met = have >= need
			label = "Fit a %s" % Catalog.display_name(wanted) if need == 1 \
				else "Fit %d × %s" % [need, Catalog.display_name(wanted)]

		"category":
			var category: String = str(req["category"])
			for entry: Dictionary in items:
				if Catalog.category_of(entry["id"]) == category:
					have += 1
			met = have >= need
			label = "Add %d %s piece%s" % [need, category, "" if need == 1 else "s"]

		"total":
			have = items.size()
			met = have >= need
			label = "Furnish with at least %d pieces" % need

		"categories":
			var seen := {}
			for entry: Dictionary in items:
				seen[Catalog.category_of(entry["id"])] = true
			have = seen.size()
			met = have >= need
			label = "Buy from at least %d different shops" % need

		"floor_color", "wall_color":
			var surface := "floor" if kind == "floor_color" else "wall"
			var names: Array = req.get("names", [])
			var current: Color = room.get(surface, Color.WHITE)
			met = _color_in(current, surface, names)
			have = 1 if met else 0
			need = 1
			label = "%s the %s: %s" % [
				"Lay" if surface == "floor" else "Paint",
				surface,
				" or ".join(PackedStringArray(names)),
			]

		"no_overlap":
			var clashes := 0
			for entry: Dictionary in items:
				if entry.get("blocked", false):
					clashes += 1
			met = clashes == 0
			have = 1 if met else 0
			need = 1
			label = "Leave nothing overlapping" if met \
				else "Leave nothing overlapping (%d clash%s)" % [clashes, "" if clashes == 1 else "es"]

		_:
			met = true
			label = "—"

	return {
		"label": str(req.get("label", label)),
		"met": met,
		"have": have,
		"need": need,
		"type": kind,
	}


## True when `color` matches one of the named paints from the Colour House.
static func _color_in(color: Color, surface: String, names: Array) -> bool:
	var palette: Array = Catalog.PAINT.get(surface, [])
	for entry: Dictionary in palette:
		if not names.has(entry["name"]):
			continue
		var target: Color = entry["color"]
		var distance := Vector3(
			color.r - target.r, color.g - target.g, color.b - target.b
		).length()
		if distance < 0.06:
			return true
	return false
