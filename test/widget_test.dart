import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/app.dart';
import 'package:kamote_rider/game/difficulty_config.dart';
import 'package:kamote_rider/game/kamote_game.dart';
import 'package:kamote_rider/services/app_services.dart';

import 'helpers.dart';

Future<AppServices> _pumpApp(WidgetTester tester, {int wallet = 0, Size logical = const Size(393, 851)}) async {
  tester.view.physicalSize = logical * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final services = await makeServices();
  services.profile.data.wallet = wallet;
  await tester.pumpWidget(KamoteApp(services: services));
  await tester.pump(const Duration(milliseconds: 100));
  return services;
}

/// Menus have looping animations, so settle with fixed pumps.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _back(WidgetTester tester) async {
  await tester.pageBack();
  await _settle(tester);
}

void main() {
  testWidgets('main menu shows title, wallet, best distance and all buttons', (tester) async {
    await _pumpApp(tester, wallet: 1234);
    expect(find.text('KAMOTE\nRIDER'), findsWidgets);
    expect(find.text('₱1,234'), findsOneWidget);
    expect(find.textContaining('Best:'), findsOneWidget);
    for (final label in ['PLAY', 'GARAGE', 'MISSIONS', 'COLLECTION', 'SETTINGS']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('every menu button opens a working screen', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('GARAGE'));
    await _settle(tester);
    expect(find.text('IMPOUND GARAGE'), findsOneWidget);
    await _back(tester);

    await tester.tap(find.text('MISSIONS'));
    await _settle(tester);
    expect(find.text('Money Magnet'), findsOneWidget);
    await _back(tester);

    await tester.tap(find.text('COLLECTION'));
    await _settle(tester);
    expect(find.text('1 / 15 motorcycles released'), findsOneWidget);
    await _back(tester);

    await tester.tap(find.text('SETTINGS'));
    await _settle(tester);
    await tester.scrollUntilVisible(find.text('HOW TO PLAY'), 300);
    expect(find.text('HOW TO PLAY'), findsOneWidget);
    await _back(tester);

    expect(find.text('PLAY'), findsOneWidget);
  });

  testWidgets('garage purchase deducts money once and unlocks the bike', (tester) async {
    final services = await _pumpApp(tester, wallet: 1500);
    await tester.tap(find.text('GARAGE'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Next'));
    await _settle(tester);
    expect(find.text('Barangay 125'), findsOneWidget);
    await tester.tap(find.text('BUY ₱1,000'));
    await _settle(tester);
    await tester.tap(find.text('PAY'));
    await _settle(tester);
    expect(find.text('UNLOCKED!'), findsOneWidget);
    await tester.tap(find.text('RIDE IT!'));
    await _settle(tester);
    expect(services.profile.data.wallet, 500);
    expect(services.garage.isUnlocked('barangay_125'), isTrue);
    expect(services.profile.data.selectedBike, 'barangay_125');
    expect(find.text('SELECTED'), findsWidgets);
  });

  testWidgets('mission rewards can be claimed once from the mission screen', (tester) async {
    final services = await _pumpApp(tester);
    services.missions.beginRun('kamote_110');
    services.missions.onChaseSurvived();
    services.profile.commit();
    await tester.tap(find.text('MISSIONS'));
    await _settle(tester);
    expect(find.text('CLAIM'), findsOneWidget);
    await tester.tap(find.text('CLAIM'));
    await _settle(tester);
    expect(services.profile.data.wallet, 300);
    // Animated reward popup: counts up to the reward and previews level 2.
    expect(find.text('MISSION CLAIMED!'), findsOneWidget);
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('+₱300'), findsOneWidget);
    expect(find.text('NEXT: LEVEL 2'), findsOneWidget);
    await tester.tap(find.text('COLLECT'));
    await _settle(tester);
    await _settle(tester);
    expect(find.text('MISSION CLAIMED!'), findsNothing);
    expect(find.text('CLAIM'), findsNothing);
  });

  testWidgets('Play goes through difficulty selection into the game', (tester) async {
    final services = await _pumpApp(tester);
    await tester.tap(find.text('PLAY'));
    await _settle(tester);
    expect(find.text('CHOOSE DIFFICULTY'), findsOneWidget);
    await tester.tap(find.text('HARD'));
    await tester.pump();
    await tester.tap(find.text('START RIDE'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(GameWidget<KamoteGame>), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.text('HARD'), findsOneWidget, reason: 'HUD shows the chosen difficulty');
    expect(services.profile.settings.lastDifficulty, DifficultyLevel.hard, reason: 'choice is remembered');
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('PAUSED'), findsOneWidget);
    await tester.tap(find.text('MAIN MENU'));
    await _settle(tester);
    expect(find.text('PLAY'), findsOneWidget);
  });

  testWidgets('small phones (320x568) have no layout overflow', (tester) async {
    await _pumpApp(tester, wallet: 50000, logical: const Size(320, 568));
    for (final label in ['GARAGE', 'MISSIONS', 'COLLECTION', 'SETTINGS']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await _settle(tester);
      if (label == 'GARAGE') {
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.byTooltip('Next'));
          await _settle(tester);
        }
      }
      await _back(tester);
    }
    await tester.ensureVisible(find.text('PLAY'));
    await tester.tap(find.text('PLAY'));
    await _settle(tester);
    await tester.tap(find.text('START RIDE'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('PAUSED'), findsOneWidget);
  });
}
