class_name CityUI
extends CanvasLayer
## Overlay for the city map: the player's wallet and level, the briefing sheet
## for a house, and the window of whichever shop they tapped.

signal start_job(house_id: String)
signal free_build()
signal career_reset()
signal repeat_taken(house_id: String)
signal district_bought(district_id: String)
signal district_focused(district_id: String)
signal shop_entered(shop_id: String)
signal estate_entered()
signal showroom_entered()

var _root: Control
var _blockers: Array[Control] = []
var _sheet: PanelContainer
var _sheet_body: VBoxContainer
var _sheet_title: Label
var _sheet_subtitle: Label
var _sheet_actions: HBoxContainer
var _money_label: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _jobs_label: Label
var _hint: Label
var _toast: Label
var _toast_timer: Timer
var _modal: Control
var _modal_body: VBoxContainer
var _stock_button: Button
var _perks_button: Button
## Which half of the Trade sheet is open: what you got good at, or who does
## the rest.
var _trade_tab := "you"
## What the side sheet is currently showing, so it can be redrawn after a
## purchase without the player losing their place.
var _current_sheet: Dictionary = {}


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.name = "CityUIRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIKit.build_theme()
	add_child(_root)

	_build_top_bar()
	_build_hint()
	_build_sheet()
	_build_modal()

	Game.money_changed.connect(func(_amount: int) -> void: refresh_hud())
	Game.progress_changed.connect(func(_l: int, _x: int, _n: int) -> void: refresh_hud())
	Game.stock_changed.connect(_on_stock_changed)
	refresh_hud()


func _on_stock_changed() -> void:
	refresh_hud()
	_redraw_sheet()


## Re-opens whatever the sheet was showing, so counts and buttons stay honest.
func _redraw_sheet() -> void:
	if _current_sheet.is_empty() or not _sheet.visible:
		return
	var showing := _current_sheet.duplicate()
	match str(showing.get("kind", "")):
		"house":
			show_house(str(showing["id"]))
		"shop":
			show_shop(str(showing["id"]))
		"stock":
			show_warehouse()
		"perks":
			show_perks()
		"district":
			show_district(str(showing["id"]))


# ------------------------------------------------------------------- top bar

func _build_top_bar() -> void:
	var panel := PanelContainer.new()
	panel.name = "TopBar"
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 10
	panel.offset_right = -10
	panel.offset_top = 10
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(panel)
	_blockers.append(panel)

	var row := HBoxContainer.new()
	panel.add_child(row)

	_money_label = UIKit.label("", 23, UIKit.GOLD)
	_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_money_label)

	var divider := UIKit.label("  ·  ", 20, UIKit.MUTED)
	divider.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(divider)

	_level_label = UIKit.label("", 20)
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_level_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(190, 18)
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp_bar.max_value = 1.0
	_xp_bar.step = 0.001
	_xp_bar.show_percentage = false
	row.add_child(_xp_bar)

	_jobs_label = UIKit.label("", 17, UIKit.MUTED)
	_jobs_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_jobs_label)

	row.add_child(UIKit.spacer())

	_stock_button = UIKit.make_button("Stock", "Everything you own and have not fitted yet")
	_stock_button.pressed.connect(show_warehouse)
	row.add_child(_stock_button)

	_perks_button = UIKit.make_button("Trade",
		"What you have made of yourself: a point for every level, and four lines to spend it on")
	_perks_button.pressed.connect(show_perks)
	row.add_child(_perks_button)

	var quarters := UIKit.make_button("City", "The quarters of the city, and what it costs to work in them")
	quarters.pressed.connect(show_districts)
	row.add_child(quarters)

	var sandbox := UIKit.make_button("Free Build", "Design a room with no client and no stock to worry about")
	sandbox.pressed.connect(func() -> void: free_build.emit())
	row.add_child(sandbox)

	# The supply side opens once there is a reason to go out there. One button:
	# the land, the works and the bench are all on the same map.
	if Game.level >= Industry.SITES[0]["level"]:
		var land := UIKit.make_button("Estate",
			"The ground you own, the works you run, and the bench")
		land.pressed.connect(func() -> void: estate_entered.emit())
		row.add_child(land)

	var guide := UIKit.make_button("Guide")
	guide.pressed.connect(_open_guide)
	row.add_child(guide)


func refresh_hud() -> void:
	_money_label.text = UIKit.money(Game.money)
	if Game.level >= Game.MAX_LEVEL:
		_level_label.text = "Level %d (max)" % Game.level
		_xp_bar.value = 1.0
		_xp_bar.tooltip_text = "Top of the ladder"
	else:
		_level_label.text = "Level %d" % Game.level
		_xp_bar.value = Game.xp_fraction()
		_xp_bar.tooltip_text = "%d / %d XP" % [Game.xp, Game.xp_needed()]
	# Repeat contracts mean this can pass the number of houses on the map.
	var done := Game.jobs_done()
	_jobs_label.text = "   %d job%s done" % [done, "" if done == 1 else "s"]
	if _stock_button:
		var held := Game.total_stock()
		_stock_button.text = "Stock  %d" % held if held > 0 else "Stock"
	if _perks_button:
		# A point sitting unspent, or money sitting in a till nobody has emptied,
		# are the two things behind this button worth chasing — so they go on it
		# rather than waiting to be found. Points first: they expire into nothing
		# if the career ends with them unspent, and the till does not.
		var spare := Game.perk_points_left()
		Game.settle_showroom()
		var taken := Game.till()
		if spare > 0:
			_perks_button.text = "Trade  ●%d" % spare
		elif taken > 0:
			_perks_button.text = "Trade  %s" % UIKit.money(taken)
		else:
			_perks_button.text = "Trade"



