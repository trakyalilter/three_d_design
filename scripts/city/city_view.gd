class_name CityView
extends Node3D
## The city map: a grid of quarters, each a procedurally built neighbourhood of
## client houses, with the shops that supply them on the first quarter's avenue.
##
## Everything is boxes, cylinders and prisms, matching the way furniture is
## built in the designer — but here the geometry is welded into a SceneryBatch
## and drawn in a handful of calls. Only the things that move or respond stay
## as nodes: the job pins, the name plates and one pick volume per building.
##
## Quarters the player has not bought yet are still drawn, in a washed-out
## palette behind a hoarding, so the rest of the city is something you can see
## before you can afford it. Buying one calls rebuild().

signal house_picked(house_id: String)
signal shop_picked(shop_id: String)
signal district_picked(district_id: String)
signal nothing_picked()

const PICK_LAYER := 4
const GROUND := Color(0.33, 0.47, 0.27)
const LAWN := Color(0.40, 0.55, 0.32)
const ROAD := Color(0.19, 0.20, 0.23)
const PAVEMENT := Color(0.55, 0.55, 0.53)
const LINE := Color(0.92, 0.90, 0.72)

## Roads. The avenue runs north to south, two cross streets east to west.
const AVENUE_HALF := 5.0
const CROSS_HALF := 4.5
const CROSS_Z := 18.0
## Half the width of one quarter. Jobs.SPACING is the gap between their centres,
## so the strip between two quarters is what the link roads cross.
const QUARTER_HALF := 48.0

const MARKER_AVAILABLE := Color(0.35, 0.80, 1.00)
const MARKER_DONE := Color(0.42, 0.83, 0.52)
const MARKER_LOCKED := Color(0.55, 0.57, 0.62)
const MARKER_RESUME := Color(0.98, 0.78, 0.32)

## Labels are drawn at a fixed size on screen, so they pile up on each other
## once the camera pulls back far enough to take in more than one quarter. Both
## kinds fade out at the range where they stop being readable.
const SHOP_LABEL_DISTANCE := 48.0
const HOUSE_LABEL_DISTANCE := 130.0
## Labels also switch off once they belong to a quarter the camera is not
## looking at. Quarters are Jobs.SPACING apart, so this reaches across the one
## in view without picking up its neighbours.
const LABEL_RANGE := 62.0

## How far a quarter behind its hoarding is drained towards grey.
const LOCKED_TONE := Color(0.48, 0.49, 0.50)
const LOCKED_MIX := 0.62

var rig: CameraRig

var _markers: Dictionary = {}
var _shop_labels: Array[Label3D] = []
var _house_labels: Array[Label3D] = []
var _pickables: Node3D
var _scenery: Node3D
var _life: CityLife
var _batch: SceneryBatch
var _touches: Dictionary = {}
var _touch_origins: Dictionary = {}
var _pinch_distance := 0.0
var _pinch_midpoint := Vector2.ZERO
var _gesture_is_pinch := false
## Set by the owner so gestures that start on a panel are ignored.
var ui_probe: Callable = Callable()

## The quarter currently being built: where it sits, and whether the player
## owns it. _at() and _tone() read these, so the builders below can be written
## as if every quarter were at the origin.
var _origin := Vector2.ZERO
var _locked := false

## Set before the node enters the tree when the caller wants to drive the build
## itself, a stage at a time, behind a loading screen. See build_stages().
var staged_build := false


func _ready() -> void:
	_build_environment()

	_scenery = Node3D.new()
	_scenery.name = "Scenery"
	add_child(_scenery)

	_pickables = Node3D.new()
	_pickables.name = "Buildings"
	add_child(_pickables)

	_life = CityLife.new()
	_life.name = "Life"
	add_child(_life)

	rig = CameraRig.new()
	rig.name = "CameraRig"
	rig.yaw = -28.0
	rig.pitch = -42.0
	rig.distance = 58.0
	rig.min_distance = 18.0
	add_child(rig)
	# The map runs to a few hundred metres once the far quarters are in view.
	rig.camera.far = 520.0

	if staged_build:
		return
	_build_city()
	rig.snap_to_target()


## Redraws the whole map. Cheap enough to do outright, and the only sane way to
## repaint a quarter once it has been bought: the scenery is welded into shared
## meshes, so there is nothing to recolour in place.
func rebuild() -> void:
	_markers.clear()
	_shop_labels.clear()
	_house_labels.clear()
	for holder in [_scenery, _pickables]:
		for child in holder.get_children():
			holder.remove_child(child)
			child.queue_free()
	_build_city()


## The map build broken into pieces a loading screen can step through, each one
## a label and the work it names. Welding a quarter is the expensive part, so
## every quarter is its own stage.
func build_stages() -> Array:
	var stages: Array = []
	stages.append(["Levelling the ground", func() -> void:
		_batch = SceneryBatch.new()
		_build_base_ground()
		_build_links()])

	for district: Dictionary in Jobs.districts():
		var quarter: Dictionary = district
		stages.append(["Laying out %s" % quarter["name"], func() -> void:
			_build_district(quarter)])

	stages.append(["Letting the traffic out", func() -> void:
		_batch.commit(_scenery)
		_batch = null
		_life.populate()
		_apply_camera_limits()
		refresh_markers()])
	return stages


func _build_city() -> void:
	for stage: Array in build_stages():
		(stage[1] as Callable).call()


func _build_district(district: Dictionary) -> void:
	_origin = district["origin"]
	_locked = not Game.is_district_unlocked(str(district["id"]))

	_build_ground(district.get("ground", GROUND))
	_build_roads()
	_build_shops(district)
	_build_houses(district)
	_build_greenery(str(district.get("planting", "street")))
	if _locked:
		_build_hoarding(district)

	_origin = Vector2.ZERO
	_locked = false


func _process(delta: float) -> void:
	# Job markers bob gently so they read as interactive.
	var t := Time.get_ticks_msec() / 1000.0
	for house_id: String in _markers:
		var marker: Node3D = _markers[house_id]
		marker.position.y = marker.get_meta("base_y") + sin(t * 2.0 + marker.get_meta("phase")) * 0.28
		marker.rotate_y(delta * 0.9)

	if rig == null:
		return
	var focus := rig.focus
	for label in _shop_labels:
		label.visible = rig.distance < SHOP_LABEL_DISTANCE \
			and label.global_position.distance_to(focus) < LABEL_RANGE
	for label in _house_labels:
		label.visible = rig.distance < HOUSE_LABEL_DISTANCE \
			and label.global_position.distance_to(focus) < LABEL_RANGE


# ------------------------------------------------------- quarter-local helpers

## A point in the quarter being built, in world space.
func _at(local: Vector3) -> Vector3:
	return local + Vector3(_origin.x, 0, _origin.y)


## A transform in the quarter being built, in world space.
func _frame(local: Transform3D) -> Transform3D:
	return local.translated(Vector3(_origin.x, 0, _origin.y))


## Colour drained towards grey while the quarter is still behind its hoarding.
func _tone(color: Color) -> Color:
	if not _locked:
		return color
	var muted := color.lerp(LOCKED_TONE, LOCKED_MIX)
	muted.a = color.a
	return muted


