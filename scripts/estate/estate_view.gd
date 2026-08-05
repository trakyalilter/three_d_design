class_name EstateView
extends Node3D
## The two maps behind the shops: the ground you work, and the works you run.
##
## They are the same thing built from different plot lists — a strip of land
## with holdings on it, a road down the middle, and one pick volume per plot.
## The fields grow trees, crops, spoil heaps and dunes; the works grow sheds
## with chimneys. Both are welded into a SceneryBatch like the city is.

signal plot_picked(kind: String, id: String)
signal nothing_picked()

enum Kind { FIELDS, WORKS }

const PICK_LAYER := 4
const HALF_W := 40.0
const HALF_D := 30.0
const ROAD_HALF := 3.4

const GRASS := Color(0.40, 0.54, 0.33)
const DIRT := Color(0.52, 0.44, 0.34)
const ROAD := Color(0.28, 0.27, 0.26)

var kind: int = Kind.FIELDS
var rig: CameraRig

var _batch: SceneryBatch
var _scenery: Node3D
var _pickables: Node3D
var _labels: Array[Label3D] = []
## The "come and get it" bubbles over the plots that have something waiting.
var _pips: Array[Label3D] = []
var _pip_tick := 0.0

var _touches: Dictionary = {}
var _touch_origins: Dictionary = {}
var _pinch_distance := 0.0
var _gesture_is_pinch := false
var _dragged := false
var ui_probe: Callable = Callable()

var staged_build := false


func setup(which: int) -> void:
	kind = which


func is_fields() -> bool:
	return kind == Kind.FIELDS


func title() -> String:
	return "The Estate" if is_fields() else "The Works"


func _ready() -> void:
	if staged_build:
		set_process_unhandled_input(false)
		return
	for stage: Array in build_stages():
		(stage[1] as Callable).call()


func build_stages() -> Array:
	return [
		["Walking the boundary", _build_shell],
		["Laying out the ground" if is_fields() else "Laying out the yard", _build_ground],
		["Counting what is standing" if is_fields() else "Firing the chimneys", _build_plots],
		["Opening the gate", _open_up],
	]


func _build_shell() -> void:
	_build_environment()

	_scenery = Node3D.new()
	_scenery.name = "Scenery"
	add_child(_scenery)

	_pickables = Node3D.new()
	_pickables.name = "Plots"
	add_child(_pickables)

	rig = CameraRig.new()
	rig.name = "CameraRig"
	rig.yaw = -18.0
	rig.pitch = -38.0
	rig.distance = 54.0
	rig.min_distance = 16.0
	rig.max_distance = 96.0
	rig.pan_limit = Vector2(HALF_W, HALF_D)
	add_child(rig)
	rig.camera.far = 320.0


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	if is_fields():
		sky_material.sky_top_color = Color(0.30, 0.50, 0.74)
		sky_material.sky_horizon_color = Color(0.80, 0.86, 0.88)
		sky_material.ground_bottom_color = Color(0.28, 0.34, 0.26)
		sky_material.ground_horizon_color = Color(0.58, 0.64, 0.54)
	else:
		# The works sit under a working sky: lower sun, more haze.
		sky_material.sky_top_color = Color(0.36, 0.42, 0.52)
		sky_material.sky_horizon_color = Color(0.78, 0.74, 0.68)
		sky_material.ground_bottom_color = Color(0.26, 0.26, 0.26)
		sky_material.ground_horizon_color = Color(0.52, 0.50, 0.47)
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.70, 0.74, 0.78) if is_fields() else Color(0.72, 0.70, 0.66)
	env.fog_density = 0.0006
	world.environment = env
	add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(-36.0), 0.0)
	key.light_energy = 0.92
	key.light_color = Color(1.0, 0.97, 0.90)
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 90.0
	key.shadow_bias = 0.04
	key.shadow_normal_bias = 1.4
	key.shadow_opacity = 0.6
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-26.0), deg_to_rad(142.0), 0.0)
	fill.light_energy = 0.22
	fill.light_color = Color(0.82, 0.88, 1.0)
	add_child(fill)


# --------------------------------------------------------------- the ground

