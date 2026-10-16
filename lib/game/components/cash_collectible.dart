import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, FontWeight;

import '../game_config.dart';
import 'highway_entity.dart';

/// A stylized paper bill. Instances are pooled by the spawner.
class CashCollectible extends HighwayEntity with EntityHitbox, Collectible {
  CashCollectible() : super(size: Vector2(34, 18), priority: 14);

  static const List<int> denominations = [20, 50, 100];
  static const Map<int, Color> _colors = {20: Color(0xFFFF9800), 50: Color(0xFFE53935), 100: Color(0xFF7E57C2)};

  static final Map<int, TextPainter> _labels = {};
  static final Paint _p = Paint()..isAntiAlias = true;
  static final Vector2 _hit = Vector2(30, 22);

  int value = 20;
  double _phase = 0;
  double _pickup = -1;
  Sprite? _override;
  void Function(CashCollectible)? onRecycle;

  @override
  Vector2 get hitSize => _hit;

  @override
  Future<void> onLoad() async {
    _override = game.sprites.get('cash');
    add(buildHitbox());
  }

  /// Prepares a pooled instance for reuse.
  void configure({required int lane, required double y, required int value, required double phase}) {
    this.lane = lane;
    this.value = value;
    x = GameConfig.laneCenter(lane);
    this.y = y;
    previousY = y;
    _phase = phase;
    _pickup = -1;
    collected = false;
    challengeId = 0;
    passedPlayer = false;
    scale.setAll(1);
  }

  @override
  void onCollected() => _pickup = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _phase += dt * 4;
    if (_pickup >= 0) {
      _pickup += dt;
      y -= 260 * dt;
      scale.setAll(1 + _pickup * 2.5);
      if (_pickup > 0.25) removeFromParent();
    }
  }

  @override
  void onRemove() {
    super.onRemove();
    onRecycle?.call(this);
  }

  @override
  void render(Canvas canvas) {
    final flip = math.cos(_phase).abs() * 0.6 + 0.4;
    final alpha = _pickup >= 0 ? (1 - _pickup / 0.25).clamp(0.0, 1.0) : 1.0;
    canvas.save();
    canvas.translate(width / 2, height / 2);
    canvas.scale(flip, 1);
    canvas.translate(-width / 2, -height / 2);
    final sprite = _override;
    if (sprite != null) {
      sprite.render(canvas, size: size, overridePaint: Paint()..color = Color.fromRGBO(255, 255, 255, alpha));
      canvas.restore();
      return;
    }
    final color = _colors[value] ?? _colors[20]!;
    _p.color = Color.fromRGBO(0, 0, 0, 0.25 * alpha);
    canvas.drawRRect(RRect.fromLTRBR(2, 3, width + 2, height + 3, const Radius.circular(2)), _p);
    _p.color = color.withValues(alpha: alpha);
    canvas.drawRRect(RRect.fromLTRBR(0, 0, width, height, const Radius.circular(2)), _p);
    _p.color = Color.fromRGBO(255, 255, 255, 0.55 * alpha);
    canvas.drawRRect(RRect.fromLTRBR(2, 2, width - 2, height - 2, const Radius.circular(1.5)), _p);
    _p.color = color.withValues(alpha: alpha);
    canvas.drawRRect(RRect.fromLTRBR(3.5, 3.5, width - 3.5, height - 3.5, const Radius.circular(1)), _p);
    _p.color = Color.fromRGBO(255, 255, 255, 0.35 * alpha);
    canvas.drawCircle(Offset(width * 0.27, height / 2), 4.2, _p);
    final label = _labels.putIfAbsent(value, () {
      return TextPainter(
        text: TextSpan(
          text: '$value',
          style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 9, fontWeight: FontWeight.w900),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
    label.paint(canvas, Offset(width * 0.66 - label.width / 2, height / 2 - label.height / 2));
    canvas.restore();
  }
}