# --------------------------------------------------------------- appearance

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.24, 0.42, 0.70)
	sky_material.sky_horizon_color = Color(0.72, 0.80, 0.86)
	sky_material.ground_bottom_color = Color(0.26, 0.30, 0.26)
	sky_material.ground_horizon_color = Color(0.55, 0.60, 0.55)
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.30
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.66, 0.74, 0.84)
	env.fog_density = 0.00035
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(-42.0), 0.0)
	sun.light_energy = 0.90
	sun.light_color = Color(1.0, 0.96, 0.90)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 130.0
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.4
	sun.shadow_opacity = 0.7
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation = Vector3(deg_to_rad(-24.0), deg_to_rad(135.0), 0.0)
	fill.light_energy = 0.24
	fill.light_color = Color(0.80, 0.88, 1.0)
	add_child(fill)


# ------------------------------------------------------------------- ground

## One slab under the whole grid, so the strips between quarters are not sky.
func _build_base_ground() -> void:
	var bounds := _city_bounds()
	var span: Vector2 = bounds[1] - bounds[0] + Vector2(QUARTER_HALF, QUARTER_HALF) * 2.0
	var centre: Vector2 = (bounds[0] + bounds[1]) * 0.5
	_batch.box(GROUND.darkened(0.18), Vector3(span.x, 1.0, span.y), Vector3(centre.x, -0.5, centre.y))


func _build_ground(tint: Color = GROUND) -> void:
	_batch.box(_tone(tint), Vector3(QUARTER_HALF * 2.0, 1.0, QUARTER_HALF * 2.0), _at(Vector3(0, -0.48, 0)))
	_patch_the_ground(tint)


## One flat green field is the largest thing on the map and the emptiest. This
## lays mown patches over it — a spread of low quads in neighbouring greens,
## seeded off the quarter's own position so a quarter looks the same every time
## it is built. They are kept clear of the avenue, where the paving goes.
func _patch_the_ground(tint: Color) -> void:
	var seeded := RandomNumberGenerator.new()
	seeded.seed = hash(Vector2i(int(_origin.x), int(_origin.y)))
	for _i in 34:
		var x: float = seeded.randf_range(-QUARTER_HALF + 4.0, QUARTER_HALF - 4.0)
		var z: float = seeded.randf_range(-QUARTER_HALF + 4.0, QUARTER_HALF - 4.0)
		if absf(x) < AVENUE_HALF + 12.0 and absf(z) < CROSS_Z + 6.0:
			continue
		var w: float = seeded.randf_range(7.0, 19.0)
		var d: float = seeded.randf_range(7.0, 19.0)
		var shade: Color = tint.lerp(LAWN, seeded.randf_range(-0.20, 0.50))
		_batch.box(_tone(shade), Vector3(w, 0.06, d), _at(Vector3(x, 0.03, z)))
	# And a scattering of bushes and stones, so the field has something on it.
	for _i in 22:
		var x: float = seeded.randf_range(-QUARTER_HALF + 3.0, QUARTER_HALF - 3.0)
		var z: float = seeded.randf_range(-QUARTER_HALF + 3.0, QUARTER_HALF - 3.0)
		if absf(x) < AVENUE_HALF + 14.0 and absf(z) < CROSS_Z + 8.0:
			continue
		if seeded.randf() < 0.65:
			var r: float = seeded.randf_range(0.5, 1.0)
			_batch.sphere(_tone(Color(0.26, 0.44, 0.25).lerp(LAWN, seeded.randf() * 0.5)),
				r, _at(Vector3(x, r * 0.55, z)))
		else:
			var r2: float = seeded.randf_range(0.35, 0.7)
			_batch.sphere(_tone(Color(0.58, 0.58, 0.55)), r2, _at(Vector3(x, r2 * 0.4, z)))


## The roads that run between quarters, so the grid reads as one city. Drawn
## in the shared palette: a road does not care who owns the land it reaches.
func _build_links() -> void:
	var gap := Jobs.SPACING - QUARTER_HALF * 2.0
	var seen: Dictionary = {}
	for district: Dictionary in Jobs.districts():
		var origin: Vector2 = district["origin"]
		for other: Dictionary in Jobs.districts():
			var to: Vector2 = other["origin"]
			var key := "%s>%s" % [district["id"], other["id"]]
			var back := "%s>%s" % [other["id"], district["id"]]
			if seen.has(key) or seen.has(back):
				continue
			var delta := to - origin
			if absf(delta.x) > 0.5 and absf(delta.y) > 0.5:
				continue
			if delta.length() > Jobs.SPACING + 0.5 or delta.length() < 0.5:
				continue
			seen[key] = true
			var middle := (origin + to) * 0.5
			if absf(delta.x) > 0.5:
				# Side by side: the cross streets carry on across the gap.
				for z in [-CROSS_Z, CROSS_Z]:
					_batch.box(PAVEMENT, Vector3(gap, 0.12, (CROSS_HALF + 1.6) * 2.0), Vector3(middle.x, 0.03, origin.y + z))
					_batch.box(ROAD, Vector3(gap, 0.14, CROSS_HALF * 2.0), Vector3(middle.x, 0.05, origin.y + z))
			else:
				# One above the other: the avenue carries on.
				_batch.box(PAVEMENT, Vector3((AVENUE_HALF + 1.6) * 2.0, 0.12, gap), Vector3(origin.x, 0.03, middle.y))
				_batch.box(ROAD, Vector3(AVENUE_HALF * 2.0, 0.14, gap), Vector3(origin.x, 0.05, middle.y))


func _build_roads() -> void:
	# Pavements sit a touch proud of the asphalt.
	_batch.box(PAVEMENT, Vector3((AVENUE_HALF + 1.6) * 2.0, 0.12, QUARTER_HALF * 2.0), _at(Vector3(0, 0.03, 0)))
	_batch.box(ROAD, Vector3(AVENUE_HALF * 2.0, 0.14, QUARTER_HALF * 2.0), _at(Vector3(0, 0.05, 0)))

	for z in [-CROSS_Z, CROSS_Z]:
		_batch.box(PAVEMENT, Vector3(QUARTER_HALF * 2.0, 0.12, (CROSS_HALF + 1.6) * 2.0), _at(Vector3(0, 0.03, z)))
		_batch.box(ROAD, Vector3(QUARTER_HALF * 2.0, 0.14, CROSS_HALF * 2.0), _at(Vector3(0, 0.05, z)))

	# Centre lines, skipping the junctions.
	var z := -QUARTER_HALF + 2.0
	while z < QUARTER_HALF:
		if absf(z - CROSS_Z) > CROSS_HALF + 1.0 and absf(z + CROSS_Z) > CROSS_HALF + 1.0:
			_batch.box(LINE, Vector3(0.28, 0.02, 2.2), _at(Vector3(0, 0.13, z)))
		z += 5.0
	for cross_z in [-CROSS_Z, CROSS_Z]:
		var x := -QUARTER_HALF + 2.0
		while x < QUARTER_HALF:
			if absf(x) > AVENUE_HALF + 1.0:
				_batch.box(LINE, Vector3(2.2, 0.02, 0.28), _at(Vector3(x, 0.13, cross_z)))
			x += 5.0


# -------------------------------------------------------------------- shops

## Every quarter has its own trade. Maple's avenue is a full parade; the others
## have a shop or two and a square with a fountain in the space left over.
func _build_shops(district: Dictionary) -> void:
	# Five plots down each side of the avenue, between the cross streets,
	# filled from the middle out so a short parade still looks arranged.
	var slots := [
		Vector2(-9.5, 0.0), Vector2(9.5, 0.0),
		Vector2(-9.5, -7.0), Vector2(9.5, -7.0),
		Vector2(-9.5, 7.0), Vector2(9.5, 7.0),
		Vector2(-9.5, -14.0), Vector2(9.5, -14.0),
		Vector2(-9.5, 14.0), Vector2(9.5, 14.0),
	]
	var shops := Catalog.shops_in(str(district["id"]))
	for i in mini(shops.size(), slots.size()):
		_build_shop(shops[i], slots[i], float(i % 3) * 2.6)
	if shops.size() < slots.size() - 1:
		_build_plaza(district, shops.size())


