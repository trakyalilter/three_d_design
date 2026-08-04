extends Node
## Thumbnails of catalogue pieces, for the tray.
##
## The furniture has no art files — every piece is welded together from
## primitives at runtime — so an icon has to be rendered rather than loaded.
## One small off-screen viewport with its own world does the work: a piece is
## mounted in it, drawn once, and the result kept as a texture for the rest of
## the session.
##
## Rendering happens one piece per frame in the background. A caller asks for a
## thumbnail and gets it later through a callback, so opening a tray tab never
## stalls on twenty renders at once. Autoloaded as `Icons`.

const SIZE := 76
## How much room to leave around the piece, as a fraction of its own size.
const MARGIN := 1.10

var _cache: Dictionary = {}
var _queue: Array[String] = []
## item id -> the callbacks waiting on it.
var _waiting: Dictionary = {}
var _busy := false

var _viewport: SubViewport
var _camera: Camera3D
var _mounted: MeshInstance3D


func _ready() -> void:
	# Headless has no renderer to draw into; callers fall back to their plain
	# text buttons, which is what the smoke test sees.
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE, SIZE)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.world_3d = World3D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.current = true
	_viewport.add_child(_camera)

	# The same two-light rig the designer uses, so a thumbnail is shaded like
	# the piece will be once it is standing in the room.
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-46.0), deg_to_rad(-38.0), 0.0)
	key.light_energy = 1.05
	key.light_color = Color(1.0, 0.97, 0.92)
	_viewport.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(132.0), 0.0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.82, 0.88, 1.0)
	_viewport.add_child(fill)

	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.72)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	_viewport.add_child(world)


## The thumbnail for a piece if it has already been drawn, otherwise null.
func texture_for(item_id: String) -> Texture2D:
	return _cache.get(item_id, null)


## Asks for a thumbnail. `on_ready` is called straight away when the piece has
## already been drawn, and once it has been otherwise. Callbacks belonging to
## freed nodes are dropped.
func request(item_id: String, on_ready: Callable) -> void:
	if _viewport == null or not Catalog.has_item(item_id):
		return
	if _cache.has(item_id):
		on_ready.call(_cache[item_id])
		return
	if not _waiting.has(item_id):
		_waiting[item_id] = []
		_queue.append(item_id)
	(_waiting[item_id] as Array).append(on_ready)


func _process(_delta: float) -> void:
	if _busy or _queue.is_empty():
		return
	_draw_next()


func _draw_next() -> void:
	_busy = true
	var item_id: String = _queue.pop_front()
	_mount(item_id)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw

	var image := _viewport.get_texture().get_image()
	if image != null and not image.is_empty():
		var texture := ImageTexture.create_from_image(image)
		_cache[item_id] = texture
		for callback: Callable in _waiting.get(item_id, []):
			if callback.is_valid():
				callback.call(texture)
	_waiting.erase(item_id)

	if _mounted != null:
		_viewport.remove_child(_mounted)
		_mounted.queue_free()
		_mounted = null
	_busy = false


## Puts one piece in front of the camera, framed so it fills the thumbnail
## whatever shape it is.
func _mount(item_id: String) -> void:
	var def: Dictionary = Catalog.get_item(item_id)
	var built := MeshBuilder.build(item_id, def["parts"])

	_mounted = MeshInstance3D.new()
	_mounted.mesh = built["mesh"]
	_mounted.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tint: Color = Catalog.default_tint(item_id)
	var roles: PackedStringArray = built["roles"]
	for index in roles.size():
		_mounted.set_surface_override_material(index, Catalog.make_material(roles[index], tint))
	_viewport.add_child(_mounted)

	var lo: Vector3 = def["extents"]["min"]
	var hi: Vector3 = def["extents"]["max"]
	var centre := (lo + hi) * 0.5
	var basis := Basis.from_euler(Vector3(deg_to_rad(-24.0), deg_to_rad(-36.0), 0.0))

	# Fit by projecting the piece's own corners onto the camera plane, so a
	# wide sofa and a tall lamp both end up filling the frame.
	var half := Vector2.ZERO
	var inverse := basis.inverse()
	for sx in [lo.x, hi.x]:
		for sy in [lo.y, hi.y]:
			for sz in [lo.z, hi.z]:
				var local := inverse * (Vector3(sx, sy, sz) - centre)
				half.x = maxf(half.x, absf(local.x))
				half.y = maxf(half.y, absf(local.y))
	var reach: float = maxf(maxf(half.x, half.y) * 2.0 * MARGIN, 0.2)

	_camera.size = reach
	_camera.near = 0.01
	_camera.far = reach * 8.0
	_camera.global_position = centre + basis * Vector3(0, 0, reach * 2.5)
	_camera.look_at(centre, Vector3.UP)
