class_name LoadingScreen
extends CanvasLayer
## The screen that covers a move between the map and a job.
##
## Both screens are built from scratch every time — the city welds a few
## thousand boxes into batched meshes, the designer lays out a floor plan and
## every piece standing on it — and that work blocks the main thread. Without
## this the last frame of the old screen just sat there, frozen, for as long as
## it took.
##
## The overlay goes up first and is given a frame to actually paint. The build
## then runs a stage at a time, with a frame in between, so the bar underneath
## moves and the player can see the thing is alive.

## Lines shown under the bar. One is picked at random each time, so the wait
## is at least worth reading.
const TIPS: PackedStringArray = [
	"Drag a piece with one finger, twist with two.",
	"Furniture snaps to a wall when you let go near one.",
	"Lamps, vases and books sit on tables, shelves and cabinets.",
	"Undo is on the toolbar — nothing you do here is final.",
	"Read the brief before you shop. Clients ask for specific things.",
	"Paint is bought per room, not per house.",
	"Stock is yours for good. Anything left over goes into the next job.",
	"Three stars needs the brief met and the budget kept.",
	"Finished clients come back with repeat work.",
	"Buying a quarter unlocks its shops as well as its houses.",
	"Walls between you and the camera fade out on their own.",
	"Tap the catalogue tab to fold the tray away and see the room.",
]

## How long the overlay takes to lift once the screen behind it is ready.
const FADE_OUT := 0.24
## Inset from the edges of the screen, and how wide the text column runs.
const MARGIN := 56
const COLUMN := 620.0

var _kicker: Label
var _title: Label
var _stage: Label
var _bar: ProgressBar
var _root: Control


func _ready() -> void:
	layer = 100
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIKit.build_theme()
	# Swallow every touch: the screen behind is half-built and must not be
	# poked at while it is.
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.07, 0.08, 0.11, 1.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(backdrop)

	# A slow wash of colour across the bottom so the panel is not a flat void.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.30, 0.72, 1.0, 0.0),
		Color(0.30, 0.72, 1.0, 0.10),
	])
	var wash := GradientTexture2D.new()
	wash.gradient = gradient
	wash.fill_from = Vector2(0.5, 0)
	wash.fill_to = Vector2(0.5, 1)
	wash.width = 4
	wash.height = 256
	var glow := TextureRect.new()
	glow.texture = wash
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(glow)

	# The game's own name, small, top left — so a screen that is otherwise all
	# placeholder text still says what it belongs to.
	var mark := MarginContainer.new()
	mark.set_anchors_preset(Control.PRESET_TOP_WIDE)
	mark.add_theme_constant_override("margin_left", MARGIN)
	mark.add_theme_constant_override("margin_top", MARGIN)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(mark)
	var name_label := UIKit.label("ROOM DESIGNER 3D", 15, Color(0.44, 0.47, 0.53))
	mark.add_child(name_label)

	# Everything else sits along the bottom, out of the way of the middle of
	# the screen where the next picture is about to appear.
	var block := MarginContainer.new()
	block.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	block.offset_top = -320
	block.add_theme_constant_override("margin_left", MARGIN)
	block.add_theme_constant_override("margin_right", MARGIN)
	block.add_theme_constant_override("margin_bottom", MARGIN)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(block)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(column)

	var tip := UIKit.wrapped_label(TIPS[randi() % TIPS.size()], COLUMN, Color(0.50, 0.54, 0.61))
	tip.add_theme_font_size_override("font_size", 17)
	column.add_child(tip)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 22)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)

	_kicker = UIKit.label("", 15, UIKit.ACCENT)
	column.add_child(_kicker)

	_title = UIKit.label("", 40)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(COLUMN, 0)
	column.add_child(_title)

	_stage = UIKit.label("", 17, UIKit.MUTED)
	column.add_child(_stage)

	_bar = ProgressBar.new()
	_bar.max_value = 1.0
	_bar.step = 0.001
	_bar.value = 0.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(COLUMN, 8)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_bar)


## What the player is on their way to. The kicker is the small line above.
func headline(kicker: String, title: String) -> void:
	_kicker.text = kicker.to_upper()
	_title.text = title


## Names the stage about to run and moves the bar to where it will be when that
## stage is done, so the bar leads the work rather than trailing it.
func stage(text: String, ratio: float) -> void:
	_stage.text = text
	_bar.value = clampf(ratio, 0.0, 1.0)


## How far along the bar is, 0 to 1.
func progress() -> float:
	return _bar.value


## Fades the overlay away and frees it. Await this so the caller knows the
## screen is its own again.
func dismiss() -> void:
	_bar.value = 1.0
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, FADE_OUT)
	await tween.finished
	queue_free()
