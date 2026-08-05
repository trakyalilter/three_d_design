extends Node
## Room Designer 3D — entry point.
##
## Owns the screens the game moves between: the front page, the city map where
## jobs are picked up, and the designer where they are carried out. Only one
## exists at a time, since each brings its own lighting and environment.
##
## Because each screen is built from scratch, moving between them is not free —
## the map welds a few thousand pieces of scenery into batched meshes, and a
## five-room job stands every piece of furniture back up. A LoadingScreen goes
## over the top first, and the build then runs one stage per frame underneath
## it, so the wait has a progress bar on it instead of a frozen picture.

## Stages are cheap to describe and expensive to run, so the bar would sit at
## 100% while the last one finished. These frames are spent after the build,
## letting the new screen draw — and its shaders compile — behind the overlay.
const SETTLE_FRAMES := 3

var title: TitleScreen
var city: CityView
var city_ui: CityUI
var designer: RoomDesigner
var shop: ShopFloor
var shop_ui: ShopUI
var estate: EstateView
var estate_ui: EstateUI

var _loading: LoadingScreen
## The house the player was last looking at, so leaving a shop puts the map
## back where they left it rather than at the centre.
var _last_house := ""
## True while a screen change is in flight. Every entry point below is a
## coroutine, so without this a second tap could start a build on top of one.
var _changing := false


func _ready() -> void:
	# Asks for the bed straight away. Nothing is synthesised on the main thread,
	# so this only marks it as wanted — it starts playing a second or two later,
	# once the sound bank and then the music itself have been built.
	Audio.start_music()
	enter_title()


## True from the moment a screen change is asked for until the loading screen
## has lifted off the screen it built.
func is_changing() -> bool:
	return _changing


## The front page. Everything starts here rather than dropping the player
## straight onto the map. Cheap enough to build outright.
func enter_title() -> void:
	if _changing:
		return
	_clear()

	title = TitleScreen.new()
	title.name = "Title"
	add_child(title)

	title.play_requested.connect(func() -> void: enter_city())
	title.free_build_requested.connect(func() -> void: enter_designer(""))
	title.new_career_requested.connect(func() -> void:
		Game.reset()
		enter_city())


func enter_city(focus_house: String = "") -> void:
	if _changing:
		return
	_changing = true

	var jobs := Game.jobs_done()
	var standing := "Level %d · %s" % [Game.level, "1 job done" if jobs == 1 else "%d jobs done" % jobs]
	var screen: LoadingScreen = await _cover(standing, "The city", "Getting the van out")

	city_ui = CityUI.new()
	city_ui.name = "CityUI"
	add_child(city_ui)

	city = CityView.new()
	city.name = "City"
	city.staged_build = true
	add_child(city)
	city.ui_probe = city_ui.is_point_over_ui

	await _run_stages(screen, city.build_stages())
	city.rig.snap_to_target()

	city.house_picked.connect(func(house_id: String) -> void:
		city_ui.show_house(house_id)
		city.focus_on(house_id))
	city.shop_picked.connect(func(shop_id: String) -> void: enter_shop(shop_id))
	city.district_picked.connect(city_ui.show_district)
	city.nothing_picked.connect(city_ui.close_sheet)

	city_ui.start_job.connect(enter_designer)
	city_ui.free_build.connect(func() -> void: enter_designer(""))
	city_ui.shop_entered.connect(func(shop_id: String) -> void: enter_shop(shop_id))
	city_ui.estate_entered.connect(func(fields: bool) -> void: enter_estate(fields))
	# A career reset can hand back quarters as well as money, so redraw the map.
	city_ui.career_reset.connect(func() -> void: city.rebuild())
	city_ui.repeat_taken.connect(func(_house_id: String) -> void: city.refresh_markers())
	city_ui.district_bought.connect(func(district_id: String) -> void:
		city.rebuild()
		city.focus_district(district_id))
	city_ui.district_focused.connect(func(district_id: String) -> void:
		city.focus_district(district_id))

	_last_house = focus_house
	if focus_house != "":
		city.focus_on(focus_house)
		city_ui.show_house(focus_house)

	await _uncover(screen)


func enter_designer(house_id: String) -> void:
	if _changing:
		return
	_changing = true

	var job: Dictionary = Jobs.get_job(house_id) if house_id != "" else {}
	var kicker := "No brief, no budget"
	var headline := "Free build"
	if not job.is_empty():
		kicker = "For %s" % job.get("client", "a client")
		headline = str(job.get("name", "The job"))
	var screen: LoadingScreen = await _cover(kicker, headline, "Driving over")

	designer = RoomDesigner.new()
	designer.name = "Designer"
	designer.staged_build = true
	designer.setup(house_id)
	add_child(designer)

	await _run_stages(screen, designer.build_stages())

	designer.job_finished.connect(func(finished_id: String) -> void: enter_city(finished_id))
	designer.left.connect(func() -> void: enter_city(house_id))

	await _uncover(screen)


