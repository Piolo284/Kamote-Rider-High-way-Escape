import 'dart:math' as math;
import 'dart:ui';

import '../../models/motorcycle_model.dart';
import 'camera3d.dart';
import 'shapes.dart';

/// Motorcycle and rider seen from behind, for the chase camera.
///
/// Art is authored in design units with the origin at the rear tyre's
/// contact patch (y grows downward, so the rider is at negative y), then
/// scaled by [designScale] into world units.
class RiderView {
  RiderView._();

  /// World units per design unit.
  static const double designScale = 0.78;

  /// Approximate world-unit size, for shadows and sorting.
  static const double worldWidth = 24;
  static const double worldLength = 46;

  static final Paint _p = Paint()..isAntiAlias = true;
  static final Paint _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static const _tire = Color(0xFF161616);
  static const _metal = Color(0xFFB0BEC5);
  static const _darkMetal = Color(0xFF37474F);
  static const _jeans = Color(0xFF283593);

  /// Draws the player's bike standing at world (x, y).
  static void drawBike(
    Canvas c,
    Camera3D cam,
    double x,
    double y,
    Motorcycle bike, {
    double roll = 0,
    double opacity = 1,
    bool braking = false,
    double anim = 0,
  }) {
    _place(c, cam, x, y, roll, opacity, (c) {
      paint(
        c,
        style: bike.style,
        body: bike.bodyColor,
        accent: bike.accentColor,
        jacket: Color.lerp(bike.accentColor, const Color(0xFF263238), 0.55)!,
        helmet: bike.accentColor,
        braking: braking,
        anim: anim,
      );
    });
  }

  /// Draws the LTO pursuit bike with flashing lights.
  static void drawOfficer(Canvas c, Camera3D cam, double x, double y, double time) {
    _place(c, cam, x, y, math.sin(time * 2.2) * 0.04, 1, (c) {
      paint(
        c,
        style: BikeStyle.naked,
        body: const Color(0xFFECEFF1),
        accent: const Color(0xFF1565C0),
        jacket: const Color(0xFF1565C0),
        helmet: const Color(0xFFFFFFFF),
        anim: time * 3,
      );
      final redOn = (time * 8).floor().isEven;
      for (final (dx, color, on) in [(-9.0, const Color(0xFFFF1744), redOn), (9.0, const Color(0xFF2979FF), !redOn)]) {
        _p.color = on ? color : color.withValues(alpha: 0.35);
        c.drawCircle(Offset(dx, -27), on ? 3.6 : 2.6, _p);
        if (on) {
          _p.color = color.withValues(alpha: 0.25);
          c.drawCircle(Offset(dx, -27), 14, _p);
        }
      }
    });
  }

