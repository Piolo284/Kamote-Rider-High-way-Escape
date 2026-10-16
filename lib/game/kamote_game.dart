import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, KeyEventResult;

import '../models/mission_model.dart';
import '../services/audio_service.dart';
import '../services/mission_service.dart';
import '../services/player_profile.dart';
import 'components/atmosphere.dart';
import 'components/cash_collectible.dart';
import 'components/effects.dart';
import 'components/environment_manager.dart';
import 'components/fuel_collectible.dart';
import 'components/highway_entity.dart';
import 'components/lto_officer.dart';
import 'components/player_motorcycle.dart';
import 'components/road_animal.dart';
import 'components/road_obstacle.dart';
import 'components/road_segment.dart';
import 'components/traffic_vehicle.dart';
import 'difficulty_config.dart';
import 'environments.dart';
import 'game_config.dart';
import 'game_state.dart';
import 'game_world.dart';
import 'hud_model.dart';
import 'sprite_overrides.dart';
import 'systems/challenge_reward_manager.dart';
import 'systems/chase_system.dart';
import 'systems/collision_system.dart';
import 'systems/difficulty.dart';
import 'systems/distance_system.dart';
import 'systems/fuel_system.dart';
import 'systems/highway_challenge_manager.dart';
import 'systems/meme_event_manager.dart';
import 'systems/reward_system.dart';
import 'systems/traffic_spawner.dart';

/// Kamote Rider: Highway Escape — the Flame game.
///
/// Owns the per-run systems (fuel, chase, distance, rewards, collisions)
/// and a [RunStateMachine] that guarantees a single run, a single ending and
/// a single payout.
class KamoteGame extends FlameGame<HighwayWorld> with HasCollisionDetection, KeyboardEvents {
  KamoteGame({
    required this.profile,
    required this.missions,
    required this.audio,
    math.Random? random,
    this.loadSprites = true,
    this.autoStart = true,
    DifficultyLevel? difficultyLevel,
  }) : _random = random ?? math.Random(),
       difficulty = DifficultyConfig.of(difficultyLevel ?? profile.settings.lastDifficulty),
       super(world: HighwayWorld());

  static const String hudOverlay = 'hud';
  static const String pauseOverlay = 'pause';
  static const String jailOverlay = 'ticketJail';
  static const String ambulanceOverlay = 'ambulance';
  static const String fuelOverlay = 'outOfFuel';
  static const String gameOverOverlay = 'gameOver';
  static const List<String> endOverlays = [jailOverlay, ambulanceOverlay, fuelOverlay, gameOverOverlay];

  final PlayerProfile profile;
  final MissionService missions;
  final AudioService audio;
  final bool loadSprites;
  final bool autoStart;
  final math.Random _random;

  final SpriteOverrides sprites = SpriteOverrides();
  final HudModel hud = HudModel();

  // Systems.
  final RunStateMachine state = RunStateMachine();
  final FuelSystem fuel = FuelSystem();
  final ChaseSystem chase = ChaseSystem();
  final CollisionSystem collisions = CollisionSystem();
  final DistanceSystem distance = DistanceSystem();
  final RewardSystem rewards = RewardSystem();
  late final MemeEventManager memes = MemeEventManager(random: _random);
  final ComboSystem combo = ComboSystem();
  final ChallengeRewardManager challengeRewards = ChallengeRewardManager();

  /// Difficulty for every run started by this game instance. Chosen on the
  /// difficulty screen before the game opens; never changes mid-run.
  final DifficultyConfig difficulty;

  // Persistent components.
  late final PlayerMotorcycle player;
  late final RoadComponent road;
  late final TrafficSpawner spawner;
  late final EnvironmentManager environment;
  late final HighwayChallengeManager challenges;
  late final AtmosphereLayer atmosphere;
  late final RoadEdge _leftEdge;
  late final RoadEdge _rightEdge;
  LtoOfficer? _officer;
  final SpeedLines _speedLines = SpeedLines();
  late final Set<Component> _persistent;

  /// Navigation hooks supplied by the game screen.
  VoidCallback? onExitToMenu;
  VoidCallback? onOpenGarage;

  // Layout.
  double viewHeight = 800;
  double _zoom = 1;
  double _safeTop = 0;
  double get playerY => viewHeight * GameConfig.playerYFraction;

  /// World-space y just below the HUD bar.
  double get hudTopInset => (_safeTop + 112) / _zoom;

