import 'dart:math' as math;

/// Turns how far the phone is tilted into a lane.
///
/// The tilt picks a lane directly: level is the middle of the road, the full
/// [rangeDegrees] left or right is the outer lane on that side. The way the
/// phone is held when steering starts (each ride, and after a pause) counts
/// as level, so any comfortable grip works. Tilt only ever aims at a real
/// lane, so it can never scrape the guardrail.
class TiltSteering {
  TiltSteering({required this.onSteer, this.rangeDegrees = defaultRange});

  static const double minRange = 12;
  static const double maxRange = 40;
  static const double defaultRange = 25;

  /// How far (in lanes) the tilt must pass a lane's edge before the target
  /// changes, so holding near an edge never flickers between two lanes.
  static const double hysteresis = 0.18;

  /// Weight of each new reading in the smoothed tilt (low-pass filter).
  static const double smoothing = 0.25;

  /// Shortest time between two lane changes, so each one can play out.
  static const double minStepSeconds = 0.12;

  final void Function(int direction) onSteer;

  /// Tilt (degrees) that reaches an outer lane.
  double rangeDegrees;

  double? _neutral;
  double _smoothed = 0;
  int? _target;
  double _sinceStep = minStepSeconds;

  /// Lane the tilt is aiming at, or null before the first reading.
  int? get targetLane => _target;

  /// Sideways tilt in degrees from an accelerometer reading (m/s², gravity
  /// included, Android axes): positive when the right edge is lower.
  static double rollDegrees(double x, double y, double z) => math.atan2(-x, math.sqrt(y * y + z * z)) * 180 / math.pi;

  /// The next reading becomes "level".
  void recenter() => _neutral = null;

  /// Feeds one reading taken [dt] seconds after the last. Steers the rider,
  /// who is in [currentLane], one lane at a time toward the tilt's lane.
  void update(double roll, double dt, {required int currentLane, int laneCount = 4}) {
    _sinceStep += dt;
    if (_neutral == null) {
      _neutral = roll;
      _smoothed = 0;
      _target = currentLane;
    }
    _smoothed += (roll - _neutral! - _smoothed) * smoothing;
    final range = rangeDegrees.clamp(minRange, maxRange);
    final share = (_smoothed / range).clamp(-1.0, 1.0);
    // 0 at the far left edge of the road … laneCount at the far right.
    final position = (share + 1) / 2 * laneCount;
    final target = _target;
    if (target == null || position < target - hysteresis || position > target + 1 + hysteresis) {
      _target = position.floor().clamp(0, laneCount - 1);
    }
    final aim = _target!;
    if (aim != currentLane && _sinceStep >= minStepSeconds) {
      onSteer((aim - currentLane).sign);
      _sinceStep = 0;
    }
  }
}
