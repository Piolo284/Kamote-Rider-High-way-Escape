import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../game_config.dart';
import '../kamote_game.dart';
import '../systems/collision_system.dart';
import '../systems/pursuit_system.dart';
import 'highway_entity.dart';

enum PursuitPhase { approaching, holding, retreating }

/// An LTO officer who rides up beside the rider and holds one lane for a
/// few seconds. Ramming them is a violation and costs a heart.
///
/// The officer moves with the rider, not with the road: the game has
/// already booked their lane with the traffic planner, so an escape lane
/// always stays open while they hold it.
class PursuitOfficer extends PositionComponent with HasGameReference<KamoteGame>, CollisionCallbacks, Hazard {
  PursuitOfficer({required this.lane}) : super(size: Vector2(34, 68), anchor: Anchor.center, priority: 31);

  static final Vector2 hitSize = Vector2(18, 46);

  /// How far behind the rider the officer starts.
  static const double startBehind = 170;

  final int lane;
  PursuitPhase phase = PursuitPhase.approaching;
  double _t = 0;
  double _time = 0;
  double _previousY = 0;

  double get time => _time;

  /// 0 while far behind, 1 once level with the rider (for the warning).
  double get closeness => phase == PursuitPhase.approaching ? (_t / PursuitSystem.approachSeconds).clamp(0.0, 1.0) : 1;

  @override
  HazardKind get hazardKind => HazardKind.officer;

  @override
  Rect get hitRect => Rect.fromCenter(center: Offset(x, y), width: hitSize.x, height: hitSize.y);

  @override
  Rect get previousHitRect => Rect.fromCenter(center: Offset(x, _previousY), width: hitSize.x, height: hitSize.y);

  @override
  Future<void> onLoad() async {
    x = GameConfig.laneCenter(lane);
    y = game.player.y + startBehind;
    _previousY = y;
    add(RectangleHitbox(size: hitSize, position: (size - hitSize) / 2, collisionType: CollisionType.passive));
  }

  /// Gives up the lane early (rammed, or the run moved underground).
  void retreat() => phase = PursuitPhase.retreating;

  @override
  void onStruck(CollisionOutcome outcome) => retreat();

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    _previousY = y;
    final playerY = game.player.y;
    switch (phase) {
      case PursuitPhase.approaching:
        _t += dt;
        final k = _easeOut((_t / PursuitSystem.approachSeconds).clamp(0.0, 1.0));
        y = playerY + startBehind * (1 - k);
        if (_t >= PursuitSystem.approachSeconds) {
          phase = PursuitPhase.holding;
          _t = 0;
        }
      case PursuitPhase.holding:
        _t += dt;
        y = playerY + math.sin(_time * 3) * 3;
        if (_t >= PursuitSystem.holdSeconds) retreat();
      case PursuitPhase.retreating:
        y += 220 * dt;
        if (y > playerY + startBehind + 80) removeFromParent();
    }
  }
}

double _easeOut(double t) => 1 - (1 - t) * (1 - t);
