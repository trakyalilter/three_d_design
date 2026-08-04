class_name ShopFloor
extends Node3D
## The inside of a shop.
##
## Tapping a counter on the map used to open a list of names and prices. This
## is the shop itself: you walk in, the stock is standing on the floor where
## you can look at it, and you buy the piece you are looking at.
##
## Built the same way as everything else — the fixtures are welded into a
## SceneryBatch, and the stock is real FurnitureItem nodes because each one has
## to be picked, lit and looked at from any side. A parade shop holds a dozen
## pieces, so that is a dozen nodes rather than the two hundred a room can hold.

signal left()
signal picked(item_id: String)
signal picked_paint(surface: String, entry: Dictionary)
signal nothing_picked()

## Aisle layout. Stock stands in rows across the floor, front to back.
const AISLE_X := 2.35
const ROW_Z := 2.30
const PER_ROW := 4

## The shell. Deep enough for four rows and open at the front, so the camera
## can look in without the near wall being in the way.
const WIDTH := 11.0
const DEPTH := 12.0
const HEIGHT := 3.4

var shop: Dictionary = {}
var rig: CameraRig
var marker: SelectionMarker

var _batch: SceneryBatch
var _fixtures: Node3D
var _tickets: Node3D
var _stock: Node3D
var _selected: FurnitureItem = null
## Paint tins are not catalogue pieces, so they are plain bodies with the
## palette entry hung off them as metadata.
var _tins: Node3D
var _selected_tin: Node3D = null
var _tin_glow: MeshInstance3D

var _touches: Dictionary = {}
var _touch_origins: Dictionary = {}
var _pinch_distance := 0.0
var _gesture_is_pinch := false
var _dragged := false
## Set by the owner so gestures that start on a panel are ignored.
var ui_probe: Callable = Callable()

## Set before the node enters the tree when the caller drives the build itself,
## a stage at a time, behind a loading screen.
var staged_build := false


func setup(shop_id: String) -> void:
	shop = Catalog.get_shop(shop_id)


func _ready() -> void:
	if staged_build:
		set_process_unhandled_input(false)
		return
	for stage: Array in build_stages():
		(stage[1] as Callable).call()


## The build, in the same shape the city and the designer use.
func build_stages() -> Array:
	return [
		["Opening up", _build_shell],
		["Dressing the shop", _build_fixtures],
		["Putting the stock out", _stock_the_floor],
		["Turning the sign round", _open_up],
	]


func is_paint_shop() -> bool:
	return str(shop.get("id", "")) == "paint"


# ------------------------------------------------------------------ the shell

func _build_shell() -> void:
	_build_environment()

	_fixtures = Node3D.new()
	_fixtures.name = "Fixtures"
	add_child(_fixtures)

	_tickets = Node3D.new()
	_tickets.name = "Tickets"
	add_child(_tickets)

	_stock = Node3D.new()
	_stock.name = "Stock"
	add_child(_stock)

	_tins = Node3D.new()
	_tins.name = "Tins"
	add_child(_tins)

	marker = SelectionMarker.new()
	marker.name = "SelectionMarker"
	add_child(marker)

	rig = CameraRig.new()
	rig.name = "CameraRig"
	rig.yaw = -14.0
	rig.pitch = -25.0
	rig.distance = 12.6
	rig.min_distance = 4.5
	rig.max_distance = 18.0
	rig.pan_limit = Vector2(WIDTH * 0.5, DEPTH * 0.5)
	add_child(rig)


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	# A shop has no sky worth seeing, and a flat backdrop keeps the eye on the
	# stock. The tint follows the shop's own colour, well drained.
	var accent: Color = shop.get("color", Color(0.6, 0.6, 0.6))
	env.background_color = accent.lerp(Color(0.10, 0.11, 0.14), 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.74, 0.76, 0.80)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.9
	world.environment = env
	add_child(world)

	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.rotation = Vector3(deg_to_rad(-58.0), deg_to_rad(-32.0), 0.0)
	key.light_energy = 0.95
	key.light_color = Color(1.0, 0.98, 0.94)
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 28.0
	key.shadow_bias = 0.03
	key.shadow_normal_bias = 1.1
	key.shadow_blur = 1.3
	key.shadow_opacity = 0.66
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation = Vector3(deg_to_rad(-24.0), deg_to_rad(148.0), 0.0)
	fill.light_energy = 0.26
	fill.light_color = Color(0.84, 0.90, 1.0)
	add_child(fill)


