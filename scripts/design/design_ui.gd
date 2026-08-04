class_name DesignerUI
extends CanvasLayer
## Interface for the room designer, built entirely in code.
##
## It runs in two modes. On a job it shows the client's brief, the running bill
## and the hand-over button; in free build it drops the money entirely and
## offers the save and load tools instead.

signal place_item(item_id: String)
signal command(name: String)
signal tint_selected(color: Color)
signal room_changed(width: float, room_depth: float, height: float)
signal floor_paint_selected(color: Color)
signal wall_paint_selected(color: Color)
signal paint_target_changed(room_id: String)
signal walls_toggled(enabled: bool)
signal snap_toggled(enabled: bool)
signal top_view_toggled(enabled: bool)
signal save_requested(layout_name: String)
signal load_requested(layout_name: String)
signal delete_layout_requested(layout_name: String)
signal new_requested()
signal recenter_requested()
signal finish_requested()
signal leave_requested()

var job_mode := false

var _job: Dictionary = {}
var _root: Control
var _blockers: Array[Control] = []
var _modal_layer: Control
var _dialog_holder: VBoxContainer
var _dialog_scroll: ScrollContainer
var _dialog_body: VBoxContainer

var _money_label: Label
var _job_label: Label
var _bill_label: Label
var _stats_label: Label
var _brief_button: Button
var _finish_button: Button
var _free_buttons: Array[Button] = []

var _brief_sheet: PanelContainer
var _brief_list: VBoxContainer

var _selection_bar: PanelContainer
var _selection_label: Label
var _catalog_panel: PanelContainer
var _catalog_items: HBoxContainer
var _category_buttons: Array[Button] = []
var _item_buttons: Dictionary = {}
var _toast_label: Label
var _toast_timer: Timer
var _swatch_popup: PanelContainer

var _walls_button: Button
var _snap_button: Button
var _top_button: Button
var _undo_button: Button
var _redo_button: Button

var _room_w: HSlider
var _room_d: HSlider
var _room_h: HSlider
var _room_dims := Vector3(6.0, 2.6, 5.0)
var _save_name: LineEdit
var _layout_list: ItemList
## The rooms of a floor plan, and which of them the paint tools act on.
var _plan: Array[Dictionary] = []
var _paint_target := ""
var _emit_room_changes := false


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.name = "UIRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIKit.build_theme()
	add_child(_root)

	_build_top_bar()
	_build_view_tools()
	_build_bottom()
	_build_brief_sheet()
	_build_toast()
	_build_swatch_popup()
	_build_modal_layer()

	Game.money_changed.connect(func(_amount: int) -> void: refresh_stock())
	Game.stock_changed.connect(refresh_stock)


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

	_money_label = UIKit.label("", 21, UIKit.GOLD)
	_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_money_label)

	_job_label = UIKit.label("", 19)
	_job_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_job_label)

	_bill_label = UIKit.label("", 16, UIKit.MUTED)
	_bill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_bill_label)

	_stats_label = UIKit.label("", 16, UIKit.MUTED)
	_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_stats_label)

	row.add_child(UIKit.spacer())

	_brief_button = UIKit.make_button("Brief", "What the client asked for")
	_brief_button.pressed.connect(_toggle_brief)
	row.add_child(_brief_button)

	var room_btn := UIKit.make_button("Room", "Floor and wall colours, room by room")
	room_btn.pressed.connect(_open_room_dialog)
	row.add_child(room_btn)

	for spec in [["Save", _open_save_dialog], ["Open", _open_load_dialog], ["New", _open_new_dialog]]:
		var b := UIKit.make_button(spec[0])
		b.pressed.connect(spec[1])
		row.add_child(b)
		_free_buttons.append(b)

	var help := UIKit.make_button("Help")
	help.pressed.connect(_open_help_dialog)
	row.add_child(help)

	var leave := UIKit.make_button("Leave")
	leave.pressed.connect(_confirm_leave)
	row.add_child(leave)

	_finish_button = UIKit.make_primary_button("Hand over")
	_finish_button.pressed.connect(func() -> void: finish_requested.emit())
	row.add_child(_finish_button)