func _build_shop(shop: Dictionary, slot: Vector2, stagger: float) -> void:
	# Shopfronts face the avenue.
	var yaw: float = deg_to_rad(90.0 if slot.x < 0.0 else -90.0)
	var world := _frame(Transform3D(Basis(Vector3.UP, yaw), Vector3(slot.x, 0, slot.y)))

	# The shop's colour, knocked back for use on the building itself. At full
	# strength a parade of ten of them reads as a row of neon, and the sign and
	# the map pin carry the identity anyway.
	var accent: Color = (shop["color"] as Color).lerp(Color(0.86, 0.85, 0.82), 0.26)
	var wall := Color(0.88, 0.87, 0.85)
	var dark := Color(0.22, 0.23, 0.27)
	var glass := Color(0.55, 0.72, 0.82, 0.55)

	var width := 6.6
	var depth := 5.4
	var height := 4.6

	_batch.box(wall, Vector3(width, height, depth), world * Vector3(0, height * 0.5, -depth * 0.5), SceneryBatch.Layer.OPAQUE, world.basis)
	_roof_top(world, accent, width, depth, height)
	# The fascia over the window, which is where a shop's colour belongs — on
	# its front, where you read it from, and not spread over the whole roof.
	_batch.box(accent, Vector3(width, 0.85, 0.22), world * Vector3(0, 4.0, 0.06), SceneryBatch.Layer.OPAQUE, world.basis)
	_batch.box(accent.darkened(0.35), Vector3(width, 0.10, 0.26), world * Vector3(0, 3.55, 0.07), SceneryBatch.Layer.OPAQUE, world.basis)
	# Shopfront glazing, mullions and door.
	_batch.box(glass, Vector3(width - 1.2, 2.4, 0.12), world * Vector3(0, 1.5, 0.02), SceneryBatch.Layer.GLASS, world.basis)
	for m in 3:
		var mx: float = (float(m) - 1.0) * (width - 1.2) * 0.30
		_batch.box(dark, Vector3(0.10, 2.4, 0.16), world * Vector3(mx, 1.5, 0.05), SceneryBatch.Layer.OPAQUE, world.basis)
	_batch.box(dark, Vector3(width - 1.0, 0.14, 0.20), world * Vector3(0, 0.26, 0.04), SceneryBatch.Layer.OPAQUE, world.basis)
	_batch.box(dark, Vector3(1.0, 2.2, 0.16), world * Vector3(width * 0.5 - 1.1, 1.1, 0.04), SceneryBatch.Layer.OPAQUE, world.basis)
	# A striped awning, hung on two stays.
	for i in 5:
		var stripe: Color = accent if i % 2 == 0 else Color(0.94, 0.93, 0.90)
		_batch.box(stripe, Vector3((width - 0.4) / 5.0, 0.16, 1.5),
			world * Vector3((float(i) - 2.0) * (width - 0.4) / 5.0, 3.15, 0.7),
			SceneryBatch.Layer.OPAQUE, world.basis)
	for sx in [-1.0, 1.0]:
		_batch.box(dark, Vector3(0.1, 0.9, 0.1), world * Vector3(sx * (width * 0.5 - 0.5), 3.6, 1.3), SceneryBatch.Layer.OPAQUE, world.basis)
	# Two planters by the door.
	for sx in [-1.0, 1.0]:
		var planter_x: float = sx * (width * 0.5 - 0.45)
		_batch.box(Color(0.55, 0.52, 0.48), Vector3(0.7, 0.55, 0.7), world * Vector3(planter_x, 0.28, 0.75), SceneryBatch.Layer.OPAQUE, world.basis)
		_batch.sphere(Color(0.30, 0.52, 0.28), 0.42, world * Vector3(planter_x, 0.95, 0.75))

	var holder := Node3D.new()
	holder.name = "Shop_%s" % shop["id"]
	holder.transform = world
	_pickables.add_child(holder)

	# Billboarded at a fixed screen size so map labels stay legible at any zoom.
	# Neighbouring signs are staggered in height so they do not collide.
	var sign := Label3D.new()
	sign.text = shop["name"]
	sign.font_size = 64
	sign.pixel_size = 0.00050
	sign.fixed_size = true
	sign.position = Vector3(0, height + 1.8 + stagger, -depth * 0.5)
	sign.modulate = (shop["color"] as Color).lightened(0.5)
	sign.outline_size = 22
	sign.outline_modulate = Color(0.05, 0.06, 0.09, 0.95)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.no_depth_test = true
	sign.render_priority = 2
	holder.add_child(sign)
	_shop_labels.append(sign)

	var body := StaticBody3D.new()
	body.collision_layer = PICK_LAYER
	body.collision_mask = 0
	body.set_meta("shop_id", shop["id"])
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width + 0.5, height + 1.0, depth + 1.5)
	shape.shape = box
	shape.position = Vector3(0, (height + 1.0) * 0.5, -depth * 0.5 + 0.4)
	body.add_child(shape)
	holder.add_child(body)


## What the map spends most of its time looking at. A shop's roof used to be one
## slab in the shop's own colour, which from up here read as a sheet of paint
## lying on the grass rather than as a building. It is a felted deck now, with
## the colour kept to a band round the parapet and enough on top of it — a
## plant room, vents, a rooflight, a run of ducting — to say this is a roof.
func _roof_top(world: Transform3D, accent: Color, width: float, depth: float, height: float) -> void:
	var b := world.basis
	var middle := -depth * 0.5
	var felt := _tone(Color(0.30, 0.31, 0.34))
	var kit := _tone(Color(0.62, 0.63, 0.66))

	_batch.box(felt, Vector3(width + 0.24, 0.30, depth + 0.24),
		world * Vector3(0, height + 0.05, middle), SceneryBatch.Layer.OPAQUE, b)
	# The parapet: four thin walls, the coloured band on the outside of them.
	for sz in [-1.0, 1.0]:
		_batch.box(accent, Vector3(width + 0.3, 0.5, 0.18),
			world * Vector3(0, height + 0.42, middle + sz * (depth + 0.12) * 0.5),
			SceneryBatch.Layer.OPAQUE, b)
	for sx in [-1.0, 1.0]:
		_batch.box(accent, Vector3(0.18, 0.5, depth + 0.3),
			world * Vector3(sx * (width + 0.12) * 0.5, height + 0.42, middle),
			SceneryBatch.Layer.OPAQUE, b)

	# A plant room and its ducting, a rooflight, and a couple of vents.
	_batch.box(kit, Vector3(1.7, 0.85, 1.3),
		world * Vector3(-width * 0.22, height + 0.62, middle - depth * 0.22),
		SceneryBatch.Layer.OPAQUE, b)
	_batch.box(kit.darkened(0.2), Vector3(1.9, 0.14, 1.5),
		world * Vector3(-width * 0.22, height + 1.08, middle - depth * 0.22),
		SceneryBatch.Layer.OPAQUE, b)
	_batch.box(kit.darkened(0.12), Vector3(0.34, 0.34, depth * 0.42),
		world * Vector3(-width * 0.22, height + 0.38, middle + depth * 0.10),
		SceneryBatch.Layer.OPAQUE, b)
	_batch.box(_tone(Color(0.62, 0.78, 0.86, 0.7)), Vector3(1.5, 0.16, 1.2),
		world * Vector3(width * 0.24, height + 0.30, middle + depth * 0.14),
		SceneryBatch.Layer.GLASS, b)
	for i in 2:
		_batch.cylinder(kit, 0.22, 0.55,
			world * Vector3(width * 0.28, height + 0.48, middle - depth * (0.18 + float(i) * 0.16)),
			SceneryBatch.Layer.SHINY, 10, b)


