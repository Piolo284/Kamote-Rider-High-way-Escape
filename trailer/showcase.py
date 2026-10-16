"""Edit the recorded footage into the 4-minute gameplay showcase.

    flutter test trailer/capture/showcase_test.dart --timeout none   # 1. footage (~35 min)
    python trailer/narration.py                                      # 2. voice-over (needs internet)
    python trailer/showcase.py                                       # 3. edit + encode (~20 min)
    python trailer/showcase.py stills 12 60 130                      #    preview frames

Every gameplay and menu shot is real footage from the game. The editor adds
narration with burned-in subtitles, captions, transitions, a soundtrack from
the game's own audio, and a clearly labelled "coming soon" card for Ghost
Race (not in the game yet). Narration, captions and sound effects are timed
from events the game logged while recording, so they match the action.

Output: trailer/kamote_rider_showcase.mp4 — 1920x1080, 60 fps, H.264 High +
AAC-LC, yuv420p, faststart (plays in Windows Media Player, Movies & TV, VLC,
browsers and phones; under GitHub's 100 MB file limit).
"""
import json
import math
import os
import pathlib
import subprocess
import sys
import wave

import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
FRAMES = pathlib.Path(os.environ.get("TRAILER_FRAMES", ROOT / "build" / "trailer_frames"))
VOICE_DIR = ROOT / "build" / "showcase_voice"
AUDIO_DIR = ROOT / "assets" / "audio"
OUT = HERE / "kamote_rider_showcase.mp4"

sys.path.insert(0, str(HERE))
from narration import LINES  # noqa: E402

W, H, FPS, DUR, SR = 1920, 1080, 60, 240.0, 44100
FONT_BLACK = r"C:\Windows\Fonts\ariblk.ttf"
FONT_BOLD = r"C:\Windows\Fonts\arialbd.ttf"
YELLOW, WHITE, PURPLE, CYAN = (255, 196, 0), (255, 255, 255), (179, 136, 255), (128, 222, 234)
ORANGE, RED = (255, 145, 0), (255, 82, 82)


def ease(x):
    x = min(max(x, 0.0), 1.0)
    return 1 - (1 - x) ** 3


# ===================================================================== footage
SHOT_FPS = {"sc_garage": 30, "sc_collection": 30, "sc_bk_setup": 30, "sc_bk_turn": 30, "sc_bk_results": 30, "sc_leaderboard": 30}
_files, _events = {}, {}


def files(shot):
    if shot not in _files:
        _files[shot] = sorted((FRAMES / shot).glob("*.png"))
        if not _files[shot]:
            sys.exit(f"Missing footage {shot} in {FRAMES}; run trailer/capture/showcase_test.dart")
    return _files[shot]


def fps_of(shot):
    return SHOT_FPS.get(shot, 60)


def length(shot):
    return len(files(shot)) / fps_of(shot)


def events(shot):
    if shot not in _events:
        p = FRAMES / shot / "events.json"
        _events[shot] = json.loads(p.read_text()) if p.exists() else []
    return _events[shot]


def frame(shot, sec):
    fl = files(shot)
    i = min(max(int(round(sec * fps_of(shot))), 0), len(fl) - 1)
    img = Image.open(fl[i]).convert("RGB")
    return img


def state(shot, sec):
    ev = events(shot)
    if not ev:
        return None
    return ev[min(max(int(round(sec * fps_of(shot))), 0), len(ev) - 1)]


def first(shot, pred, after=0.0):
    """Time (s) of the first logged frame matching [pred] after [after]."""
    ev = events(shot)
    for i in range(1, len(ev)):
        t = i / fps_of(shot)
        if t >= after and pred(ev[i], ev[i - 1]):
            return t
    return None


# ------------------------------------------------------------------ anchors
def anchors():
    a = {}
    a["intro_chase"] = first("sc_intro", lambda s, p: s["chase"] and not p["chase"]) or 2.0
    a["chase_end"] = first("sc_run1", lambda s, p: p["chase"] and not s["chase"]) or 12.0
    a["dodge"] = first("sc_run1", lambda s, p: s["combo"] > p["combo"], after=a["chase_end"] + 1) or 16.0
    a["fuel_grab"] = first("sc_run1", lambda s, p: s["fuel"] > p["fuel"] + 0.04, after=36.2) or 44.0
    a["km1"] = first("sc_run1", lambda s, p: s["m"] >= 1000 > p["m"]) or 50.0
    a["km2"] = first("sc_run2", lambda s, p: s["m"] >= 2000 > p["m"]) or 2.0
    a["fall"] = first("sc_tunnel", lambda s, p: s["ug"] == "falling" and p["ug"] != "falling") or 2.0
    a["inside"] = first("sc_tunnel", lambda s, p: s["ug"] == "inside" and p["ug"] != "inside") or a["fall"] + 0.9
    a["train"] = first("sc_tunnel", lambda s, p: s["lrtNear"] and not p["lrtNear"], after=a["inside"]) or a["inside"] + 8
    a["emerge"] = first("sc_tunnel", lambda s, p: s["ug"] == "emerging" and p["ug"] != "emerging") or a["inside"] + 21
    a["crash"] = first("sc_crash", lambda s, p: s["phase"] != "playing" and p["phase"] == "playing") or 1.0
    return a


A = None

# ===================================================================== timeline
# Each segment maps a span of the final video to footage.
#   kind "wide": full-screen gameplay, "phone": menu in a phone frame,
#   "freeze": held frame with a push-in, "card": designed title/concept card.
SEGS = []


def seg(start, end, kind, shot=None, src=0.0, speed=1.0, **kw):
    SEGS.append(dict(start=start, end=end, kind=kind, shot=shot, src=src, speed=speed, **kw))


CAPTIONS = []  # (text, start, end, colour, where)
TAGS = []  # (text, start, end, colour)
VO = []  # (line id, start)
FLASHES = []
MENU_SFX = []  # (time, name, volume)


