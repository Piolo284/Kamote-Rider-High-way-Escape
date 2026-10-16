import 'dart:math' as math;
import 'dart:ui';

import '../components/cash_collectible.dart';
import '../components/effects.dart';
import '../components/fuel_collectible.dart';
import '../components/road_animal.dart';
import '../components/road_obstacle.dart';
import '../environments.dart';
import 'camera3d.dart';
import 'shapes.dart';

/// 3D views of road obstacles, animals, pickups and pop-up effects.
class SmallViews {
  SmallViews._();

  static final Paint _p = Paint()..isAntiAlias = true;
  static final Paint _s = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  // ------------------------------------------------------------ obstacles

  /// Potholes are flat, so they are drawn with the road decals.
  static void drawPothole(Canvas c, Camera3D cam, RoadObstacle o) {
    Shapes.decal(c, cam, Rect.fromCenter(center: Offset(o.x, o.y), width: o.width, height: o.height), (c) {
      c.translate(o.x - o.width / 2, o.y - o.height / 2);
      o.render(c);
    });
  }

  static void drawObstacle(Canvas c, Camera3D cam, RoadObstacle o, {double alpha = 1}) {
    final fly = o.flyTime;
    final lift = fly >= 0 ? math.sin((fly / 0.6).clamp(0.0, 1.0) * math.pi) * 34 : 0.0;
    switch (o.type) {
      case ObstacleType.pothole:
        drawPothole(c, cam, o);
      case ObstacleType.cone:
        if (fly < 0) Shapes.shadow(c, cam, o.x, o.y, 16, 16, opacity: 0.3 * alpha);
        Shapes.billboard(c, cam, o.x, o.y, 18, 24, _cone, lift: lift, angle: o.angle, alpha: alpha);
      case ObstacleType.barrier:
        if (fly < 0) Shapes.shadow(c, cam, o.x, o.y, o.width, 10, opacity: 0.3 * alpha);
        Shapes.box(
          c,
          cam,
          left: o.x - o.width / 2,
          right: o.x + o.width / 2,
          far: o.y - 4,
          near: o.y + 4,
          bottom: lift + 5,
          top: lift + 22,
          color: const Color(0xFFF5F5F5),
          nearFace: _barrierFace,
          sideFace: _barrierFace,
          alpha: alpha,
        );
        // Legs.
        if (fly < 0) {
          for (final dx in [-o.width / 2 + 5, o.width / 2 - 9]) {
            Shapes.box(
              c,
              cam,
              left: o.x + dx,
              right: o.x + dx + 4,
              far: o.y - 2,
              near: o.y + 2,
              top: 5,
              color: const Color(0xFF424242),
              alpha: alpha,
            );
          }
        }
      case ObstacleType.box:
        if (fly < 0) Shapes.shadow(c, cam, o.x, o.y, o.width, o.height, opacity: 0.3 * alpha);
        Shapes.box(
          c,
          cam,
          left: o.x - o.width / 2,
          right: o.x + o.width / 2,
          far: o.y - o.height / 2,
          near: o.y + o.height / 2,
          bottom: lift,
          top: lift + 18,
          color: const Color(0xFFC49A6C),
          roof: (c) {
            c.translate(o.x - o.width / 2, o.y - o.height / 2);
            o.render(c);
          },
          nearFace: _boxFace,
          sideFace: _boxFace,
          alpha: alpha,
        );
    }
  }

  static void _cone(Canvas c, Size s) {
    final w = s.width;
    final h = s.height;
    _p.color = const Color(0xFFE65100);
    c.drawRect(Rect.fromLTWH(0, h - 3, w, 3), _p);
    _p.color = const Color(0xFFFF6D00);
    final cone = Path()
      ..moveTo(w * 0.42, 0)
      ..lineTo(w * 0.58, 0)
      ..lineTo(w * 0.86, h - 3)
      ..lineTo(w * 0.14, h - 3)
      ..close();
    c.drawPath(cone, _p);
    _p.color = const Color(0xFFFFFFFF);
    c.drawPath(
      Path()
        ..moveTo(w * 0.33, h * 0.38)
        ..lineTo(w * 0.67, h * 0.38)
        ..lineTo(w * 0.72, h * 0.55)
        ..lineTo(w * 0.28, h * 0.55)
        ..close(),
      _p,
    );
    _p.color = const Color(0x33000000);
    c.drawPath(
      Path()
        ..moveTo(w * 0.5, 0)
        ..lineTo(w * 0.58, 0)
        ..lineTo(w * 0.86, h - 3)
        ..lineTo(w * 0.6, h - 3)
        ..close(),
      _p,
    );
  }

