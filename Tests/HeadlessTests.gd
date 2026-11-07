extends Node
## Headless regression suite. Every check prints a failure and the run exits
## non-zero, so CI refuses to publish a broken build.

var checks := 0
var failures: Array = []


func _ready() -> void:
	print("Wonderguard 3D — headless suite")
	_test_towers()
	_test_enemies()
	_test_bosses()
	_test_campaign()
	_test_modes()
	_test_battle()
	_test_statuses()
	_test_save()
	_test_assets()
	print("checks: %d   failures: %d" % [checks, failures.size()])
	if failures.is_empty():
		print("TESTS OK")
		get_tree().quit(0)
	else:
		for failure in failures.slice(0, 40):
			printerr("FAIL: " + String(failure))
		get_tree().quit(1)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _test_towers() -> void:
	check(Towers.count() >= 24, "there must be at least 24 tower families (got %d)" % Towers.count())
	var seen := {}
	for item in Towers.ITEMS:
		var id := String(item["id"])
		check(not seen.has(id), "duplicate tower id %s" % id)
		seen[id] = true
		check(String(item["name"]).length() > 3, "tower %s needs a name" % id)
		check(int(item["cost"]) > 0, "tower %s needs a cost" % id)
		check(float(item["dmg"]) >= 0.0, "tower %s has negative damage" % id)
		check(float(item["rate"]) > 0.0, "tower %s must fire" % id)
		var branches: Dictionary = item.get("branch", {})
		check(branches.has("a") and branches.has("b"), "tower %s needs two ultimate branches" % id)
		check(String(branches["a"]["name"]) != String(branches["b"]["name"]), "tower %s branches must differ" % id)
		check(String(item["cat"]) in Towers.CATEGORIES, "tower %s category" % id)
		# Three linear tiers then two ultimates, each strictly stronger.
		var t1 := Towers.stats(id, "", 1)
		var t2 := Towers.stats(id, "", 2)
		var t3 := Towers.stats(id, "", 3)
		if float(item["dmg"]) > 0.0:
			check(float(t2["damage"]) > float(t1["damage"]), "%s tier 2 must hit harder" % id)
			check(float(t3["damage"]) > float(t2["damage"]), "%s tier 3 must hit harder" % id)
		var a := Towers.stats(id, "a", 4)
		var b := Towers.stats(id, "b", 4)
		check(String(a["display_name"]) == String(branches["a"]["name"]), "%s branch A name" % id)
		check(String(b["display_name"]) == String(branches["b"]["name"]), "%s branch B name" % id)
		check(int(a["tier"]) == 4 and int(b["tier"]) == 4, "%s branches are tier four" % id)
		check(Towers.upgrade_cost(id, 1) > 0, "%s tier 1 upgrade cost" % id)
		check(Towers.upgrade_cost(id, 4) == 0, "%s cannot upgrade past four" % id)
		check(Towers.sell_value(id, 2, 200) > 0, "%s resale" % id)
	# Every available list is a real, legal shelf.
	for k in range(Campaign.KINGDOM_COUNT):
		var shelf := Towers.available(k)
		check(shelf.size() >= 7, "kingdom %d must offer at least seven towers" % (k + 1))
		check(shelf.size() <= Towers.count(), "kingdom %d shelf too big" % (k + 1))
		for id in shelf:
			check(Towers.has(String(id)), "kingdom %d offers unknown tower %s" % [k + 1, id])
	check(Towers.available(0).size() == 7, "kingdom one starts with seven towers")
	check(Towers.available(19).size() == Towers.count(), "the last kingdom unlocks the whole shelf")
	check(Towers.available(0, true).size() == Towers.count(), "sandbox unlocks everything")
	# Every attack kind in the data must have a handler in the simulation.
	var source := FileAccess.get_file_as_string("res://Scripts/Game/Battlefield.gd")
	check(source.length() > 1000, "battlefield source must be readable")
	for kind in ["bolt", "burst", "splash", "slow", "beam", "chain", "stun", "pull", "portal", "summon", "aura", "income"]:
		check(source.contains("\"%s\"" % kind), "attack kind %s has no handler" % kind)


