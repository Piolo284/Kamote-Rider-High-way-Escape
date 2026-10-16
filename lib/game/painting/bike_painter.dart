import 'dart:ui';

import '../../models/motorcycle_model.dart';

/// Procedural top-down/rear-view motorcycle art.
///
/// Shared by the Flame player component and the Flutter garage previews so
/// both always look identical. Drawn in a 40×80 design box (front at the
/// top) scaled to the requested size; sidecar and tricycle cabs extend past
/// the right edge of the box.
class BikePainter {
  BikePainter._();

  static final Paint _p = Paint()..isAntiAlias = true;
  static final Paint _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static const _tire = Color(0xFF1B1B1B);
  static const _metal = Color(0xFFB0BEC5);
  static const _darkMetal = Color(0xFF37474F);

  static void paint(
    Canvas canvas,
    Size size,
    Motorcycle bike, {
    bool braking = false,
    double opacity = 1,
    double anim = 0,
    bool beam = false,
  }) {
    _paintGeneric(
      canvas,
      size,
      style: bike.style,
      body: bike.bodyColor,
      accent: bike.accentColor,
      jacket: Color.lerp(bike.accentColor, const Color(0xFF263238), 0.55)!,
      helmet: bike.accentColor,
      braking: braking,
      opacity: opacity,
      anim: anim,
      beam: beam,
    );
  }

  /// The fictional LTO pursuit bike with flashing lights.
  static void paintOfficer(Canvas canvas, Size size, {required double sirenPhase}) {
    _paintGeneric(
      canvas,
      size,
      style: BikeStyle.naked,
      body: const Color(0xFFECEFF1),
      accent: const Color(0xFF1565C0),
      jacket: const Color(0xFF1565C0),
      helmet: const Color(0xFFFFFFFF),
      braking: false,
      opacity: 1,
    );
    canvas.save();
    canvas.scale(size.width / 40, size.height / 80);
    final redOn = (sirenPhase * 2).floor().isEven;
    _p.color = redOn ? const Color(0xFFFF1744) : const Color(0x55FF1744);
    canvas.drawCircle(const Offset(10, 62), redOn ? 5 : 3.5, _p);
    _p.color = !redOn ? const Color(0xFF2979FF) : const Color(0x552979FF);
    canvas.drawCircle(const Offset(30, 62), !redOn ? 5 : 3.5, _p);
    if (redOn) {
      _p.color = const Color(0x33FF1744);
      canvas.drawCircle(const Offset(10, 62), 14, _p);
    } else {
      _p.color = const Color(0x332979FF);
      canvas.drawCircle(const Offset(30, 62), 14, _p);
    }
    canvas.restore();
  }

