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
signal picked_supply(supply_id: String)
signal nothing_picked()

## Aisle layout. Stock stands in rows across the floor, front to back, and the
## spacing comes from how big the pieces in each row actually are — a fixed grid
## stood a two-metre corner sofa across the ticket of the row behind it.
const PER_ROW := 4
## Side to side between two pieces.
const AISLE_GAP := 0.62
## From a piece's front edge to its own card.
const TICKET_GAP := 0.36
## The card, and the floor it needs to be read on.
const TICKET_DEPTH := 0.50
## Room to walk between one row's cards and the next row.
const WALK_GAP := 0.60
## How much of the width the rows may use, clear of the counter and the shelves.
const USABLE_W := 8.8
## The card itself. A piece narrower than its own card still has to be given a
## card's width, or two kettles put their tickets on top of each other.
const CARD_SIZE := Vector2(1.30, 0.50)
const CARD_TILT := 32.0

## The shell. Open at the front so the camera can look in without the near wall
## being in the way. The depth is whatever the stock turns out to need.
const WIDTH := 11.0
const MIN_DEPTH := 12.0
## How far apart the merchant's pallets stand.
const YARD_STEP := 2.55
const HEIGHT := 3.4

var depth := MIN_DEPTH

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

## Where every piece stands and where its card goes, worked out before anything
## is built because the shop is then sized to fit it.
var _spots: Array[Dictionary] = []
## Half the width of the widest row, so the pendants can be hung outside the
## stock rather than over the top of it and its tickets.
var _stock_half_w := 3.4

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


## The builders' merchant. Like the Colour House it sells nothing you can put
## in a room, so its floor is stacks of material rather than rows of furniture.
func is_yard() -> bool:
	return str(shop.get("id", "")) == "yard"


# ------------------------------------------------------------------ the shell

func _build_shell() -> void:
	_plan_floor()
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
	# The merchant is one row of pallets rather than a showroom, so the camera
	# starts in closer — the showroom distance leaves it stranded in a field.
	rig.distance = 9.8 if is_yard() else 12.6
	rig.min_distance = 4.5
	rig.max_distance = 18.0
	rig.pan_limit = Vector2(WIDTH * 0.5, depth * 0.5)
	add_child(rig)


