class_name ShopUI
extends CanvasLayer
## The overlay inside a shop: the wallet along the top, and a card for whatever
## the player has just tapped on the floor.
##
## The card is the whole of the buying interface. Nothing is bought from a list
## here — you pick a piece up off the shop floor and this tells you what it is,
## what it costs and how many you already have.

signal leave_requested()
signal buy_requested(item_id: String)
signal sell_requested(item_id: String)
signal buy_paint_requested(surface: String, entry: Dictionary)
signal buy_supply_requested(supply_id: String, count: int)
signal sell_supply_requested(supply_id: String, count: int)

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

	Game.money_changed.connect(func(_amount: int) -> void: refresh())
	Game.stock_changed.connect(func() -> void: refresh())
	refresh()


func configure(shop: Dictionary) -> void:
	_hint.text = "Tap a piece to see what it costs. %s" % shop.get("tagline", "")


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