## Switches between a client job and the free-build sandbox.
func configure(job: Dictionary) -> void:
	_job = job
	job_mode = not job.is_empty()
	# Only a floor plan gets a room picker in the paint dialog.
	_plan.clear()
	for entry: Variant in job.get("rooms", []):
		if typeof(entry) == TYPE_DICTIONARY:
			_plan.append(entry as Dictionary)
	_paint_target = ""

	_job_label.visible = job_mode
	_bill_label.visible = job_mode
	_brief_button.visible = job_mode
	_finish_button.visible = job_mode
	_money_label.visible = job_mode
	for button in _free_buttons:
		button.visible = not job_mode
	_job_label.text = "   %s" % job.get("name", "") if job_mode else ""
	_brief_sheet.visible = false
	refresh_bill(0)
	refresh_stock()


func refresh_bill(installed: int) -> void:
	_money_label.text = UIKit.money(Game.money)
	if not job_mode:
		return
	var budget := int(_job.get("budget", 0))
	_bill_label.text = "   fitted %s of %s budget" % [UIKit.money(installed), UIKit.money(budget)]
	_bill_label.add_theme_color_override(
		"font_color", UIKit.MUTED if installed <= budget else UIKit.BAD)


func set_stats(item_count: int, floor_area: float) -> void:
	_stats_label.text = "   %d item%s · %.1f m²" % [
		item_count, "" if item_count == 1 else "s", floor_area,
	]


# ---------------------------------------------------------------- view tools

func _build_view_tools() -> void:
	var panel := PanelContainer.new()
	panel.name = "ViewTools"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 10
	panel.offset_top = 78
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(panel)
	_blockers.append(panel)

	var col := VBoxContainer.new()
	panel.add_child(col)

	_top_button = UIKit.make_button("Top View", "Switch between 3D and plan view")
	_top_button.toggle_mode = true
	_top_button.toggled.connect(func(on: bool) -> void: top_view_toggled.emit(on))
	col.add_child(_top_button)

	_walls_button = UIKit.make_button("Walls: On")
	_walls_button.toggle_mode = true
	_walls_button.button_pressed = true
	_walls_button.toggled.connect(func(on: bool) -> void:
		_walls_button.text = "Walls: On" if on else "Walls: Off"
		walls_toggled.emit(on))
	col.add_child(_walls_button)

	_snap_button = UIKit.make_button("Snap: On", "Snap positions to a 25 cm grid")
	_snap_button.toggle_mode = true
	_snap_button.button_pressed = true
	_snap_button.toggled.connect(func(on: bool) -> void:
		_snap_button.text = "Snap: On" if on else "Snap: Off"
		snap_toggled.emit(on))
	col.add_child(_snap_button)

	var recenter := UIKit.make_button("Recenter")
	recenter.pressed.connect(func() -> void: recenter_requested.emit())
	col.add_child(recenter)

	var history := HBoxContainer.new()
	col.add_child(history)

	_undo_button = UIKit.make_button("Undo")
	_undo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_undo_button.disabled = true
	_undo_button.pressed.connect(func() -> void: command.emit("undo"))
	history.add_child(_undo_button)

	_redo_button = UIKit.make_button("Redo")
	_redo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_redo_button.disabled = true
	_redo_button.pressed.connect(func() -> void: command.emit("redo"))
	history.add_child(_redo_button)


func set_history_available(can_undo: bool, can_redo: bool) -> void:
	if _undo_button:
		_undo_button.disabled = not can_undo
	if _redo_button:
		_redo_button.disabled = not can_redo


# ------------------------------------------------------------- bottom panels

func _build_bottom() -> void:
	var column := VBoxContainer.new()
	column.name = "BottomColumn"
	column.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	column.offset_left = 10
	column.offset_right = -10
	column.offset_bottom = -10
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(column)

	_build_selection_bar(column)
	_build_catalog(column)


