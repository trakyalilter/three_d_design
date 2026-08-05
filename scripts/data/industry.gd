extends Node
## The supply side of the business, autoloaded as `Industry`.
##
## Furnishing rooms out of shop stock is the whole game up to here. This is what
## sits behind it: land you buy and work for raw materials, works that turn
## those into finished goods, and a bench where the goods go into the furniture
## you already own to make it worth more.
##
## Nothing here runs on a clock. Sites yield every time a job is handed over,
## which keeps the whole thing inside the loop the game already has and means a
## player who puts the game down does not come back to a queue.

## The four things that come out of the ground.
const MATERIALS: Array[Dictionary] = [
	{
		"id": "timber", "name": "Timber", "unit": "logs",
		"color": Color(0.55, 0.38, 0.24),
	},
	{
		"id": "cotton", "name": "Cotton", "unit": "bales",
		"color": Color(0.92, 0.90, 0.86),
	},
	{
		"id": "iron", "name": "Iron Ore", "unit": "loads",
		"color": Color(0.52, 0.54, 0.58),
	},
	{
		"id": "sand", "name": "Silica Sand", "unit": "loads",
		"color": Color(0.86, 0.78, 0.56),
	},
]

## The four things the works make out of them. `grain` is which of these a
## piece of furniture wants, decided by what the piece is actually built from.
const GOODS: Array[Dictionary] = [
	{
		"id": "board", "name": "Hardwood Board",
		"from": "timber", "takes": 3,
		"color": Color(0.62, 0.44, 0.28),
	},
	{
		"id": "cloth", "name": "Bolt of Cloth",
		"from": "cotton", "takes": 3,
		"color": Color(0.84, 0.72, 0.70),
	},
	{
		"id": "fitting", "name": "Steel Fitting",
		"from": "iron", "takes": 3,
		"color": Color(0.72, 0.75, 0.80),
	},
	{
		"id": "pane", "name": "Glass Pane",
		"from": "sand", "takes": 3,
		"color": Color(0.66, 0.82, 0.86),
	},
]

## Which good a piece wants, by what it is mostly made of. A piece is scored
## across its parts and takes the good that wins.
const GRAIN_BY_ROLE := {
	"wood": "board", "wood_dark": "board", "wood_light": "board",
	"steel": "fitting", "metal": "fitting", "mirror": "fitting",
	"white": "cloth", "towel": "cloth", "leaf": "cloth", "soil": "cloth",
	"glass": "pane", "porcelain": "pane", "screen": "pane", "dark": "pane",
}

## Ground you can buy and work. Eight holdings on a grid, two to a material, so
## there is always a second one to buy when the first is not keeping up.
const SITES: Array[Dictionary] = [
	{
		"id": "elm_stand", "name": "Elm Stand", "yields": "timber",
		"terrain": "forest", "at": Vector2(-24, -16),
		"cost": 2400, "level": 3, "per_job": 4,
		"blurb": "Mixed hardwood on a slope, cut on rotation.",
	},
	{
		"id": "black_pines", "name": "The Black Pines", "yields": "timber",
		"terrain": "forest", "at": Vector2(-24, 16),
		"cost": 9500, "level": 12, "per_job": 7,
		"blurb": "Older, straighter and a longer haul to the road.",
	},
	{
		"id": "low_meadow", "name": "Low Meadow", "yields": "cotton",
		"terrain": "field", "at": Vector2(-8, -16),
		"cost": 2800, "level": 4, "per_job": 4,
		"blurb": "Flat and well watered. Two pickings a season.",
	},
	{
		"id": "long_acre", "name": "Long Acre", "yields": "cotton",
		"terrain": "field", "at": Vector2(-8, 16),
		"cost": 11000, "level": 14, "per_job": 7,
		"blurb": "The big field. It takes a crew, and it pays for one.",
	},
	{
		"id": "old_adit", "name": "The Old Adit", "yields": "iron",
		"terrain": "hill", "at": Vector2(8, -16),
		"cost": 3600, "level": 6, "per_job": 3,
		"blurb": "A shallow working somebody else gave up on.",
	},
	{
		"id": "deep_seam", "name": "The Deep Seam", "yields": "iron",
		"terrain": "hill", "at": Vector2(8, 16),
		"cost": 14000, "level": 17, "per_job": 6,
		"blurb": "Good ore, a long way down, and a pump to run.",
	},
	{
		"id": "white_dune", "name": "White Dune", "yields": "sand",
		"terrain": "dune", "at": Vector2(24, -16),
		"cost": 3200, "level": 8, "per_job": 4,
		"blurb": "Clean silica, dug and screened on site.",
	},
	{
		"id": "glass_flats", "name": "The Glass Flats", "yields": "sand",
		"terrain": "dune", "at": Vector2(24, 16),
		"cost": 13000, "level": 20, "per_job": 7,
		"blurb": "Miles of it, and a conveyor to the loading bay.",
	},
]

