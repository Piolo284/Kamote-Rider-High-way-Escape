import '../../services/player_profile.dart';
import '../game_config.dart';

/// Run earnings. [finalize] produces the [RunResult] exactly once per run.
///
/// Paper bills pay face value; every bonus (milestones, escapes, dodges,
/// challenges) is scaled by the difficulty's [bonusMultiplier].
class RewardSystem {
  int _billCash = 0;
  int _bills = 0;
  int _milestoneCash = 0;
  int _chaseBonus = 0;
  int _skillBonus = 0;
  int _challengeCash = 0;
  int _challenges = 0;
  int _fuel = 0;
  bool _finalized = false;
  double bonusMultiplier = 1;

  /// Base near-miss bonus, multiplied by the (capped) combo count.
  static const int nearMissBase = 10;
  static const int maxComboMultiplier = 5;
  static const int cashStreakBonus = 40;

  int get billCash => _billCash;
  int get billsCollected => _bills;
  int get milestoneCash => _milestoneCash;
  int get chaseBonusCash => _chaseBonus;
  int get skillBonusCash => _skillBonus;
  int get challengeCash => _challengeCash;
  int get challengesCompleted => _challenges;
  int get fuelCollected => _fuel;
  int get runEarnings => _billCash + _milestoneCash + _chaseBonus + _skillBonus + _challengeCash;
  bool get isFinalized => _finalized;

  static int milestoneRewardFor(int kilometer) => 50 + 50 * kilometer;

  int _scaled(int base) => (base * bonusMultiplier).round();

  void addBill(int value) {
    if (_finalized) return;
    _billCash += value;
    _bills += 1;
  }

  void addFuelPickup() {
    if (_finalized) return;
    _fuel += 1;
  }

  int addMilestone(int kilometer) {
    if (_finalized) return 0;
    final reward = _scaled(milestoneRewardFor(kilometer));
    _milestoneCash += reward;
    return reward;
  }

  int addChaseEscape() {
    if (_finalized) return 0;
    final reward = _scaled(GameConfig.chaseEscapeBonus);
    _chaseBonus += reward;
    return reward;
  }

  /// Bonus for dodging a hazard by a hair while on a [combo] streak.
  int addNearMiss(int combo) {
    if (_finalized) return 0;
    final reward = _scaled(nearMissBase * combo.clamp(1, maxComboMultiplier));
    _skillBonus += reward;
    return reward;
  }

  int addCashStreak() {
    if (_finalized) return 0;
    final reward = _scaled(cashStreakBonus);
    _skillBonus += reward;
    return reward;
  }

  int addChallengeReward(int base) {
    if (_finalized) return 0;
    final reward = _scaled(base);
    _challengeCash += reward;
    _challenges += 1;
    return reward;
  }

  /// Returns the result the first time it is called for this run and null on
  /// every later call, so a reopened game-over screen cannot pay twice.
  RunResult? finalize({
    required double distanceMeters,
    List<String> missionsCompleted = const [],
    int bestCombo = 0,
    String difficultyLabel = 'MEDIUM',
  }) {
    if (_finalized) return null;
    _finalized = true;
    return RunResult(
      distanceMeters: distanceMeters,
      billCash: _billCash,
      billsCollected: _bills,
      milestoneCash: _milestoneCash,
      chaseBonusCash: _chaseBonus,
      fuelCollected: _fuel,
      missionsCompleted: missionsCompleted,
      skillBonusCash: _skillBonus,
      challengeCash: _challengeCash,
      challengesCompleted: _challenges,
      bestCombo: bestCombo,
      difficultyLabel: difficultyLabel,
    );
  }

  void reset({double bonusMultiplier = 1}) {
    _billCash = 0;
    _bills = 0;
    _milestoneCash = 0;
    _chaseBonus = 0;
    _skillBonus = 0;
    _challengeCash = 0;
    _challenges = 0;
    _fuel = 0;
    _finalized = false;
    this.bonusMultiplier = bonusMultiplier;
  }
}
