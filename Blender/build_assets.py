"""Build the original Wonderguard 3D modular asset kit.

    blender -b -P Blender/build_assets.py

Writes editable .blend files next to this script and GLBs into
Assets/Models/props/. Towers are a shared base plus a turret piece, which keeps
the download small while every family still has its own silhouette and palette.
Everything is authored from primitives, so the source is reproducible.
"""

import math
import os

import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = os.path.join(ROOT, "Assets", "Models", "props")
os.makedirs(MODELS, exist_ok=True)

MATS = {}


def srgb(hex_value):
    value = hex_value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def mat(name, color, rough=0.5, metal=0.0, emission=None, strength=0.0):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    rgb = srgb(color) if isinstance(color, str) else color
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emission:
        er = srgb(emission) if isinstance(emission, str) else emission
        bsdf.inputs["Emission Color"].default_value = (*er, 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength or 1.0
    MATS[name] = m
    return m


def _paint(obj, m, name, flat=False):
    obj.name = name
    obj.data.materials.clear()
    if m is not None:
        obj.data.materials.append(m)
    if flat:
        for poly in obj.data.polygons:
            poly.use_smooth = False
    return obj


def box(name, size, loc, m, rot=(0, 0, 0), flat=False):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _paint(o, m, name, flat)


def sphere(name, radius, loc, m, scale=(1, 1, 1), subdiv=2, flat=False):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=radius, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _paint(o, m, name, flat)


def cyl(name, radius, depth, loc, m, verts=12, rot=(0, 0, 0), flat=False):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth,
                                        location=loc, rotation=rot)
    return _paint(bpy.context.object, m, name, flat)


def cone(name, r1, r2, depth, loc, m, verts=8, rot=(0, 0, 0), flat=True):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth,
                                    location=loc, rotation=rot)
    return _paint(bpy.context.object, m, name, flat)


def torus(name, major, minor, loc, m, rot=(0, 0, 0), segments=18, minor_segments=6):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=segments, minor_segments=minor_segments,
                                     location=loc, rotation=rot)
    return _paint(bpy.context.object, m, name)


def bevel(obj, width=0.03, segments=2):
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return joined


