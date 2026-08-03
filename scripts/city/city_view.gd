class_name CityView
extends Node3D
## The city map: a procedurally built neighbourhood of client houses and the
## shops that supply them.
##
## Everything is boxes, cylinders and prisms assembled at runtime, matching the
## way furniture is built in the designer. Tapping a building emits a signal;
## the city UI turns that into a briefing or a shop window.

signal house_picked(house_id: String)
signal shop_picked(shop_id: String)
signal nothing_picked()

const PICK_LAYER := 4
const GROUND := Color(0.33, 0.47, 0.27)
const LAWN := Color(0.40, 0.55, 0.32)
const ROAD := Color(0.19, 0.20, 0.23)
const PAVEMENT := Color(0.55, 0.55, 0.53)

## Roads. The avenue runs north to south, two cross streets east to west.
const AVENUE_HALF := 5.0
const CROSS_HALF := 4.5
const CROSS_Z := 18.0
const CITY_HALF := 48.0

const MARKER_AVAILABLE := Color(0.35, 0.80, 1.00)
const MARKER_DONE := Color(0.42, 0.83, 0.52)
const MARKER_LOCKED := Color(0.55, 0.57, 0.62)
const MARKER_RESUME := Color(0.98, 0.78, 0.32)

var rig: CameraRig

var _markers: Dictionary = {}
var _pickables: Node3D
var _scenery: Node3D
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

	_build_ground()
	_build_roads()
	_build_shops()
	_build_houses()
	_build_greenery()

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


