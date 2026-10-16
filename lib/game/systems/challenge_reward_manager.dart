/// Dodge combo and cash-streak tracking. Any collision breaks the combo.
class ComboSystem {
  /// Bills collected within this many seconds of each other form a streak.
  static const double cashStreakWindow = 1.6;

  /// A cash-streak bonus is paid every this many bills.
  static const int cashStreakStep = 8;

  int _combo = 0;
  int _best = 0;
  int _cashStreak = 0;
  double _lastCash = -1e9;

  int get combo => _combo;
  int get bestCombo => _best;
  int get cashStreak => _cashStreak;

  /// Registers a successful dodge and returns the new combo count.
  int registerDodge() {
    _combo++;
    if (_combo > _best) _best = _combo;
    return _combo;
  }

  void breakCombo() => _combo = 0;

  /// Registers a bill pickup at [now]. Returns true when this pickup earns a
  /// streak bonus (every [cashStreakStep] bills in a row).
  bool registerCash(double now) {
    _cashStreak = now - _lastCash <= cashStreakWindow ? _cashStreak + 1 : 1;
    _lastCash = now;
    return _cashStreak % cashStreakStep == 0;
  }

  void reset() {
    _combo = 0;
    _best = 0;
    _cashStreak = 0;
    _lastCash = -1e9;
  }
}

class ChallengePayout {
  const ChallengePayout(this.name, this.baseReward);

  final String name;
  final int baseReward;
}

class _TrackedChallenge {
  _TrackedChallenge(this.name, this.reward, this.pieces);

  final String name;
  final int reward;
  final int pieces;
  int resolved = 0;
  bool failed = false;
  bool paid = false;
}

/// Tracks each spawned challenge until all of its pieces (hazards or
/// pickups) have been resolved. A challenge pays its reward exactly once,
/// and only if no piece was hit (or, for pickups, missed).
class ChallengeRewardManager {
  final Map<int, _TrackedChallenge> _active = {};
  int _nextId = 1;
  int _completed = 0;

  int get completedCount => _completed;
  int get activeCount => _active.length;

  int begin({required String name, required int reward, required int pieces}) {
    final id = _nextId++;
    _active[id] = _TrackedChallenge(name, reward, pieces < 1 ? 1 : pieces);
    return id;
  }

  /// Marks one piece as resolved. [success] is false if the rider hit a
  /// hazard piece or missed a pickup piece. Returns a payout the first time
  /// the whole challenge completes cleanly.
  ChallengePayout? resolvePiece(int id, {required bool success}) {
    final c = _active[id];
    if (c == null) return null;
    if (!success) c.failed = true;
    c.resolved++;
    if (c.resolved < c.pieces) return null;
    _active.remove(id);
    if (c.failed || c.paid) return null;
    c.paid = true;
    _completed++;
    return ChallengePayout(c.name, c.reward);
  }

  /// Marks a challenge as failed without resolving a piece (e.g. a crash).
  void fail(int id) => _active[id]?.failed = true;

  void reset() {
    _active.clear();
    _completed = 0;
  }
}
