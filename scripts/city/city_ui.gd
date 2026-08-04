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

	var quarters := UIKit.make_button("City", "The quarters of the city, and what it costs to work in them")
	quarters.pressed.connect(show_districts)
	row.add_child(quarters)

	var sandbox := UIKit.make_button("Free Build", "Design a room with no client and no stock to worry about")
	sandbox.pressed.connect(func() -> void: free_build.emit())
	row.add_child(sandbox)

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
	_sheet.visible = false


func is_sheet_open() -> bool:
	return _sheet.visible


func _begin_sheet(title: String, subtitle: String) -> void:
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


## The gap between what the brief needs and what the player has, with a button
## that fills the whole basket in one go.
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
	for item_id: String in missing:
		var row := HBoxContainer.new()
		var count := int(missing[item_id])
		row.add_child(UIKit.label("%d × %s" % [count, Catalog.display_name(item_id)], 17, UIKit.TEXT))
		row.add_child(UIKit.spacer())
		if Game.is_item_unlocked(item_id):
			row.add_child(UIKit.label(UIKit.money(Catalog.price(item_id) * count), 17, UIKit.GOLD))
		else:
			row.add_child(UIKit.label("Level %d" % Catalog.effective_unlock_level(item_id), 17, UIKit.BAD))
		_sheet_body.add_child(row)

	for paint: Dictionary in paints:
		var entry: Dictionary = paint["entry"]
		var price := Catalog.paint_price(entry)
		total += price
		var row := HBoxContainer.new()
		row.add_child(UIKit.label("%s paint — %s" % [
			"Floor" if paint["surface"] == "floor" else "Wall", entry["name"]], 17, UIKit.TEXT))
		row.add_child(UIKit.spacer())
		row.add_child(UIKit.label(UIKit.money(price), 17, UIKit.GOLD))
		_sheet_body.add_child(row)

	var summary := HBoxContainer.new()
	summary.add_child(UIKit.label("Basket", 18, UIKit.MUTED))
	summary.add_child(UIKit.spacer())
	summary.add_child(UIKit.label(UIKit.money(total), 18,
		UIKit.GOLD if Game.can_afford(total) else UIKit.BAD))
	_sheet_body.add_child(summary)

	# The basket button lives in the pinned action row rather than at the
	# bottom of a long brief, so it is always within reach.
	var buy_all := UIKit.make_button("Buy all  %s" % UIKit.money(total))
	buy_all.disabled = not Game.can_afford(total)
	buy_all.pressed.connect(func() -> void: _buy_basket(house_id, missing, paints))
	_sheet_actions.add_child(buy_all)


func _buy_basket(house_id: String, missing: Dictionary, paints: Array[Dictionary]) -> void:
	var bought := 0
	for item_id: String in missing:
		if not Game.is_item_unlocked(item_id):
			continue
		if Game.buy_item(item_id, int(missing[item_id])):
			bought += int(missing[item_id])
	for paint: Dictionary in paints:
		Game.buy_paint(str(paint["surface"]), paint["entry"])
	toast_message("%d piece%s added to your stock" % [bought, "" if bought == 1 else "s"])
	show_house(house_id)


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
		toast_message("Not enough money")
		return
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
		_sheet_body.add_child(UIKit.label(
			"Opens at level %d." % int(shop["level"]), 18, UIKit.BAD))
		_divider()

	if shop_id == "paint":
		_build_paint_counter()
	else:
		_build_furniture_counter(shop_id)

	var close := UIKit.make_button("Close")
	close.pressed.connect(close_sheet)
	_sheet_actions.add_child(close)


func _build_furniture_counter(shop_id: String) -> void:
	_sheet_body.add_child(UIKit.section_label("On sale"))
	for item_id in Catalog.shop_stock(shop_id):
		_sheet_body.add_child(_shop_row(item_id))

	_divider()
	_sheet_body.add_child(UIKit.wrapped_label(
		"What you buy waits in your stock until you fit it into a room. Sell anything back at the same price — you only pay for a piece for good when you hand over the house it is standing in.",
		440))


## One line of a shop counter: a buy button, and a sell button once owned.
func _shop_row(item_id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var available: bool = Game.is_item_unlocked(item_id)
	var price := Catalog.price(item_id)
	var held := Game.stock_of(item_id)

	var chip := ColorRect.new()
	chip.color = Catalog.default_tint(item_id) if available else Color(0.35, 0.36, 0.40)
	chip.custom_minimum_size = Vector2(10, 38)
	row.add_child(chip)

	var name_label := UIKit.label(
		Catalog.display_name(item_id), 18, UIKit.TEXT if available else UIKit.MUTED)
	name_label.custom_minimum_size = Vector2(176, 0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)

	var owned_label := UIKit.label("×%d" % held if held > 0 else "", 17, UIKit.GOOD)
	owned_label.custom_minimum_size = Vector2(44, 0)
	owned_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(owned_label)
	row.add_child(UIKit.spacer())

	if not available:
		row.add_child(UIKit.label(
			"Level %d" % Catalog.effective_unlock_level(item_id), 17, UIKit.BAD))
		return row

	if held > 0:
		var sell := UIKit.make_button("Sell", "Sell one back for %s" % UIKit.money(price))
		sell.pressed.connect(func() -> void:
			Game.sell_item(item_id, 1))
		row.add_child(sell)

	var buy := UIKit.make_button("Buy  %s" % UIKit.money(price))
	buy.disabled = not Game.can_afford(price)
	buy.pressed.connect(func() -> void:
		if not Game.buy_item(item_id, 1):
			toast_message("Not enough money")
	)
	row.add_child(buy)
	return row


func _build_paint_counter() -> void:
	for surface: String in ["floor", "wall"]:
		_sheet_body.add_child(UIKit.section_label(
			"Floor paint" if surface == "floor" else "Wall paint"))
		for entry: Dictionary in Catalog.paints(surface):
			_sheet_body.add_child(_paint_row(surface, entry))
	_divider()
	_sheet_body.add_child(UIKit.wrapped_label(
		"A colour is bought once and then yours to use in every room, as often as you like.",
		440))


func _paint_row(surface: String, entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	var paint_name := str(entry["name"])
	var unlocked: bool = Game.is_paint_unlocked(entry)
	var owned: bool = Game.owns_paint(surface, paint_name)
	var price := Catalog.paint_price(entry)

	var swatch := ColorRect.new()
	swatch.color = entry["color"] if unlocked else Color(0.30, 0.31, 0.35)
	swatch.custom_minimum_size = Vector2(64, 34)
	row.add_child(swatch)

	var name_label := UIKit.label(paint_name, 18, UIKit.TEXT if unlocked else UIKit.MUTED)
	name_label.custom_minimum_size = Vector2(170, 0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	row.add_child(UIKit.spacer())

	if not unlocked:
		row.add_child(UIKit.label("Level %d" % int(entry["level"]), 17, UIKit.BAD))
	elif owned:
		row.add_child(UIKit.label("In your store", 17, UIKit.GOOD))
	else:
		var buy := UIKit.make_button("Buy  %s" % UIKit.money(price))
		buy.disabled = not Game.can_afford(price)
		buy.pressed.connect(func() -> void:
			if not Game.buy_paint(surface, entry):
				toast_message("Not enough money")
		)
		row.add_child(buy)
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
			_sheet_body.add_child(_shop_row(item_id))

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
		["Go shopping", "Buy furniture at the shops on the avenue and it goes into your stock. The brief lists exactly what is missing, and one button fills the basket for you."],
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
