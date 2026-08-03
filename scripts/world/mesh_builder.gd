class_name MeshBuilder
extends RefCounted
## Turns a catalog part list into a single mesh.
##
## A piece of furniture is described as five to fifteen boxes and cylinders. As
## separate MeshInstance3D nodes that is fifteen nodes and fifteen draw calls
## each, and a furnished room ran to a couple of hundred of both. Here the parts
## are welded into one ArrayMesh with a surface per material, so a piece costs
## one node and three or four draw calls.
##
## The merged mesh only depends on the catalog entry, so it is built once per
## item type and shared by every copy in the room. Colour still varies per
## piece, through surface override materials on the instance.

## item id -> {"mesh": ArrayMesh, "roles": Array[String]}
static var _cache: Dictionary = {}


## Returns {"mesh": ArrayMesh, "roles": PackedStringArray} where roles[i] is the
## material role of surface i.
static func build(item_id: String, parts: Array) -> Dictionary:
	if _cache.has(item_id):
		return _cache[item_id]

	# Group by material so each role becomes one surface, keeping the order
	# stable for the caller.
	var order: Array[String] = []
	var grouped: Dictionary = {}
	for part: Dictionary in parts:
		var role := str(part.get("mat", "white"))
		if not grouped.has(role):
			grouped[role] = []
			order.append(role)
		grouped[role].append(part)

	var mesh := ArrayMesh.new()
	var roles := PackedStringArray()
	for role in order:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var wrote := false
		for part: Dictionary in grouped[role]:
			var primitive := _primitive_for(part)
			if primitive == null:
				continue
			tool.append_from(primitive, 0, _transform_for(part))
			wrote = true
		if not wrote:
			continue
		mesh = tool.commit(mesh)
		roles.append(role)

	var result := {"mesh": mesh, "roles": roles}
	_cache[item_id] = result
	return result


static func _primitive_for(part: Dictionary) -> Mesh:
	var size: Vector3 = part["size"]
	match str(part.get("shape", "box")):
		"cyl":
			var cyl := CylinderMesh.new()
			cyl.top_radius = size.x
			cyl.bottom_radius = size.z
			cyl.height = size.y
			cyl.radial_segments = 16
			cyl.rings = 0
			return cyl
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = size.x
			sphere.height = size.y
			sphere.radial_segments = 12
			sphere.rings = 6
			return sphere
		_:
			var box := BoxMesh.new()
			box.size = size
			return box


static func _transform_for(part: Dictionary) -> Transform3D:
	var basis := Basis.IDENTITY
	if part.has("rot"):
		var r: Vector3 = part["rot"]
		basis = Basis.from_euler(Vector3(deg_to_rad(r.x), deg_to_rad(r.y), deg_to_rad(r.z)))
	return Transform3D(basis, part["pos"])
