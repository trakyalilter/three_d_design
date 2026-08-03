class_name FurnitureItem
extends Node3D
## A single piece of furniture placed in the room.
##
## The visual is one merged mesh built from the primitive part list in Catalog
## (see MeshBuilder) with a surface per material, plus a soft blob on the floor
## that grounds it. A StaticBody3D box lets it be picked with a raycast.

const PICK_LAYER := 2

var item_id: String = ""
var tint: Color = Color.WHITE
var scale_factor: float = 1.0

var _extents_min := Vector3.ZERO
var _extents_max := Vector3.ONE
var _mesh: MeshInstance3D
var _materials: Array[StandardMaterial3D] = []
## Indices of the surfaces that follow the player's colour choice.
var _tint_surfaces: Array[int] = []
var _shadow: MeshInstance3D
var _body: StaticBody3D
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
	var built := MeshBuilder.build(item_id, def["parts"])

	_mesh = MeshInstance3D.new()
	_mesh.name = "Mesh"
	_mesh.mesh = built["mesh"]
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_mesh)

	# The mesh is shared between copies, so colour lives in per-instance
	# override materials rather than on the mesh itself.
	var roles: PackedStringArray = built["roles"]
	for index in roles.size():
		var role := roles[index]
		var material := Catalog.make_material(role, tint)
		_mesh.set_surface_override_material(index, material)
		_materials.append(material)
		if role == "tint":
			_tint_surfaces.append(index)

	_build_contact_shadow()

	# Pick volume: one box covering the whole item.
	_body = StaticBody3D.new()
	_body.name = "Pick"
	_body.collision_layer = PICK_LAYER
	_body.collision_mask = 0
	_body.input_ray_pickable = true
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var span: Vector3 = _extents_max - _extents_min
	shape.size = Vector3(maxf(span.x, 0.05), maxf(span.y, 0.05), maxf(span.z, 0.05))
	collider.shape = shape
	collider.position = (_extents_max + _extents_min) * 0.5
	_body.add_child(collider)
	add_child(_body)


## A soft dark blob just above the floor. Directional shadows alone leave
## furniture looking like it is hovering; this settles it onto the boards.
func _build_contact_shadow() -> void:
	var footprint := Catalog.footprint(item_id)
	if footprint.x <= 0.0 or footprint.y <= 0.0:
		return

	var quad := QuadMesh.new()
	quad.size = Vector2(footprint.x * 1.5, footprint.y * 1.5)
	quad.orientation = PlaneMesh.FACE_Y

	# Straight alpha blending: the texture carries the falloff in its alpha and
	# albedo_color scales it. (Multiply blending would ignore that alpha and
	# stamp a hard black square.)
	var material := StandardMaterial3D.new()
	material.albedo_texture = ProcTextures.contact_shadow()
	material.albedo_color = Color(0, 0, 0, 0.34)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_shadow = MeshInstance3D.new()
	_shadow.name = "ContactShadow"
	_shadow.mesh = quad
	_shadow.material_override = material
	_shadow.position = Vector3(
		(_extents_max.x + _extents_min.x) * 0.5,
		0.012,
		(_extents_max.z + _extents_min.z) * 0.5
	)
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)


## Uniform scale applied to the meshes and the pick volume.
func set_item_scale(value: float) -> void:
	scale_factor = clampf(value, 0.5, 2.0)
	scale = Vector3.ONE * scale_factor


func set_tint(color: Color) -> void:
	tint = color
	for index in _tint_surfaces:
		_materials[index].albedo_color = color


## Tints the whole item red while it overlaps something else.
func set_blocked(value: bool) -> void:
	if _blocked == value:
		return
	_blocked = value
	for material in _materials:
		if value:
			material.emission_enabled = true
			material.emission = Color(0.55, 0.05, 0.05)
			material.emission_energy_multiplier = 0.85
		else:
			material.emission_enabled = false


func is_blocked() -> bool:
	return _blocked


## Hides the grounding blob while a piece sits on top of another one.
func set_elevated(elevated: bool) -> void:
	if _shadow:
		_shadow.visible = not elevated


## Footprint size in world units, accounting for the item's scale.
func footprint() -> Vector2:
	return Catalog.footprint(item_id) * scale_factor


func item_height() -> float:
	return Catalog.height(item_id) * scale_factor


## Height of the top of this piece, for stacking things on it.
func top_height() -> float:
	return position.y + _extents_max.y * scale_factor


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
	item.set_elevated(item.position.y > 0.05)
	return item