func _build_selection_bar(parent: Control) -> void:
	_selection_bar = PanelContainer.new()
	_selection_bar.name = "SelectionBar"
	_selection_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_selection_bar.visible = false
	parent.add_child(_selection_bar)
	_blockers.append(_selection_bar)

	var row := HBoxContainer.new()
	_selection_bar.add_child(row)

	_selection_label = UIKit.label("-", 18)
	_selection_label.custom_minimum_size = Vector2(250, 0)
	_selection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_selection_label)
	row.add_child(UIKit.spacer())

	for spec in [
		["Rotate -", "rotate_left"],
		["Rotate +", "rotate_right"],
		["Flip", "rotate_flip"],
		["Smaller", "scale_down"],
		["Bigger", "scale_up"],
	]:
		var b := UIKit.make_button(spec[0])
		b.pressed.connect(func() -> void: command.emit(spec[1]))
		row.add_child(b)

	var color_btn := UIKit.make_button("Colour")
	color_btn.pressed.connect(_toggle_swatch_popup)
	row.add_child(color_btn)

	var copy_btn := UIKit.make_button("Duplicate")
	copy_btn.pressed.connect(func() -> void: command.emit("duplicate"))
	row.add_child(copy_btn)

	var del_btn := UIKit.make_button("Put back", "Return this piece to your stock")
	del_btn.add_theme_color_override("font_color", UIKit.BAD)
	del_btn.pressed.connect(func() -> void: command.emit("delete"))
	row.add_child(del_btn)

	var close_btn := UIKit.make_button("Done")
	close_btn.pressed.connect(func() -> void: command.emit("deselect"))
	row.add_child(close_btn)


func _build_catalog(parent: Control) -> void:
	_catalog_panel = PanelContainer.new()
	_catalog_panel.name = "Catalog"
	_catalog_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(_catalog_panel)
	_blockers.append(_catalog_panel)

	var col := VBoxContainer.new()
	_catalog_panel.add_child(col)

	var category_scroll := ScrollContainer.new()
	category_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	category_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	category_scroll.custom_minimum_size = Vector2(0, 52)
	col.add_child(category_scroll)

	var cats := HBoxContainer.new()
	category_scroll.add_child(cats)

	for category in Catalog.CATEGORIES:
		var b := UIKit.make_button(category)
		b.toggle_mode = true
		b.pressed.connect(_select_category.bind(category))
		cats.add_child(b)
		_category_buttons.append(b)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 96)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)

	# No expand flag: the row must be free to overflow so the scroller works.
	_catalog_items = HBoxContainer.new()
	scroll.add_child(_catalog_items)

	_select_category(Catalog.CATEGORIES[0])


func _select_category(category: String) -> void:
	for b in _category_buttons:
		b.button_pressed = b.text == category

	for child in _catalog_items.get_children():
		_catalog_items.remove_child(child)
		child.queue_free()
	_item_buttons.clear()

	for id in Catalog.ids_in(category):
		var button := _make_catalog_button(id)
		_catalog_items.add_child(button)
		_item_buttons[id] = button
	refresh_stock()


func _make_catalog_button(id: String) -> Button:
	var b := Button.new()
	b.text = Catalog.display_name(id)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(152, 76)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = false
	b.pressed.connect(func() -> void: place_item.emit(id))

	var strip := ColorRect.new()
	strip.name = "Strip"
	strip.color = Catalog.default_tint(id)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	strip.offset_left = 8
	strip.offset_right = -8
	strip.offset_top = 6
	strip.offset_bottom = 12
	b.add_child(strip)

	var footer := UIKit.label("", 14, UIKit.GOLD)
	footer.name = "Footer"
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -24
	footer.offset_bottom = -5
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(footer)
	return b


## Shows how many of each piece are sitting in the warehouse, and greys out
## anything that is out of stock or still locked.
func refresh_stock() -> void:
	if _money_label:
		_money_label.text = UIKit.money(Game.money)
	for item_id: String in _item_buttons:
		var button: Button = _item_buttons[item_id]
		var footer := button.get_node("Footer") as Label
		var strip := button.get_node("Strip") as ColorRect
		var footprint := Catalog.footprint(item_id)

		if not job_mode:
			button.disabled = false
			footer.text = "%.2f × %.2f m" % [footprint.x, footprint.y]
			footer.add_theme_color_override("font_color", UIKit.MUTED)
			strip.color = Catalog.default_tint(item_id)
			continue

		var stock := Game.stock_of(item_id)
		if not Game.is_item_unlocked(item_id):
			button.disabled = true
			footer.text = "Level %d" % Catalog.effective_unlock_level(item_id)
			footer.add_theme_color_override("font_color", UIKit.BAD)
			strip.color = Color(0.34, 0.35, 0.40)
		elif stock <= 0:
			button.disabled = true
			footer.text = "none in stock"
			footer.add_theme_color_override("font_color", UIKit.MUTED)
			strip.color = Catalog.default_tint(item_id).darkened(0.6)
		else:
			button.disabled = false
			footer.text = "%d in stock" % stock
			footer.add_theme_color_override("font_color", UIKit.GOOD)
			strip.color = Catalog.default_tint(item_id)