func _test_enemies() -> void:
	check(Enemies.count() >= 48, "there must be at least 48 archetypes (got %d)" % Enemies.count())
	var seen := {}
	for item in Enemies.ITEMS:
		var id := String(item["id"])
		check(not seen.has(id), "duplicate enemy id %s" % id)
		seen[id] = true
		check(float(item["hp"]) > 0.0, "enemy %s needs health" % id)
		check(float(item["speed"]) > 0.0, "enemy %s needs speed" % id)
		check(int(item["threat"]) >= 1, "enemy %s must threaten the castle" % id)
		check(int(item["reward"]) >= 1, "enemy %s must pay gold" % id)
		check(String(item["model"]) in Enemies.MODELS, "enemy %s model" % id)
		check(String(item["color"]).begins_with("#"), "enemy %s colour" % id)
	# A spread of kinds, so waves can be composed rather than reskinned.
	for kind in ["basic", "fast", "heavy", "armored", "flying", "magical", "mechanical", "support", "stealth", "shielded", "elite"]:
		check(Enemies.of_kind(kind).size() >= 2, "kind %s needs at least two archetypes" % kind)
	check(Enemies.flying("glider_bat"), "glider bats fly")
	check(not Enemies.flying("wooden_knight"), "knights walk")
	check(Enemies.resist("ember_imp", "fire") < 1.0, "embers resist fire")
	check(Enemies.resist("ember_imp", "frost") > 1.0, "embers are weak to frost")


func _test_bosses() -> void:
	check(Bosses.count() == 20, "there must be exactly twenty bosses")
	var names := {}
	for i in range(Bosses.count()):
		var boss: Dictionary = Bosses.by_index(i)
		check(not names.has(String(boss["name"])), "duplicate boss %s" % boss["name"])
		names[String(boss["name"])] = true
		check((boss["phases"] as Array).size() == 3, "%s needs three phases" % boss["name"])
		check(float(boss["hp"]) > 500.0, "%s needs a real health pool" % boss["name"])
		check(Enemies.has(String(boss["summon"])), "%s summons a real enemy" % boss["name"])
		var p1 := Bosses.stats(i, 1.0, 1)
		var p3 := Bosses.stats(i, 1.0, 3)
		check(float(p3["hp"]) > float(p1["hp"]), "%s phase three must be tougher" % boss["name"])
		check(float(p3["armor"]) > float(p1["armor"]), "%s phase three must be armoured" % boss["name"])
		check(String(p1["phase_name"]) == String((boss["phases"] as Array)[0]), "%s phase naming" % boss["name"])


func _test_campaign() -> void:
	check(Campaign.LEVEL_COUNT == 1000, "campaign must have 1,000 levels")
	check(Campaign.KINGDOMS.size() == 20, "campaign must have twenty kingdoms")
	var ids := {}
	var boss_levels := 0
	var world_roster := {}
	for k in range(Campaign.KINGDOM_COUNT):
		var roster: Array = Campaign.KINGDOMS[k]["roster"]
		check(roster.size() >= 8, "kingdom %d needs at least eight enemies" % (k + 1))
		for id in roster:
			check(Enemies.has(String(id)), "kingdom %d roster has unknown %s" % [k + 1, id])
		world_roster[k] = roster
	var first := Campaign.generate(1)
	for id in range(1, Campaign.LEVEL_COUNT + 1):
		var level := Campaign.generate(id)
		ids[id] = true
		var problems := Campaign.validate(level)
		checks += 1
		if not problems.is_empty():
			failures.append("level %d: %s" % [id, ", ".join(problems)])
		if bool(level["boss"]):
			boss_levels += 1
		check(int(level["kingdom"]) == Campaign.kingdom_index(id) + 1, "kingdom mapping for %d" % id)
		check(int(level["local"]) == ((id - 1) % 50) + 1, "local mapping for %d" % id)
		check(int(level["start_gold"]) >= 210, "level %d budget" % id)
		check(float(level["hp_scale"]) > 0.9, "level %d hp scale" % id)
		check((level["sockets"] as Array).size() >= 14, "level %d needs build space" % id)
		if id % 97 == 0:
			check(JSON.stringify(Campaign.generate(id)) == JSON.stringify(level), "level %d must be deterministic" % id)
	check(ids.size() == 1000, "all one thousand levels must exist once")
	check(boss_levels == 100, "there must be 100 boss levels (found %d)" % boss_levels)
	check(Campaign.is_boss_level(10) and not Campaign.is_boss_level(11), "boss every tenth level")
	check(Campaign.local_level(51) == 1, "level 51 opens kingdom two")
	check(String(first["name"]).begins_with("Meadows"), "level one is in the meadows")
	check(Campaign.level_name(1000) == "Infinity 50", "the last level name")
	check(Campaign.start_gold(1000) > Campaign.start_gold(1), "later levels pay more up front")
	check(Campaign.hp_scale(1000) > Campaign.hp_scale(1), "later levels are tougher")
	check(Campaign.power_scale(1000) > Campaign.power_scale(1), "later towers hit harder")
	# Every enemy in a wave must exist and every boss level must end on its boss.
	for id in [1, 5, 10, 50, 51, 199, 500, 777, 999, 1000]:
		var level := Campaign.generate(id)
		var waves: Array = level["waves"]
		check(waves.size() >= 4 and waves.size() <= 9, "level %d wave count" % id)
		for wave in waves:
			for group in wave["groups"]:
				check(Enemies.has(String(group["enemy"])), "level %d wave enemy %s" % [id, group["enemy"]])
		check(bool((waves[waves.size() - 1])["boss"]) == bool(level["boss"]), "level %d boss wave flag" % id)


