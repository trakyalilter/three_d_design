class_name ShopUI
extends CanvasLayer
## The overlay inside a shop: the wallet along the top, the client's brief down
## the left, and a card for whatever the player has just tapped on the floor.
##
## The card is the whole of the buying interface. Nothing is bought from a list
## here — you pick a piece up off the shop floor and this tells you what it is,
## what it costs and how many you already have.
##
## The brief comes shopping with you. Reading it used to mean driving back to
## the map, tapping the house and driving in again, which is a long walk for one
## line of text — so the panel on the left carries the client's words and the
## list of what is still to buy, with whatever this shop sells at the top of it.

signal leave_requested()
signal buy_requested(item_id: String)
signal sell_requested(item_id: String)
signal buy_paint_requested(surface: String, entry: Dictionary)
signal buy_supply_requested(supply_id: String, count: int)
signal sell_supply_requested(supply_id: String, count: int)
## A line of the list was tapped: show the player the piece it means, standing
## on this floor.
signal walk_to_requested(item_id: String)
signal walk_to_paint_requested(surface: String, entry: Dictionary)

## The brief panel. Wide enough for a client's sentence without crowding the
## floor, and it leaves the card on the other side of the screen alone.
const SHEET_WIDTH := 430.0
const SHEET_TEXT := SHEET_WIDTH - 34.0

var _root: Control
var _blockers: Array[Control] = []
var _money_label: Label
var _stock_label: Label
var _hint: Label
var _card: PanelContainer
var _card_body: VBoxContainer
var _toast: Label
var _toast_timer: Timer

var _shown_item := ""
var _shown_paint: Dictionary = {}
var _shown_surface := ""
var _shown_supply := ""

## The shop being stood in, and the job being shopped for. The job is empty when
## the player walked in off the map without a house in mind, and then there is
## no brief to show.
var _shop_id := ""
var _house := ""
var _brief_button: Button
var _brief_sheet: PanelContainer
var _brief_title: Label
var _brief_subtitle: Label
var _brief_body: VBoxContainer


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.name = "ShopUIRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIKit.build_theme()
	add_child(_root)

	_build_top_bar()
	_build_card()
	_build_hint()
	_build_brief_sheet()

	Game.money_changed.connect(func(_amount: int) -> void: refresh())
	Game.stock_changed.connect(func() -> void: refresh())
	refresh()


## `house_id` is the job the player is shopping for, or "" if they are only
## browsing.
func configure(shop: Dictionary, house_id: String = "") -> void:
	_shop_id = str(shop.get("id", ""))
	_house = house_id if not Jobs.get_job(house_id).is_empty() else ""
	_hint.text = "Tap a piece to see what it costs. %s" % shop.get("tagline", "")
	_sync_brief_button()
	# Open on the way in when this shop actually sells something on the list.
	# That is the whole point of carrying it: the player came here to buy those
	# pieces and should not have to ask for the list to find out which ones.
	# Quietly: the door has only just shut behind them.
	if _house != "" and _wanted_here() > 0:
		_open_brief(false)


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

	_stock_label = UIKit.label("", 17, UIKit.MUTED)
	_stock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_stock_label)

	row.add_child(UIKit.spacer())

	_brief_button = UIKit.make_button("Brief")
	_brief_button.visible = false
	_brief_button.pressed.connect(_toggle_brief)
	row.add_child(_brief_button)

	var leave := UIKit.make_primary_button("Back to the map")
	leave.pressed.connect(func() -> void: leave_requested.emit())
	row.add_child(leave)


func _build_card() -> void:
	_card = PanelContainer.new()
	_card.name = "Card"
	_card.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_card.offset_left = -420
	_card.offset_right = -14
	_card.offset_top = -300
	_card.offset_bottom = -14
	_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.visible = false
	_root.add_child(_card)
	_blockers.append(_card)

	_card_body = VBoxContainer.new()
	_card.add_child(_card_body)


func _build_hint() -> void:
	_hint = UIKit.label("", 18, UIKit.TEXT)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.offset_left = 16
	_hint.offset_top = -46
	_hint.offset_bottom = -16
	_hint.offset_right = 760
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


func toast(text: String, seconds: float = 2.0) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_timer.start(seconds)


