import 'dart:ui';

import '../environments.dart';

/// Procedural top-down traffic art. Vehicles are drawn facing up; pass
/// `facingDown` for oncoming traffic.
class VehiclePainter {
  VehiclePainter._();

  static final Paint _p = Paint()..isAntiAlias = true;

  static const _glass = Color(0xFF263850);
  static const _glassHi = Color(0xFF3E5A7A);
  static const _dark = Color(0xFF1C1C1C);

  /// Default footprint per vehicle type in world units.
  static Size sizeOf(VehicleType type) => switch (type) {
    VehicleType.car => const Size(42, 76),
    VehicleType.taxi => const Size(42, 76),
    VehicleType.van => const Size(46, 86),
    VehicleType.suv => const Size(46, 84),
    VehicleType.jeepney => const Size(48, 104),
    VehicleType.bus => const Size(56, 132),
    VehicleType.truck => const Size(54, 122),
    VehicleType.tricycle => const Size(44, 60),
  };

  /// Forward cruising speed (km/h) for same-direction traffic.
  static double cruiseKmh(VehicleType type) => switch (type) {
    VehicleType.car => 52,
    VehicleType.taxi => 50,
    VehicleType.van => 46,
    VehicleType.suv => 40,
    VehicleType.jeepney => 38,
    VehicleType.bus => 42,
    VehicleType.truck => 36,
    VehicleType.tricycle => 28,
  };

