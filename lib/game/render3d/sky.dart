import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'camera3d.dart';

/// Sky, sun, clouds and distant silhouettes behind the horizon, one look
/// per highway world.
class SkyPainter {
  static final Paint _p = Paint()..isAntiAlias = true;

  static const _top = [Color(0xFF8FB3CC), Color(0xFF3FA9F5), Color(0xFF7FA6C9), Color(0xFFFF8A65), Color(0xFF4A5A6A)];
  static const _horizon = [
    Color(0xFFD9E3E8),
    Color(0xFFD7F0FF),
    Color(0xFFE3ECF2),
    Color(0xFFFFE0B2),
    Color(0xFF9AA8B4),
  ];

  /// Haze colour where the road meets the sky.
  static Color horizonColor(int env) => _horizon[env % _horizon.length];

  void paint(Canvas c, Camera3D cam, int env, double time, {double alpha = 1}) {
    final w = cam.width;
    final hz = cam.horizonY;
    final i = env % _top.length;
    final layer = alpha < 0.999;
    if (layer) c.saveLayer(Rect.fromLTWH(0, 0, w, hz + 2), Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    _p.shader = ui.Gradient.linear(Offset.zero, Offset(0, hz), [_top[i], _horizon[i]]);
    c.drawRect(Rect.fromLTWH(0, 0, w, hz + 2), _p);
    _p.shader = null;

    // Distant scenery drifts a little as the rider steers.
    final unit = math.min(w, cam.height) / 400;
    final shift = -(cam.camX - 200) * 0.12 * unit;
    c.save();
    c.translate(shift, 0);
    switch (i) {
      case 0:
        _clouds(c, w, hz, unit, time, const Color(0xCCFFFFFF));
        _skyline(c, w, hz, unit, seed: 3, maxH: 46, color: const Color(0xFFA7B6C0), lit: false);
        _skyline(c, w, hz, unit, seed: 7, maxH: 30, color: const Color(0xFF8D9EAA), lit: false);
      case 1:
        _sun(c, Offset(w * 0.78, hz * 0.32), 20 * unit, const Color(0xFFFFF59D));
        _clouds(c, w, hz, unit, time, const Color(0xEEFFFFFF));
        _volcano(c, w * 0.3, hz, unit);
        _hills(c, w, hz, unit, seed: 2, height: 18, color: const Color(0xFF8BC34A));
        _hills(c, w, hz, unit, seed: 5, height: 10, color: const Color(0xFF7CB342));
      case 2:
        _clouds(c, w, hz, unit, time, const Color(0xBBFFFFFF));
        _mountains(c, w, hz, unit, seed: 4, height: 90, color: const Color(0xFF7D93A8), snow: true);
        _mountains(c, w, hz, unit, seed: 9, height: 50, color: const Color(0xFF4E6E58), snow: false);
      case 3:
        _sun(c, Offset(w * 0.72, hz * 0.78), 34 * unit, const Color(0xFFFFE082));
        _clouds(c, w, hz, unit, time, const Color(0x99FFCCBC));
        _islands(c, w, hz, unit);
      case 4:
        _clouds(c, w, hz, unit, time, const Color(0x88607080));
        _skyline(c, w, hz, unit, seed: 11, maxH: 70, color: const Color(0xFF5D6D7A), lit: true);
        _skyline(c, w, hz, unit, seed: 13, maxH: 44, color: const Color(0xFF46545F), lit: true);
    }
    c.restore();
    if (layer) c.restore();
  }

  void _sun(Canvas c, Offset at, double r, Color color) {
    _p.color = color.withValues(alpha: 0.25);
    c.drawCircle(at, r * 2.2, _p);
    _p.color = color;
    c.drawCircle(at, r, _p);
  }

  void _clouds(Canvas c, double w, double hz, double unit, double time, Color color) {
    _p.color = color;
    final rnd = math.Random(17);
    for (var i = 0; i < 5; i++) {
      final speed = 4 + rnd.nextDouble() * 6;
      final span = w + 240 * unit;
      final x = (rnd.nextDouble() * span + time * speed * unit) % span - 120 * unit;
      final y = hz * (0.12 + rnd.nextDouble() * 0.45);
      final s = (0.7 + rnd.nextDouble() * 0.6) * unit;
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 70 * s, height: 16 * s), _p);
      c.drawOval(Rect.fromCenter(center: Offset(x - 12 * s, y - 7 * s), width: 34 * s, height: 18 * s), _p);
      c.drawOval(Rect.fromCenter(center: Offset(x + 10 * s, y - 9 * s), width: 30 * s, height: 20 * s), _p);
    }
  }

  void _skyline(
    Canvas c,
    double w,
    double hz,
    double unit, {
    required int seed,
    required double maxH,
    required Color color,
    required bool lit,
  }) {
    final rnd = math.Random(seed);
    var x = -60.0 * unit;
    while (x < w + 60 * unit) {
      final bw = (10 + rnd.nextDouble() * 22) * unit;
      final bh = (maxH * (0.3 + rnd.nextDouble() * 0.7)) * unit;
      _p.color = color;
      c.drawRect(Rect.fromLTWH(x, hz - bh, bw, bh + 1), _p);
      // Rooftop antennas.
      if (rnd.nextDouble() < 0.25) {
        c.drawRect(Rect.fromLTWH(x + bw * 0.45, hz - bh - 8 * unit, 1.5 * unit, 8 * unit), _p);
      }
      if (lit) {
        _p.color = const Color(0x99FFE082);
        for (var wy = hz - bh + 4 * unit; wy < hz - 3 * unit; wy += 6 * unit) {
          for (var wx = x + 2 * unit; wx < x + bw - 3 * unit; wx += 5 * unit) {
            if (rnd.nextDouble() < 0.3) c.drawRect(Rect.fromLTWH(wx, wy, 2 * unit, 2.5 * unit), _p);
          }
        }
      }
      x += bw + rnd.nextDouble() * 4 * unit;
    }
  }

  void _hills(
    Canvas c,
    double w,
    double hz,
    double unit, {
    required int seed,
    required double height,
    required Color color,
  }) {
    final rnd = math.Random(seed);
    final path = Path()..moveTo(-80 * unit, hz + 1);
    for (var x = -80.0 * unit; x <= w + 80 * unit; x += 40 * unit) {
      final h = height * (0.4 + rnd.nextDouble() * 0.6) * unit;
      path.quadraticBezierTo(x + 20 * unit, hz - h * 2, x + 40 * unit, hz - h * 0.3);
    }
    path
      ..lineTo(w + 80 * unit, hz + 1)
      ..close();
    _p.color = color;
    c.drawPath(path, _p);
  }

  void _volcano(Canvas c, double x, double hz, double unit) {
    // A perfect cone on the horizon, Mayon-style.
    final h = 70 * unit;
    final path = Path()
      ..moveTo(x - 110 * unit, hz + 1)
      ..quadraticBezierTo(x - 20 * unit, hz - h * 0.6, x - 6 * unit, hz - h)
      ..lineTo(x + 6 * unit, hz - h)
      ..quadraticBezierTo(x + 20 * unit, hz - h * 0.6, x + 110 * unit, hz + 1)
      ..close();
    _p.color = const Color(0xFF8FA6B5);
    c.drawPath(path, _p);
    _p.color = const Color(0xCCFFFFFF);
    c.drawOval(
      Rect.fromCenter(center: Offset(x + 14 * unit, hz - h - 6 * unit), width: 30 * unit, height: 9 * unit),
      _p,
    );
  }

  void _mountains(
    Canvas c,
    double w,
    double hz,
    double unit, {
    required int seed,
    required double height,
    required Color color,
    required bool snow,
  }) {
    final rnd = math.Random(seed);
    var x = -90.0 * unit;
    while (x < w + 90 * unit) {
      final half = (40 + rnd.nextDouble() * 50) * unit;
      final h = height * (0.5 + rnd.nextDouble() * 0.5) * unit;
      final peak = Offset(x + half, hz - h);
      _p.color = color;
      c.drawPath(
        Path()
          ..moveTo(x, hz + 1)
          ..lineTo(peak.dx, peak.dy)
          ..lineTo(x + half * 2, hz + 1)
          ..close(),
        _p,
      );
      if (snow) {
        _p.color = const Color(0xEEFFFFFF);
        final t = 0.28;
        c.drawPath(
          Path()
            ..moveTo(peak.dx, peak.dy)
            ..lineTo(peak.dx + half * t, peak.dy + h * t)
            ..lineTo(peak.dx + half * t * 0.3, peak.dy + h * t * 0.8)
            ..lineTo(peak.dx - half * t * 0.4, peak.dy + h * t)
            ..lineTo(peak.dx - half * t, peak.dy + h * t)
            ..close(),
          _p,
        );
      }
      x += half * (1.1 + rnd.nextDouble() * 0.6);
    }
  }

  void _islands(Canvas c, double w, double hz, double unit) {
    _p.color = const Color(0xFF8D6E8A);
    for (final (x, r) in [(0.12, 26.0), (0.3, 14.0), (0.88, 20.0)]) {
      c.drawOval(Rect.fromCenter(center: Offset(w * x, hz), width: r * 3 * unit, height: r * unit), _p);
    }
  }
}
