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

	print("=== career ===")
	for job: Dictionary in Jobs.all():
		await _play(job)
	print("--- career done: money %d, level %d, jobs %d/%d" % [
		Game.money, Game.level, Game.jobs_done(), Jobs.all().size()])

	print("=== catalogue ===")
	_check_catalogue()

	print("=== designer ===")
	await _check_placement_aids()
	await _check_history()
	await _check_three_stars()
	await _check_repeat_contract()

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
	print("catalogue       %d pieces across %d categories, all stocked and priced"
		% [total, Catalog.CATEGORIES.size()])


# ------------------------------------------------------------ placement aids

func _check_placement_aids() -> void:
	var main := get_tree().current_scene
	for id in ["wardrobe", "tv_stand", "television", "bookshelf", "plant", "table_lamp"]:
		Game.buy_item(id, 1)

	main.enter_designer("maple_studio")
	await get_tree().process_frame
	await get_tree().process_frame
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
	await get_tree().process_frame


# ----------------------------------------------------------------- undo/redo

func _check_history() -> void:
	var main := get_tree().current_scene
	Game.buy_item("plant", 2)
	main.enter_designer("maple_studio")
	await get_tree().process_frame
	await get_tree().process_frame
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
	await get_tree().process_frame


# -------------------------------------------------------------------- review

## The top of the scale has to be reachable by arranging a room properly, or
## the third star is just decoration.
func _check_three_stars() -> void:
	var main := get_tree().current_scene
	Game.buy_item("bed_single", 1)
	Game.buy_item("nightstand", 1)
	Game.buy_item("plant", 2)

	main.enter_designer("maple_studio")
	await get_tree().process_frame
	await get_tree().process_frame
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
	await get_tree().process_frame


func _failed_notes(review: Dictionary) -> String:
	var failed: Array[String] = []
	for note: Dictionary in review["notes"]:
		if not note["good"]:
			failed.append(str(note["label"]))
	return "; ".join(failed)


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
	await get_tree().process_frame
	await get_tree().process_frame
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
	await get_tree().process_frame


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
	await get_tree().process_frame
	await get_tree().process_frame
	var designer = main.designer
	_furnish(designer, job)

	var results := Jobs.evaluate(house_id, designer._context())
	if not Jobs.all_met(results):
		_failures.append("%s unmet: %s" % [house_id, _unmet(results)])
		main.enter_city()
		await get_tree().process_frame
		return

	var installed: int = designer.installed_value()
	var review := RoomReview.score(
		designer._review_entries(), designer.room.area(), installed, int(job["budget"]))
	designer._on_finish()
	main.enter_city()
	await get_tree().process_frame

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


## Satisfies a brief as plainly as possible, out of stock.
func _furnish(designer, job: Dictionary) -> void:
	for req: Dictionary in job["requirements"]:
		match str(req["type"]):
			"item":
				for i in int(req.get("count", 1)):
					designer._on_place_item(str(req["id"]))
			"category":
				for i in int(req.get("count", 1)):
					var pick := _cheapest_owned_in(str(req["category"]))
					if pick != "":
						designer._on_place_item(pick)
			"categories":
				var used := 0
				for category in Catalog.CATEGORIES:
					if used >= int(req["count"]):
						break
					var id := _cheapest_owned_in(category)
					if id != "":
						designer._on_place_item(id)
						used += 1
			"floor_color":
				designer._on_floor_paint(_owned_paint("floor", req["names"]))
			"wall_color":
				designer._on_wall_paint(_owned_paint("wall", req["names"]))

	for req: Dictionary in job["requirements"]:
		if str(req["type"]) != "total":
			continue
		var guard := 0
		while designer._items().size() < int(req["count"]) and guard < 80:
			var filler := _any_owned()
			if filler == "":
				break
			designer._on_place_item(filler)
			guard += 1


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
