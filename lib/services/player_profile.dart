import 'package:flutter/foundation.dart';

import '../models/leaderboard_model.dart';
import '../models/motorcycle_model.dart';
import '../models/player_save_model.dart';
import 'save_service.dart';

/// Result of a finished run as applied to permanent progression.
class RunResult {
  const RunResult({
    required this.distanceMeters,
    required this.billCash,
    required this.billsCollected,
    required this.milestoneCash,
    required this.chaseBonusCash,
    required this.fuelCollected,
    required this.missionsCompleted,
    this.skillBonusCash = 0,
    this.challengeCash = 0,
    this.challengesCompleted = 0,
    this.bestCombo = 0,
    this.difficultyLabel = 'MEDIUM',
  });

  final double distanceMeters;
  final int billCash;
  final int billsCollected;
  final int milestoneCash;
  final int chaseBonusCash;
  final int fuelCollected;
  final List<String> missionsCompleted;

  /// Near-miss, combo and cash-streak bonuses.
  final int skillBonusCash;

  /// Money from completed highway challenges.
  final int challengeCash;
  final int challengesCompleted;
  final int bestCombo;
  final String difficultyLabel;

  int get totalEarnings => billCash + milestoneCash + chaseBonusCash + skillBonusCash + challengeCash;

  int get score => LeaderboardEntry.scoreFor(distanceMeters: distanceMeters, earnings: totalEarnings);
}

/// Summary returned to the game-over screens after the result is banked.
class RunSummary {
  const RunSummary({
    required this.result,
    required this.walletAfter,
    required this.isNewBest,
    this.leaderboardRank,
    this.isTopScore = false,
  });

  final RunResult result;
  final int walletAfter;
  final bool isNewBest;

  /// 1-based position by score among all saved runs, or null if the run
  /// did not make the board.
  final int? leaderboardRank;

  /// True when this run beat the previous top score outright.
  final bool isTopScore;
}

/// Owns the live [PlayerSaveModel] and notifies the UI when it changes.
class PlayerProfile extends ChangeNotifier {
  PlayerProfile(this._saveService) : _data = _saveService.load();

  final SaveService _saveService;
  PlayerSaveModel _data;

  PlayerSaveModel get data => _data;
  GameSettings get settings => _data.settings;
  Motorcycle get selectedBike => MotorcycleCatalog.byId(_data.selectedBike);

  /// Notifies listeners and persists asynchronously.
  void commit() {
    notifyListeners();
    _saveService.save(_data);
  }

  /// Banks a run result into the wallet and records. Callers must guarantee
  /// a given run is applied once (see `RewardSystem.finalize`).
  /// [playerName] credits a Barkada Race turn to that friend on the
  /// leaderboard instead of the device's rider name.
  RunSummary applyRun(RunResult result, {String? playerName}) {
    final isNewBest = result.distanceMeters > _data.bestDistance;
    _data.wallet += result.totalEarnings;
    _data.totalDistance += result.distanceMeters;
    if (isNewBest) _data.bestDistance = result.distanceMeters;
    _data.runsPlayed += 1;
    final rank = _recordOnLeaderboard(result, playerName: playerName);
    commit();
    return RunSummary(
      result: result,
      walletAfter: _data.wallet,
      isNewBest: isNewBest,
      leaderboardRank: rank.$1,
      isTopScore: rank.$2,
    );
  }

  /// Adds the run to the leaderboard. Returns its rank (null if trimmed off)
  /// and whether it beat the previous top score.
  (int?, bool) _recordOnLeaderboard(RunResult result, {String? playerName}) {
    // Skip empty runs (e.g. quitting on the start line) so they don't clutter the board.
    if (result.distanceMeters < 1) return (null, false);
    final board = _data.leaderboard;
    final previousTop = board.isEmpty ? null : board.first.score;
    final entry = LeaderboardEntry(
      playerName: playerName == null ? _data.playerName : Leaderboard.cleanName(playerName),
      score: result.score,
      distanceMeters: result.distanceMeters,
      earnings: result.totalEarnings,
      difficultyLabel: result.difficultyLabel,
      bikeName: selectedBike.name,
      timestamp: DateTime.now(),
      barkada: playerName != null,
    );
    board.add(entry);
    Leaderboard.trim(board);
    final index = board.indexOf(entry);
    final beatTop = previousTop != null && entry.score > previousTop;
    return (index < 0 ? null : index + 1, beatTop);
  }

  void setPlayerName(String name) {
    _data.playerName = Leaderboard.cleanName(name);
    commit();
  }

  void clearLeaderboard() {
    _data.leaderboard.clear();
    commit();
  }

  Future<void> resetProgress() async {
    final keptSettings = _data.settings;
    await _saveService.clear();
    _data = PlayerSaveModel(settings: keptSettings, playerName: _data.playerName);
    commit();
  }
}
