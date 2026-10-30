import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../components/fuel_collectible.dart';
import '../components/lto_officer.dart';
import '../components/road_animal.dart';
import '../components/road_obstacle.dart';
import '../components/scenery_prop.dart';
import '../components/traffic_vehicle.dart';
import '../difficulty_config.dart';
import '../environments.dart';
import '../game_config.dart';
import '../kamote_game.dart';
import '../painting/vehicle_painter.dart';
import 'animal_crossing_manager.dart';
import 'traffic_spawner.dart';

enum ChallengeType {
  dogCrossing,
  catCrossing,
  chickenCrossing,
  tricycleMerge,
  suddenBraking,
  roadWorks,
  potholeZone,
  fallingCargo,
  cashTrail,
  fuelEmergency,
  ltoSurprise,
  vipConvoy,
}

class ChallengeDef {
  const ChallengeDef({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.reward,
    required this.cooldown,
    required this.weights,
    this.dangerous = false,
  });

  final ChallengeType type;
  final String title;
  final String subtitle;
  final Color color;

  /// Base completion reward (scaled by difficulty). 0 = no completion reward.
  final int reward;

  /// Seconds before this challenge can be picked again.
  final double cooldown;

  /// Selection weight for Easy, Medium, Hard.
  final List<double> weights;

  /// Triggers the "SLOW DOWN, IDOL!" meme.
  final bool dangerous;

  double weightFor(DifficultyLevel level) => weights[level.index];
}

class Challenges {
  Challenges._();

  static const List<ChallengeDef> all = [
    ChallengeDef(
      type: ChallengeType.dogCrossing,
      title: 'ANIMAL CROSSING AHEAD!',
      subtitle: 'May aso! Dodge the dog.',
      color: Color(0xFFFFB74D),
      reward: 30,
      cooldown: 25,
      weights: [3, 3, 3],
    ),
    ChallengeDef(
      type: ChallengeType.catCrossing,
      title: 'ANIMAL CROSSING AHEAD!',
      subtitle: 'Pusang ligaw! Watch the cat.',
      color: Color(0xFFFFB74D),
      reward: 35,
      cooldown: 25,
      weights: [2, 3, 3],
    ),
    ChallengeDef(
      type: ChallengeType.chickenCrossing,
      title: 'ANIMAL CROSSING AHEAD!',
      subtitle: 'Mga manok tumatawid!',
      color: Color(0xFFFFB74D),
      reward: 30,
      cooldown: 30,
      weights: [2, 2, 2],
    ),
    ChallengeDef(
      type: ChallengeType.tricycleMerge,
      title: 'TRICYCLE INCOMING!',
      subtitle: 'Tricycle merging from the roadside.',
      color: Color(0xFF4FC3F7),
      reward: 40,
      cooldown: 30,
      weights: [2, 3, 3],
    ),
    ChallengeDef(
      type: ChallengeType.suddenBraking,
      title: 'BRAKE LIGHTS AHEAD!',
      subtitle: 'Car ahead is stopping suddenly.',
      color: Color(0xFFFF5252),
      reward: 45,
      cooldown: 30,
      weights: [1, 2, 3],
    ),
    ChallengeDef(
      type: ChallengeType.roadWorks,
      title: 'ROAD WORKS, IDOL!',
      subtitle: 'One lane closed ahead.',
      color: Color(0xFFFF9100),
      reward: 60,
      cooldown: 40,
      weights: [2, 2, 3],
      dangerous: true,
    ),
    ChallengeDef(
      type: ChallengeType.potholeZone,
      title: 'POTHOLE ZONE!',
      subtitle: 'Lubak everywhere. Steer carefully.',
      color: Color(0xFFA1887F),
      reward: 50,
      cooldown: 35,
      weights: [2, 2, 3],
      dangerous: true,
    ),
    ChallengeDef(
      type: ChallengeType.fallingCargo,
      title: 'FALLING CARGO!',
      subtitle: 'Watch the truck ahead.',
      color: Color(0xFFD7B98E),
      reward: 50,
      cooldown: 35,
      weights: [1, 2, 3],
    ),
    ChallengeDef(
      type: ChallengeType.cashTrail,
      title: 'CASH RUSH!',
      subtitle: 'Grab every bill for a bonus.',
      color: Color(0xFF69F0AE),
      reward: 80,
      cooldown: 30,
      weights: [3, 2, 2],
    ),
    ChallengeDef(
      type: ChallengeType.fuelEmergency,
      title: 'FUEL EMERGENCY!',
      subtitle: 'Jerry can ahead. Go get it!',
      color: Color(0xFFFFEB3B),
      reward: 0,
      cooldown: 20,
      weights: [0, 0, 0],
    ),
    ChallengeDef(
      type: ChallengeType.ltoSurprise,
      title: 'LTO CHECKPOINT AHEAD!',
      subtitle: 'Keep right (lanes 3–4) to slip through.',
      color: Color(0xFF82B1FF),
      reward: 60,
      cooldown: 60,
      weights: [1, 1, 2],
    ),
    ChallengeDef(
      type: ChallengeType.vipConvoy,
      title: 'VIP CONVOY!',
      subtitle: 'Convoy blocking the right lanes.',
      color: Color(0xFF90A4AE),
      reward: 70,
      cooldown: 45,
      weights: [0.5, 1, 2],
      dangerous: true,
    ),
  ];