## Works out where every piece will stand, before the shell is built, because
## the shell is then sized to fit it. Rows are packed by how wide the pieces
## actually are and spaced by how deep they are, with room left after each row
## for its own cards — which is what stops anything standing across a ticket.
func _plan_floor() -> void:
	_spots = []
	depth = MIN_DEPTH
	if is_paint_shop():
		return
	if is_yard():
		# Four pallets and nothing else, so the merchant is a shorter unit than a
		# showroom. Anything deeper is a hall with a stack in the middle of it.
		depth = 10.0
		_stock_half_w = YARD_STEP * 1.5 + 0.9
		return

	var ids := Catalog.shop_stock(str(shop.get("id", "")))
	if ids.is_empty():
		return

	# Tallest at the back, the way a showroom does it. It is not only tidier: a
	# wardrobe standing in front of the cards behind it hides them, and no
	# amount of spacing on the floor fixes that.
	var sorted: Array[String] = []
	for id: String in ids:
		sorted.append(id)
	sorted.sort_custom(func(a: String, b: String) -> bool:
		var left := Catalog.height(a)
		var right := Catalog.height(b)
		if not is_equal_approx(left, right):
			return left > right
		return Catalog.footprint(a).y > Catalog.footprint(b).y)

	# Every piece, with the box it takes up on the floor once it is turned.
	var pieces: Array[Dictionary] = []
	for i in sorted.size():
		var id := sorted[i]
		# Turned a little off square so a row does not read as a shelf.
		var yaw := deg_to_rad(-18.0 + float(i % 3) * 18.0)
		var box: Vector2 = Catalog.footprint(id)
		var c := absf(cos(yaw))
		var s := absf(sin(yaw))
		# Where the middle of that box sits once the piece is turned, so the
		# piece can be nudged to put its box on the spot rather than its origin.
		var middle: Vector2 = Catalog.footprint_centre(id)
		var turned := Vector2(
			middle.x * cos(yaw) + middle.y * sin(yaw),
			-middle.x * sin(yaw) + middle.y * cos(yaw))
		var across_it := box.x * c + box.y * s
		pieces.append({
			"id": id,
			"yaw": yaw,
			# A piece is given whichever is wider, itself or its card.
			"w": maxf(across_it, CARD_SIZE.x),
			"d": box.x * s + box.y * c,
			"off": turned,
		})

	# Pack across the floor: as many as fit, four at the most.
	var rows: Array[Array] = []
	var row: Array[Dictionary] = []
	var across := 0.0
	for piece: Dictionary in pieces:
		var wide := float(piece["w"])
		var want: float = (across + AISLE_GAP + wide) if not row.is_empty() else wide
		if not row.is_empty() and (row.size() >= PER_ROW or want > USABLE_W):
			rows.append(row)
			row = []
			want = wide
		row.append(piece)
		across = want
	if not row.is_empty():
		rows.append(row)

	# Then front to back, from a local zero at the back of the first row.
	var cursor := 0.0
	var widest := 0.0
	var laid: Array[Dictionary] = []
	for r: Array in rows:
		var deepest := 0.0
		var total := 0.0
		for piece: Dictionary in r:
			deepest = maxf(deepest, float(piece["d"]))
			total += float(piece["w"])
		total += AISLE_GAP * float(r.size() - 1)
		widest = maxf(widest, total)

		var x := -total * 0.5
		for piece: Dictionary in r:
			var wide := float(piece["w"])
			x += wide * 0.5
			laid.append({
				"id": piece["id"],
				"yaw": piece["yaw"],
				"off": piece["off"],
				"x": x,
				"z": cursor + deepest * 0.5,
				# The card sits clear of this piece's own front edge, not at a
				# fixed distance, so a deep piece never covers its own ticket.
				"front": float(piece["d"]) * 0.5 + TICKET_GAP,
			})
			x += wide * 0.5 + AISLE_GAP
		cursor += deepest + TICKET_GAP + TICKET_DEPTH + WALK_GAP

	# Room behind the first row for the counter — clear of it, not alongside it —
	# and a strip at the front to stand in. The shop grows if the stock needs
	# more than the usual twelve.
	var back := 4.1
	_stock_half_w = widest * 0.5
	depth = maxf(MIN_DEPTH, back + cursor + 1.0)
	var z0 := -depth * 0.5 + back
	for spot: Dictionary in laid:
		var off: Vector2 = spot["off"]
		_spots.append({
			"id": spot["id"],
			"yaw": spot["yaw"],
			# Where the middle of the piece goes, and where the piece's own
			# origin has to be put so that the middle lands there.
			"at": Vector3(float(spot["x"]), 0.0, z0 + float(spot["z"])),
			"stand": Vector3(float(spot["x"]) - off.x, 0.0, z0 + float(spot["z"]) - off.y),
			"front": float(spot["front"]),
		})


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
	var half_d := depth * 0.5
	var floor_colour := Color(0.80, 0.78, 0.75)
	var wall := Color(0.90, 0.89, 0.87)

	# Floor, with a border band in the shop's colour and a runner up the middle.
	_batch.box(floor_colour, Vector3(WIDTH, 0.2, depth), Vector3(0, -0.1, 0))
	_batch.box(accent.lerp(floor_colour, 0.55), Vector3(WIDTH, 0.02, 0.5), Vector3(0, 0.01, -half_d + 0.6))
	_batch.box(accent.lerp(floor_colour, 0.78), Vector3(2.0, 0.02, depth - 2.4), Vector3(0, 0.012, 0.6))

	# Three walls. The front is left open so the camera can see in.
	_batch.box(wall, Vector3(WIDTH, HEIGHT, 0.24), Vector3(0, HEIGHT * 0.5, -half_d))
	for sx in [-1.0, 1.0]:
		_batch.box(wall.darkened(0.04), Vector3(0.24, HEIGHT, depth), Vector3(sx * half_w, HEIGHT * 0.5, 0))
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
	var at := Vector3(-half_w + 1.5, 0, -depth * 0.5 + 2.6)

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
		_batch.box(wall.darkened(0.30), Vector3(0.42, 0.07, depth - 3.0),
			Vector3(half_w - 0.34, y, 0.4))
		for z in [-2.6, 0.4, 3.4]:
			_batch.box(bracket, Vector3(0.34, 0.05, 0.06),
				Vector3(half_w - 0.36, y - 0.06, z), SceneryBatch.Layer.SHINY)
		# Stock boxes, in the shop's colours, purely so the shelves are not bare.
		for i in 4:
			var z := -2.9 + float(i) * 1.9 + float(shelf) * 0.4
			if z > depth * 0.5 - 1.4:
				continue
			var tone: Color = accent.lerp(Color(0.92, 0.90, 0.86), 0.25 + float(i) * 0.16)
			_batch.box(tone, Vector3(0.30, 0.30, 0.44), Vector3(half_w - 0.34, y + 0.19, z))


## The shopfront: a low wall with glass over it, so the inside reads as a room
## you are looking into rather than a floating floor.
func _build_window_line(accent: Color) -> void:
	var half_w := WIDTH * 0.5
	var half_d := depth * 0.5
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


