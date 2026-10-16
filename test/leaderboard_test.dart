import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/screens/leaderboard_screen.dart';
import 'package:kamote_rider/services/app_services.dart';
import 'package:kamote_rider/models/leaderboard_model.dart';
import 'package:kamote_rider/services/player_profile.dart';

import 'helpers.dart';

RunResult _run(double meters, {int bills = 0}) => RunResult(
  distanceMeters: meters,
  billCash: bills,
  billsCollected: 0,
  milestoneCash: 0,
  chaseBonusCash: 0,
  fuelCollected: 0,
  missionsCompleted: const [],
);

void main() {
  test('score is meters plus earnings', () {
    expect(_run(1234.9, bills: 50).score, 1284);
  });

  test('runs are ranked by score, tagged with the rider name, and persist', () async {
    final services = await makeServices();
    final profile = services.profile;

    profile.setPlayerName('  Juan   Dela Cruz  ');
    final first = profile.applyRun(_run(500));
    expect(first.leaderboardRank, 1);
    expect(first.isTopScore, isFalse, reason: 'nothing to beat on an empty board');

    profile.setPlayerName('Maria');
    final second = profile.applyRun(_run(300, bills: 400));
    expect(second.leaderboardRank, 1);
    expect(second.isTopScore, isTrue);

    final third = profile.applyRun(_run(100));
    expect(third.leaderboardRank, 3);

    final reloaded = await reloadProfile();
    final board = reloaded.data.leaderboard;
    expect(board.map((e) => e.playerName), ['Maria', 'Juan Dela Cruz', 'Maria']);
    expect(reloaded.data.playerName, 'Maria');

    final longest = Leaderboard.sorted(board, LeaderboardSort.distance).first;
    expect(longest.playerName, 'Juan Dela Cruz');
    expect(Leaderboard.bestPerPlayer(board, LeaderboardSort.score).length, 2);
  });

  test('empty runs are not recorded', () async {
    final services = await makeServices();
    final summary = services.profile.applyRun(_run(0));
    expect(summary.leaderboardRank, isNull);
    expect(services.profile.data.leaderboard, isEmpty);
  });

  test('trim keeps the longest run even when its score is low', () {
    final now = DateTime(2026);
    LeaderboardEntry e(int score, double dist) => LeaderboardEntry(
      playerName: 'x',
      score: score,
      distanceMeters: dist,
      earnings: 0,
      difficultyLabel: 'EASY',
      bikeName: 'b',
      timestamp: now,
    );
    final entries = [for (var i = 0; i < Leaderboard.maxEntries + 5; i++) e(10000 + i, 10), e(1, 99999)];
    Leaderboard.trim(entries);
    expect(entries.length, Leaderboard.maxEntries);
    expect(entries.any((x) => x.distanceMeters == 99999), isTrue);
  });

  testWidgets('leaderboard screen shows the top scorer without overflow on small phones', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final services = await makeServices();
    services.profile.setPlayerName('Maria Clara');
    services.profile.applyRun(_run(4321, bills: 999));
    services.profile.setPlayerName('Juan');
    services.profile.applyRun(_run(5000));

    await tester.pumpWidget(
      AppServicesScope(services: services, child: const MaterialApp(home: LeaderboardScreen())),
    );
    expect(find.text('TOP SCORER'), findsOneWidget);
    expect(find.text('Maria Clara'), findsNWidgets(2));
    await tester.tap(find.text('DISTANCE'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