func _build_ground() -> void:
	_batch = SceneryBatch.new()
	_batch.box(GRASS if is_fields() else Color(0.44, 0.44, 0.41),
		Vector3(HALF_W * 2.0, 1.0, HALF_D * 2.0), Vector3(0, -0.5, 0))
	_weather_the_ground()

	# A track down the middle, with the plots either side of it.
	_batch.box(DIRT, Vector3(HALF_W * 2.0, 0.10, (ROAD_HALF + 1.2) * 2.0), Vector3(0, 0.02, 0))
	_batch.box(ROAD, Vector3(HALF_W * 2.0, 0.12, ROAD_HALF * 2.0), Vector3(0, 0.04, 0))
	var x := -HALF_W + 3.0
	while x < HALF_W:
		_batch.box(Color(0.86, 0.84, 0.70), Vector3(1.8, 0.02, 0.24), Vector3(x, 0.11, 0))
		x += 5.0

	# A fence round the whole holding, so it reads as land somebody owns.
	var post := Color(0.42, 0.32, 0.22)
	for sx in [-1.0, 1.0]:
		var edge: float = sx * HALF_W
		var z := -HALF_D
		while z <= HALF_D:
			_batch.box(post, Vector3(0.18, 1.10, 0.18), Vector3(edge, 0.55, z))
			z += 4.0
		_batch.box(post, Vector3(0.10, 0.10, HALF_D * 2.0), Vector3(edge, 0.92, 0))
	for sz in [-1.0, 1.0]:
		var edge: float = sz * HALF_D
		var fx := -HALF_W
		while fx <= HALF_W:
			_batch.box(post, Vector3(0.18, 1.10, 0.18), Vector3(fx, 0.55, edge))
			fx += 4.0
		_batch.box(post, Vector3(HALF_W * 2.0, 0.10, 0.10), Vector3(0, 0.92, edge))


## One flat plane is the biggest thing on either map and the emptiest. The
## fields get mown in patches with hedgerows and bushes over them; the works
## yard gets worn concrete, weeds through the cracks and the odd oil stain.
## Both are seeded off the map so a map looks the same every time it is built,
## and both keep clear of the track and the plots.
func _weather_the_ground() -> void:
	var seeded := RandomNumberGenerator.new()
	seeded.seed = 90210 if is_fields() else 40404
	var base: Color = GRASS if is_fields() else Color(0.44, 0.44, 0.41)

	for _i in 46:
		var x: float = seeded.randf_range(-HALF_W + 3.0, HALF_W - 3.0)
		var z: float = seeded.randf_range(-HALF_D + 3.0, HALF_D - 3.0)
		if absf(z) < ROAD_HALF + 2.4 or _on_a_plot(x, z):
			continue
		var w: float = seeded.randf_range(4.0, 13.0)
		var d: float = seeded.randf_range(4.0, 11.0)
		var shade: Color
		if is_fields():
			shade = base.lerp(Color(0.52, 0.62, 0.36), seeded.randf_range(-0.25, 0.60))
		else:
			shade = base.lerp(Color(0.58, 0.57, 0.53), seeded.randf_range(-0.45, 0.75))
		_batch.box(shade, Vector3(w, 0.05, d), Vector3(x, 0.025, z))

	for _i in 30:
		var x: float = seeded.randf_range(-HALF_W + 2.0, HALF_W - 2.0)
		var z: float = seeded.randf_range(-HALF_D + 2.0, HALF_D - 2.0)
		if absf(z) < ROAD_HALF + 1.6 or _on_a_plot(x, z):
			continue
		if is_fields():
			var r: float = seeded.randf_range(0.5, 1.1)
			_batch.sphere(Color(0.25, 0.42, 0.24).lerp(GRASS, seeded.randf() * 0.6),
				r, Vector3(x, r * 0.55, z))
		elif seeded.randf() < 0.5:
			# Weeds through a crack, and a pallet or a drum left out.
			var r2: float = seeded.randf_range(0.25, 0.5)
			_batch.sphere(Color(0.34, 0.44, 0.26), r2, Vector3(x, r2 * 0.5, z))
		else:
			_batch.box(Color(0.30, 0.29, 0.28), Vector3(seeded.randf_range(1.4, 3.2), 0.03,
				seeded.randf_range(1.0, 2.6)), Vector3(x, 0.055, z))