## The works. Each one turns its material into its good, and the plant's tier
## is how many it can put through in a batch.
const WORKS: Array[Dictionary] = [
	{
		"id": "sawmill", "name": "The Sawmill", "makes": "board",
		"at": Vector2(-18, -12), "cost": 5200, "level": 5,
		"blurb": "Log in one end, board out the other.",
	},
	{
		"id": "weaving_shed", "name": "The Weaving Shed", "makes": "cloth",
		"at": Vector2(6, -12), "cost": 6000, "level": 7,
		"blurb": "Looms in a long room with the light down one side.",
	},
	{
		"id": "foundry", "name": "The Foundry", "makes": "fitting",
		"at": Vector2(-18, 14), "cost": 8500, "level": 10,
		"blurb": "Ore in, castings out, and the chimney going all day.",
	},
	{
		"id": "glasshouse", "name": "The Glasshouse", "makes": "pane",
		"at": Vector2(6, 14), "cost": 9800, "level": 13,
		"blurb": "Sand, heat, and a very steady hand.",
	},
]

## The bench where goods go into furniture. It stands on the works ground and
## costs nothing — the goods are the price.
const BENCH := {
	"id": "bench", "name": "The Finishing Bench",
	"at": Vector2(-6, 1), "level": 5,
	"blurb": "Where a piece off the shop floor becomes something better.",
}

## What each tier of improvement asks for, and what it is worth. The goods are
## the real cost; the money is what the bench charges to fit them.
const TIERS: Array[Dictionary] = [
	{"goods": 2, "price_share": 0.25, "name": "Improved"},
	{"goods": 4, "price_share": 0.50, "name": "Fine"},
	{"goods": 7, "price_share": 1.00, "name": "Master"},
]

## What one tier adds to the fee and the experience of a job, per tier, spread
## across everything standing in the room. A room of nothing but Master work
## pays eighteen per cent over the asking fee.
const TIER_BONUS := 0.06

const MAX_TIER := 3

var _materials_by_id: Dictionary = {}
var _goods_by_id: Dictionary = {}
var _sites_by_id: Dictionary = {}
var _works_by_id: Dictionary = {}
## item id -> the good it wants, worked out once from its part list.
var _grain: Dictionary = {}


func _ready() -> void:
	for material in MATERIALS:
		_materials_by_id[material["id"]] = material
	for good in GOODS:
		_goods_by_id[good["id"]] = good
	for site in SITES:
		_sites_by_id[site["id"]] = site
	for works in WORKS:
		_works_by_id[works["id"]] = works


# ------------------------------------------------------------------- lookups

func materials() -> Array[Dictionary]:
	return MATERIALS


func goods() -> Array[Dictionary]:
	return GOODS


func sites() -> Array[Dictionary]:
	return SITES


func works() -> Array[Dictionary]:
	return WORKS


func get_material(id: String) -> Dictionary:
	return _materials_by_id.get(id, {})


func get_good(id: String) -> Dictionary:
	return _goods_by_id.get(id, {})


func get_site(id: String) -> Dictionary:
	return _sites_by_id.get(id, {})


func get_works(id: String) -> Dictionary:
	return _works_by_id.get(id, {})


func material_name(id: String) -> String:
	return str(_materials_by_id.get(id, {}).get("name", id))


func good_name(id: String) -> String:
	return str(_goods_by_id.get(id, {}).get("name", id))


## The works that makes a given good.
func works_for(good_id: String) -> Dictionary:
	for entry in WORKS:
		if str(entry["makes"]) == good_id:
			return entry
	return {}


# ------------------------------------------------------------------ the grain

## Which good a piece of furniture wants, from what it is built of. Worked out
## by area rather than by count, so a sofa with four small wooden feet still
## counts as upholstery.
func grain_of(item_id: String) -> String:
	if _grain.has(item_id):
		return _grain[item_id]

	var def: Dictionary = Catalog.get_item(item_id)
	var weight: Dictionary = {}
	for part: Variant in def.get("parts", []):
		var role := str((part as Dictionary).get("mat", "white"))
		# A tinted part is the piece's own upholstery or paint, which is cloth
		# on a sofa and board on a table — so it follows whatever else is there
		# rather than voting on its own.
		if role == "tint":
			continue
		var good: String = GRAIN_BY_ROLE.get(role, "board")
		var size: Vector3 = (part as Dictionary)["size"]
		var area: float = absf(size.x * size.y) + absf(size.y * size.z) + absf(size.x * size.z)
		weight[good] = float(weight.get(good, 0.0)) + area

	var best := "board"
	var most := -1.0
	for good: String in weight:
		if float(weight[good]) > most:
			most = weight[good]
			best = good
	_grain[item_id] = best
	return best


# ----------------------------------------------------------------- the prices

## What the next tier of improvement costs for a piece: how many goods, of
## which kind, and what the bench charges to fit them.
func upgrade_cost(item_id: String) -> Dictionary:
	var tier := Game.quality_of(item_id)
	if tier >= MAX_TIER:
		return {}
	var step: Dictionary = TIERS[tier]
	return {
		"tier": tier + 1,
		"name": str(step["name"]),
		"good": grain_of(item_id),
		"goods": int(step["goods"]),
		"money": int(round(float(Catalog.price(item_id)) * float(step["price_share"]) / 5.0)) * 5,
	}


## What a tier is called, for a label.
func tier_name(tier: int) -> String:
	if tier <= 0:
		return "Plain"
	return str(TIERS[mini(tier, TIERS.size()) - 1]["name"])


## What a room full of these pieces adds to the fee and the experience. Passed
## the tier of every piece standing in the room.
static func quality_bonus(tiers: Array) -> float:
	if tiers.is_empty():
		return 0.0
	var total := 0.0
	for tier: int in tiers:
		total += float(tier)
	return TIER_BONUS * total / float(tiers.size())
