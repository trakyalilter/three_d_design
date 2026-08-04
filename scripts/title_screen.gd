class_name TitleScreen
extends Node3D
## The screen the app opens on.
##
## Behind the menu is a furnished room built from the same catalogue the game
## runs on, turning slowly — the app has no art files, so the best thing it can
## put on its front page is its own work.

signal play_requested()
signal free_build_requested()
signal new_career_requested()

## Degrees a second. Slow enough to read as a held pose rather than a spin.
const TURN := 4.0

var rig: CameraRig
var _room: Room
var _root: Control


func _ready() -> void:
	_build_environment()
	_build_room()

	rig = CameraRig.new()
	rig.name = "CameraRig"
	rig.yaw = -38.0
	rig.pitch = -34.0
	rig.min_distance = 7.0
	rig.max_distance = 16.0
	rig.distance = 11.5
	rig.focus = Vector3(0.0, 0.95, 0.0)
	add_child(rig)
	# Orbiting round the room's own centre keeps it still on screen as it
	# turns; the frustum is then shifted so it sits clear of the menu column,
	# rather than moving the focus and letting the room swing about.
	rig.camera.h_offset = -2.6
	rig.snap_to_target()

	_build_ui()


func _process(delta: float) -> void:
	rig.yaw = wrapf(rig.yaw + TURN * delta, -180.0, 180.0)
	# Same dollhouse rule as the designer: whichever walls are in the way go,
	# so the room stays open however far round it has turned.
	if rig.camera != null:
		_room.update_wall_visibility(rig.camera.global_position, rig.focus)


# --------------------------------------------------------------- the backdrop

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.16, 0.20, 0.32)
	sky_material.sky_horizon_color = Color(0.42, 0.40, 0.44)
	sky_material.ground_bottom_color = Color(0.10, 0.11, 0.14)
	sky_material.ground_horizon_color = Color(0.24, 0.24, 0.28)
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.46
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.8
	world.environment = env
	add_child(world)

	# Low and warm, like a lamp on in the evening.
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-34.0), deg_to_rad(-52.0), 0.0)
	key.light_energy = 1.15
	key.light_color = Color(1.0, 0.93, 0.82)
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 22.0
	key.shadow_bias = 0.03
	key.shadow_normal_bias = 1.2
	key.shadow_blur = 1.5
	key.shadow_opacity = 0.7
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-24.0), deg_to_rad(128.0), 0.0)
	fill.light_energy = 0.30
	fill.light_color = Color(0.72, 0.82, 1.0)
	add_child(fill)


func _build_room() -> void:
	_room = Room.new()
	_room.name = "Room"
	add_child(_room)
	_room.configure(6.5, 5.0, 2.8)
	_room.set_floor_color(Catalog.PAINT["floor"][1]["color"])
	_room.set_wall_color(Catalog.PAINT["wall"][3]["color"])

	var items := Node3D.new()
	items.name = "Furniture"
	add_child(items)

	# A room somebody would be pleased with: everything against a wall, one
	# palette, floor left clear — which is what the reviewer asks for.
	var layout := [
		{"id": "rug", "at": Vector2(-0.4, 0.5), "yaw": 0.0},
		{"id": "sofa", "at": Vector2(-0.4, -1.55), "yaw": 0.0},
		{"id": "coffee_table", "at": Vector2(-0.4, 0.45), "yaw": 0.0},
		{"id": "armchair", "at": Vector2(1.75, 0.75), "yaw": -105.0},
		{"id": "bookshelf", "at": Vector2(-2.75, -0.9), "yaw": 90.0},
		{"id": "floor_lamp", "at": Vector2(-2.85, -1.95), "yaw": 0.0},
		{"id": "plant", "at": Vector2(2.85, -1.9), "yaw": 0.0},
		{"id": "wall_art", "at": Vector2(0.9, -2.25), "yaw": 0.0},
		{"id": "side_table", "at": Vector2(2.75, 0.9), "yaw": 0.0},
		{"id": "console_table", "at": Vector2(-0.4, 2.2), "yaw": 180.0},
		{"id": "vase", "at": Vector2(-0.9, 2.2), "yaw": 0.0},
		{"id": "books_stack", "at": Vector2(0.1, 2.2), "yaw": 0.0},
		{"id": "table_lamp", "at": Vector2(2.75, 0.9), "yaw": 0.0},
	]
	for entry: Dictionary in layout:
		var item := FurnitureItem.new()
		item.setup(str(entry["id"]))
		items.add_child(item)
		item.rotation.y = deg_to_rad(float(entry["yaw"]))
		var at: Vector2 = entry["at"]
		item.global_position = Vector3(at.x, 0.0, at.y)

	# The three props that belong on a surface, put on one.
	for item: Node in items.get_children():
		var piece := item as FurnitureItem
		if piece == null or not Catalog.is_stackable(piece.item_id):
			continue
		var host := "console_table" if piece.item_id in ["vase", "books_stack"] else "side_table"
		piece.position.y = Catalog.surface_height(host)
		piece.set_elevated(true)


