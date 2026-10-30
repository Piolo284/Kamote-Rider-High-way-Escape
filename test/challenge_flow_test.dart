import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/game/components/cash_collectible.dart';
import 'package:kamote_rider/game/components/fuel_collectible.dart';
import 'package:kamote_rider/game/components/lto_officer.dart';
import 'package:kamote_rider/game/components/road_animal.dart';
import 'package:kamote_rider/game/components/road_obstacle.dart';
import 'package:kamote_rider/game/components/traffic_vehicle.dart';
import 'package:kamote_rider/game/difficulty_config.dart';
import 'package:kamote_rider/game/environments.dart';
import 'package:kamote_rider/game/game_config.dart';
import 'package:kamote_rider/game/game_state.dart';
import 'package:kamote_rider/game/kamote_game.dart';
import 'package:kamote_rider/game/systems/highway_challenge_manager.dart';
import 'package:kamote_rider/game/systems/meme_event_manager.dart';
import 'package:kamote_rider/services/app_services.dart';

import 'helpers.dart';

late AppServices services;

KamoteGame Function() _factory({DifficultyLevel level = DifficultyLevel.medium, int seed = 3}) => () {
  final game = KamoteGame(
    profile: services.profile,
    missions: services.missions,
    audio: services.audio,
    random: math.Random(seed),
    loadSprites: false,
    difficultyLevel: level,
  );
  for (final name in [KamoteGame.hudOverlay, KamoteGame.pauseOverlay, ...KamoteGame.endOverlays]) {
    game.overlays.addEntry(name, (_, _) => const SizedBox());
  }
  return game;
};

Future<void> step(KamoteGame game, double seconds) async {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    await game.ready();
    game.update(1 / 60);
  }
}

/// Clean road, no random spawns or challenges, rider at cruising speed.
Future<void> prepare(KamoteGame game) async {
  game.onGameResize(Vector2(400, 860));
  game.spawner.enabled = false;
  game.challenges.enabled = false;
  for (final c in game.world.children.whereType<LtoCheckpoint>().toList()) {
    c.removeFromParent();
  }
  game.fuel.drainPerSecond = 0;
  await step(game, 3);
}