# --------------------------------------------------------------- brief sheet

func _build_brief_sheet() -> void:
	_brief_sheet = PanelContainer.new()
	_brief_sheet.name = "BriefSheet"
	_brief_sheet.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_brief_sheet.offset_left = -12
	_brief_sheet.offset_right = -12
	_brief_sheet.offset_top = 78
	_brief_sheet.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_brief_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_brief_sheet.visible = false
	_root.add_child(_brief_sheet)
	_blockers.append(_brief_sheet)

	_brief_list = VBoxContainer.new()
	_brief_sheet.add_child(_brief_list)


func _toggle_brief() -> void:
	_brief_sheet.visible = not _brief_sheet.visible


## Redraws the checklist from a fresh evaluation of the brief.
func set_requirements(results: Array[Dictionary]) -> void:
	if not job_mode:
		return
	for child in _brief_list.get_children():
		_brief_list.remove_child(child)
		child.queue_free()

	_brief_button.text = "Brief  %d/%d" % [Jobs.met_count(results), results.size()]

	_brief_list.add_child(UIKit.label(str(_job.get("name", "")), 21))
	_brief_list.add_child(UIKit.wrapped_label("“%s”" % _job.get("brief", ""), 400))

	for result: Dictionary in results:
		var row := HBoxContainer.new()
		var done: bool = result["met"]
		row.add_child(UIKit.label("✓" if done else "○", 19, UIKit.GOOD if done else UIKit.MUTED))
		var text := UIKit.label(str(result["label"]), 17, UIKit.TEXT if done else UIKit.MUTED)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(320, 0)
		row.add_child(text)
		if int(result["need"]) > 1:
			row.add_child(UIKit.spacer())
			row.add_child(UIKit.label("%d/%d" % [result["have"], result["need"]], 16, UIKit.MUTED))
		_brief_list.add_child(row)

	_finish_button.disabled = not Jobs.all_met(results)
	_finish_button.tooltip_text = "" if not _finish_button.disabled \
		else "Tick every line of the brief first"


# ----------------------------------------------------------- colour swatches

func _build_swatch_popup() -> void:
	_swatch_popup = PanelContainer.new()
	_swatch_popup.name = "Swatches"
	_swatch_popup.visible = false
	_swatch_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_swatch_popup.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_swatch_popup.offset_top = -270
	_swatch_popup.offset_bottom = -270
	_swatch_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_swatch_popup.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(_swatch_popup)
	_blockers.append(_swatch_popup)

	var grid := GridContainer.new()
	grid.columns = 6
	_swatch_popup.add_child(grid)
	for color in Catalog.SWATCHES:
		var b := UIKit.swatch_button(color)
		b.pressed.connect(func() -> void:
			tint_selected.emit(color)
			_swatch_popup.visible = false)
		grid.add_child(b)


func _toggle_swatch_popup() -> void:
	_swatch_popup.visible = not _swatch_popup.visible


# ---------------------------------------------------------------- toast text

func _build_toast() -> void:
	_toast_label = UIKit.label("", 19, Color.WHITE)
	_toast_label.name = "Toast"
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_top = 84
	_toast_label.offset_bottom = 84
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_toast_label.add_theme_constant_override("outline_size", 6)
	_toast_label.visible = false
	_root.add_child(_toast_label)

	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.timeout.connect(func() -> void: _toast_label.visible = false)
	add_child(_toast_timer)


func toast(text: String, seconds: float = 2.0) -> void:
	_toast_label.text = text
	_toast_label.visible = true
	_toast_timer.start(seconds)


# ------------------------------------------------------------------- dialogs