  static void _barrierFace(Canvas c, Size s) {
    final w = s.width;
    final h = s.height;
    c.save();
    c.clipRect(Rect.fromLTWH(0, 0, w, h));
    _p.color = const Color(0xFFFF3D00);
    for (var x = -h; x < w + h; x += 12) {
      c.drawPath(
        Path()
          ..moveTo(x, 0)
          ..lineTo(x + 6, 0)
          ..lineTo(x + 6 + h * 0.6, h)
          ..lineTo(x + h * 0.6, h)
          ..close(),
        _p,
      );
    }
    c.restore();
    _p.color = const Color(0xFFFFEB3B);
    c.drawCircle(const Offset(4, 2), 2.5, _p);
    c.drawCircle(Offset(w - 4, 2), 2.5, _p);
  }

  static void _boxFace(Canvas c, Size s) {
    _p.color = const Color(0xFFD7B98E);
    c.drawRect(Rect.fromLTWH(s.width / 2 - 2.5, 0, 5, s.height), _p);
    _p.color = const Color(0xFF5D4037);
    c.drawRect(Rect.fromLTWH(3, s.height * 0.6, s.width * 0.25, 2), _p);
    c.drawRect(Rect.fromLTWH(3, s.height * 0.6 + 3.5, s.width * 0.18, 2), _p);
  }

  // ------------------------------------------------------------ animals

  static void drawAnimal(Canvas c, Camera3D cam, RoadAnimal a, {double alpha = 1}) {
    final (w, h) = switch (a.kind) {
      AnimalKind.dog => (46.0, 30.0),
      AnimalKind.cat => (36.0, 24.0),
      AnimalKind.chicken => (52.0, 20.0),
    };
    final lift = a.hop > 0 ? math.sin(a.hop / 0.4 * math.pi) * 10 : 0.0;
    Shapes.shadow(c, cam, a.x, a.y, w * 0.8, 14, opacity: 0.28 * alpha);
    Shapes.billboard(
      c,
      cam,
      a.x,
      a.y,
      w,
      h,
      (c, size) {
        c.save();
        if (!a.facingRight) {
          c.translate(size.width, 0);
          c.scale(-1, 1);
        }
        switch (a.kind) {
          case AnimalKind.dog:
            _dog(c, size, a.variant, a.animPhase);
          case AnimalKind.cat:
            _cat(c, size, a.variant, a.animPhase);
          case AnimalKind.chicken:
            _chickens(c, size, a.animPhase);
        }
        c.restore();
        final bubble = a.bubble;
        if (bubble != null) _bubble(c, size, bubble);
      },
      lift: lift,
      alpha: alpha,
    );
  }

  static void _legs(Canvas c, Color color, List<double> xs, double top, double bottom, double phase, double width) {
    _s
      ..color = color
      ..strokeWidth = width;
    for (var i = 0; i < xs.length; i++) {
      final swing = math.sin(phase + i * math.pi) * 3;
      c.drawLine(Offset(xs[i], top), Offset(xs[i] + swing, bottom), _s);
    }
  }

  static void _dog(Canvas c, Size s, int variant, double phase) {
    const colors = [Color(0xFFB57A45), Color(0xFF8D6E63), Color(0xFFE0C097)];
    final fur = colors[variant % colors.length];
    final dark = Shapes.shade(fur, 0.3);
    final w = s.width;
    final h = s.height;
    _legs(c, dark, [w * 0.24, w * 0.34, w * 0.62, w * 0.72], h * 0.55, h - 1, phase, 3.4);
    // Tail wagging up.
    _s
      ..color = fur
      ..strokeWidth = 3.2;
    final wag = math.sin(phase * 1.5) * 3;
    c.drawLine(Offset(w * 0.18, h * 0.42), Offset(w * 0.04, h * 0.2 + wag), _s);
    _p.color = fur;
    c.drawOval(Rect.fromLTWH(w * 0.16, h * 0.3, w * 0.62, h * 0.34), _p);
    _p.color = const Color(0x33FFFFFF);
    c.drawOval(Rect.fromLTWH(w * 0.3, h * 0.5, w * 0.36, h * 0.12), _p);
    // Head, snout, ear, eye.
    _p.color = fur;
    c.drawCircle(Offset(w * 0.8, h * 0.28), h * 0.2, _p);
    c.drawOval(Rect.fromLTWH(w * 0.84, h * 0.26, w * 0.14, h * 0.15), _p);
    _p.color = dark;
    c.drawOval(Rect.fromLTWH(w * 0.72, h * 0.12, w * 0.08, h * 0.24), _p);
    _p.color = const Color(0xFF3E2723);
    c.drawCircle(Offset(w * 0.97, h * 0.31), 1.8, _p);
    c.drawCircle(Offset(w * 0.84, h * 0.24), 1.4, _p);
  }

