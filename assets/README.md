# Assets

All art in the game is drawn in code, so the game runs with no image files. Audio comes from WAV files that a script generates.

## Audio (`assets/audio/`)

`tool/generate_audio.dart` synthesizes every sound from scratch, so you can use them freely. To regenerate them:

```
dart run tool/generate_audio.dart
```

To use your own sound, replace a file and keep the same name. If a file is missing, that sound is skipped and the game keeps working.

| File | Used for |
|---|---|
| `sfx_cash.wav` | Paper-bill pickup |
| `sfx_fuel.wav` | Fuel pickup |
| `sfx_impact.wav` | Side collision |
| `sfx_bump.wav` | Pothole / cone |
| `sfx_whistle.wav` | LTO whistle |
| `sfx_click.wav` | Button clicks |
| `sfx_unlock.wav` | Motorcycle unlocked |
| `sfx_mission.wav` | Mission complete |
| `sfx_kilometer.wav` | 1 km milestone |
| `sfx_crash.wav` | Head-on crash |
| `sfx_sputter.wav` | Out of fuel |
| `sfx_game_over.wav` | Game-over screen |
| `loop_engine.wav` | Engine loop while riding |
| `loop_siren.wav` | LTO chase siren |
| `loop_ambulance.wav` | Ambulance siren |
| `music_menu.wav` | Menu music |
| `music_ride.wav` | Gameplay music |
| `sfx_whoosh.wav` | Near miss |
| `sfx_brake.wav` | Car braking suddenly |
| `sfx_challenge.wav` | Challenge announcement |
| `meme_boing.wav`, `meme_wahwah.wav`, `meme_airhorn.wav`, `meme_tada.wav`, `meme_woof.wav`, `meme_meow.wav`, `meme_cluck.wav`, `meme_uhoh.wav` | Meme reaction stingers (controlled by the **Meme sounds** setting) |

### Optional meme voice lines

The game doesn't ship any recorded voices. To add your own, put WAV files in `assets/audio/` using these names. When a voice line exists for an event, it plays instead of that event's stinger:

`voice_near_miss.wav`, `voice_kamote_moment.wav`, `voice_chase_start.wav`, `voice_fuel_critical.wav`, `voice_restart.wav`, `voice_danger_zone.wav`, `voice_cash_combo.wav`, `voice_dog_dodge.wav`, `voice_cat_dodge.wav`, `voice_chicken_dodge.wav`, `voice_animal_bump.wav`, `voice_challenge_complete.wav`, `voice_lto_slip.wav`

Only use voices you recorded yourself or have a license for. Don't use celebrity voices or clips from viral videos.

## Replacing the placeholder art (`assets/images/sprites/`)

To replace the drawn art with your own, put PNG files here using the names below. They load automatically on the next launch. Draw each sprite top-down with the front facing **up**.

In the 3D view, `vehicle_*.png` is shown on the vehicle's roof, and `cash.png` and `fuel.png` are shown as upright pickups. The bike, officer and ambulance PNGs are only used by the flat top-down drawing code; the 3D view draws those from behind with its own art.

| File | Replaces |
|---|---|
| `bike_<id>.png` | A motorcycle, e.g. `bike_kamote_110.png`, `bike_thunder_250.png` (ids are in `lib/models/motorcycle_model.dart`) |
| `vehicle_car.png`, `vehicle_taxi.png`, `vehicle_jeepney.png`, `vehicle_bus.png`, `vehicle_truck.png`, `vehicle_tricycle.png`, `vehicle_van.png`, `vehicle_suv.png` | Traffic (oncoming traffic is rotated automatically) |
| `cash.png` | Paper bill |
| `fuel.png` | Fuel can |
| `officer.png` | LTO officer motorcycle |
| `ambulance.png` | Ambulance |

Use original or properly licensed art only. If a file is missing, the drawn version is used instead.

`backgrounds/` and `fonts/` are empty for now. If you add a font, register it under `flutter: fonts:` in `pubspec.yaml`.