func _build_hint() -> void:
	_hint = UIKit.label("Tap a house for its brief, then buy what it needs at the shops before you start.", 18, UIKit.TEXT)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.offset_left = 16
	_hint.offset_top = -46
	_hint.offset_bottom = -16
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hint.add_theme_constant_override("outline_size", 6)
	_root.add_child(_hint)

	_toast = UIKit.label("", 19, Color.WHITE)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 84
	_toast.offset_bottom = 84
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.visible = false
	_root.add_child(_toast)

	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.timeout.connect(func() -> void: _toast.visible = false)
	add_child(_toast_timer)


func toast_message(text: String, seconds: float = 2.2) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.visible = true
	_toast_timer.start(seconds)


# --------------------------------------------------------------- side sheet

func _build_sheet() -> void:
	_sheet = PanelContainer.new()
	_sheet.name = "Sheet"
	_sheet.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_sheet.offset_left = -540
	_sheet.offset_right = -12
	_sheet.offset_top = 86
	_sheet.offset_bottom = -12
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet.visible = false
	_root.add_child(_sheet)
	_blockers.append(_sheet)

	var column := VBoxContainer.new()
	_sheet.add_child(column)

	_sheet_title = UIKit.label("", 24)
	_sheet_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_sheet_title)

	_sheet_subtitle = UIKit.label("", 17, UIKit.MUTED)
	_sheet_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_sheet_subtitle)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_sheet_body = VBoxContainer.new()
	_sheet_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_sheet_body)

	_sheet_actions = HBoxContainer.new()
	_sheet_actions.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(_sheet_actions)


func close_sheet() -> void:
	if _sheet.visible:
		Audio.play("close")
	_sheet.visible = false


func is_sheet_open() -> bool:
	return _sheet.visible


func _begin_sheet(title: String, subtitle: String) -> void:
	if not _sheet.visible:
		Audio.play("open")
	_sheet.visible = true
	_sheet_title.text = title
	_sheet_subtitle.text = subtitle
	for child in _sheet_body.get_children():
		_sheet_body.remove_child(child)
		child.queue_free()
	for child in _sheet_actions.get_children():
		_sheet_actions.remove_child(child)
		child.queue_free()


func _sheet_row(left: String, right: String, right_color: Color = UIKit.TEXT) -> void:
	var row := HBoxContainer.new()
	row.add_child(UIKit.label(left, 18, UIKit.MUTED))
	row.add_child(UIKit.spacer())
	row.add_child(UIKit.label(right, 18, right_color))
	_sheet_body.add_child(row)


func _divider() -> void:
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.08)
	line.custom_minimum_size = Vector2(0, 1)
	_sheet_body.add_child(line)


# --------------------------------------------------------------- house sheet

func show_house(house_id: String) -> void:
	var job := Jobs.get_job(house_id)
	if job.is_empty():
		return
	# A house in a quarter you have not bought is somebody else's problem.
	var district_id := Jobs.district_of(house_id)
	if not Game.is_district_unlocked(district_id):
		show_district(district_id)
		return

	var done: bool = Game.is_job_done(house_id)
	var locked: bool = Game.level < int(job["level"])
	var in_progress: bool = not Game.layout_for(house_id).is_empty()

	var subtitle := "%s  ·  needs level %d" % [job["client"], job["level"]]
	if job.has("theme"):
		subtitle = "%s  ·  a new %s  ·  needs level %d" % [job["client"], job["theme"], job["level"]]
	_begin_sheet(str(job["name"]), subtitle)
	_current_sheet = {"kind": "house", "id": house_id}

	var status := "Available"
	var status_color := UIKit.ACCENT
	if done:
		status = "Handed over"
		status_color = UIKit.GOOD
	elif locked:
		status = "Locked until level %d" % job["level"]
		status_color = UIKit.BAD
	elif in_progress:
		status = "In progress"
		status_color = UIKit.GOLD
	_sheet_body.add_child(UIKit.label(status, 18, status_color))

	_sheet_body.add_child(UIKit.wrapped_label("“%s”" % job["brief"], 460, UIKit.TEXT))
	# What they like, which is worth a little on top of whatever the stars earn.
	_sheet_body.add_child(UIKit.wrapped_label(Jobs.taste_line(house_id), 460,
		Catalog.style_color(Jobs.taste_of(house_id))))
	_divider()

	_sheet_row("Room" if not job.has("rooms") else "Floor", Jobs.room_line(house_id))
	# Wrapped rather than a row: five room names on one line stretches the sheet
	# off the side of the screen.
	var names := Jobs.room_names(house_id)
	if not names.is_empty():
		_sheet_body.add_child(UIKit.wrapped_label("Rooms: %s" % ", ".join(names), 440, UIKit.MUTED))
	_sheet_row("Fee", UIKit.money(int(job["payout"])), UIKit.GOLD)
	_sheet_row("Three-star bonus", "+%s" % UIKit.money(Jobs.max_bonus_for(house_id)), UIKit.GOLD)
	_sheet_row("Client budget", UIKit.money(int(job["budget"])))
	_sheet_row("Required pieces cost about", UIKit.money(Jobs.minimum_outlay(house_id)))
	_sheet_row("Experience", "+%d XP" % int(job["xp"]))
	_divider()

	_sheet_body.add_child(UIKit.section_label("The brief"))
	for result: Dictionary in Jobs.evaluate(house_id, {"items": [], "room": {}, "spend": 0}):
		var bullet := UIKit.label("•  %s" % result["label"], 17, UIKit.TEXT)
		bullet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bullet.custom_minimum_size = Vector2(440, 0)
		_sheet_body.add_child(bullet)

	var close := UIKit.make_button("Close")
	close.pressed.connect(close_sheet)
	_sheet_actions.add_child(close)

	if not done and not locked:
		_build_shopping_list(house_id)

	if done:
		_divider()
		var record: Dictionary = Game.finished_jobs[house_id]
		_sheet_body.add_child(UIKit.label(
			"%s   %s and %d XP" % [
				RoomReview.stars_text(int(record.get("stars", 1))),
				UIKit.money(int(record["payout"]) + int(record["bonus"])),
				record["xp"],
			], 19, UIKit.GOOD))

	if done:
		# The house is finished, so the only thing on offer is fresh work.
		var again := UIKit.make_primary_button("Take a new contract")
		again.disabled = locked
		again.pressed.connect(func() -> void: _take_repeat(house_id))
		_sheet_actions.add_child(again)
		return

	var action := UIKit.make_primary_button("Continue" if in_progress else "Start job")
	action.disabled = locked
	action.pressed.connect(func() -> void:
		close_sheet()
		start_job.emit(house_id))
	_sheet_actions.add_child(action)


