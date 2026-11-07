class_name JourneyMap
extends Node3D
## A miniature continent: twenty kingdom islands threaded along one glowing
## route. The camera glides to whichever kingdom is selected, cleared islands
## light their road, and locked ones sit dim on the table.

var selected := 0
var unlocked := 0
var camera: Camera3D
var _islands: Array = []
var _routes: Array = []
var _target := Vector3.ZERO
var _look := Vector3.ZERO
var _time := 0.0
var _framing := 1.0


func build(selected_index: int, unlocked_index: int) -> void:
	selected = clampi(selected_index, 0, Campaign.KINGDOM_COUNT - 1)
	unlocked = clampi(unlocked_index, 0, Campaign.KINGDOM_COUNT - 1)
	for child in get_children():
		child.queue_free()
	_islands.clear()
	_routes.clear()

	_build_environment()
	for i in range(Campaign.KINGDOM_COUNT):
		_build_island(i)
	for i in range(Campaign.KINGDOM_COUNT - 1):
		_build_route(i)
	_build_camera()


func _build_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#070c16")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9fc8e0")
	env.ambient_light_energy = 0.9
	env_node.environment = env
	add_child(env_node)

	var key := DirectionalLight3D.new()
	key.light_color = Color("#fff0d0")
	key.light_energy = 1.4
	key.rotation_degrees = Vector3(-55, -40, 0)
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#7cc6ff")
	fill.light_energy = 0.6
	fill.rotation_degrees = Vector3(-25, 130, 0)
	add_child(fill)


func _island_position(index: int) -> Vector3:
	return Vector3(sin(float(index) * 0.78) * 2.1, float((index * 3) % 5) * 0.05, float(index) * 1.35)


func _build_island(index: int) -> void:
	var kingdom: Dictionary = Campaign.KINGDOMS[index]
	var root := Node3D.new()
	root.position = _island_position(index)
	var open := index <= unlocked
	var accent := Color(String(kingdom["accent"]))
	if not open:
		accent = accent.darkened(0.6)
	var disc := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.66
	cylinder.bottom_radius = 0.5
	cylinder.height = 0.26
	disc.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(String(kingdom["grass"])).darkened(0.1 if open else 0.55)
	material.roughness = 0.7
	disc.material_override = material
	root.add_child(disc)

	var prop_name := "tree_a"
	match index % 5:
		0:
			prop_name = "windmill"
		1:
			prop_name = "castle"
		2:
			prop_name = "tree_b"
		3:
			prop_name = "house"
		_:
			prop_name = "crystal_cluster"
	var prop := Models.spawn(prop_name, accent)
	prop.position.y = 0.13
	prop.scale = Vector3(0.62, 0.62, 0.62)
	root.add_child(prop)

	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.075
	sphere.height = 0.15
	marker.mesh = sphere
	marker.position.y = 0.92
	marker.material_override = Models.glow_material(accent, 1.2 if open else 0.35)
	root.add_child(marker)

	if index == selected:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.62
		torus.outer_radius = 0.74
		ring.mesh = torus
		ring.rotation_degrees.x = 90
		ring.material_override = Models.glow_material(Color("#ffffff"), 1.6)
		ring.position.y = 0.03
		root.add_child(ring)
	add_child(root)
	_islands.append({"root": root, "marker": marker, "index": index, "open": open, "ring": index == selected})


func _build_route(index: int) -> void:
	var a: Vector3 = _island_position(index)
	var b: Vector3 = _island_position(index + 1)
	var mid := (a + b) * 0.5
	var length := a.distance_to(b)
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.03, length)
	node.mesh = box
	var lit := index < unlocked
	node.material_override = Models.glow_material(Color("#ffe6a7") if lit else Color("#2a3a52"), 1.2 if lit else 0.2)
	node.position = mid + Vector3(0, 0.02, 0)
	node.look_at_from_position(node.position, b, Vector3.UP)
	add_child(node)
	_routes.append(node)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 42.0
	camera.near = 0.05
	camera.far = 80.0
	add_child(camera)
	_snap_camera()
	camera.make_current()


func make_current() -> void:
	if camera != null:
		camera.make_current()


func set_framing(value: float) -> void:
	_framing = value
	_snap_camera()


func _snap_camera() -> void:
	var point := _island_position(selected)
	_target = point + Vector3(2.2, 3.4 * _framing, 3.0 * _framing)
	_look = point + Vector3(0, 0.7 - 0.4 * _framing, 0)
	if camera != null:
		camera.position = _target
		camera.look_at(_look, Vector3.UP)


func focus(index: int) -> void:
	selected = clampi(index, 0, Campaign.KINGDOM_COUNT - 1)
	if camera == null:
		return
	for entry in _islands:
		var is_selected := int(entry["index"]) == selected
		var ring: Node3D = entry["root"]
		# Selected islands are nudged up a touch so the eye lands on them.
		ring.position.y = 0.08 if is_selected else 0.0
	var point := _island_position(selected)
	_target = point + Vector3(2.2, 3.4 * _framing, 3.0 * _framing)
	_look = point + Vector3(0, 0.7 - 0.4 * _framing, 0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "position", _target, 0.45)


func _process(delta: float) -> void:
	if camera == null:
		return
	_time += delta
	camera.position = camera.position.lerp(_target, minf(1.0, delta * 4.0))
	if camera.position.distance_to(_target) > 0.02:
		camera.look_at(_look, Vector3.UP)
	for entry in _islands:
		var marker: MeshInstance3D = entry["marker"]
		if marker == null:
			continue
		var index := int(entry["index"])
		var base := 0.92 + sin(_time * 2.2 + float(index)) * 0.03
		marker.position.y = base
		var scale := 1.0
		if index == selected:
			scale = 1.5 + sin(_time * 4.0) * 0.14
		elif int(entry["index"]) <= unlocked:
			scale = 1.1
		marker.scale = Vector3.ONE * scale
