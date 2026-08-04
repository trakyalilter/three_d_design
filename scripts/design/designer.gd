class_name RoomDesigner
extends Node3D
## The room you actually work in.
##
## Runs either as a paid job — where the client's brief has to be satisfied and
## every piece of furniture is bought out of the player's own money — or as a
## free-build sandbox with no bill and nothing to prove.

signal job_finished(house_id: String)
signal left()

const GRID_SNAP := 0.25
const ROTATE_STEP := 15.0
const SCALE_STEP := 0.1
const TAP_SLOP := 16.0
const FLAT_ITEM_HEIGHT := 0.12

enum Gesture { NONE, ORBIT, ITEM, PINCH }

var house_id: String = ""
var job: Dictionary = {}

var room: Room
var rig: CameraRig
var marker: SelectionMarker
var ui: DesignerUI
var items_root: Node3D

var selected: FurnitureItem = null
var snap_enabled := true

var _history := DesignHistory.new()

var _touches: Dictionary = {}
var _touch_origins: Dictionary = {}
var _gesture: int = Gesture.NONE
var _drag_offset := Vector3.ZERO
var _drag_moved := false
var _pinch_distance := 0.0
var _pinch_midpoint := Vector2.ZERO
var _pinch_angle := 0.0
## True when a two-finger gesture started over the selected piece, in which
## case it turns and resizes that piece instead of moving the camera.
var _pinch_on_item := false
var _last_tap_time := 0.0
var _last_tap_position := Vector2.ZERO
var _floor_color: Color = Catalog.PAINT["floor"][0]["color"]
var _wall_color: Color = Catalog.PAINT["wall"][0]["color"]
## Which room of the plan the paint tools act on. Empty means the whole floor,
## which is the only option a single-room job ever has.
var _paint_target := ""


func job_mode() -> bool:
	return house_id != ""


## Called before the designer enters the tree. An empty id means free build.
func setup(id: String) -> void:
	house_id = id
	job = Jobs.get_job(id) if id != "" else {}


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
	ui.configure(job)

	_start_room()
	_history.reset(_serialize())
	_refresh_stats()
	_evaluate()
	_sync_history_buttons()

	if job_mode():
		ui.toast("%s — tap Brief to see what %s wants" % [job["name"], job["client"]], 4.0)
	else:
		ui.toast("Free build: everything is unlocked and nothing costs anything", 3.5)


## Sets the room up and restores whatever was left here last time.
func _start_room() -> void:
	var saved: Dictionary = Game.layout_for(house_id) if job_mode() else LayoutStore.load_autosave()

	if job_mode():
		var spec: Dictionary = job["room"]
		if job.has("rooms"):
			room.configure_plan(job["rooms"], float(spec["h"]))
		else:
			room.configure(float(spec["w"]), float(spec["d"]), float(spec["h"]))
	else:
		room.configure(6.0, 5.0, 2.6)

	if not saved.is_empty():
		_restore(saved)
	else:
		room.set_floor_color(_floor_color)
		room.set_wall_color(_wall_color)
		if not job_mode():
			_seed_starter_room()

	ui.set_room_values(room.width, room.depth, room.height)
	rig.frame_room(room.width, room.depth)
	rig.snap_to_target()


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
	ui.floor_paint_selected.connect(_on_floor_paint)
	ui.wall_paint_selected.connect(_on_wall_paint)
	ui.paint_target_changed.connect(_on_paint_target)
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
	ui.finish_requested.connect(_on_finish)
	ui.leave_requested.connect(_on_leave)


func _process(_delta: float) -> void:
	if rig.camera:
		room.update_wall_visibility(rig.camera.global_position, rig.focus)


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
			if was_tap:
				_handle_tap(event.position, was_orbit)
			if _drag_moved and (_gesture == Gesture.ITEM or _pinch_on_item):
				# One history entry per gesture, not per frame of it.
				_after_change()
			_gesture = Gesture.NONE
			_drag_moved = false
			_pinch_on_item = false
		elif _gesture == Gesture.PINCH and _touches.size() < 2:
			# Keep the remaining finger inert until it is lifted, so the camera
			# does not snap when one finger leaves a pinch.
			_gesture = Gesture.NONE


