import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, FontWeight, Shadow;

import '../game_config.dart';
import '../kamote_game.dart';
import '../painting/vehicle_painter.dart';

/// Short-lived text that pops up and floats away ("+₱50", "PRRRT!").
class FloatingText extends PositionComponent {
  FloatingText(String text, {required Vector2 position, Color color = const Color(0xFFFFFFFF), double fontSize = 16})
    : _painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Color(0xAA000000), offset: Offset(1.5, 1.5), blurRadius: 2)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
      super(position: position, anchor: Anchor.center, priority: 50);

  final TextPainter _painter;
  double _age = 0;
  static const double _life = 0.9;

  TextPainter get painter => _painter;

  /// Pop-in / fade-out size multiplier for the current age.
  double get popScale {
    final t = _age / _life;
    return t < 0.15 ? 0.6 + t / 0.15 * 0.5 : (t > 0.75 ? 1.1 * (1 - (t - 0.75) / 0.25) : 1.1);
  }

  @override
  void update(double dt) {
    _age += dt;
    y -= 55 * dt;
    if (_age >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final s = popScale;
    canvas.save();
    canvas.scale(s);
    _painter.paint(canvas, Offset(-_painter.width / 2, -_painter.height / 2));
    canvas.restore();
  }
}

/// Cartoon impact burst: star flash plus flying debris. Deliberately
/// non-graphic.
class ImpactBurst extends PositionComponent {
  ImpactBurst({required Vector2 position, this.big = false, Color color = const Color(0xFFFFEB3B)})
    : _color = color,
      super(position: position, anchor: Anchor.center, priority: 49) {
    final rnd = math.Random();
    for (var i = 0; i < (big ? 14 : 7); i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final speed = (big ? 140 : 90) + rnd.nextDouble() * 120;
      _debris.add(_Debris(Offset(math.cos(a) * speed, math.sin(a) * speed), rnd.nextDouble() * 6));
    }
  }

  final bool big;
  final Color _color;
  final List<_Debris> _debris = [];
  double _age = 0;
  static final Paint _p = Paint()..isAntiAlias = true;

  double get _life => big ? 0.9 : 0.45;

  @override
  void update(double dt) {
    _age += dt;
    for (final d in _debris) {
      d.pos += d.vel * dt;
      d.vel *= 0.92;
      d.spin += dt * 10;
    }
    if (_age >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / _life).clamp(0.0, 1.0);
    final alpha = 1 - t;
    // Star flash.
    final r = (big ? 46 : 24) * (0.5 + t);
    final star = Path();
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8;
      final rr = i.isEven ? r : r * 0.45;
      final p = Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    _p.color = _color.withValues(alpha: alpha * 0.85);
    canvas.drawPath(star, _p);
    _p.color = const Color(0xFFFFFFFF).withValues(alpha: alpha);
    canvas.drawCircle(Offset.zero, r * 0.3, _p);
    for (final d in _debris) {
      _p.color = const Color(0xFF90A4AE).withValues(alpha: alpha);
      canvas.save();
      canvas.translate(d.pos.dx, d.pos.dy);
      canvas.rotate(d.spin);
      canvas.drawRect(const Rect.fromLTWH(-3, -2, 6, 4), _p);
      canvas.restore();
    }
  }
}

class _Debris {
  _Debris(this.vel, this.spin);
  Offset pos = Offset.zero;
  Offset vel;
  double spin;
}

/// Fictional ambulance that responds in the head-on ending.
class AmbulanceResponder extends PositionComponent with HasGameReference<KamoteGame> {
  AmbulanceResponder() : super(size: Vector2(46, 86), anchor: Anchor.center, priority: 33);

  double _time = 0;
  bool arrived = false;
  late Vector2 _target;
  Sprite? _override;

  double get time => _time;

  @override
  Future<void> onLoad() async {
    _override = game.sprites.get('ambulance');
    final p = game.player;
    final lane = p.lane >= 1 ? p.lane - 1 : p.lane + 1;
    x = GameConfig.laneCenter(lane);
    y = -120;
    _target = Vector2(x, p.y - 40);
  }

  @override
  void update(double dt) {
    _time += dt;
    if (!arrived) {
      final dy = _target.y - y;
      y += math.min(dy, math.max(120, dy * 3.2) * dt);
      if (dy < 2) arrived = true;
    }
  }

  @override
  void render(Canvas canvas) {
    final sprite = _override;
    if (sprite != null) {
      canvas.save();
      canvas.translate(width, height);
      canvas.rotate(math.pi);
      sprite.render(canvas, size: size);
      canvas.restore();
    } else {
      VehiclePainter.paintAmbulance(canvas, size.toSize(), sirenPhase: _time * 3);
    }
  }
}

/// Small warning chevron at the top of a lane before an oncoming vehicle
/// enters the screen, so head-on threats are always telegraphed.
class OncomingWarning extends PositionComponent with HasGameReference<KamoteGame> {
  OncomingWarning({required double x, required this.duration})
    : super(position: Vector2(x, 0), size: Vector2(30, 26), anchor: Anchor.topCenter, priority: 45);

  final double duration;
  double _age = 0;
  static final Paint _p = Paint()..isAntiAlias = true;

  bool get blinkVisible => (_age * 8).floor().isEven;

  @override
  void update(double dt) {
    _age += dt;
    y = game.hudTopInset;
    if (_age >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if ((_age * 8).floor().isOdd) return;
    final path = Path()
      ..moveTo(width / 2, height)
      ..lineTo(width, 4)
      ..lineTo(0, 4)
      ..close();
    _p.color = const Color(0xDDFF1744);
    canvas.drawPath(path, _p);
    _p.color = const Color(0xFFFFFFFF);
    canvas.drawRect(Rect.fromLTWH(width / 2 - 1.5, 7, 3, 9), _p);
    canvas.drawCircle(Offset(width / 2, 19.5), 1.8, _p);
  }
}

/// Sparkle burst when cash or fuel is picked up.
class PickupSparkle extends PositionComponent {
  PickupSparkle({required Vector2 position, required this.color, int count = 10})
    : super(position: position, anchor: Anchor.center, priority: 48) {
    final rnd = math.Random();
    for (var i = 0; i < count; i++) {
      final a = i * math.pi * 2 / count + rnd.nextDouble() * 0.4;
      final speed = 70 + rnd.nextDouble() * 60;
      _sparks.add(_Debris(Offset(math.cos(a) * speed, math.sin(a) * speed), rnd.nextDouble() * 3));
    }
  }

  final Color color;
  final List<_Debris> _sparks = [];
  double _age = 0;
  static const double _life = 0.45;
  static final Paint _p = Paint()..isAntiAlias = true;
  static final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void update(double dt) {
    _age += dt;
    for (final s in _sparks) {
      s.pos += s.vel * dt;
      s.vel *= 0.9;
      s.spin += dt * 8;
    }
    if (_age >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / _life).clamp(0.0, 1.0);
    final alpha = 1 - t;
    _ring.color = color.withValues(alpha: 0.7 * alpha);
    canvas.drawCircle(Offset.zero, 6 + t * 26, _ring);
    _p.color = color.withValues(alpha: alpha);
    for (final s in _sparks) {
      canvas.save();
      canvas.translate(s.pos.dx, s.pos.dy);
      canvas.rotate(s.spin);
      // Four-point twinkle.
      canvas.drawRect(const Rect.fromLTWH(-3.5, -1, 7, 2), _p);
      canvas.drawRect(const Rect.fromLTWH(-1, -3.5, 2, 7), _p);
      canvas.restore();
    }
  }
}
