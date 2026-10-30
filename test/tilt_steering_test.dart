import 'dart:convert';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/app.dart';
import 'package:kamote_rider/game/kamote_game.dart';
import 'package:kamote_rider/game/systems/tilt_steering.dart';
import 'package:kamote_rider/models/player_save_model.dart';
import 'package:kamote_rider/services/app_services.dart';
import 'package:kamote_rider/services/save_service.dart';

import 'helpers.dart';

/// A rider model that changes lane the moment it is steered.
class _Rider {
  int lane = 2;
  late final TiltSteering tilt = TiltSteering(onSteer: (d) => lane = (lane + d).clamp(0, 3));

  /// Holds [degrees] of tilt for [seconds] at 50 readings a second.
  void hold(double degrees, double seconds) {
    for (var t = 0.0; t < seconds; t += 0.02) {
      tilt.update(degrees, 0.02, currentLane: lane);
    }
  }
}

void main() {
  group('TiltSteering', () {
    test('right edge down reads as a positive (rightward) tilt', () {
      const g = 9.81;
      final a = 20 * math.pi / 180;
      expect(TiltSteering.rollDegrees(-g * math.sin(a), g * math.cos(a), 0), closeTo(20, 0.01));
      expect(TiltSteering.rollDegrees(g * math.sin(a), g * math.cos(a), 0), closeTo(-20, 0.01));
      expect(TiltSteering.rollDegrees(0, 0, g), 0, reason: 'lying flat is level');
    });

    test('the grip at the start counts as level and keeps the rider in their lane', () {
      final r = _Rider();
      r.hold(12, 2); // phone held at a slant from the start
      expect(r.lane, 2);
      expect(r.tilt.targetLane, 2);
    });

    test('tilting picks lanes one step at a time, never past the edges', () {
      final r = _Rider()..hold(0, 0.5);
      r.hold(40, 2);
      expect(r.lane, 3, reason: 'full right is the right lane');
      r.hold(-40, 2);
      expect(r.lane, 0, reason: 'full left is the left lane');
      r.hold(-90, 1);
      expect(r.lane, 0);
      r.hold(-6, 2);
      expect(r.lane, 1, reason: 'a small left tilt is the inner left lane');
    });

    test('holding near a lane edge does not flicker', () {
      final r = _Rider()..hold(0, 0.5);
      // Lane edge 2|3 sits at +12.5° with the default 25° range; crossing
      // it takes about 2° more (the hysteresis), leaving it about 2° less.
      r.hold(16, 2);
      expect(r.lane, 3);
      var changes = 0;
      var last = r.lane;
      for (var i = 0; i < 200; i++) {
        r.hold(i.isEven ? 11.5 : 13.5, 0.02);
        if (r.lane != last) changes++;
        last = r.lane;
      }
      expect(changes, 0);
    });

    test('lane changes are spaced out', () {
      var steps = 0;
      final tilt = TiltSteering(onSteer: (_) => steps++);
      tilt.update(0, 0.02, currentLane: 0);
      for (var i = 0; i < 5; i++) {
        tilt.update(40, 0.02, currentLane: 0); // rider "stuck": keeps asking
      }
      expect(steps, 1, reason: 'at most one step per ${TiltSteering.minStepSeconds} s');
    });

    test('recenter takes the next reading as level', () {
      final r = _Rider()..hold(0, 0.5);
      r.tilt.recenter();
      r.hold(30, 1);
      expect(r.lane, 2);
    });

    test('a smaller range needs less tilt', () {
      final r = _Rider()..tilt.rangeDegrees = 12;
      r.hold(0, 0.5);
      r.hold(10, 1);
      expect(r.lane, 3);
    });
  });

  group('saved setting', () {
    test('off by default, also for old saves', () async {
      final s = await makeServices(
        initial: {
          SaveService.storageKey: jsonEncode({
            'settings': {'music': true},
          }),
        },
      );
      expect(s.profile.settings.tiltSteering, isFalse);
      expect(s.profile.settings.tiltRange, TiltSteering.defaultRange);
    });

    test('survives a restart, and bad values are made safe', () async {
      final s = await makeServices();
      s.profile.settings
        ..tiltSteering = true
        ..tiltRange = 18;
      s.profile.commit();
      await Future<void>.delayed(Duration.zero);
      final reloaded = await reloadProfile();
      expect(reloaded.settings.tiltSteering, isTrue);
      expect(reloaded.settings.tiltRange, 18);
      final m = PlayerSaveModel.fromJson({
        'settings': {'tilt': 'yes', 'tiltRange': 99},
      });
      expect(m.settings.tiltSteering, isFalse);
      expect(m.settings.tiltRange, TiltSteering.maxRange);
    });
  });

  group('in the app', () {
    Future<AppServices> pumpApp(WidgetTester tester, {bool tilt = false}) async {
      tester.view.physicalSize = const Size(393, 851) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final s = await makeServices();
      s.profile.settings.tiltSteering = tilt;
      await tester.pumpWidget(KamoteApp(services: s));
      await tester.pump(const Duration(milliseconds: 100));
      return s;
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('settings switch tilt steering on and show the tilt range', (tester) async {
      final s = await pumpApp(tester);
      await tester.tap(find.text('SETTINGS'));
      await settle(tester);
      final toggle = find.text('Tilt steering');
      await tester.ensureVisible(toggle);
      await settle(tester);
      expect(find.text('Tilt needed'), findsNothing);
      await tester.tap(toggle);
      await settle(tester);
      expect(s.profile.settings.tiltSteering, isTrue);
      expect(find.text('Tilt needed'), findsOneWidget);
      expect(find.text('25°'), findsOneWidget);
    });

    testWidgets('a ride with tilt on and no sensor still plays normally', (tester) async {
      await pumpApp(tester, tilt: true);
      await tester.tap(find.text('PLAY'));
      await settle(tester);
      await tester.tap(find.text('START RIDE'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final game = tester.widget<GameWidget<KamoteGame>>(find.byType(GameWidget<KamoteGame>)).game!;
      expect(game.state.isPlaying, isTrue);
      await tester.timedDrag(
        find.byType(GameWidget<KamoteGame>),
        const Offset(-30, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(game.player.lane, 1, reason: 'swipe still works alongside tilt');
      game.pauseRun();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
