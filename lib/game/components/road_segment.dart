import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../environments.dart';
import '../game_config.dart';
import '../kamote_game.dart';
import '../systems/collision_system.dart';
import 'highway_entity.dart';

/// Draws the endless highway as a stream of fixed-height segments.
///
/// Each segment remembers the environment that was active when it first
/// appeared at the top of the screen, so a new world rolls in smoothly from
/// the horizon instead of flashing in.
class RoadComponent extends Component with HasGameReference<KamoteGame> {
  RoadComponent() : super(priority: -10);

  static const double segmentHeight = 200;

  /// Total world units scrolled this run.
  double scroll = 0;
  final Map<int, int> _segmentEnv = {};
  double _time = 0;

  static final Paint _p = Paint()..isAntiAlias = false;
  static final Paint _s = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;

  void reset() {
    scroll = 0;
    _segmentEnv.clear();
    _decor.clear();
  }

  final Map<int, _SegmentDecor> _decor = {};

  /// Builds (once) the worn-asphalt details for segment [k].
  _SegmentDecor _decorFor(int k, EnvironmentTheme env) => _decor.putIfAbsent(k, () {
    final rnd = math.Random(k * 7919 + 17);
    const roadL = GameConfig.roadLeft;
    final patches = <Rect>[
      for (var i = 0; i < 2 + rnd.nextInt(2); i++)
        Rect.fromLTWH(
          roadL + 4 + rnd.nextDouble() * 230,
          rnd.nextDouble() * 170,
          18 + rnd.nextDouble() * 34,
          10 + rnd.nextDouble() * 22,
        ),
    ];
    final cracks = Path();
    for (var i = 0; i < 2; i++) {
      var x = roadL + 10 + rnd.nextDouble() * 250;
      var y = rnd.nextDouble() * 180;
      cracks.moveTo(x, y);
      for (var j = 0; j < 4; j++) {
        x += -8 + rnd.nextDouble() * 16;
        y += 4 + rnd.nextDouble() * 8;
        cracks.lineTo(x, y);
      }
    }
    final stains = <Offset>[
      if (rnd.nextDouble() < 0.5)
        Offset(
          GameConfig.laneCenter(rnd.nextInt(GameConfig.laneCount)) + (rnd.nextDouble() - 0.5) * 20,
          rnd.nextDouble() * 180,
        ),
    ];
    final urban = env.leftGround == GroundStyle.sidewalk || env.leftGround == GroundStyle.concrete;
    final manhole = urban && rnd.nextDouble() < 0.35
        ? Offset(GameConfig.laneCenter(rnd.nextInt(GameConfig.laneCount)) + 18, 30 + rnd.nextDouble() * 140)
        : null;
    return _SegmentDecor(patches, cracks, stains, manhole);
  });

  static final Paint _crack = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1
    ..color = const Color(0x40000000);

  void _drawWear(Canvas c, _SegmentDecor d, double top) {
    const roadL = GameConfig.roadLeft;
    const roadR = GameConfig.roadRight;
    // Darker tyre-worn tracks in every lane.
    _p.color = const Color(0x12000000);
    for (var lane = 0; lane < GameConfig.laneCount; lane++) {
      final cx = GameConfig.laneCenter(lane);
      c.drawRect(Rect.fromLTWH(cx - 20, top - 1, 9, RoadComponent.segmentHeight + 2), _p);
      c.drawRect(Rect.fromLTWH(cx + 11, top - 1, 9, RoadComponent.segmentHeight + 2), _p);
    }
    // Shade toward the road edges (camber).
    _p.color = const Color(0x1A000000);
    c.drawRect(Rect.fromLTWH(roadL, top - 1, 8, RoadComponent.segmentHeight + 2), _p);
    c.drawRect(Rect.fromLTWH(roadR - 8, top - 1, 8, RoadComponent.segmentHeight + 2), _p);
    // Repair patches: slightly darker asphalt with a lighter seam.
    for (final r in d.patches) {
      final rr = r.shift(Offset(0, top));
      _p.color = const Color(0x1C000000);
      c.drawRect(rr, _p);
      _p.color = const Color(0x10FFFFFF);
      c.drawRect(Rect.fromLTWH(rr.left, rr.top, rr.width, 1.2), _p);
    }
    for (final o in d.stains) {
      _p.color = const Color(0x22000000);
      c.drawOval(Rect.fromCenter(center: o.translate(0, top), width: 22, height: 13), _p);
    }
    final manhole = d.manhole;
    if (manhole != null) {
      final m = manhole.translate(0, top);
      _p.color = const Color(0xFF55595D);
      c.drawCircle(m, 9, _p);
      _p.color = const Color(0xFF3F4347);
      c.drawCircle(m, 7, _p);
      _p.color = const Color(0x22FFFFFF);
      c.drawRect(Rect.fromCenter(center: m, width: 12, height: 1.5), _p);
      c.drawRect(Rect.fromCenter(center: m, width: 1.5, height: 12), _p);
    }
    c.save();
    c.translate(0, top);
    c.drawPath(d.cracks, _crack);
    c.restore();
  }

