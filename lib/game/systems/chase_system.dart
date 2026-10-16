import '../game_config.dart';

enum ChaseTrigger { checkpoint, sideCollision }

/// The single LTO pursuit timer.
///
/// Overlap policy: there is only ever one timer. The checkpoint pursuit at
/// the start of a run is a normal chase, so any qualifying collision while
/// any chase is active is a second offense. [start] never restarts or
/// stacks a running timer; it returns false and the caller escalates to the
/// ticket-and-jail ending.
class ChaseSystem {
  ChaseSystem({this.duration = GameConfig.chaseDuration});

  final double duration;

  bool _active = false;
  double _remaining = 0;
  ChaseTrigger? _trigger;
  int _survived = 0;

  bool get active => _active;
  double get remaining => _remaining;
  ChaseTrigger? get trigger => _trigger;
  int get survivedCount => _survived;

  bool start(ChaseTrigger trigger) {
    if (_active) return false;
    _active = true;
    _remaining = duration;
    _trigger = trigger;
    return true;
  }

  /// Advances the countdown. Call only while gameplay is running so pausing
  /// freezes it. Returns true on the frame the player escapes.
  bool update(double dt) {
    if (!_active || dt <= 0) return false;
    _remaining -= dt;
    if (_remaining <= 0) {
      _remaining = 0;
      _active = false;
      _trigger = null;
      _survived += 1;
      return true;
    }
    return false;
  }

  void reset() {
    _active = false;
    _remaining = 0;
    _trigger = null;
    _survived = 0;
  }
}
