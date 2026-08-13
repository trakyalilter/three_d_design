extends Node
## The player's career: money, experience, level, the stock they own, and
## which jobs are done.
##
## Autoloaded as `Game`. Everything here persists to user://profile.json so a
## session survives closing the app.
##
## Money only ever changes in the city: furniture is bought into stock at the
## shops and can be sold back at the same price. Inside a room the player
## spends stock, never cash — a piece leaves the warehouse when it is placed
## and returns to it when it is taken out again. Handing a job over is what
## finally consumes the furniture standing in that room.

signal money_changed(amount: int)
signal stock_changed()
signal progress_changed(level: int, xp: int, xp_needed: int)
signal levelled_up(level: int)
signal district_unlocked(district_id: String)
signal estate_changed()

const PROFILE_PATH := "user://profile.json"
const STARTING_MONEY := 3000
const MAX_LEVEL := 30

var money: int = STARTING_MONEY
var xp: int = 0
var level: int = 1

## item id -> how many are sitting in the warehouse, ready to place.
var inventory: Dictionary = {}
## "<surface>/<name>" -> true for every paint the player has bought.
var owned_paints: Dictionary = {}
## house id -> {"payout": int, "bonus": int, "xp": int, "installed": int}
var finished_jobs: Dictionary = {}
## house id -> serialized layout, so an unfinished job can be resumed.
var saved_jobs: Dictionary = {}
## house id -> a generated brief the player took on after the original was
## finished. Jobs.get_job() lays these over the handcrafted entry.
var active_contracts: Dictionary = {}
## house id -> how many times it has been handed over.
var repeats: Dictionary = {}
## district id -> true for every quarter of the city the player has bought.
var owned_districts: Dictionary = {}

# ----------------------------------------------------------------- the estate

## material id -> how much is sitting at the yard, uncut.
var materials: Dictionary = {}
## good id -> how many finished pieces are waiting at the works.
var goods: Dictionary = {}
## site id -> how far it has been worked up, 1 to 3. Missing means not bought.
var sites: Dictionary = {}
## works id -> the same, for the plants that make goods.
var plants: Dictionary = {}
## item id -> how far that piece has been improved at the bench, 1 to 3.
var quality: Dictionary = {}
## site id -> how much has come up out of the ground and not been collected.
## Kept as a float so a part hour is not thrown away every time it is settled.
var site_stock: Dictionary = {}
## site id -> the wall clock when that holding was last settled.
var site_since: Dictionary = {}
## works id -> {"made": how many are in the run, "ready_at": when it comes off}.
var batches: Dictionary = {}
## trade material id -> how many units are in the workshop store. Bought with
## money at the merchant, and the only thing an ordinary piece is ever made of.
var supplies: Dictionary = {}
## What is on the workshop bench, as [{"id", "ready_at"}]. Made in the order it
## was put on, one at a time.
var making: Array = []
## Pushed forward by the test harness so a week can pass in a frame. Zero in
## anything a player runs.
var clock_offset: float = 0.0


func _ready() -> void:
	load_profile()
	_grant_starter_paints()
	_grant_free_districts()


# ---------------------------------------------------------------- levelling

## Experience needed to get from `from_level` to the next one.
##
## The whole career is worth about 46,000 experience at two stars a job, and
## the thirty levels cost 45,414 between them — so a competent run arrives at
## the cap on the last of the fifty-six houses, and a scrappier one finishes it
## off with repeat work. Levelling is meant to last the length of the city, and
## the city has grown twice since.
static func xp_for_level(from_level: int) -> int:
	return 110 + (from_level - 1) * 104


func xp_needed() -> int:
	if level >= MAX_LEVEL:
		return 0
	return xp_for_level(level)


func xp_fraction() -> float:
	var needed := xp_needed()
	if needed <= 0:
		return 1.0
	return clampf(float(xp) / float(needed), 0.0, 1.0)


