class_name Towers
extends RefCounted
## The 24 tower families.
##
## A tower is pure data: the battle simulation reads `attack`, `dmg`, `rate`,
## `range` and `effect`, and the 3D view reads `shape`, `color` and `glow`. Each
## family has three linear tiers and then two genuinely different ultimates, so
## the branching decision changes how the tower plays rather than just its
## numbers.

const MAX_TIER := 4
const TIER_MULT := [1.0, 1.6, 2.5, 3.9]
const TIER_RANGE := [0.0, 0.12, 0.26, 0.45]
const REBUILD := [0.0, 0.85, 1.25, 2.0]
const CATEGORIES := ["Physical", "Elemental", "Arcane", "Support", "Control", "Summoning"]

## The order towers open up in. Kingdom 1 starts with seven families; every
## kingdom unlocks roughly one more, and the whole shelf is open by kingdom 18.
const UNLOCK_ORDER := [
	"ballista", "cannon", "frostbloom", "emberbark", "banner", "ballista_drum",
	"boltguard", "gearspitter", "grove", "drum", "mist", "tesla",
	"prismspire", "mint", "hive", "chronobell", "mortar", "tidecaller",
	"runeweaver", "barracks", "magnet", "moonbeam", "amplifier", "roost",
	"portalist", "foundry",
]