func _build_modal_layer() -> void:
	_modal_layer = Control.new()
	_modal_layer.name = "Modal"
	_modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_layer.visible = false
	_root.add_child(_modal_layer)
	_blockers.append(_modal_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	center.add_child(panel)

	_dialog_holder = VBoxContainer.new()
	panel.add_child(_dialog_holder)


func is_modal_open() -> bool:
	return _modal_layer != null and _modal_layer.visible


func close_dialog() -> void:
	_modal_layer.visible = false
	_dialog_scroll = null
	_dialog_body = null
	for child in _dialog_holder.get_children():
		_dialog_holder.remove_child(child)
		child.queue_free()


func _begin_dialog(title: String) -> VBoxContainer:
	close_dialog()
	_modal_layer.visible = true
	_dialog_holder.add_child(UIKit.label(title, 24))

	_dialog_scroll = ScrollContainer.new()
	_dialog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dialog_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_dialog_holder.add_child(_dialog_scroll)

	_dialog_body = VBoxContainer.new()
	_dialog_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialog_scroll.add_child(_dialog_body)
	return _dialog_body


## Adds the closing button row and caps the dialog height so tall content
## scrolls instead of running off the top and bottom of the screen.
func _dialog_buttons(labels: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	_dialog_holder.add_child(row)
	for label: String in labels:
		row.add_child(UIKit.make_button(label))

	if _dialog_scroll and _dialog_body:
		var available: float = maxf(_root.size.y - 220.0, 180.0)
		var wanted: float = _dialog_body.get_combined_minimum_size().y
		_dialog_scroll.custom_minimum_size.y = minf(wanted, available)
	return row


func _open_room_dialog() -> void:
	var body := _begin_dialog("Room")
	_emit_room_changes = false

	if not _plan.is_empty():
		body.add_child(UIKit.wrapped_label(
			"This job is %d rooms. Pick which one you are painting — or all of them at once."
				% _plan.size(), 520))
		_paint_target_row(body)
	elif job_mode:
		body.add_child(UIKit.wrapped_label(
			"The client's room is %.1f × %.1f m — you can change the colours, not the walls."
				% [_room_dims.x, _room_dims.z], 520))
	else:
		_room_w = _slider_row(body, "Width", 2.0, 14.0, 0.25, _room_dims.x)
		_room_d = _slider_row(body, "Depth", 2.0, 14.0, 0.25, _room_dims.z)
		_room_h = _slider_row(body, "Height", 2.2, 3.6, 0.1, _room_dims.y)

	_paint_section(body, "floor")
	_paint_section(body, "wall")
	if job_mode:
		body.add_child(UIKit.wrapped_label(
			"Only colours you have bought at the Colour House can be used here.", 520))

	_emit_room_changes = true
	var row := _dialog_buttons(["Done"])
	(row.get_child(0) as Button).pressed.connect(close_dialog)


## Which room the swatches below act on. Kept as buttons rather than a dropdown
## so it is one tap on a phone.
func _paint_target_row(body: Control) -> void:
	var row := HBoxContainer.new()
	body.add_child(row)
	var options: Array = [{"id": "", "name": "All rooms"}]
	for entry: Dictionary in _plan:
		options.append(entry)
	for option: Dictionary in options:
		var id := str(option["id"])
		var button := UIKit.make_button(str(option["name"]))
		button.toggle_mode = true
		button.button_pressed = id == _paint_target
		button.pressed.connect(func() -> void:
			_paint_target = id
			paint_target_changed.emit(id)
			_open_room_dialog())
		row.add_child(button)


func _paint_section(body: Control, surface: String) -> void:
	body.add_child(UIKit.section_label("Floor" if surface == "floor" else "Walls"))

	var grid := GridContainer.new()
	grid.columns = 4
	for entry: Dictionary in Catalog.PAINT[surface]:
		var paint_name := str(entry["name"])
		var owned: bool = not job_mode or Game.owns_paint(surface, paint_name)
		var unlocked: bool = Game.is_paint_unlocked(entry)
		var color: Color = entry["color"]
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)

		var swatch := UIKit.swatch_button(
			color if (owned or not job_mode) else color.darkened(0.62), Vector2(104, 42))
		swatch.disabled = job_mode and not owned
		swatch.pressed.connect(func() -> void:
			if surface == "floor":
				floor_paint_selected.emit(color)
			else:
				wall_paint_selected.emit(color))
		cell.add_child(swatch)

		var caption := UIKit.label(paint_name, 14, UIKit.TEXT if owned else UIKit.MUTED)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(caption)

		if job_mode and not owned:
			var note := UIKit.label(
				"Level %d" % int(entry["level"]) if not unlocked else UIKit.money(Catalog.paint_price(entry)),
				13, UIKit.BAD if not unlocked else UIKit.MUTED)
			note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(note)
		grid.add_child(cell)
	body.add_child(grid)


func _slider_row(parent: Control, label: String, minimum: float, maximum: float, step: float, value: float) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var name_label := UIKit.label(label)
	name_label.custom_minimum_size = Vector2(90, 0)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = clampf(value, minimum, maximum)
	slider.custom_minimum_size = Vector2(320, 40)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)

	var value_label := UIKit.label("%.2f m" % slider.value)
	value_label.custom_minimum_size = Vector2(90, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = "%.2f m" % v
		if _emit_room_changes and _room_w and _room_d and _room_h:
			_room_dims = Vector3(_room_w.value, _room_h.value, _room_d.value)
			room_changed.emit(_room_w.value, _room_d.value, _room_h.value))
	return slider


