import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flame/components.dart';

import '../game_config.dart';
import '../kamote_game.dart';

/// Per-world weather and lighting drawn over the road:
/// City haze, provincial dust, mountain fog, coastal sunset, urban rain.
///
/// Particles are preallocated and recycled, so nothing is allocated per
/// frame. When the world changes the old effect fades out while the new
/// one fades in.
class AtmosphereLayer extends Component with HasGameReference<KamoteGame> {
  AtmosphereLayer({math.Random? random}) : _rnd = random ?? math.Random(), super(priority: 44);

  final math.Random _rnd;
  static const int _count = 70;
  final Float64List _px = Float64List(_count);
  final Float64List _py = Float64List(_count);
  final Float64List _pv = Float64List(_count);

  int _current = 0;
  int _previous = 0;
  double _blend = 1;
  double _time = 0;
  double _shaderHeight = -1;
  Shader? _topHaze;
  Shader? _sunset;
  Shader? _sunGlow;
  final Paint _p = Paint()..isAntiAlias = true;
  final Paint _s = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  Future<void> onLoad() async => _scatter();

  void reset() {
    _current = _previous = 0;
    _blend = 1;
    _scatter();
  }

  void _scatter() {
    for (var i = 0; i < _count; i++) {
      _px[i] = -60 + _rnd.nextDouble() * 520;
      _py[i] = _rnd.nextDouble() * game.viewHeight;
      _pv[i] = 0.5 + _rnd.nextDouble();
    }
  }

  @override
  void update(double dt) {
    if (dt <= 0) return;
    _time += dt;
    final env = game.distance.environmentIndex;
    if (env != _current) {
      _previous = _current;
      _current = env;
      _blend = 0;
    }
    if (_blend < 1) _blend = math.min(1, _blend + dt / 2.5);
    final h = game.viewHeight;
    final scroll = game.scrollSpeed;
    final rainy = _current == 4 || _previous == 4 && _blend < 1;
    for (var i = 0; i < _count; i++) {
      if (rainy) {
        _py[i] += (520 + scroll * 0.8) * _pv[i] * dt;
        _px[i] -= 60 * dt;
      } else {
        _py[i] += (scroll * 0.9 + 20) * _pv[i] * dt;
        _px[i] += math.sin(_time * 0.8 + i) * 18 * dt;
      }
      if (_py[i] > h + 20) {
        _py[i] = -20;
        _px[i] = -60 + _rnd.nextDouble() * 520;
      }
      if (_px[i] < -80) _px[i] += 560;
    }
  }

  void _ensureShaders(double h) {
    if (_shaderHeight == h) return;
    _shaderHeight = h;
    _topHaze = ui.Gradient.linear(Offset.zero, Offset(0, h * 0.4), const [Color(0xFFFFFFFF), Color(0x00FFFFFF)]);
    _sunset = ui.Gradient.linear(
      Offset.zero,
      Offset(0, h),
      const [Color(0xFFFF7043), Color(0x55FFB74D), Color(0x00FFB74D)],
      const [0, 0.45, 1],
    );
    _sunGlow = ui.Gradient.radial(const Offset(330, 40), 160, const [Color(0xFFFFF3E0), Color(0x00FFCC80)]);
  }

  @override
  void render(Canvas canvas) {
    final h = game.viewHeight;
    _ensureShaders(h);
    if (_blend < 1) _effect(canvas, _previous, 1 - _blend, h);
    _effect(canvas, _current, _blend, h);
  }