  static ChallengeDef of(ChallengeType type) => all.firstWhere((d) => d.type == type);
}

/// Weighted random challenge selection with per-type cooldowns. Pure Dart
/// so it can be unit tested.
class ChallengePicker {
  ChallengePicker({math.Random? random}) : _rnd = random ?? math.Random();

  final math.Random _rnd;
  final Map<ChallengeType, double> _lastRun = {};

  bool onCooldown(ChallengeType type, double now) {
    final last = _lastRun[type];
    return last != null && now - last < Challenges.of(type).cooldown;
  }

  void markRun(ChallengeType type, double now) => _lastRun[type] = now;

  ChallengeType? pick({required double now, required DifficultyLevel level, required bool chaseActive}) {
    final options = <ChallengeDef>[
      for (final d in Challenges.all)
        if (d.weightFor(level) > 0 && !onCooldown(d.type, now))
          if (!(d.type == ChallengeType.ltoSurprise && chaseActive)) d,
    ];
    if (options.isEmpty) return null;
    final total = options.fold<double>(0, (a, d) => a + d.weightFor(level));
    var roll = _rnd.nextDouble() * total;
    for (final d in options) {
      roll -= d.weightFor(level);
      if (roll <= 0) return d.type;
    }
    return options.last.type;
  }

  void reset() => _lastRun.clear();
}

class _PendingDrop {
  _PendingDrop(this.truck, this.dropY, this.challengeId);

  final TrafficVehicle truck;
  final double dropY;
  final int challengeId;
}

/// Runs the random highway challenges. Every challenge plans its hazards
/// through the spawner's lane planner, so a challenge is only started when
/// it can be survived; otherwise it waits and retries briefly.
class HighwayChallengeManager extends Component with HasGameReference<KamoteGame> {
  HighwayChallengeManager({math.Random? random})
    : _rnd = random ?? math.Random(),
      picker = ChallengePicker(random: random);

  final math.Random _rnd;
  final ChallengePicker picker;
  late final AnimalCrossingManager animals = AnimalCrossingManager(game, _rnd);
  final List<_PendingDrop> _drops = [];

  /// Disabled by tests that place entities by hand.
  bool enabled = true;

  /// Challenges never start before this distance.
  static const double startMeters = 220;

  double _nextIn = 0;
  ChallengeType? _pending;

  /// True while a challenge waits for room or is about to be picked, so the
  /// spawner can leave the road a little lighter for it.
  bool get challengeSoon => enabled && (_pending != null || _nextIn < 2.5);
  double _pendingTimeout = 0;
  double _lastFuelEmergency = -1e9;
  final List<ChallengeType> started = [];

  void reset() {
    picker.reset();
    _drops.clear();
    _pending = null;
    _nextIn = game.difficulty.challengeIntervalSeconds * 0.8;
    _lastFuelEmergency = -1e9;
    started.clear();
  }

  /// Forgets queued challenges and cargo drops (the road was rebuilt).
  void clearPending() {
    _drops.clear();
    _pending = null;
  }

