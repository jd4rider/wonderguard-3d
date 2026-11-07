extends Node
## Local-first save data for Wonderguard 3D.
##
## Written to `user://` after every meaningful event and mirrored to the Little
## Joy Arcade cloud save when a player is signed in. The schema is versioned,
## merged with defaults on load, and a corrupt file is backed up rather than
## deleted.

signal changed
signal achievement_unlocked(id: String)

const SAVE_PATH := "user://wonderguard_save.json"
const BACKUP_PATH := "user://wonderguard_save.corrupt.json"
const SCHEMA_VERSION := 1

## One hundred trophies, evaluated from tracked statistics so the whole list is
## data rather than a hundred bespoke checks.
const ACHIEVEMENTS: Array = [
	{"id": "first_win", "name": "First Line of Defense", "hint": "Win a battle.", "stat": "levels", "need": 1},
	{"id": "lvl_5", "name": "Tiny Tower, Big Victory", "hint": "Clear five levels.", "stat": "levels", "need": 5},
	{"id": "lvl_10", "name": "Neighbourhood Watch", "hint": "Clear ten levels.", "stat": "levels", "need": 10},
	{"id": "lvl_25", "name": "Standing Guard", "hint": "Clear twenty-five levels.", "stat": "levels", "need": 25},
	{"id": "lvl_50", "name": "Half a Kingdom", "hint": "Clear fifty levels.", "stat": "levels", "need": 50},
	{"id": "lvl_100", "name": "Hundred-Level Hero", "hint": "Clear one hundred levels.", "stat": "levels", "need": 100},
	{"id": "lvl_250", "name": "Quarter of the World", "hint": "Clear 250 levels.", "stat": "levels", "need": 250},
	{"id": "lvl_500", "name": "Five Hundred Victories", "hint": "Clear 500 levels.", "stat": "levels", "need": 500},
	{"id": "lvl_750", "name": "Almost Everything", "hint": "Clear 750 levels.", "stat": "levels", "need": 750},
	{"id": "lvl_1000", "name": "Wonderguard Champion", "hint": "Clear all 1,000 levels.", "stat": "levels", "need": 1000},
	{"id": "stars_1", "name": "One Bright Star", "hint": "Earn a star.", "stat": "stars", "need": 1},
	{"id": "stars_10", "name": "Star Cabinet", "hint": "Earn ten stars.", "stat": "stars", "need": 10},
	{"id": "stars_50", "name": "Constellation", "hint": "Earn fifty stars.", "stat": "stars", "need": 50},
	{"id": "stars_150", "name": "Night Sky", "hint": "Earn 150 stars.", "stat": "stars", "need": 150},
	{"id": "stars_500", "name": "Star Sovereign", "hint": "Earn 500 stars.", "stat": "stars", "need": 500},
	{"id": "stars_1500", "name": "Whole Sky", "hint": "Earn 1,500 stars.", "stat": "stars", "need": 1500},
	{"id": "stars_3000", "name": "Every Star", "hint": "Earn 3,000 stars.", "stat": "stars", "need": 3000},
	{"id": "perfect_1", "name": "Perfect Defense", "hint": "Win without losing a life.", "stat": "perfect", "need": 1},
	{"id": "perfect_10", "name": "Nothing Gets Through", "hint": "Ten flawless victories.", "stat": "perfect", "need": 10},
	{"id": "perfect_50", "name": "Impenetrable", "hint": "Fifty flawless victories.", "stat": "perfect", "need": 50},
	{"id": "boss_1", "name": "Boss Breaker", "hint": "Defeat a kingdom boss.", "stat": "bosses", "need": 1},
	{"id": "boss_3", "name": "Crown Collector", "hint": "Defeat three bosses.", "stat": "bosses", "need": 3},
	{"id": "boss_5", "name": "Regicide", "hint": "Defeat five bosses.", "stat": "bosses", "need": 5},
	{"id": "boss_10", "name": "Half the Crowns", "hint": "Defeat ten bosses.", "stat": "bosses", "need": 10},
	{"id": "boss_15", "name": "Crownbreaker", "hint": "Defeat fifteen bosses.", "stat": "bosses", "need": 15},
	{"id": "boss_20", "name": "All Crowns", "hint": "Defeat all twenty bosses.", "stat": "bosses", "need": 20},
	{"id": "build_1", "name": "Raise the Wall", "hint": "Build a tower.", "stat": "built", "need": 1},
	{"id": "build_10", "name": "Mason", "hint": "Build ten towers.", "stat": "built", "need": 10},
	{"id": "build_50", "name": "Town Planner", "hint": "Build fifty towers.", "stat": "built", "need": 50},
	{"id": "build_200", "name": "Fortress Architect", "hint": "Build 200 towers.", "stat": "built", "need": 200},
	{"id": "build_500", "name": "Wonderguard", "hint": "Build 500 towers.", "stat": "built", "need": 500},
	{"id": "upgrade_1", "name": "A Little Better", "hint": "Upgrade a tower.", "stat": "upgrades", "need": 1},
	{"id": "upgrade_10", "name": "Tuned Up", "hint": "Upgrade ten times.", "stat": "upgrades", "need": 10},
	{"id": "upgrade_50", "name": "Better Every Time", "hint": "Upgrade fifty times.", "stat": "upgrades", "need": 50},
	{"id": "upgrade_150", "name": "Overengineer", "hint": "Upgrade 150 times.", "stat": "upgrades", "need": 150},
	{"id": "ultimate_1", "name": "Choose a Path", "hint": "Take a tower to its ultimate.", "stat": "ultimates", "need": 1},
	{"id": "ultimate_5", "name": "Both Paths", "hint": "Unlock five ultimates.", "stat": "ultimates", "need": 5},
	{"id": "ultimate_15", "name": "Evolutionist", "hint": "Unlock fifteen ultimates.", "stat": "ultimates", "need": 15},
	{"id": "ultimate_24", "name": "Every Evolution", "hint": "Unlock all 26 tower ultimates.", "stat": "ultimates", "need": 26},
	{"id": "towers_6", "name": "Six of a Kind", "hint": "Build six different towers.", "stat": "tower_types", "need": 6},
	{"id": "towers_12", "name": "Collector of Towers", "hint": "Build twelve different towers.", "stat": "tower_types", "need": 12},
	{"id": "towers_18", "name": "Full Shelf", "hint": "Build eighteen different towers.", "stat": "tower_types", "need": 18},
	{"id": "towers_24", "name": "The Whole Toybox", "hint": "Build all 26 tower families.", "stat": "tower_types", "need": 26},
	{"id": "kills_100", "name": "Pest Control", "hint": "Defeat 100 enemies.", "stat": "kills", "need": 100},
	{"id": "kills_1000", "name": "Clean Streets", "hint": "Defeat 1,000 enemies.", "stat": "kills", "need": 1000},
	{"id": "kills_5000", "name": "Very Tidy", "hint": "Defeat 5,000 enemies.", "stat": "kills", "need": 5000},
	{"id": "kills_20000", "name": "No One Left", "hint": "Defeat 20,000 enemies.", "stat": "kills", "need": 20000},
	{"id": "waves_50", "name": "Hold the Line", "hint": "Clear fifty waves.", "stat": "waves", "need": 50},
	{"id": "waves_250", "name": "Long Watch", "hint": "Clear 250 waves.", "stat": "waves", "need": 250},
	{"id": "waves_1000", "name": "Siege Veteran", "hint": "Clear 1,000 waves.", "stat": "waves", "need": 1000},
	{"id": "gold_1000", "name": "Battle Treasury", "hint": "Earn 1,000 battle gold.", "stat": "gold", "need": 1000},
	{"id": "gold_25000", "name": "War Chest", "hint": "Earn 25,000 battle gold.", "stat": "gold", "need": 25000},
	{"id": "gold_100000", "name": "Kingdom Reserve", "hint": "Earn 100,000 battle gold.", "stat": "gold", "need": 100000},
	{"id": "enemies_12", "name": "Bestiary Beginner", "hint": "Defeat twelve enemy types.", "stat": "enemy_types", "need": 12},
	{"id": "enemies_24", "name": "Field Naturalist", "hint": "Defeat 24 enemy types.", "stat": "enemy_types", "need": 24},
	{"id": "enemies_36", "name": "Monster Scholar", "hint": "Defeat 36 enemy types.", "stat": "enemy_types", "need": 36},
	{"id": "enemies_48", "name": "Complete Bestiary", "hint": "Defeat all 48 enemy types.", "stat": "enemy_types", "need": 48},
	{"id": "kingdom_1", "name": "Emerald Guard", "hint": "Clear a level in Emerald Meadows.", "stat": "kingdoms", "need": 1},
	{"id": "kingdom_3", "name": "Traveller", "hint": "Clear levels in three kingdoms.", "stat": "kingdoms", "need": 3},
	{"id": "kingdom_5", "name": "Cartographer", "hint": "Clear levels in five kingdoms.", "stat": "kingdoms", "need": 5},
	{"id": "kingdom_10", "name": "Half the Map", "hint": "Clear levels in ten kingdoms.", "stat": "kingdoms", "need": 10},
	{"id": "kingdom_15", "name": "Wide World", "hint": "Clear levels in fifteen kingdoms.", "stat": "kingdoms", "need": 15},
	{"id": "kingdom_20", "name": "Map Complete", "hint": "Clear levels in all twenty kingdoms.", "stat": "kingdoms", "need": 20},
	{"id": "endless_5", "name": "Deep Siege", "hint": "Reach wave five in Endless Siege.", "stat": "endless", "need": 5},
	{"id": "endless_10", "name": "No Horizon", "hint": "Reach wave ten in Endless Siege.", "stat": "endless", "need": 10},
	{"id": "endless_20", "name": "Beyond the Wall", "hint": "Reach wave twenty in Endless Siege.", "stat": "endless", "need": 20},
	{"id": "endless_30", "name": "Siege Eternal", "hint": "Reach wave thirty in Endless Siege.", "stat": "endless", "need": 30},
	{"id": "survival_1", "name": "Just Survive", "hint": "Win a Survival run.", "stat": "survival", "need": 1},
	{"id": "survival_5", "name": "Still Standing", "hint": "Win five Survival runs.", "stat": "survival", "need": 5},
	{"id": "bossrush_1", "name": "Rush Hour", "hint": "Finish Boss Rush.", "stat": "bossrush", "need": 1},
	{"id": "bossrush_3", "name": "Crown Parade", "hint": "Finish Boss Rush three times.", "stat": "bossrush", "need": 3},
	{"id": "daily_1", "name": "Same Day", "hint": "Finish a Daily Defense.", "stat": "daily", "need": 1},
	{"id": "daily_7", "name": "A Week of It", "hint": "Finish seven Daily Defenses.", "stat": "daily", "need": 7},
	{"id": "daily_30", "name": "Daily Habit", "hint": "Finish thirty Daily Defenses.", "stat": "daily", "need": 30},
	{"id": "sandbox_1", "name": "Let Me Try Something", "hint": "Open Sandbox.", "stat": "sandbox", "need": 1},
	{"id": "waves_one_run_20", "name": "Long Night", "hint": "Clear twenty waves in one run.", "stat": "best_waves", "need": 20},
	{"id": "waves_one_run_40", "name": "Marathon Watch", "hint": "Clear forty waves in one run.", "stat": "best_waves", "need": 40},
	{"id": "tier3_25", "name": "Third Tier", "hint": "Reach tier three 25 times.", "stat": "tier3", "need": 25},
	{"id": "tier3_100", "name": "Tier Three Habit", "hint": "Reach tier three 100 times.", "stat": "tier3", "need": 100},
	{"id": "leaks_1", "name": "First Scratch", "hint": "Lose a life.", "stat": "leaks", "need": 1},
	{"id": "leaks_100", "name": "Well Loved Castle", "hint": "Lose 100 lives in total.", "stat": "leaks", "need": 100},
	{"id": "gold_bonus_10", "name": "Early Bird", "hint": "Call ten waves early.", "stat": "early", "need": 10},
	{"id": "gold_bonus_100", "name": "Impatient", "hint": "Call one hundred waves early.", "stat": "early", "need": 100},
	{"id": "sell_25", "name": "Change of Plan", "hint": "Sell 25 towers.", "stat": "sold", "need": 25},
	{"id": "sell_100", "name": "Redeveloper", "hint": "Sell 100 towers.", "stat": "sold", "need": 100},
	{"id": "summon_50", "name": "Tiny Army", "hint": "Summon 50 defenders.", "stat": "summons", "need": 50},
	{"id": "chain_500", "name": "Chain Reaction", "hint": "Land 500 chain hits.", "stat": "chains", "need": 500},
	{"id": "freeze_200", "name": "Ice Age", "hint": "Freeze 200 enemies.", "stat": "freezes", "need": 200},
	{"id": "burn_200", "name": "Slow Roast", "hint": "Burn 200 enemies.", "stat": "burns", "need": 200},
	{"id": "poison_200", "name": "Bitter Fog", "hint": "Poison 200 enemies.", "stat": "poisons", "need": 200},
	{"id": "play_1h", "name": "One More Wave", "hint": "Play for one hour.", "stat": "minutes", "need": 60},
	{"id": "play_5h", "name": "Devoted", "hint": "Play for five hours.", "stat": "minutes", "need": 300},
	{"id": "play_20h", "name": "Toybox Resident", "hint": "Play for twenty hours.", "stat": "minutes", "need": 1200},
	{"id": "credits_1000", "name": "Crown Purse", "hint": "Earn 1,000 crowns.", "stat": "credits", "need": 1000},
	{"id": "credits_10000", "name": "Royal Fortune", "hint": "Earn 10,000 crowns.", "stat": "credits", "need": 10000},
	{"id": "three_star_1", "name": "Untouched", "hint": "Earn three stars on a level.", "stat": "three_stars", "need": 1},
	{"id": "three_star_25", "name": "Flawless Planner", "hint": "Earn three stars on 25 levels.", "stat": "three_stars", "need": 25},
	{"id": "three_star_100", "name": "Three-Star General", "hint": "Earn three stars on 100 levels.", "stat": "three_stars", "need": 100},
	{"id": "three_star_500", "name": "Perfect Kingdom", "hint": "Earn three stars on 500 levels.", "stat": "three_stars", "need": 500},
	{"id": "tower_ult_both", "name": "Both Answers", "hint": "Unlock both ultimates of one tower.", "stat": "both_paths", "need": 1},
	{"id": "tower_ult_both_6", "name": "Branch Manager", "hint": "Unlock both ultimates of six towers.", "stat": "both_paths", "need": 6},
]


