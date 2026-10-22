"""Builds kamote_rider_scene.blend: a 3D model of the game's highway.

Run it with Blender 4.2 or newer:

    blender -b --python blender/build_scene.py

The scene uses the game's real layout and colors (lib/game/game_config.dart,
lib/game/environments.dart, lib/game/render3d/vehicle_view.dart). One game
unit is 5 cm, so a 68-unit lane is 3.4 m wide.
"""

import math
import os
import random

import bpy

S = 0.05  # metres per game unit
LANE_W = 68 * S
LANES = 4
ROAD_HALF = LANE_W * LANES / 2
SHOULDER = 10 * S
SEG = 150.0  # metres of road per world
FPS = 24
SECONDS = 40
FRAMES = FPS * SECONDS
RIDE_START = 6.0
RIDE_END = SEG * 5 + 110.0

random.seed(7)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kamote_rider_scene.blend")


def lane_x(lane):
    """Lane 0 is the far left (oncoming); lane 3 is the far right."""
    return -ROAD_HALF + LANE_W * (lane + 0.5)


# ------------------------------------------------------------------ reset

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = "Kamote Rider"
scene.frame_start = 1
scene.frame_end = FRAMES
scene.render.fps = FPS
scene.render.resolution_x = 1080
scene.render.resolution_y = 1920  # portrait, like the game
scene.view_settings.view_transform = "Standard"
for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        pass
bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"

world = bpy.data.worlds.new("Sky")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs[0].default_value = (0.42, 0.66, 0.95, 1)
bg.inputs[1].default_value = 1.0

# ------------------------------------------------------------- materials

_mats = {}


def _lin(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(hex_color, emit=0.0, rough=0.6, metal=0.0, alpha=1.0):
    key = (hex_color, emit, rough, metal, alpha)
    if key in _mats:
        return _mats[key]
    h = hex_color.lstrip("#")
    rgb = tuple(_lin(int(h[i : i + 2], 16)) for i in (0, 2, 4))
    m = bpy.data.materials.new(f"#{h}" + (" glow" if emit else ""))
    m.diffuse_color = (*rgb, alpha)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1)
        bsdf.inputs["Emission Strength"].default_value = emit
    if alpha < 1:
        bsdf.inputs["Alpha"].default_value = alpha
    _mats[key] = m
    return m


# ------------------------------------------------------------ collections

_cols = {}


def col(name, parent=None):
    if name not in _cols:
        c = bpy.data.collections.new(name)
        (parent or scene.collection).children.link(c)
        _cols[name] = c
    return _cols[name]


current = [scene.collection]


def _link(obj):
    current[0].objects.link(obj)
    return obj


# ---------------------------------------------------------------- meshes


def _mesh_obj(name, verts, faces, material, loc=(0, 0, 0), rot=(0, 0, 0), smooth=False):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    me.materials.append(material)
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    ob.rotation_euler = rot
    return _link(ob)