## Pendants down the ceiling, spread over however deep the shop turned out and
## hung outside the rows rather than over the top of them — a shade in front of
## a price card is the one thing on this floor you cannot look round. They hang
## short too: a long drop reads as something standing on the floor.
func _build_lights() -> void:
	var fitting := Color(0.24, 0.25, 0.28)
	var bulb := Color(1.0, 0.97, 0.86)
	var lamps := maxi(3, int(round(depth / 3.6)))
	var out: float = clampf(_stock_half_w + 0.80, 3.4, WIDTH * 0.5 - 0.85)
	for i in lamps:
		var z: float = -depth * 0.5 + 2.4 + (depth - 4.2) * float(i) / float(maxi(lamps - 1, 1))
		for sx in [-1.0, 1.0]:
			var x: float = sx * out
			# A pale, slightly thicker stem, so the shade overhead reads as
			# hanging rather than as something standing on the floor.
			_batch.cylinder(Color(0.62, 0.63, 0.66), 0.05, 0.34,
				Vector3(x, HEIGHT - 0.18, z), SceneryBatch.Layer.SHINY, 6)
			_batch.cone(fitting, 0.28, 0.26, Vector3(x, HEIGHT - 0.48, z), SceneryBatch.Layer.SHINY, 10)
			_batch.box(bulb, Vector3(0.30, 0.04, 0.30), Vector3(x, HEIGHT - 0.61, z))


func _build_plants() -> void:
	var pot := Color(0.66, 0.48, 0.36)
	var leaf := Color(0.28, 0.52, 0.28)
	for spot in [Vector3(-WIDTH * 0.5 + 0.9, 0, depth * 0.5 - 1.2),
			Vector3(WIDTH * 0.5 - 0.9, 0, depth * 0.5 - 1.2)]:
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
	name_plate.position = Vector3(0, HEIGHT - 0.85, -depth * 0.5 + 0.22)
	name_plate.modulate = Color(0.08, 0.09, 0.12)
	name_plate.outline_size = 0
	_fixtures.add_child(name_plate)

	var tagline := Label3D.new()
	tagline.text = str(shop.get("tagline", ""))
	tagline.font_size = 40
	tagline.pixel_size = 0.0052
	tagline.width = 1400.0
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.position = Vector3(0, HEIGHT - 1.62, -depth * 0.5 + 0.22)
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
	if is_yard():
		_stock_yard()
		return

	for spot: Dictionary in _spots:
		var id := str(spot["id"])
		var available := Game.is_item_unlocked(id)
		var at: Vector3 = spot["at"]

		var piece := FurnitureItem.new()
		piece.setup(id, Color(0.62, 0.63, 0.66) if not available else Color.TRANSPARENT)
		_stock.add_child(piece)
		piece.global_position = spot["stand"]
		piece.rotation.y = float(spot["yaw"])

		_ticket(at + Vector3(0, 0, float(spot["front"])), Catalog.height(id),
			Catalog.display_name(id),
			UIKit.money(Catalog.price(id)) if available else _lock_line(id), available)


## What a locked piece is waiting for: a level, or a quarter of the city.
func _lock_line(id: String) -> String:
	var district := Catalog.district_of(id)
	if district != "" and not Game.is_district_unlocked(district):
		return str(Jobs.get_district(district)["name"])
	return "Level %d" % Catalog.effective_unlock_level(id)


## The card in front of a piece. It stands on a little easel rather than lying
## flat: a card on the floor is read at a glancing angle and disappears behind
## whatever is in front of it, and this one is turned up towards the camera.
func _ticket(at: Vector3, tall: float, title: String, price: String, available: bool) -> void:
	var card := Node3D.new()
	card.position = at
	# The floor it takes up, so a layout check can see it.
	card.set_meta("span", Vector2(CARD_SIZE.x, TICKET_DEPTH))
	_tickets.add_child(card)

	var paper := Color(0.96, 0.95, 0.92) if available else Color(0.74, 0.73, 0.72)

	# How high the card has to sit to be read over the piece it belongs to. A
	# card on the floor works for a footstool and disappears behind a wardrobe,
	# so the post grows with the piece: it clears the top of it, less whatever
	# the camera's own angle already sees over.
	var lift: float = clampf(tall - TICKET_GAP * 0.47 + 0.06, 0.05, 1.95)

	# A foot and a post, so the card is standing on something.
	var foot := MeshInstance3D.new()
	var base := BoxMesh.new()
	base.size = Vector3(CARD_SIZE.x * 0.42, 0.04, 0.24)
	foot.mesh = base
	foot.material_override = _matte(paper.darkened(0.34))
	foot.position = Vector3(0, 0.02, 0.02)
	foot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.add_child(foot)

	if lift > 0.16:
		var post := MeshInstance3D.new()
		var stem := BoxMesh.new()
		stem.size = Vector3(0.05, lift, 0.05)
		post.mesh = stem
		post.material_override = _matte(paper.darkened(0.34))
		post.position = Vector3(0, lift * 0.5, 0.02)
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		card.add_child(post)

	# The face, leaned back at about the angle the camera looks down at.
	var face := Node3D.new()
	face.position = Vector3(0, lift + CARD_SIZE.y * 0.5 * cos(deg_to_rad(CARD_TILT)), 0)
	face.rotation = Vector3(deg_to_rad(-CARD_TILT), 0.0, 0.0)
	card.add_child(face)
	# The point a check should be able to see: the bottom line of the card, just
	# clear of the plate itself.
	card.set_meta("read_from", Vector3(0, lift + 0.05, 0.06))

	var plate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(CARD_SIZE.x, CARD_SIZE.y, 0.02)
	plate.mesh = box
	plate.material_override = _matte(paper)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	face.add_child(plate)

	var text := Label3D.new()
	text.text = "%s\n%s" % [title, price]
	text.font_size = 44
	text.pixel_size = 0.0048
	text.position = Vector3(0, 0, 0.02)
	text.modulate = Color(0.12, 0.13, 0.16) if available else Color(0.52, 0.30, 0.30)
	text.outline_size = 0
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.add_child(text)