static func _defaults() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"created": int(Time.get_unix_time_from_system()),
		"savedAt": 0,
		"profile": {"name": "Warden"},
		"settings": {
			"music": 0.55,
			"sfx": 0.85,
			"reduced_motion": false,
			"screen_shake": true,
			"high_contrast": false,
			"tutorial_done": false,
			"quality": "auto",
		},
		"progress": {
			"stars": {},
			"credits": 0,
			"cleared": 0,
			"perfect": [],
		},
		"records": {
			"endless_wave": 0,
			"survival_best": 0,
			"bossrush_best": 0,
			"daily": {},
			"daily_streak": 0,
			"runs": 0,
			"best_waves": 0,
		},
		"achievements": {},
		"stats": {
			"levels": 0,
			"perfect": 0,
			"bosses": {},
			"built": 0,
			"upgrades": 0,
			"ultimates": 0,
			"tiers": {},
			"tower_types": {},
			"enemy_types": {},
			"kingdoms": {},
			"kills": 0,
			"waves": 0,
			"gold": 0,
			"leaks": 0,
			"early": 0,
			"sold": 0,
			"summons": 0,
			"chains": 0,
			"freezes": 0,
			"burns": 0,
			"poisons": 0,
			"minutes": 0,
			"three_stars": 0,
			"both_paths": {},
			"branches": {},
			"daily": 0,
			"endless": 0,
			"survival": 0,
			"bossrush": 0,
			"sandbox": 0,
			"best_waves": 0,
			"tier3": 0,
		},
	}