## A tap on empty space clears the selection; a double tap anywhere brings the
## camera round to what was tapped.
func _handle_tap(position: Vector2, on_empty_space: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var double_tap: bool = (now - _last_tap_time) < 0.35 \
		and _last_tap_position.distance_to(position) < 48.0
	_last_tap_time = now
	_last_tap_position = position

	if double_tap:
		var hit := _pick_item(position)
		var focus := Vector3(hit.footprint_center().x, 0.0, hit.footprint_center().y) \
			if hit != null else _floor_point(position)
		rig.focus = Vector3(
			clampf(focus.x, -rig.pan_limit.x, rig.pan_limit.x),
			0.0,
			clampf(focus.z, -rig.pan_limit.y, rig.pan_limit.y)
		)
		rig.distance = clampf(rig.distance * 0.7, rig.min_distance, rig.max_distance)
		_last_tap_time = 0.0
		return

	if on_empty_space:
		_select(null)


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
	_pinch_angle = (points[1] - points[0]).angle()
	_pinch_on_item = selected != null and _pick_item(_pinch_midpoint) == selected


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
	var angle := (points[1] - points[0]).angle()

	if _pinch_on_item and selected != null:
		# Twisting two fingers over a piece turns it; spreading them resizes it.
		# Screen angles grow clockwise, world yaw grows anticlockwise from above.
		selected.rotation.y -= angle_difference(_pinch_angle, angle)
		if _pinch_distance > 1.0 and distance > 1.0:
			selected.set_item_scale(selected.scale_factor * (distance / _pinch_distance))
		selected.global_position = _clamp_to_room(selected, selected.global_position)
		ui.set_selection(selected)
		_update_overlaps()
		marker.follow(selected)
		_drag_moved = true
	else:
		if _pinch_distance > 1.0 and distance > 1.0:
			rig.zoom(_pinch_distance / distance)
		rig.pan(midpoint - _pinch_midpoint)

	_pinch_distance = distance
	_pinch_midpoint = midpoint
	_pinch_angle = angle


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
	target.y = 0.0
	if snap_enabled:
		target.x = snappedf(target.x, GRID_SNAP)
		target.z = snappedf(target.z, GRID_SNAP)
	target = _snap_to_walls(selected, target)
	target = _clamp_to_room(selected, target)
	# Small pieces ride on whatever they are dropped over.
	target.y = _support_height(selected, target)
	selected.global_position = target
	selected.set_elevated(target.y > 0.05)
	_drag_moved = true
	_update_overlaps()
	marker.follow(selected)
	_evaluate()


## Pulls a piece flush against a wall when it comes close, and turns its back
## to that wall if it was already roughly facing the right way.
func _snap_to_walls(item: FurnitureItem, desired: Vector3) -> Vector3:
	if not snap_enabled:
		return desired

	const REACH := 0.42
	var footprint := item.footprint()

	# Work out which wall is in reach using the rotation the piece has now.
	var half := _half_extents(footprint, item.rotation.y)
	var probe := Vector2(desired.x, desired.z) + _center_offset(item, desired)
	# The walls that matter are the ones around the room it is currently in.
	var rect := room.rect_at(probe)
	var middle := rect.position + rect.size * 0.5
	var room_x: float = rect.size.x * 0.5
	var room_z: float = rect.size.y * 0.5
	# Yaw that puts the piece's back (its local -Z) against each wall.
	var near_x := INF
	var near_z := INF
	if absf((probe.x - half.x) - (middle.x - room_x)) < REACH:
		near_x = deg_to_rad(90.0)
	elif absf((probe.x + half.x) - (middle.x + room_x)) < REACH:
		near_x = deg_to_rad(-90.0)
	if absf((probe.y - half.y) - (middle.y - room_z)) < REACH:
		near_z = 0.0
	elif absf((probe.y + half.y) - (middle.y + room_z)) < REACH:
		near_z = PI

	# Straighten first, but only a piece that is already close to square with
	# the wall, so a deliberate angle is never yanked away. A corner prefers the
	# longer wall behind it, which is the one on Z.
	var facing: float = near_z if near_z != INF else near_x
	if facing != INF and absf(angle_difference(item.rotation.y, facing)) < deg_to_rad(38.0):
		item.rotation.y = facing

	# Then place it flush, using whatever rotation it ended up with — the
	# extents change when it turns, so this has to come second.
	half = _half_extents(footprint, item.rotation.y)
	var offset := _center_offset(item, desired)
	var cx: float = desired.x + offset.x
	var cz: float = desired.z + offset.y
	if near_x == deg_to_rad(90.0):
		cx = middle.x - room_x + half.x
	elif near_x == deg_to_rad(-90.0):
		cx = middle.x + room_x - half.x
	if near_z == 0.0:
		cz = middle.y - room_z + half.y
	elif near_z == PI:
		cz = middle.y + room_z - half.y

	return Vector3(cx - offset.x, desired.y, cz - offset.y)


## Half the width and depth a footprint covers once turned by `yaw`.
static func _half_extents(footprint: Vector2, yaw: float) -> Vector2:
	var c: float = absf(cos(yaw))
	var s: float = absf(sin(yaw))
	return Vector2(
		(footprint.x * c + footprint.y * s) * 0.5,
		(footprint.x * s + footprint.y * c) * 0.5
	)


## How far the footprint centre sits from the node origin, in world XZ.
func _center_offset(item: FurnitureItem, at: Vector3) -> Vector2:
	var previous := item.global_position
	item.global_position = at
	var center := item.footprint_center()
	item.global_position = previous
	return Vector2(center.x - at.x, center.y - at.z)


## The height a piece should sit at: the top of whatever it is over, or the
## floor.
func _support_height(item: FurnitureItem, at: Vector3) -> float:
	if not Catalog.is_stackable(item.item_id):
		return 0.0
	var point := Vector2(at.x, at.z) + _center_offset(item, at)
	var headroom: float = room.height - Catalog.height(item.item_id) * item.scale_factor
	var best := 0.0
	for other in _items():
		if other == item or Catalog.surface_height(other.item_id) <= 0.0:
			continue
		if not Geometry2D.is_point_in_polygon(point, other.footprint_corners()):
			continue
		var top: float = other.position.y + Catalog.surface_height(other.item_id) * other.scale_factor
		# A tall piece on a tall shelf would stick out through the wall, so it
		# stays on the floor instead.
		if top > headroom:
			continue
		best = maxf(best, top)
	return best


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
	if job_mode():
		if not Game.is_item_unlocked(item_id):
			ui.toast("That needs level %d" % Catalog.effective_unlock_level(item_id), 2.0)
			return
		if not Game.take_from_stock(item_id):
			ui.toast("None in stock — buy one at %s" % Catalog.shop_name(Catalog.shop_of(item_id)), 2.6)
			return

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
	_after_change()
	if job_mode():
		ui.toast("%s placed — %d left in stock" % [
			Catalog.display_name(item_id), Game.stock_of(item_id)], 1.6)
	else:
		ui.toast("%s added — drag it to move" % Catalog.display_name(item_id), 1.6)


func _on_command(name: String) -> void:
	# History works with nothing selected; everything else needs a selection.
	if name == "undo":
		_on_undo()
		return
	if name == "redo":
		_on_redo()
		return
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
			_store_selected()
			return
		"deselect":
			_select(null)
			return
	selected.global_position = _clamp_to_room(selected, selected.global_position)
	ui.set_selection(selected)
	_update_overlaps()
	marker.follow(selected)
	_after_change()


## Takes a piece out of the room. It goes back to the warehouse rather than
## being destroyed, so nothing the player paid for is ever lost.
func _store_selected() -> void:
	if selected == null:
		return
	var doomed := selected
	var item_id := doomed.item_id
	var label := Catalog.display_name(item_id)
	_select(null)
	items_root.remove_child(doomed)
	doomed.queue_free()
	if job_mode():
		Game.return_to_stock(item_id)
		ui.toast("%s back in stock (%d)" % [label, Game.stock_of(item_id)], 1.6)
	else:
		ui.toast("%s removed" % label, 1.4)
	_update_overlaps()
	_after_change()


func _duplicate_selected() -> void:
	if selected == null:
		return
	var item_id := selected.item_id
	if job_mode() and not Game.take_from_stock(item_id):
		ui.toast("No more %s in stock" % Catalog.display_name(item_id), 2.2)
		return
	var copy := FurnitureItem.from_dict(selected.to_dict())
	if copy == null:
		return
	items_root.add_child(copy)
	copy.global_position = _find_free_spot(copy)
	_select(copy)
	_after_change()
	ui.toast("Duplicated", 1.2)


func _on_tint_selected(color: Color) -> void:
	if selected == null:
		return
	selected.set_tint(color)
	selected.set_blocked(selected.is_blocked())
	_after_change()


func _on_room_changed(width: float, room_depth: float, height: float) -> void:
	if job_mode():
		return
	room.configure(width, room_depth, height)
	room.set_floor_color(_floor_color)
	room.set_wall_color(_wall_color)
	rig.pan_limit = Vector2(room.width * 0.6, room.depth * 0.6)
	for item in _items():
		item.global_position = _clamp_to_room(item, item.global_position)
	_update_overlaps()
	_after_change()


func _on_floor_paint(color: Color) -> void:
	if not _may_paint("floor", color):
		return
	if _paint_target == "":
		_floor_color = color
	room.set_floor_color(color, _paint_target)
	_announce_paint("Floor", color)
	_after_change()


func _on_wall_paint(color: Color) -> void:
	if not _may_paint("wall", color):
		return
	if _paint_target == "":
		_wall_color = color
	room.set_wall_color(color, _paint_target)
	_announce_paint("Walls", color)
	_after_change()


## The paint tools act on one room at a time in a flat, so say which.
func _announce_paint(what: String, _color: Color) -> void:
	if not room.is_multi_room():
		return
	var where := room.room_name(_paint_target).to_lower() if _paint_target != "" else "every room"
	ui.toast("%s painted in %s" % [what, where], 1.6)


func _on_paint_target(room_id: String) -> void:
	_paint_target = room_id if room.has_room(room_id) else ""


## Colours are bought once at the Colour House; using one costs nothing.
func _may_paint(surface: String, color: Color) -> bool:
	if not job_mode() or Game.owns_color(surface, color):
		return true
	var entry := Game.paint_entry_for(surface, color)
	var label := str(entry.get("name", "That colour"))
	ui.toast("%s is not in your paint store — buy it at the Colour House" % label, 2.8)
	return false


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
	_restore(data)
	ui.set_room_values(room.width, room.depth, room.height)
	ui.toast("Opened \"%s\"" % layout_name, 1.8)
	_after_change()


func _on_delete_layout(layout_name: String) -> void:
	LayoutStore.delete_layout(layout_name)
	ui.toast("Deleted \"%s\"" % layout_name, 1.8)


func _on_new_requested() -> void:
	_select(null)
	if job_mode():
		var returned := 0
		for item in _items():
			Game.return_to_stock(item.item_id)
			returned += 1
		ui.toast("%d piece%s back in stock" % [returned, "" if returned == 1 else "s"], 2.2)
	else:
		ui.toast("Room cleared", 1.5)
	_clear_items()
	_after_change()


# --------------------------------------------------------- job hand-over

func _on_finish() -> void:
	if not job_mode():
		return
	var results := Jobs.evaluate(house_id, _context())
	if not Jobs.all_met(results):
		ui.toast("The brief is not finished yet", 2.2)
		return

	# The furniture standing in the room is what the job actually costs: it
	# stays with the client.
	var installed := installed_value()
	var payout := int(job["payout"])
	var review := RoomReview.score(_review_entries(), room.area(), installed, int(job["budget"]))
	var bonus := int(round(float(payout) * float(review["bonus_rate"])))
	# A well-judged room is worth more experience too.
	var xp_reward := int(round(float(job["xp"]) * (0.8 + 0.2 * float(review["stars"]))))

	var result := Game.record_completion(house_id, payout, bonus, xp_reward, installed, int(review["stars"]))
	Game.store_layout(house_id, _serialize())
	ui.show_completion(job, result, review, func() -> void: job_finished.emit(house_id))


## What the reviewer needs to know about each piece standing in the room. A
## piece is judged against the walls of the room it is actually in, so a sofa
## against the living room's divider counts as against a wall.
func _review_entries() -> Array:
	var entries: Array = []
	for item in _items():
		var half := _half_extents(item.footprint(), item.rotation.y)
		var centre := item.footprint_center()
		var rect := room.rect_at(centre)
		var gap: float = minf(
			minf(centre.x - half.x - rect.position.x, rect.end.x - (centre.x + half.x)),
			minf(centre.y - half.y - rect.position.y, rect.end.y - (centre.y + half.y))
		)
		var footprint := item.footprint()
		entries.append({
			"id": item.item_id,
			"tint": item.tint,
			"blocked": item.is_blocked(),
			"wall_gap": maxf(gap, 0.0),
			"area": footprint.x * footprint.y,
		})
	return entries


## Retail value of everything currently standing in the room.
func installed_value() -> int:
	var total := 0
	for item in _items():
		total += Catalog.price(item.item_id)
	return total


func _on_leave() -> void:
	_persist()
	left.emit()


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


## Keeps an item's footprint inside the walls of whichever room of the plan it
## is being dropped into. Dragging a piece across a dividing wall moves it to
## the room on the other side rather than stopping at the wall — threading a
## doorway with a fingertip is not a game.
func _clamp_to_room(item: FurnitureItem, desired: Vector3) -> Vector3:
	var half := _half_extents(item.footprint(), item.rotation.y)
	var offset := _center_offset(item, desired)
	var centre := Vector2(desired.x + offset.x, desired.z + offset.y)
	var rect := room.rect_at(centre)

	var limit_x: float = maxf(rect.size.x * 0.5 - half.x, 0.0)
	var limit_z: float = maxf(rect.size.y * 0.5 - half.y, 0.0)
	var middle := rect.position + rect.size * 0.5

	var clamped := Vector2(
		clampf(centre.x, middle.x - limit_x, middle.x + limit_x),
		clampf(centre.y, middle.y - limit_z, middle.y + limit_z)
	)
	return Vector3(clamped.x - offset.x, desired.y, clamped.y - offset.y)


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


# ------------------------------------------------------------- brief tracking

## What the job evaluator needs to know about the room as it stands.
func _context() -> Dictionary:
	var entries: Array = []
	for item in _items():
		entries.append({
			"id": item.item_id,
			"tint": item.tint,
			"blocked": item.is_blocked(),
			# Which room of the plan it is standing in, for briefs that care.
			"room": room.room_id_at(item.footprint_center()),
		})
	return {
		"items": entries,
		"room": {
			"w": room.width, "d": room.depth, "h": room.height,
			"floor": _floor_color, "wall": _wall_color,
			# Per room, for briefs that ask for a colour in one of them.
			"floors": room.floor_colors.duplicate(),
			"walls": room.wall_colors.duplicate(),
		},
		"spend": installed_value(),
	}


func _evaluate() -> void:
	if not job_mode():
		return
	ui.set_requirements(Jobs.evaluate(house_id, _context()))
	ui.refresh_bill(installed_value())


## Everything that has to happen after the room changes in any way.
func _after_change() -> void:
	_history.record(_serialize())
	_sync_history_buttons()
	_refresh_stats()
	_evaluate()
	_persist()


func _sync_history_buttons() -> void:
	ui.set_history_available(_history.can_undo(), _history.can_redo())


func _on_undo() -> void:
	_step_history(_history.undo(), "Undone")


func _on_redo() -> void:
	_step_history(_history.redo(), "Redone")


## Restores a snapshot and moves furniture between the room and the warehouse
## so the stock count still matches what is standing here.
func _step_history(state: Dictionary, label: String) -> void:
	if state.is_empty():
		return
	var before := _item_counts()
	_select(null)
	_restore(state)
	var after := _item_counts()

	if job_mode():
		var ids: Dictionary = {}
		for id: String in before:
			ids[id] = true
		for id: String in after:
			ids[id] = true
		for id: String in ids:
			var delta: int = int(after.get(id, 0)) - int(before.get(id, 0))
			if delta > 0:
				for i in delta:
					Game.take_from_stock(id)
			elif delta < 0:
				Game.return_to_stock(id, -delta)

	_sync_history_buttons()
	_refresh_stats()
	_evaluate()
	_persist()
	ui.toast(label, 1.0)


func _item_counts() -> Dictionary:
	var counts: Dictionary = {}
	for item in _items():
		counts[item.item_id] = int(counts.get(item.item_id, 0)) + 1
	return counts


func _refresh_stats() -> void:
	ui.set_stats(_items().size(), room.area())


func _persist() -> void:
	if job_mode():
		Game.store_layout(house_id, _serialize())
	else:
		LayoutStore.save_autosave(_serialize())


# --------------------------------------------------------- save / load / seed

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
			"floors": _colors_to_html(room.floor_colors),
			"walls": _colors_to_html(room.wall_colors),
		},
		"items": item_data,
	}