## Invents a new brief for a finished house and puts the player straight on it.
func _take_repeat(house_id: String) -> void:
	var contract := Jobs.generate_contract(house_id, Game.level)
	if contract.is_empty():
		return
	Game.take_repeat_contract(house_id, contract)
	repeat_taken.emit(house_id)
	show_house(house_id)
	toast_message("%s has a new job for you" % contract["client"], 2.4)


## What is already standing in a house, as item id -> count.
static func _placed_counts(house_id: String) -> Dictionary:
	var counts: Dictionary = {}
	var layout := Game.layout_for(house_id)
	for entry: Variant in layout.get("items", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id := str((entry as Dictionary).get("id", ""))
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


## The gap between what the brief needs and what the player already has. It is
## a list to shop from, not a basket: every piece is bought at its own counter.
func _build_shopping_list(house_id: String) -> void:
	var missing := Jobs.shopping_list(house_id, _placed_counts(house_id))
	var paints := Jobs.missing_paints(house_id)
	_divider()

	if missing.is_empty() and paints.is_empty():
		_sheet_body.add_child(UIKit.label(
			"You already have everything this brief needs.", 18, UIKit.GOOD))
		return

	_sheet_body.add_child(UIKit.section_label("Still to buy"))
	var total := Jobs.list_cost(missing)

	# Grouped by shop, so the list reads as a round of the city rather than a
	# heap of names: one heading per counter, and everything you want there
	# under it.
	var by_shop: Dictionary = {}
	var order: Array[String] = []
	for item_id: String in missing:
		var shop_id := Catalog.shop_of(item_id)
		if not by_shop.has(shop_id):
			by_shop[shop_id] = []
			order.append(shop_id)
		(by_shop[shop_id] as Array).append(item_id)

	for shop_id in order:
		_sheet_body.add_child(_shop_heading(shop_id))
		for item_id: String in by_shop[shop_id]:
			var count := int(missing[item_id])
			var right := UIKit.money(Game.buy_price(item_id) * count)
			var tone := UIKit.GOLD
			if not Game.is_item_unlocked(item_id):
				right = "Level %d" % Catalog.effective_unlock_level(item_id)
				tone = UIKit.BAD
			_sheet_body.add_child(_list_row(
				"%d × %s" % [count, Catalog.display_name(item_id)], right, tone))

	if not paints.is_empty():
		_sheet_body.add_child(_shop_heading("paint"))
		for paint: Dictionary in paints:
			var entry: Dictionary = paint["entry"]
			var price := Game.paint_price(entry)
			total += price
			_sheet_body.add_child(_list_row("%s — %s" % [
				"Floor" if paint["surface"] == "floor" else "Wall", entry["name"]],
				UIKit.money(price), UIKit.GOLD))

	var summary := HBoxContainer.new()
	summary.add_child(UIKit.label("Basket", 18, UIKit.MUTED))
	summary.add_child(UIKit.spacer())
	summary.add_child(UIKit.label(UIKit.money(total), 18,
		UIKit.GOLD if Game.can_afford(total) else UIKit.BAD))
	_sheet_body.add_child(summary)

	# With a runner on the books the whole round is one tap. Without her it is
	# still a list to shop from rather than a basket, which is the point of it.
	if Game.is_hired("runner"):
		var send := HBoxContainer.new()
		send.alignment = BoxContainer.ALIGNMENT_END
		var fetch := UIKit.make_primary_button("Send Rosa  %s" % UIKit.money(total))
		fetch.disabled = not Game.can_afford(total)
		fetch.tooltip_text = "Buys the whole list, from every counter above"
		fetch.pressed.connect(func() -> void: _send_the_runner(house_id))
		send.add_child(fetch)
		_sheet_body.add_child(send)
	else:
		_sheet_body.add_child(UIKit.wrapped_label(
			"Buy these at the counters above before you start.", 520, UIKit.MUTED))


func _send_the_runner(house_id: String) -> void:
	var fetched := Game.send_the_runner(house_id, _placed_counts(house_id))
	if fetched < 0:
		Audio.play("deny")
		toast_message("Rosa came back empty — the money is not there")
		return
	Audio.play("buy")
	toast_message("Rosa brought back %d thing%s" % [
		fetched, "" if fetched == 1 else "s"], 2.2)


## The name of a shop, standing over the things the brief wants from it. Once
## the player holds more than one quarter it says which one to drive to; while
## they only own Maple there is nowhere else it could be.
func _shop_heading(shop_id: String) -> Control:
	var shop: Dictionary = Catalog.get_shop(shop_id)
	var name := str(shop.get("name", "The shops"))
	var district_id := Catalog.shop_district(shop_id)
	if district_id != "" and Game.owned_districts.size() > 1:
		name += "  ·  %s" % Jobs.get_district(district_id)["name"]

	var heading := UIKit.label(name, 15, UIKit.ACCENT)
	var holder := MarginContainer.new()
	holder.add_theme_constant_override("margin_top", 8)
	holder.add_child(heading)
	return holder


## An indented line of the shopping list: what to ask for, and what it costs.
func _list_row(left: String, right: String, tone: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(14, 0)
	row.add_child(indent)
	row.add_child(UIKit.label(left, 17, UIKit.TEXT))
	row.add_child(UIKit.spacer())
	row.add_child(UIKit.label(right, 17, tone))
	return row


# ------------------------------------------------------------ district sheet

## The whole city at a glance: which quarters are yours, and what the rest cost.
func show_districts() -> void:
	_begin_sheet("The city", "Four quarters. You start with one and buy the rest out of what you earn.")
	_current_sheet = {"kind": "districts"}

	for district: Dictionary in Jobs.districts():
		var district_id := str(district["id"])
		var owned: bool = Game.is_district_unlocked(district_id)
		var row := HBoxContainer.new()

		var chip := ColorRect.new()
		chip.color = district["accent"] if owned else Color(0.35, 0.36, 0.40)
		chip.custom_minimum_size = Vector2(10, 40)
		row.add_child(chip)

		var name_label := UIKit.label(
			str(district["name"]), 18, UIKit.TEXT if owned else UIKit.MUTED)
		name_label.custom_minimum_size = Vector2(210, 0)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)
		row.add_child(UIKit.spacer())

		if owned:
			var done := 0
			var houses := Jobs.houses_in(district_id)
			for house: Dictionary in houses:
				if Game.is_job_done(str(house["id"])):
					done += 1
			row.add_child(UIKit.label("%d / %d handed over" % [done, houses.size()], 17, UIKit.GOOD))
		else:
			row.add_child(UIKit.label(UIKit.money(int(district["cost"])), 17, UIKit.GOLD))

		var open := UIKit.make_button("Open")
		open.pressed.connect(func() -> void: show_district(district_id))
		row.add_child(open)
		_sheet_body.add_child(row)

	_divider()
	_sheet_body.add_child(UIKit.wrapped_label(
		"A quarter is bought once and is then yours for good. Buying one puts a fresh set of clients on the map — bigger rooms, longer briefs and fees to match.",
		440))

	var close := UIKit.make_button("Close")
	close.pressed.connect(close_sheet)
	_sheet_actions.add_child(close)


func show_district(district_id: String) -> void:
	var district := Jobs.get_district(district_id)
	if district.is_empty():
		return
	var owned: bool = Game.is_district_unlocked(district_id)
	var cost := int(district["cost"])
	var needed_level := int(district["level"])

	_begin_sheet(str(district["name"]), str(district["tagline"]))
	_current_sheet = {"kind": "district", "id": district_id}

	var asking := Game.district_price(district_id)
	if owned:
		_sheet_body.add_child(UIKit.label("Yours", 18, UIKit.GOOD))
	elif Game.level < needed_level:
		_sheet_body.add_child(UIKit.label(
			"Nobody here will hire you below level %d." % needed_level, 18, UIKit.BAD))
	elif not Game.can_afford(asking):
		_sheet_body.add_child(UIKit.label(
			"Short by %s." % UIKit.money(asking - Game.money), 18, UIKit.BAD))
	else:
		_sheet_body.add_child(UIKit.label("On the market", 18, UIKit.ACCENT))
	_divider()

	var summary := Jobs.district_summary(district_id)
	if not summary.is_empty():
		_sheet_row("Houses", str(summary["houses"]))
		_sheet_row("Levels", "%d – %d" % [summary["low_level"], summary["high_level"]])
		_sheet_row("Fees", "%s – %s" % [
			UIKit.money(int(summary["low_fee"])), UIKit.money(int(summary["high_fee"]))], UIKit.GOLD)
	if not owned:
		_sheet_row("Price", UIKit.money(cost), UIKit.GOLD)
		_sheet_row("Kept back for furniture", UIKit.money(Jobs.district_float(district_id)))
		_sheet_row("You need in hand", UIKit.money(asking),
			UIKit.GOLD if Game.can_afford(asking) else UIKit.BAD)
	_divider()

	_sheet_body.add_child(UIKit.section_label("Who is waiting"))
	for house: Dictionary in Jobs.houses_in(district_id):
		var line := HBoxContainer.new()
		line.add_child(UIKit.label(str(house["name"]), 17, UIKit.TEXT))
		line.add_child(UIKit.spacer())
		line.add_child(UIKit.label("level %d" % int(house["level"]), 17, UIKit.MUTED))
		line.add_child(UIKit.label("   %s" % UIKit.money(int(house["payout"])), 17, UIKit.GOLD))
		_sheet_body.add_child(line)

	var back := UIKit.make_button("All quarters")
	back.pressed.connect(show_districts)
	_sheet_actions.add_child(back)

	if owned:
		var go := UIKit.make_primary_button("Show me")
		go.pressed.connect(func() -> void:
			close_sheet()
			district_focused.emit(district_id))
		_sheet_actions.add_child(go)
		return

	var buy := UIKit.make_primary_button("Buy the quarter  %s" % UIKit.money(cost))
	buy.disabled = not Game.can_unlock_district(district_id)
	buy.pressed.connect(func() -> void: _buy_district(district_id))
	_sheet_actions.add_child(buy)


func _buy_district(district_id: String) -> void:
	var district := Jobs.get_district(district_id)
	if not Game.unlock_district(district_id):
		Audio.play("deny")
		toast_message("Not enough money")
		return
	Audio.play("quarter")
	district_bought.emit(district_id)
	show_district(district_id)
	toast_message("%s is yours — %d new clients on the map" % [
		district["name"], Jobs.houses_in(district_id).size()], 3.0)


# ---------------------------------------------------------------- shop sheet

func show_shop(shop_id: String) -> void:
	var shop: Dictionary = Catalog.get_shop(shop_id)
	if shop.is_empty():
		return

	_begin_sheet(str(shop["name"]), str(shop["tagline"]))
	_current_sheet = {"kind": "shop", "id": shop_id}

	if not Game.is_shop_unlocked(shop_id):
		var district_id := str(shop.get("district", ""))
		if district_id != "" and not Game.is_district_unlocked(district_id):
			_sheet_body.add_child(UIKit.label(
				"Trades with the people who own %s." % Jobs.get_district(district_id)["name"],
				18, UIKit.BAD))
		else:
			_sheet_body.add_child(UIKit.label(
				"Opens at level %d." % int(shop["level"]), 18, UIKit.BAD))
		_divider()

	_build_window(shop_id)

	var close := UIKit.make_button("Close")
	close.pressed.connect(close_sheet)
	_sheet_actions.add_child(close)

	if Game.is_shop_unlocked(shop_id):
		var enter := UIKit.make_primary_button("Go in")
		enter.tooltip_text = "Have a look at what is on the floor"
		enter.pressed.connect(func() -> void:
			close_sheet()
			shop_entered.emit(shop_id))
		_sheet_actions.add_child(enter)


## The window rather than the counter: a look at what is on the floor, and a
## door. Everything is bought inside the shop now, off the shop floor itself.
func _build_window(shop_id: String) -> void:
	if shop_id == "paint":
		_window_paint()
	else:
		_window_stock(shop_id)


func _window_stock(shop_id: String) -> void:
	var ids := Catalog.shop_stock(shop_id)
	var ready := 0
	for id in ids:
		if Game.is_item_unlocked(id):
			ready += 1
	_sheet_body.add_child(UIKit.section_label(
		"%d pieces on the floor, %d of them yours to buy" % [ids.size(), ready]))

	# Four to a row, as a window display rather than a price list.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_sheet_body.add_child(grid)
	for id in ids:
		var available: bool = Game.is_item_unlocked(id)
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		cell.add_child(_thumbnail(id, available))
		var price := UIKit.label(
			UIKit.money(Game.buy_price(id)) if available
				else "Lv %d" % Catalog.effective_unlock_level(id),
			14, UIKit.GOLD if available else UIKit.BAD)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(price)
		grid.add_child(cell)

	_divider()
	_sheet_body.add_child(UIKit.wrapped_label(
		"Go in to look round. What you buy waits in your stock until you fit it "
		+ "into a room, and anything can be sold back at the same price.", 440))


func _window_paint() -> void:
	for surface: String in ["floor", "wall"]:
		_sheet_body.add_child(UIKit.section_label(
			"Floor paint" if surface == "floor" else "Wall paint"))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_sheet_body.add_child(row)
		for entry: Dictionary in Catalog.paints(surface):
			var unlocked: bool = Game.is_paint_unlocked(entry)
			var swatch := ColorRect.new()
			swatch.color = entry["color"] if unlocked else Color(0.30, 0.31, 0.35)
			swatch.custom_minimum_size = Vector2(46, 40)
			swatch.tooltip_text = "%s — %s" % [entry["name"],
				UIKit.money(Game.paint_price(entry)) if unlocked
					else "level %d" % int(entry["level"])]
			row.add_child(swatch)
	_divider()
	_sheet_body.add_child(UIKit.wrapped_label(
		"Go in to pick a tin off the rack. A colour is bought once and then yours "
		+ "to use in every room, as often as you like.", 440))


## A picture of the piece, for the shop counter. The same rendered thumbnails
## the designer's tray uses — a colour chip told you nothing about what you
## were buying. It arrives a frame or two late, and the tint stands in for it
## until then, which is also what headless and the smoke test see.
func _thumbnail(item_id: String, available: bool) -> Control:
	var holder := PanelContainer.new()
	holder.custom_minimum_size = Vector2(46, 44)
	# A neutral tile under every piece: the thumbnail carries its own colour,
	# and tinting the backing to match only muddied both.
	var backing := UIKit.panel_box(Color(0.17, 0.18, 0.22), 8)
	backing.content_margin_left = 2
	backing.content_margin_right = 2
	backing.content_margin_top = 2
	backing.content_margin_bottom = 2
	holder.add_theme_stylebox_override("panel", backing)

	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not available:
		picture.modulate = Color(0.62, 0.63, 0.66)
	holder.add_child(picture)

	# A shop sheet is rebuilt on every purchase, so a thumbnail can come back
	# to a row that is already gone.
	Icons.request(item_id, func(texture: Texture2D) -> void:
		if is_instance_valid(picture):
			picture.texture = texture)
	return holder


## One line of the warehouse: what it is, how many, and a way to sell one back.
## Buying happens on a shop floor now, so there is no Buy here.
func _stock_row(item_id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var price := Game.buy_price(item_id)
	var held := Game.stock_of(item_id)

	row.add_child(_thumbnail(item_id, true))

	var name_label := UIKit.label(Catalog.display_name(item_id), 18, UIKit.TEXT)
	name_label.custom_minimum_size = Vector2(200, 0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)

	var count := UIKit.label("×%d" % held, 17, UIKit.GOOD)
	count.custom_minimum_size = Vector2(48, 0)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(count)
	row.add_child(UIKit.spacer())

	var sell := UIKit.make_button("Sell", "Sell one back for %s" % UIKit.money(price))
	sell.pressed.connect(func() -> void:
		Game.sell_item(item_id, 1)
		Audio.play("sell"))
	row.add_child(sell)
	return row


# ------------------------------------------------------------- the warehouse

func show_warehouse() -> void:
	_begin_sheet("Your stock", "Bought and waiting to be fitted.")
	_current_sheet = {"kind": "stock"}

	var owned := Game.owned_item_ids()
	if owned.is_empty():
		_sheet_body.add_child(UIKit.wrapped_label(
			"Nothing in stock yet. Tap a shop on the avenue to buy furniture, then fit it into a client's room.",
			440, UIKit.TEXT))
	else:
		_sheet_row("Pieces held", str(Game.total_stock()))
		_sheet_row("Tied up in stock", UIKit.money(Game.stock_value()), UIKit.GOLD)
		_divider()
		for item_id in owned:
			_sheet_body.add_child(_stock_row(item_id))

	_divider()
	var paints: Array[String] = []
	for surface: String in ["floor", "wall"]:
		for entry: Dictionary in Catalog.paints(surface):
			if Game.owns_paint(surface, str(entry["name"])):
				paints.append(str(entry["name"]))
	_sheet_body.add_child(UIKit.section_label("Paints owned"))
	_sheet_body.add_child(UIKit.wrapped_label(", ".join(paints), 440))

	var close := UIKit.make_button("Close")
	close.pressed.connect(close_sheet)
	_sheet_actions.add_child(close)


# ------------------------------------------------------------- the showroom

## A floor of your own, the third tab of the same sheet. Every other room in the
## game belongs to somebody else; this one keeps whatever you put in it and pays
## for as long as it is dressed.
func show_showroom() -> void:
	_trade_tab = "floor"
	show_perks()


func _showroom_tab() -> void:
	Game.settle_showroom()
	if not Game.showroom_dressed():
		_sheet_body.add_child(UIKit.wrapped_label(
			"An empty floor takes nothing. Go in and stand your own stock in it — "
			+ "the furniture leaves the warehouse the way it does on a job, but "
			+ "nobody takes it away and you can pull it back out whenever you "
			+ "want it for a client.", 460))
	else:
		_sheet_row("On the floor", UIKit.money(Game.showroom_value), UIKit.GOLD)
		_sheet_row("How it reads", RoomReview.stars_text(Game.showroom_stars),
			UIKit.GOOD if Game.showroom_stars >= 2 else UIKit.BAD)
		_sheet_row("Counters shown", Showroom.spread_line(Game.showroom_shops),
			UIKit.TEXT if Game.showroom_shops >= 3 else UIKit.MUTED)
		_divider()
		_sheet_row("Takes", "%s an hour" % UIKit.money(Game.showroom_take),
			UIKit.GOLD if Game.showroom_take > 0 else UIKit.BAD)
		_sheet_row("In the till", "%s of %s" % [
			UIKit.money(Game.till()), UIKit.money(Game.till_cap())],
			UIKit.GOLD if Game.till() >= Game.till_cap() and Game.till() > 0
				else UIKit.TEXT)
		_showroom_bar(Game.till_fullness())
		if Game.showroom_take <= 0:
			_sheet_body.add_child(UIKit.wrapped_label(
				"Nobody would walk into this. It wants at least %d pieces, from a "
				% Showroom.MIN_PIECES + "spread of counters, arranged well enough "
				+ "to earn a star.", 460, UIKit.BAD))
		elif Game.till() >= Game.till_cap():
			_sheet_body.add_child(UIKit.wrapped_label(
				"The till is full and has stopped. A floor is something to look in "
				+ "on, not something to farm.", 460, UIKit.MUTED))

	_divider()
	_sheet_body.add_child(UIKit.wrapped_label(
		"What it takes is what the room is worth times how well it reads times "
		+ "how many counters it represents. A cheap floor arranged well beats an "
		+ "expensive one thrown together, which is the only thing about this "
		+ "worth getting good at.", 460, UIKit.MUTED))

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	_sheet_body.add_child(actions)
	if Game.till() > 0:
		var empty := UIKit.make_button("Empty the till  %s" % UIKit.money(Game.till()))
		empty.pressed.connect(_empty_the_till)
		actions.add_child(empty)
	var go := UIKit.make_primary_button("Go in")
	go.pressed.connect(func() -> void: showroom_entered.emit())
	actions.add_child(go)


func _empty_the_till() -> void:
	var taken := Game.collect_till()
	if taken <= 0:
		Audio.play("deny")
		return
	Audio.play("sell")
	toast_message("%s out of the till" % UIKit.money(taken), 2.2)
	show_perks()


## The till filling, on the same kind of bar the holdings use.
func _showroom_bar(fraction: float) -> void:
	var track := PanelContainer.new()
	track.custom_minimum_size = Vector2(0, 10)
	track.add_theme_stylebox_override("panel", UIKit.panel_box(Color(1, 1, 1, 0.10), 5))
	var fill := ColorRect.new()
	fill.color = UIKit.GOLD
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.custom_minimum_size = Vector2(0, 6)
	var rest := Control.new()
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.size_flags_stretch_ratio = maxf(clampf(fraction, 0.0, 1.0), 0.001)
	rest.size_flags_stretch_ratio = maxf(1.0 - clampf(fraction, 0.0, 1.0), 0.001)
	var row := HBoxContainer.new()
	row.add_child(fill)
	row.add_child(rest)
	track.add_child(row)
	_sheet_body.add_child(track)


# --------------------------------------------------------------- the trade

## What levelling up buys. Four lines, eight steps each, one point a level —
## thirty-two steps against twenty-nine points, so the last thing this sheet
## does is make you leave something behind.
func show_perks() -> void:
	var spare := Game.perk_points_left()
	var hired := Game.hired_ids().size()
	_begin_sheet("Your trade", "%s to spend%s." % [
		"A point" if spare == 1 else "%d points" % spare,
		"" if hired == 0 else ", %d on the books at %d%% of every fee"
			% [hired, int(round(Game.wage_share() * 100.0))]])
	_current_sheet = {"kind": "perks"}

	# Two halves of the same question — what you got good at, and who does the
	# rest — so they share a sheet rather than a second button on the bar.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	var tab_names: Array = [["you", "You"], ["staff", "Staff"]]
	if Game.showroom_open():
		tab_names.append(["floor", "Showroom"])
	for pair: Array in tab_names:
		var key := str(pair[0])
		var button: Button = (UIKit.make_primary_button(str(pair[1]))
			if _trade_tab == key else UIKit.make_button(str(pair[1])))
		button.pressed.connect(func() -> void:
			_trade_tab = key
			show_perks())
		tabs.add_child(button)
	tabs.add_child(UIKit.spacer())
	_sheet_body.add_child(tabs)

	if _trade_tab == "floor" and Game.showroom_open():
		_showroom_tab()
	elif _trade_tab == "you":
		_sheet_body.add_child(UIKit.wrapped_label(
			"Every level hands you one point, and a point buys the next step of one "
			+ "line. There are more steps here than there are levels in a career, so "
			+ "what you leave out is as much a decision as what you take. Nothing "
			+ "here can be given back.", 460))
		for line: Dictionary in Perks.lines():
			_divider()
			_sheet_body.add_child(_perk_line(line))
	else:
		_sheet_body.add_child(UIKit.wrapped_label(
			"Four people, each doing one chore you would otherwise tap through by "
			+ "hand. Nobody is paid by the hour — a share of every fee instead, so "
			+ "a fortnight away costs nothing. Letting somebody go is free.", 460))
		_sheet_row("Joining fee today", UIKit.money(Staff.joining_fee(Game.level)),
			UIKit.GOLD if Game.can_afford(Staff.joining_fee(Game.level)) else UIKit.BAD)
		for role: Dictionary in Staff.roles():
			_divider()
			_sheet_body.add_child(_staff_card(role))

	var close := UIKit.make_button("Close")
	close.pressed.connect(close_sheet)
	_sheet_actions.add_child(close)


## One person: who they are, what they take, what they do about it, and the
## button that puts them on the books or takes them off again.
func _staff_card(role: Dictionary) -> Control:
	var role_id := str(role["id"])
	var hired := Game.is_hired(role_id)
	var tone: Color = role["color"]

	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var head := HBoxContainer.new()
	var title := UIKit.label("%s  ·  %s" % [role["name"], role["title"]], 20,
		tone if hired else UIKit.MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var wage := UIKit.label("%d%% of a fee" % int(round(float(role["share"]) * 100.0)),
		15, UIKit.BAD if hired else UIKit.MUTED)
	wage.clip_text = true
	wage.custom_minimum_size = Vector2(150, 0)
	wage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wage.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(wage)
	block.add_child(head)

	block.add_child(UIKit.wrapped_label("“%s”" % role["blurb"], 460, UIKit.MUTED))
	block.add_child(UIKit.wrapped_label(str(role["does"]), 460,
		UIKit.TEXT if hired else UIKit.MUTED))

	var foot := HBoxContainer.new()
	var blocked := Game.hire_blocked(role_id)
	var status := UIKit.label("On the books" if hired else blocked, 15,
		UIKit.GOOD if hired else UIKit.BAD)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(status)

	if hired:
		var go := UIKit.make_button("Let go", "Costs nothing, and stops the share at once")
		go.pressed.connect(func() -> void: _let_go(role_id))
		foot.add_child(go)
	else:
		var take := UIKit.make_primary_button("Take on  %s" % UIKit.money(
			Staff.joining_fee(Game.level))) if blocked == "" \
			else UIKit.make_button("Take on", blocked)
		take.disabled = blocked != ""
		take.pressed.connect(func() -> void: _hire(role_id))
		foot.add_child(take)
	block.add_child(foot)
	return block


func _hire(role_id: String) -> void:
	if not Game.hire(role_id):
		Audio.play("deny")
		return
	Audio.play("buy")
	toast_message("%s starts today" % Staff.full_name(role_id), 2.4)
	show_perks()


func _let_go(role_id: String) -> void:
	if not Game.let_go(role_id):
		Audio.play("deny")
		return
	Audio.play("sell")
	toast_message("%s is off the books" % Staff.role_name(role_id), 2.2)
	show_perks()


## One line: its name and what it is worth now, a row of pips for the eight
## steps, what the next one is called, and the button that buys it.
func _perk_line(line: Dictionary) -> Control:
	var line_id := str(line["id"])
	var rank := Game.perk_rank(line_id)
	var tone: Color = line["color"]

	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 3)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var head := HBoxContainer.new()
	var title := UIKit.label(str(line["name"]), 20, tone)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var worth := UIKit.label("%s %s" % [Perks.value_line(line_id, rank), line["effect"]],
		15, UIKit.GOOD if rank > 0 else UIKit.MUTED)
	# Given its own width rather than allowed to ask for one: measured off its
	# text, a long line here pushed the whole head past the edge of the sheet.
	worth.clip_text = true
	worth.custom_minimum_size = Vector2(210, 0)
	worth.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	worth.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(worth)
	block.add_child(head)

	# Eight pips, filled to the rank. A bar would say the same thing, but the
	# steps are bought one at a time and the pips are what you count.
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 4)
	for step in Perks.RANKS:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(30, 7)
		pip.color = tone if step < rank else Color(1, 1, 1, 0.13)
		pips.add_child(pip)
	pips.add_child(UIKit.spacer())
	block.add_child(pips)

	block.add_child(UIKit.wrapped_label(str(line["blurb"]), 460, UIKit.MUTED))

	var foot := HBoxContainer.new()
	var blocked := Game.perk_blocked(line_id)
	var next_name := Perks.step_name(line_id, rank + 1)
	var caption := UIKit.label(
		"Taken: %s" % Perks.step_name(line_id, rank) if next_name == ""
			else "Next: %s" % next_name,
		15, UIKit.GOOD if next_name == "" else UIKit.TEXT)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(caption)

	if next_name != "":
		var take := UIKit.make_primary_button("Take it") if blocked == "" \
			else UIKit.make_button("Take it", blocked)
		take.disabled = blocked != ""
		take.pressed.connect(func() -> void: _take_perk(line_id))
		foot.add_child(take)
	block.add_child(foot)

	if blocked != "" and next_name != "":
		block.add_child(UIKit.label(blocked, 14, UIKit.BAD))
	return block


func _take_perk(line_id: String) -> void:
	var was := Game.perk_rank(line_id)
	if not Game.take_perk(line_id):
		Audio.play("deny")
		return
	Audio.play("levelup")
	toast_message("%s — %s" % [Perks.line_name(line_id),
		Perks.step_name(line_id, was + 1)], 2.4)
	show_perks()


# -------------------------------------------------------------------- modal

func _build_modal() -> void:
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.visible = false
	_root.add_child(_modal)
	_blockers.append(_modal)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)

	_modal_body = VBoxContainer.new()
	panel.add_child(_modal_body)


