class_name EstateUI
extends CanvasLayer
## The overlay on the map out of town: what is in the yard along the top, and a
## sheet for whichever plot was tapped.
##
## A holding offers to be bought, worked up and carted off; a works offers to be
## built up and to put a run on; the bench lists the furniture you own and what
## it would take to improve each piece.

signal leave_requested()
signal buy_site(site_id: String)
signal buy_works(works_id: String)
signal run_works(works_id: String)
signal collect_site(site_id: String)
signal collect_batch(works_id: String)
signal improve_item(item_id: String)

var _root: Control
var _blockers: Array[Control] = []
var _yard: HBoxContainer
var _money_label: Label
var _hint: Label
var _sheet: PanelContainer
var _sheet_title: Label
var _sheet_subtitle: Label
var _sheet_body: VBoxContainer
var _sheet_actions: HBoxContainer
var _toast: Label
var _toast_timer: Timer

var _tick := 0.0
## What the sheet is showing, so a purchase can redraw it in place.
var _showing: Dictionary = {}


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.name = "EstateUIRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIKit.build_theme()
	add_child(_root)

	_build_top_bar()
	_build_sheet()
	_build_hint()

	set_process(true)
	Game.money_changed.connect(func(_amount: int) -> void: refresh())
	Game.estate_changed.connect(func() -> void:
		refresh()
		_redraw())
	refresh()


## The estate runs on the wall clock, so the screen has to keep asking it what
## time it is: holdings fill while you are stood there and runs come off the
## line. Twice a second is plenty and costs nothing.
func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	var moved := Game.settle_estate()
	if moved or _watching_a_clock():
		refresh()
		_redraw()


## True when what is on the sheet is counting down and has to be redrawn.
func _watching_a_clock() -> bool:
	if _showing.is_empty() or not _sheet.visible:
		return false
	if str(_showing.get("kind", "")) == "works":
		return Game.batch_left(str(_showing["id"])) >= 0.0
	return str(_showing.get("kind", "")) == "site"


func configure() -> void:
	_hint.text = "Holdings fill on their own clock, open or not. Cart one off, run it through a works, then take it to the bench."
	refresh()


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

	_yard = HBoxContainer.new()
	_yard.add_theme_constant_override("separation", 10)
	row.add_child(_yard)

	row.add_child(UIKit.spacer())

	var leave := UIKit.make_primary_button("Back to the map")
	leave.pressed.connect(func() -> void: leave_requested.emit())
	row.add_child(leave)


func _build_sheet() -> void:
	_sheet = PanelContainer.new()
	_sheet.name = "Sheet"
	_sheet.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_sheet.offset_left = -520
	_sheet.offset_right = -12
	_sheet.offset_top = 86
	_sheet.offset_bottom = -12
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet.visible = false
	# The maps are thick with floating name plates; a solid back keeps them from
	# reading through the sheet.
	_sheet.add_theme_stylebox_override("panel", UIKit.panel_box(UIKit.BG_SOLID))
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


func _build_hint() -> void:
	_hint = UIKit.label("", 18, UIKit.TEXT)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.offset_left = 16
	_hint.offset_top = -46
	_hint.offset_bottom = -16
	_hint.offset_right = 900
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


## The yard tally: raw materials on the fields map, finished goods at the works.
func refresh() -> void:
	_money_label.text = UIKit.money(Game.money)
	for child in _yard.get_children():
		_yard.remove_child(child)
		child.queue_free()

	# Both halves of the estate are on one map now, so both halves of what it
	# holds are on one tally: what came out of the ground, then what was made
	# from it.
	for entry: Dictionary in Industry.materials() + Industry.goods():
		var id := str(entry["id"])
		var raw := Industry.get_material(id).has("unit")
		var held: int = Game.material_count(id) if raw else Game.good_count(id)
		var cap: int = Game.material_cap(id) if raw else Game.good_cap(id)
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 5)
		var chip := ColorRect.new()
		chip.color = entry["color"]
		chip.custom_minimum_size = Vector2(12, 22)
		chip.tooltip_text = str(entry["name"])
		cell.add_child(chip)
		# The cap is the whole point of a store, so it is on the tally: a yard
		# that is full stops taking anything in.
		var tone: Color = UIKit.TEXT
		if held >= cap:
			tone = UIKit.BAD
		elif held <= 0:
			tone = UIKit.MUTED
		var count := UIKit.label("%d/%d" % [held, cap], 16, tone)
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(count)
		_yard.add_child(cell)