# --------------------------------------------------------------------- the UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TitleUI"
	layer.layer = 10
	add_child(layer)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIKit.build_theme()
	layer.add_child(_root)

	# The menu sits in a column down the left. The backdrop is faded out under
	# it with a gradient rather than a panel: a hard edge cutting across the
	# room looked like a mistake.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.52, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.05, 0.06, 0.09, 0.94),
		Color(0.05, 0.06, 0.09, 0.90),
		Color(0.05, 0.06, 0.09, 0.0),
	])
	var fade := GradientTexture2D.new()
	fade.gradient = gradient
	fade.fill_from = Vector2(0, 0.5)
	fade.fill_to = Vector2(1, 0.5)
	fade.width = 256
	fade.height = 4

	var shade := TextureRect.new()
	shade.texture = fade
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 920
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	margin.offset_left = 52
	margin.offset_right = 520
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 40)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := UIKit.label("Room Designer 3D", 46)
	column.add_child(title)

	var strapline := UIKit.wrapped_label(
		"Furnish other people's rooms for a living. Read the brief, buy the "
		+ "furniture, fit it out, and take the fee.", 440, UIKit.MUTED)
	column.add_child(strapline)

	column.add_child(_spacer(18))

	var started := _career_started()
	if started:
		var line := UIKit.label("%s  ·  level %d  ·  %d job%s done" % [
			UIKit.money(Game.money), Game.level,
			Game.jobs_done(), "" if Game.jobs_done() == 1 else "s"], 19, UIKit.GOLD)
		column.add_child(line)
		var owned := 0
		for district: Dictionary in Jobs.districts():
			if Game.is_district_unlocked(str(district["id"])):
				owned += 1
		column.add_child(UIKit.label("%d of %d quarters of the city are yours"
			% [owned, Jobs.districts().size()], 17, UIKit.MUTED))
		column.add_child(_spacer(10))

	var play := UIKit.make_primary_button("Carry on" if started else "Start a career")
	play.tooltip_text = "Open the city map and pick a job"
	play.custom_minimum_size = Vector2(0, 58)
	play.pressed.connect(func() -> void: play_requested.emit())
	column.add_child(play)

	var sandbox := UIKit.make_button(
		"Free Build", "Design a room with no client, no stock and nothing locked")
	sandbox.custom_minimum_size = Vector2(0, 48)
	sandbox.pressed.connect(func() -> void: free_build_requested.emit())
	column.add_child(sandbox)

	var guide := UIKit.make_button("How it works")
	guide.custom_minimum_size = Vector2(0, 48)
	guide.pressed.connect(_open_guide)
	column.add_child(guide)

	if started:
		var fresh := UIKit.make_button("Start again")
		fresh.custom_minimum_size = Vector2(0, 48)
		fresh.add_theme_color_override("font_color", UIKit.BAD)
		fresh.pressed.connect(_confirm_reset)
		column.add_child(fresh)

	column.add_child(_spacer(14))
	column.add_child(UIKit.sound_row())
	column.add_child(UIKit.label(
		"v%s" % ProjectSettings.get_setting("application/config/version", ""), 15, UIKit.MUTED))

	_build_modal(layer)


static func _spacer(height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


## True once the player has done anything at all, which decides between
## "carry on" and "start a career".
func _career_started() -> bool:
	return Game.jobs_done() > 0 or Game.level > 1 \
		or Game.money != Game.STARTING_MONEY or Game.total_stock() > 0


# ------------------------------------------------------------------ the modal

var _modal: Control
var _modal_body: VBoxContainer


func _build_modal(layer: CanvasLayer) -> void:
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.visible = false
	_root.add_child(_modal)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.68)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(660, 0)
	center.add_child(panel)

	_modal_body = VBoxContainer.new()
	panel.add_child(_modal_body)


func is_modal_open() -> bool:
	return _modal != null and _modal.visible


func close_modal() -> void:
	if _modal == null:
		return
	_modal.visible = false
	for child in _modal_body.get_children():
		_modal_body.remove_child(child)
		child.queue_free()


func _begin_modal(title: String) -> void:
	close_modal()
	_modal.visible = true
	_modal_body.add_child(UIKit.label(title, 26))


func _open_guide() -> void:
	_begin_modal("How it works")
	var sections := [
		["The city", "Four quarters on a map. You own one to start with; the rest are bought outright once you have the money and the level, and each brings its own clients and its own shops."],
		["A job", "Tap a house for the owner's brief — what the room has to contain, what they will pay, and what they have budgeted. One button fills the whole shopping basket."],
		["Stock, not cash", "Furniture is bought at the shops into your own warehouse. Inside a room you spend stock, never money, and anything you take back out returns to the shelf. A piece is only paid for when a client keeps it."],
		["The verdict", "Ticking the brief gets you paid. Stars come from the room being any good: big pieces against the walls, a palette that holds together, floor left to walk on, and coming in on budget. Three stars pays thirty per cent on top."],
		["Keep going", "Levels open the pricier shops and the larger houses. A house you have finished will take you back with a fresh brief, so the map never runs out."],
	]
	for section: Array in sections:
		_modal_body.add_child(UIKit.label(section[0], 19, UIKit.ACCENT))
		_modal_body.add_child(UIKit.wrapped_label(section[1], 600))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	_modal_body.add_child(row)
	var close := UIKit.make_primary_button("Got it")
	close.pressed.connect(close_modal)
	row.add_child(close)


func _confirm_reset() -> void:
	_begin_modal("Start again?")
	_modal_body.add_child(UIKit.wrapped_label(
		"This wipes your money, level, stock, the quarters you have bought and every "
		+ "finished job, and puts you back to %s with one quarter of the city."
			% UIKit.money(Game.STARTING_MONEY), 600))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	_modal_body.add_child(row)

	var cancel := UIKit.make_button("Keep my career")
	cancel.pressed.connect(close_modal)
	row.add_child(cancel)

	var confirm := UIKit.make_button("Wipe it")
	confirm.add_theme_color_override("font_color", UIKit.BAD)
	confirm.pressed.connect(func() -> void:
		close_modal()
		new_career_requested.emit())
	row.add_child(confirm)
