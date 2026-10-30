import 'dart:math' as math;

import 'package:flame/components.dart';

import '../components/cash_collectible.dart';
import '../components/effects.dart';
import '../components/fuel_collectible.dart';
import '../components/road_obstacle.dart';
import '../components/traffic_vehicle.dart';
import '../environments.dart';
import '../game_config.dart';
import '../kamote_game.dart';
import '../painting/vehicle_painter.dart';
import 'difficulty.dart';

/// Time interval (in game seconds) during which something occupies the
/// player's row in a lane.
class LaneWindow {
  const LaneWindow(this.start, this.end);

  final double start;
  final double end;

  bool overlaps(double s, double e) => start < e && s < end;
}

/// Fairness planner. Every blocking hazard is registered with the time
/// window in which it crosses the rider's row. A new hazard is rejected if
/// it would leave fewer than `laneCount - maxBlocked` lanes open at any
/// moment (padded by reaction time), so there is always an escape lane.
class LaneScheduler {
  LaneScheduler({
    this.laneCount = GameConfig.laneCount,
    this.maxBlocked = 2,
    this.padBefore = 0.5,
    this.padAfter = 0.25,
  }) : _blocked = List.generate(laneCount, (_) => <LaneWindow>[]),
       _reserved = List.generate(laneCount, (_) => <LaneWindow>[]);

  final int laneCount;
  final int maxBlocked;

  /// Clear road kept before each hazard; set from the difficulty.
  double padBefore;
  final double padAfter;
  final List<List<LaneWindow>> _blocked;
  final List<List<LaneWindow>> _reserved;

  bool canBlock(int lane, double start, double end) {
    final s = start - padBefore;
    final e = end + padAfter;
    if (_reserved[lane].any((w) => w.overlaps(s, e))) return false;
    var others = 0;
    for (var l = 0; l < laneCount; l++) {
      if (l != lane && _blocked[l].any((w) => w.overlaps(s, e))) others++;
    }
    return others + 1 <= maxBlocked;
  }

  /// Like [canBlock] for a hazard that covers several lanes at once
  /// (convoys, animals). The total stays within [maxBlocked].
  bool canBlockAll(Iterable<int> lanes, double start, double end) {
    final set = lanes.toSet();
    final s = start - padBefore;
    final e = end + padAfter;
    for (final l in set) {
      if (_reserved[l].any((w) => w.overlaps(s, e))) return false;
    }
    var others = 0;
    for (var l = 0; l < laneCount; l++) {
      if (!set.contains(l) && _blocked[l].any((w) => w.overlaps(s, e))) others++;
    }
    return others + set.length <= maxBlocked;
  }

  /// True when no lane has any hazard during the (padded) window.
  bool allClear(double start, double end) {
    for (var l = 0; l < laneCount; l++) {
      if (!isClear(l, start, end)) return false;
    }
    return true;
  }

  void block(int lane, double start, double end) => _blocked[lane].add(LaneWindow(start, end));

  /// True when no hazard occupies [lane] during the (padded) window.
  bool isClear(int lane, double start, double end) {
    final s = start - padBefore;
    final e = end + padAfter;
    return !_blocked[lane].any((w) => w.overlaps(s, e));
  }

  /// Protects a pickup so later hazards will not be placed on top of it.
  void reserve(int lane, double start, double end) => _reserved[lane].add(LaneWindow(start, end));

  /// Number of lanes blocked at instant [t] (unpadded). Used by tests.
  int blockedLanesAt(double t) => _blocked.where((windows) => windows.any((w) => w.start <= t && t <= w.end)).length;

  void prune(double now) {
    for (final list in [..._blocked, ..._reserved]) {
      list.removeWhere((w) => w.end < now - 1);
    }
  }

  void reset() {
    for (final list in [..._blocked, ..._reserved]) {
      list.clear();
    }
  }
}

/// Spawns traffic, obstacles, cash and fuel ahead of the rider.
class TrafficSpawner extends Component with HasGameReference<KamoteGame> {
  TrafficSpawner({math.Random? random}) : _rnd = random ?? math.Random();