def build_timeline():
    global A
    A = anchors()
    a = A
    # ---- Scene 1: introduction (0–25) ---------------------------------
    cs = a["intro_chase"]
    real = min(length("sc_intro") - cs - 0.05, 10.0)
    freeze = 1.4
    slow_start = 1.6
    slow_end = 20.0 - real - freeze
    seg(slow_start, slow_end, "wide", "sc_intro", 0.0, cs / (slow_end - slow_start))
    seg(slow_end, slow_end + freeze, "freeze", "sc_intro", cs, zoom=1.12)
    seg(slow_end + freeze, 20.0, "wide", "sc_intro", cs, 1.0)
    seg(20.0, 25.0, "card", card="title_intro")
    FLASHES.extend([slow_end, slow_end + freeze, 20.0, 25.0])
    CAPTIONS.extend([
        ("ONE RIDER.", slow_end - 0.2, 19.8, WHITE, "left"),
        ("ONE CRAZY ESCAPE.", slow_end + 1.4, 19.8, YELLOW, "left2"),
        ("HOW FAR CAN YOU GO?", slow_end + 3.6, 19.8, WHITE, "left3"),
    ])
    VO.extend([("intro1", 1.8), ("intro2", 11.6)])

    # ---- Scene 2: the chase (25–55) -------------------------------------
    seg(25.0, 55.0, "wide", "sc_run1", 0.0)
    dodge_t = 25.0 + a["dodge"]
    CAPTIONS.extend([
        ("CHASE MODE: ON!", 26.2, 31.5, RED, "left"),
        ("DODGE THE TRAFFIC!", max(36.0, min(dodge_t, 46)), max(36.0, min(dodge_t, 46)) + 4.5, YELLOW, "left"),
        ("STAY ON THE ROAD!", 48.0, 53.5, WHITE, "left"),
    ])
    VO.extend([("chase1", 25.8), ("chase2", max(35.0, min(dodge_t - 0.3, 45.0)))])

    # ---- Scene 3: fuel, money, survival (55–85) -------------------------
    s3_src = 30.0
    seg(55.0, 85.0, "wide", "sc_run1", s3_src)
    grab_t = 55.0 + (a["fuel_grab"] - s3_src)
    CAPTIONS.extend([
        ("COLLECT CASH!", 55.8, 60.6, (105, 240, 174), "left"),
        ("REFUEL TO SURVIVE!", grab_t - 2.2, grab_t + 3.0, YELLOW, "left"),
        ("ONE MISTAKE CAN END THE RUN!", 78.5, 84.5, RED, "left"),
    ])
    VO.extend([("fuel1", 55.4), ("fuel2", grab_t + 0.1), ("fuel3", grab_t + 6.0)])
    globals()["FUEL_FLASH"] = grab_t

    # ---- Scene 4: new worlds (85–110) -----------------------------------
    # The 1 km crossing already happened in scene 3; here the 2 km one.
    r2 = min(9.0, length("sc_run2"))
    seg(85.0, 85.0 + r2, "wide", "sc_run2", 0.0)
    seg(85.0 + r2, 110.0, "wide", "sc_run3", 0.0)
    FLASHES.append(85.0 + r2)
    CAPTIONS.extend([
        ("EVERY 1 KM: A NEW WORLD!", 85.4 + max(0.0, a["km2"] - 2.0), 91.4 + max(0.0, a["km2"] - 2.0), (66, 165, 245), "left"),
        ("NEW ROADS. NEW HAZARDS.", 96.5, 101.8, YELLOW, "left"),
        ("CAN YOU KEEP UP?", 104.0, 109.5, WHITE, "left"),
    ])
    VO.extend([("world1", 85.4), ("world2", 99.0)])

    # ---- Scene 5: underground (110–145) ---------------------------------
    pre = 3.2  # seconds of approach before the fall
    spot = max(0.0, a["fall"] - pre)
    seg(110.0, 111.8, "freeze", "sc_tunnel", spot, zoom=1.18, focus=(0.5, 0.62))
    t0 = 111.8
    seg(t0, t0 + pre, "wide", "sc_tunnel", spot)
    t1 = t0 + pre
    fall_slow = 1.6
    seg(t1, t1 + fall_slow, "wide", "sc_tunnel", a["fall"], speed=0.5)
    t2 = t1 + fall_slow
    rest = length("sc_tunnel") - (a["fall"] + 0.8)
    end5 = min(145.0, t2 + rest)
    seg(t2, end5, "wide", "sc_tunnel", a["fall"] + 0.8)
    if end5 < 145.0:
        seg(end5, 145.0, "wide", "sc_run3", 25.0 + (end5 - 145.0))
        FLASHES.append(end5)
    base = t2 - (a["fall"] + 0.8)
    inside_t, train_t, emerge_t = base + a["inside"], base + a["train"], base + a["emerge"]
    FLASHES.extend([110.0, t0])
    CAPTIONS.extend([
        ("MANHOLE DETECTED!", 110.1, 113.6, PURPLE, "left"),
        ("UNDERGROUND MODE ACTIVATED!", inside_t + 0.6, inside_t + 4.6, PURPLE, "left"),
        ("SURVIVE FOR 20 SECONDS!", inside_t + 4.8, inside_t + 8.6, WHITE, "left"),
        ("AVOID THE TRAIN!", train_t - 0.2, train_t + 3.6, YELLOW, "left"),
        ("BACK TO THE HIGHWAY!", emerge_t + 0.2, min(emerge_t + 4.2, 144.8), (105, 240, 174), "left"),
    ])
    VO.extend([("tunnel1", t1 - 0.4), ("tunnel2", inside_t + 0.5), ("tunnel3", max(train_t - 0.3, inside_t + 9.2)), ("tunnel4", emerge_t + 0.4)])
    globals()["TUNNEL"] = (t1, inside_t, train_t, emerge_t)

    # ---- Scene 6: garage (145–170) --------------------------------------
    g_len, c_len = length("sc_garage"), length("sc_collection")
    g_speed = g_len / (25.0 - 1.0 - c_len)
    seg(145.0, 145.0 + g_len / g_speed, "phone", "sc_garage", 0.0, g_speed, side="garage")
    seg(SEGS[-1]["end"], 170.0, "phone", "sc_collection", 0.0, c_len / (170.0 - SEGS[-1]["end"]), side="garage")
    unlock_t = 145.0 + (1.2 + 3.2 + 1.0) / g_speed
    CAPTIONS.extend([
        ("15 MOTORCYCLES TO COLLECT!", 145.4, 151.5, YELLOW, "right"),
        ("EARN CASH. UNLOCK RIDES.", unlock_t - 0.6, unlock_t + 4.6, WHITE, "right"),
        ("CHOOSE YOUR NEXT ESCAPE MACHINE!", 162.4, 169.6, YELLOW, "right"),
    ])
    VO.extend([("garage1", 145.3), ("garage2", 153.0)])
    for i in range(4):
        MENU_SFX.append((145.0 + (1.2 + 0.8 * i) / g_speed, "sfx_whoosh", 0.3))
    MENU_SFX.extend([(unlock_t - 1.0 / g_speed, "sfx_click", 0.5), (unlock_t, "sfx_click", 0.5), (unlock_t + 0.05, "sfx_unlock", 0.8)])
    for i in range(10):
        MENU_SFX.append((145.0 + (1.2 + 3.2 + 1.0 + 2.6 + 0.8 + 0.6 * i) / g_speed, "sfx_whoosh", 0.22))

    # ---- Scene 7: leaderboard, Barkada Race, Ghost Race (170–205) ----------
    t = 170.0
    for shot, side in (("sc_leaderboard", "board"), ("sc_bk_setup", "barkada"), ("sc_bk_turn", "barkada"), ("sc_bk_results", "barkada")):
        seg(t, t + length(shot), "phone", shot, 0.0, side=side)
        t += length(shot)
    seg(t, 205.0, "card", card="ghost")
    ghost_t = t
    FLASHES.append(ghost_t)
    CAPTIONS.extend([
        ("CLIMB THE LEADERBOARD!", 170.4, 176.6, YELLOW, "right"),
        ("CHALLENGE YOUR FRIENDS!", 177.8, ghost_t - 0.4, (124, 77, 255), "right"),
        ("YOUR NEXT RECORD STARTS NOW!", 201.0, 204.8, YELLOW, "card"),
    ])
    TAGS.extend([
        ("ON-DEVICE LEADERBOARD", 170.4, 177.4, (245, 124, 0)),
        ("BARKADA RACE · REAL RUNS ON ONE PHONE", 177.6, ghost_t - 0.2, (124, 77, 255)),
    ])
    VO.extend([("versus1", 170.3), ("versus2", 175.6), ("versus3", ghost_t + 0.6)])
    MENU_SFX.extend([(173.0, "sfx_click", 0.4), (175.2, "sfx_click", 0.4), (178.4, "sfx_click", 0.4), (179.0, "sfx_click", 0.4)])
    globals()["GHOST_T"] = ghost_t

    # ---- Scene 8: final gameplay montage (205–225) ------------------------
    beats = [
        ("sc_run1", a["dodge"] - 1.2),          # last-second lane change
        ("sc_run1", 22.0),                      # paper money
        ("sc_run1", a["fuel_grab"] - 1.6),      # fuel while low
        ("sc_run2", max(0.0, a["km2"] - 0.6)),  # new world
        ("sc_tunnel", a["fall"] - 1.0),         # manhole
        ("sc_tunnel", a["train"] + 0.4),        # train
        ("sc_tunnel", a["emerge"] - 0.2),       # back on the highway
        ("sc_run1", 50.0),                      # keep riding
    ]
    t = 205.0
    for i, (shot, src) in enumerate(beats):
        d = 2.5
        seg(t, t + d, "wide", shot, max(0.0, src), speed=1.0 if i < 7 else 1.15)
        FLASHES.append(t)
        t += d
    CAPTIONS.extend([
        ("NO BRAKES. NO EASY WAY OUT.", 205.4, 211.6, WHITE, "left"),
        ("BEAT YOUR BEST!", 212.6, 217.6, YELLOW, "left"),
        ("HOW FAR CAN YOU GO?", 218.6, 224.6, WHITE, "left"),
    ])
    VO.extend([("final1", 205.2), ("final2", 215.6)])

    # ---- Scene 9: game over and title (225–240) ---------------------------
    c_len = length("sc_crash")
    start_src = max(0.0, a["crash"] - 1.6)
    over_end = 225.0 + (c_len - start_src)
    seg(225.0, over_end, "wide", "sc_crash", start_src)
    seg(over_end, over_end + 0.7, "freeze", "sc_crash", c_len - 0.05, zoom=1.04)
    seg(over_end + 0.7, 240.0, "card", card="title_end")
    FLASHES.extend([225.0, over_end + 0.7])
    VO.extend([("end1", 224.8), ("end2", over_end + 0.6)])
    globals()["CRASH_T"] = 225.0 + (a["crash"] - start_src)
    globals()["END_CARD"] = over_end + 0.7

    # A caption ends early when the next one in the same spot begins.
    CAPTIONS.sort(key=lambda c: c[1])
    for i, (text, start, end, color, where) in enumerate(CAPTIONS):
        for later in CAPTIONS[i + 1:]:
            if later[4] == where and start < later[1] < end:
                CAPTIONS[i] = (text, start, later[1] - 0.05, color, where)
                break


