# Kamote Rider: Highway Escape

A portrait-mode 2D endless motorcycle arcade game built with **Flutter** and the **Flame** game engine. It is a fictional, humorous game set on Philippine-inspired highways. All characters, officers, vehicles and brands in it are made up.

You ride through five changing worlds and pick up paper money and fuel. Avoid traffic, and survive the 10-second LTO chase. Spend what you earn to release 15 impounded motorcycles.

---

## 1. How to play

| Action | Control |
|---|---|
| Change lane | Swipe left/right (one lane per ~26 px of drag) or tap the on-screen ◀ ▶ buttons |
| Desktop testing | Arrow keys or A/D; P or Esc to pause |
| Pause | ⏸ button at top-right, or the Android Back button |

**Rules**

- The bike moves forward on its own. You only steer.
- **Fuel** keeps dropping while you ride. Red jerry cans refill 28% of the tank. When the tank hits zero, you get the **Out of Fuel** ending.
- **Paper bills** (₱20/₱50/₱100) add to your run earnings. Every kilometer pays a milestone bonus. Surviving a chase pays a ₱75 escape bonus.
- **LTO checkpoint:** every run starts by riding past a checkpoint, and the officer chases you for 10 seconds.
- **Side collisions** start a 10-second LTO chase. These are scraping the guardrail, hitting the side or rear of a car, or hitting a barrier.
- A **second side collision during any chase** gives you the **Ticket & Jail** ending.
- **Potholes and cones** are minor: they slow you down and make the bike wobble, but never start a chase.
- **Hitting oncoming traffic head-on** (the two left lanes) gives you the **Ambulance** ending right away. A red ▼ warning shows at the top of the lane before an oncoming car appears.
- After any hit, you are briefly invulnerable (1.2–1.6 s depending on difficulty) while you get knocked aside. This stops one crash from counting twice.
- **Dogs, cats and chickens** sometimes cross the road. Bumping one is a minor hit: you stop short, the animal hops away unhurt, and there's no chase.
- The world changes every **1 km**: City Highway → Provincial Road → Mountain Road → Coastal Highway → Urban Road. Then the loop repeats with heavier traffic.

**Collision policy (in priority order).** If several hits happen in the same frame, only the most serious one counts:

1. Head-on with oncoming traffic: the run ends (ambulance).
2. Side collision: the chase starts. If a chase is already running, you go to jail.
3. Minor hazard: you slow down.

There is only ever **one chase timer**. The checkpoint chase counts as your first offense, and a new collision never restarts or stacks the timer.

### Difficulty

Before each run you pick a difficulty on the **Choose Difficulty** screen. Your last choice is remembered, and Medium is the default. The difficulty can't change during a run.

| | Easy, "Chill ride, idol." | Medium, "Sakto lang, pero ingat." | Hard, "Para sa tunay na kamote survivor." |
|---|---|---|---|
| Starting speed | ×0.86 | ×1.0 | ×1.1 |
| Speed growth per km (cap) | +2% (20%) | +3.5% (32%) | +4.5% (40%) |
| Traffic / obstacles | ×0.7 / ×0.7, slower ramp-up | ×1.0 | ×1.22 / ×1.25, faster ramp-up |
| Clear road before each hazard | 0.75 s | 0.5 s | 0.4 s |
| Warning before oncoming cars | 1.6 s | 1.3 s | 1.1 s |
| Fuel burn / time between fuel cans | ×0.8 / ×0.75 | ×1.0 / ×1.0 | ×1.2 / ×1.2 |
| Random challenge every | ~22 s | ~16 s | ~11 s |
| Bonus money* | ×0.75 | ×1.0 | ×1.5 |
| Recovery after a hit / steering speed | 1.6 s / ×1.15 | 1.3 s / ×1.0 | 1.2 s / ×1.0 |

\*Bonus money covers milestones, escape bonuses, near misses, streaks and challenges. Paper bills always pay face value.

On every difficulty, the 10-second chase, "second offense = jail", "head-on = game over", and "never more than 2 of 4 lanes blocked" rules stay the same. All of these values live in `lib/game/difficulty_config.dart`.

### Random highway challenges

