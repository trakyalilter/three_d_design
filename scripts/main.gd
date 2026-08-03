extends Node3D
## Room Designer 3D — entry point.
##
## Owns the scene graph (room, furniture, camera, lighting, UI) and translates
## touch gestures into camera moves, selection and item dragging.

const GRID_SNAP := 0.25
const ROTATE_STEP := 15.0
const SCALE_STEP := 0.1
const TAP_SLOP := 16.0
const FLAT_ITEM_HEIGHT := 0.12

enum Gesture { NONE, ORBIT, ITEM, PINCH }

var room: Room
var rig: CameraRig
var marker: SelectionMarker
var ui: DesignerUI
var items_root: Node3D

var selected: FurnitureItem = null
var snap_enabled := true

var _touches: Dictionary = {}
var _touch_origins: Dictionary = {}
var _gesture: int = Gesture.NONE
var _drag_offset := Vector3.ZERO
var _drag_moved := false
var _pinch_distance := 0.0
var _pinch_midpoint := Vector2.ZERO
var _floor_color := DesignerUI.FLOOR_SWATCHES[0]
var _wall_color := DesignerUI.WALL_SWATCHES[0]
var _dirty := false


func _ready() -> void:
	_build_environment()

	room = Room.new()
	room.name = "Room"
	add_child(room)

	items_root = Node3D.new()
	items_root.name = "Furniture"
	add_child(items_root)

	marker = SelectionMarker.new()
	marker.name = "SelectionMarker"
	add_child(marker)

	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)

	ui = DesignerUI.new()
	ui.name = "UI"
	add_child(ui)
	_connect_ui()

	room.set_floor_color(_floor_color)
	room.set_wall_color(_wall_color)
	rig.frame_room(room.width, room.depth)
	rig.snap_to_target()

	if not _restore(LayoutStore.load_autosave()):
		_seed_starter_room()

	_refresh_stats()
	ui.toast("Tap an item below to add it to the room", 3.5)


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.30, 0.42, 0.60)
	sky_material.sky_horizon_color = Color(0.62, 0.66, 0.72)
	sky_material.ground_bottom_color = Color(0.18, 0.19, 0.22)
	sky_material.ground_horizon_color = Color(0.42, 0.43, 0.46)
	sky_material.sun_angle_max = 30.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.40
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.8
	world.environment = env
	add_child(world)

	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(-38.0), 0.0)
	key.light_energy = 0.85
	key.light_color = Color(1.0, 0.97, 0.92)
	key.shadow_enabled = true
	# One tight split: the whole scene is only a few metres across, so this
	# spends the shadow map where it is actually needed.
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 24.0
	key.shadow_bias = 0.03
	key.shadow_normal_bias = 1.2
	key.shadow_blur = 1.4
	key.shadow_opacity = 0.72
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation = Vector3(deg_to_rad(-28.0), deg_to_rad(140.0), 0.0)
	fill.light_energy = 0.22
	fill.light_color = Color(0.82, 0.88, 1.0)
	fill.shadow_enabled = false
	add_child(fill)


func _connect_ui() -> void:
	ui.place_item.connect(_on_place_item)
	ui.command.connect(_on_command)
	ui.tint_selected.connect(_on_tint_selected)
	ui.room_changed.connect(_on_room_changed)
	ui.room_colors_changed.connect(_on_room_colors_changed)
	ui.walls_toggled.connect(func(on: bool) -> void: room.set_walls_visible(on))
	ui.snap_toggled.connect(func(on: bool) -> void: snap_enabled = on)
	ui.top_view_toggled.connect(func(on: bool) -> void: rig.set_top_view(on))
	ui.save_requested.connect(_on_save_requested)
	ui.load_requested.connect(_on_load_requested)
	ui.delete_layout_requested.connect(_on_delete_layout)
	ui.new_requested.connect(_on_new_requested)
	ui.recenter_requested.connect(func() -> void:
		rig.frame_room(room.width, room.depth)
		ui.toast("View recentred", 1.2))


func _process(_delta: float) -> void:
	if rig.camera:
		room.update_wall_visibility(rig.camera.global_position)


