class_name Bosses
extends RefCounted
## The twenty kingdom bosses.
##
## A boss is an enemy with a health pool large enough to survive long enough for
## its phases to matter. Phase two and three change speed, armour and how often
## it calls reinforcements, so the fight escalates instead of just lasting
## longer.

const ITEMS: Array = [
	{"name": "The Mosswood Giant", "title": "Warden of the Emerald Meadow", "hp": 1100.0, "armor": 2.0, "speed": 0.5, "color": "#7fc46a", "model": "golem", "size": 2.0,
		"summon": "button_goblin", "aura": "regen", "phases": ["Rootbound", "Bramble Storm", "Heartwood Rage"]},
	{"name": "The Golden Sentinel", "title": "Keeper of the Gilded Gate", "hp": 1600.0, "armor": 4.0, "speed": 0.5, "color": "#ffd166", "model": "knight", "size": 2.05,
		"summon": "golden_knight", "aura": "armor", "phases": ["Polished Guard", "Shield Wall", "Golden Overdrive"]},
	{"name": "The Frost Colossus", "title": "The Preserved Sovereign", "hp": 2200.0, "armor": 6.0, "speed": 0.45, "color": "#a8e0ff", "model": "golem", "size": 2.15,
		"summon": "frost_sprite", "aura": "shield", "phases": ["Deep Freeze", "Glacier Fist", "Absolute Zero"]},
	{"name": "The Ember Dragon", "title": "Furnace of the Valley", "hp": 2800.0, "armor": 5.0, "speed": 0.55, "color": "#ff7a4a", "model": "imp", "size": 2.1,
		"summon": "ember_imp", "aura": "rage", "phases": ["Smoulder", "Backdraft", "Inferno Wings"]},
	{"name": "The Clockwork Titan", "title": "Foreman of the Great Gears", "hp": 3500.0, "armor": 8.0, "speed": 0.45, "color": "#c9b48a", "model": "construct", "size": 2.25,
		"summon": "clockwork_soldier", "aura": "armor", "phases": ["Winding Up", "Full Torque", "Overclocked"]},
	{"name": "The Tidal Leviathan", "title": "Mother of the Isles", "hp": 4200.0, "armor": 6.0, "speed": 0.5, "color": "#5fc9d8", "model": "spider", "size": 2.2,
		"summon": "crystal_crab", "aura": "shield", "phases": ["Low Tide", "Riptide", "Maelstrom"]},
	{"name": "The Ancient Treant", "title": "First Root of the Forest", "hp": 5000.0, "armor": 7.0, "speed": 0.4, "color": "#6fb04a", "model": "grove", "size": 2.3,
		"summon": "forest_entling", "aura": "regen", "phases": ["Dormant", "Awakened Bark", "Elder Bloom"]},
	{"name": "The Storm Warden", "title": "Conductor of the Highlands", "hp": 5800.0, "armor": 5.0, "speed": 0.6, "color": "#9fd0ff", "model": "wraith", "size": 2.1,
		"summon": "thunder_sprite", "aura": "rage", "phases": ["Gathering", "Thunderhead", "Lightning Crown"]},
	{"name": "The Sandstone Behemoth", "title": "The Worn Crown", "hp": 6700.0, "armor": 10.0, "speed": 0.4, "color": "#e8b45c", "model": "golem", "size": 2.35,
		"summon": "armored_boar", "aura": "armor", "phases": ["Sunbaked", "Sandstorm", "Buried Colossus"]},
	{"name": "The Crystal Sovereign", "title": "Voice of the Caverns", "hp": 7600.0, "armor": 8.0, "speed": 0.5, "color": "#b79bff", "model": "beetle", "size": 2.2,
		"summon": "crystal_phantom", "aura": "shield", "phases": ["Facet", "Refraction", "Prism Break"]},
	{"name": "The Sky Fortress", "title": "The Floating Citadel", "hp": 8600.0, "armor": 9.0, "speed": 0.35, "color": "#c8e8ff", "model": "construct", "size": 2.4,
		"summon": "shield_drone", "aura": "armor", "phases": ["Docking", "Broadside", "Full Broadside"]},
	{"name": "The Starforged Guardian", "title": "Shield of the Constellations", "hp": 9600.0, "armor": 11.0, "speed": 0.45, "color": "#8fa8ff", "model": "knight", "size": 2.3,
		"summon": "floating_eye", "aura": "shield", "phases": ["Starlit", "Nova Guard", "Starfall"]},
	{"name": "The Phantom King", "title": "The Empty Throne", "hp": 10700.0, "armor": 6.0, "speed": 0.6, "color": "#a8a0d8", "model": "wraith", "size": 2.2,
		"summon": "shadow_mage", "aura": "phase", "phases": ["Half-Seen", "Court of Shades", "Uncrowned"]},
	{"name": "The Mecha Overlord", "title": "Master of the Neon Foundry", "hp": 11800.0, "armor": 13.0, "speed": 0.45, "color": "#7be0ff", "model": "construct", "size": 2.45,
		"summon": "mechanical_wasp", "aura": "armor", "phases": ["Boot Sequence", "Combat Protocol", "Overdrive"]},
	{"name": "The Temple Guardian", "title": "Keeper of the Green Gate", "hp": 13000.0, "armor": 9.0, "speed": 0.45, "color": "#d8b86a", "model": "golem", "size": 2.4,
		"summon": "jungle_guardian", "aura": "regen", "phases": ["Stone Sleep", "Temple Awake", "Verdant Wrath"]},
	{"name": "The Quantum Architect", "title": "Both Answers at Once", "hp": 14200.0, "armor": 8.0, "speed": 0.55, "color": "#d06bff", "model": "construct", "size": 2.35,
		"summon": "portal_hopper", "aura": "phase", "phases": ["Superposition", "Collapse", "Entangled"]},
	{"name": "The Dragon Monarch", "title": "Crown of the Mountains", "hp": 15500.0, "armor": 12.0, "speed": 0.5, "color": "#ff9a5a", "model": "imp", "size": 2.6,
		"summon": "toy_dragon", "aura": "rage", "phases": ["Wingbeat", "Firestorm", "Sovereign Flame"]},
	{"name": "The Lunar Guardian", "title": "Lantern of the Silver Lake", "hp": 16800.0, "armor": 10.0, "speed": 0.5, "color": "#dfe6ff", "model": "wraith", "size": 2.4,
		"summon": "healer_pixie", "aura": "shield", "phases": ["Moonrise", "Eclipse", "Full Moon"]},
	{"name": "The Legendary Conqueror", "title": "The Crowned Machine", "hp": 18200.0, "armor": 14.0, "speed": 0.45, "color": "#ffd166", "model": "knight", "size": 2.5,
		"summon": "royal_siege_beast", "aura": "armor", "phases": ["Standard", "Conquest", "Legend"]},
	{"name": "The Infinity Sovereign", "title": "The Last Wall", "hp": 20000.0, "armor": 16.0, "speed": 0.5, "color": "#8ff0d8", "model": "construct", "size": 2.7,
		"summon": "infinity_construct", "aura": "phase", "phases": ["Endless", "Forever", "Infinity"]},
]


static func count() -> int:
	return ITEMS.size()


static func by_index(index: int) -> Dictionary:
	return ITEMS[clampi(index, 0, ITEMS.size() - 1)]


## The stat block for a boss in a given kingdom at a world scale.
static func stats(index: int, scale := 1.0, phase := 1) -> Dictionary:
	var base: Dictionary = by_index(index).duplicate(true)
	base["hp"] = float(base["hp"]) * scale * (0.85 + 0.15 * float(phase))
	base["armor"] = float(base["armor"]) + 3.0 * float(phase - 1)
	base["speed"] = float(base["speed"]) * (1.0 + 0.18 * float(phase - 1))
	base["phase"] = phase
	base["phase_name"] = String((base["phases"] as Array)[clampi(phase - 1, 0, 2)])
	base["minion_hp"] = 0.6
	base["summon_interval"] = maxf(2.2, 6.5 - 1.3 * float(phase - 1))
	return base
