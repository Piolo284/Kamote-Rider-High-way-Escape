import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/game/difficulty_config.dart';
import 'package:kamote_rider/models/barkada_model.dart';
import 'package:kamote_rider/models/leaderboard_model.dart';

BarkadaResult _r(int score, double dist) =>
    BarkadaResult(score: score, distanceMeters: dist, earnings: 0, ending: 'Crashed', tunnelTrips: 0);

void main() {
  test('turns advance in order and each is recorded once', () {
    final s = BarkadaSession(names: ['Ana', 'Ben', 'Cai'], difficulty: DifficultyLevel.medium, seed: 7);
    expect(s.currentName, 'Ana');
    expect(s.advance(), isFalse, reason: 'cannot skip an unplayed turn');
    s.record(_r(500, 400));
    s.record(_r(9999, 9999));
    expect(s.resultOf(0)!.score, 500, reason: 'first result sticks');
    expect(s.advance(), isTrue);
    s.record(_r(800, 600));
    expect(s.advance(), isTrue);
    expect(s.isLastTurn, isTrue);
    s.record(_r(800, 700));
    expect(s.advance(), isFalse);
    expect(s.finished, isTrue);
    expect([for (final row in s.standings) row.$1], ['Cai', 'Ben', 'Ana'], reason: 'score, then distance');
  });

  test('rematch keeps players and difficulty with a new highway', () {
    final s = BarkadaSession(names: ['Ana', 'Ben'], difficulty: DifficultyLevel.hard, seed: 1);
    final again = s.rematch();
    expect(again.names, s.names);
    expect(again.difficulty, DifficultyLevel.hard);
    expect(again.turn, 0);
  });

  test('barkada runs are tagged on the leaderboard and survive a save round trip', () {
    final e = LeaderboardEntry(
      playerName: 'Ben',
      score: 10,
      distanceMeters: 5,
      earnings: 5,
      difficultyLabel: 'EASY',
      bikeName: 'Kamote 110',
      timestamp: DateTime(2026),
      barkada: true,
    );
    expect(LeaderboardEntry.fromJson(e.toJson())!.barkada, isTrue);
    expect(LeaderboardEntry.fromJson({...e.toJson()}..remove('mode'))!.barkada, isFalse);
  });
}
