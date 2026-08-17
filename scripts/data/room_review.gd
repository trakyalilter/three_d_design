class_name RoomReview
extends RefCounted
## The client's opinion of a finished room.
##
## The brief is a checklist: it says what has to be in the room, and nothing
## about whether the room is any good. This is the other half — six things a
## person actually notices walking in, each either satisfied or not, turned
## into one to three stars and a bonus on the fee.
##
## Five of the six are about whether the room works: nothing jammed into
## anything, the big pieces where they belong, a palette rather than a paint
## chart, room to move, and the client's money. The sixth is the only one about
## taste, and it is the one that turns the job from a shopping run into a
## design: a room can be correct in every other way and still be a jumble of
## six different schools of furniture.

## Bonus on the fee, by star count.
const BONUS := {1: 0.0, 2: 0.15, 3: 0.30}

## How close a piece has to be to a wall to count as against it.
const WALL_REACH := 0.30
## Share of the wall-hugging pieces that have to be in place.
const WALL_SHARE := 0.7
## More distinct colours than this and the room stops reading as one scheme.
## One fewer than a quarter sells, so furnishing a room out of one is a choice
## about which of its colours to leave out rather than a thing that happens.
const PALETTE_LIMIT := 3
## Comfortable share of the floor taken up by furniture.
const CROWD_MIN := 0.12
const CROWD_MAX := 0.55
## Share of the pieces with an opinion that have to agree with each other.
## Plain stock has no opinion and is left out of the sum entirely.
const STYLE_SHARE := 0.7
## What furnishing a room in the style the client actually likes is worth, on
## top of whatever the stars earned.
const TASTE_BONUS := 0.05


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

	# 5. One school of furniture rather than six. The only line here that is
	# about taste, and the only one a room can fail while being otherwise
	# faultless.
	var voices: Dictionary = {}
	var opinionated := 0
	for entry: Dictionary in entries:
		var style := Catalog.style_of(str(entry["id"]))
		if style == Catalog.PLAIN:
			continue
		voices[style] = int(voices.get(style, 0)) + 1
		opinionated += 1
	var loudest := ""
	var second := ""
	var most := 0
	for style: String in voices:
		if int(voices[style]) > most:
			most = int(voices[style])
			second = loudest
			loudest = style
		elif second == "":
			second = style
	var style_ok: bool = opinionated == 0 \
		or float(most) / float(opinionated) >= STYLE_SHARE
	notes.append({
		"good": style_ok,
		"label": "The room has a point of view" if style_ok
			else "%s and %s are pulling against each other" % [
				Catalog.style_name(loudest), Catalog.style_name(second)],
	})

	# 6. The client's money.
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

	# Three stars means faultless. It used to mean five of the six, which made
	# one miss free — and a career measured with the palette line failing three
	# rooms in five still came out at fifty-one rooms in three stars, because the
	# miss it was failing was the one it was allowed. Two stars is what a good
	# room gets, and the top of the review is for a room with nothing wrong with
	# it at all.
	var stars := 1
	if passed >= notes.size():
		stars = 3
	elif passed >= 3:
		stars = 2

	return {
		"stars": stars,
		"bonus_rate": float(BONUS[stars]),
		"notes": notes,
		"passed": passed,
		# Which school the room speaks in, for whoever is paying for it.
		"voice": loudest if opinionated > 0 else Catalog.PLAIN,
	}


static func stars_text(stars: int) -> String:
	return "★".repeat(stars) + "☆".repeat(3 - stars)
