class_name Battlefield
extends RefCounted
## The authoritative battle simulation.
##
## Everything that decides a fight lives here: enemy movement along the road,
## targeting, damage, statuses, summons, waves, gold and the castle. It never
## touches a mesh, so it can be stepped headless in tests and replayed.
##
## `advance(delta)` runs fixed 60 Hz ticks with a capped catch-up so a slow
## frame can never fast-forward the fight into an unwinnable state.

signal finished(won: bool)

const STEP := 1.0 / 60.0
const MAX_STEPS := 8
const MAX_GUARDS := 14

var level: Dictionary = {}
var mode := "campaign"
var phase := "prep"
var gold := 0
var lives := 20
var max_lives := 20
var wave_index := 0          # waves begun so far
var waves_cleared := 0
var wave_goal := 0           # 0 means "no finishing line"
var elapsed := 0.0
var speed := 1.0
var prep_timer := 0.0
var boss_kills := 0

var enemies: Array = []
var towers: Array = []
var projectiles: Array = []
var guards: Array = []
var effects: Array = []

var path_points: Array = []
var path_dirs: Array = []
var seg_lengths: Array = []
var total_length := 0.0

var _accum := 0.0
var _uid := 1
var _by_uid := {}
var _spawn_queue: Array = []
var _wave_clock := 0.0
var _wave_last_spawn := 0.0
var _aura_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _boss: Dictionary = {}
var _started := false


func setup(setup_level: Dictionary, run_mode := "campaign") -> void:
	level = setup_level
	mode = run_mode
	_rng.seed = int(level.get("seed", 1)) + 99
	path_points = []
	for point in level.get("waypoints", []):
		path_points.append(point)
	if path_points.size() < 2:
		path_points = [Vector3(0, 0, -4.5), Vector3(0, 0, 4.5)]
	seg_lengths = []
	path_dirs = []
	total_length = 0.0
	for i in range(path_points.size() - 1):
		var a: Vector3 = path_points[i]
		var b: Vector3 = path_points[i + 1]
		var d := b - a
		seg_lengths.append(d.length())
		path_dirs.append(d.normalized())
		total_length += d.length()
	gold = int(level.get("start_gold", 220))
	max_lives = int(level.get("lives", 20))
	lives = max_lives
	wave_goal = int(level.get("wave_count", 0))
	if mode == "survival":
		wave_goal = 12
	elif mode == "bossrush":
		wave_goal = 5
	elif mode == "endless" or mode == "sandbox" or mode == "fortress":
		wave_goal = 0
	elif mode == "campaign" or mode == "daily":
		wave_goal = (level.get("waves", []) as Array).size()
	phase = "prep"
	prep_timer = 18.0
	_boss = {}
	_started = false


func start() -> void:
	_started = true


# --------------------------------------------------------------------------
# queries
# --------------------------------------------------------------------------

func sample(dist: float) -> Dictionary:
	if path_points.size() < 2:
		return {"pos": Vector3.ZERO, "dir": Vector3.FORWARD}
	var d := clampf(dist, 0.0, total_length)
	var walked := 0.0
	for i in range(seg_lengths.size()):
		var seg: float = seg_lengths[i]
		if walked + seg >= d or i == seg_lengths.size() - 1:
			var t := 0.0 if seg <= 0.0001 else (d - walked) / seg
			return {
				"pos": (path_points[i] as Vector3).lerp(path_points[i + 1], t),
				"dir": path_dirs[i],
			}
		walked += seg
	return {"pos": path_points[path_points.size() - 1], "dir": Vector3.FORWARD}


func tower_at(cell: Vector2i) -> int:
	for i in range(towers.size()):
		if towers[i]["cell"] == cell:
			return i
	return -1


func socket_open(cell: Vector2i) -> bool:
	for entry in level.get("sockets", []):
		if entry == cell:
			return tower_at(cell) < 0
	return false


func can_build(cell: Vector2i, tower_id: String) -> bool:
	if not socket_open(cell) or not Towers.has(tower_id):
		return false
	if not (level.get("allowed", []) as Array).has(tower_id):
		return false
	return gold >= int(Towers.by_id(tower_id)["cost"])


func build(cell: Vector2i, tower_id: String) -> bool:
	if not can_build(cell, tower_id):
		return false
	var base := Towers.by_id(tower_id)
	var price := int(base["cost"])
	gold -= price
	var tower := {
		"cell": cell,
		"pos": Campaign.world_of(cell),
		"id": tower_id,
		"tier": 1,
		"branch": "",
		"stats": Towers.stats(tower_id, "", 1),
		"invested": price,
		"cooldown": 0.15,
		"target_mode": "first",
		"aim": Vector3.FORWARD,
		"kills": 0,
		"power": float(level.get("power_scale", 1.0)),
		"buff_rate": 0.0,
		"buff_dmg": 0.0,
		"buff_range": 0.0,
		"pulse": 0.0,
	}
	towers.append(tower)
	Save.register_build(tower_id)
	_effect("build", {"pos": tower["pos"], "color": String(base["color"])})
	return true


