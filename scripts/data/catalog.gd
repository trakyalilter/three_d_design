extends Node
## Furniture catalog: every model in the app is described here as a small list
## of primitive parts, so the project ships with no binary mesh assets.
##
## Each entry also carries the economy data the game runs on: what it costs,
## which shop in the city sells it, and the level the player has to reach
## before that shop will sell it to them.
##
## Part dictionary keys:
##   shape : "box" | "cyl" | "sphere"
##   size  : box -> Vector3(width, height, depth)
##           cyl -> Vector3(top_radius, height, bottom_radius)
##           sphere -> Vector3(radius, height, radius)
##   pos   : centre of the part, relative to the item origin. Y = 0 is the floor.
##   mat   : material role, see MATERIALS below. "tint" uses the per-item colour
##           the user can change at runtime.
##   rot   : optional Vector3 of euler angles in degrees.

const CATEGORIES: Array[String] = [
	"Living", "Bedroom", "Dining", "Kitchen", "Bathroom", "Electronics",
	"Storage", "Decor",
]

## The shops of the city. Every one stands on the avenue of the quarter named
## in `district`, and cannot be bought from until the player owns that quarter
## and has reached `level`. `category` is empty for the paint shop, which sells
## colours rather than objects; for the rest it is the tray tab their stock
## lands in, and several shops can feed the same tab.
const SHOPS: Array[Dictionary] = [
	{
		"id": "living", "name": "Sofa & Co", "category": "Living", "district": "maple", "level": 1,
		"tagline": "Sofas, chairs and everything you sink into.",
		"color": Color(0.90, 0.55, 0.25),
	},
	{
		"id": "bedroom", "name": "Dream Beds", "category": "Bedroom", "district": "maple", "level": 1,
		"tagline": "Beds, dressers and quiet corners.",
		"color": Color(0.44, 0.42, 0.80),
	},
	{
		"id": "dining", "name": "Table Talk", "category": "Dining", "district": "maple", "level": 1,
		"tagline": "Tables and chairs for long dinners.",
		"color": Color(0.24, 0.68, 0.62),
	},
	{
		"id": "kitchen", "name": "Kitchen Works", "category": "Kitchen", "district": "maple", "level": 3,
		"tagline": "Counters, cookers and cold storage.",
		"color": Color(0.85, 0.32, 0.30),
	},
	{
		"id": "bathroom", "name": "Splash & Tile", "category": "Bathroom", "district": "maple", "level": 3,
		"tagline": "Toilets, basins, tubs and showers.",
		"color": Color(0.32, 0.72, 0.92),
	},
	{
		"id": "electronics", "name": "Volt & Wire", "category": "Electronics", "district": "maple", "level": 3,
		"tagline": "Screens, speakers and everything with a plug.",
		"color": Color(0.36, 0.40, 0.86),
	},
	{
		"id": "storage", "name": "Box & Shelf", "category": "Storage", "district": "maple", "level": 1,
		"tagline": "Wardrobes, shelving and desks.",
		"color": Color(0.62, 0.46, 0.28),
	},
	{
		"id": "decor", "name": "Little Details", "category": "Decor", "district": "maple", "level": 1,
		"tagline": "Rugs, lamps and the greenery.",
		"color": Color(0.40, 0.74, 0.42),
	},
	{
		"id": "paint", "name": "Colour House", "category": "", "district": "maple", "level": 1,
		"tagline": "Floors and walls, priced by the square metre.",
		"color": Color(0.82, 0.40, 0.68),
	},

	{
		"id": "attic", "name": "Attic & Loft", "category": "Storage",
		"district": "maple", "level": 5,
		"tagline": "The things that come down from upstairs when somebody moves.",
		"color": Color(0.74, 0.62, 0.42),
	},

	# Riverside Wharf trades in what the warehouses left behind.
	{
		"id": "salvage", "name": "Dock & Salvage", "category": "Storage",
		"district": "riverside", "level": 8,
		"tagline": "Crates, pipework and benches, straight off the quay.",
		"color": Color(0.72, 0.52, 0.28),
	},
	{
		"id": "ropewalk", "name": "Ropewalk & Co", "category": "Decor",
		"district": "riverside", "level": 8,
		"tagline": "Canvas, rope and brass, from the people who rigged the boats.",
		"color": Color(0.30, 0.58, 0.72),
	},

	# Hillside is family houses and gardens.
	{
		"id": "chandlery", "name": "The Chandlery", "category": "Kitchen",
		"district": "riverside", "level": 8,
		"tagline": "Lamps, casks and everything a galley ever needed.",
		"color": Color(0.86, 0.66, 0.30),
	},

	{
		"id": "hearth", "name": "Hearth & Home", "category": "Living",
		"district": "hillside", "level": 11,
		"tagline": "The comfortable end of the trade: seats, benches and sideboards.",
		"color": Color(0.86, 0.46, 0.34),
	},
	{
		"id": "potting", "name": "The Potting Shed", "category": "Decor",
		"district": "hillside", "level": 11,
		"tagline": "Everything green, and somewhere to stand it.",
		"color": Color(0.42, 0.68, 0.34),
	},

	{
		"id": "toybox", "name": "The Toy Cupboard", "category": "Bedroom",
		"district": "hillside", "level": 11,
		"tagline": "For the rooms with somebody small in them.",
		"color": Color(0.94, 0.58, 0.62),
	},

	# Skyline sells to people who do not ask the price.
	{
		"id": "atelier", "name": "Atelier Nine", "category": "Living",
		"district": "skyline", "level": 14,
		"tagline": "One of everything, and nothing you have seen before.",
		"color": Color(0.60, 0.42, 0.78),
	},
	{
		"id": "lumen", "name": "Lumen", "category": "Decor",
		"district": "skyline", "level": 14,
		"tagline": "Light, and the things that throw it.",
		"color": Color(0.94, 0.80, 0.34),
	},
	{
		"id": "vitrine", "name": "Vitrine", "category": "Decor",
		"district": "skyline", "level": 14,
		"tagline": "Glass, stone and things to put behind them.",
		"color": Color(0.52, 0.76, 0.80),
	},

	# Hanami Ward furnishes rooms that are meant to be mostly empty.
	{
		"id": "tatami", "name": "Tatami & Tokonoma", "category": "Living",
		"district": "hanami", "level": 19,
		"tagline": "Rush matting, low tables, and the floor as somewhere to sit.",
		"color": Color(0.78, 0.72, 0.44),
	},
	{
		"id": "washi", "name": "Washi & Lantern", "category": "Decor",
		"district": "hanami", "level": 19,
		"tagline": "Paper, light through paper, and a branch cut to length.",
		"color": Color(0.94, 0.86, 0.76),
	},
	{
		"id": "kiri", "name": "Kiri Tansu", "category": "Storage",
		"district": "hanami", "level": 19,
		"tagline": "Paulownia chests, joined and pegged, that outlive the house.",
		"color": Color(0.66, 0.48, 0.32),
	},

	# Hollow Row keeps unusual hours.
	{
		"id": "crypt", "name": "Crypt & Coffer", "category": "Bedroom",
		"district": "hollow", "level": 24,
		"tagline": "Beds for people who keep the curtains shut. Delivery after dark.",
		"color": Color(0.52, 0.34, 0.60),
	},
	{
		"id": "cauldron", "name": "The Cauldron", "category": "Kitchen",
		"district": "hollow", "level": 24,
		"tagline": "Kitchens for a household that brews as much as it cooks.",
		"color": Color(0.34, 0.56, 0.42),
	},
	{
		"id": "gargoyle", "name": "Gargoyle & Gloom", "category": "Decor",
		"district": "hollow", "level": 24,
		"tagline": "Stone, wax and things that watch the room back.",
		"color": Color(0.46, 0.42, 0.54),
	},
]

## A colour is bought once at the Colour House and then free to use in any
## room, so no money ever changes hands inside the designer. Price is set by
## the level tier the shade sits in.
const PAINT_PRICE_BY_LEVEL := [0, 160, 280, 400, 540]

## Palettes sold by the Colour House. Premium shades unlock with level.
const PAINT: Dictionary = {
	"floor": [
		{"name": "Pale Oak", "color": Color(0.72, 0.62, 0.50), "level": 1},
		{"name": "Walnut", "color": Color(0.55, 0.42, 0.30), "level": 1},
		{"name": "Espresso", "color": Color(0.36, 0.27, 0.20), "level": 1},
		{"name": "Chalk", "color": Color(0.85, 0.83, 0.80), "level": 1},
		{"name": "Concrete", "color": Color(0.62, 0.64, 0.66), "level": 3},
		{"name": "Slate", "color": Color(0.30, 0.32, 0.36), "level": 5},
		{"name": "Sandstone", "color": Color(0.74, 0.72, 0.62), "level": 4},
		{"name": "Sea Glass", "color": Color(0.52, 0.60, 0.55), "level": 8},
	],
	"wall": [
		{"name": "Cotton", "color": Color(0.92, 0.91, 0.88), "level": 1},
		{"name": "Morning", "color": Color(0.86, 0.88, 0.90), "level": 1},
		{"name": "Sage", "color": Color(0.80, 0.84, 0.79), "level": 1},
		{"name": "Linen", "color": Color(0.89, 0.84, 0.78), "level": 1},
		{"name": "Harbour", "color": Color(0.70, 0.74, 0.80), "level": 3},
		{"name": "Storm", "color": Color(0.55, 0.58, 0.64), "level": 5},
		{"name": "Blush", "color": Color(0.78, 0.72, 0.72), "level": 4},
		{"name": "Ink", "color": Color(0.36, 0.38, 0.44), "level": 8},
	],
}

## Fixed material roles. "tint" is resolved per placed item.
const MATERIALS := {
	"wood": {"color": Color(0.56, 0.38, 0.24), "rough": 0.75, "metal": 0.0},
	"wood_dark": {"color": Color(0.33, 0.21, 0.13), "rough": 0.7, "metal": 0.0},
	"wood_light": {"color": Color(0.79, 0.64, 0.45), "rough": 0.8, "metal": 0.0},
	"metal": {"color": Color(0.73, 0.75, 0.78), "rough": 0.28, "metal": 0.9},
	"white": {"color": Color(0.93, 0.93, 0.9), "rough": 0.65, "metal": 0.0},
	"porcelain": {"color": Color(0.97, 0.97, 0.96), "rough": 0.18, "metal": 0.0},
	"dark": {"color": Color(0.16, 0.17, 0.2), "rough": 0.6, "metal": 0.05},
	"screen": {"color": Color(0.05, 0.06, 0.09), "rough": 0.15, "metal": 0.0},
	"glass": {"color": Color(0.68, 0.82, 0.86, 0.35), "rough": 0.05, "metal": 0.0},
	"mirror": {"color": Color(0.80, 0.86, 0.90), "rough": 0.05, "metal": 0.85},
	"leaf": {"color": Color(0.28, 0.55, 0.26), "rough": 0.85, "metal": 0.0},
	"soil": {"color": Color(0.29, 0.22, 0.17), "rough": 1.0, "metal": 0.0},
	"steel": {"color": Color(0.85, 0.86, 0.88), "rough": 0.35, "metal": 0.75},
	"towel": {"color": Color(0.86, 0.88, 0.92), "rough": 0.95, "metal": 0.0},
}

## Colour swatches offered for the selected item's tint.
const SWATCHES: Array[Color] = [
	Color(0.85, 0.86, 0.88),
	Color(0.35, 0.38, 0.44),
	Color(0.18, 0.19, 0.22),
	Color(0.78, 0.32, 0.29),
	Color(0.87, 0.60, 0.28),
	Color(0.90, 0.79, 0.44),
	Color(0.40, 0.62, 0.42),
	Color(0.30, 0.53, 0.72),
	Color(0.45, 0.38, 0.66),
	Color(0.80, 0.52, 0.63),
	Color(0.56, 0.38, 0.24),
	Color(0.62, 0.58, 0.50),
]

var _items: Dictionary = {}
var _order: Array[String] = []
var _shops_by_id: Dictionary = {}


func _ready() -> void:
	for shop in SHOPS:
		_shops_by_id[shop["id"]] = shop
	_build()
	_build_electronics()
	_build_extras()
	_build_riverside()
	_build_hillside()
	_build_skyline()
	_build_second_wave()
	_build_hanami()
	_build_hollow()


