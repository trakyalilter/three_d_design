class_name DesignerUI
extends CanvasLayer
## Touch-oriented interface, built entirely in code so the project carries no
## binary scene assets.
##
## Everything the user can do is emitted as a signal; main.gd owns the actual
## behaviour.

signal place_item(item_id: String)
signal command(name: String)
signal tint_selected(color: Color)
signal room_changed(width: float, room_depth: float, height: float)
signal room_colors_changed(floor_color: Color, wall_color: Color)
signal walls_toggled(enabled: bool)
signal snap_toggled(enabled: bool)
signal top_view_toggled(enabled: bool)
signal save_requested(layout_name: String)
signal load_requested(layout_name: String)
signal delete_layout_requested(layout_name: String)
signal new_requested()
signal recenter_requested()

const BG := Color(0.10, 0.11, 0.14, 0.94)
const BG_SOLID := Color(0.13, 0.14, 0.18, 1.0)
const ACCENT := Color(0.30, 0.72, 1.0)
const TEXT := Color(0.92, 0.93, 0.95)
const MUTED := Color(0.60, 0.64, 0.71)

const FLOOR_SWATCHES: Array[Color] = [
	Color(0.72, 0.62, 0.50),
	Color(0.55, 0.42, 0.30),
	Color(0.36, 0.27, 0.20),
	Color(0.85, 0.83, 0.80),
	Color(0.62, 0.64, 0.66),
	Color(0.30, 0.32, 0.36),
	Color(0.74, 0.72, 0.62),
	Color(0.52, 0.60, 0.55),
]
const WALL_SWATCHES: Array[Color] = [
	Color(0.92, 0.91, 0.88),
	Color(0.86, 0.88, 0.90),
	Color(0.80, 0.84, 0.79),
	Color(0.89, 0.84, 0.78),
	Color(0.70, 0.74, 0.80),
	Color(0.55, 0.58, 0.64),
	Color(0.78, 0.72, 0.72),
	Color(0.36, 0.38, 0.44),
]

var _root: Control
var _blockers: Array[Control] = []
var _modal_layer: Control
var _dialog_holder: VBoxContainer
var _dialog_scroll: ScrollContainer
var _dialog_body: VBoxContainer

var _stats_label: Label
var _selection_bar: PanelContainer
var _selection_label: Label
var _catalog_panel: PanelContainer
var _catalog_items: HBoxContainer
var _category_buttons: Array[Button] = []
var _active_category: String = ""
var _toast_label: Label
var _toast_timer: Timer
var _swatch_popup: PanelContainer

var _walls_button: Button
var _snap_button: Button
var _top_button: Button

# Dialog state
var _room_w: HSlider
var _room_d: HSlider
var _room_h: HSlider
var _room_w_value: Label
var _room_d_value: Label
var _room_h_value: Label
var _floor_color: Color = FLOOR_SWATCHES[0]
var _wall_color: Color = WALL_SWATCHES[0]
## Width, height, depth — kept here so the dialog opens with the real values
## even before its sliders have ever been created.
var _room_dims := Vector3(6.0, 2.6, 5.0)
var _save_name: LineEdit
var _layout_list: ItemList
var _emit_room_changes := false


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.name = "UIRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _build_theme()
	add_child(_root)

	_build_top_bar()
	_build_view_tools()
	_build_bottom()
	_build_toast()
	_build_swatch_popup()
	_build_modal_layer()


# --------------------------------------------------------------------- theme