# --------------------------------------------------------------- the fittings

## Floor, walls, counter, shelving and signage. Everything that is not for
## sale, welded into one batch.
func _build_fixtures() -> void:
	_batch = SceneryBatch.new()
	var accent: Color = shop.get("color", Color(0.6, 0.6, 0.6))

	var half_w := WIDTH * 0.5
	var half_d := DEPTH * 0.5
	var floor_colour := Color(0.80, 0.78, 0.75)
	var wall := Color(0.90, 0.89, 0.87)

	# Floor, with a border band in the shop's colour and a runner up the middle.
	_batch.box(floor_colour, Vector3(WIDTH, 0.2, DEPTH), Vector3(0, -0.1, 0))
	_batch.box(accent.lerp(floor_colour, 0.55), Vector3(WIDTH, 0.02, 0.5), Vector3(0, 0.01, -half_d + 0.6))
	_batch.box(accent.lerp(floor_colour, 0.78), Vector3(2.0, 0.02, DEPTH - 2.4), Vector3(0, 0.012, 0.6))

	# Three walls. The front is left open so the camera can see in.
	_batch.box(wall, Vector3(WIDTH, HEIGHT, 0.24), Vector3(0, HEIGHT * 0.5, -half_d))
	for sx in [-1.0, 1.0]:
		_batch.box(wall.darkened(0.04), Vector3(0.24, HEIGHT, DEPTH), Vector3(sx * half_w, HEIGHT * 0.5, 0))
	# Skirting, so the wall does not meet the floor in a hard line.
	_batch.box(wall.darkened(0.22), Vector3(WIDTH, 0.18, 0.30), Vector3(0, 0.09, -half_d + 0.02))

	# A band of the shop's colour across the back wall, with the trade on it.
	_batch.box(accent, Vector3(WIDTH - 1.0, 0.9, 0.10), Vector3(0, HEIGHT - 0.85, -half_d + 0.14))
	_batch.box(accent.darkened(0.3), Vector3(WIDTH - 1.0, 0.08, 0.12), Vector3(0, HEIGHT - 1.34, -half_d + 0.15))

	_build_counter(accent)
	_build_shelving(wall, accent)
	_build_window_line(accent)
	_build_lights()
	_build_plants()

	_batch.commit(_fixtures)
	_batch = null

	_build_sign()


## The counter down the left of the shop, with a till on it.
func _build_counter(accent: Color) -> void:
	var half_w := WIDTH * 0.5
	var wood := Color(0.52, 0.38, 0.26)
	var top := Color(0.30, 0.31, 0.34)
	var at := Vector3(-half_w + 1.5, 0, -DEPTH * 0.5 + 2.6)

	_batch.box(wood, Vector3(2.2, 1.05, 0.85), at + Vector3(0, 0.52, 0))
	_batch.box(top, Vector3(2.35, 0.08, 1.0), at + Vector3(0, 1.08, 0))
	_batch.box(accent, Vector3(2.2, 0.10, 0.87), at + Vector3(0, 0.20, 0))

	# Till: a wedge with a screen and a drawer.
	_batch.box(Color(0.90, 0.90, 0.88), Vector3(0.52, 0.26, 0.42), at + Vector3(0.5, 1.25, 0))
	_batch.box(Color(0.16, 0.18, 0.22), Vector3(0.46, 0.34, 0.06),
		at + Vector3(0.5, 1.52, -0.16), SceneryBatch.Layer.SHINY,
		Basis(Vector3.RIGHT, deg_to_rad(-18.0)))
	# A stack of catalogues and a plant pot on the other end.
	for i in 3:
		_batch.box(Color(0.86, 0.82, 0.72).darkened(float(i) * 0.06),
			Vector3(0.34, 0.035, 0.26), at + Vector3(-0.62, 1.14 + float(i) * 0.04, 0.06))


