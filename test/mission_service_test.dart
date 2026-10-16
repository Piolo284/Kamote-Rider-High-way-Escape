import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/models/mission_model.dart';

import 'helpers.dart';

void main() {
  group('MissionService', () {
    test('lifetime bill mission accumulates and completes', () async {
      final s = await makeServices();
      s.missions.beginRun('kamote_110');
      final def = MissionCatalog.byId('collect_bills')!;
      var completedAt = -1;
      for (var i = 0; i < 60; i++) {
        if (s.missions.onBillCollected().contains(def)) completedAt = i;
      }
      expect(completedAt, 49, reason: 'completes on the 50th bill');
      expect(s.missions.stateOf(def).completed, isTrue);
      expect(s.missions.stateOf(def).progress, 50);
    });

    test('rewards can be claimed only once and the mission levels up', () async {
      final s = await makeServices();
      s.missions.beginRun('kamote_110');
      s.missions.onChaseSurvived();
      final def = MissionCatalog.byId('survive_chase')!;
      expect(s.missions.claimableCount, 1);
      final paid = s.missions.claim(def.id);
      expect(paid, def.rewardFor(0));
      expect(s.profile.data.wallet, paid);
      expect(s.missions.claim(def.id), 0, reason: 'second claim pays nothing');
      expect(s.profile.data.wallet, paid);
      expect(s.missions.stateOf(def).level, 1);
      expect(s.missions.stateOf(def).completed, isFalse);
    });

    test('incomplete missions pay nothing', () async {
      final s = await makeServices();
      expect(s.missions.claim('single_run_distance'), 0);
      expect(s.profile.data.wallet, 0);
    });

    test('single-run distance keeps the best run, lifetime distance accumulates', () async {
      final s = await makeServices();
      final single = MissionCatalog.byId('single_run_distance')!;
      final lifetime = MissionCatalog.byId('travel_total')!;

      s.missions.beginRun('kamote_110');
      s.missions.onDistance(deltaMeters: 600, runMeters: 600, cleanMeters: 600);
      s.missions.beginRun('kamote_110');
      s.missions.onDistance(deltaMeters: 300, runMeters: 300, cleanMeters: 300);

      expect(s.missions.stateOf(single).progress, 600, reason: 'best single run, not the sum');
      expect(s.missions.stateOf(lifetime).progress, 900, reason: 'sum across runs');
    });

    test('test-ride mission only counts the required bike', () async {
      final s = await makeServices();
      final def = MissionCatalog.byId('test_ride')!;
      final required = def.bikeFor(0)!;
      s.missions.beginRun('kamote_110');
      s.missions.onDistance(deltaMeters: 1500, runMeters: 1500, cleanMeters: 0);
      expect(s.missions.stateOf(def).progress, 0);
      s.missions.beginRun(required.id);
      s.missions.onDistance(deltaMeters: 1000, runMeters: 1000, cleanMeters: 0);
      expect(s.missions.stateOf(def).completed, isTrue);
    });

    test('completion and claims persist', () async {
      final s = await makeServices();
      s.missions.beginRun('kamote_110');
      for (var i = 0; i < 5; i++) {
        s.missions.onFuelCollected();
      }
      s.profile.commit();
      await Future<void>.delayed(Duration.zero);
      final reloaded = await reloadProfile();
      expect(reloaded.data.missionState('collect_fuel').completed, isTrue);
    });
  });
}