func _build() -> void:
	# ---------------------------------------------------------------- Living
	_add({
		"id": "sofa", "against_wall": true, "name": "Sofa", "category": "Living",
		"price": 480, "level": 1,
		"tint": Color(0.35, 0.38, 0.44),
		"parts": _sofa(2.05, 0.9),
	})
	_add({
		"id": "loveseat", "against_wall": true, "name": "Loveseat", "category": "Living",
		"price": 360, "level": 1,
		"tint": Color(0.40, 0.62, 0.42),
		"parts": _sofa(1.45, 0.9),
	})
	_add({
		"id": "armchair", "name": "Armchair", "category": "Living",
		"price": 240, "level": 1,
		"tint": Color(0.78, 0.32, 0.29),
		"parts": _sofa(0.95, 0.88),
	})
	_add({
		"id": "coffee_table", "surface": 0.42, "name": "Coffee Table", "category": "Living",
		"price": 150, "level": 1,
		"tint": Color(0.56, 0.38, 0.24),
		"parts": _table(1.10, 0.60, 0.42, 0.05),
	})
	_add({
		"id": "tv_stand", "against_wall": true, "surface": 0.52, "name": "TV Stand", "category": "Living",
		"price": 220, "level": 3,
		"tint": Color(0.33, 0.21, 0.13),
		"parts": [
			{"shape": "box", "size": Vector3(1.50, 0.06, 0.42), "pos": Vector3(0, 0.49, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.50, 0.06, 0.42), "pos": Vector3(0, 0.24, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.06, 0.50, 0.42), "pos": Vector3(-0.72, 0.25, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.06, 0.50, 0.42), "pos": Vector3(0.72, 0.25, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.50, 0.04, 0.04), "pos": Vector3(0, 0.02, -0.18), "mat": "dark"},
		],
	})
	_add({
		"id": "television", "stackable": true, "name": "Television", "category": "Electronics",
		"price": 520, "level": 5,
		"tint": Color(0.16, 0.17, 0.2),
		"parts": [
			{"shape": "box", "size": Vector3(0.40, 0.03, 0.22), "pos": Vector3(0, 0.015, 0), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.06, 0.18, 0.06), "pos": Vector3(0, 0.10, 0), "mat": "dark"},
			{"shape": "box", "size": Vector3(1.22, 0.70, 0.05), "pos": Vector3(0, 0.55, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.16, 0.64, 0.01), "pos": Vector3(0, 0.55, 0.032), "mat": "screen"},
		],
	})

	# --------------------------------------------------------------- Bedroom
	_add({
		"id": "bed_double", "against_wall": true, "name": "Double Bed", "category": "Bedroom",
		"price": 620, "level": 3,
		"tint": Color(0.30, 0.53, 0.72),
		"parts": _bed(1.62, 2.05),
	})
	_add({
		"id": "bed_single", "against_wall": true, "name": "Single Bed", "category": "Bedroom",
		"price": 380, "level": 1,
		"tint": Color(0.87, 0.60, 0.28),
		"parts": _bed(1.00, 1.95),
	})
	_add({
		"id": "nightstand", "against_wall": true, "surface": 0.58, "name": "Nightstand", "category": "Bedroom",
		"price": 130, "level": 1,
		"tint": Color(0.79, 0.64, 0.45),
		"parts": [
			{"shape": "box", "size": Vector3(0.46, 0.50, 0.40), "pos": Vector3(0, 0.33, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.40, 0.16, 0.02), "pos": Vector3(0, 0.44, 0.205), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.40, 0.16, 0.02), "pos": Vector3(0, 0.24, 0.205), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.015, 0.10, 0.015), "pos": Vector3(-0.16, 0.04, -0.14), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.015, 0.10, 0.015), "pos": Vector3(0.16, 0.04, -0.14), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.015, 0.10, 0.015), "pos": Vector3(-0.16, 0.04, 0.14), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.015, 0.10, 0.015), "pos": Vector3(0.16, 0.04, 0.14), "mat": "metal"},
		],
	})
	_add({
		"id": "dresser", "against_wall": true, "surface": 0.925, "name": "Dresser", "category": "Bedroom",
		"price": 340, "level": 3,
		"tint": Color(0.62, 0.58, 0.50),
		"parts": [
			{"shape": "box", "size": Vector3(1.20, 0.85, 0.48), "pos": Vector3(0, 0.50, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.10, 0.22, 0.02), "pos": Vector3(0, 0.78, 0.245), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.10, 0.22, 0.02), "pos": Vector3(0, 0.51, 0.245), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.10, 0.22, 0.02), "pos": Vector3(0, 0.24, 0.245), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.20, 0.08, 0.48), "pos": Vector3(0, 0.04, 0), "mat": "dark"},
		],
	})

	# ---------------------------------------------------------------- Dining
	_add({
		"id": "dining_table", "surface": 0.74, "name": "Dining Table", "category": "Dining",
		"price": 420, "level": 1,
		"tint": Color(0.56, 0.38, 0.24),
		"parts": _table(1.70, 0.95, 0.74, 0.06),
	})
	_add({
		"id": "round_table", "surface": 0.78, "name": "Round Table", "category": "Dining",
		"price": 350, "level": 3,
		"tint": Color(0.79, 0.64, 0.45),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.60, 0.06, 0.60), "pos": Vector3(0, 0.75, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.07, 0.72, 0.07), "pos": Vector3(0, 0.36, 0), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.32, 0.05, 0.36), "pos": Vector3(0, 0.025, 0), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "chair", "name": "Chair", "category": "Dining",
		"price": 90, "level": 1,
		"tint": Color(0.33, 0.21, 0.13),
		"parts": [
			{"shape": "box", "size": Vector3(0.44, 0.05, 0.44), "pos": Vector3(0, 0.44, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.44, 0.52, 0.05), "pos": Vector3(0, 0.72, -0.195), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.05, 0.44, 0.05), "pos": Vector3(-0.18, 0.22, -0.17), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.05, 0.44, 0.05), "pos": Vector3(0.18, 0.22, -0.17), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.05, 0.44, 0.05), "pos": Vector3(-0.18, 0.22, 0.17), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.05, 0.44, 0.05), "pos": Vector3(0.18, 0.22, 0.17), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "bar_stool", "name": "Bar Stool", "category": "Dining",
		"price": 110, "level": 5,
		"tint": Color(0.16, 0.17, 0.2),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.19, 0.07, 0.19), "pos": Vector3(0, 0.72, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.04, 0.69, 0.04), "pos": Vector3(0, 0.35, 0), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.22, 0.03, 0.22), "pos": Vector3(0, 0.015, 0), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.15, 0.02, 0.15), "pos": Vector3(0, 0.24, 0), "mat": "metal"},
		],
	})

	# --------------------------------------------------------------- Kitchen
	_add({
		"id": "counter", "against_wall": true, "surface": 0.91, "name": "Counter", "category": "Kitchen",
		"price": 380, "level": 1,
		"tint": Color(0.93, 0.93, 0.9),
		"parts": [
			{"shape": "box", "size": Vector3(1.20, 0.82, 0.62), "pos": Vector3(0, 0.45, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.24, 0.05, 0.66), "pos": Vector3(0, 0.885, 0), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.56, 0.74, 0.02), "pos": Vector3(-0.30, 0.45, 0.315), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.56, 0.74, 0.02), "pos": Vector3(0.30, 0.45, 0.315), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(1.20, 0.08, 0.58), "pos": Vector3(0, 0.04, 0), "mat": "dark"},
		],
	})
	_add({
		"id": "fridge", "against_wall": true, "name": "Refrigerator", "category": "Kitchen",
		"price": 700, "level": 3,
		"tint": Color(0.85, 0.86, 0.88),
		"parts": [
			{"shape": "box", "size": Vector3(0.72, 1.82, 0.70), "pos": Vector3(0, 0.91, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.70, 1.14, 0.02), "pos": Vector3(0, 1.23, 0.355), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.70, 0.60, 0.02), "pos": Vector3(0, 0.32, 0.355), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.04, 0.60, 0.05), "pos": Vector3(0.28, 1.10, 0.39), "mat": "metal"},
			{"shape": "box", "size": Vector3(0.04, 0.34, 0.05), "pos": Vector3(0.28, 0.42, 0.39), "mat": "metal"},
		],
	})
	_add({
		"id": "stove", "against_wall": true, "name": "Stove", "category": "Kitchen",
		"price": 540, "level": 5,
		"tint": Color(0.16, 0.17, 0.2),
		"parts": [
			{"shape": "box", "size": Vector3(0.60, 0.86, 0.62), "pos": Vector3(0, 0.47, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.62, 0.03, 0.64), "pos": Vector3(0, 0.905, 0), "mat": "dark"},
			{"shape": "cyl", "size": Vector3(0.09, 0.01, 0.09), "pos": Vector3(-0.14, 0.923, -0.14), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.09, 0.01, 0.09), "pos": Vector3(0.14, 0.923, -0.14), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.09, 0.01, 0.09), "pos": Vector3(-0.14, 0.923, 0.14), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.09, 0.01, 0.09), "pos": Vector3(0.14, 0.923, 0.14), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.48, 0.40, 0.02), "pos": Vector3(0, 0.42, 0.315), "mat": "glass"},
			{"shape": "box", "size": Vector3(0.44, 0.04, 0.05), "pos": Vector3(0, 0.68, 0.34), "mat": "metal"},
			{"shape": "box", "size": Vector3(0.60, 0.08, 0.58), "pos": Vector3(0, 0.04, 0), "mat": "dark"},
		],
	})
	_add({
		"id": "sink_unit", "against_wall": true, "surface": 0.91, "name": "Sink Unit", "category": "Kitchen",
		"price": 430, "level": 3,
		"tint": Color(0.93, 0.93, 0.9),
		"parts": [
			{"shape": "box", "size": Vector3(0.90, 0.82, 0.62), "pos": Vector3(0, 0.45, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.94, 0.05, 0.66), "pos": Vector3(0, 0.885, 0), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.46, 0.03, 0.36), "pos": Vector3(-0.14, 0.90, 0), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.02, 0.26, 0.02), "pos": Vector3(-0.14, 1.03, -0.20), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.02, 0.02, 0.18), "pos": Vector3(-0.14, 1.15, -0.12), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.90, 0.08, 0.58), "pos": Vector3(0, 0.04, 0), "mat": "dark"},
		],
	})

	# -------------------------------------------------------------- Bathroom
	_add({
		"id": "toilet", "against_wall": true, "name": "Toilet", "category": "Bathroom",
		"price": 280, "level": 1,
		"tint": Color(0.97, 0.97, 0.96),
		"parts": [
			{"shape": "box", "size": Vector3(0.40, 0.58, 0.20), "pos": Vector3(0, 0.34, -0.24), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.42, 0.04, 0.22), "pos": Vector3(0, 0.65, -0.24), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.03, 0.02, 0.03), "pos": Vector3(0, 0.675, -0.24), "mat": "metal"},
			{"shape": "box", "size": Vector3(0.20, 0.24, 0.26), "pos": Vector3(0, 0.12, 0.02), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.19, 0.22, 0.15), "pos": Vector3(0, 0.33, 0.10), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.20, 0.04, 0.20), "pos": Vector3(0, 0.45, 0.10), "mat": "porcelain"},
			{"shape": "cyl", "size": Vector3(0.20, 0.03, 0.20), "pos": Vector3(0, 0.49, 0.10), "mat": "dark"},
		],
	})
	_add({
		"id": "basin", "against_wall": true, "name": "Basin", "category": "Bathroom",
		"price": 220, "level": 1,
		"tint": Color(0.97, 0.97, 0.96),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.09, 0.72, 0.14), "pos": Vector3(0, 0.36, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.56, 0.14, 0.42), "pos": Vector3(0, 0.79, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.40, 0.05, 0.28), "pos": Vector3(0, 0.865, 0.03), "mat": "porcelain"},
			{"shape": "cyl", "size": Vector3(0.02, 0.16, 0.025), "pos": Vector3(0, 0.94, -0.15), "mat": "metal"},
			{"shape": "box", "size": Vector3(0.03, 0.03, 0.13), "pos": Vector3(0, 1.01, -0.10), "mat": "metal"},
		],
	})
	_add({
		"id": "bathtub", "against_wall": true, "name": "Bathtub", "category": "Bathroom",
		"price": 780, "level": 5,
		"tint": Color(0.97, 0.97, 0.96),
		"parts": [
			{"shape": "box", "size": Vector3(1.70, 0.52, 0.76), "pos": Vector3(0, 0.26, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.56, 0.06, 0.62), "pos": Vector3(0, 0.50, 0), "mat": "porcelain"},
			{"shape": "box", "size": Vector3(1.50, 0.10, 0.56), "pos": Vector3(0, 0.44, 0), "mat": "glass"},
			{"shape": "cyl", "size": Vector3(0.02, 0.20, 0.025), "pos": Vector3(-0.78, 0.62, 0), "mat": "metal"},
			{"shape": "box", "size": Vector3(0.14, 0.03, 0.03), "pos": Vector3(-0.71, 0.71, 0), "mat": "metal"},
		],
	})
	_add({
		"id": "shower", "against_wall": true, "name": "Shower", "category": "Bathroom",
		"price": 620, "level": 3,
		"tint": Color(0.85, 0.86, 0.88),
		"parts": [
			{"shape": "box", "size": Vector3(0.92, 0.12, 0.92), "pos": Vector3(0, 0.06, 0), "mat": "porcelain"},
			{"shape": "box", "size": Vector3(0.92, 1.98, 0.05), "pos": Vector3(0, 1.11, -0.44), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.05, 1.98, 0.92), "pos": Vector3(-0.44, 1.11, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.86, 1.90, 0.03), "pos": Vector3(0, 1.09, 0.44), "mat": "glass"},
			{"shape": "box", "size": Vector3(0.03, 1.90, 0.86), "pos": Vector3(0.44, 1.09, 0), "mat": "glass"},
			{"shape": "box", "size": Vector3(0.04, 0.04, 0.26), "pos": Vector3(0, 1.94, -0.30), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.10, 0.03, 0.10), "pos": Vector3(0, 1.90, -0.18), "mat": "metal"},
		],
	})
	_add({
		"id": "washing_machine", "against_wall": true, "name": "Washing Machine", "category": "Bathroom",
		"price": 560, "level": 5,
		"tint": Color(0.93, 0.93, 0.9),
		"parts": [
			{"shape": "box", "size": Vector3(0.60, 0.86, 0.62), "pos": Vector3(0, 0.43, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.52, 0.10, 0.02), "pos": Vector3(0, 0.76, 0.315), "mat": "dark"},
			{"shape": "cyl", "size": Vector3(0.20, 0.04, 0.20), "pos": Vector3(0, 0.40, 0.315), "mat": "steel", "rot": Vector3(90, 0, 0)},
			{"shape": "cyl", "size": Vector3(0.15, 0.03, 0.15), "pos": Vector3(0, 0.40, 0.33), "mat": "glass", "rot": Vector3(90, 0, 0)},
			{"shape": "cyl", "size": Vector3(0.03, 0.03, 0.03), "pos": Vector3(0.22, 0.76, 0.33), "mat": "metal", "rot": Vector3(90, 0, 0)},
		],
	})
	_add({
		"id": "vanity_unit", "against_wall": true, "surface": 0.72, "name": "Vanity Unit", "category": "Bathroom",
		"price": 340, "level": 3,
		"tint": Color(0.62, 0.58, 0.50),
		"parts": [
			{"shape": "box", "size": Vector3(0.78, 0.62, 0.42), "pos": Vector3(0, 0.35, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.82, 0.06, 0.46), "pos": Vector3(0, 0.69, 0), "mat": "porcelain"},
			{"shape": "box", "size": Vector3(0.44, 0.05, 0.30), "pos": Vector3(0, 0.735, 0.02), "mat": "porcelain"},
			{"shape": "cyl", "size": Vector3(0.02, 0.16, 0.025), "pos": Vector3(0, 0.80, -0.16), "mat": "metal"},
			{"shape": "box", "size": Vector3(0.72, 1.10, 0.04), "pos": Vector3(0, 1.28, -0.19), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.60, 0.86, 0.02), "pos": Vector3(0, 1.30, -0.16), "mat": "mirror"},
			{"shape": "box", "size": Vector3(0.36, 0.02, 0.02), "pos": Vector3(0, 0.42, 0.215), "mat": "metal"},
		],
	})
	_add({
		"id": "towel_rail", "name": "Towel Rail", "category": "Bathroom",
		"price": 70, "level": 1,
		"tint": Color(0.85, 0.86, 0.88),
		"parts": [
			{"shape": "box", "size": Vector3(0.46, 0.03, 0.30), "pos": Vector3(0, 0.015, 0), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.02, 0.92, 0.02), "pos": Vector3(-0.22, 0.46, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.02, 0.92, 0.02), "pos": Vector3(0.22, 0.46, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.46, 0.03, 0.03), "pos": Vector3(0, 0.90, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.46, 0.03, 0.03), "pos": Vector3(0, 0.60, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.30, 0.34, 0.05), "pos": Vector3(-0.06, 0.73, 0.03), "mat": "towel"},
			{"shape": "box", "size": Vector3(0.22, 0.26, 0.05), "pos": Vector3(0.14, 0.48, 0.03), "mat": "towel"},
		],
	})

	# --------------------------------------------------------------- Storage
	_add({
		"id": "wardrobe", "against_wall": true, "name": "Wardrobe", "category": "Storage",
		"price": 560, "level": 3,
		"tint": Color(0.93, 0.93, 0.9),
		"parts": [
			{"shape": "box", "size": Vector3(1.25, 2.05, 0.62), "pos": Vector3(0, 1.05, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.59, 1.94, 0.02), "pos": Vector3(-0.31, 1.06, 0.315), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.59, 1.94, 0.02), "pos": Vector3(0.31, 1.06, 0.315), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.012, 0.22, 0.012), "pos": Vector3(-0.05, 1.05, 0.335), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.012, 0.22, 0.012), "pos": Vector3(0.05, 1.05, 0.335), "mat": "metal"},
			{"shape": "box", "size": Vector3(1.25, 0.08, 0.62), "pos": Vector3(0, 0.04, 0), "mat": "dark"},
		],
	})
	_add({
		"id": "bookshelf", "against_wall": true, "name": "Bookshelf", "category": "Storage",
		"price": 290, "level": 1, "surface": 1.855,
		"tint": Color(0.56, 0.38, 0.24),
		"parts": [
			{"shape": "box", "size": Vector3(0.05, 1.85, 0.34), "pos": Vector3(-0.42, 0.93, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.05, 1.85, 0.34), "pos": Vector3(0.42, 0.93, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.89, 0.03, 0.30), "pos": Vector3(0, 1.83, -0.02), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.80, 0.04, 0.34), "pos": Vector3(0, 0.03, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.80, 0.04, 0.34), "pos": Vector3(0, 0.48, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.80, 0.04, 0.34), "pos": Vector3(0, 0.93, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.80, 0.04, 0.34), "pos": Vector3(0, 1.38, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.30, 0.28, 0.20), "pos": Vector3(-0.22, 0.64, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.22, 0.24, 0.20), "pos": Vector3(0.20, 1.07, 0), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.26, 0.26, 0.20), "pos": Vector3(-0.14, 1.53, 0), "mat": "wood_light"},
		],
	})
	_add({
		"id": "desk", "against_wall": true, "surface": 0.755, "name": "Desk", "category": "Storage",
		"price": 330, "level": 3,
		"tint": Color(0.93, 0.93, 0.9),
		"parts": [
			{"shape": "box", "size": Vector3(1.40, 0.05, 0.68), "pos": Vector3(0, 0.73, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.42, 0.60, 0.60), "pos": Vector3(0.47, 0.36, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.36, 0.15, 0.02), "pos": Vector3(0.47, 0.56, 0.305), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.36, 0.15, 0.02), "pos": Vector3(0.47, 0.36, 0.305), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.04, 0.71, 0.04), "pos": Vector3(-0.66, 0.36, -0.30), "mat": "metal"},
			{"shape": "box", "size": Vector3(0.04, 0.71, 0.04), "pos": Vector3(-0.66, 0.36, 0.30), "mat": "metal"},
		],
	})
	_add({
		"id": "cabinet", "against_wall": true, "surface": 0.84, "name": "Low Cabinet", "category": "Storage",
		"price": 260, "level": 5,
		"tint": Color(0.45, 0.38, 0.66),
		"parts": [
			{"shape": "box", "size": Vector3(0.90, 0.80, 0.42), "pos": Vector3(0, 0.44, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.41, 0.72, 0.02), "pos": Vector3(-0.22, 0.44, 0.215), "mat": "white"},
			{"shape": "box", "size": Vector3(0.41, 0.72, 0.02), "pos": Vector3(0.22, 0.44, 0.215), "mat": "white"},
			{"shape": "box", "size": Vector3(0.90, 0.08, 0.42), "pos": Vector3(0, 0.04, 0), "mat": "dark"},
		],
	})

	# ----------------------------------------------------------------- Decor
	_add({
		"id": "rug", "name": "Rug", "category": "Decor",
		"price": 160, "level": 1,
		"tint": Color(0.78, 0.32, 0.29),
		"parts": [
			{"shape": "box", "size": Vector3(2.20, 0.02, 1.55), "pos": Vector3(0, 0.01, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.90, 0.022, 1.25), "pos": Vector3(0, 0.012, 0), "mat": "white"},
			{"shape": "box", "size": Vector3(1.60, 0.024, 0.95), "pos": Vector3(0, 0.014, 0), "mat": "tint"},
		],
	})
	_add({
		"id": "floor_lamp", "name": "Floor Lamp", "category": "Decor",
		"price": 140, "level": 1,
		"tint": Color(0.90, 0.79, 0.44),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.20, 0.03, 0.22), "pos": Vector3(0, 0.015, 0), "mat": "dark"},
			{"shape": "cyl", "size": Vector3(0.02, 1.42, 0.02), "pos": Vector3(0, 0.72, 0), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.17, 0.30, 0.23), "pos": Vector3(0, 1.55, 0), "mat": "tint"},
		],
	})
	_add({
		"id": "plant", "stackable": true, "name": "Potted Plant", "category": "Decor",
		"price": 90, "level": 1,
		"tint": Color(0.62, 0.58, 0.50),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.20, 0.34, 0.15), "pos": Vector3(0, 0.17, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.185, 0.03, 0.185), "pos": Vector3(0, 0.335, 0), "mat": "soil"},
			{"shape": "cyl", "size": Vector3(0.025, 0.40, 0.035), "pos": Vector3(0, 0.54, 0), "mat": "wood_dark"},
			{"shape": "sphere", "size": Vector3(0.30, 0.44, 0.30), "pos": Vector3(0, 0.88, 0), "mat": "leaf"},
			{"shape": "sphere", "size": Vector3(0.19, 0.26, 0.19), "pos": Vector3(0.16, 0.72, 0.08), "mat": "leaf"},
			{"shape": "sphere", "size": Vector3(0.16, 0.22, 0.16), "pos": Vector3(-0.14, 0.78, -0.10), "mat": "leaf"},
		],
	})
	_add({
		"id": "table_lamp", "stackable": true, "name": "Table Lamp", "category": "Decor",
		"price": 80, "level": 1,
		"tint": Color(0.90, 0.79, 0.44),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.11, 0.02, 0.12), "pos": Vector3(0, 0.01, 0), "mat": "dark"},
			{"shape": "cyl", "size": Vector3(0.025, 0.26, 0.035), "pos": Vector3(0, 0.14, 0), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.10, 0.19, 0.15), "pos": Vector3(0, 0.36, 0), "mat": "tint"},
		],
	})
	_add({
		"id": "side_table", "surface": 0.52, "name": "Side Table", "category": "Decor",
		"price": 120, "level": 1,
		"tint": Color(0.16, 0.17, 0.2),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.26, 0.04, 0.26), "pos": Vector3(0, 0.52, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.025, 0.50, 0.025), "pos": Vector3(0, 0.25, 0), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.20, 0.02, 0.22), "pos": Vector3(0, 0.01, 0), "mat": "metal"},
		],
	})
	_add({
		"id": "partition", "against_wall": true, "name": "Partition", "category": "Decor",
		"price": 210, "level": 8,
		"tint": Color(0.62, 0.58, 0.50),
		"parts": [
			{"shape": "box", "size": Vector3(1.40, 1.75, 0.06), "pos": Vector3(0, 0.90, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.44, 0.06, 0.28), "pos": Vector3(0, 0.03, 0), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.04, 1.75, 0.08), "pos": Vector3(-0.46, 0.90, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.04, 1.75, 0.08), "pos": Vector3(0.46, 0.90, 0), "mat": "wood_dark"},
		],
	})