  static void _place(
    Canvas c,
    Camera3D cam,
    double x,
    double y,
    double roll,
    double opacity,
    void Function(Canvas) art,
  ) {
    if (!cam.isVisible(y)) return;
    Shapes.shadow(c, cam, x, y, worldWidth, worldLength * 0.45, opacity: 0.3 * opacity);
    final base = cam.project(x, y);
    final s = cam.scaleAt(y) * designScale;
    c.save();
    c.translate(base.dx, base.dy);
    c.rotate(roll);
    c.scale(s);
    if (opacity < 1) {
      c.saveLayer(const Rect.fromLTWH(-60, -90, 120, 100), Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
      art(c);
      c.restore();
    } else {
      art(c);
    }
    c.restore();
  }

  /// Paints the rear view in design units around the tyre contact point.
  /// Also used by the garage preview.
  static void paint(
    Canvas c, {
    required BikeStyle style,
    required Color body,
    required Color accent,
    required Color jacket,
    required Color helmet,
    bool braking = false,
    double anim = 0,
  }) {
    // Cabs sit beside the bike and are drawn first.
    if (style == BikeStyle.sidecar) _sidecar(c, body, accent);
    if (style == BikeStyle.tricycle) _tricycleCab(c, body, accent);

    // Rear tyre with rolling tread.
    _p.color = _tire;
    c.drawRRect(RRect.fromLTRBR(-5, -18, 5, 0, const Radius.circular(4)), _p);
    _p.color = const Color(0xFF383838);
    final tread = (anim * 40) % 4;
    for (var y = -17 + tread; y < -1; y += 4) {
      c.drawRect(Rect.fromLTWH(-4, y, 8, 1.3), _p);
    }

    // Exhaust(s).
    _p.color = _metal;
    c.drawRRect(RRect.fromLTRBR(6, -17, 11, -10, const Radius.circular(2.5)), _p);
    _p.color = const Color(0xFF263238);
    c.drawCircle(const Offset(8.5, -13.5), 1.6, _p);
    if (style == BikeStyle.cruiser) {
      _p.color = _metal;
      c.drawRRect(RRect.fromLTRBR(-11, -17, -6, -10, const Radius.circular(2.5)), _p);
    }

    // Rider's legs and boots straddling the bike.
    _p.color = _jeans;
    c.drawRRect(RRect.fromLTRBR(-14, -34, -7, -16, const Radius.circular(3.5)), _p);
    c.drawRRect(RRect.fromLTRBR(7, -34, 14, -16, const Radius.circular(3.5)), _p);
    _p.color = const Color(0xFF3E2723);
    c.drawRRect(RRect.fromLTRBR(-14, -18, -7, -13, const Radius.circular(2)), _p);
    c.drawRRect(RRect.fromLTRBR(7, -18, 14, -13, const Radius.circular(2)), _p);

    _tail(c, style, body, accent, braking);

    // Handlebar ends and mirrors peeking out past the rider.
    final wide = style == BikeStyle.cruiser || style == BikeStyle.adventure;
    final bar = wide ? 21.0 : 18.0;
    _stroke
      ..color = _darkMetal
      ..strokeWidth = 1.6;
    c.drawLine(Offset(-bar + 3, -44), Offset(-bar + 1, -54), _stroke);
    c.drawLine(Offset(bar - 3, -44), Offset(bar - 1, -54), _stroke);
    _p.color = const Color(0xFF263238);
    c.drawOval(Rect.fromCenter(center: Offset(-bar + 1, -56), width: 6, height: 4.5), _p);
    c.drawOval(Rect.fromCenter(center: Offset(bar - 1, -56), width: 6, height: 4.5), _p);

    // Torso and arms reaching forward to the grips.
    _stroke
      ..color = jacket
      ..strokeWidth = 5;
    c.drawLine(const Offset(-10, -56), Offset(-bar + 1, -43), _stroke);
    c.drawLine(const Offset(10, -56), Offset(bar - 1, -43), _stroke);
    _p.color = const Color(0xFF212121);
    c.drawCircle(Offset(-bar + 1, -42.5), 2.6, _p);
    c.drawCircle(Offset(bar - 1, -42.5), 2.6, _p);
    _p.color = jacket;
    c.drawRRect(RRect.fromLTRBR(-11, -62, 11, -32, const Radius.circular(8)), _p);
    _p.color = Shapes.shade(jacket, 0.25);
    c.drawRect(const Rect.fromLTWH(-0.8, -60, 1.6, 26), _p);
    _p.color = const Color(0x22FFFFFF);
    c.drawRRect(RRect.fromLTRBR(-9, -60, -3, -36, const Radius.circular(4)), _p);

    // Helmet bobbing slightly with the road.
    final bob = anim == 0 ? 0.0 : (anim * 9 % 2 < 1 ? 0.4 : -0.4);
    _p.color = Shapes.shade(helmet, 0.3);
    c.drawRect(Rect.fromLTWH(-3.5, -66 + bob, 7, 5), _p);
    _p.color = helmet;
    c.drawCircle(Offset(0, -71 + bob), 9, _p);
    _p.color = body;
    c.drawRect(Rect.fromLTWH(-1.6, -80 + bob, 3.2, 17), _p);
    _p.color = const Color(0x55FFFFFF);
    c.drawCircle(Offset(-3.5, -75 + bob), 2.8, _p);
  }

  /// Seat, tail section and tail light, shaped per bike style.
  static void _tail(Canvas c, BikeStyle style, Color body, Color accent, bool braking) {
    _p.color = body;
    switch (style) {
      case BikeStyle.scooter:
        c.drawRRect(RRect.fromLTRBR(-12, -34, 12, -14, const Radius.circular(8)), _p);
        _p.color = accent;
        c.drawRRect(RRect.fromLTRBR(-9, -32, 9, -27, const Radius.circular(3)), _p);
      case BikeStyle.sport:
        c.drawPath(
          Path()
            ..moveTo(-7, -18)
            ..lineTo(-9, -34)
            ..lineTo(0, -40)
            ..lineTo(9, -34)
            ..lineTo(7, -18)
            ..close(),
          _p,
        );
        _p.color = accent;
        c.drawRect(const Rect.fromLTWH(-2, -38, 4, 18), _p);
      case BikeStyle.adventure:
        _p.color = accent;
        c.drawRRect(RRect.fromLTRBR(-20, -34, -11, -14, const Radius.circular(2)), _p);
        c.drawRRect(RRect.fromLTRBR(11, -34, 20, -14, const Radius.circular(2)), _p);
        _p.color = body;
        c.drawRRect(RRect.fromLTRBR(-8, -36, 8, -16, const Radius.circular(4)), _p);
      case BikeStyle.cruiser:
        c.drawRRect(RRect.fromLTRBR(-10, -30, 10, -14, const Radius.circular(9)), _p);
        _p.color = const Color(0xFF4E342E);
        c.drawRRect(RRect.fromLTRBR(-17, -30, -10, -17, const Radius.circular(3)), _p);
        c.drawRRect(RRect.fromLTRBR(10, -30, 17, -17, const Radius.circular(3)), _p);
      case BikeStyle.naked:
        _p.color = _darkMetal;
        c.drawRRect(RRect.fromLTRBR(-6, -34, 6, -16, const Radius.circular(4)), _p);
        _p.color = body;
        c.drawRRect(RRect.fromLTRBR(-7, -26, 7, -18, const Radius.circular(3)), _p);
      case BikeStyle.underbone:
      case BikeStyle.sidecar:
      case BikeStyle.tricycle:
        c.drawRRect(RRect.fromLTRBR(-8, -34, 8, -16, const Radius.circular(5)), _p);
        _p.color = accent;
        c.drawRect(const Rect.fromLTWH(-8, -30, 16, 3), _p);
    }
    // Plate and tail light.
    _p.color = const Color(0xFFF5F5F5);
    c.drawRect(const Rect.fromLTWH(-4.5, -22, 9, 5), _p);
    _p.color = const Color(0xFF37474F);
    c.drawRect(const Rect.fromLTWH(-3, -20.4, 6, 1.4), _p);
    _p.color = braking ? const Color(0xFFFF1744) : const Color(0xFFC62828);
    c.drawRRect(RRect.fromLTRBR(-5, -27, 5, -23.5, const Radius.circular(1.5)), _p);
    if (braking) {
      _p.color = const Color(0x55FF1744);
      c.drawCircle(const Offset(0, -25), 10, _p);
    }
  }

  static void _sidecar(Canvas c, Color body, Color accent) {
    _p.color = _darkMetal;
    c.drawRect(const Rect.fromLTWH(5, -12, 16, 3), _p);
    _p.color = _tire;
    c.drawRRect(RRect.fromLTRBR(27, -12, 33, 0, const Radius.circular(3)), _p);
    _p.color = body;
    c.drawRRect(RRect.fromLTRBR(16, -28, 40, -8, const Radius.circular(9)), _p);
    _p.color = accent;
    c.drawRRect(RRect.fromLTRBR(20, -26, 36, -18, const Radius.circular(4)), _p);
    _p.color = const Color(0xFFC62828);
    c.drawRect(const Rect.fromLTWH(35, -16, 3, 3), _p);
  }

  static void _tricycleCab(Canvas c, Color body, Color accent) {
    _p.color = _tire;
    c.drawRRect(RRect.fromLTRBR(39, -12, 45, 0, const Radius.circular(3)), _p);
    _p.color = body;
    c.drawRRect(RRect.fromLTRBR(14, -54, 48, -6, const Radius.circular(5)), _p);
    _p.color = Shapes.tint(body, 0.15);
    c.drawRect(const Rect.fromLTWH(12, -58, 38, 5), _p);
    _p.color = const Color(0xFF2B2B2B);
    c.drawRRect(RRect.fromLTRBR(18, -48, 44, -16, const Radius.circular(4)), _p);
    _p.color = accent;
    c.drawRect(const Rect.fromLTWH(18, -26, 26, 4), _p);
    _p.color = const Color(0xFFC62828);
    c.drawRect(const Rect.fromLTWH(43, -12, 4, 4), _p);
  }
}
