"""Voice-over lines for the gameplay showcase.

    python trailer/narration.py      # (re)generate the voice clips

Clips are made with the free Microsoft Edge neural voices via the
`edge-tts` package (needs internet) and cached as WAV in
build/showcase_voice/. showcase.py places them on the timeline.
"""
import asyncio
import pathlib
import subprocess
import sys

import imageio_ffmpeg

ROOT = pathlib.Path(__file__).resolve().parent.parent
VOICE_DIR = ROOT / "build" / "showcase_voice"
VOICE = "en-US-GuyNeural"

# id -> text. Adapted from the showcase script to match the real game:
# the rider wears a helmet, the leaderboard is on-device, multiplayer is
# Barkada Race, and Ghost Race is announced as coming soon.
LINES = {
    "intro1": "Every highway has rules. Every rider has a choice. But this rider? Well... he has other plans!",
    "intro2": "Meet the Kamote Rider! No patience, no brakes, and absolutely no intention of stopping!",
    "chase1": "He's officially on the road! The LTO is on his tail, the traffic is getting heavier, "
    "and stopping is definitely not part of the plan!",
    "chase2": "Nice move! But don't celebrate yet. This highway is just getting started!",
    "fuel1": "Money on the road? Grab it! Fuel running low? Better find some! "
    "Because in this game, running out of gas means your escape is over!",
    "fuel2": "Fuel secured! That's what I call a last-second save!",
    "fuel3": "Every bill counts. Save your earnings, unlock your ride, and keep moving!",
    "world1": "One kilometer down, a whole new challenge ahead! The road changes, the scenery changes, "
    "and the traffic won't give you a break!",
    "world2": "Think you've mastered the highway? Just wait until the next world!",
    "tunnel1": "Wait! Did that road just swallow our rider?!",
    "tunnel2": "Welcome underground! It's dark, the LRT is moving, "
    "and you've got just twenty seconds to survive this unexpected detour!",
    "tunnel3": "Train incoming! Eyes on the road! One wrong move, and this escape could be over!",
    "tunnel4": "And we're back! Same rider, same mission, and not a single kilometer wasted!",
    "garage1": "You survived the highway. You conquered the tunnel. Now it's time to upgrade your ride!",
    "garage2": "Fifteen motorcycles are waiting for you. Earn your cash, choose your favorite, "
    "and hit the road in style!",
    "versus1": "Think you're the best rider on the highway? Prove it!",
    "versus2": "Check the leaderboard, then pass the phone in Barkada Race. "
    "Same highway, one run each, and the highest score takes the crown!",
    "versus3": "And coming soon: Ghost Race, where you chase a friend's recorded run. "
    "Your rival might be a recording, but beating their score? That's personal!",
    "final1": "Traffic is heavier. Fuel is running low. The road keeps changing. "
    "But the real question is... how long can YOU survive?",
    "final2": "One more kilometer! One more challenge! One more chance to beat your record!",
    "end1": "Every run ends. Every mistake teaches you something. And every retry is another chance to go farther!",
    "end2": "Kamote Rider: Highway Escape. Dodge the traffic. Keep your fuel. Beat your record!",
}


async def _speak(text, path):
    import edge_tts

    await edge_tts.Communicate(text, VOICE, rate="+6%", pitch="+2Hz").save(str(path))


def generate(force=False):
    VOICE_DIR.mkdir(parents=True, exist_ok=True)
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    for key, text in LINES.items():
        wav = VOICE_DIR / f"{key}.wav"
        if wav.exists() and not force:
            continue
        mp3 = VOICE_DIR / f"{key}.mp3"
        asyncio.run(_speak(text, mp3))
        subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", str(mp3), "-ac", "1", "-ar", "44100", str(wav)], check=True)
        print("voiced", key)


if __name__ == "__main__":
    generate(force="--force" in sys.argv)
