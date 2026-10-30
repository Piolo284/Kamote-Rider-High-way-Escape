/// Kinds of traffic violation the game detects.
enum Violation {
  /// Crashing into another vehicle (side, rear or head-on).
  collision,

  /// Scraping the guardrail at the edge of the highway.
  leftRoad,

  /// Driving through a barrier that closes a lane.
  ignoredRoadClosure,

  /// Ramming an LTO officer who is blocking a lane.
  hitOfficer,
}

extension ViolationText on Violation {
  String get label => switch (this) {
    Violation.collision => 'COLLISION DETECTED',
    Violation.leftRoad => 'LEFT THE ROAD',
    Violation.ignoredRoadClosure => 'IGNORED A ROAD CLOSURE',
    Violation.hitOfficer => 'HIT AN LTO OFFICER',
  };
}

/// Counts the violations of one run. Recording one is the game's job once
/// per resolved collision, so the same crash is never counted twice.
class ViolationSystem {
  ViolationSystem({this.penaltyPerViolation = defaultPenalty});

  /// Pesos deducted for each violation. Adjustable by the developer.
  static const int defaultPenalty = 100;

  /// From this many violations on, the warning gets louder.
  static const int warnAt = 3;

  final int penaltyPerViolation;
  final Map<Violation, int> _counts = {};

  int get count => _counts.values.fold(0, (a, b) => a + b);
  int countOf(Violation v) => _counts[v] ?? 0;

  /// Records one violation and returns the penalty it carries.
  int record(Violation v) {
    _counts[v] = countOf(v) + 1;
    return penaltyPerViolation;
  }

  void reset() => _counts.clear();
}