  // Run data.
  double speedKmh = 0;
  double get scrollSpeed => GameConfig.kmhToPixelsPerSecond(speedKmh);

  /// 1 = traffic drives normally, 0 = everything frozen (crash ending).
  double trafficFlow = 1;

  /// Seconds of active gameplay this run (frozen while paused).
  double runTime = 0;

  /// Meters travelled during the current frame.
  double frameMeters = 0;

  double _cleanMeters = 0;
  bool _hadCollision = false;
  int _lastWholeMeters = 0;
  bool _lowFuelWarned = false;
  bool _fuelCriticalWarned = false;
  int _runsStarted = 0;
  double _endingTimer = 0;
  double _shake = 0;
  RunSummary? lastSummary;

  GameStatus get status => state.status(chaseActive: chase.active);
  double get cleanMeters => _cleanMeters;

  // ------------------------------------------------------------ lifecycle

  @override
  Color backgroundColor() => const Color(0xFF263238);

  @override
  Future<void> onLoad() async {
    if (loadSprites) await sprites.load(images);
    camera.viewfinder.anchor = Anchor.topCenter;
    road = RoadComponent();
    player = PlayerMotorcycle();
    spawner = TrafficSpawner(random: _random);
    environment = EnvironmentManager(random: _random);
    challenges = HighwayChallengeManager(random: _random);
    atmosphere = AtmosphereLayer(random: _random);
    _leftEdge = RoadEdge(isLeft: true);
    _rightEdge = RoadEdge(isLeft: false);
    _persistent = {road, _leftEdge, _rightEdge, player, atmosphere, _speedLines};
    await world.addAll(_persistent);
    await addAll([environment, spawner, challenges]);
    _layout();
    if (autoStart) startRun();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layout();
  }

  /// Called by the game screen with the device's top safe-area inset.
  void setSafeTop(double logicalPixels) => _safeTop = logicalPixels;