## True where a plot's own pad already covers the ground, so the weathering does
## not print over the top of it.
func _on_a_plot(x: float, z: float) -> bool:
	var plots: Array = Industry.sites() if is_fields() else Industry.works()
	for plot: Dictionary in plots:
		var at: Vector2 = plot["at"]
		if absf(x - at.x) < 9.0 and absf(z - at.y) < 8.0:
			return true
	if not is_fields():
		var bench: Vector2 = Industry.BENCH["at"]
		if absf(x - bench.x) < 6.0 and absf(z - bench.y) < 5.0:
			return true
	return false


func _build_plots() -> void:
	if is_fields():
		for site: Dictionary in Industry.sites():
			_build_site(site)
	else:
		for works: Dictionary in Industry.works():
			_build_works(works)
		_build_bench()
	_batch.commit(_scenery)
	_batch = null


func _open_up() -> void:
	set_process_unhandled_input(true)
	rig.focus = Vector3(0, 0, 0)
	rig.snap_to_target()


# ---------------------------------------------------------------- the fields

## One holding: the ground it stands on, whatever grows there, and the camp on
## it once it has been bought. The camp grows with the tier.
func _build_site(site: Dictionary) -> void:
	var id := str(site["id"])
	var tier := Game.site_tier(id)
	var at: Vector2 = site["at"]
	var here := Vector3(at.x, 0, at.y)
	var terrain := str(site["terrain"])
	var owned := tier > 0

	var plot := _terrain_colour(terrain)
	if not owned:
		plot = plot.lerp(Color(0.52, 0.52, 0.50), 0.45)
	_batch.box(plot, Vector3(13.0, 0.14, 12.0), here + Vector3(0, 0.06, 0))
	_batch.box(plot.darkened(0.22), Vector3(13.4, 0.10, 12.4), here + Vector3(0, 0.03, 0))

	match terrain:
		"forest":
			_plant_trees(here, tier, owned)
		"field":
			_plant_rows(here, tier, owned)
		"hill":
			_raise_spoil(here, tier, owned)
		"dune":
			_heap_sand(here, tier, owned)

	if owned:
		_build_camp(here, terrain, tier)
	else:
		_build_forsale(here, site)

	_plot_body(here, "site", id, site, tier)


func _terrain_colour(terrain: String) -> Color:
	match terrain:
		"forest": return Color(0.30, 0.44, 0.28)
		"field": return Color(0.62, 0.66, 0.34)
		"hill": return Color(0.48, 0.44, 0.38)
		# Deep enough that the dunes standing on it still read as dunes.
		_: return Color(0.72, 0.61, 0.36)


func _plant_trees(here: Vector3, tier: int, owned: bool) -> void:
	var trunk := Color(0.34, 0.25, 0.18)
	var leaf := Color(0.22, 0.42, 0.24) if owned else Color(0.40, 0.44, 0.40)
	# A worked stand is thinner than an untouched one — that is the point of it.
	var rows := 4
	for i in rows:
		for j in 4:
			if (i * 4 + j) % 4 < tier:
				continue
			var spot := here + Vector3(-4.8 + float(j) * 3.2, 0, -4.2 + float(i) * 2.8)
			_batch.cylinder(trunk, 0.22, 2.0, spot + Vector3(0, 1.0, 0), SceneryBatch.Layer.OPAQUE, 6)
			_batch.cone(leaf, 1.15, 2.6, spot + Vector3(0, 3.3, 0), SceneryBatch.Layer.OPAQUE, 8)
	# Cut logs stacked by the track once somebody is working it.
	for i in tier:
		for j in 3:
			_batch.cylinder(Color(0.60, 0.44, 0.28), 0.24, 3.4,
				here + Vector3(4.6, 0.26 + float(j) * 0.5, 3.2 + float(i) * 0.7),
				SceneryBatch.Layer.OPAQUE, 8, Basis(Vector3.FORWARD, deg_to_rad(90)))


func _plant_rows(here: Vector3, tier: int, owned: bool) -> void:
	var crop := Color(0.72, 0.76, 0.42) if owned else Color(0.56, 0.58, 0.46)
	var soil := Color(0.42, 0.34, 0.26)
	for i in 9:
		var z := -4.6 + float(i) * 1.15
		_batch.box(soil, Vector3(10.4, 0.06, 0.5), here + Vector3(0, 0.14, z))
		if not owned:
			continue
		for j in 7:
			_batch.sphere(crop, 0.30,
				here + Vector3(-4.2 + float(j) * 1.4, 0.34, z))
	# Bales by the track, one row a tier.
	for i in tier:
		for j in 2:
			_batch.cylinder(Color(0.90, 0.88, 0.80), 0.55, 0.9,
				here + Vector3(4.4 + float(j) * 1.3, 0.55, 3.4 + float(i) * 1.3),
				SceneryBatch.Layer.OPAQUE, 10, Basis(Vector3.FORWARD, deg_to_rad(90)))


