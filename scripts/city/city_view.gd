class_name CityView
extends Node3D
## The city map: a procedurally built neighbourhood of client houses and the
## shops that supply them.
##
## Everything is boxes, cylinders and prisms, matching the way furniture is
## built in the designer — but here the geometry is welded into a SceneryBatch
## and drawn in a handful of calls. Only the things that move or respond stay
## as nodes: the job pins, the name plates and one pick volume per building.

signal house_picked(house_id: String)
signal shop_picked(shop_id: String)
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
const CITY_HALF := 48.0

const MARKER_AVAILABLE := Color(0.35, 0.80, 1.00)
const MARKER_DONE := Color(0.42, 0.83, 0.52)
const MARKER_LOCKED := Color(0.55, 0.57, 0.62)
const MARKER_RESUME := Color(0.98, 0.78, 0.32)

## Shop signs only appear once the camera comes down for a closer look, so the
## map is not a wall of text when zoomed out.
const SHOP_LABEL_DISTANCE := 46.0

var rig: CameraRig

var _markers: Dictionary = {}
var _shop_labels: Array[Label3D] = []
var _pickables: Node3D
var _scenery: Node3D
var _batch: SceneryBatch
var _touches: Dictionary = {}
var _touch_origins: Dictionary = {}
var _pinch_distance := 0.0
var _pinch_midpoint := Vector2.ZERO
var _gesture_is_pinch := false
## Set by the owner so gestures that start on a panel are ignored.
var ui_probe: Callable = Callable()


func _ready() -> void:
	_build_environment()

	_scenery = Node3D.new()
	_scenery.name = "Scenery"
	add_child(_scenery)

	_pickables = Node3D.new()
	_pickables.name = "Buildings"
	add_child(_pickables)

	_batch = SceneryBatch.new()
	_build_ground()
	_build_roads()
	_build_shops()
	_build_houses()
	_build_greenery()
	_batch.commit(_scenery)
	_batch = null

	rig = CameraRig.new()
	rig.name = "CameraRig"
	rig.yaw = -28.0
	rig.pitch = -42.0
	rig.distance = 58.0
	rig.pan_limit = Vector2(34, 34)
	rig.min_distance = 18.0
	rig.max_distance = 95.0
	add_child(rig)
	rig.snap_to_target()

	refresh_markers()


func _process(delta: float) -> void:
	# Job markers bob gently so they read as interactive.
	var t := Time.get_ticks_msec() / 1000.0
	for house_id: String in _markers:
		var marker: Node3D = _markers[house_id]
		marker.position.y = marker.get_meta("base_y") + sin(t * 2.0 + marker.get_meta("phase")) * 0.28
		marker.rotate_y(delta * 0.9)

	var show_signs: bool = rig != null and rig.distance < SHOP_LABEL_DISTANCE
	for label in _shop_labels:
		label.visible = show_signs


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
	env.fog_density = 0.0008
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

func _build_ground() -> void:
	_batch.box(GROUND, Vector3(CITY_HALF * 2.0, 1.0, CITY_HALF * 2.0), Vector3(0, -0.5, 0))


func _build_roads() -> void:
	# Pavements sit a touch proud of the asphalt.
	_batch.box(PAVEMENT, Vector3((AVENUE_HALF + 1.6) * 2.0, 0.12, CITY_HALF * 2.0), Vector3(0, 0.03, 0))
	_batch.box(ROAD, Vector3(AVENUE_HALF * 2.0, 0.14, CITY_HALF * 2.0), Vector3(0, 0.05, 0))

	for z in [-CROSS_Z, CROSS_Z]:
		_batch.box(PAVEMENT, Vector3(CITY_HALF * 2.0, 0.12, (CROSS_HALF + 1.6) * 2.0), Vector3(0, 0.03, z))
		_batch.box(ROAD, Vector3(CITY_HALF * 2.0, 0.14, CROSS_HALF * 2.0), Vector3(0, 0.05, z))

	# Centre lines, skipping the junctions.
	var z := -CITY_HALF + 2.0
	while z < CITY_HALF:
		if absf(z - CROSS_Z) > CROSS_HALF + 1.0 and absf(z + CROSS_Z) > CROSS_HALF + 1.0:
			_batch.box(LINE, Vector3(0.28, 0.02, 2.2), Vector3(0, 0.13, z))
		z += 5.0
	for cross_z in [-CROSS_Z, CROSS_Z]:
		var x := -CITY_HALF + 2.0
		while x < CITY_HALF:
			if absf(x) > AVENUE_HALF + 1.0:
				_batch.box(LINE, Vector3(2.2, 0.02, 0.28), Vector3(x, 0.13, cross_z))
			x += 5.0


