"""Edit the recorded game footage into the 90-second trailer MP4.

    flutter test trailer/capture/shots_test.dart   # 1. record footage (~9 min)
    python trailer/compose.py                      # 2. edit + encode (~3 min)
    python trailer/compose.py stills 5 44 86       #    preview frames as PNGs

Footage comes from the real game (trailer/capture/), so everything shown
is actual gameplay. Captions, cuts and the title card are added here, and
the soundtrack mixes the game's own music and sound effects, synced to the
game events logged while recording. Output: H.264 + AAC MP4 (yuv420p,
faststart), which plays in Windows Media Player, Movies & TV, VLC and phones.
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
AUDIO_DIR = ROOT / "assets" / "audio"
OUT = HERE / "kamote_rider_trailer_90s.mp4"

W, H, FPS, DUR = 1080, 1920, 30, 90.0
SR = 44100
FONT_BLACK = r"C:\Windows\Fonts\ariblk.ttf"
FONT_BOLD = r"C:\Windows\Fonts\arialbd.ttf"
YELLOW = (255, 196, 0)
WHITE = (255, 255, 255)
PURPLE = (179, 136, 255)

# ------------------------------------------------------------------ timeline
# (start, end, shot, first source frame); source frames advance 1:1.
CLIPS = [
    (0.0, 12.0, "s1_checkpoint", 0),
    (12.0, 27.0, "s2_highway", 0),
    (27.0, 31.4, "s3a_provincial", 0),
    (31.4, 35.6, "s3b_mountain", 0),
    (35.6, 40.0, "s3c_coastal_fuel", 24),
    (40.0, 40.0 + 106 / FPS, "s4a_fall", 0),
    (40.0 + 106 / FPS, 58.0 - 112 / FPS, "s4b_tunnel", 0),
    (58.0 - 112 / FPS, 58.0, "s4c_surface", 20),
    (58.0, 67.0, "s5_garage", 0),
    (67.0, 69.0, "s5_garage", -1),  # hold on the unlock
    (69.0, 71.5, "s6a_setup", 0),
    (71.5, 75.7, "s6b_results", 0),
    (75.7, 80.0, "s6c_leaderboard", 0),
    # Finale montage: quick cuts, then a speed push into the title.
    (80.0, 80.55, "s7_montage", 0),
    (80.55, 81.1, "s4b_tunnel", 84),
    (81.1, 81.65, "s2_highway", 196),
    (81.65, 82.2, "s3b_mountain", 40),
    (82.2, 82.75, "s4b_tunnel", 214),
    (82.75, 83.3, "s3c_coastal_fuel", 96),
    (83.3, 85.0, "s7_montage", 60),
]
TITLE_AT = 85.0

HARD_CUTS = [12.0, 27.0, 31.4, 35.6, 40.0, 58.0, 69.0, 80.0, 80.55, 81.1, 81.65, 82.2, 82.75, 83.3]
SOFT_CUTS = [71.5, 75.7]
GAMEPLAY = [(0.0, 58.0), (80.0, 85.0)]

# (lines, start, end, centre y as a fraction of the height, colours per line)
CAPTIONS = [
    (["ONE RIDER.", "ONE HIGHWAY.", "NO ROOM FOR MISTAKES."], 0.9, 7.2, 0.53, [WHITE, WHITE, YELLOW]),
    (["DODGE.", "COLLECT.", "SURVIVE."], 12.4, 17.8, 0.53, [WHITE, YELLOW, WHITE]),
    (["EVERY KILOMETER", "BRINGS A NEW CHALLENGE."], 27.4, 31.2, 0.56, [WHITE, YELLOW]),
    (["DIVE BELOW.", "SURVIVE THE UNKNOWN."], 44.2, 50.6, 0.53, [PURPLE, WHITE]),
    (["15 MOTORCYCLES.", "YOUR CHOICE. YOUR RIDE."], 58.3, 62.4, 0.66, [YELLOW, WHITE]),
    (["BEAT THE RECORD.", "CHALLENGE YOUR FRIENDS."], 69.2, 72.0, 0.83, [YELLOW, WHITE]),
]
# Small labels naming the feature on screen.
TAGS = [
    ("LTO CHECKPOINT CHASE", 7.6, 11.6, YELLOW),
    ("SECRET MANHOLE TUNNEL", 51.0, 54.0, PURPLE),
    ("BARKADA RACE · PASS & PLAY", 72.1, 75.6, (124, 77, 255)),
    ("LEADERBOARD", 75.9, 79.8, (245, 124, 0)),
]


def clip_at(t):
    for start, end, shot, first in CLIPS:
        if start <= t < end:
            return start, end, shot, first
    return None


_listing = {}


def shot_files(shot):
    if shot not in _listing:
        _listing[shot] = sorted(p for p in (FRAMES / shot).glob("*.png"))
        if not _listing[shot]:
            sys.exit(f"No frames for {shot} in {FRAMES}. Run: flutter test trailer/capture/shots_test.dart")
    return _listing[shot]


def load_frame(shot, i):
    """Captures come out at 1080x1921 (rounding); crop to the video size."""
    img = Image.open(shot_files(shot)[i])
    if img.size != (W, H):
        img = img.crop((0, 0, W, H))
    return img.convert("RGBA")


def source_index(t):
    start, _, shot, first = clip_at(t)
    files = shot_files(shot)
    if first < 0:
        return shot, len(files) - 1
    return shot, min(first + int(round((t - start) * FPS)), len(files) - 1)


_events = {}


def events(shot):
    if shot not in _events:
        p = FRAMES / shot / "events.json"
        _events[shot] = json.loads(p.read_text()) if p.exists() else None
    return _events[shot]


def state_at(t):
    c = clip_at(t)
    if c is None:
        return None
    shot, i = source_index(t)
    ev = events(shot)
    return ev[min(i, len(ev) - 1)] if ev else None


# ------------------------------------------------------------------ helpers
def ease(x):
    x = min(max(x, 0.0), 1.0)
    return 1 - (1 - x) ** 3


_fonts = {}


def font(path, size):
    key = (path, size)
    if key not in _fonts:
        _fonts[key] = ImageFont.truetype(path, size)
    return _fonts[key]


def text_layer(lines, colors, size, stroke):
    """Renders stacked caption lines on a transparent RGBA image."""
    f = font(FONT_BLACK, size)
    boxes = [f.getbbox(l, stroke_width=stroke) for l in lines]
    widths = [b[2] - b[0] for b in boxes]
    line_h = size + stroke * 2 + 14
    img = Image.new("RGBA", (max(widths) + 40, line_h * len(lines) + 30), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, (line, col) in enumerate(zip(lines, colors)):
        x = (img.width - widths[i]) // 2 - boxes[i][0]
        y = 15 + i * line_h - boxes[i][1]
        d.text((x + 6, y + 8), line, font=f, fill=(0, 0, 0, 150), stroke_width=stroke, stroke_fill=(0, 0, 0, 150))
        d.text((x, y), line, font=f, fill=col, stroke_width=stroke, stroke_fill=(10, 10, 14))
    return img


def fit_size(lines, max_w, size, stroke):
    while size > 30:
        f = font(FONT_BLACK, size)
        if max(f.getbbox(l, stroke_width=stroke)[2] - f.getbbox(l, stroke_width=stroke)[0] for l in lines) <= max_w:
            return size
        size -= 4
    return size


def paste_scaled(base, layer, cx, cy, scale, alpha):
    if alpha <= 0.01 or scale <= 0.01:
        return
    w, h = max(1, int(layer.width * scale)), max(1, int(layer.height * scale))
    l = layer.resize((w, h), Image.LANCZOS) if (w, h) != layer.size else layer
    if alpha < 0.999:
        a = l.getchannel("A").point(lambda v: int(v * alpha))
        l = l.copy()
        l.putalpha(a)
    base.alpha_composite(l, (int(cx - w / 2), int(cy - h / 2)))


_caption_cache = {}


def draw_captions(img, t):
    for idx, (lines, start, end, fy, colors) in enumerate(CAPTIONS):
        if not (start <= t < end + 0.01):
            continue
        out = 1 - ease((t - (end - 0.3)) / 0.3) if t > end - 0.3 else 1.0
        # Band behind the words for readability.
        band_a = 0.55 * min(ease((t - start) / 0.25), out)
        size = fit_size(lines, W - 110, 104, 9)
        line_h = size + 18 + 14
        band_h = line_h * len(lines) + 70
        cy = H * fy
        band = Image.new("RGBA", (W, int(band_h)), (8, 10, 18, int(255 * band_a)))
        img.alpha_composite(band, (0, int(cy - band_h / 2)))
        # Lines pop in one after another.
        for i, (line, col) in enumerate(zip(lines, colors)):
            t0 = start + i * 0.55
            if t < t0:
                continue
            key = (idx, i)
            if key not in _caption_cache:
                _caption_cache[key] = text_layer([line], [col], size, 9)
            k = (t - t0) / 0.22
            scale = 1 + 0.45 * (1 - ease(k))
            y = cy - (len(lines) - 1) * line_h / 2 + i * line_h
            paste_scaled(img, _caption_cache[key], W / 2, y, scale, min(ease(k * 1.4), out))


_tag_cache = {}


def draw_tags(img, t):
    for text, start, end, color in TAGS:
        if not (start <= t < end):
            continue
        a = min(ease((t - start) / 0.25), 1 - ease((t - (end - 0.25)) / 0.25))
        if text not in _tag_cache:
            f = font(FONT_BLACK, 46)
            b = f.getbbox(text)
            pill = Image.new("RGBA", (b[2] - b[0] + 70, 92), (0, 0, 0, 0))
            d = ImageDraw.Draw(pill)
            d.rounded_rectangle((0, 0, pill.width - 1, pill.height - 1), radius=46, fill=(*color, 235))
            d.text((35 - b[0], 46 - (b[1] + b[3]) / 2), text, font=f, fill=(255, 255, 255))
            _tag_cache[text] = pill
        slide = (1 - ease((t - start) / 0.3)) * 120
        paste_scaled(img, _tag_cache[text], W / 2, H * 0.875 + slide, 1.0, a)


def white_flash(t):
    a = 0.0
    for c in HARD_CUTS:
        d = t - c
        if 0 <= d < 0.22:
            strength = 0.35 if 80.5 < c < 84 else 0.75
            a = max(a, strength * (1 - d / 0.22))
    return a


_title_bg = None


def title_frame(t):
    global _title_bg
    if _title_bg is None:
        last = load_frame("s7_montage", len(shot_files("s7_montage")) - 1).convert("RGB")
        bg = last.filter(ImageFilter.GaussianBlur(18))
        bg = ImageEnhance.Brightness(bg).enhance(0.35)
        # Warm vignette.
        vig = Image.new("L", (W, H), 0)
        ImageDraw.Draw(vig).ellipse((-W * 0.4, -H * 0.15, W * 1.4, H * 1.15), fill=255)
        vig = vig.filter(ImageFilter.GaussianBlur(160))
        _title_bg = Image.composite(bg, Image.new("RGB", (W, H), (6, 6, 12)), vig).convert("RGBA")
    k = t - TITLE_AT
    img = _title_bg.copy()
    # Speed streaks, blended on their own layer.
    streaks = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(streaks)
    rnd = np.random.default_rng(3)
    for _ in range(26):
        x = rnd.uniform(0, W)
        y0 = (rnd.uniform(0, H) + k * rnd.uniform(1400, 2600)) % (H + 400) - 200
        ln = rnd.uniform(120, 360)
        d.line((x, y0, x, y0 + ln), fill=(255, 225, 150, int(rnd.uniform(18, 50))), width=2)
    img.alpha_composite(streaks)

    slam = ease(k / 0.28)
    shake = (1 - ease(k / 0.6)) * 14 * math.sin(k * 70) if k > 0.28 else 0
    big = text_layer(["KAMOTE RIDER"], [YELLOW], fit_size(["KAMOTE RIDER"], W - 90, 150, 12), 12)
    paste_scaled(img, big, W / 2 + shake, H * 0.40, 1 + 1.2 * (1 - slam), slam)
    if k > 0.35:
        sub = text_layer(["HIGHWAY ESCAPE"], [WHITE], fit_size(["HIGHWAY ESCAPE"], W - 160, 112, 10), 10)
        paste_scaled(img, sub, W / 2, H * 0.40 + 175, 1 + 0.5 * (1 - ease((k - 0.35) / 0.25)), ease((k - 0.35) / 0.2))
    if k > 1.3:
        tag = text_layer(["HOW FAR CAN YOU GO?"], [WHITE], 70, 7)
        paste_scaled(img, tag, W / 2, H * 0.58, 1.0, ease((k - 1.3) / 0.4))
    if k > 2.2:
        f = font(FONT_BOLD, 40)
        line = "Dodge the traffic. Keep your fuel. Beat your record."
        if f.getbbox(line)[2] > W - 80:
            f = font(FONT_BOLD, 34)
        layer = Image.new("RGBA", (W, 80), (0, 0, 0, 0))
        b = f.getbbox(line)
        ImageDraw.Draw(layer).text(((W - b[2]) / 2, 15), line, font=f, fill=(220, 226, 238))
        paste_scaled(img, layer, W / 2, H * 0.655, 1.0, ease((k - 2.2) / 0.5))
    if k > 3.0:
        f = font(FONT_BOLD, 34)
        line = "A fictional arcade game. Ride safe in real life!"
        b = f.getbbox(line)
        layer = Image.new("RGBA", (W, 70), (0, 0, 0, 0))
        ImageDraw.Draw(layer).text(((W - b[2]) / 2, 12), line, font=f, fill=(150, 160, 180))
        paste_scaled(img, layer, W / 2, H * 0.93, 1.0, ease((k - 3.0) / 0.5))
    return img


def render_frame(t):
    if t >= TITLE_AT:
        img = title_frame(t)
    else:
        shot, i = source_index(t)
        img = load_frame(shot, i)
        start, end, _, first = clip_at(t)
        zoom = 1.0
        if first < 0:  # slow push-in on a held frame
            zoom = 1 + 0.06 * (t - start) / (end - start)
        if 83.3 <= t < TITLE_AT:  # speed push into the title
            zoom = 1 + 0.3 * ease((t - 83.3) / 1.7) ** 2
        if zoom > 1.001:
            cw, ch = W / zoom, H / zoom
            box = ((W - cw) / 2, (H - ch) * 0.6, (W + cw) / 2, (H - ch) * 0.6 + ch)
            img = img.resize((W, H), Image.BICUBIC, box=box)
        # Crossfade on soft cuts.
        for c in SOFT_CUTS:
            if c <= t < c + 0.3:
                prev = load_frame(*source_index(c - 1 / FPS))
                img = Image.blend(prev, img, ease((t - c) / 0.3))
        draw_captions(img, t)
        draw_tags(img, t)

    flash = white_flash(t)
    if 84.75 <= t < TITLE_AT:
        flash = max(flash, (t - 84.75) / 0.25)
    if TITLE_AT <= t < TITLE_AT + 0.35:
        flash = max(flash, 1 - (t - TITLE_AT) / 0.35)
    if flash > 0.01:
        img = Image.blend(img, Image.new("RGBA", (W, H), (255, 255, 255, 255)), min(flash, 1.0))
    # Fade in from black, fade out at the end.
    black = 0.0
    if t < 0.5:
        black = 1 - t / 0.5
    if t > DUR - 1.0:
        black = (t - (DUR - 1.0)) / 1.0
    if black > 0.01:
        img = Image.blend(img, Image.new("RGBA", (W, H), (0, 0, 0, 255)), min(black, 1.0))
    return img.convert("RGB")


# ------------------------------------------------------------------ audio
def load(name):
    with wave.open(str(AUDIO_DIR / f"{name}.wav")) as w:
        sr, n, ch = w.getframerate(), w.getnframes(), w.getnchannels()
        data = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float32) / 32768
    if ch == 2:
        data = data.reshape(-1, 2).mean(axis=1)
    if sr != SR:
        x_new = np.arange(int(len(data) * SR / sr)) / SR
        data = np.interp(x_new, np.arange(len(data)) / sr, data).astype(np.float32)
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
    ph = 2 * np.pi * np.cumsum(45 + 95 * np.exp(-t / 0.035)) / SR
    return (np.sin(ph) * np.exp(-t / 0.16) + RNG.standard_normal(n) * np.exp(-t / 0.004) * 0.3).astype(np.float32)


def snare():
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    noise = np.diff(RNG.standard_normal(n), prepend=0) * 0.5
    return (noise * np.exp(-t / 0.08) * 0.7 + np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.05) * 0.6).astype(np.float32)


def hat():
    n = int(0.05 * SR)
    return (np.diff(RNG.standard_normal(n), prepend=0) * env_exp(n, 0.012) * 0.5).astype(np.float32)


def crash():
    n = int(1.6 * SR)
    return (np.diff(RNG.standard_normal(n), prepend=0) * env_exp(n, 0.45) * 0.45).astype(np.float32)


def boom():
    n = int(1.1 * SR)
    t = np.arange(n) / SR
    ph = 2 * np.pi * np.cumsum(32 + 40 * np.exp(-t / 0.12)) / SR
    return (np.sin(ph) * np.exp(-t / 0.4) + RNG.standard_normal(n) * np.exp(-t / 0.02) * 0.5).astype(np.float32)


def riser(dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    k = t / dur
    noise = np.diff(RNG.standard_normal(n), prepend=0) * 0.35
    tone = np.sign(np.sin(2 * np.pi * np.cumsum(220 + 1400 * k ** 2) / SR)) * 0.12
    return ((noise + tone) * k ** 2.2).astype(np.float32)


def lowpass(x, cutoff):
    """FFT brick-wall-ish low-pass (fast enough for a whole track)."""
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    spec *= 1 / (1 + (freqs / cutoff) ** 4)
    return np.fft.irfft(spec, len(x)).astype(np.float32)


def echo(x, delay=0.21, feedback=0.42, taps=5):
    d = int(delay * SR)
    # Leave room for the tail so short sounds ring out.
    y = np.concatenate([x, np.zeros(d * taps, np.float32)])
    for k in range(1, taps + 1):
        y[d * k : d * k + len(x)] += x * feedback ** k
    return y


def rumble(dur):
    n = int(dur * SR)
    noise = RNG.standard_normal(n).astype(np.float32)
    r = lowpass(noise, 90) * 3.0
    t = np.arange(n) / SR
    clack = np.zeros(n, np.float32)
    for c in np.arange(0.1, dur, 0.36):
        add(clack, c, hat() * 1.6)
    return (r * (0.7 + 0.3 * np.sin(2 * np.pi * 0.5 * t)) + lowpass(clack, 2500)).astype(np.float32)


def horn(dur=1.2):
    n = int(dur * SR)
    t = np.arange(n) / SR
    tone = sum(np.sign(np.sin(2 * np.pi * f * t)) for f in (311, 392)) * 0.08
    envelope = np.minimum(1, t / 0.05) * np.minimum(1, (dur - t) / 0.15)
    return lowpass((tone * envelope).astype(np.float32), 1800)


def build_audio():
    n = int(DUR * SR)
    music = np.zeros(n, np.float32)
    drums = np.zeros(n, np.float32)
    sfx = np.zeros(n, np.float32)

    ride = load("music_ride")  # 12.8 s = 8 bars at 150 BPM
    t = -0.8
    while t < TITLE_AT:
        add(music, t, ride)
        t += len(ride) / SR
    music[int(TITLE_AT * SR):] = 0
    gain = np.ones(n, np.float32)
    tt = np.arange(n) / SR
    # Intro build: muffled and quiet, opening up at the drop.
    intro = tt < 12.0
    muffled = lowpass(music, 700)
    mix = np.clip((tt - 6.0) / 6.0, 0, 1)
    music = np.where(intro, muffled * (1 - mix) + music * mix * 0.6, music)
    gain *= np.where(intro, 0.45 + 0.35 * np.clip(tt / 12.0, 0, 1), 1.0)
    # Tunnel: dark, muffled, echoing.
    a, b = int(40.6 * SR), int(56.3 * SR)
    music[a:b] = echo(lowpass(music[a:b], 450) * 1.4)[: b - a]
    # Garage: lighter.
    gain[int(58.0 * SR):int(69.0 * SR)] *= 0.7
    music *= gain
    # Title: menu theme fades in under the logo.
    menu = load("music_menu")
    seg = menu[: int((DUR - TITLE_AT - 0.2) * SR)].copy()
    seg *= np.minimum(1, np.arange(len(seg)) / (0.6 * SR)).astype(np.float32)
    seg *= np.minimum(1, (len(seg) - np.arange(len(seg))) / (1.4 * SR)).astype(np.float32)
    add(music, TITLE_AT + 0.2, seg, 0.7)

    # Drums on the 150 BPM grid from the drop.
    K, S, Hh = kick(), snare(), hat()
    beat = 0.4
    for i in range(int((TITLE_AT - 12.0) / beat)):
        bt = 12.0 + i * beat
        tunnel = 40.6 <= bt < 56.3
        if 39.6 <= bt < 40.6 or 84.2 <= bt:
            continue
        if tunnel:
            if i % 2 == 0:
                add(drums, bt, K, 0.8)
            continue
        add(drums, bt, K, 0.9 if not 58 <= bt < 69 else 0.5)
        if i % 2 == 1:
            add(drums, bt, S, 0.45)
        add(drums, bt + beat / 2, Hh, 0.32)
        if 80 <= bt:
            add(drums, bt + beat / 4, Hh, 0.2)
            add(drums, bt + 3 * beat / 4, Hh, 0.2)
    for c in (12.0, 27.0, 56.4, 69.0, 80.0):
        add(drums, c, crash(), 0.8)
    for c in (35.6, 31.4, 58.0):
        add(drums, c, crash(), 0.4)
    for at, d in ((10.4, 1.6), (38.8, 1.2), (55.2, 1.2), (78.8, 1.2), (83.6, 1.4)):
        add(sfx, at, riser(d), 0.5)
    add(sfx, TITLE_AT, boom(), 0.9)
    add(drums, TITLE_AT, crash(), 1.0)

    # Game sound effects driven by the logged events.
    cash, fuel, whistle, kilo = load("sfx_cash"), load("sfx_fuel"), load("sfx_whistle"), load("sfx_kilometer")
    whoosh, engine, siren = load("sfx_whoosh"), load("loop_engine"), load("loop_siren")
    last_cash = -1.0
    prev = None
    for f in range(int(TITLE_AT * FPS)):
        t = f / FPS
        if not any(a <= t < b for a, b in GAMEPLAY):
            prev = None
            continue
        s = state_at(t)
        if s is None:
            continue
        if prev is not None and clip_at(t)[2] == clip_at((f - 1) / FPS)[2]:
            if s["cash"] > prev["cash"] and t - last_cash > 0.07:
                add(sfx, t, cash, 0.35)
                last_cash = t
            if s["fuel"] > prev["fuel"] + 0.04:
                add(sfx, t, fuel, 0.6)
            if s["chase"] and not prev["chase"]:
                add(sfx, t, whistle, 0.7)
            if s["combo"] > prev["combo"]:
                add(sfx, t, whoosh, 0.45)
            if s["lane"] != prev["lane"]:
                add(sfx, t, whoosh, 0.12)
            if s["world"] != prev["world"] and s["world"] != 5 and prev["world"] != 5:
                add(sfx, t, kilo, 0.6)
            if s["ug"] == "falling" and prev["ug"] != "falling":
                add(sfx, t, whoosh, 0.8)
                add(sfx, t + 0.35, boom(), 0.5)
            if s["ug"] == "emerging" and prev["ug"] == "rising":
                add(sfx, t, kilo, 0.6)
        # Engine and siren loops, chopped per frame.
        i0, i1 = int(t * SR), int((t + 1 / FPS) * SR)
        pitch = 0.8 + 0.4 * min(s["kmh"], 120) / 120
        k = (np.arange(i0, i1) * pitch) % len(engine)
        sfx[i0:i1] += engine[k.astype(int)] * (0.16 if s["ug"] != "falling" else 0.05)
        if s["chase"]:
            sfx[i0:i1] += siren[np.arange(i0, i1) % len(siren)] * 0.16
        if s["world"] == 5:
            sfx[i0:i1] += 0  # tunnel ambience is added below
        prev = s
    # Tunnel ambience: rumble of trains, a horn when the LRT shows up.
    add(sfx, 43.4, rumble(12.8), 0.35)
    add(sfx, 45.6, echo(horn()), 0.5)
    add(sfx, 49.0, echo(horn(0.8)), 0.3)

    # Menus: clicks, the unlock, the results.
    click, unlock, mission, tada = load("sfx_click"), load("sfx_unlock"), load("sfx_mission"), load("meme_tada")
    for c in (59.2, 60.1, 61.0, 61.9, 62.8):
        add(sfx, c, whoosh, 0.25)
    add(sfx, 63.0, click, 0.5)
    add(sfx, 64.0, click, 0.5)
    add(sfx, 64.05, unlock, 0.8)
    for c in (69.6, 70.1, 70.5):
        add(sfx, c, click, 0.4)
    add(sfx, 71.6, tada, 0.55)
    add(sfx, 75.8, mission, 0.5)

    mixdown = music * 0.55 + drums * 0.5 + sfx * 0.8
    # Fade out with the picture.
    fade = np.clip((DUR - tt) / 1.0, 0, 1).astype(np.float32)
    mixdown *= fade
    peak = np.max(np.abs(mixdown))
    mixdown = np.tanh(mixdown / peak * 1.4) / np.tanh(1.4) * 0.92
    stereo = np.stack([mixdown, mixdown], axis=1)
    return (stereo * 32767).astype(np.int16)


def write_wav(path, data):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# ------------------------------------------------------------------ main
def main():
    if len(sys.argv) > 1 and sys.argv[1] == "stills":
        out = FRAMES.parent / "stills"
        out.mkdir(exist_ok=True)
        for s in sys.argv[2:]:
            render_frame(float(s)).save(out / f"still_{float(s):05.1f}.png")
            print("wrote", out / f"still_{float(s):05.1f}.png")
        return

    audio_path = FRAMES.parent / "trailer_audio.wav"
    print("mixing audio...")
    write_wav(audio_path, build_audio())

    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    cmd = [
        ffmpeg, "-y", "-loglevel", "error",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-i", str(audio_path),
        "-map", "0:v", "-map", "1:a",
        "-c:v", "libx264", "-preset", "medium", "-crf", "20",
        "-profile:v", "high", "-level", "4.0", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "192k", "-ar", str(SR),
        "-movflags", "+faststart", "-shortest",
        str(OUT),
    ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    total = int(DUR * FPS)
    for f in range(total):
        proc.stdin.write(render_frame(f / FPS).tobytes())
        if f % 150 == 0:
            print(f"frame {f}/{total}")
    proc.stdin.close()
    if proc.wait() != 0:
        sys.exit("ffmpeg failed")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
