class_name CityLife
extends Node3D
## Everything on the map that moves.
##
## The city itself is welded into three meshes and never changes, which is what
## keeps it cheap — but it also left the place looking abandoned. This is the
## other half: traffic on the roads, people on the pavements, and whatever the
## quarter overhead happens to be, which in Hanami is falling blossom and in
## Hollow is birds.
##
## Everything here is a MultiMesh. There are five hundred-odd moving things and
## they are all one of four shapes, so the whole layer costs nine draw calls and
## about half a millisecond of transform writes a frame, rather than five
## hundred nodes each with its own script.

## Road speeds, in metres a second. Cars vary a little either side.
const CAR_SPEED := 9.0
const WALK_SPEED := 1.35

## How many of each thing, per quarter.
const CARS_PER_LANE := 7
const WALKERS_PER_QUARTER := 9
const PETALS_PER_QUARTER := 320
const BIRDS_PER_QUARTER := 9

## Lanes sit either side of a road's centre line.
const LANE_OFFSET := 2.4
## Half the width of a quarter, matching CityView.
const QUARTER_HALF := 48.0
const CROSS_Z := 18.0

const CAR_COLOURS: Array[Color] = [
	Color(0.78, 0.24, 0.22),
	Color(0.24, 0.36, 0.66),
	Color(0.90, 0.88, 0.84),
	Color(0.28, 0.52, 0.40),
]
const COAT_COLOURS: Array[Color] = [
	Color(0.32, 0.36, 0.46),
	Color(0.64, 0.30, 0.32),
	Color(0.86, 0.84, 0.80),
]

## One entry a vehicle or a walker: which run it is on, how far along, how fast.
var _cars: Array[Dictionary] = []
var _walkers: Array[Dictionary] = []
var _petals: Array[Dictionary] = []
var _birds: Array[Dictionary] = []

## {from: Vector3, to: Vector3, yaw: float, length: float}
var _lanes: Array[Dictionary] = []
var _paths: Array[Dictionary] = []

var _car_pools: Array[MultiMeshInstance3D] = []
var _walker_pools: Array[MultiMeshInstance3D] = []
var _petal_pool: MultiMeshInstance3D
var _bird_pool: MultiMeshInstance3D

var _rng := RandomNumberGenerator.new()


## Lays the moving layer over a city whose quarters are already placed. Called
## once per map build, from the same stage list as the scenery.
func populate() -> void:
	_rng.seed = 20240804
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_cars.clear()
	_walkers.clear()
	_petals.clear()
	_birds.clear()
	_lanes.clear()
	_paths.clear()

	_lay_lanes()
	_lay_pavements()
	_fill_roads()
	_fill_pavements()
	_fill_sky()


func _process(delta: float) -> void:
	_drive(delta)
	_walk(delta)
	_fall(delta)
	_fly(delta)


# ----------------------------------------------------------------- the roads

## The runs traffic drives along. Quarters share a grid, and the link roads
## join them up, so a lane is the full length of the city rather than one
## quarter's worth: traffic drives out of Maple and into Riverside.
func _lay_lanes() -> void:
	var columns: Dictionary = {}
	var rows: Dictionary = {}
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for district: Dictionary in Jobs.districts():
		var origin: Vector2 = district["origin"]
		columns[origin.x] = true
		rows[origin.y] = true
		low = Vector2(minf(low.x, origin.x), minf(low.y, origin.y))
		high = Vector2(maxf(high.x, origin.x), maxf(high.y, origin.y))

	var top := low.y - QUARTER_HALF
	var bottom := high.y + QUARTER_HALF
	var left := low.x - QUARTER_HALF
	var right := high.x + QUARTER_HALF

	# The avenues, north and south.
	for x: float in columns:
		_add_lane(Vector3(x + LANE_OFFSET, 0, top), Vector3(x + LANE_OFFSET, 0, bottom))
		_add_lane(Vector3(x - LANE_OFFSET, 0, bottom), Vector3(x - LANE_OFFSET, 0, top))

	# The cross streets, east and west, two to a row of quarters.
	for z: float in rows:
		for side in [-CROSS_Z, CROSS_Z]:
			_add_lane(Vector3(left, 0, z + side + LANE_OFFSET), Vector3(right, 0, z + side + LANE_OFFSET))
			_add_lane(Vector3(right, 0, z + side - LANE_OFFSET), Vector3(left, 0, z + side - LANE_OFFSET))