# -------------------------------------------------------------------- shops

func _build_shops() -> void:
	# Five shops down each side of the avenue, between the cross streets.
	var slots := [
		Vector2(-9.5, -14.0), Vector2(-9.5, -7.0), Vector2(-9.5, 0.0),
		Vector2(-9.5, 7.0), Vector2(-9.5, 14.0),
		Vector2(9.5, -14.0), Vector2(9.5, -7.0), Vector2(9.5, 0.0),
		Vector2(9.5, 7.0), Vector2(9.5, 14.0),
	]
	var shops := Catalog.SHOPS
	for i in mini(shops.size(), slots.size()):
		_build_shop(shops[i], slots[i], 0.0 if i % 2 == 0 else 3.2)


func _build_shop(shop: Dictionary, slot: Vector2, stagger: float) -> void:
	# Shopfronts face the avenue.
	var yaw: float = deg_to_rad(90.0 if slot.x < 0.0 else -90.0)
	var world := Transform3D(Basis(Vector3.UP, yaw), Vector3(slot.x, 0, slot.y))

	var accent: Color = shop["color"]
	var wall := Color(0.88, 0.87, 0.85)
	var dark := Color(0.22, 0.23, 0.27)
	var glass := Color(0.55, 0.72, 0.82, 0.55)

	var width := 6.6
	var depth := 5.4
	var height := 4.6

	_batch.box(wall, Vector3(width, height, depth), world * Vector3(0, height * 0.5, -depth * 0.5), SceneryBatch.Layer.OPAQUE, world.basis)
	# Parapet band in the shop's colour, which doubles as its roof from above.
	_batch.box(accent, Vector3(width + 0.3, 0.8, depth + 0.3), world * Vector3(0, height + 0.2, -depth * 0.5), SceneryBatch.Layer.OPAQUE, world.basis)
	# Shopfront glazing and door.
	_batch.box(glass, Vector3(width - 1.2, 2.4, 0.12), world * Vector3(0, 1.5, 0.02), SceneryBatch.Layer.GLASS, world.basis)
	_batch.box(dark, Vector3(1.0, 2.2, 0.16), world * Vector3(width * 0.5 - 1.1, 1.1, 0.04), SceneryBatch.Layer.OPAQUE, world.basis)
	# Awning.
	_batch.box(accent, Vector3(width - 0.4, 0.16, 1.5), world * Vector3(0, 3.15, 0.7), SceneryBatch.Layer.OPAQUE, world.basis)
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
	sign.modulate = accent.lightened(0.5)
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


# ------------------------------------------------------------------- houses

func _build_houses() -> void:
	var houses := Jobs.all()
	for i in houses.size():
		# Neighbours get their name plates at different heights so the labels
		# do not stack on top of each other from map height.
		_build_house(houses[i], 0.0 if i % 2 == 0 else 2.6)