## The second pass over every other category, filling out the ranges.
func _build_extras() -> void:
	# ---------------------------------------------------------------- Living
	_add({
		"id": "recliner", "against_wall": true, "name": "Recliner",
		"category": "Living", "price": 380, "level": 5,
		"tint": Color(0.40, 0.30, 0.26),
		"parts": [
			{"shape": "box", "size": Vector3(0.90, 0.34, 0.92), "pos": Vector3(0, 0.24, -0.04), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.90, 0.66, 0.20), "pos": Vector3(0, 0.70, -0.40), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.16, 0.32, 0.92), "pos": Vector3(-0.37, 0.57, -0.04), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.16, 0.32, 0.92), "pos": Vector3(0.37, 0.57, -0.04), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.56, 0.14, 0.66), "pos": Vector3(0, 0.48, 0.02), "mat": "white"},
			{"shape": "box", "size": Vector3(0.72, 0.14, 0.36), "pos": Vector3(0, 0.30, 0.60), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.80, 0.08, 0.80), "pos": Vector3(0, 0.04, -0.04), "mat": "dark"},
		],
	})
	_add({
		"id": "footstool", "name": "Footstool",
		"category": "Living", "price": 110, "level": 1,
		"tint": Color(0.62, 0.46, 0.38),
		"parts": [
			{"shape": "box", "size": Vector3(0.50, 0.18, 0.50), "pos": Vector3(0, 0.31, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.03, 0.22, 0.03), "pos": Vector3(-0.18, 0.11, -0.18), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.03, 0.22, 0.03), "pos": Vector3(0.18, 0.11, -0.18), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.03, 0.22, 0.03), "pos": Vector3(-0.18, 0.11, 0.18), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.03, 0.22, 0.03), "pos": Vector3(0.18, 0.11, 0.18), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "console_table", "against_wall": true, "surface": 0.78,
		"name": "Console Table", "category": "Living", "price": 210, "level": 3,
		"tint": Color(0.50, 0.36, 0.26),
		"parts": [
			{"shape": "box", "size": Vector3(1.10, 0.05, 0.35), "pos": Vector3(0, 0.755, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.00, 0.03, 0.30), "pos": Vector3(0, 0.26, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.05, 0.73, 0.05), "pos": Vector3(-0.51, 0.37, -0.14), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.05, 0.73, 0.05), "pos": Vector3(0.51, 0.37, -0.14), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.05, 0.73, 0.05), "pos": Vector3(-0.51, 0.37, 0.14), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.05, 0.73, 0.05), "pos": Vector3(0.51, 0.37, 0.14), "mat": "wood_dark"},
		],
	})

	# --------------------------------------------------------------- Bedroom
	_add({
		"id": "bunk_bed", "against_wall": true, "name": "Bunk Bed",
		"category": "Bedroom", "price": 780, "level": 8,
		"tint": Color(0.58, 0.44, 0.32),
		"parts": [
			{"shape": "box", "size": Vector3(1.00, 0.18, 2.00), "pos": Vector3(0, 0.30, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.94, 0.18, 1.94), "pos": Vector3(0, 0.48, 0), "mat": "white"},
			{"shape": "box", "size": Vector3(1.00, 0.18, 2.00), "pos": Vector3(0, 1.38, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.94, 0.18, 1.94), "pos": Vector3(0, 1.56, 0), "mat": "white"},
			{"shape": "box", "size": Vector3(0.08, 1.78, 0.08), "pos": Vector3(-0.46, 0.89, -0.96), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.08, 1.78, 0.08), "pos": Vector3(0.46, 0.89, -0.96), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.08, 1.78, 0.08), "pos": Vector3(-0.46, 0.89, 0.96), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.08, 1.78, 0.08), "pos": Vector3(0.46, 0.89, 0.96), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.00, 0.26, 0.05), "pos": Vector3(0, 1.78, -0.96), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.34, 0.04, 0.04), "pos": Vector3(0.28, 0.62, 1.00), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.34, 0.04, 0.04), "pos": Vector3(0.28, 0.96, 1.00), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.34, 0.04, 0.04), "pos": Vector3(0.28, 1.30, 1.00), "mat": "wood_light"},
		],
	})
	_add({
		"id": "crib", "against_wall": true, "name": "Crib",
		"category": "Bedroom", "price": 300, "level": 5,
		"tint": Color(0.90, 0.89, 0.86),
		"parts": [
			{"shape": "box", "size": Vector3(0.70, 0.08, 1.30), "pos": Vector3(0, 0.40, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.64, 0.12, 1.24), "pos": Vector3(0, 0.50, 0), "mat": "white"},
			{"shape": "box", "size": Vector3(0.70, 0.55, 0.04), "pos": Vector3(0, 0.74, -0.63), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.70, 0.55, 0.04), "pos": Vector3(0, 0.74, 0.63), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.04, 0.55, 1.30), "pos": Vector3(-0.33, 0.74, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.04, 0.55, 1.30), "pos": Vector3(0.33, 0.74, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.08, 0.36, 0.08), "pos": Vector3(-0.31, 0.18, -0.61), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.08, 0.36, 0.08), "pos": Vector3(0.31, 0.18, -0.61), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.08, 0.36, 0.08), "pos": Vector3(-0.31, 0.18, 0.61), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.08, 0.36, 0.08), "pos": Vector3(0.31, 0.18, 0.61), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "dressing_table", "against_wall": true, "surface": 0.76,
		"name": "Dressing Table", "category": "Bedroom", "price": 360, "level": 5,
		"tint": Color(0.86, 0.82, 0.78),
		"parts": [
			{"shape": "box", "size": Vector3(1.00, 0.05, 0.45), "pos": Vector3(0, 0.735, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.90, 0.16, 0.40), "pos": Vector3(0, 0.62, 0.01), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.84, 0.10, 0.02), "pos": Vector3(0, 0.62, 0.215), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.05, 0.71, 0.05), "pos": Vector3(-0.46, 0.36, -0.18), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.05, 0.71, 0.05), "pos": Vector3(0.46, 0.36, -0.18), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.05, 0.71, 0.05), "pos": Vector3(-0.46, 0.36, 0.18), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.05, 0.71, 0.05), "pos": Vector3(0.46, 0.36, 0.18), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.62, 0.82, 0.04), "pos": Vector3(0, 1.20, -0.19), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.52, 0.72, 0.02), "pos": Vector3(0, 1.20, -0.16), "mat": "mirror"},
		],
	})
	_add({
		"id": "laundry_basket", "name": "Laundry Basket",
		"category": "Bedroom", "price": 70, "level": 1,
		"tint": Color(0.78, 0.72, 0.60),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.21, 0.50, 0.18), "pos": Vector3(0, 0.25, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.22, 0.03, 0.22), "pos": Vector3(0, 0.51, 0), "mat": "white"},
		],
	})

	# ---------------------------------------------------------------- Dining
	_add({
		"id": "dining_bench", "name": "Dining Bench",
		"category": "Dining", "price": 180, "level": 3,
		"tint": Color(0.50, 0.36, 0.24),
		"parts": [
			{"shape": "box", "size": Vector3(1.40, 0.06, 0.35), "pos": Vector3(0, 0.43, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.05, 0.40, 0.32), "pos": Vector3(-0.62, 0.20, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.05, 0.40, 0.32), "pos": Vector3(0.62, 0.20, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.20, 0.05, 0.05), "pos": Vector3(0, 0.14, 0), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "kitchen_island", "surface": 0.96, "name": "Kitchen Island",
		"category": "Dining", "price": 680, "level": 8,
		"tint": Color(0.90, 0.89, 0.86),
		"parts": [
			{"shape": "box", "size": Vector3(1.60, 0.86, 0.90), "pos": Vector3(0, 0.47, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.70, 0.06, 1.00), "pos": Vector3(0, 0.93, 0), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.72, 0.76, 0.02), "pos": Vector3(-0.40, 0.47, 0.455), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.72, 0.76, 0.02), "pos": Vector3(0.40, 0.47, 0.455), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(1.55, 0.08, 0.85), "pos": Vector3(0, 0.04, 0), "mat": "dark"},
		],
	})

	# --------------------------------------------------------------- Kitchen
	_add({
		"id": "dishwasher", "against_wall": true, "name": "Dishwasher",
		"category": "Kitchen", "price": 560, "level": 5,
		"tint": Color(0.88, 0.89, 0.90),
		"parts": [
			{"shape": "box", "size": Vector3(0.60, 0.86, 0.62), "pos": Vector3(0, 0.43, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.56, 0.78, 0.02), "pos": Vector3(0, 0.44, 0.315), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.50, 0.04, 0.05), "pos": Vector3(0, 0.78, 0.34), "mat": "metal"},
			{"shape": "box", "size": Vector3(0.14, 0.02, 0.01), "pos": Vector3(-0.16, 0.83, 0.33), "mat": "screen"},
		],
	})
	_add({
		"id": "pantry", "against_wall": true, "name": "Pantry Cupboard",
		"category": "Kitchen", "price": 500, "level": 5,
		"tint": Color(0.90, 0.89, 0.86),
		"parts": [
			{"shape": "box", "size": Vector3(0.90, 2.00, 0.60), "pos": Vector3(0, 1.04, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.42, 1.90, 0.02), "pos": Vector3(-0.22, 1.05, 0.305), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.42, 1.90, 0.02), "pos": Vector3(0.22, 1.05, 0.305), "mat": "wood_light"},
			{"shape": "cyl", "size": Vector3(0.012, 0.20, 0.012), "pos": Vector3(-0.03, 1.05, 0.325), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.012, 0.20, 0.012), "pos": Vector3(0.03, 1.05, 0.325), "mat": "metal"},
			{"shape": "box", "size": Vector3(0.90, 0.08, 0.60), "pos": Vector3(0, 0.04, 0), "mat": "dark"},
		],
	})
	_add({
		"id": "kettle", "stackable": true, "name": "Kettle",
		"category": "Kitchen", "price": 55, "level": 1,
		"tint": Color(0.85, 0.86, 0.88),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.09, 0.20, 0.10), "pos": Vector3(0, 0.10, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.07, 0.03, 0.07), "pos": Vector3(0, 0.215, 0), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.03, 0.03, 0.08), "pos": Vector3(0, 0.15, 0.11), "mat": "metal"},
			{"shape": "box", "size": Vector3(0.02, 0.13, 0.02), "pos": Vector3(-0.10, 0.17, 0), "mat": "dark"},
		],
	})
	_add({
		"id": "toaster", "stackable": true, "name": "Toaster",
		"category": "Kitchen", "price": 45, "level": 1,
		"tint": Color(0.85, 0.86, 0.88),
		"parts": [
			{"shape": "box", "size": Vector3(0.28, 0.17, 0.17), "pos": Vector3(0, 0.085, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.09, 0.01, 0.10), "pos": Vector3(-0.06, 0.175, 0), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.09, 0.01, 0.10), "pos": Vector3(0.06, 0.175, 0), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.03, 0.06, 0.02), "pos": Vector3(0.155, 0.12, 0), "mat": "dark"},
		],
	})

	# -------------------------------------------------------------- Bathroom
	_add({
		"id": "bath_mat", "name": "Bath Mat",
		"category": "Bathroom", "price": 45, "level": 1,
		"tint": Color(0.66, 0.76, 0.80),
		"parts": [
			{"shape": "box", "size": Vector3(0.85, 0.02, 0.55), "pos": Vector3(0, 0.01, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.72, 0.022, 0.44), "pos": Vector3(0, 0.012, 0), "mat": "white"},
		],
	})
	_add({
		"id": "bathroom_cabinet", "against_wall": true, "name": "Tall Cabinet",
		"category": "Bathroom", "price": 260, "level": 3,
		"tint": Color(0.92, 0.92, 0.90),
		"parts": [
			{"shape": "box", "size": Vector3(0.40, 1.66, 0.35), "pos": Vector3(0, 0.89, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.36, 1.56, 0.02), "pos": Vector3(0, 0.90, 0.18), "mat": "white"},
			{"shape": "cyl", "size": Vector3(0.012, 0.14, 0.012), "pos": Vector3(0.14, 0.90, 0.20), "mat": "metal"},
			{"shape": "box", "size": Vector3(0.40, 0.06, 0.35), "pos": Vector3(0, 0.03, 0), "mat": "dark"},
		],
	})

	# --------------------------------------------------------------- Storage
	_add({
		"id": "shoe_rack", "against_wall": true, "name": "Shoe Rack",
		"category": "Storage", "price": 120, "level": 1,
		"tint": Color(0.58, 0.42, 0.28),
		"parts": [
			{"shape": "box", "size": Vector3(0.80, 0.03, 0.32), "pos": Vector3(0, 0.07, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.80, 0.03, 0.32), "pos": Vector3(0, 0.29, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.80, 0.03, 0.32), "pos": Vector3(0, 0.51, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.04, 0.55, 0.32), "pos": Vector3(-0.38, 0.28, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.04, 0.55, 0.32), "pos": Vector3(0.38, 0.28, 0), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "coat_stand", "against_wall": true, "name": "Coat Stand",
		"category": "Storage", "price": 140, "level": 1,
		"tint": Color(0.40, 0.28, 0.20),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.20, 0.04, 0.22), "pos": Vector3(0, 0.02, 0), "mat": "dark"},
			{"shape": "cyl", "size": Vector3(0.035, 1.68, 0.035), "pos": Vector3(0, 0.88, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.40, 0.03, 0.03), "pos": Vector3(0, 1.62, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.03, 0.03, 0.40), "pos": Vector3(0, 1.54, 0), "mat": "tint"},
			{"shape": "sphere", "size": Vector3(0.055, 0.11, 0.055), "pos": Vector3(0, 1.75, 0), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "display_cabinet", "against_wall": true, "name": "Display Cabinet",
		"category": "Storage", "price": 460, "level": 8, "surface": 1.85,
		"tint": Color(0.40, 0.30, 0.22),
		"parts": [
			{"shape": "box", "size": Vector3(0.90, 1.80, 0.40), "pos": Vector3(0, 0.95, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.80, 1.44, 0.02), "pos": Vector3(0, 1.10, 0.205), "mat": "glass"},
			{"shape": "box", "size": Vector3(0.82, 0.03, 0.34), "pos": Vector3(0, 0.58, 0), "mat": "white"},
			{"shape": "box", "size": Vector3(0.82, 0.03, 0.34), "pos": Vector3(0, 1.00, 0), "mat": "white"},
			{"shape": "box", "size": Vector3(0.82, 0.03, 0.34), "pos": Vector3(0, 1.42, 0), "mat": "white"},
			{"shape": "box", "size": Vector3(0.20, 0.22, 0.18), "pos": Vector3(-0.20, 0.70, 0), "mat": "porcelain"},
			{"shape": "box", "size": Vector3(0.16, 0.18, 0.16), "pos": Vector3(0.22, 1.10, 0), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.90, 0.10, 0.40), "pos": Vector3(0, 0.05, 0), "mat": "dark"},
		],
	})

	# ----------------------------------------------------------------- Decor
	_add({
		"id": "floor_mirror", "against_wall": true, "name": "Floor Mirror",
		"category": "Decor", "price": 200, "level": 3,
		"tint": Color(0.52, 0.38, 0.26),
		"parts": [
			{"shape": "box", "size": Vector3(0.70, 1.68, 0.06), "pos": Vector3(0, 0.90, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.58, 1.54, 0.02), "pos": Vector3(0, 0.92, 0.035), "mat": "mirror"},
			{"shape": "box", "size": Vector3(0.34, 0.05, 0.28), "pos": Vector3(0, 0.025, 0.06), "mat": "dark"},
		],
	})
	_add({
		"id": "rug_round", "name": "Round Rug",
		"category": "Decor", "price": 180, "level": 3,
		"tint": Color(0.44, 0.52, 0.62),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.85, 0.02, 0.85), "pos": Vector3(0, 0.01, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.62, 0.022, 0.62), "pos": Vector3(0, 0.012, 0), "mat": "white"},
			{"shape": "cyl", "size": Vector3(0.40, 0.024, 0.40), "pos": Vector3(0, 0.014, 0), "mat": "tint"},
		],
	})
	_add({
		"id": "vase", "stackable": true, "name": "Vase",
		"category": "Decor", "price": 60, "level": 1,
		"tint": Color(0.72, 0.78, 0.74),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.11, 0.22, 0.07), "pos": Vector3(0, 0.11, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.05, 0.10, 0.09), "pos": Vector3(0, 0.27, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.008, 0.26, 0.008), "pos": Vector3(0.02, 0.42, 0), "mat": "leaf"},
			{"shape": "cyl", "size": Vector3(0.008, 0.22, 0.008), "pos": Vector3(-0.03, 0.40, 0.02), "mat": "leaf"},
			{"shape": "sphere", "size": Vector3(0.05, 0.09, 0.05), "pos": Vector3(0.02, 0.55, 0), "mat": "leaf"},
			{"shape": "sphere", "size": Vector3(0.04, 0.07, 0.04), "pos": Vector3(-0.03, 0.50, 0.02), "mat": "leaf"},
		],
	})
	_add({
		"id": "books_stack", "stackable": true, "name": "Stack of Books",
		"category": "Decor", "price": 45, "level": 1,
		"tint": Color(0.62, 0.28, 0.26),
		"parts": [
			{"shape": "box", "size": Vector3(0.26, 0.04, 0.19), "pos": Vector3(0, 0.02, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.24, 0.04, 0.18), "pos": Vector3(0.01, 0.06, 0.01), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.22, 0.035, 0.17), "pos": Vector3(-0.01, 0.098, -0.01), "mat": "white"},
		],
	})


## Everything with a plug. The television lives here too, over in _build().
func _build_electronics() -> void:
	_add({
		"id": "tv_large", "against_wall": true, "name": "Wide Television",
		"category": "Electronics", "price": 880, "level": 8,
		"tint": Color(0.14, 0.15, 0.18),
		"parts": [
			{"shape": "box", "size": Vector3(0.52, 0.03, 0.26), "pos": Vector3(0, 0.015, 0), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.09, 0.18, 0.09), "pos": Vector3(0, 0.11, 0), "mat": "dark"},
			{"shape": "box", "size": Vector3(1.62, 0.92, 0.05), "pos": Vector3(0, 0.66, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.55, 0.85, 0.01), "pos": Vector3(0, 0.66, 0.032), "mat": "screen"},
		],
	})
	_add({
		"id": "computer", "stackable": true, "name": "Computer",
		"category": "Electronics", "price": 640, "level": 3,
		"tint": Color(0.22, 0.23, 0.27),
		"parts": [
			{"shape": "box", "size": Vector3(0.24, 0.02, 0.16), "pos": Vector3(0, 0.01, -0.06), "mat": "dark"},
			{"shape": "cyl", "size": Vector3(0.02, 0.14, 0.02), "pos": Vector3(0, 0.09, -0.06), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.56, 0.34, 0.03), "pos": Vector3(0, 0.33, -0.06), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.52, 0.30, 0.01), "pos": Vector3(0, 0.33, -0.042), "mat": "screen"},
			{"shape": "box", "size": Vector3(0.40, 0.02, 0.14), "pos": Vector3(0, 0.01, 0.15), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.36, 0.005, 0.10), "pos": Vector3(0, 0.023, 0.15), "mat": "white"},
		],
	})
	_add({
		"id": "speaker_tower", "against_wall": true, "name": "Floor Speaker",
		"category": "Electronics", "price": 430, "level": 5,
		"tint": Color(0.20, 0.21, 0.24),
		"parts": [
			{"shape": "box", "size": Vector3(0.28, 0.03, 0.32), "pos": Vector3(0, 0.015, 0), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.24, 1.00, 0.28), "pos": Vector3(0, 0.53, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.08, 0.02, 0.08), "pos": Vector3(0, 0.80, 0.145), "mat": "dark", "rot": Vector3(90, 0, 0)},
			{"shape": "cyl", "size": Vector3(0.06, 0.02, 0.06), "pos": Vector3(0, 0.45, 0.145), "mat": "dark", "rot": Vector3(90, 0, 0)},
			{"shape": "cyl", "size": Vector3(0.035, 0.02, 0.035), "pos": Vector3(0, 0.98, 0.145), "mat": "metal", "rot": Vector3(90, 0, 0)},
		],
	})
	_add({
		"id": "soundbar", "stackable": true, "name": "Soundbar",
		"category": "Electronics", "price": 290, "level": 5,
		"tint": Color(0.18, 0.19, 0.22),
		"parts": [
			{"shape": "box", "size": Vector3(0.92, 0.09, 0.10), "pos": Vector3(0, 0.045, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.84, 0.06, 0.01), "pos": Vector3(0, 0.045, 0.055), "mat": "dark"},
		],
	})
	_add({
		"id": "game_console", "stackable": true, "name": "Games Console",
		"category": "Electronics", "price": 340, "level": 3,
		"tint": Color(0.24, 0.25, 0.30),
		"parts": [
			{"shape": "box", "size": Vector3(0.34, 0.07, 0.26), "pos": Vector3(0, 0.035, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.30, 0.01, 0.22), "pos": Vector3(0, 0.072, 0), "mat": "dark"},
			{"shape": "cyl", "size": Vector3(0.012, 0.008, 0.012), "pos": Vector3(0.13, 0.076, -0.09), "mat": "metal"},
		],
	})
	_add({
		"id": "printer", "stackable": true, "name": "Printer",
		"category": "Electronics", "price": 260, "level": 3,
		"tint": Color(0.88, 0.88, 0.86),
		"parts": [
			{"shape": "box", "size": Vector3(0.42, 0.22, 0.36), "pos": Vector3(0, 0.11, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.38, 0.02, 0.15), "pos": Vector3(0, 0.21, 0.16), "mat": "white"},
			{"shape": "box", "size": Vector3(0.14, 0.01, 0.08), "pos": Vector3(-0.10, 0.225, -0.08), "mat": "screen"},
		],
	})
	_add({
		"id": "air_conditioner", "against_wall": true, "name": "Portable Air Con",
		"category": "Electronics", "price": 700, "level": 8,
		"tint": Color(0.90, 0.90, 0.88),
		"parts": [
			{"shape": "box", "size": Vector3(0.42, 0.78, 0.38), "pos": Vector3(0, 0.40, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.34, 0.16, 0.02), "pos": Vector3(0, 0.64, 0.19), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.16, 0.05, 0.01), "pos": Vector3(0, 0.42, 0.195), "mat": "screen"},
			{"shape": "cyl", "size": Vector3(0.03, 0.03, 0.03), "pos": Vector3(-0.15, 0.02, 0.14), "mat": "dark", "rot": Vector3(0, 0, 90)},
			{"shape": "cyl", "size": Vector3(0.03, 0.03, 0.03), "pos": Vector3(0.15, 0.02, 0.14), "mat": "dark", "rot": Vector3(0, 0, 90)},
		],
	})
	_add({
		"id": "floor_fan", "name": "Floor Fan",
		"category": "Electronics", "price": 150, "level": 3,
		"tint": Color(0.86, 0.86, 0.84),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.20, 0.04, 0.22), "pos": Vector3(0, 0.02, 0), "mat": "dark"},
			{"shape": "cyl", "size": Vector3(0.03, 0.78, 0.03), "pos": Vector3(0, 0.42, 0), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.24, 0.10, 0.24), "pos": Vector3(0, 0.95, 0), "mat": "tint", "rot": Vector3(90, 0, 0)},
			{"shape": "cyl", "size": Vector3(0.06, 0.13, 0.06), "pos": Vector3(0, 0.95, 0), "mat": "dark", "rot": Vector3(90, 0, 0)},
		],
	})
	_add({
		"id": "microwave", "stackable": true, "name": "Microwave",
		"category": "Electronics", "price": 240, "level": 3,
		"tint": Color(0.85, 0.86, 0.88),
		"parts": [
			{"shape": "box", "size": Vector3(0.50, 0.28, 0.36), "pos": Vector3(0, 0.14, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.32, 0.22, 0.02), "pos": Vector3(-0.07, 0.14, 0.19), "mat": "glass"},
			{"shape": "box", "size": Vector3(0.12, 0.24, 0.02), "pos": Vector3(0.17, 0.14, 0.19), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.02, 0.18, 0.03), "pos": Vector3(0.09, 0.14, 0.20), "mat": "metal"},
		],
	})


# ------------------------------------------------------------------ helpers

func _sofa(width: float, depth: float) -> Array:
	var half := width * 0.5
	var arm := 0.17
	var seat_w: float = width - arm * 2.0
	var parts: Array = [
		{"shape": "box", "size": Vector3(width, 0.32, depth), "pos": Vector3(0, 0.22, 0), "mat": "tint"},
		{"shape": "box", "size": Vector3(width, 0.58, 0.22), "pos": Vector3(0, 0.62, -depth * 0.5 + 0.11), "mat": "tint"},
		{"shape": "box", "size": Vector3(arm, 0.34, depth), "pos": Vector3(-half + arm * 0.5, 0.55, 0), "mat": "tint"},
		{"shape": "box", "size": Vector3(arm, 0.34, depth), "pos": Vector3(half - arm * 0.5, 0.55, 0), "mat": "tint"},
	]
	# Seat cushions: one per ~0.7 m of usable width.
	var cushions: int = maxi(1, int(round(seat_w / 0.72)))
	var cw: float = (seat_w - 0.04 * (cushions + 1)) / float(cushions)
	for i in cushions:
		var cx: float = -seat_w * 0.5 + 0.04 * (i + 1) + cw * (i + 0.5)
		parts.append({
			"shape": "box",
			"size": Vector3(cw, 0.16, depth - 0.26),
			"pos": Vector3(cx, 0.46, 0.06),
			"mat": "white",
		})
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			parts.append({
				"shape": "cyl",
				"size": Vector3(0.03, 0.06, 0.03),
				"pos": Vector3(sx * (half - 0.12), 0.03, sz * (depth * 0.5 - 0.12)),
				"mat": "wood_dark",
			})
	return parts


func _bed(width: float, length: float) -> Array:
	var hw := width * 0.5
	var hl := length * 0.5
	var parts: Array = [
		{"shape": "box", "size": Vector3(width, 0.30, length), "pos": Vector3(0, 0.16, 0), "mat": "wood_dark"},
		{"shape": "box", "size": Vector3(width - 0.06, 0.24, length - 0.06), "pos": Vector3(0, 0.42, 0), "mat": "white"},
		{"shape": "box", "size": Vector3(width, 0.78, 0.08), "pos": Vector3(0, 0.60, -hl - 0.04), "mat": "wood_dark"},
		{"shape": "box", "size": Vector3(width - 0.06, 0.07, length * 0.62), "pos": Vector3(0, 0.56, hl * 0.36), "mat": "tint"},
	]
	var pillow_w: float = minf(0.62, width * 0.46)
	if width > 1.2:
		parts.append({"shape": "box", "size": Vector3(pillow_w, 0.14, 0.34), "pos": Vector3(-width * 0.24, 0.60, -hl + 0.30), "mat": "white"})
		parts.append({"shape": "box", "size": Vector3(pillow_w, 0.14, 0.34), "pos": Vector3(width * 0.24, 0.60, -hl + 0.30), "mat": "white"})
	else:
		parts.append({"shape": "box", "size": Vector3(pillow_w, 0.14, 0.34), "pos": Vector3(0, 0.60, -hl + 0.30), "mat": "white"})
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			parts.append({
				"shape": "box",
				"size": Vector3(0.07, 0.06, 0.07),
				"pos": Vector3(sx * (hw - 0.07), 0.03, sz * (hl - 0.07)),
				"mat": "dark",
			})
	return parts