func _build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 19

	theme.set_stylebox("panel", "PanelContainer", _panel_box(BG))
	theme.set_stylebox("panel", "Panel", _panel_box(BG))

	theme.set_stylebox("normal", "Button", _button_box(Color(0.20, 0.22, 0.27, 1.0)))
	theme.set_stylebox("hover", "Button", _button_box(Color(0.26, 0.29, 0.35, 1.0)))
	theme.set_stylebox("pressed", "Button", _button_box(ACCENT.darkened(0.25)))
	theme.set_stylebox("disabled", "Button", _button_box(Color(0.17, 0.18, 0.21, 1.0)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(0.45, 0.47, 0.52))
	theme.set_constant("h_separation", "Button", 6)

	theme.set_color("font_color", "Label", TEXT)

	var edit_box := _button_box(Color(0.08, 0.09, 0.12, 1.0))
	edit_box.border_width_bottom = 2
	edit_box.border_color = ACCENT
	theme.set_stylebox("normal", "LineEdit", edit_box)
	theme.set_stylebox("focus", "LineEdit", edit_box)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("caret_color", "LineEdit", ACCENT)

	theme.set_stylebox("panel", "ItemList", _panel_box(Color(0.07, 0.08, 0.10, 1.0)))
	theme.set_color("font_color", "ItemList", TEXT)
	theme.set_stylebox("selected", "ItemList", _button_box(ACCENT.darkened(0.35)))
	theme.set_stylebox("selected_focus", "ItemList", _button_box(ACCENT.darkened(0.35)))
	theme.set_constant("v_separation", "ItemList", 6)

	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.07, 0.08, 0.10)
	slider_bg.set_corner_radius_all(4)
	slider_bg.content_margin_top = 5
	slider_bg.content_margin_bottom = 5
	theme.set_stylebox("slider", "HSlider", slider_bg)
	var grabber_area := StyleBoxFlat.new()
	grabber_area.bg_color = ACCENT
	grabber_area.set_corner_radius_all(4)
	theme.set_stylebox("grabber_area", "HSlider", grabber_area)
	theme.set_stylebox("grabber_area_highlight", "HSlider", grabber_area)

	theme.set_constant("separation", "HBoxContainer", 8)
	theme.set_constant("separation", "VBoxContainer", 8)
	return theme


func _panel_box(color: Color, radius: int = 14) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


func _button_box(color: Color, radius: int = 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 9
	box.content_margin_bottom = 9
	return box


func _make_button(text: String, tooltip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tooltip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	return b


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

	var title := Label.new()
	title.text = "Room Designer 3D"
	title.add_theme_font_size_override("font_size", 21)
	row.add_child(title)

	_stats_label = Label.new()
	_stats_label.text = ""
	_stats_label.add_theme_color_override("font_color", MUTED)
	_stats_label.add_theme_font_size_override("font_size", 16)
	_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_stats_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var room_btn := _make_button("Room", "Room size and colours")
	room_btn.pressed.connect(_open_room_dialog)
	row.add_child(room_btn)

	var save_btn := _make_button("Save")
	save_btn.pressed.connect(_open_save_dialog)
	row.add_child(save_btn)

	var open_btn := _make_button("Open")
	open_btn.pressed.connect(_open_load_dialog)
	row.add_child(open_btn)

	var new_btn := _make_button("New")
	new_btn.pressed.connect(_open_new_dialog)
	row.add_child(new_btn)

	var help_btn := _make_button("Help")
	help_btn.pressed.connect(_open_help_dialog)
	row.add_child(help_btn)


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

	_top_button = _make_button("Top View", "Switch between 3D and plan view")
	_top_button.toggle_mode = true
	_top_button.toggled.connect(func(on: bool) -> void: top_view_toggled.emit(on))
	col.add_child(_top_button)

	_walls_button = _make_button("Walls: On")
	_walls_button.toggle_mode = true
	_walls_button.button_pressed = true
	_walls_button.toggled.connect(func(on: bool) -> void:
		_walls_button.text = "Walls: On" if on else "Walls: Off"
		walls_toggled.emit(on))
	col.add_child(_walls_button)

	_snap_button = _make_button("Snap: On", "Snap positions to a 25 cm grid")
	_snap_button.toggle_mode = true
	_snap_button.button_pressed = true
	_snap_button.toggled.connect(func(on: bool) -> void:
		_snap_button.text = "Snap: On" if on else "Snap: Off"
		snap_toggled.emit(on))
	col.add_child(_snap_button)

	var recenter := _make_button("Recenter")
	recenter.pressed.connect(func() -> void: recenter_requested.emit())
	col.add_child(recenter)


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
	column.alignment = BoxContainer.ALIGNMENT_END
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

	_selection_label = Label.new()
	_selection_label.text = "-"
	_selection_label.custom_minimum_size = Vector2(180, 0)
	_selection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_selection_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	for spec in [
		["Rotate -", "rotate_left"],
		["Rotate +", "rotate_right"],
		["Flip", "rotate_flip"],
		["Smaller", "scale_down"],
		["Bigger", "scale_up"],
	]:
		var b := _make_button(spec[0])
		b.pressed.connect(func() -> void: command.emit(spec[1]))
		row.add_child(b)

	var color_btn := _make_button("Colour")
	color_btn.pressed.connect(_toggle_swatch_popup)
	row.add_child(color_btn)

	var copy_btn := _make_button("Duplicate")
	copy_btn.pressed.connect(func() -> void: command.emit("duplicate"))
	row.add_child(copy_btn)

	var del_btn := _make_button("Delete")
	del_btn.add_theme_color_override("font_color", Color(1.0, 0.55, 0.52))
	del_btn.pressed.connect(func() -> void: command.emit("delete"))
	row.add_child(del_btn)

	var close_btn := _make_button("Done")
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

	var cats := HBoxContainer.new()
	col.add_child(cats)

	var hint := Label.new()
	hint.text = "Tap to add"
	hint.add_theme_color_override("font_color", MUTED)
	hint.add_theme_font_size_override("font_size", 16)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cats.add_child(hint)

	for category in Catalog.CATEGORIES:
		var b := _make_button(category)
		b.toggle_mode = true
		b.pressed.connect(_select_category.bind(category))
		cats.add_child(b)
		_category_buttons.append(b)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 92)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)

	# No expand flag: the row must be free to overflow so the scroller works.
	_catalog_items = HBoxContainer.new()
	scroll.add_child(_catalog_items)

	_select_category(Catalog.CATEGORIES[0])