func _redraw() -> void:
	if _showing.is_empty() or not _sheet.visible:
		return
	var showing := _showing.duplicate()
	show_plot(str(showing["kind"]), str(showing["id"]))


func close_sheet() -> void:
	if _sheet.visible:
		Audio.play("close")
	_sheet.visible = false
	_showing = {}


func is_sheet_open() -> bool:
	return _sheet.visible


func show_plot(plot_kind: String, id: String) -> void:
	match plot_kind:
		"site":
			_show_site(id)
		"works":
			_show_works(id)
		"bench":
			_show_bench()
	_showing = {"kind": plot_kind, "id": id}


func _begin(title: String, subtitle: String) -> void:
	if not _sheet.visible:
		Audio.play("open")
	_sheet.visible = true
	_sheet_title.text = title
	_sheet_subtitle.text = subtitle
	for holder in [_sheet_body, _sheet_actions]:
		for child in (holder as Node).get_children():
			(holder as Node).remove_child(child)
			child.queue_free()

	var close := UIKit.make_button("Close")
	close.pressed.connect(close_sheet)
	_sheet_actions.add_child(close)


func _row(left: String, right: String, tone: Color = UIKit.TEXT) -> void:
	var row := HBoxContainer.new()
	row.add_child(UIKit.label(left, 18, UIKit.MUTED))
	row.add_child(UIKit.spacer())
	row.add_child(UIKit.label(right, 18, tone))
	_sheet_body.add_child(row)


# ----------------------------------------------------------------- a holding

func _show_site(id: String) -> void:
	var site: Dictionary = Industry.get_site(id)
	if site.is_empty():
		return
	var tier := Game.site_tier(id)
	var material := str(site["yields"])

	_begin(str(site["name"]), str(site["blurb"]))
	_row("Yields", Industry.material_name(material))
	var unit := str(Industry.get_material(material)["unit"])
	if tier > 0:
		_row("Comes up at", "%d %s an hour" % [
			int(Industry.yield_per_hour(site, tier)), unit], UIKit.GOOD)
		var waiting := Game.waiting_at(id)
		var hold := Industry.hold_cap(site, tier)
		_row("Standing on the ground", "%d of %d" % [waiting, hold],
			UIKit.GOLD if waiting >= hold else UIKit.TEXT)
		_bar(Game.fullness_at(id), Industry.get_material(material)["color"])
		if waiting >= hold:
			_sheet_body.add_child(UIKit.wrapped_label(
				"Full, and nothing more will come up until it is carted off.",
				420, UIKit.BAD))
		_row("Worked up to", "%d of %d" % [tier, Industry.MAX_TIER])

		var room: int = maxi(Game.material_cap(material) - Game.material_count(material), 0)
		var cart := UIKit.make_primary_button(
			"Cart it off  (%d)" % mini(waiting, room) if waiting > 0 and room > 0
			else ("The yard is full" if waiting > 0 else "Nothing to cart yet"))
		cart.disabled = waiting <= 0 or room <= 0
		cart.pressed.connect(func() -> void: collect_site.emit(id))
		_sheet_actions.add_child(cart)
	else:
		_row("Would come up at", "%d %s an hour" % [int(site["per_job"]), unit])
		_row("And hold", "%d before it stops" % Industry.hold_cap(site, 1))

	if tier >= Industry.MAX_TIER:
		_sheet_body.add_child(UIKit.wrapped_label(
			"Worked as hard as this ground will take.", 420, UIKit.GOOD))
		return

	var price := Game.step_price(int(site["cost"]), tier)
	var needed := int(site["level"])
	_row("Price", UIKit.money(price), UIKit.GOLD if Game.can_afford(price) else UIKit.BAD)
	if Game.level < needed:
		_sheet_body.add_child(UIKit.wrapped_label(
			"The agent will not deal below level %d." % needed, 420, UIKit.BAD))
		return

	var buy := UIKit.make_primary_button(
		("Buy the land  %s" if tier == 0 else "Work it up  %s") % UIKit.money(price))
	buy.disabled = not Game.can_afford(price)
	buy.pressed.connect(func() -> void: buy_site.emit(id))
	_sheet_actions.add_child(buy)


