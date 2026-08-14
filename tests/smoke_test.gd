extends Node
## End-to-end check of the whole game, run from the command line:
##
##     godot --headless -- --smoke
##
## It plays the career from an empty profile — shopping for each brief, fitting
## the room out from stock, handing it over — then exercises the placement
## aids, the history, the star review and a generated repeat contract.
##
## Autoloaded so it can drive the real scene tree, but it does nothing at all
## unless that flag is passed, so a normal run pays only for this comment.

var _failures: Array[String] = []


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--smoke"):
		return
	await get_tree().process_frame
	Game.reset()

	print("=== the save ===")
	_check_profile()

	print("=== the front page ===")
	await _check_title()
	await _check_loading()
	await _check_brief_sheet()

	print("=== the map ===")
	await _check_life()

	print("=== the shops ===")
	await _check_shop()
	await _check_shop_brief()

	print("=== sound ===")
	_check_sound()

	print("=== districts ===")
	_check_districts()

	print("=== the trade ===")
	_check_perks()

	print("=== career ===")
	# Where the player stood when the last quarter opened. Levelling is meant
	# to still be running then, not finished a third of the way in.
	var level_at_last_quarter := 1
	for district: Dictionary in Jobs.districts():
		if not await _acquire(district):
			break
		level_at_last_quarter = Game.level
		await _work_quarter(district)
	print("--- career done: money %d, level %d/%d, jobs %d, houses %d/%d" % [
		Game.money, Game.level, Game.MAX_LEVEL, Game.jobs_done(),
		Jobs.unlocked().size(), Jobs.all().size()])
	_expect(Jobs.unlocked().size() == Jobs.all().size(),
		"the career run did not manage to buy the whole city")
	_expect(Game.level == Game.MAX_LEVEL,
		"the career ended at level %d of %d, so the last levels are unreachable"
			% [Game.level, Game.MAX_LEVEL])
	_expect(level_at_last_quarter < Game.MAX_LEVEL,
		"the level cap was already reached before the last quarter opened, so "
		+ "the whole of it is played with nothing left to earn")

	print("=== the estate ===")
	await _check_estate()

	print("=== the showroom ===")
	await _check_showroom()

	print("=== catalogue ===")
	_check_winding()
	_check_catalogue()

	print("=== floor plans ===")
	await _check_floor_plan()

	print("=== designer ===")
	# The checks below are about how the designer behaves, not about what the
	# career left in the bank, so they buy their props out of a fresh float.
	Game.earn(20000)
	await _check_placement_aids()
	await _check_history()
	await _check_three_stars()
	await _check_repeat_contract()
	await _check_tray()

	if _failures.is_empty():
		print("SMOKE TEST PASSED")
	else:
		for failure in _failures:
			print("FAIL: ", failure)
		print("SMOKE TEST FAILED (%d)" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Screen changes run behind a loading screen, a build stage per frame, so the
## new screen is not there the moment it is asked for. Waits for whichever
## change is in flight to finish.
func _settle() -> void:
	var main := get_tree().current_scene
	var guard := 0
	while main.is_changing():
		guard += 1
		if guard > 4000:
			_failures.append("a screen change never finished")
			return
		await get_tree().process_frame
	await get_tree().process_frame


# --------------------------------------------------------------- front page

## The app opens on the title screen, not on the map, and its buttons lead
## where they say they do.
func _check_title() -> void:
	var main := get_tree().current_scene
	_expect(main.title != null, "the app did not open on the title screen")
	_expect(main.city == null and main.designer == null,
		"the title screen came up with another screen already running")
	if main.title == null:
		return

	main.title.play_requested.emit()
	_expect(main.is_changing(), "Carry on did not put a loading screen up")
	await _settle()
	_expect(main.city != null, "Carry on did not open the city")
	_expect(main.title == null, "the title screen stayed behind the city")

	main.enter_title()
	await get_tree().process_frame
	main.title.free_build_requested.emit()
	await _settle()
	_expect(main.designer != null and not main.designer.job_mode(),
		"Free Build did not open the sandbox")

	main.enter_title()
	await get_tree().process_frame
	print("title           opens the app; Carry on and Free Build both land")


## Every change of screen is covered: the overlay is up before the old screen
## comes down, its bar runs to the end, and it takes itself away afterwards.
func _check_loading() -> void:
	var main := get_tree().current_scene

	main.enter_city()
	var screen: LoadingScreen = main.get_node_or_null("Loading")
	_expect(screen != null, "no loading screen went up on the way to the city")
	if screen == null:
		return
	_expect(main.title != null,
		"the title screen was torn down before the loading screen had painted")

	var seen: Array[float] = []
	while main.is_changing() and is_instance_valid(screen):
		seen.append(screen.progress())
		await get_tree().process_frame
	_expect(seen.size() >= 4, "the city build did not report its stages one at a time")
	_expect(seen[0] < 0.5 and seen[seen.size() - 1] > 0.9,
		"the loading bar did not run from one end to the other")

	await _settle()
	_expect(main.get_node_or_null("Loading") == null, "the loading screen stayed up")
	_expect(main.city != null and main.title == null,
		"the loading screen lifted on the wrong scene")

	main.enter_designer("maple_studio")
	_expect(main.get_node_or_null("Loading") != null,
		"no loading screen went up on the way to a job")
	await _settle()
	_expect(main.designer != null and main.get_node_or_null("Loading") == null,
		"the job did not come up clean behind its loading screen")

	main.enter_city()
	await _settle()
	print("loading         covers both changes of screen, bar runs end to end")


## A brief lists what is still needed and what it comes to, and leaves the
## buying to the shops — there is no button here that fills the basket.
func _check_brief_sheet() -> void:
	var main := get_tree().current_scene
	if main.city_ui == null:
		_failures.append("the brief sheet check needs the city open")
		return

	var house_id := str(Jobs.unlocked()[0]["id"])
	main.city_ui.show_house(house_id)
	await get_tree().process_frame

	var labels: Array[String] = []
	for row: Node in main.city_ui._sheet_body.get_children():
		_collect_text(row, labels)
	_expect(labels.has("Still to buy"), "the brief did not list what is still to buy")

	# Every missing piece stands under the counter that sells it, so the list
	# can be walked round the city.
	var wanted: Dictionary = {}
	for item_id: String in Jobs.shopping_list(house_id):
		var shop_name := str(Catalog.get_shop(Catalog.shop_of(item_id)).get("name", ""))
		wanted[shop_name] = true
		_expect(labels.has("%d × %s" % [
			int(Jobs.shopping_list(house_id)[item_id]), Catalog.display_name(item_id)]),
			"%s is missing from the brief's shopping list" % item_id)
	for shop_name: String in wanted:
		_expect(labels.has(shop_name),
			"the shopping list did not say to go to %s" % shop_name)
	_expect(not wanted.is_empty(), "this brief needed nothing, so it checks nothing")

	var actions: Array[String] = []
	for button: Node in main.city_ui._sheet_actions.get_children():
		if button is Button:
			actions.append((button as Button).text)
	for text in actions:
		_expect(not text.begins_with("Buy all"),
			"the brief sheet still buys the whole basket in one tap")
	_expect(actions.has("Start job"), "the brief sheet lost its Start job button")

	main.city_ui.close_sheet()
	await get_tree().process_frame
	print("brief           %d counter%s to visit, buying left to them: %s" % [
		wanted.size(), "" if wanted.size() == 1 else "s", ", ".join(actions)])


## Everything a panel says, however it is drawn. A line the player can act on is
## a button rather than a label — the shopping list in a shop is half of each —
## and the checks below care what the panel says, not which it used.
# -------------------------------------------------------------------- the save

## The career has to survive the app being killed while it is being written.
##
## Android stops a paused app whenever it likes, and the profile is saved from
## the pause notification, so a torn file is a matter of time rather than a rare
## crash. What used to happen then was the worst outcome the game has: the file
## would not parse, the career started again from nothing, and the next purchase
## wrote that over the top of it.
func _check_profile() -> void:
	Game.money = 12345
	Game.level = 7
	Game.save_profile()
	_expect(FileAccess.file_exists(Game.PROFILE_PATH), "the profile was not written")
	_expect(not FileAccess.file_exists(Game.PROFILE_TEMP),
		"the half-written file was left lying beside the profile")

	# Save again, so there is a spare, and check it is the save before this one
	# rather than a copy of it.
	Game.money = 999
	Game.save_profile()
	_expect(FileAccess.file_exists(Game.PROFILE_SPARE), "no spare was kept")
	var spare: Dictionary = Game._read_profile(Game.PROFILE_SPARE)
	_expect(int(spare.get("money", 0)) == 12345,
		"the spare holds %s rather than the save before the last one" % spare.get("money", "nothing"))

	# A profile torn off half way, which is what a kill mid-write leaves.
	var whole := FileAccess.get_file_as_string(Game.PROFILE_PATH)
	var torn := FileAccess.open(Game.PROFILE_PATH, FileAccess.WRITE)
	torn.store_string(whole.substr(0, whole.length() / 2))
	torn.close()
	_expect(JSON.parse_string(whole.substr(0, whole.length() / 2)) == null,
		"half a profile parsed as JSON, so this check is not checking anything")

	Game.money = 0
	Game.level = 1
	Game.load_profile()
	_expect(Game.money == 12345 and Game.level == 7,
		"a torn profile lost the career: money %d, level %d" % [Game.money, Game.level])

	# And with nothing readable at all it starts fresh rather than refusing to
	# open, which is the one case where a new career is the right answer.
	DirAccess.remove_absolute(Game.PROFILE_PATH)
	DirAccess.remove_absolute(Game.PROFILE_SPARE)
	Game.reset()
	_expect(Game.money == Game.STARTING_MONEY and Game.level == 1,
		"a career with no save behind it did not start clean")
	_expect(not FileAccess.file_exists(Game.PROFILE_SPARE),
		"wiping the career left the old one in the spare, where it could come back")
	print("save            survives a kill mid-write; falls back to the save before it")


static func _collect_text(node: Node, into: Array[String]) -> void:
	if node is Label:
		into.append((node as Label).text)
	elif node is Button:
		into.append((node as Button).text)
	for child in node.get_children():
		_collect_text(child, into)


# ---------------------------------------------------------------- the map

## The map has traffic on it, people on the pavements and weather over the two
## quarters that get any. All of it is meant to be moving.
func _check_life() -> void:
	var main := get_tree().current_scene
	if main.city == null:
		_failures.append("the map check needs the city open")
		return
	var life: CityLife = main.city.get_node_or_null("Life")
	_expect(life != null, "the map has no moving layer on it")
	if life == null:
		return

	var census := life.census()
	var instances: int = int(census["cars"]) + int(census["walkers"]) \
		+ int(census["petals"]) + int(census["birds"])
	var pools: int = census["pools"]
	_expect(instances > 0 and pools > 0, "nothing was put on the map to move")
	_expect(int(census["cars"]) > 0, "there is no traffic on the roads")
	_expect(int(census["walkers"]) > 0, "there is nobody on the pavements")
	# One draw call a pool, so this is the whole cost of the layer.
	_expect(pools <= 12, "the moving layer costs %d draw calls" % pools)

	# Everything has to actually move, and stay on the map while it does.
	await get_tree().process_frame
	var before: Array[Vector3] = life.positions()
	for _i in 20:
		await get_tree().process_frame
	var after: Array[Vector3] = life.positions()
	var moved := 0
	for i in mini(before.size(), after.size()):
		if before[i].distance_to(after[i]) > 0.01:
			moved += 1
	_expect(moved > before.size() / 2,
		"only %d of %d things on the map moved" % [moved, before.size()])

	var bounds := 0.0
	for district: Dictionary in Jobs.districts():
		var origin: Vector2 = district["origin"]
		bounds = maxf(bounds, maxf(absf(origin.x), absf(origin.y)))
	bounds += 60.0
	var strays := 0
	for spot in after:
		if absf(spot.x) > bounds or absf(spot.z) > bounds or spot.y < -1.0 or spot.y > 40.0:
			strays += 1
	_expect(strays == 0, "%d things on the map have wandered off it" % strays)

	print("map             %d moving in %d draw calls, %d of them shifted in 20 frames"
		% [instances, pools, moved])


# -------------------------------------------------------------------- shops

## A shop is a room you walk into. Everything it sells stands on the floor with
## a ticket in front of it, and buying happens by picking the piece up rather
## than reading a list.
func _check_shop() -> void:
	var main := get_tree().current_scene

	var shop_id := "living"
	main.enter_shop(shop_id)
	await _settle()
	_expect(main.shop != null, "the shop did not open")
	_expect(main.city == null, "the map was left running under the shop")
	if main.shop == null:
		return

	var floor_stock: Node = main.shop.get_node("Stock")
	var expected := Catalog.shop_stock(shop_id).size()
	_expect(floor_stock.get_child_count() == expected,
		"%s put %d of its %d pieces on the floor"
			% [shop_id, floor_stock.get_child_count(), expected])
	_expect(main.shop.get_node("Tickets").get_child_count() == expected,
		"not every piece on the floor has a price ticket")

	# The floor has to be laid out on the ground the pieces actually take up:
	# nothing standing inside anything else, and — the part a fixed grid got
	# wrong — nothing standing across another piece's price card.
	for shop: Dictionary in Catalog.SHOPS:
		var id := str(shop["id"])
		if str(shop["category"]) == "" or Catalog.shop_stock(id).is_empty():
			continue
		main.enter_shop(id)
		await _settle()
		# The pick bodies have to be in the physics world before anything can be
		# cast against them.
		await get_tree().physics_frame
		await get_tree().physics_frame
		if main.shop == null:
			_failures.append("%s did not open" % id)
			continue
		_check_shop_layout(id, main.shop)

	main.enter_shop(shop_id)
	await _settle()
	if main.shop == null:
		return
	floor_stock = main.shop.get_node("Stock")

	# Buying off the floor: the card's button is what the player presses.
	var item_id: String = Catalog.shop_stock(shop_id)[0]
	var before := Game.stock_of(item_id)
	var money := Game.money
	main.shop_ui.buy_requested.emit(item_id)
	await get_tree().process_frame
	_expect(Game.stock_of(item_id) == before + 1,
		"buying %s off the shop floor did not add it to stock" % item_id)
	_expect(Game.money == money - Catalog.price(item_id),
		"buying %s did not cost what the ticket said" % item_id)
	_expect(main.shop.get_node("Stock").get_child_count() == expected,
		"the floor was not laid out again after a purchase")

	main.shop_ui.sell_requested.emit(item_id)
	await get_tree().process_frame
	_expect(Game.stock_of(item_id) == before, "selling it back did not take it out of stock")
	_expect(Game.money == money, "selling it back did not return the money")

	# The Colour House sells shades, so its floor is racks of tins.
	main.enter_shop("paint")
	await _settle()
	_expect(main.shop != null and main.shop.is_paint_shop(), "the Colour House did not open")
	var tins := 0
	if main.shop != null:
		tins = main.shop.get_node("Tins").get_child_count()
	var shades := Catalog.paints("floor").size() + Catalog.paints("wall").size()
	_expect(tins == shades, "the Colour House put out %d tins for %d shades" % [tins, shades])

	main.enter_city()
	await _settle()
	_expect(main.city != null and main.shop == null, "leaving the shop did not land on the map")
	print("shops           %d pieces on the floor, priced and pickable; %d tins of paint"
		% [expected, tins])


## The brief goes shopping. Walking out to the map to read what the room still
## needs and walking back in was the longest thing in the game, so the panel on
## the left of a shop carries the client's words and the list — and the pieces
## on the list say so on their own tickets.
func _check_shop_brief() -> void:
	var main := get_tree().current_scene

	var house_id := str(Jobs.unlocked()[0]["id"])
	var missing := Jobs.shopping_list(house_id, Jobs.placed_counts(house_id))
	var item_id := ""
	for id: String in missing:
		item_id = id
		break
	if item_id == "":
		_failures.append("the first brief needed nothing, so the shop panel checks nothing")
		return
	var shop_id := Catalog.shop_of(item_id)

	# Tapping the house is the player saying which job they are on; the shops
	# then show that brief. Coming in off the map with nothing in mind shows
	# none, which is checked further down.
	main.enter_city(house_id)
	await _settle()
	main.enter_shop(shop_id)
	await _settle()
	if main.shop == null or main.shop_ui == null:
		_failures.append("%s did not open with a brief to carry" % shop_id)
		return

	_expect(main.shop_ui.is_brief_open(),
		"the brief stayed shut in a shop that sells what it needs")

	var labels: Array[String] = []
	for row: Node in main.shop_ui._brief_body.get_children():
		_collect_text(row, labels)
	var job := Jobs.get_job(house_id)
	_expect(labels.has("“%s”" % job["brief"]), "the shop did not give the client's own words")

	# Everything the shop sells is at the top of the list, everything it does not
	# is underneath it, and no piece is on the list twice.
	var here := 0
	var elsewhere := 0
	for id: String in missing:
		var line := "%d × %s" % [int(missing[id]), Catalog.display_name(id)]
		if Catalog.shop_of(id) == shop_id:
			here += 1
			_expect(labels.has(line), "%s is on the brief but not on this shop's half of the list" % id)
		else:
			elsewhere += 1
			_expect(labels.has("    " + line), "%s was left off the rest of the round" % id)
	_expect(here > 0, "the shop chosen for this check sells nothing on the list")
	_expect(labels.has("On this floor — tap to be shown it"),
		"the list did not separate what is sold here from what is not")

	# The tickets on the floor say it too, so the round can be walked rather than
	# read. One card per piece the client is short of, and no others.
	var marked := 0
	for card: Node in main.shop.get_node("Tickets").get_children():
		if card.has_meta("wanted") and int(card.get_meta("wanted")) > 0:
			marked += 1
	_expect(marked == here,
		"%d ticket%s marked for %d piece%s on the brief" % [
			marked, "" if marked == 1 else "s", here, "" if here == 1 else "s"])

	# Tapping a line takes the player to the piece it means and puts its card up,
	# because buying still happens on the piece rather than in the list.
	main.shop_ui.walk_to_requested.emit(item_id)
	await get_tree().process_frame
	_expect(main.shop_ui._shown_item == item_id,
		"tapping the list did not put up the card for %s" % item_id)

	# Buying it crosses it off both the list and the ticket.
	var was := int(missing[item_id])
	main.shop_ui.buy_requested.emit(item_id)
	await get_tree().process_frame
	var left := Jobs.shopping_list(house_id, Jobs.placed_counts(house_id))
	_expect(int(left.get(item_id, 0)) == was - 1,
		"buying %s did not come off the brief's list" % item_id)
	Game.sell_item(item_id, 1)

	# A shop entered with no job in mind is just a shop.
	main.enter_city()
	await _settle()
	main.enter_shop(shop_id)
	await _settle()
	_expect(not main.shop_ui.is_brief_open(),
		"a shop opened a brief for a job nobody had picked")

	main.enter_city()
	await _settle()
	print("brief in shop   %s: %d line%s on this floor, %d elsewhere, %d ticket%s marked" % [
		Catalog.shop_name(shop_id), here, "" if here == 1 else "s", elsewhere,
		marked, "" if marked == 1 else "s"])


## The ground every piece and every card covers, in one shop. Two of them
## overlapping is exactly what the player saw: a ticket standing under the piece
## in front of it cannot be read.
func _check_shop_layout(shop_id: String, floor) -> void:
	var boxes: Array[Dictionary] = []
	for child: Node in floor.get_node("Stock").get_children():
		var piece := child as FurnitureItem
		if piece == null:
			_failures.append("something that is not a piece is on the floor in %s" % shop_id)
			continue
		# A piece is not modelled around its own origin, so the box it covers is
		# offset from where the node stands.
		var middle: Vector2 = Catalog.footprint_centre(piece.item_id)
		var yaw := piece.rotation.y
		var at := piece.global_position + Vector3(
			middle.x * cos(yaw) + middle.y * sin(yaw), 0.0,
			-middle.x * sin(yaw) + middle.y * cos(yaw))
		var rect := _plan_rect(at, Catalog.footprint(piece.item_id), yaw)
		boxes.append({"what": piece.item_id, "card": false, "rect": rect})
		_expect(absf(rect.position.x) < ShopFloor.WIDTH * 0.5
			and absf(rect.end.x) < ShopFloor.WIDTH * 0.5
			and absf(rect.position.y) < floor.depth * 0.5
			and absf(rect.end.y) < floor.depth * 0.5,
			"%s is standing through a wall of %s" % [piece.item_id, shop_id])

	# Standing clear on the floor is not enough on its own: a card behind a tall
	# piece is still unreadable. Every card has to be visible from where the
	# camera actually is, which is a question only a ray can answer.
	var camera: Camera3D = floor.rig.camera
	var space: PhysicsDirectSpaceState3D = floor.get_world_3d().direct_space_state
	for child: Node in floor.get_node("Tickets").get_children():
		var card := child as Node3D
		if card == null or not card.has_meta("span"):
			continue
		boxes.append({
			"what": "a price card",
			"card": true,
			"rect": _plan_rect(card.global_position, card.get_meta("span"), 0.0),
		})

		var read_at: Vector3 = card.global_position + (card.get_meta("read_from") as Vector3)
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, read_at)
		query.collide_with_areas = false
		query.collision_mask = FurnitureItem.PICK_LAYER
		var blocked: Dictionary = space.intersect_ray(query)
		if blocked.is_empty():
			continue
		var by := (blocked["collider"] as Node).get_parent() as FurnitureItem
		_failures.append("in %s, %s stands in front of a price card"
			% [shop_id, by.item_id if by != null else "something"])

	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var a: Dictionary = boxes[i]
			var b: Dictionary = boxes[j]
			# A hair off each rect, so two things merely standing shoulder to
			# shoulder do not read as a clash.
			if not (a["rect"] as Rect2).grow(-0.02).intersects((b["rect"] as Rect2).grow(-0.02)):
				continue
			if bool(a["card"]) or bool(b["card"]):
				_failures.append("in %s, %s covers %s" % [shop_id, a["what"], b["what"]])
			else:
				_failures.append("in %s, %s and %s are standing in each other"
					% [shop_id, a["what"], b["what"]])


