// Records the footage for the 4-minute gameplay showcase.
//
//   flutter test trailer/capture/showcase_test.dart --timeout none
//
// Gameplay is recorded widescreen (1920Ã—1080, 60 fps); menus as a phone
// (1080Ã—1920, 30 fps). trailer/showcase.py edits them into the video.
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/game/components/manhole.dart';
import 'package:kamote_rider/game/components/traffic_vehicle.dart';
import 'package:kamote_rider/game/difficulty_config.dart';
import 'package:kamote_rider/game/environments.dart';
import 'package:kamote_rider/game/game_config.dart';
import 'package:kamote_rider/game/game_state.dart';
import 'package:kamote_rider/game/kamote_game.dart';
import 'package:kamote_rider/game/systems/underground_system.dart';
import 'package:kamote_rider/models/barkada_model.dart';
import 'package:kamote_rider/overlays/ambulance_overlay.dart';
import 'package:kamote_rider/overlays/barkada_turn_overlay.dart';
import 'package:kamote_rider/overlays/fuel_game_over_overlay.dart';
import 'package:kamote_rider/overlays/game_hud.dart';
import 'package:kamote_rider/overlays/general_game_over_overlay.dart';
import 'package:kamote_rider/overlays/ticket_jail_overlay.dart';
import 'package:kamote_rider/screens/barkada_screens.dart';
import 'package:kamote_rider/screens/collection_screen.dart';
import 'package:kamote_rider/screens/garage_screen.dart';
import 'package:kamote_rider/screens/leaderboard_screen.dart';
import 'package:kamote_rider/services/app_services.dart';

import '../../test/helpers.dart';
import 'autopilot.dart';
import 'harness.dart';

const int seed = 21;

/// Desktop-style 1280Ã—720 window rendered at 1.5Ã— = 1920Ã—1080.
void useShowcaseWidescreen() {
  useWidescreen(frameRate: 60);
  logicalSize = const Size(1280, 720);
  pixelRatio = 1.5;
}

Widget _gameWidget(KamoteGame game, {bool hud = true}) => GameWidget<KamoteGame>(
  game: game,
  initialActiveOverlays: [if (game.barkada != null) KamoteGame.barkadaTurnOverlay],
  overlayBuilderMap: {
    KamoteGame.hudOverlay: (context, g) => hud ? GameHud(game: g) : const SizedBox(),
    KamoteGame.barkadaTurnOverlay: (context, g) => BarkadaTurnOverlay(game: g),
    KamoteGame.pauseOverlay: (_, _) => const SizedBox(),
    KamoteGame.ambulanceOverlay: (context, g) => AmbulanceOverlay(game: g),
    KamoteGame.jailOverlay: (context, g) => TicketJailOverlay(game: g),
    KamoteGame.fuelOverlay: (context, g) => FuelGameOverOverlay(game: g),
    KamoteGame.gameOverOverlay: (context, g) => GeneralGameOverOverlay(game: g),
  },
);

KamoteGame _newGame(AppServices services, {BarkadaSession? barkada}) {
  services.profile.settings.showSteerButtons = false;
  return KamoteGame(
    profile: services.profile,
    missions: services.missions,
    audio: services.audio,
    random: barkada == null ? math.Random(seed) : null,
    loadSprites: false,
    difficultyLevel: DifficultyLevel.medium,
    barkada: barkada,
    autoStart: barkada == null,
  );
}

Map<String, Object?> Function() _logger(KamoteGame game) => () => {
  'cash': game.rewards.runEarnings,
  'fuel': game.fuel.fraction,
  'chase': game.chase.active,
  'ug': game.underground.phase.name,
  'ugLeft': game.underground.remaining,
  'lane': game.player.lane,
  'combo': game.combo.combo,
  'kmh': game.speedKmh.round(),
  'm': game.distance.meters.round(),
  'world': game.visualEnvironmentIndex,
  'phase': game.state.phase.name,
  'lrtNear': game.world.children.whereType<TrafficVehicle>().any(
    (v) => v.type == VehicleType.lrt && v.oncoming && v.y > game.playerY - 700 && v.y < game.playerY,
  ),
};

