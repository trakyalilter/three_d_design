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

const PROFILE_PATH := "user://profile.json"
const STARTING_MONEY := 3000
const MAX_LEVEL := 8

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


func _ready() -> void:
	load_profile()
	_grant_starter_paints()


# ---------------------------------------------------------------- levelling

## Experience needed to get from `from_level` to the next one.
static func xp_for_level(from_level: int) -> int:
	return 120 + (from_level - 1) * 110


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
	return level >= Catalog.effective_unlock_level(item_id)


func is_shop_unlocked(shop_id: String) -> bool:
	var shop: Dictionary = Catalog.get_shop(shop_id)
	return level >= int(shop.get("level", 1))


func is_paint_unlocked(entry: Dictionary) -> bool:
	return level >= int(entry.get("level", 1))


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
	return finished_jobs.size()


func record_completion(house_id: String, payout: int, bonus: int, xp_reward: int, installed: int) -> Dictionary:
	var levels_gained := add_xp(xp_reward)
	earn(payout + bonus)
	var result := {
		"payout": payout,
		"bonus": bonus,
		"xp": xp_reward,
		"installed": installed,
		"levels": levels_gained,
	}
	finished_jobs[house_id] = result
	save_profile()
	return result


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
	_grant_starter_paints()
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
		"version": 2,
		"money": money,
		"xp": xp,
		"level": level,
		"inventory": inventory,
		"paints": owned_paints,
		"finished": finished_jobs,
		"saved": saved_jobs,
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
	# Counts come back from JSON as floats.
	inventory = {}
	for item_id: String in data.get("inventory", {}):
		_set_stock(item_id, int(data["inventory"][item_id]))
	owned_paints = data.get("paints", {})
