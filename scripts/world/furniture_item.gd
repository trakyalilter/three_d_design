class_name FurnitureItem
extends Node3D
## A single piece of furniture placed in the room.
##
## The visual is built at runtime from the primitive part list in Catalog, and a
## StaticBody3D box is added so the item can be picked with a raycast.

const PICK_LAYER := 2

var item_id: String = ""
var tint: Color = Color.WHITE
var scale_factor: float = 1.0

var _extents_min := Vector3.ZERO
var _extents_max := Vector3.ONE
var _tint_materials: Array[StandardMaterial3D] = []
var _mesh_root: Node3D
var _body: StaticBody3D
var _collider: CollisionShape3D
var _blocked := false


func setup(id: String, item_tint: Color = Color.TRANSPARENT) -> void:
	item_id = id
	tint = Catalog.default_tint(id) if item_tint.a == 0.0 else item_tint
	var def: Dictionary = Catalog.get_item(id)
	if def.is_empty():
		push_warning("Unknown catalog item: %s" % id)
		return
	_extents_min = def["extents"]["min"]
	_extents_max = def["extents"]["max"]
	_build(def)


func _build(def: Dictionary) -> void:
	_mesh_root = Node3D.new()
	_mesh_root.name = "Meshes"
	add_child(_mesh_root)

	for part: Dictionary in def["parts"]:
		var mi := MeshInstance3D.new()
		var size: Vector3 = part["size"]
		match part.get("shape", "box"):
			"cyl":
				var cyl := CylinderMesh.new()
				cyl.top_radius = size.x
				cyl.bottom_radius = size.z
				cyl.height = size.y
				cyl.radial_segments = 20
				cyl.rings = 1
				mi.mesh = cyl
			"sphere":
				var sph := SphereMesh.new()
				sph.radius = size.x
				sph.height = size.y
				sph.radial_segments = 16
				sph.rings = 8
				mi.mesh = sph
			_:
				var box := BoxMesh.new()
				box.size = size
				mi.mesh = box
		var role: String = part.get("mat", "white")
		var mat := Catalog.make_material(role, tint)
		if role == "tint":
			_tint_materials.append(mat)
		mi.material_override = mat
		mi.position = part["pos"]
		if part.has("rot"):
			var r: Vector3 = part["rot"]
			mi.rotation = Vector3(deg_to_rad(r.x), deg_to_rad(r.y), deg_to_rad(r.z))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_mesh_root.add_child(mi)

	# Pick volume: one box covering the whole item.
	_body = StaticBody3D.new()
	_body.name = "Pick"
	_body.collision_layer = PICK_LAYER
	_body.collision_mask = 0
	_body.input_ray_pickable = true
	_collider = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var span: Vector3 = _extents_max - _extents_min
	shape.size = Vector3(maxf(span.x, 0.05), maxf(span.y, 0.05), maxf(span.z, 0.05))
	_collider.shape = shape
	_collider.position = (_extents_max + _extents_min) * 0.5
	_body.add_child(_collider)
	add_child(_body)


## Uniform scale applied to the meshes and the pick volume.
func set_item_scale(value: float) -> void:
	scale_factor = clampf(value, 0.5, 2.0)
	scale = Vector3.ONE * scale_factor


func set_tint(color: Color) -> void:
	tint = color
	for mat in _tint_materials:
		mat.albedo_color = color


## Tints the whole item red while it overlaps something else.
func set_blocked(value: bool) -> void:
	if _blocked == value:
		return
	_blocked = value
	for child in _mesh_root.get_children():
		var mi := child as MeshInstance3D
		var mat := mi.material_override as StandardMaterial3D
		if mat == null:
			continue
		if value:
			mat.emission_enabled = true
			mat.emission = Color(0.55, 0.05, 0.05)
			mat.emission_energy_multiplier = 0.85
		else:
			mat.emission_enabled = false


func is_blocked() -> bool:
	return _blocked


## Footprint size in world units, accounting for the item's scale.
func footprint() -> Vector2:
	return Catalog.footprint(item_id) * scale_factor


func item_height() -> float:
	return Catalog.height(item_id) * scale_factor


## Footprint centre in world space (parts are not always centred on the origin).
func footprint_center() -> Vector2:
	var local_center := Vector2(
		(_extents_max.x + _extents_min.x) * 0.5,
		(_extents_max.z + _extents_min.z) * 0.5
	) * scale_factor
	var yaw := rotation.y
	var rotated := local_center.rotated(-yaw)
	return Vector2(global_position.x + rotated.x, global_position.z + rotated.y)


## The four floor corners of the (rotated) footprint, in world XZ.
func footprint_corners() -> PackedVector2Array:
	var half := footprint() * 0.5
	var c := footprint_center()
	var yaw := -rotation.y
	var out := PackedVector2Array()
	for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		out.append(c + Vector2(s.x * half.x, s.y * half.y).rotated(yaw))
	return out


func to_dict() -> Dictionary:
	return {
		"id": item_id,
		"x": snappedf(global_position.x, 0.0001),
		"y": snappedf(global_position.y, 0.0001),
		"z": snappedf(global_position.z, 0.0001),
		"rot": snappedf(rad_to_deg(rotation.y), 0.01),
		"scale": snappedf(scale_factor, 0.001),
		"tint": tint.to_html(false),
	}


static func from_dict(data: Dictionary) -> FurnitureItem:
	var id: String = str(data.get("id", ""))
	if not Catalog.has_item(id):
		return null
	var item := FurnitureItem.new()
	var tint_hex: String = str(data.get("tint", ""))
	var color: Color = Color.TRANSPARENT
	if tint_hex != "" and Color.html_is_valid(tint_hex):
		color = Color.html(tint_hex)
	item.setup(id, color)
	item.position = Vector3(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0)),
		float(data.get("z", 0.0))
	)
	item.rotation.y = deg_to_rad(float(data.get("rot", 0.0)))
	item.set_item_scale(float(data.get("scale", 1.0)))
	return item