## A shop, from the inside. The stock stands on the floor rather than sitting
## in a list, so this is a screen of its own like the map and the designer.
func enter_shop(shop_id: String) -> void:
	if _changing:
		return
	var counter: Dictionary = Catalog.get_shop(shop_id)
	if counter.is_empty():
		return
	_changing = true

	var quarter := Catalog.shop_district(shop_id)
	var kicker := str(Jobs.get_district(quarter)["name"]) if quarter != "" else "The parade"
	var screen: LoadingScreen = await _cover(kicker, str(counter["name"]), "Walking over")

	var from_house := _last_house
	shop_ui = ShopUI.new()
	shop_ui.name = "ShopUI"
	add_child(shop_ui)

	shop = ShopFloor.new()
	shop.name = "Shop"
	shop.staged_build = true
	shop.setup(shop_id)
	add_child(shop)
	shop.ui_probe = shop_ui.is_point_over_ui

	await _run_stages(screen, shop.build_stages())
	shop_ui.configure(counter)

	shop.picked.connect(shop_ui.show_item)
	shop.picked_paint.connect(shop_ui.show_paint)
	shop.nothing_picked.connect(shop_ui.close_card)

	shop_ui.leave_requested.connect(func() -> void: enter_city(from_house))
	shop_ui.buy_requested.connect(_buy_in_shop)
	shop_ui.sell_requested.connect(_sell_in_shop)
	shop_ui.buy_paint_requested.connect(_buy_paint_in_shop)

	await _uncover(screen)


func _buy_in_shop(item_id: String) -> void:
	if not Game.buy_item(item_id, 1):
		Audio.play("deny")
		shop_ui.toast("Not enough money")
		return
	Audio.play("buy")
	shop_ui.toast("%s — %d in stock" % [
		Catalog.display_name(item_id), Game.stock_of(item_id)], 1.6)
	# The floor is laid out again so the ticket and the greying stay honest.
	shop.restock()
	shop.reselect(item_id)


func _sell_in_shop(item_id: String) -> void:
	if Game.sell_item(item_id, 1) <= 0:
		Audio.play("deny")
		return
	Audio.play("sell")
	shop_ui.toast("Sold back — %d left" % Game.stock_of(item_id), 1.6)
	shop.restock()
	shop.reselect(item_id)


func _buy_paint_in_shop(surface: String, entry: Dictionary) -> void:
	if not Game.buy_paint(surface, entry):
		Audio.play("deny")
		shop_ui.toast("Not enough money")
		return
	Audio.play("buy")
	shop_ui.toast("%s is yours to use in any room" % entry["name"], 2.0)
	shop.restock()
	shop.reselect_paint(surface, str(entry["name"]))


## The ground and the works. Two maps of the same shape, so one screen builds
## either — the land you buy and work, and the plants that turn what it yields
## into something a piece of furniture can be improved with.
func enter_estate(fields: bool) -> void:
	if _changing:
		return
	_changing = true

	var from_house := _last_house
	var screen: LoadingScreen = await _cover(
		"Out of town", "The Estate" if fields else "The Works",
		"Driving out" if fields else "Walking the yard")

	estate_ui = EstateUI.new()
	estate_ui.name = "EstateUI"
	add_child(estate_ui)

	estate = EstateView.new()
	estate.name = "Estate"
	estate.staged_build = true
	estate.setup(EstateView.Kind.FIELDS if fields else EstateView.Kind.WORKS)
	add_child(estate)
	estate.ui_probe = estate_ui.is_point_over_ui

	await _run_stages(screen, estate.build_stages())
	estate_ui.configure(fields)

	estate.plot_picked.connect(estate_ui.show_plot)
	estate.nothing_picked.connect(estate_ui.close_sheet)

	estate_ui.leave_requested.connect(func() -> void: enter_city(from_house))
	estate_ui.buy_site.connect(_take_site)
	estate_ui.buy_works.connect(_take_works)
	estate_ui.run_works.connect(_run_works)
	estate_ui.collect_site.connect(_collect_site)
	estate_ui.collect_batch.connect(_collect_batch)
	estate_ui.improve_item.connect(_improve_item)

	await _uncover(screen)


func _take_site(site_id: String) -> void:
	if not Game.take_site(site_id):
		Audio.play("deny")
		estate_ui.toast("Not enough money")
		return
	Audio.play("quarter")
	var site: Dictionary = Industry.get_site(site_id)
	estate_ui.toast("%s is yours, and working" % site["name"], 2.4)
	estate.rebuild()
	estate.focus_on(site_id)


