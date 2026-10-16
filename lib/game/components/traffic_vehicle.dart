import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';

import '../environments.dart';
import '../game_config.dart';
import '../painting/vehicle_painter.dart';
import '../systems/collision_system.dart';
import 'highway_entity.dart';

/// A car, bus, truck, jeepney, tricycle, van or SUV in a lane.
///
/// Challenges can script two extra behaviours, both predictable so the
/// spawner can plan around them:
/// * [brakeAtY]: brakes hard once it reaches that screen height.
/// * [mergeFromX]: starts on the roadside and merges into [lane] with its
///   turn signal on once it reaches [mergeStartY].
class TrafficVehicle extends HighwayEntity with EntityHitbox, Hazard {
  TrafficVehicle({
    required this.type,
    required int lane,
    required this.oncoming,
    required double speedKmh,
    required this.color,
    required this.variant,
    this.brakeAtY,
    this.brakedSpeedKmh = 6,
    this.mergeFromX,
    this.mergeStartY = 0,
  }) : super(
         size: VehiclePainter.sizeOf(type).toVector2(),
         lane: lane,
         forwardSpeed: GameConfig.kmhToPixelsPerSecond(speedKmh) * (oncoming ? -1 : 1),
         priority: 20,
       ) {
    x = mergeFromX ?? GameConfig.laneCenter(lane);
    _hitSize = Vector2(size.x * 0.82, size.y * 0.9);
  }

  /// Deceleration used for scripted braking, in world units per second².
  static const double brakeDecel = 420;
  static const double mergeSeconds = 1.1;

  /// One simulation step of scripted braking, shared with the spawner's
  /// arrival prediction so plans match what actually happens.
  static double nextForward(double forward, double y, double? brakeAtY, double brakedForward, double dt) {
    if (brakeAtY == null || y < brakeAtY || forward <= brakedForward) return forward;
    return math.max(brakedForward, forward - brakeDecel * dt);
  }

  final double? brakeAtY;
  final double brakedSpeedKmh;
  final double? mergeFromX;
  final double mergeStartY;
  bool braking = false;
  double _mergeT = -1;

  final VehicleType type;
  final bool oncoming;
  final Color color;
  final int variant;
  late final Vector2 _hitSize;
  Sprite? _override;
  double _shake = 0;
  double _time = 0;

  @override
  Vector2 get hitSize => _hitSize;

  @override
  HazardKind get hazardKind => HazardKind.vehicle;

  @override
  bool get isOncoming => oncoming;

  @override
  Future<void> onLoad() async {
    _override = game.sprites.get('vehicle_${type.name}');
    add(buildHitbox());
  }

  @override
  void onStruck(CollisionOutcome outcome) {
    _shake = 0.35;
    if (!oncoming) forwardSpeed *= 1.15;
  }

  @override
  void update(double dt) {
    final brakeY = brakeAtY;
    if (brakeY != null && !oncoming) {
      final next = nextForward(forwardSpeed, y, brakeY, GameConfig.kmhToPixelsPerSecond(brakedSpeedKmh), dt);
      if (next < forwardSpeed && !braking) {
        braking = true;
        game.onVehicleBraking(this);
      }
      forwardSpeed = next;
    }
    super.update(dt);
    _time += dt;
    if (_shake > 0) _shake = math.max(0, _shake - dt);
    final fromX = mergeFromX;
    if (fromX != null && _mergeT < 1) {
      if (_mergeT < 0 && y >= mergeStartY) _mergeT = 0;
      if (_mergeT >= 0) {
        _mergeT = math.min(1, _mergeT + dt / mergeSeconds);
        final eased = _mergeT * _mergeT * (3 - 2 * _mergeT);
        x = fromX + (GameConfig.laneCenter(lane) - fromX) * eased;
      }
    }
  }

  bool get _merging => mergeFromX != null && _mergeT < 1;

  @override
  void render(Canvas canvas) {
    // Gentle suspension sway so traffic feels alive.
    final sway = math.sin(_time * 2.3 + variant) * 0.5;
    canvas.save();
    canvas.translate(sway + (_shake > 0 ? math.sin(_time * 60) * 2.5 * _shake / 0.35 : 0), 0);
    final sprite = _override;
    if (sprite != null) {
      if (oncoming) {
        canvas.save();
        canvas.translate(width, height);
        canvas.rotate(math.pi);
        sprite.render(canvas, size: size);
        canvas.restore();
      } else {
        sprite.render(canvas, size: size);
      }
    } else {
      final signal = _merging ? ((mergeFromX! > GameConfig.laneCenter(lane)) ? -1 : 1) : 0;
      VehiclePainter.paint(
        canvas,
        size.toSize(),
        type,
        color,
        facingDown: oncoming,
        variant: variant,
        braking: braking,
        signal: signal,
        blinkPhase: _time,
      );
    }
    canvas.restore();
  }
}
