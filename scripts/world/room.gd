class_name Room
extends Node3D
## Procedural room shell: floors, walls, skirting, doorways and a floor grid.
##
## A room is a *plan*: one or more axis-aligned rectangles on the floor plane.
## Most jobs are a single rectangle, which is what configure() builds. The
## whole-floor jobs pass a list of rooms to configure_plan() instead, and the
## shell works out for itself which wall runs along the outside of the flat and
## which one divides two rooms — the dividers get a doorway knocked through.
##
## Whatever the plan, it is recentred on the origin, so the shell always spans
## [-width/2, width/2] on X and [-depth/2, depth/2] on Z and everything that
## frames or clamps against the room can keep treating it as centred.

const WALL_THICKNESS := 0.10
const GRID_STEP := 0.5
const DOOR_WIDTH := 1.10
const DOOR_HEIGHT := 2.05
## Rectangles closer than this are treated as sharing an edge exactly.
const EPS := 0.01

var width: float = 6.0
var depth: float = 5.0
var height: float = 2.6

var floor_color: Color = Color(0.72, 0.62, 0.50)
var wall_color: Color = Color(0.90, 0.89, 0.86)
var walls_visible: bool = true
var auto_hide_walls: bool = true

## The plan: [{"id": String, "name": String, "rect": Rect2}], recentred.
var plan: Array[Dictionary] = []

var _walls: Array[MeshInstance3D] = []
## Each wall's footprint on the floor plane, as [from, to] plus its outward
## normal. Used to work out which walls stand between the camera and the room
## the player is looking at.
var _wall_spans: Array[Dictionary] = []
var _floor_material: StandardMaterial3D
var _skirting_material: StandardMaterial3D
## Walls running along Z are shaded slightly darker than the ones along X, so
## the corners of a room stay readable instead of merging into one surface.
var _wall_materials: Array[StandardMaterial3D] = []
const _WALL_SHADES: Array[float] = [1.0, 0.86]


func _ready() -> void:
	# Near-white greyscale textures carry the grain; albedo_color carries the
	# colour the player chose.
	_floor_material = StandardMaterial3D.new()
	_floor_material.albedo_color = floor_color
	_floor_material.albedo_texture = ProcTextures.floor_planks()
	_floor_material.roughness = 0.78

	_wall_materials.clear()
	for shade in _WALL_SHADES:
		var mat := StandardMaterial3D.new()
		mat.roughness = 0.95
		mat.albedo_texture = ProcTextures.wall_plaster()
		mat.uv1_scale = Vector3(3.0, 2.0, 1.0)
		_wall_materials.append(mat)
	set_wall_color(wall_color)

	_skirting_material = StandardMaterial3D.new()
	_skirting_material.albedo_color = Color(0.96, 0.96, 0.95)
	_skirting_material.roughness = 0.7

	if plan.is_empty():
		configure(width, depth, height)
	else:
		rebuild()


## One rectangle, centred. The shape every job had before floor plans existed.
func configure(w: float, d: float, h: float) -> void:
	configure_plan([{
		"id": "room", "name": "",
		"w": clampf(w, 2.0, 20.0), "d": clampf(d, 2.0, 20.0), "x": 0.0, "z": 0.0,
	}], h)


## A list of rooms, each {id, name, w, d, x, z} with x/z the rectangle's centre.
## Rectangles are expected to butt up against each other; wherever two of them
## share an edge the shell puts a doorway through it.
func configure_plan(rooms: Array, h: float) -> void:
	height = clampf(h, 2.0, 4.0)
	plan.clear()
	if rooms.is_empty():
		rooms = [{"id": "room", "name": "", "w": 6.0, "d": 5.0, "x": 0.0, "z": 0.0}]

	var union := Rect2()
	for i in rooms.size():
		var spec: Dictionary = rooms[i]
		var w: float = clampf(float(spec.get("w", 4.0)), 1.5, 20.0)
		var d: float = clampf(float(spec.get("d", 4.0)), 1.5, 20.0)
		var x: float = float(spec.get("x", 0.0))
		var z: float = float(spec.get("z", 0.0))
		var rect := Rect2(x - w * 0.5, z - d * 0.5, w, d)
		union = rect if i == 0 else union.merge(rect)
		plan.append({
			"id": str(spec.get("id", "room%d" % i)),
			"name": str(spec.get("name", "")),
			"rect": rect,
		})

	# Recentre, so the rest of the game can keep assuming the room is on the
	# origin however the plan was written.
	var shift := -(union.position + union.size * 0.5)
	for entry in plan:
		var rect: Rect2 = entry["rect"]
		rect.position += shift
		entry["rect"] = rect
	width = union.size.x
	depth = union.size.y

	if is_inside_tree():
		rebuild()