func _build_house(job: Dictionary, stagger: float) -> void:
	var map: Dictionary = job["map"]
	var style: Dictionary = job["style"]
	var size: Vector3 = style["size"]
	var world := Transform3D(
		Basis(Vector3.UP, deg_to_rad(float(map.get("rot", 0.0)))),
		Vector3(map["pos"].x, 0, map["pos"].y)
	)

	var body_color: Color = style["body"]
	var roof_color: Color = style["roof"]
	var trim := Color(0.95, 0.95, 0.93)
	var glass := Color(0.52, 0.70, 0.82, 0.75)
	var door_color: Color = roof_color.darkened(0.25)
	var b := world.basis

	# Plot and path.
	_batch.box(LAWN, Vector3(size.x + 3.6, 0.10, size.z + 4.0), world * Vector3(0, 0.02, 0), SceneryBatch.Layer.OPAQUE, b)
	_batch.box(PAVEMENT, Vector3(1.4, 0.06, (size.z + 4.0) * 0.5), world * Vector3(0, 0.08, size.z * 0.5 + 1.0), SceneryBatch.Layer.OPAQUE, b)

	# Walls, floor band and roof.
	_batch.box(body_color, size, world * Vector3(0, size.y * 0.5 + 0.1, 0), SceneryBatch.Layer.OPAQUE, b)
	_batch.box(trim, Vector3(size.x + 0.3, 0.3, size.z + 0.3), world * Vector3(0, 0.25, 0), SceneryBatch.Layer.OPAQUE, b)
	_batch.prism(roof_color, Vector3(size.x + 0.7, 1.9, size.z + 0.7), world * Vector3(0, size.y + 1.05, 0), SceneryBatch.Layer.OPAQUE, b)
	_batch.box(roof_color.darkened(0.35), Vector3(0.7, 1.5, 0.7), world * Vector3(size.x * 0.28, size.y + 1.4, -size.z * 0.22), SceneryBatch.Layer.OPAQUE, b)

	# Front door and windows.
	var front := size.z * 0.5 + 0.06
	_batch.box(door_color, Vector3(1.1, 2.1, 0.12), world * Vector3(0, 1.15, front), SceneryBatch.Layer.OPAQUE, b)
	_batch.cylinder(Color(0.85, 0.72, 0.35), 0.06, 0.1, world * Vector3(0.38, 1.15, front + 0.08), SceneryBatch.Layer.SHINY, 8, b)
	for sx in [-1.0, 1.0]:
		var wx: float = sx * size.x * 0.28
		_batch.box(trim, Vector3(1.5, 1.4, 0.06), world * Vector3(wx, 1.9, front - 0.02), SceneryBatch.Layer.OPAQUE, b)
		_batch.box(glass, Vector3(1.3, 1.2, 0.10), world * Vector3(wx, 1.9, front), SceneryBatch.Layer.GLASS, b)
	if size.y > 4.0:
		for sx in [-1.0, 1.0]:
			_batch.box(glass, Vector3(1.2, 1.1, 0.10), world * Vector3(sx * size.x * 0.28, 4.2, front), SceneryBatch.Layer.GLASS, b)

	# A hedge and a bin, so no two plots look identical.
	var hedge_side: float = -1.0 if int(str(job["id"]).hash()) % 2 == 0 else 1.0
	_batch.box(Color(0.26, 0.46, 0.26), Vector3(0.6, 0.9, size.z + 2.0), world * Vector3(hedge_side * (size.x * 0.5 + 1.4), 0.5, 0), SceneryBatch.Layer.OPAQUE, b)
	_batch.cylinder(Color(0.30, 0.34, 0.38), 0.34, 0.9, world * Vector3(-hedge_side * (size.x * 0.5 + 1.0), 0.5, size.z * 0.4), SceneryBatch.Layer.OPAQUE, 10, b)

	var holder := Node3D.new()
	holder.name = "House_%s" % job["id"]
	holder.transform = world
	_pickables.add_child(holder)

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

	_build_marker(holder, job, size)

	var pick := StaticBody3D.new()
	pick.collision_layer = PICK_LAYER
	pick.collision_mask = 0
	pick.set_meta("house_id", job["id"])
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x + 3.0, size.y + 4.0, size.z + 3.4)
	shape.shape = box
	shape.position = Vector3(0, (size.y + 4.0) * 0.5, 0)
	pick.add_child(shape)
	holder.add_child(pick)


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