  @override
  void update(double dt) {
    if (!game.state.acceptsGameplay) return;
    // No highway challenges in the tunnel; it has its own hazards.
    if (game.underground.active) return;
    _processDrops();
    if (!enabled || game.distance.meters < startMeters) return;
    final now = game.runTime;

    if (game.fuel.fraction < 0.22 && now - _lastFuelEmergency > Challenges.of(ChallengeType.fuelEmergency).cooldown) {
      if (forceStart(ChallengeType.fuelEmergency)) _lastFuelEmergency = now;
    }

    final pending = _pending;
    if (pending != null) {
      // Let the road clear so the challenge can be placed fairly.
      _sp.holdHazardsFor(0.5);
      if (forceStart(pending)) {
        _pending = null;
      } else {
        _pendingTimeout -= dt;
        if (_pendingTimeout <= 0) _pending = null;
      }
      return;
    }
    _nextIn -= dt;
    if (_nextIn > 0) return;
    _nextIn = game.difficulty.challengeIntervalSeconds * (0.75 + _rnd.nextDouble() * 0.5);
    _pending = picker.pick(now: now, level: game.difficulty.level, chaseActive: game.chase.active);
    _pendingTimeout = 8;
  }

  /// Tries to start [type] right now. Returns false if it cannot be placed
  /// fairly at the moment.
  bool forceStart(ChallengeType type) {
    if (!game.state.acceptsGameplay || game.scrollSpeed < 80) return false;
    final ok = switch (type) {
      ChallengeType.dogCrossing => animals.trySpawn(AnimalKind.dog),
      ChallengeType.catCrossing => animals.trySpawn(AnimalKind.cat),
      ChallengeType.chickenCrossing => animals.trySpawn(AnimalKind.chicken),
      ChallengeType.tricycleMerge => _tricycleMerge(),
      ChallengeType.suddenBraking => _suddenBraking(),
      ChallengeType.roadWorks => _roadWorks(),
      ChallengeType.potholeZone => _potholeZone(),
      ChallengeType.fallingCargo => _fallingCargo(),
      ChallengeType.cashTrail => _cashTrail(),
      ChallengeType.fuelEmergency => _fuelEmergency(),
      ChallengeType.ltoSurprise => _ltoSurprise(),
      ChallengeType.vipConvoy => _vipConvoy(),
    };
    if (ok) {
      picker.markRun(type, game.runTime);
      started.add(type);
      game.onChallengeStarted(Challenges.of(type));
    }
    return ok;
  }

  TrafficSpawner get _sp => game.spawner;
  LaneScheduler get _sch => game.spawner.scheduler;
  double get _scroll => game.scrollSpeed;

  int _begin(ChallengeType type, int pieces) {
    final def = Challenges.of(type);
    return game.challengeRewards.begin(name: def.title.replaceAll('!', ''), reward: def.reward, pieces: pieces);
  }

  int _rightLane() => game.player.lane >= 2 ? game.player.lane : 2 + _rnd.nextInt(2);

  // ------------------------------------------------------------ challenges

  bool _tricycleMerge() {
    final lane = _rightLane();
    if (_sp.laneHasTrafficAhead(lane) || _sp.laneHasTrafficAhead(3)) return false;
    const type = VehicleType.tricycle;
    final size = VehiclePainter.sizeOf(type);
    const kmh = 24.0;
    final y0 = GameConfig.spawnY - size.height / 2;
    final w = _sp.windowFor(y0, size.height, _scroll - GameConfig.kmhToPixelsPerSecond(kmh));
    if (w == null || !_sch.canBlock(lane, w.start, w.end)) return false;
    _sch.block(lane, w.start, w.end);
    game.world.add(
      TrafficVehicle(
          type: type,
          lane: lane,
          oncoming: false,
          speedKmh: kmh,
          color: VehiclePainter.defaultColor(type, _rnd.nextInt(3)),
          variant: 0,
          mergeFromX: GameConfig.roadRight + 28,
          mergeStartY: game.hudTopInset + 10,
        )
        ..y = y0
        ..challengeId = _begin(ChallengeType.tricycleMerge, 1),
    );
    return true;
  }