## Wall shelving down the right, with a few boxes on it. Just dressing — the
## things you can buy stand on the floor where they can be walked round.
func _build_shelving(wall: Color, accent: Color) -> void:
	var half_w := WIDTH * 0.5
	var bracket := Color(0.34, 0.35, 0.38)
	for shelf in 3:
		var y := 1.05 + float(shelf) * 0.75
		_batch.box(wall.darkened(0.30), Vector3(0.42, 0.07, DEPTH - 3.0),
			Vector3(half_w - 0.34, y, 0.4))
		for z in [-2.6, 0.4, 3.4]:
			_batch.box(bracket, Vector3(0.34, 0.05, 0.06),
				Vector3(half_w - 0.36, y - 0.06, z), SceneryBatch.Layer.SHINY)
		# Stock boxes, in the shop's colours, purely so the shelves are not bare.
		for i in 4:
			var z := -2.9 + float(i) * 1.9 + float(shelf) * 0.4
			if z > DEPTH * 0.5 - 1.4:
				continue
			var tone: Color = accent.lerp(Color(0.92, 0.90, 0.86), 0.25 + float(i) * 0.16)
			_batch.box(tone, Vector3(0.30, 0.30, 0.44), Vector3(half_w - 0.34, y + 0.19, z))


## The shopfront: a low wall with glass over it, so the inside reads as a room
## you are looking into rather than a floating floor.
func _build_window_line(accent: Color) -> void:
	var half_w := WIDTH * 0.5
	var half_d := DEPTH * 0.5
	var frame := Color(0.30, 0.31, 0.35)

	# A sill and two posts, and nothing above head height. Glass across the
	# front looked right from outside and got in the way from every angle the
	# player actually uses.
	for sx in [-1.0, 1.0]:
		var x: float = sx * (half_w - 1.7)
		_batch.box(accent.darkened(0.15), Vector3(3.4, 0.62, 0.30), Vector3(x, 0.31, half_d))
		_batch.box(frame, Vector3(0.12, 1.15, 0.30), Vector3(x - 1.68, 1.20, half_d), SceneryBatch.Layer.SHINY)
		_batch.box(frame, Vector3(0.12, 1.15, 0.30), Vector3(x + 1.68, 1.20, half_d), SceneryBatch.Layer.SHINY)
		_batch.box(frame, Vector3(3.5, 0.10, 0.32), Vector3(x, 1.80, half_d), SceneryBatch.Layer.SHINY)


func _build_lights() -> void:
	var fitting := Color(0.24, 0.25, 0.28)
	var bulb := Color(1.0, 0.97, 0.86)
	for z in [-3.6, -0.6, 2.4]:
		for sx in [-1.0, 1.0]:
			var x: float = sx * 2.6
			_batch.cylinder(fitting, 0.04, 0.55, Vector3(x, HEIGHT - 0.28, z), SceneryBatch.Layer.SHINY, 6)
			_batch.cone(fitting, 0.34, 0.30, Vector3(x, HEIGHT - 0.68, z), SceneryBatch.Layer.SHINY, 10)
			_batch.box(bulb, Vector3(0.36, 0.04, 0.36), Vector3(x, HEIGHT - 0.83, z))


func _build_plants() -> void:
	var pot := Color(0.66, 0.48, 0.36)
	var leaf := Color(0.28, 0.52, 0.28)
	for spot in [Vector3(-WIDTH * 0.5 + 0.9, 0, DEPTH * 0.5 - 1.2),
			Vector3(WIDTH * 0.5 - 0.9, 0, DEPTH * 0.5 - 1.2)]:
		_batch.cylinder(pot, 0.30, 0.44, spot + Vector3(0, 0.22, 0), SceneryBatch.Layer.OPAQUE, 10)
		_batch.sphere(leaf, 0.46, spot + Vector3(0, 0.86, 0))
		_batch.sphere(leaf.darkened(0.12), 0.32, spot + Vector3(0.24, 1.16, -0.1))
		_batch.sphere(leaf.lightened(0.08), 0.28, spot + Vector3(-0.22, 1.10, 0.14))