func upgrade(index: int, branch := "") -> bool:
	if index < 0 or index >= towers.size():
		return false
	var tower: Dictionary = towers[index]
	var tier := int(tower["tier"])
	if tier >= Towers.MAX_TIER:
		return false
	if tier == Towers.MAX_TIER - 1 and branch == "":
		return false
	var price := Towers.upgrade_cost(String(tower["id"]), tier)
	if price <= 0 or gold < price:
		return false
	gold -= price
	tower["invested"] = int(tower["invested"]) + price
	tier += 1
	tower["tier"] = tier
	if tier >= Towers.MAX_TIER:
		tower["branch"] = branch
		tower["stats"] = Towers.stats(String(tower["id"]), branch, tier)
	else:
		tower["stats"] = Towers.stats(String(tower["id"]), "", tier)
	Save.register_upgrade(String(tower["id"]), tier, branch)
	_effect("upgrade", {"pos": tower["pos"], "color": String((tower["stats"] as Dictionary)["color"])})
	return true


func sell(index: int) -> bool:
	if index < 0 or index >= towers.size():
		return false
	var tower: Dictionary = towers[index]
	gold += Towers.sell_value(String(tower["id"]), int(tower["tier"]), int(tower["invested"]))
	_effect("sell", {"pos": tower["pos"]})
	towers.remove_at(index)
	Save.register_sell()
	return true


func set_target_mode(index: int, target_mode: String) -> void:
	if index < 0 or index >= towers.size():
		return
	var allowed := ["first", "last", "strong", "weak", "close", "flying"]
	if target_mode in allowed:
		towers[index]["target_mode"] = target_mode


func health_ratio() -> float:
	return clampf(float(lives) / float(maxi(1, max_lives)), 0.0, 1.0)


func wave_label() -> String:
	if wave_goal > 0:
		return "Wave %d / %d" % [mini(wave_index, wave_goal), wave_goal]
	return "Wave %d" % maxi(1, wave_index)


func prep_ready() -> bool:
	return phase == "prep" and _started


func next_wave_early() -> void:
	if phase != "prep" or not _started:
		return
	var bonus := 8 + wave_index * 3
	gold += bonus
	Save.register_early()
	_effect("bonus", {"amount": bonus})
	_begin_wave()


# --------------------------------------------------------------------------
# stepping
# --------------------------------------------------------------------------

func advance(delta: float) -> void:
	if not _started or phase == "won" or phase == "lost":
		return
	_accum += minf(delta * speed, 0.22)
	var steps := 0
	while _accum >= STEP and steps < MAX_STEPS:
		_tick(STEP)
		_accum -= STEP
		steps += 1
	if steps >= MAX_STEPS:
		_accum = 0.0


func _tick(dt: float) -> void:
	elapsed += dt
	if phase == "prep":
		prep_timer = maxf(0.0, prep_timer - dt)
		if prep_timer <= 0.0:
			_begin_wave()
		elif wave_index == 0 and prep_timer <= 0.001:
			_begin_wave()
		return
	_wave_clock += dt
	_spawn_due()
	_update_enemies(dt)
	_update_towers(dt)
	_update_projectiles(dt)
	_update_guards(dt)
	_aura_timer -= dt
	if _aura_timer <= 0.0:
		_aura_timer = 0.4
		_apply_auras()
	_check_wave()


func _begin_wave() -> void:
	wave_index += 1
	_spawn_queue.clear()
	_wave_clock = 0.0
	_wave_last_spawn = 0.0
	if mode == "bossrush":
		var boss_id := (int(level.get("kingdom_index", 0)) + wave_index - 1) % Bosses.count()
		_spawn_boss(boss_id)
		for i in range(4):
			_queue("shield_drone" if i % 2 == 0 else "clockwork_soldier", 2.2 + float(i) * 1.1)
		phase = "wave"
		return
	var wave := Campaign.wave_for(level, wave_index - 1)
	if wave.is_empty():
		_finish(true)
		return
	var groups: Array = wave.get("groups", [])
	var hp_scale := float(wave.get("hp_scale", 1.0))
	for group_index in range(groups.size()):
		var group: Dictionary = groups[group_index]
		var enemy_id := String(group.get("enemy", ""))
		if not Enemies.has(enemy_id):
			continue
		var count := int(group.get("count", 0))
		var gap := float(group.get("gap", 0.7))
		var at := float(group.get("delay", 0.0))
		for i in range(count):
			_queue(enemy_id, at + float(i) * gap, hp_scale)
			_wave_last_spawn = maxf(_wave_last_spawn, at + float(i) * gap)
	if bool(wave.get("boss", false)):
		_spawn_boss(int(level.get("boss_index", 0)))
		_wave_last_spawn = maxf(_wave_last_spawn, 1.0)
	phase = "wave"
	Audio.play_sfx("wave_start")
	_effect("wave", {"index": wave_index, "boss": bool(wave.get("boss", false))})


