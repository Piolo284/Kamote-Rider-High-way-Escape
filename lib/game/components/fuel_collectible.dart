import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../game_config.dart';
import 'highway_entity.dart';

/// Red jerry can that restores part of the tank.
class FuelCollectible extends HighwayEntity with EntityHitbox, Collectible {
  FuelCollectible({required int lane}) : super(size: Vector2(26, 32), lane: lane, priority: 15) {
    x = GameConfig.laneCenter(lane);
  }

  static final Paint _p = Paint()..isAntiAlias = true;
  static final Paint _s = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;
  static final Vector2 _hit = Vector2(30, 34);

  double _time = 0;
  double _pickup = -1;
  Sprite? _override;

  double get time => _time;

  /// Seconds since being picked up, or -1.
  double get pickupTime => _pickup;

  @override
  Vector2 get hitSize => _hit;

  @override
  Future<void> onLoad() async {
    _override = game.sprites.get('fuel');
    add(buildHitbox());
  }

  @override
  void onCollected() => _pickup = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_pickup >= 0) {
      _pickup += dt;
      scale.setAll(1 + _pickup * 3);
      if (_pickup > 0.3) removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final alpha = _pickup >= 0 ? (1 - _pickup / 0.3).clamp(0.0, 1.0) : 1.0;
    // Pulsing glow makes fuel distinct from cash at a glance.
    final pulse = 0.5 + 0.5 * math.sin(_time * 6);
    _p.color = Color.fromRGBO(255, 235, 59, (0.25 + 0.25 * pulse) * alpha);
    canvas.drawCircle(Offset(width / 2, height / 2), width * (0.9 + 0.15 * pulse), _p);

    final sprite = _override;
    if (sprite != null) {
      sprite.render(canvas, size: size, overridePaint: Paint()..color = Color.fromRGBO(255, 255, 255, alpha));
      return;
    }
    _p.color = Color.fromRGBO(0, 0, 0, 0.3 * alpha);
    canvas.drawRRect(RRect.fromLTRBR(3, 4, width + 3, height + 3, const Radius.circular(4)), _p);
    _p.color = Color.fromRGBO(211, 47, 47, alpha);
    canvas.drawRRect(RRect.fromLTRBR(0, 4, width, height, const Radius.circular(4)), _p);
    _s.color = Color.fromRGBO(183, 28, 28, alpha);
    canvas.drawRRect(RRect.fromLTRBR(5, 0, width - 9, 8, const Radius.circular(3)), _s);
    _p.color = Color.fromRGBO(255, 214, 0, alpha);
    canvas.drawRect(Rect.fromLTWH(width - 8, 1, 5, 6), _p);
    // Embossed X.
    _s.color = Color.fromRGBO(255, 255, 255, 0.6 * alpha);
    canvas.drawLine(Offset(6, 11), Offset(width - 6, height - 4), _s);
    canvas.drawLine(Offset(width - 6, 11), Offset(6, height - 4), _s);
  }
}