  static void _cat(Canvas c, Size s, int variant, double phase) {
    const colors = [Color(0xFF9E9E9E), Color(0xFFFFA726), Color(0xFF424242)];
    final fur = colors[variant % colors.length];
    final dark = Shapes.shade(fur, 0.3);
    final w = s.width;
    final h = s.height;
    _legs(c, dark, [w * 0.26, w * 0.36, w * 0.6, w * 0.7], h * 0.55, h - 1, phase, 2.6);
    _s
      ..color = fur
      ..strokeWidth = 2.6;
    final curl = math.sin(phase * 0.8) * 2;
    c.drawArc(Rect.fromLTWH(w * 0.02, h * 0.05 + curl, w * 0.2, h * 0.5), math.pi * 0.5, math.pi * 1.1, false, _s);
    _p.color = fur;
    c.drawOval(Rect.fromLTWH(w * 0.18, h * 0.34, w * 0.58, h * 0.3), _p);
    _p.color = dark;
    for (var i = 0; i < 3; i++) {
      c.drawRect(Rect.fromLTWH(w * (0.3 + i * 0.12), h * 0.35, 2, h * 0.14), _p);
    }
    _p.color = fur;
    c.drawCircle(Offset(w * 0.8, h * 0.32), h * 0.19, _p);
    c.drawPath(
      Path()
        ..moveTo(w * 0.72, h * 0.22)
        ..lineTo(w * 0.74, h * 0.02)
        ..lineTo(w * 0.8, h * 0.16)
        ..moveTo(w * 0.82, h * 0.16)
        ..lineTo(w * 0.88, h * 0.02)
        ..lineTo(w * 0.9, h * 0.24),
      _p,
    );
    _p.color = const Color(0xFFFFEB3B);
    c.drawCircle(Offset(w * 0.86, h * 0.3), 1.5, _p);
  }

  static void _chickens(Canvas c, Size s, double phase) {
    const xs = [0.0, 18.0, 34.0];
    for (var i = 0; i < xs.length; i++) {
      final x = xs[i];
      final bob = math.sin(phase + i * 1.7) * 1.2;
      final h = s.height;
      _s
        ..color = const Color(0xFFFFA000)
        ..strokeWidth = 1.4;
      c.drawLine(Offset(x + 6, h - 6), Offset(x + 6 + bob, h), _s);
      c.drawLine(Offset(x + 10, h - 6), Offset(x + 10 - bob, h), _s);
      _p.color = i == 1 ? const Color(0xFFD7A86E) : const Color(0xFFFAFAFA);
      c.drawOval(Rect.fromLTWH(x, h - 15 + bob * 0.3, 15, 10), _p);
      c.drawPath(
        Path()
          ..moveTo(x + 1, h - 12)
          ..lineTo(x - 2, h - 17)
          ..lineTo(x + 4, h - 13)
          ..close(),
        _p,
      );
      c.drawCircle(Offset(x + 14, h - 16 + bob * 0.3), 3.6, _p);
      _p.color = const Color(0xFFE53935);
      c.drawCircle(Offset(x + 14, h - 20 + bob * 0.3), 1.8, _p);
      _p.color = const Color(0xFFFFB300);
      c.drawRect(Rect.fromLTWH(x + 17, h - 16 + bob * 0.3, 2.5, 1.6), _p);
    }
  }