func _raise_spoil(here: Vector3, tier: int, owned: bool) -> void:
	var rock := Color(0.46, 0.43, 0.40) if owned else Color(0.52, 0.52, 0.50)
	# The hill itself, in steps.
	for i in 3:
		var size := 9.0 - float(i) * 2.4
		_batch.box(rock.darkened(float(i) * 0.06), Vector3(size, 1.1, size * 0.8),
			here + Vector3(-1.0, 0.6 + float(i) * 1.0, -1.0))
	if not owned:
		return
	# The adit mouth, and spoil tipped down the slope.
	_batch.box(Color(0.14, 0.13, 0.13), Vector3(2.0, 1.6, 0.4), here + Vector3(-1.0, 0.9, 1.9))
	for i in tier:
		_batch.cone(Color(0.40, 0.36, 0.32), 1.6 + float(i) * 0.3, 1.5,
			here + Vector3(3.0 + float(i) * 2.0, 0.75, 3.0), SceneryBatch.Layer.OPAQUE, 10)


func _heap_sand(here: Vector3, tier: int, owned: bool) -> void:
	var sand := Color(0.94, 0.86, 0.62) if owned else Color(0.84, 0.79, 0.64)
	for i in 4:
		_batch.cone(sand.darkened(float(i) * 0.07), 3.0 - float(i) * 0.5, 1.6 + float(i) * 0.3,
			here + Vector3(-3.4 + float(i) * 2.4, 0.8, -2.0 + float(i % 2) * 3.0),
			SceneryBatch.Layer.OPAQUE, 12)
	if not owned:
		return
	# A screening plant and a stack of graded sand.
	_batch.box(Color(0.56, 0.57, 0.60), Vector3(0.5, 3.0, 0.5), here + Vector3(3.6, 1.5, 2.6))
	_batch.box(Color(0.62, 0.63, 0.66), Vector3(3.4, 0.4, 0.9),
		here + Vector3(2.2, 2.6, 2.6), SceneryBatch.Layer.SHINY,
		Basis(Vector3.FORWARD, deg_to_rad(-16.0)))
	for i in tier:
		_batch.cone(sand.lightened(0.06), 1.3, 1.2, here + Vector3(1.0 - float(i) * 1.8, 0.6, 4.0),
			SceneryBatch.Layer.OPAQUE, 10)


