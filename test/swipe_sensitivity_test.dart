import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/app.dart';
import 'package:kamote_rider/game/kamote_game.dart';
import 'package:kamote_rider/game/systems/swipe_steering.dart';
import 'package:kamote_rider/models/player_save_model.dart';
import 'package:kamote_rider/services/app_services.dart';
import 'package:kamote_rider/services/save_service.dart';

import 'helpers.dart';

void main() {
  group('SwipeSteering', () {
    List<int> run(double sensitivity, List<double> moves, {double velocity = 0}) {
      final steps = <int>[];
      final s = SwipeSteering(onSteer: steps.add, sensitivity: sensitivity)..start();
      moves.forEach(s.update);
      s.end(velocity);
      return steps;
    }

    test('1x keeps the original 26 px per lane', () {
      expect(run(1, [25]), isEmpty);
      expect(run(1, [26]), [1]);
      expect(run(1, [-30, -30]), [-1, -1]);
    });

    test('higher sensitivity needs a shorter swipe per lane', () {
      expect(run(2, [13]), [1]);
      expect(run(2, [52]), [1, 1, 1, 1]);
      expect(run(0.5, [51]), isEmpty);
      expect(run(0.5, [52]), [1]);
    });

    test('flick threshold scales too, and only fires when no lane changed', () {
      expect(run(1, [5], velocity: 300), [1]);
      expect(run(0.5, [5], velocity: 300), isEmpty, reason: 'needs 500 px/s at 0.5x');
      expect(run(2, [5], velocity: -130), [-1], reason: 'needs 125 px/s at 2x');
      expect(run(1, [30], velocity: 900), [1], reason: 'no extra lane after a real step');
    });

    test('out-of-range sensitivity is clamped', () {
      expect(run(10, [13]), [1], reason: 'acts like 2x');
      expect(run(0, [51]), isEmpty, reason: 'acts like 0.5x');
    });
  });

  group('saved setting', () {
    test('old saves default to 1x', () async {
      final old = jsonEncode({
        'settings': {'music': true},
      });
      final s = await makeServices(initial: {SaveService.storageKey: old});
      expect(s.profile.settings.steerSensitivity, 1);
    });

    test('survives a restart', () async {
      final s = await makeServices();
      s.profile.settings.steerSensitivity = 1.75;
      s.profile.commit();
      await Future<void>.delayed(Duration.zero);
      expect((await reloadProfile()).settings.steerSensitivity, 1.75);
    });

    test('garbage and out-of-range values are made safe', () {
      double load(Object? v) => PlayerSaveModel.fromJson({
        'settings': {'steerSens': v},
      }).settings.steerSensitivity;
      expect(load('fast'), 1);
      expect(load(9), 2);
      expect(load(-1), 0.5);
    });
  });

  group('in the app', () {
    Future<AppServices> pumpApp(WidgetTester tester, {double? sensitivity}) async {
      tester.view.physicalSize = const Size(393, 851) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final services = await makeServices();
      if (sensitivity != null) services.profile.settings.steerSensitivity = sensitivity;
      await tester.pumpWidget(KamoteApp(services: services));
      await tester.pump(const Duration(milliseconds: 100));
      return services;
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('settings slider changes and saves the sensitivity', (tester) async {
      final services = await pumpApp(tester);
      await tester.tap(find.text('SETTINGS'));
      await settle(tester);
      final slider = find.byWidgetPredicate((w) => w is Slider && w.max == SwipeSteering.maxSensitivity);
      await tester.ensureVisible(slider);
      await settle(tester);
      expect(find.text('Swipe sensitivity'), findsOneWidget);
      expect(find.text('Normal · 1.0×'), findsOneWidget);
      expect(find.text('One lane every 26 px of swipe. Buttons and keys are not affected.'), findsOneWidget);

      final track = tester.getRect(slider);
      await tester.tapAt(Offset(track.right - 24, track.center.dy));
      await settle(tester);
      expect(services.profile.settings.steerSensitivity, 2);
      expect(find.text('High · 2.0×'), findsOneWidget);
      expect(find.text('One lane every 13 px of swipe. Buttons and keys are not affected.'), findsOneWidget);

      await tester.tap(find.text('RESET'));
      await settle(tester);
      expect(services.profile.settings.steerSensitivity, 1);
      expect(find.text('Normal · 1.0×'), findsOneWidget);
    });

    for (final (sens, lane) in [(0.5, 2), (1.0, 1), (2.0, 0)]) {
      testWidgets('the same swipe moves to lane $lane at ${sens}x', (tester) async {
        await pumpApp(tester, sensitivity: sens);
        await tester.tap(find.text('PLAY'));
        await settle(tester);
        await tester.tap(find.text('START RIDE'));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        final gameFinder = find.byType(GameWidget<KamoteGame>);
        final game = tester.widget<GameWidget<KamoteGame>>(gameFinder).game!;
        expect(game.player.lane, 2);
        // The same slow 30 px swipe left: 0 lanes at 0.5x (52 px per lane,
        // too slow for a flick), 1 lane at 1x (26 px), 2 lanes at 2x (13 px).
        await tester.timedDrag(gameFinder, const Offset(-30, 0), const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 50));
        expect(game.player.lane, lane);
        game.pauseRun();
        await tester.pump(const Duration(milliseconds: 100));
      });
    }
  });
}
