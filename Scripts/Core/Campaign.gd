class_name Campaign
extends RefCounted
## The 1,000-level campaign: 20 kingdoms of 50 levels, generated from a seed.
##
## A level is a winding road on a 6 x 11 miniature board, a budget, a list of
## waves and the rules a player may build under. Because it is data, any level
## can be regenerated on any device for validation, and `validate()` is run over
## all one thousand of them in CI.

const KINGDOM_COUNT := 20
const LEVELS_PER_KINGDOM := 50
const LEVEL_COUNT := 1000
const BOSS_EVERY := 10
const COLS := 6
const ROWS := 11
const CELL := 0.9

const KINGDOMS: Array = [
	{
		"name": "Emerald Meadows", "short": "Meadows",
		"tagline": "Toy windmills, bright grass, and goblins in the hedges.",
		"from": "#2f7d4f", "to": "#0d2418", "accent": "#8fe08a", "glow": "#d8ffc4",
		"grass": "#4f9e5e", "stone": "#c9b48a", "path": "#d8c9a8",
		"roster": ["button_goblin", "clockwork_mouse", "marching_mushroom", "toy_slime", "wooden_knight", "healer_pixie", "armored_boar", "forest_entling"],
		"landmark": "The Old Windmill",
	},
	{
		"name": "Golden Kingdom", "short": "Golden",
		"tagline": "Brass roofs and royal banners, polished every morning.",
		"from": "#8a6a1c", "to": "#241a05", "accent": "#ffd166", "glow": "#fff0b8",
		"grass": "#b39a54", "stone": "#e2cf9a", "path": "#f2e2b8",
		"roster": ["wooden_knight", "clockwork_soldier", "shield_carrier", "clockwork_mouse", "golden_knight", "bomb_cart", "healer_pixie", "crystal_beetle"],
		"landmark": "The Gilded Gate",
	},
	{
		"name": "Frozen Frontier", "short": "Frozen",
		"tagline": "Snow on the rooftops and frost on every gear.",
		"from": "#2a5f82", "to": "#081722", "accent": "#9fe3ff", "glow": "#e8fbff",
		"grass": "#bcd8e8", "stone": "#8fb4c8", "path": "#e8f6ff",
		"roster": ["frost_sprite", "snow_guardian", "crystal_beetle", "frost_golem", "clockwork_soldier", "crystal_crab", "glider_bat", "wooden_knight"],
		"landmark": "The Frozen Mill",
	},
	{
		"name": "Inferno Valley", "short": "Inferno",
		"tagline": "Lava runs under the boardwalk. The foundry never cools.",
		"from": "#7a2a10", "to": "#200603", "accent": "#ff7a3d", "glow": "#ffd0a0",
		"grass": "#8a4a32", "stone": "#5a3a30", "path": "#d97a4a",
		"roster": ["ember_imp", "lava_beetle", "bomb_cart", "fire_elemental", "clockwork_rhino", "armored_boar", "oil_slime", "siege_walker"],
		"landmark": "The Ember Forge",
	},
	{
		"name": "Clockwork Empire", "short": "Clockwork",
		"tagline": "Every street turns on a gear the size of a house.",
		"from": "#4a5568", "to": "#11151d", "accent": "#c9b48a", "glow": "#ffe8bc",
		"grass": "#7a7a6a", "stone": "#c9b48a", "path": "#e8d2a8",
		"roster": ["mechanical_spider", "clockwork_soldier", "clockwork_rhino", "mechanical_serpent", "clockwork_mouse", "shield_drone", "goblin_engineer", "armored_boar"],
		"landmark": "The Great Escapement",
	},
	{
		"name": "Oceanic Isles", "short": "Isles",
		"tagline": "Turquoise water, coral bridges, and very patient crabs.",
		"from": "#1d6a78", "to": "#04161b", "accent": "#5fd8e0", "glow": "#c8fbff",
		"grass": "#7fc9a8", "stone": "#d8c9a8", "path": "#f0e6c8",
		"roster": ["crystal_crab", "floating_lantern", "glider_bat", "mechanical_wasp", "mini_griffin", "crystal_phantom", "shield_carrier", "healer_pixie"],
		"landmark": "The Coral Bridge",
	},
	{
		"name": "Enchanted Forest", "short": "Forest",
		"tagline": "Mushroom lanterns light the path between the roots.",
		"from": "#25603f", "to": "#061810", "accent": "#9be07a", "glow": "#e0ffc8",
		"grass": "#3f8a5a", "stone": "#a8b48a", "path": "#c9d8a8",
		"roster": ["forest_entling", "marching_mushroom", "jungle_guardian", "healer_pixie", "shadow_runner", "toy_slime", "floating_lantern", "arcane_mimic"],
		"landmark": "The Elder Stump",
	},
	{
		"name": "Thunder Highlands", "short": "Highlands",
		"tagline": "Storm clouds caught on the peaks like wool on a fence.",
		"from": "#2a4560", "to": "#080f18", "accent": "#9fd0ff", "glow": "#e0f2ff",
		"grass": "#5f7a6a", "stone": "#8a9aa8", "path": "#c8d8e0",
		"roster": ["thunder_sprite", "wind_elemental", "glider_bat", "mechanical_wasp", "mini_griffin", "floating_eye", "shield_drone", "siege_walker"],
		"landmark": "The Lightning Rod",
	},
	{
		"name": "Sunstone Desert", "short": "Desert",
		"tagline": "Golden dunes over an older, stranger kingdom.",
		"from": "#8a6a2a", "to": "#241705", "accent": "#e8b45c", "glow": "#ffe6b0",
		"grass": "#c9a86a", "stone": "#b08a58", "path": "#f2d9a8",
		"roster": ["armored_boar", "crystal_beetle", "golden_knight", "siege_walker", "bomb_cart", "shadow_runner", "royal_siege_beast", "healer_pixie"],
		"landmark": "The Worn Crown",
	},
	{
		"name": "Crystal Caverns", "short": "Caverns",
		"tagline": "The walls hum in three keys. None of them agree.",
		"from": "#3a2a6a", "to": "#0a0618", "accent": "#b79bff", "glow": "#e8dcff",
		"grass": "#5a4a8a", "stone": "#8a7ab8", "path": "#c8b8f0",
		"roster": ["crystal_beetle", "crystal_crab", "crystal_phantom", "floating_eye", "arcane_mimic", "shield_drone", "mechanical_serpent", "snow_guardian"],
		"landmark": "The Singing Facet",
	},
	{
		"name": "Skybound Kingdom", "short": "Skybound",
		"tagline": "Floating islands, tethered by bridges and stubbornness.",
		"from": "#3a5a82", "to": "#08131f", "accent": "#c8e8ff", "glow": "#f0faff",
		"grass": "#8ab8c8", "stone": "#c8d8e0", "path": "#e8f4ff",
		"roster": ["mini_griffin", "shield_drone", "wind_elemental", "mechanical_wasp", "floating_eye", "glider_bat", "snow_guardian", "arcane_colossus"],
		"landmark": "The Anchor Chain",
	},
	{
		"name": "Starlight Galaxy", "short": "Starlight",
		"tagline": "Constellations you can walk between, if you are careful.",
		"from": "#2a2a5a", "to": "#06060f", "accent": "#8fa8ff", "glow": "#e0e8ff",
		"grass": "#4a4a7a", "stone": "#8a8ab8", "path": "#c8c8f0",
		"roster": ["floating_eye", "arcane_colossus", "thunder_sprite", "crystal_phantom", "mechanical_serpent", "shield_drone", "fire_elemental", "infinity_construct"],
		"landmark": "The Star Well",
	},
	{
		"name": "Haunted Hollow", "short": "Hollow",
		"tagline": "Friendly ghosts, unfriendly taxes, excellent lanterns.",
		"from": "#3a2a4a", "to": "#0d0812", "accent": "#b8a0d8", "glow": "#e8d8ff",
		"grass": "#6a5a7a", "stone": "#9a8aa8", "path": "#d8c8e8",
		"roster": ["shadow_runner", "shadow_mage", "crystal_phantom", "floating_lantern", "arcane_mimic", "portal_hopper", "mechanical_spider", "healer_pixie"],
		"landmark": "The Empty Manor",
	},
	{
		"name": "Cyber Citadel", "short": "Citadel",
		"tagline": "Neon tubes over old stone. The robots are very polite.",
		"from": "#1d4a5a", "to": "#050f14", "accent": "#7be0ff", "glow": "#d8faff",
		"grass": "#3a6a7a", "stone": "#7a9aa8", "path": "#a8e0f0",
		"roster": ["mechanical_spider", "mechanical_wasp", "clockwork_soldier", "shield_drone", "mechanical_serpent", "infinity_construct", "bomb_cart", "arcane_colossus"],
		"landmark": "The Firewall",
	},
	{
		"name": "Jungle Temples", "short": "Temples",
		"tagline": "Stone steps, water gardens, and vines that remember you.",
		"from": "#2a6a3a", "to": "#071a0d", "accent": "#9be06a", "glow": "#e0ffb8",
		"grass": "#4a9a4a", "stone": "#a8a878", "path": "#d8d0a0",
		"roster": ["jungle_guardian", "forest_entling", "marching_mushroom", "healer_pixie", "shadow_mage", "crystal_crab", "mechanical_serpent", "royal_siege_beast"],
		"landmark": "The Green Gate",
	},
	{
		"name": "Quantum Realm", "short": "Quantum",
		"tagline": "Two paths, both true, neither where you left it.",
		"from": "#4a2a6a", "to": "#0a0514", "accent": "#d06bff", "glow": "#f0d8ff",
		"grass": "#6a4a8a", "stone": "#a88ac8", "path": "#e0c8f8",
		"roster": ["portal_hopper", "arcane_mimic", "floating_eye", "crystal_phantom", "infinity_construct", "shield_drone", "arcane_colossus", "wind_elemental"],
		"landmark": "The Forking Gate",
	},
	{
		"name": "Dragon Mountains", "short": "Dragons",
		"tagline": "Every peak has a nest. Every nest has opinions.",
		"from": "#6a2a20", "to": "#180604", "accent": "#ff9a5a", "glow": "#ffd0a8",
		"grass": "#8a4a3a", "stone": "#a87a6a", "path": "#e8b898",
		"roster": ["toy_dragon", "fire_elemental", "mini_griffin", "lava_beetle", "royal_siege_beast", "siege_walker", "clockwork_rhino", "frost_golem"],
		"landmark": "The Dragon Perch",
	},
	{
		"name": "Moonlight Sanctuary", "short": "Sanctuary",
		"tagline": "Silver water and a lake that keeps the sky for you.",
		"from": "#2a3a5a", "to": "#060a14", "accent": "#dfe6ff", "glow": "#ffffff",
		"grass": "#5a7a8a", "stone": "#a8b8d8", "path": "#e8f0ff",
		"roster": ["healer_pixie", "floating_lantern", "frost_sprite", "snow_guardian", "crystal_phantom", "arcane_colossus", "shield_drone", "infinity_construct"],
		"landmark": "The Silver Lake",
	},
	{
		"name": "Legendary Dominion", "short": "Dominion",
		"tagline": "Every tower you have ever built, at ten times the scale.",
		"from": "#5a4a1a", "to": "#151005", "accent": "#ffd166", "glow": "#fff4c8",
		"grass": "#8a7a4a", "stone": "#c8b47a", "path": "#f0e0a8",
		"roster": ["royal_siege_beast", "golden_knight", "siege_walker", "clockwork_rhino", "toy_dragon", "arcane_colossus", "infinity_construct", "frost_golem"],
		"landmark": "The Crown Terrace",
	},
	{
		"name": "Infinity Kingdom", "short": "Infinity",
		"tagline": "The last board, and the whole toybox watching.",
		"from": "#1a4a4a", "to": "#04100f", "accent": "#8ff0d8", "glow": "#d8fff4",
		"grass": "#3a8f7a", "stone": "#a8c8c0", "path": "#d8f0e8",
		"roster": ["infinity_construct", "arcane_colossus", "royal_siege_beast", "toy_dragon", "frost_golem", "mechanical_serpent", "siege_walker", "clockwork_rhino"],
		"landmark": "The First Stone",
	},
]


