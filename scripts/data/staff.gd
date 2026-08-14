extends Node
## The people on your books, autoloaded as `Staff`.
##
## The perk tree is what *you* got better at, and it is free and permanent. This
## is the opposite of it on every axis: four people who do a chore you would
## otherwise do by hand, hired and let go whenever you like, and paid out of
## every fee for as long as they are on the books.
##
## Each one removes exactly one chore, and none of them touches a decision:
##
##   Rosa    fetches a brief's shopping so you do not walk the parade for it
##   Tomas   carts every holding in as it fills, so nothing stands still
##   Ada     puts a run on at every works that can take one
##   Petar   keeps the workshop bench fed with the last thing you made
##
## Nobody makes a design choice for you — where a piece goes, what colour it is
## and what a room is *for* stay yours. They only do the walking.
##
## **Nobody is paid by the hour.** A wage on the wall clock would mean coming
## back from a fortnight away to an empty account, which is a punishment for
## having a life. Everyone takes a share of every fee instead, so employing four
## people costs you nothing at all until you are actually paid — and the moment
## it stops being worth it, you let them go for free.

const ROLES: Array[Dictionary] = [
	{
		"id": "runner",
		"name": "Rosa",
		"title": "Runner",
		"share": 0.04,
		"level": 6,
		"color": Color(0.86, 0.66, 0.42),
		"blurb": "Knows every counter in the city and which of them is lying "
			+ "about having it in stock.",
		"does": "Puts a button on a brief that buys everything still missing, "
			+ "from every shop at once, without you walking the parade for it.",
	},
	{
		"id": "hand",
		"name": "Tomas",
		"title": "Yard hand",
		"share": 0.03,
		"level": 8,
		"color": Color(0.56, 0.74, 0.50),
		"blurb": "Grew up on the land west of the road and has never once "
			+ "left a full cart standing.",
		"does": "Carts every holding in as it fills, so you never tap Collect "
			+ "again — and a heap he is working holds three times as much before "
			+ "the ground stops.",
	},
	{
		"id": "millwright",
		"name": "Ada",
		"title": "Millwright",
		"share": 0.03,
		"level": 12,
		"color": Color(0.60, 0.70, 0.88),
		"blurb": "Keeps four plants running and can hear which one is about "
			+ "to stop from the other end of the yard.",
		"does": "Puts a run on at every works that has the material for one, "
			+ "the moment the last run comes off it.",
	},
	{
		"id": "joiner",
		"name": "Petar",
		"title": "Joiner",
		"share": 0.04,
		"level": 15,
		"color": Color(0.84, 0.56, 0.52),
		"blurb": "Serves his time at the bench and would rather it were never "
			+ "empty.",
		"does": "Keeps the workshop bench going: whatever came off it last "
			+ "goes back on, as long as the trade store can pay for it.",
	},
]

## How much longer a holding runs before its heap stops it, with Tomas on it.
## Bounded rather than removed: the yard's own capacity is the ceiling that is
## meant to be built rather than hired, and this does not touch it.
const HEAP_MULTIPLE := 3.0

## What it costs to take somebody on. It rises with the level because so does
## everything they would be handling, and letting somebody go and taking them
## back on again is not free.
const JOINING_FEE := 900
const JOINING_PER_LEVEL := 260


func roles() -> Array[Dictionary]:
	return ROLES


func get_role(id: String) -> Dictionary:
	for entry in ROLES:
		if str(entry["id"]) == id:
			return entry
	return {}


func role_name(id: String) -> String:
	return str(get_role(id).get("name", id))


func title_of(id: String) -> String:
	return str(get_role(id).get("title", ""))


## How somebody is introduced: "Rosa, runner".
func full_name(id: String) -> String:
	var role := get_role(id)
	if role.is_empty():
		return id
	return "%s, %s" % [role["name"], str(role["title"]).to_lower()]


func share_of(id: String) -> float:
	return float(get_role(id).get("share", 0.0))


## What taking somebody on costs today. It rises with the level because so does
## everything they would be handling.
static func joining_fee(level: int) -> int:
	return JOINING_FEE + JOINING_PER_LEVEL * maxi(level - 1, 0)
