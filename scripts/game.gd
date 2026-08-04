extends Node
## Room Designer 3D — entry point.
##
## Owns the two screens the game moves between: the city map where jobs are
## picked up, and the designer where they are carried out. Only one exists at a
## time, since each brings its own lighting and environment.

var title: TitleScreen
var city: CityView
var city_ui: CityUI
var designer: RoomDesigner


func _ready() -> void:
	enter_title()


## The front page. Everything starts here rather than dropping the player
## straight onto the map.
func enter_title() -> void:
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
	_clear()

	city_ui = CityUI.new()
	city_ui.name = "CityUI"
	add_child(city_ui)

	city = CityView.new()
	city.name = "City"
	add_child(city)
	city.ui_probe = city_ui.is_point_over_ui

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


func enter_designer(house_id: String) -> void:
	_clear()

	designer = RoomDesigner.new()
	designer.name = "Designer"
	designer.setup(house_id)
	add_child(designer)

	designer.job_finished.connect(func(finished_id: String) -> void: enter_city(finished_id))
	designer.left.connect(func() -> void: enter_city(house_id))


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
			# The designer handles its own back button; from the city, back
			# closes whatever is open and then leaves the game.
			if designer != null:
				return
			if city_ui == null:
				get_tree().quit()
			elif city_ui.is_modal_open():
				city_ui.close_modal()
			elif city_ui.is_sheet_open():
				city_ui.close_sheet()
			else:
				Game.save_profile()
				get_tree().quit()