static func clamp_level(id: int) -> int:
	return clampi(id, 1, LEVEL_COUNT)


static func kingdom_index(id: int) -> int:
	return clampi(int((clamp_level(id) - 1) / LEVELS_PER_KINGDOM), 0, KINGDOM_COUNT - 1)


static func kingdom(id: int) -> Dictionary:
	return KINGDOMS[kingdom_index(id)]


static func local_level(id: int) -> int:
	return ((clamp_level(id) - 1) % LEVELS_PER_KINGDOM) + 1


static func is_boss_level(id: int) -> bool:
	return local_level(id) % BOSS_EVERY == 0


static func level_seed(id: int) -> int:
	return clamp_level(id) * 7919 + 104729


static func level_name(id: int) -> String:
	return "%s %02d" % [String(kingdom(id)["short"]), local_level(id)]


static func hp_scale(id: int) -> float:
	return 1.0 + 0.09 * float(kingdom_index(id)) + 0.005 * float(local_level(id) - 1)


static func power_scale(id: int) -> float:
	return 1.0 + 0.11 * float(kingdom_index(id)) + 0.008 * float(local_level(id) - 1)


static func gold_scale(id: int) -> float:
	return 1.0 + 0.07 * float(kingdom_index(id)) + 0.004 * float(local_level(id) - 1)


