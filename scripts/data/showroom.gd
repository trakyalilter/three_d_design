class_name Showroom
extends RefCounted
## What a room of your own is worth, standing there.
##
## Every other room in the game belongs to somebody else: you fit it out, hand
## it over, and the furniture goes with it. This one is yours. Nobody briefs
## you, nothing is taken away, and it pays for as long as it is dressed —
## passers-by see it through the window and order what is in it.
##
## The point of it is that **the design is the mechanic**. Up to here the review
## fired once at a hand-over and was never heard from again; here it is the
## multiplier on everything the room earns, every hour, until you change it. A
## floor of expensive furniture arranged badly is worth less than a cheaper one
## arranged well, and a floor from one shop is a corner rather than a showroom.

## What a floor takes in an hour, as a share of what is standing on it.
const RATE_PER_HOUR := 0.012
## How the client's own six-point review multiplies that. A room nobody would
## walk into takes nothing at all.
const BY_STARS := {0: 0.0, 1: 0.6, 2: 1.0, 3: 1.5}
## And what a spread of counters is worth: a floor of nothing but sofas is a
## sofa shop, and there is one of those on the avenue already.
const SPREAD_BASE := 0.7
const SPREAD_PER_SHOP := 0.1
const SPREAD_SHOPS := 6
## Fewer pieces than this and there is nothing to look at.
const MIN_PIECES := 4
## How long the till fills before it stops. A trading day, so a showroom is
## something you look in on rather than something you farm.
const TRADING_HOURS := 12.0


## What the floor takes in an hour: what is standing on it, how well it is
## arranged, and how many counters it represents.
static func takings(stars: int, value: int, shops: int, pieces: int) -> int:
	if pieces < MIN_PIECES or value <= 0:
		return 0
	var by_stars := float(BY_STARS.get(stars, 0.0))
	if by_stars <= 0.0:
		return 0
	var spread := SPREAD_BASE + SPREAD_PER_SHOP * float(mini(shops, SPREAD_SHOPS))
	return int(round(float(value) * RATE_PER_HOUR * by_stars * spread))


## What it will hold before it stops.
static func till_cap(per_hour: int) -> int:
	return int(ceil(float(per_hour) * TRADING_HOURS))


## How a rate reads on a sheet.
static func spread_line(shops: int) -> String:
	if shops >= SPREAD_SHOPS:
		return "%d counters — as broad as it counts" % shops
	return "%d counter%s of the %d that count" % [
		shops, "" if shops == 1 else "s", SPREAD_SHOPS]