def export(obj, filename):
    path = os.path.join(MODELS, filename + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    rna = bpy.ops.export_scene.gltf.get_rna_type().properties
    kwargs = {
        "filepath": path,
        "export_format": "GLB",
        "use_selection": True,
        "export_apply": True,
        "export_yup": True,
        "export_animations": False,
        "export_materials": "EXPORT",
        "export_cameras": False,
        "export_lights": False,
    }
    kwargs = {k: v for k, v in kwargs.items() if k in rna}
    bpy.ops.export_scene.gltf(**kwargs)
    print("exported", os.path.basename(path))


def new_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATS.clear()
    return {
        "wood": mat("wood", "#a97a4a", 0.55, metal=0.0),
        "wood_dark": mat("wood_dark", "#6b4a2c", 0.6),
        "stone": mat("stone", "#c2c8d0", 0.7),
        "stone_dark": mat("stone_dark", "#8f98a4", 0.75),
        "brass": mat("brass", "#c9a24a", 0.3, metal=0.85),
        "steel": mat("steel", "#aab4c4", 0.25, metal=0.9),
        "cream": mat("cream", "#f2ead8", 0.5),
        "glow": mat("glow", "#bff8ff", 0.25, emission="#63e9ff", strength=3.0),
        "amber": mat("amber", "#ffdca0", 0.25, emission="#ffb23d", strength=2.6),
        "pink": mat("pink", "#ffd0e8", 0.25, emission="#ff6fb5", strength=2.4),
        "leaf": mat("leaf", "#5aa85a", 0.6),
        "leaf_dark": mat("leaf_dark", "#3f7a44", 0.65),
        "ice": mat("ice", "#cfefff", 0.15, emission="#7fd8ff", strength=1.1),
        "rock": mat("rock", "#8a8f96", 0.8),
        "red": mat("red", "#d9614e", 0.5),
        "dark": mat("dark", "#1d2330", 0.45, metal=0.5),
        "roof": mat("roof", "#a84a3a", 0.5),
        "skin": mat("skin", "#7fbf6a", 0.55),
    }


# --------------------------------------------------------------------------
# towers
# --------------------------------------------------------------------------

def build_base():
    p = new_scene()
    parts = [
        cyl("dais", 0.46, 0.16, (0, 0, 0.08), p["stone"], verts=8),
        cyl("rim", 0.4, 0.1, (0, 0, 0.19), p["wood"], verts=8),
        box("post_l", (0.07, 0.07, 0.24), (-0.34, 0.0, 0.32), p["wood_dark"]),
        box("post_r", (0.07, 0.07, 0.24), (0.34, 0.0, 0.32), p["wood_dark"]),
        box("post_b", (0.07, 0.07, 0.24), (0.0, -0.34, 0.32), p["wood_dark"]),
        torus("ring", 0.4, 0.025, (0, 0, 0.2), p["brass"], rot=(math.pi / 2, 0, 0), segments=20, minor_segments=5),
    ]
    obj = join(parts, "tower_base")
    bevel(obj, 0.02)
    export(obj, "tower_base")


def build_crossbow():
    p = new_scene()
    parts = [
        cyl("turntable", 0.22, 0.1, (0, 0, 0.05), p["wood_dark"], verts=8),
        box("stock", (0.12, 0.5, 0.1), (0, 0.0, 0.14), p["wood"]),
        box("arm_l", (0.46, 0.05, 0.05), (-0.16, 0.12, 0.2), p["brass"], rot=(0, 0, 0.22)),
        box("arm_r", (0.46, 0.05, 0.05), (0.16, 0.12, 0.2), p["brass"], rot=(0, 0, -0.22)),
        box("bow", (0.52, 0.03, 0.03), (0, 0.19, 0.21), p["cream"]),
        cyl("bolt", 0.02, 0.5, (0, 0.18, 0.24), p["steel"], verts=6, rot=(math.pi / 2, 0, 0)),
        sphere("sight", 0.05, (0, 0.06, 0.28), p["amber"], subdiv=1),
    ]
    obj = join(parts, "turret_crossbow")
    bevel(obj, 0.012)
    export(obj, "turret_crossbow")


def build_barrel():
    p = new_scene()
    parts = [
        cyl("turntable", 0.22, 0.1, (0, 0, 0.05), p["steel"], verts=10),
        box("breech", (0.2, 0.26, 0.18), (0, 0.02, 0.2), p["steel"]),
        cyl("barrel", 0.085, 0.52, (0, 0.27, 0.23), p["dark"], verts=12, rot=(math.pi / 2, 0, 0)),
        cyl("muzzle", 0.12, 0.1, (0, 0.52, 0.23), p["brass"], verts=12, rot=(math.pi / 2, 0, 0)),
        torus("band", 0.11, 0.02, (0, 0.4, 0.23), p["brass"], rot=(math.pi / 2, 0, 0), segments=12, minor_segments=4),
        sphere("charge", 0.05, (0, 0.55, 0.23), p["amber"], subdiv=1),
        box("wheel_l", (0.06, 0.14, 0.14), (-0.19, -0.02, 0.16), p["wood_dark"]),
        box("wheel_r", (0.06, 0.14, 0.14), (0.19, -0.02, 0.16), p["wood_dark"]),
    ]
    obj = join(parts, "turret_barrel")
    bevel(obj, 0.014)
    export(obj, "turret_barrel")


def build_crystal():
    p = new_scene()
    parts = [
        cyl("turntable", 0.22, 0.1, (0, 0, 0.05), p["stone_dark"], verts=8),
        torus("ring", 0.2, 0.03, (0, 0, 0.14), p["brass"], rot=(math.pi / 2, 0, 0), segments=16, minor_segments=4),
        cone("shard_a", 0.14, 0.02, 0.62, (0, 0, 0.46), p["ice"], verts=6),
        cone("shard_b", 0.08, 0.01, 0.4, (-0.14, 0.08, 0.34), p["glow"], verts=5, rot=(0.18, 0.2, 0)),
        cone("shard_c", 0.07, 0.01, 0.34, (0.13, -0.06, 0.31), p["glow"], verts=5, rot=(-0.16, -0.2, 0)),
        sphere("heart", 0.09, (0, 0, 0.3), p["pink"], subdiv=1),
    ]
    obj = join(parts, "turret_crystal")
    export(obj, "turret_crystal")


def build_gear():
    p = new_scene()
    parts = [cyl("hub", 0.12, 0.12, (0, 0, 0.06), p["brass"], verts=10)]
    for i, (radius, depth, z) in enumerate(((0.3, 0.06, 0.14), (0.24, 0.06, 0.24), (0.17, 0.06, 0.32))):
        parts.append(cyl("gear%d" % i, radius, depth, (0, 0, z), p["brass"], verts=12))
        for tooth in range(8):
            a = tooth * math.tau / 8 + i * 0.2
            parts.append(box("t%d_%d" % (i, tooth), (0.07, 0.07, depth),
                             (math.cos(a) * radius, math.sin(a) * radius, z), p["brass"], rot=(0, 0, a)))
    parts.append(sphere("lamp", 0.07, (0, 0, 0.4), p["amber"], subdiv=1))
    obj = join(parts, "turret_gear")
    bevel(obj, 0.008)
    export(obj, "turret_gear")


def build_drum():
    p = new_scene()
    parts = [
        cyl("drum", 0.34, 0.3, (0, 0, 0.22), p["wood"], verts=16),
        cyl("skin", 0.36, 0.04, (0, 0, 0.38), p["cream"], verts=16),
        torus("hoop", 0.35, 0.025, (0, 0, 0.39), p["brass"], rot=(math.pi / 2, 0, 0), segments=18, minor_segments=4),
        box("leg_l", (0.06, 0.06, 0.2), (-0.3, 0.16, 0.1), p["wood_dark"], rot=(0.3, 0, 0)),
        box("leg_r", (0.06, 0.06, 0.2), (0.3, 0.16, 0.1), p["wood_dark"], rot=(0.3, 0, 0)),
        box("stick", (0.03, 0.5, 0.03), (0.16, 0.05, 0.45), p["brass"], rot=(0.2, 0.1, 0.4)),
    ]
    obj = join(parts, "turret_drum")
    bevel(obj, 0.012)
    export(obj, "turret_drum")


def build_bell():
    p = new_scene()
    parts = [
        box("frame", (0.34, 0.34, 0.12), (0, 0, 0.06), p["wood_dark"]),
        cyl("post_l", 0.035, 0.5, (-0.16, 0, 0.3), p["brass"], verts=6),
        cyl("post_r", 0.035, 0.5, (0.16, 0, 0.3), p["brass"], verts=6),
        box("beam", (0.42, 0.06, 0.06), (0, 0, 0.55), p["brass"]),
        cone("bell", 0.2, 0.1, 0.3, (0, 0, 0.38), p["brass"], verts=12),
        sphere("clapper", 0.05, (0, 0, 0.24), p["amber"], subdiv=1),
        torus("halo", 0.24, 0.015, (0, 0, 0.52), p["glow"], rot=(math.pi / 2, 0, 0), segments=16, minor_segments=4),
    ]
    obj = join(parts, "turret_bell")
    export(obj, "turret_bell")


def build_hive():
    p = new_scene()
    parts = [
        cyl("post", 0.05, 0.5, (0, 0, 0.25), p["wood_dark"], verts=6),
        sphere("hive", 0.3, (0, 0, 0.66), p["amber"], scale=(1.0, 1.0, 1.2), subdiv=2),
        torus("ring_a", 0.26, 0.03, (0, 0, 0.56), p["brass"], rot=(math.pi / 2, 0, 0), segments=14, minor_segments=4),
        torus("ring_b", 0.22, 0.03, (0, 0, 0.74), p["brass"], rot=(math.pi / 2, 0, 0), segments=14, minor_segments=4),
        cyl("hole", 0.07, 0.06, (0, 0.29, 0.66), p["dark"], verts=8, rot=(math.pi / 2, 0, 0)),
    ]
    for i in range(3):
        a = i * math.tau / 3
        parts.append(sphere("bee%d" % i, 0.05, (math.cos(a) * 0.4, math.sin(a) * 0.4, 0.8), p["dark"], subdiv=1))
    obj = join(parts, "turret_hive")
    export(obj, "turret_hive")


def build_banner():
    p = new_scene()
    parts = [
        box("plinth", (0.36, 0.36, 0.12), (0, 0, 0.06), p["stone_dark"]),
        cyl("pole", 0.04, 1.0, (0, 0, 0.56), p["wood_dark"], verts=8),
        box("flag", (0.36, 0.04, 0.28), (0.2, 0, 0.86), p["red"]),
        box("trim", (0.4, 0.05, 0.05), (0.2, 0, 0.72), p["brass"]),
        sphere("finial", 0.06, (0, 0, 1.08), p["amber"], subdiv=1),
        cyl("shield", 0.12, 0.04, (0, -0.02, 0.62), p["brass"], verts=8, rot=(math.pi / 2, 0, 0)),
    ]
    obj = join(parts, "turret_banner")
    bevel(obj, 0.01)
    export(obj, "turret_banner")


def build_portal():
    p = new_scene()
    parts = [
        cyl("base", 0.34, 0.12, (0, 0, 0.06), p["stone_dark"], verts=10),
        torus("ring", 0.42, 0.06, (0, 0, 0.58), p["glow"], rot=(0, math.pi / 2, 0), segments=24, minor_segments=6),
        torus("inner", 0.3, 0.03, (0, 0, 0.58), p["pink"], rot=(0, math.pi / 2, 0), segments=20, minor_segments=4),
        box("clamp_l", (0.1, 0.16, 0.16), (0, 0, 0.14), p["brass"]),
        box("clamp_r", (0.1, 0.16, 0.16), (0, 0, 1.02), p["brass"]),
    ]
    obj = join(parts, "turret_portal")
    export(obj, "turret_portal")


def build_castle_turret():
    p = new_scene()
    parts = [
        cyl("keep", 0.3, 0.6, (0, 0, 0.3), p["stone"], verts=8),
        cyl("battlement", 0.34, 0.12, (0, 0, 0.64), p["stone_dark"], verts=8),
        cone("roof", 0.3, 0.02, 0.36, (0, 0, 0.9), p["roof"], verts=8),
        box("door", (0.12, 0.04, 0.2), (0, 0.3, 0.14), p["wood_dark"]),
        sphere("lantern", 0.06, (0, 0, 1.12), p["amber"], subdiv=1),
        box("flag", (0.16, 0.02, 0.1), (0.1, 0, 1.16), p["glow"]),
    ]
    obj = join(parts, "turret_castle")
    bevel(obj, 0.012)
    export(obj, "turret_castle")


def build_mint():
    p = new_scene()
    parts = [
        box("bench", (0.46, 0.34, 0.14), (0, 0, 0.07), p["wood"]),
        box("press", (0.22, 0.22, 0.22), (0, 0, 0.28), p["steel"]),
        cyl("screw", 0.05, 0.2, (0, 0, 0.48), p["brass"], verts=8),
        torus("wheel", 0.1, 0.02, (0, 0, 0.58), p["brass"], rot=(math.pi / 2, 0, 0), segments=12, minor_segments=4),
        cyl("coin", 0.1, 0.02, (0, 0.2, 0.18), p["amber"], verts=12, rot=(math.pi / 2, 0, 0)),
        sphere("spark", 0.04, (0.16, 0.16, 0.34), p["amber"], subdiv=1),
    ]
    obj = join(parts, "turret_mint")
    bevel(obj, 0.01)
    export(obj, "turret_mint")


def build_grove():
    p = new_scene()
    parts = [
        cyl("trunk", 0.13, 0.62, (0, 0, 0.31), p["wood_dark"], verts=8),
        sphere("canopy_a", 0.32, (0, 0, 0.74), p["leaf"], scale=(1.0, 1.0, 0.8), subdiv=2),
        sphere("canopy_b", 0.2, (-0.2, 0.1, 0.6), p["leaf_dark"], subdiv=1),
        sphere("canopy_c", 0.18, (0.2, -0.1, 0.62), p["leaf"], subdiv=1),
        cone("vine_a", 0.05, 0.0, 0.34, (0.24, 0.18, 0.18), p["leaf_dark"], verts=5, rot=(0.4, 0, 0.5)),
        cone("vine_b", 0.04, 0.0, 0.28, (-0.22, 0.2, 0.16), p["leaf_dark"], verts=5, rot=(0.4, 0, -0.5)),
        sphere("berry", 0.05, (0, 0.3, 0.7), p["pink"], subdiv=1),
    ]
    obj = join(parts, "turret_grove")
    export(obj, "turret_grove")


def build_mist():
    p = new_scene()
    parts = [
        cyl("tank", 0.24, 0.5, (0, 0, 0.28), p["steel"], verts=12),
        cyl("cap", 0.26, 0.08, (0, 0, 0.56), p["brass"], verts=12),
        cyl("nozzle", 0.06, 0.28, (0, 0.2, 0.64), p["brass"], verts=8, rot=(0.9, 0, 0)),
        torus("band", 0.25, 0.03, (0, 0, 0.36), p["brass"], rot=(math.pi / 2, 0, 0), segments=14, minor_segments=4),
        sphere("bubble_a", 0.06, (0.16, 0.34, 0.74), p["glow"], subdiv=1),
        sphere("bubble_b", 0.04, (0.26, 0.3, 0.62), p["glow"], subdiv=1),
        box("gauge", (0.1, 0.04, 0.1), (0, 0.24, 0.4), p["amber"]),
    ]
    obj = join(parts, "turret_mist")
    bevel(obj, 0.01)
    export(obj, "turret_mist")


def build_magnet():
    p = new_scene()
    parts = [
        cyl("base", 0.3, 0.12, (0, 0, 0.06), p["stone_dark"], verts=10),
        torus("horseshoe", 0.26, 0.075, (0, 0, 0.46), p["steel"], rot=(math.pi / 2, 0, 0), segments=20, minor_segments=8),
        box("cut", (0.16, 0.1, 0.26), (0, 0, 0.46), p["dark"]),
        cyl("tip_l", 0.075, 0.12, (-0.26, 0, 0.22), p["red"], verts=8),
        cyl("tip_r", 0.075, 0.12, (0.26, 0, 0.22), p["glow"], verts=8),
        sphere("spark", 0.05, (0, 0.12, 0.72), p["glow"], subdiv=1),
    ]
    obj = join(parts, "turret_magnet")
    export(obj, "turret_magnet")


def build_roost():
    p = new_scene()
    parts = [
        cyl("nest", 0.34, 0.16, (0, 0, 0.1), p["wood_dark"], verts=10),
        torus("rim", 0.32, 0.04, (0, 0, 0.2), p["wood"], rot=(math.pi / 2, 0, 0), segments=16, minor_segments=4),
        cyl("perch", 0.05, 0.5, (0, 0, 0.42), p["wood"], verts=6),
        box("beam", (0.44, 0.06, 0.06), (0, 0, 0.68), p["wood"]),
        sphere("guardian", 0.1, (0.14, 0, 0.8), p["cream"], subdiv=1),
        cone("beak", 0.04, 0.0, 0.1, (0.14, 0.12, 0.8), p["amber"], verts=5, rot=(math.pi / 2, 0, 0)),
        box("wing", (0.16, 0.04, 0.1), (0.14, 0, 0.82), p["cream"], rot=(0, 0.3, 0)),
    ]
    obj = join(parts, "turret_roost")
    export(obj, "turret_roost")


def build_furnace():
    p = new_scene()
    parts = [
        box("body", (0.44, 0.4, 0.5), (0, 0, 0.27), p["stone_dark"]),
        box("door", (0.24, 0.06, 0.22), (0, 0.22, 0.2), p["amber"]),
        cyl("chimney", 0.1, 0.34, (0.12, -0.1, 0.66), p["steel"], verts=8),
        torus("band", 0.13, 0.02, (0.12, -0.1, 0.82), p["brass"], rot=(math.pi / 2, 0, 0), segments=10, minor_segments=4),
        cyl("smoke", 0.06, 0.1, (0.12, -0.1, 0.9), p["glow"], verts=8),
        box("anvil", (0.24, 0.14, 0.08), (-0.02, 0.24, 0.42), p["steel"]),
        sphere("ember", 0.04, (0.0, 0.26, 0.32), p["amber"], subdiv=1),
    ]
    obj = join(parts, "turret_furnace")
    bevel(obj, 0.012)
    export(obj, "turret_furnace")


def build_coil():
    p = new_scene()
    parts = [
        cyl("base", 0.26, 0.14, (0, 0, 0.07), p["brass"], verts=10),
        cyl("column", 0.09, 0.6, (0, 0, 0.4), p["steel"], verts=8),
        torus("coil_a", 0.2, 0.035, (0, 0, 0.44), p["glow"], rot=(math.pi / 2, 0, 0), segments=16, minor_segments=4),
        torus("coil_b", 0.17, 0.035, (0, 0, 0.56), p["glow"], rot=(math.pi / 2, 0, 0), segments=16, minor_segments=4),
        torus("coil_c", 0.14, 0.035, (0, 0, 0.68), p["glow"], rot=(math.pi / 2, 0, 0), segments=16, minor_segments=4),
        sphere("orb", 0.13, (0, 0, 0.82), p["glow"], subdiv=2),
        cone("spike", 0.05, 0.0, 0.2, (0, 0, 0.98), p["brass"], verts=5),
    ]
    obj = join(parts, "turret_coil")
    export(obj, "turret_coil")


def build_fountain():
    p = new_scene()
    parts = [
        cyl("basin", 0.38, 0.16, (0, 0, 0.08), p["stone"], verts=12),
        cyl("water", 0.34, 0.04, (0, 0, 0.17), p["glow"], verts=12),
        cyl("stem", 0.1, 0.36, (0, 0, 0.34), p["stone_dark"], verts=8),
        cyl("bowl", 0.24, 0.1, (0, 0, 0.54), p["stone"], verts=12),
        sphere("drop", 0.08, (0, 0, 0.68), p["glow"], scale=(1, 1, 1.4), subdiv=2),
        torus("ring", 0.26, 0.02, (0, 0, 0.2), p["brass"], rot=(math.pi / 2, 0, 0), segments=16, minor_segments=4),
    ]
    obj = join(parts, "turret_fountain")
    export(obj, "turret_fountain")


def build_rune():
    p = new_scene()
    parts = [
        cyl("dais", 0.34, 0.14, (0, 0, 0.07), p["stone_dark"], verts=10),
        cyl("obelisk", 0.16, 0.68, (0, 0, 0.45), p["stone"], verts=4, rot=(0, 0, 0.785)),
        torus("halo", 0.3, 0.025, (0, 0, 0.62), p["glow"], rot=(math.pi / 2, 0, 0), segments=18, minor_segments=4),
        box("rune_a", (0.06, 0.02, 0.2), (0, 0.16, 0.6), p["glow"]),
        box("rune_b", (0.14, 0.02, 0.05), (0, 0.16, 0.55), p["glow"]),
        sphere("crown", 0.07, (0, 0, 0.84), p["pink"], subdiv=1),
    ]
    obj = join(parts, "turret_rune")
    export(obj, "turret_rune")


# --------------------------------------------------------------------------
# board and props
# --------------------------------------------------------------------------

def build_castle():
    p = new_scene()
    parts = [
        box("plinth", (1.5, 1.3, 0.2), (0, 0, 0.1), p["stone_dark"]),
        box("keep", (0.9, 0.8, 0.9), (0, 0, 0.65), p["cream"]),
        box("hall", (1.1, 0.7, 0.5), (0, 0.1, 0.45), p["cream"]),
        cyl("tower_l", 0.24, 0.95, (-0.5, -0.2, 0.72), p["cream"], verts=8),
        cyl("tower_r", 0.24, 0.95, (0.5, -0.2, 0.72), p["cream"], verts=8),
        cone("roof_l", 0.3, 0.02, 0.4, (-0.5, -0.2, 1.4), p["roof"], verts=8),
        cone("roof_r", 0.3, 0.02, 0.4, (0.5, -0.2, 1.4), p["roof"], verts=8),
        cone("roof_main", 0.4, 0.02, 0.5, (0, 0, 1.35), p["roof"], verts=8),
        box("gate", (0.3, 0.06, 0.4), (0, 0.42, 0.28), p["wood_dark"]),
        box("banner", (0.2, 0.02, 0.3), (0, 0.45, 0.85), p["glow"]),
        sphere("heart", 0.1, (0, 0, 1.68), p["amber"], subdiv=1),
    ]
    obj = join(parts, "castle")
    bevel(obj, 0.02)
    export(obj, "castle")


def build_tree_a():
    p = new_scene()
    parts = [
        cyl("trunk", 0.1, 0.5, (0, 0, 0.25), p["wood_dark"], verts=8),
        sphere("canopy", 0.34, (0, 0, 0.62), p["leaf"], subdiv=2),
        sphere("canopy2", 0.2, (0.16, 0.1, 0.72), p["leaf_dark"], subdiv=1),
    ]
    obj = join(parts, "tree_a")
    export(obj, "tree_a")


def build_tree_b():
    p = new_scene()
    parts = [
        cyl("trunk", 0.12, 0.62, (0, 0, 0.31), p["wood_dark"], verts=6),
        cone("canopy", 0.36, 0.02, 0.7, (0, 0, 0.9), p["leaf_dark"], verts=8),
        cone("canopy2", 0.3, 0.02, 0.5, (0, 0, 1.18), p["leaf"], verts=8),
    ]
    obj = join(parts, "tree_b")
    export(obj, "tree_b")


def build_rock():
    p = new_scene()
    parts = [
        sphere("rock", 0.3, (0, 0, 0.18), p["rock"], scale=(1.2, 0.9, 0.8), subdiv=1, flat=True),
        sphere("rock2", 0.16, (0.26, 0.1, 0.12), p["stone_dark"], scale=(1.0, 0.8, 0.7), subdiv=1, flat=True),
    ]
    obj = join(parts, "rock")
    export(obj, "rock")


def build_crystal_prop():
    p = new_scene()
    parts = [
        sphere("base", 0.26, (0, 0, 0.1), p["stone_dark"], scale=(1.2, 1.0, 0.5), subdiv=1),
        cone("shard", 0.14, 0.01, 0.7, (0, 0, 0.45), p["ice"], verts=6),
        cone("shard2", 0.08, 0.01, 0.4, (0.18, 0.06, 0.3), p["glow"], verts=5, rot=(0.2, 0.2, 0)),
    ]
    obj = join(parts, "crystal_cluster")
    export(obj, "crystal_cluster")


def build_windmill():
    p = new_scene()
    parts = [
        cyl("tower", 0.24, 0.9, (0, 0, 0.45), p["cream"], verts=8),
        cone("roof", 0.28, 0.02, 0.3, (0, 0, 1.02), p["roof"], verts=8),
        cyl("hub", 0.07, 0.12, (0, 0.28, 0.8), p["brass"], verts=8, rot=(math.pi / 2, 0, 0)),
    ]
    for i in range(4):
        a = i * math.tau / 4
        parts.append(box("blade%d" % i, (0.1, 0.03, 0.42),
                         (math.cos(a) * 0.24, 0.36, 0.8 + math.sin(a) * 0.24), p["cream"],
                         rot=(a, 0, 0)))
    obj = join(parts, "windmill")
    export(obj, "windmill")


def build_house():
    p = new_scene()
    parts = [
        box("walls", (0.5, 0.42, 0.34), (0, 0, 0.17), p["cream"]),
        cone("roof", 0.42, 0.02, 0.3, (0, 0, 0.48), p["roof"], verts=4, rot=(0, 0, 0.785)),
        box("door", (0.12, 0.03, 0.2), (0, 0.22, 0.1), p["wood_dark"]),
        box("chimney", (0.08, 0.08, 0.2), (0.16, -0.1, 0.52), p["stone_dark"]),
    ]
    obj = join(parts, "house")
    bevel(obj, 0.012)
    export(obj, "house")


# --------------------------------------------------------------------------
# toy enemies
# --------------------------------------------------------------------------

def build_goblin():
    p = new_scene()
    parts = [
        sphere("body", 0.24, (0, 0, 0.26), p["skin"], scale=(1.0, 0.9, 1.15), subdiv=2),
        sphere("head", 0.19, (0, 0, 0.58), p["skin"], subdiv=2),
        cone("ear_l", 0.09, 0.0, 0.22, (-0.19, 0, 0.62), p["skin"], verts=5, rot=(0, 0.9, 0)),
        cone("ear_r", 0.09, 0.0, 0.22, (0.19, 0, 0.62), p["skin"], verts=5, rot=(0, -0.9, 0)),
        sphere("eye_l", 0.035, (-0.07, 0.16, 0.62), p["dark"], subdiv=1),
        sphere("eye_r", 0.035, (0.07, 0.16, 0.62), p["dark"], subdiv=1),
        box("belt", (0.34, 0.24, 0.05), (0, 0, 0.28), p["wood_dark"]),
        cyl("foot_l", 0.06, 0.1, (-0.1, 0.02, 0.05), p["wood_dark"], verts=6),
        cyl("foot_r", 0.06, 0.1, (0.1, 0.02, 0.05), p["wood_dark"], verts=6),
    ]
    obj = join(parts, "goblin")
    export(obj, "goblin")


def build_mouse():
    p = new_scene()
    parts = [
        sphere("body", 0.2, (0, 0, 0.2), p["brass"], scale=(1.0, 1.25, 0.9), subdiv=2),
        sphere("head", 0.13, (0, 0.24, 0.24), p["brass"], subdiv=1),
        sphere("ear_l", 0.075, (-0.1, 0.26, 0.34), p["amber"], subdiv=1),
        sphere("ear_r", 0.075, (0.1, 0.26, 0.34), p["amber"], subdiv=1),
        torus("wheel", 0.14, 0.03, (0, 0, 0.13), p["steel"], rot=(0, math.pi / 2, 0), segments=14, minor_segments=4),
        cyl("tail", 0.02, 0.3, (0, -0.28, 0.24), p["steel"], verts=5, rot=(1.2, 0, 0)),
    ]
    obj = join(parts, "mouse")
    export(obj, "mouse")


def build_slime():
    p = new_scene()
    parts = [
        sphere("body", 0.26, (0, 0, 0.2), p["leaf"], scale=(1.15, 1.05, 0.85), subdiv=2),
        sphere("eye_l", 0.05, (-0.09, 0.22, 0.3), p["dark"], subdiv=1),
        sphere("eye_r", 0.05, (0.09, 0.22, 0.3), p["dark"], subdiv=1),
        sphere("shine", 0.07, (0, -0.1, 0.36), p["cream"], subdiv=1),
    ]
    obj = join(parts, "slime")
    export(obj, "slime")


def build_knight():
    p = new_scene()
    parts = [
        box("torso", (0.26, 0.2, 0.3), (0, 0, 0.34), p["steel"]),
        sphere("helm", 0.15, (0, 0, 0.58), p["steel"], subdiv=1),
        box("visor", (0.2, 0.05, 0.05), (0, 0.13, 0.58), p["dark"]),
        box("leg_l", (0.09, 0.1, 0.2), (-0.08, 0, 0.1), p["stone_dark"]),
        box("leg_r", (0.09, 0.1, 0.2), (0.08, 0, 0.1), p["stone_dark"]),
        box("shield", (0.06, 0.22, 0.26), (0.2, 0.02, 0.36), p["brass"], rot=(0, 0, 0.1)),
        box("sword", (0.04, 0.04, 0.36), (-0.2, 0.04, 0.4), p["cream"], rot=(0, 0, 0.25)),
        torus("crest", 0.07, 0.015, (0, -0.1, 0.55), p["red"], rot=(math.pi / 2, 0, 0), segments=10, minor_segments=4),
    ]
    obj = join(parts, "knight")
    bevel(obj, 0.008)
    export(obj, "knight")


def build_beetle():
    p = new_scene()
    parts = [
        sphere("shell", 0.26, (0, 0, 0.22), p["glow"], scale=(1.1, 1.3, 0.75), subdiv=2),
        sphere("head", 0.12, (0, 0.28, 0.18), p["stone_dark"], subdiv=1),
        sphere("eye_l", 0.03, (-0.06, 0.36, 0.22), p["pink"], subdiv=1),
        sphere("eye_r", 0.03, (0.06, 0.36, 0.22), p["pink"], subdiv=1),
        cone("horn", 0.04, 0.0, 0.16, (0, 0.36, 0.3), p["brass"], verts=5, rot=(-0.7, 0, 0)),
    ]
    for i in range(6):
        side = -1 if i % 2 == 0 else 1
        z = 0.1 + (i // 2) * 0.14
        parts.append(box("leg%d" % i, (0.2, 0.04, 0.04), (side * 0.26, 0.05, z), p["dark"], rot=(0, 0, side * 0.5)))
    obj = join(parts, "beetle")
    export(obj, "beetle")


def build_imp():
    p = new_scene()
    parts = [
        sphere("body", 0.2, (0, 0, 0.26), p["red"], scale=(1.0, 0.9, 1.1), subdiv=1),
        sphere("head", 0.16, (0, 0, 0.52), p["red"], subdiv=1),
        cone("horn_l", 0.05, 0.0, 0.18, (-0.1, 0, 0.66), p["cream"], verts=5, rot=(0, 0.4, 0)),
        cone("horn_r", 0.05, 0.0, 0.18, (0.1, 0, 0.66), p["cream"], verts=5, rot=(0, -0.4, 0)),
        box("wing_l", (0.26, 0.03, 0.16), (-0.24, -0.06, 0.34), p["pink"], rot=(0, 0.3, 0.35)),
        box("wing_r", (0.26, 0.03, 0.16), (0.24, -0.06, 0.34), p["pink"], rot=(0, -0.3, -0.35)),
        sphere("eye_l", 0.03, (-0.06, 0.14, 0.54), p["amber"], subdiv=1),
        sphere("eye_r", 0.03, (0.06, 0.14, 0.54), p["amber"], subdiv=1),
    ]
    obj = join(parts, "imp")
    export(obj, "imp")


def build_spider():
    p = new_scene()
    parts = [
        sphere("abdomen", 0.22, (0, -0.1, 0.24), p["stone_dark"], scale=(1.0, 1.2, 0.9), subdiv=1),
        sphere("head", 0.15, (0, 0.18, 0.24), p["brass"], subdiv=1),
        sphere("eye_l", 0.035, (-0.06, 0.28, 0.3), p["glow"], subdiv=1),
        sphere("eye_r", 0.035, (0.06, 0.28, 0.3), p["glow"], subdiv=1),
    ]
    for i in range(8):
        side = -1 if i % 2 == 0 else 1
        z = 0.05 + (i // 2) * 0.1
        parts.append(box("leg%d" % i, (0.3, 0.04, 0.04), (side * 0.24, 0, z), p["dark"], rot=(0, 0, side * 0.6)))
        parts.append(box("shin%d" % i, (0.18, 0.035, 0.035), (side * 0.4, 0.02, z - 0.06), p["dark"], rot=(0, 0, side * -0.4)))
    obj = join(parts, "spider")
    export(obj, "spider")


def build_golem():
    p = new_scene()
    parts = [
        box("torso", (0.4, 0.3, 0.4), (0, 0, 0.42), p["stone"]),
        sphere("head", 0.18, (0, 0, 0.74), p["stone_dark"], subdiv=1, flat=True),
        box("arm_l", (0.14, 0.14, 0.34), (-0.3, 0, 0.36), p["stone_dark"]),
        box("arm_r", (0.14, 0.14, 0.34), (0.3, 0, 0.36), p["stone_dark"]),
        box("leg_l", (0.16, 0.16, 0.22), (-0.13, 0, 0.11), p["stone_dark"]),
        box("leg_r", (0.16, 0.16, 0.22), (0.13, 0, 0.11), p["stone_dark"]),
        sphere("eye", 0.06, (0, 0.16, 0.76), p["glow"], subdiv=1),
        torus("crack", 0.12, 0.02, (0, 0.16, 0.44), p["glow"], rot=(math.pi / 2, 0, 0), segments=8, minor_segments=4),
    ]
    obj = join(parts, "golem")
    bevel(obj, 0.02)
    export(obj, "golem")


def build_bat():
    p = new_scene()
    parts = [
        sphere("body", 0.16, (0, 0, 0.4), p["stone_dark"], scale=(0.9, 1.2, 0.9), subdiv=1),
        sphere("head", 0.1, (0, 0.16, 0.44), p["stone_dark"], subdiv=1),
        sphere("eye_l", 0.025, (-0.04, 0.22, 0.46), p["pink"], subdiv=1),
        sphere("eye_r", 0.025, (0.04, 0.22, 0.46), p["pink"], subdiv=1),
        box("wing_l", (0.34, 0.03, 0.2), (-0.28, 0, 0.42), p["pink"], rot=(0, 0.2, 0.5)),
        box("wing_r", (0.34, 0.03, 0.2), (0.28, 0, 0.42), p["pink"], rot=(0, -0.2, -0.5)),
        cone("ear_l", 0.04, 0.0, 0.1, (-0.06, 0.16, 0.54), p["stone_dark"], verts=4),
        cone("ear_r", 0.04, 0.0, 0.1, (0.06, 0.16, 0.54), p["stone_dark"], verts=4),
    ]
    obj = join(parts, "bat")
    export(obj, "bat")


def build_wraith():
    p = new_scene()
    parts = [
        cone("cloak", 0.3, 0.06, 0.7, (0, 0, 0.3), p["stone_dark"], verts=8),
        sphere("hood", 0.17, (0, 0, 0.68), p["dark"], subdiv=1),
        sphere("face", 0.11, (0, 0.1, 0.68), p["glow"], subdiv=1),
        sphere("eye_l", 0.025, (-0.04, 0.18, 0.7), p["dark"], subdiv=1),
        sphere("eye_r", 0.025, (0.04, 0.18, 0.7), p["dark"], subdiv=1),
        sphere("wisp_a", 0.05, (-0.2, 0, 0.2), p["glow"], subdiv=1),
        sphere("wisp_b", 0.04, (0.18, 0, 0.12), p["glow"], subdiv=1),
    ]
    obj = join(parts, "wraith")
    export(obj, "wraith")


def build_construct():
    p = new_scene()
    parts = [
        box("core", (0.32, 0.32, 0.32), (0, 0, 0.4), p["steel"], rot=(0, 0, 0.4)),
        torus("ring", 0.34, 0.045, (0, 0, 0.42), p["brass"], rot=(math.pi / 2, 0.4, 0), segments=18, minor_segments=5),
        sphere("eye", 0.12, (0, 0.2, 0.42), p["glow"], subdiv=2),
        box("plate_a", (0.16, 0.04, 0.16), (0, -0.2, 0.42), p["stone_dark"]),
        sphere("orb_a", 0.05, (-0.32, 0.1, 0.6), p["glow"], subdiv=1),
        sphere("orb_b", 0.04, (0.3, -0.1, 0.28), p["glow"], subdiv=1),
    ]
    obj = join(parts, "construct")
    bevel(obj, 0.012)
    export(obj, "construct")


def build_grove_enemy():
    p = new_scene()
    parts = [
        cyl("trunk", 0.13, 0.42, (0, 0, 0.21), p["wood_dark"], verts=6),
        sphere("canopy", 0.24, (0, 0, 0.56), p["leaf"], scale=(1.1, 1.0, 0.85), subdiv=1),
        sphere("eye_l", 0.035, (-0.08, 0.18, 0.3), p["amber"], subdiv=1),
        sphere("eye_r", 0.035, (0.08, 0.18, 0.3), p["amber"], subdiv=1),
        box("root_l", (0.16, 0.06, 0.06), (-0.16, 0, 0.06), p["wood_dark"], rot=(0, 0, 0.3)),
        box("root_r", (0.16, 0.06, 0.06), (0.16, 0, 0.06), p["wood_dark"], rot=(0, 0, -0.3)),
        cone("branch", 0.04, 0.0, 0.2, (0.18, 0, 0.44), p["leaf_dark"], verts=4, rot=(0, 0.6, 0)),
    ]
    obj = join(parts, "grove_enemy")
    export(obj, "grove")


def build_boss_core():
    p = new_scene()
    parts = [
        sphere("shell", 0.7, (0, 0, 0.7), p["stone"], scale=(1.0, 0.9, 1.0), subdiv=2),
        torus("ring", 0.7, 0.07, (0, 0, 0.7), p["brass"], rot=(math.pi / 2, 0, 0), segments=22, minor_segments=6),
        sphere("eye", 0.26, (0, 0.58, 0.7), p["pink"], scale=(1.0, 0.5, 0.8), subdiv=2),
        sphere("pupil", 0.12, (0, 0.72, 0.72), p["amber"], subdiv=1),
    ]
    for i in range(6):
        a = i * math.tau / 6
        parts.append(box("plate%d" % i, (0.2, 0.14, 0.28),
                         (math.cos(a) * 0.62, math.sin(a) * 0.62, 0.7), p["steel"], rot=(0, 0, a)))
    obj = join(parts, "boss_core")
    export(obj, "boss_core")


BUILDERS = [
    build_base, build_crossbow, build_barrel, build_crystal, build_gear, build_drum,
    build_bell, build_hive, build_banner, build_portal, build_castle_turret, build_mint,
    build_grove, build_mist, build_magnet, build_roost, build_furnace, build_coil,
    build_fountain, build_rune, build_castle, build_tree_a, build_tree_b, build_rock,
    build_crystal_prop, build_windmill, build_house, build_goblin, build_mouse,
    build_slime, build_knight, build_beetle, build_imp, build_spider, build_golem,
    build_bat, build_wraith, build_construct, build_grove_enemy, build_boss_core,
]


if __name__ == "__main__":
    for builder in BUILDERS:
        builder()
    print("asset build complete:", len(BUILDERS), "models")