A challenge is announced in a small banner under the top bar just before it arrives. If you clear it without touching any part of it, you get bonus pesos, paid once per challenge.

| Challenge | What happens | Base reward |
|---|---|---:|
| Animal crossing: dog / cat / chicken | A dog runs straight across, hesitates, or turns back. A cat dashes, pauses mid-road, or reverses. A flock of chickens waddles across. A "!" bubble shows before any stop or turn. | ₱30–35 |
| Tricycle incoming | A tricycle merges from the roadside with its turn signal on | ₱40 |
| Brake lights ahead | A car ahead brakes hard (brake lights, tyre screech) | ₱45 |
| Road works | A barrier and cones close one lane, with a warning sign | ₱60 |
| Pothole zone | A scattered field of potholes | ₱50 |
| Falling cargo | A truck drops a cardboard box behind it | ₱50 |
| Cash rush | A 12-bill trail that weaves across lanes, including oncoming ones. Collect every bill to win. | ₱80 |
| Fuel emergency | When fuel is low, a jerry can appears in a risky but reachable lane | — |
| LTO surprise | A checkpoint ahead waves you through if you're in the right lanes (3–4). Counterflow and you're chased. | ₱60 |
| VIP convoy | Four black SUVs with strobes block both right lanes | ₱70 |

**Fairness.** Every challenge is planned through the same lane planner as normal traffic, so it only starts if there's always an escape lane. Animals start on the shoulder above the screen and begin crossing only once visible. The game simulates their path ahead of time and only allows paths that cover at most 2 lanes when they reach you. While an animal crosses, normal traffic pauses. A pending challenge also briefly holds new traffic so the road can clear.

### Combos, near misses and memes

- **Near miss:** pass a hazard by a hair and you earn ₱10 × combo (up to ×5). Each dodge or cleared challenge adds to your combo, which shows as "x3 COMBO" in the HUD. Any collision resets it.
- **Cash streak:** collect 8 bills in quick succession for a ₱40 bonus.
- **Meme reactions:** short Taglish pop-ups react to what just happened. Examples: "AY, NAKO!", "KAMOTE MOMENT!", "LAGOT KA, BOSS!", "TAKBO, KAMOTE!", "SANA ALL MAY GASOLINA!", "NICE ONE, IDOL!", "GOOD BOY, GOOD SAVE!", "PUSA SA GITNA!".
  - **Placement:** they appear below the rider, between the steering buttons. That road is already behind you, so they never cover hazards, the fuel gauge or the chase timer.
  - **Cooldowns:** each event has its own cooldown, there's a global cooldown, and the same line never repeats twice in a row.
  - **Settings:** pop-ups can be set to **Full**, **Reduced** (major moments only) or **Off**. Meme sounds have their own on/off switch, separate from other sound effects.

---

## 2. Setting up your computer (beginner guide)

### 2.1 Install Flutter
1. Download the Flutter SDK (stable channel) from <https://docs.flutter.dev/get-started/install/windows>.
2. Extract it to a folder **without spaces**, e.g. `C:\src\flutter`.
3. Add `C:\src\flutter\bin` to your **PATH**: Start → "Edit the system environment variables" → Environment Variables → Path → New.
4. Open a new terminal and run:
   ```
   flutter --version
   flutter doctor
   ```
   This project was built with **Flutter 3.38.7 / Dart 3.10.7**. Any newer stable release should also work.

### 2.2 Install the Android tools
1. Install **Android Studio** from <https://developer.android.com/studio>. It includes the Android SDK.
2. In Android Studio, open **More Actions → SDK Manager** and install:
   - Android SDK Platform (latest)
   - Android SDK Command-line Tools
   - Android SDK Build-Tools
3. Accept the licenses:
   ```
   flutter doctor --android-licenses
   ```
   Press `y` for each one.
4. Create an emulator: **More Actions → Virtual Device Manager → Create device**. Pick a phone such as a Pixel 7 with a recent system image.

Run `flutter doctor` again until the **Flutter** and **Android toolchain** lines both show ✓.

### 2.3 Set up VS Code
1. Install VS Code from <https://code.visualstudio.com>.
2. Install these extensions:
   - **Flutter** (Dart Code). This also installs the **Dart** extension.
3. Open this folder: **File → Open Folder… → `kamote_rider`**.