func set_floor_color(c: Color) -> void:
	floor_color = c
	if _floor_material:
		_floor_material.albedo_color = c


func set_wall_color(c: Color) -> void:
	wall_color = c
	for i in _wall_materials.size():
		var shade: float = _WALL_SHADES[i]
		_wall_materials[i].albedo_color = Color(c.r * shade, c.g * shade, c.b * shade, c.a)


func set_walls_visible(value: bool) -> void:
	walls_visible = value
	for wall in _walls:
		wall.visible = value


## The bounding box of the whole plan.
func bounds() -> Rect2:
	return Rect2(-width * 0.5, -depth * 0.5, width, depth)


## Floor actually inside the walls, which for a plan is the sum of its rooms —
## not the bounding box, since an L-shaped flat has a corner that is outdoors.
func area() -> float:
	var total := 0.0
	for entry in plan:
		var rect: Rect2 = entry["rect"]
		total += rect.size.x * rect.size.y
	return total


func is_multi_room() -> bool:
	return plan.size() > 1


func room_count() -> int:
	return plan.size()


## Index of the room a floor point falls in, or the nearest one if the point is
## outside the plan altogether.
func room_index_at(point: Vector2) -> int:
	for i in plan.size():
		var rect: Rect2 = plan[i]["rect"]
		if rect.has_point(point):
			return i
	var best := 0
	var best_distance := INF
	for i in plan.size():
		var rect: Rect2 = plan[i]["rect"]
		var nearest := Vector2(
			clampf(point.x, rect.position.x, rect.end.x),
			clampf(point.y, rect.position.y, rect.end.y))
		var distance := nearest.distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best


func room_id_at(point: Vector2) -> String:
	return str(plan[room_index_at(point)]["id"]) if not plan.is_empty() else ""


func rect_at(point: Vector2) -> Rect2:
	return plan[room_index_at(point)]["rect"] if not plan.is_empty() else bounds()


func rect_of(room_id: String) -> Rect2:
	for entry in plan:
		if str(entry["id"]) == room_id:
			return entry["rect"]
	return bounds()


func has_room(room_id: String) -> bool:
	for entry in plan:
		if str(entry["id"]) == room_id:
			return true
	return false


func room_name(room_id: String) -> String:
	for entry in plan:
		if str(entry["id"]) == room_id:
			return str(entry["name"])
	return ""


func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_walls.clear()
	_wall_spans.clear()

	for entry in plan:
		_build_floor(entry)
	_build_grid()
	_build_walls()
	if is_multi_room():
		_build_room_labels()


# -------------------------------------------------------------------- floors

func _build_floor(entry: Dictionary) -> void:
	var rect: Rect2 = entry["rect"]
	var slab := MeshInstance3D.new()
	slab.name = "Floor_%s" % entry["id"]
	var mesh := BoxMesh.new()
	mesh.size = Vector3(rect.size.x, 0.10, rect.size.y)
	slab.mesh = mesh
	var centre := rect.position + rect.size * 0.5
	slab.position = Vector3(centre.x, -0.05, centre.y)
	slab.material_override = _floor_material
	add_child(slab)
	# One texture tile every two metres, so boards stay the same size whatever
	# the room's dimensions. The material is shared, so the largest room wins.
	var scale_x: float = maxf(_floor_material.uv1_scale.x, rect.size.x * 0.5)
	var scale_y: float = maxf(_floor_material.uv1_scale.y, rect.size.y * 0.5)
	_floor_material.uv1_scale = Vector3(scale_x, scale_y, 1.0)


func _build_grid() -> void:
	var grid := MeshInstance3D.new()
	grid.name = "Grid"
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 1)

	# Kept faint: the floor texture already gives the eye something to read,
	# and this only has to show where things will snap to.
	var minor := Color(0, 0, 0, 0.06)
	var major := Color(0, 0, 0, 0.14)

	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for entry in plan:
		var rect: Rect2 = entry["rect"]
		var x := ceilf(rect.position.x / GRID_STEP) * GRID_STEP
		while x <= rect.end.x + 0.0001:
			var tone: Color = major if absf(fmod(x, 1.0)) < 0.001 else minor
			im.surface_set_color(tone)
			im.surface_add_vertex(Vector3(x, 0, rect.position.y))
			im.surface_set_color(tone)
			im.surface_add_vertex(Vector3(x, 0, rect.end.y))
			x += GRID_STEP
		var z := ceilf(rect.position.y / GRID_STEP) * GRID_STEP
		while z <= rect.end.y + 0.0001:
			var tone: Color = major if absf(fmod(z, 1.0)) < 0.001 else minor
			im.surface_set_color(tone)
			im.surface_add_vertex(Vector3(rect.position.x, 0, z))
			im.surface_set_color(tone)
			im.surface_add_vertex(Vector3(rect.end.x, 0, z))
			z += GRID_STEP
	im.surface_end()

	grid.mesh = im
	grid.position = Vector3(0, 0.004, 0)
	grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grid)


