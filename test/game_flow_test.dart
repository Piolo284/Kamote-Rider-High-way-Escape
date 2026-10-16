import 'dart:math' as math;
import 'dart:ui' show Color, Rect;

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/game/components/cash_collectible.dart';
import 'package:kamote_rider/game/components/fuel_collectible.dart';
import 'package:kamote_rider/game/components/lto_officer.dart';
import 'package:kamote_rider/game/components/road_obstacle.dart';
import 'package:kamote_rider/game/components/traffic_vehicle.dart';
import 'package:kamote_rider/game/environments.dart';
import 'package:kamote_rider/game/game_config.dart';
import 'package:kamote_rider/game/game_state.dart';
import 'package:kamote_rider/game/kamote_game.dart';
import 'package:kamote_rider/models/mission_model.dart';
import 'package:kamote_rider/services/app_services.dart';

import 'helpers.dart';

late AppServices services;

KamoteGame _create() {
  final game = KamoteGame(
    profile: services.profile,
    missions: services.missions,
    audio: services.audio,
    random: math.Random(3),
    loadSprites: false,
  );
  // GameWidget normally registers overlay builders; stub them headless.
  for (final name in [KamoteGame.hudOverlay, KamoteGame.pauseOverlay, ...KamoteGame.endOverlays]) {
    game.overlays.addEntry(name, (_, _) => const SizedBox());
  }
  return game;
}

/// Portrait phone-sized viewport, no random spawns, no checkpoint chase.
Future<void> _prepare(KamoteGame game, {bool removeCheckpoint = true}) async {
  game.onGameResize(Vector2(400, 800));
  game.spawner.enabled = false;
  game.challenges.enabled = false;
  if (removeCheckpoint) {
    for (final c in game.world.children.whereType<LtoCheckpoint>().toList()) {
      c.removeFromParent();
    }
  }
  await step(game, 0.1);
}

/// Advances the simulation at 60 fps. Yields between frames like the real
/// event loop so components added mid-run finish loading and mount.
Future<void> step(KamoteGame game, double seconds) async {
  final frames = (seconds * 60).round();
  for (var i = 0; i < frames; i++) {
    await game.ready();
    game.update(1 / 60);
  }
}

/// Lets the rider reach cruising speed so hazards actually approach.
Future<void> cruise(KamoteGame game) async {
  game.fuel.drainPerSecond = 0;
  await step(game, 3);
}

void placeBarrierAhead(KamoteGame game) {
  game.world.add(RoadObstacle(type: ObstacleType.barrier, lane: game.player.lane)..y = game.playerY - 90);
}