var data: Dictionary = {}
var _dirty := false
var _timer: Timer
var _writing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 0.7
	_timer.timeout.connect(flush)
	add_child(_timer)
	load_data()


func load_data() -> void:
	data = _defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		queue_save()
		return
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_backup_corrupt(text)
		queue_save()
		return
	data = _merge(parsed, _defaults())
	data["schema"] = SCHEMA_VERSION
	changed.emit()


func _backup_corrupt(text: String) -> void:
	push_warning("Wonderguard save could not be parsed; keeping a backup.")
	var file := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.close()


func _merge(target: Dictionary, defaults: Dictionary) -> Dictionary:
	for key in defaults.keys():
		if not target.has(key):
			target[key] = defaults[key]
		elif typeof(target[key]) == TYPE_DICTIONARY and typeof(defaults[key]) == TYPE_DICTIONARY:
			_merge(target[key], defaults[key])
	return target


func queue_save() -> void:
	_dirty = true
	if _timer and _timer.is_inside_tree():
		_timer.start()


func flush() -> void:
	if _writing:
		return
	_writing = true
	data["savedAt"] = int(Time.get_unix_time_from_system() * 1000.0)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.flush()
		file.close()
		_dirty = false
		if has_node("/root/Arcade"):
			get_node("/root/Arcade").on_local_save(data)
	if has_node("/root/Audio"):
		get_node("/root/Audio").apply_settings(data["settings"])
	_writing = false


