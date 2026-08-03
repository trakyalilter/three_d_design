class_name RoomReview
extends RefCounted
## The client's opinion of a finished room.
##
## The brief is a checklist: it says what has to be in the room, and nothing
## about whether the room is any good. This is the other half — five things a
## person actually notices walking in, each either satisfied or not, turned
## into one to three stars and a bonus on the fee.

## Bonus on the fee, by star count.
const BONUS := {1: 0.0, 2: 0.15, 3: 0.30}

## How close a piece has to be to a wall to count as against it.
const WALL_REACH := 0.30
## Share of the wall-hugging pieces that have to be in place.
const WALL_SHARE := 0.7
## More distinct colours than this and the room stops reading as one scheme.
const PALETTE_LIMIT := 4
## Comfortable share of the floor taken up by furniture.
const CROWD_MIN := 0.12
const CROWD_MAX := 0.55


## `entries` is one dictionary per placed piece:
##   {"id": String, "tint": Color, "blocked": bool, "wall_gap": float,
##    "area": float}
## Returns {"stars": int, "bonus_rate": float, "notes": Array[Dictionary]}
## where each note is {"label": String, "good": bool}.
static func score(entries: Array, floor_area: float, installed: int, budget: int) -> Dictionary:
	var notes: Array[Dictionary] = []

	# 1. Nothing jammed into anything else.
	var clashes := 0
	for entry: Dictionary in entries:
		if entry.get("blocked", false):
			clashes += 1
	notes.append({
		"good": clashes == 0,
		"label": "Nothing overlaps" if clashes == 0
			else "%d piece%s pushed into another" % [clashes, "" if clashes == 1 else "s"],
	})

	# 2. The big pieces are against the walls, where they belong.
	var wall_pieces := 0
	var wall_placed := 0
	for entry: Dictionary in entries:
		if not Catalog.get_item(str(entry["id"])).get("against_wall", false):
			continue
		wall_pieces += 1
		if float(entry.get("wall_gap", 99.0)) <= WALL_REACH:
			wall_placed += 1
	var wall_ok: bool = wall_pieces == 0 or float(wall_placed) / float(wall_pieces) >= WALL_SHARE
	notes.append({
		"good": wall_ok,
		"label": "The big pieces sit against the walls" if wall_ok
			else "%d of %d big pieces are stranded mid-floor" % [wall_pieces - wall_placed, wall_pieces],
	})

	# 3. A palette rather than a paint chart.
	var tones: Dictionary = {}
	for entry: Dictionary in entries:
		var tint: Color = entry.get("tint", Color.WHITE)
		# Round hard, so near-identical shades count as one colour.
		tones["%d,%d,%d" % [roundi(tint.r * 6.0), roundi(tint.g * 6.0), roundi(tint.b * 6.0)]] = true
	var palette_ok: bool = tones.size() <= PALETTE_LIMIT
	notes.append({
		"good": palette_ok,
		"label": "The colours hang together" if palette_ok
			else "%d different colours is a lot for one room" % tones.size(),
	})

	# 4. Room left to walk around in.
	var used := 0.0
	for entry: Dictionary in entries:
		used += float(entry.get("area", 0.0))
	var density: float = used / maxf(floor_area, 0.01)
	var crowd_ok: bool = density >= CROWD_MIN and density <= CROWD_MAX
	notes.append({
		"good": crowd_ok,
		"label": "There is room to move" if crowd_ok
			else ("It feels bare" if density < CROWD_MIN else "It is packed tight"),
	})

	# 5. The client's money.
	var budget_ok: bool = budget <= 0 or installed <= budget
	notes.append({
		"good": budget_ok,
		"label": "Came in on budget" if budget_ok
			else "Over budget by %d" % (installed - budget),
	})

	var passed := 0
	for note: Dictionary in notes:
		if note["good"]:
			passed += 1

	var stars := 1
	if passed >= 5:
		stars = 3
	elif passed >= 3:
		stars = 2

	return {"stars": stars, "bonus_rate": float(BONUS[stars]), "notes": notes, "passed": passed}


static func stars_text(stars: int) -> String:
	return "★".repeat(stars) + "☆".repeat(3 - stars)
