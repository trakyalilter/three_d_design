extends Node
## What levelling up is actually for, autoloaded as `Perks`.
##
## Up to here a level was a key: it unlocked a shop, a quarter, a holding, and
## did nothing else. Two players at level 20 had exactly the same business. This
## is the other half of it — every level hands you a point, and a point buys one
## step up one of four lines. The lines are the four things a person in this
## trade can be good at, and they do not overlap:
##
##   Haggler   what you pay for everything
##   Stager    what a finished room is worth
##   Scholar   what a finished room teaches you
##   Grafter   how fast the land and the workshop turn
##
## There are eight steps in each line and twenty-nine points in a whole career,
## so the tree is deliberately four short of affordable. You cannot have all of
## it, which is the only thing that makes choosing any of it interesting.
##
## Everything here is a pure function of a rank. The ranks themselves live on
## the profile in `GameState`, which is also where the effects are read from —
## `Game.discount()`, `Game.fee_bonus()` and so on — so nothing in this file
## needs to know a career exists.

## Steps in a line.
const RANKS := 8

## What each step is worth. All four are per-rank and stack straight up.
const HAGGLE_STEP := 0.02
const FEE_STEP := 0.015
const XP_STEP := 0.03
const GRAFT_STEP := 0.04

## The ranks of the Grafter line that put another piece on the bench at once.
const BENCH_RANKS := [3, 6]

## The four lines, each with a name for every step. The names are the point of
## them: "Grafter 4" is a number, "Grease the line" is a decision you made.
const LINES: Array[Dictionary] = [
	{
		"id": "haggler",
		"name": "Haggler",
		"color": Color(0.86, 0.72, 0.36),
		"blurb": "Everything in the shops costs less — furniture, paint and "
			+ "trade material alike. What you sell back is worth whatever it "
			+ "would cost you today, so a mistake is still free.",
		"effect": "off in the shops",
		"steps": [
			"Ask the price twice", "Know the delivery man", "Buy by the pallet",
			"A trade account", "End-of-line stock", "First refusal",
			"The manager's number", "Named on the invoice",
		],
	},
	{
		"id": "stager",
		"name": "Stager",
		"color": Color(0.52, 0.76, 0.58),
		"blurb": "Every room you hand over is worth more than the fee says. "
			+ "This is on top of the client's own review, and it is paid whether "
			+ "they liked the room or not.",
		"effect": "on every fee",
		"steps": [
			"Straighten the shade", "Cushions at the corner", "Photograph it",
			"Leave a card", "Word of mouth", "A page in the trade press",
			"They ask for you by name", "A waiting list",
		],
	},
	{
		"id": "scholar",
		"name": "Scholar",
		"color": Color(0.56, 0.70, 0.88),
		"blurb": "Every job teaches you more than it did. It pays for itself: "
			+ "the levels it brings forward are more points for the tree.",
		"effect": "more from a job",
		"steps": [
			"Keep a sketchbook", "Measure everything", "Read the trade press",
			"Draw before you buy", "Study the room first", "Learn the joints",
			"Take an apprentice", "Write it all down",
		],
	},
	{
		"id": "grafter",
		"name": "Grafter",
		"color": Color(0.84, 0.58, 0.44),
		"blurb": "The land out of town yields faster, the works and the workshop "
			+ "turn quicker, and two of the steps put another piece on the bench "
			+ "at the same time.",
		"effect": "faster out of town",
		"steps": [
			"Sharpen the saws", "A second shift", "Two at the bench",
			"Grease the line", "Hire a hand", "Three at the bench",
			"Night working", "The whole yard turning",
		],
	},
]


func lines() -> Array[Dictionary]:
	return LINES


func get_line(id: String) -> Dictionary:
	for entry in LINES:
		if str(entry["id"]) == id:
			return entry
	return {}


func line_name(id: String) -> String:
	return str(get_line(id).get("name", id))


## The name of one step. Ranks are one-based, the way they are shown.
func step_name(id: String, rank: int) -> String:
	var steps: Array = get_line(id).get("steps", [])
	if rank < 1 or rank > steps.size():
		return ""
	return str(steps[rank - 1])


## What level the career has to have reached before a step can be bought.
##
## Points alone would let you pour a whole early career into one line and be
## finished with it by level nine. This paces the lines against each other: the
## last step of anything is a late-career decision.
static func level_for_rank(rank: int) -> int:
	return 2 + (rank - 1) * 3


## What one line is worth at a rank, as a plain fraction.
static func value_at(id: String, rank: int) -> float:
	var steps: float = float(clampi(rank, 0, RANKS))
	match id:
		"haggler":
			return steps * HAGGLE_STEP
		"stager":
			return steps * FEE_STEP
		"scholar":
			return steps * XP_STEP
		"grafter":
			return steps * GRAFT_STEP
	return 0.0


## How that reads on a card.
static func value_line(id: String, rank: int) -> String:
	return "%d%%" % int(round(value_at(id, rank) * 100.0))


## How many pieces the workshop bench can have under the clamps at once.
static func bench_slots(grafter_rank: int) -> int:
	var slots := 1
	for at: int in BENCH_RANKS:
		if grafter_rank >= at:
			slots += 1
	return slots