### 2.4 Get the dependencies
In the VS Code terminal (**Terminal → New Terminal**), run:
```
flutter pub get
```
The game uses:
- `flame`: game loop, components and collision detection
- `flame_audio`: music and sound effects
- `shared_preferences`: saves your progress on the device
- `flame_test`: testing helpers (dev only)

To recreate this project from scratch, run `flutter create kamote_rider`, then `flutter pub add flame flame_audio shared_preferences` and `flutter pub add dev:flame_test`.

### 2.5 Run the game
1. Start an emulator: click the device name in the VS Code status bar (bottom-right) and pick your emulator. You can also run `flutter emulators --launch <name>`.
2. Press **F5** (Run → Start Debugging), or run:
   ```
   flutter run
   ```
3. While it runs, press `r` in the terminal to hot reload or `R` to hot restart.

To quickly try it on Windows without Android, run `flutter run -d windows` and steer with the arrow keys.

### 2.6 Run on a real Android phone
1. On the phone, open **Settings → About phone** and tap **Build number** 7 times to enable Developer options.
2. Open **Settings → Developer options** and turn on **USB debugging**.
3. Connect the phone with a USB cable and accept the "Allow USB debugging?" prompt.
4. Run `flutter devices`. The phone should be listed. Then run `flutter run`.
5. To build an installable APK, run `flutter build apk --release`. The file is at `build/app/outputs/flutter-apk/app-release.apk`.

### 2.7 Checks
```
flutter analyze        # static analysis (should print "No issues found!")
flutter test           # 133 unit, game-simulation, render and widget tests
```

---

## 3. Troubleshooting

| Problem | Fix |
|---|---|
| `Some Android licenses not accepted` | Run `flutter doctor --android-licenses` and accept them all. |
| `No connected devices` | Start an emulator, or check the USB cable and the debugging prompt. Then run `flutter devices`. |
| Gradle build fails or hangs on first run | The first build downloads Gradle and takes a few minutes. Run `flutter clean`, then `flutter pub get`, and try again. Make sure Android Studio's JDK is used: run `flutter doctor -v` to check. |
| `Unable to load asset` | Check that the `assets:` section in `pubspec.yaml` lists `assets/audio/` and `assets/images/sprites/`. Run `flutter pub get`, then do a full restart (not hot reload). |
| Missing audio files | Run `dart run tool/generate_audio.dart`. The game still runs silently without them. |
| Version conflicts after editing `pubspec.yaml` | Run `flutter pub upgrade`, or check `flutter pub outdated`. |
| Game runs in landscape | Portrait is locked in `main.dart` and in `android:screenOrientation="portrait"` in `AndroidManifest.xml`. Uninstall the app and reinstall it. |
| No sound | Check **Settings** in the game, the phone's media volume, and silent mode. |

---

## 4. Project structure

```
lib/
  main.dart                  App start: portrait lock, load save, init audio
  app.dart                   MaterialApp, routes, theme
  game/
    kamote_game.dart         FlameGame: run flow, collisions, endings, HUD sync
    game_config.dart         Tunable constants (lanes, speeds, fuel, chase)
    difficulty_config.dart   Easy / Medium / Hard parameters (single source)
    game_state.dart          RunStateMachine + GameStatus (incl. PoliceChase)
    game_world.dart          World container
    environments.dart        The 5 world themes (visuals, traffic mix, density)
    hud_model.dart           Values the Flutter HUD listens to
    sprite_overrides.dart    Optional PNG replacements for procedural art
    components/              Player, traffic, obstacles, cash, fuel, road,
                             LTO officer + checkpoint, scenery, effects,
                             road_animal (dog/cat/chicken), atmosphere
                             (haze/dust/fog/sunset/rain, speed lines)
    systems/                 Fuel, chase, collision, distance, reward,
                             difficulty, traffic spawner (+ fairness planner),
                             meme_event_manager, animal_crossing_manager,
                             highway_challenge_manager, challenge_reward_manager
    painting/                Procedural art shared by game and menus
  models/                    Motorcycles (15), missions, save data
  services/                  Save, profile, garage, missions, audio
  screens/                   Main menu, difficulty select, garage,
                             collection, missions, settings, game screen
  overlays/                  HUD, pause, ticket/jail, ambulance,
                             out-of-fuel, shared game-over panel
  widgets/                   Arcade buttons, bike preview, menu backdrop
assets/                      Audio + optional sprites (see assets/README.md)
tool/generate_audio.dart     Synthesizes the sound effects and music
test/                        Unit, game-simulation and widget tests
```