func _table(width: float, depth: float, height: float, top: float) -> Array:
	var parts: Array = [
		{"shape": "box", "size": Vector3(width, top, depth), "pos": Vector3(0, height - top * 0.5, 0), "mat": "tint"},
	]
	var leg := 0.06
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			parts.append({
				"shape": "box",
				"size": Vector3(leg, height - top, leg),
				"pos": Vector3(
					sx * (width * 0.5 - leg),
					(height - top) * 0.5,
					sz * (depth * 0.5 - leg)
				),
				"mat": "wood_dark",
			})
	return parts


func _add(def: Dictionary) -> void:
	# Two pieces with the same id used to mean the second quietly replaced the
	# first, moving it to another shop and another level and leaving every
	# brief that asked for it unsatisfiable. Nothing said so at the time.
	assert(not _items.has(def["id"]),
		"catalogue already has a piece called '%s'" % def["id"])
	def["extents"] = _measure(def["parts"])
	def["level"] = def.get("level", 1)
	def["price"] = def.get("price", 100)
	def["shop"] = str(def.get("shop", _shop_for_category(def["category"])))
	_items[def["id"]] = def
	_order.append(def["id"])


func _shop_for_category(category: String) -> String:
	for shop in SHOPS:
		if shop["category"] == category:
			return shop["id"]
	return ""


## Axis-aligned bounds of an item in its own local space, as
## {"min": Vector3, "max": Vector3}.
func _measure(parts: Array) -> Dictionary:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for part in parts:
		var size: Vector3 = part["size"]
		var half: Vector3
		match part.get("shape", "box"):
			"cyl":
				var r: float = maxf(size.x, size.z)
				half = Vector3(r, size.y * 0.5, r)
			"sphere":
				half = Vector3(size.x, size.y * 0.5, size.x)
			_:
				half = size * 0.5
		if part.has("rot"):
			# Conservative: rotated parts get a bounding cube of their longest axis.
			var m: float = maxf(half.x, maxf(half.y, half.z))
			half = Vector3(m, m, m)
		var pos: Vector3 = part["pos"]
		lo = Vector3(minf(lo.x, pos.x - half.x), minf(lo.y, pos.y - half.y), minf(lo.z, pos.z - half.z))
		hi = Vector3(maxf(hi.x, pos.x + half.x), maxf(hi.y, pos.y + half.y), maxf(hi.z, pos.z + half.z))
	return {"min": lo, "max": hi}


# --------------------------------------------------------------- public API

func ids() -> Array[String]:
	return _order


func ids_in(category: String) -> Array[String]:
	var out: Array[String] = []
	for id in _order:
		if _items[id]["category"] == category:
			out.append(id)
	return out


func has_item(id: String) -> bool:
	return _items.has(id)


func get_item(id: String) -> Dictionary:
	return _items.get(id, {})


func display_name(id: String) -> String:
	return _items.get(id, {}).get("name", id)


func category_of(id: String) -> String:
	return str(_items.get(id, {}).get("category", ""))


func price(id: String) -> int:
	return int(_items.get(id, {}).get("price", 0))


func unlock_level(id: String) -> int:
	return int(_items.get(id, {}).get("level", 1))


## The level that actually matters: an item cannot be bought before the shop
## that stocks it has opened, however cheap the item itself is.
func effective_unlock_level(id: String) -> int:
	var shop: Dictionary = _shops_by_id.get(shop_of(id), {})
	return maxi(unlock_level(id), int(shop.get("level", 1)))


func shop_of(id: String) -> String:
	return str(_items.get(id, {}).get("shop", ""))


func default_tint(id: String) -> Color:
	return _items.get(id, {}).get("tint", Color.WHITE)


## Height of this piece's usable top, or 0 when nothing can be put on it.
func surface_height(id: String) -> float:
	return float(_items.get(id, {}).get("surface", 0.0))


## True for the small pieces that belong on a table rather than the floor.
func is_stackable(id: String) -> bool:
	return bool(_items.get(id, {}).get("stackable", false))


func get_shop(shop_id: String) -> Dictionary:
	return _shops_by_id.get(shop_id, {})


func shop_name(shop_id: String) -> String:
	return str(_shops_by_id.get(shop_id, {}).get("name", shop_id))


## Everything a shop sells, in catalog order.
func shop_stock(shop_id: String) -> Array[String]:
	var out: Array[String] = []
	for id in _order:
		if str(_items[id]["shop"]) == shop_id:
			out.append(id)
	return out


## The shops standing in one quarter of the city.
func shops_in(district_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for shop: Dictionary in SHOPS:
		if str(shop.get("district", "")) == district_id:
			out.append(shop)
	return out


## Which quarter has to be bought before a shop will serve you.
func shop_district(shop_id: String) -> String:
	return str(_shops_by_id.get(shop_id, {}).get("district", ""))


func district_of(id: String) -> String:
	return shop_district(shop_of(id))


func paint_price(entry: Dictionary) -> int:
	var tier: int = clampi(int(entry.get("level", 1)), 1, PAINT_PRICE_BY_LEVEL.size() - 1)
	return PAINT_PRICE_BY_LEVEL[tier]


## Every shade in a palette, for the shop window and the designer's picker.
func paints(surface: String) -> Array:
	return PAINT.get(surface, [])


## Footprint (width, depth) on the floor, in metres.
func footprint(id: String) -> Vector2:
	var e: Dictionary = _items.get(id, {}).get("extents", {})
	if e.is_empty():
		return Vector2.ONE
	var lo: Vector3 = e["min"]
	var hi: Vector3 = e["max"]
	return Vector2(hi.x - lo.x, hi.z - lo.z)


func height(id: String) -> float:
	var e: Dictionary = _items.get(id, {}).get("extents", {})
	if e.is_empty():
		return 1.0
	return (e["max"] as Vector3).y - (e["min"] as Vector3).y


func make_material(role: String, tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if role == "tint":
		mat.albedo_color = tint
		mat.roughness = 0.7
		mat.metallic = 0.0
	else:
		var spec: Dictionary = MATERIALS.get(role, MATERIALS["white"])
		mat.albedo_color = spec["color"]
		mat.roughness = spec["rough"]
		mat.metallic = spec["metal"]
	if mat.albedo_color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


# ------------------------------------------------------------ Riverside Wharf

## Dock & Salvage and Ropewalk & Co, on the wharf's own avenue. Nothing here is
## sold anywhere else in the city, and the quarter has to be bought first.
func _build_riverside() -> void:
	_add({
		"id": "crate_shelf", "against_wall": true, "shop": "salvage",
		"name": "Crate Shelving", "category": "Storage",
		"price": 340, "level": 8,
		"tint": Color(0.68, 0.50, 0.30),
		"parts": [
			{"shape": "box", "size": Vector3(0.52, 0.42, 0.36), "pos": Vector3(-0.28, 0.21, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.52, 0.42, 0.36), "pos": Vector3(0.28, 0.21, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.52, 0.42, 0.36), "pos": Vector3(-0.28, 0.64, 0), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.52, 0.42, 0.36), "pos": Vector3(0.28, 0.64, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.52, 0.42, 0.36), "pos": Vector3(0, 1.07, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.46, 0.03, 0.30), "pos": Vector3(-0.28, 0.42, 0.02), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.46, 0.03, 0.30), "pos": Vector3(0.28, 0.85, 0.02), "mat": "wood_light"},
		],
		"surface": 1.29,
	})
	_add({
		"id": "pipe_rack", "against_wall": true, "shop": "salvage",
		"name": "Pipe Clothes Rail", "category": "Storage",
		"price": 280, "level": 8,
		"tint": Color(0.52, 0.54, 0.58),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.035, 1.62, 0.035), "pos": Vector3(-0.55, 0.81, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.035, 1.62, 0.035), "pos": Vector3(0.55, 0.81, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.20, 0.05, 0.05), "pos": Vector3(0, 1.58, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.20, 0.04, 0.34), "pos": Vector3(0, 0.34, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.24, 0.03, 0.32), "pos": Vector3(-0.62, 0.06, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.24, 0.03, 0.32), "pos": Vector3(0.62, 0.06, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.90, 0.52, 0.22), "pos": Vector3(0, 1.26, 0.04), "mat": "towel"},
		],
	})
	_add({
		"id": "workbench", "against_wall": true, "shop": "salvage",
		"name": "Salvage Workbench", "category": "Storage",
		"price": 420, "level": 8,
		"tint": Color(0.46, 0.32, 0.20),
		"parts": [
			{"shape": "box", "size": Vector3(1.60, 0.09, 0.68), "pos": Vector3(0, 0.87, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.10, 0.83, 0.10), "pos": Vector3(-0.72, 0.41, -0.26), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.10, 0.83, 0.10), "pos": Vector3(0.72, 0.41, -0.26), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.10, 0.83, 0.10), "pos": Vector3(-0.72, 0.41, 0.26), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.10, 0.83, 0.10), "pos": Vector3(0.72, 0.41, 0.26), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.40, 0.03, 0.50), "pos": Vector3(0, 0.28, 0), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.16, 0.14, 0.16), "pos": Vector3(-0.60, 0.99, 0.10), "mat": "steel"},
		],
		"surface": 0.92,
	})
	_add({
		"id": "steamer_trunk", "shop": "salvage",
		"name": "Steamer Trunk", "category": "Storage",
		"price": 310, "level": 8,
		"tint": Color(0.40, 0.26, 0.20),
		"parts": [
			{"shape": "box", "size": Vector3(0.94, 0.40, 0.54), "pos": Vector3(0, 0.24, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.96, 0.10, 0.56), "pos": Vector3(0, 0.49, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.08, 0.52, 0.58), "pos": Vector3(-0.30, 0.28, 0), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.08, 0.52, 0.58), "pos": Vector3(0.30, 0.28, 0), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.14, 0.10, 0.04), "pos": Vector3(0, 0.30, 0.28), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.90, 0.06, 0.50), "pos": Vector3(0, 0.03, 0), "mat": "dark"},
		],
		"surface": 0.54,
	})
	_add({
		"id": "barrel_table", "shop": "salvage",
		"name": "Barrel Table", "category": "Dining",
		"price": 360, "level": 8,
		"tint": Color(0.55, 0.35, 0.22),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.34, 0.70, 0.34), "pos": Vector3(0, 0.35, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.36, 0.05, 0.36), "pos": Vector3(0, 0.22, 0), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.36, 0.05, 0.36), "pos": Vector3(0, 0.52, 0), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.62, 0.06, 0.62), "pos": Vector3(0, 0.73, 0), "mat": "wood_light"},
		],
		"surface": 0.76,
	})

	_add({
		"id": "deck_chair", "shop": "ropewalk",
		"name": "Deck Chair", "category": "Living",
		"price": 220, "level": 8,
		"tint": Color(0.82, 0.78, 0.66),
		"parts": [
			{"shape": "box", "size": Vector3(0.56, 0.04, 0.60), "pos": Vector3(0, 0.40, 0.06), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.56, 0.60, 0.04), "pos": Vector3(0, 0.66, -0.24), "mat": "tint", "rot": Vector3(-18, 0, 0)},
			{"shape": "box", "size": Vector3(0.05, 0.62, 0.05), "pos": Vector3(-0.28, 0.31, 0.24), "mat": "wood_light", "rot": Vector3(22, 0, 0)},
			{"shape": "box", "size": Vector3(0.05, 0.62, 0.05), "pos": Vector3(0.28, 0.31, 0.24), "mat": "wood_light", "rot": Vector3(22, 0, 0)},
			{"shape": "box", "size": Vector3(0.05, 0.80, 0.05), "pos": Vector3(-0.28, 0.40, -0.16), "mat": "wood_light", "rot": Vector3(-14, 0, 0)},
			{"shape": "box", "size": Vector3(0.05, 0.80, 0.05), "pos": Vector3(0.28, 0.40, -0.16), "mat": "wood_light", "rot": Vector3(-14, 0, 0)},
		],
	})
	_add({
		"id": "net_hammock", "shop": "ropewalk",
		"name": "Net Hammock", "category": "Bedroom",
		"price": 390, "level": 8,
		"tint": Color(0.86, 0.80, 0.64),
		"parts": [
			{"shape": "box", "size": Vector3(0.10, 1.30, 0.10), "pos": Vector3(-0.95, 0.65, 0), "mat": "wood_dark", "rot": Vector3(0, 0, 10)},
			{"shape": "box", "size": Vector3(0.10, 1.30, 0.10), "pos": Vector3(0.95, 0.65, 0), "mat": "wood_dark", "rot": Vector3(0, 0, -10)},
			{"shape": "box", "size": Vector3(0.40, 0.06, 0.44), "pos": Vector3(-0.98, 0.03, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.40, 0.06, 0.44), "pos": Vector3(0.98, 0.03, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.50, 0.14, 0.62), "pos": Vector3(0, 0.60, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.44, 0.20, 0.34), "pos": Vector3(-0.50, 0.74, 0), "mat": "towel"},
		],
	})
	_add({
		"id": "porthole_mirror", "against_wall": true, "shop": "ropewalk",
		"name": "Porthole Mirror", "category": "Decor",
		"price": 260, "level": 8,
		"tint": Color(0.78, 0.62, 0.30),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.10, 1.10, 0.10), "pos": Vector3(0, 0.55, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.44, 0.05, 0.34), "pos": Vector3(0, 0.03, 0), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.40, 0.09, 0.40), "pos": Vector3(0, 1.30, 0), "mat": "tint", "rot": Vector3(90, 0, 0)},
			{"shape": "cyl", "size": Vector3(0.33, 0.11, 0.33), "pos": Vector3(0, 1.30, 0.02), "mat": "mirror", "rot": Vector3(90, 0, 0)},
		],
	})
	_add({
		"id": "rope_light", "shop": "ropewalk",
		"name": "Rope Lamp", "category": "Decor",
		"price": 190, "level": 8,
		"tint": Color(0.80, 0.72, 0.54),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.20, 0.05, 0.20), "pos": Vector3(0, 0.02, 0), "mat": "dark"},
			{"shape": "cyl", "size": Vector3(0.07, 1.34, 0.07), "pos": Vector3(0, 0.72, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.09, 0.06, 0.09), "pos": Vector3(0, 0.50, 0), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.09, 0.06, 0.09), "pos": Vector3(0, 1.02, 0), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.24, 0.26, 0.16), "pos": Vector3(0, 1.52, 0), "mat": "white"},
		],
	})
	_add({
		"id": "sail_screen", "against_wall": true, "shop": "ropewalk",
		"name": "Sail Screen", "category": "Decor",
		"price": 300, "level": 8,
		"tint": Color(0.90, 0.88, 0.80),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.05, 1.80, 0.05), "pos": Vector3(-0.62, 0.90, 0), "mat": "wood_light"},
			{"shape": "cyl", "size": Vector3(0.05, 1.80, 0.05), "pos": Vector3(0.62, 0.90, 0), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(1.24, 1.46, 0.03), "pos": Vector3(0, 0.94, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.46, 0.04, 0.34), "pos": Vector3(-0.62, 0.02, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.46, 0.04, 0.34), "pos": Vector3(0.62, 0.02, 0), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.03, 1.30, 0.03), "pos": Vector3(0, 1.78, 0), "mat": "steel", "rot": Vector3(0, 0, 90)},
		],
	})


# ----------------------------------------------------------- Hillside Terrace