## The rectangle a thing of this size covers on the floor once it is turned.
func _plan_rect(at: Vector3, size: Vector2, yaw: float) -> Rect2:
	var c := absf(cos(yaw))
	var s := absf(sin(yaw))
	var span := Vector2(size.x * c + size.y * s, size.x * s + size.y * c)
	return Rect2(at.x - span.x * 0.5, at.z - span.y * 0.5, span.x, span.y)


# -------------------------------------------------------------------- sound

## Every sound is synthesised, so there is nothing to fail to load — but a cue
## the bank does not build is silent, and nothing else would ever say so.
func _check_sound() -> void:
	var bank := SoundBank.build_all()
	for name: String in SoundBank.CUES:
		_expect(bank.has(name), "the bank does not build the '%s' cue" % name)
	for name: String in bank:
		_expect(SoundBank.CUES.has(name), "'%s' is built but not listed in CUES" % name)

	# Levelled by loudness rather than peak, so no cue shouts over the others.
	var loudest := 0.0
	var quietest := 1.0
	var longest := 0.0
	for name: String in bank:
		var data: PackedByteArray = bank[name]
		var frames := data.size() / 2
		_expect(frames > SoundBank.GUARD, "the '%s' cue is empty" % name)
		longest = maxf(longest, float(frames) / SoundBank.RATE)
		var level := _rms(data)
		loudest = maxf(loudest, level)
		quietest = minf(quietest, level)
		_expect(_peak(data) < 1.0, "the '%s' cue clips" % name)

	# The mixer reads one frame past whatever it is playing, so every buffer
	# ends in silence it is allowed to read. Getting this wrong is an
	# out-of-bounds read on the audio thread, which on Android takes the app
	# down inside AudioTrack rather than anywhere it can be caught.
	for name: String in bank:
		var data: PackedByteArray = bank[name]
		var tail := 0
		for i in SoundBank.GUARD:
			tail += absi(data.decode_s16(data.size() - (i + 1) * 2))
		_expect(tail == 0, "the '%s' cue has no silent guard on the end" % name)

	# And a looping stream has to stop short of it, because loop_end is
	# inclusive: pointing it at the last frame is what makes the mixer read off
	# the end every time round.
	var bed := SoundBank.stream(SoundBank.build_music(), true)
	var bed_frames := bed.data.size() / 2
	_expect(bed.loop_mode == AudioStreamWAV.LOOP_FORWARD, "the music does not loop")
	_expect(bed.loop_end > 0 and bed.loop_end < bed_frames - 1,
		"the music loops at frame %d of %d, which is past the end of it"
			% [bed.loop_end, bed_frames])
	_expect(loudest / maxf(quietest, 0.0001) < 1.6,
		"the cues are %.1fx apart in loudness" % (loudest / maxf(quietest, 0.0001)))

	# The game asks Audio for cues by name from several files. Anything it asks
	# for that the bank has no answer to is a silent action.
	for asked in _cues_asked_for():
		_expect(SoundBank.CUES.has(asked),
			"the game plays '%s', which the bank does not build" % asked)

	_expect(Audio.is_silent(), "the smoke test should not be making any noise")
	print("sound           %d cues, longest %.1f s, within %.0f%% of each other in level"
		% [bank.size(), longest, (loudest / maxf(quietest, 0.0001) - 1.0) * 100.0])


## Every cue name the game passes to Audio.play(), read out of the source.
func _cues_asked_for() -> Array[String]:
	var found: Array[String] = []
	var pattern := RegEx.create_from_string('Audio\\.play\\("([a-z_]+)"')
	for path in [
		"res://scripts/city/city_ui.gd",
		"res://scripts/design/designer.gd",
		"res://scripts/design/design_ui.gd",
		"res://scripts/ui/ui_kit.gd",
	]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		for match in pattern.search_all(file.get_as_text()):
			var name := match.get_string(1)
			if not found.has(name):
				found.append(name)
		file.close()
	return found


static func _rms(data: PackedByteArray) -> float:
	var n := data.size() / 2
	var sum := 0.0
	for i in n:
		var v := float(data.decode_s16(i * 2)) / 32768.0
		sum += v * v
	return sqrt(sum / maxi(n, 1))


