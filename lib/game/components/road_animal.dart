import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../game_config.dart';
import '../systems/collision_system.dart';
import 'highway_entity.dart';

enum AnimalKind { dog, cat, chicken }

/// One leg of an animal's crossing script.
class PathStep {
  const PathStep(this.duration, this.vx, {this.alert = false});

  final double duration;

  /// Sideways speed in world units per second (negative = leftwards).
  final double vx;

  /// Shows a "!" bubble (hesitating / about to turn).
  final bool alert;
}

/// Deterministic, readable crossing script. The last step lasts forever, so
/// the animal always ends up leaving the road.
class AnimalPath {
  AnimalPath(this.steps) : assert(steps.isNotEmpty);

  final List<PathStep> steps;

  static const double _roadWidth = GameConfig.roadRight - GameConfig.roadLeft;

  /// Sideways offset from the start position after [t] seconds.
  double offsetAt(double t) {
    var x = 0.0;
    var remaining = t;
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      final last = i == steps.length - 1;
      if (last || remaining <= s.duration) {
        return x + s.vx * math.max(0, remaining);
      }
      x += s.vx * s.duration;
      remaining -= s.duration;
    }
    return x;
  }

  PathStep stepAt(double t) {
    var remaining = t;
    for (var i = 0; i < steps.length - 1; i++) {
      if (remaining <= steps[i].duration) return steps[i];
      remaining -= steps[i].duration;
    }
    return steps.last;
  }

  /// Dog: straight run, a hesitation on the shoulder, or one turn back.
  factory AnimalPath.dog(int dir, int variant) {
    const v = 150.0;
    return switch (variant % 3) {
      0 => AnimalPath([PathStep(double.infinity, v * dir)]),
      1 => AnimalPath([PathStep(0.5, 0, alert: true), PathStep(double.infinity, v * dir)]),
      _ => AnimalPath([
        PathStep(_roadWidth * 0.3 / v, v * dir),
        const PathStep(0.35, 0, alert: true),
        PathStep(double.infinity, -v * dir),
      ]),
    };
  }

  /// Cat: a quick dash, a pause in the middle, or a sudden reversal.
  factory AnimalPath.cat(int dir, int variant) {
    const v = 190.0;
    return switch (variant % 3) {
      0 => AnimalPath([PathStep(double.infinity, v * dir)]),
      1 => AnimalPath([
        PathStep((_roadWidth / 2 + 22) / v, v * dir),
        const PathStep(0.55, 0, alert: true),
        PathStep(double.infinity, v * dir),
      ]),
      _ => AnimalPath([
        PathStep(_roadWidth * 0.4 / v, v * dir),
        const PathStep(0.25, 0, alert: true),
        PathStep(double.infinity, -v * 1.2 * dir),
      ]),
    };
  }

  /// Chickens: slow waddle with a short stop.
  factory AnimalPath.chicken(int dir, int variant) {
    const v = 85.0;
    return AnimalPath([
      PathStep(_roadWidth * (0.25 + 0.1 * (variant % 3)) / v, v * dir),
      const PathStep(0.3, 0, alert: true),
      PathStep(double.infinity, v * 1.3 * dir),
    ]);
  }

  factory AnimalPath.forKind(AnimalKind kind, int dir, int variant) => switch (kind) {
    AnimalKind.dog => AnimalPath.dog(dir, variant),
    AnimalKind.cat => AnimalPath.cat(dir, variant),
    AnimalKind.chicken => AnimalPath.chicken(dir, variant),
  };
}

/// A dog, cat or chicken flock crossing the highway.
///
/// It waits on the shoulder until it scrolls into view ([activateY]), then
/// follows its [path]. Hitting it is a non-graphic minor bump: the animal
/// jumps and runs off unhurt.
class RoadAnimal extends HighwayEntity with EntityHitbox, Hazard {
  RoadAnimal({
    required this.kind,
    required this.path,
    required this.startX,
    required this.activateY,
    required this.variant,
  }) : super(size: _sizeOf(kind), priority: 18) {
    x = startX;
    _hit = switch (kind) {
      AnimalKind.dog => Vector2(34, 18),
      AnimalKind.cat => Vector2(26, 14),
      AnimalKind.chicken => Vector2(44, 26),
    };
  }

  static Vector2 _sizeOf(AnimalKind kind) => switch (kind) {
    AnimalKind.dog => Vector2(46, 28),
    AnimalKind.cat => Vector2(38, 22),
    AnimalKind.chicken => Vector2(50, 33),
  };