func _queue(enemy_id: String, at: float, hp_scale := 1.0) -> void:
	_spawn_queue.append({"enemy": enemy_id, "at": at, "hp": hp_scale})


func _spawn_due() -> void:
	while not _spawn_queue.is_empty() and float(_spawn_queue[0]["at"]) <= _wave_clock:
		var entry: Dictionary = _spawn_queue.pop_front()
		_spawn_enemy(String(entry["enemy"]), float(entry["hp"]), 0.0)


func _spawn_enemy(enemy_id: String, hp_scale: float, at_dist: float, minion := false, offset := 0.0) -> void:
	if not Enemies.has(enemy_id):
		return
	var arch := Enemies.by_id(enemy_id)
	var scale := float(level.get("hp_scale", 1.0)) * hp_scale
	var hp := float(arch["hp"]) * scale
	if minion:
		hp *= 0.4
	var enemy := {
		"uid": _uid,
		"id": enemy_id,
		"name": String(arch["name"]),
		"hp": hp,
		"max_hp": hp,
		"armor": float(arch.get("armor", 0.0)),
		"base_speed": float(arch.get("speed", 1.0)),
		"dist": at_dist,
		"flying": bool(arch.get("flying", false)),
		"statuses": {},
		"shield": 0.0,
		"alive": true,
		"is_boss": false,
		"phase": 1,
		"summon_t": float(arch.get("summon_interval", 0.0)),
		"ability": String(arch.get("ability", "")),
		"offset": offset,
		"pos": Vector3.ZERO,
		"bob": _rng.randf_range(0.0, 6.28),
		"color": String(arch["color"]),
		"size": float(arch.get("size", 1.0)),
		"reward": int(arch.get("reward", 5)),
		"threat": int(arch.get("threat", 1)),
		"hit_flash": 0.0,
	}
	if enemy["ability"] == "shield":
		enemy["shield"] = hp * 0.35
	_uid += 1
	enemies.append(enemy)
	_by_uid[enemy["uid"]] = enemy
	_effect("spawn", {"uid": enemy["uid"], "pos": sample(at_dist)["pos"], "color": enemy["color"]})


func _spawn_boss(index: int) -> void:
	var stats := Bosses.stats(index, float(level.get("hp_scale", 1.0)) * 2.2, 1)
	var hp := float(stats["hp"])
	var enemy := {
		"uid": _uid,
		"id": "boss",
		"name": String(stats["name"]),
		"hp": hp,
		"max_hp": hp,
		"armor": float(stats["armor"]),
		"base_speed": float(stats["speed"]),
		"dist": 0.0,
		"flying": false,
		"statuses": {},
		"shield": hp * 0.12,
		"alive": true,
		"is_boss": true,
		"phase": 1,
		"summon_t": 4.0,
		"ability": "boss",
		"offset": 0.0,
		"pos": Vector3.ZERO,
		"bob": 0.0,
		"color": String(stats["color"]),
		"size": float(stats["size"]),
		"reward": 120,
		"threat": 10,
		"hit_flash": 0.0,
		"boss_index": index,
		"boss_stats": stats,
	}
	_uid += 1
	enemies.append(enemy)
	_by_uid[enemy["uid"]] = enemy
	_boss = enemy
	_effect("boss", {"name": String(stats["name"]), "title": String(stats["title"]), "color": enemy["color"]})