static func _peak(data: PackedByteArray) -> float:
	var top := 0.0
	for i in data.size() / 2:
		top = maxf(top, absf(float(data.decode_s16(i * 2)) / 32768.0))
	return top


# ---------------------------------------------------------------- districts

## A fresh career owns one quarter and can see the rest but not work in them.
func _check_districts() -> void:
	var districts := Jobs.districts()
	_expect(districts.size() >= 2, "the city needs more than one quarter to sell")

	var first := str(districts[0]["id"])
	_expect(Game.is_district_unlocked(first), "the starting quarter should come free")
	_expect(int(districts[0]["cost"]) == 0, "the starting quarter should cost nothing")

	var cost := 0
	for i in range(1, districts.size()):
		var district: Dictionary = districts[i]
		var district_id := str(district["id"])
		_expect(not Game.is_district_unlocked(district_id),
			"%s should start behind its hoarding" % district_id)
		_expect(not Game.can_unlock_district(district_id),
			"%s should not be affordable on day one" % district_id)
		_expect(int(district["cost"]) > cost,
			"%s costs no more than the quarter before it" % district_id)
		cost = int(district["cost"])
		_expect(not Jobs.houses_in(district_id).is_empty(),
			"%s has no houses in it" % district_id)

	_expect(Jobs.unlocked().size() == Jobs.houses_in(first).size(),
		"a new career should only be able to work the first quarter")

	# Every house belongs to a quarter, and sits where that quarter puts it.
	for house: Dictionary in Jobs.all():
		var house_id := str(house["id"])
		var district_id := Jobs.district_of(house_id)
		_expect(not Jobs.get_district(district_id).is_empty(),
			"%s is in an unknown quarter" % house_id)
		var origin: Vector2 = Jobs.get_district(district_id)["origin"]
		_expect(Jobs.world_position(house_id) == origin + (house["map"]["pos"] as Vector2),
			"%s is not placed relative to its quarter" % house_id)

	print("districts       %d quarters, %d houses, %s to own the city outright"
		% [districts.size(), Jobs.all().size(), UIKit.money(_city_price())])


func _city_price() -> int:
	var total := 0
	for district: Dictionary in Jobs.districts():
		total += int(district["cost"])
	return total


# --------------------------------------------------------------- the estate

## The crafting loop, end to end and through the screens the player uses: buy
## ground and work it, hand a job over and watch the yard fill, put the material
## through a works, and fit the goods into furniture already in stock. Then hand
## a room of improved pieces over and check the improvement actually paid.
## The perk tree. Runs on a fresh career, before a point has been earned, so the
## gates and the arithmetic can be checked from nothing — then puts the profile
## back the way it found it and lets the career spend its own points.
func _check_perks() -> void:
	var lines := Perks.lines()
	_expect(lines.size() == 4, "the tree has %d lines, not four" % lines.size())

	# The tree has to be bigger than a career, or there is nothing to choose.
	var steps: int = lines.size() * Perks.RANKS
	var points: int = Game.MAX_LEVEL - 1
	_expect(steps > points,
		"%d steps against %d points, so a whole career can buy the whole tree"
			% [steps, points])
	for line: Dictionary in lines:
		_expect(int((line["steps"] as Array).size()) == Perks.RANKS,
			"%s names %d steps for its %d" % [line["id"],
			(line["steps"] as Array).size(), Perks.RANKS])
		_expect(Perks.value_at(str(line["id"]), Perks.RANKS) > 0.0,
			"%s is worth nothing at the top of it" % line["id"])
	_expect(Perks.level_for_rank(Perks.RANKS) <= Game.MAX_LEVEL,
		"the last step of a line opens at level %d, above the cap"
			% Perks.level_for_rank(Perks.RANKS))

	# Nothing is earned at level one, and nothing can be taken.
	_expect(Game.perk_points_earned() == 0, "a new career started with points in hand")
	_expect(not Game.can_take_perk("haggler"), "a step could be taken with no points")

	Game.level = 2
	_expect(Game.perk_points_left() == 1, "the second level did not hand over a point")
	_expect(Game.take_perk("haggler"), "the first step could not be taken")
	_expect(Game.perk_rank("haggler") == 1, "taking a step did not raise the rank")
	_expect(Game.perk_points_left() == 0, "a taken step did not cost its point")
	_expect(not Game.take_perk("haggler"), "a second step was taken on one point")

	# The level gate, which is what stops one line being finished by level nine.
	Game.level = Game.MAX_LEVEL
	_expect(Game.perk_points_left() == Game.MAX_LEVEL - 2,
		"the levels between did not each hand over a point")
	Game.perk_ranks["stager"] = Perks.RANKS
	_expect(not Game.can_take_perk("stager"), "a line went past its last step")
	Game.perk_ranks["stager"] = 0
	Game.level = Perks.level_for_rank(3) - 1
	Game.perk_ranks["scholar"] = 2
	_expect(not Game.can_take_perk("scholar"),
		"a step was taken a level before it opens")
	Game.level = Perks.level_for_rank(3)
	_expect(Game.can_take_perk("scholar"), "a step did not open at its own level")

	# Haggling. What a shop asks comes down, and what it gives back comes down
	# with it — so buying and selling is still a wash, whatever the rank.
	Game.perk_ranks = {}
	Game.earn(5000)
	var full := Game.buy_price("sofa")
	_expect(full == Catalog.price("sofa"), "an unhaggled sofa is not its shelf price")
	Game.perk_ranks["haggler"] = Perks.RANKS
	var cut := Game.buy_price("sofa")
	_expect(cut < full, "the whole Haggler line took nothing off a sofa")
	_expect(Game.supply_price("lumber") < Catalog.trade_price("lumber"),
		"haggling does not reach the merchant")
	var purse := Game.money
	Game.buy_item("sofa", 1)
	_expect(Game.money == purse - cut, "a sofa did not cost the haggled price")
	Game.sell_item("sofa", 1)
	_expect(Game.money == purse, "selling a haggled sofa back was not a wash")

	# Out of town. Everything on a clock runs quicker, and the bench takes more
	# under the clamps at once — but a holding still only holds what it held.
	Game.perk_ranks = {}
	var slow := Industry.batch_seconds("sawmill")
	var bare := Industry.hold_cap(Industry.SITES[0], 2)
	var one := Game.bench_slots()
	Game.perk_ranks["grafter"] = Perks.RANKS
	_expect(Industry.batch_seconds("sawmill") < slow, "the works did not speed up")
	_expect(Industry.rate_at(Industry.SITES[0], 2)
		> Industry.yield_per_hour(Industry.SITES[0], 2), "the ground did not speed up")
	_expect(Industry.hold_cap(Industry.SITES[0], 2) == bare,
		"a perk made the barn bigger as well as the crop faster")
	_expect(Game.bench_slots() > one, "the bench never took a second piece")

	# Two under the clamps really are made at the same time.
	Game.supplies = {}
	for material: String in Catalog.bill_of("chair"):
		Game.supplies[material] = int(Catalog.bill_of("chair")[material]) * 2
	Game.making = []
	Game.start_making("chair")
	Game.start_making("chair")
	Game.clock_offset += Catalog.make_seconds("chair") + 1.0
	_expect(Game.made_waiting() == 2,
		"a bench with room for two still made them one after the other")

	_check_staff()

	Game.reset()
	print("trade           %d steps across %d lines against %d points; %s off, "
		% [steps, lines.size(), points, Perks.value_line("haggler", Perks.RANKS)]
		+ "%s on a fee, %s on what it teaches, %s faster out of town"
			% [Perks.value_line("stager", Perks.RANKS),
			Perks.value_line("scholar", Perks.RANKS),
			Perks.value_line("grafter", Perks.RANKS)])


## The people on the books. Each of the four is checked by doing the chore they
## are supposed to have taken off you and finding it already done.
func _check_staff() -> void:
	var roles := Staff.roles()
	_expect(roles.size() == 4, "the books have %d roles, not four" % roles.size())
	var payroll := 0.0
	for role: Dictionary in roles:
		_expect(int(role["level"]) <= Game.MAX_LEVEL,
			"%s only looks for work at level %d, above the cap"
				% [role["id"], role["level"]])
		_expect(float(role["share"]) > 0.0, "%s works for nothing" % role["id"])
		payroll += float(role["share"])
	# Everybody at once has to be a real bite out of a fee and nowhere near all
	# of it, or the decision is not one.
	_expect(payroll > 0.05 and payroll < 0.35,
		"the whole payroll comes to %.0f%% of a fee" % (payroll * 100.0))

	Game.reset()
	Game.level = Game.MAX_LEVEL
	Game.earn(90000)

	# Hiring, the fee for it, and letting somebody go again.
	_expect(Game.wage_share() == 0.0, "an empty payroll still costs something")
	var purse := Game.money
	var fee := Staff.joining_fee(Game.level)
	_expect(Game.hire("runner"), "nobody could be taken on")
	_expect(Game.money == purse - fee, "taking somebody on did not cost the joining fee")
	_expect(Game.is_hired("runner"), "the runner did not go on the books")
	_expect(is_equal_approx(Game.wage_share(), Staff.share_of("runner")),
		"one person on the books is not one person's share")
	_expect(not Game.hire("runner"), "the same person was taken on twice")
	_expect(Game.let_go("runner"), "nobody could be let go")
	_expect(Game.wage_share() == 0.0, "letting somebody go did not stop their share")
	_expect(not Game.let_go("runner"), "somebody was let go twice")

	# Rosa. A brief's whole list, in one go, at the counters' own prices.
	var house_id := str(Jobs.all()[0]["id"])
	Game.hire("runner")
	var basket := Jobs.shopping_list(house_id)
	var bill := Jobs.list_cost(basket)
	for paint: Dictionary in Jobs.missing_paints(house_id):
		bill += Game.paint_price(paint["entry"])
	purse = Game.money
	var fetched := Game.send_the_runner(house_id)
	_expect(fetched > 0, "the runner came back with nothing")
	_expect(Game.money == purse - bill,
		"the runner spent %d of the %d the list came to" % [purse - Game.money, bill])
	for item_id: String in basket:
		_expect(Game.stock_of(item_id) >= int(basket[item_id]),
			"the runner did not bring back %s" % item_id)
	_expect(Jobs.shopping_list(house_id).is_empty(),
		"the brief still wants something after the runner has been round")
	# And she cannot spend money that is not there.
	var broke := Game.money
	Game.spend(broke)
	_expect(Game.send_the_runner("the_observatory") == -1,
		"the runner shopped on an empty account")
	Game.earn(90000)

	# Tomas. A holding that has filled up is carted in without being tapped.
	Game.let_go("runner")
	var site: Dictionary = Industry.sites()[0]
	var site_id := str(site["id"])
	Game.sites[site_id] = 2
	Game.site_since[site_id] = Game.now()
	Game.clock_offset += Industry.HOUR * 4.0
	Game.settle_estate()
	_expect(Game.waiting_at(site_id) > 0, "four hours on a holding grew nothing")
	Game.hire("hand")
	Game.settle_estate()
	_expect(Game.waiting_at(site_id) == 0, "the yard hand left the holding standing")
	_expect(Game.material_count(str(site["yields"])) > 0,
		"the yard hand carted it off to nowhere")

	# And a heap he is working runs three times as long before the ground stops.
	# The yard's own capacity is untouched, which is the ceiling that is meant to
	# be built rather than hired.
	var deep := Game.heap_cap(site, 2)
	var store := Game.material_cap(str(site["yields"]))
	Game.let_go("hand")
	_expect(Game.heap_cap(site, 2) == Industry.hold_cap(site, 2),
		"a holding nobody works still holds more than its own heap")
	_expect(deep > Game.heap_cap(site, 2),
		"the yard hand made no difference to how much a holding will pile up")
	_expect(Game.material_cap(str(site["yields"])) == store,
		"the yard hand made the yard itself bigger")
	Game.hire("hand")

	# Ada. A works with the material for a run has one on it without being asked.
	var works_id := str(Industry.works()[0]["id"])
	var plant: Dictionary = Industry.get_works(works_id)
	var good: Dictionary = Industry.get_good(str(plant["makes"]))
	Game.plants[works_id] = 1
	Game.materials[str(good["from"])] = int(good["takes"]) * 3
	Game.settle_estate()
	_expect(Game.batch_left(works_id) < 0.0,
		"a works put a run on with nobody employed to do it")
	Game.hire("millwright")
	Game.settle_estate()
	_expect(Game.batch_left(works_id) >= 0.0, "the millwright never put a run on")
	# And takes the finished run off and puts the next one straight on.
	Game.clock_offset += Industry.batch_seconds(works_id) + 1.0
	Game.settle_estate()
	_expect(Game.good_count(str(good["id"])) > 0,
		"the millwright left a finished run on the line")

	# Petar. Whatever came off the bench last goes back on it.
	Game.making = []
	Game.supplies = {}
	Game.last_made = ""
	for material: String in Catalog.bill_of("chair"):
		Game.supplies[material] = int(Catalog.bill_of("chair")[material]) * 4
	Game.start_making("chair")
	_expect(Game.last_made == "chair", "the bench did not remember what was on it")
	Game.clock_offset += Catalog.make_seconds("chair") + 1.0
	Game.collect_made()
	Game.settle_estate()
	_expect(Game.making.is_empty(),
		"the bench refilled itself with no joiner on the books")
	Game.hire("joiner")
	Game.settle_estate()
	_expect(Game.making.size() == Game.bench_slots(),
		"the joiner filled %d of the bench's %d clamps"
			% [Game.making.size(), Game.bench_slots()])
	# And stops when the store runs dry rather than making out of thin air.
	Game.supplies = {}
	Game.clock_offset += Catalog.make_seconds("chair") + 1.0
	Game.collect_made()
	Game.settle_estate()
	_expect(Game.making.is_empty(), "the joiner made a chair out of nothing")

	# The wage comes out of a fee and out of nothing else.
	Game.reset()
	Game.level = Game.MAX_LEVEL
	Game.earn(90000)
	var bare := Game.money
	Game.record_completion("_wages_test", 10000, 2000, 0, 0, 2)
	var without := Game.money - bare
	Game.reset()
	Game.level = Game.MAX_LEVEL
	Game.earn(90000)
	for role: Dictionary in roles:
		Game.hire(str(role["id"]))
	bare = Game.money
	var owed := Game.wages_on(12000)
	Game.record_completion("_wages_test", 10000, 2000, 0, 0, 2)
	_expect(Game.money - bare == without - owed,
		"a fee with four on the books paid %d, not the %d it owes them"
			% [Game.money - bare, without - owed])
	_expect(owed > 0, "four people on the books were paid nothing")

	print("staff           %d on the books at %d%% of a fee between them; "
		% [roles.size(), int(round(payroll * 100.0))]
		+ "joining costs %s at the cap" % UIKit.money(Staff.joining_fee(Game.MAX_LEVEL)))