  bool _suddenBraking() {
    final lane = _rightLane();
    if (_sp.laneHasTrafficAhead(lane)) return false;
    if (game.world.children.any((c) => c is RoadObstacle && c.lane == lane && c.y < game.playerY)) return false;
    final type = [VehicleType.car, VehicleType.van, VehicleType.jeepney][_rnd.nextInt(3)];
    final size = VehiclePainter.sizeOf(type);
    final kmh = VehiclePainter.cruiseKmh(type);
    final y0 = GameConfig.spawnY - size.height / 2;
    final brakeY = game.hudTopInset + 60 + _rnd.nextDouble() * 80;
    final brakedFwd = GameConfig.kmhToPixelsPerSecond(6);
    var fwd = GameConfig.kmhToPixelsPerSecond(kmh);
    final w = _sp.windowForMotion(y0, size.height, (y, dt) {
      fwd = TrafficVehicle.nextForward(fwd, y, brakeY, brakedFwd, dt);
      return _scroll - fwd;
    });
    if (w == null || !_sch.canBlock(lane, w.start, w.end)) return false;
    _sch.block(lane, w.start, w.end);
    game.world.add(
      TrafficVehicle(
          type: type,
          lane: lane,
          oncoming: false,
          speedKmh: kmh,
          color: VehiclePainter.defaultColor(type, _rnd.nextInt(8)),
          variant: _rnd.nextInt(4),
          brakeAtY: brakeY,
        )
        ..y = y0
        ..challengeId = _begin(ChallengeType.suddenBraking, 1),
    );
    return true;
  }

  bool _roadWorks() {
    // Usually an outer lane, so the narrowing reads like real road works.
    final lane = _rnd.nextDouble() < 0.7 ? (_rnd.nextBool() ? 0 : 3) : 1 + _rnd.nextInt(2);
    if (_sp.laneHasTrafficAhead(lane)) return false;
    const cones = 6;
    const gap = 52.0;
    const y0 = GameConfig.spawnY;
    const zoneHeight = cones * gap + 22;
    final w = _sp.windowFor(y0 - zoneHeight / 2 + 11, zoneHeight, _scroll);
    if (w == null || !_sch.canBlock(lane, w.start, w.end)) return false;
    _sch.block(lane, w.start, w.end);
    final id = _begin(ChallengeType.roadWorks, cones + 1);
    game.world.add(
      RoadObstacle(type: ObstacleType.barrier, lane: lane)
        ..y = y0
        ..challengeId = id,
    );
    for (var i = 1; i <= cones; i++) {
      game.world.add(
        RoadObstacle(type: ObstacleType.cone, lane: lane)
          ..y = y0 - i * gap
          ..challengeId = id,
      );
    }
    // Warning sign on the nearest shoulder.
    final left = lane < 2;
    game.world.add(
      SceneryProp(type: PropType.warningSign, onLeft: left, variant: 0)
        ..position = Vector2(left ? GameConfig.roadLeft - 22 : GameConfig.roadRight + 22, y0 + 80),
    );
    return true;
  }

  bool _potholeZone() {
    final planned = <(int, double)>[];
    for (var i = 0; i < 7; i++) {
      final y = GameConfig.spawnY - i * 70.0;
      final lanes = List.generate(GameConfig.laneCount, (l) => l)..shuffle(_rnd);
      for (final lane in lanes) {
        if (game.world.children.any((c) => c is TrafficVehicle && c.lane == lane && c.y < game.playerY)) continue;
        final w = _sp.windowFor(y, 28, _scroll);
        if (w == null || !_sch.canBlock(lane, w.start, w.end)) continue;
        _sch.block(lane, w.start, w.end);
        planned.add((lane, y));
        break;
      }
    }
    if (planned.length < 3) return false;
    final id = _begin(ChallengeType.potholeZone, planned.length);
    for (final (lane, y) in planned) {
      game.world.add(
        RoadObstacle(type: ObstacleType.pothole, lane: lane)
          ..y = y
          ..challengeId = id,
      );
    }
    return true;
  }

  bool _fallingCargo() {
    final lane = _rightLane();
    if (_sp.laneHasTrafficAhead(lane)) return false;
    const type = VehicleType.truck;
    final size = VehiclePainter.sizeOf(type);
    const kmh = 34.0;
    final screen = _scroll - GameConfig.kmhToPixelsPerSecond(kmh);
    final y0 = GameConfig.spawnY - size.height / 2;
    final dropY = game.hudTopInset + 70;
    final truckWindow = _sp.windowFor(y0, size.height, screen);
    if (truckWindow == null || screen <= 40) return false;
    final dropAfter = (dropY - y0) / screen;
    final boxY = dropY + size.height / 2 + 16;
    final rel = _sp.windowFor(boxY, 22, _scroll);
    if (rel == null) return false;
    final boxWindow = LaneWindow(rel.start + dropAfter, rel.end + dropAfter);
    if (!_sch.canBlock(lane, truckWindow.start, truckWindow.end) ||
        !_sch.canBlock(lane, boxWindow.start, boxWindow.end)) {
      return false;
    }
    _sch.block(lane, truckWindow.start, truckWindow.end);
    _sch.block(lane, boxWindow.start, boxWindow.end);
    final id = _begin(ChallengeType.fallingCargo, 2);
    final truck =
        TrafficVehicle(
            type: type,
            lane: lane,
            oncoming: false,
            speedKmh: kmh,
            color: VehiclePainter.defaultColor(type, _rnd.nextInt(3)),
            variant: 0,
          )
          ..y = y0
          ..challengeId = id;
    game.world.add(truck);
    _drops.add(_PendingDrop(truck, dropY, id));
    return true;
  }