# --------------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton and event.pressed:
		# Desktop convenience: wheel zoom.
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			rig.zoom(0.90)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rig.zoom(1.10)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if ui.is_modal_open() or ui.is_point_over_ui(event.position):
			return
		_touches[event.index] = event.position
		_touch_origins[event.index] = event.position

		if _touches.size() == 1:
			_begin_single_touch(event.position)
		elif _touches.size() == 2:
			_begin_pinch()
	else:
		var was_tap: bool = _touch_origins.has(event.index) \
			and _touch_origins[event.index].distance_to(event.position) <= TAP_SLOP
		var was_orbit: bool = _gesture == Gesture.ORBIT
		_touches.erase(event.index)
		_touch_origins.erase(event.index)

		if _touches.is_empty():
			if was_orbit and was_tap:
				_select(null)
			if _gesture == Gesture.ITEM and _drag_moved:
				_mark_dirty()
			_gesture = Gesture.NONE
			_drag_moved = false
		elif _gesture == Gesture.PINCH and _touches.size() < 2:
			# Keep the remaining finger inert until it is lifted, so the camera
			# does not snap when one finger leaves a pinch.
			_gesture = Gesture.NONE


func _begin_single_touch(position: Vector2) -> void:
	var hit := _pick_item(position)
	if hit != null:
		if hit != selected:
			_select(hit)
		var floor_point := _floor_point(position)
		_drag_offset = hit.global_position - floor_point
		_drag_offset.y = 0.0
		_drag_moved = false
		_gesture = Gesture.ITEM
	else:
		_gesture = Gesture.ORBIT


func _begin_pinch() -> void:
	_gesture = Gesture.PINCH
	var points := _touch_points()
	if points.size() < 2:
		return
	_pinch_distance = points[0].distance_to(points[1])
	_pinch_midpoint = (points[0] + points[1]) * 0.5


func _handle_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	_touches[event.index] = event.position

	match _gesture:
		Gesture.ORBIT:
			rig.orbit(event.relative)
			ui.set_top_view_pressed(rig.is_top_view())
		Gesture.ITEM:
			_drag_selected(event.position)
		Gesture.PINCH:
			_update_pinch()


func _update_pinch() -> void:
	var points := _touch_points()
	if points.size() < 2:
		return
	var distance := points[0].distance_to(points[1])
	var midpoint := (points[0] + points[1]) * 0.5
	if _pinch_distance > 1.0 and distance > 1.0:
		rig.zoom(_pinch_distance / distance)
	rig.pan(midpoint - _pinch_midpoint)
	_pinch_distance = distance
	_pinch_midpoint = midpoint


func _touch_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var keys := _touches.keys()
	keys.sort()
	for key in keys:
		out.append(_touches[key])
	return out


func _drag_selected(position: Vector2) -> void:
	if selected == null:
		return
	var target := _floor_point(position) + _drag_offset
	target.y = selected.position.y
	if snap_enabled:
		target.x = snappedf(target.x, GRID_SNAP)
		target.z = snappedf(target.z, GRID_SNAP)
	selected.global_position = _clamp_to_room(selected, target)
	_drag_moved = true
	_update_overlaps()
	marker.follow(selected)


## Screen point projected onto the floor plane (y = 0).
func _floor_point(screen_position: Vector2) -> Vector3:
	var camera := rig.camera
	if camera == null:
		return Vector3.ZERO
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	if typeof(hit) != TYPE_VECTOR3:
		# Ray parallel to (or pointing away from) the floor: fall back to the
		# point straight below the camera.
		return Vector3(origin.x, 0.0, origin.z)
	return hit as Vector3


func _pick_item(screen_position: Vector2) -> FurnitureItem:
	var camera := rig.camera
	if camera == null:
		return null
	var origin := camera.project_ray_origin(screen_position)
	var to := origin + camera.project_ray_normal(screen_position) * 500.0
	var query := PhysicsRayQueryParameters3D.create(origin, to)
	query.collision_mask = FurnitureItem.PICK_LAYER
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	var node: Node = result["collider"]
	while node != null:
		if node is FurnitureItem:
			return node as FurnitureItem
		node = node.get_parent()
	return null


# ------------------------------------------------------------------ commands

