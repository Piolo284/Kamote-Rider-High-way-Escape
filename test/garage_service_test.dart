import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/models/motorcycle_model.dart';
import 'package:kamote_rider/models/player_save_model.dart';
import 'package:kamote_rider/services/garage_service.dart';
import 'package:kamote_rider/services/save_service.dart';

import 'helpers.dart';

void main() {
  test('catalog has exactly 15 bikes in 5 tiers of 3', () {
    expect(MotorcycleCatalog.all.length, 15);
    for (var tier = 1; tier <= 5; tier++) {
      expect(MotorcycleCatalog.all.where((m) => m.tier == tier).length, 3);
    }
    expect(MotorcycleCatalog.all.map((m) => m.id).toSet().length, 15);
    expect(MotorcycleCatalog.all.first.isFree, isTrue);
  });

  test('pricier bikes are faster but not better at everything', () {
    final bikes = MotorcycleCatalog.all;
    for (var i = 1; i < bikes.length; i++) {
      expect(bikes[i].price, greaterThan(bikes[i - 1].price));
      expect(bikes[i].topSpeedKmh, greaterThan(bikes[i - 1].topSpeedKmh));
    }
    final xtreme = MotorcycleCatalog.byId('kamote_xtreme');
    final starter = MotorcycleCatalog.byId('kamote_110');
    expect(xtreme.fuelEfficiency, lessThan(starter.fuelEfficiency));
  });

  group('GarageService', () {
    test('starter bike is unlocked and selected by default', () async {
      final s = await makeServices();
      expect(s.garage.isUnlocked(MotorcycleCatalog.starterId), isTrue);
      expect(s.garage.isSelected(MotorcycleCatalog.starterId), isTrue);
    });

    test('insufficient money prevents purchase', () async {
      final s = await makeServices();
      s.profile.data.wallet = 999;
      expect(s.garage.canBuy('barangay_125'), isFalse);
      expect(s.garage.buy('barangay_125'), PurchaseResult.insufficientFunds);
      expect(s.profile.data.wallet, 999);
      expect(s.garage.isUnlocked('barangay_125'), isFalse);
    });

    test('purchase deducts exactly once and cannot be repeated', () async {
      final s = await makeServices();
      s.profile.data.wallet = 5000;
      expect(s.garage.buy('barangay_125'), PurchaseResult.success);
      expect(s.profile.data.wallet, 4000);
      expect(s.garage.buy('barangay_125'), PurchaseResult.alreadyOwned);
      expect(s.profile.data.wallet, 4000);
      expect(s.garage.canBuy('barangay_125'), isFalse);
    });

    test('cannot select a locked bike; selection changes the gameplay bike', () async {
      final s = await makeServices();
      expect(s.garage.select('kamote_xtreme'), isFalse);
      s.profile.data.wallet = 1000;
      s.garage.buy('barangay_125');
      expect(s.garage.select('barangay_125'), isTrue);
      expect(s.profile.selectedBike.id, 'barangay_125');
      expect(s.profile.selectedBike.topSpeedKmh, greaterThan(MotorcycleCatalog.byId('kamote_110').topSpeedKmh));
    });

    test('purchases and selection survive an app restart', () async {
      final s = await makeServices();
      s.profile.data.wallet = 3000;
      s.garage.buy('sidecar_sprint');
      s.garage.select('sidecar_sprint');
      await Future<void>.delayed(Duration.zero);
      final reloaded = await reloadProfile();
      expect(reloaded.data.unlockedBikes, contains('sidecar_sprint'));
      expect(reloaded.data.selectedBike, 'sidecar_sprint');
      expect(reloaded.data.wallet, 1000);
    });
  });

  group('save data safety', () {
    test('corrupted JSON falls back to defaults', () async {
      final s = await makeServices(initial: {SaveService.storageKey: '{not json'});
      expect(s.profile.data.wallet, 0);
      expect(s.profile.data.unlockedBikes, {MotorcycleCatalog.starterId});
    });

    test('invalid values are repaired', () async {
      final raw = jsonEncode({
        'wallet': -500,
        'best': 'far',
        'unlocked': ['ghost_bike', 'thunder_250'],
        'selected': 'ghost_bike',
        'missions': {
          'unknown_mission': {'level': 3},
        },
        'settings': {'musicVol': 7},
      });
      final s = await makeServices(initial: {SaveService.storageKey: raw});
      final d = s.profile.data;
      expect(d.wallet, 0);
      expect(d.bestDistance, 0);
      expect(d.unlockedBikes, {MotorcycleCatalog.starterId, 'thunder_250'});
      expect(d.selectedBike, MotorcycleCatalog.starterId);
      expect(d.missions.containsKey('unknown_mission'), isFalse);
      expect(d.settings.musicVolume, 1.0);
    });

    test('round trip keeps every field', () {
      final m = PlayerSaveModel(wallet: 42, bestDistance: 3100, totalDistance: 9000, runsPlayed: 3)
        ..unlockedBikes.add('thunder_250')
        ..selectedBike = 'thunder_250';
      m.missionState('collect_bills').progress = 12;
      m.settings.musicEnabled = false;
      final back = PlayerSaveModel.fromJson(jsonDecode(jsonEncode(m.toJson())));
      expect(back.wallet, 42);
      expect(back.bestDistance, 3100);
      expect(back.selectedBike, 'thunder_250');
      expect(back.missionState('collect_bills').progress, 12);
      expect(back.settings.musicEnabled, isFalse);
    });
  });
}