## The floor of your own. Every other room belongs to a client; this one keeps
## what you stand in it and pays for as long as it is dressed, off the same
## review that used to fire once at a hand-over and never again.
func _check_showroom() -> void:
	var main = get_tree().current_scene

	# The arithmetic first, where it can be pinned down exactly.
	_expect(Showroom.takings(3, 10000, 6, Showroom.MIN_PIECES - 1) == 0,
		"a floor with almost nothing on it still traded")
	_expect(Showroom.takings(0, 10000, 6, 20) == 0,
		"a floor nobody would walk into still traded")
	_expect(Showroom.takings(3, 10000, 6, 20) > Showroom.takings(2, 10000, 6, 20),
		"arranging the floor better was worth nothing")
	_expect(Showroom.takings(2, 10000, 6, 20) > Showroom.takings(2, 10000, 1, 20),
		"a spread of counters was worth nothing")
	_expect(Showroom.takings(2, 20000, 6, 20) > Showroom.takings(2, 10000, 6, 20),
		"a dearer floor was worth nothing")
	# A cheap floor arranged well has to beat a dear one thrown together, or the
	# design is not the mechanic and the money is.
	_expect(Showroom.takings(3, 12000, 6, 20) > Showroom.takings(1, 20000, 6, 20),
		"an expensive floor thrown together beats a cheap one arranged well")

	# No reset here: the career's finished houses are still wanted by the checks
	# that come after this one, and it never touches the floor anyway.
	Game.earn(90000)
	_expect(Game.showroom_open(), "the showroom never opens")
	_expect(not Game.showroom_dressed(), "a fresh career came with a floor already dressed")
	_expect(Game.showroom_take == 0, "an empty floor takes something an hour")

	# Stock for it, then the floor itself. This is a job's rules without a job:
	# the furniture leaves the warehouse and nobody takes it away.
	var kit := ["sofa", "coffee_table", "armchair", "bookshelf", "floor_lamp", "rug"]
	for item_id in kit:
		if not Game.buy_item(item_id, 1):
			_failures.append("the showroom check could not stock %s" % item_id)
			return
	var warehouse := Game.total_stock()

	main.enter_designer(Game.SHOWROOM)
	await _settle()
	var designer = main.designer
	_expect(designer != null, "the showroom did not open")
	if designer == null:
		return
	_expect(designer.showroom_mode(), "the showroom opened as something else")
	_expect(not designer.job_mode(), "the showroom opened as a client's job")
	_expect(designer.costs_stock(), "the showroom is furnished out of thin air")
	_expect(not designer.ui._finish_button.visible,
		"the showroom offered to hand itself over to somebody")
	# No brief to tick — but the same six things anybody notices walking in, now
	# that the floor is paid on them.
	_expect(designer.ui._brief_button.text == "Verdict",
		"the showroom came with a brief")

	for item_id in kit:
		designer._on_place_item(item_id)
	_expect(Game.total_stock() == warehouse - kit.size(),
		"dressing the floor did not take the furniture out of the warehouse")
	var rating: Dictionary = designer.showroom_rating()
	_expect((rating.get("notes", []) as Array).size() >= 5,
		"the floor is rated without saying why")
	_expect(int(rating["pieces"]) == kit.size(),
		"the floor counted %d pieces of the %d standing on it"
			% [rating["pieces"], kit.size()])
	_expect(int(rating["value"]) > 0, "the floor is worth nothing with stock on it")
	_expect(int(rating["shops"]) > 1, "six pieces came from one counter")

	# A piece pulled back off the floor is in the warehouse again, the same as
	# taking one out of a client's room.
	designer._select(designer._items()[0])
	designer._store_selected()
	_expect(Game.total_stock() == warehouse - kit.size() + 1,
		"a piece taken off the floor did not come back to the warehouse")
	designer._on_place_item(kit[0])

	main.enter_city()
	await _settle()

	# Closing up caches what the floor reads as, because the till goes on filling
	# while the room is not built and there is nothing to measure then.
	_expect(Game.showroom_dressed(), "leaving the floor did not save it")
	_expect(Game.showroom_stars > 0, "a dressed floor was rated at nothing")
	_expect(Game.showroom_take > 0, "a dressed floor takes nothing an hour")
	_expect(Game.showroom_value > 0, "a dressed floor is worth nothing")
	_expect(Game.till() == 0, "the till had money in it before any time passed")

	# It fills on the wall clock, and stops at a trading day.
	Game.clock_offset += Industry.HOUR * 3.0
	Game.settle_showroom()
	var after_three := Game.till()
	_expect(after_three == Game.showroom_take * 3,
		"three hours took %d, not the %d it should" % [after_three, Game.showroom_take * 3])
	Game.clock_offset += Industry.HOUR * 24.0 * 7.0
	Game.settle_showroom()
	_expect(Game.till() == Game.till_cap(),
		"a week on the floor stood at %d, not the %d the till holds"
			% [Game.till(), Game.till_cap()])
	_expect(Game.till_cap() == Showroom.till_cap(Game.showroom_take),
		"the till holds something other than a trading day")

	# And emptying it is money, once.
	var purse := Game.money
	var taken := Game.collect_till()
	_expect(taken == Game.till_cap(), "the till paid out %d of the %d in it"
		% [taken, Game.till_cap()])
	_expect(Game.money == purse + taken, "emptying the till paid nothing")
	_expect(Game.till() == 0, "the till still had money after it was emptied")
	_expect(Game.collect_till() == 0, "the till paid out twice")

	print("showroom        %s of stock reads %s across %d counters and takes %s "
		% [UIKit.money(Game.showroom_value),
		RoomReview.stars_text(Game.showroom_stars), Game.showroom_shops,
		UIKit.money(Game.showroom_take)]
		+ "an hour, %s a trading day" % UIKit.money(Game.till_cap()))


func _check_estate() -> void:
	var main = get_tree().current_scene

	# Everything below is about what the ground, the works and the bench do on
	# their own. The career hired the people whose whole job is doing it for
	# you, so they stand down for this and go back on the books afterwards.
	var books := Game.hired_ids()
	for role_id in books:
		Game.let_go(role_id)

	# Nothing out of town may be gated above the cap, or it could never be had.
	for entry: Dictionary in Industry.sites():
		_expect(int(entry["level"]) <= Game.MAX_LEVEL,
			"%s is gated at level %d, above the cap" % [entry["id"], entry["level"]])
	for entry: Dictionary in Industry.works():
		_expect(int(entry["level"]) <= Game.MAX_LEVEL,
			"%s is gated at level %d, above the cap" % [entry["id"], entry["level"]])
		_expect(not Industry.get_good(str(entry["makes"])).is_empty(),
			"%s makes '%s', which is not a good" % [entry["id"], entry["makes"]])
	for good: Dictionary in Industry.goods():
		_expect(not Industry.works_for(str(good["id"])).is_empty(),
			"nothing makes %s" % good["id"])
		_expect(not Industry.get_material(str(good["from"])).is_empty(),
			"%s is made from '%s', which is not a material" % [good["id"], good["from"]])

	main.enter_estate()
	await _settle()
	_expect(main.estate != null, "the estate did not open")
	_expect(main.city == null, "the map was left running under the estate")
	if main.estate == null:
		return
	# One map: every holding, every works and the bench, all on it.
	var want: int = Industry.sites().size() + Industry.works().size() + 1
	_expect(main.estate.get_node("Plots").get_child_count() == want,
		"the estate put out %d plots for the %d it has"
			% [main.estate.get_node("Plots").get_child_count(), want])

	# Buying ground, through the sheet's own button.
	var site: Dictionary = Industry.sites()[0]
	var site_id := str(site["id"])
	var price := Game.step_price(int(site["cost"]), 0)
	var money := Game.money
	main.estate_ui.buy_site.emit(site_id)
	await get_tree().process_frame
	_expect(Game.site_tier(site_id) == 1, "buying %s did not put it in hand" % site_id)
	_expect(Game.money == money - price, "%s did not cost its asking price" % site_id)

	# Working it up again costs more than the first step did.
	money = Game.money
	var step_up := Game.step_price(int(site["cost"]), 1)
	_expect(step_up > price, "working a holding up costs no more than buying it")
	main.estate_ui.buy_site.emit(site_id)
	await get_tree().process_frame
	_expect(Game.site_tier(site_id) == 2, "%s did not work up a level" % site_id)
	_expect(Game.money == money - step_up, "working %s up did not cost the stepped price" % site_id)

	# The holding fills on the wall clock. Nothing ticks in the background, so
	# pushing the clock forward is exactly what a night away looks like.
	var material := str(site["yields"])
	_expect(Game.waiting_at(site_id) == 0, "%s had a crop before any time passed" % site_id)
	Game.clock_offset += Industry.HOUR * 2.0
	Game.settle_estate()
	var two_hours := int(Industry.rate_at(site, 2) * 2.0)
	_expect(Game.waiting_at(site_id) == two_hours,
		"two hours on %s grew %d, not %d" % [site_id, Game.waiting_at(site_id), two_hours])

	# And it stops when it is full, rather than filling for ever.
	Game.clock_offset += Industry.HOUR * 24.0 * 7.0
	Game.settle_estate()
	var hold := Industry.hold_cap(site, 2)
	_expect(Game.waiting_at(site_id) == hold,
		"a week on %s stood at %d, not the %d it holds"
			% [site_id, Game.waiting_at(site_id), hold])

	# Carting it off puts it in the yard, and the yard has a cap of its own.
	var in_yard := Game.material_count(material)
	main.estate_ui.collect_site.emit(site_id)
	await get_tree().process_frame
	var room: int = mini(hold, Game.material_cap(material) - in_yard)
	_expect(Game.material_count(material) == in_yard + room,
		"carting %s off moved %d, not the %d there was room for"
			% [site_id, Game.material_count(material) - in_yard, room])
	_expect(Game.waiting_at(site_id) == hold - room,
		"what the yard could not take should have stayed in the ground")
	_expect(Game.material_count(material) <= Game.material_cap(material),
		"the yard took more %s than it holds" % material)

	# The works: material in, a run that takes time, goods out. Same map — the
	# holdings and the plants are two ends of one road now.
	# Whichever works serves the sofa, since the sofa is what goes on the bench.
	var plant: Dictionary = Industry.works_for(Industry.grain_of("sofa"))
	_expect(not plant.is_empty(), "nothing makes what a sofa wants")
	if plant.is_empty():
		return
	var works_id := str(plant["id"])
	var good: Dictionary = Industry.get_good(str(plant["makes"]))
	var feed := str(good["from"])
	# Make sure there is something to put through, whichever works this turned
	# out to be — the sofa decides it, and the sofa may change.
	Game.materials[feed] = Game.material_count(feed) + int(good["takes"]) * 4
	main.estate_ui.buy_works.emit(works_id)
	await get_tree().process_frame
	_expect(Game.works_tier(works_id) == 1, "%s was not built" % works_id)

	var stock := Game.material_count(feed)
	var made := Game.good_count(str(good["id"]))
	main.estate_ui.run_works.emit(works_id)
	await get_tree().process_frame
	_expect(Game.material_count(feed) == stock - int(good["takes"]),
		"putting a run on at %s did not take its material" % works_id)
	_expect(Game.good_count(str(good["id"])) == made,
		"a run at %s made its goods before it had run" % works_id)
	_expect(Game.batch_left(works_id) > 0.0, "the run at %s started finished" % works_id)
	_expect(not Game.batch_ready(works_id), "the run at %s was ready at once" % works_id)

	# Nothing comes off before the time is up, and nothing else can go on.
	main.estate_ui.collect_batch.emit(works_id)
	await get_tree().process_frame
	_expect(Game.good_count(str(good["id"])) == made,
		"a run at %s could be taken off early" % works_id)
	_expect(Game.batches_available(works_id) == 0,
		"%s took a second run while the first was still on" % works_id)

	Game.clock_offset += Industry.batch_seconds(works_id) + 1.0
	_expect(Game.batch_ready(works_id), "the run at %s never came off" % works_id)
	main.estate_ui.collect_batch.emit(works_id)
	await get_tree().process_frame
	_expect(Game.good_count(str(good["id"])) == made + 1,
		"taking the run off %s left nothing behind" % works_id)
	_expect(Game.batch_left(works_id) < 0.0, "the finished run stayed on the line")

	# The store fills up too, and a full store will not take a run.
	var full: int = Game.good_cap(str(good["id"]))
	Game.goods[str(good["id"])] = full
	Game.materials[feed] = Game.material_count(feed) + int(good["takes"]) * 4
	_expect(Game.batches_available(works_id) == 0,
		"%s would run into a store that is already full" % works_id)
	Game.goods[str(good["id"])] = made

	# The bench: goods into furniture the player owns.
	Game.buy_item("sofa", 1)
	var cost: Dictionary = Industry.upgrade_cost("sofa")
	Game.goods[str(cost["good"])] = int(cost["goods"])
	money = Game.money
	main.estate_ui.improve_item.emit("sofa")
	await get_tree().process_frame
	_expect(Game.quality_of("sofa") == 1, "the bench did not improve the sofa")
	_expect(Game.good_count(str(cost["good"])) == 0, "the bench did not use up its goods")
	_expect(Game.money == money - int(cost["money"]), "the bench did not charge its fee")
	_expect(not Game.can_improve("sofa"), "the sofa can be improved again with an empty yard")

	await _check_workshop()

	main.enter_city()
	await _settle()

	print("estate          %s fills at %d an hour and holds %d; %s runs %s a batch"
		% [site_id, int(Industry.yield_per_hour(site, 2)), Industry.hold_cap(site, 2),
		works_id, Game.spell_out(Industry.batch_seconds(works_id))])
	for role_id in books:
		Game.staff[role_id] = true
	await _check_craft_pays()


