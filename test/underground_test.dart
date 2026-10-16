import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/game/components/manhole.dart';
import 'package:kamote_rider/game/components/road_animal.dart';
import 'package:kamote_rider/game/components/road_obstacle.dart';
import 'package:kamote_rider/game/components/traffic_vehicle.dart';
import 'package:kamote_rider/game/environments.dart';
import 'package:kamote_rider/game/game_config.dart';
import 'package:kamote_rider/game/game_state.dart';
import 'package:kamote_rider/game/kamote_game.dart';
import 'package:kamote_rider/game/systems/underground_system.dart';
import 'package:kamote_rider/services/app_services.dart';

import 'helpers.dart';

late AppServices services;

KamoteGame _create({int seed = 5}) {
  final game = KamoteGame(
    profile: services.profile,
    missions: services.missions,
    audio: services.audio,
    random: math.Random(seed),
    loadSprites: false,
  );
  for (final name in [KamoteGame.hudOverlay, KamoteGame.pauseOverlay, ...KamoteGame.endOverlays]) {
    game.overlays.addEntry(name, (_, _) => const SizedBox());
  }
  return game;
}

Future<void> _run(KamoteGame game, double seconds, {void Function()? each}) async {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    await game.ready();
    game.update(1 / 60);
    each?.call();
  }
}

/// Lanes blocked at the rider's row (same rule as the challenge tests).
Set<int> _blockedLanes(KamoteGame game) {
  final row = Rect.fromLTRB(0, game.playerY - 30, 400, game.playerY + 30);
  final lanes = <int>{};
  for (final c in game.world.children) {
    Rect? r;
    if (c is TrafficVehicle) r = c.hitRect;
    if (c is RoadObstacle) r = c.hitRect;
    if (c is RoadAnimal && c.isOnRoad) r = c.hitRect;
    if (r == null || !r.overlaps(row)) continue;
    for (var lane = 0; lane < GameConfig.laneCount; lane++) {
      final l0 = GameConfig.roadLeft + lane * GameConfig.laneWidth;
      if (r.right > l0 && r.left < l0 + GameConfig.laneWidth) lanes.add(lane);
    }
  }
  return lanes;
}

/// Drops the rider into a manhole placed right in front of them.
Future<void> _fallIn(KamoteGame game) async {
  game.world.add(OpenManhole(lane: game.player.lane)..y = game.playerY - 120);
  var guard = 0;
  while (game.underground.phase != UndergroundPhase.falling && guard++ < 300) {
    await _run(game, 1 / 60);
  }
  expect(game.underground.phase, UndergroundPhase.falling, reason: 'rider rode into the manhole');
}

