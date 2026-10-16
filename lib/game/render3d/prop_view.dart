import 'dart:math' as math;
import 'dart:ui';

import '../components/lto_officer.dart';
import '../components/scenery_prop.dart';
import '../environments.dart';
import '../game_config.dart';
import '../painting/prop_painter.dart';
import 'camera3d.dart';
import 'shapes.dart';

/// Something to draw, sorted far-to-near by [sortY] (larger y = nearer).
class Drawable3D {
  Drawable3D(this.sortY, this.draw);

  final double sortY;
  final void Function(Canvas canvas) draw;
}

/// Roadside scenery and the LTO checkpoint in 3D.
class PropView {
  PropView._();

  static final Paint _p = Paint()..isAntiAlias = true;
  static final Paint _s = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static const _walls = [
    Color(0xFFB0BEC5),
    Color(0xFFCFD8DC),
    Color(0xFFBCAAA4),
    Color(0xFF90A4AE),
    Color(0xFFD7CCC8),
    Color(0xFFA1887F),
  ];

  static void drawProp(Canvas c, Camera3D cam, SceneryProp prop) {
    final z = cam.zOf(prop.y);
    // Fade in at the far edge of the draw distance.
    final alpha = ((Camera3D.farZ - 40 - z) / 300).clamp(0.0, 1.0);
    if (alpha <= 0.01) return;
    final x = prop.x;
    final y = prop.y;
    final w = prop.width;
    final l = prop.height;
    final v = prop.variant;
    void roofArt(Canvas c) {
      c.translate(x - w / 2, y - l / 2);
      PropPainter.paint(c, prop.type, Size(w, l), variant: v, onLeft: prop.onLeft);
    }

    switch (prop.type) {
      case PropType.building:
      case PropType.tower:
        final tower = prop.type == PropType.tower;
        final height = tower ? 140.0 + (v % 4) * 22 : 64.0 + (v % 4) * 14;
        final wall = tower
            ? const [Color(0xFF78909C), Color(0xFF5C7A99), Color(0xFF8DA4B8), Color(0xFF607D8B)][v % 4]
            : _walls[v % _walls.length];
        Shapes.box(
          c,
          cam,
          left: x - w / 2,
          right: x + w / 2,
          far: y - l / 2,
          near: y + l / 2,
          top: height,
          color: wall,
          roof: roofArt,
          nearFace: (c, s) => _facade(c, s, wall, tower: tower, shop: !tower && v.isEven),
          sideFace: (c, s) => _facade(c, s, wall, tower: tower, shop: false),
          alpha: alpha,
        );
      case PropType.nipaHut:
        _nipaHut(c, cam, x, y, w, l, roofArt, alpha);
      case PropType.sariSari:
        final wall = v.isEven ? const Color(0xFFD32F2F) : const Color(0xFF1976D2);
        Shapes.box(
          c,
          cam,
          left: x - w / 2,
          right: x + w / 2,
          far: y - l / 2,
          near: y + l / 2,
          top: 30,
          color: wall,
          roof: roofArt,
          nearFace: (c, s) => _storeFront(c, s, wall),
          sideFace: (c, s) => _storeFront(c, s, wall),
          alpha: alpha,
        );
      case PropType.tree:
        Shapes.shadow(c, cam, x, y, w, l * 0.8, opacity: 0.25 * alpha);
        Shapes.billboard(c, cam, x, y, 54, 74, (c, s) => _tree(c, s, v), alpha: alpha);
      case PropType.palm:
        Shapes.shadow(c, cam, x, y, w * 0.8, l * 0.6, opacity: 0.22 * alpha);
        Shapes.billboard(c, cam, x, y, 64, 100, (c, s) => _palm(c, s, v, prop.onLeft), alpha: alpha);
      case PropType.pine:
        Shapes.shadow(c, cam, x, y, w, l * 0.8, opacity: 0.25 * alpha);
        Shapes.billboard(c, cam, x, y, 40, 86, _pine, alpha: alpha);
      case PropType.bush:
        Shapes.billboard(c, cam, x, y, 34, 22, _bush, alpha: alpha);
      case PropType.rock:
        Shapes.shadow(c, cam, x, y, w, l, opacity: 0.25 * alpha);
        Shapes.billboard(c, cam, x, y, 40, 28, _rock, alpha: alpha);
      case PropType.streetlight:
        Shapes.billboard(c, cam, x, y, 40, 104, (c, s) => _streetlight(c, s, prop.onLeft), alpha: alpha);
      case PropType.roadSign:
        Shapes.billboard(c, cam, x, y, 40, 54, _roadSign, alpha: alpha);
      case PropType.warningSign:
        Shapes.billboard(c, cam, x, y, 24, 40, _warningSign, alpha: alpha);
      case PropType.billboard:
        Shapes.billboard(c, cam, x, y, 64, 84, (c, s) => _billboard(c, s, v), alpha: alpha);
      case PropType.boat:
        Shapes.billboard(c, cam, x, y, 56, 30, (c, s) => _boat(c, s, v), lift: -2, alpha: alpha);
      case PropType.flyover:
        _flyover(c, cam, prop, roofArt, alpha);
    }
  }