## The shop's name over the back wall, and its tagline under it.
func _build_sign() -> void:
	var name_plate := Label3D.new()
	name_plate.text = str(shop.get("name", "The shop"))
	name_plate.font_size = 96
	name_plate.pixel_size = 0.0042
	name_plate.position = Vector3(0, HEIGHT - 0.85, -DEPTH * 0.5 + 0.22)
	name_plate.modulate = Color(0.08, 0.09, 0.12)
	name_plate.outline_size = 0
	_fixtures.add_child(name_plate)

	var tagline := Label3D.new()
	tagline.text = str(shop.get("tagline", ""))
	tagline.font_size = 40
	tagline.pixel_size = 0.0052
	tagline.width = 1400.0
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.position = Vector3(0, HEIGHT - 1.62, -DEPTH * 0.5 + 0.22)
	tagline.modulate = Color(0.36, 0.38, 0.42)
	tagline.outline_size = 0
	_fixtures.add_child(tagline)


# ---------------------------------------------------------------- the stock

## Everything the shop sells, standing on the floor in rows with a price ticket
## in front of it. A piece the player cannot buy yet is still put out, drained
## of colour, with what it is waiting for on the ticket.
func _stock_the_floor() -> void:
	if is_paint_shop():
		_stock_paint()
		return

	var ids := Catalog.shop_stock(str(shop.get("id", "")))
	for i in ids.size():
		var id: String = ids[i]
		var available := Game.is_item_unlocked(id)

		var piece := FurnitureItem.new()
		piece.setup(id, Color(0.62, 0.63, 0.66) if not available else Color.TRANSPARENT)
		_stock.add_child(piece)
		piece.global_position = _stand_at(i)
		# Turned a little off square so a row does not read as a shelf.
		piece.rotation.y = deg_to_rad(-18.0 + float(i % 3) * 18.0)

		_ticket(_stand_at(i), Catalog.display_name(id),
			UIKit.money(Catalog.price(id)) if available else _lock_line(id), available)


## Where the i-th piece stands. Rows of four, front to back.
func _stand_at(index: int) -> Vector3:
	var column := index % PER_ROW
	var row := index / PER_ROW
	return Vector3(
		(float(column) - float(PER_ROW - 1) * 0.5) * AISLE_X,
		0.0,
		-DEPTH * 0.5 + 4.2 + float(row) * ROW_Z)


## What a locked piece is waiting for: a level, or a quarter of the city.
func _lock_line(id: String) -> String:
	var district := Catalog.district_of(id)
	if district != "" and not Game.is_district_unlocked(district):
		return str(Jobs.get_district(district)["name"])
	return "Level %d" % Catalog.effective_unlock_level(id)


## A little card on the floor in front of a piece, the way a showroom does it.
func _ticket(at: Vector3, title: String, price: String, available: bool) -> void:
	var card := Node3D.new()
	card.position = at + Vector3(0, 0.02, 0.86)
	_tickets.add_child(card)

	var stand := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.10, 0.02, 0.46)
	stand.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.96, 0.95, 0.92) if available else Color(0.74, 0.73, 0.72)
	material.roughness = 0.9
	stand.material_override = material
	stand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.add_child(stand)

	var text := Label3D.new()
	text.text = "%s\n%s" % [title, price]
	text.font_size = 44
	text.pixel_size = 0.0044
	text.rotation = Vector3(deg_to_rad(-90.0), 0.0, 0.0)
	text.position = Vector3(0, 0.02, 0)
	text.modulate = Color(0.12, 0.13, 0.16) if available else Color(0.52, 0.30, 0.30)
	text.outline_size = 0
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(text)