func _update_enemies(dt: float) -> void:
	var guard_stop := false
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		if not bool(enemy["alive"]):
			enemies.remove_at(i)
			_by_uid.erase(enemy["uid"])
			continue
		# statuses
		var statuses: Dictionary = enemy["statuses"]
		var mult := 1.0
		var stopped := false
		for key in statuses.keys():
			var status: Dictionary = statuses[key]
			status["left"] = float(status.get("left", 0.0)) - dt
			if float(status["left"]) <= 0.0:
				statuses.erase(key)
				continue
			match key:
				"burn", "poison":
					enemy["hp"] = float(enemy["hp"]) - float(status.get("dps", 0.0)) * dt
					if float(enemy["hp"]) <= 0.0:
						_kill(enemy)
						break
				"slow":
					mult = minf(mult, float(status.get("factor", 0.6)))
				"freeze", "root", "stun":
					stopped = true
		if not bool(enemy["alive"]):
			enemies.remove_at(i)
			_by_uid.erase(enemy["uid"])
			continue
		if float(enemy["hp"]) <= 0.0:
			_kill(enemy)
			enemies.remove_at(i)
			_by_uid.erase(enemy["uid"])
			continue
		# armour aura from shield carriers
		if String(enemy["ability"]) == "heal" or String(enemy["ability"]) == "aura_armor":
			for other in enemies:
				if other == enemy or not bool(other["alive"]):
					continue
				var gap := absf(float(other["dist"]) - float(enemy["dist"]))
				if gap > 1.6:
					continue
				if String(enemy["ability"]) == "heal":
					other["hp"] = minf(float(other["max_hp"]), float(other["hp"]) + 7.0 * dt)
				else:
					other["aura_armor"] = 3.0
		# ability ticks
		if String(enemy["ability"]) == "summon" and not bool(enemy["is_boss"]):
			enemy["summon_t"] = float(enemy["summon_t"]) - dt
			if float(enemy["summon_t"]) <= 0.0:
				enemy["summon_t"] = 7.5
				_spawn_enemy("button_goblin" if int(level.get("kingdom_index", 0)) < 5 else "clockwork_soldier", 0.8, maxf(0.0, float(enemy["dist"]) - 0.6), true, 0.2)
		if bool(enemy["is_boss"]):
			_update_boss(enemy, dt)
		# movement
		guard_stop = false
		for guard in guards:
			if absf(float(guard["dist"]) - float(enemy["dist"])) < 0.34 and float(enemy["dist"]) <= float(guard["dist"]):
				guard_stop = true
				break
		var move := 0.0
		if not stopped and not guard_stop:
			move = float(enemy["base_speed"]) * mult * dt
		enemy["dist"] = float(enemy["dist"]) + move
		var point := sample(float(enemy["dist"]))
		var pos: Vector3 = point["pos"]
		var dir: Vector3 = point["dir"]
		var side := Vector3(dir.z, 0.0, -dir.x)
		if float(enemy["size"]) > 1.8:
			pos.y = 0.0
		else:
			pos.y = 0.0
		pos += side * float(enemy["offset"])
		enemy["pos"] = pos
		enemy["dir"] = dir
		enemy["hit_flash"] = maxf(0.0, float(enemy["hit_flash"]) - dt * 4.0)
		if float(enemy["dist"]) >= total_length:
			_leak(enemy)
			enemies.remove_at(i)
			_by_uid.erase(enemy["uid"])


func _update_boss(enemy: Dictionary, dt: float) -> void:
	var ratio := float(enemy["hp"]) / maxf(1.0, float(enemy["max_hp"]))
	var phase := int(enemy["phase"])
	if phase == 1 and ratio <= 0.66:
		_advance_boss(enemy, 2)
	elif phase == 2 and ratio <= 0.33:
		_advance_boss(enemy, 3)
	enemy["summon_t"] = float(enemy["summon_t"]) - dt
	if float(enemy["summon_t"]) <= 0.0:
		var stats: Dictionary = enemy["boss_stats"]
		enemy["summon_t"] = float(stats.get("summon_interval", 5.2))
		var minion := String(stats.get("summon", "button_goblin"))
		if Enemies.has(minion):
			for i in range(2):
				_spawn_enemy(minion, 0.7, maxf(0.0, float(enemy["dist"]) - 0.7 - 0.3 * float(i)), true, 0.34 * float(i + 1))
	# bosses shrug off a share of damage while their shield is up
	if float(enemy["shield"]) > 0.0:
		enemy["shield"] = maxf(0.0, float(enemy["shield"]) - 2.0 * dt)


func _advance_boss(enemy: Dictionary, phase: int) -> void:
	enemy["phase"] = phase
	var stats := Bosses.stats(int(enemy["boss_index"]), float(level.get("hp_scale", 1.0)) * 2.2, phase)
	enemy["armor"] = float(stats["armor"])
	enemy["base_speed"] = float(stats["speed"])
	enemy["shield"] = float(enemy["max_hp"]) * 0.16
	enemy["boss_stats"] = stats
	_effect("boss_phase", {"pos": enemy["pos"], "phase": phase, "name": String(stats["phase_name"]), "color": enemy["color"]})


func _leak(enemy: Dictionary) -> void:
	var threat := int(enemy["threat"])
	lives -= threat
	Save.register_leak()
	Audio.play_sfx("leak", 1.0, -4.0)
	_effect("leak", {"pos": enemy["pos"], "amount": threat})
	if lives <= 0:
		lives = 0
		_finish(false)


func _kill(enemy: Dictionary) -> void:
	enemy["alive"] = false
	var reward := int(round(float(enemy["reward"]) * float(level.get("gold_scale", 1.0))))
	gold += reward
	Save.register_kill(String(enemy["id"]), reward)
	Audio.play_sfx("enemy_die", 1.0, -10.0)
	_effect("death", {"pos": enemy["pos"], "color": enemy["color"], "size": float(enemy["size"]), "boss": bool(enemy["is_boss"])})
	if bool(enemy["is_boss"]):
		boss_kills += 1
		Audio.play_sfx("boss_die")
		_effect("boss_die", {"pos": enemy["pos"], "color": enemy["color"]})
		_boss = {}
	# splitting happens at a fraction of the parent's health
	if String(enemy["ability"]) == "split" and float(enemy["size"]) <= 1.2:
		var point := sample(float(enemy["dist"]))
		for i in range(2):
			_spawn_enemy("toy_slime", 0.45, maxf(0.0, float(enemy["dist"]) - 0.25), true, 0.25 * float(i + 1))


