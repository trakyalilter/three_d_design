class_name SelectionMarker
extends Node3D
## Floor highlight drawn under the currently selected item: a translucent pad,
## four corner brackets and a small nose marker showing which way it faces.

const OK_COLOR := Color(0.30, 0.72, 1.0)
const BLOCKED_COLOR := Color(1.0, 0.35, 0.32)

var _pad: MeshInstance3D
var _pad_mesh: BoxMesh
var _corners: Array[MeshInstance3D] = []
var _nose: MeshInstance3D
var _pad_material: StandardMaterial3D
var _edge_material: StandardMaterial3D


func _ready() -> void:
	_pad_material = _make_material(OK_COLOR, 0.20)
	_edge_material = _make_material(OK_COLOR, 0.95)

	_pad_mesh = BoxMesh.new()
	_pad_mesh.size = Vector3(1, 0.004, 1)
	_pad = MeshInstance3D.new()
	_pad.name = "Pad"
	_pad.mesh = _pad_mesh
	_pad.material_override = _pad_material
	_pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pad)

	for i in 8:
		var bar := MeshInstance3D.new()
		bar.name = "Corner%d" % i
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.24, 0.012, 0.045)
		bar.mesh = mesh
		bar.material_override = _edge_material
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bar)
		_corners.append(bar)

	_nose = MeshInstance3D.new()
	_nose.name = "Nose"
	var nose_mesh := CylinderMesh.new()
	nose_mesh.top_radius = 0.0
	nose_mesh.bottom_radius = 0.09
	nose_mesh.height = 0.02
	nose_mesh.radial_segments = 3
	_nose.mesh = nose_mesh
	_nose.material_override = _edge_material
	_nose.rotation = Vector3(0, deg_to_rad(90), 0)
	_nose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_nose)

	visible = false


func _make_material(color: Color, alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.no_depth_test = false
	return mat


func follow(item: FurnitureItem) -> void:
	if item == null:
		visible = false
		return
	visible = true
	var size := item.footprint()
	var center := item.footprint_center()
	global_position = Vector3(center.x, 0.008, center.y)
	rotation.y = item.rotation.y

	_pad_mesh.size = Vector3(maxf(size.x, 0.08), 0.004, maxf(size.y, 0.08))

	var hx: float = size.x * 0.5
	var hz: float = size.y * 0.5
	var bar_len: float = clampf(minf(size.x, size.y) * 0.35, 0.10, 0.30)
	var i := 0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			# Bar running along X at this corner.
			var along_x := _corners[i]
			(along_x.mesh as BoxMesh).size = Vector3(bar_len, 0.012, 0.04)
			along_x.position = Vector3(sx * (hx - bar_len * 0.5), 0.006, sz * hz)
			i += 1
			# Bar running along Z at this corner.
			var along_z := _corners[i]
			(along_z.mesh as BoxMesh).size = Vector3(0.04, 0.012, bar_len)
			along_z.position = Vector3(sx * hx, 0.006, sz * (hz - bar_len * 0.5))
			i += 1

	_nose.position = Vector3(0, 0.006, -hz - 0.11)
	set_blocked(item.is_blocked())


func set_blocked(blocked: bool) -> void:
	var color := BLOCKED_COLOR if blocked else OK_COLOR
	_pad_material.albedo_color = Color(color.r, color.g, color.b, 0.20)
	_edge_material.albedo_color = Color(color.r, color.g, color.b, 0.95)


func clear() -> void:
	visible = false