## The hut, yard and gear that says somebody works here. Bigger every tier.
func _build_camp(here: Vector3, terrain: String, tier: int) -> void:
	var wall := Color(0.78, 0.74, 0.66)
	var roof := Color(0.44, 0.30, 0.24)
	var at := here + Vector3(-4.4, 0, 4.0)
	var width := 2.6 + float(tier) * 0.7

	_batch.box(Color(0.56, 0.52, 0.46), Vector3(width + 2.4, 0.08, 4.6), at + Vector3(0, 0.11, 0))
	_batch.box(wall, Vector3(width, 2.2, 3.0), at + Vector3(0, 1.1, 0))
	# A stone plinth, a boarded gable and a tiled roof rather than a bare wedge.
	_batch.box(Color(0.58, 0.55, 0.50), Vector3(width + 0.24, 0.34, 3.24), at + Vector3(0, 0.32, 0))
	_batch.roof(roof, Vector2(width + 0.5, 3.4), 2.2, 0.9, at, Basis.IDENTITY, 3)
	_batch.box(Color(0.34, 0.24, 0.18), Vector3(0.8, 1.5, 0.10), at + Vector3(0, 0.75, 1.55))
	# A window either side of the door, with a sill under it.
	for sx in [-1.0, 1.0]:
		var wx: float = sx * (width * 0.5 - 0.55)
		_batch.box(Color(0.62, 0.74, 0.80, 0.85), Vector3(0.62, 0.66, 0.08),
			at + Vector3(wx, 1.35, 1.52), SceneryBatch.Layer.GLASS)
		_batch.box(Color(0.92, 0.90, 0.86), Vector3(0.78, 0.09, 0.16),
			at + Vector3(wx, 0.98, 1.54))
	# A chimney once it is a going concern.
	if tier >= 2:
		_batch.box(Color(0.50, 0.44, 0.40), Vector3(0.5, 1.4, 0.5), at + Vector3(width * 0.3, 3.1, -0.6))
		_batch.box(Color(0.38, 0.33, 0.30), Vector3(0.62, 0.16, 0.62), at + Vector3(width * 0.3, 3.86, -0.6))
	# A woodpile against the gable, and a water butt on the corner.
	for i in mini(tier, 3):
		# Along the gable, not through it: turned about X the log runs on Z,
		# which is the short way past the hut rather than into it.
		_batch.cylinder(Color(0.62, 0.46, 0.30), 0.14, 2.4,
			at + Vector3(-width * 0.5 - 0.45, 0.30 + float(i) * 0.29, -0.2),
			SceneryBatch.Layer.OPAQUE, 8, Basis(Vector3.RIGHT, deg_to_rad(90)))
	_batch.cylinder(Color(0.36, 0.40, 0.36), 0.34, 1.0,
		at + Vector3(width * 0.5 + 0.5, 0.5, 1.2), SceneryBatch.Layer.OPAQUE, 10)
	# A cart at the gate, and a second one when the place is at full tilt.
	for i in mini(tier, 2):
		var cart := here + Vector3(2.0 + float(i) * 3.4, 0, 4.4)
		_batch.box(Color(0.46, 0.34, 0.24), Vector3(2.6, 0.5, 1.4), cart + Vector3(0, 0.75, 0))
		_batch.box(Color(0.38, 0.28, 0.20), Vector3(2.6, 0.5, 0.10), cart + Vector3(0, 1.15, 0.66))
		for sx in [-1.0, 1.0]:
			_batch.cylinder(Color(0.24, 0.20, 0.18), 0.45, 0.18,
				cart + Vector3(sx * 0.9, 0.45, 0.72), SceneryBatch.Layer.OPAQUE, 10,
				Basis(Vector3.FORWARD, deg_to_rad(90)))


## A board on a post, for ground nobody has bought yet.
func _build_forsale(here: Vector3, plot: Dictionary) -> void:
	var at := here + Vector3(0, 0, 5.4)
	_batch.box(Color(0.44, 0.34, 0.24), Vector3(0.18, 2.4, 0.18), at + Vector3(-1.3, 1.2, 0))
	_batch.box(Color(0.44, 0.34, 0.24), Vector3(0.18, 2.4, 0.18), at + Vector3(1.3, 1.2, 0))
	_batch.box(Color(0.96, 0.94, 0.88), Vector3(3.2, 1.5, 0.12), at + Vector3(0, 2.0, 0))
	_batch.box(Color(0.90, 0.66, 0.24), Vector3(3.3, 0.20, 0.16), at + Vector3(0, 1.32, 0))

	var plate := Label3D.new()
	plate.text = "%s\n%s" % [plot["name"], UIKit.money(int(plot["cost"]))]
	plate.font_size = 40
	plate.pixel_size = 0.0052
	plate.position = at + Vector3(0, 2.05, 0.10)
	plate.modulate = Color(0.12, 0.13, 0.16)
	plate.outline_size = 0
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scenery.add_child(plate)


# ----------------------------------------------------------------- the works

