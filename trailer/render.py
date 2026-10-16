"""Render the Kamote Rider trailer to MP4.

    python render.py                 # full render -> kamote_rider_trailer.mp4
    python render.py stills 3 9.5    # PNG stills at the given times (seconds)
    python render.py audio           # audio track only

Frames come from trailer.html (headless Edge via Playwright); the soundtrack
mixes the game's own assets/audio with synthesized drums and impacts.
"""
import base64
import pathlib
import subprocess
import sys
import wave

import numpy as np
from playwright.sync_api import sync_playwright
import imageio_ffmpeg

HERE = pathlib.Path(__file__).resolve().parent
AUDIO_DIR = HERE.parent / "assets" / "audio"
OUT = HERE / "kamote_rider_trailer.mp4"
FPS = 60
SR = 44100


# ------------------------------------------------------------------ browser
def open_page(p):
    browser = p.chromium.launch(channel="msedge", headless=True)
    page = browser.new_page(viewport={"width": 1080, "height": 1920})
    page.goto((HERE / "trailer.html").as_uri() + "?capture=1")
    page.wait_for_function("window.TRAILER !== undefined")
    page.evaluate("document.fonts.ready")
    return browser, page


def grab(page, t, fmt="jpeg"):
    if fmt == "png":
        url = page.evaluate(f"(TRAILER.renderFrame({t}), document.getElementById('c').toDataURL('image/png'))")
    else:
        url = page.evaluate(f"TRAILER.captureFrame({t}, 0.94)")
    return base64.b64decode(url.split(",", 1)[1])


# -------------------------------------------------------------------- audio
def load(name):
    with wave.open(str(AUDIO_DIR / f"{name}.wav")) as w:
        sr, n = w.getframerate(), w.getnframes()
        data = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float32) / 32768
        if w.getnchannels() == 2:
            data = data.reshape(-1, 2).mean(axis=1)
    if sr != SR:
        x_old = np.arange(len(data)) / sr
        x_new = np.arange(int(len(data) * SR / sr)) / SR
        data = np.interp(x_new, x_old, data).astype(np.float32)
    return data


def add(buf, t, clip, vol=1.0):
    i = int(round(t * SR))
    if i >= len(buf):
        return
    j = min(len(buf), i + len(clip))
    buf[i:j] += clip[: j - i] * vol


def env_exp(n, decay):
    return np.exp(-np.arange(n) / SR / decay).astype(np.float32)


RNG = np.random.default_rng(7)


def kick():
    n = int(0.32 * SR)
    t = np.arange(n) / SR
    f = 45 + 95 * np.exp(-t / 0.035)
    ph = 2 * np.pi * np.cumsum(f) / SR
    click = RNG.standard_normal(n) * np.exp(-t / 0.004) * 0.3
    return (np.sin(ph) * np.exp(-t / 0.16) + click).astype(np.float32)


def snare():
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    noise = RNG.standard_normal(n)
    noise = np.diff(noise, prepend=0) * 0.5  # brighten
    tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.05)
    return ((noise * np.exp(-t / 0.08)) * 0.7 + tone * 0.6).astype(np.float32)


def hat():
    n = int(0.05 * SR)
    noise = np.diff(RNG.standard_normal(n), prepend=0)
    return (noise * env_exp(n, 0.012) * 0.5).astype(np.float32)


def crash():
    n = int(1.6 * SR)
    noise = np.diff(RNG.standard_normal(n), prepend=0)
    return (noise * env_exp(n, 0.45) * 0.45).astype(np.float32)


def boom():
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    f = 32 + 40 * np.exp(-t / 0.12)
    ph = 2 * np.pi * np.cumsum(f) / SR
    hit = RNG.standard_normal(n) * np.exp(-t / 0.02) * 0.5
    return (np.sin(ph) * np.exp(-t / 0.35) + hit).astype(np.float32)


