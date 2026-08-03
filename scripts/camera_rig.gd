class_name CameraRig
extends Node3D
## Orbit camera driven by touch gestures.
##
## The rig owns yaw/pitch/distance around a focus point on the floor plane and
## smoothly interpolates towards them, so flicks feel damped rather than jittery.

const MIN_PITCH := -88.0
const MAX_PITCH := -6.0
const MIN_DISTANCE := 2.0
const MAX_DISTANCE := 26.0

var yaw: float = -35.0
var pitch: float = -32.0
var distance: float = 10.0
var focus: Vector3 = Vector3.ZERO

## Half-extent the focus point is allowed to wander from the room centre.
var pan_limit: Vector2 = Vector2(6, 6)

var _yaw_current: float = -35.0
var _pitch_current: float = -32.0
var _distance_current: float = 10.0
var _focus_current: Vector3 = Vector3.ZERO

var camera: Camera3D


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 62.0
	camera.near = 0.05
	camera.far = 200.0
	camera.current = true
	add_child(camera)
	snap_to_target()


func _process(delta: float) -> void:
	var t: float = clampf(delta * 12.0, 0.0, 1.0)
	_yaw_current = lerp_angle(deg_to_rad(_yaw_current), deg_to_rad(yaw), t)
	_yaw_current = rad_to_deg(_yaw_current)
	_pitch_current = lerpf(_pitch_current, pitch, t)
	_distance_current = lerpf(_distance_current, distance, t)
	_focus_current = _focus_current.lerp(focus, t)
	_apply()


func snap_to_target() -> void:
	_yaw_current = yaw
	_pitch_current = pitch
	_distance_current = distance
	_focus_current = focus
	_apply()


func _apply() -> void:
	if camera == null:
		return
	var basis := Basis.from_euler(Vector3(deg_to_rad(_pitch_current), deg_to_rad(_yaw_current), 0.0))
	var offset := basis * Vector3(0, 0, _distance_current)
	camera.global_position = _focus_current + offset
	camera.look_at(_focus_current, Vector3.UP)


func orbit(delta_pixels: Vector2) -> void:
	yaw -= delta_pixels.x * 0.30
	pitch = clampf(pitch - delta_pixels.y * 0.25, MIN_PITCH, MAX_PITCH)


func zoom(factor: float) -> void:
	distance = clampf(distance * factor, MIN_DISTANCE, MAX_DISTANCE)


## Pans the focus point across the floor, in the camera's screen directions.
func pan(delta_pixels: Vector2) -> void:
	var scale_factor: float = _distance_current * 0.0022
	var yaw_rad := deg_to_rad(_yaw_current)
	var right := Vector3(cos(yaw_rad), 0, -sin(yaw_rad))
	var forward := Vector3(sin(yaw_rad), 0, cos(yaw_rad))
	focus -= right * delta_pixels.x * scale_factor
	focus -= forward * delta_pixels.y * scale_factor
	focus.x = clampf(focus.x, -pan_limit.x, pan_limit.x)
	focus.z = clampf(focus.z, -pan_limit.y, pan_limit.y)
	focus.y = 0.0


func frame_room(width: float, depth: float) -> void:
	pan_limit = Vector2(width * 0.6, depth * 0.6)
	focus = Vector3.ZERO
	distance = clampf(maxf(width, depth) * 1.25, MIN_DISTANCE, MAX_DISTANCE)


func set_top_view(enabled: bool) -> void:
	if enabled:
		pitch = MIN_PITCH
		yaw = 0.0
	else:
		pitch = -32.0
		yaw = -35.0


func is_top_view() -> bool:
	return pitch <= MIN_PITCH + 1.0
