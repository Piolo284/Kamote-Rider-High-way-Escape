import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../environments.dart';
import '../game_config.dart';
import '../systems/collision_system.dart';
import 'highway_entity.dart';

/// Static road hazard. Potholes and cones are minor; barriers bring the LTO.
class RoadObstacle extends HighwayEntity with EntityHitbox, Hazard {
  RoadObstacle({required this.type, required int lane})
    : super(size: _sizeOf(type), lane: lane, priority: type == ObstacleType.pothole ? 8 : 12) {
    x = GameConfig.laneCenter(lane);
    _hitSize = switch (type) {
      ObstacleType.pothole => Vector2(size.x * 0.7, size.y * 0.6),
      ObstacleType.cone => Vector2(size.x * 0.7, size.y * 0.7),
      ObstacleType.barrier => Vector2(size.x * 0.9, size.y * 0.8),
      ObstacleType.box => Vector2(size.x * 0.8, size.y * 0.8),
    };
  }

  static Vector2 _sizeOf(ObstacleType type) => switch (type) {
    ObstacleType.pothole => Vector2(40, 28),
    ObstacleType.cone => Vector2(20, 20),
    ObstacleType.barrier => Vector2(56, 22),
    ObstacleType.box => Vector2(26, 22),
  };

  final ObstacleType type;
  late final Vector2 _hitSize;

  // Knock-away animation once hit.
  double _flyTime = -1;
  double _flyDir = 1;

  static final Paint _p = Paint()..isAntiAlias = true;

  @override
  Vector2 get hitSize => _hitSize;

  @override
  HazardKind get hazardKind => switch (type) {
    ObstacleType.pothole => HazardKind.pothole,
    ObstacleType.cone => HazardKind.cone,
    ObstacleType.barrier => HazardKind.barrier,
    ObstacleType.box => HazardKind.debris,
  };

  @override
  Future<void> onLoad() async => add(buildHitbox());

  @override
  void onStruck(CollisionOutcome outcome) {
    if (type == ObstacleType.pothole) return;
    _flyTime = 0;
    _flyDir = game.player.x < x ? 1 : -1;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flyTime >= 0) {
      _flyTime += dt;
      x += _flyDir * 160 * dt;
      y -= 120 * dt;
      angle += _flyDir * 9 * dt;
      if (_flyTime > 0.6) removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final w = width;
    final h = height;
    switch (type) {
      case ObstacleType.pothole:
        _p.color = const Color(0xFF5D5D5D);
        canvas.drawOval(Rect.fromLTWH(0, 0, w, h), _p);
        _p.color = const Color(0xFF1E1E1E);
        canvas.drawOval(Rect.fromLTWH(4, 3, w - 8, h - 6), _p);
        _p.color = const Color(0xFF2F3A44);
        canvas.drawOval(Rect.fromLTWH(w * 0.3, h * 0.35, w * 0.35, h * 0.3), _p);
      case ObstacleType.cone:
        _p.color = const Color(0x44000000);
        canvas.drawCircle(Offset(w / 2 + 2, h / 2 + 3), w / 2, _p);
        _p.color = const Color(0xFFFF6D00);
        canvas.drawRect(Rect.fromLTWH(1, 1, w - 2, h - 2), _p);
        _p.color = const Color(0xFFFF9100);
        canvas.drawCircle(Offset(w / 2, h / 2), w * 0.38, _p);
        _p.color = const Color(0xFFFFFFFF);
        canvas.drawCircle(Offset(w / 2, h / 2), w * 0.25, _p);
        _p.color = const Color(0xFFFF6D00);
        canvas.drawCircle(Offset(w / 2, h / 2), w * 0.13, _p);
      case ObstacleType.barrier:
        _p.color = const Color(0x44000000);
        canvas.drawRect(Rect.fromLTWH(3, 4, w, h), _p);
        _p.color = const Color(0xFFF5F5F5);
        canvas.drawRRect(RRect.fromLTRBR(0, 0, w, h, const Radius.circular(3)), _p);
        _p.color = const Color(0xFFFF3D00);
        final stripes = math.max(3, (w / 12).floor());
        for (var i = 0; i < stripes; i += 2) {
          final x0 = w * i / stripes;
          final path = Path()
            ..moveTo(x0, 0)
            ..lineTo(x0 + w / stripes, 0)
            ..lineTo(x0 + w / stripes - 6, h)
            ..lineTo(x0 - 6, h)
            ..close();
          canvas.save();
          canvas.clipRRect(RRect.fromLTRBR(0, 0, w, h, const Radius.circular(3)));
          canvas.drawPath(path, _p);
          canvas.restore();
        }
        _p.color = const Color(0xFFFFEB3B);
        canvas.drawCircle(Offset(5, h / 2), 2.5, _p);
        canvas.drawCircle(Offset(w - 5, h / 2), 2.5, _p);
      case ObstacleType.box:
        // Harmless cardboard balikbayan-style box that fell off a truck.
        _p.color = const Color(0x44000000);
        canvas.drawRect(Rect.fromLTWH(3, 4, w, h), _p);
        _p.color = const Color(0xFFC49A6C);
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _p);
        _p.color = const Color(0xFFA67C52);
        canvas.drawRect(Rect.fromLTWH(0, h / 2 - 1, w, 2), _p);
        canvas.drawRect(Rect.fromLTWH(w / 2 - 3, 0, 6, h), _p);
        _p.color = const Color(0xFFD7B98E);
        canvas.drawRect(Rect.fromLTWH(w / 2 - 2, 0, 4, h), _p);
        _p.color = const Color(0xFF5D4037);
        canvas.drawRect(Rect.fromLTWH(3, 3, 7, 2), _p);
        canvas.drawRect(Rect.fromLTWH(w - 10, h - 5, 7, 2), _p);
    }
  }
}