func refresh() -> void:
	_money_label.text = UIKit.money(Game.money)
	var held := Game.total_stock()
	_stock_label.text = "   %d piece%s in stock" % [held, "" if held == 1 else "s"]
	if _shown_item != "":
		show_item(_shown_item)
	elif not _shown_paint.is_empty():
		show_paint(_shown_surface, _shown_paint)
	elif _shown_supply != "":
		show_supply(_shown_supply)
	# Buying something crosses it off the list, so the list is read again.
	_sync_brief_button()
	if _brief_sheet != null and _brief_sheet.visible:
		_redraw_brief()


## The card for a piece of furniture: a picture of it, what it is, what it
## costs, and the two things you can do about that.
func show_item(item_id: String) -> void:
	_shown_item = item_id
	_shown_paint = {}
	_shown_surface = ""
	_shown_supply = ""
	_clear_card()
	_card.visible = true

	var available := Game.is_item_unlocked(item_id)
	var price := Game.buy_price(item_id)
	var held := Game.stock_of(item_id)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_card_body.add_child(head)

	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(76, 76)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not available:
		picture.modulate = Color(0.62, 0.63, 0.66)
	head.add_child(picture)
	Icons.request(item_id, func(texture: Texture2D) -> void:
		if is_instance_valid(picture):
			picture.texture = texture)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	head.add_child(titles)
	var name_label := UIKit.label(Catalog.display_name(item_id), 22)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(name_label)
	titles.add_child(UIKit.label(Catalog.category_of(item_id), 16, UIKit.MUTED))

	# What this piece says about a room. Plain stock says nothing, which is
	# worth knowing too — it is the only thing that never argues.
	var style := Catalog.style_of(item_id)
	_row("Style", Catalog.style_name(style), Catalog.style_color(style))

	_row("Price", UIKit.money(price), UIKit.GOLD if Game.can_afford(price) else UIKit.BAD)
	_row("You own", "%d" % held, UIKit.GOOD if held > 0 else UIKit.MUTED)

	if not available:
		var district := Catalog.district_of(item_id)
		var reason := "Opens at level %d." % Catalog.effective_unlock_level(item_id)
		if district != "" and not Game.is_district_unlocked(district):
			reason = "Sold only to people who own %s." % Jobs.get_district(district)["name"]
		_card_body.add_child(UIKit.wrapped_label(reason, 360, UIKit.BAD))
		return

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	_card_body.add_child(actions)

	if held > 0:
		var sell := UIKit.make_button("Sell one", "Get %s back" % UIKit.money(price))
		sell.pressed.connect(func() -> void: sell_requested.emit(item_id))
		actions.add_child(sell)

	var buy := UIKit.make_primary_button("Buy  %s" % UIKit.money(price))
	buy.disabled = not Game.can_afford(price)
	buy.pressed.connect(func() -> void: buy_requested.emit(item_id))
	actions.add_child(buy)


## The card for a tin of paint. A colour is bought once and then yours forever,
## so there is nothing to sell and no count to keep.
func show_paint(surface: String, entry: Dictionary) -> void:
	_shown_item = ""
	_shown_paint = entry
	_shown_surface = surface
	_shown_supply = ""
	_clear_card()
	_card.visible = true

	var available := Game.is_paint_unlocked(entry)
	var owned := Game.owns_paint(surface, str(entry["name"]))
	var price := Game.paint_price(entry)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_card_body.add_child(head)

	var swatch := PanelContainer.new()
	swatch.custom_minimum_size = Vector2(76, 76)
	var box := UIKit.panel_box(entry["color"], 10)
	swatch.add_theme_stylebox_override("panel", box)
	head.add_child(swatch)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	head.add_child(titles)
	titles.add_child(UIKit.label(str(entry["name"]), 22))
	titles.add_child(UIKit.label(
		"Floor paint" if surface == "floor" else "Wall paint", 16, UIKit.MUTED))

	if owned:
		_card_body.add_child(UIKit.wrapped_label(
			"Already yours. A colour is bought once and then free to use in every "
			+ "room you fit out.", 360, UIKit.GOOD))
		return

	_row("Price", UIKit.money(price), UIKit.GOLD if Game.can_afford(price) else UIKit.BAD)

	if not available:
		_card_body.add_child(UIKit.wrapped_label(
			"Opens at level %d." % int(entry.get("level", 1)), 360, UIKit.BAD))
		return

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	_card_body.add_child(actions)
	var buy := UIKit.make_primary_button("Buy  %s" % UIKit.money(price))
	buy.disabled = not Game.can_afford(price)
	buy.pressed.connect(func() -> void: buy_paint_requested.emit(surface, entry))
	actions.add_child(buy)


