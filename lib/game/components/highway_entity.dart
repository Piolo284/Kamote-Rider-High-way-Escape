import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../game_config.dart';
import '../kamote_game.dart';
import '../systems/collision_system.dart';

/// Base class for everything that lives on the scrolling highway.
///
/// Entities move down the screen at the road's scroll speed minus their own
/// [forwardSpeed] (positive = same direction as the player, negative =
/// oncoming). Off-screen entities remove themselves so spawning stays bounded.
abstract class HighwayEntity extends PositionComponent with HasGameReference<KamoteGame> {
  HighwayEntity({required Vector2 size, this.lane = -1, this.forwardSpeed = 0, super.priority})
    : super(size: size, anchor: Anchor.center);

  int lane;

  /// World units per second along the road.
  double forwardSpeed;

  /// Y position before this frame's movement, used for impact classification.
  double previousY = 0;

  /// Downward screen speed this frame.
  double get screenSpeed => game.scrollSpeed - forwardSpeed * game.trafficFlow;

  @override
  void onMount() {
    super.onMount();
    previousY = y;
  }

  @override
  void update(double dt) {
    super.update(dt);
    previousY = y;
    y += screenSpeed * dt;
    if (y - height / 2 > game.viewHeight + 80 || y + height / 2 < GameConfig.spawnY - 1500) {
      removeFromParent();
    }
  }
}

/// Something the player can crash into.
mixin Hazard on PositionComponent {
  HazardKind get hazardKind;

  /// True for traffic driving toward the player.
  bool get isOncoming => false;

  /// Set once this hazard has produced a collision so it never counts twice.
  bool processed = false;

  /// Challenge this hazard belongs to (0 = ordinary traffic).
  int challengeId = 0;

  /// Set once the hazard has moved past the rider's row (dodge bookkeeping).
  bool passedPlayer = false;

  /// Smallest side gap to the rider while level with them (near misses).
  double minGap = double.infinity;

  Rect get hitRect;
  Rect get previousHitRect;

  /// Visual/physical reaction after the game has resolved the collision.
  void onStruck(CollisionOutcome outcome) {}
}

/// Adds a centered passive hitbox of [hitSize] and the rects the collision
/// classifier needs.
mixin EntityHitbox on HighwayEntity {
  Vector2 get hitSize;

  Rect get hitRect => Rect.fromCenter(center: Offset(x, y), width: hitSize.x, height: hitSize.y);

  Rect get previousHitRect => Rect.fromCenter(center: Offset(x, previousY), width: hitSize.x, height: hitSize.y);

  RectangleHitbox buildHitbox() =>
      RectangleHitbox(size: hitSize, position: (size - hitSize) / 2, collisionType: CollisionType.passive);
}

/// Something the player can pick up exactly once.
mixin Collectible on HighwayEntity {
  bool collected = false;

  /// Challenge this pickup belongs to (0 = none). Missing it fails the challenge.
  int challengeId = 0;
  bool passedPlayer = false;

  /// Called by the game the first time the player touches this item.
  void onCollected();
}
