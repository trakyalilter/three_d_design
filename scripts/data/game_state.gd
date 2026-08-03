extends Node
## The player's career: money, experience, level, and which jobs are done.
##
## Autoloaded as `Game`. Everything here persists to user://profile.json so a
## session survives closing the app.

signal money_changed(amount: int)
signal progress_changed(level: int, xp: int, xp_needed: int)
signal levelled_up(level: int)

const PROFILE_PATH := "user://profile.json"
const STARTING_MONEY := 3000
const MAX_LEVEL := 8

var money: int = STARTING_MONEY
var xp: int = 0
var level: int = 1

## house id -> {"payout": int, "xp": int, "spend": int, "bonus": int}
var finished_jobs: Dictionary = {}
## house id -> serialized layout, so an unfinished job can be resumed.
var saved_jobs: Dictionary = {}
## house id -> money already sunk into that job, refundable until it is handed in.
var job_spend: Dictionary = {}


func _ready() -> void:
	load_profile()


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


# --------------------------------------------------------------------- jobs

func is_job_done(house_id: String) -> bool:
	return finished_jobs.has(house_id)


func jobs_done() -> int:
	return finished_jobs.size()


func spend_on(house_id: String) -> int:
	return int(job_spend.get(house_id, 0))


## Buying for a job: takes the money and remembers it against the house so it
## can be refunded if the player changes their mind.
func charge_to_job(house_id: String, amount: int) -> bool:
	if not spend(amount):
		return false
	job_spend[house_id] = spend_on(house_id) + amount
	return true


## Selling something back gives the full price; the player is never punished
## for rearranging.
func refund_to_job(house_id: String, amount: int) -> void:
	earn(amount)
	job_spend[house_id] = maxi(spend_on(house_id) - amount, 0)


func record_completion(house_id: String, payout: int, bonus: int, xp_reward: int) -> Dictionary:
	var levels_gained := add_xp(xp_reward)
	earn(payout + bonus)
	var result := {
		"payout": payout,
		"bonus": bonus,
		"xp": xp_reward,
		"spend": spend_on(house_id),
		"levels": levels_gained,
	}
	finished_jobs[house_id] = result
	job_spend.erase(house_id)
	save_profile()
	return result


func store_layout(house_id: String, data: Dictionary) -> void:
	saved_jobs[house_id] = data
	save_profile()


func layout_for(house_id: String) -> Dictionary:
	return saved_jobs.get(house_id, {})


## Walking away from a job: the furniture goes back to the shops and the money
## returns to the player.
func abandon_job(house_id: String) -> int:
	var refund := spend_on(house_id)
	if refund > 0:
		earn(refund)
	job_spend.erase(house_id)
	saved_jobs.erase(house_id)
	save_profile()
	return refund


# -------------------------------------------------------------- persistence

func reset() -> void:
	money = STARTING_MONEY
	xp = 0
	level = 1
	finished_jobs.clear()
	saved_jobs.clear()
	job_spend.clear()
	save_profile()
	money_changed.emit(money)
	progress_changed.emit(level, xp, xp_needed())


func save_profile() -> void:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save the profile (%d)" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({
		"version": 1,
		"money": money,
		"xp": xp,
		"level": level,
		"finished": finished_jobs,
		"saved": saved_jobs,
		"spend": job_spend,
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
	job_spend = data.get("spend", {})