## The card for a pallet of trade material. This is the only place in the game
## where you buy something that is not finished, so it says what it is for.
func show_supply(supply_id: String) -> void:
	_shown_item = ""
	_shown_paint = {}
	_shown_surface = ""
	_shown_supply = supply_id
	_clear_card()
	_card.visible = true

	var entry := Catalog.get_trade(supply_id)
	if entry.is_empty():
		return
	var price := Game.supply_price(supply_id)
	var held := Game.supply_count(supply_id)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_card_body.add_child(head)

	var swatch := PanelContainer.new()
	swatch.custom_minimum_size = Vector2(76, 76)
	swatch.add_theme_stylebox_override("panel", UIKit.panel_box(entry["color"], 10))
	head.add_child(swatch)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	head.add_child(titles)
	titles.add_child(UIKit.label(str(entry["name"]), 22))
	titles.add_child(UIKit.label("Sold by the unit", 16, UIKit.MUTED))

	_card_body.add_child(UIKit.wrapped_label(str(entry["blurb"]), 360, UIKit.MUTED))
	_row("A unit", UIKit.money(price), UIKit.GOLD if Game.can_afford(price) else UIKit.BAD)
	_row("In the store", "%d %s" % [held, entry["unit"]],
		UIKit.GOOD if held > 0 else UIKit.MUTED)

	if held > 0:
		var back := HBoxContainer.new()
		back.alignment = BoxContainer.ALIGNMENT_END
		_card_body.add_child(back)
		var sell := UIKit.make_button("Sell one back", "Get %s back" % UIKit.money(price))
		sell.pressed.connect(func() -> void: sell_supply_requested.emit(supply_id, 1))
		back.add_child(sell)

	# A wardrobe takes a hundred boards, so the merchant sells by the lorry as
	# well as by the unit. The bill is what it is; tapping it out one at a time
	# would be the only hard part of the whole game.
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 6)
	_card_body.add_child(actions)
	actions.add_child(UIKit.label("Buy", 18, UIKit.MUTED))
	for count in [1, 10, 50]:
		var lot: int = count
		var button: Button = (UIKit.make_primary_button("%d" % lot) if lot == 10
			else UIKit.make_button("%d" % lot, UIKit.money(price * lot)))
		button.disabled = not Game.can_afford(price * lot)
		button.pressed.connect(func() -> void: buy_supply_requested.emit(supply_id, lot))
		actions.add_child(button)


# ---------------------------------------------------------------- the brief

func _build_brief_sheet() -> void:
	_brief_sheet = PanelContainer.new()
	_brief_sheet.name = "BriefSheet"
	_brief_sheet.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_brief_sheet.offset_left = 12
	_brief_sheet.offset_right = 12 + SHEET_WIDTH
	_brief_sheet.offset_top = 78
	_brief_sheet.offset_bottom = -12
	_brief_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_brief_sheet.visible = false
	_root.add_child(_brief_sheet)
	_blockers.append(_brief_sheet)

	var column := VBoxContainer.new()
	_brief_sheet.add_child(column)

	_brief_title = UIKit.label("", 22)
	_brief_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_brief_title)

	_brief_subtitle = UIKit.label("", 16, UIKit.MUTED)
	_brief_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_brief_subtitle)

	# A whole-floor job asks for a dozen things, so the panel scrolls rather than
	# growing off the bottom of a phone.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_brief_body = VBoxContainer.new()
	_brief_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_brief_body)


func is_brief_open() -> bool:
	return _brief_sheet != null and _brief_sheet.visible


func close_brief() -> void:
	if not is_brief_open():
		return
	Audio.play("close")
	_brief_sheet.visible = false
	_hint.visible = true


func _toggle_brief() -> void:
	if is_brief_open():
		close_brief()
	else:
		_open_brief(true)


func _open_brief(with_sound: bool) -> void:
	if with_sound:
		Audio.play("open")
	_brief_sheet.visible = true
	# The hint lives in the corner the panel covers, and it has been read by the
	# time anybody is reading a brief.
	_hint.visible = false
	_redraw_brief()


