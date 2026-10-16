/// One finished run as shown on the leaderboard.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.playerName,
    required this.score,
    required this.distanceMeters,
    required this.earnings,
    required this.difficultyLabel,
    required this.bikeName,
    required this.timestamp,
  });

  final String playerName;
  final int score;
  final double distanceMeters;
  final int earnings;
  final String difficultyLabel;
  final String bikeName;
  final DateTime timestamp;

  /// Score rewards both how far the rider got and what they earned on the
  /// way. Earnings already include the difficulty reward multiplier.
  static int scoreFor({required double distanceMeters, required int earnings}) => distanceMeters.floor() + earnings;

  Map<String, dynamic> toJson() => {
    'name': playerName,
    'score': score,
    'dist': distanceMeters,
    'cash': earnings,
    'diff': difficultyLabel,
    'bike': bikeName,
    'at': timestamp.millisecondsSinceEpoch,
  };

  /// Returns null for unreadable entries so one bad row never wipes the board.
  static LeaderboardEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final score = raw['score'];
    final dist = raw['dist'];
    if (score is! num || dist is! num || !dist.isFinite || dist < 0) return null;
    final cash = raw['cash'];
    final at = raw['at'];
    String readString(String k, String fallback) {
      final v = raw[k];
      return v is String && v.trim().isNotEmpty ? v : fallback;
    }

    return LeaderboardEntry(
      playerName: readString('name', Leaderboard.defaultPlayerName),
      score: score.toInt(),
      distanceMeters: dist.toDouble(),
      earnings: cash is num ? cash.toInt() : 0,
      difficultyLabel: readString('diff', 'MEDIUM'),
      bikeName: readString('bike', '-'),
      timestamp: at is int ? DateTime.fromMillisecondsSinceEpoch(at) : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

enum LeaderboardSort { score, distance }

/// Leaderboard rules shared by the save model and the UI.
class Leaderboard {
  Leaderboard._();

  static const String defaultPlayerName = 'Rider';
  static const int maxNameLength = 14;

  /// Runs kept on the device. The best-distance run is always kept too.
  static const int maxEntries = 100;

  static String cleanName(String? raw) {
    final name = (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) return defaultPlayerName;
    return name.length > maxNameLength ? name.substring(0, maxNameLength) : name;
  }

  static int compareBy(LeaderboardSort sort, LeaderboardEntry a, LeaderboardEntry b) {
    final primary = switch (sort) {
      LeaderboardSort.score => b.score.compareTo(a.score),
      LeaderboardSort.distance => b.distanceMeters.compareTo(a.distanceMeters),
    };
    if (primary != 0) return primary;
    // Ties go to whoever set it first.
    return a.timestamp.compareTo(b.timestamp);
  }

  static List<LeaderboardEntry> sorted(Iterable<LeaderboardEntry> entries, LeaderboardSort sort) =>
      entries.toList()..sort((a, b) => compareBy(sort, a, b));

  /// Sorts [entries] by score in place and drops the overflow, keeping the
  /// longest run even if its score fell outside the cut.
  static void trim(List<LeaderboardEntry> entries) {
    entries.sort((a, b) => compareBy(LeaderboardSort.score, a, b));
    if (entries.length <= maxEntries) return;
    final longest = sorted(entries, LeaderboardSort.distance).first;
    entries.removeRange(maxEntries, entries.length);
    if (!entries.contains(longest)) {
      entries[maxEntries - 1] = longest;
    }
  }

  /// Best run per player, ordered by [sort]; one row per rider name.
  static List<LeaderboardEntry> bestPerPlayer(Iterable<LeaderboardEntry> entries, LeaderboardSort sort) {
    final best = <String, LeaderboardEntry>{};
    for (final e in sorted(entries, sort)) {
      best.putIfAbsent(e.playerName.toLowerCase(), () => e);
    }
    return best.values.toList();
  }
}