  @override
  void update(double dt) {
    scroll += game.scrollSpeed * dt;
    _time += dt;
    final first = (scroll / segmentHeight).floor();
    _segmentEnv.removeWhere((k, _) => k < first - 1);
    _decor.removeWhere((k, _) => k < first - 1);
  }

  int _envFor(int k) => _segmentEnv.putIfAbsent(k, () => game.distance.environmentIndex);

  @override
  void render(Canvas canvas) {
    final viewH = game.viewHeight;
    final first = (scroll / segmentHeight).floor();
    final last = ((scroll + viewH) / segmentHeight).floor();
    // Assign from the top down so the newest segment gets the current world.
    for (var k = last; k >= first; k--) {
      _envFor(k);
    }
    for (var k = first; k <= last; k++) {
      final top = viewH - ((k + 1) * segmentHeight - scroll);
      _drawSegment(canvas, Environments.at(_segmentEnv[k]!), k, top);
    }
    _drawLaneMarkings(canvas, viewH);
  }

  // Screen y of a road distance d is: viewH - (d - scroll).
  void _drawSegment(Canvas c, EnvironmentTheme env, int k, double top) {
    const h = segmentHeight;
    const roadL = GameConfig.roadLeft;
    const roadR = GameConfig.roadRight;
    const sh = GameConfig.shoulderWidth;
    // Overlap by 1 unit to avoid hairline seams between segments.
    final rectTop = top - 1;
    const rectH = h + 2;

    _ground(c, env.leftGround, env.leftColor, env.detailColor, -800, roadL - sh, rectTop, rectH, k, true);
    _ground(c, env.rightGround, env.rightColor, env.detailColor, roadR + sh, 1200, rectTop, rectH, k, false);

    _p.color = env.shoulder;
    c.drawRect(Rect.fromLTWH(roadL - sh, rectTop, sh, rectH), _p);
    c.drawRect(Rect.fromLTWH(roadR, rectTop, sh, rectH), _p);

    _p.color = env.asphalt;
    c.drawRect(Rect.fromLTWH(roadL, rectTop, roadR - roadL, rectH), _p);

    _drawWear(c, _decorFor(k, env), top);

    if (env.crosswalks && k % 6 == 3) {
      _p.color = const Color(0xDDFFFFFF);
      for (var x = roadL + 6; x < roadR - 10; x += 16) {
        c.drawRect(Rect.fromLTWH(x, top + 80, 9, 40), _p);
      }
    }

    if (env.guardrails) {
      for (final railX in [roadL - sh - 2.0, roadR + sh - 2.0]) {
        _p.color = const Color(0xFF90A4AE);
        c.drawRect(Rect.fromLTWH(railX, rectTop, 4, rectH), _p);
        _p.color = const Color(0xFF546E7A);
        for (var y = 0.0; y < h; y += 25) {
          c.drawRect(Rect.fromLTWH(railX - 1, top + y, 6, 4), _p);
        }
      }
    }
  }