## A plant: a shed with a roof lantern, a chimney and a yard. The chimney gets
## taller and the yard fuller as it is built up.
func _build_works(works: Dictionary) -> void:
	var id := str(works["id"])
	var tier := Game.works_tier(id)
	var at: Vector2 = works["at"]
	var here := Vector3(at.x, 0, at.y)
	var owned := tier > 0
	var good: Dictionary = Industry.get_good(str(works["makes"]))
	var accent: Color = good.get("color", Color(0.6, 0.6, 0.6))
	if not owned:
		accent = accent.lerp(Color(0.55, 0.55, 0.54), 0.55)

	var yard := Color(0.50, 0.49, 0.47) if owned else Color(0.56, 0.56, 0.55)
	_batch.box(yard, Vector3(15.0, 0.14, 12.0), here + Vector3(0, 0.06, 0))

	var wall := Color(0.72, 0.70, 0.66) if owned else Color(0.66, 0.66, 0.65)
	var roof := Color(0.34, 0.35, 0.38)
	var width := 8.0
	var depth := 6.0
	var height := 3.6 + float(tier) * 0.5

	var shed := here + Vector3(-1.6, 0, -1.0)
	var front: float = depth * 0.5 + 0.08
	_batch.box(wall, Vector3(width, height, depth), shed + Vector3(0, height * 0.5, 0))
	# A brick plinth the shed stands on, and a sheeted roof over it.
	_batch.box(Color(0.46, 0.36, 0.32) if owned else Color(0.52, 0.50, 0.48),
		Vector3(width + 0.3, 0.6, depth + 0.3), shed + Vector3(0, 0.30, 0))
	_batch.roof(roof, Vector2(width + 0.6, depth + 0.6), height, 1.5, shed, Basis.IDENTITY, 5)
	# A lantern along the ridge, which is what a works has instead of windows.
	_batch.box(Color(0.86, 0.90, 0.92), Vector3(width * 0.5, 0.5, 1.2),
		shed + Vector3(0, height + 1.55, 0), SceneryBatch.Layer.GLASS)
	# The loading door, its lintel, and a colour band in whatever it makes.
	_batch.box(Color(0.28, 0.26, 0.24), Vector3(2.6, 2.6, 0.16), shed + Vector3(0, 1.3, front))
	_batch.box(Color(0.40, 0.38, 0.36), Vector3(3.0, 0.22, 0.24), shed + Vector3(0, 2.72, front))
	for i in 5:
		_batch.box(Color(0.42, 0.40, 0.38), Vector3(2.4, 0.06, 0.20),
			shed + Vector3(0, 0.35 + float(i) * 0.48, front + 0.05))
	_batch.box(accent, Vector3(width, 0.5, 0.10), shed + Vector3(0, height - 0.45, front - 0.02))
	# Steel-framed windows down the long side, and a gutter over them.
	for i in 4:
		_batch.box(Color(0.66, 0.76, 0.82, 0.8), Vector3(0.10, 1.0, 1.1),
			shed + Vector3(-width * 0.5 - 0.02, height - 1.3, -depth * 0.5 + 1.2 + float(i) * 1.2),
			SceneryBatch.Layer.GLASS)
	_batch.box(Color(0.52, 0.51, 0.49), Vector3(0.18, 0.16, depth + 0.4),
		shed + Vector3(-width * 0.5 - 0.12, height + 0.02, 0))
	_batch.cylinder(Color(0.52, 0.51, 0.49), 0.09, height,
		shed + Vector3(-width * 0.5 - 0.12, height * 0.5, depth * 0.5 - 0.3),
		SceneryBatch.Layer.OPAQUE, 8)

	if owned:
		# The stack stands on the shed, at the back corner of it, rather than
		# out in the yard on its own.
		var stack := 2.0 + float(tier) * 1.1
		var foot := shed + Vector3(width * 0.5 - 1.0, 0, -depth * 0.5 + 1.0)
		_batch.box(Color(0.46, 0.38, 0.35), Vector3(1.5, height + 0.6, 1.5),
			foot + Vector3(0, (height + 0.6) * 0.5, 0))
		_batch.cylinder(Color(0.50, 0.42, 0.38), 0.62, stack,
			foot + Vector3(0, height + 0.6 + stack * 0.5, 0), SceneryBatch.Layer.OPAQUE, 10)
		_batch.cylinder(Color(0.38, 0.32, 0.30), 0.72, 0.4,
			foot + Vector3(0, height + 0.4 + stack, 0), SceneryBatch.Layer.OPAQUE, 10)
		# Finished goods stacked in the yard, one pallet a tier, on a pallet.
		for i in tier:
			_batch.box(Color(0.56, 0.44, 0.30), Vector3(1.7, 0.12, 1.3),
				here + Vector3(4.4, 0.19, 2.4 + float(i) * 1.5))
			for j in 3:
				_batch.box(accent.darkened(0.05 * float(j)), Vector3(1.5, 0.34, 1.1),
					here + Vector3(4.4, 0.42 + float(j) * 0.36, 2.4 + float(i) * 1.5))
		# A hopper on legs, and a skip by the gate — a yard that works has
		# something standing about in it.
		_batch.box(Color(0.46, 0.45, 0.42), Vector3(2.0, 1.5, 2.0),
			here + Vector3(-6.0, 2.4, 2.6))
		_batch.prism(Color(0.46, 0.45, 0.42), Vector3(2.0, 1.1, 2.0),
			here + Vector3(-6.0, 1.10, 2.6), SceneryBatch.Layer.OPAQUE,
			Basis(Vector3.FORWARD, deg_to_rad(180)))
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_batch.box(Color(0.40, 0.39, 0.37), Vector3(0.14, 1.6, 0.14),
					here + Vector3(-6.0 + sx * 0.85, 0.8, 2.6 + sz * 0.85))
		_batch.box(accent.darkened(0.4), Vector3(2.8, 1.0, 1.6),
			here + Vector3(5.6, 0.55, -3.2))
		_batch.box(accent.darkened(0.28), Vector3(2.9, 0.14, 1.7),
			here + Vector3(5.6, 1.08, -3.2))
	else:
		_build_forsale(here, works)

	_plot_body(here, "works", id, works, tier)