def seg_at(t):
    for s in SEGS:
        if s["start"] <= t < s["end"]:
            return s
    return SEGS[-1]


def src_time(s, t):
    return s["src"] + (t - s["start"]) * s["speed"]


# ===================================================================== drawing
_fonts = {}


def font(path, size):
    if (path, size) not in _fonts:
        _fonts[(path, size)] = ImageFont.truetype(path, size)
    return _fonts[(path, size)]


def text_img(text, size, color, stroke=8, path=FONT_BLACK, shadow=True):
    f = font(path, size)
    b = f.getbbox(text, stroke_width=stroke)
    img = Image.new("RGBA", (b[2] - b[0] + 24, b[3] - b[1] + 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x, y = 12 - b[0], 12 - b[1]
    if shadow:
        d.text((x + 5, y + 6), text, font=f, fill=(0, 0, 0, 140), stroke_width=stroke, stroke_fill=(0, 0, 0, 140))
    d.text((x, y), text, font=f, fill=color, stroke_width=stroke, stroke_fill=(12, 12, 18))
    return img


def paste(base, layer, x, y, alpha=1.0, scale=1.0, anchor="c"):
    if alpha <= 0.01:
        return
    if abs(scale - 1) > 0.005:
        layer = layer.resize((max(1, int(layer.width * scale)), max(1, int(layer.height * scale))), Image.LANCZOS)
    if alpha < 0.999:
        layer = layer.copy()
        layer.putalpha(layer.getchannel("A").point(lambda v: int(v * alpha)))
    if anchor == "c":
        pos = (int(x - layer.width / 2), int(y - layer.height / 2))
    elif anchor == "l":
        pos = (int(x), int(y - layer.height / 2))
    else:
        pos = (int(x - layer.width), int(y - layer.height / 2))
    base.alpha_composite(layer, pos)


_cap_cache = {}


def draw_captions(img, t):
    for text, start, end, color, where in CAPTIONS:
        if not (start <= t < end):
            continue
        k_in = (t - start) / 0.25
        out = 1 - ease((t - (end - 0.3)) / 0.3)
        a = min(ease(k_in * 1.3), out)
        scale = 1 + 0.4 * (1 - ease(k_in))
        key = (text, color)
        if key not in _cap_cache:
            size = 78 if len(text) <= 22 else 64
            _cap_cache[key] = text_img(text, size, color, stroke=8)
        layer = _cap_cache[key]
        if where.startswith("left"):
            row = {"left": 0, "left2": 1, "left3": 2}[where]
            slide = (1 - ease(k_in)) * -80
            paste(img, layer, 60 + slide, 470 + row * 105, a, scale, anchor="l")
        elif where == "right":
            # Side panel next to the phone: left-aligned, shrunk to fit.
            fit = min(1.0, (W - 840 - 60) / layer.width)
            paste(img, layer, 830 + (1 - ease(k_in)) * 60, 450, a, scale * fit, anchor="l")
        else:  # card
            paste(img, layer, W / 2, 930, a, scale)


_tag_cache = {}


def draw_tags(img, t):
    for text, start, end, color in TAGS:
        if not (start <= t < end):
            continue
        a = min(ease((t - start) / 0.25), 1 - ease((t - (end - 0.25)) / 0.25))
        if text not in _tag_cache:
            f = font(FONT_BLACK, 34)
            b = f.getbbox(text)
            pill = Image.new("RGBA", (b[2] - b[0] + 56, 70), (0, 0, 0, 0))
            d = ImageDraw.Draw(pill)
            d.rounded_rectangle((0, 0, pill.width - 1, 69), radius=35, fill=(*color, 235))
            d.text((28 - b[0], 35 - (b[1] + b[3]) / 2), text, font=f, fill=WHITE)
            _tag_cache[text] = pill
        paste(img, _tag_cache[text], 840, 330, a, anchor="l")


# ------------------------------------------------------------- subtitles
VO_TIMES = {}  # id -> (start, end) after fitting


def subtitle_chunks(text, start, end):
    """Splits a line into readable chunks timed by their share of characters."""
    words = text.split()
    chunks, cur = [], ""
    for w in words:
        if len(cur) + len(w) + 1 > 52 and cur:
            chunks.append(cur)
            cur = w
        else:
            cur = f"{cur} {w}".strip()
    chunks.append(cur)
    # Two short pieces can share one subtitle.
    merged = []
    for c in chunks:
        if merged and len(merged[-1]) + len(c) < 50:
            merged[-1] += " " + c
        else:
            merged.append(c)
    total = sum(len(c) for c in merged)
    out, t = [], start
    for c in merged:
        d = (end - start) * len(c) / total
        out.append((c, t, t + d))
        t += d
    return out


SUBS = []
_sub_cache = {}


def draw_subtitles(img, t):
    for text, start, end in SUBS:
        if start <= t < end + 0.05:
            if text not in _sub_cache:
                f = font(FONT_BOLD, 40)
                b = f.getbbox(text)
                box = Image.new("RGBA", (b[2] - b[0] + 48, 64), (0, 0, 0, 0))
                d = ImageDraw.Draw(box)
                d.rounded_rectangle((0, 0, box.width - 1, 63), radius=14, fill=(0, 0, 0, 170))
                d.text((24 - b[0], 32 - (b[1] + b[3]) / 2), text, font=f, fill=WHITE)
                _sub_cache[text] = box
            paste(img, _sub_cache[text], W / 2, H - 70)
            return


# ----------------------------------------------------------------- phone frame
_bg_cache = {}


def menu_background(t, side):
    key = side
    if key not in _bg_cache:
        bg = Image.new("RGB", (W, H), (14, 17, 28))
        d = ImageDraw.Draw(bg)
        for y in range(H):
            c = int(14 + 18 * y / H)
            d.line((0, y, W, y), fill=(c, c + 3, c + 18))
        _bg_cache[key] = bg.convert("RGBA")
    img = _bg_cache[key].copy()
    # Moving diagonal road stripes for energy.
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    off = (t * 240) % 220
    for i in range(-4, 16):
        x = i * 220 + off
        d.polygon([(x, H), (x + 70, H), (x + 70 + 600, 0), (x + 600, 0)], fill=(255, 196, 0, 12))
    img.alpha_composite(layer)
    return img


SIDE_TEXT = {
    "garage": ("IMPOUND GARAGE", ["15 motorcycles, 5 tiers", "Earn pesos on every run", "Speed · handling · fuel stats", "Unlock and ride instantly"]),
    "board": ("LEADERBOARD", ["Every run saved on the device", "Sort by score or distance", "Best run per rider", "Top scorer gets the crown"]),
    "barkada": ("BARKADA RACE", ["2–4 friends, one phone", "Same seeded highway for all", "One run each, no restarts", "Results podium + leaderboard"]),
}
_side_cache = {}
_phone_mask = None


def phone_frame(shot, sec):
    global _phone_mask
    ph_h = 990
    ph_w = int(ph_h * 1080 / 1920)
    screen = frame(shot, sec).crop((0, 0, 1080, 1920)).resize((ph_w, ph_h), Image.BICUBIC).convert("RGBA")
    if _phone_mask is None:
        _phone_mask = Image.new("L", (ph_w, ph_h), 0)
        ImageDraw.Draw(_phone_mask).rounded_rectangle((0, 0, ph_w - 1, ph_h - 1), radius=38, fill=255)
    body = Image.new("RGBA", (ph_w + 36, ph_h + 36), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle((0, 0, body.width - 1, body.height - 1), radius=56, fill=(20, 22, 28, 255), outline=(90, 96, 110, 255), width=4)
    body.paste(screen, (18, 18), _phone_mask)
    return body


def render_phone(s, t):
    img = menu_background(t, s["side"])
    body = phone_frame(s["shot"], src_time(s, t))
    img.alpha_composite(body, (150, (H - body.height) // 2 - 10))
    title, bullets = SIDE_TEXT[s["side"]]
    if s["side"] not in _side_cache:
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        title_img = text_img(title, 74, YELLOW, stroke=6)
        layer.alpha_composite(title_img, (840, 150))
        f = font(FONT_BOLD, 44)
        d = ImageDraw.Draw(layer)
        for i, b in enumerate(bullets):
            y = 560 + i * 78
            d.ellipse((850, y + 8, 878, y + 36), fill=(*YELLOW, 255))
            d.text((900, y), b, font=f, fill=(225, 230, 240))
        _side_cache[s["side"]] = layer
    seg_start = min(x["start"] for x in SEGS if x.get("side") == s["side"])
    a = ease((t - seg_start) / 0.4)
    paste(img, _side_cache[s["side"]], W / 2, H / 2, a)
    return img


# ----------------------------------------------------------------- cards
_card_bg = {}


def blurred(shot, sec, dark=0.35):
    key = (shot, round(sec, 2), dark)
    if key not in _card_bg:
        f = frame(shot, sec).filter(ImageFilter.GaussianBlur(14))
        _card_bg[key] = ImageEnhance.Brightness(f).enhance(dark).convert("RGBA")
    return _card_bg[key].copy()


def streaks(img, t, seed=3, color=(255, 225, 150)):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    rnd = np.random.default_rng(seed)
    for _ in range(30):
        y = rnd.uniform(0, H)
        x0 = (rnd.uniform(0, W) - t * rnd.uniform(1600, 2800)) % (W + 600) - 300
        ln = rnd.uniform(160, 420)
        d.line((x0, y, x0 + ln, y), fill=(*color, int(rnd.uniform(16, 46))), width=3)
    img.alpha_composite(layer)


def logo(img, k, y=420):
    slam = ease(k / 0.28)
    shake = (1 - ease(k / 0.6)) * 12 * math.sin(k * 70) if k > 0.28 else 0
    paste(img, text_img("KAMOTE RIDER", 150, YELLOW, stroke=10), W / 2 + shake, y, slam, 1 + 1.1 * (1 - slam))
    if k > 0.3:
        kk = ease((k - 0.3) / 0.25)
        paste(img, text_img("HIGHWAY ESCAPE", 92, WHITE, stroke=8), W / 2, y + 150, kk, 1 + 0.5 * (1 - kk))


def render_card(s, t):
    k = t - s["start"]
    if s["card"] == "title_intro":
        img = blurred("sc_intro", length("sc_intro") - 0.1)
        streaks(img, t)
        logo(img, k, 470)
        return img
    if s["card"] == "title_end":
        img = blurred("sc_run1", 55.0, 0.3)
        streaks(img, t)
        logo(img, k, 400)
        if k > 1.0:
            paste(img, text_img("THE ROAD NEVER ENDS. YOUR NEXT RUN STARTS NOW.", 46, WHITE, stroke=5), W / 2, 700, ease((k - 1.0) / 0.4))
        if k > 1.8:
            paste(img, text_img("PLAY. SURVIVE. REPEAT.", 58, YELLOW, stroke=6), W / 2, 800, ease((k - 1.8) / 0.4))
        if k > 2.6:
            paste(img, text_img("A fictional arcade game. Ride safe in real life!", 30, (170, 178, 196), stroke=0, path=FONT_BOLD, shadow=False), W / 2, 905, ease((k - 2.6) / 0.4))
        return img
    # Ghost Race: clearly labelled concept, built from a real frame.
    src_t = A["dodge"] + 1.0
    img = ImageEnhance.Brightness(frame("sc_run1", src_t + k * 0.6)).enhance(0.72).convert("RGBA")
    # Mock-up ghost: a cyan, see-through copy of the rider in the next lane.
    ghost = frame("sc_run1", src_t + k * 0.6).crop((800, 700, 1120, 1080)).convert("RGBA")
    ghost = Image.blend(ImageEnhance.Color(ghost).enhance(0.0), Image.new("RGBA", ghost.size, (*CYAN, 255)), 0.5)
    mask = Image.new("L", ghost.size, 0)
    ImageDraw.Draw(mask).ellipse((70, 30, ghost.width - 70, ghost.height - 10), fill=150)
    ghost.putalpha(mask.filter(ImageFilter.GaussianBlur(28)))
    img.alpha_composite(ghost, (1150, 640))
    panel = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(panel)
    d.rounded_rectangle((50, 300, 900, 870), radius=30, fill=(10, 14, 26, 215), outline=(*CYAN, 255), width=4)
    panel.alpha_composite(text_img("GHOST RACE", 92, CYAN, stroke=7), (90, 330))
    badge = text_img("COMING SOON · CONCEPT PREVIEW", 34, WHITE, stroke=0, path=FONT_BLACK, shadow=False)
    d.rounded_rectangle((90, 470, 90 + badge.width + 20, 470 + badge.height + 10), radius=18, fill=(229, 57, 53, 255))
    panel.alpha_composite(badge, (100, 475))
    f = font(FONT_BOLD, 40)
    for i, line in enumerate(["Record your best run", "Share it with a challenge code", "Race a friend's ghost on the same highway", "Compare distance and score at the finish"]):
        d.text((110, 570 + i * 64), "•  " + line, font=f, fill=(225, 232, 242))
    d.text((110, 830), "Not in the game yet. Ghost rider shown is a mock-up.", font=font(FONT_BOLD, 28), fill=(160, 170, 190))
    img.alpha_composite(panel)
    label = text_img("GHOST (MOCK-UP)", 30, CYAN, stroke=4)
    paste(img, label, 1310, 640, ease(k / 0.5))
    return img


# ----------------------------------------------------------------- frame
def render_frame(t):
    s = seg_at(t)
    kind = s["kind"]
    if kind == "card":
        img = render_card(s, t)
    elif kind == "phone":
        img = render_phone(s, t)
    else:
        sec = s["src"] if kind == "freeze" else src_time(s, t)
        img = frame(s["shot"], sec).convert("RGBA")
        if kind == "freeze":
            k = ease((t - s["start"]) / (s["end"] - s["start"]))
            z = 1 + (s.get("zoom", 1.1) - 1) * k
            fx, fy = s.get("focus", (0.5, 0.7))
            cw, ch = W / z, H / z
            box = (fx * W - cw * fx, fy * H - ch * fy, fx * W - cw * fx + cw, fy * H - ch * fy + ch)
            img = img.resize((W, H), Image.BICUBIC, box=box)
            # Freeze-frame look: slight desaturation and a light vignette band.
            img = Image.blend(img, ImageEnhance.Color(img).enhance(0.25), 0.5)
        if globals().get("FUEL_FLASH") and 0 <= t - FUEL_FLASH < 1.4:
            k = t - FUEL_FLASH
            ring = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            a = int(255 * (1 - k / 1.4) * (0.6 + 0.4 * math.sin(k * 20)))
            ImageDraw.Draw(ring).rounded_rectangle((12, 10, 1520, 74), radius=30, outline=(255, 235, 59, max(a, 0)), width=8)
            img.alpha_composite(ring)
    draw_tags(img, t)
    draw_captions(img, t)
    draw_subtitles(img, t)

    flash = 0.0
    for c in FLASHES:
        d = t - c
        if 0 <= d < 0.2:
            flash = max(flash, 0.55 * (1 - d / 0.2))
    if flash > 0.01:
        img = Image.blend(img, Image.new("RGBA", (W, H), (255, 255, 255, 255)), flash)
    black = 0.0
    if t < 1.6:
        black = 1.0 if t < 0.9 else 1 - (t - 0.9) / 0.7
    if t > DUR - 1.2:
        black = (t - (DUR - 1.2)) / 1.2
    if black > 0.01:
        img = Image.blend(img, Image.new("RGBA", (W, H), (0, 0, 0, 255)), min(black, 1.0))
    return img.convert("RGB")


# ===================================================================== audio
def load(name, folder=AUDIO_DIR):
    with wave.open(str(folder / f"{name}.wav")) as w:
        sr, n, ch = w.getframerate(), w.getnframes(), w.getnchannels()
        data = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float32) / 32768
    if ch == 2:
        data = data.reshape(-1, 2).mean(axis=1)
    if sr != SR:
        data = np.interp(np.arange(int(len(data) * SR / sr)) / SR, np.arange(len(data)) / sr, data).astype(np.float32)
    return data


def add(buf, t, clip, vol=1.0):
    i = int(round(t * SR))
    if i >= len(buf) or i + len(clip) <= 0:
        return
    j = min(len(buf), i + len(clip))
    buf[max(i, 0):j] += clip[max(0, -i): j - i] * vol


RNG = np.random.default_rng(7)


def env_exp(n, decay):
    return np.exp(-np.arange(n) / SR / decay).astype(np.float32)


def kick():
    n = int(0.32 * SR)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * np.cumsum(45 + 95 * np.exp(-t / 0.035)) / SR) * np.exp(-t / 0.16) + RNG.standard_normal(n) * np.exp(-t / 0.004) * 0.3).astype(np.float32)


def snare():
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    return (np.diff(RNG.standard_normal(n), prepend=0) * 0.35 * np.exp(-t / 0.08) + np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.05) * 0.6).astype(np.float32)


def hat():
    n = int(0.05 * SR)
    return (np.diff(RNG.standard_normal(n), prepend=0) * env_exp(n, 0.012) * 0.5).astype(np.float32)


def crash():
    n = int(1.6 * SR)
    return (np.diff(RNG.standard_normal(n), prepend=0) * env_exp(n, 0.45) * 0.45).astype(np.float32)


def boom():
    n = int(1.1 * SR)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * np.cumsum(32 + 40 * np.exp(-t / 0.12)) / SR) * np.exp(-t / 0.4) + RNG.standard_normal(n) * np.exp(-t / 0.02) * 0.5).astype(np.float32)