# --------------------------------------------------------------------------
# towers
# --------------------------------------------------------------------------

func _update_towers(dt: float) -> void:
	for tower in towers:
		var stats: Dictionary = tower["stats"]
		var attack := String(stats["attack"])
		tower["pulse"] = float(tower["pulse"]) + dt
		if attack == "aura":
			continue
		if attack == "income":
			tower["cooldown"] = float(tower["cooldown"]) - dt
			if float(tower["cooldown"]) <= 0.0:
				tower["cooldown"] = float(stats["interval"]) / maxf(0.1, 1.0 + float(tower["buff_rate"]))
				var effect: Dictionary = stats["effect"]
				var amount := int(round(float(effect.get("gold", 8.0)) * float(tower["power"]) * 0.6))
				gold += amount
				Save.data["stats"]["gold"] = int(Save.data["stats"]["gold"]) + amount
				_effect("coin", {"pos": tower["pos"], "amount": amount})
			continue
		tower["cooldown"] = float(tower["cooldown"]) - dt
		if float(tower["cooldown"]) > 0.0:
			continue
		var target := _pick_target(tower)
		if target.is_empty():
			continue
		var interval: float = float(stats["interval"]) / maxf(0.1, 1.0 + float(tower["buff_rate"]))
		tower["cooldown"] = maxf(0.05, interval)
		_fire(tower, target)


func _pick_target(tower: Dictionary) -> Dictionary:
	var stats: Dictionary = tower["stats"]
	var reach := float(stats["reach"]) + float(tower["buff_range"])
	var best: Dictionary = {}
	var best_score := -INF
	var can_air := bool(stats.get("air", false))
	var mode_target := String(tower["target_mode"])
	for enemy in enemies:
		if not bool(enemy["alive"]):
			continue
		if bool(enemy["flying"]) and not can_air:
			continue
		if mode_target == "flying" and not bool(enemy["flying"]):
			continue
		var distance := (enemy["pos"] as Vector3).distance_to(tower["pos"] as Vector3)
		if distance > reach:
			continue
		var score := 0.0
		match mode_target:
			"last":
				score = -float(enemy["dist"])
			"strong":
				score = float(enemy["hp"])
			"weak":
				score = -float(enemy["hp"])
			"close":
				score = -distance
			_:
				score = float(enemy["dist"])
		if score > best_score:
			best_score = score
			best = enemy
	return best


