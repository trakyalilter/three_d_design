class_name EstateUI
extends CanvasLayer
## The overlay on the two estate maps: what is in the yard along the top, and a
## sheet for whichever plot was tapped.
##
## One panel serves both maps. A holding offers to be bought or worked up; a
## works offers to be built up and to run a batch; the bench lists the furniture
## you own and what it would take to improve each piece.

signal leave_requested()
signal buy_site(site_id: String)
signal buy_works(works_id: String)
signal run_works(works_id: String)
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

var _fields := true
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

	Game.money_changed.connect(func(_amount: int) -> void: refresh())
	Game.estate_changed.connect(func() -> void:
		refresh()
		_redraw())
	refresh()


func configure(fields: bool) -> void:
	_fields = fields
	_hint.text = "Tap a holding to buy it or work it up. Everything you own yields when a job is handed over." \
		if fields \
		else "Tap a works to build it or run a batch, or the bench to improve what you own."
	# The tally is materials on the fields and finished goods at the works, so it
	# has to be redrawn whenever the map changes under it.
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
	_yard.add_theme_constant_override("separation", 14)
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

	var entries: Array = Industry.materials() if _fields else Industry.goods()
	for entry: Dictionary in entries:
		var id := str(entry["id"])
		var held: int = Game.material_count(id) if _fields else Game.good_count(id)
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 5)
		var chip := ColorRect.new()
		chip.color = entry["color"]
		chip.custom_minimum_size = Vector2(12, 22)
		chip.tooltip_text = str(entry["name"])
		cell.add_child(chip)
		var count := UIKit.label(str(held), 18, UIKit.TEXT if held > 0 else UIKit.MUTED)
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
	if tier > 0:
		_row("Every job hands you", "%d %s" % [
			int(site["per_job"]) * tier, Industry.get_material(material)["unit"]], UIKit.GOOD)
		_row("Worked up to", "%d of %d" % [tier, Industry.MAX_TIER])
	else:
		_row("Would hand you", "%d %s a job" % [
			int(site["per_job"]), Industry.get_material(material)["unit"]])

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

	_begin(str(works["name"]), str(works["blurb"]))
	_row("Makes", str(good["name"]))
	_row("Out of", "%d %s a piece" % [takes, Industry.material_name(material)])
	_row("In the yard", "%d %s" % [Game.material_count(material), Industry.material_name(material)],
		UIKit.GOOD if Game.material_count(material) >= takes else UIKit.MUTED)
	_row("Made and waiting", str(Game.good_count(str(good["id"]))), UIKit.GOOD)

	if tier > 0:
		_row("Batch", "%d a run" % tier)
		var possible: int = mini(tier, Game.material_count(material) / maxi(takes, 1))
		var run := UIKit.make_primary_button(
			"Run a batch  (+%d)" % possible if possible > 0 else "Nothing to run")
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
