import 'dart:ui';

import 'package:flame/components.dart';

import '../game_config.dart';
import 'highway_entity.dart';

/// An open manhole: ride into it to fall into the secret LRT tunnel.
/// Not a hazard, so it never causes a crash or a chase.
class OpenManhole extends HighwayEntity with EntityHitbox {
  OpenManhole({required int lane}) : super(size: Vector2(34, 24), lane: lane, priority: 7) {
    x = GameConfig.laneCenter(lane);
  }

  /// Small target so it takes a deliberate line to fall in.
  static final Vector2 _hit = Vector2(16, 12);
  static final Paint _p = Paint()..isAntiAlias = true;

  /// Set once the rider has fallen in.
  bool used = false;

  @override
  Vector2 get hitSize => _hit;

  @override
  Future<void> onLoad() async => add(buildHitbox());

  /// Top-down art; the 3D view lays it flat on the road.
  @override
  void render(Canvas canvas) {
    final w = width;
    final h = height;
    // Iron rim, black shaft and a hint of the ladder.
    _p.color = const Color(0xFF6D6F72);
    canvas.drawOval(Rect.fromLTWH(w * 0.05, h * 0.08, w * 0.62, h * 0.84), _p);
    _p.color = const Color(0xFF050608);
    canvas.drawOval(Rect.fromLTWH(w * 0.1, h * 0.16, w * 0.52, h * 0.68), _p);
    _p.color = const Color(0x55B388FF);
    canvas.drawOval(Rect.fromLTWH(w * 0.2, h * 0.32, w * 0.32, h * 0.36), _p);
    _p.color = const Color(0xFF8D6E63);
    canvas.drawRect(Rect.fromLTWH(w * 0.3, h * 0.2, w * 0.03, h * 0.6), _p);
    canvas.drawRect(Rect.fromLTWH(w * 0.4, h * 0.2, w * 0.03, h * 0.6), _p);
    // The lifted cover lying beside the hole.
    _p.color = const Color(0xFF4A4C4F);
    canvas.drawOval(Rect.fromLTWH(w * 0.62, h * 0.2, w * 0.36, h * 0.6), _p);
    _p.color = const Color(0x33FFFFFF);
    canvas.drawRect(Rect.fromLTWH(w * 0.68, h * 0.48, w * 0.24, h * 0.04), _p);
  }
}