  static const List<Color> carColors = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFFFAFAFA),
    Color(0xFF424242),
    Color(0xFF43A047),
    Color(0xFFFDD835),
    Color(0xFF8E24AA),
    Color(0xFF90A4AE),
  ];

  static Color defaultColor(VehicleType type, int variant) => switch (type) {
    VehicleType.taxi => const Color(0xFFF5F5F5),
    VehicleType.jeepney => const [Color(0xFFCFD8DC), Color(0xFFFFCA28), Color(0xFFEF5350)][variant % 3],
    VehicleType.bus => const [Color(0xFF1565C0), Color(0xFFF4511E), Color(0xFF00897B)][variant % 3],
    VehicleType.truck => const [Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFFFFB300)][variant % 3],
    VehicleType.tricycle => const [Color(0xFF1E88E5), Color(0xFFE53935), Color(0xFF43A047)][variant % 3],
    _ => carColors[variant % carColors.length],
  };

  static void paint(
    Canvas canvas,
    Size size,
    VehicleType type,
    Color color, {
    bool facingDown = false,
    int variant = 0,
    bool braking = false,
    int signal = 0,
    double blinkPhase = 0,
  }) {
    final w = size.width;
    final h = size.height;

    // Soft two-layer shadow, always cast down-right regardless of heading.
    _p.color = const Color(0x22000000);
    canvas.drawRRect(RRect.fromLTRBR(4, 7, w + 5, h + 7, const Radius.circular(11)), _p);
    _p.color = const Color(0x33000000);
    canvas.drawRRect(RRect.fromLTRBR(2, 3, w + 2, h + 3, const Radius.circular(9)), _p);

    canvas.save();
    if (facingDown) {
      canvas.translate(w, h);
      canvas.rotate(3.14159265);
    }

    // Headlight beams spilling ahead of the vehicle.
    if (type != VehicleType.tricycle) {
      final beam = Path()
        ..moveTo(w * 0.15, 2)
        ..lineTo(w * 0.3, 2)
        ..lineTo(w * 0.42, -h * 0.32)
        ..lineTo(-w * 0.05, -h * 0.32)
        ..close()
        ..moveTo(w * 0.7, 2)
        ..lineTo(w * 0.85, 2)
        ..lineTo(w * 1.05, -h * 0.32)
        ..lineTo(w * 0.58, -h * 0.32)
        ..close();
      _p.color = const Color(0x12FFF9C4);
      canvas.drawPath(beam, _p);
      _wheels(canvas, w, h);
    }

    switch (type) {
      case VehicleType.car:
      case VehicleType.taxi:
        _car(canvas, w, h, color, taxi: type == VehicleType.taxi);
      case VehicleType.van:
        _van(canvas, w, h, color);
      case VehicleType.jeepney:
        _jeepney(canvas, w, h, color, variant);
      case VehicleType.bus:
        _bus(canvas, w, h, color);
      case VehicleType.truck:
        _truck(canvas, w, h, color);
      case VehicleType.tricycle:
        _tricycle(canvas, w, h, color);
      case VehicleType.suv:
        _suv(canvas, w, h, color, blinkPhase);
    }

    if (braking) {
      _p.color = const Color(0xFFFF1744);
      canvas.drawRRect(RRect.fromLTRBR(3, h - 6, 13, h - 1, const Radius.circular(2)), _p);
      canvas.drawRRect(RRect.fromLTRBR(w - 13, h - 6, w - 3, h - 1, const Radius.circular(2)), _p);
      _p.color = const Color(0x55FF1744);
      canvas.drawCircle(Offset(8, h), 11, _p);
      canvas.drawCircle(Offset(w - 8, h), 11, _p);
    }
    if (signal != 0 && (blinkPhase * 2.5).floor().isEven) {
      final sx = signal < 0 ? 2.0 : w - 8;
      _p.color = const Color(0xFFFFAB00);
      canvas.drawRRect(RRect.fromLTRBR(sx, 1, sx + 6, 6, const Radius.circular(2)), _p);
      canvas.drawRRect(RRect.fromLTRBR(sx, h - 7, sx + 6, h - 2, const Radius.circular(2)), _p);
      _p.color = const Color(0x44FFAB00);
      canvas.drawCircle(Offset(sx + 3, 3), 9, _p);
      canvas.drawCircle(Offset(sx + 3, h - 4), 9, _p);
    }
    canvas.restore();
  }

  /// Tyres peeking out at the four corners.
  static void _wheels(Canvas c, double w, double h) {
    _p.color = const Color(0xFF111111);
    final front = h * 0.14;
    final rear = h * 0.76;
    final len = h * 0.12;
    for (final y in [front, rear]) {
      c.drawRRect(RRect.fromLTRBR(-2, y, 3, y + len, const Radius.circular(2)), _p);
      c.drawRRect(RRect.fromLTRBR(w - 3, y, w + 2, y + len, const Radius.circular(2)), _p);
    }
  }

  static void _suv(Canvas c, double w, double h, Color color, double blink) {
    _mirrors(c, w, h * 0.24, color);
    _p.color = color;
    c.drawRRect(RRect.fromLTRBR(0, 0, w, h, const Radius.circular(9)), _p);
    _p.color = const Color(0xFF0D0D0D);
    c.drawRRect(RRect.fromLTRBR(5, h * 0.2, w - 5, h * 0.33, const Radius.circular(3)), _p);
    c.drawRRect(RRect.fromLTRBR(6, h * 0.82, w - 6, h * 0.9, const Radius.circular(3)), _p);
    _p.color = Color.lerp(color, const Color(0xFFFFFFFF), 0.12)!;
    c.drawRRect(RRect.fromLTRBR(5, h * 0.34, w - 5, h * 0.8, const Radius.circular(4)), _p);
    // Roof rails.
    _p.color = const Color(0xFF9E9E9E);
    c.drawRect(Rect.fromLTWH(7, h * 0.38, 2, h * 0.38), _p);
    c.drawRect(Rect.fromLTWH(w - 9, h * 0.38, 2, h * 0.38), _p);
    // Flashing blue VIP dashboard strobes.
    final on = (blink * 6).floor().isEven;
    _p.color = on ? const Color(0xFF2979FF) : const Color(0xFFFF1744);
    c.drawRect(Rect.fromLTWH(w * 0.3, h * 0.21, w * 0.15, 3), _p);
    _p.color = on ? const Color(0xFFFF1744) : const Color(0xFF2979FF);
    c.drawRect(Rect.fromLTWH(w * 0.55, h * 0.21, w * 0.15, 3), _p);
    _p.color = const Color(0xFF2979FF).withValues(alpha: on ? 0.22 : 0.08);
    c.drawCircle(Offset(w * 0.37, h * 0.22), 7, _p);
    _p.color = const Color(0xFFFF1744).withValues(alpha: on ? 0.08 : 0.22);
    c.drawCircle(Offset(w * 0.63, h * 0.22), 7, _p);
    _lights(c, w, h);
  }

  static void _lights(Canvas c, double w, double h, {double inset = 4}) {
    _p.color = const Color(0xFFFFF9C4);
    c.drawRRect(RRect.fromLTRBR(inset, 1, inset + 9, 5, const Radius.circular(2)), _p);
    c.drawRRect(RRect.fromLTRBR(w - inset - 9, 1, w - inset, 5, const Radius.circular(2)), _p);
    _p.color = const Color(0xFFD50000);
    c.drawRRect(RRect.fromLTRBR(inset, h - 5, inset + 8, h - 1.5, const Radius.circular(2)), _p);
    c.drawRRect(RRect.fromLTRBR(w - inset - 8, h - 5, w - inset, h - 1.5, const Radius.circular(2)), _p);
  }

  static void _mirrors(Canvas c, double w, double y, Color color) {
    _p.color = color;
    c.drawRRect(RRect.fromLTRBR(-4, y, 2, y + 4, const Radius.circular(2)), _p);
    c.drawRRect(RRect.fromLTRBR(w - 2, y, w + 4, y + 4, const Radius.circular(2)), _p);
  }

  static void _car(Canvas c, double w, double h, Color color, {required bool taxi}) {
    _mirrors(c, w, h * 0.3, color);
    _p.color = color;
    c.drawRRect(RRect.fromLTRBR(0, 0, w, h, const Radius.circular(10)), _p);
    _p.color = _glass;
    final ws = Path()
      ..moveTo(5, h * 0.27)
      ..lineTo(w - 5, h * 0.27)
      ..lineTo(w - 8, h * 0.38)
      ..lineTo(8, h * 0.38)
      ..close();
    c.drawPath(ws, _p);
    c.drawRRect(RRect.fromLTRBR(7, h * 0.75, w - 7, h * 0.84, const Radius.circular(3)), _p);
    _p.color = Color.lerp(color, const Color(0xFFFFFFFF), 0.18)!;
    c.drawRRect(RRect.fromLTRBR(6, h * 0.38, w - 6, h * 0.75, const Radius.circular(5)), _p);
    _p.color = _glassHi;
    c.drawRect(Rect.fromLTWH(9, h * 0.29, 6, 2), _p);
    if (taxi) {
      _p.color = const Color(0xFFFFC107);
      c.drawRRect(RRect.fromLTRBR(w * 0.3, h * 0.5, w * 0.7, h * 0.58, const Radius.circular(2)), _p);
      _p.color = const Color(0xFF212121);
      c.drawRect(Rect.fromLTWH(0, h * 0.62, w, 3), _p);
    }
    _lights(c, w, h);
  }

  static void _van(Canvas c, double w, double h, Color color) {
    _mirrors(c, w, h * 0.18, color);
    _p.color = color;
    c.drawRRect(RRect.fromLTRBR(0, 0, w, h, const Radius.circular(8)), _p);
    _p.color = _glass;
    c.drawRRect(RRect.fromLTRBR(5, h * 0.12, w - 5, h * 0.24, const Radius.circular(3)), _p);
    _p.color = Color.lerp(color, const Color(0xFFFFFFFF), 0.15)!;
    c.drawRRect(RRect.fromLTRBR(5, h * 0.26, w - 5, h * 0.95, const Radius.circular(4)), _p);
    _p.color = Color.lerp(color, const Color(0xFF000000), 0.12)!;
    for (var y = h * 0.35; y < h * 0.9; y += h * 0.14) {
      c.drawRect(Rect.fromLTWH(8, y, w - 16, 2), _p);
    }
    _lights(c, w, h);
  }

  static void _jeepney(Canvas c, double w, double h, Color color, int variant) {
    _mirrors(c, w, h * 0.2, const Color(0xFFCFD8DC));
    // Hood.
    _p.color = const Color(0xFFB0BEC5);
    c.drawRRect(RRect.fromLTRBR(4, 0, w - 4, h * 0.22, const Radius.circular(6)), _p);
    _p.color = const Color(0xFFECEFF1);
    for (var x = 8.0; x < w - 8; x += 5) {
      c.drawRect(Rect.fromLTWH(x, 2, 2, h * 0.05), _p);
    }
    // Hood ornaments.
    _p.color = const Color(0xFFFFD54F);
    c.drawCircle(Offset(w * 0.35, h * 0.12), 2.5, _p);
    c.drawCircle(Offset(w * 0.65, h * 0.12), 2.5, _p);
    _p.color = _glass;
    c.drawRect(Rect.fromLTWH(5, h * 0.21, w - 10, h * 0.06), _p);
    // Long passenger body with festive stripes.
    _p.color = color;
    c.drawRRect(RRect.fromLTRBR(0, h * 0.26, w, h, const Radius.circular(5)), _p);
    const stripes = [Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFFFFEB3B), Color(0xFF43A047)];
    for (var i = 0; i < 4; i++) {
      _p.color = stripes[(i + variant) % stripes.length];
      c.drawRect(Rect.fromLTWH(3, h * (0.33 + i * 0.15), w - 6, 4), _p);
    }
    _p.color = const Color(0xFF424242);
    c.drawRect(Rect.fromLTWH(w * 0.25, h - 6, w * 0.5, 6), _p);
    _p.color = const Color(0xFFD50000);
    c.drawRect(Rect.fromLTWH(3, h - 4, 6, 3), _p);
    c.drawRect(Rect.fromLTWH(w - 9, h - 4, 6, 3), _p);
    _p.color = const Color(0xFFFFF9C4);
    c.drawCircle(Offset(9, 3), 3, _p);
    c.drawCircle(Offset(w - 9, 3), 3, _p);
  }

  static void _bus(Canvas c, double w, double h, Color color) {
    _mirrors(c, w, h * 0.06, _dark);
    _p.color = color;
    c.drawRRect(RRect.fromLTRBR(0, 0, w, h, const Radius.circular(7)), _p);
    _p.color = _glass;
    c.drawRRect(RRect.fromLTRBR(4, 3, w - 4, h * 0.09, const Radius.circular(3)), _p);
    _p.color = const Color(0xFFF5F5F5);
    c.drawRRect(RRect.fromLTRBR(5, h * 0.12, w - 5, h * 0.96, const Radius.circular(4)), _p);
    _p.color = const Color(0xFFB0BEC5);
    c.drawRRect(RRect.fromLTRBR(w * 0.22, h * 0.3, w * 0.78, h * 0.42, const Radius.circular(3)), _p);
    c.drawRRect(RRect.fromLTRBR(w * 0.22, h * 0.6, w * 0.78, h * 0.72, const Radius.circular(3)), _p);
    _p.color = color;
    c.drawRect(Rect.fromLTWH(5, h * 0.5, w - 10, 4), _p);
    _lights(c, w, h, inset: 3);
  }

  static void _truck(Canvas c, double w, double h, Color color) {
    _mirrors(c, w, h * 0.08, _dark);
    _p.color = color;
    c.drawRRect(RRect.fromLTRBR(2, 0, w - 2, h * 0.24, const Radius.circular(7)), _p);
    _p.color = _glass;
    c.drawRect(Rect.fromLTWH(6, h * 0.04, w - 12, h * 0.07), _p);
    _p.color = const Color(0xFF616161);
    c.drawRect(Rect.fromLTWH(w * 0.3, h * 0.23, w * 0.4, h * 0.04), _p);
    _p.color = const Color(0xFFE0E0E0);
    c.drawRRect(RRect.fromLTRBR(0, h * 0.26, w, h, const Radius.circular(3)), _p);
    _p.color = const Color(0xFFBDBDBD);
    for (var y = h * 0.3; y < h; y += 9) {
      c.drawRect(Rect.fromLTWH(3, y, w - 6, 2), _p);
    }
    _p.color = const Color(0xFFFF6F00);
    c.drawRect(Rect.fromLTWH(0, h - 4, w, 4), _p);
    _p.color = const Color(0xFFFFF9C4);
    c.drawRRect(RRect.fromLTRBR(5, 1, 13, 4, const Radius.circular(2)), _p);
    c.drawRRect(RRect.fromLTRBR(w - 13, 1, w - 5, 4, const Radius.circular(2)), _p);
  }

  static void _tricycle(Canvas c, double w, double h, Color color) {
    // Motorcycle on the left half.
    _p.color = _dark;
    c.drawRRect(RRect.fromLTRBR(w * 0.17, 0, w * 0.31, h * 0.22, const Radius.circular(2)), _p);
    c.drawRRect(RRect.fromLTRBR(w * 0.16, h * 0.74, w * 0.32, h, const Radius.circular(2)), _p);
    _p.color = color;
    c.drawRRect(RRect.fromLTRBR(w * 0.12, h * 0.15, w * 0.36, h * 0.85, const Radius.circular(4)), _p);
    _p.color = const Color(0xFF37474F);
    c.drawCircle(Offset(w * 0.24, h * 0.5), w * 0.11, _p);
    // Passenger cab on the right.
    _p.color = _dark;
    c.drawRRect(RRect.fromLTRBR(w * 0.88, h * 0.6, w, h * 0.86, const Radius.circular(2)), _p);
    _p.color = color;
    c.drawRRect(RRect.fromLTRBR(w * 0.38, h * 0.05, w * 0.96, h * 0.95, const Radius.circular(5)), _p);
    _p.color = const Color(0xFFFFF8E1);
    c.drawRRect(RRect.fromLTRBR(w * 0.44, h * 0.12, w * 0.9, h * 0.88, const Radius.circular(4)), _p);
    _p.color = color;
    c.drawRect(Rect.fromLTWH(w * 0.44, h * 0.4, w * 0.46, 3), _p);
    _p.color = const Color(0xFFD50000);
    c.drawRect(Rect.fromLTWH(w * 0.42, h - 3, 5, 2.5), _p);
  }

  /// Fictional ambulance used in the head-on ending.
  static void paintAmbulance(Canvas canvas, Size size, {required double sirenPhase, bool facingDown = true}) {
    canvas.save();
    if (facingDown) {
      canvas.translate(size.width, size.height);
      canvas.rotate(3.14159265);
    }
    final w = size.width;
    final h = size.height;
    _p.color = const Color(0x44000000);
    canvas.drawRRect(RRect.fromLTRBR(3, 5, w + 3, h + 4, const Radius.circular(9)), _p);
    _van(canvas, w, h, const Color(0xFFFAFAFA));
    _p.color = const Color(0xFFD32F2F);
    canvas.drawRect(Rect.fromLTWH(w * 0.42, h * 0.45, w * 0.16, h * 0.3), _p);
    canvas.drawRect(Rect.fromLTWH(w * 0.25, h * 0.54, w * 0.5, h * 0.12), _p);
    _p.color = const Color(0xFFFF6F00);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.85, w, 3), _p);
    final on = (sirenPhase * 2).floor().isEven;
    _p.color = on ? const Color(0xFFFF1744) : const Color(0xFF2979FF);
    canvas.drawRRect(RRect.fromLTRBR(5, h * 0.27, w * 0.45, h * 0.32, const Radius.circular(2)), _p);
    _p.color = on ? const Color(0xFF2979FF) : const Color(0xFFFF1744);
    canvas.drawRRect(RRect.fromLTRBR(w * 0.55, h * 0.27, w - 5, h * 0.32, const Radius.circular(2)), _p);
    _p.color = on ? const Color(0x33FF1744) : const Color(0x332979FF);
    canvas.drawCircle(Offset(w / 2, h * 0.3), w * 0.9, _p);
    canvas.restore();
  }
}