func _on_place_item(item_id: String) -> void:
	var item := FurnitureItem.new()
	item.setup(item_id)
	items_root.add_child(item)

	var spot := rig.focus
	spot.y = 0.0
	if snap_enabled:
		spot.x = snappedf(spot.x, GRID_SNAP)
		spot.z = snappedf(spot.z, GRID_SNAP)
	item.global_position = _clamp_to_room(item, spot)
	item.global_position = _find_free_spot(item)

	_select(item)
	_mark_dirty()
	_refresh_stats()
	ui.toast("%s added — drag it to move" % Catalog.display_name(item_id), 1.8)


func _on_command(name: String) -> void:
	if selected == null:
		return
	match name:
		"rotate_left":
			selected.rotation.y += deg_to_rad(ROTATE_STEP)
		"rotate_right":
			selected.rotation.y -= deg_to_rad(ROTATE_STEP)
		"rotate_flip":
			selected.rotation.y += PI
		"scale_up":
			selected.set_item_scale(selected.scale_factor + SCALE_STEP)
		"scale_down":
			selected.set_item_scale(selected.scale_factor - SCALE_STEP)
		"duplicate":
			_duplicate_selected()
			return
		"delete":
			var label := Catalog.display_name(selected.item_id)
			var doomed := selected
			_select(null)
			items_root.remove_child(doomed)
			doomed.queue_free()
			_mark_dirty()
			_refresh_stats()
			_update_overlaps()
			ui.toast("%s removed" % label, 1.4)
			return
		"deselect":
			_select(null)
			return
	selected.global_position = _clamp_to_room(selected, selected.global_position)
	ui.set_selection(selected)
	_update_overlaps()
	marker.follow(selected)
	_mark_dirty()


func _duplicate_selected() -> void:
	if selected == null:
		return
	var copy := FurnitureItem.from_dict(selected.to_dict())
	if copy == null:
		return
	items_root.add_child(copy)
	copy.global_position = _find_free_spot(copy)
	_select(copy)
	_mark_dirty()
	_refresh_stats()
	ui.toast("Duplicated", 1.2)


func _on_tint_selected(color: Color) -> void:
	if selected == null:
		return
	selected.set_tint(color)
	selected.set_blocked(selected.is_blocked())
	_mark_dirty()


func _on_room_changed(width: float, room_depth: float, height: float) -> void:
	room.configure(width, room_depth, height)
	room.set_floor_color(_floor_color)
	room.set_wall_color(_wall_color)
	rig.pan_limit = Vector2(room.width * 0.6, room.depth * 0.6)
	for item in _items():
		item.global_position = _clamp_to_room(item, item.global_position)
	_update_overlaps()
	_refresh_stats()
	_mark_dirty()


func _on_room_colors_changed(floor_color: Color, wall_color: Color) -> void:
	_floor_color = floor_color
	_wall_color = wall_color
	room.set_floor_color(floor_color)
	room.set_wall_color(wall_color)
	_mark_dirty()


func _on_save_requested(layout_name: String) -> void:
	var clean := LayoutStore.sanitize(layout_name)
	if LayoutStore.save_layout(clean, _serialize()):
		ui.toast("Saved as \"%s\"" % clean, 2.0)
	else:
		ui.toast("Could not save the layout", 2.5)


func _on_load_requested(layout_name: String) -> void:
	var data := LayoutStore.load_layout(layout_name)
	if data.is_empty():
		ui.toast("Could not open \"%s\"" % layout_name, 2.5)
		return
	if _restore(data):
		ui.toast("Opened \"%s\"" % layout_name, 1.8)
		_mark_dirty()


func _on_delete_layout(layout_name: String) -> void:
	LayoutStore.delete_layout(layout_name)
	ui.toast("Deleted \"%s\"" % layout_name, 1.8)


func _on_new_requested() -> void:
	_select(null)
	_clear_items()
	_refresh_stats()
	_mark_dirty()
	ui.toast("Room cleared", 1.5)


# ----------------------------------------------------------------- selection

func _select(item: FurnitureItem) -> void:
	selected = item
	ui.set_selection(item)
	if item == null:
		marker.clear()
	else:
		marker.follow(item)


# ------------------------------------------------------------------ geometry

func _items() -> Array[FurnitureItem]:
	var out: Array[FurnitureItem] = []
	for child in items_root.get_children():
		if child is FurnitureItem:
			out.append(child as FurnitureItem)
	return out