  // ------------------------------------------------------------ buildings

  static void _facade(Canvas c, Size s, Color wall, {required bool tower, required bool shop}) {
    final w = s.width;
    final h = s.height;
    final glass = tower ? const Color(0xFF9EC9E8) : const Color(0xFF455A64);
    final rows = (h / (tower ? 12 : 16)).floor();
    final cols = math.max(1, (w / 14).floor());
    final cw = w / cols;
    final rh = h / rows;
    final startRow = shop ? 1 : 0;
    for (var r = startRow; r < rows; r++) {
      for (var col = 0; col < cols; col++) {
        // A few lit windows for life.
        final lit = !tower && (r * 7 + col * 3) % 5 == 0;
        _p.color = lit ? const Color(0xFFFFE082) : glass;
        c.drawRect(Rect.fromLTWH(col * cw + cw * 0.22, r * rh + rh * 0.25, cw * 0.56, rh * 0.5), _p);
      }
    }
    if (tower) {
      _p.color = Shapes.shade(wall, 0.2);
      for (var r = 0; r < rows; r += 4) {
        c.drawRect(Rect.fromLTWH(0, r * rh, w, 1.5), _p);
      }
    }
    if (shop) {
      // Ground-floor shop with a coloured awning.
      _p.color = const Color(0xFF263238);
      c.drawRect(Rect.fromLTWH(w * 0.1, h - rh * 0.9, w * 0.8, rh * 0.9), _p);
      _p.color = const Color(0xFFFFCA28);
      c.drawRect(Rect.fromLTWH(w * 0.08, h - rh, w * 0.84, rh * 0.22), _p);
    }
  }