## The Colour House sells shades rather than furniture, so its floor is racks
## of tins instead of rows of pieces.
func _stock_paint() -> void:
	var surfaces := ["floor", "wall"]
	for s in surfaces.size():
		var surface: String = surfaces[s]
		var entries: Array = Catalog.paints(surface)
		for i in entries.size():
			var entry: Dictionary = entries[i]
			var at := Vector3(
				(float(i) - float(entries.size() - 1) * 0.5) * 1.15,
				0.0,
				-DEPTH * 0.5 + 4.6 + float(s) * 3.4)
			_tin(surface, entry, at)

		var heading := Label3D.new()
		heading.text = "Floors" if surface == "floor" else "Walls"
		heading.font_size = 52
		heading.pixel_size = 0.0034
		heading.rotation = Vector3(deg_to_rad(-90.0), 0.0, 0.0)
		heading.position = Vector3(-WIDTH * 0.5 + 1.9, 0.03, at_row(s))
		heading.modulate = Color(0.30, 0.32, 0.36)
		heading.outline_size = 0
		_tickets.add_child(heading)


func at_row(surface_index: int) -> float:
	return -DEPTH * 0.5 + 4.6 + float(surface_index) * 3.4


## One tin of paint on a stand, pickable in its own right.
func _tin(surface: String, entry: Dictionary, at: Vector3) -> void:
	var owned := Game.owns_paint(surface, str(entry["name"]))
	var available := Game.is_paint_unlocked(entry)
	var colour: Color = entry["color"]

	var holder := Node3D.new()
	holder.name = "Tin_%s_%s" % [surface, entry["name"]]
	holder.position = at
	holder.set_meta("surface", surface)
	holder.set_meta("paint", entry)
	_tins.add_child(holder)

	var plinth := _solid(Vector3(0.86, 0.55, 0.86), Color(0.86, 0.85, 0.82), Vector3(0, 0.275, 0))
	holder.add_child(plinth)

	var body := _solid(Vector3(0.46, 0.44, 0.46),
		colour if available else colour.lerp(Color(0.62, 0.62, 0.62), 0.75),
		Vector3(0, 0.77, 0))
	holder.add_child(body)
	var lid := _solid(Vector3(0.50, 0.05, 0.50), Color(0.88, 0.88, 0.86), Vector3(0, 1.01, 0))
	holder.add_child(lid)

	var text := Label3D.new()
	text.text = "%s\n%s" % [entry["name"],
		"Owned" if owned else (UIKit.money(Catalog.paint_price(entry))
			if available else "Level %d" % int(entry.get("level", 1)))]
	text.font_size = 34
	text.pixel_size = 0.0030
	text.position = Vector3(0, 1.32, 0)
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.modulate = Color(0.94, 0.95, 0.97) if available else Color(0.90, 0.62, 0.60)
	text.outline_size = 18
	text.outline_modulate = Color(0.06, 0.07, 0.10, 0.9)
	holder.add_child(text)

	var pick := StaticBody3D.new()
	pick.collision_layer = FurnitureItem.PICK_LAYER
	pick.collision_mask = 0
	pick.set_meta("tin", holder)
	var shape := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = Vector3(0.9, 1.3, 0.9)
	shape.shape = volume
	shape.position = Vector3(0, 0.65, 0)
	pick.add_child(shape)
	holder.add_child(pick)


