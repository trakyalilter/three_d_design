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

	print("=== districts ===")
	_check_districts()

	print("=== career ===")
	for district: Dictionary in Jobs.districts():
		if not await _acquire(district):
			break
		# Cheapest brief first, the way anyone short of money would work a new
		# quarter. The float held back when buying it only guarantees the
		# cheapest one is affordable.
		var houses := Jobs.houses_in(str(district["id"]))
		houses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return Jobs.minimum_outlay(str(a["id"])) < Jobs.minimum_outlay(str(b["id"])))
		for job: Dictionary in houses:
			await _play(job)
	print("--- career done: money %d, level %d, jobs %d, houses %d/%d" % [
		Game.money, Game.level, Game.jobs_done(),
		Jobs.unlocked().size(), Jobs.all().size()])
	_expect(Jobs.unlocked().size() == Jobs.all().size(),
		"the career run did not manage to buy the whole city")

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
	print("brief           lists the shopping and leaves the buying to the shops: %s"
		% ", ".join(actions))


static func _collect_text(node: Node, into: Array[String]) -> void:
	if node is Label:
		into.append((node as Label).text)
	for child in node.get_children():
		_collect_text(child, into)


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
		var house_id := _biggest_finished_house()
		if house_id == "":
			break
		var contract := Jobs.generate_contract(house_id, Game.level)
		if contract.is_empty():
			break
		var before := Game.money
		Game.take_repeat_contract(house_id, contract)
		await _play(Jobs.get_job(house_id))
		contracts += 1
		if Game.money <= before:
			_failures.append("repeat work at %s did not pay: %s -> %s"
				% [house_id, UIKit.money(before), UIKit.money(Game.money)])
			break

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


## The finished house with the most floor, which is where a repeat contract pays
## best — the generator scales the brief to the size of the room.
func _biggest_finished_house() -> String:
	var best := ""
	var best_area := 0.0
	for house: Dictionary in Jobs.unlocked():
		var house_id := str(house["id"])
		if not Game.is_job_done(house_id):
			continue
		var room: Dictionary = house["room"]
		var area: float = float(room["w"]) * float(room["d"])
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

	for id in Catalog.ids():
		_expect(Catalog.price(id) > 0, "%s costs nothing" % id)
		_expect(Catalog.shop_of(id) != "", "%s is not stocked by any shop" % id)
		var footprint := Catalog.footprint(id)
		_expect(footprint.x > 0.02 and footprint.y > 0.02, "%s has no footprint" % id)
		_expect(Catalog.height(id) > 0.01, "%s has no height" % id)
		if Catalog.surface_height(id) > 0.0:
			_expect(Catalog.surface_height(id) < Catalog.height(id) + 0.05,
				"%s has a surface above its own top" % id)
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