func _fire(tower: Dictionary, target: Dictionary) -> void:
	var stats: Dictionary = tower["stats"]
	var attack := String(stats["attack"])
	var damage := float(stats["damage"]) * float(tower["power"]) * float(stats.get("effect_power", 1.0))
	var color := String(stats["color"])
	var reach := float(stats["reach"]) + float(tower["buff_range"])
	var effect: Dictionary = stats["effect"]
	tower["aim"] = (target["pos"] as Vector3) - (tower["pos"] as Vector3)
	match attack:
		"bolt", "burst", "splash", "slow":
			var shots := int(stats["shots"])
			var splash := float(stats["blast"])
			for i in range(shots):
				var offset := Vector3.ZERO
				if shots > 1:
					offset = Vector3(float(i) - (shots - 1) * 0.5, 0.0, 0.0) * 0.22
				var shot := {
					"pos": (tower["pos"] as Vector3) + Vector3(0, 0.75, 0) + offset,
					"target": target["uid"],
					"dir": ((target["pos"] as Vector3) - (tower["pos"] as Vector3)).normalized(),
					"speed": float(stats.get("move_speed", 18.0)),
					"damage": damage,
					"type": String(stats["type"]),
					"splash": splash,
					"effect": effect,
					"color": color,
					"life": 2.5,
					"air_bonus": float(stats.get("air_bonus", 1.0)),
					"owner": tower,
				}
				projectiles.append(shot)
			Audio.play_sfx(_shot_sound(String(stats["type"])), randf_range(0.94, 1.06), -9.0)
		"beam":
			var hits := int(stats["shots"])
			var used := {}
			var current := target
			for i in range(hits):
				if current.is_empty():
					break
				var amount := damage if i == 0 else damage * 0.7
				_effect("beam", {"from": (tower["pos"] as Vector3) + Vector3(0, 0.9, 0), "to": current["pos"], "color": color})
				_damage(current, amount, String(stats["type"]), effect)
				used[current["uid"]] = true
				current = _nearest_enemy(current["pos"], reach, used)
			Audio.play_sfx("zap", randf_range(0.95, 1.05), -9.0)
		"chain":
			var jumps := int(stats["jumps"])
			var used := {}
			var current := target
			var chain_positions: Array = [(tower["pos"] as Vector3) + Vector3(0, 0.9, 0)]
			var hop := 0
			while not current.is_empty() and hop <= jumps:
				chain_positions.append(current["pos"])
				var amount := damage * pow(0.78, hop)
				_damage(current, amount, String(stats["type"]), effect)
				Save.register_status("chain")
				used[current["uid"]] = true
				current = _nearest_enemy(current["pos"], 2.4, used)
				hop += 1
			_effect("chain", {"points": chain_positions, "color": color})
			Audio.play_sfx("zap", randf_range(0.9, 1.1), -7.0)
		"stun":
			var radius := maxf(1.2, reach * 0.9)
			var center: Vector3 = tower["pos"]
			_effect("shockwave", {"pos": center, "radius": radius, "color": color})
			for enemy in enemies:
				if not bool(enemy["alive"]):
					continue
				if (enemy["pos"] as Vector3).distance_to(center) <= radius:
					_damage(enemy, damage, String(stats["type"]), effect)
					_apply_status(enemy, effect)
			Audio.play_sfx("drum", randf_range(0.92, 1.04), -6.0)
		"pull":
			var center: Vector3 = tower["pos"]
			var toward := (tower["pos"] as Vector3) - (target["pos"] as Vector3)
			_effect("magnet", {"from": target["pos"], "to": center, "color": color})
			var pulled := 0
			for enemy in enemies:
				if not bool(enemy["alive"]):
					continue
				if (enemy["pos"] as Vector3).distance_to(center) <= reach:
					if bool(enemy["flying"]):
						continue
					enemy["dist"] = maxf(0.0, float(enemy["dist"]) - float(effect.get("amount", 1.0)))
					_damage(enemy, damage, String(stats["type"]), {})
					pulled += 1
			if pulled > 0:
				Audio.play_sfx("magnet", randf_range(0.9, 1.05), -8.0)
		"portal":
			var amount := float(effect.get("amount", 2.0))
			var count := int(stats["shots"])
			var moved := 0
			for enemy in enemies:
				if not bool(enemy["alive"]):
					continue
				if (enemy["pos"] as Vector3).distance_to(tower["pos"] as Vector3) <= reach:
					enemy["dist"] = maxf(0.0, float(enemy["dist"]) - amount)
					_damage(enemy, damage, String(stats["type"]), {})
					if effect.has("stun"):
						_apply_status(enemy, {"kind": "stun", "secs": float(effect["stun"])})
					_effect("portal", {"pos": enemy["pos"], "color": color})
					moved += 1
					if moved >= count:
						break
			Audio.play_sfx("portal", randf_range(0.9, 1.05), -8.0)
		"summon":
			_summon(tower)
	# support towers still pulse visually
	if attack == "aura" or attack == "summon":
		tower["cooldown"] = maxf(0.1, float(stats["interval"]))


func _summon(tower: Dictionary) -> void:
	if guards.size() >= MAX_GUARDS:
		return
	var stats: Dictionary = tower["stats"]
	var effect: Dictionary = stats["effect"]
	var closest := _pick_target(tower)
	var dist := 0.0
	if not closest.is_empty():
		dist = maxf(0.4, float(closest["dist"]) - 0.5)
	else:
		var point: Vector3 = tower["pos"]
		var best := INF
		for i in range(0, 101):
			var d := total_length * float(i) / 100.0
			var p: Vector3 = sample(d)["pos"]
			var gap := p.distance_to(point)
			if gap < best:
				best = gap
				dist = d
	var count := int(stats["shots"])
	for i in range(count):
		guards.append({
			"dist": clampf(dist + float(i) * 0.22, 0.2, total_length - 0.2),
			"hp": float(effect.get("hp", 90.0)) * float(stats.get("effect_power", 1.0)),
			"max_hp": float(effect.get("hp", 90.0)) * float(stats.get("effect_power", 1.0)),
			"dps": float(effect.get("dps", 10.0)) * float(stats.get("effect_power", 1.0)),
			"left": float(effect.get("secs", 12.0)),
			"color": String(stats["color"]),
			"pos": sample(dist)["pos"],
		})
		Save.register_summon()
	_effect("summon", {"pos": sample(dist)["pos"], "color": String(stats["color"])})
	Audio.play_sfx("summon", randf_range(0.92, 1.06), -9.0)