static func _solid(size: Vector3, colour: Color, at: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.75
	mesh.material_override = material
	mesh.position = at
	return mesh


func _open_up() -> void:
	set_process_unhandled_input(true)
	# Far enough back to take the whole floor in, and low enough to read the
	# tickets.
	rig.focus = Vector3(0, 1.1, 0.0)
	rig.distance = 12.6
	rig.snap_to_target()


# --------------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			rig.zoom(0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rig.zoom(1.1)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if ui_probe.is_valid() and ui_probe.call(event.position):
			return
		_touches[event.index] = event.position
		_touch_origins[event.index] = event.position
		if _touches.size() == 2:
			_gesture_is_pinch = true
			_pinch_distance = _pinch_span()
		elif _touches.size() == 1:
			_dragged = false
		return

	var was: Vector2 = _touches.get(event.index, event.position)
	_touches.erase(event.index)
	_touch_origins.erase(event.index)
	if _touches.is_empty():
		if not _dragged and not _gesture_is_pinch:
			_pick(was)
		_gesture_is_pinch = false


func _handle_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	_touches[event.index] = event.position
	if (event.position - Vector2(_touch_origins.get(event.index, event.position))).length() > 12.0:
		_dragged = true

	if _touches.size() >= 2:
		var span := _pinch_span()
		if _pinch_distance > 0.0:
			rig.zoom(_pinch_distance / maxf(span, 1.0))
		_pinch_distance = span
		return
	rig.orbit(event.relative)
	rig.yaw = clampf(rig.yaw, -62.0, 62.0)
	rig.pitch = clampf(rig.pitch, -46.0, -8.0)


func _pinch_span() -> float:
	var points := _touches.values()
	if points.size() < 2:
		return 0.0
	return (Vector2(points[0]) - Vector2(points[1])).length()


## What is under the finger: a piece of stock, a tin, or the floor.
func _pick(at: Vector2) -> void:
	var camera := rig.camera
	var query := PhysicsRayQueryParameters3D.create(
		camera.project_ray_origin(at),
		camera.project_ray_origin(at) + camera.project_ray_normal(at) * 200.0)
	query.collide_with_areas = false
	query.collision_mask = FurnitureItem.PICK_LAYER
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		select(null)
		nothing_picked.emit()
		return

	var collider: Object = hit["collider"]
	if collider.has_meta("tin"):
		_select_tin(collider.get_meta("tin"))
		var holder: Node3D = collider.get_meta("tin")
		picked_paint.emit(str(holder.get_meta("surface")), holder.get_meta("paint"))
		return

	var piece := (collider as Node).get_parent() as FurnitureItem
	if piece == null:
		select(null)
		nothing_picked.emit()
		return
	select(piece)
	picked.emit(piece.item_id)


func select(piece: FurnitureItem) -> void:
	_clear_tin()
	if _selected == piece:
		return
	_selected = piece
	if piece == null:
		marker.clear()
	else:
		marker.follow(piece)
		Audio.play("lift", 0.7)


func _select_tin(holder: Node3D) -> void:
	_selected = null
	marker.clear()
	if _selected_tin == holder:
		return
	_clear_tin()
	_selected_tin = holder
	Audio.play("lift", 0.7)

	_tin_glow = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.60
	ring.outer_radius = 0.72
	_tin_glow.mesh = ring
	var material := StandardMaterial3D.new()
	material.albedo_color = UIKit.ACCENT
	material.emission_enabled = true
	material.emission = UIKit.ACCENT
	material.emission_energy_multiplier = 0.7
	_tin_glow.material_override = material
	_tin_glow.position = Vector3(0, 0.03, 0)
	_tin_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(_tin_glow)


func _clear_tin() -> void:
	if is_instance_valid(_tin_glow):
		_tin_glow.queue_free()
	_tin_glow = null
	_selected_tin = null


## The shop is rebuilt after a purchase so the tickets and the greying are
## honest, which means the selection has to be found again by id.
func reselect(item_id: String) -> void:
	for child in _stock.get_children():
		var piece := child as FurnitureItem
		if piece != null and piece.item_id == item_id:
			select(piece)
			return


func reselect_paint(surface: String, name: String) -> void:
	for child in _tins.get_children():
		var holder := child as Node3D
		if holder == null:
			continue
		if str(holder.get_meta("surface")) == surface \
				and str((holder.get_meta("paint") as Dictionary)["name"]) == name:
			_select_tin(holder)
			return


## Puts the stock out again after a purchase, so the tickets and the greying
## stay honest. The fittings do not change, so they are left where they are.
func restock() -> void:
	for holder in [_stock, _tins, _tickets]:
		for child in holder.get_children():
			holder.remove_child(child)
			child.queue_free()
	_selected = null
	marker.clear()
	_clear_tin()
	_stock_the_floor()