  static void _nipaHut(
    Canvas c,
    Camera3D cam,
    double x,
    double y,
    double w,
    double l,
    void Function(Canvas) roofArt,
    double alpha,
  ) {
    const bamboo = Color(0xFFC8A165);
    for (final (dx, dy) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)]) {
      final px = x + dx * (w / 2 - 4);
      final py = y + dy * (l / 2 - 4);
      Shapes.box(
        c,
        cam,
        left: px - 2,
        right: px + 2,
        far: py - 2,
        near: py + 2,
        top: 9,
        color: const Color(0xFF6D4C41),
        alpha: alpha,
      );
    }
    Shapes.box(
      c,
      cam,
      left: x - w / 2 + 2,
      right: x + w / 2 - 2,
      far: y - l / 2 + 2,
      near: y + l / 2 - 2,
      bottom: 9,
      top: 30,
      color: bamboo,
      nearFace: _bambooWall,
      sideFace: _bambooWall,
      alpha: alpha,
    );
    Shapes.box(
      c,
      cam,
      left: x - w / 2 - 3,
      right: x + w / 2 + 3,
      far: y - l / 2 - 3,
      near: y + l / 2 + 3,
      bottom: 30,
      top: 40,
      color: const Color(0xFFA67C42),
      roof: roofArt,
      roofSrc: Rect.fromLTRB(x - w / 2, y - l / 2, x + w / 2, y + l / 2),
      alpha: alpha,
    );
  }

  static void _bambooWall(Canvas c, Size s) {
    _s
      ..color = const Color(0x55704A1E)
      ..strokeWidth = 1;
    for (var x = 3.0; x < s.width; x += 4) {
      c.drawLine(Offset(x, 0), Offset(x, s.height), _s);
    }
    _p.color = const Color(0xFF3E2723);
    c.drawRect(Rect.fromLTWH(s.width * 0.35, s.height * 0.25, s.width * 0.3, s.height * 0.4), _p);
  }

  static void _storeFront(Canvas c, Size s, Color wall) {
    final w = s.width;
    final h = s.height;
    // Serving window with snacks hanging inside.
    _p.color = const Color(0xFF3E2723);
    c.drawRect(Rect.fromLTWH(w * 0.12, h * 0.35, w * 0.76, h * 0.4), _p);
    const goods = [Color(0xFFFFEB3B), Color(0xFFE53935), Color(0xFF43A047), Color(0xFF1E88E5)];
    for (var i = 0; i < 6; i++) {
      _p.color = goods[i % goods.length];
      c.drawRect(Rect.fromLTWH(w * 0.15 + i * w * 0.12, h * 0.38, w * 0.07, h * 0.12), _p);
    }
    _s
      ..color = const Color(0xFF8D6E63)
      ..strokeWidth = 1;
    for (var x = w * 0.15; x < w * 0.88; x += 4) {
      c.drawLine(Offset(x, h * 0.35), Offset(x, h * 0.75), _s);
    }
    // Striped awning.
    for (var i = 0; i < 8; i++) {
      _p.color = i.isEven ? const Color(0xFFFFFFFF) : const Color(0xFFFFC107);
      c.drawRect(Rect.fromLTWH(w * i / 8, h * 0.14, w / 8 + 0.5, h * 0.16), _p);
    }
    _p.color = Shapes.tint(wall, 0.4);
    c.drawRect(Rect.fromLTWH(w * 0.2, h * 0.02, w * 0.6, h * 0.1), _p);
  }

  // ------------------------------------------------------------ plants

  static void _tree(Canvas c, Size s, int v) {
    final w = s.width;
    final h = s.height;
    _p.color = const Color(0xFF6D4C41);
    c.drawRect(Rect.fromLTWH(w / 2 - 3.5, h * 0.5, 7, h * 0.5), _p);
    final greens = [const Color(0xFF2E7D32), const Color(0xFF388E3C), const Color(0xFF43A047)];
    _p.color = greens[0];
    c.drawCircle(Offset(w / 2, h * 0.38), w * 0.4, _p);
    _p.color = greens[1];
    c.drawCircle(Offset(w * 0.34, h * 0.42), w * 0.24, _p);
    c.drawCircle(Offset(w * 0.66, h * 0.4), w * 0.24, _p);
    _p.color = greens[2];
    c.drawCircle(Offset(w * 0.42 + (v % 3), h * 0.24), w * 0.2, _p);
    _p.color = const Color(0x22000000);
    c.drawCircle(Offset(w * 0.62, h * 0.5), w * 0.2, _p);
  }

  static void _palm(Canvas c, Size s, int v, bool onLeft) {
    final w = s.width;
    final h = s.height;
    final lean = (onLeft ? -1 : 1) * (6.0 + v % 4 * 2);
    final top = Offset(w / 2 + lean, h * 0.18);
    _s
      ..color = const Color(0xFF8D6E63)
      ..strokeWidth = 5;
    final trunk = Path()
      ..moveTo(w / 2, h)
      ..quadraticBezierTo(w / 2 - lean * 0.2, h * 0.5, top.dx, top.dy);
    c.drawPath(trunk, _s);
    _s
      ..color = const Color(0xFF6D4C41)
      ..strokeWidth = 1.2;
    for (var t = 0.25; t < 0.95; t += 0.1) {
      final y = h - (h - top.dy) * t;
      final x = w / 2 + (top.dx - w / 2) * t * t;
      c.drawLine(Offset(x - 2.5, y), Offset(x + 2.5, y), _s);
    }
    for (var i = 0; i < 7; i++) {
      final a = -math.pi * 0.95 + i * math.pi * 0.95 / 6 + (v % 3) * 0.05;
      final tip = top + Offset(math.cos(a) * w * 0.42, math.sin(a) * h * 0.12 + h * 0.08);
      final ctrl = top + Offset(math.cos(a) * w * 0.25, math.sin(a) * h * 0.2 - 4);
      _s
        ..color = i.isEven ? const Color(0xFF2E7D32) : const Color(0xFF43A047)
        ..strokeWidth = 4.5;
      c.drawPath(
        Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy),
        _s,
      );
    }
    _p.color = const Color(0xFF5D4037);
    c.drawCircle(top + const Offset(-2, 3), 3, _p);
    c.drawCircle(top + const Offset(3, 4), 3, _p);
  }

  static void _pine(Canvas c, Size s) {
    final w = s.width;
    final h = s.height;
    _p.color = const Color(0xFF5D4037);
    c.drawRect(Rect.fromLTWH(w / 2 - 2.5, h * 0.82, 5, h * 0.18), _p);
    const tiers = [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)];
    for (var i = 0; i < 3; i++) {
      final top = h * (0.02 + i * 0.22);
      final bottom = h * (0.4 + i * 0.22);
      final half = w * (0.28 + i * 0.1);
      _p.color = tiers[i];
      c.drawPath(
        Path()
          ..moveTo(w / 2, top)
          ..lineTo(w / 2 + half, bottom)
          ..lineTo(w / 2 - half, bottom)
          ..close(),
        _p,
      );
    }
  }

  static void _bush(Canvas c, Size s) {
    _p.color = const Color(0xFF558B2F);
    c.drawOval(Rect.fromLTWH(0, s.height * 0.2, s.width, s.height * 0.8), _p);
    _p.color = const Color(0xFF7CB342);
    c.drawOval(Rect.fromLTWH(s.width * 0.15, s.height * 0.1, s.width * 0.45, s.height * 0.55), _p);
    c.drawOval(Rect.fromLTWH(s.width * 0.5, s.height * 0.25, s.width * 0.38, s.height * 0.45), _p);
  }

  static void _rock(Canvas c, Size s) {
    final w = s.width;
    final h = s.height;
    _p.color = const Color(0xFF757575);
    c.drawPath(
      Path()
        ..moveTo(0, h)
        ..lineTo(w * 0.1, h * 0.4)
        ..lineTo(w * 0.35, h * 0.05)
        ..lineTo(w * 0.7, 0)
        ..lineTo(w * 0.95, h * 0.45)
        ..lineTo(w, h)
        ..close(),
      _p,
    );
    _p.color = const Color(0xFF9E9E9E);
    c.drawPath(
      Path()
        ..moveTo(w * 0.2, h * 0.45)
        ..lineTo(w * 0.38, h * 0.1)
        ..lineTo(w * 0.62, h * 0.08)
        ..lineTo(w * 0.5, h * 0.5)
        ..close(),
      _p,
    );
  }

  // ------------------------------------------------------------ street furniture

  static void _streetlight(Canvas c, Size s, bool onLeft) {
    c.save();
    // The lamp arm reaches over the road.
    if (!onLeft) {
      c.translate(s.width, 0);
      c.scale(-1, 1);
    }
    final w = s.width;
    final h = s.height;
    _p.color = const Color(0xFF546E7A);
    c.drawRect(Rect.fromLTWH(1, 6, 3.5, h - 6), _p);
    c.drawRect(Rect.fromLTWH(1, 4, w - 6, 3), _p);
    _p.color = const Color(0x40FFF59D);
    c.drawCircle(Offset(w - 6, 9), 12, _p);
    _p.color = const Color(0xFFFFF59D);
    c.drawRRect(RRect.fromLTRBR(w - 13, 6, w - 1, 10, const Radius.circular(2)), _p);
    _p.color = const Color(0xFF37474F);
    c.drawRect(Rect.fromLTWH(0, h - 5, 5.5, 5), _p);
    c.restore();
  }

  static void _roadSign(Canvas c, Size s) {
    final w = s.width;
    final h = s.height;
    _p.color = const Color(0xFF616161);
    c.drawRect(Rect.fromLTWH(w * 0.22, h * 0.3, 2.5, h * 0.7), _p);
    c.drawRect(Rect.fromLTWH(w * 0.78 - 2.5, h * 0.3, 2.5, h * 0.7), _p);
    _p.color = const Color(0xFF2E7D32);
    c.drawRRect(RRect.fromLTRBR(0, 0, w, h * 0.45, const Radius.circular(2.5)), _p);
    _p.color = const Color(0xFFFFFFFF);
    c.drawRect(Rect.fromLTWH(4, h * 0.08, w * 0.55, 3), _p);
    c.drawRect(Rect.fromLTWH(4, h * 0.2, w * 0.75, 3), _p);
    c.drawPath(
      Path()
        ..moveTo(w - 10, h * 0.3)
        ..lineTo(w - 4, h * 0.22)
        ..lineTo(w - 10, h * 0.14)
        ..close(),
      _p,
    );
  }

  static void _warningSign(Canvas c, Size s) {
    final w = s.width;
    final h = s.height;
    _p.color = const Color(0xFF424242);
    c.drawRect(Rect.fromLTWH(w / 2 - 1.2, h * 0.45, 2.4, h * 0.55), _p);
    _p.color = const Color(0xFFFFD600);
    c.drawPath(
      Path()
        ..moveTo(w / 2, 0)
        ..lineTo(w, w / 2)
        ..lineTo(w / 2, w)
        ..lineTo(0, w / 2)
        ..close(),
      _p,
    );
    _s
      ..color = const Color(0xFF212121)
      ..strokeWidth = 2.2;
    c.drawPath(
      Path()
        ..moveTo(w * 0.35, w * 0.65)
        ..lineTo(w * 0.35, w * 0.4)
        ..lineTo(w * 0.62, w * 0.4)
        ..moveTo(w * 0.55, w * 0.32)
        ..lineTo(w * 0.64, w * 0.4)
        ..lineTo(w * 0.55, w * 0.48),
      _s,
    );
  }

  static void _billboard(Canvas c, Size s, int v) {
    final w = s.width;
    final h = s.height;
    _p.color = const Color(0xFF455A64);
    c.drawRect(Rect.fromLTWH(w * 0.25, h * 0.45, 3, h * 0.55), _p);
    c.drawRect(Rect.fromLTWH(w * 0.75 - 3, h * 0.45, 3, h * 0.55), _p);
    const ads = [Color(0xFFFF7043), Color(0xFFAB47BC), Color(0xFF26A69A), Color(0xFFFFCA28)];
    _p.color = const Color(0xFF37474F);
    c.drawRect(Rect.fromLTWH(0, 0, w, h * 0.52), _p);
    _p.color = ads[v % ads.length];
    c.drawRect(Rect.fromLTWH(2, 2, w - 4, h * 0.52 - 4), _p);
    _p.color = const Color(0xDDFFFFFF);
    c.drawRect(Rect.fromLTWH(6, 7, w * 0.45, 5), _p);
    c.drawRect(Rect.fromLTWH(6, 16, w * 0.3, 4), _p);
    c.drawCircle(Offset(w * 0.76, h * 0.26), 9, _p);
    _p.color = ads[(v + 1) % ads.length];
    c.drawCircle(Offset(w * 0.76, h * 0.26), 5, _p);
  }

  static void _boat(Canvas c, Size s, int v) {
    final w = s.width;
    final h = s.height;
    // Bamboo outriggers spread to both sides.
    _s
      ..color = const Color(0xFFD7CCC8)
      ..strokeWidth = 2;
    c.drawLine(Offset(0, h * 0.72), Offset(w, h * 0.72), _s);
    c.drawLine(Offset(w * 0.06, h * 0.72), Offset(w * 0.06, h * 0.86), _s);
    c.drawLine(Offset(w * 0.94, h * 0.72), Offset(w * 0.94, h * 0.86), _s);
    _p.color = v.isEven ? const Color(0xFFFFFFFF) : const Color(0xFFFFEB3B);
    c.drawPath(
      Path()
        ..moveTo(w * 0.32, h * 0.55)
        ..lineTo(w * 0.68, h * 0.55)
        ..lineTo(w * 0.56, h * 0.95)
        ..lineTo(w * 0.44, h * 0.95)
        ..close(),
      _p,
    );
    _p.color = const Color(0xFF1E88E5);
    c.drawRect(Rect.fromLTWH(w * 0.34, h * 0.55, w * 0.32, h * 0.08), _p);
    // Small sail.
    _p.color = const Color(0xFFFFF3E0);
    c.drawPath(
      Path()
        ..moveTo(w * 0.5, 0)
        ..lineTo(w * 0.5, h * 0.52)
        ..lineTo(w * 0.72, h * 0.48)
        ..close(),
      _p,
    );
    _p.color = const Color(0x6681D4FA);
    c.drawRect(Rect.fromLTWH(0, h * 0.94, w, h * 0.06), _p);
  }

  static void _flyover(Canvas c, Camera3D cam, SceneryProp prop, void Function(Canvas) roofArt, double alpha) {
    // Fade the deck out as it passes over the rider so it never hides them.
    final z = cam.zOf(prop.y);
    final a = alpha * (0.25 + 0.75 * ((z - 60) / 220).clamp(0.0, 1.0));
    final far = prop.y - prop.height / 2;
    final near = prop.y + prop.height / 2;
    const concrete = Color(0xFFB0BEC5);
    for (final px in [GameConfig.roadLeft - 34.0, GameConfig.roadRight + 22.0]) {
      Shapes.box(
        c,
        cam,
        left: px,
        right: px + 12,
        far: prop.y - 6,
        near: prop.y + 6,
        top: 112,
        color: const Color(0xFF90A4AE),
        alpha: a,
      );
    }
    Shapes.box(
      c,
      cam,
      left: -500,
      right: 900,
      far: far,
      near: near,
      bottom: 112,
      top: 134,
      color: concrete,
      roofSrc: Rect.fromLTRB(-500, far, 900, near),
      roof: roofArt,
      nearFace: (c, s) {
        _p.color = const Color(0xFF78909C);
        c.drawRect(Rect.fromLTWH(0, s.height - 4, s.width, 4), _p);
        _p.color = const Color(0xFFECEFF1);
        c.drawRect(Rect.fromLTWH(0, 0, s.width, 3), _p);
        _p.color = const Color(0xFF1565C0);
        c.drawRect(Rect.fromLTWH(s.width / 2 - 40, 6, 80, 11), _p);
      },
      alpha: a,
    );
  }

  // ------------------------------------------------------------ checkpoint

  static void collectCheckpoint(List<Drawable3D> out, Camera3D cam, LtoCheckpoint cp) {
    const roadL = GameConfig.roadLeft;
    const roadR = GameConfig.roadRight;
    final top = cp.y - cp.height / 2;
    final time = cp.time;

    // Overhead gantry with the banner.
    out.add(
      Drawable3D(top + 8, (c) {
        const post = Color(0xFF37474F);
        Shapes.box(c, cam, left: roadL - 12, right: roadL - 4, far: top, near: top + 8, top: 92, color: post);
        Shapes.box(c, cam, left: roadR + 4, right: roadR + 12, far: top, near: top + 8, top: 92, color: post);
        Shapes.box(
          c,
          cam,
          left: roadL - 12,
          right: roadR + 12,
          far: top + 1,
          near: top + 7,
          bottom: 86,
          top: 92,
          color: post,
        );
        Shapes.box(
          c,
          cam,
          left: roadL + 30,
          right: roadR - 30,
          far: top + 2,
          near: top + 6,
          bottom: 62,
          top: 86,
          color: const Color(0xFF0D47A1),
          nearFace: (c, s) {
            _p.color = const Color(0xFFFFD600);
            c.drawRect(Rect.fromLTWH(0, s.height - 3, s.width, 3), _p);
            final text = LtoCheckpoint.bannerText;
            final k = math.min(1.25, (s.width - 12) / text.width);
            c.save();
            c.translate(s.width / 2, (s.height - 3) / 2);
            c.scale(k);
            text.paint(c, Offset(-text.width / 2, -text.height / 2));
            c.restore();
          },
        );
      }),
    );

    // Cones lining the right shoulder.
    for (var i = 0; i < 4; i++) {
      final cy = top + 8 + i * 22;
      out.add(Drawable3D(cy, (c) => Shapes.billboard(c, cam, roadR - 10, cy, 14, 20, _miniCone)));
    }

    // Booth with a flashing beacon.
    final boothFar = top + 27;
    final boothNear = top + 67;
    out.add(
      Drawable3D(boothNear, (c) {
        Shapes.shadow(c, cam, roadR + 36, (boothFar + boothNear) / 2, 48, 44);
        Shapes.box(
          c,
          cam,
          left: roadR + 14,
          right: roadR + 58,
          far: boothFar,
          near: boothNear,
          top: 40,
          color: const Color(0xFF1565C0),
          nearFace: _boothFace,
          sideFace: _boothFace,
        );
        final on = (time * 3).floor().isEven;
        Shapes.billboard(c, cam, roadR + 50, boothFar + 6, 10, 8, (c, s) {
          if (on) {
            _p.color = const Color(0x55FFAB00);
            c.drawCircle(Offset(s.width / 2, s.height / 2), 12, _p);
          }
          _p.color = on ? const Color(0xFFFFAB00) : const Color(0xFF8D6E00);
          c.drawRRect(RRect.fromLTRBR(1, 0, s.width - 1, s.height, const Radius.circular(3)), _p);
        }, lift: 40);
      }),
    );

    // Officer waving a stop paddle beside the road.
    final officerY = top + 70;
    out.add(
      Drawable3D(officerY, (c) {
        Shapes.shadow(c, cam, roadR + 4, officerY, 12, 8);
        Shapes.billboard(c, cam, roadR + 4, officerY, 22, 40, (c, s) => _officerFigure(c, s, time));
      }),
    );

    // Raised boom gate.
    final gateY = top + 82;
    out.add(
      Drawable3D(gateY, (c) {
        Shapes.box(
          c,
          cam,
          left: roadR + 2,
          right: roadR + 10,
          far: gateY - 4,
          near: gateY + 4,
          top: 10,
          color: const Color(0xFF37474F),
        );
        Shapes.billboard(c, cam, roadR + 6, gateY, 4, 56, (c, s) {
          for (var i = 0; i < 7; i++) {
            _p.color = i.isEven ? const Color(0xFFD50000) : const Color(0xFFFFFFFF);
            c.drawRect(Rect.fromLTWH(0, s.height * i / 7, s.width, s.height / 7 + 0.3), _p);
          }
        }, lift: 10);
      }),
    );
  }

  /// "Slow down" chevrons painted on the road before the gantry.
  static void drawCheckpointDecal(Canvas c, Camera3D cam, LtoCheckpoint cp) {
    final bottom = cp.y + cp.height / 2;
    Shapes.decal(c, cam, Rect.fromLTRB(GameConfig.roadLeft, bottom - 16, GameConfig.roadRight, bottom), (c) {
      _p.color = const Color(0x99FFFFFF);
      for (var lane = 0; lane < GameConfig.laneCount; lane++) {
        final cx = GameConfig.laneCenter(lane);
        c.drawPath(
          Path()
            ..moveTo(cx - 14, bottom - 4)
            ..lineTo(cx, bottom - 14)
            ..lineTo(cx + 14, bottom - 4)
            ..lineTo(cx + 14, bottom)
            ..lineTo(cx, bottom - 10)
            ..lineTo(cx - 14, bottom)
            ..close(),
          _p,
        );
      }
    });
  }

  static void _miniCone(Canvas c, Size s) {
    _p.color = const Color(0xFFFF6D00);
    c.drawPath(
      Path()
        ..moveTo(s.width * 0.42, 0)
        ..lineTo(s.width * 0.58, 0)
        ..lineTo(s.width * 0.9, s.height)
        ..lineTo(s.width * 0.1, s.height)
        ..close(),
      _p,
    );
    _p.color = const Color(0xFFFFFFFF);
    c.drawRect(Rect.fromLTWH(s.width * 0.3, s.height * 0.4, s.width * 0.4, s.height * 0.16), _p);
  }

  static void _boothFace(Canvas c, Size s) {
    final w = s.width;
    final h = s.height;
    _p.color = const Color(0xFFFFFFFF);
    c.drawRect(Rect.fromLTWH(0, h * 0.12, w, h * 0.2), _p);
    final text = LtoCheckpoint.boothText;
    text.paint(c, Offset(w / 2 - text.width / 2, h * 0.22 - text.height / 2));
    _p.color = const Color(0xFF22344A);
    c.drawRect(Rect.fromLTWH(w * 0.15, h * 0.42, w * 0.7, h * 0.3), _p);
    _p.color = const Color(0x335E86B0);
    c.drawRect(Rect.fromLTWH(w * 0.2, h * 0.44, w * 0.12, h * 0.26), _p);
  }

  static void _officerFigure(Canvas c, Size s, double time) {
    final w = s.width;
    final h = s.height;
    _p.color = const Color(0xFF263238);
    c.drawRect(Rect.fromLTWH(w * 0.32, h * 0.62, w * 0.14, h * 0.38), _p);
    c.drawRect(Rect.fromLTWH(w * 0.54, h * 0.62, w * 0.14, h * 0.38), _p);
    _p.color = const Color(0xFF1565C0);
    c.drawRRect(RRect.fromLTRBR(w * 0.26, h * 0.28, w * 0.74, h * 0.66, const Radius.circular(4)), _p);
    _p.color = const Color(0xFFFFCC80);
    c.drawCircle(Offset(w / 2, h * 0.2), w * 0.17, _p);
    _p.color = const Color(0xFFFFFFFF);
    c.drawRect(Rect.fromLTWH(w * 0.3, h * 0.06, w * 0.4, h * 0.06), _p);
    _p.color = const Color(0xFF0D47A1);
    c.drawRect(Rect.fromLTWH(w * 0.24, h * 0.11, w * 0.52, h * 0.03), _p);
    // Waving arm with the red paddle.
    final wave = math.sin(time * 10) * 0.5;
    _s
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 3.5;
    final shoulder = Offset(w * 0.3, h * 0.32);
    final hand = shoulder + Offset(-w * 0.2 + wave * 3, -h * 0.2);
    c.drawLine(shoulder, hand, _s);
    _p.color = const Color(0xFFD50000);
    c.drawCircle(hand + const Offset(0, -4), 5, _p);
    _p.color = const Color(0xFFFFFFFF);
    c.drawRect(Rect.fromCenter(center: hand + const Offset(0, -4), width: 6, height: 1.6), _p);
  }
}