func is_modal_open() -> bool:
	return _modal.visible


func close_modal() -> void:
	_modal.visible = false
	for child in _modal_body.get_children():
		_modal_body.remove_child(child)
		child.queue_free()


func _open_guide() -> void:
	close_modal()
	_modal.visible = true
	_modal_body.add_child(UIKit.label("How the work goes", 24))

	var sections := [
		["Pick up a job", "Tap a house on the map. The client tells you what the room has to contain and what they will pay for it."],
		["Go shopping", "Buy furniture at the shops on the avenue and it goes into your stock. The brief lists exactly what is missing, grouped by the shop that sells it, so you know where to go."],
		["Fit it out", "Inside a room you place pieces from stock — no money changes hands there. Put a piece back and it returns to the warehouse, ready for the next house."],
		["Hand it over", "Once every line of the brief is ticked, hand the room over. The furniture you left behind stays with the client, and they mark the room out of three stars — for keeping the big pieces against the walls, holding to a palette, leaving room to move, and coming in on budget. Three stars pays thirty per cent on top of the fee."],
		["Grow", "Every finished job pays experience. New levels open the pricier shops, the better paints and the larger, more demanding houses."],
		["Buy the city", "Maple Quarter is only one corner of the map. The other three sit behind hoardings until you buy them outright — tap one to see the price and who is waiting. Each brings four more clients, with longer briefs and much bigger fees."],
		["Keep going", "A house you have handed over will take you back: open it again and the owner has a fresh room in mind, scaled to the level you have reached."],
	]
	for section: Array in sections:
		_modal_body.add_child(UIKit.label(section[0], 19, UIKit.ACCENT))
		_modal_body.add_child(UIKit.wrapped_label(section[1], 560))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	_modal_body.add_child(row)

	row.add_child(UIKit.sound_row())
	row.add_child(UIKit.spacer())

	var reset := UIKit.make_button("Start a new career")
	reset.add_theme_color_override("font_color", UIKit.BAD)
	reset.pressed.connect(_confirm_reset)
	row.add_child(reset)

	var close := UIKit.make_primary_button("Got it")
	close.pressed.connect(close_modal)
	row.add_child(close)