# -------------------------------------------------------------------- plaza

## The stretch of avenue a quarter's shops do not fill becomes a square:
## paving, a fountain and some benches, so the centre is not bald grass.
## `taken` is how many shop plots are already spoken for, counting from the
## middle out, which is where the paving has to start.
func _build_plaza(district: Dictionary, taken: int) -> void:
	var paving := _tone(Color(0.62, 0.61, 0.58))
	var stone := _tone(Color(0.72, 0.71, 0.68))
	var water := _tone(Color(0.34, 0.58, 0.72, 0.80))
	var accent: Color = _tone(district["accent"])
	# Plots are filled two at a time, one each side, from z = 0 outwards.
	var near: float = 3.5 + ceilf(float(taken) * 0.5) * 7.0
	var far := 21.0
	if far - near < 6.0:
		return
	var span := far - near

	for sx in [-1.0, 1.0]:
		var cx: float = sx * 11.0
		for sz in [-1.0, 1.0]:
			var centre: float = sz * (near + span * 0.5)
			_batch.box(paving, Vector3(11.0, 0.12, span), _at(Vector3(cx, 0.06, centre)))
			# A ring of paving bands, so the square is not one flat rectangle.
			_batch.box(stone, Vector3(9.0, 0.14, 1.2), _at(Vector3(cx, 0.08, centre)))

			# Fountain.
			_batch.cylinder(stone, 2.2, 0.7, _at(Vector3(cx, 0.35, centre)), SceneryBatch.Layer.OPAQUE, 16)
			_batch.cylinder(water, 1.9, 0.16, _at(Vector3(cx, 0.72, centre)), SceneryBatch.Layer.GLASS, 16)
			_batch.cylinder(stone, 0.35, 1.6, _at(Vector3(cx, 1.4, centre)), SceneryBatch.Layer.OPAQUE, 10)
			_batch.sphere(accent, 0.55, _at(Vector3(cx, 2.4, centre)))

			# Benches facing the fountain.
			for bench in [-1.0, 1.0]:
				var bz: float = centre + bench * (span * 0.5 - 1.6)
				_batch.box(_tone(Color(0.48, 0.36, 0.24)), Vector3(3.0, 0.16, 0.6), _at(Vector3(cx, 0.55, bz)))
				for bx in [-1.2, 1.2]:
					_batch.box(_tone(Color(0.30, 0.32, 0.36)), Vector3(0.14, 0.46, 0.5), _at(Vector3(cx + bx, 0.3, bz)))


# ------------------------------------------------------------------- houses

func _build_houses(district: Dictionary) -> void:
	var houses := Jobs.houses_in(str(district["id"]))
	for i in houses.size():
		# Neighbours get their name plates at three different heights so the
		# labels do not stack on top of each other from map height. Two was not
		# enough: a plate still landed on its neighbour's neighbour.
		_build_house(houses[i], float(i % 3) * 2.4, district)


func _build_house(job: Dictionary, stagger: float, district: Dictionary) -> void:
	var map: Dictionary = job["map"]
	var style: Dictionary = job["style"]
	var size: Vector3 = style["size"]
	var world := _frame(Transform3D(
		Basis(Vector3.UP, deg_to_rad(float(map.get("rot", 0.0)))),
		Vector3(map["pos"].x, 0, map["pos"].y)
	))

	# Quarters that build to their own pattern say so on the house.
	match str(style.get("kind", "house")):
		"machiya":
			_machiya(job, style, world)
		"manor":
			_manor(job, style, world)
		_:
			_terrace_house(job, style, world)

	var holder := Node3D.new()
	holder.name = "House_%s" % job["id"]
	holder.transform = world
	_pickables.add_child(holder)

	# A house behind a hoarding is a building, not a job: no name plate, no pin,
	# and tapping it asks about the quarter rather than the room.
	if not _locked:
		var plate := Label3D.new()
		plate.text = str(job.get("short", job["name"]))
		plate.font_size = 64
		plate.pixel_size = 0.00058
		plate.fixed_size = true
		plate.position = Vector3(0, size.y + 1.2 + stagger, size.z * 0.5 + 2.4)
		plate.modulate = Color(0.97, 0.98, 1.0)
		plate.outline_size = 24
		plate.outline_modulate = Color(0.05, 0.06, 0.09, 0.95)
		plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plate.no_depth_test = true
		plate.render_priority = 2
		holder.add_child(plate)
		_house_labels.append(plate)

		_build_marker(holder, job, size)

	var pick := StaticBody3D.new()
	pick.collision_layer = PICK_LAYER
	pick.collision_mask = 0
	if _locked:
		pick.set_meta("district_id", district["id"])
	else:
		pick.set_meta("house_id", job["id"])
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x + 3.0, size.y + 4.0, size.z + 3.4)
	shape.shape = box
	shape.position = Vector3(0, (size.y + 4.0) * 0.5, 0)
	pick.add_child(shape)
	holder.add_child(pick)