  void _processDrops() {
    for (final drop in _drops.toList()) {
      final truck = drop.truck;
      if (truck.isRemoved || truck.isRemoving) {
        _drops.remove(drop);
        continue;
      }
      if (truck.y >= drop.dropY) {
        _drops.remove(drop);
        game.world.add(
          RoadObstacle(type: ObstacleType.box, lane: truck.lane)
            ..y = truck.y + truck.height / 2 + 16
            ..challengeId = drop.challengeId,
        );
        game.onCargoDropped(truck);
      }
    }
  }

  bool _cashTrail() {
    if (_scroll < 80) return false;
    var lane = _rnd.nextInt(GameConfig.laneCount);
    const count = 12;
    final plan = <(int, double, LaneWindow)>[];
    var y = GameConfig.spawnY;
    for (var i = 0; i < count; i++) {
      if (i > 0 && i % 3 == 0) {
        // Weave one lane over, with extra room to make the switch.
        final dir = lane == 0 ? 1 : (lane == GameConfig.laneCount - 1 ? -1 : (_rnd.nextBool() ? 1 : -1));
        lane += dir;
        // Room to switch lanes scales with speed so every bill is reachable.
        y -= math.max(90, _scroll * 0.45);
      }
      final w = _sp.windowFor(y, 18, _scroll);
      if (w == null || !_sch.isClear(lane, w.start, w.end)) return false;
      plan.add((lane, y, w));
      y -= 40;
    }
    final id = _begin(ChallengeType.cashTrail, count);
    for (final (l, by, w) in plan) {
      _sch.reserve(l, w.start, w.end);
      _sp.spawnBill(lane: l, y: by, value: 20, phase: by * 0.02, challengeId: id);
    }
    return true;
  }

  bool _fuelEmergency() {
    if (game.world.children.any((c) => c is FuelCollectible)) return false;
    const y = GameConfig.spawnY;
    final w = _sp.windowFor(y, 32, _scroll);
    if (w == null) return false;
    // Prefer the risky oncoming lanes, but always a clear one.
    for (final lane in [1, 0, 2, 3]) {
      if (!_sch.isClear(lane, w.start, w.end)) continue;
      _sch.reserve(lane, w.start, w.end);
      game.world.add(FuelCollectible(lane: lane)..y = y);
      return true;
    }
    return false;
  }

  bool _ltoSurprise() {
    if (game.chase.active || game.world.children.any((c) => c is LtoCheckpoint)) return false;
    game.world.add(LtoCheckpoint(surprise: true)..y = GameConfig.spawnY - 40);
    return true;
  }

  bool _vipConvoy() {
    if (_sp.laneHasTrafficAhead(2) || _sp.laneHasTrafficAhead(3)) return false;
    if (game.world.children.any((c) => c is RoadObstacle && c.lane >= 2 && c.y < game.playerY)) return false;
    const type = VehicleType.suv;
    final size = VehiclePainter.sizeOf(type);
    const kmh = 36.0;
    const rowGap = 112.0;
    final groupH = rowGap + size.height;
    final topY = GameConfig.spawnY - size.height / 2;
    final centerY = topY - rowGap / 2;
    final w = _sp.windowFor(centerY, groupH, _scroll - GameConfig.kmhToPixelsPerSecond(kmh));
    if (w == null || !_sch.canBlockAll(const [2, 3], w.start, w.end)) return false;
    _sch.block(2, w.start, w.end);
    _sch.block(3, w.start, w.end);
    final id = _begin(ChallengeType.vipConvoy, 4);
    for (var row = 0; row < 2; row++) {
      for (final lane in const [2, 3]) {
        game.world.add(
          TrafficVehicle(
              type: type,
              lane: lane,
              oncoming: false,
              speedKmh: kmh,
              color: const Color(0xFF1B1B1B),
              variant: row * 2 + lane,
            )
            ..y = topY - row * rowGap
            ..challengeId = id,
        );
      }
    }
    return true;
  }
}
