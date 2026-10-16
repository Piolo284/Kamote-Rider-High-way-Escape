import 'dart:math' as math;
import 'dart:ui';

import '../environments.dart';

/// Procedural top-down roadside scenery.
class PropPainter {
  PropPainter._();

  static final Paint _p = Paint()..isAntiAlias = true;
  static final Paint _s = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  /// Footprint of each prop type in world units.
  static Size sizeOf(PropType type) => switch (type) {
    PropType.building => const Size(56, 74),
    PropType.tower => const Size(60, 96),
    PropType.nipaHut => const Size(46, 42),
    PropType.sariSari => const Size(44, 40),
    PropType.tree => const Size(44, 44),
    PropType.palm => const Size(48, 48),
    PropType.pine => const Size(36, 36),
    PropType.streetlight => const Size(34, 14),
    PropType.roadSign => const Size(34, 14),
    PropType.warningSign => const Size(22, 22),
    PropType.rock => const Size(36, 30),
    PropType.billboard => const Size(50, 18),
    PropType.boat => const Size(22, 56),
    PropType.bush => const Size(30, 24),
    PropType.flyover => const Size(1200, 64),
  };

  static const _roofColors = [
    Color(0xFF90A4AE),
    Color(0xFFB0BEC5),
    Color(0xFF8D6E63),
    Color(0xFF78909C),
    Color(0xFFBCAAA4),
    Color(0xFF607D8B),
  ];

