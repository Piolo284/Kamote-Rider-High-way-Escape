import 'dart:math' as math;

/// How curvy the road is allowed to be at some distance.
class CurveProfile {
  const CurveProfile({
    required this.maxIntensity,
    required this.straightChance,
    required this.minMeters,
    required this.maxMeters,
  });

  /// Strongest bend, from 0 (straight) to 1 (sharpest).
  final double maxIntensity;

  /// Chance that the next stretch is straight.
  final double straightChance;
  final double minMeters;
  final double maxMeters;
}

/// Gentle left and right bends of the highway.
///
/// The bends are visual: the chase camera bends the road ahead of the
/// rider, but the gameplay world stays straight. At the rider's own row the
/// road never shifts, so lanes, collisions and the escape-lane rule are
/// exactly as on a straight road.
class CurveSystem {
  CurveSystem({math.Random? random}) : _rnd = random ?? math.Random();

  /// How fast the bend can change, per meter ridden (a full swing takes
  /// about 250 m, so transitions are never sudden).
  static const double changePerMeter = 0.004;

  final math.Random _rnd;
  double _current = 0;
  double _target = 0;
  double _stretchLeft = 0;

  /// Current bend, -1 (sharp left) to 1 (sharp right).
  double get curvature => _current;
  double get target => _target;

  static CurveProfile profileAt(double meters) {
    if (meters < 1000) return const CurveProfile(maxIntensity: 0, straightChance: 1, minMeters: 200, maxMeters: 300);
    if (meters < 3000) {
      return const CurveProfile(maxIntensity: 0.45, straightChance: 0.5, minMeters: 250, maxMeters: 400);
    }
    if (meters < 5000) {
      return const CurveProfile(maxIntensity: 0.65, straightChance: 0.35, minMeters: 200, maxMeters: 350);
    }
    if (meters < 10000) {
      return const CurveProfile(maxIntensity: 0.85, straightChance: 0.25, minMeters: 180, maxMeters: 320);
    }
    if (meters < 15000) {
      return const CurveProfile(maxIntensity: 1, straightChance: 0.2, minMeters: 150, maxMeters: 280);
    }
    return const CurveProfile(maxIntensity: 1, straightChance: 0.12, minMeters: 120, maxMeters: 240);
  }

  /// Advances along the road by [frameMeters], at total distance [meters].
  void update(double meters, double frameMeters) {
    if (frameMeters <= 0) return;
    _stretchLeft -= frameMeters;
    if (_stretchLeft <= 0) _nextStretch(meters);
    final step = changePerMeter * frameMeters;
    _current += (_target - _current).clamp(-step, step);
  }

  void _nextStretch(double meters) {
    final p = profileAt(meters);
    _stretchLeft = p.minMeters + _rnd.nextDouble() * (p.maxMeters - p.minMeters);
    if (p.maxIntensity <= 0 || _rnd.nextDouble() < p.straightChance) {
      _target = 0;
      return;
    }
    final strength = p.maxIntensity * (0.5 + 0.5 * _rnd.nextDouble());
    _target = _rnd.nextBool() ? strength : -strength;
  }

  /// Straightens out instantly (new run, tunnel).
  void reset() {
    _current = 0;
    _target = 0;
    _stretchLeft = 0;
  }
}