  void _layout() {
    if (size.x <= 0 || size.y <= 0) return;
    _zoom = math.min(size.x / GameConfig.worldWidth, size.y / GameConfig.minVisibleHeight);
    camera.viewfinder.zoom = _zoom;
    camera.viewfinder.position = Vector2(GameConfig.worldWidth / 2, 0);
    viewHeight = size.y / _zoom;
    if (isLoaded) {
      _leftEdge.layout(viewHeight);
      _rightEdge.layout(viewHeight);
      player.y = playerY;
    }
  }

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    super.lifecycleStateChange(state);
    // Losing focus mid-run opens the pause menu instead of silently
    // resuming later.
    if (state != AppLifecycleState.resumed && this.state.isPlaying) pauseRun();
  }

  /// Stops sounds owned by the game. Called when the game screen closes.
  void shutdown() {
    audio.stopAllLoops();
  }

  // ------------------------------------------------------------ run flow

  /// Begins a new run. Ignored unless the previous run is fully over, so a
  /// single Play action can only ever start one run.
  void startRun() {
    if (!state.start()) return;
    world.clearRunEntities(_persistent);
    _officer = null;
    fuel.reset(drainMultiplier: profile.selectedBike.fuelDrainMultiplier * difficulty.fuelDrainMultiplier);
    chase.reset();
    collisions.clear();
    distance.reset();
    rewards.reset(bonusMultiplier: difficulty.rewardMultiplier);
    memes.reset();
    combo.reset();
    challengeRewards.reset();
    speedKmh = 0;
    trafficFlow = 1;
    runTime = 0;
    frameMeters = 0;
    _cleanMeters = 0;
    _hadCollision = false;
    _lastWholeMeters = 0;
    _lowFuelWarned = false;
    _fuelCriticalWarned = false;
    _endingTimer = 0;
    _shake = 0;
    lastSummary = null;

    final bike = profile.selectedBike;
    player.reset(bike, y: playerY);
    player.steeringMultiplier = difficulty.steeringMultiplier;
    road.reset();
    spawner.reset();
    challenges.reset();
    atmosphere.reset();
    environment.reset();
    environment.populate(viewHeight);
    missions.beginRun(bike.id);

    hud.resetRun();
    hud.setBike(bike.name);
    hud.setDifficulty(difficulty.label, difficulty.color);
    world.add(LtoCheckpoint()..y = playerY - 330);

    for (final o in [...endOverlays, pauseOverlay]) {
      overlays.remove(o);
    }
    overlays.add(hudOverlay);
    audio.startLoop(LoopSound.engine);
    audio.playMusic(MusicTrack.ride);
    if (_runsStarted++ > 0) _meme(MemeEvent.restart);
    resumeEngine();
  }

  void pauseRun() {
    if (!state.pause()) return;
    audio.pauseLoops();
    overlays.add(pauseOverlay);
    pauseEngine();
  }

  void resumeRun() {
    if (!state.resume()) return;
    overlays.remove(pauseOverlay);
    audio.resumeLoops();
    resumeEngine();
  }

  void restartRun() {
    _abandonLiveRun();
    startRun();
  }

  void exitToMenu() {
    _abandonLiveRun();
    audio.stopAllLoops();
    onExitToMenu?.call();
  }

  void openGarage() {
    _abandonLiveRun();
    audio.stopAllLoops();
    onOpenGarage?.call();
  }

  /// Quitting keeps whatever was earned so far; the run is banked once.
  void _abandonLiveRun() {
    if (state.quit()) {
      _bankRun();
    } else if (state.isEnding) {
      state.finishEnding();
      _bankRun();
    }
  }

  // ------------------------------------------------------------ input

  void steer(int direction) {
    if (!state.acceptsGameplay) return;
    player.steer(direction);
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      steer(-1);
    } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
      steer(1);
    } else if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP) {
      state.isPaused ? resumeRun() : pauseRun();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ------------------------------------------------------------ update

  @override
  void update(double dt) {
    final step = math.min(dt, GameConfig.maxFrameDt);
    // Belt and braces: the engine is paused too, but never simulate while
    // the pause menu is open even if update is driven manually (tests).
    if (state.isPaused || state.phase == RunPhase.idle || state.isOver) {
      super.update(0);
      return;
    }
    if (state.acceptsGameplay) {
      _simulateRun(step);
    } else if (state.isEnding) {
      _simulateEnding(step);
    } else {
      frameMeters = 0;
    }
    // Components move, then Flame runs collision detection.
    super.update(step);
    _resolveCollisions();
    _trackPasses();
    _updateShake(step);
    _syncHud();
    hud.tick(step);
    hud.flush();
  }

  void _simulateRun(double dt) {
    runTime += dt;
    final bike = player.bike;
    final target = bike.topSpeedKmh * Difficulty.at(distance.meters, difficulty).speedMultiplier;
    if (speedKmh < target) {
      speedKmh = math.min(target, speedKmh + bike.accelerationKmhPerSec * dt);
    } else {
      speedKmh = math.max(target, speedKmh - 40 * dt);
    }
    frameMeters = speedKmh / 3.6 * dt;

    final throttle = 0.3 + 0.7 * (speedKmh / target).clamp(0.0, 1.0);
    if (fuel.consume(dt, throttle: throttle)) {
      _endRun(EndReason.outOfFuel);
      return;
    }
    if (fuel.isLow && !_lowFuelWarned) {
      _lowFuelWarned = true;
      hud.toast('LOW FUEL! Grab a jerry can!', color: const Color(0xFFFF5252));
    } else if (!fuel.isLow) {
      _lowFuelWarned = false;
    }
    if (fuel.fraction < 0.15 && !_fuelCriticalWarned) {
      _fuelCriticalWarned = true;
      _meme(MemeEvent.fuelCritical);
    } else if (fuel.fraction > 0.3) {
      _fuelCriticalWarned = false;
    }

    if (chase.update(dt)) _onChaseSurvived();

    final km = distance.advance(frameMeters);
    if (km != null) _onKilometer(km);
    if (!_hadCollision) _cleanMeters += frameMeters;

    final whole = distance.meters.floor();
    if (whole != _lastWholeMeters) {
      _announce(
        missions.onDistance(deltaMeters: whole - _lastWholeMeters, runMeters: whole, cleanMeters: _cleanMeters.floor()),
      );
      _lastWholeMeters = whole;
    }
  }

  void _simulateEnding(double dt) {
    _endingTimer += dt;
    switch (state.endReason) {
      case EndReason.headOnCrash:
        speedKmh = 0;
        if (_endingTimer > 2.4) _finishRun();
      case EndReason.ticketAndJail:
        speedKmh = math.max(0, speedKmh - 140 * dt);
        final caught = _officer?.hasCaughtRider ?? true;
        if ((_endingTimer > 1.6 && caught) || _endingTimer > 3.0) _finishRun();
      case EndReason.outOfFuel:
        speedKmh = math.max(0, speedKmh - 48 * dt);
        if ((speedKmh <= 0 && _endingTimer > 1.0) || _endingTimer > 4.0) _finishRun();
      case EndReason.quit:
      case null:
        _finishRun();
    }
    frameMeters = 0;
  }

  // ------------------------------------------------------------ collisions

  /// Called by the rider's hitbox when a contact starts. Pickups are applied
  /// immediately; crashes are queued and resolved once per frame by priority.
  void onPlayerContact(PositionComponent other) {
    if (!state.acceptsGameplay) return;
    if (other is Collectible) {
      _collect(other);
      return;
    }
    if (other is! Hazard) return;
    final hazard = other;
    if (hazard.processed) return;
    ImpactAxis? axis;
    if (hazard.hazardKind == HazardKind.vehicle) {
      axis = classifyImpact(
        previousA: player.previousHitRect,
        currentA: player.hitRect,
        previousB: hazard.previousHitRect,
        currentB: hazard.hitRect,
      );
    }
    collisions.report(
      CollisionEvent(
        outcome: outcomeFor(kind: hazard.hazardKind, oncoming: hazard.isOncoming, axis: axis),
        kind: hazard.hazardKind,
        axis: axis,
        source: hazard,
      ),
    );
  }

  void _resolveCollisions() {
    final event = collisions.resolve();
    if (event == null || !state.acceptsGameplay) return;
    // Short grace period after a hit: the rider is being knocked aside.
    if (player.isInvulnerable) return;
    final source = event.source as Hazard;
    if (source is! RoadEdge) source.processed = true;
    _hadCollision = true;
    // A crash breaks the dodge combo and fails the challenge it belongs to.
    combo.breakCombo();
    if (source.challengeId != 0) challengeRewards.fail(source.challengeId);

    switch (event.outcome) {
      case CollisionOutcome.headOn:
        source.onStruck(event.outcome);
        _endRun(EndReason.headOnCrash);
      case CollisionOutcome.sideCollision:
        if (chase.active) {
          source.onStruck(event.outcome);
          _impactFx(source, big: false);
          _endRun(EndReason.ticketAndJail);
          return;
        }
        chase.start(ChaseTrigger.sideCollision);
        _onSideHit(source, event);
        _spawnOfficer();
        audio.startLoop(LoopSound.siren);
        audio.play(Sfx.whistle);
        _meme(MemeEvent.chaseStart);
        hud.toast(
          event.kind == HazardKind.roadEdge
              ? 'Scraped the guardrail! LTO is after you!'
              : 'Kamote move! LTO is after you!',
          color: const Color(0xFFFF8A80),
        );
      case CollisionOutcome.minor:
        source.onStruck(event.outcome);
        final animal = event.kind == HazardKind.animal;
        // Animals cause a sudden stop (no injury shown); other bumps a slowdown.
        speedKmh *= animal ? 0.45 : 0.6;
        player.wobble();
        player.startInvulnerability(animal ? 0.8 : 0.45);
        audio.play(Sfx.bump);
        audio.haptic();
        _shake = math.max(_shake, animal ? 0.25 : 0.15);
        world.add(
          FloatingText(
            switch (event.kind) {
              HazardKind.pothole => 'LUBAK!',
              HazardKind.animal => 'PRENO!',
              HazardKind.debris => 'KAHON!',
              _ => 'BUMP!',
            },
            position: Vector2(player.x, player.y - 46),
            color: const Color(0xFFFFE082),
          ),
        );
        _meme(animal ? MemeEvent.animalBump : MemeEvent.kamoteMoment);
    }
  }

  void _onSideHit(Hazard source, CollisionEvent event) {
    source.onStruck(event.outcome);
    if (source is TrafficVehicle || source is RoadObstacle) {
      final lane = (source as HighwayEntity).lane;
      final dir = player.x < source.x ? -1 : 1;
      var newLane = lane + dir;
      if (newLane < 0 || newLane >= GameConfig.laneCount) newLane = lane - dir;
      player.knockTo(newLane);
    }
    speedKmh *= 0.75;
    player.wobble();
    player.startInvulnerability(difficulty.invulnerabilitySeconds);
    audio.play(Sfx.impact);
    audio.haptic(heavy: true);
    _impactFx(source, big: false);
  }

  void _impactFx(Hazard source, {required bool big}) {
    final Vector2 at;
    if (source is RoadEdge) {
      at = Vector2(source.isLeft ? GameConfig.roadLeft : GameConfig.roadRight, player.y - 10);
    } else {
      at = Vector2((player.x + source.x) / 2, (player.y + source.y) / 2);
    }
    world.add(ImpactBurst(position: at, big: big));
    _shake = math.max(_shake, big ? 0.6 : 0.3);
  }

  // ------------------------------------------------------------ events

  void _collect(Collectible item) {
    if (item.collected) return;
    item.collected = true;
    item.onCollected();
    if (item.challengeId != 0) _resolveChallenge(item.challengeId, success: true);
    if (item is CashCollectible) {
      rewards.addBill(item.value);
      audio.play(Sfx.cash, gain: 0.7);
      world.add(PickupSparkle(position: Vector2(item.x, item.y), color: const Color(0xFF69F0AE), count: 8));
      if (combo.registerCash(runTime)) {
        final bonus = rewards.addCashStreak();
        hud.toast('CASH STREAK x${combo.cashStreak}! +₱$bonus', color: const Color(0xFF69F0AE));
        _meme(MemeEvent.cashCombo);
      }
      world.add(
        FloatingText(
          '+₱${item.value}',
          position: Vector2(item.x, item.y - 16),
          color: const Color(0xFFB9F6CA),
          fontSize: 14,
        ),
      );
      _announce(missions.onBillCollected());
      _announce(missions.onRunCashChanged(rewards.billCash));
    } else if (item is FuelCollectible) {
      fuel.refill(GameConfig.fuelPickupAmount);
      rewards.addFuelPickup();
      audio.play(Sfx.fuel);
      world.add(PickupSparkle(position: Vector2(item.x, item.y), color: const Color(0xFFFFEB3B), count: 12));
      world.add(FloatingText('+FUEL', position: Vector2(item.x, item.y - 18), color: const Color(0xFFFFEB3B)));
      _announce(missions.onFuelCollected());
    }
  }

  /// Fired by the checkpoint when the rider rolls past it.
  void onCheckpointPassed({bool surprise = false}) {
    if (!state.acceptsGameplay) return;
    // Mid-run surprise checkpoints wave through riders who keep to the
    // right (their own) lanes; counterflowing kamotes get chased.
    if (surprise && player.lane >= GameConfig.oncomingLaneCount) {
      final bonus = rewards.addChallengeReward(Challenges.of(ChallengeType.ltoSurprise).reward);
      hud.toast('Waved through the checkpoint! +₱$bonus', color: const Color(0xFF82B1FF));
      _meme(MemeEvent.ltoSlip);
      return;
    }
    if (!chase.start(ChaseTrigger.checkpoint)) return;
    _meme(MemeEvent.chaseStart);
    _spawnOfficer();
    audio.play(Sfx.whistle);
    audio.startLoop(LoopSound.siren);
    hud.toast('LTO checkpoint! Escape for 10 seconds!', color: const Color(0xFF82B1FF), seconds: 2.8);
    world.add(FloatingText('HOY! TIGIL!', position: Vector2(player.x, player.y + 70), color: const Color(0xFF82B1FF)));
  }

  /// Fired by the environment manager whenever the distance counter moves
  /// into a new world.
  void onEnvironmentChanged(int index, {required bool announce}) {
    final theme = Environments.at(index);
    hud.setEnvironment(theme.name, theme.accent);
    if (!announce) return;
    final loop = distance.cycle;
    hud.showBanner(
      'WORLD ${index + 1}: ${theme.name.toUpperCase()}',
      loop > 0 ? '${theme.tagline} · Loop ${loop + 1}: heavier traffic' : theme.tagline,
      theme.accent,
    );
  }

  void _onKilometer(int km) {
    final reward = rewards.addMilestone(km);
    audio.play(Sfx.kilometer);
    hud.toast('$km KM REACHED! +₱$reward', color: const Color(0xFFFFD54F));
    _announce(missions.onEnvironmentVisited(distance.distinctEnvironmentsVisited));
  }

  void _onChaseSurvived() {
    final bonus = rewards.addChaseEscape();
    _officer?.leave();
    audio.stopLoop(LoopSound.siren);
    hud.toast('You escaped the LTO! +₱$bonus', color: const Color(0xFF69F0AE));
    _announce(missions.onChaseSurvived());
  }

  void _announce(List<MissionDef> completed) {
    for (final def in completed) {
      final level = missions.stateOf(def).level;
      hud.toast('MISSION COMPLETE: ${def.titleFor(level)}', color: const Color(0xFFFFD740), seconds: 3);
      audio.play(Sfx.mission);
    }
  }

  /// Called by the challenge manager once a challenge has been placed.
  void onChallengeStarted(ChallengeDef def) {
    hud.announce(def.title, def.subtitle, def.color);
    audio.play(Sfx.challenge, gain: 0.8);
    if (def.dangerous) _meme(MemeEvent.dangerZone);
  }

  void onVehicleBraking(TrafficVehicle vehicle) {
    if (!state.acceptsGameplay) return;
    audio.play(Sfx.brake, gain: 0.6);
    world.add(
      FloatingText(
        'SKRRT!',
        position: Vector2(vehicle.x, vehicle.y + vehicle.height / 2 + 10),
        color: const Color(0xFFFF8A80),
        fontSize: 13,
      ),
    );
  }

  void onCargoDropped(TrafficVehicle truck) {
    audio.play(Sfx.bump, gain: 0.7);
    world.add(
      FloatingText(
        'BLAG!',
        position: Vector2(truck.x, truck.y + truck.height / 2 + 20),
        color: const Color(0xFFD7B98E),
        fontSize: 13,
      ),
    );
  }

  /// Shows (and plays) a meme reaction, respecting cooldowns and settings.
  void _meme(MemeEvent event) {
    final s = profile.settings;
    final popups = s.memePopups != MemePopupMode.off;
    if (!popups && !s.memeSounds) return;
    final line = memes.trigger(event, runTime, mode: popups ? s.memePopups : MemePopupMode.full);
    if (line == null) return;
    if (popups) hud.showMeme(line.text);
    audio.playMeme(event, line.sound);
  }

  /// Resolves dodges once each hazard is behind the rider: near misses,
  /// challenge completion, and missed challenge pickups.
  void _trackPasses() {
    if (!state.acceptsGameplay) return;
    final pr = player.hitRect;
    for (final c in world.children) {
      if (c is Hazard && c is! RoadEdge) {
        final h = c;
        if (h.passedPlayer) continue;
        final r = h.hitRect;
        if (r.bottom >= pr.top && r.top <= pr.bottom) {
          if (c is! RoadAnimal || c.isOnRoad) {
            final gap = r.left >= pr.right ? r.left - pr.right : (pr.left >= r.right ? pr.left - r.right : 0.0);
            if (gap < h.minGap) h.minGap = gap;
          }
        } else if (r.top > pr.bottom) {
          h.passedPlayer = true;
          _onHazardPassed(h);
        }
      } else if (c is Collectible) {
        final item = c;
        if (item.challengeId == 0 || item.passedPlayer || item.collected) continue;
        if (item.y - item.height / 2 > pr.bottom) {
          item.passedPlayer = true;
          _resolveChallenge(item.challengeId, success: false);
        }
      }
    }
    hud.setCombo(combo.combo);
  }

  /// Side gap (world units) that counts as a near miss.
  static const double nearMissGap = 20;
  static const double oncomingNearMissGap = 30;

  void _onHazardPassed(Hazard h) {
    if (h.processed) {
      if (h.challengeId != 0) _resolveChallenge(h.challengeId, success: false, source: h);
      return;
    }
    if (h.challengeId != 0) _resolveChallenge(h.challengeId, success: true, source: h);
    if (h is RoadAnimal) return;
    final threshold = h is TrafficVehicle && h.oncoming ? oncomingNearMissGap : nearMissGap;
    if (h.minGap <= threshold) {
      final n = combo.registerDodge();
      final bonus = rewards.addNearMiss(n);
      audio.play(Sfx.whoosh, gain: 0.7);
      world.add(
        FloatingText(
          n > 1 ? 'NEAR MISS x$n +₱$bonus' : 'NEAR MISS +₱$bonus',
          position: Vector2(player.x, player.y + 48),
          color: const Color(0xFF80D8FF),
          fontSize: 13,
        ),
      );
      _meme(MemeEvent.nearMiss);
    }
  }

  void _resolveChallenge(int id, {required bool success, Hazard? source}) {
    final payout = challengeRewards.resolvePiece(id, success: success);
    if (payout == null) return;
    final amount = rewards.addChallengeReward(payout.baseReward);
    final n = combo.registerDodge();
    final comboText = n > 1 ? '  (x$n combo)' : '';
    hud.toast('${payout.name} CLEARED! +₱$amount$comboText', color: const Color(0xFFFFD740));
    audio.play(Sfx.mission, gain: 0.8);
    if (source is RoadAnimal) {
      _meme(switch (source.kind) {
        AnimalKind.dog => MemeEvent.dogDodge,
        AnimalKind.cat => MemeEvent.catDodge,
        AnimalKind.chicken => MemeEvent.chickenDodge,
      });
    } else {
      _meme(MemeEvent.challengeComplete);
    }
  }

  void _spawnOfficer() {
    final existing = _officer;
    if (existing != null && !existing.isRemoving && !existing.isRemoved && existing.parent != null) {
      existing.rejoin();
      return;
    }
    _officer = LtoOfficer();
    world.add(_officer!);
  }

  // ------------------------------------------------------------ endings

  void _endRun(EndReason reason) {
    if (!state.beginEnding(reason)) return;
    collisions.clear();
    _endingTimer = 0;
    player.braking = true;
    audio.stopLoop(LoopSound.engine);
    switch (reason) {
      case EndReason.headOnCrash:
        speedKmh = 0;
        trafficFlow = 0;
        player.crash();
        world.add(ImpactBurst(position: Vector2(player.x, player.y - 30), big: true, color: const Color(0xFFFFAB40)));
        world.add(AmbulanceResponder());
        _officer?.leave();
        _shake = 0.7;
        audio.stopLoop(LoopSound.siren);
        audio.play(Sfx.crash);
        audio.startLoop(LoopSound.ambulance);
        audio.haptic(heavy: true);
      case EndReason.ticketAndJail:
        _spawnOfficer();
        _officer!.catchRider();
        audio.play(Sfx.whistle);
        world.add(
          FloatingText(
            'PRRRT! HULI KA!',
            position: Vector2(player.x, player.y - 60),
            color: const Color(0xFF82B1FF),
            fontSize: 20,
          ),
        );
        audio.haptic(heavy: true);
      case EndReason.outOfFuel:
        _officer?.leave();
        audio.stopLoop(LoopSound.siren);
        audio.play(Sfx.sputter);
        world.add(
          FloatingText('*sputter*', position: Vector2(player.x, player.y - 50), color: const Color(0xFFFFCC80)),
        );
      case EndReason.quit:
        break;
    }
  }

  void _finishRun() {
    if (!state.finishEnding()) return;
    _bankRun();
    audio.stopAllLoops();
    audio.play(Sfx.gameOver);
    overlays.remove(hudOverlay);
    overlays.add(switch (state.endReason) {
      EndReason.ticketAndJail => jailOverlay,
      EndReason.headOnCrash => ambulanceOverlay,
      EndReason.outOfFuel => fuelOverlay,
      _ => gameOverOverlay,
    });
    pauseEngine();
  }

  /// Banks the run exactly once; later calls return the same summary.
  RunSummary? _bankRun() {
    final result = rewards.finalize(
      distanceMeters: distance.meters,
      missionsCompleted: missions.completedThisRun,
      bestCombo: combo.bestCombo,
      difficultyLabel: difficulty.label,
    );
    if (result != null) lastSummary = profile.applyRun(result);
    return lastSummary;
  }

  // ------------------------------------------------------------ helpers

  void _updateShake(double dt) {
    if (_shake <= 0) {
      camera.viewfinder.position.setValues(GameConfig.worldWidth / 2, 0);
      return;
    }
    _shake = math.max(0, _shake - dt);
    final amp = 9 * _shake;
    camera.viewfinder.position.setValues(
      GameConfig.worldWidth / 2 + (_random.nextDouble() - 0.5) * amp,
      (_random.nextDouble() - 0.5) * amp,
    );
  }

  void _syncHud() {
    hud.setDistance(distance.meters);
    hud.setSpeed(speedKmh);
    hud.setFuel(fuel.fraction);
    hud.setLowFuel(fuel.isLow);
    hud.setRunCash(rewards.runEarnings);
    hud.setChase(active: chase.active, remaining: chase.remaining);
    hud.setInvulnerable(player.isInvulnerable);
  }
}
