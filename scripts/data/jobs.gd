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

## The city is laid out as a grid of quarters, `SPACING` apart. Maple Quarter
## comes with the business; the rest are bought with money once the player has
## the level to work in them, and each one holds harder, better-paid houses.
## `origin` is where a quarter's centre sits in the world, and every house in it
## puts its `map.pos` relative to that.
const SPACING := 104.0

const DISTRICTS: Array[Dictionary] = [
	{
		"id": "maple",
		"name": "Maple Quarter",
		"origin": Vector2(0, 0),
		"cost": 0,
		"level": 1,
		"accent": Color(0.45, 0.72, 0.52),
		"tagline": "Where you started. Two streets of small homes and the shops that supply them.",
	},
	{
		"id": "riverside",
		"name": "Riverside Wharf",
		"origin": Vector2(SPACING, 0),
		"cost": 18000,
		"level": 7,
		"accent": Color(0.36, 0.62, 0.82),
		"tagline": "Old warehouses on the water, being turned into homes by people with taste and deadlines.",
	},
	{
		"id": "hillside",
		"name": "Hillside Terrace",
		"origin": Vector2(0, SPACING),
		"cost": 36000,
		"level": 11,
		"accent": Color(0.82, 0.60, 0.34),
		"tagline": "Family houses up the slope. Whole floors at a time, and clients who know what they want.",
	},
	{
		"id": "skyline",
		"name": "Skyline Heights",
		"origin": Vector2(SPACING, SPACING),
		"cost": 58000,
		"level": 15,
		"accent": Color(0.68, 0.48, 0.86),
		"tagline": "The towers. Every brief here is a showpiece, and the fees say so.",
	},
	{
		"id": "hanami",
		"name": "Hanami Ward",
		"origin": Vector2(-SPACING, 0),
		"cost": 68000,
		"level": 19,
		"accent": Color(0.90, 0.62, 0.70),
		"planting": "cherry",
		"ground": Color(0.38, 0.50, 0.34),
		"tagline": "Timber houses under the cherry trees. The rooms are meant to be mostly empty, and the clients will notice if they are not.",
	},
	{
		"id": "hollow",
		"name": "Hollow Row",
		"origin": Vector2(-SPACING, SPACING),
		"cost": 98000,
		"level": 24,
		"accent": Color(0.58, 0.40, 0.74),
		"planting": "bare",
		"ground": Color(0.26, 0.30, 0.25),
		"tagline": "The old row at the edge of the map, and the households that kept it. Deliveries after dark, and nobody asks what the cellar is for.",
	},
]