const ITEMS: Array = [
	# ---------------------------------------------------------------- physical
	{
		"id": "ballista", "name": "Boltguard Ballista", "cat": "Physical",
		"blurb": "A brass crossbow on a wooden tower. Punishes single targets.",
		"cost": 90, "type": "physical", "attack": "bolt",
		"dmg": 17.0, "rate": 0.85, "range": 3.9, "speed": 20.0,
		"color": "#c9a06a", "glow": "#ffe2a8", "shape": "ballista",
		"effect": {}, "air": false,
		"branch": {
			"a": {"name": "Skyneedle Arbalest", "note": "One enormous piercing bolt.", "mod": {"dmg": 2.4, "rate": 0.8, "range": 0.5}},
			"b": {"name": "Storm Volley", "note": "Three bolts per shot.", "mod": {"dmg": 0.8, "rate": 0.95, "count": 3}},
		},
	},
	{
		"id": "cannon", "name": "Ironjaw Cannon", "cat": "Physical",
		"blurb": "A polished fortress cannon. Splash damage for tight packs.",
		"cost": 130, "type": "siege", "attack": "splash",
		"dmg": 30.0, "rate": 0.5, "range": 3.5, "speed": 14.0, "splash": 1.15,
		"color": "#8d97a8", "glow": "#ffb45c", "shape": "cannon",
		"effect": {}, "air": false,
		"branch": {
			"a": {"name": "Siege Monarch", "note": "Huge shells, huge blast.", "mod": {"dmg": 2.6, "rate": 0.85, "splash": 0.75}},
			"b": {"name": "Thunder Battery", "note": "A cluster of fast barrels.", "mod": {"dmg": 0.7, "rate": 1.9, "count": 2, "splash": -0.35}},
		},
	},
	{
		"id": "gearspitter", "name": "Gearspitter", "cat": "Physical",
		"blurb": "Spinning brass gears fling a constant stream of shot.",
		"cost": 110, "type": "physical", "attack": "burst",
		"dmg": 7.0, "rate": 2.2, "range": 3.1, "speed": 24.0,
		"color": "#b08a58", "glow": "#ffd08a", "shape": "gears",
		"effect": {}, "air": false,
		"branch": {
			"a": {"name": "Ricochet Works", "note": "Shots bounce to a second target.", "mod": {"dmg": 1.7, "chain": 1, "speed": 0.2}},
			"b": {"name": "Hailspitter", "note": "Seven tiny gears at once.", "mod": {"dmg": 0.55, "count": 3, "rate": 1.15}},
		},
	},
	{
		"id": "mortar", "name": "Mortar Mound", "cat": "Physical",
		"blurb": "Arcing shells that land on the road from far away.",
		"cost": 150, "type": "siege", "attack": "splash",
		"dmg": 42.0, "rate": 0.38, "range": 5.2, "speed": 10.0, "splash": 1.35,
		"color": "#8a6c4a", "glow": "#ffcf7a", "shape": "mortar",
		"effect": {}, "air": false,
		"branch": {
			"a": {"name": "Earthshaker", "note": "Blast radius the size of a road.", "mod": {"dmg": 1.9, "splash": 1.1, "range": 0.6}},
			"b": {"name": "Cluster Battery", "note": "Two shells that leave fire.", "mod": {"dmg": 0.9, "rate": 1.5, "count": 2, "effect": {"kind": "burn", "dps": 9.0, "secs": 3.0}}},
		},
	},
	# --------------------------------------------------------------- elemental
	{
		"id": "frostbloom", "name": "Frostbloom Spire", "cat": "Elemental",
		"blurb": "Crystalline ice that chills, then freezes solid.",
		"cost": 120, "type": "frost", "attack": "slow",
		"dmg": 9.0, "rate": 0.9, "range": 3.4, "speed": 18.0,
		"color": "#9fe3ff", "glow": "#dffbff", "shape": "frost",
		"effect": {"kind": "slow", "factor": 0.55, "secs": 2.2}, "air": true,
		"branch": {
			"a": {"name": "Glacier Bloom", "note": "Freezes enemies in place.", "mod": {"effect": {"kind": "freeze", "secs": 1.1}, "dmg": 1.2}},
			"b": {"name": "Rime Blizzard", "note": "Blast of cold over a wide area.", "mod": {"attack": "splash", "splash": 1.1, "dmg": 1.5, "rate": 0.9}},
		},
	},
	{
		"id": "emberbark", "name": "Emberbark Furnace", "cat": "Elemental",
		"blurb": "A mechanical dragon mouth that pours fire onto the road.",
		"cost": 140, "type": "fire", "attack": "splash",
		"dmg": 20.0, "rate": 0.75, "range": 2.9, "speed": 16.0, "splash": 0.85,
		"color": "#e8703a", "glow": "#ffc27a", "shape": "ember",
		"effect": {"kind": "burn", "dps": 7.0, "secs": 2.5}, "air": false,
		"branch": {
			"a": {"name": "Cinder Maw", "note": "Long, hungry burn.", "mod": {"dmg": 1.5, "effect": {"kind": "burn", "dps": 15.0, "secs": 4.0}}},
			"b": {"name": "Flame Wave", "note": "Every shot is a rolling wall of fire.", "mod": {"attack": "splash", "splash": 1.4, "dmg": 1.8, "rate": 0.75}},
		},
	},
	{
		"id": "tesla", "name": "Stormcoil Tesla", "cat": "Elemental",
		"blurb": "Chain lightning that leaps between clustered enemies.",
		"cost": 160, "type": "lightning", "attack": "chain",
		"dmg": 17.0, "rate": 0.8, "range": 3.6, "speed": 0.0, "chain": 2,
		"color": "#7cc6ff", "glow": "#d9f2ff", "shape": "tesla",
		"effect": {}, "air": true,
		"branch": {
			"a": {"name": "Tempest Coil", "note": "Five hops, stronger with each.", "mod": {"chain": 3, "dmg": 1.35, "range": 0.4}},
			"b": {"name": "Ball Lightning", "note": "Slow orbs that shock everything nearby.", "mod": {"attack": "splash", "splash": 1.2, "dmg": 1.7, "chain": -1}},
		},
	},
	{
		"id": "tidecaller", "name": "Tidecaller Fountain", "cat": "Elemental",
		"blurb": "Soaks enemies so lightning hits far harder.",
		"cost": 130, "type": "water", "attack": "splash",
		"dmg": 15.0, "rate": 0.7, "range": 3.2, "speed": 15.0, "splash": 1.0,
		"color": "#5fc9d8", "glow": "#bff6ff", "shape": "tide",
		"effect": {"kind": "soak", "secs": 4.0}, "air": false,
		"branch": {
			"a": {"name": "Tidal Font", "note": "Soaks a much wider stretch of road.", "mod": {"splash": 1.3, "dmg": 1.4}},
			"b": {"name": "Riptide Engine", "note": "Fast pulses that push enemies back.", "mod": {"rate": 1.8, "dmg": 0.8, "effect": {"kind": "pull", "amount": 0.55}}},
		},
	},
	# ------------------------------------------------------------------ arcane
	{
		"id": "prismspire", "name": "Prismspire", "cat": "Arcane",
		"blurb": "A focused beam that ignores a share of armour.",
		"cost": 170, "type": "arcane", "attack": "beam",
		"dmg": 26.0, "rate": 0.95, "range": 4.0, "speed": 0.0,
		"color": "#b79bff", "glow": "#eadcff", "shape": "prism",
		"effect": {"kind": "pierce", "amount": 0.5}, "air": true,
		"branch": {
			"a": {"name": "Prism Cascade", "note": "Splits the beam into three lanes.", "mod": {"count": 3, "dmg": 0.65}},
			"b": {"name": "Singular Lens", "note": "One beam that cuts through everything.", "mod": {"dmg": 2.8, "effect": {"kind": "pierce", "amount": 0.9}}},
		},
	},
	{
		"id": "moonbeam", "name": "Moonbeam Observatory", "cat": "Arcane",
		"blurb": "Marks a priority target for bonus damage from every tower.",
		"cost": 190, "type": "arcane", "attack": "beam",
		"dmg": 34.0, "rate": 0.65, "range": 4.4, "speed": 0.0,
		"color": "#dfe6ff", "glow": "#ffffff", "shape": "moon",
		"effect": {"kind": "mark", "secs": 3.5, "amount": 0.3}, "air": true,
		"branch": {
			"a": {"name": "Eclipse Array", "note": "Marks everything it hits.", "mod": {"attack": "splash", "splash": 1.5, "dmg": 1.3}},
			"b": {"name": "Comet Lancet", "note": "Huge single hit on the marked target.", "mod": {"dmg": 2.4, "effect": {"kind": "mark", "secs": 5.0, "amount": 0.5}}},
		},
	},
	{
		"id": "runeweaver", "name": "Runeweaver Shrine", "cat": "Arcane",
		"blurb": "Curses enemies in range, widening every elemental weakness.",
		"cost": 150, "type": "arcane", "attack": "aura",
		"dmg": 6.0, "rate": 1.0, "range": 3.0, "speed": 0.0,
		"color": "#9b7bff", "glow": "#d9c8ff", "shape": "rune",
		"effect": {"kind": "weaken", "secs": 1.2, "amount": 0.22}, "air": true,
		"branch": {
			"a": {"name": "Hex Cathedral", "note": "Curses a third of the board.", "mod": {"range": 1.6, "effect": {"kind": "weaken", "secs": 2.0, "amount": 0.34}}},
			"b": {"name": "Sigil of Ruin", "note": "Also burns and soaks what it touches.", "mod": {"effect": {"kind": "weaken", "secs": 2.0, "amount": 0.3}, "dmg": 2.0, "rate": 1.3}},
		},
	},
	{
		"id": "portalist", "name": "Portalist Gateway", "cat": "Arcane",
		"blurb": "Teleports the leading enemy back down the road.",
		"cost": 210, "type": "arcane", "attack": "portal",
		"dmg": 12.0, "rate": 0.25, "range": 4.6, "speed": 0.0,
		"color": "#7be0ff", "glow": "#c8f6ff", "shape": "portal",
		"effect": {"kind": "portal", "amount": 2.6}, "air": true,
		"branch": {
			"a": {"name": "Voidgate Array", "note": "Sends a whole cluster back.", "mod": {"count": 3, "dmg": 1.2}},
			"b": {"name": "Anchor Rift", "note": "Further back, and stuns on arrival.", "mod": {"effect": {"kind": "portal", "amount": 5.0, "stun": 1.0}, "rate": 1.25}},
		},
	},
	# ----------------------------------------------------------------- support
	{
		"id": "banner", "name": "Banner Keep", "cat": "Support",
		"blurb": "Inspiring banners quicken every tower around it.",
		"cost": 140, "type": "none", "attack": "aura",
		"dmg": 0.0, "rate": 1.0, "range": 2.7, "speed": 0.0,
		"color": "#ffd166", "glow": "#fff0b8", "shape": "banner",
		"effect": {"kind": "buff", "rate": 0.25, "dmg": 0.12}, "air": true,
		"branch": {
			"a": {"name": "Warband Standard", "note": "Far more attack speed nearby.", "mod": {"range": 1.0, "effect": {"kind": "buff", "rate": 0.5, "dmg": 0.2}}},
			"b": {"name": "Crown Battery", "note": "Far more damage nearby.", "mod": {"range": 0.5, "effect": {"kind": "buff", "rate": 0.15, "dmg": 0.55}}},
		},
	},
	{
		"id": "mint", "name": "Mint Workshop", "cat": "Support",
		"blurb": "Prints a steady trickle of battle gold. Pays for itself late.",
		"cost": 120, "type": "none", "attack": "income",
		"dmg": 0.0, "rate": 0.5, "range": 0.0, "speed": 0.0,
		"color": "#ffcf5c", "glow": "#fff3c4", "shape": "mint",
		"effect": {"kind": "income", "gold": 9.0}, "air": true,
		"branch": {
			"a": {"name": "Royal Treasury", "note": "A big, slow payout.", "mod": {"effect": {"kind": "income", "gold": 34.0}, "rate": 0.45}},
			"b": {"name": "Coin Fountain", "note": "Small payouts, constantly.", "mod": {"effect": {"kind": "income", "gold": 8.0}, "rate": 1.9}},
		},
	},
	{
		"id": "chronobell", "name": "Chronobell Tower", "cat": "Support",
		"blurb": "Bends time: nearby enemies crawl, nearby towers hurry.",
		"cost": 200, "type": "arcane", "attack": "aura",
		"dmg": 5.0, "rate": 1.0, "range": 2.9, "speed": 0.0,
		"color": "#8ae0d0", "glow": "#d6fff7", "shape": "bell",
		"effect": {"kind": "time", "slow": 0.4, "rate": 0.16}, "air": true,
		"branch": {
			"a": {"name": "Long Hour", "note": "Almost stops nearby enemies.", "mod": {"range": 1.2, "effect": {"kind": "time", "slow": 0.7, "rate": 0.12}}},
			"b": {"name": "Metronome", "note": "Nearby towers fire much faster.", "mod": {"effect": {"kind": "time", "slow": 0.2, "rate": 0.45}}},
		},
	},
	{
		"id": "amplifier", "name": "Crystal Amplifier", "cat": "Support",
		"blurb": "Channels raw power into neighbouring magical towers.",
		"cost": 180, "type": "none", "attack": "aura",
		"dmg": 0.0, "rate": 1.0, "range": 2.6, "speed": 0.0,
		"color": "#8fe8c8", "glow": "#d6fff1", "shape": "amplifier",
		"effect": {"kind": "buff_magic", "rate": 0.2, "dmg": 0.4}, "air": true,
		"branch": {
			"a": {"name": "Resonance Chamber", "note": "Massive boost to elemental damage.", "mod": {"effect": {"kind": "buff_magic", "rate": 0.25, "dmg": 0.85}}},
			"b": {"name": "Field Nexus", "note": "Buffs every tower, and adds range.", "mod": {"range": 1.4, "effect": {"kind": "buff", "rate": 0.22, "dmg": 0.25}}},
		},
	},
	# ----------------------------------------------------------------- control
	{
		"id": "grove", "name": "Thornsnare Grove", "cat": "Control",
		"blurb": "Living vines root enemies to the spot.",
		"cost": 130, "type": "poison", "attack": "slow",
		"dmg": 8.0, "rate": 0.7, "range": 3.0, "speed": 18.0,
		"color": "#6fd48a", "glow": "#c8ffd8", "shape": "grove",
		"effect": {"kind": "root", "secs": 1.1, "dps": 4.0}, "air": false,
		"branch": {
			"a": {"name": "Ancient Snare", "note": "Long roots, long holds.", "mod": {"effect": {"kind": "root", "secs": 2.2, "dps": 8.0}, "dmg": 1.4}},
			"b": {"name": "Thorn Barrage", "note": "Rapid thorns that bleed.", "mod": {"attack": "burst", "count": 3, "rate": 1.7, "dmg": 0.7}},
		},
	},
	{
		"id": "mist", "name": "Mist Sprayer", "cat": "Control",
		"blurb": "A lingering alchemical cloud that poisons everything under it.",
		"cost": 145, "type": "poison", "attack": "splash",
		"dmg": 10.0, "rate": 0.6, "range": 3.2, "speed": 12.0, "splash": 1.25,
		"color": "#9ad46f", "glow": "#e2ffb8", "shape": "mist",
		"effect": {"kind": "poison", "dps": 8.0, "secs": 4.0}, "air": true,
		"branch": {
			"a": {"name": "Blight Engine", "note": "Poison that stacks deep.", "mod": {"effect": {"kind": "poison", "dps": 18.0, "secs": 5.0}, "dmg": 1.4}},
			"b": {"name": "Weakening Fog", "note": "Also softens armour.", "mod": {"effect": {"kind": "weaken", "secs": 3.0, "amount": 0.3}, "dmg": 1.5, "splash": 0.4}},
		},
	},
	{
		"id": "drum", "name": "Quake Drum", "cat": "Control",
		"blurb": "Shockwaves that stun every enemy around the drum.",
		"cost": 175, "type": "siege", "attack": "stun",
		"dmg": 22.0, "rate": 0.42, "range": 2.8, "speed": 0.0,
		"color": "#c98a5a", "glow": "#ffd0a0", "shape": "drum",
		"effect": {"kind": "stun", "secs": 0.75}, "air": true,
		"branch": {
			"a": {"name": "World Drum", "note": "Huge radius, long stun.", "mod": {"range": 1.5, "effect": {"kind": "stun", "secs": 1.6}, "dmg": 1.2}},
			"b": {"name": "Warbeat", "note": "Fast pulses that also crack armour.", "mod": {"rate": 2.0, "dmg": 0.7, "effect": {"kind": "stun", "secs": 0.35}}},
		},
	},
	{
		"id": "magnet", "name": "Magnet Mace", "cat": "Control",
		"blurb": "Drags armoured enemies backwards into your kill zone.",
		"cost": 165, "type": "physical", "attack": "pull",
		"dmg": 14.0, "rate": 0.5, "range": 3.4, "speed": 0.0,
		"color": "#a9b4c8", "glow": "#dbe6ff", "shape": "magnet",
		"effect": {"kind": "pull", "amount": 1.1}, "air": false,
		"branch": {
			"a": {"name": "Iron Dominion", "note": "Yanks everything close.", "mod": {"effect": {"kind": "pull", "amount": 2.4}, "range": 1.0, "dmg": 1.2}},
			"b": {"name": "Crushing Field", "note": "Pulses damage as it pulls.", "mod": {"rate": 2.1, "dmg": 1.1, "effect": {"kind": "pull", "amount": 0.6}}},
		},
	},
	# --------------------------------------------------------------- summoning
	{
		"id": "barracks", "name": "Toy Soldier Barracks", "cat": "Summoning",
		"blurb": "Wind-up soldiers hold the road and fight what walks past.",
		"cost": 160, "type": "physical", "attack": "summon",
		"dmg": 9.0, "rate": 0.16, "range": 3.0, "speed": 0.0,
		"color": "#e06a6a", "glow": "#ffc9a8", "shape": "barracks",
		"effect": {"kind": "summon", "hp": 90.0, "dps": 10.0, "secs": 14.0}, "air": false,
		"branch": {
			"a": {"name": "Royal Guard", "note": "Three tough soldiers at a time.", "mod": {"effect": {"kind": "summon", "hp": 240.0, "dps": 16.0, "secs": 18.0}, "count": 3}},
			"b": {"name": "Clockwork Legion", "note": "A constant stream of small ones.", "mod": {"rate": 2.4, "effect": {"kind": "summon", "hp": 70.0, "dps": 9.0, "secs": 9.0}}},
		},
	},
	{
		"id": "hive", "name": "Clockwork Bee Hive", "cat": "Summoning",
		"blurb": "A mechanical hive that launches swarms of tiny defenders.",
		"cost": 155, "type": "physical", "attack": "burst",
		"dmg": 5.0, "rate": 2.6, "range": 2.9, "speed": 22.0, "count": 2,
		"color": "#e8c05a", "glow": "#fff0b0", "shape": "hive",
		"effect": {}, "air": true,
		"branch": {
			"a": {"name": "Royal Apiary", "note": "Bees that sting and slow.", "mod": {"dmg": 1.6, "effect": {"kind": "slow", "factor": 0.7, "secs": 1.5}}},
			"b": {"name": "Steel Swarm", "note": "A cloud of armour-piercing shot.", "mod": {"count": 5, "dmg": 0.7, "rate": 1.15}},
		},
	},
	{
		"id": "roost", "name": "Griffin Roost", "cat": "Summoning",
		"blurb": "Flying guardians that shred anything with wings.",
		"cost": 185, "type": "physical", "attack": "bolt",
		"dmg": 24.0, "rate": 0.85, "range": 4.2, "speed": 26.0,
		"color": "#d8c9a8", "glow": "#fff2cf", "shape": "roost",
		"effect": {}, "air": true, "air_bonus": 2.0,
		"branch": {
			"a": {"name": "Sky Hunt", "note": "Dive-bombs that also splash.", "mod": {"attack": "splash", "splash": 1.0, "dmg": 1.9}},
			"b": {"name": "Talon Patrol", "note": "Two griffins, constant attacks.", "mod": {"count": 2, "rate": 1.3, "dmg": 0.75}},
		},
	},
	{
		"id": "foundry", "name": "Golem Foundry", "cat": "Summoning",
		"blurb": "Builds a toy golem that anchors the road and hits like a cart.",
		"cost": 230, "type": "siege", "attack": "summon",
		"dmg": 22.0, "rate": 0.1, "range": 2.6, "speed": 0.0,
		"color": "#9aa7b8", "glow": "#ffd9a8", "shape": "foundry",
		"effect": {"kind": "summon", "hp": 420.0, "dps": 34.0, "secs": 20.0}, "air": false,
		"branch": {
			"a": {"name": "Titan Works", "note": "One enormous, armoured golem.", "mod": {"effect": {"kind": "summon", "hp": 1200.0, "dps": 62.0, "secs": 24.0}}},
			"b": {"name": "Golem Line", "note": "Two golems and a faster build.", "mod": {"count": 2, "rate": 1.8, "effect": {"kind": "summon", "hp": 340.0, "dps": 26.0, "secs": 16.0}}},
		},
	},
	# Two extra families keep the early shelf from feeling empty and give the
	# unlock curve something to hand out at kingdom three.
	{
		"id": "boltguard", "name": "Watchtower Archers", "cat": "Physical",
		"blurb": "Cheap archers that hit air and ground alike.",
		"cost": 70, "type": "physical", "attack": "bolt",
		"dmg": 9.0, "rate": 1.15, "range": 3.2, "speed": 22.0, "count": 1,
		"color": "#a8b98a", "glow": "#e8ffc0", "shape": "ballista",
		"effect": {}, "air": true,
		"branch": {
			"a": {"name": "Longbow Watch", "note": "Long range, heavy arrows.", "mod": {"dmg": 2.2, "range": 1.2, "rate": 0.9}},
			"b": {"name": "Arrow Rain", "note": "Three arrows per volley.", "mod": {"count": 3, "dmg": 0.75}},
		},
	},
	{
		"id": "ballista_drum", "name": "Signal Drum", "cat": "Support",
		"blurb": "A cheap drum that speeds up the towers beside it.",
		"cost": 85, "type": "none", "attack": "aura",
		"dmg": 0.0, "rate": 1.0, "range": 2.2, "speed": 0.0,
		"color": "#c9a26a", "glow": "#ffe6b8", "shape": "bell",
		"effect": {"kind": "buff", "rate": 0.16, "dmg": 0.0}, "air": true,
		"branch": {
			"a": {"name": "Battle Choir", "note": "Wider, faster inspiration.", "mod": {"range": 1.1, "effect": {"kind": "buff", "rate": 0.38, "dmg": 0.05}}},
			"b": {"name": "Siege Signal", "note": "Adds damage instead of speed.", "mod": {"effect": {"kind": "buff", "rate": 0.06, "dmg": 0.3}}},
		},
	},
]