## Making furniture out of trade material. The point of the whole thing is that
## it comes out cheaper than the shelf and teaches you something on the way, so
## that is what is checked — on every piece in the catalogue, not one of them.
func _check_workshop() -> void:
	var main = get_tree().current_scene

	# Every piece has to be worth making, and worth about as much as every other
	# piece is — a glazed cabinet that costs four fifths of its shelf price in
	# material while a wooden one costs a third would be two different games.
	var thickest := 0.0
	var thinnest := 1.0
	for item_id in Catalog.ids():
		var bill := Catalog.bill_of(item_id)
		if bill.is_empty():
			_failures.append("%s has no bill of materials, so it can never be made"
				% item_id)
			continue
		var shelf := Catalog.price(item_id)
		var cost := Catalog.bill_cost(bill)
		var share := float(cost) / float(shelf)
		if share > 0.75:
			_failures.append("%s saves too little to be worth making (%d of %d)"
				% [item_id, cost, shelf])
		if share < 0.35:
			_failures.append("%s is nearly free to make (%d of %d)"
				% [item_id, cost, shelf])
		thickest = maxf(thickest, share)
		thinnest = minf(thinnest, share)
		for material: String in bill:
			if Catalog.get_trade(material).is_empty():
				_failures.append("%s calls for '%s', which the yard does not sell"
					% [item_id, material])

	# The merchant's floor, and a pallet picked off it.
	main.enter_shop("yard")
	await _settle()
	var floor_view = main.shop
	_expect(floor_view != null and floor_view.is_yard(), "the yard did not open")
	if floor_view != null:
		var pallets := 0
		for child in floor_view.get_node("Tins").get_children():
			if (child as Node).has_meta("supply"):
				pallets += 1
		_expect(pallets == Catalog.trade().size(),
			"the yard put out %d pallets for the %d things it sells"
				% [pallets, Catalog.trade().size()])

	# Buying by the unit, through the card's own buttons.
	var money := Game.money
	main.shop_ui.buy_supply_requested.emit("lumber", 10)
	await get_tree().process_frame
	_expect(Game.supply_count("lumber") == 10, "ten boards did not land in the store")
	_expect(Game.money == money - Game.supply_price("lumber") * 10,
		"the yard did not charge for ten boards")
	main.shop_ui.sell_supply_requested.emit("lumber", 4)
	await get_tree().process_frame
	_expect(Game.supply_count("lumber") == 6, "selling four boards back left the wrong count")
	_expect(Game.money == money - Game.supply_price("lumber") * 6,
		"selling back at the yard did not refund what it cost")

	main.enter_estate()
	await _settle()

	# A chair off the bench. Its bill is bought, it is started, and it is not
	# there until its time is up.
	var made_id := "chair"
	Game.supplies = {}
	for material: String in Catalog.bill_of(made_id):
		Game.buy_supply(material, int(Catalog.bill_of(made_id)[material]))
	_expect(Game.can_make(made_id), "the store holds a chair's bill and still cannot make one")

	var held := Game.stock_of(made_id)
	var xp := Game.xp
	main.estate_ui.make_item.emit(made_id)
	await get_tree().process_frame
	_expect(Game.making.size() == 1, "starting a chair put nothing on the bench")
	_expect(Game.stock_of(made_id) == held, "a chair appeared before it was made")
	for material: String in Catalog.bill_of(made_id):
		_expect(Game.supply_count(material) == 0,
			"making a chair left its %s in the store" % material)
	_expect(not Game.can_make(made_id), "a second chair could be started out of thin air")

	main.estate_ui.collect_made.emit()
	await get_tree().process_frame
	_expect(Game.stock_of(made_id) == held, "an unfinished chair came off the bench")

	Game.clock_offset += Catalog.make_seconds(made_id) + 1.0
	_expect(Game.made_waiting() == 1, "the chair never finished")
	main.estate_ui.collect_made.emit()
	await get_tree().process_frame
	_expect(Game.stock_of(made_id) == held + 1, "the finished chair never reached the warehouse")
	_expect(Game.making.is_empty(), "the finished chair stayed on the bench")
	_expect(Game.xp > xp or Game.level == Game.MAX_LEVEL,
		"making a chair taught nothing")

	# The bench runs as many at once as it has clamps for, and one more than that
	# waits its turn. How many clamps there are is whatever the Grafter line has
	# bought, so this is checked against that rather than against a number.
	var slots := Game.bench_slots()
	Game.supplies = {}
	for material: String in Catalog.bill_of(made_id):
		Game.buy_supply(material, int(Catalog.bill_of(made_id)[material]) * (slots + 1))
	for i in slots + 1:
		Game.start_making(made_id)
	_expect(Game.making.size() == slots + 1, "the bench would not take them all on")
	Game.clock_offset += Catalog.make_seconds(made_id) + 1.0
	_expect(Game.made_waiting() == slots,
		"a bench with %d clamp%s finished %d pieces in the time one of them takes"
			% [slots, "" if slots == 1 else "s", Game.made_waiting()])
	Game.clock_offset += Catalog.make_seconds(made_id) + 1.0
	_expect(Game.made_waiting() == slots + 1, "the one that queued never came off")
	Game.collect_made()

	print("workshop        material is %.0f%%–%.0f%% of the shelf price; a chair "
		% [thinnest * 100.0, thickest * 100.0]
		+ "takes %s and %s of timber"
			% [Game.spell_out(Catalog.make_seconds(made_id)),
			UIKit.money(Catalog.bill_cost(Catalog.bill_of(made_id)))])


## Improving furniture is meant to lift the fee and the experience of the room
## it stands in. Furnishes a repeat job entirely out of improved stock and
## checks the money that came back carries the craft bonus.
func _check_craft_pays() -> void:
	var main = get_tree().current_scene
	var house_id := _biggest_finished_house()
	if house_id == "":
		_failures.append("the craft check needs a finished house to work again")
		return
	var contract := Jobs.generate_contract(house_id, Game.level)
	if contract.is_empty():
		return
	Game.take_repeat_contract(house_id, contract)

	var job: Dictionary = Jobs.get_job(house_id)
	var basket := Jobs.shopping_list(house_id)
	for item_id: String in basket:
		if not Game.buy_item(item_id, int(basket[item_id])):
			_failures.append("the craft check could not stock %s" % item_id)
			return
	for paint: Dictionary in Jobs.missing_paints(house_id):
		Game.buy_paint(str(paint["surface"]), paint["entry"])

	# Everything that will stand in the room, straight to the top of the bench.
	for item_id: String in basket:
		Game.quality[item_id] = Industry.MAX_TIER

	main.enter_designer(house_id)
	await _settle()
	var designer = main.designer
	_furnish(designer, job)
	if not Jobs.all_met(Jobs.evaluate(house_id, designer._context())):
		_failures.append("the craft check could not finish %s" % house_id)
		main.enter_city()
		await _settle()
		return

	var tiers: Array = []
	for item in designer._items():
		tiers.append(Game.quality_of(item.item_id))
	var craft := Industry.quality_bonus(tiers)
	_expect(craft > 0.0, "a room of Master furniture earned no craft bonus")

	var review := RoomReview.score(designer._review_entries(), designer.room.area(),
		designer.installed_value(), int(job["budget"]))
	var payout := int(job["payout"])
	var money := Game.money
	designer._on_finish()
	main.enter_city()
	await _settle()

	# Everything that rides the fee: the client's own review, the Stager line,
	# and — now the brief asks what the room has to do rather than naming the
	# pieces — the chance that the answer landed in the school this client
	# actually likes.
	var earned := float(review["bonus_rate"]) + Game.fee_bonus()
	if str(review["voice"]) == Jobs.taste_of(house_id) \
			and str(review["voice"]) != Catalog.PLAIN:
		earned += RoomReview.TASTE_BONUS
	var plain := payout + int(round(float(payout) * earned))
	var gross := payout + int(round(float(payout) * (earned + craft)))
	# What lands in the account is the fee less whatever the books take out of it.
	var withcraft := gross - Game.wages_on(gross)
	_expect(Game.money - money == withcraft,
		"%s paid %d, not the %d a room of improved furniture is worth"
			% [house_id, Game.money - money, withcraft])
	_expect(gross > plain, "the craft bonus added nothing to the fee")
	# The same bonus rides the experience. The career ends pinned at the cap, so
	# the reward itself is what has to be checked rather than the bar.
	var taught := float(job["xp"]) * (0.8 + 0.2 * float(review["stars"]))
	_expect(int(round(taught * (1.0 + craft))) > int(round(taught)),
		"the craft bonus added nothing to what the job teaches")
	print("craft           %s paid %s over the plain fee at %.0f%% craft"
		% [house_id, UIKit.money(gross - plain), craft * 100.0])


## Buys a quarter, grinding repeat work at the houses already finished until the
## money and the level are there. Returns false if it could not be reached.
func _acquire(district: Dictionary) -> bool:
	var district_id := str(district["id"])
	if Game.is_district_unlocked(district_id):
		return true

	var asking := Game.district_price(district_id)
	var needed_level := int(district["level"])
	var money_before := Game.money
	var contracts := 0
	while (Game.money < asking or Game.level < needed_level) and contracts < 60:
		if not await _take_repeat():
			break
		contracts += 1

	if not Game.unlock_district(district_id):
		_failures.append("could not buy %s: %s at level %d, wanted %s at level %d"
			% [district_id, UIKit.money(Game.money), Game.level,
				UIKit.money(asking), needed_level])
		return false
	print("--- bought %-18s %s after %d repeat job%s (had %s, %s left)" % [
		district["name"], UIKit.money(int(district["cost"])), contracts,
		"" if contracts == 1 else "s", UIKit.money(money_before), UIKit.money(Game.money)])
	_expect(Game.money >= Jobs.district_float(district_id),
		"buying %s left nothing to go shopping with" % district_id)
	return true


## Takes one repeat contract at the best-paying finished house and works it.
## This is how a player closes a gap — in money towards the next quarter, or in
## levels towards a house still out of reach. False when there is no repeat to
## be had, or when one did not pay.
func _take_repeat() -> bool:
	var house_id := _biggest_finished_house()
	if house_id == "":
		return false
	var contract := Jobs.generate_contract(house_id, Game.level)
	if contract.is_empty():
		return false
	var before := Game.money
	Game.take_repeat_contract(house_id, contract)
	await _play(Jobs.get_job(house_id))
	if Game.money <= before:
		_failures.append("repeat work at %s did not pay: %s -> %s"
			% [house_id, UIKit.money(before), UIKit.money(Game.money)])
		return false
	return true


## Works a quarter until every house in it has been handed over. Cheapest brief
## first, the way anyone short of money would — and when everything left is
## still above the player's level, repeat work at a finished house is what
## closes the gap. That is what the level gates are there to make you do.
func _work_quarter(district: Dictionary) -> void:
	var remaining: Array[Dictionary] = Jobs.houses_in(str(district["id"]))
	var grinds := 0
	while not remaining.is_empty():
		remaining.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return Jobs.minimum_outlay(str(a["id"])) < Jobs.minimum_outlay(str(b["id"])))

		var next := -1
		for i in remaining.size():
			if Game.level >= int(remaining[i]["level"]):
				next = i
				break

		if next < 0:
			if grinds >= 40 or not await _take_repeat():
				_failures.append(
					"%s cannot be finished: %d house%s left above level %d" % [
						district["id"], remaining.size(),
						"" if remaining.size() == 1 else "s", Game.level])
				return
			grinds += 1
			continue

		var job: Dictionary = remaining[next]
		remaining.remove_at(next)
		await _play(job)

	if grinds > 0:
		print("--- %s took %d repeat job%s to reach the level for the rest" % [
			district["name"], grinds, "" if grinds == 1 else "s"])