## The bench: a small open workshop that costs nothing and is always there.
func _build_bench() -> void:
	var at: Vector2 = Industry.BENCH["at"]
	var here := Vector3(at.x, 0, at.y)
	_batch.box(Color(0.58, 0.54, 0.48), Vector3(9.0, 0.14, 7.0), here + Vector3(0, 0.06, 0))

	var post := Color(0.44, 0.32, 0.22)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_batch.box(post, Vector3(0.26, 3.0, 0.26), here + Vector3(sx * 3.4, 1.5, sz * 2.6))
	_batch.prism(Color(0.40, 0.30, 0.26), Vector3(7.8, 1.1, 6.0), here + Vector3(0, 3.5, 0))

	# The bench itself, with a vice and a rack of tools behind it.
	_batch.box(Color(0.60, 0.44, 0.28), Vector3(4.6, 0.22, 1.4), here + Vector3(0, 1.0, -0.6))
	for sx in [-1.0, 1.0]:
		_batch.box(Color(0.48, 0.34, 0.22), Vector3(0.24, 1.0, 1.2), here + Vector3(sx * 2.0, 0.5, -0.6))
	_batch.box(Color(0.54, 0.56, 0.60), Vector3(0.5, 0.4, 0.5),
		here + Vector3(1.9, 1.28, -0.6), SceneryBatch.Layer.SHINY)
	_batch.box(Color(0.46, 0.34, 0.24), Vector3(4.4, 1.3, 0.14), here + Vector3(0, 2.0, -1.5))
	for i in 6:
		_batch.box(Color(0.62, 0.64, 0.68), Vector3(0.10, 0.7, 0.10),
			here + Vector3(-1.8 + float(i) * 0.72, 2.0, -1.4), SceneryBatch.Layer.SHINY)

	_plot_body(here, "bench", str(Industry.BENCH["id"]), Industry.BENCH, 1)


# -------------------------------------------------------------- plot volumes

## One pick volume and one name plate per plot, so it can be tapped and read.
func _plot_body(here: Vector3, plot_kind: String, id: String,
		plot: Dictionary, tier: int) -> void:
	var holder := Node3D.new()
	holder.name = "Plot_%s" % id
	holder.position = here
	_pickables.add_child(holder)

	var plate := Label3D.new()
	plate.text = str(plot["name"])
	if tier > 0 and plot_kind != "bench":
		plate.text += "  ·  %s" % ["", "worked", "well worked", "at full tilt"][mini(tier, 3)]
	plate.font_size = 60
	plate.pixel_size = 0.00060
	plate.fixed_size = true
	plate.position = Vector3(0, 6.4, 0)
	plate.modulate = Color(0.97, 0.98, 1.0)
	plate.outline_size = 22
	plate.outline_modulate = Color(0.05, 0.06, 0.09, 0.95)
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.no_depth_test = true
	plate.render_priority = 2
	holder.add_child(plate)
	_labels.append(plate)

	# The bubble that says there is something here to come and get. Hidden
	# until there is, and checked once a second rather than every frame.
	if plot_kind != "bench":
		var pip := Label3D.new()
		pip.name = "Ready"
		pip.font_size = 72
		pip.pixel_size = 0.00060
		pip.fixed_size = true
		# Over the name plate, not under it, and carrying the number so the map
		# says how much is waiting without anything being tapped.
		pip.position = Vector3(0, 7.9, 0)
		pip.modulate = Color(0.99, 0.83, 0.35)
		pip.outline_size = 26
		pip.outline_modulate = Color(0.05, 0.06, 0.09, 0.95)
		pip.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pip.no_depth_test = true
		pip.render_priority = 3
		pip.visible = false
		pip.set_meta("plot_kind", plot_kind)
		pip.set_meta("plot_id", id)
		holder.add_child(pip)
		_pips.append(pip)

	var body := StaticBody3D.new()
	body.collision_layer = PICK_LAYER
	body.collision_mask = 0
	body.set_meta("plot_kind", plot_kind)
	body.set_meta("plot_id", id)
	var shape := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = Vector3(13.0, 8.0, 12.0)
	shape.shape = volume
	shape.position = Vector3(0, 4.0, 0)
	body.add_child(shape)
	holder.add_child(body)


