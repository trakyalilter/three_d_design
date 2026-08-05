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

	print("=== the front page ===")
	await _check_title()
	await _check_loading()
	await _check_brief_sheet()

	print("=== the map ===")
	await _check_life()

	print("=== the shops ===")
	await _check_shop()

	print("=== sound ===")
	_check_sound()

	print("=== districts ===")
	_check_districts()

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

	print("=== catalogue ===")
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


static func _collect_text(node: Node, into: Array[String]) -> void:
	if node is Label:
		into.append((node as Label).text)
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
func _check_estate() -> void:
	var main = get_tree().current_scene

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

	main.enter_estate(true)
	await _settle()
	_expect(main.estate != null, "the estate did not open")
	_expect(main.city == null, "the map was left running under the estate")
	if main.estate == null:
		return
	_expect(main.estate.get_node("Plots").get_child_count() == Industry.sites().size(),
		"the fields put out %d holdings for %d in the table"
			% [main.estate.get_node("Plots").get_child_count(), Industry.sites().size()])

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

	main.enter_city()
	await _settle()

	# A job handed over is what pays the yard. Nothing else in the game moves it.
	var material := str(site["yields"])
	var in_yard := Game.material_count(material)
	var worked := await _take_repeat()
	_expect(worked, "the estate check needs one repeat job to hand over")
	if not worked:
		return
	var expected: int = int(site["per_job"]) * 2
	_expect(Game.material_count(material) == in_yard + expected,
		"handing a job over brought in %d %s, not the %d two tiers of %s should yield"
			% [Game.material_count(material) - in_yard, material, expected, site_id])

	# The works: material in, goods out.
	main.enter_estate(false)
	await _settle()
	_expect(main.estate != null and not main.estate.is_fields(), "the works did not open")
	if main.estate == null:
		return
	_expect(main.estate.get_node("Plots").get_child_count() == Industry.works().size() + 1,
		"the works ground is missing a plant or the bench")

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
	_expect(Game.good_count(str(good["id"])) == made + 1,
		"a batch at %s made nothing" % works_id)
	_expect(Game.material_count(feed) == stock - int(good["takes"]),
		"a batch at %s did not eat its material" % works_id)

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

	main.enter_city()
	await _settle()

	print("estate          %s worked to tier 2, %s built, sofa off the bench %s"
		% [site_id, works_id, Industry.tier_name(Game.quality_of("sofa"))])
	await _check_craft_pays()


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

	var plain := payout + int(round(float(payout) * float(review["bonus_rate"])))
	var withcraft := payout + int(round(float(payout) * (float(review["bonus_rate"]) + craft)))
	_expect(Game.money - money == withcraft,
		"%s paid %d, not the %d a room of improved furniture is worth"
			% [house_id, Game.money - money, withcraft])
	_expect(withcraft > plain, "the craft bonus added nothing to the fee")
	# The same bonus rides the experience. The career ends pinned at the cap, so
	# the reward itself is what has to be checked rather than the bar.
	var taught := float(job["xp"]) * (0.8 + 0.2 * float(review["stars"]))
	_expect(int(round(taught * (1.0 + craft))) > int(round(taught)),
		"the craft bonus added nothing to what the job teaches")
	print("craft           %s paid %s over the plain fee at %.0f%% craft"
		% [house_id, UIKit.money(withcraft - plain), craft * 100.0])


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

	# And the brief means the room it names: a bed in the bathroom is not a bed
	# in the bedroom.
	designer._on_place_item("bed_double")
	var bed = designer.selected
	var bathroom: Rect2 = room.rect_of("bathroom")
	var spot := bathroom.position + bathroom.size * 0.5
	bed.global_position = designer._clamp_to_room(bed, Vector3(spot.x, 0.0, spot.y))
	_expect(not _line_met(house_id, designer, "bed_double", "bedroom"),
		"a bed left in the bathroom ticked the bedroom's line")

	var bedroom: Rect2 = room.rect_of("bedroom")
	spot = bedroom.position + bedroom.size * 0.5
	bed.global_position = designer._clamp_to_room(bed, Vector3(spot.x, 0.0, spot.y))
	_expect(_line_met(house_id, designer, "bed_double", "bedroom"),
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
	print("review          a properly arranged room scores %s"
		% RoomReview.stars_text(int(review["stars"])))

	designer._on_new_requested()
	main.enter_city()
	await _settle()


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


func _unmet(results: Array[Dictionary]) -> String:
	var missing: Array[String] = []
	for result: Dictionary in results:
		if not result["met"]:
			missing.append("%s (%d/%d)" % [result["label"], result["have"], result["need"]])
	return ", ".join(missing)


## Satisfies a brief as plainly as possible, out of stock. Lines pinned to a
## room of a flat are placed in that room.
func _furnish(designer, job: Dictionary) -> void:
	for req: Dictionary in job["requirements"]:
		var scope := str(req.get("room", ""))
		match str(req["type"]):
			"item":
				for i in int(req.get("count", 1)):
					_place(designer, str(req["id"]), scope)
			"category":
				for i in int(req.get("count", 1)):
					var pick := _cheapest_owned_in(str(req["category"]))
					if pick != "":
						_place(designer, pick, scope)
			"categories":
				var used := 0
				for category in Catalog.CATEGORIES:
					if used >= int(req["count"]):
						break
					var id := _cheapest_owned_in(category)
					if id != "":
						_place(designer, id, scope)
						used += 1
			"floor_color":
				designer._on_paint_target(scope)
				designer._on_floor_paint(_owned_paint("floor", req["names"]))
				designer._on_paint_target("")
			"wall_color":
				designer._on_paint_target(scope)
				designer._on_wall_paint(_owned_paint("wall", req["names"]))
				designer._on_paint_target("")

	# Room-by-room piece counts have to be topped up room by room.
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