## Hearth & Home and The Potting Shed, up the slope.
func _build_hillside() -> void:
	_add({
		"id": "window_seat", "against_wall": true, "shop": "hearth",
		"name": "Window Seat", "category": "Living",
		"price": 430, "level": 11,
		"tint": Color(0.74, 0.72, 0.62),
		"parts": [
			{"shape": "box", "size": Vector3(1.60, 0.34, 0.56), "pos": Vector3(0, 0.17, 0), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(1.56, 0.14, 0.54), "pos": Vector3(0, 0.41, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.42, 0.34, 0.14), "pos": Vector3(-0.50, 0.63, -0.18), "mat": "towel"},
			{"shape": "box", "size": Vector3(0.42, 0.34, 0.14), "pos": Vector3(0.00, 0.63, -0.18), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.42, 0.34, 0.14), "pos": Vector3(0.50, 0.63, -0.18), "mat": "towel"},
			{"shape": "box", "size": Vector3(1.60, 0.06, 0.06), "pos": Vector3(0, 0.03, 0.28), "mat": "wood_dark"},
		],
		"surface": 0.48,
	})
	_add({
		"id": "ottoman", "shop": "hearth",
		"name": "Ottoman", "category": "Living",
		"price": 260, "level": 11,
		"tint": Color(0.62, 0.40, 0.36),
		"parts": [
			{"shape": "box", "size": Vector3(0.90, 0.34, 0.66), "pos": Vector3(0, 0.21, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.84, 0.05, 0.60), "pos": Vector3(0, 0.40, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.05, 0.09, 0.05), "pos": Vector3(-0.36, 0.04, -0.24), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.05, 0.09, 0.05), "pos": Vector3(0.36, 0.04, -0.24), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.05, 0.09, 0.05), "pos": Vector3(-0.36, 0.04, 0.24), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.05, 0.09, 0.05), "pos": Vector3(0.36, 0.04, 0.24), "mat": "wood_dark"},
		],
		"surface": 0.43,
	})
	_add({
		"id": "sideboard", "against_wall": true, "shop": "hearth",
		"name": "Sideboard", "category": "Dining",
		"price": 520, "level": 11,
		"tint": Color(0.50, 0.34, 0.22),
		"parts": [
			{"shape": "box", "size": Vector3(1.70, 0.72, 0.46), "pos": Vector3(0, 0.48, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.74, 0.05, 0.50), "pos": Vector3(0, 0.86, 0), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.52, 0.58, 0.03), "pos": Vector3(-0.55, 0.48, 0.235), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.52, 0.58, 0.03), "pos": Vector3(0.00, 0.48, 0.235), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.52, 0.58, 0.03), "pos": Vector3(0.55, 0.48, 0.235), "mat": "wood_light"},
			{"shape": "cyl", "size": Vector3(0.03, 0.12, 0.03), "pos": Vector3(-0.55, 0.48, 0.27), "mat": "steel", "rot": Vector3(0, 0, 90)},
			{"shape": "cyl", "size": Vector3(0.03, 0.12, 0.03), "pos": Vector3(0.00, 0.48, 0.27), "mat": "steel", "rot": Vector3(0, 0, 90)},
			{"shape": "cyl", "size": Vector3(0.03, 0.12, 0.03), "pos": Vector3(0.55, 0.48, 0.27), "mat": "steel", "rot": Vector3(0, 0, 90)},
			{"shape": "box", "size": Vector3(0.06, 0.12, 0.06), "pos": Vector3(-0.78, 0.06, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.06, 0.12, 0.06), "pos": Vector3(0.78, 0.06, 0), "mat": "wood_dark"},
		],
		"surface": 0.89,
	})
	_add({
		"id": "rocking_chair", "shop": "hearth",
		"name": "Rocking Chair", "category": "Living",
		"price": 340, "level": 11,
		"tint": Color(0.58, 0.38, 0.24),
		"parts": [
			{"shape": "box", "size": Vector3(0.54, 0.06, 0.50), "pos": Vector3(0, 0.44, 0.02), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.50, 0.72, 0.05), "pos": Vector3(0, 0.78, -0.22), "mat": "tint", "rot": Vector3(-12, 0, 0)},
			{"shape": "box", "size": Vector3(0.05, 0.42, 0.05), "pos": Vector3(-0.25, 0.23, -0.20), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.05, 0.42, 0.05), "pos": Vector3(0.25, 0.23, -0.20), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.05, 0.42, 0.05), "pos": Vector3(-0.25, 0.23, 0.20), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.05, 0.42, 0.05), "pos": Vector3(0.25, 0.23, 0.20), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.05, 0.06, 0.76), "pos": Vector3(-0.25, 0.03, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.05, 0.06, 0.76), "pos": Vector3(0.25, 0.03, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.06, 0.05, 0.44), "pos": Vector3(-0.28, 0.66, 0.02), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.06, 0.05, 0.44), "pos": Vector3(0.28, 0.66, 0.02), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "high_chair", "shop": "hearth",
		"name": "High Chair", "category": "Dining",
		"price": 210, "level": 11,
		"tint": Color(0.86, 0.82, 0.74),
		"parts": [
			{"shape": "box", "size": Vector3(0.36, 0.04, 0.34), "pos": Vector3(0, 0.58, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.36, 0.44, 0.04), "pos": Vector3(0, 0.80, -0.15), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.40, 0.04, 0.24), "pos": Vector3(0, 0.74, 0.18), "mat": "white"},
			{"shape": "box", "size": Vector3(0.05, 0.58, 0.05), "pos": Vector3(-0.18, 0.29, -0.14), "mat": "wood_light", "rot": Vector3(-6, 0, 6)},
			{"shape": "box", "size": Vector3(0.05, 0.58, 0.05), "pos": Vector3(0.18, 0.29, -0.14), "mat": "wood_light", "rot": Vector3(-6, 0, -6)},
			{"shape": "box", "size": Vector3(0.05, 0.58, 0.05), "pos": Vector3(-0.18, 0.29, 0.14), "mat": "wood_light", "rot": Vector3(6, 0, 6)},
			{"shape": "box", "size": Vector3(0.05, 0.58, 0.05), "pos": Vector3(0.18, 0.29, 0.14), "mat": "wood_light", "rot": Vector3(6, 0, -6)},
			{"shape": "box", "size": Vector3(0.42, 0.04, 0.04), "pos": Vector3(0, 0.22, 0.16), "mat": "wood_light"},
		],
	})

	_add({
		"id": "planter_box", "shop": "potting",
		"name": "Planter Trough", "category": "Decor",
		"price": 230, "level": 11,
		"tint": Color(0.58, 0.48, 0.38),
		"parts": [
			{"shape": "box", "size": Vector3(1.20, 0.42, 0.38), "pos": Vector3(0, 0.21, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.24, 0.05, 0.42), "pos": Vector3(0, 0.44, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.10, 0.05, 0.30), "pos": Vector3(0, 0.42, 0), "mat": "soil"},
			{"shape": "sphere", "size": Vector3(0.22, 0.22, 0.22), "pos": Vector3(-0.36, 0.60, 0), "mat": "leaf"},
			{"shape": "sphere", "size": Vector3(0.26, 0.26, 0.26), "pos": Vector3(0.02, 0.64, 0.02), "mat": "leaf"},
			{"shape": "sphere", "size": Vector3(0.20, 0.20, 0.20), "pos": Vector3(0.38, 0.58, -0.02), "mat": "leaf"},
		],
	})
	_add({
		"id": "garden_bench", "against_wall": true, "shop": "potting",
		"name": "Garden Bench", "category": "Decor",
		"price": 280, "level": 11,
		"tint": Color(0.44, 0.52, 0.42),
		"parts": [
			{"shape": "box", "size": Vector3(1.44, 0.05, 0.16), "pos": Vector3(0, 0.44, -0.14), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.44, 0.05, 0.16), "pos": Vector3(0, 0.44, 0.06), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.44, 0.14, 0.05), "pos": Vector3(0, 0.72, -0.22), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.44, 0.14, 0.05), "pos": Vector3(0, 0.92, -0.22), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.07, 0.44, 0.44), "pos": Vector3(-0.66, 0.22, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.07, 0.44, 0.44), "pos": Vector3(0.66, 0.22, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.07, 0.58, 0.07), "pos": Vector3(-0.66, 0.70, -0.20), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.07, 0.58, 0.07), "pos": Vector3(0.66, 0.70, -0.20), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "fern_stand", "shop": "potting",
		"name": "Fern Stand", "category": "Decor",
		"price": 170, "level": 11,
		"tint": Color(0.66, 0.54, 0.42),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.20, 0.04, 0.20), "pos": Vector3(0, 0.02, 0), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.05, 0.86, 0.05), "pos": Vector3(0, 0.45, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.22, 0.04, 0.22), "pos": Vector3(0, 0.88, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.17, 0.20, 0.13), "pos": Vector3(0, 1.00, 0), "mat": "porcelain"},
			{"shape": "sphere", "size": Vector3(0.26, 0.26, 0.26), "pos": Vector3(0, 1.22, 0), "mat": "leaf"},
			{"shape": "sphere", "size": Vector3(0.16, 0.16, 0.16), "pos": Vector3(-0.18, 1.14, 0.06), "mat": "leaf"},
			{"shape": "sphere", "size": Vector3(0.15, 0.15, 0.15), "pos": Vector3(0.17, 1.12, -0.07), "mat": "leaf"},
		],
	})
	_add({
		"id": "herb_rack", "against_wall": true, "shop": "potting",
		"name": "Herb Rack", "category": "Kitchen",
		"price": 200, "level": 11,
		"tint": Color(0.60, 0.46, 0.32),
		"parts": [
			{"shape": "box", "size": Vector3(0.06, 1.40, 0.06), "pos": Vector3(-0.42, 0.70, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.06, 1.40, 0.06), "pos": Vector3(0.42, 0.70, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.42, 0.04, 0.32), "pos": Vector3(0, 0.02, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.90, 0.04, 0.24), "pos": Vector3(0, 0.62, 0), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.90, 0.04, 0.24), "pos": Vector3(0, 1.02, 0), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.90, 0.04, 0.24), "pos": Vector3(0, 1.38, 0), "mat": "wood_light"},
			{"shape": "cyl", "size": Vector3(0.08, 0.13, 0.06), "pos": Vector3(-0.24, 0.70, 0), "mat": "porcelain"},
			{"shape": "sphere", "size": Vector3(0.10, 0.10, 0.10), "pos": Vector3(-0.24, 0.82, 0), "mat": "leaf"},
			{"shape": "cyl", "size": Vector3(0.08, 0.13, 0.06), "pos": Vector3(0.20, 1.10, 0), "mat": "porcelain"},
			{"shape": "sphere", "size": Vector3(0.10, 0.10, 0.10), "pos": Vector3(0.20, 1.22, 0), "mat": "leaf"},
		],
	})
	_add({
		"id": "watering_shelf", "against_wall": true, "shop": "potting",
		"name": "Potting Shelf", "category": "Decor",
		"price": 240, "level": 11,
		"tint": Color(0.56, 0.50, 0.40),
		"parts": [
			{"shape": "box", "size": Vector3(1.10, 0.05, 0.44), "pos": Vector3(0, 0.75, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.10, 0.04, 0.40), "pos": Vector3(0, 0.30, 0), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.07, 0.78, 0.07), "pos": Vector3(-0.50, 0.39, -0.17), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.07, 0.78, 0.07), "pos": Vector3(0.50, 0.39, -0.17), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.07, 0.78, 0.07), "pos": Vector3(-0.50, 0.39, 0.17), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.07, 0.78, 0.07), "pos": Vector3(0.50, 0.39, 0.17), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.11, 0.20, 0.11), "pos": Vector3(-0.34, 0.88, 0), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.03, 0.26, 0.03), "pos": Vector3(-0.16, 0.92, 0), "mat": "steel", "rot": Vector3(0, 0, 62)},
			{"shape": "cyl", "size": Vector3(0.13, 0.16, 0.10), "pos": Vector3(0.16, 0.86, 0), "mat": "soil"},
			{"shape": "cyl", "size": Vector3(0.13, 0.16, 0.10), "pos": Vector3(0.42, 0.86, 0), "mat": "soil"},
		],
		"surface": 0.78,
	})


# ------------------------------------------------------------ Skyline Heights

## Atelier Nine and Lumen, at the top of the city and priced accordingly.
func _build_skyline() -> void:
	_add({
		"id": "designer_sofa", "against_wall": true, "shop": "atelier",
		"name": "Gallery Sofa", "category": "Living",
		"price": 1250, "level": 14,
		"tint": Color(0.26, 0.30, 0.36),
		"parts": [
			{"shape": "box", "size": Vector3(2.40, 0.30, 0.92), "pos": Vector3(0, 0.30, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(2.34, 0.16, 0.86), "pos": Vector3(0, 0.50, 0.02), "mat": "tint"},
			{"shape": "box", "size": Vector3(2.40, 0.44, 0.20), "pos": Vector3(0, 0.66, -0.36), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.16, 0.30, 0.92), "pos": Vector3(-1.12, 0.62, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.16, 0.30, 0.92), "pos": Vector3(1.12, 0.62, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(2.20, 0.06, 0.06), "pos": Vector3(0, 0.12, -0.40), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.04, 0.14, 0.04), "pos": Vector3(-1.06, 0.07, 0.34), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.04, 0.14, 0.04), "pos": Vector3(1.06, 0.07, 0.34), "mat": "steel"},
		],
	})
	_add({
		"id": "wing_chair", "shop": "atelier",
		"name": "Wing Chair", "category": "Living",
		"price": 680, "level": 14,
		"tint": Color(0.44, 0.26, 0.32),
		"parts": [
			{"shape": "box", "size": Vector3(0.76, 0.32, 0.74), "pos": Vector3(0, 0.32, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.70, 0.10, 0.68), "pos": Vector3(0, 0.52, 0.02), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.76, 0.92, 0.18), "pos": Vector3(0, 0.94, -0.28), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.14, 0.66, 0.60), "pos": Vector3(-0.31, 0.78, -0.04), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.14, 0.66, 0.60), "pos": Vector3(0.31, 0.78, -0.04), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.04, 0.16, 0.04), "pos": Vector3(-0.28, 0.08, -0.26), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.04, 0.16, 0.04), "pos": Vector3(0.28, 0.08, -0.26), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.04, 0.16, 0.04), "pos": Vector3(-0.28, 0.08, 0.28), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.04, 0.16, 0.04), "pos": Vector3(0.28, 0.08, 0.28), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "marble_table", "shop": "atelier",
		"name": "Marble Table", "category": "Dining",
		"price": 980, "level": 14,
		"tint": Color(0.92, 0.92, 0.90),
		"parts": [
			{"shape": "box", "size": Vector3(2.00, 0.09, 1.00), "pos": Vector3(0, 0.72, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.16, 0.68, 0.80), "pos": Vector3(-0.72, 0.34, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.16, 0.68, 0.80), "pos": Vector3(0.72, 0.34, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.30, 0.06, 0.10), "pos": Vector3(0, 0.20, 0), "mat": "steel"},
		],
		"surface": 0.77,
	})
	_add({
		"id": "sculpture_plinth", "shop": "atelier",
		"name": "Sculpture Plinth", "category": "Decor",
		"price": 540, "level": 14,
		"tint": Color(0.94, 0.93, 0.90),
		"parts": [
			{"shape": "box", "size": Vector3(0.42, 1.06, 0.42), "pos": Vector3(0, 0.53, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.48, 0.05, 0.48), "pos": Vector3(0, 1.08, 0), "mat": "tint"},
			{"shape": "sphere", "size": Vector3(0.17, 0.17, 0.17), "pos": Vector3(0, 1.24, 0), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.06, 0.34, 0.06), "pos": Vector3(0.02, 1.44, 0), "mat": "steel", "rot": Vector3(0, 0, 14)},
			{"shape": "sphere", "size": Vector3(0.11, 0.11, 0.11), "pos": Vector3(0.07, 1.62, 0), "mat": "steel"},
		],
		"surface": 1.11,
	})
	_add({
		"id": "drinks_cabinet", "against_wall": true, "shop": "atelier",
		"name": "Drinks Cabinet", "category": "Storage",
		"price": 860, "level": 14,
		"tint": Color(0.30, 0.22, 0.26),
		"parts": [
			{"shape": "box", "size": Vector3(0.96, 1.10, 0.44), "pos": Vector3(0, 0.72, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.86, 0.86, 0.03), "pos": Vector3(0, 0.76, 0.225), "mat": "glass"},
			{"shape": "box", "size": Vector3(0.88, 0.03, 0.38), "pos": Vector3(0, 0.62, 0), "mat": "mirror"},
			{"shape": "box", "size": Vector3(0.88, 0.03, 0.38), "pos": Vector3(0, 0.98, 0), "mat": "mirror"},
			{"shape": "box", "size": Vector3(1.00, 0.05, 0.48), "pos": Vector3(0, 1.29, 0), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.06, 0.24, 0.06), "pos": Vector3(-0.20, 0.72, 0), "mat": "glass"},
			{"shape": "cyl", "size": Vector3(0.05, 0.20, 0.05), "pos": Vector3(0.10, 1.10, 0), "mat": "glass"},
			{"shape": "box", "size": Vector3(0.08, 0.34, 0.08), "pos": Vector3(-0.40, 0.10, -0.14), "mat": "steel", "rot": Vector3(0, 0, 8)},
			{"shape": "box", "size": Vector3(0.08, 0.34, 0.08), "pos": Vector3(0.40, 0.10, -0.14), "mat": "steel", "rot": Vector3(0, 0, -8)},
			{"shape": "box", "size": Vector3(0.08, 0.34, 0.08), "pos": Vector3(-0.40, 0.10, 0.14), "mat": "steel", "rot": Vector3(0, 0, 8)},
			{"shape": "box", "size": Vector3(0.08, 0.34, 0.08), "pos": Vector3(0.40, 0.10, 0.14), "mat": "steel", "rot": Vector3(0, 0, -8)},
		],
		"surface": 1.32,
	})

	_add({
		"id": "arc_lamp", "shop": "lumen",
		"name": "Arc Lamp", "category": "Decor",
		"price": 620, "level": 14,
		"tint": Color(0.86, 0.86, 0.88),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.30, 0.06, 0.30), "pos": Vector3(0, 0.03, 0), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.05, 1.70, 0.05), "pos": Vector3(-0.52, 0.88, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.05, 0.70, 0.05), "pos": Vector3(-0.30, 1.68, 0), "mat": "tint", "rot": Vector3(0, 0, 66)},
			{"shape": "cyl", "size": Vector3(0.05, 0.60, 0.05), "pos": Vector3(0.18, 1.86, 0), "mat": "tint", "rot": Vector3(0, 0, 84)},
			{"shape": "cyl", "size": Vector3(0.26, 0.22, 0.20), "pos": Vector3(0.46, 1.76, 0), "mat": "white"},
		],
	})
	_add({
		"id": "pendant_cluster", "shop": "lumen",
		"name": "Pendant Cluster", "category": "Decor",
		"price": 480, "level": 14,
		"tint": Color(0.22, 0.23, 0.27),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.24, 0.05, 0.24), "pos": Vector3(0, 0.02, 0), "mat": "dark"},
			{"shape": "cyl", "size": Vector3(0.04, 2.06, 0.04), "pos": Vector3(0, 1.06, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.60, 0.04, 0.30), "pos": Vector3(0.18, 2.08, 0), "mat": "tint"},
			{"shape": "sphere", "size": Vector3(0.14, 0.14, 0.14), "pos": Vector3(0.02, 1.86, 0), "mat": "white"},
			{"shape": "sphere", "size": Vector3(0.12, 0.12, 0.12), "pos": Vector3(0.26, 1.70, 0.08), "mat": "white"},
			{"shape": "sphere", "size": Vector3(0.13, 0.13, 0.13), "pos": Vector3(0.38, 1.94, -0.06), "mat": "white"},
		],
	})
	_add({
		"id": "floor_uplighter", "shop": "lumen",
		"name": "Uplighter", "category": "Decor",
		"price": 330, "level": 14,
		"tint": Color(0.78, 0.80, 0.84),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.22, 0.05, 0.22), "pos": Vector3(0, 0.02, 0), "mat": "dark"},
			{"shape": "cyl", "size": Vector3(0.04, 1.56, 0.04), "pos": Vector3(0, 0.80, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.24, 0.20, 0.13), "pos": Vector3(0, 1.66, 0), "mat": "white"},
		],
	})
	_add({
		"id": "smart_panel", "against_wall": true, "shop": "lumen",
		"name": "Smart Panel", "category": "Electronics",
		"price": 740, "level": 14,
		"tint": Color(0.20, 0.21, 0.25),
		"parts": [
			{"shape": "box", "size": Vector3(0.50, 0.04, 0.34), "pos": Vector3(0, 0.02, 0), "mat": "dark"},
			{"shape": "cyl", "size": Vector3(0.04, 1.10, 0.04), "pos": Vector3(0, 0.57, 0), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.72, 0.50, 0.05), "pos": Vector3(0, 1.32, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.66, 0.44, 0.02), "pos": Vector3(0, 1.32, 0.035), "mat": "screen"},
			{"shape": "box", "size": Vector3(0.20, 0.03, 0.03), "pos": Vector3(0, 1.04, 0.02), "mat": "steel"},
		],
	})
	_add({
		"id": "projector", "against_wall": true, "shop": "lumen",
		"name": "Projector & Screen", "category": "Electronics",
		"price": 920, "level": 14,
		"tint": Color(0.94, 0.94, 0.92),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.04, 1.94, 0.04), "pos": Vector3(-0.82, 0.97, 0), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.04, 1.94, 0.04), "pos": Vector3(0.82, 0.97, 0), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.34, 0.04, 0.30), "pos": Vector3(-0.82, 0.02, 0), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.34, 0.04, 0.30), "pos": Vector3(0.82, 0.02, 0), "mat": "dark"},
			{"shape": "box", "size": Vector3(1.64, 1.02, 0.03), "pos": Vector3(0, 1.32, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.70, 0.08, 0.07), "pos": Vector3(0, 1.88, 0), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.34, 0.13, 0.26), "pos": Vector3(0, 0.34, 0.44), "mat": "dark"},
			{"shape": "cyl", "size": Vector3(0.05, 0.06, 0.05), "pos": Vector3(0, 0.34, 0.30), "mat": "glass", "rot": Vector3(90, 0, 0)},
		],
	})


# ------------------------------------------------------------- second wave

## Depth for the counters that were thinnest, and the stock for the four shops
## added alongside them: Attic & Loft on Maple's avenue, The Chandlery on the
## wharf, The Toy Cupboard up the slope and Vitrine in the towers.
func _build_second_wave() -> void:
	_build_attic()
	_build_chandlery()
	_build_toybox()
	_build_vitrine()
	_build_deeper_counters()


# -------------------------------------------------------- Attic & Loft (Maple)

func _build_attic() -> void:
	_add({
		"id": "blanket_box", "shop": "attic",
		"name": "Blanket Box", "category": "Storage",
		"price": 190, "level": 5,
		"tint": Color(0.62, 0.46, 0.30),
		"parts": [
			{"shape": "box", "size": Vector3(1.00, 0.38, 0.46), "pos": Vector3(0, 0.22, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.04, 0.06, 0.50), "pos": Vector3(0, 0.44, 0), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.96, 0.05, 0.42), "pos": Vector3(0, 0.03, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.12, 0.05, 0.04), "pos": Vector3(0, 0.30, 0.24), "mat": "steel"},
		],
		"surface": 0.47,
	})
	_add({
		"id": "hat_stand", "shop": "attic",
		"name": "Hat Stand", "category": "Decor",
		"price": 150, "level": 5,
		"tint": Color(0.42, 0.30, 0.22),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.24, 0.05, 0.24), "pos": Vector3(0, 0.02, 0), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.05, 1.66, 0.05), "pos": Vector3(0, 0.85, 0), "mat": "tint"},
			{"shape": "sphere", "size": Vector3(0.08, 0.08, 0.08), "pos": Vector3(0, 1.70, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.03, 0.26, 0.03), "pos": Vector3(0.11, 1.54, 0), "mat": "tint", "rot": Vector3(0, 0, 70)},
			{"shape": "cyl", "size": Vector3(0.03, 0.26, 0.03), "pos": Vector3(-0.11, 1.54, 0), "mat": "tint", "rot": Vector3(0, 0, -70)},
			{"shape": "cyl", "size": Vector3(0.03, 0.26, 0.03), "pos": Vector3(0, 1.54, 0.11), "mat": "tint", "rot": Vector3(70, 0, 0)},
			{"shape": "cyl", "size": Vector3(0.20, 0.09, 0.20), "pos": Vector3(0.16, 1.50, 0), "mat": "towel"},
		],
	})
	_add({
		"id": "step_ladder", "shop": "attic",
		"name": "Step Ladder", "category": "Storage",
		"price": 170, "level": 5,
		"tint": Color(0.76, 0.68, 0.52),
		"parts": [
			{"shape": "box", "size": Vector3(0.05, 1.50, 0.05), "pos": Vector3(-0.26, 0.75, -0.16), "mat": "tint", "rot": Vector3(-10, 0, 0)},
			{"shape": "box", "size": Vector3(0.05, 1.50, 0.05), "pos": Vector3(0.26, 0.75, -0.16), "mat": "tint", "rot": Vector3(-10, 0, 0)},
			{"shape": "box", "size": Vector3(0.05, 1.44, 0.05), "pos": Vector3(-0.26, 0.72, 0.20), "mat": "tint", "rot": Vector3(12, 0, 0)},
			{"shape": "box", "size": Vector3(0.05, 1.44, 0.05), "pos": Vector3(0.26, 0.72, 0.20), "mat": "tint", "rot": Vector3(12, 0, 0)},
			{"shape": "box", "size": Vector3(0.58, 0.04, 0.20), "pos": Vector3(0, 0.36, -0.08), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.58, 0.04, 0.20), "pos": Vector3(0, 0.76, -0.13), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.58, 0.04, 0.20), "pos": Vector3(0, 1.16, -0.19), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.58, 0.04, 0.34), "pos": Vector3(0, 1.46, -0.02), "mat": "wood_light"},
		],
		"surface": 1.49,
	})
	_add({
		"id": "trunk_stack", "against_wall": true, "shop": "attic",
		"name": "Stacked Trunks", "category": "Storage",
		"price": 240, "level": 5,
		"tint": Color(0.48, 0.34, 0.26),
		"parts": [
			{"shape": "box", "size": Vector3(0.90, 0.42, 0.52), "pos": Vector3(0, 0.21, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.94, 0.06, 0.56), "pos": Vector3(0, 0.44, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.76, 0.34, 0.46), "pos": Vector3(0.02, 0.64, 0), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.80, 0.05, 0.50), "pos": Vector3(0.02, 0.83, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.58, 0.26, 0.38), "pos": Vector3(-0.04, 0.98, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.62, 0.04, 0.42), "pos": Vector3(-0.04, 1.13, 0), "mat": "steel"},
		],
		"surface": 1.15,
	})
	_add({
		"id": "mantel_clock", "stackable": true, "shop": "attic",
		"name": "Mantel Clock", "category": "Decor",
		"price": 90, "level": 5,
		"tint": Color(0.44, 0.28, 0.18),
		"parts": [
			{"shape": "box", "size": Vector3(0.26, 0.30, 0.12), "pos": Vector3(0, 0.17, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.30, 0.05, 0.16), "pos": Vector3(0, 0.02, 0), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.10, 0.03, 0.10), "pos": Vector3(0, 0.20, 0.07), "mat": "porcelain", "rot": Vector3(90, 0, 0)},
			{"shape": "box", "size": Vector3(0.02, 0.07, 0.01), "pos": Vector3(0, 0.23, 0.09), "mat": "dark"},
		],
	})