func _flat(color: Color, rough: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _box(parent: Node3D, size: Vector3, position: Vector3, material: Material, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = position
	mi.material_override = material
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cylinder(parent: Node3D, radius: float, height: float, position: Vector3, material: Material, segments := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mi.mesh = mesh
	mi.position = position
	mi.material_override = material
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, radius: float, position: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	mi.mesh = mesh
	mi.position = position
	mi.material_override = material
	parent.add_child(mi)
	return mi


# ------------------------------------------------------------------- ground

func _build_ground() -> void:
	_box(_scenery, Vector3(CITY_HALF * 2.0, 1.0, CITY_HALF * 2.0), Vector3(0, -0.5, 0), _flat(GROUND), false)


func _build_roads() -> void:
	var road_material := _flat(ROAD, 0.95)
	var pavement_material := _flat(PAVEMENT, 0.95)
	var line_material := _flat(Color(0.92, 0.90, 0.72), 0.9)

	# Pavements sit a touch proud of the asphalt.
	_box(_scenery, Vector3((AVENUE_HALF + 1.6) * 2.0, 0.12, CITY_HALF * 2.0), Vector3(0, 0.03, 0), pavement_material, false)
	_box(_scenery, Vector3(AVENUE_HALF * 2.0, 0.14, CITY_HALF * 2.0), Vector3(0, 0.05, 0), road_material, false)

	for z in [-CROSS_Z, CROSS_Z]:
		_box(_scenery, Vector3(CITY_HALF * 2.0, 0.12, (CROSS_HALF + 1.6) * 2.0), Vector3(0, 0.03, z), pavement_material, false)
		_box(_scenery, Vector3(CITY_HALF * 2.0, 0.14, CROSS_HALF * 2.0), Vector3(0, 0.05, z), road_material, false)

	# Centre lines, skipping the junctions.
	var z := -CITY_HALF + 2.0
	while z < CITY_HALF:
		if absf(z - CROSS_Z) > CROSS_HALF + 1.0 and absf(z + CROSS_Z) > CROSS_HALF + 1.0:
			_box(_scenery, Vector3(0.28, 0.02, 2.2), Vector3(0, 0.13, z), line_material, false)
		z += 5.0
	for cross_z in [-CROSS_Z, CROSS_Z]:
		var x := -CITY_HALF + 2.0
		while x < CITY_HALF:
			if absf(x) > AVENUE_HALF + 1.0:
				_box(_scenery, Vector3(2.2, 0.02, 0.28), Vector3(x, 0.13, cross_z), line_material, false)
			x += 5.0


# -------------------------------------------------------------------- shops

func _build_shops() -> void:
	# Four shops down each side of the avenue, between the cross streets.
	var slots := [
		Vector2(-9.5, -12.0), Vector2(-9.5, -4.0), Vector2(-9.5, 4.0), Vector2(-9.5, 12.0),
		Vector2(9.5, -12.0), Vector2(9.5, -4.0), Vector2(9.5, 4.0), Vector2(9.5, 12.0),
	]
	var shops := Catalog.SHOPS
	for i in mini(shops.size(), slots.size()):
		_build_shop(shops[i], slots[i], 0.0 if i % 2 == 0 else 3.2)


func _build_shop(shop: Dictionary, slot: Vector2, stagger: float) -> void:
	var root := Node3D.new()
	root.name = "Shop_%s" % shop["id"]
	root.position = Vector3(slot.x, 0, slot.y)
	# Shopfronts face the avenue.
	root.rotation.y = deg_to_rad(90.0 if slot.x < 0.0 else -90.0)
	_pickables.add_child(root)

	var accent: Color = shop["color"]
	var wall := _flat(Color(0.88, 0.87, 0.85), 0.92)
	var accent_material := _flat(accent, 0.7)
	var dark := _flat(Color(0.22, 0.23, 0.27), 0.8)
	var glass := _flat(Color(0.55, 0.72, 0.82, 0.55), 0.15)

	var width := 6.6
	var depth := 5.4
	var height := 4.6

	_box(root, Vector3(width, height, depth), Vector3(0, height * 0.5, -depth * 0.5), wall)
	# Parapet band in the shop's colour.
	_box(root, Vector3(width + 0.3, 0.8, depth + 0.3), Vector3(0, height + 0.2, -depth * 0.5), accent_material)
	# Shopfront glazing and door.
	_box(root, Vector3(width - 1.2, 2.4, 0.12), Vector3(0, 1.5, 0.02), glass)
	_box(root, Vector3(1.0, 2.2, 0.16), Vector3(width * 0.5 - 1.1, 1.1, 0.04), dark)
	# Awning.
	_box(root, Vector3(width - 0.4, 0.16, 1.5), Vector3(0, 3.15, 0.7), accent_material)
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(0.1, 0.9, 0.1), Vector3(sx * (width * 0.5 - 0.5), 3.6, 1.3), dark)
	# Two planters by the door.
	for sx in [-1.0, 1.0]:
		var planter_x: float = sx * (width * 0.5 - 0.45)
		_box(root, Vector3(0.7, 0.55, 0.7), Vector3(planter_x, 0.28, 0.75), _flat(Color(0.55, 0.52, 0.48)))
		_sphere(root, 0.42, Vector3(planter_x, 0.95, 0.75), _flat(Color(0.30, 0.52, 0.28)))

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
	root.add_child(sign)

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
	root.add_child(body)


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

	var root := Node3D.new()
	root.name = "House_%s" % job["id"]
	root.position = Vector3(map["pos"].x, 0, map["pos"].y)
	root.rotation.y = deg_to_rad(float(map.get("rot", 0.0)))
	_pickables.add_child(root)

	var body_material := _flat(style["body"], 0.9)
	var roof_material := _flat(style["roof"], 0.85)
	var trim := _flat(Color(0.95, 0.95, 0.93), 0.8)
	var glass := _flat(Color(0.52, 0.70, 0.82, 0.75), 0.12)
	var door_material := _flat(style["roof"].darkened(0.25), 0.7)

	# Plot and path.
	_box(root, Vector3(size.x + 3.6, 0.10, size.z + 4.0), Vector3(0, 0.02, 0), _flat(LAWN), false)
	_box(root, Vector3(1.4, 0.06, (size.z + 4.0) * 0.5), Vector3(0, 0.08, size.z * 0.5 + 1.0), _flat(PAVEMENT), false)

	# Walls, floor band and roof.
	_box(root, Vector3(size.x, size.y, size.z), Vector3(0, size.y * 0.5 + 0.1, 0), body_material)
	_box(root, Vector3(size.x + 0.3, 0.3, size.z + 0.3), Vector3(0, 0.25, 0), trim)

	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(size.x + 0.7, 1.9, size.z + 0.7)
	roof.mesh = prism
	roof.position = Vector3(0, size.y + 1.05, 0)
	roof.material_override = roof_material
	root.add_child(roof)

	# Chimney.
	_box(root, Vector3(0.7, 1.5, 0.7), Vector3(size.x * 0.28, size.y + 1.4, -size.z * 0.22), _flat(style["roof"].darkened(0.35)))

	# Front door and windows.
	var front := size.z * 0.5 + 0.06
	_box(root, Vector3(1.1, 2.1, 0.12), Vector3(0, 1.15, front), door_material)
	_cylinder(root, 0.06, 0.1, Vector3(0.38, 1.15, front + 0.08), _flat(Color(0.85, 0.72, 0.35), 0.3, 0.8), 8)
	for sx in [-1.0, 1.0]:
		var wx: float = sx * size.x * 0.28
		_box(root, Vector3(1.3, 1.2, 0.10), Vector3(wx, 1.9, front), glass)
		_box(root, Vector3(1.5, 1.4, 0.06), Vector3(wx, 1.9, front - 0.02), trim)
		_box(root, Vector3(1.3, 1.2, 0.10), Vector3(wx, 1.9, front), glass)
	if size.y > 4.0:
		for sx in [-1.0, 1.0]:
			_box(root, Vector3(1.2, 1.1, 0.10), Vector3(sx * size.x * 0.28, 4.2, front), glass)

	# A hedge and a bin, so no two plots look identical.
	var hedge_side: float = -1.0 if int(job["id"].hash()) % 2 == 0 else 1.0
	_box(root, Vector3(0.6, 0.9, size.z + 2.0), Vector3(hedge_side * (size.x * 0.5 + 1.4), 0.5, 0), _flat(Color(0.26, 0.46, 0.26)))
	_cylinder(root, 0.34, 0.9, Vector3(-hedge_side * (size.x * 0.5 + 1.0), 0.5, size.z * 0.4), _flat(Color(0.30, 0.34, 0.38)), 10)

	# Name plate at the kerb.
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
	root.add_child(plate)

	_build_marker(root, job, size)

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
	root.add_child(pick)


## The floating pin that tells the player what a house wants from them.
func _build_marker(parent: Node3D, job: Dictionary, size: Vector3) -> void:
	var marker := Node3D.new()
	marker.name = "Marker"
	var base_y: float = size.y + 4.6
	marker.position = Vector3(0, base_y, 0)
	marker.set_meta("base_y", base_y)
	marker.set_meta("phase", float(absi(int(job["id"].hash())) % 100) * 0.06)
	parent.add_child(marker)

	var material := _flat(MARKER_AVAILABLE, 0.35)
	material.emission_enabled = true
	material.emission = MARKER_AVAILABLE
	material.emission_energy_multiplier = 0.75

	# A downward map pin: cone under a ball, sized to read from map height.
	var cone := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.30
	mesh.bottom_radius = 0.0
	mesh.height = 2.30
	mesh.radial_segments = 4
	cone.mesh = mesh
	cone.position = Vector3(0, 1.15, 0)
	cone.material_override = material
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(cone)

	var top := _sphere(marker, 0.95, Vector3(0, 2.75, 0), material)
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	marker.set_meta("material", material)
	_markers[job["id"]] = marker


## Recolours every pin from the player's current progress.
func refresh_markers() -> void:
	for house_id: String in _markers:
		var marker: Node3D = _markers[house_id]
		var material: StandardMaterial3D = marker.get_meta("material")
		var job := Jobs.get_job(house_id)
		var color := MARKER_AVAILABLE
		if Game.is_job_done(house_id):
			color = MARKER_DONE
		elif Game.level < int(job.get("level", 1)):
			color = MARKER_LOCKED
		elif not Game.layout_for(house_id).is_empty():
			color = MARKER_RESUME
		material.albedo_color = color
		material.emission = color
		marker.visible = true


# ---------------------------------------------------------------- greenery

func _build_greenery() -> void:
	var trunk := _flat(Color(0.36, 0.27, 0.19), 0.95)
	var leaves := [
		_flat(Color(0.26, 0.48, 0.26), 0.9),
		_flat(Color(0.32, 0.55, 0.30), 0.9),
		_flat(Color(0.22, 0.42, 0.24), 0.9),
	]
	var lamp_post := _flat(Color(0.24, 0.26, 0.30), 0.5, 0.4)
	var lamp_glow := _flat(Color(0.98, 0.92, 0.70), 0.3)

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
		_cylinder(_scenery, 0.22 * scale_factor, 2.2 * scale_factor, Vector3(spot.x, 1.1 * scale_factor, spot.y), trunk, 8)
		var canopy: Material = leaves[i % leaves.size()]
		_sphere(_scenery, 1.35 * scale_factor, Vector3(spot.x, 3.1 * scale_factor, spot.y), canopy)
		_sphere(_scenery, 0.95 * scale_factor, Vector3(spot.x + 0.7, 2.5 * scale_factor, spot.y - 0.4), canopy)
		_sphere(_scenery, 0.85 * scale_factor, Vector3(spot.x - 0.6, 2.6 * scale_factor, spot.y + 0.5), canopy)

	for z in [-22.0, -6.0, 6.0, 22.0]:
		for sx in [-1.0, 1.0]:
			var x: float = sx * (AVENUE_HALF + 1.0)
			_cylinder(_scenery, 0.09, 4.4, Vector3(x, 2.2, z), lamp_post, 8)
			_box(_scenery, Vector3(0.9, 0.14, 0.3), Vector3(x - sx * 0.4, 4.45, z), lamp_post)
			_box(_scenery, Vector3(0.5, 0.18, 0.26), Vector3(x - sx * 0.72, 4.32, z), lamp_glow)

	# A couple of parked cars to give the street some life.
	var car_colors := [Color(0.78, 0.24, 0.22), Color(0.24, 0.36, 0.66), Color(0.90, 0.88, 0.84)]
	var car_spots := [Vector2(-3.4, -22.0), Vector2(3.4, 8.0), Vector2(-3.4, 16.0)]
	for i in car_spots.size():
		_build_car(car_spots[i], car_colors[i], 0.0 if i % 2 == 0 else 180.0)


func _build_car(spot: Vector2, color: Color, yaw: float) -> void:
	var car := Node3D.new()
	car.position = Vector3(spot.x, 0, spot.y)
	car.rotation.y = deg_to_rad(yaw)
	_scenery.add_child(car)
	var paint := _flat(color, 0.35, 0.25)
	var window := _flat(Color(0.28, 0.34, 0.40, 0.85), 0.1)
	var tyre := _flat(Color(0.11, 0.11, 0.13), 0.95)
	_box(car, Vector3(1.8, 0.65, 4.0), Vector3(0, 0.62, 0), paint)
	_box(car, Vector3(1.62, 0.62, 2.0), Vector3(0, 1.22, -0.2), window)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_cylinder(car, 0.34, 0.24, Vector3(sx * 0.85, 0.34, sz * 1.35), tyre, 10).rotation = Vector3(0, 0, deg_to_rad(90))


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
