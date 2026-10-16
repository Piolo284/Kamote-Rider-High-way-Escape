import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/game/components/road_obstacle.dart';
import 'package:kamote_rider/game/components/traffic_vehicle.dart';
import 'package:kamote_rider/game/environments.dart';
import 'package:kamote_rider/game/game_state.dart';
import 'package:kamote_rider/game/kamote_game.dart';
import 'package:kamote_rider/game/systems/highway_challenge_manager.dart';
import 'package:kamote_rider/game/painting/bike_painter.dart';
import 'package:kamote_rider/game/painting/prop_painter.dart';
import 'package:kamote_rider/game/painting/vehicle_painter.dart';
import 'package:kamote_rider/models/motorcycle_model.dart';
import 'package:kamote_rider/services/app_services.dart';

import 'helpers.dart';

/// Executes every paint path so drawing code cannot crash at runtime.
late AppServices services;

Canvas _canvas() => Canvas(PictureRecorder());

KamoteGame _create() {
  final game = KamoteGame(
    profile: services.profile,
    missions: services.missions,
    audio: services.audio,
    random: math.Random(9),
    loadSprites: false,
  );
  for (final name in [KamoteGame.hudOverlay, KamoteGame.pauseOverlay, ...KamoteGame.endOverlays]) {
    game.overlays.addEntry(name, (_, _) => const SizedBox());
  }
  return game;
}

/// Steps at 60 fps and renders every [renderEvery] frames.
Future<void> _run(KamoteGame game, double seconds, {int renderEvery = 1}) async {
  final frames = (seconds * 60).round();
  for (var i = 0; i < frames; i++) {
    await game.ready();
    game.update(1 / 60);
    if (i % renderEvery == 0) game.render(_canvas());
  }
}

void main() {
  setUp(() async => services = await makeServices());

  test('every motorcycle, vehicle and prop paints without errors', () {
    final canvas = _canvas();
    for (final bike in MotorcycleCatalog.all) {
      BikePainter.paint(canvas, const Size(30, 60), bike, braking: true, opacity: 0.5);
    }
    BikePainter.paintOfficer(canvas, const Size(30, 60), sirenPhase: 1.3);
    for (final type in VehicleType.values) {
      VehiclePainter.paint(canvas, VehiclePainter.sizeOf(type), type, VehiclePainter.defaultColor(type, 1));
      VehiclePainter.paint(
        canvas,
        VehiclePainter.sizeOf(type),
        type,
        VehiclePainter.defaultColor(type, 2),
        facingDown: true,
        variant: 3,
      );
    }
    VehiclePainter.paintAmbulance(canvas, const Size(46, 86), sirenPhase: 0.7);
    for (final type in PropType.values) {
      PropPainter.paint(canvas, type, PropPainter.sizeOf(type), variant: 3, onLeft: true);
      PropPainter.paint(canvas, type, PropPainter.sizeOf(type), variant: 4, onLeft: false);
    }
  });

  testWithGame<KamoteGame>('renders a ride through all five worlds', _create, (game) async {
    game.onGameResize(Vector2(400, 860));
    game.fuel.drainPerSecond = 0;
    game.player.startInvulnerability(1e9);
    final seen = <int>{};
    while (game.distance.meters < 5100) {
      await _run(game, 0.5, renderEvery: 30);
      seen.add(game.distance.environmentIndex);
    }
    expect(seen, {0, 1, 2, 3, 4});
    expect(game.distance.cycle, 1);
  });

  testWithGame<KamoteGame>('renders the chase and jail ending', _create, (game) async {
    game.onGameResize(Vector2(400, 860));
    game.spawner.enabled = false;
    game.fuel.drainPerSecond = 0;
    await _run(game, 6);
    expect(game.chase.active, isTrue, reason: 'checkpoint chase');
    game.world.add(RoadObstacle(type: ObstacleType.barrier, lane: game.player.lane)..y = game.playerY - 90);
    await _run(game, 4);
    expect(game.state.endReason, EndReason.ticketAndJail);
  });

  testWithGame<KamoteGame>('renders the head-on ambulance ending', _create, (game) async {
    game.onGameResize(Vector2(400, 860));
    game.spawner.enabled = false;
    game.fuel.drainPerSecond = 0;
    await _run(game, 1);
    game.world.add(
      TrafficVehicle(
        type: VehicleType.bus,
        lane: game.player.lane,
        oncoming: true,
        speedKmh: 50,
        color: const Color(0xFF1565C0),
        variant: 0,
      )..y = game.playerY - 220,
    );
    await _run(game, 4);
    expect(game.state.endReason, EndReason.headOnCrash);
  });

  testWithGame<KamoteGame>('renders the out-of-fuel ending', _create, (game) async {
    game.onGameResize(Vector2(400, 860));
    game.spawner.enabled = false;
    await _run(game, 1);
    game.fuel.setFuel(0.01);
    await _run(game, 5);
    expect(game.state.endReason, EndReason.outOfFuel);
  });

  testWithGame<KamoteGame>('renders every highway challenge and animal', _create, (game) async {
    game.onGameResize(Vector2(400, 860));
    game.spawner.enabled = false;
    game.challenges.enabled = false;
    game.fuel.drainPerSecond = 0;
    game.player.startInvulnerability(1e9);
    await _run(game, 3, renderEvery: 30);
    for (final type in ChallengeType.values) {
      if (type == ChallengeType.fuelEmergency) game.fuel.setFuel(15);
      expect(game.challenges.forceStart(type), isTrue, reason: type.name);
      await _run(game, 6, renderEvery: 4);
      game.fuel.setFuel(100);
    }
    expect(game.state.phase, RunPhase.playing);
  });
}