  final math.Random _rnd;
  final LaneScheduler scheduler = LaneScheduler();
  final List<CashCollectible> _cashPool = [];

  /// Disabled in tests that place entities by hand.
  bool enabled = true;

  static const int maxVehicles = 16;
  static const int maxObstacles = 10;
  static const int maxCash = 40;

  double _rowMeters = 0;
  double _cashMeters = 0;
  double _fuelSeconds = 0;
  int _activeCash = 0;
  double _holdUntil = 0;

  math.Random get random => _rnd;

  /// Pauses ordinary traffic/obstacle rows (e.g. while animals cross).
  void holdHazardsFor(double seconds) => _holdUntil = math.max(_holdUntil, game.runTime + seconds);

  bool get isHoldingHazards => game.runTime < _holdUntil;

  void reset() {
    scheduler.reset();
    scheduler.padBefore = game.difficulty.reactionPadding;
    _holdUntil = 0;
    _rowMeters = 25;
    _cashMeters = 12;
    _fuelSeconds = 9;
    _activeCash = 0;
  }

  @override
  void update(double dt) {
    if (!enabled || !game.state.acceptsGameplay) return;
    final now = game.runTime;
    scheduler.prune(now);
    final meters = game.frameMeters;
    final difficulty = Difficulty.at(game.distance.meters, game.difficulty);

    _cashMeters -= meters;
    if (_cashMeters <= 0) {
      _cashMeters = (45 + _rnd.nextDouble() * 40) * game.difficulty.cashIntervalMultiplier;
      _spawnCashLine();
    }

    _fuelSeconds -= dt;
    if (_fuelSeconds <= 0) {
      _fuelSeconds = _spawnFuel() ? _nextFuelInterval() : 1.0;
    }

    if (game.distance.meters < GameConfig.hazardFreeStartMeters || isHoldingHazards) return;
    _rowMeters -= meters;
    if (_rowMeters <= 0) {
      _rowMeters = difficulty.rowSpacingMeters * (0.75 + _rnd.nextDouble() * 0.5);
      _spawnRow(difficulty);
    }
  }

  double _nextFuelInterval() {
    final km = game.distance.meters / 1000;
    var seconds = 11.0 + km * 0.5 + _rnd.nextDouble() * 3;
    if (game.fuel.fraction < 0.35) seconds *= 0.65;
    return (seconds * game.difficulty.fuelIntervalMultiplier).clamp(7.0, 22.0);
  }

  // ------------------------------------------------------------ timing

  double get _playerTop => game.playerY - 32;
  double get _playerBottom => game.playerY + 32;

  /// Predicts when an entity at [spawnY] of [height] moving down at
  /// [speed] px/s will overlap the rider's row. Null if it will not arrive.
  LaneWindow? windowFor(double spawnY, double height, double speed) => _windowFor(spawnY, height, speed);

  /// Like [windowFor] for scripted motion: [screenSpeedAt] returns the
  /// downward screen speed for a given y and time step. Simulated at 30 Hz
  /// for up to 8 seconds.
  LaneWindow? windowForMotion(double spawnY, double height, double Function(double y, double dt) screenSpeedAt) {
    const dt = 1 / 30;
    var y = spawnY;
    double? start;
    for (var t = 0.0; t < 8; t += dt) {
      final overlapping = y + height / 2 >= _playerTop && y - height / 2 <= _playerBottom;
      if (overlapping) start ??= t;
      if (start != null && !overlapping) return LaneWindow(game.runTime + start, game.runTime + t);
      y += screenSpeedAt(y, dt) * dt;
    }
    return start == null ? null : LaneWindow(game.runTime + start, game.runTime + 8);
  }

  LaneWindow? _windowFor(double spawnY, double height, double speed) {
    if (speed < 40) return null;
    final now = game.runTime;
    final start = now + (_playerTop - (spawnY + height / 2)) / speed;
    final end = now + (_playerBottom - (spawnY - height / 2)) / speed;
    return LaneWindow(start, end);
  }

  // ------------------------------------------------------------ spawning

  /// Chance, relative to the row's vehicle chance, of one more oncoming
  /// vehicle in the two left lanes on top of the row's usual traffic.
  static const double extraOncomingShare = 0.5;