def riser(dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    k = t / dur
    noise = np.diff(RNG.standard_normal(n), prepend=0) * 0.35
    f = 220 + 1400 * k ** 2
    tone = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.12
    return ((noise + tone) * k ** 2.2).astype(np.float32)


def one_pole_lowpass(x, alpha):
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha * (x[i] - acc)
        y[i] = acc
    return y


def build_audio(cues, dur):
    n = int(dur * SR) + SR
    music = np.zeros(n, np.float32)
    drums = np.zeros(n, np.float32)
    sfx = np.zeros(n, np.float32)

    slow = next((c for c in cues if c["name"] == "_slowmo"), None)
    slow_a, slow_b = (slow["t"], slow["t"] + slow["dur"]) if slow else (-1, -1)
    gap_a, gap_b = 44.4, 44.8  # breath before the logo slam

    # Music: the in-game ride theme (150 BPM), looped from the first drop.
    ride = load("music_ride")
    t, start = 1.6, 1.6
    while t < 50.4:
        add(music, t, ride)
        t += len(ride) / SR
    music[int(50.4 * SR):] = 0
    fade = np.linspace(1, 0, int(0.8 * SR), dtype=np.float32)
    music[int(49.6 * SR): int(49.6 * SR) + len(fade)] *= fade
    music[int(gap_a * SR): int(gap_b * SR)] = 0

    # Slow-mo: duck and muffle the music.
    if slow:
        a, b = int(slow_a * SR), int(slow_b * SR)
        seg = one_pole_lowpass(music[a:b].copy(), 0.04) * 1.6
        ramp = np.ones(b - a, np.float32)
        r = int(0.12 * SR)
        ramp[:r] = np.linspace(0, 1, r)
        ramp[-r:] = np.linspace(1, 0, r)
        music[a:b] = music[a:b] * (1 - ramp) + seg * ramp * 0.5

    # Drums on the 150 BPM grid.
    K, Sn, Hh = kick(), snare(), hat()
    beat = 0.4
    i = 0
    while True:
        bt = start + i * beat
        if bt >= 50.4:
            break
        quiet = slow_a - 0.05 <= bt < slow_b or gap_a <= bt < gap_b
        if not quiet:
            add(drums, bt, K, 0.95)
            if i % 2 == 1:
                add(drums, bt, Sn, 0.5)
            add(drums, bt + beat / 2, Hh, 0.35)
            if 24.0 <= bt < 30.4 or 30.4 <= bt < 35.2:  # busier hats in montage + cash rush
                add(drums, bt + beat / 4, Hh, 0.2)
                add(drums, bt + 3 * beat / 4, Hh, 0.2)
        i += 1
    if slow:  # heartbeat in slow-mo
        for hb in np.arange(slow_a + 0.1, slow_b - 0.2, 0.7):
            add(drums, hb, K, 0.7)
            add(drums, hb + 0.18, K, 0.45)

    CR, BM = crash(), boom()
    for t0 in (1.6, 24.0, 44.8):
        add(drums, t0, CR, 0.9)
    for t0, d in ((0.4, 1.2), (22.8, 1.2), (43.6, 0.8)):
        add(sfx, t0, riser(d), 0.55)

    cache = {}
    for c in cues:
        name, vol = c["name"], c["vol"]
        if name.startswith("_"):
            continue
        if name == "boom":
            add(sfx, c["t"], BM, 0.55 * vol)
            continue
        if name not in cache:
            cache[name] = load(name)
        add(sfx, c["t"], cache[name], 0.75 * vol)

    mix = music * 0.55 + drums * 0.55 + sfx
    mix = np.tanh(mix * 1.3) / np.tanh(1.3)
    mix *= 0.95 / max(1e-6, np.abs(mix).max())
    mix = mix[: int(dur * SR)]
    tail = int(0.3 * SR)
    mix[-tail:] *= np.linspace(1, 0, tail)
    return np.stack([mix, mix], axis=1)


def write_wav(path, stereo):
    pcm = (np.clip(stereo, -1, 1) * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


# --------------------------------------------------------------------- main
def main():
    args = sys.argv[1:]
    with sync_playwright() as p:
        browser, page = open_page(p)
        dur = page.evaluate("TRAILER.DUR")
        cues = page.evaluate("TRAILER.CUES")

        if args and args[0] == "stills":
            outdir = pathlib.Path(args[1])
            outdir.mkdir(parents=True, exist_ok=True)
            for ts in args[2:]:
                (outdir / f"still_{float(ts):06.2f}.png").write_bytes(grab(page, float(ts), "png"))
            browser.close()
            return

        wav = HERE / "trailer_audio.wav"
        write_wav(wav, build_audio(cues, dur))
        print(f"audio: {wav}")
        if args and args[0] == "audio":
            browser.close()
            return

        ff = imageio_ffmpeg.get_ffmpeg_exe()
        cmd = [
            ff, "-y", "-loglevel", "error",
            "-f", "image2pipe", "-framerate", str(FPS), "-c:v", "mjpeg", "-i", "-",
            "-i", str(wav),
            "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p",
            "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart",
            str(OUT),
        ]
        proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
        frames = int(round(dur * FPS))
        for f in range(frames):
            proc.stdin.write(grab(page, f / FPS))
            if f % 300 == 0:
                print(f"frame {f}/{frames}", flush=True)
        proc.stdin.close()
        proc.wait()
        browser.close()
        print(f"done: {OUT}")


if __name__ == "__main__":
    main()