func _nearest_enemy(from: Vector3, reach: float, skip: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_gap := reach
	for enemy in enemies:
		if not bool(enemy["alive"]) or skip.has(enemy["uid"]):
			continue
		var gap := (enemy["pos"] as Vector3).distance_to(from)
		if gap < best_gap:
			best_gap = gap
			best = enemy
	return best


# --------------------------------------------------------------------------
# projectiles, guards, auras
# --------------------------------------------------------------------------

func _update_projectiles(dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[i]
		shot["life"] = float(shot["life"]) - dt
		if float(shot["life"]) <= 0.0:
			projectiles.remove_at(i)
			continue
		var target: Dictionary = _by_uid.get(shot["target"], {})
		if target.is_empty() or not bool(target["alive"]):
			# fly on briefly, then fizzle
			shot["pos"] = (shot["pos"] as Vector3) + (shot["dir"] as Vector3) * float(shot["speed"]) * dt
			if float(shot["life"]) < 1.7:
				projectiles.remove_at(i)
			continue
		var to: Vector3 = (target["pos"] as Vector3) + Vector3(0, 0.35, 0) - (shot["pos"] as Vector3)
		if to.length() <= 0.32:
			_impact(shot, target)
			projectiles.remove_at(i)
			continue
		shot["dir"] = to.normalized()
		shot["pos"] = (shot["pos"] as Vector3) + (shot["dir"] as Vector3) * float(shot["speed"]) * dt


func _impact(shot: Dictionary, target: Dictionary) -> void:
	var splash := float(shot.get("splash", 0.0))
	var damage := float(shot["damage"])
	var type := String(shot["type"])
	var effect: Dictionary = shot.get("effect", {})
	if bool(target.get("flying", false)):
		damage *= float(shot.get("air_bonus", 1.0))
	_damage(target, damage, type, effect)
	if splash > 0.01:
		var center: Vector3 = target["pos"]
		_effect("blast", {"pos": center, "radius": splash, "color": String(shot["color"])})
		for enemy in enemies:
			if enemy == target or not bool(enemy["alive"]):
				continue
			var gap := (enemy["pos"] as Vector3).distance_to(center)
			if gap <= splash:
				var falloff := 1.0 - gap / maxf(0.001, splash) * 0.55
				_damage(enemy, damage * falloff, type, effect)


func _update_guards(dt: float) -> void:
	for i in range(guards.size() - 1, -1, -1):
		var guard: Dictionary = guards[i]
		guard["left"] = float(guard["left"]) - dt
		if float(guard["left"]) <= 0.0 or float(guard["hp"]) <= 0.0:
			_effect("guard_die", {"pos": guard["pos"], "color": guard["color"]})
			guards.remove_at(i)
			continue
		for enemy in enemies:
			if not bool(enemy["alive"]) or bool(enemy["flying"]):
				continue
			var gap := absf(float(enemy["dist"]) - float(guard["dist"]))
			if gap <= 0.75:
				_damage(enemy, float(guard["dps"]) * dt, "physical", {})
				enemy["hp"] = float(enemy["hp"]) - float(guard["dps"]) * dt * 0.4
				guard["hp"] = float(guard["hp"]) - (5.0 + float(enemy["threat"]) * 2.0) * dt
				Save.register_status("chain")


func _apply_auras() -> void:
	# Reset, then let every aura tower contribute. Buffs are additive and
	# capped so a ring of banners cannot make a tower fire infinitely.
	for tower in towers:
		tower["buff_rate"] = 0.0
		tower["buff_dmg"] = 0.0
		tower["buff_range"] = 0.0
	var auras: Array = []
	for tower in towers:
		if String((tower["stats"] as Dictionary)["attack"]) == "aura":
			auras.append(tower)
	for source in auras:
		var stats: Dictionary = source["stats"]
		var effect: Dictionary = stats["effect"]
		var reach := float(stats["reach"]) + float(source["buff_range"])
		var kind := String(effect.get("kind", "buff"))
		if kind == "weaken":
			for enemy in enemies:
				if bool(enemy["alive"]) and (enemy["pos"] as Vector3).distance_to(source["pos"] as Vector3) <= reach:
					_apply_status(enemy, {"kind": "weaken", "secs": 0.9, "amount": float(effect.get("amount", 0.2))})
			continue
		if kind == "time":
			for enemy in enemies:
				if bool(enemy["alive"]) and (enemy["pos"] as Vector3).distance_to(source["pos"] as Vector3) <= reach:
					_apply_status(enemy, {"kind": "slow", "factor": 1.0 - float(effect.get("slow", 0.4)), "secs": 0.9})
		for tower in towers:
			if tower == source:
				continue
			if (tower["pos"] as Vector3).distance_to(source["pos"] as Vector3) > reach:
				continue
			var magic := ["fire", "frost", "lightning", "water", "poison", "arcane", "siege"]
			if kind == "buff_magic" and not magic.has(String((tower["stats"] as Dictionary)["type"])):
				continue
			tower["buff_rate"] = minf(1.4, float(tower["buff_rate"]) + float(effect.get("rate", 0.2)))
			tower["buff_dmg"] = minf(1.6, float(tower["buff_dmg"]) + float(effect.get("dmg", 0.2)))
			if kind == "time":
				tower["buff_rate"] = minf(1.4, float(tower["buff_rate"]) + 0.0)


# --------------------------------------------------------------------------
# damage
# --------------------------------------------------------------------------

func _damage(enemy: Dictionary, amount: float, damage_type: String, effect: Dictionary) -> void:
	if not bool(enemy.get("alive", false)):
		return
	var statuses: Dictionary = enemy["statuses"]
	if String(enemy["ability"]) == "dodge" and _rng.randf() < 0.18:
		_effect("miss", {"pos": enemy["pos"]})
		return
	var pierce := 0.0
	if String(effect.get("kind", "")) == "pierce":
		pierce = float(effect.get("amount", 0.0))
	var armor := float(enemy["armor"]) + float(enemy.get("aura_armor", 0.0))
	var reduced := maxf(1.0, amount - armor * (1.0 - pierce))
	reduced *= Enemies.resist(String(enemy["id"]), damage_type)
	if statuses.has("mark"):
		reduced *= 1.0 + float((statuses["mark"] as Dictionary).get("amount", 0.25))
	if statuses.has("weaken"):
		reduced *= 1.0 + float((statuses["weaken"] as Dictionary).get("amount", 0.2))
	if statuses.has("soak") and damage_type == "lightning":
		reduced *= 1.45
	if bool(enemy["is_boss"]) and float(enemy["shield"]) > 0.0:
		var absorbed := minf(float(enemy["shield"]), reduced * 0.5)
		enemy["shield"] = float(enemy["shield"]) - absorbed
		reduced -= absorbed
	enemy["hp"] = float(enemy["hp"]) - reduced
	enemy["hit_flash"] = 1.0
	_apply_status(enemy, effect)
	_effect("hit", {"pos": enemy["pos"], "color": Towers.type_color(damage_type), "amount": reduced})
	if float(enemy["hp"]) <= 0.0:
		_kill(enemy)


func _apply_status(enemy: Dictionary, effect: Dictionary) -> void:
	if effect.is_empty():
		return
	var statuses: Dictionary = enemy["statuses"]
	var kind := String(effect.get("kind", ""))
	var power := 1.0
	match kind:
		"slow":
			statuses["slow"] = {"factor": clampf(float(effect.get("factor", 0.6)), 0.25, 0.95), "left": float(effect.get("secs", 2.0))}
		"freeze":
			statuses["freeze"] = {"left": float(effect.get("secs", 1.0))}
			Save.register_status("freeze")
		"root":
			statuses["root"] = {"left": float(effect.get("secs", 1.0))}
			if effect.has("dps"):
				statuses["burn"] = {"dps": float(effect["dps"]), "left": float(effect.get("secs", 1.0))}
		"stun":
			statuses["stun"] = {"left": float(effect.get("secs", 0.7))}
		"burn", "poison":
			statuses[kind] = {"dps": float(effect.get("dps", 6.0)), "left": float(effect.get("secs", 3.0))}
			Save.register_status(kind)
		"soak":
			statuses["soak"] = {"left": float(effect.get("secs", 4.0))}
		"mark":
			statuses["mark"] = {"amount": float(effect.get("amount", 0.25)), "left": float(effect.get("secs", 3.0))}
		"weaken":
			statuses["weaken"] = {"amount": float(effect.get("amount", 0.2)), "left": float(effect.get("secs", 2.0))}
	if kind == "" or kind == "buff" or kind == "buff_magic" or kind == "income" or kind == "time" or kind == "summon" or kind == "pull" or kind == "portal":
		return
	power = 1.0


# --------------------------------------------------------------------------
# wave / end of battle
# --------------------------------------------------------------------------

func _check_wave() -> void:
	if phase != "wave":
		return
	if _wave_clock < _wave_last_spawn + 0.05:
		return
	if not enemies.is_empty():
		return
	waves_cleared += 1
	Save.register_wave()
	var bonus := 14 + wave_index * 4 + int(level.get("kingdom_index", 0)) * 2
	gold += bonus
	_effect("wave_clear", {"bonus": bonus, "wave": waves_cleared})
	Audio.play_sfx("wave_clear")
	if wave_goal > 0 and waves_cleared >= wave_goal:
		_finish(true)
		return
	phase = "prep"
	prep_timer = 9.0


func _finish(won: bool) -> void:
	if phase == "won" or phase == "lost":
		return
	phase = "won" if won else "lost"
	Audio.play_sfx("victory" if won else "defeat")
	finished.emit(won)


func _shot_sound(damage_type: String) -> String:
	match damage_type:
		"fire":
			return "flame"
		"frost":
			return "ice"
		"lightning":
			return "zap"
		"water":
			return "splash"
		"poison":
			return "mist"
		"arcane":
			return "magic"
		"siege":
			return "cannon"
		_:
			return "arrow"


func _effect(kind: String, data: Dictionary) -> void:
	data["kind"] = kind
	effects.append(data)
	if effects.size() > 220:
		effects = effects.slice(effects.size() - 180, effects.size())


func snapshot() -> Dictionary:
	return {
		"mode": mode,
		"phase": phase,
		"wave": wave_index,
		"waves_cleared": waves_cleared,
		"wave_goal": wave_goal,
		"gold": gold,
		"lives": lives,
		"enemies": enemies.size(),
		"towers": towers.size(),
		"boss": not _boss.is_empty(),
		"elapsed": snappedf(elapsed, 0.01),
	}