  void _spawnRow(Difficulty d) {
    final env = Environments.visual(game.visualEnvironmentIndex);
    if (_rnd.nextDouble() < d.vehicleChance) _trySpawnVehicle(d, env);
    // Busier left lanes on the highway. The tunnel keeps its own pace, and
    // the extra traffic gives way while a challenge needs room.
    if (!game.underground.showsTunnel &&
        !game.challenges.challengeSoon &&
        _rnd.nextDouble() < d.vehicleChance * extraOncomingShare) {
      _trySpawnVehicle(d, env, oncoming: true);
    }
    if (_rnd.nextDouble() < d.obstacleChance) _trySpawnObstacle(env);
  }

  void _trySpawnVehicle(Difficulty d, EnvironmentTheme env, {bool? oncoming}) {
    final vehicles = game.world.children.whereType<TrafficVehicle>().toList();
    if (vehicles.length >= maxVehicles) return;
    oncoming ??= _rnd.nextDouble() < d.oncomingShare;
    final type = _weighted(env.vehicleWeights);
    final size = VehiclePainter.sizeOf(type);
    final lanes = oncoming ? [0, 1] : [2, 3];
    lanes.shuffle(_rnd);
    final obstacles = game.world.children.whereType<RoadObstacle>();

    for (final lane in lanes) {
      final double speedKmh;
      final double spawnY;
      if (oncoming) {
        speedKmh = d.oncomingSpeedKmh + _rnd.nextDouble() * 8;
        final screenSpeed = game.scrollSpeed + GameConfig.kmhToPixelsPerSecond(speedKmh);
        // Spawn far enough up that the rider always gets the difficulty's
        // minimum warning time.
        spawnY =
            math.min(GameConfig.spawnY, game.playerY - screenSpeed * game.difficulty.oncomingWarningSeconds) -
            size.height / 2;
        // Oncoming cars must not drive through obstacles still ahead.
        if (obstacles.any((o) => o.lane == lane && o.y < game.playerY)) continue;
        if (vehicles.any((v) => v.lane == lane && v.y < 40)) continue;
      } else {
        speedKmh = VehiclePainter.cruiseKmh(type) * (0.95 + _rnd.nextDouble() * 0.1);
        spawnY = GameConfig.spawnY - size.height / 2;
        // Keep a gap behind the previous vehicle in this lane.
        if (vehicles.any((v) => v.lane == lane && v.y - v.height / 2 < spawnY + size.height / 2 + 70)) continue;
        // Never spawn on top of a work zone still entering the screen.
        if (obstacles.any((o) => o.lane == lane && o.y < 60)) continue;
      }
      final forward = GameConfig.kmhToPixelsPerSecond(speedKmh) * (oncoming ? -1 : 1);
      final window = _windowFor(spawnY, size.height, game.scrollSpeed - forward);
      if (window == null || !scheduler.canBlock(lane, window.start, window.end)) continue;

      scheduler.block(lane, window.start, window.end);
      final vehicle = TrafficVehicle(
        type: type,
        lane: lane,
        oncoming: oncoming,
        speedKmh: speedKmh,
        color: VehiclePainter.defaultColor(type, _rnd.nextInt(8)),
        variant: _rnd.nextInt(4),
      )..y = spawnY;
      game.world.add(vehicle);
      if (oncoming) {
        final secondsUntilVisible = (-spawnY - size.height / 2) / (game.scrollSpeed - forward);
        game.world.add(OncomingWarning(x: GameConfig.laneCenter(lane), duration: secondsUntilVisible.clamp(0.5, 1.5)));
      }
      return;
    }
  }