## How many pieces on the list are sold on this floor. It goes on the button,
## because a shop with nothing on the list in it is a shop to walk out of.
func _wanted_here() -> int:
	if _house == "":
		return 0
	var count := 0
	var missing := Jobs.shopping_list(_house, Jobs.placed_counts(_house))
	for item_id: String in missing:
		if Catalog.shop_of(item_id) == _shop_id:
			count += int(missing[item_id])
	if _shop_id == "paint":
		count += Jobs.missing_paints(_house).size()
	return count


func _sync_brief_button() -> void:
	if _brief_button == null:
		return
	_brief_button.visible = _house != ""
	if _house == "":
		if _brief_sheet != null:
			_brief_sheet.visible = false
			_hint.visible = true
		return
	var here := _wanted_here()
	_brief_button.text = "Brief  %d here" % here if here > 0 else "Brief"
	_brief_button.tooltip_text = "What %s asked for, and what is still to buy" \
		% Jobs.get_job(_house).get("client", "the client")


## The brief, as it reads from inside a shop: the client's words, then the list,
## with everything this floor sells at the top of it and everything it does not
## underneath. The lines of the brief itself come last — they are the reason for
## the list rather than something to act on with a wallet in your hand.
func _redraw_brief() -> void:
	for child in _brief_body.get_children():
		_brief_body.remove_child(child)
		child.queue_free()
	if _house == "":
		return

	var job := Jobs.get_job(_house)
	_brief_title.text = str(job.get("name", ""))
	_brief_subtitle.text = "For %s  ·  %s" % [
		job.get("client", "a client"), Jobs.room_line(_house)]

	_brief_body.add_child(UIKit.wrapped_label(
		"“%s”" % job.get("brief", ""), SHEET_TEXT, UIKit.TEXT))
	# What the client likes, which is a buying decision more than a fitting one.
	_brief_body.add_child(UIKit.wrapped_label(
		Jobs.taste_line(_house), SHEET_TEXT, Catalog.style_color(Jobs.taste_of(_house))))

	_build_brief_list(Jobs.shopping_list(_house, Jobs.placed_counts(_house)))

	_brief_divider()
	_brief_body.add_child(UIKit.section_label("The brief"))
	for result: Dictionary in Jobs.evaluate(_house, {"items": [], "room": {}, "spend": 0}):
		var bullet := UIKit.label("•  %s" % result["label"], 16, UIKit.MUTED)
		bullet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bullet.custom_minimum_size = Vector2(SHEET_TEXT, 0)
		_brief_body.add_child(bullet)


func _build_brief_list(missing: Dictionary) -> void:
	var paints := Jobs.missing_paints(_house)
	_brief_divider()

	if missing.is_empty() and paints.is_empty():
		_brief_body.add_child(UIKit.wrapped_label(
			"You already have everything this brief needs. Go and fit it.",
			SHEET_TEXT, UIKit.GOOD))
		return

	# Split the list in two: what is standing on this floor, and what is not.
	var here: Array[String] = []
	var by_shop: Dictionary = {}
	var order: Array[String] = []
	for item_id: String in missing:
		var shop_id := Catalog.shop_of(item_id)
		if shop_id == _shop_id:
			here.append(item_id)
			continue
		if not by_shop.has(shop_id):
			by_shop[shop_id] = []
			order.append(shop_id)
		(by_shop[shop_id] as Array).append(item_id)
	var paints_here: Array[Dictionary] = []
	if _shop_id == "paint":
		paints_here = paints

	var spend_here := 0
	if here.is_empty() and paints_here.is_empty():
		_brief_body.add_child(UIKit.wrapped_label(
			"Nothing on the list is sold here.", SHEET_TEXT, UIKit.MUTED))
	else:
		_brief_body.add_child(UIKit.section_label("On this floor — tap to be shown it"))
		for item_id in here:
			var count := int(missing[item_id])
			spend_here += Game.buy_price(item_id) * count
			_brief_body.add_child(_brief_row(
				"%d × %s" % [count, Catalog.display_name(item_id)],
				_price_text(item_id, count), _price_tone(item_id, count),
				func() -> void: walk_to_requested.emit(item_id)))
		for paint: Dictionary in paints_here:
			var entry: Dictionary = paint["entry"]
			var surface := str(paint["surface"])
			spend_here += Game.paint_price(entry)
			_brief_body.add_child(_brief_row(
				"%s — %s" % ["Floor" if surface == "floor" else "Wall", entry["name"]],
				UIKit.money(Game.paint_price(entry)),
				UIKit.GOLD if Game.can_afford(Game.paint_price(entry)) else UIKit.BAD,
				func() -> void: walk_to_paint_requested.emit(surface, entry)))
		_brief_total("Here", spend_here)

	# Everything else, so the player knows whether this is the last stop or the
	# first of four. Not tappable: it is somewhere else.
	if not order.is_empty() or (not paints.is_empty() and paints_here.is_empty()):
		_brief_divider()
		_brief_body.add_child(UIKit.section_label("The rest of the round"))
		for shop_id in order:
			_brief_body.add_child(UIKit.label(
				"  %s" % Catalog.shop_name(shop_id), 15, UIKit.ACCENT))
			for item_id: String in by_shop[shop_id]:
				var count := int(missing[item_id])
				_brief_body.add_child(_brief_row(
					"    %d × %s" % [count, Catalog.display_name(item_id)],
					_price_text(item_id, count), _price_tone(item_id, count), Callable()))
		if not paints.is_empty() and paints_here.is_empty():
			_brief_body.add_child(UIKit.label("  %s" % Catalog.shop_name("paint"), 15, UIKit.ACCENT))
			for paint: Dictionary in paints:
				var entry: Dictionary = paint["entry"]
				_brief_body.add_child(_brief_row("    %s — %s" % [
					"Floor" if str(paint["surface"]) == "floor" else "Wall", entry["name"]],
					UIKit.money(Game.paint_price(entry)), UIKit.GOLD, Callable()))

	var total := Jobs.list_cost(missing)
	for paint: Dictionary in paints:
		total += Game.paint_price(paint["entry"])
	if total != spend_here:
		_brief_total("The whole list", total)