  /// [onLeft] mirrors props that point toward the road.
  static void paint(Canvas c, PropType type, Size s, {required int variant, required bool onLeft}) {
    final w = s.width;
    final h = s.height;
    switch (type) {
      case PropType.building:
      case PropType.tower:
        _shadow(c, w, h);
        _p.color = _roofColors[variant % _roofColors.length];
        c.drawRect(Rect.fromLTWH(0, 0, w, h), _p);
        _p.color = const Color(0x33000000);
        c.drawRect(Rect.fromLTWH(0, 0, w, 3), _p);
        c.drawRect(Rect.fromLTWH(0, 0, 3, h), _p);
        _p.color = const Color(0x22FFFFFF);
        c.drawRect(Rect.fromLTWH(w - 3, 0, 3, h), _p);
        c.drawRect(Rect.fromLTWH(0, h - 3, w, 3), _p);
        // Rooftop clutter: water tank and AC units.
        _p.color = const Color(0xFF1976D2);
        c.drawCircle(Offset(w * 0.3, h * 0.28), 6, _p);
        _p.color = const Color(0xFFECEFF1);
        c.drawRect(Rect.fromLTWH(w * 0.55, h * 0.55, 10, 8), _p);
        c.drawRect(Rect.fromLTWH(w * 0.2, h * 0.68, 10, 8), _p);
        if (type == PropType.tower) {
          _s
            ..color = const Color(0x55FFFFFF)
            ..strokeWidth = 2;
          c.drawCircle(Offset(w * 0.62, h * 0.24), 10, _s);
          _p.color = const Color(0xFFFF1744);
          c.drawCircle(Offset(w - 6, 6), 2.5, _p);
        }
      case PropType.nipaHut:
        _shadow(c, w, h);
        _p.color = const Color(0xFFC8A165);
        c.drawRect(Rect.fromLTWH(0, 0, w, h), _p);
        _p.color = const Color(0xFFA67C42);
        c.drawRect(Rect.fromLTWH(0, h / 2 - 1.5, w, 3), _p);
        _s
          ..color = const Color(0x55704A1E)
          ..strokeWidth = 1.2;
        for (var x = 4.0; x < w; x += 5) {
          c.drawLine(Offset(x, 2), Offset(x, h - 2), _s);
        }
      case PropType.sariSari:
        _shadow(c, w, h);
        _p.color = variant.isEven ? const Color(0xFFD32F2F) : const Color(0xFF1976D2);
        c.drawRect(Rect.fromLTWH(0, 0, w, h * 0.75), _p);
        _s
          ..color = const Color(0x44FFFFFF)
          ..strokeWidth = 1.5;
        for (var x = 4.0; x < w; x += 6) {
          c.drawLine(Offset(x, 1), Offset(x, h * 0.75 - 1), _s);
        }
        // Striped awning facing the road.
        for (var i = 0; i < 6; i++) {
          _p.color = i.isEven ? const Color(0xFFFFFFFF) : const Color(0xFFFFC107);
          c.drawRect(Rect.fromLTWH(w * i / 6, h * 0.75, w / 6, h * 0.25), _p);
        }
      case PropType.tree:
        _p.color = const Color(0x33000000);
        c.drawCircle(Offset(w * 0.55, h * 0.58), w * 0.45, _p);
        _p.color = const Color(0xFF2E7D32);
        c.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.42, _p);
        _p.color = const Color(0xFF43A047);
        c.drawCircle(Offset(w * 0.38, h * 0.4), w * 0.24, _p);
        c.drawCircle(Offset(w * 0.62, h * 0.55), w * 0.2, _p);
      case PropType.palm:
        _p.color = const Color(0x33000000);
        c.drawCircle(Offset(w * 0.56, h * 0.58), w * 0.4, _p);
        _s
          ..color = const Color(0xFF388E3C)
          ..strokeWidth = 6;
        final center = Offset(w / 2, h / 2);
        for (var i = 0; i < 7; i++) {
          final a = i * math.pi * 2 / 7 + variant;
          c.drawLine(center, center + Offset(math.cos(a), math.sin(a)) * (w * 0.46), _s);
        }
        _s
          ..color = const Color(0xFF66BB6A)
          ..strokeWidth = 2;
        for (var i = 0; i < 7; i++) {
          final a = i * math.pi * 2 / 7 + variant;
          c.drawLine(center, center + Offset(math.cos(a), math.sin(a)) * (w * 0.4), _s);
        }
        _p.color = const Color(0xFF795548);
        c.drawCircle(center, 4.5, _p);
      case PropType.pine:
        _p.color = const Color(0x33000000);
        c.drawCircle(Offset(w * 0.56, h * 0.58), w * 0.45, _p);
        _p.color = const Color(0xFF1B5E20);
        c.drawCircle(Offset(w / 2, h / 2), w * 0.48, _p);
        _p.color = const Color(0xFF2E7D32);
        c.drawCircle(Offset(w / 2, h / 2), w * 0.32, _p);
        _p.color = const Color(0xFF388E3C);
        c.drawCircle(Offset(w / 2, h / 2), w * 0.16, _p);
      case PropType.streetlight:
        // Pole lies flat in top-down view, arm reaching over the road edge.
        c.save();
        if (onLeft) {
          c.translate(w, 0);
          c.scale(-1, 1);
        }
        _p.color = const Color(0xFF546E7A);
        c.drawRRect(RRect.fromLTRBR(0, h / 2 - 2, w - 6, h / 2 + 2, const Radius.circular(2)), _p);
        _p.color = const Color(0x44FFF59D);
        c.drawCircle(Offset(4, h / 2), 13, _p);
        _p.color = const Color(0xFFFFF59D);
        c.drawRRect(RRect.fromLTRBR(0, h / 2 - 4, 10, h / 2 + 4, const Radius.circular(3)), _p);
        _p.color = const Color(0xFF37474F);
        c.drawCircle(Offset(w - 5, h / 2), 4, _p);
        c.restore();
      case PropType.roadSign:
        _p.color = const Color(0xFF616161);
        c.drawRect(Rect.fromLTWH(w * 0.2, h - 3, 2, 3), _p);
        c.drawRect(Rect.fromLTWH(w * 0.8 - 2, h - 3, 2, 3), _p);
        _p.color = const Color(0xFF2E7D32);
        c.drawRRect(RRect.fromLTRBR(0, 0, w, h - 3, const Radius.circular(2)), _p);
        _p.color = const Color(0xFFFFFFFF);
        c.drawRect(Rect.fromLTWH(4, 3, w * 0.5, 2), _p);
        c.drawRect(Rect.fromLTWH(4, 7, w * 0.7, 2), _p);
      case PropType.warningSign:
        _p.color = const Color(0xFF424242);
        c.drawRect(Rect.fromLTWH(w / 2 - 1, h * 0.6, 2, h * 0.4), _p);
        final diamond = Path()
          ..moveTo(w / 2, 0)
          ..lineTo(w, h * 0.42)
          ..lineTo(w / 2, h * 0.84)
          ..lineTo(0, h * 0.42)
          ..close();
        _p.color = const Color(0xFFFFD600);
        c.drawPath(diamond, _p);
        _p.color = const Color(0xFF212121);
        c.drawRect(Rect.fromLTWH(w / 2 - 1.2, h * 0.18, 2.4, h * 0.3), _p);
        c.drawCircle(Offset(w / 2, h * 0.6), 1.5, _p);
      case PropType.rock:
        _p.color = const Color(0x33000000);
        c.drawOval(Rect.fromLTWH(3, 4, w, h), _p);
        _p.color = const Color(0xFF757575);
        final rock = Path()
          ..moveTo(w * 0.2, 0)
          ..lineTo(w * 0.75, h * 0.08)
          ..lineTo(w, h * 0.55)
          ..lineTo(w * 0.7, h)
          ..lineTo(w * 0.15, h * 0.9)
          ..lineTo(0, h * 0.4)
          ..close();
        c.drawPath(rock, _p);
        _p.color = const Color(0xFF9E9E9E);
        c.drawCircle(Offset(w * 0.4, h * 0.35), w * 0.15, _p);
      case PropType.billboard:
        _p.color = const Color(0xFF455A64);
        c.drawRect(Rect.fromLTWH(w * 0.25, h - 4, 3, 4), _p);
        c.drawRect(Rect.fromLTWH(w * 0.75 - 3, h - 4, 3, 4), _p);
        const ads = [Color(0xFFFF7043), Color(0xFFAB47BC), Color(0xFF26A69A), Color(0xFFFFCA28)];
        _p.color = ads[variant % ads.length];
        c.drawRRect(RRect.fromLTRBR(0, 0, w, h - 4, const Radius.circular(2)), _p);
        _p.color = const Color(0xCCFFFFFF);
        c.drawRect(Rect.fromLTWH(4, 3, w * 0.45, 3), _p);
        c.drawRect(Rect.fromLTWH(4, 8, w * 0.3, 3), _p);
        c.drawCircle(Offset(w * 0.78, (h - 4) / 2), 4, _p);
      case PropType.boat:
        // Bangka with bamboo outriggers.
        _s
          ..color = const Color(0xFFD7CCC8)
          ..strokeWidth = 2;
        c.drawLine(Offset(-6, h * 0.35), Offset(w + 6, h * 0.35), _s);
        c.drawLine(Offset(-6, h * 0.65), Offset(w + 6, h * 0.65), _s);
        c.drawLine(Offset(-8, h * 0.25), Offset(-8, h * 0.75), _s);
        c.drawLine(Offset(w + 8, h * 0.25), Offset(w + 8, h * 0.75), _s);
        final hull = Path()
          ..moveTo(w / 2, 0)
          ..quadraticBezierTo(w, h * 0.3, w * 0.8, h)
          ..lineTo(w * 0.2, h)
          ..quadraticBezierTo(0, h * 0.3, w / 2, 0)
          ..close();
        _p.color = variant.isEven ? const Color(0xFFFFFFFF) : const Color(0xFFFFEB3B);
        c.drawPath(hull, _p);
        _p.color = const Color(0xFF1E88E5);
        c.drawRect(Rect.fromLTWH(w * 0.3, h * 0.4, w * 0.4, h * 0.3), _p);
      case PropType.bush:
        _p.color = const Color(0xFF558B2F);
        c.drawOval(Rect.fromLTWH(0, 0, w, h), _p);
        _p.color = const Color(0xFF7CB342);
        c.drawOval(Rect.fromLTWH(w * 0.2, h * 0.15, w * 0.5, h * 0.5), _p);
      case PropType.flyover:
        _p.color = const Color(0x44000000);
        c.drawRect(Rect.fromLTWH(0, h * 0.2, w, h), _p);
        _p.color = const Color(0xFFB0BEC5);
        c.drawRect(Rect.fromLTWH(0, 0, w, h), _p);
        _p.color = const Color(0xFF90A4AE);
        c.drawRect(Rect.fromLTWH(0, 0, w, 5), _p);
        c.drawRect(Rect.fromLTWH(0, h - 5, w, 5), _p);
        _p.color = const Color(0xFFECEFF1);
        for (var x = 10.0; x < w; x += 46) {
          c.drawRect(Rect.fromLTWH(x, h / 2 - 1.5, 24, 3), _p);
        }
    }
  }

  static void _shadow(Canvas c, double w, double h) {
    _p.color = const Color(0x40000000);
    c.drawRect(Rect.fromLTWH(5, 6, w, h), _p);
  }
}
