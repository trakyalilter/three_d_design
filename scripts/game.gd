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

var _loading: LoadingScreen
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
	city.shop_picked.connect(city_ui.show_shop)
	city.district_picked.connect(city_ui.show_district)
	city.nothing_picked.connect(city_ui.close_sheet)

	city_ui.start_job.connect(enter_designer)
	city_ui.free_build.connect(func() -> void: enter_designer(""))
	# A career reset can hand back quarters as well as money, so redraw the map.
	city_ui.career_reset.connect(func() -> void: city.rebuild())
	city_ui.repeat_taken.connect(func(_house_id: String) -> void: city.refresh_markers())
	city_ui.district_bought.connect(func(district_id: String) -> void:
		city.rebuild()
		city.focus_district(district_id))
	city_ui.district_focused.connect(func(district_id: String) -> void:
		city.focus_district(district_id))

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
	for node in [designer, city, city_ui, title]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	designer = null
	city = null
	city_ui = null
	title = null


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
			# The designer handles its own back button; from the city, back
			# closes whatever is open and then returns to the front page.
			if designer != null:
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