  void _effect(Canvas c, int env, double a, double h) {
    if (a <= 0.01) return;
    const area = Rect.fromLTRB(-400, 0, 800, 0);
    final full = Rect.fromLTRB(area.left, 0, area.right, h);
    _p.shader = null;
    switch (env) {
      case 0: // City: smoggy haze toward the horizon.
        _p
          ..shader = _topHaze
          ..color = Color.fromRGBO(0, 0, 0, 0.22 * a);
        c.drawRect(full, _p);
      case 1: // Provincial: warm sun and drifting dust.
        _p.color = Color.fromRGBO(255, 214, 120, 0.06 * a);
        c.drawRect(full, _p);
        _p.color = Color.fromRGBO(215, 180, 130, 0.35 * a);
        for (var i = 0; i < 36; i++) {
          c.drawCircle(Offset(_px[i], _py[i]), 1.2 + _pv[i], _p);
        }
      case 2: // Mountain: cool tint and rolling fog banks.
        _p.color = Color.fromRGBO(120, 160, 200, 0.07 * a);
        c.drawRect(full, _p);
        _p.color = Color.fromRGBO(255, 255, 255, 0.10 * a);
        for (var i = 0; i < 3; i++) {
          final fx = ((_time * (10 + i * 6) + i * 170) % 700) - 200;
          final fy = h * (0.08 + 0.18 * i);
          c.drawOval(Rect.fromCenter(center: Offset(fx, fy), width: 320, height: 70), _p);
        }
      case 3: // Coastal: sunset glow from the top-right.
        _p
          ..shader = _sunset
          ..color = Color.fromRGBO(0, 0, 0, 0.28 * a);
        c.drawRect(full, _p);
        _p
          ..shader = _sunGlow
          ..color = Color.fromRGBO(0, 0, 0, 0.5 * a);
        c.drawCircle(const Offset(330, 40), 160, _p);
      case 4: // Urban: overcast tint and rain.
        _p.color = Color.fromRGBO(30, 45, 80, 0.14 * a);
        c.drawRect(full, _p);
        _s
          ..color = Color.fromRGBO(210, 225, 255, 0.5 * a)
          ..strokeWidth = 1.4;
        for (var i = 0; i < _count; i++) {
          c.drawLine(Offset(_px[i], _py[i]), Offset(_px[i] - 5, _py[i] + 20 * _pv[i]), _s);
        }
    }
    _p.shader = null;
  }
}

/// Wind streaks along the screen edges at high speed.
class SpeedLines extends Component with HasGameReference<KamoteGame> {
  SpeedLines({math.Random? random}) : _rnd = random ?? math.Random(), super(priority: 46);

  final math.Random _rnd;
  static const int _count = 16;
  static const double threshold = 105;
  final Float64List _x = Float64List(_count);
  final Float64List _y = Float64List(_count);
  final Float64List _len = Float64List(_count);
  final Paint _p = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 2;

  @override
  Future<void> onLoad() async {
    for (var i = 0; i < _count; i++) {
      _respawn(i, _rnd.nextDouble() * game.viewHeight);
    }
  }

  void _respawn(int i, double y) {
    final left = i.isEven;
    _x[i] = left
        ? GameConfig.roadLeft - 30 + _rnd.nextDouble() * 50
        : GameConfig.roadRight - 20 + _rnd.nextDouble() * 50;
    _y[i] = y;
    _len[i] = 40 + _rnd.nextDouble() * 70;
  }

  double get _intensity => ((game.speedKmh - threshold) / 50).clamp(0.0, 1.0);

  @override
  void update(double dt) {
    if (dt <= 0 || _intensity <= 0) return;
    for (var i = 0; i < _count; i++) {
      _y[i] += game.scrollSpeed * 1.8 * dt;
      if (_y[i] > game.viewHeight + 100) _respawn(i, -_len[i] - _rnd.nextDouble() * 200);
    }
  }

  @override
  void render(Canvas canvas) {
    final a = _intensity;
    if (a <= 0) return;
    _p.color = Color.fromRGBO(255, 255, 255, 0.28 * a);
    for (var i = 0; i < _count; i++) {
      canvas.drawLine(Offset(_x[i], _y[i]), Offset(_x[i], _y[i] + _len[i]), _p);
    }
  }
}