# ------------------------------------------------------------------- a works

func _show_works(id: String) -> void:
	var works: Dictionary = Industry.get_works(id)
	if works.is_empty():
		return
	var tier := Game.works_tier(id)
	var good: Dictionary = Industry.get_good(str(works["makes"]))
	var material := str(good["from"])
	var takes := int(good["takes"])

	var made := str(good["id"])
	_begin(str(works["name"]), str(works["blurb"]))
	_row("Makes", str(good["name"]))
	_row("Out of", "%d %s a piece" % [takes, Industry.material_name(material)])
	_row("In the yard", "%d %s" % [Game.material_count(material), Industry.material_name(material)],
		UIKit.GOOD if Game.material_count(material) >= takes else UIKit.MUTED)
	_row("In the store", "%d of %d" % [Game.good_count(made), Game.good_cap(made)],
		UIKit.BAD if Game.good_count(made) >= Game.good_cap(made) else UIKit.GOOD)

	if tier > 0:
		_row("A run", "%d at a time, %s" % [tier,
			Game.spell_out(Industry.batch_seconds(id))])
		if Game.batch_ready(id):
			_row("Off the line", "%d waiting" % Game.batch_size(id), UIKit.GOLD)
			var take := UIKit.make_primary_button("Take it off  (%d)" % Game.batch_size(id))
			take.pressed.connect(func() -> void: collect_batch.emit(id))
			_sheet_actions.add_child(take)
		elif Game.batch_left(id) > 0.0:
			_row("Running", "%d, ready in %s" % [
				Game.batch_size(id), Game.spell_out(Game.batch_left(id))], UIKit.TEXT)
			_bar(1.0 - Game.batch_left(id) / maxf(Industry.batch_seconds(id), 1.0),
				good.get("color", UIKit.ACCENT))
			var waiting := UIKit.make_button("On the line")
			waiting.disabled = true
			_sheet_actions.add_child(waiting)
		else:
			var possible := Game.batches_available(id)
			var why := "Nothing to run"
			if Game.good_count(made) >= Game.good_cap(made):
				why = "The store is full"
			var run := UIKit.make_primary_button(
				"Put a run on  (%d)" % possible if possible > 0 else why)
			run.disabled = possible <= 0
			run.pressed.connect(func() -> void: run_works.emit(id))
			_sheet_actions.add_child(run)

	if tier >= Industry.MAX_TIER:
		_sheet_body.add_child(UIKit.wrapped_label(
			"Running as hard as the building will stand.", 420, UIKit.GOOD))
		return

	var price := Game.step_price(int(works["cost"]), tier)
	var needed := int(works["level"])
	_divider()
	_row("Price", UIKit.money(price), UIKit.GOLD if Game.can_afford(price) else UIKit.BAD)
	if Game.level < needed:
		_sheet_body.add_child(UIKit.wrapped_label(
			"Nobody will sign off a plant like this below level %d." % needed, 420, UIKit.BAD))
		return

	var build := UIKit.make_button(
		("Build it  %s" if tier == 0 else "Build it up  %s") % UIKit.money(price))
	build.disabled = not Game.can_afford(price)
	build.pressed.connect(func() -> void: buy_works.emit(id))
	_sheet_actions.add_child(build)


