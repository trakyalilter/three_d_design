class_name Prim
extends RefCounted
## The shapes a piece of furniture is built out of.
##
## Everything in the catalogue used to be a plain BoxMesh, and a room of plain
## boxes reads as a room of crates. The reason is lighting, not detail: a hard
## ninety-degree edge puts two faces at right angles and nothing sits between
## them, so no edge in the room ever catches a highlight and every piece comes
## out flat. Taking a couple of millimetres off each edge — which is what a real
## piece of furniture has anyway — gives every one of them a lit rim.
##
## Three things are offered on top of a box:
##
##   bevel  how much is cut off each edge, in metres
##   soft   shades that cut smoothly rather than as a facet, which is the
##          difference between a cushion and a block
##   taper  narrows the top of the box, which is what makes a leg a leg
##
## The chamfer is cut *inside* the box, and a taper only ever narrows it, so a
## piece's extents come out exactly as they were. Everything that measures,
## places, stacks, prices or picks furniture is unaffected by any of this.

## What comes off an edge when nothing else is asked for. Small enough to read
## as a manufactured edge rather than as a rounded-over toy.
const DEFAULT_BEVEL := 0.012

## How much comes off something upholstered, unless the part says otherwise.
const SOFT_BEVEL := 0.06


## A box with its edges taken off.
static func box(size: Vector3, bevel: float = DEFAULT_BEVEL, soft: bool = false,
		taper: Vector2 = Vector2.ONE) -> Mesh:
	var h: Vector3 = size.abs() * 0.5
	var smallest: float = minf(minf(h.x, h.y), h.z)
	var b: float = clampf(bevel, 0.0, smallest * 0.85)
	if b < 0.0006:
		var plain := BoxMesh.new()
		plain.size = size
		return plain

	var a := Vector3(h.x - b, h.y - b, h.z - b)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# The six faces, each inset by the chamfer. Taking the two other axes in
	# cyclic order makes the corners come out wound anticlockwise from outside.
	for axis in 3:
		var i := (axis + 1) % 3
		var j := (axis + 2) % 3
		for s in [-1.0, 1.0]:
			var out := Vector3.ZERO
			out[axis] = s
			var corners: Array[Vector2] = [
				Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
			var quad: Array[Vector3] = []
			for corner in corners:
				var p := Vector3.ZERO
				p[axis] = s * h[axis]
				p[i] = corner.x * a[i]
				p[j] = corner.y * a[j]
				quad.append(p)
			_quad(tool, quad, out, a, h, soft, taper, size.y)

	# The twelve edges, one band each, running along axis k.
	for k in 3:
		var i := (k + 1) % 3
		var j := (k + 2) % 3
		for si in [-1.0, 1.0]:
			for sj in [-1.0, 1.0]:
				var out := Vector3.ZERO
				out[i] = si
				out[j] = sj
				out = out.normalized()
				var quad: Array[Vector3] = []
				for step: Array in [[h[i], a[j], -a[k]], [h[i], a[j], a[k]],
						[a[i], h[j], a[k]], [a[i], h[j], -a[k]]]:
					var p := Vector3.ZERO
					p[i] = si * float(step[0])
					p[j] = sj * float(step[1])
					p[k] = float(step[2])
					quad.append(p)
				_quad(tool, quad, out, a, h, soft, taper, size.y)

	# And the eight corners, a triangle apiece.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var s := Vector3(sx, sy, sz)
				var tri: Array[Vector3] = [
					Vector3(sx * h.x, sy * a.y, sz * a.z),
					Vector3(sx * a.x, sy * h.y, sz * a.z),
					Vector3(sx * a.x, sy * a.y, sz * h.z),
				]
				_tri(tool, tri, s.normalized(), a, h, soft, taper, size.y)

	# Indexed, like every mesh Godot builds itself. MeshBuilder welds a piece's
	# parts together with append_from, and mixing an indexed source with a plain
	# one there loses whichever went in first.
	tool.index()
	tool.generate_tangents()
	return tool.commit()


## A cylinder. The catalogue's own convention: x is the radius at the top and z
## the radius at the bottom, so one shape covers posts, legs and lampshades.
static func cylinder(size: Vector3, segments: int = 20) -> Mesh:
	var cyl := CylinderMesh.new()
	cyl.top_radius = size.x
	cyl.bottom_radius = size.z
	cyl.height = size.y
	cyl.radial_segments = maxi(segments, 6)
	cyl.rings = 0
	return cyl


static func sphere(size: Vector3) -> Mesh:
	var ball := SphereMesh.new()
	ball.radius = size.x
	ball.height = size.y
	ball.radial_segments = 16
	ball.rings = 8
	return ball


# ------------------------------------------------------------------ the welding

## One quad, wound so it faces `out` whichever order the corners arrived in.
static func _quad(tool: SurfaceTool, points: Array[Vector3], out: Vector3,
		a: Vector3, h: Vector3, soft: bool, taper: Vector2, tall: float) -> void:
	var p: Array[Vector3] = []
	for point in points:
		p.append(_pull(point, taper, h.y, tall))
	if (p[1] - p[0]).cross(p[2] - p[0]).dot(out) < 0.0:
		p.reverse()
		points = points.duplicate()
		points.reverse()
	_vertex(tool, p[0], points[0], out, a, soft)
	_vertex(tool, p[1], points[1], out, a, soft)
	_vertex(tool, p[2], points[2], out, a, soft)
	_vertex(tool, p[0], points[0], out, a, soft)
	_vertex(tool, p[2], points[2], out, a, soft)
	_vertex(tool, p[3], points[3], out, a, soft)


static func _tri(tool: SurfaceTool, points: Array[Vector3], out: Vector3,
		a: Vector3, h: Vector3, soft: bool, taper: Vector2, tall: float) -> void:
	var p: Array[Vector3] = []
	for point in points:
		p.append(_pull(point, taper, h.y, tall))
	if (p[1] - p[0]).cross(p[2] - p[0]).dot(out) < 0.0:
		p.reverse()
		points = points.duplicate()
		points.reverse()
	for index in 3:
		_vertex(tool, p[index], points[index], out, a, soft)


## Narrows the foot of the box: `taper` is how wide the bottom is as a fraction
## of the top. Nothing is ever pushed outwards, so a tapered part still measures
## exactly the size it declared. A part that wants to be wider at the top says
## so with its size and takes the bottom in.
static func _pull(p: Vector3, taper: Vector2, half_tall: float, tall: float) -> Vector3:
	if is_equal_approx(taper.x, 1.0) and is_equal_approx(taper.y, 1.0):
		return p
	var up: float = clampf((p.y + half_tall) / maxf(tall, 0.0001), 0.0, 1.0)
	return Vector3(
		p.x * lerpf(clampf(taper.x, 0.02, 1.0), 1.0, up),
		p.y,
		p.z * lerpf(clampf(taper.y, 0.02, 1.0), 1.0, up))


## `square` is where the point sat before the taper, which is what the normal
## has to be worked out from: on a soft box it is the direction out of the core,
## which is what makes the chamfer shade as a curve rather than as a facet.
static func _vertex(tool: SurfaceTool, at: Vector3, square: Vector3, flat: Vector3,
		a: Vector3, soft: bool) -> void:
	var normal := flat
	if soft:
		var core := Vector3(
			clampf(square.x, -a.x, a.x),
			clampf(square.y, -a.y, a.y),
			clampf(square.z, -a.z, a.z))
		var away := square - core
		if away.length_squared() > 0.000001:
			normal = away.normalized()
	tool.set_normal(normal)
	tool.set_uv(Vector2(at.x + at.z, -at.y))
	tool.add_vertex(at)