func _test_modes() -> void:
	var modes := ["endless", "survival", "bossrush", "daily", "sandbox"]
	for mode in modes:
		var level := Campaign.generate_mode(mode, 4242, 4)
		check(String(level["mode"]) == mode, "%s mode tag" % mode)
		check((level["sockets"] as Array).size() >= 14, "%s needs sockets" % mode)
		check(Campaign.validate(level).is_empty(), "%s level must validate: %s" % [mode, Campaign.validate(level)])
	check((Campaign.generate_mode("endless", 7, 0)["allowed"] as Array).size() == Towers.count(), "endless opens the shelf")
	check((Campaign.generate_mode("survival", 7, 0)["lives"] as int) == 8, "survival is short and sharp")
	check((Campaign.generate_mode("bossrush", 7, 0)["wave_count"] as int) == 5, "boss rush is five bosses")
	check((Campaign.generate_mode("sandbox", 7, 0)["start_gold"] as int) > 1000, "sandbox is generous")
	var wave := Campaign.wave_for(Campaign.generate_mode("endless", 7, 0), 9)
	check(not wave.is_empty(), "endless must synthesise waves past the list")
	check((wave["groups"] as Array).size() > 0, "endless waves need groups")
	var again := Campaign.wave_for(Campaign.generate_mode("endless", 7, 0), 9)
	check(JSON.stringify(wave) == JSON.stringify(again), "endless waves must be seeded")


