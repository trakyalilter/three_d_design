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

## Most that can be paid on top of the fee, earned by a three-star room.
## See RoomReview for what the client is actually judging.
const MAX_BONUS := 0.30

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

# ------------------------------------------------------- generated contracts

## Rooms a returning client might ask for. `core` is what the room is really
## about; the generator picks two or three of them plus some filler.
const THEMES: Array[Dictionary] = [
	{
		"name": "living room", "level": 1,
		"core": ["sofa", "loveseat", "armchair", "coffee_table", "tv_stand"],
		"filler": "Decor",
		"brief": "The room we actually live in. Somewhere to sit, somewhere to put a cup down, and it should not echo.",
	},
	{
		"name": "bedroom", "level": 1,
		"core": ["bed_single", "bed_double", "nightstand", "wardrobe", "dresser"],
		"filler": "Decor",
		"brief": "A room to sleep in and nothing else. Somewhere for the clothes, a lamp within reach, and no clutter.",
	},
	{
		"name": "study", "level": 1,
		"core": ["desk", "bookshelf", "chair", "cabinet", "armchair"],
		"filler": "Decor",
		"brief": "I work from home now. Somewhere to put the books, somewhere to sit that is not the bed.",
	},
	{
		"name": "dining room", "level": 1,
		"core": ["dining_table", "round_table", "chair", "cabinet"],
		"filler": "Decor",
		"brief": "We eat together every night and the current arrangement is not helping.",
	},
	{
		"name": "kitchen", "level": 2,
		"core": ["counter", "fridge", "sink_unit", "stove"],
		"filler": "Decor",
		"brief": "It has to work before it looks good. Counters, cold storage, somewhere to wash up.",
	},
	{
		"name": "media room", "level": 2,
		"core": ["television", "tv_large", "sofa", "speaker_tower", "soundbar", "tv_stand"],
		"filler": "Decor",
		"brief": "One room for films and nothing else. A screen worth watching, something to sit on, and sound that fills it.",
	},
	{
		"name": "home office", "level": 2,
		"core": ["desk", "computer", "printer", "bookshelf", "cabinet"],
		"filler": "Decor",
		"brief": "I am on calls all day. Somewhere to work properly, and somewhere to file the things that pile up.",
	},
	{
		"name": "bathroom", "level": 2,
		"core": ["toilet", "basin", "shower", "bathtub", "vanity_unit", "towel_rail"],
		"filler": "Bathroom",
		"brief": "Everything a bathroom needs, fitted properly, with somewhere to put a towel.",
	},
]

const CLIENTS: Array[String] = [
	"Deniz", "Cem", "Ece", "Mert", "Sude", "Arda", "Bahar", "Kaan", "İpek",
	"Tolga", "Yasemin", "Berk", "Elif", "Sinan", "Pelin", "Umut",
]

var _by_id: Dictionary = {}


func _ready() -> void:
	for house in HOUSES:
		_by_id[house["id"]] = house


func all() -> Array[Dictionary]:
	return HOUSES


## The brief currently attached to a house: the generated one if the player
## took a repeat contract there, otherwise the handcrafted original.
func get_job(house_id: String) -> Dictionary:
	var base: Dictionary = _by_id.get(house_id, {})
	if base.is_empty():
		return {}
	var contract: Dictionary = Game.active_contracts.get(house_id, {})
	if contract.is_empty():
		return base
	# The house itself never changes — only what is being asked for inside it.
	var merged := base.duplicate(true)
	for key: String in contract:
		merged[key] = contract[key]
	return merged


func has_repeat_contract(house_id: String) -> bool:
	return Game.active_contracts.has(house_id)


## Invents a fresh brief for a house that has already been handed over. Only
## JSON-safe values go in, because this is saved with the profile.
func generate_contract(house_id: String, level: int) -> Dictionary:
	var base: Dictionary = _by_id.get(house_id, {})
	if base.is_empty():
		return {}

	var random := RandomNumberGenerator.new()
	random.seed = hash("%s/%d/%d" % [house_id, level, Game.repeat_count(house_id)])

	# Pick a theme the player has the shops for.
	var choices: Array[Dictionary] = []
	for theme: Dictionary in THEMES:
		if level >= int(theme["level"]):
			choices.append(theme)
	var theme: Dictionary = choices[random.randi() % choices.size()]

	# Two or three of the theme's core pieces, whichever the player can buy.
	var available: Array[String] = []
	for id: String in theme["core"]:
		if level >= Catalog.effective_unlock_level(id):
			available.append(id)
	available.shuffle()
	var wanted: int = clampi(2 + level / 3, 2, mini(4, available.size()))

	var requirements: Array = []
	var outlay := 0
	for i in mini(wanted, available.size()):
		var id: String = available[i]
		var count: int = 1
		if id == "chair":
			count = 2 + random.randi() % 3
		elif id == "counter" or id == "nightstand":
			count = 1 + random.randi() % 2
		requirements.append({"type": "item", "id": id, "count": count})
		outlay += Catalog.price(id) * count

	var room: Dictionary = base["room"]
	var total: int = clampi(int(float(room["w"]) * float(room["d"]) / 2.4), 5, 22)
	requirements.append({"type": "total", "count": total})
	requirements.append({"type": "no_overlap"})
	# Filler to reach the piece count, priced in so the budget is fair.
	var filler_price := _cheapest_price_in(str(theme["filler"]))
	outlay += maxi(total - requirements.size(), 0) * filler_price

	var budget: int = int(round(float(outlay) * 1.30 / 50.0)) * 50
	var payout: int = int(round(float(budget) * 1.55 / 50.0)) * 50
	var repeats := Game.repeat_count(house_id)

	return {
		"client": CLIENTS[random.randi() % CLIENTS.size()],
		"level": maxi(int(base["level"]), 1),
		"brief": str(theme["brief"]),
		"theme": str(theme["name"]),
		"budget": budget,
		"payout": payout,
		"xp": 70 + level * 35,
		"requirements": requirements,
		"repeat": repeats + 1,
	}