func _clear_items() -> void:
	for item in _items():
		items_root.remove_child(item)
		item.queue_free()


## Keeps an item's footprint inside the room walls.
func _clamp_to_room(item: FurnitureItem, desired: Vector3) -> Vector3:
	var footprint := item.footprint()
	var yaw: float = item.rotation.y
	var c: float = absf(cos(yaw))
	var s: float = absf(sin(yaw))
	var half_x: float = (footprint.x * c + footprint.y * s) * 0.5
	var half_z: float = (footprint.x * s + footprint.y * c) * 0.5

	# The footprint centre is not always the node origin.
	var previous := item.global_position
	item.global_position = desired
	var center := item.footprint_center()
	item.global_position = previous
	var offset := Vector2(center.x - desired.x, center.y - desired.z)

	var bounds := room.bounds()
	var limit_x: float = maxf(bounds.size.x * 0.5 - half_x, 0.0)
	var limit_z: float = maxf(bounds.size.y * 0.5 - half_z, 0.0)

	var clamped_center := Vector2(
		clampf(desired.x + offset.x, -limit_x, limit_x),
		clampf(desired.z + offset.y, -limit_z, limit_z)
	)
	return Vector3(clamped_center.x - offset.x, desired.y, clamped_center.y - offset.y)


## Nudges a freshly added item along a spiral until it stops overlapping.
func _find_free_spot(item: FurnitureItem) -> Vector3:
	var start := item.global_position
	if not _overlaps_any(item):
		return start
	var others := _items()
	for ring in range(1, 13):
		var radius: float = ring * GRID_SNAP * 2.0
		for step in 8:
			var angle: float = TAU * float(step) / 8.0
			var candidate := Vector3(
				start.x + cos(angle) * radius,
				0.0,
				start.z + sin(angle) * radius
			)
			if snap_enabled:
				candidate.x = snappedf(candidate.x, GRID_SNAP)
				candidate.z = snappedf(candidate.z, GRID_SNAP)
			item.global_position = _clamp_to_room(item, candidate)
			if not _overlaps_any(item, others):
				return item.global_position
	item.global_position = _clamp_to_room(item, start)
	return item.global_position


## Rugs (very low) and items resting on top of other furniture are exempt from
## the overlap warning.
func _ignores_overlap(item: FurnitureItem) -> bool:
	return item.item_height() < FLAT_ITEM_HEIGHT or item.position.y > 0.05


func _overlaps_any(item: FurnitureItem, others: Array[FurnitureItem] = []) -> bool:
	if _ignores_overlap(item):
		return false
	var list := others if not others.is_empty() else _items()
	var corners := item.footprint_corners()
	for other in list:
		if other == item or _ignores_overlap(other):
			continue
		if _rects_overlap(corners, other.footprint_corners()):
			return true
	return false


func _update_overlaps() -> void:
	var list := _items()
	var corners: Array[PackedVector2Array] = []
	for item in list:
		corners.append(item.footprint_corners())
	for i in list.size():
		var blocked := false
		if not _ignores_overlap(list[i]):
			for j in list.size():
				if i == j or _ignores_overlap(list[j]):
					continue
				if _rects_overlap(corners[i], corners[j]):
					blocked = true
					break
		list[i].set_blocked(blocked)
	if selected != null:
		marker.set_blocked(selected.is_blocked())


## Separating-axis test between two oriented rectangles on the floor plane.
static func _rects_overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() < 4 or b.size() < 4:
		return false
	for polygon in [a, b]:
		for i in 4:
			var edge: Vector2 = polygon[(i + 1) % 4] - polygon[i]
			if edge.length_squared() < 0.000001:
				continue
			var axis := Vector2(-edge.y, edge.x).normalized()
			var a_range := _project_range(a, axis)
			var b_range := _project_range(b, axis)
			# A small tolerance lets items sit flush against each other.
			if a_range.y <= b_range.x + 0.02 or b_range.y <= a_range.x + 0.02:
				return false
	return true


static func _project_range(polygon: PackedVector2Array, axis: Vector2) -> Vector2:
	var lo := INF
	var hi := -INF
	for point in polygon:
		var value := point.dot(axis)
		lo = minf(lo, value)
		hi = maxf(hi, value)
	return Vector2(lo, hi)