static func count() -> int:
	return ITEMS.size()


static func by_id(id: String) -> Dictionary:
	for item in ITEMS:
		if String(item["id"]) == id:
			return item
	return {}


static func has(id: String) -> bool:
	return not by_id(id).is_empty()


static func index_of(id: String) -> int:
	for i in range(ITEMS.size()):
		if String(ITEMS[i]["id"]) == id:
			return i
	return -1


## Seven families are available immediately and the shelf keeps opening as the
## campaign advances. Sandbox ignores the curve and offers everything.
static func available(kingdom_index: int, sandbox := false) -> Array:
	if sandbox:
		var all: Array = []
		for item in ITEMS:
			all.append(String(item["id"]))
		return all
	var limit: int = clampi(7 + int(kingdom_index * 1.15), 7, ITEMS.size())
	return UNLOCK_ORDER.slice(0, limit)


## The merged stat block for a tower at a tier and (at tier four) a branch.
static func stats(id: String, branch := "", tier := 1) -> Dictionary:
	var base := by_id(id).duplicate(true)
	if base.is_empty():
		return {}
	# Keep the ultimate branches aside before the chosen branch id replaces
	# that key below, otherwise the lookups below read a String.
	var branch_options: Dictionary = (base.get("branch", {}) as Dictionary).duplicate(true)
	tier = clampi(tier, 1, MAX_TIER)
	var mult: float = TIER_MULT[tier - 1]
	base["tier"] = tier
	base["branch"] = branch
	base["damage"] = float(base["dmg"]) * mult
	base["interval"] = 1.0 / maxf(0.05, float(base["rate"]))
	base["reach"] = float(base["range"]) + float(TIER_RANGE[tier - 1])
	base["move_speed"] = float(base.get("speed", 0.0))
	base["shots"] = maxi(1, int(base.get("count", 1)))
	base["jumps"] = int(base.get("chain", 0))
	base["blast"] = float(base.get("splash", 0.0))
	base["effect_power"] = 1.0 + 0.45 * float(tier - 1)
	base["air_bonus"] = float(base.get("air_bonus", 1.0))
	var effect: Dictionary = (base.get("effect", {}) as Dictionary).duplicate(true)
	if branch != "" and tier >= MAX_TIER:
		var options: Dictionary = branch_options
		var chosen: Dictionary = options.get(branch, {})
		if not chosen.is_empty():
			base["display_name"] = String(chosen["name"])
			base["note"] = String(chosen.get("note", ""))
			var mod: Dictionary = chosen.get("mod", {})
			if mod.has("dmg"):
				base["damage"] = float(base["damage"]) * float(mod["dmg"])
			if mod.has("rate"):
				base["interval"] = base["interval"] / float(mod["rate"])
			if mod.has("range"):
				base["reach"] = float(base["reach"]) + float(mod["range"])
			if mod.has("splash"):
				base["blast"] = maxf(0.0, float(base["blast"]) + float(mod["splash"]))
			if mod.has("count"):
				base["shots"] = maxi(1, int(base["shots"]) + int(mod["count"]))
			if mod.has("chain"):
				base["jumps"] = maxi(0, int(base["jumps"]) + int(mod["chain"]))
			if mod.has("attack"):
				base["attack"] = String(mod["attack"])
			if mod.has("effect"):
				var override: Dictionary = mod["effect"]
				if String(override.get("kind", "")) == "buff" or String(override.get("kind", "")) == "buff_magic" or String(override.get("kind", "")) == "time":
					effect = override.duplicate(true)
				else:
					effect = override.duplicate(true)
			base["branch_mod"] = mod
	if base.has("display_name") == false:
		base["display_name"] = String(base["name"])
	if branch == "" or tier < MAX_TIER:
		base["display_name"] = String(base["name"])
	base["effect"] = effect
	base["upgrade_cost"] = upgrade_cost(id, tier)
	return base


static func upgrade_cost(id: String, tier: int) -> int:
	var base := by_id(id)
	if base.is_empty() or tier >= MAX_TIER:
		return 0
	return int(round(float(base["cost"]) * float(REBUILD[clampi(tier, 0, 3)])))


static func sell_value(id: String, tier: int, invested: int) -> int:
	return int(round(float(invested) * 0.6))


static func type_color(damage_type: String) -> Color:
	match damage_type:
		"fire":
			return Color("#ff8a4c")
		"frost":
			return Color("#9fe3ff")
		"lightning":
			return Color("#8fc8ff")
		"water":
			return Color("#5fd8e0")
		"poison":
			return Color("#9ee06a")
		"arcane":
			return Color("#bb9bff")
		"siege":
			return Color("#ffc46a")
		_:
			return Color("#e8eef8")


static func type_label(damage_type: String) -> String:
	match damage_type:
		"fire":
			return "Fire"
		"frost":
			return "Frost"
		"lightning":
			return "Lightning"
		"water":
			return "Water"
		"poison":
			return "Poison"
		"arcane":
			return "Arcane"
		"siege":
			return "Siege"
		"none":
			return "Support"
		_:
			return "Physical"
