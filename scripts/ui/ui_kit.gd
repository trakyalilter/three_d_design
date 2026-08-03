class_name UIKit
extends RefCounted
## Shared look and feel. Both the city map and the room designer build their
## interfaces from these helpers so the two screens feel like one app.

const BG := Color(0.10, 0.11, 0.14, 0.94)
const BG_SOLID := Color(0.13, 0.14, 0.18, 1.0)
const SUNKEN := Color(0.07, 0.08, 0.10, 1.0)
const ACCENT := Color(0.30, 0.72, 1.0)
const GOLD := Color(0.98, 0.78, 0.32)
const GOOD := Color(0.42, 0.83, 0.52)
const BAD := Color(1.0, 0.48, 0.45)
const TEXT := Color(0.92, 0.93, 0.95)
const MUTED := Color(0.60, 0.64, 0.71)


static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 19

	theme.set_stylebox("panel", "PanelContainer", panel_box(BG))
	theme.set_stylebox("panel", "Panel", panel_box(BG))

	theme.set_stylebox("normal", "Button", button_box(Color(0.20, 0.22, 0.27, 1.0)))
	theme.set_stylebox("hover", "Button", button_box(Color(0.26, 0.29, 0.35, 1.0)))
	theme.set_stylebox("pressed", "Button", button_box(ACCENT.darkened(0.25)))
	theme.set_stylebox("disabled", "Button", button_box(Color(0.16, 0.17, 0.20, 1.0)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(0.42, 0.44, 0.49))
	theme.set_constant("h_separation", "Button", 6)

	theme.set_color("font_color", "Label", TEXT)

	var edit := button_box(SUNKEN)
	edit.border_width_bottom = 2
	edit.border_color = ACCENT
	theme.set_stylebox("normal", "LineEdit", edit)
	theme.set_stylebox("focus", "LineEdit", edit)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("caret_color", "LineEdit", ACCENT)

	theme.set_stylebox("panel", "ItemList", panel_box(SUNKEN))
	theme.set_color("font_color", "ItemList", TEXT)
	theme.set_stylebox("selected", "ItemList", button_box(ACCENT.darkened(0.35)))
	theme.set_stylebox("selected_focus", "ItemList", button_box(ACCENT.darkened(0.35)))
	theme.set_constant("v_separation", "ItemList", 6)

	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = SUNKEN
	slider_bg.set_corner_radius_all(4)
	slider_bg.content_margin_top = 5
	slider_bg.content_margin_bottom = 5
	theme.set_stylebox("slider", "HSlider", slider_bg)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = ACCENT
	grabber.set_corner_radius_all(4)
	theme.set_stylebox("grabber_area", "HSlider", grabber)
	theme.set_stylebox("grabber_area_highlight", "HSlider", grabber)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = SUNKEN
	bar_bg.set_corner_radius_all(6)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = GOLD
	bar_fill.set_corner_radius_all(6)
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)
	theme.set_color("font_color", "ProgressBar", Color(0.08, 0.08, 0.10))
	theme.set_font_size("font_size", "ProgressBar", 14)

	theme.set_constant("separation", "HBoxContainer", 8)
	theme.set_constant("separation", "VBoxContainer", 8)
	return theme


static func panel_box(color: Color, radius: int = 14) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


static func button_box(color: Color, radius: int = 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 9
	box.content_margin_bottom = 9
	return box


static func make_button(text: String, tooltip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tooltip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	return b


## A button tinted to read as the primary action of a panel.
static func make_primary_button(text: String) -> Button:
	var b := make_button(text)
	b.add_theme_stylebox_override("normal", button_box(ACCENT.darkened(0.15)))
	b.add_theme_stylebox_override("hover", button_box(ACCENT))
	b.add_theme_stylebox_override("pressed", button_box(ACCENT.darkened(0.35)))
	b.add_theme_color_override("font_color", Color(0.05, 0.07, 0.10))
	b.add_theme_color_override("font_hover_color", Color(0.05, 0.07, 0.10))
	return b


static func swatch_button(color: Color, size: Vector2 = Vector2(58, 46)) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = size
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(8)
	var hover := box.duplicate() as StyleBoxFlat
	hover.set_border_width_all(3)
	hover.border_color = Color.WHITE
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", box)
	return b


static func label(text: String, size: int = 19, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func section_label(text: String) -> Label:
	return label(text, 16, MUTED)


static func wrapped_label(text: String, width: float = 520.0, color: Color = MUTED) -> Label:
	var l := label(text, 18, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## "$1,250", with a minus sign in front for debts.
static func money(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-$" if amount < 0 else "$") + out
