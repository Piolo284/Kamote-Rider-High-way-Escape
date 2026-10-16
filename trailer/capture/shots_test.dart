// Records every gameplay and menu shot used by the trailer.
//
//   flutter test trailer/capture/shots_test.dart
//
// Frames land in $TRAILER_FRAMES/<shot>/ (default build/trailer_frames);
// trailer/compose.py turns them into the finished MP4.
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/game/components/manhole.dart';
import 'package:kamote_rider/game/components/road_animal.dart';
import 'package:kamote_rider/game/components/scenery_prop.dart';
import 'package:kamote_rider/game/components/traffic_vehicle.dart';
import 'package:kamote_rider/game/difficulty_config.dart';
import 'package:kamote_rider/game/environments.dart';
import 'package:kamote_rider/game/game_config.dart';
import 'package:kamote_rider/game/game_state.dart';
import 'package:kamote_rider/game/kamote_game.dart';
import 'package:kamote_rider/game/systems/underground_system.dart';
import 'package:kamote_rider/models/barkada_model.dart';
import 'package:kamote_rider/models/leaderboard_model.dart';
import 'package:kamote_rider/overlays/game_hud.dart';
import 'package:kamote_rider/screens/barkada_screens.dart';
import 'package:kamote_rider/screens/garage_screen.dart';
import 'package:kamote_rider/screens/leaderboard_screen.dart';
import 'package:kamote_rider/services/app_services.dart';

import '../../test/helpers.dart';
import 'autopilot.dart';
import 'harness.dart';

Future<KamoteGame> _startGame(WidgetTester tester, AppServices services, int seed) async {
  services.profile.settings.showSteerButtons = false;
  final game = KamoteGame(
    profile: services.profile,
    missions: services.missions,
    audio: services.audio,
    random: math.Random(seed),
    loadSprites: false,
    difficultyLevel: DifficultyLevel.medium,
  );
  await tester.pumpWidget(
    appShell(
      services,
      GameWidget<KamoteGame>(
        game: game,
        initialActiveOverlays: const [KamoteGame.hudOverlay],
        overlayBuilderMap: {
          KamoteGame.hudOverlay: (context, g) => GameHud(game: g),
          for (final name in [KamoteGame.pauseOverlay, ...KamoteGame.endOverlays]) name: (_, _) => const SizedBox(),
        },
      ),
    ),
  );
  return game;
}

/// Skips ahead without recording.
Future<void> _skip(WidgetTester tester, double seconds, {void Function()? each}) async {
  for (var i = 0; i < (seconds * fps).round(); i++) {
    each?.call();
    await tester.pump(const Duration(microseconds: 1000000 ~/ fps));
  }
}

/// Cuts to the start of [world]: new scenery all the way to the horizon.
void _jumpToWorld(KamoteGame game, int world) {
  game.distance.advance(world * GameConfig.metersPerEnvironment + 8 - game.distance.meters);
  for (final prop in game.world.children.whereType<SceneryProp>().toList()) {
    prop.removeFromParent();
  }
  game.road.reset();
  game.environment.reset();
  game.environment.populate(game.viewHeight);
  final theme = Environments.at(world);
  game.hud.showBanner('WORLD ${world + 1}: ${theme.name.toUpperCase()}', theme.tagline, theme.accent);
}

void _expectAlive(KamoteGame game, String shot) {
  expect(game.state.phase, RunPhase.playing, reason: 'the rider crashed during $shot; try another seed');
}