const HOUSES: Array[Dictionary] = [
	{
		"id": "maple_studio",
		"short": "Maple Row",
		"district": "maple",
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
		"district": "maple",
		"name": "Harbour View Lounge",
		"client": "Kerem",
		"level": 2,
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
		"district": "maple",
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
		"district": "maple",
		"name": "Orchard Family Kitchen",
		"client": "Emre",
		"level": 3,
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
		"district": "maple",
		"name": "Cedar Guest Bathroom",
		"client": "Zeynep",
		"level": 3,
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
		"district": "maple",
		"name": "Rosewood Master Bedroom",
		"client": "Selin",
		"level": 6,
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
			{"type": "item", "id": "blanket_box", "count": 1},
			{"type": "total", "count": 8},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "pine_loft",
		"short": "Pine Loft",
		"district": "maple",
		"name": "Pine Street Loft",
		"client": "Baran",
		"level": 5,
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
			{"type": "item", "id": "chaise", "count": 1},
			{"type": "categories", "count": 4},
			{"type": "total", "count": 14},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "ivy_suite",
		"short": "Ivy Suite",
		"district": "maple",
		"name": "Ivy House Bathroom Suite",
		"client": "Melis",
		"level": 5,
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
			{"type": "item", "id": "bath_screen", "count": 1},
			{"type": "floor_color", "names": ["Chalk", "Concrete", "Sandstone"]},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "grand_avenue",
		"short": "Grand Avenue",
		"district": "maple",
		"name": "Grand Avenue Apartment",
		"client": "Okan",
		"level": 5,
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
			{"type": "item", "id": "kitchen_trolley", "count": 1},
			{"type": "item", "id": "wall_art", "count": 2},
			{"type": "categories", "count": 5},
			{"type": "total", "count": 18},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "corner_townhouse",
		"short": "Corner Townhouse",
		"district": "maple",
		"name": "The Corner Townhouse",
		"client": "Ayla",
		"level": 6,
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
			{"type": "item", "id": "bed_king", "count": 1},
			{"type": "item", "id": "range_hood", "count": 1},
			{"type": "item", "id": "ladder_shelf", "count": 1},
			{"type": "wall_color", "names": ["Harbour", "Storm", "Ink", "Blush"]},
			{"type": "no_overlap"},
		],
	},

	# ------------------------------------------------------- Riverside Wharf
	{
		"id": "wharf_loft",
		"short": "Wharf Loft",
		"district": "riverside",
		"name": "Wharf Conversion Loft",
		"client": "Doruk",
		"level": 8,
		"brief": "It was a grain store and the ceiling proves it. I sleep, work and cook in one room, and I would like those to feel like three rooms without a single wall going up.",
		"room": {"w": 7.0, "d": 5.5, "h": 3.2},
		"budget": 4400,
		"payout": 6000,
		"xp": 300,
		"map": {"pos": Vector2(-22, -27), "rot": 0.0},
		"style": {"body": Color(0.72, 0.66, 0.58), "roof": Color(0.34, 0.32, 0.30), "size": Vector3(7.5, 4.6, 6.5)},
		"requirements": [
			{"type": "item", "id": "bed_double", "count": 1},
			{"type": "item", "id": "desk", "count": 1},
			{"type": "item", "id": "computer", "count": 1},
			{"type": "item", "id": "counter", "count": 1},
			{"type": "item", "id": "sail_screen", "count": 1, "label": "Split the room with a sail screen"},
			{"type": "item", "id": "crate_shelf", "count": 1},
			{"type": "categories", "count": 5},
			{"type": "total", "count": 14},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "dockside_kitchen",
		"short": "Dockside Kitchen",
		"district": "riverside",
		"name": "Dockside Kitchen",
		"client": "Ferda",
		"level": 8,
		"brief": "I cook for a living and I am tired of doing it in a corridor. An island I can work all the way round, a machine to do the washing up, and somewhere to put a month of dry goods.",
		"room": {"w": 6.5, "d": 5.0, "h": 2.9},
		"budget": 5900,
		"payout": 8100,
		"xp": 350,
		"map": {"pos": Vector2(22, -27), "rot": 0.0},
		"style": {"body": Color(0.84, 0.78, 0.64), "roof": Color(0.40, 0.34, 0.30), "size": Vector3(7.0, 3.8, 6.0)},
		"requirements": [
			{"type": "item", "id": "kitchen_island", "count": 1},
			{"type": "item", "id": "dishwasher", "count": 1},
			{"type": "item", "id": "pantry", "count": 1},
			{"type": "item", "id": "stove", "count": 1},
			{"type": "item", "id": "fridge", "count": 1},
			{"type": "item", "id": "counter", "count": 2},
			{"type": "item", "id": "workbench", "count": 1},
			{"type": "item", "id": "cask_stand", "count": 1},
			{"type": "item", "id": "galley_shelf", "count": 1},
			{"type": "floor_color", "names": ["Concrete", "Slate", "Chalk"]},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "netmaker_media",
		"short": "Netmaker's",
		"district": "riverside",
		"name": "The Netmaker's Screening Room",
		"client": "Tuna",
		"level": 10,
		"brief": "One room, one purpose: films. The biggest screen you can get in here, sound from both sides, and somewhere I will not want to get up from. Keep the walls dark.",
		"room": {"w": 7.0, "d": 5.5, "h": 3.0},
		"budget": 5200,
		"payout": 7200,
		"xp": 400,
		"map": {"pos": Vector2(-22, 27), "rot": 180.0},
		"style": {"body": Color(0.56, 0.60, 0.66), "roof": Color(0.24, 0.26, 0.32), "size": Vector3(7.0, 4.2, 6.5)},
		"requirements": [
			{"type": "item", "id": "tv_large", "count": 1},
			{"type": "item", "id": "speaker_tower", "count": 2},
			{"type": "item", "id": "soundbar", "count": 1},
			{"type": "item", "id": "sofa", "count": 1},
			{"type": "item", "id": "recliner", "count": 2},
			{"type": "item", "id": "rope_light", "count": 2},
			{"type": "item", "id": "lantern", "count": 2},
			{"type": "wall_color", "names": ["Ink", "Storm", "Harbour"]},
			{"type": "total", "count": 12},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "harbourmaster_office",
		"short": "Harbourmaster",
		"district": "riverside",
		"name": "The Harbourmaster's Office",
		"client": "Işıl",
		"level": 9,
		"brief": "I run two businesses off this desk and both of them generate paper. Somewhere to work, somewhere to file, and a cabinet good enough to keep the ship models in.",
		"room": {"w": 6.0, "d": 5.0, "h": 2.9},
		"budget": 4400,
		"payout": 6100,
		"xp": 380,
		"map": {"pos": Vector2(22, 27), "rot": 180.0},
		"style": {"body": Color(0.68, 0.74, 0.78), "roof": Color(0.28, 0.34, 0.40), "size": Vector3(6.5, 4.0, 6.0)},
		"requirements": [
			{"type": "item", "id": "desk", "count": 1},
			{"type": "item", "id": "computer", "count": 1},
			{"type": "item", "id": "printer", "count": 1},
			{"type": "item", "id": "bookshelf", "count": 2},
			{"type": "item", "id": "display_cabinet", "count": 1},
			{"type": "item", "id": "porthole_mirror", "count": 1},
			{"type": "item", "id": "steamer_trunk", "count": 1},
			{"type": "item", "id": "signal_flags", "count": 1},
			{"type": "item", "id": "filing_cabinet", "count": 2},
			{"type": "item", "id": "chair", "count": 1},
			{"type": "categories", "count": 4},
			{"type": "total", "count": 12},
			{"type": "no_overlap"},
		],
	},

	# ------------------------------------------------------ Hillside Terrace
	{
		"id": "terrace_family",
		"short": "Terrace Family",
		"district": "hillside",
		"name": "Terrace Family Room",
		"client": "Gökçe",
		"level": 12,
		"brief": "Five of us and one television. Everybody needs their own seat, the little ones need the floor kept clear, and it has to survive a Sunday.",
		"room": {"w": 7.5, "d": 5.5, "h": 2.9},
		"budget": 5400,
		"payout": 7400,
		"xp": 420,
		"map": {"pos": Vector2(-22, -27), "rot": 0.0},
		"style": {"body": Color(0.88, 0.78, 0.62), "roof": Color(0.50, 0.30, 0.24), "size": Vector3(7.5, 4.0, 6.5)},
		"requirements": [
			{"type": "item", "id": "sofa", "count": 1},
			{"type": "item", "id": "loveseat", "count": 1},
			{"type": "item", "id": "armchair", "count": 2},
			{"type": "item", "id": "television", "count": 1},
			{"type": "item", "id": "tv_stand", "count": 1},
			{"type": "item", "id": "rug", "count": 1},
			{"type": "item", "id": "ottoman", "count": 1},
			{"type": "item", "id": "rocking_chair", "count": 1},
			{"type": "item", "id": "play_mat", "count": 1},
			{"type": "item", "id": "fireside_set", "count": 1},
			{"type": "categories", "count": 5},
			{"type": "total", "count": 16},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "crest_nursery",
		"short": "Crest Nursery",
		"district": "hillside",
		"name": "Crest Road Nursery",
		"client": "Neslihan",
		"level": 11,
		"brief": "One baby, one four-year-old, and a room they will grow through. A cot now, bunks for later, and somewhere the washing can live that is not the landing.",
		"room": {"w": 5.5, "d": 4.5, "h": 2.7},
		"budget": 4200,
		"payout": 5800,
		"xp": 400,
		"map": {"pos": Vector2(22, -27), "rot": 0.0},
		"style": {"body": Color(0.90, 0.84, 0.86), "roof": Color(0.46, 0.32, 0.42), "size": Vector3(6.0, 3.6, 5.5)},
		"requirements": [
			{"type": "item", "id": "crib", "count": 1},
			{"type": "item", "id": "bunk_bed", "count": 1},
			{"type": "item", "id": "dressing_table", "count": 1},
			{"type": "item", "id": "laundry_basket", "count": 1},
			{"type": "item", "id": "shoe_rack", "count": 1},
			{"type": "item", "id": "high_chair", "count": 1},
			{"type": "item", "id": "toy_chest", "count": 1},
			{"type": "item", "id": "rocking_horse", "count": 1},
			{"type": "item", "id": "bookcase_low", "count": 1},
			{"type": "wall_color", "names": ["Blush", "Sage", "Linen"]},
			{"type": "total", "count": 11},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "slope_suite",
		"short": "Slope Suite",
		"district": "hillside",
		"name": "Slope House Master Suite",
		"client": "Bora",
		"level": 13,
		"brief": "The whole top floor is ours and I want it to feel like a hotel we would go back to. Bed, dressing, storage — and a mirror I can see all of myself in.",
		"room": {"w": 7.0, "d": 5.5, "h": 3.0},
		"budget": 6200,
		"payout": 8600,
		"xp": 470,
		"map": {"pos": Vector2(-22, 27), "rot": 180.0},
		"style": {"body": Color(0.80, 0.72, 0.76), "roof": Color(0.38, 0.24, 0.32), "size": Vector3(7.5, 4.4, 6.5)},
		"requirements": [
			{"type": "item", "id": "bed_double", "count": 1},
			{"type": "item", "id": "wardrobe", "count": 2},
			{"type": "item", "id": "dressing_table", "count": 1},
			{"type": "item", "id": "floor_mirror", "count": 1},
			{"type": "item", "id": "nightstand", "count": 2},
			{"type": "item", "id": "window_seat", "count": 1},
			{"type": "item", "id": "fern_stand", "count": 2},
			{"type": "categories", "count": 4},
			{"type": "total", "count": 15},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "ridge_diner",
		"short": "Ridge Diner",
		"district": "hillside",
		"name": "Ridge Kitchen & Diner",
		"client": "Alper",
		"level": 13,
		"brief": "Knock the wall through and it is one room, so the cooking end has to look as good as the eating end. Eight of us at Sunday lunch, and I refuse to hide the kitchen.",
		"room": {"w": 8.0, "d": 6.0, "h": 3.0},
		"budget": 7000,
		"payout": 9700,
		"xp": 520,
		"map": {"pos": Vector2(22, 27), "rot": 180.0},
		"style": {"body": Color(0.86, 0.82, 0.72), "roof": Color(0.44, 0.36, 0.28), "size": Vector3(8.0, 4.6, 7.0)},
		"requirements": [
			{"type": "item", "id": "kitchen_island", "count": 1},
			{"type": "item", "id": "dining_table", "count": 1},
			{"type": "item", "id": "chair", "count": 6},
			{"type": "item", "id": "stove", "count": 1},
			{"type": "item", "id": "sink_unit", "count": 1},
			{"type": "item", "id": "sideboard", "count": 1},
			{"type": "item", "id": "herb_rack", "count": 1},
			{"type": "item", "id": "bench_long", "count": 2},
			{"type": "item", "id": "range_hood", "count": 1},
			{"type": "categories", "count": 5},
			{"type": "total", "count": 20},
			{"type": "no_overlap"},
		],
	},

	# ------------------------------------------------------- Skyline Heights
	{
		"id": "atrium_gallery",
		"short": "Atrium Gallery",
		"district": "skyline",
		"name": "The Atrium Gallery Floor",
		"client": "Reyhan",
		"level": 15,
		"brief": "I collect, and the collection has outgrown the shelves. Cabinets with glass in them, light in the right places, and enough floor left that people can stand back and look.",
		"room": {"w": 8.0, "d": 6.0, "h": 3.2},
		"budget": 10800,
		"payout": 14800,
		"xp": 540,
		"map": {"pos": Vector2(-22, -27), "rot": 0.0},
		"style": {"body": Color(0.78, 0.76, 0.82), "roof": Color(0.30, 0.28, 0.40), "size": Vector3(8.0, 6.4, 7.0)},
		"requirements": [
			{"type": "item", "id": "display_cabinet", "count": 3},
			{"type": "item", "id": "bookshelf", "count": 2},
			{"type": "item", "id": "floor_lamp", "count": 2},
			{"type": "item", "id": "vase", "count": 2},
			{"type": "item", "id": "wing_chair", "count": 2},
			{"type": "item", "id": "sculpture_plinth", "count": 2},
			{"type": "item", "id": "glass_case", "count": 2},
			{"type": "item", "id": "art_easel", "count": 2},
			{"type": "item", "id": "pedestal_vase", "count": 1},
			{"type": "item", "id": "pendant_cluster", "count": 1},
			{"type": "item", "id": "arc_lamp", "count": 1},
			{"type": "categories", "count": 5},
			{"type": "total", "count": 18},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "tower_spa",
		"short": "Tower Spa",
		"district": "skyline",
		"name": "Tower Spa Bathroom",
		"client": "Cansu",
		"level": 16,
		"brief": "A bathroom you would happily spend an hour in. Tub, shower, twin basins in a proper vanity, and every last thing put away out of sight.",
		"room": {"w": 6.0, "d": 5.0, "h": 2.9},
		"budget": 6600,
		"payout": 9100,
		"xp": 520,
		"map": {"pos": Vector2(22, -27), "rot": 0.0},
		"style": {"body": Color(0.76, 0.86, 0.88), "roof": Color(0.22, 0.42, 0.50), "size": Vector3(6.5, 5.6, 6.0)},
		"requirements": [
			{"type": "item", "id": "bathtub", "count": 1},
			{"type": "item", "id": "shower", "count": 1},
			{"type": "item", "id": "basin", "count": 2},
			{"type": "item", "id": "vanity_unit", "count": 1},
			{"type": "item", "id": "bathroom_cabinet", "count": 1},
			{"type": "item", "id": "bath_mat", "count": 2},
			{"type": "item", "id": "floor_uplighter", "count": 2},
			{"type": "item", "id": "towel_rail", "count": 2},
			{"type": "floor_color", "names": ["Chalk", "Sandstone", "Concrete"]},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "skyline_penthouse",
		"short": "Penthouse",
		"district": "skyline",
		"name": "Skyline Penthouse",
		"client": "Levent",
		"level": 17,
		"brief": "The whole floor, and the view does half the work. Somewhere to sit, somewhere to eat, somewhere to watch, somewhere to work — and it must read as one room, not four.",
		"room": {"w": 9.0, "d": 7.0, "h": 3.2},
		"budget": 10400,
		"payout": 14300,
		"xp": 620,
		"map": {"pos": Vector2(-22, 27), "rot": 180.0},
		"style": {"body": Color(0.62, 0.64, 0.74), "roof": Color(0.20, 0.22, 0.32), "size": Vector3(8.5, 7.0, 7.0)},
		"requirements": [
			{"type": "item", "id": "designer_sofa", "count": 1},
			{"type": "item", "id": "marble_table", "count": 1},
			{"type": "item", "id": "marble_console", "count": 1},
			{"type": "item", "id": "light_column", "count": 2},
			{"type": "item", "id": "arc_lamp", "count": 1},
			{"type": "item", "id": "tv_large", "count": 1},
			{"type": "item", "id": "dining_table", "count": 1},
			{"type": "item", "id": "chair", "count": 4},
			{"type": "item", "id": "desk", "count": 1},
			{"type": "item", "id": "air_conditioner", "count": 1},
			{"type": "categories", "count": 6},
			{"type": "total", "count": 24},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "summit_residence",
		"short": "The Summit",
		"district": "skyline",
		"name": "The Summit Residence",
		"client": "Hülya",
		"level": 17,
		"brief": "The last word. Everything the city sells should be represented somewhere on this floor, it should all agree with itself, and I will know if you rushed the corners.",
		"room": {"w": 10.0, "d": 7.5, "h": 3.2},
		"budget": 13000,
		"payout": 18500,
		"xp": 800,
		"map": {"pos": Vector2(22, 27), "rot": 180.0},
		"style": {"body": Color(0.92, 0.88, 0.80), "roof": Color(0.42, 0.20, 0.24), "size": Vector3(9.0, 7.6, 7.5)},
		"requirements": [
			{"type": "categories", "count": 8, "label": "Buy from every shop in the city"},
			{"type": "item", "id": "bed_double", "count": 1},
			{"type": "item", "id": "bathtub", "count": 1},
			{"type": "item", "id": "kitchen_island", "count": 1},
			{"type": "item", "id": "tv_large", "count": 1},
			{"type": "item", "id": "drinks_cabinet", "count": 1},
			{"type": "item", "id": "projector", "count": 1},
			{"type": "item", "id": "mirror_wall", "count": 1},
			{"type": "item", "id": "corner_sofa", "count": 1},
			{"type": "wall_color", "names": ["Harbour", "Storm", "Ink", "Blush", "Sage"]},
			{"type": "total", "count": 30},
			{"type": "no_overlap"},
		],
	},

	# ------------------------------------------------------- the second street
	#
	# Filling out the empty plots on each quarter's far row, and leaning on the
	# stock the later shops brought with them.
	{
		"id": "aspen_hall",
		"short": "Aspen Hall",
		"district": "maple",
		"name": "Aspen Road Hallway",
		"client": "Timur",
		"level": 3,
		"brief": "It is the first thing anybody sees and at the moment it is a pile of shoes. Somewhere for coats, somewhere for boots, and something on the wall worth looking at.",
		"room": {"w": 4.5, "d": 3.0, "h": 2.6},
		"budget": 1900,
		"payout": 2600,
		"xp": 190,
		"map": {"pos": Vector2(34, 27), "rot": 180.0},
		"style": {"body": Color(0.84, 0.76, 0.70), "roof": Color(0.40, 0.30, 0.26), "size": Vector3(5.5, 3.2, 5.0)},
		"requirements": [
			{"type": "item", "id": "coat_stand", "count": 1},
			{"type": "item", "id": "shoe_rack", "count": 1},
			{"type": "item", "id": "umbrella_stand", "count": 1},
			{"type": "item", "id": "wall_art", "count": 2},
			{"type": "item", "id": "console_table", "count": 1},
			{"type": "total", "count": 8},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "capstan_studio",
		"short": "Capstan",
		"district": "riverside",
		"name": "Capstan Row Studio",
		"client": "Eren",
		"level": 8,
		"brief": "One room over the water and I work in it as well as live in it. I want the working half to look deliberate, not like a desk shoved against a wall.",
		"room": {"w": 5.5, "d": 4.5, "h": 3.0},
		"budget": 3600,
		"payout": 4900,
		"xp": 320,
		"map": {"pos": Vector2(-10, -27), "rot": 0.0},
		"style": {"body": Color(0.74, 0.72, 0.66), "roof": Color(0.32, 0.34, 0.36), "size": Vector3(6.0, 4.0, 5.5)},
		"requirements": [
			{"type": "item", "id": "workbench", "count": 1},
			{"type": "item", "id": "pipe_rack", "count": 1},
			{"type": "item", "id": "bed_single", "count": 1},
			{"type": "item", "id": "lantern", "count": 2},
			{"type": "item", "id": "girder_shelf", "count": 1},
			{"type": "categories", "count": 4},
			{"type": "total", "count": 12},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "chandlers_rest",
		"short": "Chandler's",
		"district": "riverside",
		"name": "The Chandler's Rest",
		"client": "Nazlı",
		"level": 9,
		"brief": "The old shop with the flat above. Downstairs is mine now and I want it to feel like the harbour it looks at — rope, brass, canvas, none of it fussy.",
		"room": {"w": 6.5, "d": 5.0, "h": 3.0},
		"budget": 4800,
		"payout": 6600,
		"xp": 380,
		"map": {"pos": Vector2(10, -27), "rot": 0.0},
		"style": {"body": Color(0.78, 0.74, 0.62), "roof": Color(0.34, 0.40, 0.44), "size": Vector3(6.5, 4.2, 6.0)},
		"requirements": [
			{"type": "item", "id": "deck_chair", "count": 2},
			{"type": "item", "id": "barrel_table", "count": 1},
			{"type": "item", "id": "signal_flags", "count": 1},
			{"type": "item", "id": "rope_coil", "count": 2},
			{"type": "item", "id": "porthole_mirror", "count": 1},
			{"type": "item", "id": "galley_shelf", "count": 1},
			{"type": "categories", "count": 4},
			{"type": "total", "count": 15},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "tide_house",
		"short": "Tide House",
		"district": "riverside",
		"name": "Tide House, Ground Floor",
		"client": "Ozan",
		"level": 11,
		"brief": "Two rooms and a wall between them I am not allowed to touch. Make the kitchen work and the sitting room worth sitting in, and make them look like the same person did both.",
		"room": {"h": 3.0},
		"rooms": [
			{"id": "living", "name": "Living room", "w": 5.5, "d": 4.5, "x": -2.75, "z": 0.0},
			{"id": "kitchen", "name": "Kitchen", "w": 4.0, "d": 4.5, "x": 2.0, "z": 0.0},
		],
		"budget": 6200,
		"payout": 8600,
		"xp": 450,
		"map": {"pos": Vector2(-34, 27), "rot": 180.0},
		"style": {"body": Color(0.68, 0.72, 0.74), "roof": Color(0.28, 0.32, 0.38), "size": Vector3(7.5, 4.4, 6.5)},
		"requirements": [
			{"type": "item", "id": "corner_sofa", "count": 1, "room": "living"},
			{"type": "item", "id": "girder_shelf", "count": 1, "room": "living"},
			{"type": "item", "id": "cask_stand", "count": 1, "room": "kitchen"},
			{"type": "item", "id": "counter", "count": 2, "room": "kitchen"},
			{"type": "item", "id": "range_hood", "count": 1, "room": "kitchen"},
			{"type": "item", "id": "galley_shelf", "count": 1, "room": "kitchen"},
			{"type": "floor_color", "names": ["Concrete", "Slate"], "room": "kitchen"},
			{"type": "wall_color", "names": ["Harbour", "Storm"], "room": "living"},
			{"type": "total", "count": 18},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "bramble_playroom",
		"short": "Bramble",
		"district": "hillside",
		"name": "Bramble Cottage Playroom",
		"client": "Aysu",
		"level": 11,
		"brief": "Three under seven. It has to survive them, it has to be easy to tidy at the end of the day, and I would like one corner of it to still look like a room in a house.",
		"room": {"w": 5.5, "d": 4.5, "h": 2.8},
		"budget": 4000,
		"payout": 5500,
		"xp": 360,
		"map": {"pos": Vector2(-10, -27), "rot": 0.0},
		"style": {"body": Color(0.92, 0.82, 0.72), "roof": Color(0.52, 0.34, 0.26), "size": Vector3(6.0, 3.6, 5.5)},
		"requirements": [
			{"type": "item", "id": "toy_chest", "count": 2},
			{"type": "item", "id": "play_mat", "count": 1},
			{"type": "item", "id": "bookcase_low", "count": 2},
			{"type": "item", "id": "rocking_horse", "count": 1},
			{"type": "item", "id": "night_light", "count": 1},
			{"type": "total", "count": 13},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "orchard_snug",
		"short": "Orchard Snug",
		"district": "hillside",
		"name": "The Orchard Snug",
		"client": "Feride",
		"level": 13,
		"brief": "The little room off the kitchen, and the only one in the house that is mine. A chair by the fire, somewhere for the plants, and nothing in it I did not choose.",
		"room": {"w": 4.5, "d": 4.0, "h": 2.8},
		"budget": 3800,
		"payout": 5200,
		"xp": 340,
		"map": {"pos": Vector2(10, -27), "rot": 0.0},
		"style": {"body": Color(0.86, 0.84, 0.70), "roof": Color(0.42, 0.36, 0.24), "size": Vector3(5.5, 3.4, 5.0)},
		"requirements": [
			{"type": "item", "id": "rocking_chair", "count": 1},
			{"type": "item", "id": "fireside_set", "count": 1},
			{"type": "item", "id": "tall_planter", "count": 2},
			{"type": "item", "id": "fern_stand", "count": 1},
			{"type": "item", "id": "window_seat", "count": 1},
			{"type": "wall_color", "names": ["Sage", "Linen", "Blush"]},
			{"type": "total", "count": 11},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "heather_house",
		"short": "Heather House",
		"district": "hillside",
		"name": "Heather House, Upstairs",
		"client": "Emin",
		"level": 15,
		"brief": "Three rooms across the top of the house: ours, the children's, and the bathroom they share. Nobody is going to be polite about it if you get the wrong thing in the wrong room.",
		"room": {"h": 2.9},
		"rooms": [
			{"id": "bedroom", "name": "Bedroom", "w": 5.0, "d": 5.0, "x": -2.5, "z": 0.0},
			{"id": "nursery", "name": "Children's room", "w": 4.5, "d": 2.5, "x": 2.25, "z": -1.25},
			{"id": "bathroom", "name": "Bathroom", "w": 4.5, "d": 2.5, "x": 2.25, "z": 1.25},
		],
		"budget": 8200,
		"payout": 11300,
		"xp": 560,
		"map": {"pos": Vector2(-10, 27), "rot": 180.0},
		"style": {"body": Color(0.82, 0.78, 0.72), "roof": Color(0.38, 0.32, 0.28), "size": Vector3(8.0, 5.0, 6.5)},
		"requirements": [
			{"type": "item", "id": "bed_king", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "wardrobe", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "bedside_shelf", "count": 2, "room": "bedroom"},
			{"type": "item", "id": "bunk_bed", "count": 1, "room": "nursery"},
			{"type": "item", "id": "toy_chest", "count": 1, "room": "nursery"},
			{"type": "item", "id": "bookcase_low", "count": 1, "room": "nursery"},
			{"type": "item", "id": "bathtub", "count": 1, "room": "bathroom"},
			{"type": "item", "id": "basin", "count": 1, "room": "bathroom"},
			{"type": "item", "id": "bath_screen", "count": 1, "room": "bathroom"},
			{"type": "wall_color", "names": ["Blush", "Sage"], "room": "nursery"},
			{"type": "floor_color", "names": ["Chalk", "Concrete"], "room": "bathroom"},
			{"type": "total", "count": 24},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "cirrus_studio",
		"short": "Cirrus",
		"district": "skyline",
		"name": "Cirrus Tower Studio",
		"client": "Zeki",
		"level": 15,
		"brief": "Small, high up, and everything in it has to earn its place. I would rather have four good things than twelve ordinary ones.",
		"room": {"w": 5.0, "d": 4.5, "h": 3.1},
		"budget": 6400,
		"payout": 8800,
		"xp": 450,
		"map": {"pos": Vector2(-10, -27), "rot": 0.0},
		"style": {"body": Color(0.72, 0.72, 0.80), "roof": Color(0.26, 0.28, 0.38), "size": Vector3(5.5, 6.0, 5.5)},
		"requirements": [
			{"type": "item", "id": "wing_chair", "count": 1},
			{"type": "item", "id": "marble_console", "count": 1},
			{"type": "item", "id": "light_column", "count": 1},
			{"type": "item", "id": "crystal_bowl", "count": 1},
			{"type": "item", "id": "bed_double", "count": 1},
			{"type": "categories", "count": 4},
			{"type": "total", "count": 12},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "meridian_gallery",
		"short": "Meridian",
		"district": "skyline",
		"name": "The Meridian Viewing Room",
		"client": "Suna",
		"level": 16,
		"brief": "People come up here to look at the city and at what I have collected, in that order, and I would like to change the order.",
		"room": {"w": 7.0, "d": 5.5, "h": 3.2},
		"budget": 9800,
		"payout": 13500,
		"xp": 600,
		"map": {"pos": Vector2(10, -27), "rot": 0.0},
		"style": {"body": Color(0.80, 0.78, 0.86), "roof": Color(0.30, 0.26, 0.40), "size": Vector3(7.0, 6.6, 6.0)},
		"requirements": [
			{"type": "item", "id": "glass_case", "count": 3},
			{"type": "item", "id": "pedestal_vase", "count": 2},
			{"type": "item", "id": "art_easel", "count": 1},
			{"type": "item", "id": "mirror_wall", "count": 1},
			{"type": "item", "id": "designer_sofa", "count": 1},
			{"type": "item", "id": "light_column", "count": 2},
			{"type": "categories", "count": 4},
			{"type": "total", "count": 18},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "zenith_suite",
		"short": "Zenith",
		"district": "skyline",
		"name": "Zenith Guest Suite",
		"client": "Tarık",
		"level": 16,
		"brief": "Two rooms for people who stay a week and are used to hotels better than mine. Bedroom and bathroom, and the bathroom is where they will judge me.",
		"room": {"h": 3.1},
		"rooms": [
			{"id": "bedroom", "name": "Bedroom", "w": 5.5, "d": 5.0, "x": -2.75, "z": 0.0},
			{"id": "bathroom", "name": "Bathroom", "w": 4.0, "d": 5.0, "x": 2.0, "z": 0.0},
		],
		"budget": 9000,
		"payout": 12400,
		"xp": 580,
		"map": {"pos": Vector2(-34, 27), "rot": 180.0},
		"style": {"body": Color(0.74, 0.80, 0.84), "roof": Color(0.24, 0.36, 0.44), "size": Vector3(7.5, 6.4, 6.5)},
		"requirements": [
			{"type": "item", "id": "bed_king", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "wing_chair", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "mirror_wall", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "bedside_shelf", "count": 2, "room": "bedroom"},
			{"type": "item", "id": "bathtub", "count": 1, "room": "bathroom"},
			{"type": "item", "id": "corner_shower", "count": 1, "room": "bathroom"},
			{"type": "item", "id": "vanity_unit", "count": 1, "room": "bathroom"},
			{"type": "item", "id": "bathroom_cabinet", "count": 1, "room": "bathroom"},
			{"type": "floor_color", "names": ["Chalk", "Sandstone"], "room": "bathroom"},
			{"type": "wall_color", "names": ["Ink", "Storm", "Harbour"], "room": "bedroom"},
			{"type": "total", "count": 22},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "apex_residence",
		"short": "Apex",
		"district": "skyline",
		"name": "The Apex Residence",
		"client": "Bilge",
		"level": 18,
		"brief": "Four rooms, and the only brief I will give you is this: I have seen the Observatory and I want people to argue about which of us got the better job.",
		"room": {"h": 3.2},
		"rooms": [
			{"id": "living", "name": "Living room", "w": 7.0, "d": 5.5, "x": -3.5, "z": -2.75},
			{"id": "dining", "name": "Dining room", "w": 7.0, "d": 4.5, "x": -3.5, "z": 2.25},
			{"id": "bedroom", "name": "Bedroom", "w": 5.0, "d": 5.5, "x": 2.5, "z": -2.75},
			{"id": "study", "name": "Study", "w": 5.0, "d": 4.5, "x": 2.5, "z": 2.25},
		],
		"budget": 14500,
		"payout": 20000,
		"xp": 820,
		"map": {"pos": Vector2(10, 27), "rot": 180.0},
		"style": {"body": Color(0.86, 0.84, 0.88), "roof": Color(0.32, 0.24, 0.38), "size": Vector3(8.5, 7.8, 7.0)},
		"requirements": [
			{"type": "item", "id": "corner_sofa", "count": 1, "room": "living"},
			{"type": "item", "id": "tv_large", "count": 1, "room": "living"},
			{"type": "item", "id": "light_column", "count": 2, "room": "living"},
			{"type": "item", "id": "marble_table", "count": 1, "room": "dining"},
			{"type": "item", "id": "chair", "count": 6, "room": "dining"},
			{"type": "item", "id": "glass_case", "count": 1, "room": "dining"},
			{"type": "item", "id": "bed_king", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "mirror_wall", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "marble_console", "count": 1, "room": "study"},
			{"type": "item", "id": "art_easel", "count": 1, "room": "study"},
			{"type": "categories", "count": 7},
			{"type": "total", "count": 36},
			{"type": "no_overlap"},
		],
	},

	# ------------------------------------------------ whole floors, room by room
	#
	# These carry a "rooms" plan instead of a single rectangle, and their briefs
	# pin lines to a room: a bed in the bedroom is not a bed in the hall. The
	# rectangles have to butt up against each other — wherever two of them share
	# an edge, the shell puts a doorway through it.
	{
		"id": "alder_flat",
		"short": "Alder Flat",
		"district": "maple",
		"name": "The Alder Street Flat",
		"client": "Yağmur",
		"level": 5,
		"brief": "Two rooms and a landlord who wants it let by the month. Somewhere to sit at the front, somewhere to sleep at the back, and please keep them feeling like separate rooms.",
		"room": {"h": 2.7},
		"rooms": [
			{"id": "living", "name": "Living room", "w": 4.5, "d": 3.5, "x": -2.25, "z": 0.0},
			{"id": "bedroom", "name": "Bedroom", "w": 3.0, "d": 3.5, "x": 1.5, "z": 0.0},
		],
		"budget": 3200,
		"payout": 4400,
		"xp": 300,
		"map": {"pos": Vector2(22, 27), "rot": 180.0},
		"style": {"body": Color(0.84, 0.86, 0.78), "roof": Color(0.36, 0.40, 0.30), "size": Vector3(7.0, 3.4, 5.5)},
		"requirements": [
			{"type": "item", "id": "sofa", "count": 1, "room": "living"},
			{"type": "item", "id": "coffee_table", "count": 1, "room": "living"},
			{"type": "item", "id": "bed_single", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "wardrobe", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "bedside_shelf", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "umbrella_stand", "count": 1, "room": "living"},
			{"type": "total", "count": 12},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "cooperage_flat",
		"short": "Cooperage",
		"district": "riverside",
		"name": "The Cooperage Flat",
		"client": "Sinem",
		"level": 9,
		"brief": "One of six in the old barrel works. I want the living end to be the room people remember and the bedroom to be somewhere I can shut the door on.",
		"room": {"h": 3.0},
		"rooms": [
			{"id": "living", "name": "Living room", "w": 5.0, "d": 4.5, "x": -2.5, "z": 0.0},
			{"id": "bedroom", "name": "Bedroom", "w": 3.6, "d": 4.5, "x": 1.8, "z": 0.0},
		],
		"budget": 4800,
		"payout": 6600,
		"xp": 380,
		"map": {"pos": Vector2(-34, -27), "rot": 0.0},
		"style": {"body": Color(0.76, 0.70, 0.62), "roof": Color(0.36, 0.32, 0.30), "size": Vector3(7.5, 4.4, 6.0)},
		"requirements": [
			{"type": "item", "id": "sofa", "count": 1, "room": "living"},
			{"type": "item", "id": "television", "count": 1, "room": "living"},
			{"type": "item", "id": "tv_stand", "count": 1, "room": "living"},
			{"type": "item", "id": "bed_double", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "nightstand", "count": 2, "room": "bedroom"},
			{"type": "item", "id": "pipe_rack", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "barrel_table", "count": 1, "room": "living"},
			{"type": "total", "count": 16},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "granary_duplex",
		"short": "Granary",
		"district": "riverside",
		"name": "The Granary Duplex",
		"client": "Onur",
		"level": 11,
		"brief": "Three rooms off one big space. The kitchen and the bathroom are small so they have to be exactly right, and the living room has to carry the whole flat.",
		"room": {"h": 3.0},
		"rooms": [
			{"id": "living", "name": "Living room", "w": 5.5, "d": 5.0, "x": -2.75, "z": 0.0},
			{"id": "kitchen", "name": "Kitchen", "w": 4.0, "d": 2.5, "x": 2.0, "z": -1.25},
			{"id": "bathroom", "name": "Bathroom", "w": 4.0, "d": 2.5, "x": 2.0, "z": 1.25},
		],
		"budget": 6900,
		"payout": 9500,
		"xp": 460,
		"map": {"pos": Vector2(34, -27), "rot": 0.0},
		"style": {"body": Color(0.70, 0.74, 0.80), "roof": Color(0.26, 0.30, 0.38), "size": Vector3(8.0, 5.0, 6.5)},
		"requirements": [
			{"type": "item", "id": "sofa", "count": 1, "room": "living"},
			{"type": "item", "id": "bookshelf", "count": 2, "room": "living"},
			{"type": "item", "id": "deck_chair", "count": 2, "room": "living"},
			{"type": "item", "id": "counter", "count": 2, "room": "kitchen"},
			{"type": "item", "id": "galley_shelf", "count": 1, "room": "kitchen"},
			{"type": "item", "id": "girder_shelf", "count": 1, "room": "living"},
			{"type": "item", "id": "fridge", "count": 1, "room": "kitchen"},
			{"type": "item", "id": "toilet", "count": 1, "room": "bathroom"},
			{"type": "item", "id": "basin", "count": 1, "room": "bathroom"},
			{"type": "item", "id": "shower", "count": 1, "room": "bathroom"},
			{"type": "floor_color", "names": ["Concrete", "Slate", "Chalk"], "room": "bathroom"},
			{"type": "total", "count": 20},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "beacon_house",
		"short": "Beacon House",
		"district": "hillside",
		"name": "Beacon House Ground Floor",
		"client": "Merve",
		"level": 14,
		"brief": "The whole ground floor in one go. Cooking at the back, sitting at the front, and the long room down the side is for my mother — she is moving in and she is particular.",
		"room": {"h": 2.9},
		"rooms": [
			{"id": "living", "name": "Living room", "w": 5.5, "d": 4.0, "x": -2.75, "z": -2.0},
			{"id": "kitchen", "name": "Kitchen", "w": 5.5, "d": 3.5, "x": -2.75, "z": 1.75},
			{"id": "bedroom", "name": "Bedroom", "w": 4.5, "d": 7.5, "x": 2.25, "z": -0.25},
		],
		"budget": 7800,
		"payout": 10700,
		"xp": 530,
		"map": {"pos": Vector2(-34, -27), "rot": 0.0},
		"style": {"body": Color(0.88, 0.80, 0.66), "roof": Color(0.48, 0.32, 0.24), "size": Vector3(8.5, 4.4, 7.0)},
		"requirements": [
			{"type": "item", "id": "sofa", "count": 1, "room": "living"},
			{"type": "item", "id": "armchair", "count": 2, "room": "living"},
			{"type": "item", "id": "window_seat", "count": 1, "room": "living"},
			{"type": "item", "id": "planter_box", "count": 1, "room": "kitchen"},
			{"type": "item", "id": "stove", "count": 1, "room": "kitchen"},
			{"type": "item", "id": "sink_unit", "count": 1, "room": "kitchen"},
			{"type": "item", "id": "dining_table", "count": 1, "room": "kitchen"},
			{"type": "item", "id": "bed_double", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "dresser", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "tall_planter", "count": 1, "room": "living"},
			{"type": "categories", "count": 5},
			{"type": "total", "count": 24},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "fell_view",
		"short": "Fell View",
		"district": "hillside",
		"name": "Fell View, Upstairs",
		"client": "Kaya",
		"level": 15,
		"brief": "Four rooms, and I have lived with the builders long enough to know exactly what goes where. Do not put anything in the wrong room; I will notice on the walk-through.",
		"room": {"h": 2.9},
		"rooms": [
			{"id": "living", "name": "Living room", "w": 6.0, "d": 4.5, "x": -3.0, "z": -2.25},
			{"id": "dining", "name": "Dining room", "w": 6.0, "d": 3.5, "x": -3.0, "z": 1.75},
			{"id": "bedroom", "name": "Bedroom", "w": 4.5, "d": 4.5, "x": 2.25, "z": -2.25},
			{"id": "bathroom", "name": "Bathroom", "w": 4.5, "d": 3.5, "x": 2.25, "z": 1.75},
		],
		"budget": 9400,
		"payout": 13000,
		"xp": 620,
		"map": {"pos": Vector2(34, -27), "rot": 0.0},
		"style": {"body": Color(0.80, 0.76, 0.70), "roof": Color(0.34, 0.30, 0.28), "size": Vector3(8.5, 5.6, 7.0)},
		"requirements": [
			{"type": "item", "id": "sofa", "count": 1, "room": "living"},
			{"type": "item", "id": "television", "count": 1, "room": "living"},
			{"type": "item", "id": "dining_table", "count": 1, "room": "dining"},
			{"type": "item", "id": "chair", "count": 4, "room": "dining"},
			{"type": "item", "id": "sideboard", "count": 1, "room": "dining"},
			{"type": "item", "id": "garden_bench", "count": 1, "room": "living"},
			{"type": "item", "id": "bed_double", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "wardrobe", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "bathtub", "count": 1, "room": "bathroom"},
			{"type": "item", "id": "toilet", "count": 1, "room": "bathroom"},
			{"type": "item", "id": "basin", "count": 1, "room": "bathroom"},
			{"type": "total", "count": 28},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "cloud_court",
		"short": "Cloud Court",
		"district": "skyline",
		"name": "Cloud Court, Floor 22",
		"client": "Devrim",
		"level": 17,
		"brief": "Four rooms and a lift that opens into them. I entertain, I work from home, and I sleep badly — so the bedroom has to be the quietest thing you have ever laid out.",
		"room": {"h": 3.1},
		"rooms": [
			{"id": "living", "name": "Living room", "w": 7.0, "d": 5.5, "x": -3.5, "z": -2.75},
			{"id": "kitchen", "name": "Kitchen", "w": 7.0, "d": 4.0, "x": -3.5, "z": 2.0},
			{"id": "bedroom", "name": "Bedroom", "w": 5.0, "d": 5.5, "x": 2.5, "z": -2.75},
			{"id": "study", "name": "Study", "w": 5.0, "d": 4.0, "x": 2.5, "z": 2.0},
		],
		"budget": 14800,
		"payout": 20400,
		"xp": 720,
		"map": {"pos": Vector2(-34, -27), "rot": 0.0},
		"style": {"body": Color(0.66, 0.68, 0.78), "roof": Color(0.22, 0.24, 0.36), "size": Vector3(8.5, 7.4, 7.0)},
		"requirements": [
			{"type": "item", "id": "sofa", "count": 2, "room": "living"},
			{"type": "item", "id": "designer_sofa", "count": 1, "room": "living"},
			{"type": "item", "id": "projector", "count": 1, "room": "living"},
			{"type": "item", "id": "kitchen_island", "count": 1, "room": "kitchen"},
			{"type": "item", "id": "fridge", "count": 1, "room": "kitchen"},
			{"type": "item", "id": "dishwasher", "count": 1, "room": "kitchen"},
			{"type": "item", "id": "bed_double", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "wardrobe", "count": 2, "room": "bedroom"},
			{"type": "item", "id": "bed_king", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "glass_case", "count": 1, "room": "study"},
			{"type": "item", "id": "desk", "count": 1, "room": "study"},
			{"type": "item", "id": "computer", "count": 1, "room": "study"},
			{"type": "item", "id": "bookshelf", "count": 2, "room": "study"},
			{"type": "categories", "count": 6},
			{"type": "total", "count": 34},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "the_observatory",
		"short": "Observatory",
		"district": "skyline",
		"name": "The Observatory",
		"client": "Perihan",
		"level": 19,
		"brief": "Five rooms at the top of the tower, and the last word on what this city can do. Every room finished properly, every room agreeing with the others, and nothing left looking like it was put down in a hurry.",
		"room": {"h": 3.2},
		"rooms": [
			{"id": "living", "name": "Living room", "w": 7.0, "d": 6.0, "x": -3.5, "z": -3.0},
			{"id": "dining", "name": "Dining room", "w": 7.0, "d": 4.5, "x": -3.5, "z": 2.25},
			{"id": "bedroom", "name": "Bedroom", "w": 5.5, "d": 6.0, "x": 2.75, "z": -3.0},
			{"id": "bathroom", "name": "Bathroom", "w": 2.75, "d": 4.5, "x": 1.375, "z": 2.25},
			{"id": "study", "name": "Study", "w": 2.75, "d": 4.5, "x": 4.125, "z": 2.25},
		],
		"budget": 18000,
		"payout": 24800,
		"xp": 900,
		"map": {"pos": Vector2(34, -27), "rot": 0.0},
		"style": {"body": Color(0.90, 0.88, 0.84), "roof": Color(0.40, 0.20, 0.26), "size": Vector3(9.0, 8.4, 7.5)},
		"requirements": [
			{"type": "item", "id": "sofa", "count": 2, "room": "living"},
			{"type": "item", "id": "tv_large", "count": 1, "room": "living"},
			{"type": "item", "id": "speaker_tower", "count": 2, "room": "living"},
			{"type": "item", "id": "designer_sofa", "count": 1, "room": "living"},
			{"type": "item", "id": "marble_table", "count": 1, "room": "dining"},
			{"type": "item", "id": "drinks_cabinet", "count": 1, "room": "dining"},
			{"type": "item", "id": "smart_panel", "count": 1, "room": "study"},
			{"type": "item", "id": "mirror_wall", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "crystal_bowl", "count": 2, "room": "dining"},
			{"type": "item", "id": "dining_table", "count": 1, "room": "dining"},
			{"type": "item", "id": "chair", "count": 6, "room": "dining"},
			{"type": "item", "id": "display_cabinet", "count": 1, "room": "dining"},
			{"type": "item", "id": "bed_double", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "wardrobe", "count": 2, "room": "bedroom"},
			{"type": "item", "id": "dressing_table", "count": 1, "room": "bedroom"},
			{"type": "item", "id": "bathtub", "count": 1, "room": "bathroom"},
			{"type": "item", "id": "toilet", "count": 1, "room": "bathroom"},
			{"type": "item", "id": "desk", "count": 1, "room": "study"},
			{"type": "item", "id": "bookshelf", "count": 2, "room": "study"},
			{"type": "categories", "count": 7},
			{"type": "wall_color", "names": ["Harbour", "Storm", "Ink", "Sage", "Linen"]},
			{"type": "total", "count": 42},
			{"type": "no_overlap"},
		],
	},

	# ------------------------------------------------------------ Hanami Ward
	{
		"id": "sakura_tearoom",
		"short": "Sakura Tearoom",
		"district": "hanami",
		"name": "The Sakura Tearoom",
		"client": "Nozomi",
		"level": 19,
		"brief": "One room, and it should feel like there is nothing in it. Mats on the floor, a low table in the middle, cushions to kneel on. Somewhere to rest the eye and nothing else.",
		"room": {"w": 5.0, "d": 4.5, "h": 2.5},
		"budget": 2100,
		"payout": 5600,
		"xp": 780,
		"map": {"pos": Vector2(-22, -27), "rot": 0.0},
		"style": {"kind": "machiya", "body": Color(0.90, 0.86, 0.78), "roof": Color(0.28, 0.30, 0.34), "size": Vector3(7.0, 3.2, 6.5)},
		"requirements": [
			{"type": "item", "id": "tatami_mat", "count": 4},
			{"type": "item", "id": "chabudai", "count": 1},
			{"type": "item", "id": "zabuton", "count": 4},
			{"type": "total", "count": 10},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "kiri_bedroom",
		"short": "Kiri Bedroom",
		"district": "hanami",
		"name": "The Kiri Bedroom",
		"client": "Haruto",
		"level": 19,
		"brief": "I sleep on the floor and I put the bedding away in the morning. A futon, mats under it, and a chest that will outlive me.",
		"room": {"w": 4.8, "d": 4.2, "h": 2.5},
		"budget": 2600,
		"payout": 6200,
		"xp": 830,
		"map": {"pos": Vector2(-10, -27), "rot": 0.0},
		"style": {"kind": "machiya", "body": Color(0.84, 0.78, 0.68), "roof": Color(0.24, 0.26, 0.30), "size": Vector3(6.5, 3.0, 6.0)},
		"requirements": [
			{"type": "item", "id": "futon_roll", "count": 1},
			{"type": "item", "id": "tatami_mat", "count": 3},
			{"type": "item", "id": "tansu", "count": 1},
			{"type": "item", "id": "andon_lamp", "count": 1},
			{"type": "total", "count": 9},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "shoji_study",
		"short": "Shoji Study",
		"district": "hanami",
		"name": "The Shoji Study",
		"client": "Aiko",
		"level": 20,
		"brief": "I write here. Screens to divide the light, somewhere low to work, and one green thing to look at when the writing will not come.",
		"room": {"w": 5.4, "d": 4.6, "h": 2.5},
		"budget": 3200,
		"payout": 7100,
		"xp": 900,
		"map": {"pos": Vector2(10, -27), "rot": 0.0},
		"style": {"kind": "machiya", "body": Color(0.88, 0.84, 0.76), "roof": Color(0.30, 0.28, 0.32), "size": Vector3(7.0, 3.4, 6.5)},
		"requirements": [
			{"type": "item", "id": "shoji_screen", "count": 2},
			{"type": "item", "id": "chabudai", "count": 1},
			{"type": "item", "id": "bonsai", "count": 1},
			{"type": "category", "category": "Storage", "count": 1},
			{"type": "total", "count": 11},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "engawa_house",
		"short": "Engawa House",
		"district": "hanami",
		"name": "The Engawa House",
		"client": "Ren",
		"level": 21,
		"brief": "Two rooms. The front one is for sitting with guests, the back one is where we actually live. Keep the front one bare.",
		"room": {"h": 2.5},
		"rooms": [
			{"id": "front", "name": "Guest room", "x": -2.25, "z": 0.0, "w": 4.5, "d": 5.0},
			{"id": "back", "name": "Living room", "x": 2.25, "z": 0.0, "w": 4.5, "d": 5.0},
		],
		"budget": 4200,
		"payout": 8400,
		"xp": 1020,
		"map": {"pos": Vector2(22, -27), "rot": 0.0},
		"style": {"kind": "machiya", "body": Color(0.86, 0.82, 0.74), "roof": Color(0.26, 0.28, 0.32), "size": Vector3(8.0, 3.4, 6.5)},
		"requirements": [
			{"type": "item", "id": "tatami_mat", "count": 3, "room": "front"},
			{"type": "item", "id": "zabuton", "count": 3, "room": "front"},
			{"type": "item", "id": "kotatsu", "count": 1, "room": "back"},
			{"type": "item", "id": "tansu", "count": 1, "room": "back"},
			{"type": "floor_color", "names": ["Pale Oak", "Sandstone"]},
			{"type": "total", "count": 15},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "lantern_court",
		"short": "Lantern Court",
		"district": "hanami",
		"name": "Lantern Court",
		"client": "Emi",
		"level": 22,
		"brief": "The light matters more than the furniture. Lanterns, paper screens, and as little else as you can get away with while still calling it furnished.",
		"room": {"w": 6.0, "d": 5.2, "h": 2.6},
		"budget": 4600,
		"payout": 9200,
		"xp": 1080,
		"map": {"pos": Vector2(-34, 27), "rot": 180.0},
		"style": {"kind": "machiya", "body": Color(0.92, 0.88, 0.80), "roof": Color(0.22, 0.24, 0.28), "size": Vector3(7.5, 3.6, 6.5)},
		"requirements": [
			{"type": "item", "id": "andon_lamp", "count": 3},
			{"type": "item", "id": "shoji_screen", "count": 2},
			{"type": "item", "id": "byobu", "count": 1},
			{"type": "categories", "count": 4},
			{"type": "total", "count": 14},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "tsukubai_bath",
		"short": "Tsukubai Bath",
		"district": "hanami",
		"name": "The Tsukubai Bath",
		"client": "Sora",
		"level": 22,
		"brief": "A bathroom that behaves like a garden. The usual fittings, but a stone basin by the door and something growing in the corner.",
		"room": {"w": 4.6, "d": 4.2, "h": 2.5},
		"budget": 4400,
		"payout": 9000,
		"xp": 1050,
		"map": {"pos": Vector2(-22, 27), "rot": 180.0},
		"style": {"kind": "machiya", "body": Color(0.80, 0.80, 0.76), "roof": Color(0.30, 0.32, 0.34), "size": Vector3(6.0, 3.2, 6.0)},
		"requirements": [
			{"type": "category", "category": "Bathroom", "count": 3},
			{"type": "item", "id": "tsukubai", "count": 1},
			{"type": "item", "id": "bonsai", "count": 1},
			{"type": "wall_color", "names": ["Sage", "Cotton", "Morning"]},
			{"type": "total", "count": 12},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "machiya_upstairs",
		"short": "Machiya Upstairs",
		"district": "hanami",
		"name": "The Machiya, Upstairs",
		"client": "Yuki",
		"level": 23,
		"brief": "Three rooms over the shop. Somewhere to sleep, somewhere to eat, and a small room for the things nobody wants to look at.",
		"room": {"h": 2.5},
		"rooms": [
			{"id": "sleep", "name": "Bedroom", "x": -3.5, "z": 0.0, "w": 3.5, "d": 5.5},
			{"id": "eat", "name": "Dining room", "x": 0.0, "z": 0.0, "w": 3.5, "d": 5.5},
			{"id": "store", "name": "Store room", "x": 3.5, "z": 0.0, "w": 3.5, "d": 5.5},
		],
		"budget": 6200,
		"payout": 11800,
		"xp": 1280,
		"map": {"pos": Vector2(-10, 27), "rot": 180.0},
		"style": {"kind": "machiya", "body": Color(0.82, 0.76, 0.66), "roof": Color(0.24, 0.26, 0.30), "size": Vector3(8.5, 5.6, 6.5)},
		"requirements": [
			{"type": "item", "id": "futon_roll", "count": 1, "room": "sleep"},
			{"type": "item", "id": "tatami_mat", "count": 2, "room": "sleep"},
			{"type": "item", "id": "chabudai", "count": 1, "room": "eat"},
			{"type": "item", "id": "zabuton", "count": 4, "room": "eat"},
			{"type": "item", "id": "kaidan_dansu", "count": 1, "room": "store"},
			{"type": "item", "id": "getabako", "count": 1, "room": "store"},
			{"type": "total", "count": 20},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "the_hanami_house",
		"short": "Hanami House",
		"district": "hanami",
		"name": "The Hanami House",
		"client": "Kaede",
		"level": 24,
		"brief": "The whole floor, and the ward's best-known address. Four rooms, everything the ward sells represented somewhere in it, and not one piece more than the room needs.",
		"room": {"h": 2.6},
		"rooms": [
			{"id": "tea", "name": "Tea room", "x": -3.0, "z": -2.5, "w": 5.0, "d": 4.0},
			{"id": "sleep", "name": "Bedroom", "x": 3.0, "z": -2.5, "w": 5.0, "d": 4.0},
			{"id": "living", "name": "Living room", "x": -3.0, "z": 2.5, "w": 5.0, "d": 4.0},
			{"id": "study", "name": "Study", "x": 3.0, "z": 2.5, "w": 5.0, "d": 4.0},
		],
		"budget": 9800,
		"payout": 17500,
		"xp": 1650,
		"map": {"pos": Vector2(22, 27), "rot": 180.0},
		"style": {"kind": "machiya", "body": Color(0.88, 0.84, 0.74), "roof": Color(0.20, 0.22, 0.26), "size": Vector3(9.5, 4.2, 7.5)},
		"requirements": [
			{"type": "item", "id": "tatami_mat", "count": 4, "room": "tea"},
			{"type": "item", "id": "chabudai", "count": 1, "room": "tea"},
			{"type": "item", "id": "futon_roll", "count": 1, "room": "sleep"},
			{"type": "item", "id": "tansu", "count": 1, "room": "sleep"},
			{"type": "item", "id": "kotatsu", "count": 1, "room": "living"},
			{"type": "item", "id": "byobu", "count": 1, "room": "living"},
			{"type": "item", "id": "shoji_screen", "count": 1, "room": "study"},
			{"type": "item", "id": "bonsai", "count": 1, "room": "study"},
			{"type": "categories", "count": 5},
			{"type": "total", "count": 30},
			{"type": "no_overlap"},
		],
	},

	# ------------------------------------------------------------- Hollow Row
	{
		"id": "gravediggers_flat",
		"short": "Sexton's Flat",
		"district": "hollow",
		"name": "The Sexton's Flat",
		"client": "Mr Crale",
		"level": 24,
		"brief": "I work nights at the yard and sleep through the afternoon. Somewhere dark to lie down, somewhere to put a candle, and a chair that does not creak.",
		"room": {"w": 5.0, "d": 4.5, "h": 2.7},
		"budget": 4200,
		"payout": 11200,
		"xp": 1240,
		"map": {"pos": Vector2(-22, -27), "rot": 0.0},
		"style": {"kind": "manor", "body": Color(0.42, 0.40, 0.44), "roof": Color(0.20, 0.17, 0.24), "size": Vector3(6.5, 4.4, 6.0)},
		"requirements": [
			{"type": "item", "id": "coffin_bed", "count": 1},
			{"type": "item", "id": "candelabra", "count": 1},
			{"type": "item", "id": "high_back_chair", "count": 1},
			{"type": "total", "count": 9},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "witchs_kitchen",
		"short": "Witch's Kitchen",
		"district": "hollow",
		"name": "The Witch's Kitchen",
		"client": "Bramble",
		"level": 24,
		"brief": "I cook and I brew and the two are not always different. The cauldron over the fire, the counter along the wall, and somewhere to hang things to dry.",
		"room": {"w": 5.5, "d": 5.0, "h": 2.8},
		"budget": 5200,
		"payout": 12400,
		"xp": 1320,
		"map": {"pos": Vector2(-10, -27), "rot": 0.0},
		"style": {"kind": "manor", "body": Color(0.38, 0.42, 0.38), "roof": Color(0.18, 0.20, 0.22), "size": Vector3(6.5, 4.6, 6.0)},
		"requirements": [
			{"type": "item", "id": "cauldron_stove", "count": 1},
			{"type": "item", "id": "apothecary_counter", "count": 1},
			{"type": "item", "id": "drying_rack", "count": 1},
			{"type": "item", "id": "skull_candle", "count": 2},
			{"type": "total", "count": 12},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "moonlit_parlour",
		"short": "Moonlit Parlour",
		"district": "hollow",
		"name": "The Moonlit Parlour",
		"client": "Lady Vane",
		"level": 25,
		"brief": "I receive people here, and I would like them uneasy. High-backed chairs, a mirror they will avoid looking into, and candles rather than lamps.",
		"room": {"w": 6.0, "d": 5.2, "h": 3.0},
		"budget": 6400,
		"payout": 14000,
		"xp": 1420,
		"map": {"pos": Vector2(10, -27), "rot": 0.0},
		"style": {"kind": "manor", "body": Color(0.46, 0.40, 0.48), "roof": Color(0.22, 0.16, 0.26), "size": Vector3(7.0, 5.2, 6.5)},
		"requirements": [
			{"type": "item", "id": "high_back_chair", "count": 2},
			{"type": "item", "id": "black_mirror", "count": 1},
			{"type": "item", "id": "candelabra", "count": 2},
			{"type": "wall_color", "names": ["Ink", "Storm", "Slate"]},
			{"type": "total", "count": 13},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "howlers_den",
		"short": "Howler's Den",
		"district": "hollow",
		"name": "The Howler's Den",
		"client": "Ovid",
		"level": 25,
		"brief": "Two rooms, and both of them have to survive one bad night a month. Nothing precious, nothing narrow, and the bed had better be solid.",
		"room": {"h": 2.9},
		"rooms": [
			{"id": "den", "name": "Living room", "x": -2.4, "z": 0.0, "w": 4.7, "d": 5.5},
			{"id": "sleep", "name": "Bedroom", "x": 2.4, "z": 0.0, "w": 4.7, "d": 5.5},
		],
		"budget": 7600,
		"payout": 15600,
		"xp": 1540,
		"map": {"pos": Vector2(22, -27), "rot": 0.0},
		"style": {"kind": "manor", "body": Color(0.40, 0.36, 0.34), "roof": Color(0.20, 0.18, 0.20), "size": Vector3(7.5, 5.0, 6.5)},
		"requirements": [
			{"type": "item", "id": "high_back_chair", "count": 2, "room": "den"},
			{"type": "item", "id": "grimoire_case", "count": 1, "room": "den"},
			{"type": "item", "id": "four_poster", "count": 1, "room": "sleep"},
			{"type": "item", "id": "casket_chest", "count": 1, "room": "sleep"},
			{"type": "total", "count": 18},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "ravens_landing",
		"short": "Raven's Landing",
		"district": "hollow",
		"name": "Raven's Landing",
		"client": "Corvin",
		"level": 26,
		"brief": "The top of the stair, and the birds get the run of it. Somewhere for them to perch, something stone to look at, and books I can reach without a ladder.",
		"room": {"w": 6.2, "d": 5.4, "h": 3.0},
		"budget": 7800,
		"payout": 16200,
		"xp": 1580,
		"map": {"pos": Vector2(-34, 27), "rot": 180.0},
		"style": {"kind": "manor", "body": Color(0.36, 0.36, 0.42), "roof": Color(0.16, 0.16, 0.22), "size": Vector3(7.0, 5.8, 6.5)},
		"requirements": [
			{"type": "item", "id": "raven_perch", "count": 2},
			{"type": "item", "id": "gargoyle_statue", "count": 1},
			{"type": "item", "id": "grimoire_case", "count": 2},
			{"type": "categories", "count": 4},
			{"type": "total", "count": 16},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "the_seance_room",
		"short": "Séance Room",
		"district": "hollow",
		"name": "The Séance Room",
		"client": "Madame Orrin",
		"level": 26,
		"brief": "One table, six chairs, and everything else in the room has to earn its place. The globe goes in the middle and the candles do the rest.",
		"room": {"w": 6.5, "d": 5.6, "h": 2.9},
		"budget": 8200,
		"payout": 17000,
		"xp": 1640,
		"map": {"pos": Vector2(-22, 27), "rot": 180.0},
		"style": {"kind": "manor", "body": Color(0.44, 0.38, 0.46), "roof": Color(0.22, 0.16, 0.24), "size": Vector3(7.0, 5.4, 6.5)},
		"requirements": [
			{"type": "category", "category": "Dining", "count": 2},
			{"type": "item", "id": "crystal_ball", "count": 1},
			{"type": "item", "id": "candelabra", "count": 2},
			{"type": "item", "id": "skull_candle", "count": 2},
			{"type": "total", "count": 17},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "the_undercroft",
		"short": "The Undercroft",
		"district": "hollow",
		"name": "The Undercroft",
		"client": "Master Vell",
		"level": 27,
		"brief": "Three rooms below the house. A cellar to sleep in, a still-room to work in, and a library. No windows anywhere, so the light has to come off the walls.",
		"room": {"h": 2.8},
		"rooms": [
			{"id": "cellar", "name": "Bedroom", "x": -4.0, "z": 0.0, "w": 4.0, "d": 6.0},
			{"id": "still", "name": "Kitchen", "x": 0.0, "z": 0.0, "w": 4.0, "d": 6.0},
			{"id": "library", "name": "Study", "x": 4.0, "z": 0.0, "w": 4.0, "d": 6.0},
		],
		"budget": 11500,
		"payout": 21000,
		"xp": 1880,
		"map": {"pos": Vector2(-10, 27), "rot": 180.0},
		"style": {"kind": "manor", "body": Color(0.34, 0.34, 0.38), "roof": Color(0.16, 0.14, 0.20), "size": Vector3(8.5, 5.6, 7.0)},
		"requirements": [
			{"type": "item", "id": "coffin_bed", "count": 1, "room": "cellar"},
			{"type": "item", "id": "casket_chest", "count": 1, "room": "cellar"},
			{"type": "item", "id": "cauldron_stove", "count": 1, "room": "still"},
			{"type": "item", "id": "apothecary_counter", "count": 1, "room": "still"},
			{"type": "item", "id": "grimoire_case", "count": 2, "room": "library"},
			{"type": "item", "id": "candelabra", "count": 2},
			{"type": "wall_color", "names": ["Ink", "Storm"]},
			{"type": "total", "count": 26},
			{"type": "no_overlap"},
		],
	},
	{
		"id": "hollow_house",
		"short": "Hollow House",
		"district": "hollow",
		"name": "Hollow House",
		"client": "The Ashgrave Family",
		"level": 28,
		"brief": "The house at the end of the row, and the last address on the map. Four rooms, every trade in the row represented, and it should look like the family has been here three hundred years.",
		"room": {"h": 3.0},
		"rooms": [
			{"id": "hall", "name": "Living room", "x": -3.25, "z": -2.6, "w": 5.5, "d": 4.3},
			{"id": "sleep", "name": "Bedroom", "x": 3.25, "z": -2.6, "w": 5.5, "d": 4.3},
			{"id": "kitchen", "name": "Kitchen", "x": -3.25, "z": 2.6, "w": 5.5, "d": 4.3},
			{"id": "library", "name": "Study", "x": 3.25, "z": 2.6, "w": 5.5, "d": 4.3},
		],
		"budget": 17500,
		"payout": 29000,
		"xp": 2400,
		"map": {"pos": Vector2(22, 27), "rot": 180.0},
		"style": {"kind": "manor", "body": Color(0.38, 0.34, 0.42), "roof": Color(0.18, 0.14, 0.22), "size": Vector3(9.5, 6.6, 7.5)},
		"requirements": [
			{"type": "item", "id": "high_back_chair", "count": 2, "room": "hall"},
			{"type": "item", "id": "black_mirror", "count": 1, "room": "hall"},
			{"type": "item", "id": "four_poster", "count": 1, "room": "sleep"},
			{"type": "item", "id": "casket_chest", "count": 1, "room": "sleep"},
			{"type": "item", "id": "cauldron_stove", "count": 1, "room": "kitchen"},
			{"type": "item", "id": "drying_rack", "count": 1, "room": "kitchen"},
			{"type": "item", "id": "grimoire_case", "count": 2, "room": "library"},
			{"type": "item", "id": "gargoyle_statue", "count": 1},
			{"type": "item", "id": "candelabra", "count": 3},
			{"type": "categories", "count": 6},
			{"type": "total", "count": 38},
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
		"name": "kitchen", "level": 3,
		"core": ["counter", "fridge", "sink_unit", "stove"],
		"filler": "Decor",
		"brief": "It has to work before it looks good. Counters, cold storage, somewhere to wash up.",
	},
	{
		"name": "media room", "level": 3,
		"core": ["television", "tv_large", "sofa", "speaker_tower", "soundbar", "tv_stand"],
		"filler": "Decor",
		"brief": "One room for films and nothing else. A screen worth watching, something to sit on, and sound that fills it.",
	},
	{
		"name": "home office", "level": 3,
		"core": ["desk", "computer", "printer", "bookshelf", "cabinet"],
		"filler": "Decor",
		"brief": "I am on calls all day. Somewhere to work properly, and somewhere to file the things that pile up.",
	},
	{
		"name": "bathroom", "level": 3,
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
var _districts_by_id: Dictionary = {}


func _ready() -> void:
	for house in HOUSES:
		_by_id[house["id"]] = house
	for district in DISTRICTS:
		_districts_by_id[district["id"]] = district


func all() -> Array[Dictionary]:
	return HOUSES


## Only the houses the player can actually walk into: the ones in quarters they
## have bought. Everything else is scenery until the deeds change hands.
func unlocked() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for house in HOUSES:
		if Game.is_district_unlocked(district_of(str(house["id"]))):
			out.append(house)
	return out


# ------------------------------------------------------------------ districts

func districts() -> Array[Dictionary]:
	return DISTRICTS


func get_district(district_id: String) -> Dictionary:
	return _districts_by_id.get(district_id, {})


func district_of(house_id: String) -> String:
	var house: Dictionary = _by_id.get(house_id, {})
	return str(house.get("district", DISTRICTS[0]["id"]))


## What this client actually likes, which is the look of the street they live
## on. Somebody in Hanami Ward wants a Hanami room; somebody in Maple wants
## nothing in particular and will not mind what you bring, as long as it agrees
## with itself.
func taste_of(house_id: String) -> String:
	return str(Catalog.STYLE_BY_DISTRICT.get(district_of(house_id), Catalog.PLAIN))


## And how to say it in a sentence, for the brief.
func taste_line(house_id: String) -> String:
	var style := taste_of(house_id)
	if style == Catalog.PLAIN:
		return "No strong feelings about the look, as long as the room agrees with itself."
	return "%s has a soft spot for %s: %s" % [
		str(_by_id.get(house_id, {}).get("client", "The client")),
		Catalog.style_name(style).to_lower(),
		str(Catalog.STYLES[style]["blurb"]).to_lower()]


func houses_in(district_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for house in HOUSES:
		if str(house.get("district", "")) == district_id:
			out.append(house)
	return out


## Where a house stands in the world, once its quarter's origin is added on.
func world_position(house_id: String) -> Vector2:
	var house: Dictionary = _by_id.get(house_id, {})
	if house.is_empty():
		return Vector2.ZERO
	var district := get_district(district_of(house_id))
	var origin: Vector2 = district.get("origin", Vector2.ZERO)
	return origin + (house["map"]["pos"] as Vector2)


## Working money a quarter has to be bought with on top of its price: enough to
## shop for its cheapest brief, with room for the paint and for rounding. Buying
## a quarter and then not being able to afford a single job in it would be a
## dead end, so this is held back rather than spent.
func district_float(district_id: String) -> int:
	var lowest := 0
	for house: Dictionary in houses_in(district_id):
		var outlay := minimum_outlay(str(house["id"]))
		if lowest == 0 or outlay < lowest:
			lowest = outlay
	return int(ceilf(float(lowest) * 1.30 / 100.0)) * 100


## The span of levels and fees behind a quarter's gate, for the sales pitch.
func district_summary(district_id: String) -> Dictionary:
	var houses := houses_in(district_id)
	if houses.is_empty():
		return {}
	var low_level := 99
	var high_level := 0
	var low_fee := 1 << 30
	var high_fee := 0
	for house in houses:
		low_level = mini(low_level, int(house["level"]))
		high_level = maxi(high_level, int(house["level"]))
		low_fee = mini(low_fee, int(house["payout"]))
		high_fee = maxi(high_fee, int(house["payout"]))
	return {
		"houses": houses.size(),
		"low_level": low_level,
		"high_level": high_level,
		"low_fee": low_fee,
		"high_fee": high_fee,
	}


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


## Total floor the player has to fill: one rectangle, or the sum of a plan.
func floor_area(house_id: String) -> float:
	var job := get_job(house_id)
	if job.is_empty():
		return 0.0
	if not job.has("rooms"):
		var room: Dictionary = job["room"]
		return float(room["w"]) * float(room["d"])
	var total := 0.0
	for entry: Dictionary in job["rooms"]:
		total += float(entry["w"]) * float(entry["d"])
	return total


## How the job describes its floor on the briefing sheet.
func room_line(house_id: String) -> String:
	var job := get_job(house_id)
	if job.is_empty():
		return ""
	if not job.has("rooms"):
		var room: Dictionary = job["room"]
		return "%.1f × %.1f m  (%.0f m²)" % [room["w"], room["d"], floor_area(house_id)]
	return "%d rooms  (%.0f m²)" % [job["rooms"].size(), floor_area(house_id)]


## The names of the rooms in a plan, for the brief. Empty for a single room.
func room_names(house_id: String) -> Array[String]:
	var out: Array[String] = []
	var job := get_job(house_id)
	for entry: Variant in job.get("rooms", []):
		if typeof(entry) == TYPE_DICTIONARY:
			out.append(str((entry as Dictionary).get("name", "")))
	return out


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
		if Game.is_item_unlocked(id):
			available.append(id)
	available.shuffle()
	# Longer briefs the further on the player is. Divided so the four-piece
	# ceiling arrives around level 14, where the last of the shops opens.
	var wanted: int = clampi(2 + level / 6, 2, mini(4, available.size()))

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

	# Scaled to the floor the client actually has. A whole-floor job has no
	# single width and depth, so this asks for the area rather than reading a
	# rectangle that is not there.
	var total: int = clampi(int(floor_area(house_id) / 2.4), 5, 22)
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
		if Game.is_item_unlocked(id):
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

	# "Furnish with at least N pieces" — top up with the cheapest decor. A brief
	# for a flat can ask room by room, and then the whole floor needs at least
	# the sum of what its rooms were promised.
	var whole_floor := 0
	var per_room := 0
	for req: Dictionary in job["requirements"]:
		if str(req.get("type", "")) != "total":
			continue
		if str(req.get("room", "")) == "":
			whole_floor = maxi(whole_floor, int(req.get("count", 1)))
		else:
			per_room += int(req.get("count", 1))

	var required: int = maxi(whole_floor, per_room)
	if required > 0:
		var placed := 0
		for count: int in wanted.values():
			placed += count
		var filler := _cheapest_in("Decor")
		if filler != "" and required > placed:
			wanted[filler] = int(wanted.get(filler, 0)) + (required - placed)

	return wanted


func _count_in_category(wanted: Dictionary, category: String) -> int:
	var total := 0
	for item_id: String in wanted:
		if Catalog.category_of(item_id) == category:
			total += int(wanted[item_id])
	return total


## The cheapest thing in a category that stands on the floor and that the
## player can actually walk into a shop and buy. Tabletop props are skipped: a
## brief asking for another piece of furniture should not be satisfied by a
## stack of books left on the boards. Stock behind a quarter the player has not
## bought is skipped too, or the shopping list would ask for the unbuyable.
func _cheapest_in(category: String) -> String:
	var best := ""
	var best_price := 1 << 30
	for id in Catalog.ids_in(category):
		if Catalog.is_stackable(id) or not Game.is_item_unlocked(id):
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
	# Rooms are named in the plan, so a requirement only has to carry the id.
	var names: Dictionary = {}
	for entry: Variant in job.get("rooms", []):
		if typeof(entry) == TYPE_DICTIONARY:
			names[str((entry as Dictionary)["id"])] = str((entry as Dictionary).get("name", ""))
	for req: Dictionary in job["requirements"]:
		var scope := str(req.get("room", ""))
		if scope != "" and names.has(scope):
			req = req.duplicate()
			req["room_name"] = names[scope]
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
	var room: Dictionary = context.get("room", {})
	var kind: String = str(req.get("type", ""))
	var need: int = int(req.get("count", 1))
	var have := 0
	var met := false
	var label := ""

	# A brief for a flat can pin a line to one of its rooms, in which case only
	# what is standing in that room counts towards it.
	var scope := str(req.get("room", ""))
	var items: Array = context.get("items", [])
	if scope != "":
		var in_scope: Array = []
		for entry: Dictionary in items:
			if str(entry.get("room", "")) == scope:
				in_scope.append(entry)
		items = in_scope
	var where := ""
	if scope != "":
		where = " in the %s" % str(req.get("room_name", scope)).to_lower()

	match kind:
		"item":
			var wanted: String = str(req["id"])
			for entry: Dictionary in items:
				if entry["id"] == wanted:
					have += 1
			met = have >= need
			var piece := Catalog.display_name(wanted)
			label = "Fit %s %s%s" % [_article(piece), piece, where] if need == 1 \
				else "Fit %d × %s%s" % [need, piece, where]

		"category":
			var category: String = str(req["category"])
			for entry: Dictionary in items:
				if Catalog.category_of(entry["id"]) == category:
					have += 1
			met = have >= need
			label = "Add %d %s piece%s%s" % [need, category, "" if need == 1 else "s", where]

		"total":
			have = items.size()
			met = have >= need
			label = "Furnish%s with at least %d pieces" % [where, need]

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
			# Per-room colours when the job is a floor plan. A line that names a
			# room means that room; one that does not means all of them.
			var painted: Dictionary = room.get(surface + "s", {})
			var shades: Array[Color] = []
			if painted.is_empty():
				shades.append(room.get(surface, Color.WHITE))
			elif scope != "":
				shades.append(painted.get(scope, Color.WHITE))
			else:
				for room_id: String in painted:
					shades.append(painted[room_id])
			met = not shades.is_empty()
			for shade in shades:
				if not _color_in(shade, surface, names):
					met = false
			have = 1 if met else 0
			need = 1
			label = "%s the %s%s: %s" % [
				"Lay" if surface == "floor" else "Paint",
				surface,
				where if scope != "" else ("s throughout" if painted.size() > 1 else ""),
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