  final AnimalKind kind;
  final AnimalPath path;
  final double startX;
  final double activateY;
  final int variant;
  late final Vector2 _hit;

  double _t = -1;
  double _anim = 0;
  double _fleeVx = 0;
  double _hop = 0;
  bool _facingRight = true;

  static final Paint _p = Paint()..isAntiAlias = true;

  bool get isActive => _t >= 0;

  @override
  Vector2 get hitSize => _hit;

  @override
  HazardKind get hazardKind => HazardKind.animal;

  /// True while the animal is on the asphalt.
  bool get isOnRoad => x > GameConfig.roadLeft - 6 && x < GameConfig.roadRight + 6;

  @override
  Future<void> onLoad() async => add(buildHitbox());

  @override
  void onStruck(CollisionOutcome outcome) {
    // Startled, not hurt: hop and scamper off the nearest side.
    _fleeVx = (x < GameConfig.worldWidth / 2 ? -1 : 1) * 320;
    _hop = 0.4;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_t < 0 && y >= activateY) _t = 0;
    if (_t >= 0) _t += dt;
    double vx;
    if (_fleeVx != 0) {
      vx = _fleeVx;
      x += vx * dt;
    } else if (_t >= 0) {
      vx = path.stepAt(_t).vx;
      x = startX + path.offsetAt(_t);
    } else {
      vx = 0;
    }
    if (vx != 0) _facingRight = vx > 0;
    if (vx != 0) _anim += dt * (kind == AnimalKind.chicken ? 14 : 18);
    if (_hop > 0) _hop = math.max(0, _hop - dt);
    // Leaving sideways only removes it once it is behind the rider, so the
    // dodge is always resolved by the pass tracker first.
    if ((x < -90 || x > GameConfig.worldWidth + 90) && passedPlayer) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final alert = _t >= 0 && _fleeVx == 0 && path.stepAt(_t).alert;
    canvas.save();
    final hopLift = _hop > 0 ? math.sin(_hop / 0.4 * math.pi) * 8 : 0.0;
    canvas.translate(0, -hopLift);
    if (!_facingRight) {
      canvas.translate(width, 0);
      canvas.scale(-1, 1);
    }
    switch (kind) {
      case AnimalKind.dog:
        _dog(canvas);
      case AnimalKind.cat:
        _cat(canvas);
      case AnimalKind.chicken:
        _chickens(canvas);
    }
    canvas.restore();
    if (alert || _hop > 0) _bubble(canvas, _hop > 0 ? '!!' : '!');
  }

  void _shadow(Canvas c) {
    _p.color = const Color(0x33000000);
    c.drawOval(Rect.fromLTWH(width * 0.1, height * 0.55, width * 0.8, height * 0.5), _p);
  }

  void _legs(Canvas c, Color color, double bodyLeft, double bodyRight, double top, double bottom) {
    final swing = math.sin(_anim) * 3;
    _p.color = color;
    for (final lx in [bodyLeft + 4, bodyRight - 6]) {
      c.drawOval(Rect.fromLTWH(lx + swing, top - 3, 4, 5), _p);
      c.drawOval(Rect.fromLTWH(lx - swing, bottom - 2, 4, 5), _p);
    }
  }

  void _dog(Canvas c) {
    // Top-down askal: brown with a lighter belly patch, facing right.
    const colors = [Color(0xFFB57A45), Color(0xFF8D6E63), Color(0xFFE0C097)];
    final fur = colors[variant % colors.length];
    final w = width;
    final h = height;
    _shadow(c);
    _legs(c, Color.lerp(fur, const Color(0xFF000000), 0.3)!, w * 0.18, w * 0.72, h * 0.22, h * 0.78);
    // Tail wags.
    final wag = math.sin(_anim * 1.5) * 4;
    _p.color = fur;
    c.drawOval(Rect.fromLTWH(1, h * 0.38 + wag, 10, 5), _p);
    c.drawOval(Rect.fromLTWH(w * 0.15, h * 0.22, w * 0.6, h * 0.56), _p);
    _p.color = const Color(0x33FFFFFF);
    c.drawOval(Rect.fromLTWH(w * 0.3, h * 0.32, w * 0.3, h * 0.2), _p);
    // Head, ears, snout.
    _p.color = fur;
    c.drawCircle(Offset(w * 0.8, h * 0.5), h * 0.3, _p);
    _p.color = Color.lerp(fur, const Color(0xFF000000), 0.35)!;
    c.drawOval(Rect.fromLTWH(w * 0.7, h * 0.12, 6, 5), _p);
    c.drawOval(Rect.fromLTWH(w * 0.7, h * 0.72, 6, 5), _p);
    _p.color = const Color(0xFF3E2723);
    c.drawCircle(Offset(w * 0.97, h * 0.5), 2.2, _p);
  }

  void _cat(Canvas c) {
    const colors = [Color(0xFF9E9E9E), Color(0xFFFFA726), Color(0xFF424242)];
    final fur = colors[variant % colors.length];
    final w = width;
    final h = height;
    _shadow(c);
    _legs(c, Color.lerp(fur, const Color(0xFF000000), 0.3)!, w * 0.2, w * 0.7, h * 0.2, h * 0.8);
    // Curly tail held up.
    _p
      ..color = fur
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final curl = math.sin(_anim * 0.8) * 3;
    c.drawArc(Rect.fromLTWH(0, h * 0.2 + curl, 10, 10), math.pi * 0.5, math.pi * 1.2, false, _p);
    _p.style = PaintingStyle.fill;
    c.drawOval(Rect.fromLTWH(w * 0.18, h * 0.24, w * 0.56, h * 0.52), _p);
    // Tabby stripes.
    _p.color = Color.lerp(fur, const Color(0xFF000000), 0.25)!;
    for (var i = 0; i < 3; i++) {
      c.drawRect(Rect.fromLTWH(w * (0.28 + i * 0.13), h * 0.26, 2.5, h * 0.48), _p);
    }
    _p.color = fur;
    c.drawCircle(Offset(w * 0.8, h * 0.5), h * 0.3, _p);
    // Pointy ears.
    final ears = Path()
      ..moveTo(w * 0.76, h * 0.25)
      ..lineTo(w * 0.86, h * 0.02)
      ..lineTo(w * 0.9, h * 0.3)
      ..moveTo(w * 0.76, h * 0.75)
      ..lineTo(w * 0.86, h * 0.98)
      ..lineTo(w * 0.9, h * 0.7);
    c.drawPath(ears, _p);
    _p.color = const Color(0xFFFFEB3B);
    c.drawCircle(Offset(w * 0.86, h * 0.38), 1.6, _p);
    c.drawCircle(Offset(w * 0.86, h * 0.62), 1.6, _p);
  }

  void _chickens(Canvas c) {
    // Three hens waddling in a loose line.
    const offsets = [Offset(4, 3), Offset(17, 14), Offset(28, 2)];
    _shadow(c);
    for (var i = 0; i < offsets.length; i++) {
      final o = offsets[i];
      final bob = math.sin(_anim + i * 1.7) * 1.5;
      _p.color = const Color(0xFFFFA000);
      c.drawRect(Rect.fromLTWH(o.dx + 4 + bob, o.dy + 11, 2, 3), _p);
      c.drawRect(Rect.fromLTWH(o.dx + 8 - bob, o.dy + 11, 2, 3), _p);
      _p.color = i == 1 ? const Color(0xFFD7A86E) : const Color(0xFFFAFAFA);
      c.drawOval(Rect.fromLTWH(o.dx, o.dy + bob * 0.3, 14, 12), _p);
      _p.color = const Color(0xFFE53935);
      c.drawCircle(Offset(o.dx + 13, o.dy + 2 + bob * 0.3), 2.5, _p);
      _p.color = const Color(0xFFFFB300);
      c.drawRect(Rect.fromLTWH(o.dx + 15, o.dy + 5 + bob * 0.3, 3, 2), _p);
    }
  }

  void _bubble(Canvas c, String text) {
    final cx = width / 2;
    _p.color = const Color(0xFFFFFFFF);
    c.drawRRect(RRect.fromLTRBR(cx - 9, -22, cx + 9, -6, const Radius.circular(5)), _p);
    final tail = Path()
      ..moveTo(cx - 3, -7)
      ..lineTo(cx + 3, -7)
      ..lineTo(cx, -2)
      ..close();
    c.drawPath(tail, _p);
    _p.color = const Color(0xFFD50000);
    if (text == '!!') {
      c.drawRect(Rect.fromLTWH(cx - 5, -19, 3, 7), _p);
      c.drawRect(Rect.fromLTWH(cx + 2, -19, 3, 7), _p);
      c.drawRect(Rect.fromLTWH(cx - 5, -11, 3, 2.5), _p);
      c.drawRect(Rect.fromLTWH(cx + 2, -11, 3, 2.5), _p);
    } else {
      c.drawRect(Rect.fromLTWH(cx - 1.5, -19, 3, 7), _p);
      c.drawRect(Rect.fromLTWH(cx - 1.5, -11, 3, 2.5), _p);
    }
  }
}