void main() {
  setUp(() async {
    services = await makeServices();
  });

  testWithGame<KamoteGame>('run starts once with HUD, full fuel and the selected bike', _create, (game) async {
    await _prepare(game);
    expect(game.state.phase, RunPhase.playing);
    expect(game.overlays.isActive(KamoteGame.hudOverlay), isTrue);
    expect(game.fuel.fraction, closeTo(1, 0.01));
    expect(game.player.bike.id, services.profile.data.selectedBike);
    game.startRun();
    expect(game.state.phase, RunPhase.playing, reason: 'second start is ignored');
  });

  testWithGame<KamoteGame>('swipe steering moves lanes smoothly and stays on the road', _create, (game) async {
    await _prepare(game);
    final startX = game.player.x;
    game.steer(1);
    await step(game, 0.05);
    expect(game.player.x, greaterThan(startX));
    expect(game.player.x, lessThan(GameConfig.laneCenter(3)), reason: 'interpolates, no teleport');
    await step(game, 0.5);
    expect(game.player.x, closeTo(GameConfig.laneCenter(3), 0.5));
    game.steer(-1);
    game.steer(-1);
    game.steer(-1);
    await step(game, 1);
    expect(game.player.lane, 0);
    expect(game.player.x, greaterThanOrEqualTo(GameConfig.roadLeft));
  });

  testWithGame<KamoteGame>('fuel drains while riding and pickups refill without overflow', _create, (game) async {
    await _prepare(game);
    await step(game, 3);
    final afterRiding = game.fuel.fuel;
    expect(afterRiding, lessThan(GameConfig.maxFuel));
    game.world.add(FuelCollectible(lane: game.player.lane)..y = game.playerY - 70);
    await step(game, 1);
    expect(game.rewards.fuelCollected, 1);
    expect(game.fuel.fuel, lessThanOrEqualTo(GameConfig.maxFuel));
    expect(game.fuel.fuel, greaterThan(afterRiding));
  });

  testWithGame<KamoteGame>('cash is collected once and increases run earnings', _create, (game) async {
    await _prepare(game);
    await cruise(game);
    final bill = CashCollectible()..configure(lane: game.player.lane, y: game.playerY - 70, value: 50, phase: 0);
    game.world.add(bill);
    await step(game, 1);
    expect(game.rewards.billCash, 50);
    expect(game.rewards.billsCollected, 1);
    expect(game.hud.runCash, 50);
    expect(
      services.missions.stateOf(MissionCatalog.byId('collect_bills')!).progress,
      1,
      reason: 'missions track real pickups',
    );
  });

  testWithGame<KamoteGame>('side collision starts a 10 s chase that can be survived', _create, (game) async {
    await _prepare(game);
    await cruise(game);
    placeBarrierAhead(game);
    await step(game, 1);
    expect(game.chase.active, isTrue);
    expect(game.status, GameStatus.policeChase);
    expect(game.state.phase, RunPhase.playing, reason: 'a chase does not end the run');
    expect(game.world.children.whereType<LtoOfficer>().length, 1);
    await step(game, 10);
    expect(game.chase.active, isFalse);
    expect(game.chase.survivedCount, 1);
    expect(game.rewards.chaseBonusCash, GameConfig.chaseEscapeBonus);
    await step(game, 2);
    expect(game.world.children.whereType<LtoOfficer>(), isEmpty, reason: 'officer leaves');
  });

  testWithGame<KamoteGame>('second collision during a chase ends in ticket and jail', _create, (game) async {
    await _prepare(game);
    await cruise(game);
    placeBarrierAhead(game);
    await step(game, 2);
    expect(game.chase.active, isTrue);
    placeBarrierAhead(game);
    await step(game, 1);
    expect(game.state.endReason, EndReason.ticketAndJail);
    await step(game, 4);
    expect(game.state.phase, RunPhase.gameOver);
    expect(game.overlays.isActive(KamoteGame.jailOverlay), isTrue);
    expect(game.overlays.isActive(KamoteGame.ambulanceOverlay), isFalse);
  });

  testWithGame<KamoteGame>('checkpoint chase counts as the first offense', _create, (game) async {
    await _prepare(game, removeCheckpoint: false);
    game.fuel.drainPerSecond = 0;
    await step(game, 4);
    expect(game.chase.active, isTrue);
    placeBarrierAhead(game);
    await step(game, 1);
    expect(game.state.endReason, EndReason.ticketAndJail);
  });

  testWithGame<KamoteGame>('head-on crash ends the run immediately with the ambulance', _create, (game) async {
    await _prepare(game);
    await cruise(game);
    game.steer(-1);
    game.steer(-1);
    await step(game, 0.6);
    expect(game.player.lane, 0);
    game.world.add(
      TrafficVehicle(
        type: VehicleType.car,
        lane: 0,
        oncoming: true,
        speedKmh: 50,
        color: const Color(0xFFFF0000),
        variant: 0,
      )..y = game.playerY - 200,
    );
    await step(game, 0.6);
    expect(game.state.endReason, EndReason.headOnCrash);
    expect(game.speedKmh, 0);
    // More crashes while the ending plays must not change anything.
    placeBarrierAhead(game);
    await step(game, 3);
    expect(game.state.phase, RunPhase.gameOver);
    expect(game.overlays.isActive(KamoteGame.ambulanceOverlay), isTrue);
    expect(game.overlays.isActive(KamoteGame.jailOverlay), isFalse);
    expect(services.profile.data.runsPlayed, 1, reason: 'banked exactly once');
    final wallet = services.profile.data.wallet;
    game.exitToMenu();
    expect(services.profile.data.runsPlayed, 1);
    expect(services.profile.data.wallet, wallet);
  });

  testWithGame<KamoteGame>('empty tank triggers the out-of-fuel ending', _create, (game) async {
    await _prepare(game);
    await step(game, 1);
    game.fuel.setFuel(0.01);
    await step(game, 0.2);
    expect(game.state.endReason, EndReason.outOfFuel);
    expect(game.fuel.fuel, 0);
    await step(game, 5);
    expect(game.state.phase, RunPhase.gameOver);
    expect(game.overlays.isActive(KamoteGame.fuelOverlay), isTrue);
  });

  testWithGame<KamoteGame>('pause freezes fuel, distance and the chase countdown', _create, (game) async {
    await _prepare(game);
    await cruise(game);
    game.fuel.drainPerSecond = GameConfig.baseFuelDrainPerSecond;
    placeBarrierAhead(game);
    await step(game, 1);
    expect(game.chase.active, isTrue);
    game.pauseRun();
    expect(game.overlays.isActive(KamoteGame.pauseOverlay), isTrue);
    final fuel = game.fuel.fuel;
    final chase = game.chase.remaining;
    final meters = game.distance.meters;
    await step(game, 3);
    expect(game.fuel.fuel, fuel);
    expect(game.chase.remaining, chase);
    expect(game.distance.meters, meters);
    game.resumeRun();
    await step(game, 1);
    expect(game.fuel.fuel, lessThan(fuel));
    expect(game.chase.remaining, lessThan(chase));
  });

  testWithGame<KamoteGame>('losing app focus pauses the run', _create, (game) async {
    await _prepare(game);
    game.lifecycleStateChange(AppLifecycleState.paused);
    expect(game.state.phase, RunPhase.paused);
    expect(game.overlays.isActive(KamoteGame.pauseOverlay), isTrue);
  });

  testWithGame<KamoteGame>('restart resets run data but keeps saved progress', _create, (game) async {
    await _prepare(game);
    await cruise(game);
    game.world.add(CashCollectible()..configure(lane: game.player.lane, y: game.playerY - 70, value: 100, phase: 0));
    await step(game, 1);
    expect(game.rewards.billCash, 100);
    game.pauseRun();
    game.restartRun();
    expect(game.state.phase, RunPhase.playing);
    expect(game.distance.meters, 0);
    expect(game.rewards.runEarnings, 0);
    expect(game.fuel.fraction, 1);
    expect(game.chase.active, isFalse);
    expect(services.profile.data.wallet, greaterThanOrEqualTo(100), reason: 'quit run was banked');
  });

  testWithGame<KamoteGame>('crossing a kilometer switches world and pays a milestone', _create, (game) async {
    await _prepare(game);
    game.fuel.drainPerSecond = 0;
    expect(game.hud.environmentName, Environments.all[0].name);
    var seconds = 0;
    while (game.distance.meters < 1005 && seconds < 120) {
      await step(game, 1);
      seconds++;
    }
    expect(game.distance.environmentIndex, 1);
    expect(game.hud.environmentName, Environments.all[1].name);
    expect(game.hud.banner?.title, contains('PROVINCIAL'));
    expect(game.rewards.milestoneCash, greaterThan(0));
    expect(game.state.phase, RunPhase.playing, reason: 'fuel, money and chase are preserved');
  });

  testWithGame<KamoteGame>('spawning stays bounded as entities leave the screen', _create, (game) async {
    await _prepare(game);
    game.spawner.enabled = true;
    game.fuel.drainPerSecond = 0;
    await step(game, 20);
    expect(game.distance.meters, greaterThan(300));
    // Bounded spawning: entities are culled once off-screen.
    expect(game.world.children.whereType<TrafficVehicle>().length, lessThanOrEqualTo(12));
    expect(game.world.children.length, lessThan(120));
  });

  testWithGame<KamoteGame>('spawned hazards always leave an open lane at the rider', _create, (game) async {
    await _prepare(game);
    game.spawner.enabled = true;
    game.fuel.drainPerSecond = 0;
    // Ghost rider: we only audit spawn fairness here, not crashes.
    game.player.startInvulnerability(1e9);
    var worst = 0;
    var oncomingSeen = 0;
    final vehiclesSeen = <TrafficVehicle>{};
    for (var frame = 0; frame < 90 * 60; frame++) {
      await game.ready();
      game.update(1 / 60);
      final row = Rect.fromLTRB(0, game.playerY - 30, 400, game.playerY + 30);
      final blocked = <int>{};
      for (final c in game.world.children) {
        if (c is TrafficVehicle && c.hitRect.overlaps(row)) blocked.add(c.lane);
        if (c is RoadObstacle && c.hitRect.overlaps(row)) blocked.add(c.lane);
        if (c is TrafficVehicle && vehiclesSeen.add(c) && c.oncoming) oncomingSeen++;
      }
      worst = math.max(worst, blocked.length);
    }
    expect(game.distance.meters, greaterThan(1800));
    expect(vehiclesSeen.length, greaterThan(20));
    expect(oncomingSeen, greaterThan(0));
    expect(worst, lessThanOrEqualTo(2), reason: 'at least two of four lanes stay open');
  });
}
