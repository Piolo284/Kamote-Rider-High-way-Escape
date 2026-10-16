import 'dart:math' as math;

enum UndergroundPhase { surface, falling, inside, rising, emerging }

/// Moments the game reacts to while travelling through the tunnel.
enum UndergroundEvent {
  /// The screen is black after the fall: swap the world to the tunnel.
  arrived,

  /// The 20 seconds are up: the rider heads for the exit.
  timeUp,

  /// The screen is black at the exit: swap the world back to the surface.
  surfaced,
}

/// The secret manhole tunnel trip: fall in, survive [duration] seconds
/// underground, then climb back out. Pure Dart so it can be unit tested.
class UndergroundSystem {
  static const double duration = 20;
  static const double fallSeconds = 0.9;
  static const double riseSeconds = 0.9;
  static const double fadeSeconds = 0.6;

  UndergroundPhase _phase = UndergroundPhase.surface;
  double _t = 0;
  int _trips = 0;

  UndergroundPhase get phase => _phase;

  /// True from the fall until the rider is back on the surface road.
  bool get active => _phase != UndergroundPhase.surface && _phase != UndergroundPhase.emerging;

  /// True while the screen shows the tunnel.
  bool get showsTunnel => _phase == UndergroundPhase.inside || _phase == UndergroundPhase.rising;

  /// Falling in or climbing out: collisions are ignored.
  bool get transitioning => _phase == UndergroundPhase.falling || _phase == UndergroundPhase.rising;

  /// Seconds left before the exit (only meaningful inside).
  double get remaining => _phase == UndergroundPhase.inside ? math.max(0, duration - _t) : 0;

  /// 0..1 progress of the current phase.
  double get progress => switch (_phase) {
    UndergroundPhase.falling => (_t / fallSeconds).clamp(0.0, 1.0),
    UndergroundPhase.inside => (_t / duration).clamp(0.0, 1.0),
    UndergroundPhase.rising => (_t / riseSeconds).clamp(0.0, 1.0),
    UndergroundPhase.emerging => (_t / fadeSeconds).clamp(0.0, 1.0),
    UndergroundPhase.surface => 0,
  };

  /// How black the screen is (0 = clear, 1 = fully black).
  double get blackout => switch (_phase) {
    UndergroundPhase.falling || UndergroundPhase.rising => progress,
    UndergroundPhase.inside => math.max(0, 1 - _t / fadeSeconds),
    UndergroundPhase.emerging => 1 - progress,
    UndergroundPhase.surface => 0,
  };

  /// Completed tunnel trips this run.
  int get trips => _trips;

  /// Starts the fall. Returns false if already underground.
  bool enter() {
    if (_phase != UndergroundPhase.surface && _phase != UndergroundPhase.emerging) return false;
    _phase = UndergroundPhase.falling;
    _t = 0;
    return true;
  }

  /// Advances the trip. Call only while gameplay runs, so pausing freezes it.
  UndergroundEvent? update(double dt) {
    if (_phase == UndergroundPhase.surface || dt <= 0) return null;
    _t += dt;
    switch (_phase) {
      case UndergroundPhase.falling when _t >= fallSeconds:
        _phase = UndergroundPhase.inside;
        _t = 0;
        return UndergroundEvent.arrived;
      case UndergroundPhase.inside when _t >= duration:
        _phase = UndergroundPhase.rising;
        _t = 0;
        return UndergroundEvent.timeUp;
      case UndergroundPhase.rising when _t >= riseSeconds:
        _phase = UndergroundPhase.emerging;
        _t = 0;
        _trips++;
        return UndergroundEvent.surfaced;
      case UndergroundPhase.emerging when _t >= fadeSeconds:
        _phase = UndergroundPhase.surface;
        _t = 0;
      default:
        break;
    }
    return null;
  }

  void reset() {
    _phase = UndergroundPhase.surface;
    _t = 0;
    _trips = 0;
  }
}

/// Decides where each world's single open manhole appears.
class ManholePlanner {
  ManholePlanner({math.Random? random}) : _rnd = random ?? math.Random();

  final math.Random _rnd;
  final Set<int> _placed = {};
  int _plannedWorld = -1;
  double _spawnAt = 0;

  /// Earliest and latest point inside a 1 km world for the manhole.
  static const double earliest = 180;
  static const double latest = 820;

  /// First run distance a manhole may appear at (after the start checkpoint).
  static const double firstRunMeters = 260;

  /// Distance at which the current world's manhole should appear.
  double get spawnAt => _spawnAt;

  /// True when a manhole should be placed now in world [world]
  /// (0-based kilometer) at run distance [meters].
  bool due(int world, double meters) {
    if (world != _plannedWorld) {
      _plannedWorld = world;
      final base = world * 1000.0;
      _spawnAt = math.max(base + earliest + _rnd.nextDouble() * (latest - earliest), firstRunMeters);
    }
    return !_placed.contains(world) && meters >= _spawnAt && meters < world * 1000.0 + 990;
  }

  /// Placement failed (lane blocked); try again a little further on.
  void retry() => _spawnAt += 12;

  void markPlaced(int world) => _placed.add(world);

  bool placedIn(int world) => _placed.contains(world);

  void reset() {
    _placed.clear();
    _plannedWorld = -1;
    _spawnAt = 0;
  }
}