## The finished house with the most floor, which is where a repeat contract pays
## best — the generator scales the brief to the size of the room.
func _biggest_finished_house() -> String:
	var best := ""
	var best_area := 0.0
	for house: Dictionary in Jobs.unlocked():
		var house_id := str(house["id"])
		if not Game.is_job_done(house_id):
			continue
		# floor_area() covers both shapes; a floor plan has no single w and d.
		var area: float = Jobs.floor_area(house_id)
		if area > best_area:
			best_area = area
			best = house_id
	return best


## Which way round the triangles face. Godot winds a front face clockwise seen
## from outside, and a piece wound the other way is drawn inside out: the
## renderer culls the surface you are looking at and you see the back of the far
## wall instead, so a solid chest of drawers comes out looking like an open
## crate. It is invisible on anything with no cavity in it, which is why it went
## unnoticed across a whole release — so it is measured here rather than looked
## at.
func _check_winding() -> void:
	var inside_out := 0
	var worst := ""
	for id in Catalog.ids():
		var built: Dictionary = MeshBuilder.build(id, Catalog.get_item(id)["parts"])
		var wrong := _facing_the_wrong_way(built["mesh"] as ArrayMesh)
		if wrong > 0:
			inside_out += 1
			worst = id
	_expect(inside_out == 0,
		"%d pieces are wound inside out, %s among them" % [inside_out, worst])

	# And the rule itself is checked against Godot's own meshes, so this cannot
	# quietly agree with a mistake.
	var reference := BoxMesh.new()
	reference.size = Vector3.ONE
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, reference.surface_get_arrays(0))
	_expect(_facing_the_wrong_way(mesh) == 0,
		"the winding rule disagrees with Godot's own BoxMesh, so it is the rule that is wrong")
	print("winding         %d pieces, every triangle facing out" % Catalog.ids().size())


## Triangles whose winding disagrees with the normal they carry.
func _facing_the_wrong_way(mesh: ArrayMesh) -> int:
	var wrong := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if index.is_empty():
			for i in verts.size():
				index.append(i)
		for t in index.size() / 3:
			var ia := index[t * 3]
			var ib := index[t * 3 + 1]
			var ic := index[t * 3 + 2]
			var face := (verts[ib] - verts[ia]).cross(verts[ic] - verts[ia])
			if face.length_squared() < 1e-12:
				continue
			var carried: Vector3 = norms[ia] + norms[ib] + norms[ic]
			if carried.length_squared() < 1e-12:
				continue
			if face.normalized().dot(carried.normalized()) > 0.2:
				wrong += 1
	return wrong


# ---------------------------------------------------------------- catalogue

## Every piece has to be buyable somewhere, priced, and physically sane.
func _check_catalogue() -> void:
	var total := 0
	for category in Catalog.CATEGORIES:
		var ids := Catalog.ids_in(category)
		total += ids.size()
		_expect(not ids.is_empty(), "category %s has nothing in it" % category)
		var has_shop := false
		for shop: Dictionary in Catalog.SHOPS:
			if shop["category"] == category:
				has_shop = true
		_expect(has_shop, "category %s is not sold anywhere" % category)

	# Release builds strip the assert in Catalog._add(), so the rule it guards
	# is checked here as well: an id used twice means the second piece silently
	# replaced the first.
	var seen: Dictionary = {}
	for id in Catalog.ids():
		_expect(not seen.has(id), "'%s' is in the catalogue twice" % id)
		seen[id] = true

	for id in Catalog.ids():
		_expect(Catalog.price(id) > 0, "%s costs nothing" % id)
		_expect(Catalog.shop_of(id) != "", "%s is not stocked by any shop" % id)
		var footprint := Catalog.footprint(id)
		_expect(footprint.x > 0.02 and footprint.y > 0.02, "%s has no footprint" % id)
		_expect(Catalog.height(id) > 0.01, "%s has no height" % id)
		if Catalog.surface_height(id) > 0.0:
			_expect(Catalog.surface_height(id) < Catalog.height(id) + 0.05,
				"%s has a surface above its own top" % id)
		# Every piece has to want a good that some works actually makes, or it
		# could never come off the bench.
		var grain := Industry.grain_of(id)
		_expect(not Industry.get_good(grain).is_empty(),
			"%s wants '%s', which is not a good" % [id, grain])
		_expect(not Industry.works_for(grain).is_empty(),
			"%s wants %s, which nothing makes" % [id, grain])
	# Shops belong to a quarter, and their stock is that quarter's alone.
	var exclusive := 0
	for shop: Dictionary in Catalog.SHOPS:
		var shop_id := str(shop["id"])
		var district := str(shop.get("district", ""))
		_expect(not Jobs.get_district(district).is_empty(),
			"%s stands in '%s', which is not a quarter" % [shop_id, district])
		_expect(not Catalog.shop_stock(shop_id).is_empty() or str(shop["category"]) == "",
			"%s has nothing on its shelves" % shop_id)
		if district != str(Jobs.DISTRICTS[0]["id"]):
			exclusive += Catalog.shop_stock(shop_id).size()
	_expect(exclusive > 0, "no quarter but the first has any trade of its own")

	# A brief can only ask for what its own quarter, or the first one, sells —
	# quarters are not bought in a fixed order, so anything else could be
	# impossible to buy by the time the job is open.
	var home := str(Jobs.DISTRICTS[0]["id"])
	for house: Dictionary in Jobs.all():
		var house_id := str(house["id"])
		var quarter := Jobs.district_of(house_id)
		for req: Dictionary in house["requirements"]:
			if str(req.get("type", "")) != "item":
				continue
			var sold_in := Catalog.district_of(str(req["id"]))
			_expect(sold_in == home or sold_in == quarter,
				"%s (%s) needs %s, which is only sold in %s"
					% [house_id, quarter, req["id"], sold_in])

	# A brief can only ask for what the player's level can buy by the time the
	# house opens. Houses and stock are gated on the same ladder, and this is
	# what keeps the two in step — get it wrong and the job is unfinishable
	# rather than merely hard.
	for house: Dictionary in Jobs.all():
		var house_id := str(house["id"])
		var gate := int(house["level"])
		for req: Dictionary in house["requirements"]:
			var needed := _requirement_level(req)
			_expect(needed <= gate,
				"%s opens at level %d but its %s needs level %d"
					% [house_id, gate, req.get("type", "?"), needed])
		_expect(gate >= int(Jobs.get_district(Jobs.district_of(house_id))["level"]),
			"%s opens before the quarter it stands in" % house_id)

	# And the client's budget has to cover what they are asking for, or the
	# fifth star is unreachable however well the room is laid out.
	for house: Dictionary in Jobs.all():
		var house_id := str(house["id"])
		var outlay := Jobs.minimum_outlay(house_id)
		_expect(outlay <= int(house["budget"]),
			"%s asks for %s of furniture on a %s budget"
				% [house_id, UIKit.money(outlay), UIKit.money(int(house["budget"]))])

	print("catalogue       %d pieces across %d categories and %d shops, %d of them exclusive"
		% [total, Catalog.CATEGORIES.size(), Catalog.SHOPS.size(), exclusive])


## The level a player has to reach before one line of a brief can be satisfied:
## the piece it names, or the cheapest way of meeting it where it names a
## category or a choice of colours.
static func _requirement_level(req: Dictionary) -> int:
	match str(req.get("type", "")):
		"item":
			return Catalog.effective_unlock_level(str(req["id"]))
		"category":
			var best := 99
			for id in Catalog.ids_in(str(req["category"])):
				if Catalog.is_stackable(id):
					continue
				best = mini(best, Catalog.effective_unlock_level(id))
			return 1 if best == 99 else best
		"color":
			var best := 99
			for entry: Dictionary in Catalog.PAINT[str(req.get("surface", "floor"))]:
				if str(entry["name"]) in req.get("names", []):
					best = mini(best, int(entry["level"]))
			return 1 if best == 99 else best
	return 1


# ----------------------------------------------------------------- the plans

## Houses that are a whole floor rather than one room: the shell has to build
## every room in the plan, and a brief that names a room has to mean it.
func _check_floor_plan() -> void:
	var plans := 0
	for house: Dictionary in Jobs.all():
		if not house.has("rooms"):
			continue
		plans += 1
		var house_id := str(house["id"])
		var rects: Array[Rect2] = []
		for entry: Dictionary in house["rooms"]:
			rects.append(Rect2(
				float(entry["x"]) - float(entry["w"]) * 0.5,
				float(entry["z"]) - float(entry["d"]) * 0.5,
				float(entry["w"]), float(entry["d"])))
		# Rooms may share a wall but must never sit on top of each other.
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				var shared := rects[i].intersection(rects[j])
				_expect(shared.size.x < 0.01 or shared.size.y < 0.01,
					"%s: %s overlaps %s" % [house_id,
						house["rooms"][i]["id"], house["rooms"][j]["id"]])
		# Every room a requirement names has to exist in the plan.
		var ids: Dictionary = {}
		for entry: Dictionary in house["rooms"]:
			ids[str(entry["id"])] = true
		for req: Dictionary in house["requirements"]:
			var scope := str(req.get("room", ""))
			_expect(scope == "" or ids.has(scope),
				"%s asks for something in '%s', which is not a room" % [house_id, scope])

	_expect(plans > 0, "no house in the city is more than one room")

	# The whole city asks what a room has to *do*, not what it has to contain.
	# A handful of named pieces survive where the brief genuinely turns on that
	# object — a rocking horse, a play mat — and nothing else does.
	var named := 0
	var open_asks := 0
	for house: Dictionary in Jobs.all():
		for req: Dictionary in house["requirements"]:
			if str(req.get("type", "")) == "item":
				named += 1
			elif Catalog.ask_key(req) != "":
				open_asks += 1
	_expect(open_asks > named * 2,
		"only %d lines ask what the room has to do against %d that name a product"
			% [open_asks, named])
	for house: Dictionary in Jobs.all():
		if not house.has("rooms"):
			continue
		for req: Dictionary in house["requirements"]:
			_expect(str(req.get("type", "")) != "item",
				"%s still hands out a shopping list: %s"
					% [house["id"], req.get("id", "")])

	# And every open ask has to be answerable out of what that client's own
	# quarter will actually sell, or the brief is a riddle.
	for house: Dictionary in Jobs.all():
		var plan := Jobs.room_plan(str(house["id"]))
		for scope: String in plan:
			for item_id: String in plan[scope]:
				_expect(int(house["level"]) >= Catalog.effective_unlock_level(item_id),
					"%s suggests %s, which does not open until level %d"
						% [house["id"], item_id, Catalog.effective_unlock_level(item_id)])

	# Then take the biggest one into the designer and check it stands up.
	var house_id := "the_observatory"
	var job := Jobs.get_job(house_id)
	var main := get_tree().current_scene
	for item_id: String in Jobs.shopping_list(house_id):
		Game.buy_item(item_id, int(Jobs.shopping_list(house_id)[item_id]))
	main.enter_designer(house_id)
	await _settle()
	var designer = main.designer
	designer._on_new_requested()

	var room = designer.room
	_expect(room.room_count() == job["rooms"].size(),
		"%s built %d rooms, expected %d" % [house_id, room.room_count(), job["rooms"].size()])
	_expect(absf(room.area() - Jobs.floor_area(house_id)) < 0.1,
		"%s floor is %.1f m², the brief says %.1f" % [
			house_id, room.area(), Jobs.floor_area(house_id)])

	# A piece dropped in the middle of each room is reported as being in it.
	for entry: Dictionary in room.plan:
		var rect: Rect2 = entry["rect"]
		var middle := rect.position + rect.size * 0.5
		_expect(room.room_id_at(middle) == str(entry["id"]),
			"the middle of %s reads as %s" % [entry["id"], room.room_id_at(middle)])

	# And the brief means the room it names. The line asks for somewhere to
	# sleep in the bedroom, so a bed standing in the bathroom does not answer
	# it — the same bed, two metres away, does.
	designer._on_place_item("bed_double")
	var bed = designer.selected
	var bathroom: Rect2 = room.rect_of("bathroom")
	var spot := bathroom.position + bathroom.size * 0.5
	bed.global_position = designer._clamp_to_room(bed, Vector3(spot.x, 0.0, spot.y))
	_expect(not _room_line_met(house_id, designer, "sleeps", "bedroom"),
		"a bed left in the bathroom ticked the bedroom's line")

	var bedroom: Rect2 = room.rect_of("bedroom")
	spot = bedroom.position + bedroom.size * 0.5
	bed.global_position = designer._clamp_to_room(bed, Vector3(spot.x, 0.0, spot.y))
	_expect(_room_line_met(house_id, designer, "sleeps", "bedroom"),
		"a bed in the bedroom did not tick the bedroom's line")

	# Paint is per room: a colour laid in one must not spread to the others.
	var first := str(room.plan[0]["id"])
	var second := str(room.plan[1]["id"])
	var slate: Color = Catalog.PAINT["floor"][0]["color"]
	var other: Color = Catalog.PAINT["floor"][1]["color"]
	# Both shades have to be in the paint store, or the designer refuses them.
	Game.buy_paint("floor", Catalog.PAINT["floor"][1])
	designer._on_paint_target("")
	designer._on_floor_paint(slate)
	designer._on_paint_target(first)
	designer._on_floor_paint(other)
	designer._on_paint_target("")
	_expect(room.floor_color_of(first) == other,
		"painting the %s did not take" % first)
	_expect(room.floor_color_of(second) == slate,
		"painting the %s spread into the %s" % [first, second])
	_expect(room.floor_colors.size() == room.room_count(),
		"the plan carries %d floor colours for %d rooms"
			% [room.floor_colors.size(), room.room_count()])
	# And it survives a save and reload, which is how a job is resumed.
	var saved: Dictionary = designer._serialize()
	designer._restore(saved)
	# Saved colours go through 8-bit hex, so compare them the way the brief
	# evaluator does rather than exactly.
	_expect(_same_color(room.floor_color_of(first), other),
		"the %s lost its floor colour on reload" % first)
	_expect(_same_color(room.floor_color_of(second), slate),
		"the %s lost its floor colour on reload" % second)
	designer._on_floor_paint(slate)

	print("plans           %d whole floors, %s builds %d rooms over %.0f m², painted room by room"
		% [plans, house_id, room.room_count(), room.area()])

	designer._on_new_requested()
	main.enter_city()
	await _settle()