  static void _paintGeneric(
    Canvas canvas,
    Size size, {
    required BikeStyle style,
    required Color body,
    required Color accent,
    required Color jacket,
    required Color helmet,
    required bool braking,
    required double opacity,
    double anim = 0,
    bool beam = false,
  }) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 80);
    if (opacity < 1) {
      canvas.saveLayer(const Rect.fromLTWH(-10, -10, 90, 100), Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    }

    // Headlight beam on the road ahead.
    if (beam) {
      final cone = Path()
        ..moveTo(17, 8)
        ..lineTo(23, 8)
        ..lineTo(38, -70)
        ..lineTo(2, -70)
        ..close();
      _p.color = const Color(0x16FFF59D);
      canvas.drawPath(cone, _p);
    }

    // Shadow.
    _p.color = const Color(0x40000000);
    canvas.drawOval(const Rect.fromLTWH(5, 10, 32, 70), _p);

    // Extra cabs drawn first so the bike sits on top.
    if (style == BikeStyle.sidecar) _sidecar(canvas, body, accent);
    if (style == BikeStyle.tricycle) _tricycleCab(canvas, body, accent);

    // Tires.
    _p.color = _tire;
    canvas.drawRRect(RRect.fromLTRBR(16, 1, 24, 19, const Radius.circular(3)), _p);
    canvas.drawRRect(RRect.fromLTRBR(14.5, 60, 25.5, 79, const Radius.circular(3)), _p);
    // Rolling tread blocks.
    _p.color = const Color(0xFF3A3A3A);
    final tread = (anim * 40) % 4;
    for (var y = 1 + tread; y < 19; y += 4) {
      canvas.drawRect(Rect.fromLTWH(17, y, 6, 1.2), _p);
    }
    for (var y = 60 + tread; y < 79; y += 4) {
      canvas.drawRect(Rect.fromLTWH(15.5, y, 9, 1.4), _p);
    }

    // Exhaust.
    _p.color = _metal;
    canvas.drawRRect(RRect.fromLTRBR(27, 52, 31.5, 73, const Radius.circular(2)), _p);
    if (style == BikeStyle.cruiser) {
      canvas.drawRRect(RRect.fromLTRBR(8.5, 52, 13, 73, const Radius.circular(2)), _p);
    }

    _bodyShape(canvas, style, body, accent);

    // Handlebar.
    final wideBars = style == BikeStyle.cruiser || style == BikeStyle.adventure;
    _p.color = _darkMetal;
    canvas.drawRRect(RRect.fromLTRBR(wideBars ? 3 : 6, 16, wideBars ? 37 : 34, 19.5, const Radius.circular(2)), _p);
    _p.color = const Color(0xFF111111);
    canvas.drawRRect(RRect.fromLTRBR(wideBars ? 2 : 5, 15, wideBars ? 7 : 10, 20.5, const Radius.circular(2)), _p);
    canvas.drawRRect(RRect.fromLTRBR(wideBars ? 33 : 30, 15, wideBars ? 38 : 35, 20.5, const Radius.circular(2)), _p);

    // Headlight glow.
    _p.color = const Color(0xFFFFF59D);
    canvas.drawCircle(const Offset(20, 12), 2.6, _p);

    // Rider: arms, back, helmet.
    _stroke
      ..color = jacket
      ..strokeWidth = 4.2;
    canvas.drawLine(const Offset(13, 36), Offset(wideBars ? 6 : 8.5, 19), _stroke);
    canvas.drawLine(const Offset(27, 36), Offset(wideBars ? 34 : 31.5, 19), _stroke);
    _p.color = jacket;
    canvas.drawRRect(RRect.fromLTRBR(11, 30, 29, 55, const Radius.circular(8)), _p);
    _p.color = const Color(0x22FFFFFF);
    canvas.drawRRect(RRect.fromLTRBR(13, 33, 20, 52, const Radius.circular(5)), _p);
    _p.color = helmet;
    final bob = anim == 0 ? 0.0 : (anim * 9 % 2 < 1 ? 0.4 : -0.4);
    canvas.drawCircle(Offset(20 + bob, 33), 7.6, _p);
    _p.color = body;
    canvas.drawRect(Rect.fromLTWH(18.6 + bob, 25.6, 2.8, 14.8), _p);
    _p.color = const Color(0x55FFFFFF);
    canvas.drawCircle(Offset(17.5 + bob, 30.5), 2.6, _p);

    // Tail light.
    _p.color = braking ? const Color(0xFFFF1744) : const Color(0xFFC62828);
    canvas.drawRRect(RRect.fromLTRBR(15.5, 62.5, 24.5, 66, const Radius.circular(1.5)), _p);
    if (braking) {
      _p.color = const Color(0x55FF1744);
      canvas.drawCircle(const Offset(20, 64), 8, _p);
    }

    if (opacity < 1) canvas.restore();
    canvas.restore();
  }

  static void _bodyShape(Canvas canvas, BikeStyle style, Color body, Color accent) {
    _p.color = body;
    switch (style) {
      case BikeStyle.underbone:
      case BikeStyle.sidecar:
      case BikeStyle.tricycle:
        canvas.drawRRect(RRect.fromLTRBR(12.5, 15, 27.5, 63, const Radius.circular(6)), _p);
        _p.color = accent;
        canvas.drawRRect(RRect.fromLTRBR(15, 20, 25, 26, const Radius.circular(2)), _p);
      case BikeStyle.scooter:
        canvas.drawRRect(RRect.fromLTRBR(10, 14, 30, 64, const Radius.circular(9)), _p);
        _p.color = accent;
        canvas.drawRRect(RRect.fromLTRBR(13, 54, 27, 61, const Radius.circular(3)), _p);
      case BikeStyle.sport:
        final path = Path()
          ..moveTo(20, 5)
          ..lineTo(30, 20)
          ..lineTo(29.5, 58)
          ..lineTo(25, 67)
          ..lineTo(15, 67)
          ..lineTo(10.5, 58)
          ..lineTo(10, 20)
          ..close();
        canvas.drawPath(path, _p);
        _p.color = accent;
        final stripe = Path()
          ..moveTo(20, 8)
          ..lineTo(23, 14)
          ..lineTo(23, 60)
          ..lineTo(17, 60)
          ..lineTo(17, 14)
          ..close();
        canvas.drawPath(stripe, _p);
        _p.color = const Color(0xAA1A237E);
        canvas.drawRRect(RRect.fromLTRBR(14, 12, 26, 17, const Radius.circular(3)), _p);
      case BikeStyle.naked:
        canvas.drawOval(const Rect.fromLTWH(11.5, 17, 17, 22), _p);
        _p.color = _darkMetal;
        canvas.drawRRect(RRect.fromLTRBR(15, 36, 25, 64, const Radius.circular(4)), _p);
        _p.color = accent;
        canvas.drawOval(const Rect.fromLTWH(15, 21, 10, 12), _p);
      case BikeStyle.adventure:
        _p.color = accent;
        canvas.drawRRect(RRect.fromLTRBR(2, 46, 11, 66, const Radius.circular(2)), _p);
        canvas.drawRRect(RRect.fromLTRBR(29, 46, 38, 66, const Radius.circular(2)), _p);
        _p.color = body;
        canvas.drawRRect(RRect.fromLTRBR(11, 12, 29, 64, const Radius.circular(5)), _p);
        _p.color = const Color(0x88FFFFFF);
        canvas.drawRRect(RRect.fromLTRBR(14, 9, 26, 15, const Radius.circular(3)), _p);
      case BikeStyle.cruiser:
        canvas.drawRRect(RRect.fromLTRBR(11, 13, 29, 66, const Radius.circular(10)), _p);
        _p.color = accent;
        canvas.drawOval(const Rect.fromLTWH(13.5, 17, 13, 18), _p);
        _p.color = _metal;
        canvas.drawRRect(RRect.fromLTRBR(17, 13, 23, 16, const Radius.circular(1)), _p);
    }
  }

  static void _sidecar(Canvas canvas, Color body, Color accent) {
    _p.color = _darkMetal;
    canvas.drawRect(const Rect.fromLTWH(26, 40, 14, 3), _p);
    _p.color = _tire;
    canvas.drawRRect(RRect.fromLTRBR(53, 42, 59, 58, const Radius.circular(2)), _p);
    _p.color = body;
    canvas.drawOval(const Rect.fromLTWH(36, 22, 20, 40), _p);
    _p.color = accent;
    canvas.drawOval(const Rect.fromLTWH(40, 34, 12, 20), _p);
  }

  static void _tricycleCab(Canvas canvas, Color body, Color accent) {
    _p.color = _tire;
    canvas.drawRRect(RRect.fromLTRBR(58, 46, 64, 64, const Radius.circular(2)), _p);
    _p.color = body;
    canvas.drawRRect(RRect.fromLTRBR(29, 10, 62, 68, const Radius.circular(5)), _p);
    _p.color = accent;
    canvas.drawRRect(RRect.fromLTRBR(32, 14, 59, 64, const Radius.circular(4)), _p);
    _p.color = body;
    for (var y = 20.0; y < 62; y += 9) {
      canvas.drawRect(Rect.fromLTWH(32, y, 27, 2), _p);
    }
  }
}