def riser(dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    k = t / dur
    tone = np.sign(np.sin(2 * np.pi * np.cumsum(220 + 1400 * k ** 2) / SR)) * 0.12
    return ((np.diff(RNG.standard_normal(n), prepend=0) * 0.35 + tone) * k ** 2.2).astype(np.float32)


def lowpass(x, cutoff):
    spec = np.fft.rfft(x)
    spec *= 1 / (1 + (np.fft.rfftfreq(len(x), 1 / SR) / cutoff) ** 4)
    return np.fft.irfft(spec, len(x)).astype(np.float32)


def echo(x, delay=0.21, feedback=0.42, taps=5):
    d = int(delay * SR)
    y = np.concatenate([x, np.zeros(d * taps, np.float32)])
    for k in range(1, taps + 1):
        y[d * k: d * k + len(x)] += x * feedback ** k
    return y


def rumble(dur):
    n = int(dur * SR)
    r = lowpass(RNG.standard_normal(n).astype(np.float32), 90) * 3.0
    clack = np.zeros(n, np.float32)
    for c in np.arange(0.1, dur, 0.36):
        add(clack, c, hat() * 1.6)
    return r + lowpass(clack, 2500)


def horn(dur=1.2):
    n = int(dur * SR)
    t = np.arange(n) / SR
    tone = sum(np.sign(np.sin(2 * np.pi * f * t)) for f in (311, 392)) * 0.08
    return lowpass((tone * np.minimum(1, t / 0.05) * np.minimum(1, (dur - t) / 0.15)).astype(np.float32), 1800)


def rev(dur=1.6):
    """Engine start and rev made from the game's engine loop."""
    eng = load("loop_engine")
    n = int(dur * SR)
    t = np.arange(n) / SR
    pitch = 0.6 + 1.4 * np.clip(t / (dur * 0.55), 0, 1) ** 1.5 - 0.5 * np.clip((t - dur * 0.6) / (dur * 0.4), 0, 1)
    idx = (np.cumsum(pitch) % len(eng)).astype(int)
    return (eng[idx] * np.minimum(1, t / 0.08) * np.minimum(1, (dur - t) / 0.3) * 1.6).astype(np.float32)


def trim_silence(x, thresh=0.01):
    loud = np.where(np.abs(x) > thresh)[0]
    if len(loud) == 0:
        return x
    return x[max(0, loud[0] - int(0.02 * SR)): loud[-1] + int(0.12 * SR)]


def place_voice():
    """Loads voice clips and resolves overlaps (each line waits for the last)."""
    clips, last_end = {}, 0.0
    ordered = sorted(VO, key=lambda v: v[1])
    for i, (key, want) in enumerate(ordered):
        clip = trim_silence(load(key, VOICE_DIR))
        start = max(want, last_end + 0.25)
        nxt = ordered[i + 1][1] if i + 1 < len(ordered) else DUR - 0.4
        room = max(nxt, start + 0.5) - start
        dur = len(clip) / SR
        if dur > room and key in ("end2",):
            # Squeeze the last line slightly so it finishes before the fade.
            room = DUR - 0.5 - start
        if dur > room:
            factor = min(1.18, dur / room)
            clip = np.interp(np.arange(0, len(clip), factor), np.arange(len(clip)), clip).astype(np.float32)
            dur = len(clip) / SR
        clips[key] = (start, clip)
        VO_TIMES[key] = (start, start + dur)
        last_end = start + dur
        SUBS.extend(subtitle_chunks(LINES[key], start, start + dur))
    return clips


def build_audio():
    n = int(DUR * SR)
    tt = np.arange(n) / SR
    music, drums, sfx, voice = (np.zeros(n, np.float32) for _ in range(4))
    ride, menu = load("music_ride"), load("music_menu")

    def loop_into(buf, clip, a, b, vol=1.0):
        t = a
        while t < b:
            add(buf, t, clip[: int(min(len(clip), (b - t) * SR))], vol)
            t += len(clip) / SR

    t1, inside_t, train_t, emerge_t = TUNNEL
    loop_into(music, ride, 2.0, 20.0, 0.55)
    loop_into(music, ride, 25.0, t1 - 0.2, 1.0)
    loop_into(music, ride, t1 + 1.0, emerge_t, 0.9)
    loop_into(music, ride, emerge_t, 145.0, 1.0)
    loop_into(music, menu, 145.0, 170.0, 0.9)
    loop_into(music, ride, 170.0, CRASH_T, 1.0)
    loop_into(music, menu, END_CARD - 0.2, DUR, 0.8)
    # Intro: muffled build.
    a, b = int(2.0 * SR), int(20.0 * SR)
    music[a:b] = lowpass(music[a:b], 900) * np.linspace(0.5, 1.0, b - a, dtype=np.float32)
    # Tunnel: dark and echoing.
    a, b = int((t1 + 1.0) * SR), int(emerge_t * SR)
    music[a:b] = echo(lowpass(music[a:b], 450) * 1.3)[: b - a]
    # Fades at section edges.
    for edge in (20.0, 145.0, 170.0, CRASH_T):
        i = int(edge * SR)
        w = int(0.25 * SR)
        music[i - w:i] *= np.linspace(1, 0, w, dtype=np.float32)

    K, S, Hh = kick(), snare(), hat()
    beat = 0.4
    for i in range(int((DUR - 25.0) / beat)):
        bt = 25.0 + i * beat
        if bt >= CRASH_T or 145.0 <= bt < 170.0 or t1 - 0.3 <= bt < t1 + 1.0:
            continue
        if t1 + 1.0 <= bt < emerge_t:
            if i % 2 == 0:
                add(drums, bt, K, 0.75)
            continue
        busy = bt >= 205.0
        add(drums, bt, K, 0.85)
        if i % 2 == 1:
            add(drums, bt, S, 0.42)
        add(drums, bt + beat / 2, Hh, 0.3)
        if busy:
            add(drums, bt + beat / 4, Hh, 0.2)
            add(drums, bt + 3 * beat / 4, Hh, 0.2)
    for c in (25.0, 55.0, 85.0, 95.0, emerge_t, 170.0, 205.0):
        add(drums, c, crash(), 0.7)
    for at, d in ((18.4, 1.6), (83.6, 1.4), (t1 - 1.2, 1.2), (emerge_t - 1.4, 1.4), (203.6, 1.4), (221.5, 2.8)):
        add(sfx, at, riser(d), 0.45)
    add(sfx, 20.0, boom(), 0.8)
    add(drums, 20.0, crash(), 0.9)
    add(sfx, 0.5, rev(1.9), 0.9)
    add(sfx, 24.4, rev(1.2), 0.7)
    add(sfx, END_CARD, boom(), 0.8)
    add(sfx, DUR - 3.2, rev(1.8), 0.7)

    # Gameplay sounds from the logged events.
    snd = {k: load(k) for k in ("sfx_cash", "sfx_fuel", "sfx_whistle", "sfx_kilometer", "sfx_whoosh", "sfx_crash", "sfx_game_over", "loop_engine", "loop_siren", "loop_ambulance")}
    last_cash, prev, prev_seg = -1.0, None, None
    for f in range(int(DUR * FPS)):
        t = f / FPS
        s = seg_at(t)
        if s["kind"] not in ("wide",) or not events(s["shot"]):
            prev = None
            continue
        st = state(s["shot"], src_time(s, t))
        if prev is not None and prev_seg is s:
            if st["cash"] > prev["cash"] and t - last_cash > 0.07:
                add(sfx, t, snd["sfx_cash"], 0.3)
                last_cash = t
            if st["fuel"] > prev["fuel"] + 0.04:
                add(sfx, t, snd["sfx_fuel"], 0.6)
            if st["chase"] and not prev["chase"]:
                add(sfx, t, snd["sfx_whistle"], 0.7)
            if st["combo"] > prev["combo"]:
                add(sfx, t, snd["sfx_whoosh"], 0.4)
            if st["lane"] != prev["lane"]:
                add(sfx, t, snd["sfx_whoosh"], 0.1)
            if st["world"] != prev["world"] and 5 not in (st["world"], prev["world"]):
                add(sfx, t, snd["sfx_kilometer"], 0.6)
            if st["ug"] == "falling" and prev["ug"] != "falling":
                add(sfx, t, snd["sfx_whoosh"], 0.8)
                add(sfx, t + 0.3, boom(), 0.5)
            if st["phase"] != "playing" and prev["phase"] == "playing":
                add(sfx, t, snd["sfx_crash"], 0.8)
            if st["phase"] == "gameOver" and prev["phase"] != "gameOver":
                add(sfx, t, snd["sfx_game_over"], 0.6)
        i0, i1 = int(t * SR), int((t + 1 / FPS) * SR)
        if st["phase"] == "playing":
            pitch = 0.8 + 0.4 * min(st["kmh"], 120) / 120
            k = (np.arange(i0, i1) * pitch % len(snd["loop_engine"])).astype(int)
            sfx[i0:i1] += snd["loop_engine"][k] * (0.12 if s["speed"] >= 0.9 else 0.07)
        if st["chase"]:
            sfx[i0:i1] += snd["loop_siren"][np.arange(i0, i1) % len(snd["loop_siren"])] * 0.12
        if st["phase"] == "ending":
            sfx[i0:i1] += snd["loop_ambulance"][np.arange(i0, i1) % len(snd["loop_ambulance"])] * 0.12
        prev, prev_seg = st, s
    add(sfx, inside_t, rumble(emerge_t - inside_t), 0.3)
    add(sfx, train_t - 0.6, echo(horn()), 0.5)
    for t, name, vol in MENU_SFX:
        add(sfx, t, load(name), vol)
    add(sfx, GHOST_T, load("sfx_whoosh"), 0.5)

    # Voice-over on top, with the music ducked underneath.
    for key, (start, clip) in place_voice().items():
        peak = np.max(np.abs(clip)) or 1
        add(voice, start, clip / peak * 0.9)
    active = np.zeros(n, np.float32)
    for start, end in VO_TIMES.values():
        active[int(start * SR):int(end * SR)] = 1
    k = int(0.25 * SR)
    duck = np.convolve(active, np.ones(k, np.float32) / k, mode="same")
    bed = (music * 0.5 + drums * 0.45) * (1 - 0.6 * duck) + sfx * (0.75 - 0.3 * duck)
    mix = bed + voice * 1.0
    mix *= np.clip((DUR - tt) / 1.2, 0, 1).astype(np.float32)
    mix = np.tanh(mix / np.max(np.abs(mix)) * 1.3) / np.tanh(1.3) * 0.92
    return (np.stack([mix, mix], axis=1) * 32767).astype(np.int16)


def write_wav(path, data):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# ===================================================================== main
def main():
    build_timeline()
    audio_path = FRAMES.parent / "showcase_audio.wav"
    print("mixing audio (places narration and subtitles)...")
    write_wav(audio_path, build_audio())
    if len(sys.argv) > 1 and sys.argv[1] == "stills":
        out = FRAMES.parent / "showcase_stills"
        out.mkdir(exist_ok=True)
        for s in sys.argv[2:]:
            render_frame(float(s)).save(out / f"sc_{float(s):06.1f}.png")
        print("anchors", {k: round(v, 2) for k, v in A.items()})
        return
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    cmd = [
        ffmpeg, "-y", "-loglevel", "error",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-i", str(audio_path), "-map", "0:v", "-map", "1:a",
        "-c:v", "libx264", "-preset", "medium", "-crf", "21", "-maxrate", "2800k", "-bufsize", "5600k",
        "-profile:v", "high", "-level", "4.2", "-pix_fmt", "yuv420p", "-g", "120",
        "-c:a", "aac", "-b:a", "160k", "-ar", str(SR),
        "-movflags", "+faststart", "-shortest", str(OUT),
    ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    total = int(DUR * FPS)
    for f in range(total):
        proc.stdin.write(render_frame(f / FPS).tobytes())
        if f % 600 == 0:
            print(f"frame {f}/{total}", flush=True)
    proc.stdin.close()
    if proc.wait() != 0:
        sys.exit("ffmpeg failed")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