# -------------------------------------------------------- save / load / seed

func _serialize() -> Dictionary:
	var item_data: Array = []
	for item in _items():
		item_data.append(item.to_dict())
	return {
		"room": {
			"w": snappedf(room.width, 0.01),
			"d": snappedf(room.depth, 0.01),
			"h": snappedf(room.height, 0.01),
			"floor": _floor_color.to_html(false),
			"wall": _wall_color.to_html(false),
		},
		"items": item_data,
	}


func _restore(data: Dictionary) -> bool:
	if data.is_empty() or not data.has("items"):
		return false

	_select(null)
	_clear_items()

	var room_data: Dictionary = data.get("room", {})
	var w := float(room_data.get("w", 6.0))
	var d := float(room_data.get("d", 5.0))
	var h := float(room_data.get("h", 2.6))
	_floor_color = _color_or(room_data.get("floor", ""), DesignerUI.FLOOR_SWATCHES[0])
	_wall_color = _color_or(room_data.get("wall", ""), DesignerUI.WALL_SWATCHES[0])
	room.configure(w, d, h)
	room.set_floor_color(_floor_color)
	room.set_wall_color(_wall_color)
	ui.set_room_values(room.width, room.depth, room.height, _floor_color, _wall_color)
	rig.pan_limit = Vector2(room.width * 0.6, room.depth * 0.6)

	for entry: Variant in data["items"]:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item := FurnitureItem.from_dict(entry)
		if item == null:
			continue
		items_root.add_child(item)
		item.global_position = _clamp_to_room(item, item.global_position)

	_update_overlaps()
	_refresh_stats()
	return true


static func _color_or(value: Variant, fallback: Color) -> Color:
	var text := str(value)
	if text != "" and Color.html_is_valid(text):
		return Color.html(text)
	return fallback


## A small furnished room so the app never opens on an empty floor.
func _seed_starter_room() -> void:
	var seeds := [
		{"id": "rug", "pos": Vector2(-1.2, 0.30), "rot": 0.0},
		{"id": "sofa", "pos": Vector2(-1.2, -0.75), "rot": 0.0},
		{"id": "coffee_table", "pos": Vector2(-1.2, 0.45), "rot": 0.0},
		{"id": "tv_stand", "pos": Vector2(-1.2, 1.85), "rot": 180.0},
		{"id": "television", "pos": Vector2(-1.2, 1.85), "rot": 180.0},
		{"id": "armchair", "pos": Vector2(0.70, 0.75), "rot": -80.0},
		{"id": "floor_lamp", "pos": Vector2(-2.60, -1.90), "rot": 0.0},
		{"id": "plant", "pos": Vector2(-2.60, 1.90), "rot": 0.0},
		{"id": "bookshelf", "pos": Vector2(2.60, -1.60), "rot": -90.0},
		{"id": "dining_table", "pos": Vector2(1.60, -0.60), "rot": 0.0},
		{"id": "chair", "pos": Vector2(1.60, -1.45), "rot": 180.0},
		{"id": "chair", "pos": Vector2(0.45, -0.60), "rot": 90.0},
	]
	for seed_data: Dictionary in seeds:
		var item := FurnitureItem.new()
		item.setup(seed_data["id"])
		items_root.add_child(item)
		item.rotation.y = deg_to_rad(seed_data["rot"])
		var spot: Vector2 = seed_data["pos"]
		item.global_position = _clamp_to_room(item, Vector3(spot.x, 0.0, spot.y))
	# The TV sits on its stand rather than on the floor.
	for item in _items():
		if item.item_id == "television":
			item.position.y = 0.52
	_update_overlaps()


func _refresh_stats() -> void:
	ui.set_stats(_items().size(), room.area())


func _mark_dirty() -> void:
	_dirty = true
	_autosave()


func _autosave() -> void:
	if not _dirty:
		return
	_dirty = false
	LayoutStore.save_autosave(_serialize())


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			_dirty = true
			_autosave()
			get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED:
			_dirty = true
			_autosave()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android back button: unwind one level at a time.
			if ui.is_modal_open():
				ui.close_dialog()
			elif selected != null:
				_select(null)
			else:
				_dirty = true
				_autosave()
				get_tree().quit()
