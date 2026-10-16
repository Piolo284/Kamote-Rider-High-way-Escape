import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../models/motorcycle_model.dart';
import '../game_config.dart';
import '../kamote_game.dart';
import '../painting/bike_painter.dart';

/// The rider. Moves only horizontally between lanes; the world scrolls past.
class PlayerMotorcycle extends PositionComponent with HasGameReference<KamoteGame>, CollisionCallbacks {
  PlayerMotorcycle() : super(size: Vector2(34, 68), anchor: Anchor.center, priority: 30);

  /// Hitbox is narrower than the sprite so near misses feel fair.
  static final Vector2 hitSize = Vector2(15, 44);

  Motorcycle bike = MotorcycleCatalog.all.first;
  int lane = 2;
  double previousX = 0;

  double _targetX = 0;
  double _vx = 0;
  double _lean = 0;
  double _bumpTimer = 0;
  double _bumpX = 0;
  double _wobble = 0;
  double _invulnerable = 0;
  bool _crashed = false;
  double _crashTime = 0;
  double _time = 0;
  double _wheelTravel = 0;
  bool braking = false;

  /// Lane-change speed multiplier from the difficulty (forgiving on Easy).
  double steeringMultiplier = 1;
  Sprite? _override;

  bool get isInvulnerable => _invulnerable > 0;
  bool get isCrashed => _crashed;
  double get crashTime => _crashTime;
  double get time => _time;
  double get wheelTravel => _wheelTravel;

  /// Body roll in radians (lean into lane changes plus wobble).
  double get roll => _lean + (_wobble > 0 ? math.sin(_time * 40) * 0.12 * _wobble : 0);

  /// Blink opacity while invulnerable.
  double get opacity => _invulnerable > 0 && (_time * 12).floor().isEven ? 0.35 : 1.0;
  bool get isBumping => _bumpTimer > 0;

  Rect get hitRect => Rect.fromCenter(center: Offset(x, y), width: hitSize.x, height: hitSize.y);
  Rect get previousHitRect => Rect.fromCenter(center: Offset(previousX, y), width: hitSize.x, height: hitSize.y);

  double get _maxLateralSpeed => GameConfig.laneWidth / bike.laneChangeSeconds * steeringMultiplier;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(size: hitSize, position: (size - hitSize) / 2));
  }

  void reset(Motorcycle newBike, {required double y, int startLane = 2}) {
    bike = newBike;
    _override = game.sprites.get('bike_${bike.id}');
    lane = startLane;
    x = GameConfig.laneCenter(lane);
    this.y = y;
    previousX = x;
    _targetX = x;
    _vx = 0;
    _lean = 0;
    _bumpTimer = 0;
    _wobble = 0;
    _invulnerable = 0;
    _crashed = false;
    _crashTime = 0;
    braking = false;
  }

  /// Moves one lane left (-1) or right (+1). Steering past the outer lane
  /// scrapes the guardrail, which the game treats as a side collision.
  void steer(int direction) {
    if (_crashed || direction == 0) return;
    final next = lane + direction.sign;
    if (next < 0 || next >= GameConfig.laneCount) {
      _bumpTimer = 0.22;
      _bumpX = direction < 0 ? GameConfig.roadLeft + 5 : GameConfig.roadRight - 5;
      return;
    }
    _bumpTimer = 0;
    lane = next;
    _targetX = GameConfig.laneCenter(lane);
  }

  /// Pushes the rider into a neighbouring lane after a side hit.
  void knockTo(int newLane) {
    lane = newLane.clamp(0, GameConfig.laneCount - 1);
    _targetX = GameConfig.laneCenter(lane);
    _bumpTimer = 0;
  }

  /// Grants at least [seconds] of invulnerability (never shortens it).
  void startInvulnerability(double seconds) => _invulnerable = math.max(_invulnerable, seconds);

  void wobble() => _wobble = 0.6;

  void crash() {
    _crashed = true;
    _crashTime = 0;
    _vx = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    _wheelTravel += game.scrollSpeed * dt / 600;
    previousX = x;
    if (_invulnerable > 0) _invulnerable = math.max(0, _invulnerable - dt);
    if (_wobble > 0) _wobble = math.max(0, _wobble - dt);

    if (_crashed) {
      _crashTime += dt;
      return;
    }

    var target = _targetX;
    if (_bumpTimer > 0) {
      _bumpTimer -= dt;
      target = _bumpX;
    }

    final maxV = _maxLateralSpeed * (_bumpTimer > 0 ? 1.2 : 1.0);
    final dx = target - x;
    final desired = (dx * 16).clamp(-maxV, maxV);
    _vx += (desired - _vx) * math.min(1.0, dt * 22);
    x += _vx * dt;
    if ((target - x).sign != dx.sign) {
      x = target;
      _vx = 0;
    }
    x = x.clamp(GameConfig.roadLeft + 4, GameConfig.roadRight - 4);

    final targetLean = (_vx / _maxLateralSpeed) * 0.34;
    _lean += (targetLean - _lean) * math.min(1.0, dt * 14);
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    game.onPlayerContact(other);
  }

  @override
  void render(Canvas canvas) {
    final blinkHidden = _invulnerable > 0 && (_time * 12).floor().isEven;
    var angle = _lean + (_wobble > 0 ? math.sin(_time * 40) * 0.12 * _wobble : 0);
    var opacity = blinkHidden ? 0.35 : 1.0;
    if (_crashed) {
      // Bike slides and tips over: no gore, just a cartoon spin.
      final t = math.min(_crashTime / 0.6, 1.0);
      angle = 1.5 * (1 - (1 - t) * (1 - t));
      opacity = 1;
    }
    canvas.save();
    canvas.translate(width / 2, height / 2);
    canvas.rotate(angle);
    canvas.translate(-width / 2, -height / 2);
    final sprite = _override;
    if (sprite != null) {
      sprite.render(canvas, size: size, overridePaint: Paint()..color = Color.fromRGBO(255, 255, 255, opacity));
    } else {
      BikePainter.paint(
        canvas,
        size.toSize(),
        bike,
        braking: braking,
        opacity: opacity,
        anim: _crashed ? 0 : _wheelTravel,
        beam: !_crashed,
      );
    }
    canvas.restore();
  }
}