## Whether each plot has something standing on it worth coming for. Once a
## second is plenty: nothing here changes faster than that.
func _process(delta: float) -> void:
	_pip_tick -= delta
	if _pip_tick > 0.0:
		return
	_pip_tick = 1.0
	for pip in _pips:
		if not is_instance_valid(pip):
			continue
		var id := str(pip.get_meta("plot_id"))
		var waiting := 0
		if str(pip.get_meta("plot_kind")) == "site":
			waiting = Game.waiting_at(id)
		elif Game.batch_ready(id):
			waiting = Game.batch_size(id)
		pip.visible = waiting > 0
		if waiting > 0:
			pip.text = "▼ %d" % waiting


## Rebuilds everything after a purchase, since the camps and chimneys grow.
func rebuild() -> void:
	_labels.clear()
	_pips.clear()
	for holder in [_scenery, _pickables]:
		for child in holder.get_children():
			holder.remove_child(child)
			child.queue_free()
	_batch = SceneryBatch.new()
	_build_ground()
	_build_plots()


# --------------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			rig.zoom(0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rig.zoom(1.1)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if ui_probe.is_valid() and ui_probe.call(event.position):
			return
		_touches[event.index] = event.position
		_touch_origins[event.index] = event.position
		if _touches.size() == 2:
			_gesture_is_pinch = true
			_pinch_distance = _pinch_span()
		elif _touches.size() == 1:
			_dragged = false
		return

	var was: Vector2 = _touches.get(event.index, event.position)
	_touches.erase(event.index)
	_touch_origins.erase(event.index)
	if _touches.is_empty():
		if not _dragged and not _gesture_is_pinch:
			_pick(was)
		_gesture_is_pinch = false


func _handle_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	_touches[event.index] = event.position
	if (event.position - Vector2(_touch_origins.get(event.index, event.position))).length() > 12.0:
		_dragged = true

	if _touches.size() >= 2:
		var span := _pinch_span()
		if _pinch_distance > 0.0:
			rig.zoom(_pinch_distance / maxf(span, 1.0))
		_pinch_distance = span
		return
	rig.pan(event.relative)


func _pinch_span() -> float:
	var points := _touches.values()
	if points.size() < 2:
		return 0.0
	return (Vector2(points[0]) - Vector2(points[1])).length()


func _pick(at: Vector2) -> void:
	var camera := rig.camera
	var query := PhysicsRayQueryParameters3D.create(
		camera.project_ray_origin(at),
		camera.project_ray_origin(at) + camera.project_ray_normal(at) * 600.0)
	query.collide_with_areas = false
	query.collision_mask = PICK_LAYER
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		nothing_picked.emit()
		return
	var collider: Object = hit["collider"]
	if collider.has_meta("plot_id"):
		Audio.play("open")
		plot_picked.emit(str(collider.get_meta("plot_kind")), str(collider.get_meta("plot_id")))
	else:
		nothing_picked.emit()


## Puts the camera over a plot, so buying one shows what it changed.
func focus_on(id: String) -> void:
	var holder := _pickables.get_node_or_null("Plot_%s" % id)
	if holder == null:
		return
	rig.focus = (holder as Node3D).position
	rig.distance = minf(rig.distance, 34.0)
