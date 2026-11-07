class_name BattleView
extends Node3D
## The 3D presentation of a battle: the miniature diorama, the toy towers, the
## marching enemies and every spark of feedback.
##
## It reads the simulation and never writes to it. Board queries (which cell was
## tapped) go through the camera, so input and rendering share one coordinate
## space while the rules stay on their own grid.

const TILE := Campaign.CELL

var sim: Battlefield
var level: Dictionary = {}

var camera: Camera3D
var board: Node3D
var _enemy_nodes: Dictionary = {}
var _tower_nodes: Dictionary = {}
var _guard_nodes: Array = []
var _shot_nodes: Dictionary = {}
var _transient: Array = []
var _sockets: Array = []
var _socket_on := false
var _socket_tower := ""
var _range_ring: MeshInstance3D
var _select_ring: MeshInstance3D
var _castle: Node3D
var _heart: MeshInstance3D
var _shake := 0.0
var _time := 0.0
var _last_lives := 0
var _palette: Dictionary = {}


func build(battle: Battlefield) -> void:
	sim = battle
	level = sim.level
	_palette = level.get("palette", {})
	_time = 0.0
	_last_lives = sim.lives
	for child in get_children():
		child.queue_free()
	_enemy_nodes.clear()
	_tower_nodes.clear()
	_shot_nodes.clear()
	_guard_nodes.clear()
	_transient.clear()
	_sockets.clear()
	_build_environment()
	_build_table()
	_build_board()
	_build_path()
	_build_sockets()
	_build_castle()
	_build_camera()
	_build_range_ring()


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(String(_palette.get("to", "#0a1220"))).darkened(0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9fc8e0")
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#fff0d0")
	sun.light_energy = 1.3
	sun.rotation_degrees = Vector3(-58, -32, 0)
	sun.shadow_enabled = false
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#8fd8ff")
	fill.light_energy = 0.45
	fill.rotation_degrees = Vector3(-30, 140, 0)
	add_child(fill)


func _build_table() -> void:
	var table := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 8.4
	cylinder.bottom_radius = 8.6
	cylinder.height = 0.5
	table.mesh = cylinder
	table.position.y = -0.42
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#2b1e17").lerp(Color(String(_palette.get("to", "#0a1220"))), 0.25)
	material.roughness = 0.85
	material.metallic = 0.05
	table.material_override = material
	add_child(table)

	# A soft glowing rim catches the diorama and keeps the board from floating.
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 8.15
	torus.outer_radius = 8.45
	rim.mesh = torus
	rim.position.y = -0.1
	rim.material_override = Models.glow_material(Color(String(_palette.get("accent", "#7fe4c8"))), 0.7)
	add_child(rim)

	# Distant toy islands give the table some depth without costing draw calls.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(level.get("seed", 1))
	for i in range(5):
		var island := Node3D.new()
		var angle := float(i) / 5.0 * TAU + 0.6
		var distance := 10.0 + rng.randf_range(0.0, 3.0)
		island.position = Vector3(cos(angle) * distance, rng.randf_range(-2.4, 0.4), sin(angle) * distance)
		var rock := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.1
		sphere.height = 1.2
		rock.mesh = sphere
		rock.scale = Vector3(1.4, 0.6, 1.2)
		rock.material_override = Models.glow_material(Color(String(_palette.get("stone", "#c9b48a"))).darkened(0.35), 0.1)
		island.add_child(rock)
		var tree := Models.spawn("tree_a")
		tree.position = Vector3(0, 0.5, 0)
		tree.scale = Vector3(1.6, 1.6, 1.6)
		island.add_child(tree)
		add_child(island)


func _build_board() -> void:
	board = Node3D.new()
	board.name = "Board"
	add_child(board)

	var slab := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(Campaign.COLS * TILE + 0.5, 0.42, Campaign.ROWS * TILE + 0.5)
	slab.mesh = box
	slab.position = Vector3(0, -0.16, 0)
	var slab_material := StandardMaterial3D.new()
	slab_material.albedo_color = Color(String(_palette.get("stone", "#c9b48a"))).darkened(0.55)
	slab_material.roughness = 0.8
	slab.material_override = slab_material
	board.add_child(slab)

	var grass := Color(String(_palette.get("grass", "#4f9e5e")))
	var path_color := Color(String(_palette.get("path", "#d8c9a8")))
	var on_path := {}
	for cell in level.get("path", []):
		on_path[cell] = true

	var grass_mesh := BoxMesh.new()
	grass_mesh.size = Vector3(TILE * 0.99, 0.1, TILE * 0.99)
	var grass_material := StandardMaterial3D.new()
	grass_material.albedo_color = grass
	grass_material.roughness = 0.75
	var path_material := StandardMaterial3D.new()
	path_material.albedo_color = path_color
	path_material.roughness = 0.6

	for row in range(Campaign.ROWS):
		for col in range(Campaign.COLS):
			var cell := Vector2i(row, col)
			var tile := MeshInstance3D.new()
			tile.mesh = grass_mesh
			tile.position = Campaign.world_of(cell) + Vector3(0, 0.02, 0)
			if on_path.has(cell):
				tile.material_override = path_material
				tile.position.y = 0.07
			else:
				tile.material_override = grass_material
				# A tiny deterministic height variation reads as hand-placed turf.
				var wobble := float((row * 7 + col * 13) % 5) * 0.006
				tile.position.y += wobble
			board.add_child(tile)

	for cell in level.get("scenery", []):
		_spawn_scenery(cell)

	var rim := MeshInstance3D.new()
	var rim_box := BoxMesh.new()
	rim_box.size = Vector3(Campaign.COLS * TILE + 0.6, 0.24, Campaign.ROWS * TILE + 0.6)
	rim.mesh = rim_box
	rim.position = Vector3(0, -0.3, 0)
	var rim_material := StandardMaterial3D.new()
	rim_material.albedo_color = Color(String(_palette.get("stone", "#c9b48a"))).darkened(0.25)
	rim_material.roughness = 0.55
	rim.material_override = rim_material
	board.add_child(rim)


func _spawn_scenery(cell: Vector2i) -> void:
	var pick := (cell.x * 5 + cell.y * 3) % 4
	var model := "tree_a"
	match pick:
		1:
			model = "tree_b"
		2:
			model = "rock"
		3:
			model = "crystal_cluster"
	var node := Models.spawn(model, Color(String(_palette.get("grass", "#4f9e5e"))).lightened(0.25))
	node.position = Campaign.world_of(cell)
	node.position.y = 0.06
	node.scale = Vector3(0.9, 0.9, 0.9)
	node.rotation.y = float(cell.x + cell.y) * 0.7
	board.add_child(node)


func _build_path() -> void:
	var points: Array = level.get("waypoints", [])
	if points.size() < 2:
		return
	var guide := Models.glow_material(Color(String(_palette.get("glow", "#d8ffc4"))), 1.4)
	var distance := 0.0
	while distance < _path_length(points):
		var point := _sample_points(points, distance)
		var dot := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.045
		sphere.height = 0.09
		dot.mesh = sphere
		dot.position = point + Vector3(0, 0.14, 0)
		dot.material_override = guide
		board.add_child(dot)
		distance += 0.42


func _path_length(points: Array) -> float:
	var total := 0.0
	for i in range(points.size() - 1):
		total += (points[i] as Vector3).distance_to(points[i + 1])
	return total


func _sample_points(points: Array, distance: float) -> Vector3:
	var walked := 0.0
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var seg := a.distance_to(b)
		if walked + seg >= distance:
			return a.lerp(b, 0.0 if seg < 0.0001 else (distance - walked) / seg)
		walked += seg
	return points[points.size() - 1]


func _build_sockets() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(String(_palette.get("accent", "#7fe4c8")))
	material.emission_enabled = true
	material.emission = Color(String(_palette.get("glow", "#d8ffc4")))
	material.emission_energy_multiplier = 1.4
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.4
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.33
	mesh.bottom_radius = 0.33
	mesh.height = 0.02
	for cell in level.get("sockets", []):
		var disc := MeshInstance3D.new()
		disc.mesh = mesh
		disc.material_override = material
		disc.position = Campaign.world_of(cell) + Vector3(0, 0.1, 0)
		disc.visible = false
		board.add_child(disc)
		_sockets.append({"cell": cell, "node": disc})


func _build_castle() -> void:
	var path: Array = level.get("path", [])
	if path.is_empty():
		return
	var cell: Vector2i = path[path.size() - 1]
	_castle = Node3D.new()
	_castle.position = Campaign.world_of(cell) + Vector3(0, 0.06, 0)
	var model := Models.spawn("castle", Color(String(_palette.get("accent", "#ffd166"))))
	model.scale = Vector3(0.78, 0.78, 0.78)
	_castle.add_child(model)
	_heart = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	_heart.mesh = sphere
	_heart.position = Vector3(0, 1.32, 0)
	_heart.material_override = Models.glow_material(Color("#ffd166"), 2.4)
	_castle.add_child(_heart)
	board.add_child(_castle)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Frame the whole eleven-row board inside the band between the top bar and
	# the tower shelf: at 14.6 units the projected board (about 9.1 units) fills
	# roughly 62% of a portrait screen, and the look target sits south of the
	# board so the near edge is not hidden behind the build bar.
	camera.size = 14.2
	camera.position = Vector3(0, 15.0, 8.8)
	camera.look_at_from_position(camera.position, Vector3(0, 0, 1.0), Vector3.UP)
	camera.near = 0.1
	camera.far = 60.0
	add_child(camera)
	# The journey map owns its own camera, and only one camera can render a
	# viewport: claim it explicitly or the board is drawn through the map's
	# camera, which sits inches from island one.
	camera.make_current()


func _build_range_ring() -> void:
	_range_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.97
	torus.outer_radius = 1.0
	_range_ring.mesh = torus
	_range_ring.rotation_degrees.x = 90
	_range_ring.material_override = Models.glow_material(Color("#ffd166"), 1.2)
	_range_ring.visible = false
	add_child(_range_ring)

	_select_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.36
	ring.outer_radius = 0.44
	_select_ring.mesh = ring
	_select_ring.rotation_degrees.x = 90
	_select_ring.material_override = Models.glow_material(Color("#ffffff"), 1.6)
	_select_ring.visible = false
	add_child(_select_ring)


# --------------------------------------------------------------------------
# input helpers
# --------------------------------------------------------------------------

func cell_from_screen(screen: Vector2) -> Vector2i:
	if camera == null:
		return Vector2i(-1, -1)
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	if absf(direction.y) < 0.0001:
		return Vector2i(-1, -1)
	var t := (0.12 - origin.y) / direction.y
	if t < 0.0 or t > 60.0:
		return Vector2i(-1, -1)
	var hit := origin + direction * t
	var cell := Campaign.cell_of(hit)
	if cell.x < 0 or cell.x >= Campaign.ROWS or cell.y < 0 or cell.y >= Campaign.COLS:
		return Vector2i(-1, -1)
	return cell


func set_build_mode(on: bool, tower_id := "") -> void:
	_socket_on = on
	_socket_tower = tower_id
	for entry in _sockets:
		var legal := sim.socket_open(entry["cell"]) if on else false
		if legal and tower_id != "" and not (level.get("allowed", []) as Array).has(tower_id):
			legal = false
		var node: MeshInstance3D = entry["node"]
		node.visible = legal


func show_selection(index: int) -> void:
	if index < 0 or index >= sim.towers.size():
		_select_ring.visible = false
		_range_ring.visible = false
		return
	var tower: Dictionary = sim.towers[index]
	_select_ring.visible = true
	_select_ring.position = (tower["pos"] as Vector3) + Vector3(0, 0.14, 0)
	var reach := float((tower["stats"] as Dictionary)["reach"]) + float(tower["buff_range"])
	_range_ring.visible = reach > 0.1
	_range_ring.position = (tower["pos"] as Vector3) + Vector3(0, 0.12, 0)
	_range_ring.scale = Vector3(reach, reach, reach)


# --------------------------------------------------------------------------
# per-frame sync
# --------------------------------------------------------------------------

func sync(delta: float) -> void:
	if sim == null:
		return
	_time += delta
	_sync_enemies()
	_sync_towers(delta)
	_sync_shots(delta)
	_sync_guards()
	_drain_effects()
	_update_transients(delta)
	_update_shake(delta)
	if sim.lives < _last_lives:
		_shake = minf(0.55, _shake + 0.35)
		if _heart != null:
			_heart.scale = Vector3.ONE * 1.6
	_last_lives = sim.lives
	var ratio := sim.health_ratio()
	if _heart != null:
		_heart.scale = _heart.scale.lerp(Vector3.ONE * (0.8 + ratio * 0.5), delta * 6.0)
		var mat := _heart.material_override as StandardMaterial3D
		if mat != null:
			mat.emission = Color("#ffd166").lerp(Color("#ff6b6b"), 1.0 - ratio)
	if _castle != null and sim.lives <= 3:
		_castle.rotation.y = sin(_time * 5.0) * 0.02


func _sync_enemies() -> void:
	var alive := {}
	for enemy in sim.enemies:
		var uid := int(enemy["uid"])
		alive[uid] = true
		var node: Node3D = _enemy_nodes.get(uid)
		if node == null:
			node = _make_enemy(enemy)
			_enemy_nodes[uid] = node
		var pos: Vector3 = enemy["pos"]
		var flying := bool(enemy["flying"])
		var bob := sin(_time * 4.0 + float(enemy["bob"])) * 0.045
		node.position = Vector3(pos.x, 0.08 + bob + (0.32 if flying else 0.0), pos.z)
		var dir: Vector3 = enemy.get("dir", Vector3.FORWARD)
		var target_yaw := atan2(dir.x, dir.z)
		node.rotation.y = lerp_angle(node.rotation.y, target_yaw + PI, 0.18)
		if float(enemy["hit_flash"]) > 0.4:
			node.scale = Vector3.ONE * float(enemy["size"]) * 0.62 * (1.0 + 0.08 * sin(_time * 40.0))
		else:
			node.scale = Vector3.ONE * float(enemy["size"]) * 0.62
		# Boss phase ring
		if bool(enemy["is_boss"]):
			var halo: MeshInstance3D = node.get_node_or_null("Halo")
			if halo != null:
				halo.rotation.y = _time * 1.6
				halo.scale = Vector3.ONE * (1.0 + 0.04 * sin(_time * 3.0))
	for uid in _enemy_nodes.keys():
		if not alive.has(uid):
			var node: Node3D = _enemy_nodes[uid]
			_burst(node.position, Color("#ffd9a8"), 4, 0.9)
			node.queue_free()
			_enemy_nodes.erase(uid)


func _make_enemy(enemy: Dictionary) -> Node3D:
	var root := Node3D.new()
	var arch := Enemies.by_id(String(enemy["id"]))
	var model_name := String(arch.get("model", "goblin")) if not arch.is_empty() else "goblin"
	var color := Color(String(enemy.get("color", "#8fbf6a")))
	var body := Models.spawn(model_name, color)
	root.add_child(body)
	if bool(enemy["is_boss"]):
		var halo := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.62
		torus.outer_radius = 0.72
		halo.mesh = torus
		halo.name = "Halo"
		halo.position.y = 0.55
		halo.material_override = Models.glow_material(color, 1.8)
		root.add_child(halo)
		root.scale = Vector3.ONE * 0.8
	add_child(root)
	return root


func _sync_towers(delta: float) -> void:
	var alive := {}
	for i in range(sim.towers.size()):
		alive[i] = true
		var tower: Dictionary = sim.towers[i]
		var node: Node3D = _tower_nodes.get(i)
		if node == null:
			node = _make_tower(tower)
			_tower_nodes[i] = node
			_burst(tower["pos"] as Vector3, Color(String((tower["stats"] as Dictionary)["color"])), 6, 0.8)
		var turret: Node3D = node.get_node_or_null("Turret")
		if turret != null:
			var aim: Vector3 = tower.get("aim", Vector3.FORWARD)
			var yaw := atan2(aim.x, aim.z)
			turret.rotation.y = lerp_angle(turret.rotation.y, yaw, delta * 9.0)
			if String((tower["stats"] as Dictionary)["attack"]) == "aura" or String((tower["stats"] as Dictionary)["attack"]) == "income":
				turret.rotation.y += delta * 0.8
		var orb: MeshInstance3D = node.get_node_or_null("Orb")
		if orb != null:
			orb.position.y = 1.18 + sin(_time * 2.4) * 0.05
			orb.rotation.y = _time * 2.0
	for key in _tower_nodes.keys():
		if not alive.has(key):
			var node: Node3D = _tower_nodes[key]
			node.queue_free()
			_tower_nodes.erase(key)


func _make_tower(tower: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.position = tower["pos"] as Vector3
	var stats: Dictionary = tower["stats"]
	var color := Color(String(stats["color"]))
	var base := Models.spawn("tower_base", color.darkened(0.15))
	root.add_child(base)
	var turret_name := _turret_for(String(stats["shape"]))
	var turret := Models.spawn(turret_name, color)
	turret.name = "Turret"
	turret.position.y = 0.26
	turret.scale = Vector3(0.9, 0.9, 0.9)
	root.add_child(turret)
	if int(tower["tier"]) >= 3:
		var orb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.075
		sphere.height = 0.15
		orb.mesh = sphere
		orb.name = "Orb"
		orb.position.y = 1.18
		orb.material_override = Models.glow_material(Color(String(stats["glow"])), 2.6)
		root.add_child(orb)
	add_child(root)
	return root


func _turret_for(shape: String) -> String:
	match shape:
		"ballista":
			return "turret_crossbow"
		"cannon", "mortar":
			return "turret_barrel"
		"gears":
			return "turret_gear"
		"frost", "prism", "moon", "amplifier":
			return "turret_crystal"
		"ember", "foundry":
			return "turret_furnace"
		"tesla":
			return "turret_coil"
		"tide":
			return "turret_fountain"
		"rune":
			return "turret_rune"
		"portal":
			return "turret_portal"
		"banner":
			return "turret_banner"
		"mint":
			return "turret_mint"
		"bell":
			return "turret_bell"
		"grove":
			return "turret_grove"
		"mist":
			return "turret_mist"
		"drum":
			return "turret_drum"
		"magnet":
			return "turret_magnet"
		"barracks":
			return "turret_castle"
		"hive":
			return "turret_hive"
		"roost":
			return "turret_roost"
		_:
			return "turret_crystal"


func _sync_shots(delta: float) -> void:
	var alive := {}
	for i in range(sim.projectiles.size()):
		var shot: Dictionary = sim.projectiles[i]
		alive[i] = true
		var node: MeshInstance3D = _shot_nodes.get(i)
		if node == null:
			node = MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.075
			sphere.height = 0.15
			node.mesh = sphere
			node.material_override = Models.glow_material(Color(String(shot["color"])), 2.4)
			add_child(node)
			_shot_nodes[i] = node
		node.position = shot["pos"] as Vector3
	for key in _shot_nodes.keys():
		if not alive.has(key):
			(_shot_nodes[key] as Node).queue_free()
			_shot_nodes.erase(key)


func _sync_guards() -> void:
	while _guard_nodes.size() < sim.guards.size():
		var root := Node3D.new()
		var body := Models.spawn("knight", Color("#e06a6a"))
		body.scale = Vector3(0.45, 0.45, 0.45)
		root.add_child(body)
		add_child(root)
		_guard_nodes.append(root)
	while _guard_nodes.size() > sim.guards.size():
		var node: Node3D = _guard_nodes.pop_back()
		node.queue_free()
	for i in range(sim.guards.size()):
		var guard: Dictionary = sim.guards[i]
		var node: Node3D = _guard_nodes[i]
		node.position = (guard["pos"] as Vector3) + Vector3(0, 0.1 + sin(_time * 8.0 + i) * 0.03, 0)
		node.rotation.y = _time * 1.2


## Effect colours arrive either as an authored hex string or as a live Color
## from the damage table. Accept both rather than assuming one.
func _effect_color(effect: Dictionary, fallback := Color("#ffffff")) -> Color:
	var value: Variant = effect.get("color", fallback)
	if value is Color:
		return value
	var text := String(value)
	if text.begins_with("#"):
		return Color(text)
	return fallback


func _drain_effects() -> void:
	for effect in sim.effects:
		var kind := String(effect.get("kind", ""))
		match kind:
			"death":
				_burst(effect["pos"] as Vector3, _effect_color(effect), 6, float(effect.get("size", 1.0)))
				_shake = minf(0.35, _shake + 0.03)
			"hit":
				_spark(effect["pos"] as Vector3, _effect_color(effect))
			"beam":
				_line(effect["from"] as Vector3, effect["to"] as Vector3, _effect_color(effect), 0.09)
			"chain":
				var points: Array = effect["points"]
				for i in range(points.size() - 1):
					_line(points[i], points[i + 1], _effect_color(effect), 0.06)
			"blast":
				_ring(effect["pos"] as Vector3, float(effect.get("radius", 1.0)), _effect_color(effect))
			"shockwave":
				_ring(effect["pos"] as Vector3, float(effect.get("radius", 1.5)), _effect_color(effect))
			"magnet":
				_line(effect["from"] as Vector3, effect["to"] as Vector3, _effect_color(effect), 0.05)
			"portal":
				_burst(effect["pos"] as Vector3, _effect_color(effect), 3, 0.6)
			"summon":
				_burst(effect["pos"] as Vector3, _effect_color(effect), 8, 1.0)
			"boss_phase":
				_shake = 0.5
				_ring(effect["pos"] as Vector3, 2.0, _effect_color(effect))
				_burst(effect["pos"] as Vector3, _effect_color(effect), 14, 1.4)
			"boss_die":
				_shake = 0.8
				for i in range(3):
					_burst(effect["pos"] as Vector3, _effect_color(effect).lerp(Color("#ffffff"), 0.3 * i), 12, 1.8)
			"leak":
				_shake = 0.5
				_burst(effect["pos"] as Vector3, Color("#ff6b6b"), 10, 1.2)
			"build", "upgrade":
				_burst(effect["pos"] as Vector3, _effect_color(effect), 8, 1.0)
	sim.effects.clear()


func _burst(at: Vector3, color: Color, count: int, size := 1.0) -> void:
	var material := Models.glow_material(color, 1.8)
	var mesh := SphereMesh.new()
	mesh.radius = 0.07 * size
	mesh.height = 0.14 * size
	for i in range(count):
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = material
		node.position = at + Vector3(0, 0.35, 0)
		add_child(node)
		var angle := randf() * TAU
		var speed := randf_range(0.6, 2.6)
		_transient.append({
			"node": node,
			"vel": Vector3(cos(angle) * speed, randf_range(0.8, 2.8), sin(angle) * speed),
			"life": randf_range(0.32, 0.7),
			"max": 0.7,
			"grow": 0.0,
		})


func _spark(at: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	node.mesh = sphere
	node.material_override = Models.glow_material(color, 2.6)
	node.position = at + Vector3(0, 0.4, 0)
	add_child(node)
	_transient.append({"node": node, "vel": Vector3(0, 1.2, 0), "life": 0.18, "max": 0.18, "grow": 0.0})


func _line(from: Vector3, to: Vector3, color: Color, width: float) -> void:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	var length := from.distance_to(to)
	box.size = Vector3(width, width, maxf(0.05, length))
	node.mesh = box
	node.material_override = Models.glow_material(color, 2.8)
	node.position = (from + to) * 0.5
	if length > 0.001:
		node.look_at_from_position(node.position, to, Vector3.UP)
		node.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	add_child(node)
	_transient.append({"node": node, "vel": Vector3.ZERO, "life": 0.16, "max": 0.16, "grow": 0.0})


func _ring(at: Vector3, radius: float, color: Color) -> void:
	var node := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.88
	torus.outer_radius = 1.0
	node.mesh = torus
	node.material_override = Models.glow_material(color, 2.2)
	node.rotation_degrees.x = 90
	node.position = at + Vector3(0, 0.16, 0)
	node.scale = Vector3.ONE * 0.2
	add_child(node)
	_transient.append({"node": node, "vel": Vector3.ZERO, "life": 0.42, "max": 0.42, "grow": radius})


func _update_transients(delta: float) -> void:
	for i in range(_transient.size() - 1, -1, -1):
		var entry: Dictionary = _transient[i]
		var node: MeshInstance3D = entry["node"]
		if not is_instance_valid(node):
			_transient.remove_at(i)
			continue
		entry["life"] = float(entry["life"]) - delta
		if float(entry["life"]) <= 0.0:
			node.queue_free()
			_transient.remove_at(i)
			continue
		node.position += (entry["vel"] as Vector3) * delta
		entry["vel"] = (entry["vel"] as Vector3) - Vector3(0, 6.0 * delta, 0)
		if float(entry["grow"]) > 0.0:
			var progress := 1.0 - float(entry["life"]) / maxf(0.001, float(entry["max"]))
			node.scale = Vector3.ONE * (0.2 + float(entry["grow"]) * progress)
		else:
			node.scale = Vector3.ONE * clampf(float(entry["life"]) / maxf(0.001, float(entry["max"])), 0.05, 1.0)


func _update_shake(delta: float) -> void:
	if camera == null:
		return
	var enabled := bool(Save.get_setting("screen_shake", true)) and not bool(Save.get_setting("reduced_motion", false))
	_shake = maxf(0.0, _shake - delta * 2.2)
	var offset := Vector3.ZERO
	if enabled and _shake > 0.001:
		offset = Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)) * _shake * 0.18
	camera.position = Vector3(0, 15.0, 8.8) + offset
	camera.look_at(Vector3(0, 0, 1.0) + offset * 0.5, Vector3.UP)


func focus_on(point: Vector3) -> void:
	if camera == null:
		return
	camera.position = Vector3(point.x * 0.4, 14.0, 7.0)
	camera.look_at(Vector3(point.x * 0.4, 0, point.z * 0.6), Vector3.UP)
