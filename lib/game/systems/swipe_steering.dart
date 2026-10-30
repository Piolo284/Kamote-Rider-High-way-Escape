/// Turns a horizontal drag into lane changes.
///
/// [sensitivity] only scales how far the finger must travel per lane (and how
/// fast a short flick must be). It never changes how fast the bike moves
/// between lanes, so it can't affect balance or leaderboard fairness.
class SwipeSteering {
  SwipeSteering({required this.onSteer, this.sensitivity = 1});

  /// Logical pixels of drag per lane at 1× sensitivity.
  static const double baseStep = 26;

  /// Fling speed (px/s) that counts as one lane when the drag was too short.
  static const double baseFlickVelocity = 250;

  static const double minSensitivity = 0.5;
  static const double maxSensitivity = 2;

  final void Function(int direction) onSteer;
  double sensitivity;

  double _accum = 0;
  int _steps = 0;

  double get _sens => sensitivity.clamp(minSensitivity, maxSensitivity);
  double get step => baseStep / _sens;
  double get flickVelocity => baseFlickVelocity / _sens;

  void start() {
    _accum = 0;
    _steps = 0;
  }

  void update(double dx) {
    _accum += dx;
    // Each threshold crossed mid-drag is one lane, so steering responds
    // before the finger lifts.
    while (_accum.abs() >= step) {
      final dir = _accum.sign.toInt();
      onSteer(dir);
      _accum -= dir * step;
      _steps++;
    }
  }

  /// A quick flick shorter than one step still counts as one lane.
  void end(double velocity) {
    if (_steps == 0 && velocity.abs() > flickVelocity) onSteer(velocity.sign.toInt());
  }
}