# ------------------------------------------------------ The Chandlery (wharf)

func _build_chandlery() -> void:
	_add({
		"id": "lantern", "shop": "chandlery",
		"name": "Deck Lantern", "category": "Decor",
		"price": 160, "level": 8,
		"tint": Color(0.30, 0.34, 0.38),
		"parts": [
			{"shape": "box", "size": Vector3(0.34, 0.05, 0.34), "pos": Vector3(0, 0.02, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.04, 0.92, 0.04), "pos": Vector3(0, 0.48, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.26, 0.32, 0.26), "pos": Vector3(0, 1.08, 0), "mat": "glass"},
			{"shape": "box", "size": Vector3(0.30, 0.06, 0.30), "pos": Vector3(0, 0.90, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.30, 0.08, 0.30), "pos": Vector3(0, 1.27, 0), "mat": "tint"},
			{"shape": "sphere", "size": Vector3(0.09, 0.09, 0.09), "pos": Vector3(0, 1.08, 0), "mat": "white"},
		],
	})
	_add({
		"id": "rope_coil", "stackable": true, "shop": "chandlery",
		"name": "Coil of Rope", "category": "Decor",
		"price": 80, "level": 8,
		"tint": Color(0.78, 0.70, 0.52),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.30, 0.07, 0.30), "pos": Vector3(0, 0.035, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.24, 0.07, 0.24), "pos": Vector3(0.02, 0.10, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.17, 0.06, 0.17), "pos": Vector3(-0.01, 0.16, 0.01), "mat": "tint"},
		],
	})
	_add({
		"id": "galley_shelf", "against_wall": true, "shop": "chandlery",
		"name": "Galley Shelf", "category": "Kitchen",
		"price": 290, "level": 8,
		"tint": Color(0.66, 0.56, 0.44),
		"parts": [
			{"shape": "box", "size": Vector3(1.20, 0.06, 0.34), "pos": Vector3(0, 0.86, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.20, 0.06, 0.30), "pos": Vector3(0, 1.24, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.20, 0.06, 0.26), "pos": Vector3(0, 1.58, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.07, 1.62, 0.07), "pos": Vector3(-0.56, 0.81, -0.12), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.07, 1.62, 0.07), "pos": Vector3(0.56, 0.81, -0.12), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.16, 0.03, 0.03), "pos": Vector3(0, 0.96, 0.15), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.08, 0.13, 0.08), "pos": Vector3(-0.30, 1.32, 0), "mat": "porcelain"},
			{"shape": "cyl", "size": Vector3(0.08, 0.13, 0.08), "pos": Vector3(0.10, 1.32, 0), "mat": "porcelain"},
		],
		"surface": 0.89,
	})
	_add({
		"id": "cask_stand", "shop": "chandlery",
		"name": "Cask Stand", "category": "Kitchen",
		"price": 330, "level": 8,
		"tint": Color(0.52, 0.34, 0.22),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.30, 0.90, 0.30), "pos": Vector3(0, 0.52, 0), "mat": "tint", "rot": Vector3(90, 0, 0)},
			{"shape": "cyl", "size": Vector3(0.32, 0.05, 0.32), "pos": Vector3(0, 0.52, -0.30), "mat": "steel", "rot": Vector3(90, 0, 0)},
			{"shape": "cyl", "size": Vector3(0.32, 0.05, 0.32), "pos": Vector3(0, 0.52, 0.30), "mat": "steel", "rot": Vector3(90, 0, 0)},
			{"shape": "box", "size": Vector3(0.66, 0.10, 0.14), "pos": Vector3(0, 0.05, -0.24), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.66, 0.10, 0.14), "pos": Vector3(0, 0.05, 0.24), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.10, 0.44, 0.10), "pos": Vector3(-0.28, 0.28, -0.24), "mat": "wood_dark", "rot": Vector3(0, 0, 20)},
			{"shape": "box", "size": Vector3(0.10, 0.44, 0.10), "pos": Vector3(0.28, 0.28, -0.24), "mat": "wood_dark", "rot": Vector3(0, 0, -20)},
			{"shape": "box", "size": Vector3(0.10, 0.44, 0.10), "pos": Vector3(-0.28, 0.28, 0.24), "mat": "wood_dark", "rot": Vector3(0, 0, 20)},
			{"shape": "box", "size": Vector3(0.10, 0.44, 0.10), "pos": Vector3(0.28, 0.28, 0.24), "mat": "wood_dark", "rot": Vector3(0, 0, -20)},
			{"shape": "cyl", "size": Vector3(0.03, 0.14, 0.03), "pos": Vector3(0, 0.42, 0.36), "mat": "steel", "rot": Vector3(90, 0, 0)},
		],
		"surface": 0.84,
	})
	_add({
		"id": "signal_flags", "against_wall": true, "shop": "chandlery",
		"name": "Signal Flags", "category": "Decor",
		"price": 140, "level": 8,
		"tint": Color(0.88, 0.34, 0.30),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.04, 1.80, 0.04), "pos": Vector3(-0.60, 0.90, 0), "mat": "wood_light"},
			{"shape": "cyl", "size": Vector3(0.04, 1.80, 0.04), "pos": Vector3(0.60, 0.90, 0), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.36, 0.04, 0.28), "pos": Vector3(-0.60, 0.02, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.36, 0.04, 0.28), "pos": Vector3(0.60, 0.02, 0), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.02, 1.20, 0.02), "pos": Vector3(0, 1.74, 0), "mat": "steel", "rot": Vector3(0, 0, 90)},
			{"shape": "box", "size": Vector3(0.26, 0.30, 0.02), "pos": Vector3(-0.36, 1.56, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.26, 0.30, 0.02), "pos": Vector3(0.00, 1.56, 0), "mat": "white"},
			{"shape": "box", "size": Vector3(0.26, 0.30, 0.02), "pos": Vector3(0.36, 1.56, 0), "mat": "steel"},
		],
	})


# -------------------------------------------------- The Toy Cupboard (slope)

func _build_toybox() -> void:
	_add({
		"id": "toy_chest", "shop": "toybox",
		"name": "Toy Chest", "category": "Bedroom",
		"price": 220, "level": 11,
		"tint": Color(0.94, 0.60, 0.34),
		"parts": [
			{"shape": "box", "size": Vector3(0.90, 0.40, 0.44), "pos": Vector3(0, 0.24, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.94, 0.06, 0.48), "pos": Vector3(0, 0.46, 0), "mat": "white"},
			{"shape": "box", "size": Vector3(0.86, 0.06, 0.40), "pos": Vector3(0, 0.03, 0), "mat": "wood_light"},
			{"shape": "sphere", "size": Vector3(0.16, 0.16, 0.16), "pos": Vector3(-0.24, 0.56, 0), "mat": "leaf"},
			{"shape": "box", "size": Vector3(0.16, 0.16, 0.16), "pos": Vector3(0.06, 0.56, 0.04), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.09, 0.16, 0.09), "pos": Vector3(0.30, 0.56, -0.02), "mat": "porcelain"},
		],
		"surface": 0.49,
	})
	_add({
		"id": "play_mat", "shop": "toybox",
		"name": "Play Mat", "category": "Decor",
		"price": 130, "level": 11,
		"tint": Color(0.44, 0.72, 0.86),
		"parts": [
			{"shape": "box", "size": Vector3(1.70, 0.03, 1.30), "pos": Vector3(0, 0.015, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.54, 0.04, 0.42), "pos": Vector3(-0.44, 0.02, -0.32), "mat": "leaf"},
			{"shape": "box", "size": Vector3(0.54, 0.04, 0.42), "pos": Vector3(0.44, 0.02, 0.32), "mat": "white"},
			{"shape": "cyl", "size": Vector3(0.26, 0.04, 0.26), "pos": Vector3(0.38, 0.02, -0.30), "mat": "towel"},
		],
	})
	_add({
		"id": "rocking_horse", "shop": "toybox",
		"name": "Rocking Horse", "category": "Decor",
		"price": 260, "level": 11,
		"tint": Color(0.84, 0.70, 0.52),
		"parts": [
			{"shape": "box", "size": Vector3(0.06, 0.10, 0.94), "pos": Vector3(-0.20, 0.06, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.06, 0.10, 0.94), "pos": Vector3(0.20, 0.06, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.34, 0.06, 0.30), "pos": Vector3(0, 0.14, 0), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.30, 0.34, 0.70), "pos": Vector3(0, 0.44, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.22, 0.30, 0.22), "pos": Vector3(0, 0.72, -0.28), "mat": "tint", "rot": Vector3(24, 0, 0)},
			{"shape": "box", "size": Vector3(0.18, 0.16, 0.24), "pos": Vector3(0, 0.86, -0.38), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.24, 0.06, 0.10), "pos": Vector3(0, 0.62, 0.30), "mat": "white"},
			{"shape": "cyl", "size": Vector3(0.02, 0.34, 0.02), "pos": Vector3(0, 0.78, -0.22), "mat": "steel", "rot": Vector3(0, 0, 90)},
		],
	})
	_add({
		"id": "bookcase_low", "against_wall": true, "shop": "toybox",
		"name": "Low Bookcase", "category": "Bedroom",
		"price": 280, "level": 11,
		"tint": Color(0.96, 0.80, 0.42),
		"parts": [
			{"shape": "box", "size": Vector3(0.05, 0.86, 0.30), "pos": Vector3(-0.55, 0.43, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.05, 0.86, 0.30), "pos": Vector3(0.55, 0.43, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.14, 0.05, 0.30), "pos": Vector3(0, 0.84, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.06, 0.04, 0.30), "pos": Vector3(0, 0.04, 0), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(1.06, 0.04, 0.30), "pos": Vector3(0, 0.42, 0), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.24, 0.24, 0.18), "pos": Vector3(-0.30, 0.56, 0), "mat": "leaf"},
			{"shape": "box", "size": Vector3(0.20, 0.22, 0.18), "pos": Vector3(0.16, 0.18, 0), "mat": "towel"},
		],
		"surface": 0.87,
	})
	_add({
		"id": "night_light", "stackable": true, "shop": "toybox",
		"name": "Night Light", "category": "Decor",
		"price": 70, "level": 11,
		"tint": Color(0.98, 0.86, 0.56),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.11, 0.04, 0.11), "pos": Vector3(0, 0.02, 0), "mat": "white"},
			{"shape": "sphere", "size": Vector3(0.13, 0.13, 0.13), "pos": Vector3(0, 0.15, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.03, 0.09, 0.03), "pos": Vector3(0, 0.28, 0), "mat": "white"},
		],
	})


# ------------------------------------------------------------ Vitrine (towers)

func _build_vitrine() -> void:
	_add({
		"id": "glass_case", "against_wall": true, "shop": "vitrine",
		"name": "Glass Case", "category": "Storage",
		"price": 780, "level": 14,
		"tint": Color(0.24, 0.25, 0.30),
		"parts": [
			{"shape": "box", "size": Vector3(1.10, 0.14, 0.48), "pos": Vector3(0, 0.07, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.10, 0.06, 0.48), "pos": Vector3(0, 1.18, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.02, 1.00, 0.03), "pos": Vector3(0, 0.66, 0.225), "mat": "glass"},
			{"shape": "box", "size": Vector3(1.02, 1.00, 0.03), "pos": Vector3(0, 0.66, -0.225), "mat": "glass"},
			{"shape": "box", "size": Vector3(0.03, 1.00, 0.44), "pos": Vector3(-0.53, 0.66, 0), "mat": "glass"},
			{"shape": "box", "size": Vector3(0.03, 1.00, 0.44), "pos": Vector3(0.53, 0.66, 0), "mat": "glass"},
			{"shape": "box", "size": Vector3(1.00, 0.03, 0.42), "pos": Vector3(0, 0.72, 0), "mat": "mirror"},
			{"shape": "sphere", "size": Vector3(0.11, 0.11, 0.11), "pos": Vector3(-0.28, 0.86, 0), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.08, 0.20, 0.08), "pos": Vector3(0.24, 0.28, 0), "mat": "porcelain"},
		],
		"surface": 1.21,
	})
	_add({
		"id": "pedestal_vase", "shop": "vitrine",
		"name": "Pedestal Vase", "category": "Decor",
		"price": 420, "level": 14,
		"tint": Color(0.72, 0.78, 0.80),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.28, 0.10, 0.28), "pos": Vector3(0, 0.05, 0), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.14, 0.44, 0.14), "pos": Vector3(0, 0.32, 0), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.30, 0.62, 0.20), "pos": Vector3(0, 0.85, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.16, 0.14, 0.16), "pos": Vector3(0, 1.21, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.02, 0.46, 0.02), "pos": Vector3(0.04, 1.44, 0), "mat": "leaf", "rot": Vector3(0, 0, 10)},
			{"shape": "sphere", "size": Vector3(0.12, 0.12, 0.12), "pos": Vector3(0.09, 1.66, 0), "mat": "leaf"},
		],
	})
	_add({
		"id": "art_easel", "shop": "vitrine",
		"name": "Art Easel", "category": "Decor",
		"price": 360, "level": 14,
		"tint": Color(0.58, 0.44, 0.28),
		"parts": [
			{"shape": "box", "size": Vector3(0.05, 1.70, 0.05), "pos": Vector3(-0.30, 0.85, 0.10), "mat": "tint", "rot": Vector3(8, 0, 0)},
			{"shape": "box", "size": Vector3(0.05, 1.70, 0.05), "pos": Vector3(0.30, 0.85, 0.10), "mat": "tint", "rot": Vector3(8, 0, 0)},
			{"shape": "box", "size": Vector3(0.05, 1.62, 0.05), "pos": Vector3(0, 0.81, -0.28), "mat": "tint", "rot": Vector3(-16, 0, 0)},
			{"shape": "box", "size": Vector3(0.70, 0.06, 0.12), "pos": Vector3(0, 0.72, 0.06), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.78, 0.62, 0.04), "pos": Vector3(0, 1.08, 0.04), "mat": "white"},
			{"shape": "box", "size": Vector3(0.66, 0.50, 0.02), "pos": Vector3(0, 1.08, 0.07), "mat": "steel"},
		],
	})
	_add({
		"id": "mirror_wall", "against_wall": true, "shop": "vitrine",
		"name": "Gallery Mirror", "category": "Decor",
		"price": 690, "level": 14,
		"tint": Color(0.30, 0.31, 0.36),
		"parts": [
			{"shape": "box", "size": Vector3(1.40, 2.00, 0.09), "pos": Vector3(0, 1.00, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.24, 1.84, 0.03), "pos": Vector3(0, 1.00, 0.055), "mat": "mirror"},
			{"shape": "box", "size": Vector3(1.48, 0.07, 0.16), "pos": Vector3(0, 0.03, 0), "mat": "steel"},
			{"shape": "box", "size": Vector3(1.48, 0.06, 0.14), "pos": Vector3(0, 2.02, 0), "mat": "steel"},
		],
	})
	_add({
		"id": "crystal_bowl", "stackable": true, "shop": "vitrine",
		"name": "Crystal Bowl", "category": "Decor",
		"price": 240, "level": 14,
		"tint": Color(0.74, 0.86, 0.90),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.20, 0.13, 0.11), "pos": Vector3(0, 0.10, 0), "mat": "glass"},
			{"shape": "cyl", "size": Vector3(0.09, 0.05, 0.09), "pos": Vector3(0, 0.02, 0), "mat": "tint"},
		],
	})


# ----------------------------------------------- depth for the older counters