func add_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	var gained := 0
	xp += amount
	while level < MAX_LEVEL and xp >= xp_for_level(level):
		xp -= xp_for_level(level)
		level += 1
		gained += 1
		levelled_up.emit(level)
	if level >= MAX_LEVEL:
		xp = 0
	progress_changed.emit(level, xp, xp_needed())
	return gained


# ------------------------------------------------------------------- wallet

func can_afford(amount: int) -> bool:
	return money >= amount


func spend(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	money_changed.emit(money)
	return true


func earn(amount: int) -> void:
	money += amount
	money_changed.emit(money)


# ------------------------------------------------------------------ unlocks

func is_item_unlocked(item_id: String) -> bool:
	return is_shop_unlocked(Catalog.shop_of(item_id)) \
		and level >= Catalog.effective_unlock_level(item_id)


## A shop needs two things: the standing to be served, and the deeds to the
## quarter it stands in. Riverside's salvage yard does not deliver.
func is_shop_unlocked(shop_id: String) -> bool:
	var shop: Dictionary = Catalog.get_shop(shop_id)
	if shop.is_empty():
		return false
	var district := str(shop.get("district", ""))
	if district != "" and not is_district_unlocked(district):
		return false
	return level >= int(shop.get("level", 1))


func is_paint_unlocked(entry: Dictionary) -> bool:
	return level >= int(entry.get("level", 1))


# ---------------------------------------------------------------- the city

func is_district_unlocked(district_id: String) -> bool:
	return owned_districts.has(district_id)


## What buying a quarter really takes: its price, and enough left over
## afterwards to go shopping for the first brief in it.
func district_price(district_id: String) -> int:
	var district := Jobs.get_district(district_id)
	if district.is_empty():
		return 0
	return int(district["cost"]) + Jobs.district_float(district_id)


## A quarter can only be bought once the player has the standing to work in it.
func can_unlock_district(district_id: String) -> bool:
	var district := Jobs.get_district(district_id)
	if district.is_empty() or is_district_unlocked(district_id):
		return false
	return level >= int(district["level"]) and can_afford(district_price(district_id))


## Buys a quarter of the city outright. All or nothing, like everything else.
func unlock_district(district_id: String) -> bool:
	if not can_unlock_district(district_id):
		return false
	if not spend(int(Jobs.get_district(district_id)["cost"])):
		return false
	owned_districts[district_id] = true
	save_profile()
	district_unlocked.emit(district_id)
	return true


## Maple Quarter came with the business, and so does anything else priced at
## nothing — including quarters added to the game after a profile was written.
func _grant_free_districts() -> void:
	for district: Dictionary in Jobs.districts():
		if int(district["cost"]) <= 0:
			owned_districts[str(district["id"])] = true


# -------------------------------------------------------------------- stock

func stock_of(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


func total_stock() -> int:
	var total := 0
	for count: int in inventory.values():
		total += count
	return total


## Value of everything sitting unused in the warehouse.
func stock_value() -> int:
	var total := 0
	for item_id: String in inventory:
		total += Catalog.price(item_id) * int(inventory[item_id])
	return total


func owned_item_ids() -> Array[String]:
	var out: Array[String] = []
	for item_id in Catalog.ids():
		if stock_of(item_id) > 0:
			out.append(item_id)
	return out


## Buys `count` of an item into the warehouse. All or nothing.
func buy_item(item_id: String, count: int = 1) -> bool:
	if count <= 0 or not is_item_unlocked(item_id):
		return false
	var cost := Catalog.price(item_id) * count
	if not spend(cost):
		return false
	inventory[item_id] = stock_of(item_id) + count
	stock_changed.emit()
	save_profile()
	return true


## Sells stock back at the price it was bought for, so a mistake at the shop
## never costs the player anything.
func sell_item(item_id: String, count: int = 1) -> int:
	var sellable: int = mini(count, stock_of(item_id))
	if sellable <= 0:
		return 0
	var refund := Catalog.price(item_id) * sellable
	_set_stock(item_id, stock_of(item_id) - sellable)
	earn(refund)
	stock_changed.emit()
	save_profile()
	return refund


## Placing a piece in a room. Returns false when the warehouse is empty.
func take_from_stock(item_id: String) -> bool:
	if stock_of(item_id) <= 0:
		return false
	_set_stock(item_id, stock_of(item_id) - 1)
	stock_changed.emit()
	return true


## Taking a piece back out of a room.
func return_to_stock(item_id: String, count: int = 1) -> void:
	if count <= 0:
		return
	inventory[item_id] = stock_of(item_id) + count
	stock_changed.emit()


func _set_stock(item_id: String, count: int) -> void:
	if count <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = count


# -------------------------------------------------------------------- paint

static func paint_key(surface: String, paint_name: String) -> String:
	return "%s/%s" % [surface, paint_name]


func owns_paint(surface: String, paint_name: String) -> bool:
	return owned_paints.has(paint_key(surface, paint_name))


## Finds the palette entry a colour belongs to, or an empty dictionary.
func paint_entry_for(surface: String, color: Color) -> Dictionary:
	for entry: Dictionary in Catalog.PAINT[surface]:
		var target: Color = entry["color"]
		if Vector3(color.r - target.r, color.g - target.g, color.b - target.b).length() < 0.01:
			return entry
	return {}


func owns_color(surface: String, color: Color) -> bool:
	var entry := paint_entry_for(surface, color)
	return not entry.is_empty() and owns_paint(surface, str(entry["name"]))


func buy_paint(surface: String, entry: Dictionary) -> bool:
	if not is_paint_unlocked(entry):
		return false
	var paint_name := str(entry["name"])
	if owns_paint(surface, paint_name):
		return true
	if not spend(Catalog.paint_price(entry)):
		return false
	owned_paints[paint_key(surface, paint_name)] = true
	stock_changed.emit()
	save_profile()
	return true


## The plainest colour in each palette comes with the toolbox.
func _grant_starter_paints() -> void:
	for surface: String in ["floor", "wall"]:
		var first: Dictionary = Catalog.PAINT[surface][0]
		owned_paints[paint_key(surface, str(first["name"]))] = true


# --------------------------------------------------------------------- jobs

func is_job_done(house_id: String) -> bool:
	return finished_jobs.has(house_id)


func jobs_done() -> int:
	var total := 0
	for house_id: String in repeats:
		total += int(repeats[house_id])
	return total


func repeat_count(house_id: String) -> int:
	return int(repeats.get(house_id, 0))


## Takes a fresh brief at a house that has already been finished once. The room
## is emptied back into stock by the caller before this is called.
func take_repeat_contract(house_id: String, contract: Dictionary) -> void:
	active_contracts[house_id] = contract
	finished_jobs.erase(house_id)
	saved_jobs.erase(house_id)
	save_profile()


func record_completion(house_id: String, payout: int, bonus: int, xp_reward: int, installed: int, stars: int = 1) -> Dictionary:
	var levels_gained := add_xp(xp_reward)
	earn(payout + bonus)
	var result := {
		"payout": payout,
		"bonus": bonus,
		"xp": xp_reward,
		"installed": installed,
		"levels": levels_gained,
		"stars": stars,
	}
	finished_jobs[house_id] = result
	repeats[house_id] = repeat_count(house_id) + 1
	active_contracts.erase(house_id)
	save_profile()
	return result


# ----------------------------------------------------------------- the estate

func material_count(id: String) -> int:
	return int(materials.get(id, 0))


func good_count(id: String) -> int:
	return int(goods.get(id, 0))


## How far a holding has been worked up. Zero means it is not yours yet.
func site_tier(id: String) -> int:
	return int(sites.get(id, 0))


func works_tier(id: String) -> int:
	return int(plants.get(id, 0))


## How far a piece of furniture has been improved at the bench.
func quality_of(item_id: String) -> int:
	return int(quality.get(item_id, 0))


## What the next step on a holding or a works costs. The first is the asking
## price; working it up again costs more each time.
static func step_price(base: int, tier: int) -> int:
	return int(round(float(base) * pow(1.75, float(tier)) / 50.0)) * 50


func can_take_site(id: String) -> bool:
	var site: Dictionary = Industry.get_site(id)
	if site.is_empty():
		return false
	var tier := site_tier(id)
	if tier >= Industry.MAX_TIER:
		return false
	return level >= int(site["level"]) and can_afford(step_price(int(site["cost"]), tier))


## Buys a holding, or works the one you have up a level.
func take_site(id: String) -> bool:
	if not can_take_site(id):
		return false
	var site: Dictionary = Industry.get_site(id)
	var tier := site_tier(id)
	if not spend(step_price(int(site["cost"]), tier)):
		return false
	# Settle first, so working a holding up does not pay the old rate for the
	# hours since it was last looked at, and start the new rate from now.
	settle_estate()
	sites[id] = tier + 1
	site_since[id] = now()
	save_profile()
	estate_changed.emit()
	return true


func can_take_works(id: String) -> bool:
	var plant: Dictionary = Industry.get_works(id)
	if plant.is_empty():
		return false
	var tier := works_tier(id)
	if tier >= Industry.MAX_TIER:
		return false
	return level >= int(plant["level"]) and can_afford(step_price(int(plant["cost"]), tier))


func take_works(id: String) -> bool:
	if not can_take_works(id):
		return false
	var plant: Dictionary = Industry.get_works(id)
	var tier := works_tier(id)
	if not spend(step_price(int(plant["cost"]), tier)):
		return false
	plants[id] = tier + 1
	save_profile()
	estate_changed.emit()
	return true


# ------------------------------------------------------------ ground and time

## The wall clock the estate runs on. The offset is a seam for the tests, which
## have to be able to let a week pass without waiting a week.
func now() -> float:
	return Time.get_unix_time_from_system() + clock_offset


## Brings every holding up to date with the clock. Cheap enough to call
## whenever anything is about to be looked at, and the only thing that ever
## moves material: nothing ticks in the background, and the app being shut
## makes no difference to what is waiting when it opens.
func settle_estate() -> bool:
	var moved := false
	var when := now()
	for site: Dictionary in Industry.sites():
		var id := str(site["id"])
		var tier := site_tier(id)
		if tier <= 0:
			continue
		var since := float(site_since.get(id, when))
		# A clock that has gone backwards — a device set by hand, a timezone —
		# is treated as no time at all rather than as a windfall or a debt.
		var elapsed: float = clampf(when - since, 0.0, 60.0 * 60.0 * 24.0 * 30.0)
		site_since[id] = when
		if elapsed <= 0.0:
			continue
		var cap := float(Industry.hold_cap(site, tier))
		var held := float(site_stock.get(id, 0.0))
		if held >= cap:
			continue
		var grown: float = minf(cap, held + elapsed / Industry.HOUR
			* Industry.yield_per_hour(site, tier))
		if grown > held:
			site_stock[id] = grown
			moved = true
	if moved:
		estate_changed.emit()
	return moved


## What is standing at a holding, ready to be carted off.
func waiting_at(site_id: String) -> int:
	return int(floor(float(site_stock.get(site_id, 0.0))))


## And how full it is, nought to one, for a bar.
func fullness_at(site_id: String) -> float:
	var site: Dictionary = Industry.get_site(site_id)
	var tier := site_tier(site_id)
	if site.is_empty() or tier <= 0:
		return 0.0
	var cap := float(Industry.hold_cap(site, tier))
	if cap <= 0.0:
		return 0.0
	return clampf(float(site_stock.get(site_id, 0.0)) / cap, 0.0, 1.0)


## What the yard will take of one material. Every tier of every holding that
## yields it adds to the pile it can stand on.
func material_cap(id: String) -> int:
	var tiers := 0
	for site: Dictionary in Industry.sites():
		if str(site["yields"]) == id:
			tiers += site_tier(str(site["id"]))
	return Industry.YARD_BASE + Industry.YARD_PER_TIER * tiers


## And of one finished good, which is what the works it comes from will hold.
func good_cap(id: String) -> int:
	var plant: Dictionary = Industry.works_for(id)
	if plant.is_empty():
		return Industry.STORE_BASE
	return Industry.STORE_BASE + Industry.STORE_PER_TIER * works_tier(str(plant["id"]))


## Carts what is waiting at a holding into the yard. A full yard takes what it
## can and the rest stays in the ground — which is the point of the cap, and of
## working a second holding up so the yard will hold more.
func collect_site(site_id: String) -> int:
	settle_estate()
	var site: Dictionary = Industry.get_site(site_id)
	if site.is_empty() or site_tier(site_id) <= 0:
		return 0
	var waiting := waiting_at(site_id)
	if waiting <= 0:
		return 0
	var material := str(site["yields"])
	var room: int = maxi(material_cap(material) - material_count(material), 0)
	var taken: int = mini(waiting, room)
	if taken <= 0:
		return 0
	site_stock[site_id] = float(site_stock.get(site_id, 0.0)) - float(taken)
	materials[material] = material_count(material) + taken
	save_profile()
	estate_changed.emit()
	return taken


# ------------------------------------------------------------ the merchant

func supply_count(id: String) -> int:
	return int(supplies.get(id, 0))


## Buys trade material by the unit. All or nothing, like everything else.
func buy_supply(id: String, count: int = 1) -> bool:
	if count <= 0 or Catalog.get_trade(id).is_empty():
		return false
	if not spend(Catalog.trade_price(id) * count):
		return false
	supplies[id] = supply_count(id) + count
	save_profile()
	estate_changed.emit()
	return true


## Sells it back at what it cost, so a mistake at the merchant costs nothing —
## the same deal the furniture shops give.
func sell_supply(id: String, count: int = 1) -> int:
	var sellable: int = mini(count, supply_count(id))
	if sellable <= 0:
		return 0
	supplies[id] = supply_count(id) - sellable
	earn(Catalog.trade_price(id) * sellable)
	save_profile()
	estate_changed.emit()
	return sellable


# ------------------------------------------------------------- the workshop

## Whether the store holds everything one of these would take.
func can_make(item_id: String) -> bool:
	if not is_item_unlocked(item_id):
		return false
	var bill := Catalog.bill_of(item_id)
	if bill.is_empty():
		return false
	for material: String in bill:
		if supply_count(material) < int(bill[material]):
			return false
	return true


## What is still short, as material id -> units, for a piece you cannot make.
func short_for(item_id: String) -> Dictionary:
	var short: Dictionary = {}
	for material: String in Catalog.bill_of(item_id):
		var gap: int = int(Catalog.bill_of(item_id)[material]) - supply_count(material)
		if gap > 0:
			short[material] = gap
	return short


## Puts a piece on the bench. The materials go in now — they are in the piece,
## not in the store — and it comes off finished when its time is up.
func start_making(item_id: String) -> bool:
	if not can_make(item_id):
		return false
	var bill := Catalog.bill_of(item_id)
	for material: String in bill:
		supplies[material] = supply_count(material) - int(bill[material])
	# One at a time: the queue starts when whatever is in front of it finishes.
	var free_at := now()
	for entry: Variant in making:
		free_at = maxf(free_at, float((entry as Dictionary)["ready_at"]))
	making.append({
		"id": item_id,
		"ready_at": free_at + Catalog.make_seconds(item_id),
	})
	save_profile()
	estate_changed.emit()
	stock_changed.emit()
	return true


## Everything on the bench that is finished, moved into the warehouse. Making
## something teaches you as much as fitting it does.
func collect_made() -> int:
	var when := now()
	var taken := 0
	var still: Array = []
	for entry: Variant in making:
		var job: Dictionary = entry
		if float(job["ready_at"]) > when:
			still.append(job)
			continue
		var item_id := str(job["id"])
		inventory[item_id] = stock_of(item_id) + 1
		add_xp(Catalog.make_xp(item_id))
		taken += 1
	making = still
	if taken > 0:
		save_profile()
		estate_changed.emit()
		stock_changed.emit()
	return taken


## How many are finished and waiting to be taken off.
func made_waiting() -> int:
	var when := now()
	var ready := 0
	for entry: Variant in making:
		if float((entry as Dictionary)["ready_at"]) <= when:
			ready += 1
	return ready


## Seconds until the next one comes off, or -1.0 when the bench is clear.
func making_left() -> float:
	var soonest := -1.0
	var when := now()
	for entry: Variant in making:
		var left: float = float((entry as Dictionary)["ready_at"]) - when
		if left > 0.0 and (soonest < 0.0 or left < soonest):
			soonest = left
	return soonest


# --------------------------------------------------------------- the works

## How many a works could put through in one run right now: one per tier, and
## no more than the yard can feed it.
func batches_available(works_id: String) -> int:
	var plant: Dictionary = Industry.get_works(works_id)
	if plant.is_empty() or works_tier(works_id) <= 0:
		return 0
	if batches.has(works_id):
		return 0
	var good: Dictionary = Industry.get_good(str(plant["makes"]))
	var takes := int(good["takes"])
	if takes <= 0:
		return 0
	var room: int = maxi(good_cap(str(good["id"])) - good_count(str(good["id"])), 0)
	return mini(mini(works_tier(works_id), material_count(str(good["from"])) / takes), room)


## Puts a run on. The material goes in now — it is in the machine, not in the
## yard — and the goods come off when the run is done.
func run_works(works_id: String) -> int:
	var plant: Dictionary = Industry.get_works(works_id)
	if plant.is_empty():
		return 0
	var count := batches_available(works_id)
	if count <= 0:
		return 0
	var good: Dictionary = Industry.get_good(str(plant["makes"]))
	var material := str(good["from"])
	materials[material] = material_count(material) - count * int(good["takes"])
	batches[works_id] = {
		"made": count,
		"ready_at": now() + Industry.batch_seconds(works_id),
	}
	save_profile()
	estate_changed.emit()
	return count


## Seconds left on the run, or -1.0 when there is nothing on.
func batch_left(works_id: String) -> float:
	if not batches.has(works_id):
		return -1.0
	return maxf(float((batches[works_id] as Dictionary)["ready_at"]) - now(), 0.0)


func batch_ready(works_id: String) -> bool:
	return batches.has(works_id) and batch_left(works_id) <= 0.0


func batch_size(works_id: String) -> int:
	if not batches.has(works_id):
		return 0
	return int((batches[works_id] as Dictionary)["made"])


## Takes a finished run off the works. What will not fit in the store stays on
## the works floor until there is room for it.
func collect_batch(works_id: String) -> int:
	if not batch_ready(works_id):
		return 0
	var plant: Dictionary = Industry.get_works(works_id)
	var made := str((Industry.get_good(str(plant["makes"])))["id"])
	var count := batch_size(works_id)
	var room: int = maxi(good_cap(made) - good_count(made), 0)
	var taken: int = mini(count, room)
	if taken <= 0:
		return 0
	goods[made] = good_count(made) + taken
	if taken >= count:
		batches.erase(works_id)
	else:
		(batches[works_id] as Dictionary)["made"] = count - taken
	save_profile()
	estate_changed.emit()
	return taken


## How long is left, as something to put on a button.
static func spell_out(seconds: float) -> String:
	var whole: int = int(ceil(maxf(seconds, 0.0)))
	if whole >= 3600:
		return "%dh %02dm" % [whole / 3600, (whole % 3600) / 60]
	if whole >= 60:
		return "%dm %02ds" % [whole / 60, whole % 60]
	return "%ds" % whole


## True when the bench could improve this piece a step further right now.
func can_improve(item_id: String) -> bool:
	var cost: Dictionary = Industry.upgrade_cost(item_id)
	if cost.is_empty():
		return false
	return good_count(str(cost["good"])) >= int(cost["goods"]) \
		and can_afford(int(cost["money"]))


## Takes a piece up one tier. Every copy of that piece follows — the bench
## improves the pattern, not the one on the trolley.
func improve(item_id: String) -> bool:
	if not can_improve(item_id):
		return false
	var cost: Dictionary = Industry.upgrade_cost(item_id)
	if not spend(int(cost["money"])):
		return false
	var good := str(cost["good"])
	goods[good] = good_count(good) - int(cost["goods"])
	quality[item_id] = int(cost["tier"])
	save_profile()
	estate_changed.emit()
	stock_changed.emit()
	return true


func store_layout(house_id: String, data: Dictionary) -> void:
	saved_jobs[house_id] = data
	save_profile()


func layout_for(house_id: String) -> Dictionary:
	return saved_jobs.get(house_id, {})


# -------------------------------------------------------------- persistence

func reset() -> void:
	money = STARTING_MONEY
	xp = 0
	level = 1
	inventory.clear()
	owned_paints.clear()
	finished_jobs.clear()
	saved_jobs.clear()
	active_contracts.clear()
	repeats.clear()
	owned_districts.clear()
	materials.clear()
	goods.clear()
	sites.clear()
	plants.clear()
	quality.clear()
	site_stock.clear()
	site_since.clear()
	batches.clear()
	supplies.clear()
	making.clear()
	_grant_starter_paints()
	_grant_free_districts()
	save_profile()
	money_changed.emit(money)
	stock_changed.emit()
	progress_changed.emit(level, xp, xp_needed())


func save_profile() -> void:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save the profile (%d)" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({
		"version": 6,
		"money": money,
		"xp": xp,
		"level": level,
		"inventory": inventory,
		"paints": owned_paints,
		"finished": finished_jobs,
		"saved": saved_jobs,
		"contracts": active_contracts,
		"repeats": repeats,
		"districts": owned_districts,
		"materials": materials,
		"goods": goods,
		"sites": sites,
		"plants": plants,
		"quality": quality,
		"site_stock": site_stock,
		"site_since": site_since,
		"batches": batches,
		"supplies": supplies,
		"making": making,
	}, "\t"))
	file.close()