# ------------------------------------------------------------------ the bench

## Everything you own that could be improved, and what it would take. Pieces
## already at the top are listed last so the work to do is at the front.
func _show_bench() -> void:
	_begin(str(Industry.BENCH["name"]), str(Industry.BENCH["blurb"]))

	var owned := Game.owned_item_ids()
	if owned.is_empty():
		_sheet_body.add_child(UIKit.wrapped_label(
			"Nothing in stock to work on. Buy furniture at the shops first — the "
			+ "bench improves the pattern, so every piece of that kind you own "
			+ "or buy later comes off it improved.", 420, UIKit.TEXT))
		return

	_sheet_body.add_child(UIKit.wrapped_label(
		"Improving a piece lifts every one of that kind you own. A room of "
		+ "improved furniture pays more and teaches you more.", 420))
	_divider()

	var sorted := owned.duplicate()
	sorted.sort_custom(func(a: String, b: String) -> bool:
		var left := Game.quality_of(a)
		var right := Game.quality_of(b)
		if left != right:
			return left < right
		return Catalog.price(a) > Catalog.price(b))

	var first := true
	for item_id: String in sorted:
		if not first:
			_divider()
		first = false
		_sheet_body.add_child(_bench_row(item_id))


## Two lines a piece: what it is and how many you hold, then what the next step
## up would take. The button sits on its own line so a long name can never push
## the sheet wider than the screen.
func _bench_row(item_id: String) -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 1)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tier := Game.quality_of(item_id)

	var head := HBoxContainer.new()
	var title := UIKit.label(Catalog.display_name(item_id), 17)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(title)
	head.add_child(UIKit.label(
		"%s  ·  ×%d" % [Industry.tier_name(tier), Game.stock_of(item_id)], 14,
		UIKit.GOOD if tier > 0 else UIKit.MUTED))
	block.add_child(head)

	var foot := HBoxContainer.new()
	var cost: Dictionary = Industry.upgrade_cost(item_id)
	if cost.is_empty():
		foot.add_child(UIKit.label("As fine as this pattern goes.", 15, UIKit.GOOD))
		block.add_child(foot)
		return block

	var good := str(cost["good"])
	var have := Game.good_count(good)
	var want := int(cost["goods"])
	var enough := have >= want and Game.can_afford(int(cost["money"]))

	var need := UIKit.label("%d/%d %s" % [have, want, Industry.good_name(good)], 15,
		UIKit.GOOD if have >= want else UIKit.BAD)
	need.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(need)
	foot.add_child(UIKit.spacer())

	var button := UIKit.make_button("%s  %s" % [cost["name"], UIKit.money(int(cost["money"]))])
	button.disabled = not enough
	button.pressed.connect(func() -> void: improve_item.emit(item_id))
	foot.add_child(button)
	block.add_child(foot)
	return block


## A filling bar, for a holding that is filling and a run that is running.
func _bar(fraction: float, tone: Color) -> void:
	var track := PanelContainer.new()
	track.custom_minimum_size = Vector2(0, 10)
	track.add_theme_stylebox_override("panel", UIKit.panel_box(Color(1, 1, 1, 0.10), 5))
	var fill := ColorRect.new()
	fill.color = tone
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.custom_minimum_size = Vector2(0, 6)
	var row := HBoxContainer.new()
	row.add_child(fill)
	var rest := Control.new()
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rest)
	fill.size_flags_stretch_ratio = maxf(clampf(fraction, 0.0, 1.0), 0.001)
	rest.size_flags_stretch_ratio = maxf(1.0 - clampf(fraction, 0.0, 1.0), 0.001)
	track.add_child(row)
	_sheet_body.add_child(track)


func _divider() -> void:
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.10)
	line.custom_minimum_size = Vector2(0, 1)
	_sheet_body.add_child(line)


func is_point_over_ui(point: Vector2) -> bool:
	for panel in _blockers:
		if panel.visible and panel.get_global_rect().has_point(point):
			return true
	return false