## The ordinary house, and what most of the city is built of: rendered walls, a
## pitched roof, a chimney and a hedge.
func _terrace_house(job: Dictionary, style: Dictionary, world: Transform3D) -> void:
	var size: Vector3 = style["size"]
	var body_color: Color = _tone(style["body"])
	var roof_color: Color = _tone(style["roof"])
	var trim := _tone(Color(0.95, 0.95, 0.93))
	var glass := _tone(Color(0.52, 0.70, 0.82, 0.75))
	var door_color: Color = roof_color.darkened(0.25)
	var b := world.basis

	# Plot and path.
	_batch.box(_tone(LAWN), Vector3(size.x + 3.6, 0.10, size.z + 4.0), world * Vector3(0, 0.02, 0), SceneryBatch.Layer.OPAQUE, b)
	_batch.box(_tone(PAVEMENT), Vector3(1.4, 0.06, (size.z + 4.0) * 0.5), world * Vector3(0, 0.08, size.z * 0.5 + 1.0), SceneryBatch.Layer.OPAQUE, b)

	# Walls, floor band and roof.
	_batch.box(body_color, size, world * Vector3(0, size.y * 0.5 + 0.1, 0), SceneryBatch.Layer.OPAQUE, b)
	_batch.box(trim, Vector3(size.x + 0.3, 0.3, size.z + 0.3), world * Vector3(0, 0.25, 0), SceneryBatch.Layer.OPAQUE, b)
	_pitched_roof(world, roof_color, Vector2(size.x + 0.7, size.z + 0.7), size.y + 0.1, 1.9)
	_batch.box(roof_color.darkened(0.35), Vector3(0.7, 1.5, 0.7), world * Vector3(size.x * 0.28, size.y + 1.4, -size.z * 0.22), SceneryBatch.Layer.OPAQUE, b)
	_batch.box(trim.darkened(0.10), Vector3(0.78, 0.22, 0.78), world * Vector3(size.x * 0.28, size.y + 2.2, -size.z * 0.22), SceneryBatch.Layer.OPAQUE, b)

	# Front door and windows.
	var front := size.z * 0.5 + 0.06
	_batch.box(door_color, Vector3(1.1, 2.1, 0.12), world * Vector3(0, 1.15, front), SceneryBatch.Layer.OPAQUE, b)
	_batch.cylinder(_tone(Color(0.85, 0.72, 0.35)), 0.06, 0.1, world * Vector3(0.38, 1.15, front + 0.08), SceneryBatch.Layer.SHINY, 8, b)
	for sx in [-1.0, 1.0]:
		var wx: float = sx * size.x * 0.28
		_batch.box(trim, Vector3(1.5, 1.4, 0.06), world * Vector3(wx, 1.9, front - 0.02), SceneryBatch.Layer.OPAQUE, b)
		_batch.box(glass, Vector3(1.3, 1.2, 0.10), world * Vector3(wx, 1.9, front), SceneryBatch.Layer.GLASS, b)
	# Taller houses carry their windows up the storeys.
	var storey := 4.2
	while storey < size.y - 0.6:
		for sx in [-1.0, 1.0]:
			_batch.box(glass, Vector3(1.2, 1.1, 0.10), world * Vector3(sx * size.x * 0.28, storey, front), SceneryBatch.Layer.GLASS, b)
		storey += 2.6

	# A hedge and a bin, so no two plots look identical.
	var hedge_side: float = -1.0 if int(str(job["id"]).hash()) % 2 == 0 else 1.0
	_batch.box(_tone(Color(0.26, 0.46, 0.26)), Vector3(0.6, 0.9, size.z + 2.0), world * Vector3(hedge_side * (size.x * 0.5 + 1.4), 0.5, 0), SceneryBatch.Layer.OPAQUE, b)
	_batch.cylinder(_tone(Color(0.30, 0.34, 0.38)), 0.34, 0.9, world * Vector3(-hedge_side * (size.x * 0.5 + 1.0), 0.5, size.z * 0.4), SceneryBatch.Layer.OPAQUE, 10, b)


## A pitched roof, which from map height is most of what a house is. A bare
## prism reads as a coloured wedge, so this one gets the things that say tile:
## courses running up each slope, a ridge cap along the top and barge boards
## down the ends.
## `plan` is the roof's footprint and `base` the height it springs from. A
## PrismMesh runs its ridge along Z and slopes away to ±X, so that is the axis
## everything here is laid out on.
func _pitched_roof(world: Transform3D, roof_color: Color, plan: Vector2,
		base: float, rise: float, courses: int = 4, verge: bool = true) -> void:
	var b := world.basis
	_batch.prism(roof_color, Vector3(plan.x, rise, plan.y),
		world * Vector3(0, base + rise * 0.5, 0), SceneryBatch.Layer.OPAQUE, b)

	# Courses up each slope, each one sitting proud of the one below it. The
	# bar runs the length of the ridge and is laid over on the pitch.
	var pitch := atan2(rise, plan.x * 0.5)
	var out := Vector2(sin(pitch), cos(pitch)) * 0.035
	for sx in [-1.0, 1.0]:
		for i in courses:
			var along: float = (float(i) + 0.5) / float(courses)
			var x: float = sx * plan.x * 0.5 * (1.0 - along)
			var y: float = base + rise * along
			_batch.box(roof_color.darkened(0.13 if i % 2 == 0 else 0.04),
				Vector3(0.18, 0.07, plan.y + 0.04),
				world * Vector3(x + sx * out.x, y + out.y, 0),
				SceneryBatch.Layer.OPAQUE,
				b * Basis(Vector3.BACK, -sx * pitch))
	# The ridge along the top, and a board down each gable end.
	_batch.box(roof_color.darkened(0.22), Vector3(0.26, 0.16, plan.y + 0.18),
		world * Vector3(0, base + rise, 0), SceneryBatch.Layer.OPAQUE, b)
	if not verge:
		return
	for sz in [-1.0, 1.0]:
		_batch.prism(roof_color.darkened(0.28), Vector3(plan.x + 0.12, rise, 0.16),
			world * Vector3(0, base + rise * 0.5, sz * plan.y * 0.5),
			SceneryBatch.Layer.OPAQUE, b)


## Hanami Ward. A townhouse under a broad tiled roof: shallow pitch, eaves that
## overhang far enough to stand under, a raised veranda along the front and
## paper panels instead of glass.
func _machiya(job: Dictionary, style: Dictionary, world: Transform3D) -> void:
	var size: Vector3 = style["size"]
	var body_color: Color = _tone(style["body"])
	var roof_color: Color = _tone(style["roof"])
	var timber := _tone(Color(0.34, 0.24, 0.18))
	var paper := _tone(Color(0.96, 0.94, 0.88))
	var b := world.basis

	# Raked gravel rather than lawn, with stepping stones to the door.
	_batch.box(_tone(Color(0.72, 0.70, 0.64)), Vector3(size.x + 3.6, 0.10, size.z + 4.2), world * Vector3(0, 0.02, 0), SceneryBatch.Layer.OPAQUE, b)
	for i in 3:
		_batch.box(_tone(Color(0.52, 0.52, 0.50)), Vector3(0.8, 0.08, 0.6),
			world * Vector3(0, 0.09, size.z * 0.5 + 0.9 + float(i) * 0.95), SceneryBatch.Layer.OPAQUE, b)

	# The body, on a plinth, with a timber frame showing at the corners.
	_batch.box(timber, Vector3(size.x + 0.5, 0.42, size.z + 0.5), world * Vector3(0, 0.21, 0), SceneryBatch.Layer.OPAQUE, b)
	_batch.box(body_color, size, world * Vector3(0, size.y * 0.5 + 0.42, 0), SceneryBatch.Layer.OPAQUE, b)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_batch.box(timber, Vector3(0.26, size.y, 0.26),
				world * Vector3(sx * size.x * 0.5, size.y * 0.5 + 0.42, sz * size.z * 0.5), SceneryBatch.Layer.OPAQUE, b)

	# The engawa: a plank veranda along the front, under the eaves.
	var front := size.z * 0.5
	_batch.box(_tone(Color(0.58, 0.44, 0.30)), Vector3(size.x + 0.4, 0.16, 1.5),
		world * Vector3(0, 0.50, front + 0.75), SceneryBatch.Layer.OPAQUE, b)

	# Shoji panels across the front, split by mullions.
	var panels := maxi(int(size.x / 1.5), 3)
	var step := (size.x - 0.6) / float(panels)
	for i in panels:
		var px := -size.x * 0.5 + 0.3 + step * (float(i) + 0.5)
		_batch.box(paper, Vector3(step * 0.86, 1.95, 0.10), world * Vector3(px, 1.55, front + 0.02), SceneryBatch.Layer.OPAQUE, b)
		_batch.box(timber, Vector3(0.09, 2.05, 0.13), world * Vector3(px + step * 0.5, 1.55, front + 0.04), SceneryBatch.Layer.OPAQUE, b)
	_batch.box(timber, Vector3(size.x, 0.14, 0.16), world * Vector3(0, 2.56, front + 0.04), SceneryBatch.Layer.OPAQUE, b)

	# The roof: a shallow prism with a deep overhang all round, on a fascia.
	var eave := 1.5
	var ridge: float = 0.9 + size.y * 0.10
	_batch.box(roof_color.darkened(0.25), Vector3(size.x + eave * 2.0, 0.22, size.z + eave * 2.0),
		world * Vector3(0, size.y + 0.52, 0), SceneryBatch.Layer.OPAQUE, b)
	_pitched_roof(world, roof_color,
		Vector2(size.x + eave * 2.0, size.z + eave * 2.0), size.y + 0.63, ridge, 6, false)
	# Two more storeys get a second, smaller roof over them.
	if size.y > 4.6:
		_batch.box(roof_color.darkened(0.25), Vector3(size.x + eave, 0.20, size.z + eave),
			world * Vector3(0, size.y * 0.56, 0), SceneryBatch.Layer.OPAQUE, b)

	# A stone lantern at the corner of the plot.
	var side: float = -1.0 if int(str(job["id"]).hash()) % 2 == 0 else 1.0
	var lantern := world * Vector3(side * (size.x * 0.5 + 1.5), 0.0, front + 1.4)
	_batch.cylinder(_tone(Color(0.55, 0.55, 0.52)), 0.20, 0.9, lantern + Vector3(0, 0.45, 0), SceneryBatch.Layer.OPAQUE, 8)
	_batch.box(_tone(Color(0.62, 0.62, 0.58)), Vector3(0.60, 0.42, 0.60), lantern + Vector3(0, 1.11, 0), SceneryBatch.Layer.OPAQUE, b)
	_batch.box(_tone(Color(0.98, 0.92, 0.72)), Vector3(0.40, 0.30, 0.40), lantern + Vector3(0, 1.11, 0), SceneryBatch.Layer.OPAQUE, b)
	_batch.prism(_tone(Color(0.50, 0.50, 0.47)), Vector3(0.86, 0.34, 0.86), lantern + Vector3(0, 1.49, 0), SceneryBatch.Layer.OPAQUE, b)


