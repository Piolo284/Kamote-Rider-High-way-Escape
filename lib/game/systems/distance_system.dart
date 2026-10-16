import '../game_config.dart';

/// Tracks run distance and derives the current environment from it, so the
/// world can never drift out of sync with the distance counter.
class DistanceSystem {
  double _meters = 0;
  int _kilometersPassed = 0;
  final Set<int> _visited = {0};

  double get meters => _meters;
  int get kilometersPassed => _kilometersPassed;
  int get environmentIndex => environmentFor(_meters);
  int get distinctEnvironmentsVisited => _visited.length;

  /// Completed five-environment loops; used to raise difficulty on repeats.
  int get cycle => (_meters / (GameConfig.metersPerEnvironment * GameConfig.environmentCount)).floor();

  static int environmentFor(double meters) =>
      (meters / GameConfig.metersPerEnvironment).floor() % GameConfig.environmentCount;

  /// Adds distance. Returns the kilometer number if a milestone was crossed
  /// this step, otherwise null.
  int? advance(double deltaMeters) {
    if (deltaMeters <= 0) return null;
    _meters += deltaMeters;
    final km = (_meters / GameConfig.metersPerEnvironment).floor();
    if (km > _kilometersPassed) {
      _kilometersPassed = km;
      _visited.add(environmentIndex);
      return km;
    }
    return null;
  }

  void reset() {
    _meters = 0;
    _kilometersPassed = 0;
    _visited
      ..clear()
      ..add(0);
  }
}