# --------------------------------------------------------------------- walls

## Every room contributes its four sides. Where a side is shared with the room
## next door it becomes one dividing wall with a doorway in it, built once;
## the rest of the side is the outside of the flat.
func _build_walls() -> void:
	for i in plan.size():
		var rect: Rect2 = plan[i]["rect"]
		for side in 4:
			var line := _side_line(rect, side)
			var span := _side_span(rect, side)
			var shared: Array[Vector2] = []
			for j in plan.size():
				if j == i:
					continue
				var other: Rect2 = plan[j]["rect"]
				if absf(_side_line(other, _opposite(side)) - line) > EPS:
					continue
				var overlap := _overlap(span, _side_span(other, _opposite(side)))
				if overlap.y - overlap.x <= EPS:
					continue
				shared.append(overlap)
				# Build the divider once, from the lower-indexed room.
				if j > i:
					_build_wall(side, line, overlap, true)
			for part in _subtract(span, shared):
				if part.y - part.x > EPS:
					_build_wall(side, line, part, false)


## Where a rectangle's side sits: the X of an east/west side, the Z of a
## north/south one. Sides are ordered north, south, west, east.
static func _side_line(rect: Rect2, side: int) -> float:
	match side:
		0: return rect.position.y
		1: return rect.end.y
		2: return rect.position.x
		_: return rect.end.x


## The interval a side runs along, on whichever axis it is parallel to.
static func _side_span(rect: Rect2, side: int) -> Vector2:
	if side < 2:
		return Vector2(rect.position.x, rect.end.x)
	return Vector2(rect.position.y, rect.end.y)


static func _opposite(side: int) -> int:
	return [1, 0, 3, 2][side]


## Outward normal of a side, pointing away from the room it belongs to.
static func _side_normal(side: int) -> Vector3:
	return [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)][side]


static func _overlap(a: Vector2, b: Vector2) -> Vector2:
	return Vector2(maxf(a.x, b.x), minf(a.y, b.y))


## What is left of `span` once every interval in `cuts` is taken out of it.
static func _subtract(span: Vector2, cuts: Array[Vector2]) -> Array[Vector2]:
	var parts: Array[Vector2] = [span]
	for cut in cuts:
		var next: Array[Vector2] = []
		for part in parts:
			if cut.y <= part.x + EPS or cut.x >= part.y - EPS:
				next.append(part)
				continue
			if cut.x > part.x + EPS:
				next.append(Vector2(part.x, cut.x))
			if cut.y < part.y - EPS:
				next.append(Vector2(cut.y, part.y))
		parts = next
	return parts


## One run of wall. A divider gets a doorway punched through the middle of it,
## which is two posts and a lintel rather than one slab.
func _build_wall(side: int, line: float, span: Vector2, divider: bool) -> void:
	var normal := _side_normal(side)
	var along := span.y - span.x
	if not divider or along < DOOR_WIDTH + 0.8:
		_add_wall_piece(side, line, span, height, 0.0, divider)
		_add_skirting(side, line, span)
		return

	var middle: float = (span.x + span.y) * 0.5
	var opening := Vector2(middle - DOOR_WIDTH * 0.5, middle + DOOR_WIDTH * 0.5)
	_add_wall_piece(side, line, Vector2(span.x, opening.x), height, 0.0, divider)
	_add_wall_piece(side, line, Vector2(opening.y, span.y), height, 0.0, divider)
	# The lintel over the doorway keeps the wall reading as one run.
	_add_wall_piece(side, line, opening, height - DOOR_HEIGHT, DOOR_HEIGHT, divider)
	_add_skirting(side, line, Vector2(span.x, opening.x))
	_add_skirting(side, line, Vector2(opening.y, span.y))