static func start_gold(id: int) -> int:
	return 210 + 26 * kingdom_index(id) + 7 * local_level(id)


static func star_spec() -> String:
	return "2 stars: keep at least 80% of the heart.  3 stars: let nothing through."


# --------------------------------------------------------------------------
# level generation
# --------------------------------------------------------------------------

static func generate(id: int) -> Dictionary:
	var level_id := clamp_level(id)
	var k_index := kingdom_index(level_id)
	var local := local_level(level_id)
	var seed := level_seed(level_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var path := _make_path(rng)
	var on_path := {}
	for cell in path:
		on_path[_key(cell)] = true

	var free: Array = []
	for row in range(ROWS):
		for col in range(COLS):
			if not on_path.has(_key(Vector2i(row, col))):
				free.append(Vector2i(row, col))

	# A little scenery makes the board feel built rather than generated, and
	# takes a handful of sockets out of play so placement is a decision.
	var scenery: Array = []
	var wanted := 3 + rng.randi_range(0, 4)
	var pool := free.duplicate()
	_shuffle(pool, rng)
	for cell in pool:
		if scenery.size() >= wanted:
			break
		scenery.append(cell)
	var blocked := {}
	for cell in scenery:
		blocked[_key(cell)] = true
	var sockets: Array = []
	for cell in free:
		if not blocked.has(_key(cell)):
			sockets.append(cell)

	var boss := local % BOSS_EVERY == 0
	var waves := _build_waves(level_id, rng, boss, path.size())

	return {
		"id": level_id,
		"kingdom": k_index + 1,
		"kingdom_index": k_index,
		"kingdom_name": String(KINGDOMS[k_index]["name"]),
		"name": level_name(level_id),
		"local": local,
		"seed": seed,
		"boss": boss,
		"boss_index": k_index,
		"boss_name": String(Bosses.by_index(k_index)["name"]) if boss else "",
		"path": path,
		"waypoints": _waypoints(path),
		"scenery": scenery,
		"sockets": sockets,
		"start_gold": start_gold(level_id),
		"lives": 20,
		"waves": waves,
		"wave_count": waves.size(),
		"hp_scale": hp_scale(level_id),
		"power_scale": power_scale(level_id),
		"gold_scale": gold_scale(level_id),
		"allowed": Towers.available(k_index),
		"difficulty": _difficulty(level_id),
		"mode": "campaign",
		"endless": false,
		"palette": KINGDOMS[k_index],
		"music": "battle",
		"ambience": String(KINGDOMS[k_index]["short"]).to_lower(),
	}


static func _difficulty(id: int) -> String:
	var local := local_level(id)
	if local % 10 == 0:
		return "boss"
	if local % 5 == 0:
		return "elite"
	if local <= 3:
		return "tutorial"
	return "standard"


static func _key(cell: Vector2i) -> int:
	return cell.x * 31 + cell.y


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp: Variant = list[i]
		list[i] = list[j]
		list[j] = temp


## A road that always moves down the board, sometimes sideways, never over
## itself. Monotonic rows guarantee a loop-free path and therefore a valid
## route for every enemy.
static func _make_path(rng: RandomNumberGenerator) -> Array:
	var path: Array = []
	var row := 0
	var col := rng.randi_range(1, COLS - 2)
	path.append(Vector2i(row, col))
	var guard := 0
	while row < ROWS - 1 and guard < 60:
		guard += 1
		var run := rng.randi_range(2, 3)
		for step in range(run):
			if row >= ROWS - 1:
				break
			row += 1
			path.append(Vector2i(row, col))
		if row >= ROWS - 1:
			break
		var target := col
		while target == col:
			target = rng.randi_range(0, COLS - 1)
		var dir := 1 if target > col else -1
		while col != target:
			col += dir
			path.append(Vector2i(row, col))
	return path


## World-space points for the renderer and the simulation. Row 0 is the far end
## of the board (the spawn), the last row is the castle end nearest the camera.
static func _waypoints(path: Array) -> Array:
	var points: Array = []
	for cell in path:
		points.append(_world(cell))
	return points


static func _world(cell: Vector2i) -> Vector3:
	return Vector3(
		(float(cell.y) - (COLS - 1) * 0.5) * CELL,
		0.0,
		(float(cell.x) - (ROWS - 1) * 0.5) * CELL
	)


static func world_of(cell: Vector2i) -> Vector3:
	return _world(cell)


static func cell_of(point: Vector3) -> Vector2i:
	var col := int(round(point.x / CELL + (COLS - 1) * 0.5))
	var row := int(round(point.z / CELL + (ROWS - 1) * 0.5))
	return Vector2i(clampi(row, 0, ROWS - 1), clampi(col, 0, COLS - 1))


# --------------------------------------------------------------------------
# waves
# --------------------------------------------------------------------------

static func _build_waves(id: int, rng: RandomNumberGenerator, boss: bool, path_len: int) -> Array:
	var local := local_level(id)
	var count := clampi(4 + int(local / 8.0), 4, 8)
	var roster: Array = (KINGDOMS[kingdom_index(id)]["roster"] as Array)
	var waves: Array = []
	for wave in range(count):
		# The roster opens up across the kingdom so a new enemy type arrives at
		# a readable pace rather than all at once.
		var unlocked := clampi(4 + int(local / 7.0), 4, roster.size())
		var pool := roster.slice(0, unlocked)
		var budget := 7.0 + 2.6 * float(wave) + float(local) * 0.32 + float(path_len) * 0.12
		var groups: Array = []
		var guard := 0
		while budget > 0.6 and guard < 18:
			guard += 1
			var enemy_id := String(pool[rng.randi_range(0, pool.size() - 1)])
			if not Enemies.has(enemy_id):
				continue
			var cost := _cost(enemy_id)
			var amount := clampi(int(budget / cost), 1, 16)
			budget -= float(amount) * cost
			groups.append({
				"enemy": enemy_id,
				"count": amount,
				"gap": maxf(0.38, 0.95 - 0.04 * float(wave)),
				"delay": 0.0,
			})
		if groups.is_empty():
			groups.append({"enemy": String(pool[0]), "count": 4, "gap": 0.8, "delay": 0.0})
		for i in range(groups.size()):
			(groups[i] as Dictionary)["delay"] = 0.0 if i == 0 else 0.9 + 0.3 * float(i)
		waves.append({"groups": groups, "boss": false, "hp_scale": 0.85 + 0.06 * float(wave)})
	if boss:
		var boss_id := String((Bosses.by_index(kingdom_index(id))["summon"]))
		var escorts: Array = []
		if Enemies.has(boss_id):
			escorts.append({"enemy": boss_id, "count": 6, "gap": 0.55, "delay": 1.4})
		waves.append({"groups": escorts, "boss": true, "hp_scale": 1.0})
	return waves


static func _cost(enemy_id: String) -> float:
	var item := Enemies.by_id(enemy_id)
	if item.is_empty():
		return 3.0
	return maxf(1.2, float(item["hp"]) / 60.0 + float(item.get("threat", 1)) * 0.7)


## Campaign waves come from the record; endless and survival ask for one at a
## time. The synthesis is seeded, so wave 40 is the same on every device.
static func wave_for(level: Dictionary, index: int) -> Dictionary:
	var waves: Array = level.get("waves", [])
	if index < waves.size():
		return waves[index]
	if not bool(level.get("endless", false)):
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(level.get("seed", 1)) + index * 977
	var k_index := int(level.get("kingdom_index", 0))
	var roster: Array = KINGDOMS[k_index]["roster"]
	var pool := roster.slice(0, mini(roster.size(), 4 + int(index / 3.0)))
	var budget := 8.0 + float(index) * 2.4
	var groups: Array = []
	var guard := 0
	while budget > 0.8 and guard < 12:
		guard += 1
		var enemy_id := String(pool[rng.randi_range(0, pool.size() - 1)])
		if not Enemies.has(enemy_id):
			continue
		var cost := _cost(enemy_id)
		var amount := clampi(int(budget / cost), 1, 20)
		budget -= float(amount) * cost
		groups.append({"enemy": enemy_id, "count": amount, "gap": 0.6, "delay": 0.0})
	var boss := index > 0 and index % 8 == 0
	if boss:
		groups.append({"enemy": String(Bosses.by_index(k_index)["summon"]), "count": 4, "gap": 0.7, "delay": 1.2})
	return {
		"groups": groups,
		"boss": boss,
		"hp_scale": 0.9 + 0.05 * float(index),
	}


# --------------------------------------------------------------------------
# alternate modes
# --------------------------------------------------------------------------

static func generate_mode(mode: String, seed: int, k_index := 0) -> Dictionary:
	k_index = clampi(k_index, 0, KINGDOM_COUNT - 1)
	var level_id := clampi(k_index * LEVELS_PER_KINGDOM + 1, 1, LEVEL_COUNT)
	var base := generate(level_id)
	base["seed"] = seed
	base["mode"] = mode
	base["boss"] = false
	base["boss_name"] = ""
	base["boss_index"] = k_index
	base["palette"] = KINGDOMS[k_index]
	base["ambience"] = String(KINGDOMS[k_index]["short"]).to_lower()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var path := _make_path(rng)
	var on_path := {}
	for cell in path:
		on_path[_key(cell)] = true
	var free: Array = []
	for row in range(ROWS):
		for col in range(COLS):
			if not on_path.has(_key(Vector2i(row, col))):
				free.append(Vector2i(row, col))
	var blocked: Array = []
	var pool := free.duplicate()
	_shuffle(pool, rng)
	for i in range(mini(4, pool.size())):
		blocked.append(pool[i])
	var blocked_lookup := {}
	for cell in blocked:
		blocked_lookup[_key(cell)] = true
	var sockets: Array = []
	for cell in free:
		if not blocked_lookup.has(_key(cell)):
			sockets.append(cell)
	base["path"] = path
	base["waypoints"] = _waypoints(path)
	base["scenery"] = blocked
	base["sockets"] = sockets
	base["allowed"] = Towers.available(k_index, mode == "sandbox")
	base["hp_scale"] = 1.0 + 0.09 * float(k_index) + 0.02 * float(int(seed % 5))
	base["power_scale"] = 1.0 + 0.11 * float(k_index)
	base["gold_scale"] = 1.0 + 0.07 * float(k_index)
	match mode:
		"endless":
			base["name"] = "Endless Siege"
			base["waves"] = []
			base["endless"] = true
			base["start_gold"] = 420 + 30 * k_index
			base["lives"] = 15
			base["allowed"] = Towers.available(KINGDOM_COUNT - 1)
		"survival":
			base["name"] = "Survival"
			base["waves"] = []
			base["endless"] = false
			base["start_gold"] = 320 + 20 * k_index
			base["lives"] = 8
			base["allowed"] = Towers.available(KINGDOM_COUNT - 1)
			base["wave_count"] = 12
		"bossrush":
			base["name"] = "Boss Rush"
			base["waves"] = []
			base["endless"] = false
			base["start_gold"] = 560
			base["lives"] = 25
			base["allowed"] = Towers.available(KINGDOM_COUNT - 1)
			base["wave_count"] = 5
		"daily":
			base["name"] = "Daily Defense"
			base["waves"] = _build_waves(level_id, rng, false, path.size())
			base["wave_count"] = (base["waves"] as Array).size()
			base["endless"] = false
			base["start_gold"] = 360
			base["lives"] = 15
			base["allowed"] = Towers.available(KINGDOM_COUNT - 1)
		"sandbox":
			base["name"] = "Sandbox"
			base["waves"] = []
			base["endless"] = true
			base["start_gold"] = 9999
			base["lives"] = 999
			base["allowed"] = Towers.available(k_index, true)
		"fortress":
			base["name"] = "Fortress Builder"
			base["waves"] = []
			base["endless"] = true
			base["start_gold"] = 700
			base["lives"] = 20
			base["allowed"] = Towers.available(KINGDOM_COUNT - 1)
			base["fortress"] = true
	return base


# --------------------------------------------------------------------------
# validation
# --------------------------------------------------------------------------

## Everything a level must satisfy to be publishable. Returns human-readable
## problems; an empty array means the level is structurally sound.
static func validate(level: Dictionary) -> Array:
	var problems: Array = []
	var id := int(level.get("id", 0))
	var path: Array = level.get("path", [])
	if path.size() < 12:
		problems.append("L%d: path is only %d cells" % [id, path.size()])
		return problems
	if (path[0] as Vector2i).x != 0:
		problems.append("L%d: path must start on the top row" % id)
	if (path[path.size() - 1] as Vector2i).x != ROWS - 1:
		problems.append("L%d: path must end on the castle row" % id)
	var seen := {}
	for i in range(path.size()):
		var cell: Vector2i = path[i]
		if cell.x < 0 or cell.x >= ROWS or cell.y < 0 or cell.y >= COLS:
			problems.append("L%d: path leaves the board at %s" % [id, cell])
		if seen.has(_key(cell)):
			problems.append("L%d: path crosses itself at %s" % [id, cell])
		seen[_key(cell)] = true
		if i > 0:
			var prev: Vector2i = path[i - 1]
			if absi(prev.x - cell.x) + absi(prev.y - cell.y) != 1:
				problems.append("L%d: path jumps from %s to %s" % [id, prev, cell])
	var sockets: Array = level.get("sockets", [])
	if sockets.size() < 14:
		problems.append("L%d: only %d build sockets" % [id, sockets.size()])
	for cell in sockets:
		if seen.has(_key(cell)):
			problems.append("L%d: a socket sits on the road at %s" % [id, cell])
	var waves: Array = level.get("waves", [])
	var mode := String(level.get("mode", "campaign"))
	var needs_waves := mode == "campaign" or mode == "daily"
	if needs_waves:
		if waves.size() < 4:
			problems.append("L%d: only %d waves" % [id, waves.size()])
		for wave_index in range(waves.size()):
			var wave: Dictionary = waves[wave_index]
			var groups: Array = wave.get("groups", [])
			if groups.is_empty() and not bool(wave.get("boss", false)):
				problems.append("L%d: wave %d is empty" % [id, wave_index])
			for group in groups:
				var enemy_id := String(group.get("enemy", ""))
				if not Enemies.has(enemy_id):
					problems.append("L%d: wave %d uses unknown enemy %s" % [id, wave_index, enemy_id])
				if int(group.get("count", 0)) <= 0:
					problems.append("L%d: wave %d has a zero-count group" % [id, wave_index])
		if bool(level.get("boss", false)):
			var last: Dictionary = waves[waves.size() - 1]
			if not bool(last.get("boss", false)):
				problems.append("L%d: boss level has no boss wave" % id)
	if int(level.get("start_gold", 0)) < 150:
		problems.append("L%d: starting gold is too low" % id)
	if int(level.get("lives", 0)) <= 0:
		problems.append("L%d: lives must be positive" % id)
	if float(level.get("hp_scale", 0.0)) <= 0.0 or float(level.get("power_scale", 0.0)) <= 0.0:
		problems.append("L%d: scales must be positive" % id)
	for id_string in level.get("allowed", []):
		if not Towers.has(String(id_string)):
			problems.append("L%d: unknown tower %s" % [id, id_string])
	return problems


static func level_count_for(mode: String) -> int:
	match mode:
		"endless":
			return 1
		"survival":
			return 1
		"bossrush":
			return 1
		"daily":
			return 1
		"sandbox":
			return 1
		"fortress":
			return 1
		_:
			return LEVEL_COUNT