def box(name, center, size, material, rot=(0, 0, 0)):
    """Axis-aligned box; size is the full (x, y, z) extent."""
    x, y, z = (s / 2 for s in size)
    v = [(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z), (-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return _mesh_obj(name, v, f, material, center, rot)


def cyl(name, center, radius, depth, material, sides=16, rot=(0, 0, 0), top_radius=None):
    """Cylinder (or cone/frustum when top_radius differs) along local Z."""
    tr = radius if top_radius is None else top_radius
    v, f = [], []
    for i in range(sides):
        a = 2 * math.pi * i / sides
        v.append((radius * math.cos(a), radius * math.sin(a), -depth / 2))
        v.append((tr * math.cos(a), tr * math.sin(a), depth / 2))
    for i in range(sides):
        j = (i + 1) % sides
        f.append((2 * i, 2 * j, 2 * j + 1, 2 * i + 1))
    f.append(tuple(2 * i for i in reversed(range(sides))))
    if tr > 0:
        f.append(tuple(2 * i + 1 for i in range(sides)))
    return _mesh_obj(name, v, f, material, center, rot, smooth=sides > 8)


def ball(name, center, radius, material, scale=(1, 1, 1), rings=8, segs=12):
    v, f = [(0, 0, radius)], []
    for r in range(1, rings):
        t = math.pi * r / rings
        for s in range(segs):
            a = 2 * math.pi * s / segs
            v.append((radius * math.sin(t) * math.cos(a), radius * math.sin(t) * math.sin(a), radius * math.cos(t)))
    v.append((0, 0, -radius))
    bottom = len(v) - 1
    for s in range(segs):
        f.append((0, 1 + s, 1 + (s + 1) % segs))
    for r in range(rings - 2):
        a0, a1 = 1 + r * segs, 1 + (r + 1) * segs
        for s in range(segs):
            n = (s + 1) % segs
            f.append((a0 + s, a1 + s, a1 + n, a0 + n))
    last = 1 + (rings - 2) * segs
    for s in range(segs):
        f.append((last + s, bottom, last + (s + 1) % segs))
    ob = _mesh_obj(name, v, f, material, center, smooth=True)
    ob.scale = scale
    return ob


def pyramid(name, center, w, d, h, material):
    x, y = w / 2, d / 2
    v = [(-x, -y, 0), (x, -y, 0), (x, y, 0), (-x, y, 0), (0, 0, h)]
    f = [(0, 3, 2, 1), (0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)]
    return _mesh_obj(name, v, f, material, center)


def text(name, body, loc, size, material, rot=(math.radians(90), 0, 0), align="CENTER"):
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = body
    cu.size = size
    cu.align_x = align
    cu.align_y = "CENTER"
    cu.extrude = 0.02
    ob = bpy.data.objects.new(name, cu)
    ob.data.materials.append(material)
    ob.location = loc
    ob.rotation_euler = rot
    return _link(ob)


def group(name, loc=(0, 0, 0), rot_z=0.0):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.5
    e.location = loc
    e.rotation_euler = (0, 0, rot_z)
    return _link(e)


def parent(children, p):
    for c in children:
        c.parent = p
    return p


# ---------------------------------------------------------------- worlds

WORLDS = [
    dict(name="City Highway", left="8D9AA3", right="8D9AA3", detail="7A8790", asphalt="3C4043", shoulder="5F6368",
         rails=False, cross=False, lprops=["building", "streetlight", "building", "roadsign"],
         rprops=["building", "streetlight", "billboard", "building"], spacing=120,
         traffic={"car": 5, "taxi": 3, "bus": 2, "van": 2}, accent="42A5F5"),
    dict(name="Provincial Road", left="7CB342", right="8BC34A", detail="558B2F", asphalt="4A4A48", shoulder="A1887F",
         rails=False, cross=False, lprops=["nipahut", "palm", "tree", "bush"],
         rprops=["sarisari", "palm", "tree", "nipahut"], spacing=150,
         traffic={"tricycle": 5, "jeepney": 4, "truck": 1, "car": 2}, accent="9CCC65"),
    dict(name="Mountain Road", left="795548", right="2E7D32", detail="5D4037", asphalt="424242", shoulder="6D6D6D",
         rails=True, cross=False, lprops=["rock", "warning", "rock"],
         rprops=["pine", "pine", "warning", "pine"], spacing=110,
         traffic={"truck": 4, "car": 3, "jeepney": 2, "van": 1}, accent="8D6E63"),
    dict(name="Coastal Highway", left="29B6F6", right="FFE082", detail="81D4FA", asphalt="455A64", shoulder="FFECB3",
         rails=True, cross=False, lprops=["boat", "boat"],
         rprops=["palm", "palm", "sarisari", "bush"], spacing=140,
         traffic={"car": 4, "van": 3, "bus": 2, "jeepney": 2}, accent="26C6DA"),
    dict(name="Urban Road", left="9E9E9E", right="A5A5A5", detail="888888", asphalt="353535", shoulder="BDBDBD",
         rails=False, cross=True, lprops=["tower", "building", "billboard", "tower"],
         rprops=["tower", "streetlight", "building", "tower"], spacing=100,
         traffic={"jeepney": 5, "car": 3, "bus": 2, "taxi": 2, "tricycle": 2}, accent="FF7043"),
]

VEHICLE_SIZE = {  # game units: width, length
    "car": (42, 76), "taxi": (42, 76), "van": (46, 86), "suv": (46, 84), "jeepney": (48, 104),
    "bus": (56, 132), "truck": (54, 122), "tricycle": (44, 60), "lrt": (56, 190),
}
# part, from, to, bottom, top, inset, xFrom, xTo  (from vehicle_view.dart)
VEHICLE_BLOCKS = {
    "car": [("body", 0, 1, 0, 14, 0, 0, 1), ("cabin", .27, .8, 14, 27, 4, 0, 1)],
    "taxi": [("body", 0, 1, 0, 14, 0, 0, 1), ("cabin", .27, .8, 14, 27, 4, 0, 1)],
    "suv": [("body", 0, 1, 0, 17, 0, 0, 1), ("cabin", .2, .88, 17, 35, 3, 0, 1)],
    "van": [("hood", 0, .14, 0, 17, 1, 0, 1), ("upper", .12, 1, 0, 38, 0, 0, 1)],
    "jeepney": [("hood", 0, .22, 0, 18, 4, 0, 1), ("jeep", .22, 1, 0, 37, 0, 0, 1)],
    "bus": [("upper", 0, 1, 0, 58, 0, 0, 1)],
    "truck": [("cab", 0, .25, 0, 36, 2, 0, 1), ("cargo", .26, 1, 0, 48, 0, 0, 1)],
    "tricycle": [("bike", .05, .95, 0, 18, 0, .12, .36), ("sidecab", .05, .95, 0, 33, 0, .38, .96)],
    "lrt": [("train", 0, .49, 0, 52, 0, 0, 1), ("train", .51, 1, 0, 52, 0, 0, 1)],
}
PAINT = ["E53935", "1E88E5", "FAFAFA", "424242", "43A047", "FDD835", "8E24AA", "90A4AE"]


def paint_for(kind, variant):
    return {
        "taxi": "F5F5F5",
        "jeepney": ["CFD8DC", "FFCA28", "EF5350"][variant % 3],
        "bus": ["1565C0", "F4511E", "00897B"][variant % 3],
        "truck": ["E53935", "1E88E5", "FFB300"][variant % 3],
        "tricycle": ["1E88E5", "E53935", "43A047"][variant % 3],
        "lrt": ["ECEFF1", "E0F2F1", "EDE7F6"][variant % 3],
    }.get(kind, PAINT[variant % len(PAINT)])


# --------------------------------------------------------------- vehicles

GLASS = mat("22344A", rough=0.15, metal=0.2)
TIRE = mat("151515", rough=0.9)
CHROME = mat("CFD8DC", rough=0.2, metal=0.9)
HEAD = mat("FFF9C4", emit=4)
TAIL = mat("C62828", emit=3)
BLACK = mat("212121")
WHITE = mat("F5F5F5")
LIFT = 0.28  # wheel clearance under a vehicle body


def vehicle(name, kind, variant, loc, oncoming=False, body_hex=None):
    w, l = (u * S for u in VEHICLE_SIZE[kind])
    body = mat(body_hex or paint_for(kind, variant), rough=0.35, metal=0.3)
    root = group(name, loc, math.pi if oncoming else 0.0)
    parts = []
    for part, fr, to, bot, top, inset, xf, xt in VEHICLE_BLOCKS[kind]:
        y0, y1 = l / 2 - fr * l, l / 2 - to * l  # front of the vehicle is +Y
        x0, x1 = -w / 2 + xf * w + inset * S, -w / 2 + xt * w - inset * S
        z0, z1 = LIFT + bot * S, LIFT + top * S
        cx, cy, cz = (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2
        sx, sy, sz = x1 - x0, y0 - y1, z1 - z0
        if part == "cabin":
            parts.append(box(f"{name} cabin", (cx, cy, cz), (sx, sy, sz), GLASS))
            parts.append(box(f"{name} roof", (cx, cy, z1 - 0.04), (sx + 0.02, sy * 0.8, 0.1), body))
            if kind == "taxi":
                parts.append(box(f"{name} taxi sign", (cx, cy, z1 + 0.12), (0.5, 0.2, 0.16), mat("FFC107", emit=1)))
        elif part in ("upper", "train"):
            parts.append(box(f"{name} body", (cx, cy, cz), (sx, sy, sz), body))
            band = z0 + sz * 0.62
            parts.append(box(f"{name} windows", (cx, cy, band), (sx + 0.03, sy * 0.92, sz * 0.28), GLASS))
            if kind == "lrt":
                parts.append(box(f"{name} stripe", (cx, cy, z0 + sz * 0.3), (sx + 0.04, sy, 0.18), mat("7E57C2")))
        elif part == "jeep":
            parts.append(box(f"{name} body", (cx, cy, cz), (sx, sy, sz), body))
            parts.append(box(f"{name} windows", (cx, cy, z0 + sz * 0.68), (sx + 0.03, sy * 0.9, sz * 0.22), GLASS))
            parts.append(box(f"{name} roof", (cx, cy, z1 + 0.05), (sx + 0.08, sy + 0.1, 0.1), CHROME))
            for i, c in enumerate(["E53935", "1E88E5", "FFEB3B", "43A047"]):
                parts.append(box(f"{name} stripe {i}", (cx, cy, z0 + 0.25 + i * 0.09), (sx + 0.05, sy * 0.95, 0.06), mat(c)))
            parts.append(ball(f"{name} horse", (cx, y0 + 0.9, z1 + 0.2), 0.12, CHROME, scale=(1, 2, 1)))
        elif part == "hood" and kind == "jeepney":
            parts.append(box(f"{name} hood", (cx, cy, cz), (sx, sy, sz), CHROME))
        elif part == "cab":
            parts.append(box(f"{name} cab", (cx, cy, cz), (sx, sy, sz), body))
            parts.append(box(f"{name} windshield", (cx, y0 + 0.02, z0 + sz * 0.7), (sx * 0.9, 0.05, sz * 0.35), GLASS))
        elif part == "cargo":
            parts.append(box(f"{name} cargo", (cx, cy, cz), (sx, sy, sz), mat("E0E0E0")))
        elif part == "sidecab":
            parts.append(box(f"{name} sidecar", (cx, cy, cz), (sx, sy, sz), body))
            parts.append(box(f"{name} sidecar window", (cx, cy, z0 + sz * 0.7), (sx + 0.03, sy * 0.7, sz * 0.3), GLASS))
        elif part == "bike":
            parts.append(box(f"{name} bike", (cx, cy, cz), (sx, sy, sz), mat("37474F")))
            parts.append(ball(f"{name} driver", (cx, cy - 0.1, z1 + 0.25), 0.22, mat("D7A982")))
        else:
            parts.append(box(f"{name} {part}", (cx, cy, cz), (sx, sy, sz), body))
    # Lights at the front and rear.
    for side in (-1, 1):
        parts.append(box(f"{name} headlight", (side * w * 0.36, l / 2 + 0.01, LIFT + 0.4), (0.3, 0.04, 0.14), HEAD))
        parts.append(box(f"{name} taillight", (side * w * 0.38, -l / 2 - 0.01, LIFT + 0.45), (0.26, 0.04, 0.14), TAIL))
    # Wheels.
    axles = [l / 2 - min(0.7, l * 0.18), -l / 2 + min(0.7, l * 0.18)]
    if l > 5.5:
        axles.append(-l / 2 + 1.7)
    for ay in axles:
        for side in (-1, 1):
            parts.append(cyl(f"{name} wheel", (side * (w / 2 - 0.12), ay, 0.32), 0.32, 0.24, TIRE, 14, rot=(0, math.radians(90), 0)))
    return parent(parts, root)


# -------------------------------------------------------- bike and riders


def motorcycle(name, loc, body_hex, accent_hex, jacket_hex, helmet_hex, officer=False):
    root = group(name, loc)
    body, accent = mat(body_hex, rough=0.3, metal=0.4), mat(accent_hex)
    p = []
    for y in (0.62, -0.62):
        p.append(cyl(f"{name} tyre", (0, y, 0.32), 0.32, 0.12, TIRE, 18, rot=(0, math.radians(90), 0)))
        p.append(cyl(f"{name} rim", (0, y, 0.32), 0.17, 0.14, CHROME, 12, rot=(0, math.radians(90), 0)))
    p.append(box(f"{name} frame", (0, 0, 0.55), (0.22, 1.05, 0.3), body))
    p.append(box(f"{name} tank", (0, 0.25, 0.78), (0.3, 0.45, 0.2), body))
    p.append(box(f"{name} stripe", (0, 0.25, 0.79), (0.32, 0.12, 0.21), accent))
    p.append(box(f"{name} seat", (0, -0.25, 0.8), (0.26, 0.55, 0.1), BLACK))
    p.append(box(f"{name} fork", (0, 0.55, 0.62), (0.08, 0.08, 0.6), CHROME, rot=(math.radians(-20), 0, 0)))
    p.append(box(f"{name} handlebar", (0, 0.5, 0.98), (0.7, 0.05, 0.05), CHROME))
    p.append(box(f"{name} headlight", (0, 0.72, 0.85), (0.16, 0.05, 0.12), HEAD))
    p.append(box(f"{name} taillight", (0, -0.7, 0.75), (0.16, 0.04, 0.08), TAIL))
    p.append(cyl(f"{name} exhaust", (0.16, -0.35, 0.4), 0.05, 0.6, CHROME, 10, rot=(math.radians(90), 0, 0)))
    # Rider, leaning forward over the tank.
    jacket, jeans = mat(jacket_hex), mat("283593")
    p.append(box(f"{name} rider legs", (0, -0.15, 0.88), (0.36, 0.4, 0.18), jeans))
    p.append(box(f"{name} rider torso", (0, -0.05, 1.18), (0.4, 0.26, 0.55), jacket, rot=(math.radians(-25), 0, 0)))
    for side in (-1, 1):
        p.append(box(f"{name} rider arm", (side * 0.24, 0.24, 1.15), (0.09, 0.5, 0.09), jacket, rot=(math.radians(25), 0, 0)))
    p.append(ball(f"{name} helmet", (0, 0.08, 1.55), 0.17, mat(helmet_hex, rough=0.2), scale=(1, 1.1, 1)))
    p.append(box(f"{name} visor", (0, 0.24, 1.55), (0.22, 0.04, 0.1), GLASS))
    if officer:
        p.append(box(f"{name} siren bar", (0, -0.62, 1.1), (0.5, 0.08, 0.06), BLACK))
        p.append(ball(f"{name} red light", (-0.22, -0.62, 1.18), 0.07, mat("FF1744", emit=12)))
        p.append(ball(f"{name} blue light", (0.22, -0.62, 1.18), 0.07, mat("2979FF", emit=12)))
        text(f"{name} LTO", "LTO", (0, -0.73, 0.62), 0.16, mat("1565C0")).parent = root
    return parent(p, root)


# -------------------------------------------------------- roadside props


def prop(kind, x, y, w, side):
    """Builds one roadside prop centred at (x, y). side is -1 left, 1 right."""
    n = f"{kind} {y:.0f}"
    face = -side  # the side facing the road
    if kind == "building":
        h = random.uniform(7, 20)
        d = random.uniform(8, 12)
        c = random.choice(["B0BEC5", "CFD8DC", "FFCC80", "BCAAA4", "90CAF9", "E6EE9C"])
        box(n, (x + side * d / 2, y, h / 2), (d, random.uniform(10, 14), h), mat(c))
        for k in range(1, int(h // 3)):
            box(f"{n} windows", (x + side * d / 2 + face * (d / 2 + 0.02), y, k * 3), (0.04, 9, 1.1), mat("FFF59D", emit=0.6))
    elif kind == "tower":
        h = random.uniform(30, 60)
        c = random.choice(["78909C", "546E7A", "90A4AE", "4FC3F7"])
        box(n, (x + side * 7, y, h / 2), (13, 13, h), mat(c, rough=0.25, metal=0.4))
        for k in range(1, int(h // 3.5)):
            box(f"{n} glass", (x + side * 7 + face * 6.52, y, k * 3.5), (0.04, 12, 1.6), GLASS)
    elif kind == "streetlight":
        cyl(n, (x, y, 4), 0.1, 8, mat("616161"), 8)
        box(f"{n} arm", (x + face * 1, y, 7.9), (2.2, 0.12, 0.12), mat("616161"))
        box(f"{n} lamp", (x + face * 2, y, 7.8), (0.6, 0.3, 0.12), mat("FFF8E1", emit=6))
    elif kind == "billboard":
        for dy in (-2.5, 2.5):
            cyl(f"{n} post", (x, y + dy, 3), 0.15, 6, mat("455A64"), 8)
        box(f"{n} board", (x, y, 7.5), (0.3, 8, 3.5), mat("FFFFFF"))
        text(f"{n} text", "KAMOTE\nRIDER", (x + face * 0.17, y, 7.5), 1.1, mat("E53935"),
             rot=(math.radians(90), 0, math.radians(90 * face)))
    elif kind == "roadsign":
        cyl(n, (x, y, 2), 0.06, 4, mat("9E9E9E"), 8)
        box(f"{n} panel", (x, y, 4.2), (0.08, 2.4, 1.2), mat("2E7D32"))
    elif kind == "warning":
        cyl(n, (x, y, 1.2), 0.05, 2.4, mat("9E9E9E"), 8)
        box(f"{n} sign", (x, y, 2.6), (0.06, 0.9, 0.9), mat("FFEB3B"), rot=(math.radians(45), 0, 0))
    elif kind == "tree":
        cyl(n, (x, y, 1.5), 0.25, 3, mat("6D4C41"), 8)
        ball(f"{n} leaves", (x, y, 4), random.uniform(1.8, 2.6), mat(random.choice(["43A047", "388E3C", "66BB6A"])))
    elif kind == "bush":
        ball(n, (x, y, 0.6), random.uniform(0.8, 1.3), mat("558B2F"), scale=(1.3, 1, 0.8))
    elif kind == "pine":
        cyl(n, (x, y, 1), 0.25, 2, mat("5D4037"), 8)
        for k, r in enumerate((2.4, 1.8, 1.2)):
            cyl(f"{n} needles", (x, y, 2.6 + k * 1.6), r, 2.6, mat("1B5E20"), 10, top_radius=0)
    elif kind == "palm":
        h = random.uniform(7, 10)
        lean = math.radians(random.uniform(-8, 8))
        cyl(n, (x, y, h / 2), 0.18, h, mat("8D6E63"), 8, rot=(lean, 0, 0))
        top = (x, y - math.sin(lean) * h / 2, h)
        for k in range(7):
            a = 2 * math.pi * k / 7
            box(f"{n} frond", (top[0] + math.cos(a) * 1.4, top[1] + math.sin(a) * 1.4, top[2] - 0.3),
                (3, 0.6, 0.06), mat("2E7D32"), rot=(0, math.radians(20), a))
        ball(f"{n} coconuts", top, 0.35, mat("6D4C41"))
    elif kind == "rock":
        r = random.uniform(1, 2.2)
        ball(n, (x, y, r * 0.5), r, mat("8D8D8D", rough=0.9), scale=(1.2, 1, 0.7), rings=5, segs=7)
    elif kind == "nipahut":
        for dx in (-1.6, 1.6):
            for dy in (-1.6, 1.6):
                cyl(f"{n} stilt", (x + dx, y + dy, 0.5), 0.1, 1, mat("6D4C41"), 6)
        box(f"{n} walls", (x, y, 2.1), (3.6, 3.6, 2.2), mat("D7B98E"))
        box(f"{n} door", (x + face * 1.81, y, 1.9), (0.04, 0.9, 1.5), mat("5D4037"))
        pyramid(f"{n} roof", (x, y, 3.2), 4.8, 4.8, 2.2, mat("A1887F", rough=1))
    elif kind == "sarisari":
        box(n, (x, y, 1.4), (3.6, 4.4, 2.8), mat("FFE0B2"))
        box(f"{n} counter", (x + face * 1.81, y, 1.6), (0.05, 3.2, 1.0), mat("3E2723"))
        box(f"{n} awning", (x + face * 2.3, y, 2.7), (1.4, 4.6, 0.08), mat("E53935"), rot=(0, math.radians(-12 * face), 0))
        box(f"{n} sign", (x + face * 1.81, y, 3.1), (0.06, 3.6, 0.6), mat("FFEB3B"))
        text(f"{n} text", "SARI-SARI", (x + face * 1.85, y, 3.1), 0.45, mat("C62828"),
             rot=(math.radians(90), 0, math.radians(90 * face)))
    elif kind == "boat":
        bx = x + side * random.uniform(4, 18)
        hull = mat(random.choice(["E53935", "1E88E5", "FFFFFF", "FFB300"]))
        box(n, (bx, y, 0.15), (1.0, 6, 0.5), hull)
        for dx in (-1.6, 1.6):
            box(f"{n} outrigger", (bx + dx, y, 0.05), (0.15, 5, 0.15), mat("D7CCC8"))
            box(f"{n} arm", (bx + dx / 2, y + 1.2, 0.3), (1.6, 0.1, 0.1), mat("D7CCC8"))
        cyl(f"{n} mast", (bx, y, 1.5), 0.05, 2.6, mat("8D6E63"), 6)


def road_segment(i, wd, y0, y1):
    length = y1 - y0
    cy = (y0 + y1) / 2
    current[0] = col(f"{i + 1}. {wd['name']}")
    asphalt = mat(wd["asphalt"], rough=0.85)
    box("road", (0, cy, -0.05), (ROAD_HALF * 2, length, 0.1), asphalt)
    for side in (-1, 1):
        box("shoulder", (side * (ROAD_HALF + SHOULDER / 2), cy, -0.04), (SHOULDER, length, 0.1), mat(wd["shoulder"]))
        box("edge line", (side * (ROAD_HALF - 0.12), cy, 0.005), (0.15, length, 0.01), WHITE)
    # Double yellow between the two oncoming lanes and the two same-direction lanes.
    for dx in (-0.12, 0.12):
        box("centre line", (dx, cy, 0.005), (0.12, length, 0.01), mat("FFC107"))
    # White dashes between lanes going the same way.
    for lane_edge in (-LANE_W, LANE_W):
        y = y0 + 2
        while y < y1 - 3:
            box("lane dash", (lane_edge, y + 1.5, 0.005), (0.14, 3, 0.01), WHITE)
            y += 9
    edge = ROAD_HALF + SHOULDER
    # Ground on each side.
    for side, key in ((-1, "left"), (1, "right")):
        gm = mat(wd[key], rough=0.95)
        if wd["name"] == "Mountain Road" and side == -1:
            # Cliff face rising beside the road.
            _mesh_obj("cliff", [(-edge, y0, 0), (-edge, y1, 0), (-edge - 12, y1, 22), (-edge - 12, y0, 22),
                                (-edge - 60, y0, 22), (-edge - 60, y1, 22)],
                      [(0, 1, 2, 3), (3, 2, 5, 4)], gm)
        elif wd["name"] == "Coastal Highway" and side == -1:
            box("seawall", (-edge - 1, cy, -0.5), (2, length, 1.2), mat("BDBDBD"))
            box("sea", (-edge - 152, cy, -1.0), (300, length, 0.1), mat(wd["left"], rough=0.05, metal=0.2))
        else:
            box("ground", (side * (edge + 40), cy, -0.06), (80, length, 0.1), gm)
            if wd["name"] == "Provincial Road":
                for k in range(3):  # rice-paddy dykes
                    box("paddy dyke", (side * (edge + 8 + k * 9), cy, 0.02), (0.4, length, 0.12), mat(wd["detail"]))
    if wd["rails"]:
        for side in (-1, 1):
            box("guardrail", (side * (edge - 0.1), cy, 0.7), (0.08, length, 0.32), CHROME)
            y = y0 + 1
            while y < y1:
                box("rail post", (side * (edge - 0.1), y, 0.35), (0.12, 0.12, 0.7), mat("9E9E9E"))
                y += 4
    if wd["cross"]:
        for cyw in (y0 + 40, y0 + 110):
            for k in range(9):
                box("crosswalk", (-ROAD_HALF + 0.7 + k * 1.5, cyw, 0.006), (0.8, 3.5, 0.01), WHITE)
    # Roadside props, using the game's per-world prop lists and spacing.
    for side, props in ((-1, wd["lprops"]), (1, wd["rprops"])):
        y, k = y0 + random.uniform(2, 10), 0
        while y < y1 - 4:
            kind = props[k % len(props)]
            off = 2.5 if kind in ("streetlight", "roadsign", "warning") else 6
            if kind == "boat":
                off = 4
            prop(kind, side * (edge + off), y, wd, side)
            y += wd["spacing"] * S * random.uniform(1.6, 2.6)
            k += 1
    # Overhead gantry naming the world, like the game's world banner.
    for side in (-1, 1):
        cyl("gantry post", (side * (edge + 0.3), y0 + 4, 3.5), 0.18, 7, mat("607D8B"), 10)
    box("gantry beam", (0, y0 + 4, 6.9), (edge * 2 + 0.6, 0.3, 0.35), mat("607D8B"))
    box("world sign", (0, y0 + 3.85, 6.0), (9, 0.1, 1.6), mat(wd["accent"]))
    text("world name", wd["name"].upper(), (0, y0 + 3.79, 6.0), 0.8, mat("FFFFFF", emit=1.5))
    if wd["name"] == "City Highway":
        flyover(y0 + 75)


def flyover(y):
    deck = mat("9E9E9E")
    box("flyover deck", (0, y, 7.5), (60, 9, 0.8), deck)
    for x in (-ROAD_HALF - 2.5, ROAD_HALF + 2.5):
        box("flyover pillar", (x, y, 3.6), (1.2, 2.5, 7.2), deck)
    for dy in (-4.3, 4.3):
        box("flyover barrier", (0, y + dy, 8.3), (60, 0.25, 0.8), mat("BDBDBD"))


def tunnel(y0, y1):
    current[0] = col("6. Secret Manhole Tunnel")
    length, cy = y1 - y0, (y0 + y1) / 2
    wall, dark = mat("3A3F45"), mat("2E3237")
    box("tunnel floor", (0, cy, -0.05), (ROAD_HALF * 2 + 2, length, 0.1), mat("2B2D30"))
    for side in (-1, 1):
        box("tunnel wall", (side * (ROAD_HALF + 1.5), cy, 4), (1, length, 8), wall)
    box("tunnel ceiling", (0, cy, 8.2), (ROAD_HALF * 2 + 4, length, 0.4), dark)
    portal = mat("455A64")
    box("portal top", (0, y0, 9.5), (ROAD_HALF * 2 + 8, 1.5, 3), portal)
    text("tunnel name", "UNDERGROUND TUNNEL", (0, y0 - 0.8, 9.5), 0.9, mat("B388FF", emit=3))
    # Far wall with the exit back up to the surface.
    box("tunnel end wall", (0, y1, 4), (ROAD_HALF * 2 + 4, 0.5, 8.4), wall)
    box("exit ramp light", (0, y1 - 0.3, 4.5), (6, 0.1, 3), mat("FFF8E1", emit=5))
    text("exit sign", "EXIT TO SURFACE", (0, y1 - 0.4, 6.7), 0.6, mat("76FF03", emit=4))
    # LRT rails in every lane.
    for lane in range(LANES):
        for dx in (-0.72, 0.72):
            box("rail", (lane_x(lane) + dx, cy, 0.05), (0.08, length, 0.1), CHROME)
    y = y0 + 1
    while y < y1:
        for lane in range(LANES):
            box("sleeper", (lane_x(lane), y, 0.02), (2, 0.25, 0.06), mat("4E342E"))
        y += 1.2
    y = y0 + 5
    while y < y1:
        for side in (-1, 1):
            box("pillar", (side * (ROAD_HALF + 0.6), y, 4), (0.6, 0.6, 8), mat("55595E"))
            box("tunnel lamp", (side * (ROAD_HALF + 0.85), y + 3, 6.2), (0.1, 1.4, 0.2), mat("B388FF", emit=8))
        light = bpy.data.lights.new("tunnel light", "POINT")
        light.energy = 600
        light.color = (0.75, 0.65, 1.0)
        _link(bpy.data.objects.new("tunnel light", light)).location = (0, y + 3, 6.5)
        y += 10
    # LRT trains running through.
    current[0] = col("Traffic")
    for k, (lane, ty) in enumerate([(0, y0 + 40), (1, y0 + 85), (2, y0 + 25)]):
        vehicle(f"LRT {k + 1}", "lrt", k, (lane_x(lane), ty, 0), oncoming=lane < 2)


# --------------------------------------------------------------- pickups


def cash(name, loc):
    root = group(name, loc)
    bill = box(f"{name} bill", (0, 0, 0), (0.9, 0.05, 0.45), mat("66BB6A", emit=0.4))
    num = text(f"{name} value", "P100", (0, -0.03, 0), 0.22, mat("1B5E20"))
    return parent([bill, num], root)


def fuel(name, loc):
    root = group(name, loc)
    p = [box(f"{name} can", (0, 0, 0), (0.45, 0.25, 0.6), mat("E53935", rough=0.3)),
         box(f"{name} handle", (0, 0, 0.36), (0.3, 0.06, 0.1), BLACK),
         cyl(f"{name} spout", (0.14, 0, 0.38), 0.05, 0.18, mat("FFEB3B"), 8)]
    return parent(p, root)


def cone(name, loc):
    root = group(name, loc)
    p = [box(f"{name} base", (0, 0, 0.03), (0.5, 0.5, 0.06), mat("FF6D00")),
         cyl(f"{name} cone", (0, 0, 0.4), 0.2, 0.7, mat("FF6D00"), 12, top_radius=0.03),
         cyl(f"{name} band", (0, 0, 0.45), 0.13, 0.12, WHITE, 12)]
    return parent(p, root)


def pothole(name, loc):
    return cyl(name, loc, 0.7, 0.02, mat("1A1A1A", rough=1), 12)


def barrier(name, loc):
    root = group(name, loc)
    p = [box(f"{name} board", (0, 0, 0.8), (2.4, 0.12, 0.35), mat("FF3D00")),
         box(f"{name} stripe", (0, -0.07, 0.8), (1.6, 0.02, 0.12), WHITE)]
    for dx in (-1, 1):
        p.append(box(f"{name} leg", (dx, 0, 0.4), (0.08, 0.5, 0.8), mat("FFEB3B")))
    return parent(p, root)


def spin(ob, start_frame=1):
    ob.rotation_euler = (0, 0, 0)
    ob.keyframe_insert("rotation_euler", index=2, frame=start_frame)
    ob.rotation_euler = (0, 0, math.radians(360 * SECONDS / 2))
    ob.keyframe_insert("rotation_euler", index=2, frame=FRAMES)


def hide_after(ob, frame):
    ob.scale = (1, 1, 1)
    ob.keyframe_insert("scale", frame=max(1, frame - 1))
    ob.scale = (0.001, 0.001, 0.001)
    ob.keyframe_insert("scale", frame=frame)


# ----------------------------------------------------------------- build

for i, wd in enumerate(WORLDS):
    road_segment(i, wd, i * SEG, (i + 1) * SEG)
tunnel(SEG * 5, SEG * 5 + 130)

current[0] = col("Manhole")
cyl("manhole cover", (lane_x(3), SEG * 5 - 6, 0.01), 0.9, 0.03, mat("37474F", metal=0.6), 20)
cyl("manhole rim", (lane_x(3), SEG * 5 - 6, 0.005), 1.0, 0.02, mat("FFC107", emit=1), 20)

# LTO checkpoint at the start of every run.
current[0] = col("LTO Checkpoint")
edge = ROAD_HALF + SHOULDER
box("checkpoint booth", (edge + 2, 12, 1.3), (2.4, 2.4, 2.6), mat("1565C0"))
box("checkpoint roof", (edge + 2, 12, 2.7), (3, 3, 0.2), WHITE)
text("checkpoint sign", "LTO CHECKPOINT", (edge + 0.75, 12, 2.0), 0.28, WHITE,
     rot=(math.radians(90), 0, math.radians(-90)))
for k in range(4):
    cone(f"checkpoint cone {k}", (ROAD_HALF + 0.2, 4 + k * 3, 0))

# Player's bike: the starter Kamote 110 (red with white accents).
current[0] = col("Player")
player = motorcycle("Kamote 110", (lane_x(3), RIDE_START, 0), "E53935", "FFFFFF", "6D3A3A", "FFFFFF")


def ride_y(frame):
    return RIDE_START + (RIDE_END - RIDE_START) * (frame - 1) / (FRAMES - 1)


def frame_at(y):
    return 1 + (y - RIDE_START) / (RIDE_END - RIDE_START) * (FRAMES - 1)


player.keyframe_insert("location", frame=1)
player.location.y = RIDE_END
player.keyframe_insert("location", frame=FRAMES)

# Lane changes: weave into lane 2 around hazards at these distances.
DODGES = [95, 260, 420, 560, 700]
for y in DODGES:
    f = frame_at(y)
    for df, lane, roll in ((-24, 3, 0), (-12, 2, -12), (0, 2, 0), (12, 3, 12), (24, 3, 0)):
        player.location.x = lane_x(lane)
        player.keyframe_insert("location", index=0, frame=f + df)
        player.rotation_euler.y = math.radians(roll)
        player.keyframe_insert("rotation_euler", index=1, frame=f + df)
        player.rotation_euler.y = 0

# The LTO officer chasing the player for the first stretch, then falling back.
officer = motorcycle("LTO Officer", (lane_x(3), RIDE_START - 9, 0), "ECEFF1", "1565C0", "1565C0", "FFFFFF", officer=True)
officer.keyframe_insert("location", frame=1)
officer.location.y = ride_y(FPS * 10) - 4
officer.keyframe_insert("location", frame=FPS * 10)
officer.location.y = ride_y(FPS * 10) + 25
officer.keyframe_insert("location", frame=FPS * 14)

# Hazards in lane 3 that the player swerves around; pickups in lane 2 the
# player grabs mid-swerve.
current[0] = col("Hazards and Pickups")
hazard_makers = [cone, pothole, barrier, pothole, cone]
for k, y in enumerate(DODGES):
    hazard_makers[k](f"hazard {k + 1}", (lane_x(3), y, 0.01 if hazard_makers[k] is pothole else 0))
    c = cash(f"cash {k + 1}", (lane_x(2), y, 1.0))
    spin(c)
    hide_after(c, int(frame_at(y)))
for k, y in enumerate((180, 340, 500, 640)):
    fc = fuel(f"fuel {k + 1}", (lane_x(3), y, 0.6))
    spin(fc)
    hide_after(fc, int(frame_at(y)))

# Traffic: same-direction vehicles in lane 2 are overtaken by the player;
# oncoming vehicles in lanes 0 and 1 rush past.
current[0] = col("Traffic")
n = 0
for i, wd in enumerate(WORLDS):
    kinds = [k for k, wgt in wd["traffic"].items() for _ in range(wgt)]
    for j in range(5):
        n += 1
        kind = random.choice(kinds)
        oncoming = j % 2 == 1
        lane = random.choice((0, 1)) if oncoming else 2
        # Place each vehicle so it meets the player inside this world.
        meet_y = i * SEG + 15 + j * 26 + random.uniform(-4, 4)
        meet_f = frame_at(meet_y)
        speed = random.uniform(9, 13) / FPS  # metres per frame
        v = vehicle(f"{kind.title()} {n}", kind, random.randrange(9), (lane_x(lane), meet_y, 0), oncoming)
        direction = -1 if oncoming else 1
        if not oncoming:
            # Keep same-direction traffic clear of the player's swerves.
            if any(abs(meet_y - d) < 30 for d in DODGES):
                v.location.x = lane_x(random.choice((0, 1)))
                v.rotation_euler.z = math.pi
                direction = -1
        start, end = 1, FRAMES
        v.location.y = meet_y + direction * speed * (start - meet_f)
        v.keyframe_insert("location", index=1, frame=start)
        v.location.y = meet_y + direction * speed * (end - meet_f)
        v.keyframe_insert("location", index=1, frame=end)

# A parked jeepney and a tricycle at the sari-sari store, for close-up viewing.
current[0] = col("Showcase")
showcase = [("jeepney", 1), ("tricycle", 0), ("bus", 1), ("truck", 2), ("taxi", 0), ("van", 3), ("suv", 4), ("car", 1)]
for k, (kind, var) in enumerate(showcase):
    vehicle(f"Showcase {kind}", kind, var, (ROAD_HALF + 30 + (k % 4) * 5, -40 - (k // 4) * 12, 0), oncoming=True)
motorcycle("Showcase Kamote 110", (ROAD_HALF + 30, -60, 0), "E53935", "FFFFFF", "6D3A3A", "FFFFFF")
motorcycle("Showcase Thunder", (ROAD_HALF + 33, -60, 0), "263238", "FF5252", "7A2E2E", "FF5252")
motorcycle("Showcase LTO", (ROAD_HALF + 36, -60, 0), "ECEFF1", "1565C0", "1565C0", "FFFFFF", officer=True)
current[0] = col("Showcase")
box("showroom floor", (ROAD_HALF + 37.5, -50, -0.04), (26, 30, 0.08), mat("ECEFF1", rough=0.3))
text("showroom title", "KAMOTE RIDER: HIGHWAY ESCAPE", (ROAD_HALF + 37.5, -35.5, 3), 1.2, mat("FF7043", emit=2))

# ------------------------------------------------------- cameras and lights

current[0] = col("Cameras and Lights")
sun_data = bpy.data.lights.new("Sun", "SUN")
sun_data.energy = 3.5
sun = _link(bpy.data.objects.new("Sun", sun_data))
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))

# Chase camera: follows the player's distance, not their lane, like the game.
rig = group("Chase Rig", (0, RIDE_START, 0))
rig.constraints.new("COPY_LOCATION").target = player
rig.constraints[-1].use_x = False
rig.constraints[-1].use_z = False
cam_data = bpy.data.cameras.new("Chase Camera")
cam_data.lens = 28
chase = _link(bpy.data.objects.new("Chase Camera", cam_data))
chase.parent = rig
chase.location = (lane_x(3) - 1.2, -8.5, 4.2)
chase.rotation_euler = (math.radians(74), 0, 0)
scene.camera = chase

over_data = bpy.data.cameras.new("Overview Camera")
over_data.lens = 24
over = _link(bpy.data.objects.new("Overview Camera", over_data))
over.location = (60, -60, 70)
target = group("Overview Target", (0, 200, 0))
tc = over.constraints.new("TRACK_TO")
tc.target = target
tc.track_axis = "TRACK_NEGATIVE_Z"
tc.up_axis = "UP_Y"

show_data = bpy.data.cameras.new("Showroom Camera")
show_data.lens = 35
show = _link(bpy.data.objects.new("Showroom Camera", show_data))
show.location = (ROAD_HALF + 37.5, -72, 6)
show.rotation_euler = (math.radians(78), 0, 0)

# Open the 3D view looking through the chase camera, with materials shown.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == "VIEW_3D":
            for space in area.spaces:
                if space.type == "VIEW_3D":
                    space.shading.type = "MATERIAL"
                    space.region_3d.view_perspective = "CAMERA"

scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=OUT, compress=True)
print("Saved", OUT, "objects:", len(bpy.data.objects))