func _confirm_reset() -> void:
	close_modal()
	_modal.visible = true
	_modal_body.add_child(UIKit.label("Start again?", 24))
	_modal_body.add_child(UIKit.wrapped_label(
		"This wipes your money, level and every finished job, and puts you back to %s."
			% UIKit.money(Game.STARTING_MONEY), 560))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	_modal_body.add_child(row)
	var cancel := UIKit.make_button("Keep playing")
	cancel.pressed.connect(close_modal)
	row.add_child(cancel)
	var confirm := UIKit.make_button("Wipe it")
	confirm.add_theme_color_override("font_color", UIKit.BAD)
	confirm.pressed.connect(func() -> void:
		close_modal()
		close_sheet()
		Game.reset()
		career_reset.emit())
	row.add_child(confirm)


func show_message(title: String, lines: Array) -> void:
	close_modal()
	_modal.visible = true
	_modal_body.add_child(UIKit.label(title, 24))
	for line: String in lines:
		_modal_body.add_child(UIKit.wrapped_label(line, 560, UIKit.TEXT))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	_modal_body.add_child(row)
	var close := UIKit.make_primary_button("Close")
	close.pressed.connect(close_modal)
	row.add_child(close)


## True when the point lands on a panel, so the map should ignore the gesture.
func is_point_over_ui(point: Vector2) -> bool:
	for control in _blockers:
		if is_instance_valid(control) and control.visible and control.get_global_rect().has_point(point):
			return true
	return false