void main() {
  setUp(() async => services = await makeServices());

  group('UndergroundSystem', () {
    test('fall, 20 s inside, climb out', () {
      final u = UndergroundSystem();
      expect(u.enter(), isTrue);
      expect(u.enter(), isFalse, reason: 'cannot fall twice');
      final events = <UndergroundEvent>[];
      var insideSeconds = 0.0;
      for (var i = 0; i < 60 * 30; i++) {
        if (u.phase == UndergroundPhase.inside) insideSeconds += 1 / 60;
        final e = u.update(1 / 60);
        if (e != null) events.add(e);
      }
      expect(events, [UndergroundEvent.arrived, UndergroundEvent.timeUp, UndergroundEvent.surfaced]);
      expect(insideSeconds, closeTo(UndergroundSystem.duration, 0.05));
      expect(u.phase, UndergroundPhase.surface);
      expect(u.trips, 1);
      expect(u.blackout, 0);
    });

    test('pausing (no time step) freezes the countdown', () {
      final u = UndergroundSystem()..enter();
      u.update(1);
      final left = u.remaining;
      for (var i = 0; i < 100; i++) {
        u.update(0);
      }
      expect(u.remaining, left);
    });

    test('the screen is black at both swaps', () {
      final u = UndergroundSystem()..enter();
      while (u.update(1 / 60) != UndergroundEvent.arrived) {}
      expect(u.blackout, closeTo(1, 0.01));
      while (u.update(1 / 60) != UndergroundEvent.surfaced) {}
      expect(u.blackout, closeTo(1, 0.01));
    });
  });

  group('ManholePlanner', () {
    test('one manhole per world, inside the world', () {
      for (var seed = 0; seed < 20; seed++) {
        final p = ManholePlanner(random: math.Random(seed));
        final placedAt = <int, double>{};
        for (var m = 0.0; m < 5000; m += 2) {
          final world = (m / 1000).floor();
          if (p.due(world, m)) {
            expect(placedAt.containsKey(world), isFalse);
            placedAt[world] = m;
            p.markPlaced(world);
          }
        }
        expect(placedAt.keys, [0, 1, 2, 3, 4]);
        for (final MapEntry(key: world, value: m) in placedAt.entries) {
          expect(
            m,
            greaterThanOrEqualTo(math.max(world * 1000 + ManholePlanner.earliest, ManholePlanner.firstRunMeters)),
          );
          expect(m, lessThan(world * 1000 + ManholePlanner.latest + 2));
        }
      }
    });
  });

  testWithGame<KamoteGame>('each world gets exactly one manhole', _create, (game) async {
    game.onGameResize(Vector2(400, 860));
    game.fuel.drainPerSecond = 0;
    game.player.startInvulnerability(1e9);
    // Keep to the far-left lane edge so the rider never falls in.
    final seen = <OpenManhole>{};
    final worlds = <int>[];
    while (game.distance.meters < 3000 && game.state.phase == RunPhase.playing) {
      await _run(
        game,
        0.5,
        each: () {
          for (final hole in game.world.children.whereType<OpenManhole>()) {
            if (seen.add(hole)) worlds.add((game.distance.meters / 1000).floor());
            hole.used = true;
          }
        },
      );
      if (game.underground.active) fail('rider should not have fallen in');
    }
    expect(worlds, [0, 1, 2]);
  });

  testWithGame<KamoteGame>('falling in: 20 s tunnel with LRT and pedestrians, then back up', _create, (game) async {
    game.onGameResize(Vector2(400, 860));
    game.fuel.drainPerSecond = 0;
    await _run(game, 6);
    expect(game.chase.active, isTrue, reason: 'start checkpoint chase');
    await _fallIn(game);
    expect(game.chase.active, isFalse, reason: 'the LTO cannot follow you down');

    game.player.startInvulnerability(1e9);
    var tunnelSeconds = 0.0;
    var worst = 0;
    final pedestrians = <RoadAnimal>{};
    var lrt = 0;
    while (game.underground.active) {
      await _run(game, 1 / 60);
      if (game.underground.showsTunnel) {
        tunnelSeconds += 1 / 60;
        expect(game.visualEnvironmentIndex, Environments.undergroundIndex);
        worst = math.max(worst, _blockedLanes(game).length);
        pedestrians.addAll(game.world.children.whereType<RoadAnimal>().where((a) => a.kind == AnimalKind.pedestrian));
        lrt = math.max(
          lrt,
          game.world.children.whereType<TrafficVehicle>().where((v) => v.type == VehicleType.lrt).length,
        );
      }
    }
    expect(tunnelSeconds, closeTo(UndergroundSystem.duration + UndergroundSystem.riseSeconds, 0.1));
    expect(worst, lessThanOrEqualTo(2), reason: 'always an escape lane');
    expect(lrt, greaterThan(0), reason: 'LRT trains ran');
    expect(pedestrians, isNotEmpty, reason: 'pedestrians crossed');
    expect(game.visualEnvironmentIndex, game.distance.environmentIndex);
    expect(game.underground.trips, 1);
    expect(game.state.phase, RunPhase.playing);
  });

  testWithGame<KamoteGame>('crashing into an LRT underground still ends the run', _create, (game) async {
    game.onGameResize(Vector2(400, 860));
    game.fuel.drainPerSecond = 0;
    await _run(game, 1);
    await _fallIn(game);
    while (game.underground.phase != UndergroundPhase.inside) {
      await _run(game, 1 / 60);
    }
    await _run(game, 1.5);
    game.spawner.enabled = false;
    game.world.add(
      TrafficVehicle(
        type: VehicleType.lrt,
        lane: game.player.lane,
        oncoming: true,
        speedKmh: 40,
        color: const Color(0xFFECEFF1),
        variant: 0,
      )..y = game.playerY - 300,
    );
    await _run(game, 4);
    expect(game.state.endReason, EndReason.headOnCrash);
  });
}
