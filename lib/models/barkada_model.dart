import 'dart:math' as math;

import '../game/difficulty_config.dart';
import 'leaderboard_model.dart';

/// One player's finished turn in a Barkada Race.
class BarkadaResult {
  const BarkadaResult({
    required this.score,
    required this.distanceMeters,
    required this.earnings,
    required this.ending,
    required this.tunnelTrips,
  });

  final int score;
  final double distanceMeters;
  final int earnings;

  /// How the run ended, e.g. "Huli ng LTO".
  final String ending;
  final int tunnelTrips;
}

/// A pass-and-play race for 2–4 friends on one phone.
///
/// Every turn rides the same seeded highway, so traffic and the manhole
/// spots start out identical for everyone. Highest score wins.
class BarkadaSession {
  BarkadaSession({required List<String> names, required this.difficulty, int? seed})
    : assert(names.length >= minPlayers && names.length <= maxPlayers),
      names = List.unmodifiable(names.map(Leaderboard.cleanName)),
      seed = seed ?? math.Random().nextInt(1 << 30),
      _results = List.filled(names.length, null);

  static const int minPlayers = 2;
  static const int maxPlayers = 4;

  final List<String> names;
  final DifficultyLevel difficulty;

  /// Seed for the highway shared by every turn.
  final int seed;
  final List<BarkadaResult?> _results;
  int _turn = 0;

  int get playerCount => names.length;

  /// Index of the player whose turn it is.
  int get turn => _turn;
  String get currentName => names[_turn];
  bool get isLastTurn => _turn == names.length - 1;

  /// True once every player has a result.
  bool get finished => _results.every((r) => r != null);

  BarkadaResult? resultOf(int player) => _results[player];

  /// Stores the current player's result. Later calls for the same turn are
  /// ignored, so a turn is only ever counted once.
  void record(BarkadaResult result) => _results[_turn] ??= result;

  /// Moves to the next player. Returns false after the last turn.
  bool advance() {
    if (_results[_turn] == null || isLastTurn) return false;
    _turn++;
    return true;
  }

  /// Players with results, best first (score, then distance, then turn order).
  List<(String name, BarkadaResult result)> get standings {
    final rows = [
      for (var i = 0; i < names.length; i++)
        if (_results[i] case final r?) (i, names[i], r),
    ];
    rows.sort((a, b) {
      final byScore = b.$3.score.compareTo(a.$3.score);
      if (byScore != 0) return byScore;
      final byDistance = b.$3.distanceMeters.compareTo(a.$3.distanceMeters);
      return byDistance != 0 ? byDistance : a.$1.compareTo(b.$1);
    });
    return [for (final r in rows) (r.$2, r.$3)];
  }

  /// Same friends, new highway.
  BarkadaSession rematch() => BarkadaSession(names: names, difficulty: difficulty);
}
