class_name SceneryBatch
extends RefCounted
## Welds the city's scenery into a couple of meshes.
##
## The neighbourhood is a few hundred boxes and cylinders — roads, kerbs,
## houses, shopfronts, trees, lamps, cars. Spawned individually that is several
## hundred nodes and as many draw calls for what is, in the end, a menu screen.
##
## Here every primitive is baked into one of three shared surfaces and its
## colour is written into the vertices, so the whole city draws in three calls.
## Anything that has to move, animate or be tapped stays a real node.

enum Layer { OPAQUE, GLASS, SHINY }

var _tools: Dictionary = {}
var _counts: Dictionary = {}


func _tool_for(layer: Layer) -> SurfaceTool:
	if not _tools.has(layer):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[layer] = tool
		_counts[layer] = 0
	return _tools[layer]


func box(color: Color, size: Vector3, position: Vector3, layer: Layer = Layer.OPAQUE, basis: Basis = Basis.IDENTITY) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_append(mesh, color, Transform3D(basis, position), layer)


func cylinder(color: Color, radius: float, height: float, position: Vector3, layer: Layer = Layer.OPAQUE, segments: int = 12, basis: Basis = Basis.IDENTITY) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 0
	_append(mesh, color, Transform3D(basis, position), layer)


func cone(color: Color, radius: float, height: float, position: Vector3, layer: Layer = Layer.OPAQUE, segments: int = 12) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 0
	_append(mesh, color, Transform3D(Basis.IDENTITY, position), layer)


func sphere(color: Color, radius: float, position: Vector3, layer: Layer = Layer.OPAQUE) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	_append(mesh, color, Transform3D(Basis.IDENTITY, position), layer)


func prism(color: Color, size: Vector3, position: Vector3, layer: Layer = Layer.OPAQUE, basis: Basis = Basis.IDENTITY) -> void:
	var mesh := PrismMesh.new()
	mesh.size = size
	_append(mesh, color, Transform3D(basis, position), layer)


## Copies a primitive's triangles into the batch, transformed into world space
## with the colour written onto every vertex.
func _append(mesh: Mesh, color: Color, transform: Transform3D, layer: Layer) -> void:
	var arrays := mesh.surface_get_arrays(0)
	if arrays.is_empty():
		return
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := transform.basis.inverse().transposed()

	var tool := _tool_for(layer)
	for index in indices:
		tool.set_color(color)
		tool.set_normal((normal_basis * normals[index]).normalized())
		if index < uvs.size():
			tool.set_uv(uvs[index])
		tool.add_vertex(transform * vertices[index])
	_counts[layer] = int(_counts[layer]) + indices.size() / 3


## Builds the finished meshes under `parent`. Returns how many nodes it made.
func commit(parent: Node3D) -> int:
	var made := 0
	for layer: Layer in _tools:
		var mesh := (_tools[layer] as SurfaceTool).commit()
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var instance := MeshInstance3D.new()
		instance.name = "Batch_%d" % layer
		instance.mesh = mesh
		instance.material_override = _material_for(layer)
		if layer == Layer.GLASS:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
		made += 1
	_tools.clear()
	return made


func triangle_count() -> int:
	var total := 0
	for count: int in _counts.values():
		total += count
	return total


static func _material_for(layer: Layer) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	match layer:
		Layer.GLASS:
			material.roughness = 0.1
			material.metallic = 0.1
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		Layer.SHINY:
			material.roughness = 0.35
			material.metallic = 0.7
		_:
			material.roughness = 0.92
			material.metallic = 0.0
	return material
