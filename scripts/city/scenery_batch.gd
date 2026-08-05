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


## A pitched roof, which from map height is most of what a building is. A bare
## prism reads as a coloured wedge, so this adds what says tile: courses running
## up each slope, a ridge cap along the top and boards down the gable ends.
##
## `plan` is the roof's footprint and `base` the height it springs from. A prism
## runs its ridge along Z and slopes away to ±X, so that is the axis everything
## here is laid out on.
func roof(color: Color, plan: Vector2, base: float, rise: float, at: Vector3,
		basis: Basis = Basis.IDENTITY, courses: int = 4, verge: bool = true) -> void:
	var frame := Transform3D(basis, at)
	prism(color, Vector3(plan.x, rise, plan.y),
		frame * Vector3(0, base + rise * 0.5, 0), Layer.OPAQUE, basis)

	# Courses up each slope, each one sitting proud of the one below it. The
	# bar runs the length of the ridge and is laid over on the pitch.
	var pitch := atan2(rise, plan.x * 0.5)
	var out := Vector2(sin(pitch), cos(pitch)) * 0.035
	for sx in [-1.0, 1.0]:
		for i in courses:
			var along: float = (float(i) + 0.5) / float(courses)
			var x: float = sx * plan.x * 0.5 * (1.0 - along)
			var y: float = base + rise * along
			box(color.darkened(0.13 if i % 2 == 0 else 0.04),
				Vector3(0.18, 0.07, plan.y + 0.04),
				frame * Vector3(x + sx * out.x, y + out.y, 0),
				Layer.OPAQUE, basis * Basis(Vector3.BACK, -sx * pitch))
	# The ridge along the top, and a board down each gable end.
	box(color.darkened(0.22), Vector3(0.26, 0.16, plan.y + 0.18),
		frame * Vector3(0, base + rise, 0), Layer.OPAQUE, basis)
	if not verge:
		return
	for sz in [-1.0, 1.0]:
		prism(color.darkened(0.28), Vector3(plan.x + 0.12, rise, 0.16),
			frame * Vector3(0, base + rise * 0.5, sz * plan.y * 0.5), Layer.OPAQUE, basis)


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