func _build_deeper_counters() -> void:
	_add({
		"id": "chaise", "against_wall": true, "name": "Chaise Longue", "category": "Living",
		"price": 560, "level": 5,
		"tint": Color(0.46, 0.34, 0.46),
		"parts": _sofa(1.10, 1.90) + [
			{"shape": "box", "size": Vector3(1.02, 0.20, 0.44), "pos": Vector3(0, 0.48, 0.62), "mat": "white"},
		],
	})
	_add({
		"id": "corner_sofa", "against_wall": true, "name": "Corner Sofa", "category": "Living",
		"price": 940, "level": 5,
		"tint": Color(0.38, 0.40, 0.46),
		"parts": _sofa(2.30, 0.95) + [
			{"shape": "box", "size": Vector3(0.95, 0.32, 1.10), "pos": Vector3(1.62, 0.22, 0.55), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.22, 0.58, 1.10), "pos": Vector3(1.99, 0.62, 0.55), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.78, 0.16, 0.94), "pos": Vector3(1.56, 0.46, 0.55), "mat": "white"},
		],
	})
	_add({
		"id": "bed_king", "against_wall": true, "name": "King Bed", "category": "Bedroom",
		"price": 880, "level": 5,
		"tint": Color(0.40, 0.36, 0.46),
		"parts": _bed(1.90, 2.10),
	})
	_add({
		"id": "bedside_shelf", "against_wall": true, "name": "Bedside Shelf", "category": "Bedroom",
		"price": 150, "level": 3,
		"tint": Color(0.72, 0.62, 0.48),
		"parts": [
			{"shape": "box", "size": Vector3(0.46, 0.04, 0.32), "pos": Vector3(0, 0.56, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.46, 0.04, 0.32), "pos": Vector3(0, 0.26, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.05, 0.60, 0.05), "pos": Vector3(-0.20, 0.29, -0.12), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.05, 0.60, 0.05), "pos": Vector3(0.20, 0.29, -0.12), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.05, 0.60, 0.05), "pos": Vector3(-0.20, 0.29, 0.12), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.05, 0.60, 0.05), "pos": Vector3(0.20, 0.29, 0.12), "mat": "wood_dark"},
		],
		"surface": 0.58,
	})
	_add({
		"id": "bistro_table", "name": "Bistro Table", "category": "Dining",
		"price": 260, "level": 3,
		"tint": Color(0.86, 0.86, 0.84),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.38, 0.05, 0.38), "pos": Vector3(0, 0.73, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.05, 0.70, 0.05), "pos": Vector3(0, 0.35, 0), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.28, 0.05, 0.28), "pos": Vector3(0, 0.02, 0), "mat": "steel"},
		],
		"surface": 0.76,
	})
	_add({
		"id": "bench_long", "name": "Long Bench", "category": "Dining",
		"price": 240, "level": 3,
		"tint": Color(0.60, 0.42, 0.26),
		"parts": [
			{"shape": "box", "size": Vector3(1.70, 0.07, 0.36), "pos": Vector3(0, 0.44, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.08, 0.42, 0.32), "pos": Vector3(-0.72, 0.21, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.08, 0.42, 0.32), "pos": Vector3(0.72, 0.21, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.30, 0.05, 0.05), "pos": Vector3(0, 0.18, 0), "mat": "wood_dark"},
		],
		"surface": 0.48,
	})
	_add({
		"id": "range_hood", "against_wall": true, "name": "Range Hood", "category": "Kitchen",
		"price": 420, "level": 5,
		"tint": Color(0.82, 0.84, 0.87),
		"parts": [
			{"shape": "box", "size": Vector3(0.90, 0.16, 0.52), "pos": Vector3(0, 1.52, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.90, 0.34, 0.52), "pos": Vector3(0, 1.74, 0), "mat": "tint", "rot": Vector3(-14, 0, 0)},
			{"shape": "box", "size": Vector3(0.36, 0.60, 0.28), "pos": Vector3(0, 2.16, -0.10), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.80, 0.03, 0.40), "pos": Vector3(0, 1.44, 0), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.10, 1.44, 0.10), "pos": Vector3(-0.40, 0.72, -0.20), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.10, 1.44, 0.10), "pos": Vector3(0.40, 0.72, -0.20), "mat": "steel"},
		],
	})
	_add({
		"id": "kitchen_trolley", "name": "Kitchen Trolley", "category": "Kitchen",
		"price": 290, "level": 3,
		"tint": Color(0.88, 0.88, 0.86),
		"parts": [
			{"shape": "box", "size": Vector3(0.80, 0.05, 0.44), "pos": Vector3(0, 0.85, 0), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.76, 0.04, 0.40), "pos": Vector3(0, 0.52, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.76, 0.04, 0.40), "pos": Vector3(0, 0.24, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.03, 0.76, 0.03), "pos": Vector3(-0.35, 0.48, -0.18), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.03, 0.76, 0.03), "pos": Vector3(0.35, 0.48, -0.18), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.03, 0.76, 0.03), "pos": Vector3(-0.35, 0.48, 0.18), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.03, 0.76, 0.03), "pos": Vector3(0.35, 0.48, 0.18), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.05, 0.04, 0.05), "pos": Vector3(-0.35, 0.05, 0.18), "mat": "dark", "rot": Vector3(0, 0, 90)},
			{"shape": "cyl", "size": Vector3(0.05, 0.04, 0.05), "pos": Vector3(0.35, 0.05, 0.18), "mat": "dark", "rot": Vector3(0, 0, 90)},
		],
		"surface": 0.88,
	})
	_add({
		"id": "corner_shower", "against_wall": true, "name": "Corner Shower", "category": "Bathroom",
		"price": 700, "level": 5,
		"tint": Color(0.94, 0.95, 0.96),
		"parts": [
			{"shape": "box", "size": Vector3(1.10, 0.12, 1.10), "pos": Vector3(0, 0.06, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.10, 2.00, 0.05), "pos": Vector3(0, 1.06, -0.53), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.05, 2.00, 1.10), "pos": Vector3(-0.53, 1.06, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.02, 1.86, 0.03), "pos": Vector3(0.06, 1.02, 0.50), "mat": "glass", "rot": Vector3(0, -34, 0)},
			{"shape": "cyl", "size": Vector3(0.03, 0.60, 0.03), "pos": Vector3(-0.42, 1.50, -0.44), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.11, 0.04, 0.11), "pos": Vector3(-0.42, 1.82, -0.36), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.10, 0.22, 0.06), "pos": Vector3(-0.48, 1.06, -0.30), "mat": "steel"},
		],
	})
	_add({
		"id": "bath_screen", "against_wall": true, "name": "Bath Screen", "category": "Bathroom",
		"price": 260, "level": 5,
		"tint": Color(0.86, 0.90, 0.92),
		"parts": [
			{"shape": "box", "size": Vector3(0.08, 1.50, 0.08), "pos": Vector3(-0.42, 0.75, 0), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.80, 1.44, 0.03), "pos": Vector3(0, 0.76, 0), "mat": "glass"},
			{"shape": "box", "size": Vector3(0.86, 0.06, 0.24), "pos": Vector3(0, 0.02, 0), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.86, 0.05, 0.06), "pos": Vector3(0, 1.50, 0), "mat": "steel"},
		],
	})
	_add({
		"id": "turntable", "stackable": true, "name": "Turntable", "category": "Electronics",
		"price": 460, "level": 5,
		"tint": Color(0.20, 0.21, 0.24),
		"parts": [
			{"shape": "box", "size": Vector3(0.46, 0.11, 0.36), "pos": Vector3(0, 0.055, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.15, 0.03, 0.15), "pos": Vector3(-0.04, 0.12, 0), "mat": "dark"},
			{"shape": "cyl", "size": Vector3(0.02, 0.03, 0.02), "pos": Vector3(-0.04, 0.14, 0), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.03, 0.02, 0.22), "pos": Vector3(0.14, 0.13, -0.02), "mat": "steel", "rot": Vector3(0, 24, 0)},
			{"shape": "box", "size": Vector3(0.44, 0.02, 0.34), "pos": Vector3(0, 0.24, 0), "mat": "glass"},
		],
	})
	_add({
		"id": "robot_vacuum", "name": "Robot Vacuum", "category": "Electronics",
		"price": 380, "level": 5,
		"tint": Color(0.26, 0.27, 0.32),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.18, 0.09, 0.18), "pos": Vector3(0, 0.045, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.06, 0.02, 0.06), "pos": Vector3(0, 0.10, 0), "mat": "screen"},
			{"shape": "box", "size": Vector3(0.30, 0.05, 0.24), "pos": Vector3(0, 0.025, 0.16), "mat": "dark"},
		],
	})
	_add({
		"id": "filing_cabinet", "against_wall": true, "name": "Filing Cabinet", "category": "Storage",
		"price": 310, "level": 3,
		"tint": Color(0.62, 0.64, 0.68),
		"parts": [
			{"shape": "box", "size": Vector3(0.48, 1.06, 0.60), "pos": Vector3(0, 0.55, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.48, 0.05, 0.62), "pos": Vector3(0, 1.10, 0), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.42, 0.30, 0.03), "pos": Vector3(0, 0.26, 0.305), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.42, 0.30, 0.03), "pos": Vector3(0, 0.60, 0.305), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.42, 0.30, 0.03), "pos": Vector3(0, 0.94, 0.305), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.14, 0.03, 0.03), "pos": Vector3(0, 0.26, 0.33), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.14, 0.03, 0.03), "pos": Vector3(0, 0.60, 0.33), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.14, 0.03, 0.03), "pos": Vector3(0, 0.94, 0.33), "mat": "dark"},
		],
		"surface": 1.13,
	})
	_add({
		"id": "ladder_shelf", "against_wall": true, "name": "Ladder Shelf", "category": "Storage",
		"price": 340, "level": 3,
		"tint": Color(0.68, 0.50, 0.32),
		"parts": [
			{"shape": "box", "size": Vector3(0.06, 1.82, 0.06), "pos": Vector3(-0.42, 0.91, 0.06), "mat": "tint", "rot": Vector3(6, 0, 0)},
			{"shape": "box", "size": Vector3(0.06, 1.82, 0.06), "pos": Vector3(0.42, 0.91, 0.06), "mat": "tint", "rot": Vector3(6, 0, 0)},
			{"shape": "box", "size": Vector3(0.90, 0.04, 0.42), "pos": Vector3(0, 0.30, 0.13), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.86, 0.04, 0.36), "pos": Vector3(0, 0.76, 0.08), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.82, 0.04, 0.30), "pos": Vector3(0, 1.22, 0.03), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.78, 0.04, 0.24), "pos": Vector3(0, 1.68, -0.02), "mat": "wood_light"},
		],
		"surface": 1.70,
	})
	_add({
		"id": "wall_art", "against_wall": true, "name": "Framed Print", "category": "Decor",
		"price": 190, "level": 3,
		"tint": Color(0.34, 0.30, 0.26),
		"parts": [
			{"shape": "box", "size": Vector3(0.10, 1.34, 0.10), "pos": Vector3(0, 0.67, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.52, 0.06, 0.34), "pos": Vector3(0, 0.03, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.86, 0.66, 0.06), "pos": Vector3(0, 1.52, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.72, 0.52, 0.02), "pos": Vector3(0, 1.52, 0.04), "mat": "white"},
		],
	})
	_add({
		"id": "umbrella_stand", "name": "Umbrella Stand", "category": "Decor",
		"price": 110, "level": 1,
		"tint": Color(0.46, 0.48, 0.52),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.17, 0.56, 0.17), "pos": Vector3(0, 0.28, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.19, 0.05, 0.19), "pos": Vector3(0, 0.02, 0), "mat": "dark"},
			{"shape": "cyl", "size": Vector3(0.03, 0.74, 0.03), "pos": Vector3(0.05, 0.50, 0.02), "mat": "wood_dark", "rot": Vector3(4, 0, -8)},
			{"shape": "cyl", "size": Vector3(0.03, 0.70, 0.03), "pos": Vector3(-0.04, 0.48, -0.03), "mat": "leaf", "rot": Vector3(-3, 0, 6)},
		],
	})
	_add({
		"id": "girder_shelf", "against_wall": true, "shop": "salvage",
		"name": "Girder Shelving", "category": "Storage",
		"price": 460, "level": 8,
		"tint": Color(0.56, 0.36, 0.28),
		"parts": [
			{"shape": "box", "size": Vector3(0.10, 2.00, 0.10), "pos": Vector3(-0.80, 1.00, -0.20), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.10, 2.00, 0.10), "pos": Vector3(0.80, 1.00, -0.20), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.10, 2.00, 0.10), "pos": Vector3(-0.80, 1.00, 0.20), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.10, 2.00, 0.10), "pos": Vector3(0.80, 1.00, 0.20), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.76, 0.06, 0.52), "pos": Vector3(0, 0.36, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.76, 0.06, 0.52), "pos": Vector3(0, 0.96, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.76, 0.06, 0.52), "pos": Vector3(0, 1.56, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.76, 0.06, 0.52), "pos": Vector3(0, 1.98, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.70, 0.04, 0.04), "pos": Vector3(0, 1.30, -0.22), "mat": "steel", "rot": Vector3(0, 0, 14)},
		],
		"surface": 2.01,
	})
	_add({
		"id": "rope_swing", "shop": "ropewalk",
		"name": "Rope Swing", "category": "Decor",
		"price": 280, "level": 8,
		"tint": Color(0.84, 0.76, 0.58),
		"parts": [
			{"shape": "box", "size": Vector3(0.09, 2.00, 0.09), "pos": Vector3(-0.62, 1.00, 0), "mat": "wood_dark", "rot": Vector3(0, 0, 7)},
			{"shape": "box", "size": Vector3(0.09, 2.00, 0.09), "pos": Vector3(0.62, 1.00, 0), "mat": "wood_dark", "rot": Vector3(0, 0, -7)},
			{"shape": "box", "size": Vector3(1.50, 0.09, 0.09), "pos": Vector3(0, 1.98, 0), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.02, 1.20, 0.02), "pos": Vector3(-0.26, 1.36, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.02, 1.20, 0.02), "pos": Vector3(0.26, 1.36, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.62, 0.05, 0.24), "pos": Vector3(0, 0.74, 0), "mat": "wood_light"},
		],
	})
	_add({
		"id": "fireside_set", "against_wall": true, "shop": "hearth",
		"name": "Fireside Set", "category": "Decor",
		"price": 230, "level": 11,
		"tint": Color(0.26, 0.27, 0.30),
		"parts": [
			{"shape": "box", "size": Vector3(0.80, 0.14, 0.34), "pos": Vector3(0, 0.07, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.72, 0.44, 0.06), "pos": Vector3(0, 0.36, -0.14), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.05, 0.06, 0.05), "pos": Vector3(0.30, 0.17, 0.06), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.02, 0.72, 0.02), "pos": Vector3(0.30, 0.50, 0.06), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.02, 0.66, 0.02), "pos": Vector3(0.22, 0.47, 0.06), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.13, 0.24, 0.13), "pos": Vector3(-0.22, 0.26, 0.02), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.05, 0.30, 0.05), "pos": Vector3(-0.22, 0.42, 0.02), "mat": "wood_light", "rot": Vector3(10, 0, 6)},
		],
	})
	_add({
		"id": "tall_planter", "shop": "potting",
		"name": "Tall Planter", "category": "Decor",
		"price": 260, "level": 11,
		"tint": Color(0.64, 0.58, 0.46),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.26, 0.86, 0.22), "pos": Vector3(0, 0.43, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.28, 0.06, 0.28), "pos": Vector3(0, 0.86, 0), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.22, 0.04, 0.22), "pos": Vector3(0, 0.86, 0), "mat": "soil"},
			{"shape": "cyl", "size": Vector3(0.03, 0.80, 0.03), "pos": Vector3(0, 1.28, 0), "mat": "wood_dark"},
			{"shape": "sphere", "size": Vector3(0.30, 0.30, 0.30), "pos": Vector3(0, 1.72, 0), "mat": "leaf"},
			{"shape": "sphere", "size": Vector3(0.20, 0.20, 0.20), "pos": Vector3(-0.20, 1.58, 0.06), "mat": "leaf"},
			{"shape": "sphere", "size": Vector3(0.18, 0.18, 0.18), "pos": Vector3(0.19, 1.60, -0.06), "mat": "leaf"},
		],
	})
	_add({
		"id": "marble_console", "against_wall": true, "shop": "atelier",
		"name": "Marble Console", "category": "Storage",
		"price": 720, "level": 14,
		"tint": Color(0.90, 0.90, 0.88),
		"parts": _table(1.50, 0.42, 0.82, 0.08) + [
			{"shape": "box", "size": Vector3(1.34, 0.03, 0.34), "pos": Vector3(0, 0.30, 0), "mat": "steel"},
		],
		"surface": 0.83,
	})
	_add({
		"id": "light_column", "shop": "lumen",
		"name": "Light Column", "category": "Decor",
		"price": 540, "level": 14,
		"tint": Color(0.90, 0.92, 0.94),
		"parts": [
			{"shape": "box", "size": Vector3(0.34, 0.06, 0.34), "pos": Vector3(0, 0.03, 0), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.22, 1.86, 0.22), "pos": Vector3(0, 0.99, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.16, 1.70, 0.02), "pos": Vector3(0, 0.99, 0.115), "mat": "white"},
			{"shape": "box", "size": Vector3(0.02, 1.70, 0.16), "pos": Vector3(0.115, 0.99, 0), "mat": "white"},
			{"shape": "box", "size": Vector3(0.28, 0.05, 0.28), "pos": Vector3(0, 1.94, 0), "mat": "steel"},
		],
	})


# --------------------------------------------------------------- Hanami Ward

## Tatami & Tokonoma, Washi & Lantern and Kiri Tansu. The ward furnishes a room
## from the floor up rather than from the walls in: everything here is low, and
## a good deal of it is meant to be moved out of the way at night.
func _build_hanami() -> void:
	_add({
		"id": "tatami_mat", "shop": "tatami",
		"name": "Tatami Mat", "category": "Living",
		"price": 240, "level": 19,
		# Fresh rush, which is green rather than straw — and it needs to be,
		# because a pale mat on a pale floor was all but invisible.
		"tint": Color(0.70, 0.73, 0.45),
		"parts": [
			{"shape": "box", "size": Vector3(1.90, 0.09, 0.95), "pos": Vector3(0, 0.045, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.96, 0.10, 0.09), "pos": Vector3(0, 0.05, -0.49), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.96, 0.10, 0.09), "pos": Vector3(0, 0.05, 0.49), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.06, 0.10, 1.00), "pos": Vector3(-0.95, 0.05, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.06, 0.10, 1.00), "pos": Vector3(0.95, 0.05, 0), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "zabuton", "shop": "tatami",
		"name": "Zabuton Cushion", "category": "Living",
		"price": 90, "level": 19,
		"tint": Color(0.62, 0.26, 0.30),
		"parts": [
			{"shape": "box", "size": Vector3(0.62, 0.10, 0.62), "pos": Vector3(0, 0.05, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.52, 0.05, 0.52), "pos": Vector3(0, 0.11, 0), "mat": "tint"},
		],
	})
	_add({
		"id": "chabudai", "surface": 0.32, "shop": "tatami",
		"name": "Chabudai Table", "category": "Living",
		"price": 320, "level": 19,
		"tint": Color(0.48, 0.30, 0.19),
		"parts": [
			{"shape": "box", "size": Vector3(1.10, 0.06, 0.72), "pos": Vector3(0, 0.29, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.035, 0.29, 0.035), "pos": Vector3(-0.46, 0.145, -0.28), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.035, 0.29, 0.035), "pos": Vector3(0.46, 0.145, -0.28), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.035, 0.29, 0.035), "pos": Vector3(-0.46, 0.145, 0.28), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.035, 0.29, 0.035), "pos": Vector3(0.46, 0.145, 0.28), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "kotatsu", "surface": 0.40, "shop": "tatami",
		"name": "Kotatsu", "category": "Living",
		"price": 520, "level": 19,
		"tint": Color(0.72, 0.60, 0.44),
		"parts": [
			{"shape": "box", "size": Vector3(1.24, 0.05, 0.86), "pos": Vector3(0, 0.375, 0), "mat": "wood_dark"},
			# The quilt hanging over the frame, which is the whole point of it.
			{"shape": "box", "size": Vector3(1.34, 0.30, 0.96), "pos": Vector3(0, 0.21, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.02, 0.06, 0.66), "pos": Vector3(0, 0.36, 0), "mat": "wood"},
			{"shape": "cyl", "size": Vector3(0.04, 0.34, 0.04), "pos": Vector3(-0.55, 0.17, -0.36), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.04, 0.34, 0.04), "pos": Vector3(0.55, 0.17, -0.36), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.04, 0.34, 0.04), "pos": Vector3(-0.55, 0.17, 0.36), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.04, 0.34, 0.04), "pos": Vector3(0.55, 0.17, 0.36), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "zaisu", "shop": "tatami",
		"name": "Zaisu Floor Chair", "category": "Living",
		"price": 210, "level": 19,
		"tint": Color(0.36, 0.42, 0.38),
		"parts": [
			{"shape": "box", "size": Vector3(0.50, 0.09, 0.48), "pos": Vector3(0, 0.05, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.50, 0.46, 0.09), "pos": Vector3(0, 0.30, -0.22), "mat": "tint", "rot": Vector3(-12, 0, 0)},
			{"shape": "box", "size": Vector3(0.54, 0.03, 0.52), "pos": Vector3(0, 0.005, 0), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "futon_roll", "shop": "tatami",
		"name": "Futon", "category": "Bedroom",
		"price": 380, "level": 19,
		"tint": Color(0.90, 0.88, 0.84),
		"parts": [
			{"shape": "box", "size": Vector3(1.02, 0.16, 2.02), "pos": Vector3(0, 0.08, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.98, 0.10, 1.30), "pos": Vector3(0, 0.20, 0.30), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.46, 0.13, 0.28), "pos": Vector3(0, 0.22, -0.78), "mat": "white"},
		],
	})
	_add({
		"id": "shoji_screen", "against_wall": true, "shop": "washi",
		"name": "Shoji Screen", "category": "Decor",
		"price": 460, "level": 19,
		"tint": Color(0.94, 0.92, 0.86),
		"parts": [
			{"shape": "box", "size": Vector3(1.80, 1.86, 0.05), "pos": Vector3(0, 0.95, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.86, 0.09, 0.09), "pos": Vector3(0, 0.04, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.86, 0.09, 0.09), "pos": Vector3(0, 1.88, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.07, 1.86, 0.08), "pos": Vector3(-0.89, 0.95, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.07, 1.86, 0.08), "pos": Vector3(0.89, 0.95, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.05, 1.86, 0.07), "pos": Vector3(0.0, 0.95, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.86, 0.05, 0.07), "pos": Vector3(0, 0.62, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.86, 0.05, 0.07), "pos": Vector3(0, 1.28, 0), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "byobu", "against_wall": true, "shop": "washi",
		"name": "Byōbu Folding Screen", "category": "Decor",
		"price": 640, "level": 19,
		"tint": Color(0.86, 0.74, 0.42),
		"parts": [
			{"shape": "box", "size": Vector3(0.62, 1.52, 0.05), "pos": Vector3(-0.52, 0.78, 0.16), "mat": "tint", "rot": Vector3(0, 26, 0)},
			{"shape": "box", "size": Vector3(0.62, 1.52, 0.05), "pos": Vector3(0.0, 0.78, -0.02), "mat": "tint", "rot": Vector3(0, -14, 0)},
			{"shape": "box", "size": Vector3(0.62, 1.52, 0.05), "pos": Vector3(0.54, 0.78, 0.14), "mat": "tint", "rot": Vector3(0, 24, 0)},
			{"shape": "box", "size": Vector3(0.64, 0.07, 0.07), "pos": Vector3(-0.52, 0.03, 0.16), "mat": "wood_dark", "rot": Vector3(0, 26, 0)},
			{"shape": "box", "size": Vector3(0.64, 0.07, 0.07), "pos": Vector3(0.0, 0.03, -0.02), "mat": "wood_dark", "rot": Vector3(0, -14, 0)},
			{"shape": "box", "size": Vector3(0.64, 0.07, 0.07), "pos": Vector3(0.54, 0.03, 0.14), "mat": "wood_dark", "rot": Vector3(0, 24, 0)},
		],
	})
	_add({
		"id": "andon_lamp", "shop": "washi",
		"name": "Andon Lantern", "category": "Decor",
		"price": 280, "level": 19,
		"tint": Color(0.97, 0.92, 0.74),
		"parts": [
			{"shape": "box", "size": Vector3(0.34, 0.03, 0.34), "pos": Vector3(0, 0.015, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.28, 0.82, 0.28), "pos": Vector3(0, 0.45, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.04, 0.82, 0.04), "pos": Vector3(-0.14, 0.45, -0.14), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.04, 0.82, 0.04), "pos": Vector3(0.14, 0.45, -0.14), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.04, 0.82, 0.04), "pos": Vector3(-0.14, 0.45, 0.14), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.04, 0.82, 0.04), "pos": Vector3(0.14, 0.45, 0.14), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.38, 0.04, 0.38), "pos": Vector3(0, 0.88, 0), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "bonsai", "stackable": true, "shop": "washi",
		"name": "Bonsai", "category": "Decor",
		"price": 190, "level": 19,
		"tint": Color(0.42, 0.30, 0.22),
		"parts": [
			{"shape": "box", "size": Vector3(0.30, 0.10, 0.22), "pos": Vector3(0, 0.05, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.26, 0.02, 0.18), "pos": Vector3(0, 0.11, 0), "mat": "soil"},
			{"shape": "cyl", "size": Vector3(0.022, 0.16, 0.03), "pos": Vector3(-0.02, 0.19, 0), "mat": "wood_dark", "rot": Vector3(0, 0, 14)},
			{"shape": "cyl", "size": Vector3(0.016, 0.13, 0.02), "pos": Vector3(0.06, 0.30, 0.01), "mat": "wood_dark", "rot": Vector3(0, 0, -52)},
			{"shape": "sphere", "size": Vector3(0.13, 0.10, 0.13), "pos": Vector3(0.11, 0.35, 0.01), "mat": "leaf"},
			{"shape": "sphere", "size": Vector3(0.09, 0.07, 0.09), "pos": Vector3(-0.08, 0.31, -0.02), "mat": "leaf"},
		],
	})
	_add({
		"id": "ikebana", "stackable": true, "shop": "washi",
		"name": "Ikebana Arrangement", "category": "Decor",
		"price": 150, "level": 19,
		"tint": Color(0.28, 0.32, 0.36),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.13, 0.07, 0.13), "pos": Vector3(0, 0.035, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.012, 0.34, 0.015), "pos": Vector3(0.01, 0.24, 0), "mat": "leaf", "rot": Vector3(0, 0, -16)},
			{"shape": "cyl", "size": Vector3(0.010, 0.24, 0.012), "pos": Vector3(-0.05, 0.18, 0.02), "mat": "leaf", "rot": Vector3(12, 0, 24)},
			{"shape": "sphere", "size": Vector3(0.05, 0.05, 0.05), "pos": Vector3(0.06, 0.41, 0), "mat": "white"},
		],
	})
	_add({
		"id": "tansu", "against_wall": true, "surface": 0.92, "shop": "kiri",
		"name": "Kiri Tansu Chest", "category": "Storage",
		"price": 720, "level": 19,
		"tint": Color(0.64, 0.47, 0.31),
		"parts": [
			{"shape": "box", "size": Vector3(1.10, 0.90, 0.48), "pos": Vector3(0, 0.45, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.04, 0.02, 0.02), "pos": Vector3(0, 0.28, 0.25), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.04, 0.02, 0.02), "pos": Vector3(0, 0.58, 0.25), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.10, 0.10, 0.03), "pos": Vector3(-0.30, 0.14, 0.25), "mat": "metal"},
			{"shape": "box", "size": Vector3(0.10, 0.10, 0.03), "pos": Vector3(0.30, 0.14, 0.25), "mat": "metal"},
			{"shape": "box", "size": Vector3(0.10, 0.10, 0.03), "pos": Vector3(-0.30, 0.44, 0.25), "mat": "metal"},
			{"shape": "box", "size": Vector3(0.10, 0.10, 0.03), "pos": Vector3(0.30, 0.44, 0.25), "mat": "metal"},
			{"shape": "box", "size": Vector3(0.10, 0.10, 0.03), "pos": Vector3(0.0, 0.74, 0.25), "mat": "metal"},
			{"shape": "box", "size": Vector3(1.14, 0.04, 0.52), "pos": Vector3(0, 0.92, 0), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "kaidan_dansu", "against_wall": true, "surface": 1.30, "shop": "kiri",
		"name": "Kaidan Step Chest", "category": "Storage",
		"price": 880, "level": 19,
		"tint": Color(0.58, 0.42, 0.28),
		"parts": [
			{"shape": "box", "size": Vector3(0.52, 0.44, 0.50), "pos": Vector3(-0.55, 0.22, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.52, 0.88, 0.50), "pos": Vector3(0.0, 0.44, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.52, 1.30, 0.50), "pos": Vector3(0.55, 0.65, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.56, 0.03, 0.54), "pos": Vector3(-0.55, 0.45, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.56, 0.03, 0.54), "pos": Vector3(0.0, 0.89, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.56, 0.03, 0.54), "pos": Vector3(0.55, 1.31, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.09, 0.09, 0.03), "pos": Vector3(-0.55, 0.16, 0.26), "mat": "metal"},
			{"shape": "box", "size": Vector3(0.09, 0.09, 0.03), "pos": Vector3(0.0, 0.60, 0.26), "mat": "metal"},
		],
	})
	_add({
		"id": "getabako", "against_wall": true, "surface": 0.62, "shop": "kiri",
		"name": "Getabako Shoe Chest", "category": "Storage",
		"price": 420, "level": 19,
		"tint": Color(0.70, 0.56, 0.38),
		"parts": [
			{"shape": "box", "size": Vector3(0.86, 0.60, 0.36), "pos": Vector3(0, 0.30, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.40, 0.26, 0.02), "pos": Vector3(-0.21, 0.17, 0.19), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.40, 0.26, 0.02), "pos": Vector3(0.21, 0.17, 0.19), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.40, 0.26, 0.02), "pos": Vector3(-0.21, 0.45, 0.19), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.40, 0.26, 0.02), "pos": Vector3(0.21, 0.45, 0.19), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.90, 0.04, 0.40), "pos": Vector3(0, 0.62, 0), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "tsukubai", "shop": "washi",
		"name": "Tsukubai Basin", "category": "Decor",
		"price": 340, "level": 19,
		"tint": Color(0.46, 0.48, 0.46),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.30, 0.34, 0.32), "pos": Vector3(0, 0.17, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.22, 0.05, 0.22), "pos": Vector3(0, 0.355, 0), "mat": "glass"},
			{"shape": "cyl", "size": Vector3(0.035, 0.52, 0.035), "pos": Vector3(-0.02, 0.26, -0.30), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.028, 0.24, 0.028), "pos": Vector3(-0.02, 0.50, -0.19), "mat": "wood_dark", "rot": Vector3(90, 0, 0)},
			{"shape": "box", "size": Vector3(0.44, 0.06, 0.30), "pos": Vector3(0, 0.03, 0.32), "mat": "tint"},
		],
	})