func _add_lane(from: Vector3, to: Vector3) -> void:
	var delta := to - from
	_lanes.append({
		"from": from,
		"to": to,
		"length": delta.length(),
		"yaw": atan2(delta.x, delta.z),
	})


## Pavement runs, down both sides of every quarter's avenue — which is where
## the shops are, so it is where anybody would be walking.
func _lay_pavements() -> void:
	for district: Dictionary in Jobs.districts():
		var origin: Vector2 = district["origin"]
		for side in [-6.3, 6.3]:
			_paths.append({
				"from": Vector3(origin.x + side, 0, origin.y - QUARTER_HALF + 3.0),
				"to": Vector3(origin.x + side, 0, origin.y + QUARTER_HALF - 3.0),
			})


func _fill_roads() -> void:
	for colour in CAR_COLOURS:
		_car_pools.append(_pool(_car_mesh(colour), "Cars"))

	for lane in _lanes.size():
		# Evenly spaced, and every car on a lane drives at the lane's speed.
		# Letting them pick their own meant the quick ones caught the slow ones
		# and drove through them, and the avenue ended up as one long queue.
		var speed := CAR_SPEED * _rng.randf_range(0.78, 1.24)
		for i in CARS_PER_LANE:
			_cars.append({
				"lane": lane,
				"at": (float(i) + _rng.randf_range(-0.22, 0.22)) / float(CARS_PER_LANE),
				"speed": speed,
				"pool": _rng.randi() % _car_pools.size(),
			})
	_size_pools(_car_pools, _cars)


func _fill_pavements() -> void:
	for colour in COAT_COLOURS:
		_walker_pools.append(_pool(_person_mesh(colour), "Walkers"))

	for path in _paths.size():
		for i in WALKERS_PER_QUARTER:
			_walkers.append({
				"path": path,
				"at": _rng.randf(),
				"speed": WALK_SPEED * _rng.randf_range(0.7, 1.35) * (1.0 if _rng.randf() < 0.5 else -1.0),
				"phase": _rng.randf() * TAU,
				"pool": _rng.randi() % _walker_pools.size(),
			})
	_size_pools(_walker_pools, _walkers)


# ------------------------------------------------------------------- the sky

## What is in the air over a quarter, if anything. Two of them have something.
func _fill_sky() -> void:
	for district: Dictionary in Jobs.districts():
		var origin: Vector2 = district["origin"]
		match str(district.get("planting", "")):
			"cherry":
				for i in PETALS_PER_QUARTER:
					_petals.append({
						"home": origin,
						"at": Vector3(
							_rng.randf_range(-QUARTER_HALF, QUARTER_HALF),
							_rng.randf_range(0.0, 9.0),
							_rng.randf_range(-QUARTER_HALF, QUARTER_HALF)),
						"fall": _rng.randf_range(0.5, 1.15),
						"drift": _rng.randf_range(-0.7, 0.7),
						"spin": _rng.randf_range(1.2, 3.4),
						"phase": _rng.randf() * TAU,
					})
			"bare":
				for i in BIRDS_PER_QUARTER:
					_birds.append({
						"home": origin + Vector2(_rng.randf_range(-24, 24), _rng.randf_range(-24, 24)),
						"radius": _rng.randf_range(9.0, 21.0),
						"height": _rng.randf_range(11.0, 19.0),
						"rate": _rng.randf_range(0.12, 0.26) * (1.0 if _rng.randf() < 0.5 else -1.0),
						"at": _rng.randf() * TAU,
						"phase": _rng.randf() * TAU,
					})

	if not _petals.is_empty():
		_petal_pool = _pool(_petal_mesh(), "Blossom")
		_petal_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_petal_pool.multimesh.instance_count = _petals.size()
	if not _birds.is_empty():
		_bird_pool = _pool(_bird_mesh(), "Birds")
		_bird_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bird_pool.multimesh.instance_count = _birds.size()


# ---------------------------------------------------------------- the motion