void main() {
  testWidgets('ride: checkpoint, highway, worlds, tunnel', (tester) async {
    await loadFonts(tester);
    setPhoneScreen(tester);
    final services = await makeServices();
    final game = await _startGame(tester, services, 21);
    final pilot = Autopilot();
    void drive() => pilot.step(game, 1 / fps);
    Map<String, Object?> state() => {
      'cash': game.rewards.runEarnings,
      'fuel': game.fuel.fraction,
      'chase': game.chase.active,
      'ug': game.underground.phase.name,
      'lane': game.player.lane,
      'combo': game.combo.combo,
      'kmh': game.speedKmh.round(),
      'world': game.visualEnvironmentIndex,
    };

    await Recorder('s1_checkpoint').record(tester, 12, each: drive, log: state);
    _expectAlive(game, 's1');
    await Recorder('s2_highway').record(tester, 15, each: drive, log: state);
    _expectAlive(game, 's2');

    // Worlds montage.
    _jumpToWorld(game, 1);
    await Recorder('s3a_provincial').record(tester, 4.4, each: drive, log: state);
    _jumpToWorld(game, 2);
    await Recorder('s3b_mountain').record(tester, 4.4, each: drive, log: state);
    _jumpToWorld(game, 3);
    game.fuel.setFuel(13);
    await Recorder('s3c_coastal_fuel').record(tester, 5.2, each: drive, log: state);
    _expectAlive(game, 's3');
    game.fuel.setFuel(80);

    // Ride into a manhole.
    await _skip(tester, 1.5, each: drive);
    final holeLane = game.player.lane >= 2 ? game.player.lane - 1 : game.player.lane + 1;
    game.world.add(OpenManhole(lane: holeLane)..y = game.playerY - 470);
    pilot
      ..seekManhole = true
      ..preferLane = holeLane;
    final tunnelIn = Recorder('s4a_fall');
    var guard = 0;
    while (game.underground.phase != UndergroundPhase.inside && guard++ < 200) {
      await tunnelIn.record(tester, 1 / fps, each: drive, log: state);
    }
    expect(game.underground.phase, UndergroundPhase.inside, reason: 'rider fell into the manhole');
    pilot
      ..seekManhole = false
      ..preferLane = null;
    await tunnelIn.record(tester, 1.2, each: drive, log: state);

    // Inside: make sure an oncoming train and a pedestrian show up on camera.
    final inside = Recorder('s4b_tunnel');
    var t = 0.0;
    var trainSent = false;
    var pedestrian = false;
    await inside.record(
      tester,
      11.5,
      log: state,
      each: () {
        drive();
        t += 1 / fps;
        if (!trainSent && t > 1.5) {
          final lane = game.player.lane <= 1 ? 1 - game.player.lane : 0;
          game.world.add(
            TrafficVehicle(
              type: VehicleType.lrt,
              lane: lane,
              oncoming: true,
              speedKmh: 34,
              color: const Color(0xFFEDE7F6),
              variant: 2,
            )..y = GameConfig.spawnY - 95,
          );
          trainSent = true;
        }
        if (!pedestrian && t > 5.5) {
          game.spawner.holdHazardsFor(0.5);
          pedestrian = game.challenges.animals.trySpawn(AnimalKind.pedestrian);
        }
      },
    );
    _expectAlive(game, 's4b');
    await _skip(tester, math.max(0, game.underground.remaining - 1.4), each: drive);
    await Recorder('s4c_surface').record(tester, 4.4, each: drive, log: state);
    _expectAlive(game, 's4c');

    // Extra fast footage for the finale montage.
    await Recorder('s7_montage').record(tester, 6, each: drive, log: state);
    // ignore: avoid_print
    print('ride done at ${game.distance.meters.round()} m, pedestrian=$pedestrian');
  });

  testWidgets('garage: browse and unlock', (tester) async {
    await loadFonts(tester);
    setPhoneScreen(tester);
    final services = await makeServices();
    services.profile.data.wallet = 9400;
    services.profile.commit();
    await tester.pumpWidget(appShell(services, const GarageScreen()));
    final rec = Recorder('s5_garage');
    await rec.record(tester, 1.2);
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await rec.record(tester, 0.9);
    }
    await tester.tap(find.text('BUY ₱5,000'));
    await rec.record(tester, 1.0);
    await tester.tap(find.text('PAY'));
    await rec.record(tester, 3.2);
  });

  testWidgets('barkada race and leaderboard', (tester) async {
    await loadFonts(tester);
    setPhoneScreen(tester);
    final services = await makeServices();
    services.profile.setPlayerName('Ana');

    await tester.pumpWidget(appShell(services, const BarkadaSetupScreen()));
    final setup = Recorder('s6a_setup');
    await setup.record(tester, 0.6);
    await tester.tap(find.text('3'));
    await setup.record(tester, 0.5);
    await tester.enterText(find.byType(TextField).at(1), 'Ben');
    await setup.record(tester, 0.4);
    await tester.enterText(find.byType(TextField).at(2), 'Carlo');
    await setup.record(tester, 1.0);

    final session = BarkadaSession(names: ['Ana', 'Ben', 'Carlo'], difficulty: DifficultyLevel.medium, seed: 4);
    for (final r in const [
      BarkadaResult(score: 3480, distanceMeters: 2810, earnings: 670, ending: 'Caught by the LTO', tunnelTrips: 1),
      BarkadaResult(score: 4125, distanceMeters: 3302, earnings: 823, ending: 'Crashed', tunnelTrips: 1),
      BarkadaResult(score: 2290, distanceMeters: 1964, earnings: 326, ending: 'Out of fuel', tunnelTrips: 0),
    ]) {
      session.record(r);
      session.advance();
    }
    await tester.pumpWidget(appShell(services, BarkadaResultsScreen(session: session)));
    await Recorder('s6b_results').record(tester, 4.2);

    final board = services.profile.data.leaderboard;
    var day = 0;
    for (final (name, score, dist, barkada) in const [
      ('Ben', 4125, 3302.0, true),
      ('Kamote King', 3950, 3120.0, false),
      ('Ana', 3480, 2810.0, true),
      ('Lodi Rider', 3110, 2604.0, false),
      ('Carlo', 2290, 1964.0, true),
      ('Idol Juan', 1875, 1550.0, false),
      ('Ana', 1420, 1206.0, false),
    ]) {
      board.add(
        LeaderboardEntry(
          playerName: name,
          score: score,
          distanceMeters: dist,
          earnings: score - dist.floor(),
          difficultyLabel: 'MEDIUM',
          bikeName: 'Kamote 110',
          timestamp: DateTime(2026, 10, 1 + day++),
          barkada: barkada,
        ),
      );
    }
    Leaderboard.trim(board);
    services.profile.commit();
    await tester.pumpWidget(appShell(services, const LeaderboardScreen()));
    await Recorder('s6c_leaderboard').record(tester, 4.4);
  });
}