  static void _bubble(Canvas c, Size s, String text) {
    final cx = s.width / 2;
    _p.color = const Color(0xFFFFFFFF);
    c.drawRRect(RRect.fromLTRBR(cx - 9, -20, cx + 9, -4, const Radius.circular(5)), _p);
    c.drawPath(
      Path()
        ..moveTo(cx - 3, -5)
        ..lineTo(cx + 3, -5)
        ..lineTo(cx, 0)
        ..close(),
      _p,
    );
    _p.color = const Color(0xFFD50000);
    final xs = text == '!!' ? [cx - 5, cx + 2] : [cx - 1.5];
    for (final x in xs) {
      c.drawRect(Rect.fromLTWH(x, -17, 3, 7), _p);
      c.drawRect(Rect.fromLTWH(x, -9, 3, 2.5), _p);
    }
  }

  // ------------------------------------------------------------ pickups

  static void drawCash(Canvas c, Camera3D cam, CashCollectible cash, {double alpha = 1}) {
    final picked = cash.pickupTime >= 0;
    if (!picked) Shapes.shadow(c, cam, cash.x, cash.y, 22, 10, opacity: 0.22 * alpha);
    final lift = 9 + math.sin(cash.spinPhase * 0.5) * 2 + (picked ? cash.pickupTime * 160 : 0);
    // Bills are drawn a bit smaller than their pickup box so they read as cash.
    final grow = cash.scale.x * 0.75;
    Shapes.billboard(
      c,
      cam,
      cash.x,
      cash.y,
      cash.width * grow,
      cash.height * grow,
      (c, size) {
        c.scale(grow);
        cash.render(c);
      },
      lift: lift,
      alpha: alpha,
    );
  }

  static void drawFuel(Canvas c, Camera3D cam, FuelCollectible fuel, {double alpha = 1}) {
    final picked = fuel.pickupTime >= 0;
    if (!picked) Shapes.shadow(c, cam, fuel.x, fuel.y, 22, 12, opacity: 0.25 * alpha);
    final lift = 3 + math.sin(fuel.time * 3) * 1.5 + (picked ? fuel.pickupTime * 120 : 0);
    final grow = fuel.scale.x;
    Shapes.billboard(
      c,
      cam,
      fuel.x,
      fuel.y,
      fuel.width * grow,
      fuel.height * grow,
      (c, size) {
        c.scale(grow);
        fuel.render(c);
      },
      lift: lift,
      alpha: alpha,
    );
  }

  // ------------------------------------------------------------ effects

  /// Screen-size factor that keeps pop-up text about as large as it was in
  /// the top-down view.
  static double _uiScale(Camera3D cam) => math.min(cam.width / 400, cam.height / 640);

  static void drawFloatingText(Canvas c, Camera3D cam, FloatingText t) {
    final y = cam.pullBehind(t.y);
    if (!cam.isVisible(y)) return;
    final base = cam.project(t.x, y, 34);
    final depthScale = (cam.scaleAt(y) / cam.playerScale).clamp(0.65, 1.35);
    final s = depthScale * _uiScale(cam) * t.popScale;
    final painter = t.painter;
    c.save();
    c.translate(base.dx, base.dy);
    c.scale(s);
    painter.paint(c, Offset(-painter.width / 2, -painter.height / 2));
    c.restore();
  }

  /// Bursts and sparkles draw around their own origin.
  static void drawBurst(Canvas c, Camera3D cam, double x, double worldY, double lift, void Function(Canvas) render) {
    final y = cam.pullBehind(worldY);
    if (!cam.isVisible(y)) return;
    final base = cam.project(x, y, lift);
    final s = math.max(cam.scaleAt(y), cam.playerScale * 0.5) * 0.8;
    c.save();
    c.translate(base.dx, base.dy);
    c.scale(s);
    render(c);
    c.restore();
  }

  /// Red chevron hovering over the lane an oncoming vehicle will use.
  static void drawOncomingWarning(Canvas c, Camera3D cam, OncomingWarning w) {
    if (!w.blinkVisible) return;
    final y = cam.playerY - 640;
    final base = cam.project(w.x, y, 46);
    final s = _uiScale(cam) * 0.9;
    c.save();
    c.translate(base.dx, base.dy);
    c.scale(s);
    c.translate(-w.width / 2, -w.height);
    w.render(c);
    c.restore();
  }
}
