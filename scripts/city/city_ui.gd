class_name CityUI
extends CanvasLayer
## Overlay for the city map: the player's wallet and level, the briefing sheet
## for a house, and the window of whichever shop they tapped.

signal start_job(house_id: String)
signal free_build()
signal career_reset()

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
var _modal: Control
var _modal_body: VBoxContainer


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
	refresh_hud()


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

	var sandbox := UIKit.make_button("Free Build", "Design a room with no client and no bill")
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
	_jobs_label.text = "   %d of %d jobs done" % [Game.jobs_done(), Jobs.all().size()]


func _build_hint() -> void:
	_hint = UIKit.label("Tap a house to see what the client wants. Tap a shop to browse its stock.", 18, UIKit.TEXT)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.offset_left = 16
	_hint.offset_top = -46
	_hint.offset_bottom = -16
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hint.add_theme_constant_override("outline_size", 6)
	_root.add_child(_hint)


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

	var done: bool = Game.is_job_done(house_id)
	var locked: bool = Game.level < int(job["level"])
	var in_progress: bool = not Game.layout_for(house_id).is_empty()

	_begin_sheet(str(job["name"]), "%s  ·  needs level %d" % [job["client"], job["level"]])

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

	var room: Dictionary = job["room"]
	_sheet_row("Room", "%.1f × %.1f m  (%.0f m²)" % [room["w"], room["d"], float(room["w"]) * float(room["d"])])
	_sheet_row("Fee", UIKit.money(int(job["payout"])), UIKit.GOLD)
	_sheet_row("On-budget bonus", "+%s" % UIKit.money(Jobs.bonus_for(house_id)), UIKit.GOLD)
	_sheet_row("Client budget", UIKit.money(int(job["budget"])))
	_sheet_row("Required pieces cost about", UIKit.money(Jobs.minimum_outlay(house_id)))
	_sheet_row("Experience", "+%d XP" % int(job["xp"]))
	if in_progress and not done:
		_sheet_row("Already spent here", UIKit.money(Game.spend_on(house_id)), UIKit.GOLD)
	_divider()

	_sheet_body.add_child(UIKit.section_label("The brief"))
	for result: Dictionary in Jobs.evaluate(house_id, {"items": [], "room": {}, "spend": 0}):
		var bullet := UIKit.label("•  %s" % result["label"], 17, UIKit.TEXT)
		bullet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bullet.custom_minimum_size = Vector2(440, 0)
		_sheet_body.add_child(bullet)

	if done:
		_divider()
		var record: Dictionary = Game.finished_jobs[house_id]
		_sheet_body.add_child(UIKit.label(
			"Earned %s and %d XP." % [UIKit.money(int(record["payout"]) + int(record["bonus"])), record["xp"]],
			18, UIKit.GOOD))

	var close := UIKit.make_button("Close")
	close.pressed.connect(close_sheet)
	_sheet_actions.add_child(close)

	var action_label := "Start job"
	if done:
		action_label = "Redesign"
	elif in_progress:
		action_label = "Continue"
	var action := UIKit.make_primary_button(action_label)
	action.disabled = locked
	action.pressed.connect(func() -> void:
		close_sheet()
		start_job.emit(house_id))
	_sheet_actions.add_child(action)


# ---------------------------------------------------------------- shop sheet

func show_shop(shop_id: String) -> void:
	var shop: Dictionary = Catalog.get_shop(shop_id)
	if shop.is_empty():
		return

	var unlocked := Game.is_shop_unlocked(shop_id)
	_begin_sheet(str(shop["name"]), str(shop["tagline"]))

	if not unlocked:
		_sheet_body.add_child(UIKit.label(
			"Opens at level %d." % int(shop["level"]), 18, UIKit.BAD))
		_divider()

	if shop_id == "paint":
		_build_paint_stock()
	else:
		_build_item_stock(shop_id)

	var close := UIKit.make_button("Close")
	close.pressed.connect(close_sheet)
	_sheet_actions.add_child(close)


func _build_item_stock(shop_id: String) -> void:
	_sheet_body.add_child(UIKit.section_label("Stock"))
	for item_id in Catalog.shop_stock(shop_id):
		var row := HBoxContainer.new()
		var available: bool = Game.is_item_unlocked(item_id)

		var chip := ColorRect.new()
		chip.color = Catalog.default_tint(item_id) if available else Color(0.35, 0.36, 0.40)
		chip.custom_minimum_size = Vector2(10, 34)
		row.add_child(chip)

		var name_label := UIKit.label(Catalog.display_name(item_id), 18, UIKit.TEXT if available else UIKit.MUTED)
		name_label.custom_minimum_size = Vector2(200, 0)
		row.add_child(name_label)

		var footprint := Catalog.footprint(item_id)
		row.add_child(UIKit.label("%.2f × %.2f m" % [footprint.x, footprint.y], 15, UIKit.MUTED))
		row.add_child(UIKit.spacer())

		if available:
			row.add_child(UIKit.label(UIKit.money(Catalog.price(item_id)), 18, UIKit.GOLD))
		else:
			row.add_child(UIKit.label("Level %d" % Catalog.effective_unlock_level(item_id), 17, UIKit.BAD))
		_sheet_body.add_child(row)

	_divider()
	_sheet_body.add_child(UIKit.wrapped_label(
		"Buy from the tray while you are working on a house. Anything you take out again is refunded in full.",
		440))


func _build_paint_stock() -> void:
	for surface: String in ["floor", "wall"]:
		_sheet_body.add_child(UIKit.section_label(
			"%s  ·  %s per m²" % [
				"Floors" if surface == "floor" else "Walls",
				UIKit.money(Catalog.FLOOR_PAINT_RATE if surface == "floor" else Catalog.WALL_PAINT_RATE),
			]))
		var grid := GridContainer.new()
		grid.columns = 4
		for entry: Dictionary in Catalog.PAINT[surface]:
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 2)
			var unlocked: bool = Game.is_paint_unlocked(entry)
			var swatch := UIKit.swatch_button(entry["color"] if unlocked else Color(0.30, 0.31, 0.35), Vector2(96, 40))
			swatch.disabled = true
			cell.add_child(swatch)
			cell.add_child(UIKit.label(str(entry["name"]), 15, UIKit.TEXT if unlocked else UIKit.MUTED))
			if not unlocked:
				cell.add_child(UIKit.label("Level %d" % int(entry["level"]), 13, UIKit.BAD))
			grid.add_child(cell)
		_sheet_body.add_child(grid)
	_divider()
	_sheet_body.add_child(UIKit.wrapped_label(
		"Repainting is charged on the room's floor area, so a bigger job costs more. Pick colours from the Room panel while you work.",
		440))


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
		["Spend to earn", "Furniture comes out of your own pocket while you work. Take a piece out again and the shop refunds it in full, so nothing is ever wasted."],
		["Hand it over", "Once every line of the brief is ticked, hand the room over. You collect the fee, plus a quarter of it again if the bill came in under the client's budget."],
		["Grow", "Every finished job pays experience. New levels open the pricier shops, the better paints and the larger, more demanding houses."],
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