## Hollow Row. Steep slate, a corner tower with a spire, tall thin windows and
## an iron railing along the front. Nothing here has been painted this century.
func _manor(job: Dictionary, style: Dictionary, world: Transform3D) -> void:
	var size: Vector3 = style["size"]
	var body_color: Color = _tone(style["body"])
	var roof_color: Color = _tone(style["roof"])
	var iron := _tone(Color(0.15, 0.15, 0.18))
	var glass := _tone(Color(0.86, 0.72, 0.36, 0.85))
	var b := world.basis

	# A dark, overgrown plot behind railings.
	_batch.box(_tone(Color(0.22, 0.26, 0.21)), Vector3(size.x + 3.6, 0.10, size.z + 4.2), world * Vector3(0, 0.02, 0), SceneryBatch.Layer.OPAQUE, b)
	_batch.box(_tone(Color(0.34, 0.33, 0.32)), Vector3(1.3, 0.06, (size.z + 4.2) * 0.5), world * Vector3(0, 0.08, size.z * 0.5 + 1.05), SceneryBatch.Layer.OPAQUE, b)
	var rail_z := size.z * 0.5 + 2.0
	_batch.box(iron, Vector3(size.x + 3.4, 0.10, 0.10), world * Vector3(0, 1.05, rail_z), SceneryBatch.Layer.SHINY, b)
	for i in 11:
		var rx := -(size.x + 3.2) * 0.5 + (size.x + 3.2) * float(i) / 10.0
		if absf(rx) < 0.9:
			continue
		_batch.box(iron, Vector3(0.08, 1.10, 0.08), world * Vector3(rx, 0.55, rail_z), SceneryBatch.Layer.SHINY, b)

	# Body and a heavy string course.
	_batch.box(body_color, size, world * Vector3(0, size.y * 0.5 + 0.1, 0), SceneryBatch.Layer.OPAQUE, b)
	_batch.box(body_color.darkened(0.30), Vector3(size.x + 0.34, 0.34, size.z + 0.34), world * Vector3(0, 0.28, 0), SceneryBatch.Layer.OPAQUE, b)
	_batch.box(body_color.darkened(0.22), Vector3(size.x + 0.26, 0.26, size.z + 0.26), world * Vector3(0, size.y - 0.2, 0), SceneryBatch.Layer.OPAQUE, b)

	# A steep roof, and a chimney stack at each end.
	_pitched_roof(world, roof_color, Vector2(size.x + 0.6, size.z + 0.6),
		size.y, size.y * 0.62 + 1.4, 7)
	for sx in [-1.0, 1.0]:
		_batch.box(body_color.darkened(0.42), Vector3(0.8, 2.3, 0.8), world * Vector3(sx * size.x * 0.34, size.y + 1.5, -size.z * 0.18), SceneryBatch.Layer.OPAQUE, b)

	# The tower on the front corner, with a spire on top.
	var tx: float = (size.x * 0.5 + 0.5) * (-1.0 if int(str(job["id"]).hash()) % 2 == 0 else 1.0)
	var tower_h: float = size.y + 2.4
	var tower := world * Vector3(tx, 0, size.z * 0.5 - 0.6)
	_batch.cylinder(body_color.darkened(0.12), 1.25, tower_h, tower + Vector3(0, tower_h * 0.5, 0), SceneryBatch.Layer.OPAQUE, 10)
	_batch.cylinder(body_color.darkened(0.34), 1.38, 0.30, tower + Vector3(0, tower_h - 0.15, 0), SceneryBatch.Layer.OPAQUE, 10)
	_batch.cone(roof_color.darkened(0.15), 1.42, 3.2, tower + Vector3(0, tower_h + 1.6, 0), SceneryBatch.Layer.OPAQUE, 10)
	_batch.box(glass, Vector3(0.5, 1.1, 0.14), tower + Vector3(0, tower_h * 0.62, 1.2), SceneryBatch.Layer.GLASS, b)

	# Door and the tall lit windows.
	var front := size.z * 0.5 + 0.06
	_batch.box(_tone(Color(0.24, 0.16, 0.14)), Vector3(1.2, 2.4, 0.14), world * Vector3(0, 1.30, front), SceneryBatch.Layer.OPAQUE, b)
	_batch.prism(_tone(Color(0.24, 0.16, 0.14)), Vector3(1.2, 0.5, 0.14), world * Vector3(0, 2.70, front), SceneryBatch.Layer.OPAQUE, b)
	var storey := 1.9
	while storey < size.y - 0.9:
		for sx in [-1.0, 1.0]:
			var wx: float = sx * size.x * 0.30
			_batch.box(glass, Vector3(0.62, 1.7, 0.12), world * Vector3(wx, storey, front), SceneryBatch.Layer.GLASS, b)
			_batch.prism(body_color.darkened(0.35), Vector3(0.78, 0.42, 0.14), world * Vector3(wx, storey + 1.06, front), SceneryBatch.Layer.OPAQUE, b)
		storey += 2.7

	# A dead tree leaning over the plot.
	var side: float = 1.0 if int(str(job["id"]).hash()) % 2 == 0 else -1.0
	var bare := world * Vector3(side * (size.x * 0.5 + 1.7), 0, -size.z * 0.2)
	var bark := _tone(Color(0.24, 0.20, 0.18))
	_batch.cylinder(bark, 0.26, 4.2, bare + Vector3(0, 2.1, 0), SceneryBatch.Layer.OPAQUE, 8)
	for a in [-52.0, 24.0, 108.0]:
		var swing := Basis(Vector3.FORWARD, deg_to_rad(a))
		_batch.cylinder(bark, 0.10, 2.0, bare + Vector3(sin(deg_to_rad(a)) * 0.7, 4.2, cos(deg_to_rad(a)) * 0.4), SceneryBatch.Layer.OPAQUE, 6, swing)