func _drive(delta: float) -> void:
	var used: Array[int] = []
	used.resize(_car_pools.size())
	for car: Dictionary in _cars:
		var lane: Dictionary = _lanes[car["lane"]]
		var length: float = lane["length"]
		car["at"] = fmod(float(car["at"]) + float(car["speed"]) * delta / length, 1.0)
		var spot: Vector3 = (lane["from"] as Vector3).lerp(lane["to"], float(car["at"]))
		var pool: int = car["pool"]
		car["spot"] = spot + Vector3(0, 0.18, 0)
		_car_pools[pool].multimesh.set_instance_transform(used[pool], Transform3D(
			Basis(Vector3.UP, float(lane["yaw"])), car["spot"]))
		used[pool] += 1


func _walk(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var used: Array[int] = []
	used.resize(_walker_pools.size())
	for walker: Dictionary in _walkers:
		var path: Dictionary = _paths[walker["path"]]
		var from: Vector3 = path["from"]
		var to: Vector3 = path["to"]
		var length := from.distance_to(to)
		# Walkers turn round at the ends rather than wrapping, which from map
		# height reads as somebody going about their business.
		var travel: float = float(walker["at"]) + float(walker["speed"]) * delta / length
		if travel > 1.0:
			travel = 2.0 - travel
			walker["speed"] = -float(walker["speed"])
		elif travel < 0.0:
			travel = -travel
			walker["speed"] = -float(walker["speed"])
		walker["at"] = travel

		var facing := 0.0 if float(walker["speed"]) > 0.0 else PI
		var bob: float = absf(sin(now * 6.0 + float(walker["phase"]))) * 0.07
		var pool: int = walker["pool"]
		walker["spot"] = from.lerp(to, travel) + Vector3(0, 0.20 + bob, 0)
		_walker_pools[pool].multimesh.set_instance_transform(used[pool], Transform3D(
			Basis(Vector3.UP, facing), walker["spot"]))
		used[pool] += 1


func _fall(delta: float) -> void:
	if _petal_pool == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for i in _petals.size():
		var petal: Dictionary = _petals[i]
		var at: Vector3 = petal["at"]
		at.y -= float(petal["fall"]) * delta
		at.x += sin(now * 0.8 + float(petal["phase"])) * float(petal["drift"]) * delta
		if at.y < 0.05:
			at.y = _rng.randf_range(6.0, 8.0)
			at.x = _rng.randf_range(-QUARTER_HALF, QUARTER_HALF)
			at.z = _rng.randf_range(-QUARTER_HALF, QUARTER_HALF)
		petal["at"] = at
		var home: Vector2 = petal["home"]
		var spin := now * float(petal["spin"]) + float(petal["phase"])
		petal["spot"] = Vector3(home.x + at.x, at.y, home.y + at.z)
		_petal_pool.multimesh.set_instance_transform(i, Transform3D(
			Basis.from_euler(Vector3(spin * 0.6, spin, spin * 0.35)), petal["spot"]))


func _fly(delta: float) -> void:
	if _bird_pool == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for i in _birds.size():
		var bird: Dictionary = _birds[i]
		bird["at"] = float(bird["at"]) + float(bird["rate"]) * delta
		var angle: float = bird["at"]
		var radius: float = bird["radius"]
		var home: Vector2 = bird["home"]
		var spot := Vector3(
			home.x + cos(angle) * radius,
			float(bird["height"]) + sin(now * 0.9 + float(bird["phase"])) * 0.9,
			home.y + sin(angle) * radius)
		# Facing along the circle, banked into the turn.
		var heading := -angle + (PI * 0.5 if float(bird["rate"]) > 0.0 else -PI * 0.5)
		var basis := Basis(Vector3.UP, heading) * Basis(Vector3.FORWARD, deg_to_rad(18.0))
		bird["spot"] = spot
		_bird_pool.multimesh.set_instance_transform(i, Transform3D(basis, spot))


## Where everything is, read off the simulation rather than the MultiMeshes —
## a headless run has no renderer to store a transform in, so what is drawn
## cannot be read back there. This is what the smoke test looks at.
func positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for group: Array in [_cars, _walkers, _petals, _birds]:
		for thing: Dictionary in group:
			out.append(thing.get("spot", Vector3.ZERO))
	return out


## How many things are moving, and how many draw calls they cost.
func census() -> Dictionary:
	var pools := 0
	for child: Node in get_children():
		if child is MultiMeshInstance3D:
			pools += 1
	return {
		"cars": _cars.size(),
		"walkers": _walkers.size(),
		"petals": _petals.size(),
		"birds": _birds.size(),
		"pools": pools,
	}


# --------------------------------------------------------------- the pieces

func _pool(mesh: ArrayMesh, name: String) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	var instance := MultiMeshInstance3D.new()
	instance.name = name
	instance.multimesh = multimesh
	add_child(instance)
	return instance


## Sizes each pool to how many of its things were actually handed out.
func _size_pools(pools: Array[MultiMeshInstance3D], things: Array[Dictionary]) -> void:
	var counts: Array[int] = []
	counts.resize(pools.size())
	for thing: Dictionary in things:
		counts[thing["pool"]] += 1
	for i in pools.size():
		pools[i].multimesh.instance_count = counts[i]


## Welds a list of coloured boxes into one mesh, the way the scenery is built —
## colour in the vertices, so a pool is one material and one call. Written a
## vertex at a time rather than with append_from(), which carries the source
## mesh's attributes over and ignores the colour entirely.
static func _weld(parts: Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: Array in parts:
		var box := BoxMesh.new()
		box.size = part[1]
		var basis: Basis = part[3] if part.size() > 3 else Basis.IDENTITY
		var transform := Transform3D(basis, part[2])
		var normal_basis := basis.inverse().transposed()

		var arrays := box.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index: int in (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array):
			tool.set_color(part[0])
			tool.set_normal((normal_basis * normals[index]).normalized())
			tool.add_vertex(transform * vertices[index])

	var mesh := ArrayMesh.new()
	mesh = tool.commit(mesh)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.7
	mesh.surface_set_material(0, material)
	return mesh


static func _car_mesh(colour: Color) -> ArrayMesh:
	var glass := Color(0.30, 0.38, 0.46)
	var tyre := Color(0.10, 0.10, 0.12)
	var lamp := Color(0.98, 0.94, 0.72)
	return _weld([
		[colour, Vector3(1.8, 0.62, 4.0), Vector3(0, 0.44, 0)],
		[colour.darkened(0.12), Vector3(1.62, 0.58, 2.0), Vector3(0, 0.98, -0.2)],
		[glass, Vector3(1.66, 0.40, 1.5), Vector3(0, 1.02, -0.25)],
		[lamp, Vector3(1.4, 0.16, 0.10), Vector3(0, 0.50, 2.02)],
		[tyre, Vector3(0.34, 0.56, 0.56), Vector3(-0.86, 0.30, -1.35)],
		[tyre, Vector3(0.34, 0.56, 0.56), Vector3(0.86, 0.30, -1.35)],
		[tyre, Vector3(0.34, 0.56, 0.56), Vector3(-0.86, 0.30, 1.35)],
		[tyre, Vector3(0.34, 0.56, 0.56), Vector3(0.86, 0.30, 1.35)],
	])


static func _person_mesh(coat: Color) -> ArrayMesh:
	var skin := Color(0.84, 0.68, 0.55)
	var legs := Color(0.24, 0.26, 0.32)
	return _weld([
		[legs, Vector3(0.34, 0.66, 0.24), Vector3(0, 0.33, 0)],
		[coat, Vector3(0.44, 0.62, 0.30), Vector3(0, 0.97, 0)],
		[skin, Vector3(0.26, 0.26, 0.26), Vector3(0, 1.41, 0)],
	])


static func _petal_mesh() -> ArrayMesh:
	# Larger than a real petal by some way. At map height anything honestly
	# sized is a single pixel, and a blossom you cannot see is not weather.
	return _weld([[Color(0.96, 0.58, 0.72), Vector3(0.42, 0.03, 0.28), Vector3.ZERO]])


static func _bird_mesh() -> ArrayMesh:
	var feather := Color(0.10, 0.10, 0.14)
	return _weld([
		[feather, Vector3(0.22, 0.20, 0.70), Vector3.ZERO],
		[feather, Vector3(0.90, 0.05, 0.30), Vector3(-0.52, 0.08, -0.05),
			Basis(Vector3.FORWARD, deg_to_rad(22.0))],
		[feather, Vector3(0.90, 0.05, 0.30), Vector3(0.52, 0.08, -0.05),
			Basis(Vector3.FORWARD, deg_to_rad(-22.0))],
	])