Future<void> _skip(WidgetTester tester, double seconds, {void Function()? each}) async {
  for (var i = 0; i < (seconds * fps).round(); i++) {
    each?.call();
    await tester.pump(Duration(microseconds: 1000000 ~/ fps));
  }
}

/// Sends an oncoming vehicle straight at the rider (for the game-over scene).
void _headOn(KamoteGame game, VehicleType type) {
  game.spawner.enabled = false;
  game.world.add(
    TrafficVehicle(
      type: type,
      lane: game.player.lane,
      oncoming: true,
      speedKmh: 45,
      color: const Color(0xFF1565C0),
      variant: 0,
    )..y = game.playerY - 330,
  );
}

void main() {
  testWidgets('intro: checkpoint without HUD', (tester) async {
    useShowcaseWidescreen();
    await loadFonts(tester);
    setPhoneScreen(tester);
    final services = await makeServices();
    final game = _newGame(services);
    await tester.pumpWidget(appShell(services, _gameWidget(game, hud: false)));
    final pilot = Autopilot();
    await Recorder('sc_intro').record(tester, 12, each: () => pilot.step(game, 1 / fps), log: _logger(game));
  });

  testWidgets('main run: chase, cash, fuel, worlds, tunnel, crash', (tester) async {
    useShowcaseWidescreen();
    await loadFonts(tester);
    setPhoneScreen(tester);
    final services = await makeServices();
    final game = _newGame(services);
    await tester.pumpWidget(appShell(services, _gameWidget(game)));
    final pilot = Autopilot();
    final log = _logger(game);
    // Only the scripted manhole should send the rider underground, so the
    // video can show the highway scenes first.
    game.tunnels.enabled = false;
    void drive() => pilot.step(game, 1 / fps);
    void alive(String shot) => expect(game.state.phase, RunPhase.playing, reason: 'crashed during $shot');

    // Chase, traffic, cash; fuel runs low and a can saves the run.
    var t = 0.0;
    await Recorder('sc_run1').record(
      tester,
      62,
      log: log,
      each: () {
        drive();
        t += 1 / fps;
        if (t > 36 && t < 36.05) game.fuel.setFuel(17);
      },
    );
    alive('sc_run1');

    // Ride up to the next kilometer for a real world change.
    game.distance.advance(2000 - 110 - game.distance.meters);
    await Recorder('sc_run2').record(tester, 9, each: drive, log: log);
    alive('sc_run2');

    // The manhole and the full 20-second tunnel.
    game.tunnels.enabled = true; // pedestrians in the tunnel
    final holeLane = game.player.lane >= 2 ? game.player.lane - 1 : game.player.lane + 1;
    game.world.add(OpenManhole(lane: holeLane)..y = game.playerY - 520);
    pilot
      ..seekManhole = true
      ..preferLane = holeLane;
    var sentTrain = false;
    var inside = 0.0;
    final tunnel = Recorder('sc_tunnel');
    while (game.underground.trips == 0 && tunnel.frames < 60 * 40) {
      await tunnel.record(
        tester,
        1 / fps,
        log: log,
        each: () {
          drive();
          if (game.underground.phase == UndergroundPhase.inside) {
            pilot
              ..seekManhole = false
              ..preferLane = null;
            inside += 1 / fps;
            if (!sentTrain && inside > 6) {
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
              sentTrain = true;
            }
          }
        },
      );
    }
    game.tunnels.enabled = false;
    await tunnel.record(tester, 3, each: drive, log: log);
    expect(game.underground.trips, 1, reason: 'tunnel trip completed');
    alive('sc_tunnel');

    await Recorder('sc_run3').record(tester, 24, each: drive, log: log);
    alive('sc_run3');

    // Game over: a head-on crash, the results, then RESTART.
    _headOn(game, VehicleType.bus);
    final crash = Recorder('sc_crash');
    await crash.record(tester, 5.5, log: log);
    expect(game.state.phase, RunPhase.gameOver);
    await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -900));
    await crash.record(tester, 2.2, log: log);
    await tester.tap(find.text('RESTART'));
    await crash.record(tester, 1.5, log: log);
  });

  testWidgets('garage and collection', (tester) async {
    usePhone();
    await loadFonts(tester);
    setPhoneScreen(tester);
    final services = await makeServices();
    services.profile.data.wallet = 9400;
    services.profile.commit();
    await tester.pumpWidget(appShell(services, const GarageScreen()));
    final rec = Recorder('sc_garage');
    await rec.record(tester, 1.2);
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await rec.record(tester, 0.8);
    }
    await tester.tap(find.text('BUY ₱5,000'));
    await rec.record(tester, 1.0);
    await tester.tap(find.text('PAY'));
    await rec.record(tester, 2.6);
    await tester.tap(find.text('RIDE IT!'));
    await rec.record(tester, 0.8);
    for (var i = 0; i < 10; i++) {
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await rec.record(tester, 0.6);
    }
    await rec.record(tester, 0.6);

    await tester.pumpWidget(appShell(services, const CollectionScreen()));
    final grid = Recorder('sc_collection');
    await grid.record(tester, 1.6);
    await tester.drag(find.byType(GridView), const Offset(0, -700));
    await grid.record(tester, 2.2);
  });

  testWidgets('barkada race and leaderboard (real runs)', (tester) async {
    usePhone();
    await loadFonts(tester);
    setPhoneScreen(tester);
    final services = await makeServices();
    services.profile.setPlayerName('Ana');

    await tester.pumpWidget(appShell(services, const BarkadaSetupScreen()));
    final setup = Recorder('sc_bk_setup');
    await setup.record(tester, 0.8);
    await tester.tap(find.text('3'));
    await setup.record(tester, 0.6);
    await tester.enterText(find.byType(TextField).at(1), 'Ben');
    await setup.record(tester, 0.6);
    await tester.enterText(find.byType(TextField).at(2), 'Carlo');
    await setup.record(tester, 1.4);

    // Three real turns on the same seeded highway; each rider crashes at a
    // different point so the standings differ.
    final session = BarkadaSession(names: ['Ana', 'Ben', 'Carlo'], difficulty: DifficultyLevel.medium, seed: 77);
    const crashAfter = [26.0, 34.0, 19.0];
    for (var turn = 0; turn < 3; turn++) {
      final game = _newGame(services, barkada: session);
      await tester.pumpWidget(appShell(services, _gameWidget(game)));
      final pilot = Autopilot();
      if (turn == 1) {
        final rec = Recorder('sc_bk_turn');
        await rec.record(tester, 2.2);
        await tester.tap(find.text('START'));
        await rec.record(tester, 3.5, each: () => pilot.step(game, 1 / fps));
      } else {
        await tester.pump();
        await tester.tap(find.text('START'));
      }
      var guard = 0.0;
      while (game.state.phase == RunPhase.playing && guard < crashAfter[turn]) {
        await _skip(tester, 0.5, each: () => pilot.step(game, 1 / fps));
        guard += 0.5;
      }
      if (game.state.phase == RunPhase.playing) _headOn(game, VehicleType.truck);
      await _skip(tester, 5);
      expect(session.resultOf(turn), isNotNull, reason: 'turn ${turn + 1} recorded');
      session.advance();
    }
    expect(session.finished, isTrue);

    await tester.pumpWidget(appShell(services, BarkadaResultsScreen(session: session)));
    await Recorder('sc_bk_results').record(tester, 4.6);

    await tester.pumpWidget(appShell(services, const LeaderboardScreen()));
    final board = Recorder('sc_leaderboard');
    await board.record(tester, 3.0);
    await tester.tap(find.text('DISTANCE'));
    await board.record(tester, 2.2);
    await tester.tap(find.text('Best each'));
    await board.record(tester, 2.4);
  });
}