func get_setting(key: String, fallback: Variant = null) -> Variant:
	if data.has("settings") and data["settings"].has(key):
		return data["settings"][key]
	return fallback


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	queue_save()
	if has_node("/root/Audio"):
		get_node("/root/Audio").apply_settings(data["settings"])
	changed.emit()


# --------------------------------------------------------------------------
# progress queries
# --------------------------------------------------------------------------

func level_stars(id: int) -> int:
	return int(data["progress"]["stars"].get(str(id), 0))


func is_level_complete(id: int) -> bool:
	return level_stars(id) > 0


func total_stars() -> int:
	var total := 0
	for value in data["progress"]["stars"].values():
		total += int(value)
	return total


func completed_levels() -> int:
	var total := 0
	for value in data["progress"]["stars"].values():
		if int(value) > 0:
			total += 1
	return total


func stars_in_kingdom(index: int) -> int:
	var total := 0
	var first := index * Campaign.LEVELS_PER_KINGDOM + 1
	for id in range(first, first + Campaign.LEVELS_PER_KINGDOM):
		total += level_stars(id)
	return total


func completed_in_kingdom(index: int) -> int:
	var total := 0
	var first := index * Campaign.LEVELS_PER_KINGDOM + 1
	for id in range(first, first + Campaign.LEVELS_PER_KINGDOM):
		if is_level_complete(id):
			total += 1
	return total


