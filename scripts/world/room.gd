class_name Room
extends Node3D
## Procedural room shell: floor, four walls, skirting and a floor grid.
##
## The room is centred on the origin, so it spans
## [-width/2, width/2] on X and [-depth/2, depth/2] on Z.

const WALL_THICKNESS := 0.10
const GRID_STEP := 0.5

var width: float = 6.0
var depth: float = 5.0
var height: float = 2.6

var floor_color: Color = Color(0.72, 0.62, 0.50)
var wall_color: Color = Color(0.90, 0.89, 0.86)
var walls_visible: bool = true
var auto_hide_walls: bool = true

var _floor: MeshInstance3D
var _grid: MeshInstance3D
var _walls: Array[MeshInstance3D] = []
## Outward normal (XZ) of each wall, matching _walls by index.
var _wall_normals: Array[Vector3] = []
var _floor_material: StandardMaterial3D
var _skirting_material: StandardMaterial3D
## One material per wall. Side walls are shaded slightly darker so the corners
## of the room stay readable instead of merging into one white surface.
var _wall_materials: Array[StandardMaterial3D] = []
const _WALL_SHADES: Array[float] = [1.0, 1.0, 0.86, 0.86]


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

	rebuild()


func configure(w: float, d: float, h: float) -> void:
	width = clampf(w, 2.0, 20.0)
	depth = clampf(d, 2.0, 20.0)
	height = clampf(h, 2.0, 4.0)
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


func bounds() -> Rect2:
	return Rect2(-width * 0.5, -depth * 0.5, width, depth)


func area() -> float:
	return width * depth


func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_walls.clear()
	_wall_normals.clear()

	_build_floor()
	_build_grid()
	_build_walls()


func _build_floor() -> void:
	_floor = MeshInstance3D.new()
	_floor.name = "Floor"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.10, depth)
	_floor.mesh = mesh
	_floor.position = Vector3(0, -0.05, 0)
	_floor.material_override = _floor_material
	# One texture tile every two metres, so boards stay the same size whatever
	# the room's dimensions.
	_floor_material.uv1_scale = Vector3(width * 0.5, depth * 0.5, 1.0)
	add_child(_floor)


func _build_grid() -> void:
	_grid = MeshInstance3D.new()
	_grid.name = "Grid"
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 1)

	var hw := width * 0.5
	var hd := depth * 0.5
	# Kept faint: the floor texture already gives the eye something to read,
	# and this only has to show where things will snap to.
	var minor := Color(0, 0, 0, 0.06)
	var major := Color(0, 0, 0, 0.14)

	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var x := -hw
	var i := 0
	while x <= hw + 0.0001:
		im.surface_set_color(major if absf(fmod(x, 1.0)) < 0.001 else minor)
		im.surface_add_vertex(Vector3(x, 0, -hd))
		im.surface_set_color(major if absf(fmod(x, 1.0)) < 0.001 else minor)
		im.surface_add_vertex(Vector3(x, 0, hd))
		x += GRID_STEP
		i += 1
	var z := -hd
	while z <= hd + 0.0001:
		im.surface_set_color(major if absf(fmod(z, 1.0)) < 0.001 else minor)
		im.surface_add_vertex(Vector3(-hw, 0, z))
		im.surface_set_color(major if absf(fmod(z, 1.0)) < 0.001 else minor)
		im.surface_add_vertex(Vector3(hw, 0, z))
		z += GRID_STEP
	im.surface_end()

	_grid.mesh = im
	_grid.position = Vector3(0, 0.004, 0)
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_grid)


func _build_walls() -> void:
	var hw := width * 0.5
	var hd := depth * 0.5
	var t := WALL_THICKNESS
	var specs := [
		{"name": "WallNorth", "size": Vector3(width + t * 2.0, height, t), "pos": Vector3(0, height * 0.5, -hd - t * 0.5), "normal": Vector3(0, 0, -1)},
		{"name": "WallSouth", "size": Vector3(width + t * 2.0, height, t), "pos": Vector3(0, height * 0.5, hd + t * 0.5), "normal": Vector3(0, 0, 1)},
		{"name": "WallWest", "size": Vector3(t, height, depth), "pos": Vector3(-hw - t * 0.5, height * 0.5, 0), "normal": Vector3(-1, 0, 0)},
		{"name": "WallEast", "size": Vector3(t, height, depth), "pos": Vector3(hw + t * 0.5, height * 0.5, 0), "normal": Vector3(1, 0, 0)},
	]
	for index in specs.size():
		var spec: Dictionary = specs[index]
		var holder := MeshInstance3D.new()
		holder.name = spec["name"]
		var mesh := BoxMesh.new()
		mesh.size = spec["size"]
		holder.mesh = mesh
		holder.position = spec["pos"]
		holder.material_override = _wall_materials[index]
		holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.visible = walls_visible
		add_child(holder)
		_walls.append(holder)
		_wall_normals.append(spec["normal"])

		# Skirting board along the inner face.
		var skirt := MeshInstance3D.new()
		skirt.name = spec["name"] + "Skirt"
		var skirt_mesh := BoxMesh.new()
		var n: Vector3 = spec["normal"]
		if absf(n.z) > 0.5:
			skirt_mesh.size = Vector3(width, 0.09, 0.02)
			skirt.position = Vector3(0, 0.045, -n.z * (hd - 0.011))
		else:
			skirt_mesh.size = Vector3(0.02, 0.09, depth)
			skirt.position = Vector3(-n.x * (hw - 0.011), 0.045, 0)
		skirt.mesh = skirt_mesh
		skirt.material_override = _skirting_material
		skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(skirt)


## Hides whichever walls sit between the camera and the room, so the interior
## stays visible from any orbit angle (the classic "dollhouse" view).
func update_wall_visibility(camera_position: Vector3) -> void:
	if not walls_visible:
		return
	var to_camera := camera_position - global_position
	to_camera.y = 0.0
	# Looking straight down: walls would only clutter the plan view.
	var overhead: bool = to_camera.length() < 1.0
	for i in _walls.size():
		var wall := _walls[i]
		if not auto_hide_walls:
			wall.visible = true
		elif overhead:
			wall.visible = false
		else:
			wall.visible = to_camera.normalized().dot(_wall_normals[i]) < 0.10