static func _same_color(a: Color, b: Color) -> bool:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < 0.01


## Whether the brief's line for `item_id` in `scope` currently reads as met.
## Whether a line pinned to a room is ticked — by its kind, since most lines
## ask for what a room has to do rather than for a named piece.
func _room_line_met(house_id: String, designer, kind: String, scope: String) -> bool:
	var job := Jobs.get_job(house_id)
	var index := 0
	for req: Dictionary in job["requirements"]:
		if str(req.get("type", "")) == kind and str(req.get("room", "")) == scope:
			return bool(Jobs.evaluate(house_id, designer._context())[index]["met"])
		index += 1
	return false


func _line_met(house_id: String, designer, item_id: String, scope: String) -> bool:
	var job := Jobs.get_job(house_id)
	var index := 0
	for req: Dictionary in job["requirements"]:
		if str(req.get("id", "")) == item_id and str(req.get("room", "")) == scope:
			return bool(Jobs.evaluate(house_id, designer._context())[index]["met"])
		index += 1
	return false


# ------------------------------------------------------------ placement aids

func _check_placement_aids() -> void:
	var main := get_tree().current_scene
	for id in ["wardrobe", "tv_stand", "television", "bookshelf", "plant", "table_lamp"]:
		Game.buy_item(id, 1)

	main.enter_designer("maple_studio")
	await _settle()
	var designer = main.designer
	designer._on_new_requested()

	# Wall snap: a wardrobe nudged towards the back wall should end up flush
	# against it, with its back turned to the wall.
	designer._on_place_item("wardrobe")
	var wardrobe = designer.selected
	wardrobe.rotation.y = deg_to_rad(12.0)
	var half_depth: float = designer.room.depth * 0.5
	var snapped: Vector3 = designer._snap_to_walls(wardrobe, Vector3(0.0, 0.0, -half_depth + 0.5))
	# Flush means the footprint edge touches the wall, and the wardrobe's
	# footprint is not centred on its origin.
	var centre_offset: float = designer._center_offset(wardrobe, Vector3.ZERO).y
	var expected_z: float = -half_depth + Catalog.footprint("wardrobe").y * 0.5 - centre_offset
	_expect(absf(snapped.z - expected_z) < 0.02,
		"wall snap put the wardrobe at z=%.3f, expected %.3f" % [snapped.z, expected_z])
	_expect(absf(wardrobe.rotation.y) < 0.01,
		"wall snap left the wardrobe at %.1f degrees" % rad_to_deg(wardrobe.rotation.y))

	# Stacking: a television dropped over a TV stand rides on its top.
	designer._on_new_requested()
	designer._on_place_item("tv_stand")
	var stand = designer.selected
	stand.global_position = Vector3.ZERO
	designer._on_place_item("television")
	var telly = designer.selected
	var support: float = designer._support_height(telly, Vector3.ZERO)
	_expect(absf(support - Catalog.surface_height("tv_stand")) < 0.01,
		"stacking put the television at %.3f, expected %.3f"
			% [support, Catalog.surface_height("tv_stand")])
	_expect(designer._support_height(stand, Vector3.ZERO) == 0.0,
		"a TV stand should not stack onto anything")

	# Headroom: the shelf tops are high enough that a big prop on one would
	# poke out through the wall, so it has to stay on the floor.
	designer._on_new_requested()
	designer._on_place_item("bookshelf")
	designer.selected.global_position = Vector3.ZERO
	designer._on_place_item("plant")
	var tall = designer.selected
	designer._on_place_item("table_lamp")
	var small = designer.selected
	var shelf_top := Catalog.surface_height("bookshelf")
	_expect(shelf_top > 0.0, "the bookshelf has no surface to put anything on")
	_expect(designer._support_height(small, Vector3.ZERO) == shelf_top,
		"a table lamp should sit on the bookshelf")
	_expect(shelf_top + Catalog.height("plant") > designer.room.height,
		"this check needs a prop too tall for the shelf to hold")
	_expect(designer._support_height(tall, Vector3.ZERO) == 0.0,
		"a plant too tall for the room stacked onto the bookshelf anyway")

	print("placement       wall snap flush at z=%.2f, stack height %.2f, shelf top %.2f"
		% [snapped.z, support, shelf_top])
	designer._on_new_requested()
	main.enter_city()
	await _settle()


# ----------------------------------------------------------------- undo/redo

func _check_history() -> void:
	var main := get_tree().current_scene
	Game.buy_item("plant", 2)
	main.enter_designer("maple_studio")
	await _settle()
	var designer = main.designer
	designer._on_new_requested()

	var stock_before: int = Game.stock_of("plant")
	var count_before: int = designer._items().size()

	designer._on_place_item("plant")
	var after_place: int = designer._items().size()
	_expect(after_place == count_before + 1, "placing did not add a piece")
	_expect(Game.stock_of("plant") == stock_before - 1, "placing did not take from stock")

	designer._on_undo()
	_expect(designer._items().size() == count_before, "undo did not remove the piece")
	_expect(Game.stock_of("plant") == stock_before, "undo did not return it to stock")

	designer._on_redo()
	_expect(designer._items().size() == after_place, "redo did not put the piece back")
	_expect(Game.stock_of("plant") == stock_before - 1, "redo did not take from stock again")

	print("history         place, undo and redo keep room and stock in step")
	designer._on_new_requested()
	main.enter_city()
	await _settle()


# -------------------------------------------------------------------- review

## The top of the scale has to be reachable by arranging a room properly, or
## the third star is just decoration.
func _check_three_stars() -> void:
	var main := get_tree().current_scene
	Game.buy_item("bed_single", 1)
	Game.buy_item("nightstand", 1)
	Game.buy_item("plant", 2)

	main.enter_designer("maple_studio")
	await _settle()
	var designer = main.designer
	designer._on_new_requested()

	var half_d: float = designer.room.depth * 0.5
	for id in ["bed_single", "nightstand", "plant", "plant"]:
		designer._on_place_item(id)
	for item in designer._items():
		if not Catalog.get_item(item.item_id).get("against_wall", false):
			continue
		var target := Vector3(item.global_position.x, 0.0, -half_d + 0.1)
		item.global_position = designer._clamp_to_room(item, designer._snap_to_walls(item, target))
	for item in designer._items():
		item.set_tint(Color(0.62, 0.58, 0.50))
	designer._update_overlaps()

	var review := RoomReview.score(
		designer._review_entries(), designer.room.area(), designer.installed_value(), 950)
	_expect(int(review["stars"]) == 3,
		"a tidy, wall-hugging room scored %d stars, not 3 (%s)"
			% [review["stars"], _failed_notes(review)])

	# The same verdict is on the bar while the room is being worked on, not only
	# once it has been handed over and can no longer be changed. It has to be
	# the same verdict — one that flatters you while you work and marks you down
	# at the door would be worse than none.
	var live: Dictionary = designer.verdict()
	_expect(int(live["stars"]) == int(review["stars"]),
		"the room reads as %d stars while you work and %d at the door"
			% [live["stars"], review["stars"]])
	_expect((live.get("notes", []) as Array).size() == (review["notes"] as Array).size(),
		"the live verdict and the hand-over notice different things")

	# And it moves with the room. Pushing everything into one corner breaks the
	# line about the big pieces standing against the walls.
	var before := int(designer.verdict()["stars"])
	for item in designer._items():
		item.global_position = Vector3(0.0, item.global_position.y, 0.0)
	designer._update_overlaps()
	_expect(int(designer.verdict()["stars"]) < before,
		"heaping the whole room in the middle did not move the verdict")

	print("review          a properly arranged room scores %s, and says so while you work"
		% RoomReview.stars_text(int(review["stars"])))
	_check_style()

	designer._on_new_requested()
	main.enter_city()
	await _settle()


## The one line of the review that is about taste rather than tidiness: a room
## can be faultless in every other way and still be six schools of furniture
## shouting at each other.
func _check_style() -> void:
	# Every piece has to belong to a school somebody has heard of, or the
	# review would be judging a room against a style that does not exist.
	for id in Catalog.ids():
		_expect(Catalog.STYLES.has(Catalog.style_of(id)),
			"%s is of no known style" % id)
	var schools: Dictionary = {}
	for id in Catalog.ids():
		schools[Catalog.style_of(id)] = int(schools.get(Catalog.style_of(id), 0)) + 1
	for style: String in Catalog.STYLES:
		_expect(schools.has(style), "nothing in the city is %s" % style)

	# A room of plain stock has no opinion, so it cannot fail the line.
	var plain := RoomReview.score([
		{"id": "sofa", "tint": Color.WHITE, "blocked": false, "wall_gap": 0.0, "area": 1.0},
		{"id": "coffee_table", "tint": Color.WHITE, "blocked": false, "wall_gap": 0.0, "area": 1.0},
	], 20.0, 100, 1000)
	_expect(str(plain["voice"]) == Catalog.PLAIN, "a room of plain stock claimed a style")
	_expect(bool((plain["notes"] as Array)[4]["good"]),
		"a room of plain stock was told off for having no point of view")

	# One school, with plain stock alongside it, still hangs together.
	var one := RoomReview.score([
		{"id": "tatami_mat", "tint": Color.WHITE, "blocked": false, "wall_gap": 0.0, "area": 1.0},
		{"id": "sofa", "tint": Color.WHITE, "blocked": false, "wall_gap": 0.0, "area": 1.0},
	], 20.0, 100, 1000)
	_expect(bool((one["notes"] as Array)[4]["good"]),
		"one school plus plain stock was called a jumble")

	# Two schools in equal measure is exactly what the line is there to catch.
	var mixed := RoomReview.score([
		{"id": "tatami_mat", "tint": Color.WHITE, "blocked": false, "wall_gap": 0.0, "area": 1.0},
		{"id": "coffin_bed", "tint": Color.WHITE, "blocked": false, "wall_gap": 0.0, "area": 1.0},
	], 20.0, 100, 1000)
	_expect(not bool((mixed["notes"] as Array)[4]["good"]),
		"japandi and gothic in one room passed as a point of view")

	# And a client wants the look of the street they live on.
	for house: Dictionary in Jobs.all():
		var house_id := str(house["id"])
		_expect(Catalog.STYLES.has(Jobs.taste_of(house_id)),
			"%s likes a style that does not exist" % house_id)
	_expect(Jobs.taste_of("sakura_tearoom") == "japandi",
		"a client in Hanami Ward does not want a Hanami room")
	print("style           %d schools across the city; a mixed room is marked down"
		% Catalog.STYLES.size())


func _failed_notes(review: Dictionary) -> String:
	var failed: Array[String] = []
	for note: Dictionary in review["notes"]:
		if not note["good"]:
			failed.append(str(note["label"]))
	return "; ".join(failed)


# ------------------------------------------------------------------- the tray

## The catalogue strip is dragged with a finger rather than a scrollbar, so a
## press that wanders has to slide the row and place nothing, and a press that
## stays put has to place the piece under it.
func _check_tray() -> void:
	var main := get_tree().current_scene
	Game.buy_item("sofa", 3)
	main.enter_designer("maple_studio")
	await _settle()
	var designer = main.designer
	designer._on_new_requested()
	var ui = designer.ui

	_expect(not ui.is_catalog_open(), "the catalogue should start closed")
	ui.set_catalog_open(true)
	_expect(ui.is_catalog_open(), "the Furniture bar did not open the catalogue")
	for i in 4:
		await get_tree().process_frame

	var strip: ScrollContainer = ui._item_scroll
	_expect(not strip.get_h_scroll_bar().visible,
		"the tray still shows a scrollbar")

	var placed: int = designer._items().size()
	var scrolled: int = strip.scroll_horizontal
	_tap(ui, strip, "sofa", [2.0, -3.0])
	_expect(designer._items().size() == placed + 1,
		"a tap on the tray did not place anything")
	_expect(strip.scroll_horizontal == scrolled,
		"a tap on the tray slid the row by %d px" % (strip.scroll_horizontal - scrolled))

	placed = designer._items().size()
	_tap(ui, strip, "sofa", [-40.0, -40.0, -40.0, -40.0, -40.0, -40.0])
	_expect(designer._items().size() == placed,
		"dragging across the tray placed a piece")
	_expect(strip.scroll_horizontal > scrolled,
		"dragging across the tray did not slide it")

	print("tray            closed by default, drags to %d px and taps still place"
		% strip.scroll_horizontal)
	designer._on_new_requested()
	main.enter_city()
	await _settle()