func _add_wall_piece(side: int, line: float, span: Vector2, tall: float, base: float, divider: bool) -> void:
	if span.y - span.x <= EPS or tall <= EPS:
		return
	var t := WALL_THICKNESS
	var normal := _side_normal(side)
	var middle: float = (span.x + span.y) * 0.5
	var run: float = span.y - span.x
	# A divider stands on the boundary; an outside wall sits just beyond it.
	var offset: float = 0.0 if divider else t * 0.5

	var size: Vector3
	var position: Vector3
	if side < 2:
		size = Vector3(run, tall, t)
		position = Vector3(middle, base + tall * 0.5, line + normal.z * offset)
	else:
		size = Vector3(t, tall, run)
		position = Vector3(line + normal.x * offset, base + tall * 0.5, middle)

	var piece := MeshInstance3D.new()
	piece.name = "Wall"
	var mesh := BoxMesh.new()
	mesh.size = size
	piece.mesh = mesh
	piece.position = position
	piece.material_override = _wall_materials[0 if side < 2 else 1]
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.visible = walls_visible
	add_child(piece)
	_walls.append(piece)

	var from: Vector2
	var to: Vector2
	if side < 2:
		from = Vector2(span.x, position.z)
		to = Vector2(span.y, position.z)
	else:
		from = Vector2(position.x, span.x)
		to = Vector2(position.x, span.y)
	_wall_spans.append({"from": from, "to": to})


func _add_skirting(side: int, line: float, span: Vector2) -> void:
	if span.y - span.x <= EPS:
		return
	var normal := _side_normal(side)
	var middle: float = (span.x + span.y) * 0.5
	var run: float = span.y - span.x
	var skirt := MeshInstance3D.new()
	skirt.name = "Skirting"
	var mesh := BoxMesh.new()
	if side < 2:
		mesh.size = Vector3(run, 0.09, 0.02)
		skirt.position = Vector3(middle, 0.045, line - normal.z * 0.06)
	else:
		mesh.size = Vector3(0.02, 0.09, run)
		skirt.position = Vector3(line - normal.x * 0.06, 0.045, middle)
	skirt.mesh = mesh
	skirt.material_override = _skirting_material
	skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(skirt)


## A name floating over each room, so a plan reads as rooms rather than as one
## odd-shaped floor. Fixed on screen, like the map labels.
func _build_room_labels() -> void:
	for entry in plan:
		if str(entry["name"]) == "":
			continue
		var rect: Rect2 = entry["rect"]
		var centre := rect.position + rect.size * 0.5
		var label := Label3D.new()
		label.text = str(entry["name"])
		label.font_size = 64
		# Sized in metres rather than pinned to the screen: a name has to stay
		# inside its own room, and half a dozen fixed-size labels at map height
		# pile into an unreadable heap.
		label.pixel_size = 0.0055
		label.position = Vector3(centre.x, height * 0.62, centre.y)
		label.modulate = Color(1, 1, 1, 0.66)
		label.outline_size = 18
		label.outline_modulate = Color(0.05, 0.06, 0.09, 0.7)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.render_priority = 2
		add_child(label)


# ---------------------------------------------------------------- visibility

## Hides whichever walls stand between the camera and the inside of the flat,
## so every room stays open from any orbit angle — the classic "dollhouse"
## view. A wall goes when it blocks the line to any room's middle, which for a
## single room is exactly the old rule of dropping the walls facing you.
func update_wall_visibility(camera_position: Vector3, focus: Vector3 = Vector3.ZERO) -> void:
	if not walls_visible:
		return
	var eye := Vector2(camera_position.x, camera_position.z)
	var targets: Array[Vector2] = []
	for entry in plan:
		var rect: Rect2 = entry["rect"]
		targets.append(rect.position + rect.size * 0.5)
	# Looking straight down: walls would only clutter the plan view.
	var overhead: bool = eye.distance_to(Vector2(focus.x, focus.z)) < 1.0

	for i in _walls.size():
		var wall := _walls[i]
		if not auto_hide_walls:
			wall.visible = true
			continue
		if overhead:
			wall.visible = false
			continue
		var span: Dictionary = _wall_spans[i]
		var blocking := false
		for target in targets:
			if _crosses(eye, target, span["from"], span["to"]):
				blocking = true
				break
		wall.visible = not blocking


## True when the line of sight passes through a wall's footprint.
static func _crosses(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var s1 := _side_of(a, b, c)
	var s2 := _side_of(a, b, d)
	var s3 := _side_of(c, d, a)
	var s4 := _side_of(c, d, b)
	return s1 * s2 < 0.0 and s3 * s4 < 0.0


static func _side_of(a: Vector2, b: Vector2, p: Vector2) -> float:
	return (b - a).cross(p - a)