func _select_category(category: String) -> void:
	_active_category = category
	for b in _category_buttons:
		b.button_pressed = b.text == category

	for child in _catalog_items.get_children():
		_catalog_items.remove_child(child)
		child.queue_free()

	for id in Catalog.ids_in(category):
		_catalog_items.add_child(_make_catalog_button(id))


func _make_catalog_button(id: String) -> Button:
	var b := Button.new()
	b.text = Catalog.display_name(id)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(148, 72)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = false
	b.pressed.connect(func() -> void: place_item.emit(id))

	var strip := ColorRect.new()
	strip.color = Catalog.default_tint(id)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	strip.offset_left = 8
	strip.offset_right = -8
	strip.offset_top = 6
	strip.offset_bottom = 12
	b.add_child(strip)

	var size_label := Label.new()
	var fp := Catalog.footprint(id)
	size_label.text = "%.2f x %.2f m" % [fp.x, fp.y]
	size_label.add_theme_color_override("font_color", MUTED)
	size_label.add_theme_font_size_override("font_size", 13)
	size_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	size_label.offset_top = -22
	size_label.offset_bottom = -4
	size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(size_label)
	return b


# ----------------------------------------------------------- colour swatches

func _build_swatch_popup() -> void:
	_swatch_popup = PanelContainer.new()
	_swatch_popup.name = "Swatches"
	_swatch_popup.visible = false
	_swatch_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_swatch_popup.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_swatch_popup.offset_top = -250
	_swatch_popup.offset_bottom = -250
	_swatch_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_swatch_popup.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(_swatch_popup)
	_blockers.append(_swatch_popup)

	var grid := GridContainer.new()
	grid.columns = 6
	_swatch_popup.add_child(grid)
	for color in Catalog.SWATCHES:
		var b := _swatch_button(color)
		b.pressed.connect(func() -> void:
			tint_selected.emit(color)
			_swatch_popup.visible = false)
		grid.add_child(b)


func _swatch_button(color: Color) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(58, 46)
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(8)
	var hover := box.duplicate() as StyleBoxFlat
	hover.set_border_width_all(3)
	hover.border_color = Color.WHITE
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	return b


func _toggle_swatch_popup() -> void:
	_swatch_popup.visible = not _swatch_popup.visible


# ---------------------------------------------------------------- toast text

func _build_toast() -> void:
	_toast_label = Label.new()
	_toast_label.name = "Toast"
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_top = 84
	_toast_label.offset_bottom = 84
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.add_theme_color_override("font_color", Color.WHITE)
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
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
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

	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 24)
	_dialog_holder.add_child(head)

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
		row.add_child(_make_button(label))

	if _dialog_scroll and _dialog_body:
		var available: float = maxf(_root.size.y - 220.0, 180.0)
		var wanted: float = _dialog_body.get_combined_minimum_size().y
		_dialog_scroll.custom_minimum_size.y = minf(wanted, available)
	return row


func _open_room_dialog() -> void:
	var body := _begin_dialog("Room")
	_emit_room_changes = false

	var w_pair := _slider_row(body, "Width", 2.0, 14.0, 0.25, _room_dims.x)
	_room_w = w_pair[0]
	_room_w_value = w_pair[1]
	var d_pair := _slider_row(body, "Depth", 2.0, 14.0, 0.25, _room_dims.z)
	_room_d = d_pair[0]
	_room_d_value = d_pair[1]
	var h_pair := _slider_row(body, "Height", 2.2, 3.6, 0.1, _room_dims.y)
	_room_h = h_pair[0]
	_room_h_value = h_pair[1]

	body.add_child(_section_label("Floor"))
	body.add_child(_swatch_row(FLOOR_SWATCHES, func(c: Color) -> void:
		_floor_color = c
		room_colors_changed.emit(_floor_color, _wall_color)))

	body.add_child(_section_label("Walls"))
	body.add_child(_swatch_row(WALL_SWATCHES, func(c: Color) -> void:
		_wall_color = c
		room_colors_changed.emit(_floor_color, _wall_color)))

	_emit_room_changes = true
	var row := _dialog_buttons(["Done"])
	(row.get_child(0) as Button).pressed.connect(close_dialog)