## A kingdom opens once six levels of the previous one are cleared: enough of a
## nudge forward without demanding a perfect run.
func is_kingdom_unlocked(index: int) -> bool:
	if index <= 0:
		return true
	return completed_in_kingdom(index - 1) >= 6


func highest_kingdom() -> int:
	var best := 0
	for k in range(Campaign.KINGDOM_COUNT):
		if is_kingdom_unlocked(k):
			best = k
	return best


func next_level() -> int:
	for id in range(1, Campaign.LEVEL_COUNT + 1):
		if is_level_complete(id):
			continue
		if is_kingdom_unlocked(Campaign.kingdom_index(id)):
			return id
	return Campaign.LEVEL_COUNT


func next_level_in_kingdom(index: int) -> int:
	var first := index * Campaign.LEVELS_PER_KINGDOM + 1
	for id in range(first, first + Campaign.LEVELS_PER_KINGDOM):
		if not is_level_complete(id):
			return id
	return first


func credits() -> int:
	return int(data["progress"]["credits"])


func add_credits(amount: int) -> void:
	data["progress"]["credits"] = maxi(0, credits() + amount)
	queue_save()


func spend_credits(amount: int) -> bool:
	if credits() < amount:
		return false
	data["progress"]["credits"] = credits() - amount
	queue_save()
	return true


# --------------------------------------------------------------------------
# battle results
# --------------------------------------------------------------------------

func register_build(tower_id: String) -> void:
	data["stats"]["built"] = int(data["stats"]["built"]) + 1
	var seen: Dictionary = data["stats"]["tower_types"]
	seen[tower_id] = true
	check_achievements()
	queue_save()