func _open_save_dialog() -> void:
	var body := _begin_dialog("Save layout")

	_save_name = LineEdit.new()
	_save_name.placeholder_text = "Layout name"
	_save_name.text = "My Room"
	_save_name.custom_minimum_size = Vector2(0, 46)
	body.add_child(_save_name)

	var existing := LayoutStore.list_layouts()
	if not existing.is_empty():
		body.add_child(UIKit.section_label("Existing"))
		var list := ItemList.new()
		list.custom_minimum_size = Vector2(0, 150)
		for layout_name in existing:
			list.add_item(layout_name)
		list.item_selected.connect(func(index: int) -> void:
			_save_name.text = list.get_item_text(index))
		body.add_child(list)

	var row := _dialog_buttons(["Cancel", "Save"])
	(row.get_child(0) as Button).pressed.connect(close_dialog)
	(row.get_child(1) as Button).pressed.connect(func() -> void:
		var layout_name := _save_name.text
		close_dialog()
		save_requested.emit(layout_name))


func _open_load_dialog() -> void:
	var body := _begin_dialog("Open layout")
	var existing := LayoutStore.list_layouts()

	if existing.is_empty():
		body.add_child(UIKit.label("No saved layouts yet.", 18, UIKit.MUTED))
		var only_row := _dialog_buttons(["Close"])
		(only_row.get_child(0) as Button).pressed.connect(close_dialog)
		return

	_layout_list = ItemList.new()
	_layout_list.custom_minimum_size = Vector2(0, 220)
	for layout_name in existing:
		_layout_list.add_item(layout_name)
	_layout_list.select(0)
	body.add_child(_layout_list)

	var row := _dialog_buttons(["Cancel", "Delete", "Open"])
	(row.get_child(0) as Button).pressed.connect(close_dialog)
	(row.get_child(1) as Button).pressed.connect(func() -> void:
		var picked := _selected_layout()
		if picked != "":
			close_dialog()
			delete_layout_requested.emit(picked))
	(row.get_child(2) as Button).pressed.connect(func() -> void:
		var picked := _selected_layout()
		if picked != "":
			close_dialog()
			load_requested.emit(picked))


func _selected_layout() -> String:
	if _layout_list == null:
		return ""
	var selected := _layout_list.get_selected_items()
	if selected.is_empty():
		return ""
	return _layout_list.get_item_text(selected[0])


func _open_new_dialog() -> void:
	var body := _begin_dialog("Start over")
	body.add_child(UIKit.wrapped_label("Remove every item from the room?", 520, UIKit.TEXT))
	var row := _dialog_buttons(["Cancel", "Clear room"])
	(row.get_child(0) as Button).pressed.connect(close_dialog)
	(row.get_child(1) as Button).pressed.connect(func() -> void:
		close_dialog()
		new_requested.emit())


func _confirm_leave() -> void:
	if not job_mode:
		leave_requested.emit()
		return
	var body := _begin_dialog("Back to the city")
	body.add_child(UIKit.wrapped_label(
		"The room is kept exactly as it is, and the pieces you have placed stay in it. Go and buy whatever else the brief needs, then come back.",
		520, UIKit.TEXT))
	var row := _dialog_buttons(["Stay", "Back to city"])
	(row.get_child(0) as Button).pressed.connect(close_dialog)
	(row.get_child(1) as Button).pressed.connect(func() -> void:
		close_dialog()
		leave_requested.emit())