## The floating pin that tells the player what a house wants from them.
func _build_marker(parent: Node3D, job: Dictionary, size: Vector3) -> void:
	var marker := Node3D.new()
	marker.name = "Marker"
	var base_y: float = size.y + 4.6
	marker.position = Vector3(0, base_y, 0)
	marker.set_meta("base_y", base_y)
	marker.set_meta("phase", float(absi(int(str(job["id"]).hash())) % 100) * 0.06)
	parent.add_child(marker)

	var material := StandardMaterial3D.new()
	material.albedo_color = MARKER_AVAILABLE
	material.roughness = 0.35
	material.emission_enabled = true
	material.emission = MARKER_AVAILABLE
	material.emission_energy_multiplier = 0.75

	# A downward map pin: cone under a ball, sized to read from map height.
	var pin := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 1.30
	cone.bottom_radius = 0.0
	cone.height = 2.30
	cone.radial_segments = 4
	pin.mesh = cone
	pin.position = Vector3(0, 1.15, 0)
	pin.material_override = material
	pin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(pin)

	var top := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.95
	ball.height = 1.90
	ball.radial_segments = 10
	ball.rings = 6
	top.mesh = ball
	top.position = Vector3(0, 2.75, 0)
	top.material_override = material
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(top)

	marker.set_meta("material", material)
	_markers[job["id"]] = marker


## Recolours every pin from the player's current progress.
func refresh_markers() -> void:
	for house_id: String in _markers:
		var marker: Node3D = _markers[house_id]
		var material: StandardMaterial3D = marker.get_meta("material")
		var job := Jobs.get_job(house_id)
		var color := MARKER_AVAILABLE
		if Game.level < int(job.get("level", 1)):
			color = MARKER_LOCKED
		elif not Game.layout_for(house_id).is_empty() and not Game.is_job_done(house_id):
			color = MARKER_RESUME
		elif Game.is_job_done(house_id):
			color = MARKER_DONE
		material.albedo_color = color
		material.emission = color


# ----------------------------------------------------------------- hoarding

## What a quarter you do not own yet looks like: a builder's hoarding round the
## edge, and a sign in the middle with the asking price on it.
func _build_hoarding(district: Dictionary) -> void:
	var accent: Color = district["accent"]
	var board := Color(0.86, 0.72, 0.28)
	var post := Color(0.32, 0.30, 0.28)
	var edge := QUARTER_HALF - 1.0
	var height := 2.2

	for side in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		var along := Vector2(side.y, side.x)
		var half_road: float = AVENUE_HALF + 2.0 if absf(side.y) > 0.5 else CROSS_HALF + 2.0
		# Two runs per side, leaving the road through the middle open.
		for sign_x in [-1.0, 1.0]:
			var run: float = (QUARTER_HALF - half_road)
			var centre: Vector2 = side * edge + along * sign_x * (half_road + run * 0.5)
			var size := Vector3(
				absf(along.x) * run + absf(side.x) * 0.4,
				height,
				absf(along.y) * run + absf(side.y) * 0.4)
			_batch.box(board, size, _at(Vector3(centre.x, height * 0.5, centre.y)))
			_batch.box(accent, Vector3(size.x, 0.3, size.z) + Vector3(0.1, 0, 0.1), _at(Vector3(centre.x, height - 0.15, centre.y)))
			# Posts along the run.
			var steps := int(run / 6.0) + 1
			for i in steps + 1:
				var t: float = float(i) / float(steps)
				var at: Vector2 = centre + along * sign_x * (t - 0.5) * run
				_batch.box(post, Vector3(0.34, height + 0.3, 0.34), _at(Vector3(at.x, (height + 0.3) * 0.5, at.y)))

	# The sign in the middle of the quarter, and a plinth to pick.
	var holder := Node3D.new()
	holder.name = "District_%s" % district["id"]
	holder.position = _at(Vector3.ZERO)
	_pickables.add_child(holder)

	_batch.box(post, Vector3(1.0, 12.0, 1.0), _at(Vector3(0, 6.0, 0)))
	_batch.box(board, Vector3(8.0, 3.4, 0.5), _at(Vector3(0, 13.4, 0)))
	_batch.box(accent, Vector3(8.4, 0.5, 0.7), _at(Vector3(0, 15.35, 0)))

	var sign := Label3D.new()
	sign.text = "%s\n%s · level %d" % [
		district["name"], UIKit.money(int(district["cost"])), int(district["level"])]
	sign.font_size = 60
	sign.pixel_size = 0.00060
	sign.fixed_size = true
	sign.position = Vector3(0, 17.6, 0)
	sign.modulate = Color(1.0, 0.92, 0.68)
	sign.outline_size = 26
	sign.outline_modulate = Color(0.05, 0.06, 0.09, 0.95)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.no_depth_test = true
	sign.render_priority = 3
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(sign)

	var pick := StaticBody3D.new()
	pick.collision_layer = PICK_LAYER
	pick.collision_mask = 0
	pick.set_meta("district_id", district["id"])
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(9.0, 17.0, 3.0)
	shape.shape = box
	shape.position = Vector3(0, 8.5, 0)
	pick.add_child(shape)
	holder.add_child(pick)


# ---------------------------------------------------------------- greenery