func register_upgrade(tower_id: String, tier: int, branch: String) -> void:
	data["stats"]["upgrades"] = int(data["stats"]["upgrades"]) + 1
	var tiers: Dictionary = data["stats"]["tiers"]
	tiers[str(tier)] = int(tiers.get(str(tier), 0)) + 1
	if tier >= 3:
		data["stats"]["tier3"] = int(data["stats"]["tier3"]) + 1
	if tier >= 4:
		data["stats"]["ultimates"] = int(data["stats"]["ultimates"]) + 1
		var branches: Dictionary = data["stats"]["branches"]
		branches["%s:%s" % [tower_id, branch]] = true
		var both: Dictionary = data["stats"]["both_paths"]
		var opposite := "b" if branch == "a" else "a"
		if branches.has("%s:%s" % [tower_id, opposite]):
			both[tower_id] = true
	data["stats"]["sold"] = int(data["stats"]["sold"])
	check_achievements()
	queue_save()


func register_sell() -> void:
	data["stats"]["sold"] = int(data["stats"]["sold"]) + 1
	queue_save()


func register_kill(enemy_id: String, gold: int, waves := 0) -> void:
	data["stats"]["kills"] = int(data["stats"]["kills"]) + 1
	data["stats"]["gold"] = int(data["stats"]["gold"]) + gold
	var seen: Dictionary = data["stats"]["enemy_types"]
	seen[enemy_id] = true
	queue_save()


func register_wave() -> void:
	data["stats"]["waves"] = int(data["stats"]["waves"]) + 1
	queue_save()


func register_leak() -> void:
	data["stats"]["leaks"] = int(data["stats"]["leaks"]) + 1
	queue_save()


func register_early() -> void:
	data["stats"]["early"] = int(data["stats"]["early"]) + 1
	queue_save()


func register_summon() -> void:
	data["stats"]["summons"] = int(data["stats"]["summons"]) + 1
	queue_save()


func register_status(kind: String) -> void:
	match kind:
		"chain":
			data["stats"]["chains"] = int(data["stats"]["chains"]) + 1
		"freeze":
			data["stats"]["freezes"] = int(data["stats"]["freezes"]) + 1
		"burn":
			data["stats"]["burns"] = int(data["stats"]["burns"]) + 1
		"poison":
			data["stats"]["poisons"] = int(data["stats"]["poisons"]) + 1
	queue_save()


## Records a finished level. Returns the ids of trophies unlocked by it.
func complete_level(id: int, stars: int, leaks: int, kills: int, waves: int) -> Array:
	var key := str(id)
	var previous := level_stars(id)
	if stars > previous:
		data["progress"]["stars"][key] = stars
	if leaks == 0:
		var perfect: Array = data["progress"]["perfect"]
		if not perfect.has(key):
			perfect.append(key)
		if previous == 0:
			data["stats"]["perfect"] = int(data["stats"]["perfect"]) + 1
	data["progress"]["cleared"] = completed_levels()
	data["progress"]["credits"] = int(data["progress"]["credits"]) + 25 + stars * 20
	data["stats"]["levels"] = completed_levels()
	data["stats"]["three_stars"] = _count_three_stars()
	var k_index := Campaign.kingdom_index(id)
	var kingdoms: Dictionary = data["stats"]["kingdoms"]
	kingdoms[str(k_index)] = true
	if Campaign.is_boss_level(id):
		(data["stats"]["bosses"] as Dictionary)[str(k_index)] = true
	data["stats"]["kills"] = int(data["stats"]["kills"]) + kills
	data["stats"]["waves"] = int(data["stats"]["waves"]) + waves
	data["stats"]["best_waves"] = maxi(int(data["stats"]["best_waves"]), waves)
	data["records"]["runs"] = int(data["records"]["runs"]) + 1
	var unlocked := check_achievements()
	queue_save()
	changed.emit()
	return unlocked


func _count_three_stars() -> int:
	var count := 0
	for value in data["progress"]["stars"].values():
		if int(value) >= 3:
			count += 1
	return count