func _open_help_dialog() -> void:
	var body := _begin_dialog("How to use")
	var sections := [
		["Add furniture", "Pick a category, then tap an item to drop it into the room. On a job you place pieces from your own stock — buy more at the shops in the city."],
		["Move", "Drag an item with one finger. Push it towards a wall and it sits flush against it and squares up. Small things like a television or a lamp land on whatever table they are dropped over."],
		["Turn and resize", "With a piece selected, twist two fingers over it to turn it and spread them to resize it. The buttons in the bar do the same in steps."],
		["Look around", "Drag an empty spot with one finger to orbit. Pinch with two fingers to zoom, drag with two to pan, and double tap anything to bring the camera to it."],
		["Undo", "Undo and Redo on the left go back through everything, and move the furniture between the room and your stock as they go."],
		["Red tint", "That piece overlaps another. Most briefs ask for a room with no clashes, and the client notices."],
		["Handing over", "Tick every line of the Brief, then hand the room over. The client marks it out of three stars — for keeping the big pieces against the walls, holding to a palette, leaving room to move, and coming in on budget — and pays a bonus to match."],
	]
	for section: Array in sections:
		body.add_child(UIKit.label(section[0], 19, UIKit.ACCENT))
		body.add_child(UIKit.wrapped_label(section[1], 520))
	var row := _dialog_buttons(["Close"])
	(row.get_child(0) as Button).pressed.connect(close_dialog)


## The hand-over screen: what the client thought, and what it paid.
func show_completion(job: Dictionary, result: Dictionary, review: Dictionary, on_close: Callable) -> void:
	var stars := int(result.get("stars", 1))
	var body := _begin_dialog("%s — handed over" % job["name"])

	var verdict := ["", "“It will do.”", "“I am very happy with this.”", "“It is exactly what I wanted.”"]
	body.add_child(UIKit.label(RoomReview.stars_text(stars), 30, UIKit.GOLD))
	body.add_child(UIKit.wrapped_label("%s — %s" % [job["client"], verdict[stars]], 520, UIKit.TEXT))

	body.add_child(UIKit.section_label("What they noticed"))
	for note: Dictionary in review.get("notes", []):
		var row := HBoxContainer.new()
		var good: bool = note["good"]
		row.add_child(UIKit.label("✓" if good else "·", 19, UIKit.GOOD if good else UIKit.BAD))
		var text := UIKit.label(str(note["label"]), 17, UIKit.TEXT if good else UIKit.MUTED)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(480, 0)
		row.add_child(text)
		body.add_child(row)

	var rows := [
		["Fee", UIKit.money(int(result["payout"]))],
		["%d-star bonus" % stars, UIKit.money(int(result["bonus"]))],
		["Furniture left in the house", "-%s" % UIKit.money(int(result["installed"]))],
		["Net", UIKit.money(int(result["payout"]) + int(result["bonus"]) - int(result["installed"]))],
		["Experience", "+%d XP" % int(result["xp"])],
	]
	for entry: Array in rows:
		var row := HBoxContainer.new()
		row.add_child(UIKit.label(entry[0], 18, UIKit.MUTED))
		row.add_child(UIKit.spacer())
		row.add_child(UIKit.label(entry[1], 18, UIKit.GOLD))
		body.add_child(row)

	if int(result["levels"]) > 0:
		body.add_child(UIKit.label(
			"Level %d reached — better stock and bigger jobs are open." % Game.level, 19, UIKit.GOOD))

	var button_row := _dialog_buttons(["Back to the city"])
	(button_row.get_child(0) as Button).pressed.connect(func() -> void:
		close_dialog()
		on_close.call())


# -------------------------------------------------------------- public state

func set_selection(item: FurnitureItem) -> void:
	if item == null:
		_selection_bar.visible = false
		_swatch_popup.visible = false
		return
	_selection_bar.visible = true
	var text := "%s   %d%%" % [Catalog.display_name(item.item_id), roundi(item.scale_factor * 100.0)]
	if job_mode:
		text += "   %s fitted" % UIKit.money(Catalog.price(item.item_id))
	_selection_label.text = text


func set_room_values(w: float, d: float, h: float) -> void:
	_room_dims = Vector3(w, h, d)
	_emit_room_changes = false
	if _room_w:
		_room_w.value = w
	if _room_d:
		_room_d.value = d
	if _room_h:
		_room_h.value = h
	_emit_room_changes = true


func set_top_view_pressed(on: bool) -> void:
	if _top_button:
		_top_button.set_pressed_no_signal(on)


## True when the point (in viewport pixels) lands on an interactive panel, so
## the 3D view should ignore the gesture.
func is_point_over_ui(point: Vector2) -> bool:
	for control in _blockers:
		if is_instance_valid(control) and control.visible and control.get_global_rect().has_point(point):
			return true
	return false