# ---------------------------------------------------------------- greenery

func _build_greenery() -> void:
	var trunk := Color(0.36, 0.27, 0.19)
	var leaves := [
		Color(0.26, 0.48, 0.26),
		Color(0.32, 0.55, 0.30),
		Color(0.22, 0.42, 0.24),
	]
	var post := Color(0.24, 0.26, 0.30)
	var glow := Color(0.98, 0.92, 0.70)

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
		_batch.cylinder(trunk, 0.22 * scale_factor, 2.2 * scale_factor, Vector3(spot.x, 1.1 * scale_factor, spot.y), SceneryBatch.Layer.OPAQUE, 8)
		var canopy: Color = leaves[i % leaves.size()]
		_batch.sphere(canopy, 1.35 * scale_factor, Vector3(spot.x, 3.1 * scale_factor, spot.y))
		_batch.sphere(canopy, 0.95 * scale_factor, Vector3(spot.x + 0.7, 2.5 * scale_factor, spot.y - 0.4))
		_batch.sphere(canopy, 0.85 * scale_factor, Vector3(spot.x - 0.6, 2.6 * scale_factor, spot.y + 0.5))

	for z in [-22.0, -6.0, 6.0, 22.0]:
		for sx in [-1.0, 1.0]:
			var x: float = sx * (AVENUE_HALF + 1.0)
			_batch.cylinder(post, 0.09, 4.4, Vector3(x, 2.2, z), SceneryBatch.Layer.SHINY, 8)
			_batch.box(post, Vector3(0.9, 0.14, 0.3), Vector3(x - sx * 0.4, 4.45, z), SceneryBatch.Layer.SHINY)
			_batch.box(glow, Vector3(0.5, 0.18, 0.26), Vector3(x - sx * 0.72, 4.32, z))

	# A couple of parked cars to give the street some life.
	var car_colors := [Color(0.78, 0.24, 0.22), Color(0.24, 0.36, 0.66), Color(0.90, 0.88, 0.84)]
	var car_spots := [Vector2(-3.4, -22.0), Vector2(3.4, 8.0), Vector2(-3.4, 16.0)]
	for i in car_spots.size():
		_build_car(car_spots[i], car_colors[i], 0.0 if i % 2 == 0 else 180.0)


func _build_car(spot: Vector2, color: Color, yaw: float) -> void:
	var world := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), Vector3(spot.x, 0, spot.y))
	var b := world.basis
	var window := Color(0.28, 0.34, 0.40, 0.85)
	var tyre := Color(0.11, 0.11, 0.13)
	_batch.box(color, Vector3(1.8, 0.65, 4.0), world * Vector3(0, 0.62, 0), SceneryBatch.Layer.SHINY, b)
	_batch.box(window, Vector3(1.62, 0.62, 2.0), world * Vector3(0, 1.22, -0.2), SceneryBatch.Layer.GLASS, b)
	var wheel_basis := b * Basis(Vector3.FORWARD, deg_to_rad(90))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_batch.cylinder(tyre, 0.34, 0.24, world * Vector3(sx * 0.85, 0.34, sz * 1.35), SceneryBatch.Layer.OPAQUE, 10, wheel_basis)


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
	var to := from + camera.project_ray_normal(position) * 400.0
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
	else:
		nothing_picked.emit()


## Slides the camera over to a building, used when the UI opens a briefing.
func focus_on(house_id: String) -> void:
	var job := Jobs.get_job(house_id)
	if job.is_empty():
		return
	var spot: Vector2 = job["map"]["pos"]
	rig.focus = Vector3(spot.x, 0, spot.y)
	rig.distance = clampf(rig.distance, 22.0, 40.0)