func record_run(mode: String, value: int, kingdom_index := 0) -> Array:
	match mode:
		"endless":
			data["records"]["endless_wave"] = maxi(int(data["records"]["endless_wave"]), value)
			data["stats"]["endless"] = maxi(int(data["stats"]["endless"]), value)
		"survival":
			data["records"]["survival_best"] = maxi(int(data["records"]["survival_best"]), value)
			data["stats"]["survival"] = int(data["stats"]["survival"]) + 1
		"bossrush":
			data["records"]["bossrush_best"] = maxi(int(data["records"]["bossrush_best"]), value)
			data["stats"]["bossrush"] = int(data["stats"]["bossrush"]) + 1
		"sandbox":
			data["stats"]["sandbox"] = int(data["stats"]["sandbox"]) + 1
	data["records"]["runs"] = int(data["records"]["runs"]) + 1
	data["stats"]["best_waves"] = maxi(int(data["stats"]["best_waves"]), value)
	var unlocked := check_achievements()
	queue_save()
	changed.emit()
	return unlocked


func daily_date_key() -> String:
	var now := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [now.year, now.month, now.day]


func daily_seed() -> int:
	var value := 0
	for i in range(daily_date_key().length()):
		value = (value * 31 + daily_date_key().unicode_at(i)) % 2147483647
	return maxi(1, value)


func record_daily(score: int) -> Array:
	var key := daily_date_key()
	var entry: Dictionary = data["records"]["daily"].get(key, {"best": 0, "attempts": 0, "done": false})
	entry["best"] = maxi(int(entry.get("best", 0)), score)
	entry["attempts"] = int(entry.get("attempts", 0)) + 1
	entry["done"] = true
	data["records"]["daily"][key] = entry
	data["records"]["daily_streak"] = _streak()
	data["stats"]["daily"] = int(data["stats"]["daily"]) + 1
	var unlocked := check_achievements()
	queue_save()
	return unlocked


func _streak() -> int:
	var streak := 0
	var now := int(Time.get_unix_time_from_system())
	for i in range(120):
		var stamp := now - i * 86400
		var d := Time.get_datetime_dict_from_unix_time(stamp)
		var key := "%04d-%02d-%02d" % [d.year, d.month, d.day]
		var entry: Variant = data["records"]["daily"].get(key)
		if typeof(entry) != TYPE_DICTIONARY or not bool(entry.get("done", false)):
			if i == 0:
				continue
			break
		streak += 1
	return streak


func add_play_time(seconds: float) -> void:
	data["stats"]["minutes"] = int(data["stats"]["minutes"]) + int(seconds / 60.0)
	queue_save()


# --------------------------------------------------------------------------
# achievements
# --------------------------------------------------------------------------

func has_achievement(id: String) -> bool:
	return data["achievements"].has(id)


func unlock_achievement(id: String) -> bool:
	if data["achievements"].has(id):
		return false
	data["achievements"][id] = int(Time.get_unix_time_from_system())
	queue_save()
	achievement_unlocked.emit(id)
	if has_node("/root/Arcade"):
		get_node("/root/Arcade").achievement(id)
	return true


func _stat(key: String) -> int:
	var stats: Dictionary = data["stats"]
	match key:
		"stars":
			return total_stars()
		"bosses":
			return (stats["bosses"] as Dictionary).size()
		"tower_types":
			return (stats["tower_types"] as Dictionary).size()
		"enemy_types":
			return (stats["enemy_types"] as Dictionary).size()
		"kingdoms":
			return (stats["kingdoms"] as Dictionary).size()
		"both_paths":
			return (stats["both_paths"] as Dictionary).size()
		"credits":
			return credits()
		"best_waves":
			return int(data["records"]["best_waves"])
		_:
			return int(stats.get(key, 0))


func check_achievements() -> Array:
	var unlocked: Array = []
	for entry in ACHIEVEMENTS:
		var id := String(entry["id"])
		if data["achievements"].has(id):
			continue
		if _stat(String(entry["stat"])) >= int(entry["need"]):
			if unlock_achievement(id):
				unlocked.append(id)
	return unlocked


func trophy_count() -> int:
	return (data["achievements"] as Dictionary).size()


func reset_progress() -> void:
	var profile: Dictionary = data["profile"]
	var settings: Dictionary = data["settings"]
	var created: Variant = data["created"]
	data = _defaults()
	data["profile"] = profile
	data["settings"] = settings
	data["created"] = created
	queue_save()
	changed.emit()