func _restore(data: Dictionary) -> void:
	if data.is_empty() or not data.has("items"):
		return

	_select(null)
	_clear_items()

	var room_data: Dictionary = data.get("room", {})
	_floor_color = _color_or(room_data.get("floor", ""), Catalog.PAINT["floor"][0]["color"])
	_wall_color = _color_or(room_data.get("wall", ""), Catalog.PAINT["wall"][0]["color"])
	if not job_mode():
		room.configure(
			float(room_data.get("w", 6.0)),
			float(room_data.get("d", 5.0)),
			float(room_data.get("h", 2.6))
		)
	room.set_floor_color(_floor_color)
	room.set_wall_color(_wall_color)
	# Rooms painted individually override the flat-wide colour.
	for room_id: String in room_data.get("floors", {}):
		room.set_floor_color(_color_or(room_data["floors"][room_id], _floor_color), room_id)
	for room_id: String in room_data.get("walls", {}):
		room.set_wall_color(_color_or(room_data["walls"][room_id], _wall_color), room_id)
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


static func _colors_to_html(colors: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for room_id: String in colors:
		out[room_id] = (colors[room_id] as Color).to_html(false)
	return out


static func _color_or(value: Variant, fallback: Color) -> Color:
	var text := str(value)
	if text != "" and Color.html_is_valid(text):
		return Color.html(text)
	return fallback


## A small furnished room so free build never opens on an empty floor.
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


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_persist()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android back button: unwind one level at a time.
			if ui.is_modal_open():
				ui.close_dialog()
			elif ui.is_catalog_open():
				ui.set_catalog_open(false)
			elif selected != null:
				_select(null)
			else:
				_on_leave()
