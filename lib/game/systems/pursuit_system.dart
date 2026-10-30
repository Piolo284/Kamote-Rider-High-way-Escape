import 'dart:math' as math;

/// LTO pressure that grows with distance: one more pursuing officer every
/// [metersPerLevel]. While officers pursue, one of them now and then rides
/// up beside the rider and blocks a lane for a few seconds.
///
/// This class only keeps the numbers and the timing; the game decides where
/// an officer may go so the road always keeps an escape lane.
class PursuitSystem {
  PursuitSystem({math.Random? random}) : _rnd = random ?? math.Random();

  static const double metersPerLevel = 5000;

  /// How long an officer takes to ride up beside the rider (the warning).
  static const double approachSeconds = 1.2;

  /// How long an officer holds the lane once beside the rider.
  static const double holdSeconds = 2.6;

  /// Wait before trying again when no lane could be blocked fairly.
  static const double retrySeconds = 1.0;

  final math.Random _rnd;
  int _level = 0;
  int _maxLevel = 0;
  double _nextMove = 0;

  /// Officers pursuing right now.
  int get level => _level;
  int get maxLevel => _maxLevel;

  static int levelAt(double meters) => (meters / metersPerLevel).floor().clamp(0, 999);

  /// Seconds between lane-blocking moves; shorter with more officers.
  double interval() => math.max(4.0, 16.0 - 2.0 * _level) + _rnd.nextDouble() * 3;

  /// Follows the distance counter. Returns the new level on the frame a
  /// 5 km milestone adds an officer, else null.
  int? updateDistance(double meters) {
    final next = levelAt(meters);
    if (next <= _level) return null;
    final first = _level == 0;
    _level = next;
    _maxLevel = math.max(_maxLevel, next);
    // The new officer makes their first move soon after the milestone.
    if (first || _nextMove > 4) _nextMove = 4;
    return next;
  }

  /// Advances the move timer. Returns true when an officer should try to
  /// block a lane now.
  bool tick(double dt) {
    if (_level == 0 || dt <= 0) return false;
    _nextMove -= dt;
    return _nextMove <= 0;
  }

  /// Reports whether the officer actually moved in, and schedules the next try.
  void moveDone({required bool placed}) => _nextMove = placed ? interval() : retrySeconds;

  static String milestoneMessage(int level) {
    final km = (level * metersPerLevel / 1000).round();
    return switch (level) {
      1 => '$km KM REACHED! AN LTO OFFICER IS AFTER YOU!',
      2 => '$km KM REACHED! TWO LTO OFFICERS ARE NOW PURSUING YOU!',
      3 => '$km KM REACHED! THE CHASE IS GETTING SERIOUS!',
      4 => '$km KM REACHED! THERE IS NO ESCAPE NOW!',
      _ => '$km KM REACHED! $level LTO OFFICERS ON YOUR TAIL!',
    };
  }

  void reset() {
    _level = 0;
    _maxLevel = 0;
    _nextMove = 0;
  }
}