# ---------------------------------------------------------------- Hollow Row

## Crypt & Coffer, The Cauldron and Gargoyle & Gloom. The row's clients keep
## late hours and have firm views about drapery; the trade here is heavy, dark
## and lit by candles, and none of it is sold anywhere else in the city.
func _build_hollow() -> void:
	_add({
		"id": "coffin_bed", "against_wall": true, "shop": "crypt",
		"name": "Casket Bed", "category": "Bedroom",
		"price": 1450, "level": 24,
		"tint": Color(0.24, 0.16, 0.20),
		"parts": [
			{"shape": "box", "size": Vector3(1.05, 0.30, 2.10), "pos": Vector3(0, 0.30, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.86, 0.20, 1.94), "pos": Vector3(0, 0.52, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.78, 0.12, 1.86), "pos": Vector3(0, 0.60, 0), "mat": "towel"},
			{"shape": "box", "size": Vector3(0.44, 0.14, 0.28), "pos": Vector3(0, 0.70, -0.76), "mat": "white"},
			{"shape": "box", "size": Vector3(1.09, 0.16, 0.14), "pos": Vector3(0, 0.22, -1.02), "mat": "metal"},
			{"shape": "box", "size": Vector3(1.09, 0.16, 0.14), "pos": Vector3(0, 0.22, 1.02), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.05, 0.16, 0.05), "pos": Vector3(-0.46, 0.08, -0.86), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.05, 0.16, 0.05), "pos": Vector3(0.46, 0.08, -0.86), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.05, 0.16, 0.05), "pos": Vector3(-0.46, 0.08, 0.86), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.05, 0.16, 0.05), "pos": Vector3(0.46, 0.08, 0.86), "mat": "metal"},
		],
	})
	_add({
		"id": "four_poster", "against_wall": true, "shop": "crypt",
		"name": "Draped Four-Poster", "category": "Bedroom",
		"price": 1980, "level": 24,
		"tint": Color(0.36, 0.16, 0.24),
		"parts": [
			{"shape": "box", "size": Vector3(1.55, 0.34, 2.10), "pos": Vector3(0, 0.30, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.45, 0.20, 2.00), "pos": Vector3(0, 0.55, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.60, 0.14, 0.34), "pos": Vector3(-0.36, 0.70, -0.78), "mat": "white"},
			{"shape": "box", "size": Vector3(0.60, 0.14, 0.34), "pos": Vector3(0.36, 0.70, -0.78), "mat": "white"},
			{"shape": "cyl", "size": Vector3(0.06, 2.20, 0.06), "pos": Vector3(-0.74, 1.10, -1.00), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.06, 2.20, 0.06), "pos": Vector3(0.74, 1.10, -1.00), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.06, 2.20, 0.06), "pos": Vector3(-0.74, 1.10, 1.00), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.06, 2.20, 0.06), "pos": Vector3(0.74, 1.10, 1.00), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.60, 0.10, 2.10), "pos": Vector3(0, 2.18, 0), "mat": "wood_dark"},
			# The drapes, hung at the head and gathered at each post.
			{"shape": "box", "size": Vector3(1.50, 1.70, 0.06), "pos": Vector3(0, 1.30, -1.02), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.22, 1.90, 0.22), "pos": Vector3(-0.72, 1.18, 0.98), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.22, 1.90, 0.22), "pos": Vector3(0.72, 1.18, 0.98), "mat": "tint"},
		],
	})
	_add({
		"id": "casket_chest", "against_wall": true, "surface": 0.74, "shop": "crypt",
		"name": "Iron-Bound Chest", "category": "Storage",
		"price": 760, "level": 24,
		"tint": Color(0.30, 0.22, 0.18),
		"parts": [
			{"shape": "box", "size": Vector3(1.05, 0.62, 0.55), "pos": Vector3(0, 0.31, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.09, 0.10, 0.59), "pos": Vector3(0, 0.68, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.09, 0.74, 0.59), "pos": Vector3(-0.34, 0.36, 0), "mat": "metal"},
			{"shape": "box", "size": Vector3(0.09, 0.74, 0.59), "pos": Vector3(0.34, 0.36, 0), "mat": "metal"},
			{"shape": "box", "size": Vector3(0.16, 0.18, 0.06), "pos": Vector3(0, 0.52, 0.29), "mat": "metal"},
		],
	})
	_add({
		"id": "high_back_chair", "shop": "crypt",
		"name": "High-Backed Chair", "category": "Living",
		"price": 890, "level": 24,
		"tint": Color(0.42, 0.14, 0.20),
		"parts": [
			{"shape": "box", "size": Vector3(0.74, 0.16, 0.70), "pos": Vector3(0, 0.46, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.74, 1.36, 0.14), "pos": Vector3(0, 1.10, -0.34), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.13, 0.70, 0.60), "pos": Vector3(-0.34, 1.20, -0.02), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.13, 0.70, 0.60), "pos": Vector3(0.34, 1.20, -0.02), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.15, 0.22, 0.62), "pos": Vector3(-0.33, 0.63, 0.02), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.15, 0.22, 0.62), "pos": Vector3(0.33, 0.63, 0.02), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.05, 0.38, 0.05), "pos": Vector3(-0.30, 0.19, -0.28), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.05, 0.38, 0.05), "pos": Vector3(0.30, 0.19, -0.28), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.05, 0.38, 0.05), "pos": Vector3(-0.30, 0.19, 0.28), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.05, 0.38, 0.05), "pos": Vector3(0.30, 0.19, 0.28), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "cauldron_stove", "shop": "cauldron",
		"name": "Cauldron & Hearth", "category": "Kitchen",
		"price": 1120, "level": 24,
		"tint": Color(0.20, 0.21, 0.24),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.44, 0.20, 0.48), "pos": Vector3(0, 0.10, 0), "mat": "dark"},
			{"shape": "cyl", "size": Vector3(0.05, 0.62, 0.05), "pos": Vector3(-0.34, 0.31, -0.20), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.05, 0.62, 0.05), "pos": Vector3(0.34, 0.31, -0.20), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.05, 0.62, 0.05), "pos": Vector3(0, 0.31, 0.38), "mat": "metal"},
			{"shape": "sphere", "size": Vector3(0.42, 0.62, 0.42), "pos": Vector3(0, 0.72, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.40, 0.06, 0.40), "pos": Vector3(0, 0.94, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.34, 0.03, 0.34), "pos": Vector3(0, 0.95, 0), "mat": "leaf"},
		],
	})
	_add({
		"id": "apothecary_counter", "against_wall": true, "surface": 0.94, "shop": "cauldron",
		"name": "Apothecary Counter", "category": "Kitchen",
		"price": 1240, "level": 24,
		"tint": Color(0.28, 0.20, 0.16),
		"parts": [
			{"shape": "box", "size": Vector3(1.80, 0.88, 0.62), "pos": Vector3(0, 0.44, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.88, 0.06, 0.68), "pos": Vector3(0, 0.91, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.26, 0.24, 0.02), "pos": Vector3(-0.62, 0.66, 0.32), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.26, 0.24, 0.02), "pos": Vector3(-0.21, 0.66, 0.32), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.26, 0.24, 0.02), "pos": Vector3(0.21, 0.66, 0.32), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.26, 0.24, 0.02), "pos": Vector3(0.62, 0.66, 0.32), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.26, 0.24, 0.02), "pos": Vector3(-0.62, 0.30, 0.32), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.26, 0.24, 0.02), "pos": Vector3(-0.21, 0.30, 0.32), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.26, 0.24, 0.02), "pos": Vector3(0.21, 0.30, 0.32), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.26, 0.24, 0.02), "pos": Vector3(0.62, 0.30, 0.32), "mat": "wood_light"},
		],
	})
	_add({
		"id": "drying_rack", "against_wall": true, "shop": "cauldron",
		"name": "Drying Rack", "category": "Kitchen",
		"price": 480, "level": 24,
		"tint": Color(0.36, 0.26, 0.18),
		"parts": [
			{"shape": "box", "size": Vector3(0.08, 1.72, 0.08), "pos": Vector3(-0.52, 0.86, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.08, 1.72, 0.08), "pos": Vector3(0.52, 0.86, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.12, 0.07, 0.07), "pos": Vector3(0, 1.70, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.12, 0.06, 0.06), "pos": Vector3(0, 1.18, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.16, 0.44, 0.14), "pos": Vector3(-0.30, 1.46, 0), "mat": "leaf"},
			{"shape": "box", "size": Vector3(0.14, 0.36, 0.12), "pos": Vector3(0.06, 1.50, 0), "mat": "leaf"},
			{"shape": "box", "size": Vector3(0.15, 0.40, 0.13), "pos": Vector3(0.34, 1.48, 0), "mat": "leaf"},
			{"shape": "box", "size": Vector3(0.13, 0.30, 0.11), "pos": Vector3(-0.10, 1.01, 0), "mat": "leaf"},
			{"shape": "box", "size": Vector3(1.08, 0.05, 0.36), "pos": Vector3(0, 0.10, 0), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "candelabra", "shop": "gargoyle",
		"name": "Iron Candelabra", "category": "Decor",
		"price": 560, "level": 24,
		"tint": Color(0.18, 0.18, 0.21),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.30, 0.06, 0.34), "pos": Vector3(0, 0.03, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.05, 1.30, 0.05), "pos": Vector3(0, 0.68, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.86, 0.05, 0.05), "pos": Vector3(0, 1.24, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.05, 0.05, 0.60), "pos": Vector3(0, 1.10, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.05, 0.22, 0.05), "pos": Vector3(-0.42, 1.36, 0), "mat": "white"},
			{"shape": "cyl", "size": Vector3(0.05, 0.22, 0.05), "pos": Vector3(0.42, 1.36, 0), "mat": "white"},
			{"shape": "cyl", "size": Vector3(0.05, 0.22, 0.05), "pos": Vector3(0, 1.22, -0.29), "mat": "white"},
			{"shape": "cyl", "size": Vector3(0.05, 0.22, 0.05), "pos": Vector3(0, 1.22, 0.29), "mat": "white"},
			{"shape": "cyl", "size": Vector3(0.05, 0.26, 0.05), "pos": Vector3(0, 1.46, 0), "mat": "white"},
		],
	})
	_add({
		"id": "gargoyle_statue", "shop": "gargoyle",
		"name": "Gargoyle", "category": "Decor",
		"price": 820, "level": 24,
		"tint": Color(0.44, 0.44, 0.46),
		"parts": [
			{"shape": "box", "size": Vector3(0.46, 0.52, 0.46), "pos": Vector3(0, 0.26, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.38, 0.06, 0.38), "pos": Vector3(0, 0.55, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.34, 0.40, 0.32), "pos": Vector3(0, 0.78, 0), "mat": "tint"},
			{"shape": "sphere", "size": Vector3(0.15, 0.15, 0.15), "pos": Vector3(0, 1.04, 0.02), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.07, 0.11, 0.07), "pos": Vector3(-0.08, 1.14, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.07, 0.11, 0.07), "pos": Vector3(0.08, 1.14, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.34, 0.44, 0.06), "pos": Vector3(-0.24, 0.86, -0.12), "mat": "tint", "rot": Vector3(0, -34, 18)},
			{"shape": "box", "size": Vector3(0.34, 0.44, 0.06), "pos": Vector3(0.24, 0.86, -0.12), "mat": "tint", "rot": Vector3(0, 34, -18)},
		],
	})
	_add({
		"id": "raven_perch", "shop": "gargoyle",
		"name": "Raven on a Stand", "category": "Decor",
		"price": 390, "level": 24,
		"tint": Color(0.14, 0.14, 0.17),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.26, 0.05, 0.28), "pos": Vector3(0, 0.025, 0), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.035, 1.24, 0.035), "pos": Vector3(0, 0.64, 0), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.03, 0.34, 0.03), "pos": Vector3(0, 1.24, 0), "mat": "wood_dark", "rot": Vector3(90, 0, 0)},
			{"shape": "sphere", "size": Vector3(0.11, 0.16, 0.11), "pos": Vector3(0, 1.34, 0.06), "mat": "tint"},
			{"shape": "sphere", "size": Vector3(0.07, 0.07, 0.07), "pos": Vector3(0, 1.45, 0.02), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.03, 0.02, 0.09), "pos": Vector3(0, 1.45, -0.06), "mat": "wood_light"},
			{"shape": "box", "size": Vector3(0.05, 0.09, 0.20), "pos": Vector3(0, 1.30, 0.16), "mat": "tint", "rot": Vector3(24, 0, 0)},
		],
	})
	_add({
		"id": "crystal_ball", "stackable": true, "shop": "gargoyle",
		"name": "Scrying Globe", "category": "Decor",
		"price": 260, "level": 24,
		"tint": Color(0.56, 0.48, 0.72),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.11, 0.05, 0.13), "pos": Vector3(0, 0.025, 0), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.07, 0.04, 0.09), "pos": Vector3(0, 0.06, 0), "mat": "metal"},
			{"shape": "sphere", "size": Vector3(0.11, 0.22, 0.11), "pos": Vector3(0, 0.18, 0), "mat": "glass"},
			{"shape": "sphere", "size": Vector3(0.07, 0.14, 0.07), "pos": Vector3(0, 0.18, 0), "mat": "tint"},
		],
	})
	_add({
		"id": "skull_candle", "stackable": true, "shop": "gargoyle",
		"name": "Candle & Skull", "category": "Decor",
		"price": 130, "level": 24,
		"tint": Color(0.88, 0.86, 0.80),
		"parts": [
			{"shape": "box", "size": Vector3(0.22, 0.03, 0.20), "pos": Vector3(0, 0.015, 0), "mat": "wood_dark"},
			{"shape": "sphere", "size": Vector3(0.08, 0.09, 0.08), "pos": Vector3(-0.05, 0.07, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.07, 0.04, 0.06), "pos": Vector3(-0.05, 0.03, 0.05), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.035, 0.20, 0.035), "pos": Vector3(0.07, 0.13, 0), "mat": "white"},
			{"shape": "cyl", "size": Vector3(0.006, 0.03, 0.006), "pos": Vector3(0.07, 0.245, 0), "mat": "dark"},
		],
	})
	_add({
		"id": "black_mirror", "against_wall": true, "shop": "gargoyle",
		"name": "Tall Dark Mirror", "category": "Decor",
		"price": 940, "level": 24,
		"tint": Color(0.22, 0.18, 0.24),
		"parts": [
			{"shape": "box", "size": Vector3(0.86, 1.90, 0.10), "pos": Vector3(0, 0.98, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.68, 1.70, 0.04), "pos": Vector3(0, 0.98, 0.05), "mat": "mirror"},
			{"shape": "box", "size": Vector3(0.94, 0.12, 0.16), "pos": Vector3(0, 1.98, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.94, 0.10, 0.20), "pos": Vector3(0, 0.05, 0), "mat": "tint"},
			{"shape": "sphere", "size": Vector3(0.07, 0.07, 0.07), "pos": Vector3(-0.38, 2.06, 0), "mat": "metal"},
			{"shape": "sphere", "size": Vector3(0.07, 0.07, 0.07), "pos": Vector3(0.38, 2.06, 0), "mat": "metal"},
		],
	})
	_add({
		"id": "grimoire_case", "against_wall": true, "surface": 1.86, "shop": "gargoyle",
		"name": "Grimoire Case", "category": "Storage",
		"price": 1080, "level": 24,
		"tint": Color(0.26, 0.19, 0.17),
		"parts": [
			{"shape": "box", "size": Vector3(1.15, 1.84, 0.36), "pos": Vector3(0, 0.92, -0.02), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.06, 0.04, 0.32), "pos": Vector3(0, 0.50, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.06, 0.04, 0.32), "pos": Vector3(0, 0.96, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.06, 0.04, 0.32), "pos": Vector3(0, 1.42, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.30, 0.34, 0.22), "pos": Vector3(-0.32, 0.68, 0.02), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.24, 0.30, 0.20), "pos": Vector3(0.10, 0.66, 0.02), "mat": "leaf"},
			{"shape": "box", "size": Vector3(0.28, 0.36, 0.22), "pos": Vector3(-0.20, 1.15, 0.02), "mat": "wood"},
			{"shape": "box", "size": Vector3(0.22, 0.28, 0.20), "pos": Vector3(0.28, 1.11, 0.02), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(1.20, 0.08, 0.42), "pos": Vector3(0, 1.88, 0), "mat": "wood_dark"},
		],
	})