func load_profile() -> void:
	if not FileAccess.file_exists(PROFILE_PATH):
		return
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Profile file is malformed; starting a fresh career.")
		return
	var data: Dictionary = parsed
	money = int(data.get("money", STARTING_MONEY))
	xp = int(data.get("xp", 0))
	level = clampi(int(data.get("level", 1)), 1, MAX_LEVEL)
	finished_jobs = data.get("finished", {})
	saved_jobs = data.get("saved", {})
	active_contracts = data.get("contracts", {})
	repeats = data.get("repeats", {})
	# Profiles written before the city had quarters simply own none of them;
	# _grant_free_districts() hands back the one everybody starts with.
	owned_districts = data.get("districts", {})
	# Profiles written before the estate existed simply have none of it, and
	# start with nothing bought and nothing in the yard.
	materials = data.get("materials", {})
	goods = data.get("goods", {})
	sites = data.get("sites", {})
	plants = data.get("plants", {})
	quality = data.get("quality", {})
	# Profiles written before the estate ran on a clock have no timestamps, so
	# every holding they own starts filling from the moment they are opened
	# rather than being paid for the time the feature did not exist.
	site_stock = data.get("site_stock", {})
	site_since = data.get("site_since", {})
	batches = data.get("batches", {})
	supplies = data.get("supplies", {})
	making = data.get("making", [])
	var opened := now()
	for site: Dictionary in Industry.sites():
		var site_id := str(site["id"])
		if site_tier(site_id) > 0 and not site_since.has(site_id):
			site_since[site_id] = opened
	# Counts come back from JSON as floats.
	inventory = {}
	for item_id: String in data.get("inventory", {}):
		_set_stock(item_id, int(data["inventory"][item_id]))
	owned_paints = data.get("paints", {})
