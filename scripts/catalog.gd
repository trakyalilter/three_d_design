extends Node
## Furniture catalog: every model in the app is described here as a small list
## of primitive parts, so the project ships with no binary mesh assets.
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
	"Living", "Bedroom", "Dining", "Storage", "Kitchen", "Decor",
]

## Fixed material roles. "tint" is resolved per placed item.
const MATERIALS := {
	"wood": {"color": Color(0.56, 0.38, 0.24), "rough": 0.75, "metal": 0.0},
	"wood_dark": {"color": Color(0.33, 0.21, 0.13), "rough": 0.7, "metal": 0.0},
	"wood_light": {"color": Color(0.79, 0.64, 0.45), "rough": 0.8, "metal": 0.0},
	"metal": {"color": Color(0.73, 0.75, 0.78), "rough": 0.28, "metal": 0.9},
	"white": {"color": Color(0.93, 0.93, 0.9), "rough": 0.65, "metal": 0.0},
	"dark": {"color": Color(0.16, 0.17, 0.2), "rough": 0.6, "metal": 0.05},
	"screen": {"color": Color(0.05, 0.06, 0.09), "rough": 0.15, "metal": 0.0},
	"glass": {"color": Color(0.68, 0.82, 0.86, 0.35), "rough": 0.05, "metal": 0.0},
	"leaf": {"color": Color(0.28, 0.55, 0.26), "rough": 0.85, "metal": 0.0},
	"soil": {"color": Color(0.29, 0.22, 0.17), "rough": 1.0, "metal": 0.0},
	"steel": {"color": Color(0.85, 0.86, 0.88), "rough": 0.35, "metal": 0.75},
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


func _ready() -> void:
	_build()


func _build() -> void:
	# ---------------------------------------------------------------- Living
	_add({
		"id": "sofa",
		"name": "Sofa",
		"category": "Living",
		"tint": Color(0.35, 0.38, 0.44),
		"parts": _sofa(2.05, 0.9),
	})
	_add({
		"id": "loveseat",
		"name": "Loveseat",
		"category": "Living",
		"tint": Color(0.40, 0.62, 0.42),
		"parts": _sofa(1.45, 0.9),
	})
	_add({
		"id": "armchair",
		"name": "Armchair",
		"category": "Living",
		"tint": Color(0.78, 0.32, 0.29),
		"parts": _sofa(0.95, 0.88),
	})
	_add({
		"id": "coffee_table",
		"name": "Coffee Table",
		"category": "Living",
		"tint": Color(0.56, 0.38, 0.24),
		"parts": _table(1.10, 0.60, 0.42, 0.05),
	})
	_add({
		"id": "tv_stand",
		"name": "TV Stand",
		"category": "Living",
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
		"id": "television",
		"name": "Television",
		"category": "Living",
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
		"id": "bed_double",
		"name": "Double Bed",
		"category": "Bedroom",
		"tint": Color(0.30, 0.53, 0.72),
		"parts": _bed(1.62, 2.05),
	})
	_add({
		"id": "bed_single",
		"name": "Single Bed",
		"category": "Bedroom",
		"tint": Color(0.87, 0.60, 0.28),
		"parts": _bed(1.00, 1.95),
	})
	_add({
		"id": "nightstand",
		"name": "Nightstand",
		"category": "Bedroom",
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
		"id": "dresser",
		"name": "Dresser",
		"category": "Bedroom",
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
		"id": "dining_table",
		"name": "Dining Table",
		"category": "Dining",
		"tint": Color(0.56, 0.38, 0.24),
		"parts": _table(1.70, 0.95, 0.74, 0.06),
	})
	_add({
		"id": "round_table",
		"name": "Round Table",
		"category": "Dining",
		"tint": Color(0.79, 0.64, 0.45),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.60, 0.06, 0.60), "pos": Vector3(0, 0.75, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.07, 0.72, 0.07), "pos": Vector3(0, 0.36, 0), "mat": "wood_dark"},
			{"shape": "cyl", "size": Vector3(0.32, 0.05, 0.36), "pos": Vector3(0, 0.025, 0), "mat": "wood_dark"},
		],
	})
	_add({
		"id": "chair",
		"name": "Chair",
		"category": "Dining",
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
		"id": "bar_stool",
		"name": "Bar Stool",
		"category": "Dining",
		"tint": Color(0.16, 0.17, 0.2),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.19, 0.07, 0.19), "pos": Vector3(0, 0.72, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.04, 0.69, 0.04), "pos": Vector3(0, 0.35, 0), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.22, 0.03, 0.22), "pos": Vector3(0, 0.015, 0), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.15, 0.02, 0.15), "pos": Vector3(0, 0.24, 0), "mat": "metal"},
		],
	})

	# --------------------------------------------------------------- Storage
	_add({
		"id": "wardrobe",
		"name": "Wardrobe",
		"category": "Storage",
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
		"id": "bookshelf",
		"name": "Bookshelf",
		"category": "Storage",
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
		"id": "desk",
		"name": "Desk",
		"category": "Storage",
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
		"id": "cabinet",
		"name": "Low Cabinet",
		"category": "Storage",
		"tint": Color(0.45, 0.38, 0.66),
		"parts": [
			{"shape": "box", "size": Vector3(0.90, 0.80, 0.42), "pos": Vector3(0, 0.44, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.41, 0.72, 0.02), "pos": Vector3(-0.22, 0.44, 0.215), "mat": "white"},
			{"shape": "box", "size": Vector3(0.41, 0.72, 0.02), "pos": Vector3(0.22, 0.44, 0.215), "mat": "white"},
			{"shape": "box", "size": Vector3(0.90, 0.08, 0.42), "pos": Vector3(0, 0.04, 0), "mat": "dark"},
		],
	})

	# --------------------------------------------------------------- Kitchen
	_add({
		"id": "counter",
		"name": "Counter",
		"category": "Kitchen",
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
		"id": "fridge",
		"name": "Refrigerator",
		"category": "Kitchen",
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
		"id": "stove",
		"name": "Stove",
		"category": "Kitchen",
		"tint": Color(0.16, 0.17, 0.2),
		"parts": [
			{"shape": "box", "size": Vector3(0.60, 0.86, 0.62), "pos": Vector3(0, 0.47, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(0.62, 0.03, 0.64), "pos": Vector3(0, 0.905, 0), "mat": "dark"},
			{"shape": "cyl", "size": Vector3(0.09, 0.01, 0.09), "pos": Vector3(-0.14, 0.923, -0.14), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.09, 0.01, 0.09), "pos": Vector3(0.14, 0.923, -0.14), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.09, 0.01, 0.09), "pos": Vector3(-0.14, 0.923, 0.14), "mat": "steel"},
			{"shape": "cyl", "size": Vector3(0.09, 0.01, 0.09), "pos": Vector3(0.14, 0.923, 0.14), "mat": "steel"},
			{"shape": "box", "size": Vector3(0.48, 0.40, 0.02), "pos": Vector3(0, 0.42, 0.315), "mat": "glass"},
			{"shape": "box", "size": Vector3(0.04, 0.44, 0.05), "pos": Vector3(0, 0.68, 0.34), "mat": "metal"},
			{"shape": "box", "size": Vector3(0.04, 0.44, 0.05), "pos": Vector3(0, 0.68, 0.34), "mat": "metal", "rot": Vector3(0, 0, 90)},
			{"shape": "box", "size": Vector3(0.60, 0.08, 0.58), "pos": Vector3(0, 0.04, 0), "mat": "dark"},
		],
	})
	_add({
		"id": "sink_unit",
		"name": "Sink Unit",
		"category": "Kitchen",
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

	# ----------------------------------------------------------------- Decor
	_add({
		"id": "rug",
		"name": "Rug",
		"category": "Decor",
		"tint": Color(0.78, 0.32, 0.29),
		"parts": [
			{"shape": "box", "size": Vector3(2.20, 0.02, 1.55), "pos": Vector3(0, 0.01, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.90, 0.022, 1.25), "pos": Vector3(0, 0.012, 0), "mat": "white"},
			{"shape": "box", "size": Vector3(1.60, 0.024, 0.95), "pos": Vector3(0, 0.014, 0), "mat": "tint"},
		],
	})
	_add({
		"id": "floor_lamp",
		"name": "Floor Lamp",
		"category": "Decor",
		"tint": Color(0.90, 0.79, 0.44),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.20, 0.03, 0.22), "pos": Vector3(0, 0.015, 0), "mat": "dark"},
			{"shape": "cyl", "size": Vector3(0.02, 1.42, 0.02), "pos": Vector3(0, 0.72, 0), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.17, 0.30, 0.23), "pos": Vector3(0, 1.55, 0), "mat": "tint"},
		],
	})
	_add({
		"id": "plant",
		"name": "Potted Plant",
		"category": "Decor",
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
		"id": "side_table",
		"name": "Side Table",
		"category": "Decor",
		"tint": Color(0.16, 0.17, 0.2),
		"parts": [
			{"shape": "cyl", "size": Vector3(0.26, 0.04, 0.26), "pos": Vector3(0, 0.52, 0), "mat": "tint"},
			{"shape": "cyl", "size": Vector3(0.025, 0.50, 0.025), "pos": Vector3(0, 0.25, 0), "mat": "metal"},
			{"shape": "cyl", "size": Vector3(0.20, 0.02, 0.22), "pos": Vector3(0, 0.01, 0), "mat": "metal"},
		],
	})
	_add({
		"id": "partition",
		"name": "Partition",
		"category": "Decor",
		"tint": Color(0.62, 0.58, 0.50),
		"parts": [
			{"shape": "box", "size": Vector3(1.40, 1.75, 0.06), "pos": Vector3(0, 0.90, 0), "mat": "tint"},
			{"shape": "box", "size": Vector3(1.44, 0.06, 0.28), "pos": Vector3(0, 0.03, 0), "mat": "dark"},
			{"shape": "box", "size": Vector3(0.04, 1.75, 0.08), "pos": Vector3(-0.46, 0.90, 0), "mat": "wood_dark"},
			{"shape": "box", "size": Vector3(0.04, 1.75, 0.08), "pos": Vector3(0.46, 0.90, 0), "mat": "wood_dark"},
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
	def["extents"] = _measure(def["parts"])
	_items[def["id"]] = def
	_order.append(def["id"])


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


func default_tint(id: String) -> Color:
	return _items.get(id, {}).get("tint", Color.WHITE)


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
