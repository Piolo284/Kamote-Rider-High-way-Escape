import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import '../game_config.dart';
import 'camera3d.dart';

/// The secret LRT tunnel: concrete walls and ceiling, darkness that only
/// the headlight and the lamps cut through, and daylight at the exit.
class TunnelView {
  TunnelView._();

  static final Paint _p = Paint()..isAntiAlias = true;
  static final Path _path = Path();

  /// Walls stand this far outside the road edges.
  static const double wallGap = 52;

  /// Road distance between ceiling lights and wall joints.
  static const double bay = 140;

  static double _ceiling(Camera3D cam) => cam.camHeight + 70;

  static void _poly(Canvas c, List<Offset> points, Paint paint) {
    _path.reset();
    _path.moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      _path.lineTo(p.dx, p.dy);
    }
    _path.close();
    c.drawPath(_path, paint);
  }

  /// World rows of the ceiling lights / wall joints between [cam.farY] and
  /// [cam.nearY]; they are fixed to the road so they stream past.
  static Iterable<double> _bays(Camera3D cam, double scroll, double viewHeight) sync* {
    // Road distance D sits at world row viewHeight - (D - scroll).
    final first = ((viewHeight + scroll - cam.nearY) / bay).ceil();
    final last = ((viewHeight + scroll - cam.farY) / bay).floor();
    for (var k = last; k >= first; k--) {
      yield viewHeight - (k * bay - scroll);
    }
  }

  /// Ceiling, walls and the light at the end of the tunnel.
  static void structure(
    Canvas c,
    Camera3D cam, {
    required double scroll,
    required double viewHeight,
    required double exitGlow,
  }) {
    final w = cam.width;
    final ceiling = _ceiling(cam);
    _p.shader = ui.Gradient.linear(Offset.zero, Offset(0, cam.horizonY), const [Color(0xFF0B0C0E), Color(0xFF1C1F23)]);
    c.drawRect(Rect.fromLTWH(0, 0, w, cam.horizonY + 2), _p);
    _p.shader = null;

    final far = cam.farY;
    final near = cam.nearY;
    for (final x in [GameConfig.roadLeft - wallGap, GameConfig.roadRight + wallGap]) {
      final quad = [
        cam.project(x, far, ceiling),
        cam.project(x, near, ceiling),
        cam.project(x, near, 0),
        cam.project(x, far, 0),
      ];
      paintOnQuad(c, Rect.fromLTRB(far, 0, near, ceiling), quad, (c) {
        _p.color = const Color(0xFF34383D);
        c.drawRect(Rect.fromLTRB(far, 0, near, ceiling), _p);
        // Grimy lower band, a cable tray and a yellow guide stripe.
        _p.color = const Color(0xFF26292D);
        c.drawRect(Rect.fromLTRB(far, ceiling - 34, near, ceiling), _p);
        _p.color = const Color(0xFF1C1E21);
        c.drawRect(Rect.fromLTRB(far, ceiling - 120, near, ceiling - 112), _p);
        _p.color = const Color(0xFFB08A1E);
        c.drawRect(Rect.fromLTRB(far, ceiling - 40, near, ceiling - 36), _p);
        _p.color = const Color(0xFF2A2D31);
        for (final y in _bays(cam, scroll, viewHeight)) {
          c.drawRect(Rect.fromLTWH(y - 2, 0, 4, ceiling), _p);
        }
      });
    }

    // Daylight growing at the far end as the exit approaches.
    if (exitGlow > 0) {
      final y = cam.playerY - Camera3D.farZ + 200;
      final a = cam.project(GameConfig.roadLeft - wallGap, y, ceiling * 0.8);
      final b = cam.project(GameConfig.roadRight + wallGap, y);
      final rect = Rect.fromPoints(a, b);
      _p.shader = ui.Gradient.radial(rect.center, math.max(rect.width, 8) * 2.4, [
        Color.fromRGBO(255, 248, 220, 0.75 * exitGlow),
        const Color(0x00FFF8DC),
      ]);
      c.drawCircle(rect.center, math.max(rect.width, 8) * 2.4, _p);
      _p.shader = null;
      _p.color = Color.fromRGBO(255, 252, 235, exitGlow);
      c.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(rect.width * 0.3)), _p);
    }
  }

  /// Darkens the tunnel except for the headlight, the lamps and train lights.
  static void darkness(
    Canvas c,
    Camera3D cam, {
    required Offset rider,
    required bool headlight,
    required List<Offset> lamps,
    required List<Offset> trainLights,
  }) {
    final screen = Rect.fromLTWH(0, 0, cam.width, cam.height);
    c.saveLayer(screen, Paint());
    _p.color = const Color(0xC8030408);
    c.drawRect(screen, _p);
    final cut = Paint()
      ..isAntiAlias = true
      ..blendMode = BlendMode.dstOut;

    final px = rider.dx;
    final py = rider.dy;
    if (headlight) {
      final cone = [
        cam.project(px - 8, py - 12),
        cam.project(px + 8, py - 12),
        cam.project(px + 85, py - 620),
        cam.project(px - 85, py - 620),
      ];
      cut.shader = ui.Gradient.linear(cone[0], cone[3], const [Color(0xF2FFFFFF), Color(0x00FFFFFF)]);
      _poly(c, cone, cut);
    }
    // A pool of light around the rider so they are always readable.
    final s = cam.scaleAt(py);
    final halo = cam.project(px, py, 18);
    cut.shader = ui.Gradient.radial(halo, 46 * s, const [Color(0xE6FFFFFF), Color(0x00FFFFFF)]);
    c.drawCircle(halo, 46 * s, cut);

    for (final lamp in lamps) {
      if (!cam.isVisible(lamp.dy)) continue;
      final ls = cam.scaleAt(lamp.dy);
      final at = cam.project(lamp.dx, lamp.dy, 40);
      cut.shader = ui.Gradient.radial(at, 70 * ls, const [Color(0xB3FFFFFF), Color(0x00FFFFFF)]);
      c.drawCircle(at, 70 * ls, cut);
    }
    for (final light in trainLights) {
      if (!cam.isVisible(light.dy)) continue;
      final ls = cam.scaleAt(light.dy);
      final at = cam.project(light.dx, light.dy, 14);
      cut.shader = ui.Gradient.radial(at, 60 * ls, const [Color(0xCCFFFFFF), Color(0x00FFFFFF)]);
      c.drawCircle(at, 60 * ls, cut);
    }
    c.restore();
  }

  /// Things that glow on top of the darkness: ceiling lights, wall lamps
  /// and LRT headlights.
  static void glows(
    Canvas c,
    Camera3D cam, {
    required double scroll,
    required double viewHeight,
    required List<Offset> lamps,
    required List<Offset> trainLights,
  }) {
    final ceiling = _ceiling(cam);
    _p.color = const Color(0xFFFFF3C4);
    for (final y in _bays(cam, scroll, viewHeight)) {
      if (!cam.isVisible(y)) continue;
      _poly(c, [
        cam.project(GameConfig.worldWidth / 2 - 14, y - 9, ceiling),
        cam.project(GameConfig.worldWidth / 2 + 14, y - 9, ceiling),
        cam.project(GameConfig.worldWidth / 2 + 14, y + 9, ceiling),
        cam.project(GameConfig.worldWidth / 2 - 14, y + 9, ceiling),
      ], _p);
    }
    final glow = Paint()
      ..isAntiAlias = true
      ..blendMode = BlendMode.plus;
    for (final lamp in lamps) {
      if (!cam.isVisible(lamp.dy)) continue;
      final at = cam.project(lamp.dx, lamp.dy, 76);
      final r = 16 * cam.scaleAt(lamp.dy);
      glow.shader = ui.Gradient.radial(at, r, const [Color(0x88FFE0A0), Color(0x00FFE0A0)]);
      c.drawCircle(at, r, glow);
    }
    for (final light in trainLights) {
      if (!cam.isVisible(light.dy)) continue;
      final at = cam.project(light.dx, light.dy, 38);
      final r = 22 * cam.scaleAt(light.dy);
      glow.shader = ui.Gradient.radial(at, r, const [Color(0xCCFFFDE7), Color(0x00FFFDE7)]);
      c.drawCircle(at, r, glow);
    }
  }
}