/// Lanes blocked by hazards level with the rider right now.
Set<int> blockedLanes(KamoteGame game) {
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

void main() {
  setUp(() async => services = await makeServices());

  group('difficulty in a real run', () {
    for (final level in DifficultyLevel.values) {
      testWithGame<KamoteGame>('${level.name}: config is applied to the run', _factory(level: level), (game) async {
        await prepare(game);
        final config = DifficultyConfig.of(level);
        expect(game.difficulty.level, level);
        expect(game.hud.difficultyLabel, config.label);
        expect(game.rewards.bonusMultiplier, config.rewardMultiplier);
        expect(game.spawner.scheduler.padBefore, config.reactionPadding);
        final bike = services.profile.selectedBike;
        expect(game.speedKmh, closeTo(bike.topSpeedKmh * config.startSpeedMultiplier, 3));
        game.fuel.reset(drainMultiplier: bike.fuelDrainMultiplier * config.fuelDrainMultiplier);
        expect(
          game.fuel.drainPerSecond,
          closeTo(GameConfig.baseFuelDrainPerSecond * bike.fuelDrainMultiplier * config.fuelDrainMultiplier, 1e-9),
        );
      });
    }

    testWithGame<KamoteGame>(
      'easy burns less fuel than hard over the same ride',
      _factory(level: DifficultyLevel.easy),
      (game) async {
        game.onGameResize(Vector2(400, 860));
        game.spawner.enabled = false;
        game.challenges.enabled = false;
        await step(game, 5);
        final easyUsed = 100 - game.fuel.fuel;
        final hardRate = GameConfig.baseFuelDrainPerSecond * DifficultyConfig.hard.fuelDrainMultiplier;
        expect(easyUsed, lessThan(hardRate * 5 * services.profile.selectedBike.fuelDrainMultiplier));
      },
    );
  });

  group('challenges', () {
    for (final type in ChallengeType.values) {
      testWithGame<KamoteGame>('${type.name} starts on a clear road and is announced', _factory(), (game) async {
        await prepare(game);
        if (type == ChallengeType.fuelEmergency) game.fuel.setFuel(15);
        final before = game.world.children.length;
        expect(game.challenges.forceStart(type), isTrue);
        await step(game, 0.05);
        expect(game.world.children.length, greaterThan(before), reason: 'spawned something');
        expect(game.hud.announcement?.title, Challenges.of(type).title);
      });
    }

    testWithGame<KamoteGame>('clean challenge completion pays once', _factory(), (game) async {
      await prepare(game);
      // Ghost rider: hazards pass without contact, so every piece is cleared.
      game.player.startInvulnerability(1e9);
      game.player.steer(-1);
      game.player.steer(-1);
      expect(game.challenges.forceStart(ChallengeType.roadWorks), isTrue);
      await step(game, 6);
      expect(game.rewards.challengesCompleted, 1);
      final paid = game.rewards.challengeCash;
      expect(paid, Challenges.of(ChallengeType.roadWorks).reward);
      await step(game, 3);
      expect(game.rewards.challengeCash, paid, reason: 'no duplicate payout');
    });

    testWithGame<KamoteGame>('cash rush pays only when every bill is collected', _factory(seed: 5), (game) async {
      await prepare(game);
      expect(game.challenges.forceStart(ChallengeType.cashTrail), isTrue);
      // Autopilot: follow the trail.
      for (var i = 0; i < 6 * 60; i++) {
        final next = game.world.children
            .whereType<CashCollectible>()
            .where((b) => b.challengeId != 0 && !b.collected && b.y < game.player.y + 10)
            .fold<CashCollectible?>(null, (best, b) => best == null || b.y > best.y ? b : best);
        if (next != null && next.lane != game.player.lane) game.steer((next.lane - game.player.lane).sign);
        await game.ready();
        game.update(1 / 60);
      }
      expect(game.rewards.billsCollected, 12);
      expect(game.rewards.challengesCompleted, 1);
    });

    testWithGame<KamoteGame>('fuel emergency drops a reachable jerry can', _factory(), (game) async {
      await prepare(game);
      game.fuel.setFuel(15);
      game.challenges.enabled = true;
      game.distance.advance(300);
      await step(game, 0.1);
      final cans = game.world.children.whereType<FuelCollectible>().toList();
      expect(cans, hasLength(1));
      expect(cans.single.x, inInclusiveRange(GameConfig.roadLeft, GameConfig.roadRight));
    });

    testWithGame<KamoteGame>('surprise checkpoint waves through riders who keep right', _factory(), (game) async {
      await prepare(game);
      expect(game.challenges.forceStart(ChallengeType.ltoSurprise), isTrue);
      await step(game, 4);
      expect(game.chase.active, isFalse);
      expect(game.rewards.challengeCash, greaterThan(0));
    });

    testWithGame<KamoteGame>('surprise checkpoint chases counterflowing riders', _factory(), (game) async {
      await prepare(game);
      game.steer(-1);
      game.steer(-1);
      expect(game.challenges.forceStart(ChallengeType.ltoSurprise), isTrue);
      await step(game, 4);
      expect(game.chase.active, isTrue);
      expect(game.chase.remaining, lessThanOrEqualTo(GameConfig.chaseDuration));
    });

    testWithGame<KamoteGame>('sudden braking car lights up its brake lights', _factory(), (game) async {
      await prepare(game);
      game.player.startInvulnerability(1e9);
      expect(game.challenges.forceStart(ChallengeType.suddenBraking), isTrue);
      await step(game, 0.05);
      final car = game.world.children.whereType<TrafficVehicle>().single;
      double? brakeY;
      for (var i = 0; i < 8 * 60 && brakeY == null; i++) {
        await step(game, 1 / 60);
        if (car.braking) brakeY = car.y;
      }
      expect(brakeY, isNotNull);
      // Brakes near the top of the screen: over a second of warning.
      expect((game.playerY - brakeY!) / game.scrollSpeed, greaterThan(1.0));
    });

    testWithGame<KamoteGame>('falling cargo drops a box behind the truck', _factory(), (game) async {
      await prepare(game);
      game.player.startInvulnerability(1e9);
      expect(game.challenges.forceStart(ChallengeType.fallingCargo), isTrue);
      await step(game, 3);
      expect(game.world.children.whereType<RoadObstacle>().where((o) => o.type == ObstacleType.box), isNotEmpty);
    });
  });

  group('animals', () {
    testWithGame<KamoteGame>('animals start off the road and away from the rider', _factory(), (game) async {
      await prepare(game);
      expect(game.challenges.forceStart(ChallengeType.dogCrossing), isTrue);
      await step(game, 0.05);
      final dog = game.world.children.whereType<RoadAnimal>().single;
      expect(dog.isOnRoad, isFalse);
      expect(dog.y, lessThan(0), reason: 'spawns above the screen');
      expect((dog.y - game.player.y).abs(), greaterThan(300));
      expect(game.challenges.forceStart(ChallengeType.catCrossing), isFalse, reason: 'one animal event at a time');
    });

    testWithGame<KamoteGame>('dodging an animal pays once and triggers a dodge meme', _factory(), (game) async {
      await prepare(game);
      game.player.startInvulnerability(1e9);
      expect(game.challenges.forceStart(ChallengeType.dogCrossing), isTrue);
      await step(game, 6);
      expect(game.rewards.challengesCompleted, 1);
      expect(game.rewards.challengeCash, 30);
      expect(MemeEventManager.pools[MemeEvent.dogDodge], contains(game.hud.meme?.text));
    });

    testWithGame<KamoteGame>('hitting an animal is a minor stop: no chase, no reward', _factory(), (game) async {
      await prepare(game);
      final cat = RoadAnimal(
        kind: AnimalKind.cat,
        path: AnimalPath.cat(1, 0),
        startX: game.player.x,
        activateY: 1e9, // never starts moving: sits in the rider's lane
        variant: 0,
      )..y = game.playerY - 150;
      cat.challengeId = game.challengeRewards.begin(name: 'CAT DODGE', reward: 35, pieces: 1);
      game.world.add(cat);
      final speed = game.speedKmh;
      await step(game, 1);
      expect(game.chase.active, isFalse);
      expect(game.state.phase, RunPhase.playing);
      expect(game.speedKmh, lessThan(speed));
      await step(game, 2);
      expect(game.rewards.challengeCash, 0, reason: 'no reward for hitting animals');
    });

    testWithGame<KamoteGame>('animals freeze when paused and after game over', _factory(), (game) async {
      await prepare(game);
      game.player.startInvulnerability(1e9);
      expect(game.challenges.forceStart(ChallengeType.chickenCrossing), isTrue);
      await step(game, 1.5);
      final hens = game.world.children.whereType<RoadAnimal>().single;
      game.pauseRun();
      final paused = hens.position.clone();
      await step(game, 2);
      expect(hens.position, paused);
      game.resumeRun();
      await step(game, 0.3);
      expect(hens.position, isNot(paused));
      game.fuel.setFuel(0.01);
      game.fuel.drainPerSecond = 5;
      await step(game, 6);
      expect(game.state.phase, RunPhase.gameOver);
      final over = hens.position.clone();
      await step(game, 2);
      expect(hens.position, over);
    });
  });

  group('near misses and memes', () {
    testWithGame<KamoteGame>('a close pass is a near miss with a bonus and combo', _factory(), (game) async {
      await prepare(game);
      game.world.add(
        RoadObstacle(type: ObstacleType.cone, lane: game.player.lane)
          ..x = game.player.x + 26
          ..y = game.playerY - 160,
      );
      await step(game, 1.5);
      expect(game.combo.combo, 1);
      expect(game.rewards.skillBonusCash, greaterThan(0));
      expect(game.state.phase, RunPhase.playing);
    });

    testWithGame<KamoteGame>('a crash resets the combo', _factory(), (game) async {
      await prepare(game);
      game.combo.registerDodge();
      game.combo.registerDodge();
      game.world.add(RoadObstacle(type: ObstacleType.pothole, lane: game.player.lane)..y = game.playerY - 120);
      await step(game, 1);
      expect(game.combo.combo, 0);
    });

    testWithGame<KamoteGame>('meme pop-ups can be turned off', _factory(), (game) async {
      services.profile.settings.memePopups = MemePopupMode.off;
      await prepare(game);
      game.world.add(RoadObstacle(type: ObstacleType.pothole, lane: game.player.lane)..y = game.playerY - 120);
      await step(game, 1);
      expect(game.hud.meme, isNull);
    });

    testWithGame<KamoteGame>('reduced mode hides minor jokes but keeps major ones', _factory(), (game) async {
      services.profile.settings.memePopups = MemePopupMode.reduced;
      await prepare(game);
      game.world.add(RoadObstacle(type: ObstacleType.pothole, lane: game.player.lane)..y = game.playerY - 120);
      await step(game, 1.5);
      expect(game.hud.meme, isNull, reason: 'KAMOTE MOMENT is a minor joke');
      game.world.add(RoadObstacle(type: ObstacleType.barrier, lane: game.player.lane)..y = game.playerY - 120);
      await step(game, 1);
      expect(game.chase.active, isTrue);
      expect(MemeEventManager.pools[MemeEvent.chaseStart], contains(game.hud.meme?.text));
    });
  });

  group('fairness with challenges on', () {
    for (final level in DifficultyLevel.values) {
      testWithGame<KamoteGame>('${level.name}: never more than two lanes blocked', _factory(level: level, seed: 11), (
        game,
      ) async {
        game.onGameResize(Vector2(400, 860));
        game.fuel.drainPerSecond = 0;
        game.player.startInvulnerability(1e9);
        // Tunnel trips pause highway challenges; they have their own test.
        game.tunnels.enabled = false;
        var worst = 0;
        final animals = <RoadAnimal>{};
        for (var frame = 0; frame < 150 * 60; frame++) {
          await game.ready();
          game.update(1 / 60);
          worst = math.max(worst, blockedLanes(game).length);
          animals.addAll(game.world.children.whereType<RoadAnimal>());
        }
        // How many fit in 150 s swings with the random sequence (3–5 on Easy),
        // so this only checks that several really ran.
        expect(game.challenges.started.length, greaterThan(2), reason: 'challenges actually ran');
        expect(worst, lessThanOrEqualTo(2));
        // Cleanup: nothing accumulates.
        expect(game.world.children.length, lessThan(140));
        // ignore: avoid_print
        print(
          '${level.name}: ${game.distance.meters.round()} m, challenges ${game.challenges.started.map((t) => t.name).toList()}, animals ${animals.length}',
        );
      });
    }
  });
}