## The trees, lamps and parked cars a quarter is planted with. Two quarters
## are planted differently enough to be recognisable from map height: Hanami is
## cherry, and Hollow is whatever is left after the cherry.
func _build_greenery(planting: String = "street") -> void:
	var trunk := _tone(Color(0.36, 0.27, 0.19))
	var leaves := [
		_tone(Color(0.26, 0.48, 0.26)),
		_tone(Color(0.32, 0.55, 0.30)),
		_tone(Color(0.22, 0.42, 0.24)),
	]
	if planting == "cherry":
		trunk = _tone(Color(0.32, 0.24, 0.22))
		leaves = [
			_tone(Color(0.92, 0.56, 0.68)),
			_tone(Color(0.86, 0.44, 0.60)),
			_tone(Color(0.96, 0.68, 0.78)),
		]
	elif planting == "bare":
		trunk = _tone(Color(0.22, 0.19, 0.18))
		leaves = [
			_tone(Color(0.26, 0.24, 0.28)),
			_tone(Color(0.22, 0.21, 0.26)),
			_tone(Color(0.30, 0.26, 0.32)),
		]
	var post := _tone(Color(0.24, 0.26, 0.30))
	var glow := _tone(Color(0.98, 0.92, 0.70))
	if planting == "bare":
		glow = _tone(Color(0.72, 0.60, 0.92))

	# Street trees down the avenue and the two cross streets.
	var spots: Array[Vector2] = []
	for z in [-30.0, -24.0, 24.0, 30.0, -14.0, 14.0]:
		spots.append(Vector2(-7.2, z))
		spots.append(Vector2(7.2, z))
	for x in [-40.0, -28.0, -16.0, 16.0, 28.0, 40.0]:
		spots.append(Vector2(x, -CROSS_Z - 6.4))
		spots.append(Vector2(x, CROSS_Z + 6.4))
	for x in [-45.0, -38.0, 38.0, 45.0]:
		for z in [-38.0, -8.0, 8.0, 38.0]:
			spots.append(Vector2(x, z))

	for i in spots.size():
		var spot := spots[i]
		var scale_factor: float = 0.82 + float(i % 5) * 0.09
		_batch.cylinder(trunk, 0.22 * scale_factor, 2.2 * scale_factor, _at(Vector3(spot.x, 1.1 * scale_factor, spot.y)), SceneryBatch.Layer.OPAQUE, 8)
		var canopy: Color = leaves[i % leaves.size()]
		if planting == "bare":
			# No canopy at all — three bare limbs off the trunk instead.
			for a in [-56.0, 18.0, 122.0]:
				var swing := Basis(Vector3.FORWARD, deg_to_rad(a + float(i) * 11.0))
				_batch.cylinder(canopy, 0.09 * scale_factor, 1.9 * scale_factor,
					_at(Vector3(spot.x + sin(deg_to_rad(a)) * 0.6, 2.4 * scale_factor, spot.y + cos(deg_to_rad(a)) * 0.35)),
					SceneryBatch.Layer.OPAQUE, 6, swing)
			continue
		_batch.sphere(canopy, 1.35 * scale_factor, _at(Vector3(spot.x, 3.1 * scale_factor, spot.y)))
		_batch.sphere(canopy, 0.95 * scale_factor, _at(Vector3(spot.x + 0.7, 2.5 * scale_factor, spot.y - 0.4)))
		_batch.sphere(canopy, 0.85 * scale_factor, _at(Vector3(spot.x - 0.6, 2.6 * scale_factor, spot.y + 0.5)))
		if planting == "cherry":
			# Blossom on the ground under each tree.
			_batch.box(canopy, Vector3(2.6 * scale_factor, 0.04, 2.6 * scale_factor),
				_at(Vector3(spot.x, 0.13, spot.y)), SceneryBatch.Layer.OPAQUE)

	for z in [-22.0, -6.0, 6.0, 22.0]:
		for sx in [-1.0, 1.0]:
			var x: float = sx * (AVENUE_HALF + 1.0)
			_batch.cylinder(post, 0.09, 4.4, _at(Vector3(x, 2.2, z)), SceneryBatch.Layer.SHINY, 8)
			_batch.box(post, Vector3(0.9, 0.14, 0.3), _at(Vector3(x - sx * 0.4, 4.45, z)), SceneryBatch.Layer.SHINY)
			_batch.box(glow, Vector3(0.5, 0.18, 0.26), _at(Vector3(x - sx * 0.72, 4.32, z)))

	# One car parked up on the kerb. The rest of the traffic is moving, and
	# lives in CityLife rather than in the batch.
	_build_car(Vector2(-7.6, -34.0), _tone(Color(0.62, 0.64, 0.68)), 0.0)


func _build_car(spot: Vector2, color: Color, yaw: float) -> void:
	var world := _frame(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), Vector3(spot.x, 0, spot.y)))
	var b := world.basis
	var window := _tone(Color(0.28, 0.34, 0.40, 0.85))
	var tyre := _tone(Color(0.11, 0.11, 0.13))
	_batch.box(color, Vector3(1.8, 0.65, 4.0), world * Vector3(0, 0.62, 0), SceneryBatch.Layer.SHINY, b)
	_batch.box(window, Vector3(1.62, 0.62, 2.0), world * Vector3(0, 1.22, -0.2), SceneryBatch.Layer.GLASS, b)
	var wheel_basis := b * Basis(Vector3.FORWARD, deg_to_rad(90))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_batch.cylinder(tyre, 0.34, 0.24, world * Vector3(sx * 0.85, 0.34, sz * 1.35), SceneryBatch.Layer.OPAQUE, 10, wheel_basis)


# -------------------------------------------------------------------- camera

## The rectangle covering every quarter's centre, as [min, max].
func _city_bounds() -> Array[Vector2]:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for district: Dictionary in Jobs.districts():
		var origin: Vector2 = district["origin"]
		low = Vector2(minf(low.x, origin.x), minf(low.y, origin.y))
		high = Vector2(maxf(high.x, origin.x), maxf(high.y, origin.y))
	return [low, high]


## The camera roams the whole grid whether or not the player owns it: a quarter
## you cannot afford is meant to be something you can go and look at. Buying one
## changes what you can work on, not where you can point the camera.
func _apply_camera_limits() -> void:
	var bounds := _city_bounds()
	rig.pan_center = (bounds[0] + bounds[1]) * 0.5
	rig.pan_limit = (bounds[1] - bounds[0]) * 0.5 + Vector2(34, 34)
	rig.max_distance = clampf(maxf(rig.pan_limit.x, rig.pan_limit.y) * 2.8, 95.0, 320.0)


# -------------------------------------------------------------------- input

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


func _over_ui(position: Vector2) -> bool:
	return ui_probe.is_valid() and bool(ui_probe.call(position))


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _over_ui(event.position):
			return
		_touches[event.index] = event.position
		_touch_origins[event.index] = event.position
		if _touches.size() == 2:
			_gesture_is_pinch = true
			var points := _points()
			_pinch_distance = points[0].distance_to(points[1])
			_pinch_midpoint = (points[0] + points[1]) * 0.5
	else:
		var tapped: bool = _touch_origins.has(event.index) \
			and _touch_origins[event.index].distance_to(event.position) <= 16.0
		_touches.erase(event.index)
		_touch_origins.erase(event.index)
		if _touches.is_empty():
			if tapped and not _gesture_is_pinch:
				_pick_at(event.position)
			_gesture_is_pinch = false


func _handle_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	_touches[event.index] = event.position
	if _touches.size() >= 2:
		var points := _points()
		var distance := points[0].distance_to(points[1])
		var midpoint := (points[0] + points[1]) * 0.5
		if _pinch_distance > 1.0 and distance > 1.0:
			rig.zoom(_pinch_distance / distance)
		rig.pan(midpoint - _pinch_midpoint)
		_pinch_distance = distance
		_pinch_midpoint = midpoint
	else:
		rig.orbit(event.relative)


func _points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var keys := _touches.keys()
	keys.sort()
	for key in keys:
		out.append(_touches[key])
	return out


func _pick_at(position: Vector2) -> void:
	var camera := rig.camera
	if camera == null:
		return
	var from := camera.project_ray_origin(position)
	var to := from + camera.project_ray_normal(position) * 600.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = PICK_LAYER
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		nothing_picked.emit()
		return
	var collider: Object = result["collider"]
	if collider.has_meta("house_id"):
		house_picked.emit(str(collider.get_meta("house_id")))
	elif collider.has_meta("shop_id"):
		shop_picked.emit(str(collider.get_meta("shop_id")))
	elif collider.has_meta("district_id"):
		district_picked.emit(str(collider.get_meta("district_id")))
	else:
		nothing_picked.emit()


## Slides the camera over to a building, used when the UI opens a briefing.
func focus_on(house_id: String) -> void:
	var job := Jobs.get_job(house_id)
	if job.is_empty():
		return
	var spot := Jobs.world_position(house_id)
	rig.focus = Vector3(spot.x, 0, spot.y)
	rig.distance = clampf(rig.distance, 22.0, 40.0)


## Pulls the camera back over a whole quarter, for the district list.
func focus_district(district_id: String) -> void:
	var district := Jobs.get_district(district_id)
	if district.is_empty():
		return
	var origin: Vector2 = district["origin"]
	rig.focus = Vector3(origin.x, 0, origin.y)
	rig.distance = clampf(rig.distance, 58.0, rig.max_distance)