func _take_works(works_id: String) -> void:
	if not Game.take_works(works_id):
		Audio.play("deny")
		estate_ui.toast("Not enough money")
		return
	Audio.play("quarter")
	var works: Dictionary = Industry.get_works(works_id)
	estate_ui.toast("%s is built" % works["name"], 2.4)
	estate.rebuild()
	estate.focus_on(works_id)


func _run_works(works_id: String) -> void:
	var started := Game.run_works(works_id)
	if started <= 0:
		Audio.play("deny")
		estate_ui.toast("Nothing to put through")
		return
	Audio.play("buy")
	var works: Dictionary = Industry.get_works(works_id)
	var good: Dictionary = Industry.get_good(str(works["makes"]))
	estate_ui.toast("%d × %s on the line, ready in %s" % [
		started, good["name"], Game.spell_out(Industry.batch_seconds(works_id))], 2.4)


func _collect_site(site_id: String) -> void:
	var taken := Game.collect_site(site_id)
	if taken <= 0:
		Audio.play("deny")
		estate_ui.toast("The yard will not hold any more")
		return
	Audio.play("buy")
	var site: Dictionary = Industry.get_site(site_id)
	estate_ui.toast("%d %s carted off %s" % [
		taken, Industry.get_material(str(site["yields"]))["unit"], site["name"]], 2.0)


func _collect_batch(works_id: String) -> void:
	var taken := Game.collect_batch(works_id)
	if taken <= 0:
		Audio.play("deny")
		estate_ui.toast("The store will not hold any more")
		return
	Audio.play("buy")
	var works: Dictionary = Industry.get_works(works_id)
	var good: Dictionary = Industry.get_good(str(works["makes"]))
	estate_ui.toast("%d × %s off the line" % [taken, good["name"]], 2.0)


func _improve_item(item_id: String) -> void:
	var cost: Dictionary = Industry.upgrade_cost(item_id)
	if not Game.improve(item_id):
		Audio.play("deny")
		estate_ui.toast("Not enough to do that yet")
		return
	Audio.play("levelup")
	estate_ui.toast("%s is now %s" % [
		Catalog.display_name(item_id), str(cost["name"]).to_lower()], 2.2)


# ------------------------------------------------------------- the changeover

## Puts the loading screen up, gives it a frame to actually paint, and only
## then takes the old screen down — so there is never a blank frame between the
## two. Returns the overlay for the caller to report stages to.
func _cover(kicker: String, headline: String, first_stage: String) -> LoadingScreen:
	_loading = LoadingScreen.new()
	_loading.name = "Loading"
	add_child(_loading)
	_loading.headline(kicker, headline)
	_loading.stage(first_stage, 0.04)

	await get_tree().process_frame
	await get_tree().process_frame
	_clear()
	return _loading


## Runs a build one stage per frame, so the bar moves and the overlay is drawn
## between the expensive bits rather than only side of them.
func _run_stages(screen: LoadingScreen, stages: Array) -> void:
	var total := float(maxi(stages.size(), 1))
	for i in stages.size():
		var stage: Array = stages[i]
		screen.stage(str(stage[0]), (float(i) + 1.0) / total * 0.92)
		await get_tree().process_frame
		(stage[1] as Callable).call()


## Lets the new screen draw a few frames behind the overlay — the first one
## carries the shader compiles — then lifts it.
func _uncover(screen: LoadingScreen) -> void:
	screen.stage("Almost there", 1.0)
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	await screen.dismiss()
	if _loading == screen:
		_loading = null
	_changing = false


func _clear() -> void:
	for node in [designer, city, city_ui, title, shop, shop_ui, estate, estate_ui]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	designer = null
	city = null
	city_ui = null
	title = null
	shop = null
	shop_ui = null
	estate = null
	estate_ui = null


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			Game.save_profile()
			get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED:
			Game.save_profile()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# There is nothing to go back to while a screen is still building.
			if _changing:
				return
			# The designer handles its own back button; from a shop, back is
			# the way out to the map; from the city, back closes whatever is
			# open and then returns to the front page.
			if designer != null:
				return
			if shop != null:
				enter_city(_last_house)
				return
			if estate != null:
				if estate_ui.is_sheet_open():
					estate_ui.close_sheet()
				else:
					enter_city(_last_house)
				return
			if city_ui == null:
				Game.save_profile()
				get_tree().quit()
			elif city_ui.is_modal_open():
				city_ui.close_modal()
			elif city_ui.is_sheet_open():
				city_ui.close_sheet()
			else:
				enter_title()
