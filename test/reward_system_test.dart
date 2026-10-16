import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/game/game_config.dart';
import 'package:kamote_rider/game/systems/reward_system.dart';

import 'helpers.dart';

void main() {
  group('RewardSystem', () {
    test('sums bills, milestones and chase bonus', () {
      final r = RewardSystem();
      r.addBill(20);
      r.addBill(50);
      r.addMilestone(1);
      r.addChaseEscape();
      expect(r.billCash, 70);
      expect(r.billsCollected, 2);
      expect(r.milestoneCash, RewardSystem.milestoneRewardFor(1));
      expect(r.runEarnings, 70 + RewardSystem.milestoneRewardFor(1) + GameConfig.chaseEscapeBonus);
    });

    test('finalize returns a result exactly once', () {
      final r = RewardSystem()..addBill(100);
      final first = r.finalize(distanceMeters: 1234);
      final second = r.finalize(distanceMeters: 1234);
      expect(first, isNotNull);
      expect(first!.totalEarnings, 100);
      expect(second, isNull);
      r.addBill(100);
      expect(r.billCash, 100, reason: 'no earnings after finalization');
    });

    test('banking a run pays the wallet once and records the best', () async {
      final services = await makeServices();
      final r = RewardSystem()
        ..addBill(50)
        ..addMilestone(1);
      final result = r.finalize(distanceMeters: 1500)!;
      final summary = services.profile.applyRun(result);
      expect(summary.walletAfter, 50 + RewardSystem.milestoneRewardFor(1));
      expect(summary.isNewBest, isTrue);
      expect(services.profile.data.bestDistance, 1500);
      expect(r.finalize(distanceMeters: 1500), isNull);
      expect(services.profile.data.wallet, 50 + RewardSystem.milestoneRewardFor(1));
    });
  });
}
