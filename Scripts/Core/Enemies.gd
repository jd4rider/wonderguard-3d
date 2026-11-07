class_name Enemies
extends RefCounted
## The enemy roster: 48 mechanically distinct archetypes.
##
## Every enemy is data plus one behaviour tag that the battle simulation
## implements generically (`heal`, `shield`, `summon`, `split`, `phase`,
## `aura_armor`, `regen`, `dodge`, `rage`). `kind` drives category filtering in
## the bestiary and the wave composer's difficulty weighting.

const ITEMS: Array = [
	# ------------------------------------------------------------- basic
	{"id": "button_goblin", "name": "Button Goblin", "kind": "basic", "hp": 44.0, "speed": 1.05, "armor": 0.0, "reward": 5, "threat": 1, "color": "#8fbf6a", "model": "goblin", "size": 0.9, "ability": ""},
	{"id": "marching_mushroom", "name": "Marching Mushroom", "kind": "basic", "hp": 60.0, "speed": 0.85, "armor": 0.0, "reward": 6, "threat": 1, "color": "#d98ac0", "model": "slime", "size": 0.85, "ability": ""},
	{"id": "windup_skeleton", "name": "Wind-Up Skeleton", "kind": "basic", "hp": 52.0, "speed": 1.0, "armor": 0.5, "reward": 6, "threat": 1, "color": "#e8e2cf", "model": "knight", "size": 0.9, "ability": ""},
	{"id": "toy_slime", "name": "Toy Slime", "kind": "basic", "hp": 78.0, "speed": 0.8, "armor": 0.0, "reward": 6, "threat": 2, "color": "#7fd8b0", "model": "slime", "size": 1.0, "ability": "split"},
	{"id": "clockwork_mouse", "name": "Clockwork Mouse", "kind": "fast", "hp": 34.0, "speed": 1.7, "armor": 0.0, "reward": 5, "threat": 1, "color": "#c9b48a", "model": "mouse", "size": 0.7, "ability": ""},
	{"id": "forest_entling", "name": "Forest Entling", "kind": "basic", "hp": 95.0, "speed": 0.75, "armor": 1.5, "reward": 8, "threat": 2, "color": "#7a9e5a", "model": "grove", "size": 1.1, "ability": "regen"},
	{"id": "crystal_beetle", "name": "Crystal Beetle", "kind": "armored", "hp": 120.0, "speed": 0.9, "armor": 4.0, "reward": 10, "threat": 2, "color": "#a8c8ff", "model": "beetle", "size": 1.0, "ability": ""},
	{"id": "wooden_knight", "name": "Wooden Knight", "kind": "heavy", "hp": 165.0, "speed": 0.8, "armor": 2.5, "reward": 11, "threat": 3, "color": "#c9a26a", "model": "knight", "size": 1.15, "ability": ""},
	{"id": "armored_boar", "name": "Armored Boar", "kind": "heavy", "hp": 190.0, "speed": 0.95, "armor": 3.0, "reward": 12, "threat": 3, "color": "#a8846a", "model": "golem", "size": 1.1, "ability": "rage"},
	{"id": "frost_sprite", "name": "Frost Sprite", "kind": "magical", "hp": 70.0, "speed": 1.2, "armor": 0.0, "reward": 9, "threat": 2, "color": "#b8ecff", "model": "wraith", "size": 0.9, "ability": "", "resist": {"frost": 0.4, "fire": 1.35}},
	{"id": "ember_imp", "name": "Ember Imp", "kind": "magical", "hp": 66.0, "speed": 1.3, "armor": 0.5, "reward": 9, "threat": 2, "color": "#ff9a5a", "model": "imp", "size": 0.9, "ability": "", "resist": {"fire": 0.3, "frost": 1.35}},
	{"id": "floating_lantern", "name": "Floating Lantern", "kind": "flying", "hp": 74.0, "speed": 1.1, "armor": 0.0, "reward": 10, "threat": 2, "color": "#ffe6a0", "model": "wraith", "size": 0.9, "flying": true, "ability": "heal"},
	{"id": "glider_bat", "name": "Glider Bat", "kind": "flying", "hp": 48.0, "speed": 1.55, "armor": 0.0, "reward": 8, "threat": 1, "color": "#9f8bbf", "model": "bat", "size": 0.85, "flying": true, "ability": ""},
	{"id": "mechanical_spider", "name": "Mechanical Spider", "kind": "mechanical", "hp": 105.0, "speed": 1.25, "armor": 1.0, "reward": 11, "threat": 2, "color": "#8fa0b8", "model": "spider", "size": 0.95, "ability": ""},
	{"id": "mini_stone_golem", "name": "Mini Stone Golem", "kind": "heavy", "hp": 260.0, "speed": 0.65, "armor": 5.0, "reward": 16, "threat": 4, "color": "#9aa3a8", "model": "golem", "size": 1.25, "ability": "", "resist": {"physical": 0.7, "siege": 0.65}},
	{"id": "shield_carrier", "name": "Shield Carrier", "kind": "shielded", "hp": 150.0, "speed": 0.9, "armor": 2.0, "reward": 12, "threat": 3, "color": "#c9d6a8", "model": "knight", "size": 1.05, "ability": "aura_armor"},
	{"id": "healer_pixie", "name": "Healer Pixie", "kind": "support", "hp": 58.0, "speed": 1.1, "armor": 0.0, "reward": 10, "threat": 1, "color": "#9fffd0", "model": "wraith", "size": 0.85, "flying": true, "ability": "heal"},
	{"id": "bomb_cart", "name": "Bomb Cart", "kind": "heavy", "hp": 130.0, "speed": 1.15, "armor": 1.0, "reward": 11, "threat": 4, "color": "#d96a4a", "model": "construct", "size": 1.0, "ability": ""},
	{"id": "shadow_runner", "name": "Shadow Runner", "kind": "stealth", "hp": 68.0, "speed": 1.65, "armor": 0.0, "reward": 11, "threat": 2, "color": "#7a6f9e", "model": "wraith", "size": 0.95, "ability": "dodge"},
	{"id": "crystal_crab", "name": "Crystal Crab", "kind": "armored", "hp": 175.0, "speed": 0.75, "armor": 6.0, "reward": 13, "threat": 3, "color": "#9fd8c8", "model": "beetle", "size": 1.1, "ability": ""},
	{"id": "goblin_engineer", "name": "Goblin Engineer", "kind": "support", "hp": 90.0, "speed": 1.0, "armor": 0.5, "reward": 12, "threat": 2, "color": "#a8c46a", "model": "goblin", "size": 0.95, "ability": "summon"},
	{"id": "clockwork_soldier", "name": "Clockwork Soldier", "kind": "mechanical", "hp": 145.0, "speed": 1.0, "armor": 3.0, "reward": 13, "threat": 3, "color": "#b8a878", "model": "knight", "size": 1.0, "ability": ""},
	{"id": "floating_eye", "name": "Floating Eye Construct", "kind": "magical", "hp": 110.0, "speed": 1.0, "armor": 0.0, "reward": 13, "threat": 2, "color": "#c8a0ff", "model": "construct", "size": 1.0, "flying": true, "ability": "phase"},
	{"id": "thunder_sprite", "name": "Thunder Sprite", "kind": "magical", "hp": 82.0, "speed": 1.35, "armor": 0.0, "reward": 11, "threat": 2, "color": "#9fd0ff", "model": "wraith", "size": 0.9, "flying": true, "ability": ""},
	{"id": "toy_dragon", "name": "Toy Dragon", "kind": "elite", "hp": 340.0, "speed": 0.95, "armor": 3.0, "reward": 22, "threat": 5, "color": "#e07a5a", "model": "golem", "size": 1.35, "flying": true, "ability": "rage", "resist": {"fire": 0.5}},
	{"id": "snow_guardian", "name": "Snow Guardian", "kind": "heavy", "hp": 300.0, "speed": 0.7, "armor": 4.0, "reward": 18, "threat": 4, "color": "#cfeaff", "model": "golem", "size": 1.25, "ability": "shield", "resist": {"frost": 0.35}},
	{"id": "jungle_guardian", "name": "Jungle Guardian", "kind": "elite", "hp": 380.0, "speed": 0.8, "armor": 4.5, "reward": 22, "threat": 5, "color": "#7fc46a", "model": "grove", "size": 1.35, "ability": "regen"},
	{"id": "oil_slime", "name": "Oil Slime", "kind": "basic", "hp": 120.0, "speed": 0.9, "armor": 0.0, "reward": 10, "threat": 2, "color": "#5a5a6a", "model": "slime", "size": 1.05, "ability": "split", "resist": {"fire": 1.6}},
	{"id": "arcane_mimic", "name": "Arcane Mimic", "kind": "magical", "hp": 190.0, "speed": 1.05, "armor": 1.0, "reward": 15, "threat": 3, "color": "#c09bff", "model": "construct", "size": 1.05, "ability": "phase", "resist": {"arcane": 0.4}},
	{"id": "golden_knight", "name": "Golden Knight", "kind": "armored", "hp": 420.0, "speed": 0.85, "armor": 8.0, "reward": 24, "threat": 5, "color": "#ffd166", "model": "knight", "size": 1.2, "ability": "shield"},
	{"id": "mechanical_serpent", "name": "Mechanical Serpent", "kind": "mechanical", "hp": 360.0, "speed": 1.1, "armor": 5.0, "reward": 22, "threat": 4, "color": "#8fa89f", "model": "spider", "size": 1.2, "ability": "split"},
	{"id": "portal_hopper", "name": "Portal Hopper", "kind": "stealth", "hp": 150.0, "speed": 1.5, "armor": 0.0, "reward": 16, "threat": 2, "color": "#7be0ff", "model": "wraith", "size": 1.0, "ability": "dodge"},
	{"id": "shield_drone", "name": "Shield Drone", "kind": "shielded", "hp": 200.0, "speed": 1.2, "armor": 2.0, "reward": 17, "threat": 3, "color": "#a8d8ff", "model": "construct", "size": 1.0, "flying": true, "ability": "shield"},
	{"id": "lava_beetle", "name": "Lava Beetle", "kind": "armored", "hp": 260.0, "speed": 1.0, "armor": 5.0, "reward": 19, "threat": 4, "color": "#ff7a4a", "model": "beetle", "size": 1.1, "ability": "", "resist": {"fire": 0.25, "frost": 1.4}},
	{"id": "wind_elemental", "name": "Wind Elemental", "kind": "flying", "hp": 170.0, "speed": 1.75, "armor": 0.0, "reward": 16, "threat": 2, "color": "#c8f0ff", "model": "wraith", "size": 1.0, "flying": true, "ability": "dodge"},
	{"id": "clockwork_rhino", "name": "Clockwork Rhino", "kind": "heavy", "hp": 520.0, "speed": 0.9, "armor": 7.0, "reward": 28, "threat": 6, "color": "#a89a7a", "model": "golem", "size": 1.3, "ability": "rage"},
	{"id": "crystal_phantom", "name": "Crystal Phantom", "kind": "stealth", "hp": 240.0, "speed": 1.3, "armor": 0.0, "reward": 20, "threat": 3, "color": "#b8a8ff", "model": "wraith", "size": 1.05, "ability": "phase", "flying": true},
	{"id": "mini_griffin", "name": "Mini Griffin", "kind": "flying", "hp": 280.0, "speed": 1.45, "armor": 2.0, "reward": 20, "threat": 4, "color": "#e8d4a8", "model": "bat", "size": 1.1, "flying": true, "ability": ""},
	{"id": "fire_elemental", "name": "Fire Elemental", "kind": "magical", "hp": 330.0, "speed": 1.15, "armor": 1.0, "reward": 22, "threat": 4, "color": "#ff9a3a", "model": "imp", "size": 1.2, "ability": "regen", "flying": true, "resist": {"fire": 0.2, "frost": 1.5}},
	{"id": "frost_golem", "name": "Frost Golem", "kind": "heavy", "hp": 620.0, "speed": 0.7, "armor": 9.0, "reward": 32, "threat": 7, "color": "#a8e0ff", "model": "golem", "size": 1.4, "ability": "shield", "resist": {"frost": 0.2, "fire": 1.4}},
	{"id": "siege_walker", "name": "Armored Siege Walker", "kind": "heavy", "hp": 700.0, "speed": 0.65, "armor": 10.0, "reward": 36, "threat": 8, "color": "#9a8a78", "model": "construct", "size": 1.45, "ability": ""},
	{"id": "shadow_mage", "name": "Shadow Mage", "kind": "support", "hp": 260.0, "speed": 1.0, "armor": 1.0, "reward": 24, "threat": 3, "color": "#8f7ab8", "model": "wraith", "size": 1.05, "ability": "summon"},
	{"id": "mechanical_wasp", "name": "Mechanical Wasp", "kind": "flying", "hp": 210.0, "speed": 1.85, "armor": 1.0, "reward": 20, "threat": 3, "color": "#d8c46a", "model": "bat", "size": 0.95, "flying": true, "ability": ""},
	{"id": "arcane_colossus", "name": "Arcane Colossus", "kind": "elite", "hp": 980.0, "speed": 0.6, "armor": 6.0, "reward": 48, "threat": 10, "color": "#b08fff", "model": "construct", "size": 1.5, "ability": "phase", "resist": {"arcane": 0.35}},
	{"id": "royal_siege_beast", "name": "Royal Siege Beast", "kind": "elite", "hp": 1150.0, "speed": 0.75, "armor": 12.0, "reward": 55, "threat": 12, "color": "#d9a24a", "model": "golem", "size": 1.55, "ability": "rage"},
	{"id": "infinity_construct", "name": "Infinity Construct", "kind": "elite", "hp": 1500.0, "speed": 0.8, "armor": 8.0, "reward": 60, "threat": 14, "color": "#8ff0d8", "model": "construct", "size": 1.5, "ability": "shield", "flying": true},
	{"id": "boss_core_small", "name": "Husk Sentry", "kind": "mechanical", "hp": 400.0, "speed": 1.1, "armor": 4.0, "reward": 18, "threat": 3, "color": "#a8b8c8", "model": "construct", "size": 1.1, "ability": ""},
	{"id": "zephyr_skitter", "name": "Zephyr Skitter", "kind": "fast", "hp": 42.0, "speed": 1.9, "armor": 0.0, "reward": 6, "threat": 1, "color": "#a8f0e0", "model": "mouse", "size": 0.72, "ability": "dodge"},
]

const MODELS := ["goblin", "mouse", "slime", "knight", "beetle", "imp", "spider", "golem", "bat", "wraith", "construct", "grove"]


static func count() -> int:
	return ITEMS.size()


static func by_id(id: String) -> Dictionary:
	for item in ITEMS:
		if String(item["id"]) == id:
			return item
	return {}


static func has(id: String) -> bool:
	return not by_id(id).is_empty()


static func of_kind(kind: String) -> Array:
	var out: Array = []
	for item in ITEMS:
		if String(item["kind"]) == kind:
			out.append(String(item["id"]))
	return out


static func flying(id: String) -> bool:
	return bool(by_id(id).get("flying", false))


static func resist(id: String, damage_type: String) -> float:
	var table: Dictionary = by_id(id).get("resist", {})
	return float(table.get(damage_type, 1.0))


static func threat(id: String) -> int:
	return int(by_id(id).get("threat", 1))


static func reward(id: String) -> int:
	return int(by_id(id).get("reward", 5))


static func costume(id: String, tint: Color, scale := 1.0) -> Dictionary:
	var item := by_id(id)
	return {
		"model": String(item.get("model", "goblin")),
		"color": tint,
		"size": float(item.get("size", 1.0)) * scale,
	}
