class_name Models
extends RefCounted
## Loads the Blender-authored modular kit.
##
## A tower is composed from `tower_base` plus one turret piece, tinted with the
## family's palette, so twenty-six families do not need twenty-six bespoke
## meshes at web download sizes. If a GLB is missing the caller still gets a
## visible primitive rather than a crash.

const DIR := "res://Assets/Models/props/"

static var _cache: Dictionary = {}
static var _tints: Dictionary = {}
static var _painted: Dictionary = {}
static var _glow_cache: Dictionary = {}


static func has(name: String) -> bool:
	return ResourceLoader.exists(DIR + name + ".glb")


static func spawn(name: String, tint := Color.WHITE) -> Node3D:
	if not has(name):
		return _fallback(name)
	var packed: PackedScene = _cache.get(name)
	if packed == null:
		packed = load(DIR + name + ".glb")
		_cache[name] = packed
	if packed == null:
		return _fallback(name)
	var node := packed.instantiate() as Node3D
	if tint != Color.WHITE:
		tint_node(node, tint)
	return node


static func _fallback(name: String) -> Node3D:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#8b8fa3")
	var shape: Mesh
	if name.begins_with("tower"):
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.34
		cylinder.bottom_radius = 0.42
		cylinder.height = 0.9
		shape = cylinder
	elif name.begins_with("turret"):
		var box := BoxMesh.new()
		box.size = Vector3(0.4, 0.34, 0.5)
		shape = box
	elif name == "castle":
		var box := BoxMesh.new()
		box.size = Vector3(1.2, 1.4, 1.2)
		shape = box
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.32
		sphere.height = 0.64
		shape = sphere
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position.y = 0.4
	root.add_child(mesh)
	return root


static func tint_node(node: Node, color: Color) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(surface)
			var key := "%d|%d|%s" % [material.get_instance_id() if material != null else 0, surface, color.to_html()]
			var copy: StandardMaterial3D = _tints.get(key)
			if copy == null:
				if material is StandardMaterial3D:
					copy = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
				else:
					copy = StandardMaterial3D.new()
				if copy.emission_enabled and copy.emission_energy_multiplier > 1.4:
					continue
				copy.albedo_color = copy.albedo_color.lerp(color, 0.7)
				_tints[key] = copy
			mesh_instance.set_surface_override_material(surface, copy)


## One shared material per colour keeps draw calls low and the art direction
## consistent: painted pieces read as solid toy volumes.
static func paint(node: Node, color: Color, emission := 0.18) -> void:
	var key := "%s|%.2f" % [color.to_html(), emission]
	var material: StandardMaterial3D = _painted.get(key)
	if material == null:
		material = StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.28
		material.metallic = 0.42
		material.metallic_specular = 0.8
		material.rim_enabled = true
		material.rim = 0.5
		material.rim_tint = 0.55
		if emission > 0.0:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = emission
		_painted[key] = material
	for child in node.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = material


static func glow_material(color: Color, energy := 2.2) -> StandardMaterial3D:
	var key := "%s|%.2f" % [color.to_html(), energy]
	var cached: StandardMaterial3D = _glow_cache.get(key)
	if cached != null:
		return cached
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_cache[key] = material
	return material