**Architecture notes**

- The gameplay rules live in plain Dart classes (`systems/`), which are unit-tested without Flame.
- Flame's collision callbacks only *report* contacts. `KamoteGame` resolves one highest-priority event per frame, after collision detection runs.
- `RunStateMachine` allows exactly one run per Play action and one ending per run. `RewardSystem.finalize` pays out exactly once.
- Movement uses delta time, and frame time is capped at 50 ms to prevent tunneling after a hitch.
- Pausing stops the Flame engine *and* the update loop. Fuel, distance and the chase timer cannot advance while paused, and losing app focus opens the pause menu.
- The spawner registers every hazard's arrival time at the rider. A hazard is rejected if it would block more than 2 of the 4 lanes at once. Oncoming cars always give at least 1.3 s of warning. Paper bills are pooled for reuse, and off-screen entities are removed.
- Progress is stored as one validated JSON blob in SharedPreferences. Corrupted or outdated data falls back to safe defaults. Older saves load without problems: missing new settings (difficulty, meme options) get their defaults.
- Challenges and animals tag their hazards with a challenge ID. A pass tracker resolves each hazard once it is behind the rider, which drives near misses, challenge completion and missed pickups. Each challenge pays at most once.
- Every new feature follows the run state. Paused or game-over runs freeze all movement and animations, and only a live run processes collisions or rewards.

---

## 5. Garage balance

| Tier | Motorcycle | Price | Speed | Handling | Fuel eff. |
|---|---|---:|---:|---:|---:|
| 1 | Kamote 110 | Free | 1 | 6 | 8 |
| 1 | Barangay 125 | ₱1,000 | 2 | 5 | 9 |
| 1 | Sidecar Sprint | ₱2,000 | 3 | 3 | 9 |
| 2 | Tricycle Escape | ₱3,500 | 4 | 2 | 10 |
| 2 | Highway Cub | ₱5,000 | 5 | 7 | 6 |
| 2 | Provincial Flash | ₱7,000 | 6 | 6 | 5 |
| 3 | Road Rebel 150 | ₱10,000 | 7 | 7 | 5 |
| 3 | Falcon Street 200 | ₱14,000 | 8 | 8 | 4 |
| 3 | Midnight Racer | ₱18,000 | 9 | 6 | 6 |
| 4 | Thunder 250 | ₱24,000 | 10 | 7 | 3 |
| 4 | Asphalt Phantom | ₱32,000 | 11 | 9 | 3 |
| 4 | Mountain Stalker | ₱42,000 | 12 | 8 | 5 |
| 5 | Highway King 400 | ₱55,000 | 13 | 6 | 4 |
| 5 | Impound Legend | ₱75,000 | 14 | 9 | 2 |
| 5 | Kamote Xtreme | ₱100,000 | 15 | 10 | 1 |

What the stats do:
- **Speed** sets cruising speed (76–135 km/h before distance scaling).
- **Handling** sets lane-change time and acceleration.
- **Fuel efficiency** scales fuel use from 0.75× to 1.2×.

Fuel cans spawn on a timer, not by distance, so fast bikes that burn a lot of fuel still have to be managed. You can tune all of this in `models/motorcycle_model.dart` and `game/game_config.dart`.

---

## 6. Known limitations

- The art is procedural placeholder art in one consistent style. The sound and music are simple synthesized chiptune. Both can be replaced; see `assets/README.md`.
- The camera is a 2D top-down view from behind the rider, not a pseudo-3D road.
- Missions are local and repeatable: each claim raises the level. They do not reset on a real-world daily calendar.
- The engine sound does not change pitch with speed.
- The meme sounds are original synthesized stingers, not voice recordings. You can drop in your own recorded voice lines; see `assets/README.md`.
- Weather is tied to the world: Urban Road is always rainy and Coastal Highway always has a sunset. It isn't random.