func _test_battle() -> void:
	var level := Campaign.generate(1)
	var battle := Battlefield.new()
	battle.setup(level, "campaign")
	battle.start()
	check(battle.gold == int(level["start_gold"]), "battle starts with the level budget")
	check(battle.lives == int(level["lives"]), "battle starts with the level lives")
	check(absf(battle.total_length - _path_length(level)) < 0.01, "path length must match the waypoints")
	check(battle.sample(0.0)["pos"].distance_to(level["waypoints"][0]) < 0.01, "sample at zero is the spawn")
	check(battle.sample(battle.total_length)["pos"].distance_to(level["waypoints"][level["waypoints"].size() - 1]) < 0.01, "sample at the end is the castle")

	# A tower can only go on a legal socket, and only if it is affordable.
	var socket: Vector2i = level["sockets"][0]
	var tower_id := String((level["allowed"] as Array)[0])
	check(battle.can_build(socket, tower_id), "a free socket should accept the first tower")
	battle.gold = 0
	check(not battle.can_build(socket, tower_id), "no gold, no tower")
	battle.gold = 5000
	check(not battle.can_build(level["path"][2], tower_id), "the road is not a build spot")
	check(battle.build(socket, tower_id), "building on a socket must succeed")
	check(battle.tower_at(socket) == 0, "the tower is registered at its cell")
	check(battle.gold == 5000 - int(Towers.by_id(tower_id)["cost"]), "building spends the cost")
	check(not battle.build(socket, tower_id), "two towers cannot share a cell")
	check(battle.upgrade(0, ""), "first upgrade")
	check(int(battle.towers[0]["tier"]) == 2, "tier two after upgrade")
	check(battle.upgrade(0, ""), "second upgrade")
	check(int(battle.towers[0]["tier"]) == 3, "tier three after upgrade")
	check(not battle.upgrade(0, ""), "cannot take an ultimate without choosing a branch")
	check(battle.upgrade(0, "a"), "choosing an ultimate")
	check(int(battle.towers[0]["tier"]) == 4, "tier four after the branch")
	check(String(battle.towers[0]["branch"]) == "a", "branch recorded")
	check(not battle.upgrade(0, "b"), "a tower cannot take both ultimates")
	check(battle.sell(0), "selling works")
	check(battle.towers.is_empty(), "sold tower is gone")

	# Start a wave and confirm enemies actually spawn, walk and can be killed.
	battle.gold = 4000
	battle.build(socket, tower_id)
	battle.next_wave_early()
	check(battle.phase == "wave", "calling the wave starts it")
	check(battle.wave_index == 1, "wave counter advances")
	var spawned := 0
	for i in range(1200):
		battle.advance(0.1)
		spawned = maxi(spawned, battle.enemies.size())
		if battle.phase == "won" or battle.phase == "lost":
			break
	check(spawned > 0, "a wave must spawn enemies")
	check(battle.waves_cleared >= 1 or battle.phase == "lost", "the first wave should resolve")

	# Enemies that reach the end cost lives.
	var leak_level := Campaign.generate(1)
	var leak_battle := Battlefield.new()
	leak_battle.setup(leak_level, "campaign")
	leak_battle.start()
	var before := leak_battle.lives
	for i in range(60 * 90):
		leak_battle.advance(1.0 / 60.0)
		if leak_battle.lives < before:
			break
	check(leak_battle.lives < before, "an undefended road must cost the castle lives")


func _path_length(level: Dictionary) -> float:
	var points: Array = level["waypoints"]
	var total := 0.0
	for i in range(points.size() - 1):
		total += (points[i] as Vector3).distance_to(points[i + 1])
	return total


func _test_statuses() -> void:
	# Frost slows, lightning loves soaked targets, and marks amplify damage.
	var level := Campaign.generate(1)
	var battle := Battlefield.new()
	battle.setup(level, "campaign")
	battle.start()
	battle._spawn_enemy("wooden_knight", 1.0, 0.0)
	var enemy: Dictionary = battle.enemies[0]
	var hp_before := float(enemy["hp"])
	battle._damage(enemy, 20.0, "physical", {})
	check(float(enemy["hp"]) < hp_before, "damage reduces health")
	battle._apply_status(enemy, {"kind": "mark", "secs": 3.0, "amount": 0.5})
	var hp_marked := float(enemy["hp"])
	battle._damage(enemy, 20.0, "physical", {})
	var marked_loss := hp_marked - float(enemy["hp"])
	var fresh := Battlefield.new()
	fresh.setup(level, "campaign")
	fresh.start()
	fresh._spawn_enemy("wooden_knight", 1.0, 0.0)
	var plain: Dictionary = fresh.enemies[0]
	var plain_hp := float(plain["hp"])
	fresh._damage(plain, 20.0, "physical", {})
	var plain_loss := plain_hp - float(plain["hp"])
	check(marked_loss > plain_loss, "a marked enemy takes more damage")
	battle._apply_status(enemy, {"kind": "soak", "secs": 4.0})
	var hp_soaked := float(enemy["hp"])
	battle._damage(enemy, 20.0, "lightning", {})
	check(hp_soaked - float(enemy["hp"]) > plain_loss, "soaked enemies take extra lightning")
	battle._apply_status(enemy, {"kind": "freeze", "secs": 1.0})
	check(enemy["statuses"].has("freeze"), "freeze is applied")
	battle._apply_status(enemy, {"kind": "slow", "factor": 0.4, "secs": 2.0})
	check(is_equal_approx(float((enemy["statuses"]["slow"] as Dictionary)["factor"]), 0.4), "slow factor recorded")