func _cheapest_price_in(category: String) -> int:
	var best := 999999
	for id in Catalog.ids_in(category):
		best = mini(best, Catalog.price(id))
	return best if best < 999999 else 100


func max_bonus_for(house_id: String) -> int:
	var job := get_job(house_id)
	if job.is_empty():
		return 0
	return int(round(float(job["payout"]) * MAX_BONUS))


## An estimate of what the required pieces alone will cost, shown in the brief
## so the player can judge whether they can afford to take the job on.
func minimum_outlay(house_id: String) -> int:
	var total := 0
	for item_id: String in _needed_pieces(house_id):
		total += Catalog.price(item_id) * int(_needed_pieces(house_id)[item_id])
	return total


## Everything the brief calls for, as item id -> count, ignoring what the
## player already owns. Open-ended lines (a plain count of pieces, or a spread
## across shops) are filled with the cheapest thing that satisfies them.
func _needed_pieces(house_id: String) -> Dictionary:
	var job := get_job(house_id)
	if job.is_empty():
		return {}

	var wanted: Dictionary = {}
	var categories_used: Dictionary = {}

	for req: Dictionary in job["requirements"]:
		match str(req.get("type", "")):
			"item":
				var id: String = str(req["id"])
				wanted[id] = int(wanted.get(id, 0)) + int(req.get("count", 1))
				categories_used[Catalog.category_of(id)] = true
			"category":
				var category := str(req["category"])
				var have := _count_in_category(wanted, category)
				var pick := _cheapest_in(category)
				if pick != "":
					var missing: int = maxi(int(req.get("count", 1)) - have, 0)
					if missing > 0:
						wanted[pick] = int(wanted.get(pick, 0)) + missing
					categories_used[category] = true

	# "Buy from N different shops" — add a cheap piece from categories not yet
	# represented until enough of them are.
	for req: Dictionary in job["requirements"]:
		if str(req.get("type", "")) != "categories":
			continue
		for category in Catalog.CATEGORIES:
			if categories_used.size() >= int(req.get("count", 1)):
				break
			if categories_used.has(category):
				continue
			var pick := _cheapest_in(category)
			if pick != "":
				wanted[pick] = int(wanted.get(pick, 0)) + 1
				categories_used[category] = true

	# "Furnish with at least N pieces" — top up with the cheapest decor.
	for req: Dictionary in job["requirements"]:
		if str(req.get("type", "")) != "total":
			continue
		var placed := 0
		for count: int in wanted.values():
			placed += count
		var filler := _cheapest_in("Decor")
		if filler != "":
			var missing: int = maxi(int(req.get("count", 1)) - placed, 0)
			if missing > 0:
				wanted[filler] = int(wanted.get(filler, 0)) + missing

	return wanted


func _count_in_category(wanted: Dictionary, category: String) -> int:
	var total := 0
	for item_id: String in wanted:
		if Catalog.category_of(item_id) == category:
			total += int(wanted[item_id])
	return total


## The cheapest thing in a category that stands on the floor. Tabletop props
## are skipped: a brief asking for another piece of furniture should not be
## satisfied by a stack of books left on the boards.
func _cheapest_in(category: String) -> String:
	var best := ""
	var best_price := 1 << 30
	for id in Catalog.ids_in(category):
		if Catalog.is_stackable(id):
			continue
		if Catalog.price(id) < best_price:
			best_price = Catalog.price(id)
			best = id
	return best


## What still has to be bought for a job: the brief's pieces, minus whatever is
## already standing in the room and whatever is sitting in the warehouse.
## Returns item id -> count.
func shopping_list(house_id: String, placed: Dictionary = {}) -> Dictionary:
	var missing: Dictionary = {}
	for item_id: String in _needed_pieces(house_id):
		var need := int(_needed_pieces(house_id)[item_id])
		var have := int(placed.get(item_id, 0)) + Game.stock_of(item_id)
		if need > have:
			missing[item_id] = need - have
	return missing


static func list_cost(list: Dictionary) -> int:
	var total := 0
	for item_id: String in list:
		total += Catalog.price(item_id) * int(list[item_id])
	return total


## Colours the brief asks for that the player does not own yet, as
## [{"surface": String, "entry": Dictionary}].
func missing_paints(house_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var job := get_job(house_id)
	if job.is_empty():
		return out
	for req: Dictionary in job["requirements"]:
		var kind := str(req.get("type", ""))
		if kind != "floor_color" and kind != "wall_color":
			continue
		var surface := "floor" if kind == "floor_color" else "wall"
		var satisfied := false
		var candidate: Dictionary = {}
		for entry: Dictionary in Catalog.PAINT[surface]:
			if not req["names"].has(entry["name"]):
				continue
			if Game.owns_paint(surface, str(entry["name"])):
				satisfied = true
				break
			if candidate.is_empty() and Game.is_paint_unlocked(entry):
				candidate = entry
		if not satisfied and not candidate.is_empty():
			out.append({"surface": surface, "entry": candidate})
	return out


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
			var piece := Catalog.display_name(wanted)
			label = "Fit %s %s" % [_article(piece), piece] if need == 1 \
				else "Fit %d × %s" % [need, piece]

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


static func _article(word: String) -> String:
	return "an" if word.length() > 0 and "AEIOUaeiou".contains(word[0]) else "a"


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