  void _trySpawnObstacle(EnvironmentTheme env) {
    final obstacles = game.world.children.whereType<RoadObstacle>();
    if (obstacles.length >= maxObstacles) return;
    final type = _weighted(env.obstacleWeights);
    final lanes = List.generate(GameConfig.laneCount, (i) => i)..shuffle(_rnd);
    final vehicles = game.world.children.whereType<TrafficVehicle>();
    const spawnY = GameConfig.spawnY;
    for (final lane in lanes) {
      // Avoid traffic driving through a static obstacle.
      if (vehicles.any((v) => v.lane == lane && v.y < game.playerY)) continue;
      final window = _windowFor(spawnY, 28, game.scrollSpeed);
      if (window == null || !scheduler.canBlock(lane, window.start, window.end)) continue;
      scheduler.block(lane, window.start, window.end);
      game.world.add(RoadObstacle(type: type, lane: lane)..y = spawnY);
      return;
    }
  }

  void _spawnCashLine() {
    if (_activeCash >= maxCash || game.scrollSpeed < 40) return;
    final count = 3 + _rnd.nextInt(4);
    const spacing = 34.0;
    final startLane = _rnd.nextInt(GameConfig.laneCount);
    // Optionally drift one lane halfway through for a zig-zag pattern.
    final drift = _rnd.nextDouble() < 0.35 ? (startLane >= 2 ? -1 : 1) : 0;
    final lineHeight = spacing * count;
    final window = _windowFor(GameConfig.spawnY - lineHeight / 2, lineHeight, game.scrollSpeed);
    if (window == null) return;
    if (!scheduler.isClear(startLane, window.start, window.end)) return;
    if (drift != 0 && !scheduler.isClear(startLane + drift, window.start, window.end)) return;

    final km = game.distance.meters / 1000;
    for (var i = 0; i < count; i++) {
      final lane = (drift != 0 && i >= count ~/ 2) ? startLane + drift : startLane;
      final roll = _rnd.nextDouble() - math.min(0.25, km * 0.03);
      final value = roll < 0.6 ? 20 : (roll < 0.9 ? 50 : 100);
      spawnBill(lane: lane, y: GameConfig.spawnY - i * spacing, value: value, phase: i * 0.6);
    }
  }

  /// Adds one (pooled) paper bill.
  CashCollectible spawnBill({
    required int lane,
    required double y,
    required int value,
    double phase = 0,
    int challengeId = 0,
  }) {
    final bill = _cashPool.isNotEmpty ? _cashPool.removeLast() : (CashCollectible()..onRecycle = _recycle);
    bill.configure(lane: lane, y: y, value: value, phase: phase);
    bill.challengeId = challengeId;
    _activeCash++;
    game.world.add(bill);
    return bill;
  }

  /// True if no vehicle is in [lane] between the top of the world and the rider.
  bool laneHasTrafficAhead(int lane) =>
      game.world.children.any((c) => c is TrafficVehicle && c.lane == lane && c.y < game.playerY + 60);

  /// True if any traffic or obstacle is between the top and the rider.
  bool roadHasHazardsAhead({double above = 0}) => game.world.children.any(
    (c) => (c is TrafficVehicle || c is RoadObstacle) && (c as PositionComponent).y < game.playerY - above,
  );

  void _recycle(CashCollectible bill) {
    _activeCash = math.max(0, _activeCash - 1);
    if (_cashPool.length < maxCash) _cashPool.add(bill);
  }

  bool _spawnFuel() {
    if (game.scrollSpeed < 40) return false;
    final lanes = [2, 3, 1, 0];
    if (_rnd.nextBool()) lanes.swap(0, 1);
    const spawnY = GameConfig.spawnY;
    final window = _windowFor(spawnY, 32, game.scrollSpeed);
    if (window == null) return false;
    for (final lane in lanes) {
      if (!scheduler.isClear(lane, window.start, window.end)) continue;
      scheduler.reserve(lane, window.start, window.end);
      game.world.add(FuelCollectible(lane: lane)..y = spawnY);
      return true;
    }
    return false;
  }

  T _weighted<T>(Map<T, int> weights) {
    final total = weights.values.fold<int>(0, (a, b) => a + b);
    var roll = _rnd.nextInt(total);
    for (final e in weights.entries) {
      roll -= e.value;
      if (roll < 0) return e.key;
    }
    return weights.keys.first;
  }
}

extension on List<int> {
  void swap(int a, int b) {
    final t = this[a];
    this[a] = this[b];
    this[b] = t;
  }
}