static func _matte(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	return material


## Four stacks of trade material across the middle of the yard, each on a pallet
## with its price standing over it.
func _stock_yard() -> void:
	var trade := Catalog.trade()
	for i in trade.size():
		var entry: Dictionary = trade[i]
		_pallet(entry, Vector3(
			(float(i) - float(trade.size() - 1) * 0.5) * YARD_STEP, 0.0, 1.6))


## One stack, pickable in its own right.
func _pallet(entry: Dictionary, at: Vector3) -> void:
	var id := str(entry["id"])
	var available := Game.level >= int(shop.get("level", 1))
	var colour: Color = entry["color"]
	if not available:
		colour = colour.lerp(Color(0.60, 0.60, 0.58), 0.7)

	var holder := Node3D.new()
	holder.name = "Pallet_%s" % id
	holder.position = at
	holder.set_meta("supply", id)
	_tins.add_child(holder)

	var pallet := Color(0.56, 0.44, 0.30)
	holder.add_child(_solid(Vector3(1.9, 0.10, 1.35), pallet, Vector3(0, 0.05, 0)))
	for sx in [-0.62, 0.0, 0.62]:
		holder.add_child(_solid(Vector3(0.22, 0.14, 1.35), pallet.darkened(0.18),
			Vector3(float(sx), 0.17, 0)))
	holder.add_child(_solid(Vector3(1.9, 0.08, 1.35), pallet, Vector3(0, 0.28, 0)))

	# The stack itself, laid in courses turned a quarter each time so it reads as
	# material stacked rather than as one painted block.
	for course in 7:
		var wide: float = 1.66 - float(course) * 0.05
		var turn: bool = course % 2 == 1
		holder.add_child(_solid(
			Vector3(wide if not turn else 1.12, 0.19, 1.12 if not turn else wide),
			colour.darkened(0.035 * float(course)),
			Vector3(0, 0.42 + float(course) * 0.20, 0)))

	var text := Label3D.new()
	text.text = "%s\n%s a %s" % [entry["name"], UIKit.money(int(entry["price"])),
		str(entry["unit"]).trim_suffix("s")]
	text.font_size = 40
	text.pixel_size = 0.0044
	text.position = Vector3(0, 2.30, 0)
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.modulate = Color(0.96, 0.96, 0.98) if available else Color(0.92, 0.64, 0.62)
	text.outline_size = 20
	text.outline_modulate = Color(0.06, 0.07, 0.10, 0.92)
	holder.add_child(text)

	var pick := StaticBody3D.new()
	pick.collision_layer = FurnitureItem.PICK_LAYER
	pick.collision_mask = 0
	pick.set_meta("pallet", holder)
	var shape := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = Vector3(2.0, 1.9, 1.45)
	shape.shape = volume
	shape.position = Vector3(0, 0.95, 0)
	pick.add_child(shape)
	holder.add_child(pick)


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
				-depth * 0.5 + 4.6 + float(s) * 3.4)
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
	return -depth * 0.5 + 4.6 + float(surface_index) * 3.4


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
	# tickets. Both follow the depth, since the shop is built to fit its stock.
	var middle := 0.0
	if not _spots.is_empty():
		for spot: Dictionary in _spots:
			middle += (spot["at"] as Vector3).z
		middle /= float(_spots.size())
	rig.focus = Vector3(0, 1.0, middle)
	rig.max_distance = maxf(18.0, depth * 1.3)
	rig.distance = clampf(depth * 0.82, 10.5, rig.max_distance)
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
	if collider.has_meta("pallet"):
		var stack: Node3D = collider.get_meta("pallet")
		_select_tin(stack)
		picked_supply.emit(str(stack.get_meta("supply")))
		return
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