func _test_save() -> void:
	var defaults := Save._defaults()
	check(int(defaults["schema"]) == 1, "save schema version")
	check(defaults.has("progress") and defaults.has("records"), "save has progress and records")
	check((defaults["progress"] as Dictionary).has("stars"), "save tracks stars")
	var round_trip: Variant = JSON.parse_string(JSON.stringify(defaults))
	check(typeof(round_trip) == TYPE_DICTIONARY, "save must survive JSON")
	if typeof(round_trip) == TYPE_DICTIONARY:
		var merged := Save._merge(round_trip, defaults)
		check(merged.has("settings"), "merge keeps settings")
		check(int(merged["schema"]) == 1, "merge keeps schema")
	var old := {"schema": 1, "progress": {"stars": {"1": 3}}}
	var healed := Save._merge(old, Save._defaults())
	check(healed["progress"]["stars"].has("1"), "old stars survive a merge")
	check(healed.has("achievements"), "missing keys are restored")
	check(Save.ACHIEVEMENTS.size() >= 100, "at least one hundred trophies (got %d)" % Save.ACHIEVEMENTS.size())
	var ids := {}
	for entry in Save.ACHIEVEMENTS:
		var id := String(entry["id"])
		check(not ids.has(id), "duplicate trophy %s" % id)
		ids[id] = true
		check(String(entry["hint"]).length() > 5, "trophy %s needs a hint" % id)
		check(Save.data["stats"].has(String(entry["stat"])) or String(entry["stat"]) in ["stars", "bosses", "tower_types", "enemy_types", "kingdoms", "both_paths", "credits", "best_waves"], "trophy %s reads unknown stat %s" % [id, entry["stat"]])
	check(Save.data.has("settings"), "live save data is ready")
	check(Save.next_level() >= 1, "next level must be valid")
	check(Save.is_kingdom_unlocked(0), "kingdom one is always open")
	var fresh: Dictionary = Save._defaults()
	check((fresh["progress"]["stars"] as Dictionary).is_empty(), "a new profile starts with no stars")
	check(Save.total_stars() >= 0, "star total")
	var key := Save.daily_date_key()
	check(key.length() == 10 and key[4] == "-", "daily date key format")
	check(Save.daily_seed() == Save.daily_seed(), "daily seed is stable within a day")
	check(Save.daily_seed() > 0, "daily seed is positive")


func _test_assets() -> void:
	var models := ["tower_base", "turret_crossbow", "turret_barrel", "turret_crystal", "turret_gear",
		"turret_drum", "turret_bell", "turret_hive", "turret_banner", "turret_portal", "turret_castle",
		"turret_mint", "turret_grove", "turret_mist", "turret_magnet", "turret_roost", "turret_furnace",
		"turret_coil", "turret_fountain", "turret_rune", "castle", "tree_a", "tree_b", "rock",
		"crystal_cluster", "windmill", "house", "goblin", "mouse", "slime", "knight", "beetle",
		"imp", "spider", "golem", "bat", "wraith", "construct", "grove", "boss_core"]
	for model in models:
		check(ResourceLoader.exists("res://Assets/Models/props/%s.glb" % model), "missing model %s" % model)
	var sounds := ["ui_click", "build", "upgrade", "sell", "arrow", "cannon", "flame", "ice", "zap",
		"splash", "mist", "magic", "drum", "magnet", "portal", "summon", "coin", "enemy_die",
		"leak", "wave_start", "wave_clear", "boss", "boss_die", "victory", "defeat"]
	for sound in sounds:
		check(ResourceLoader.exists("res://Assets/Audio/SFX/%s.wav" % sound), "missing sound %s" % sound)
	for mood in ["menu", "battle", "boss"]:
		check(ResourceLoader.exists("res://Assets/Audio/Music/%s.wav" % mood), "missing music %s" % mood)
	# Every turret a tower can ask for must exist as an asset.
	var view_source := FileAccess.get_file_as_string("res://Scripts/Game/BattleView.gd")
	for model in models:
		if model.begins_with("turret_"):
			check(view_source.contains("\"%s\"" % model), "turret %s is never used" % model)