## One press, a run of moves, and a release, straight at the strip handler.
func _tap(ui, strip: ScrollContainer, item_id: String, moves: Array) -> void:
	var on_tap := func() -> void: ui.place_item.emit(item_id)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	ui._on_strip_input(down, strip, on_tap)
	for dx: float in moves:
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(dx, 0.0)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		ui._on_strip_input(motion, strip, on_tap)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	ui._on_strip_input(up, strip, on_tap)


# ------------------------------------------------------------ repeat contract

## After the ten handcrafted jobs the map has to keep offering work.
func _check_repeat_contract() -> void:
	var main := get_tree().current_scene
	var house_id := "maple_studio"
	_expect(Game.is_job_done(house_id), "the career run should have finished %s" % house_id)

	var before := Game.repeat_count(house_id)
	var contract := Jobs.generate_contract(house_id, Game.level)
	_expect(not contract.is_empty(), "no repeat contract was generated")
	Game.take_repeat_contract(house_id, contract)

	var job := Jobs.get_job(house_id)
	_expect(not Game.is_job_done(house_id), "the house should be open for work again")
	_expect(job["client"] == contract["client"], "the generated client did not stick")
	_expect(job.has("map") and job.has("style"), "the generated job lost the house itself")
	_expect(int(job["payout"]) > int(job["budget"]), "a repeat contract has to be worth doing")

	var basket := Jobs.shopping_list(house_id)
	for item_id: String in basket:
		if not Game.is_item_unlocked(item_id):
			_failures.append("repeat contract asks for locked item %s" % item_id)
			return
		Game.buy_item(item_id, int(basket[item_id]))

	main.enter_designer(house_id)
	await _settle()
	var designer = main.designer
	_furnish(designer, job)

	var results := Jobs.evaluate(house_id, designer._context())
	if not Jobs.all_met(results):
		_failures.append("repeat contract unmet: %s" % _unmet(results))
	else:
		designer._on_finish()
		_expect(Game.repeat_count(house_id) == before + 1, "finishing the repeat did not count")
		_expect(not Jobs.has_repeat_contract(house_id),
			"the generated brief should clear once handed over")
		print("repeat          %s wants a %s, %s fee — shopped for, built and handed over" % [
			contract["client"], contract["theme"], UIKit.money(int(contract["payout"]))])
	main.enter_city()
	await _settle()


# ------------------------------------------------------------------- career

func _play(job: Dictionary) -> void:
	var house_id: String = job["id"]
	var main := get_tree().current_scene

	if Game.level < int(job["level"]):
		_failures.append("%s needs level %d, player only reached %d"
			% [house_id, job["level"], Game.level])
		return

	var money_before := Game.money
	var basket := Jobs.shopping_list(house_id)
	for item_id: String in basket:
		if not Game.buy_item(item_id, int(basket[item_id])):
			_failures.append("%s could not afford %d x %s" % [house_id, basket[item_id], item_id])
			return
	for paint: Dictionary in Jobs.missing_paints(house_id):
		if not Game.buy_paint(str(paint["surface"]), paint["entry"]):
			_failures.append("%s could not buy %s paint" % [house_id, paint["entry"]["name"]])
			return

	main.enter_designer(house_id)
	await _settle()
	var designer = main.designer
	_furnish(designer, job)

	var results := Jobs.evaluate(house_id, designer._context())
	if not Jobs.all_met(results):
		_failures.append("%s unmet: %s" % [house_id, _unmet(results)])
		main.enter_city()
		await _settle()
		return

	var installed: int = designer.installed_value()
	var review := RoomReview.score(
		designer._review_entries(), designer.room.area(), installed, int(job["budget"]))
	designer._on_finish()
	main.enter_city()
	await _settle()

	print("%-18s fitted %5d  %s  money %5d -> %5d  level %d" % [
		house_id, installed, RoomReview.stars_text(int(review["stars"])),
		money_before, Game.money, Game.level])

	if Game.money < money_before:
		_failures.append("%s left the player poorer (%d -> %d)" % [house_id, money_before, Game.money])

	# A player levels up and spends the point, so the run does too. Anything else
	# would balance the career against a feature nobody leaves switched off.
	_spend_points()
	_take_people_on()


## Puts whatever points are going spare into the four lines in turn, which is
## the least clever thing a player could do with them and so the fairest thing
## to balance the career against.
func _spend_points() -> void:
	while Game.perk_points_left() > 0:
		# Whichever line is furthest behind, so the four come up together.
		var pick := ""
		var lowest := Perks.RANKS + 1
		for line: Dictionary in Perks.lines():
			var line_id := str(line["id"])
			if not Game.can_take_perk(line_id):
				continue
			if Game.perk_rank(line_id) < lowest:
				lowest = Game.perk_rank(line_id)
				pick = line_id
		if pick == "" or not Game.take_perk(pick):
			return


## And takes everybody on as soon as they will come, so the career is played
## with 14% coming off every fee rather than with the books empty.
func _take_people_on() -> void:
	for role: Dictionary in Staff.roles():
		var role_id := str(role["id"])
		if not Game.is_hired(role_id) and Game.can_hire(role_id):
			Game.hire(role_id)


func _unmet(results: Array[Dictionary]) -> String:
	var missing: Array[String] = []
	for result: Dictionary in results:
		if not result["met"]:
			missing.append("%s (%d/%d)" % [result["label"], result["have"], result["need"]])
	return ", ".join(missing)


## Satisfies a brief as plainly as possible, out of stock. Lines pinned to a
## room of a flat are placed in that room.
func _furnish(designer, job: Dictionary) -> void:
	# The paint first: a wall is not in anybody's way, and doing it last means
	# fighting the selection.
	for req: Dictionary in job["requirements"]:
		var scope := str(req.get("room", ""))
		match str(req["type"]):
			"floor_color":
				designer._on_paint_target(scope)
				designer._on_floor_paint(_owned_paint("floor", req["names"]))
				designer._on_paint_target("")
			"wall_color":
				designer._on_paint_target(scope)
				designer._on_wall_paint(_owned_paint("wall", req["names"]))
				designer._on_paint_target("")

	# Then exactly what the brief's own planner said, in the room it said. A
	# player is free to answer differently — that is the whole point of a
	# capability line — but the run has to follow one plan rather than two, or a
	# room takes the piece another room was going to answer its own line with
	# and every brief comes up one short somewhere else.
	var plan: Dictionary = Jobs.room_plan(str(job["id"]))
	for scope: String in plan:
		for item_id: String in plan[scope]:
			for i in int((plan[scope] as Dictionary)[item_id]):
				if Game.stock_of(item_id) <= 0:
					break
				_place(designer, item_id, scope)

	# Anything still short — a piece that would not fit, or stock the run could
	# not afford — is answered out of whatever is left in the warehouse.
	var wants: Dictionary = {}
	for req: Dictionary in job["requirements"]:
		var key := Catalog.ask_key(req)
		if key == "":
			continue
		var scope := str(req.get("room", ""))
		if not wants.has(scope):
			wants[scope] = {}
		var room: Dictionary = wants[scope]
		room[key] = int(room.get(key, 0)) + int(req.get("count", 1))

	for scope: String in wants:
		var guard := 0
		while _still_wanting(designer, wants[scope], scope) and guard < 30:
			var left := _what_is_left(designer, wants[scope], scope)
			var pick := _owned_that_covers(left)
			if pick == "":
				break
			var before := _covered(designer, wants[scope], scope)
			_place(designer, pick, scope)
			# A piece that did not land would otherwise be tried thirty times.
			if _covered(designer, wants[scope], scope) == before:
				break
			guard += 1

	# Named lines and room-by-room piece counts, topped up the same way.
	for req: Dictionary in job["requirements"]:
		var scope := str(req.get("room", ""))
		match str(req["type"]):
			"item":
				var short: int = int(req.get("count", 1)) \
					- _held_in(designer, str(req["id"]), scope)
				for i in maxi(short, 0):
					_place(designer, str(req["id"]), scope)
			"categories":
				var used := 0
				for category in Catalog.CATEGORIES:
					if used >= int(req["count"]):
						break
					var id := _cheapest_owned_in(category)
					if id != "":
						_place(designer, id, scope)
						used += 1
	for req: Dictionary in job["requirements"]:
		if str(req["type"]) != "total":
			continue
		var scope := str(req.get("room", ""))
		var guard := 0
		while _count_in(designer, scope) < int(req["count"]) and guard < 120:
			var filler := _any_owned()
			if filler == "":
				break
			_place(designer, filler, scope)
			guard += 1


## How many of one piece are already standing in a scope.
func _held_in(designer, item_id: String, scope: String) -> int:
	var total := 0
	for item in designer._items():
		if scope != "" and designer.room.room_id_at(item.footprint_center()) != scope:
			continue
		if item.item_id == item_id:
			total += 1
	return total


func _count_in(designer, scope: String) -> int:
	if scope == "":
		return designer._items().size()
	var total := 0
	for item in designer._items():
		if designer.room.room_id_at(item.footprint_center()) == scope:
			total += 1
	return total


## Drops a piece and, when the brief named a room, walks it to a free spot in
## that room — the designer drops at the camera focus, which the test does not
## move around.
func _place(designer, item_id: String, scope: String) -> void:
	designer._on_place_item(item_id)
	var item = designer.selected
	if item == null or scope == "" or not designer.room.has_room(scope):
		return
	var rect: Rect2 = designer.room.rect_of(scope)
	# Sweep the room on a half-metre grid and take the first spot that is clear.
	var step := 0.5
	var z: float = rect.position.y + step
	while z < rect.end.y:
		var x: float = rect.position.x + step
		while x < rect.end.x:
			item.global_position = designer._clamp_to_room(item, Vector3(x, 0.0, z))
			if designer.room.room_id_at(item.footprint_center()) == scope \
					and not designer._overlaps_any(item):
				return
			x += step
		z += step
	# Nowhere clear: leave it in the right room and let the overlap check speak.
	var middle := rect.position + rect.size * 0.5
	item.global_position = designer._clamp_to_room(item, Vector3(middle.x, 0.0, middle.y))


## How much of one open ask the room already answers, in a given scope.
func _does_in(designer, key: String, scope: String) -> int:
	var total := 0
	for item in designer._items():
		if scope != "" and designer.room.room_id_at(item.footprint_center()) != scope:
			continue
		total += Catalog.answers(item.item_id, key)
	return total


## What a room still needs, trait by trait.
func _what_is_left(designer, wanted: Dictionary, scope: String) -> Dictionary:
	var left: Dictionary = {}
	for kind: String in wanted:
		left[kind] = maxi(int(wanted[kind]) - _does_in(designer, kind, scope), 0)
	return left


func _still_wanting(designer, wanted: Dictionary, scope: String) -> bool:
	for kind: String in wanted:
		if _does_in(designer, kind, scope) < int(wanted[kind]):
			return true
	return false


## How much of what the room wants it already does, all traits together.
func _covered(designer, wanted: Dictionary, scope: String) -> int:
	var total := 0
	for kind: String in wanted:
		total += mini(_does_in(designer, kind, scope), int(wanted[kind]))
	return total


## The piece in stock that covers the most of what is left. A bookshelf is a
## surface *and* somewhere to put things away, so it answers two lines with one
## piece and leaves floor for the rest.
func _owned_that_covers(left: Dictionary) -> String:
	var best := ""
	var best_cover := 0
	var best_price := 1 << 30
	for id in Catalog.ids():
		if Game.stock_of(id) <= 0:
			continue
		var cover := 0
		for key: String in left:
			cover += mini(Catalog.answers(id, key), int(left[key]))
		if cover <= 0:
			continue
		if cover > best_cover or (cover == best_cover and Catalog.price(id) < best_price):
			best_cover = cover
			best_price = Catalog.price(id)
			best = id
	return best


func _cheapest_owned_in(category: String) -> String:
	var best := ""
	var best_price := 1 << 30
	for id in Catalog.ids_in(category):
		if Game.stock_of(id) <= 0:
			continue
		if Catalog.price(id) < best_price:
			best_price = Catalog.price(id)
			best = id
	return best


func _any_owned() -> String:
	var owned := Game.owned_item_ids()
	return owned[0] if not owned.is_empty() else ""


func _owned_paint(surface: String, names: Array) -> Color:
	for entry: Dictionary in Catalog.PAINT[surface]:
		if names.has(entry["name"]) and Game.owns_paint(surface, str(entry["name"])):
			return entry["color"]
	return Color.WHITE
