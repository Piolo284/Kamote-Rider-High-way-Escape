import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/game/components/road_animal.dart';
import 'package:kamote_rider/game/difficulty_config.dart';
import 'package:kamote_rider/game/game_config.dart';
import 'package:kamote_rider/game/systems/animal_crossing_manager.dart';
import 'package:kamote_rider/game/systems/challenge_reward_manager.dart';
import 'package:kamote_rider/game/systems/difficulty.dart';
import 'package:kamote_rider/game/systems/highway_challenge_manager.dart';
import 'package:kamote_rider/game/systems/meme_event_manager.dart';
import 'package:kamote_rider/game/systems/reward_system.dart';
import 'package:kamote_rider/models/player_save_model.dart';
import 'package:kamote_rider/services/save_service.dart';

import 'helpers.dart';

void main() {
  group('DifficultyConfig', () {
    const easy = DifficultyConfig.easy;
    const medium = DifficultyConfig.medium;
    const hard = DifficultyConfig.hard;

    test('parameters scale from easy to hard', () {
      expect(easy.startSpeedMultiplier, lessThan(medium.startSpeedMultiplier));
      expect(medium.startSpeedMultiplier, lessThan(hard.startSpeedMultiplier));
      expect(easy.fuelDrainMultiplier, lessThan(hard.fuelDrainMultiplier));
      expect(easy.fuelIntervalMultiplier, lessThan(hard.fuelIntervalMultiplier), reason: 'easy = more fuel');
      expect(easy.trafficDensity, lessThan(hard.trafficDensity));
      expect(easy.reactionPadding, greaterThan(hard.reactionPadding), reason: 'easy = longer reaction windows');
      expect(easy.oncomingWarningSeconds, greaterThan(hard.oncomingWarningSeconds));
      expect(easy.challengeIntervalSeconds, greaterThan(hard.challengeIntervalSeconds));
      expect(hard.rewardMultiplier, greaterThan(medium.rewardMultiplier));
      expect(hard.oncomingWarningSeconds, greaterThanOrEqualTo(1.0), reason: 'hard is still fair');
    });

    test('distance curve uses the config', () {
      for (final meters in [0.0, 1500.0, 4000.0]) {
        final e = Difficulty.at(meters, easy);
        final m = Difficulty.at(meters, medium);
        final h = Difficulty.at(meters, hard);
        expect(e.speedMultiplier, lessThan(m.speedMultiplier));
        expect(m.speedMultiplier, lessThan(h.speedMultiplier));
        expect(e.vehicleChance, lessThan(h.vehicleChance));
        expect(e.rowSpacingMeters, greaterThan(h.rowSpacingMeters));
      }
      // Easy progresses slower: its density at 3 km rises less than hard's.
      final easyRamp = Difficulty.at(3000, easy).vehicleChance / Difficulty.at(400, easy).vehicleChance;
      final hardRamp = Difficulty.at(3000, hard).vehicleChance / Difficulty.at(400, hard).vehicleChance;
      expect(easyRamp, lessThan(hardRamp));
    });

    test('chase rules are not difficulty-dependent', () {
      expect(GameConfig.chaseDuration, 10);
    });

    test('bonus money is scaled, paper bills are not', () {
      final r = RewardSystem()..reset(bonusMultiplier: hard.rewardMultiplier);
      r.addBill(50);
      expect(r.billCash, 50);
      expect(r.addMilestone(1), (RewardSystem.milestoneRewardFor(1) * 1.5).round());
      expect(r.addChallengeReward(40), 60);
    });
  });

  group('save migration', () {
    test('old saves without the new settings get safe defaults', () async {
      final oldSave = jsonEncode({
        'wallet': 1200,
        'settings': {'music': false, 'sfx': true},
      });
      final s = await makeServices(initial: {SaveService.storageKey: oldSave});
      final settings = s.profile.settings;
      expect(s.profile.data.wallet, 1200, reason: 'existing progress kept');
      expect(settings.musicEnabled, isFalse);
      expect(settings.memeSounds, isTrue);
      expect(settings.memePopups, MemePopupMode.full);
      expect(settings.lastDifficulty, DifficultyLevel.medium, reason: 'medium is the default');
    });

    test('difficulty and meme settings survive a restart', () async {
      final s = await makeServices();
      s.profile.settings
        ..lastDifficulty = DifficultyLevel.hard
        ..memePopups = MemePopupMode.reduced
        ..memeSounds = false;
      s.profile.commit();
      await Future<void>.delayed(Duration.zero);
      final reloaded = await reloadProfile();
      expect(reloaded.settings.lastDifficulty, DifficultyLevel.hard);
      expect(reloaded.settings.memePopups, MemePopupMode.reduced);
      expect(reloaded.settings.memeSounds, isFalse);
    });

    test('garbage values fall back', () {
      final m = PlayerSaveModel.fromJson({
        'settings': {'difficulty': 'nightmare', 'memePopups': 42, 'memeSounds': 'yes'},
      });
      expect(m.settings.lastDifficulty, DifficultyLevel.medium);
      expect(m.settings.memePopups, MemePopupMode.full);
      expect(m.settings.memeSounds, isTrue);
    });
  });

  group('MemeEventManager', () {
    test('per-event cooldown blocks repeats', () {
      final m = MemeEventManager(random: math.Random(1));
      expect(m.trigger(MemeEvent.nearMiss, 0), isNotNull);
      expect(m.trigger(MemeEvent.nearMiss, 2), isNull, reason: 'within cooldown');
      expect(m.trigger(MemeEvent.nearMiss, 10), isNotNull);
    });

    test('global cooldown spaces out different events', () {
      final m = MemeEventManager(random: math.Random(1));
      expect(m.trigger(MemeEvent.chaseStart, 0), isNotNull);
      expect(m.trigger(MemeEvent.cashCombo, 0.5), isNull);
      expect(m.trigger(MemeEvent.cashCombo, 2), isNotNull);
    });

    test('reduced mode only shows major events, with a longer gap', () {
      final m = MemeEventManager(random: math.Random(1));
      expect(m.trigger(MemeEvent.nearMiss, 0, mode: MemePopupMode.reduced), isNull);
      expect(m.trigger(MemeEvent.chaseStart, 0, mode: MemePopupMode.reduced), isNotNull);
      expect(m.trigger(MemeEvent.cashCombo, 3, mode: MemePopupMode.reduced), isNull);
      expect(m.trigger(MemeEvent.cashCombo, 8, mode: MemePopupMode.reduced), isNotNull);
    });

    test('lines come from the right context and never repeat back to back', () {
      final m = MemeEventManager(random: math.Random(7));
      String? last;
      for (var i = 0; i < 30; i++) {
        final line = m.trigger(MemeEvent.catDodge, i * 10.0)!;
        expect(MemeEventManager.pools[MemeEvent.catDodge], contains(line.text));
        expect(line.text, isNot(last));
        last = line.text;
      }
    });

    test('required meme phrases are present', () {
      final all = MemeEventManager.pools.values.expand((e) => e).toSet();
      for (final phrase in [
        'AY, NAKO!',
        'KAMOTE MOMENT!',
        'LAGOT KA, BOSS!',
        'TAKBO, KAMOTE!',
        'SANA ALL MAY GASOLINA!',
        'ISA PANG CHANCE!',
        'SLOW DOWN, IDOL!',
        'NICE ONE, IDOL!',
        'GOOD BOY, GOOD SAVE!',
        'PUSA SA GITNA!',
      ]) {
        expect(all, contains(phrase));
      }
    });
  });

  group('combos and challenge rewards', () {
    test('combo counts dodges and resets on crash', () {
      final c = ComboSystem();
      expect(c.registerDodge(), 1);
      expect(c.registerDodge(), 2);
      c.breakCombo();
      expect(c.combo, 0);
      expect(c.bestCombo, 2);
    });

    test('cash streak bonus every 8 quick pickups, broken by a gap', () {
      final c = ComboSystem();
      var bonuses = 0;
      for (var i = 0; i < 16; i++) {
        if (c.registerCash(i * 0.5)) bonuses++;
      }
      expect(bonuses, 2);
      expect(c.registerCash(100), isFalse);
      expect(c.cashStreak, 1);
    });

    test('a challenge pays once, only when every piece is cleared', () {
      final m = ChallengeRewardManager();
      final id = m.begin(name: 'ROAD WORKS', reward: 60, pieces: 3);
      expect(m.resolvePiece(id, success: true), isNull);
      expect(m.resolvePiece(id, success: true), isNull);
      final payout = m.resolvePiece(id, success: true);
      expect(payout?.baseReward, 60);
      expect(m.resolvePiece(id, success: true), isNull, reason: 'never paid twice');
      expect(m.completedCount, 1);
    });

    test('hitting any piece forfeits the reward', () {
      final m = ChallengeRewardManager();
      final id = m.begin(name: 'POTHOLES', reward: 50, pieces: 2);
      m.fail(id);
      expect(m.resolvePiece(id, success: true), isNull);
      expect(m.resolvePiece(id, success: true), isNull);
      final id2 = m.begin(name: 'CASH', reward: 80, pieces: 2);
      expect(m.resolvePiece(id2, success: false), isNull);
      expect(m.resolvePiece(id2, success: true), isNull);
    });
  });

  group('animal paths', () {
    test('dog that turns back leaves on the side it came from', () {
      final path = AnimalPath.dog(1, 2);
      expect(path.offsetAt(0.2), greaterThan(0));
      expect(path.offsetAt(10), lessThan(0), reason: 'ran back off the starting shoulder');
    });

    test('straight dash crosses the whole road', () {
      final path = AnimalPath.cat(-1, 0);
      final roadWidth = GameConfig.roadRight - GameConfig.roadLeft;
      expect(path.offsetAt(5), lessThan(-roadWidth));
    });

    test('cat pausing in the middle shows an alert', () {
      final path = AnimalPath.cat(1, 1);
      final pauseStart = path.steps.first.duration;
      expect(path.stepAt(pauseStart + 0.1).alert, isTrue);
      expect(path.stepAt(pauseStart + 0.1).vx, 0);
    });

    test('lanes at the rider never exceed two', () {
      for (final kind in AnimalKind.values) {
        for (var v = 0; v < 3; v++) {
          for (final dir in [-1, 1]) {
            final path = AnimalPath.forKind(kind, dir, v);
            for (var t = 0.0; t < 3; t += 0.1) {
              final lanes = AnimalCrossingManager.lanesAtRider(
                path: path,
                startX: dir > 0 ? GameConfig.roadLeft - 24 : GameConfig.roadRight + 24,
                hitWidth: 40,
                activateTime: 0.5,
                rowStart: t,
                rowEnd: t + 0.2,
              );
              if (lanes != null) expect(lanes.length, lessThanOrEqualTo(2));
            }
          }
        }
      }
    });
  });

  group('ChallengePicker', () {
    test('respects cooldowns and skips the LTO surprise during a chase', () {
      final p = ChallengePicker(random: math.Random(3));
      final seen = <ChallengeType>{};
      for (var i = 0; i < 200; i++) {
        final t = p.pick(now: 0, level: DifficultyLevel.hard, chaseActive: true);
        if (t != null) seen.add(t);
      }
      expect(seen, isNot(contains(ChallengeType.ltoSurprise)));
      expect(seen, isNot(contains(ChallengeType.fuelEmergency)), reason: 'fuel emergency is need-based only');
      p.markRun(ChallengeType.dogCrossing, 0);
      for (var i = 0; i < 200; i++) {
        expect(p.pick(now: 5, level: DifficultyLevel.hard, chaseActive: false), isNot(ChallengeType.dogCrossing));
      }
    });

    test('harder difficulties favour harder challenges', () {
      double share(DifficultyLevel level, ChallengeType type) {
        final total = Challenges.all.fold<double>(0, (a, d) => a + d.weightFor(level));
        return Challenges.of(type).weightFor(level) / total;
      }

      expect(
        share(DifficultyLevel.hard, ChallengeType.vipConvoy),
        greaterThan(share(DifficultyLevel.easy, ChallengeType.vipConvoy)),
      );
      expect(
        share(DifficultyLevel.hard, ChallengeType.suddenBraking),
        greaterThan(share(DifficultyLevel.easy, ChallengeType.suddenBraking)),
      );
    });
  });
}