  void _ground(
    Canvas c,
    GroundStyle style,
    Color base,
    Color detail,
    double left,
    double right,
    double top,
    double h,
    int k,
    bool isLeft,
  ) {
    _p.color = base;
    c.drawRect(Rect.fromLTRB(left, top, right, top + h), _p);
    final nearEdge = isLeft ? right : left;
    final rnd = math.Random(k * 31 + (isLeft ? 1 : 2));
    switch (style) {
      case GroundStyle.sidewalk:
      case GroundStyle.concrete:
        _p.color = detail;
        final step = style == GroundStyle.sidewalk ? 20.0 : 32.0;
        for (var y = 0.0; y < h; y += step) {
          c.drawRect(Rect.fromLTRB(left, top + y, right, top + y + 1.5), _p);
        }
        for (var x = nearEdge; isLeft ? x > left : x < right; x += isLeft ? -step : step) {
          c.drawRect(Rect.fromLTWH(x, top, 1.5, h), _p);
        }
        _p.color = const Color(0xFFCFD8DC);
        c.drawRect(Rect.fromLTWH(isLeft ? right - 4 : left, top, 4, h), _p);
      case GroundStyle.ricefield:
        _p.color = detail;
        for (var x = nearEdge + (isLeft ? -10 : 10); isLeft ? x > left : x < right; x += isLeft ? -7 : 7) {
          c.drawRect(Rect.fromLTWH(x, top, 2, h), _p);
        }
        _p.color = const Color(0xFF8D6E63);
        c.drawRect(Rect.fromLTRB(left, top + 96, right, top + 100), _p);
        c.drawRect(Rect.fromLTWH(isLeft ? right - 6 : left, top, 6, h), _p);
      case GroundStyle.forest:
        _p.color = detail.withValues(alpha: 0.5);
        for (var i = 0; i < 6; i++) {
          final dx = rnd.nextDouble() * 300;
          c.drawCircle(Offset(isLeft ? nearEdge - 8 - dx : nearEdge + 8 + dx, top + rnd.nextDouble() * h), 8, _p);
        }
        _p.color = const Color(0xFF1B5E20);
        for (var i = 0; i < 5; i++) {
          final dx = rnd.nextDouble() * 300;
          c.drawCircle(Offset(isLeft ? nearEdge - 10 - dx : nearEdge + 10 + dx, top + rnd.nextDouble() * h), 6, _p);
        }
      case GroundStyle.cliff:
        _p.color = detail;
        for (var y = 0.0; y < h; y += 26) {
          final path = Path()
            ..moveTo(left, top + y)
            ..lineTo(right - 6, top + y + 14)
            ..lineTo(right - 6, top + y + 20)
            ..lineTo(left, top + y + 8)
            ..close();
          c.drawPath(path, _p);
        }
        _p.color = const Color(0xFF9E9E9E);
        c.drawRect(Rect.fromLTWH(isLeft ? right - 6 : left, top, 6, h), _p);
      case GroundStyle.sea:
        _s
          ..color = detail
          ..strokeWidth = 2;
        for (var i = 0; i < 7; i++) {
          final x = nearEdge - 24 - rnd.nextDouble() * 280;
          final y = top + rnd.nextDouble() * h;
          final drift = math.sin(_time * 2 + i) * 4;
          c.drawArc(Rect.fromLTWH(x + drift, y, 18, 8), math.pi, math.pi, false, _s);
        }
        _p.color = const Color(0xFFFFE082);
        c.drawRect(Rect.fromLTWH(isLeft ? right - 14 : left, top, 14, h), _p);
        _p.color = const Color(0xAAFFFFFF);
        c.drawRect(Rect.fromLTWH(isLeft ? right - 16 : left + 14, top, 2, h), _p);
      case GroundStyle.sand:
        _p.color = const Color(0xFFFFD54F);
        for (var i = 0; i < 14; i++) {
          final dx = rnd.nextDouble() * 300;
          c.drawCircle(Offset(isLeft ? nearEdge - dx : nearEdge + dx, top + rnd.nextDouble() * h), 1.5, _p);
        }
    }
  }

  void _drawLaneMarkings(Canvas c, double viewH) {
    const roadL = GameConfig.roadLeft;
    const lw = GameConfig.laneWidth;
    const dash = 26.0;
    const period = 56.0;
    // Phase so dashes move with the road.
    final phase = scroll % period;
    for (final lane in [1, 3]) {
      final x = roadL + lw * lane - 2;
      for (var y = -period + phase; y < viewH; y += period) {
        // Paint wears unevenly; the fade is keyed to the dash's road
        // position so it stays fixed while scrolling.
        final idx = ((scroll + viewH - y) / period).round() + lane * 7;
        final wear = ((idx * 2654435761) % 1000) / 1000;
        _p.color = Color.fromRGBO(255, 255, 255, 0.62 + 0.33 * wear);
        c.drawRect(Rect.fromLTWH(x, y, 4, dash), _p);
      }
    }
    // Center double yellow separates oncoming lanes.
    _p.color = const Color(0xFFFFC400);
    final cx = roadL + lw * GameConfig.oncomingLaneCount;
    c.drawRect(Rect.fromLTWH(cx - 5, 0, 3, viewH), _p);
    c.drawRect(Rect.fromLTWH(cx + 2, 0, 3, viewH), _p);
    // Edge lines.
    _p.color = const Color(0xCCFFFFFF);
    c.drawRect(Rect.fromLTWH(roadL + 2, 0, 3, viewH), _p);
    c.drawRect(Rect.fromLTWH(GameConfig.roadRight - 5, 0, 3, viewH), _p);
  }
}

/// Invisible guardrail along one side of the road. Scraping it is a side
/// collision.
class RoadEdge extends PositionComponent with Hazard {
  RoadEdge({required this.isLeft}) : super(priority: 0);

  final bool isLeft;

  @override
  HazardKind get hazardKind => HazardKind.roadEdge;

  @override
  Rect get hitRect => toRect();

  @override
  Rect get previousHitRect => toRect();

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.passive)..size = size);
  }

  void layout(double viewHeight) {
    const thickness = 40.0;
    position = Vector2(isLeft ? GameConfig.roadLeft - thickness : GameConfig.roadRight, -200);
    size = Vector2(thickness, viewHeight + 400);
    for (final hb in children.whereType<RectangleHitbox>()) {
      hb.size = size;
    }
  }
}

class _SegmentDecor {
  _SegmentDecor(this.patches, this.cracks, this.stains, this.manhole);

  final List<Rect> patches;
  final Path cracks;
  final List<Offset> stains;
  final Offset? manhole;
}