func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", MUTED)
	l.add_theme_font_size_override("font_size", 16)
	return l


func _slider_row(parent: Control, label: String, minimum: float, maximum: float, step: float, value: float) -> Array:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = label
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

	var value_label := Label.new()
	value_label.text = "%.2f m" % slider.value
	value_label.custom_minimum_size = Vector2(90, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = "%.2f m" % v
		if _emit_room_changes:
			_room_dims = Vector3(_room_w.value, _room_h.value, _room_d.value)
			room_changed.emit(_room_w.value, _room_d.value, _room_h.value))
	return [slider, value_label]


func _swatch_row(colors: Array[Color], on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	for color in colors:
		var b := _swatch_button(color)
		b.custom_minimum_size = Vector2(52, 40)
		b.pressed.connect(func() -> void: on_pick.call(color))
		row.add_child(b)
	return row


func _open_save_dialog() -> void:
	var body := _begin_dialog("Save layout")

	_save_name = LineEdit.new()
	_save_name.placeholder_text = "Layout name"
	_save_name.text = "My Room"
	_save_name.custom_minimum_size = Vector2(0, 46)
	body.add_child(_save_name)

	var existing := LayoutStore.list_layouts()
	if not existing.is_empty():
		body.add_child(_section_label("Existing"))
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
		var empty := Label.new()
		empty.text = "No saved layouts yet."
		empty.add_theme_color_override("font_color", MUTED)
		body.add_child(empty)
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
	var text := Label.new()
	text.text = "Remove every item from the room?"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(text)
	var row := _dialog_buttons(["Cancel", "Clear room"])
	(row.get_child(0) as Button).pressed.connect(close_dialog)
	(row.get_child(1) as Button).pressed.connect(func() -> void:
		close_dialog()
		new_requested.emit())


func _open_help_dialog() -> void:
	var body := _begin_dialog("How to use")
	var sections := [
		["Add furniture", "Pick a category, then tap an item to drop it into the room."],
		["Move", "Drag an item with one finger. It slides along the floor and stays inside the walls."],
		["Look around", "Drag an empty spot with one finger to orbit. Pinch with two fingers to zoom, and drag with two fingers to pan."],
		["Adjust", "Select an item, then use the bar at the bottom to rotate, resize, recolour, duplicate or delete it."],
		["Red tint", "The item overlaps something else. It can still be left there — it is only a warning."],
		["Saving", "Layouts are stored on the device, and your last arrangement is restored the next time you open the app."],
	]
	for section: Array in sections:
		var heading := Label.new()
		heading.text = section[0]
		heading.add_theme_color_override("font_color", ACCENT)
		body.add_child(heading)

		var text := Label.new()
		text.text = section[1]
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(520, 0)
		text.add_theme_color_override("font_color", MUTED)
		body.add_child(text)
	var row := _dialog_buttons(["Close"])
	(row.get_child(0) as Button).pressed.connect(close_dialog)


# -------------------------------------------------------------- public state

func set_selection(item: FurnitureItem) -> void:
	if item == null:
		_selection_bar.visible = false
		_swatch_popup.visible = false
		return
	_selection_bar.visible = true
	_selection_label.text = "%s   %d%%" % [
		Catalog.display_name(item.item_id),
		roundi(item.scale_factor * 100.0),
	]


func set_stats(item_count: int, floor_area: float) -> void:
	_stats_label.text = "   %d item%s  ·  %.1f m²" % [
		item_count, "" if item_count == 1 else "s", floor_area,
	]


func set_room_values(w: float, d: float, h: float, floor_color: Color, wall_color: Color) -> void:
	_floor_color = floor_color
	_wall_color = wall_color
	_room_dims = Vector3(w, h, d)
	_emit_room_changes = false
	if _room_w:
		_room_w.value = w
	if _room_d:
		_room_d.value = d
	if _room_h:
		_room_h.value = h
	_emit_room_changes = true


## Width, height, depth.
func room_dimensions() -> Vector3:
	return _room_dims


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