func _price_text(item_id: String, count: int) -> String:
	if not Game.is_item_unlocked(item_id):
		return "Level %d" % Catalog.effective_unlock_level(item_id)
	return UIKit.money(Game.buy_price(item_id) * count)


func _price_tone(item_id: String, count: int) -> Color:
	if not Game.is_item_unlocked(item_id):
		return UIKit.BAD
	return UIKit.GOLD if Game.can_afford(Game.buy_price(item_id) * count) else UIKit.BAD


## One line of the list. Where the piece is on this floor the whole line is a
## button that walks the camera over to it and puts its card up — the buying
## itself still happens on the piece, the way everything else in a shop does.
func _brief_row(text: String, right: String, tone: Color, walk_to: Callable) -> Control:
	if not walk_to.is_valid():
		var row := HBoxContainer.new()
		var name_label := UIKit.label(text, 16, UIKit.MUTED)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(UIKit.label(right, 16, tone))
		return row

	var button := UIKit.make_button(text)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(walk_to)

	var price := UIKit.label(right, 16, tone)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	price.offset_left = -128
	price.offset_right = -14
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(price)
	return button


func _brief_total(left: String, amount: int) -> void:
	var row := HBoxContainer.new()
	row.add_child(UIKit.label(left, 16, UIKit.MUTED))
	row.add_child(UIKit.spacer())
	row.add_child(UIKit.label(UIKit.money(amount), 17,
		UIKit.GOLD if Game.can_afford(amount) else UIKit.BAD))
	_brief_body.add_child(row)


func _brief_divider() -> void:
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.08)
	line.custom_minimum_size = Vector2(0, 1)
	_brief_body.add_child(line)


func close_card() -> void:
	_shown_item = ""
	_shown_paint = {}
	_shown_surface = ""
	_shown_supply = ""
	_card.visible = false


func _row(left: String, right: String, tone: Color) -> void:
	var row := HBoxContainer.new()
	row.add_child(UIKit.label(left, 18, UIKit.MUTED))
	row.add_child(UIKit.spacer())
	row.add_child(UIKit.label(right, 18, tone))
	_card_body.add_child(row)


func _clear_card() -> void:
	for child in _card_body.get_children():
		_card_body.remove_child(child)
		child.queue_free()


## True when a point is over a panel, so gestures that start there do not also
## orbit the shop behind it.
func is_point_over_ui(point: Vector2) -> bool:
	for panel in _blockers:
		if panel.visible and panel.get_global_rect().has_point(point):
			return true
	return false
