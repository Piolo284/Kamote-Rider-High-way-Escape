import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart' show Size, SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/app.dart';
import 'package:kamote_rider/game/components/lto_officer.dart';
import 'package:kamote_rider/game/components/manhole.dart';
import 'package:kamote_rider/game/components/pursuit_officer.dart';
import 'package:kamote_rider/game/components/road_obstacle.dart';
import 'package:kamote_rider/game/components/traffic_vehicle.dart';
import 'package:kamote_rider/game/environments.dart';
import 'package:kamote_rider/game/game_config.dart';
import 'package:kamote_rider/game/game_state.dart';
import 'package:kamote_rider/game/kamote_game.dart';
import 'package:kamote_rider/game/painting/vehicle_painter.dart';
import 'package:kamote_rider/game/render3d/camera3d.dart';
import 'package:kamote_rider/game/systems/pursuit_system.dart';
import 'package:kamote_rider/game/systems/reward_system.dart';
import 'package:kamote_rider/game/systems/shop_system.dart';
import 'package:kamote_rider/game/systems/curve_system.dart';
import 'package:kamote_rider/game/systems/underground_system.dart';
import 'package:kamote_rider/game/systems/violation_system.dart';
import 'package:kamote_rider/models/leaderboard_model.dart';
import 'package:kamote_rider/models/motorcycle_model.dart';
import 'package:kamote_rider/models/player_save_model.dart';
import 'package:kamote_rider/models/upgrade_model.dart';
import 'package:kamote_rider/services/app_services.dart';
import 'package:kamote_rider/services/garage_service.dart';

import 'helpers.dart';

late AppServices services;

KamoteGame _create() {
  final game = KamoteGame(
    profile: services.profile,
    missions: services.missions,
    audio: services.audio,
    random: math.Random(5),
    loadSprites: false,
  );
  for (final name in [
    KamoteGame.hudOverlay,
    KamoteGame.pauseOverlay,
    KamoteGame.shopOverlay,
    ...KamoteGame.endOverlays,
  ]) {
    game.overlays.addEntry(name, (_, _) => const SizedBox());
  }
  return game;
}

/// Portrait viewport, no random traffic or challenges, no checkpoint chase.
Future<void> _prepare(KamoteGame game) async {
  game.onGameResize(Vector2(400, 800));
  game.spawner.enabled = false;
  game.challenges.enabled = false;
  for (final c in game.world.children.whereType<LtoCheckpoint>().toList()) {
    c.removeFromParent();
  }
  game.fuel.drainPerSecond = 0;
  await _step(game, 0.1);
}

/// Renders every [renderEvery]th frame when [render] is set.
Future<void> _step(KamoteGame game, double seconds, {bool render = false, int renderEvery = 1}) async {
  final frames = (seconds * 60).round();
  for (var i = 0; i < frames; i++) {
    await game.ready();
    game.update(1 / 60);
    _frame++;
    if (render && _frame % renderEvery == 0) game.render(Canvas(PictureRecorder()));
  }
}

int _frame = 0;

void _barrierAhead(KamoteGame game) =>
    game.world.add(RoadObstacle(type: ObstacleType.barrier, lane: game.player.lane)..y = game.playerY - 90);

void main() {
  setUp(() async => services = await makeServices());

  // ------------------------------------------------------------ economy

  group('run money', () {
    test('spending and penalties never take more than the rider has', () {
      final r = RewardSystem()..reset();
      r.addBill(100);
      expect(r.spend(60), isTrue);
      expect(r.runEarnings, 40);
      expect(r.spend(50), isFalse, reason: 'not enough money');
      expect(r.runEarnings, 40, reason: 'nothing charged on a refused purchase');
      expect(r.penalize(100), 40, reason: 'only what is left is taken');
      expect(r.runEarnings, 0);
      expect(r.penalize(100), 0);
      expect(r.runEarnings, 0, reason: 'never negative');
      final result = r.finalize(distanceMeters: 500)!;
      expect(result.grossEarnings, 100);
      expect(result.spentCash, 60);
      expect(result.penaltyCash, 40);
      expect(result.totalEarnings, 0);
      expect(result.score, 500 + 100 - 40, reason: 'shop spending does not lower the score; penalties do');
    });

    test('violations count each one and carry a configurable penalty', () {
      final v = ViolationSystem();
      expect(v.record(Violation.collision), ViolationSystem.defaultPenalty);
      v.record(Violation.leftRoad);
      expect(v.count, 2);
      expect(v.countOf(Violation.collision), 1);
      expect(ViolationSystem(penaltyPerViolation: 250).record(Violation.hitOfficer), 250);
    });
  });

  // ------------------------------------------------------------ shop

  group('shop catalog and boosters', () {
    test('offers the three refills and three boosters from the design', () {
      expect(ShopCatalog.fuel.map((i) => i.fuelFraction), [0.25, 0.5, 1.0]);
      expect(ShopCatalog.boosters.map((i) => i.boostSeconds), [5, 10, 15]);
      for (final list in [ShopCatalog.fuel, ShopCatalog.boosters]) {
        expect(list[0].price, lessThan(list[1].price));
        expect(list[1].price, lessThan(list[2].price));
      }
    });

    test('a boost runs for its duration, then cools down', () {
      final b = BoostSystem();
      expect(b.start(5), isTrue);
      expect(b.start(5), isFalse, reason: 'already running');
      var ended = 0;
      for (var i = 0; i < 60 * 6; i++) {
        if (b.update(1 / 60)) ended++;
      }
      expect(ended, 1);
      expect(b.active, isFalse);
      expect(b.coolingDown, isTrue);
      expect(b.start(5), isFalse, reason: 'cooldown prevents back-to-back boosts');
      for (var i = 0; i < 60 * BoostSystem.cooldownSeconds; i++) {
        b.update(1 / 60);
      }
      expect(b.start(10), isTrue);
    });
  });

  testWithGame<KamoteGame>('buying gasoline pauses safely, deducts cash and never overfills', _create, (game) async {
    await _prepare(game);
    game.rewards.addBill(500);
    game.fuel.setFuel(40);
    game.openShop();
    expect(game.state.isPaused, isTrue, reason: 'the run is paused while shopping');
    expect(game.overlays.isActive(KamoteGame.shopOverlay), isTrue);

    expect(game.buy(ShopCatalog.mediumRefill), ShopResult.success);
    expect(game.rewards.runEarnings, 500 - ShopCatalog.mediumRefill.price);
    expect(game.fuel.fraction, closeTo(0.9, 0.001));

    expect(game.buy(ShopCatalog.largeRefill), ShopResult.success);
    expect(game.fuel.fraction, 1.0, reason: 'never above the tank capacity');
    expect(game.buy(ShopCatalog.smallRefill), ShopResult.tankFull);

    game.fuel.setFuel(10);
    final cash = game.rewards.runEarnings;
    game.rewards.spend(cash); // empty pockets
    expect(game.buy(ShopCatalog.smallRefill), ShopResult.insufficientFunds);
    expect(game.fuel.fuel, 10, reason: 'nothing happens without enough money');

    game.closeShop();
    expect(game.state.isPlaying, isTrue);
    expect(game.overlays.isActive(KamoteGame.shopOverlay), isFalse);
  });

  testWithGame<KamoteGame>('a booster speeds the bike up, expires, and never protects from crashes', _create, (
    game,
  ) async {
    await _prepare(game);
    await _step(game, 3);
    final cruising = game.speedKmh;
    game.rewards.addBill(500);
    expect(game.buy(ShopCatalog.shortBooster), ShopResult.success);
    expect(game.buy(ShopCatalog.mediumBooster), ShopResult.boostActive);
    await _step(game, 1.5);
    expect(game.speedKmh, greaterThan(cruising * 1.15));
    expect(game.hud.boostActive, isTrue);

    _barrierAhead(game);
    await _step(game, 1);
    expect(game.chase.active, isTrue, reason: 'boosting gives no immunity: the crash counts');
    expect(game.violations.count, 1);

    await _step(game, 4);
    expect(game.boost.active, isFalse, reason: 'the 5 s booster has run out');
    expect(game.buy(ShopCatalog.shortBooster), ShopResult.boostCoolingDown);
  });

  // ------------------------------------------------------------ violations

  testWithGame<KamoteGame>('a violation deducts the penalty once, with a reason', _create, (game) async {
    await _prepare(game);
    await _step(game, 3);
    game.rewards.addBill(250);
    final before = game.rewards.runEarnings;
    _barrierAhead(game);
    await _step(game, 2);
    expect(game.violations.count, 1);
    expect(game.violations.countOf(Violation.ignoredRoadClosure), 1);
    expect(game.rewards.runEarnings, before - ViolationSystem.defaultPenalty);
    expect(game.hud.toasts.any((t) => t.text.contains('TRAFFIC VIOLATION!')), isTrue);
    // Riding on: the same barrier is never charged twice.
    await _step(game, 2);
    expect(game.violations.count, 1);
    expect(game.rewards.runEarnings, before - ViolationSystem.defaultPenalty);
  });

  testWithGame<KamoteGame>('a penalty larger than the cash takes only what is there', _create, (game) async {
    await _prepare(game);
    await _step(game, 3);
    game.rewards.spend(game.rewards.runEarnings);
    game.rewards.addBill(50);
    _barrierAhead(game);
    await _step(game, 2);
    expect(game.rewards.runEarnings, 0);
    expect(game.rewards.penaltyCash, 50);
  });

  testWithGame<KamoteGame>('head-on still ends the run at once and counts as a violation', _create, (game) async {
    await _prepare(game);
    await _step(game, 3);
    game.steer(-1);
    game.steer(-1);
    await _step(game, 0.6);
    game.world.add(
      TrafficVehicle(
        type: VehicleType.car,
        lane: game.player.lane,
        oncoming: true,
        speedKmh: 50,
        color: const Color(0xFFFF0000),
        variant: 0,
      )..y = game.playerY - 200,
    );
    await _step(game, 0.6);
    expect(game.state.endReason, EndReason.headOnCrash);
    expect(game.violations.count, 1);
  });

  testWithGame<KamoteGame>('collisions count the same in the underground tunnel', _create, (game) async {
    await _prepare(game);
    await _step(game, 3);
    game.world.add(OpenManhole(lane: game.player.lane)..y = game.playerY - 120);
    var guard = 0;
    while (!game.underground.showsTunnel && guard++ < 600) {
      await _step(game, 1 / 60);
    }
    expect(game.underground.phase, UndergroundPhase.inside);
    await _step(game, 2); // past the arrival grace period
    game.world.add(
      TrafficVehicle(
        type: VehicleType.lrt,
        lane: game.player.lane,
        oncoming: false,
        speedKmh: 5,
        color: VehiclePainter.defaultColor(VehicleType.lrt, 0),
        variant: 0,
      )..y = game.playerY - 160,
    );
    await _step(game, 2);
    expect(game.chase.active, isTrue);
    expect(game.violations.count, 1);
  });

  // ------------------------------------------------------------ LTO pursuit

  group('PursuitSystem', () {
    test('one more officer every 5 km', () {
      expect(PursuitSystem.levelAt(4999), 0);
      expect(PursuitSystem.levelAt(5000), 1);
      expect(PursuitSystem.levelAt(14999), 2);
      expect(PursuitSystem.levelAt(29999), 5);
      expect(PursuitSystem.levelAt(35000), 7);
      final p = PursuitSystem(random: math.Random(1));
      expect(p.updateDistance(4000), isNull);
      expect(p.updateDistance(5001), 1);
      expect(p.updateDistance(6000), isNull, reason: 'announced once per milestone');
      expect(p.updateDistance(10000), 2);
      expect(p.maxLevel, 2);
    });

    test('milestone messages', () {
      expect(PursuitSystem.milestoneMessage(1), '5 KM REACHED! AN LTO OFFICER IS AFTER YOU!');
      expect(PursuitSystem.milestoneMessage(2), '10 KM REACHED! TWO LTO OFFICERS ARE NOW PURSUING YOU!');
      expect(PursuitSystem.milestoneMessage(3), '15 KM REACHED! THE CHASE IS GETTING SERIOUS!');
      expect(PursuitSystem.milestoneMessage(4), '20 KM REACHED! THERE IS NO ESCAPE NOW!');
      expect(PursuitSystem.milestoneMessage(6), '30 KM REACHED! 6 LTO OFFICERS ON YOUR TAIL!');
    });

    test('more officers move in more often', () {
      final p = PursuitSystem(random: math.Random(2))..updateDistance(5000);
      final one = p.interval();
      p.updateDistance(25000);
      expect(p.interval(), lessThan(one + 3));
      expect(p.interval(), greaterThanOrEqualTo(4));
    });
  });

  testWithGame<KamoteGame>('at 5 km an officer blocks a lane beside the rider, fairly', _create, (game) async {
    await _prepare(game);
    await _step(game, 2);
    game.distance.advance(PursuitSystem.metersPerLevel - 5);
    await _step(game, 1);
    expect(game.pursuit.level, 1);
    expect(game.hud.banner?.title, PursuitSystem.milestoneMessage(1));
    PursuitOfficer? officer;
    for (var i = 0; i < 60 * 8 && officer == null; i++) {
      await _step(game, 1 / 60);
      officer = game.world.children.whereType<PursuitOfficer>().firstOrNull;
    }
    expect(officer, isNotNull, reason: 'an officer moves in soon after the milestone');
    expect(officer!.lane, isNot(game.player.lane), reason: 'never in the rider\'s own lane');
    final s = game.spawner.scheduler;
    for (var t = game.runTime; t < game.runTime + 4; t += 0.1) {
      expect(s.blockedLanesAt(t), lessThanOrEqualTo(s.maxBlocked), reason: 'an escape lane always stays open');
    }

    // Wait until the officer is level with the rider, then ram them.
    while (officer.phase == PursuitPhase.approaching) {
      await _step(game, 1 / 60);
    }
    game.steer((officer.lane - game.player.lane).sign);
    await _step(game, 1);
    expect(game.violations.countOf(Violation.hitOfficer), 1);
    expect(game.chase.active, isTrue, reason: 'ramming an officer starts a chase like any side crash');
  });

  // ------------------------------------------------------------ upgrades

  group('upgrades', () {
    test('each level improves the bike, and costs rise with level and tier', () {
      final bike = MotorcycleCatalog.byId('kamote_110');
      final stock = BikeStats.of(bike);
      final levels = UpgradeLevels();
      for (var i = 0; i < 4; i++) {
        levels
          ..raise(UpgradeStat.maxSpeed)
          ..raise(UpgradeStat.acceleration)
          ..raise(UpgradeStat.handling)
          ..raise(UpgradeStat.fuelEfficiency)
          ..raise(UpgradeStat.fuelCapacity);
      }
      expect(levels.raise(UpgradeStat.maxSpeed), isFalse, reason: 'level 5 is the maximum');
      final maxed = BikeStats.of(bike, levels);
      expect(maxed.topSpeedKmh, greaterThan(stock.topSpeedKmh));
      expect(maxed.accelerationKmhPerSec, greaterThan(stock.accelerationKmhPerSec));
      expect(maxed.laneChangeSeconds, lessThan(stock.laneChangeSeconds));
      expect(maxed.fuelDrainMultiplier, lessThan(stock.fuelDrainMultiplier));
      expect(maxed.fuelCapacity, greaterThan(stock.fuelCapacity));

      final costs = [for (var l = 1; l < 5; l++) UpgradeCatalog.costFor(bike, l)!];
      for (var i = 1; i < costs.length; i++) {
        expect(costs[i], greaterThan(costs[i - 1]));
      }
      expect(UpgradeCatalog.costFor(bike, 5), isNull);
      expect(
        UpgradeCatalog.costFor(MotorcycleCatalog.byId('kamote_xtreme'), 1),
        greaterThan(UpgradeCatalog.costFor(bike, 1)!),
      );
    });

    test('garage upgrades charge once, per bike, and survive a restart', () async {
      final s = await makeServices();
      s.profile.data.wallet = 1000;
      final garage = s.garage;
      expect(garage.upgrade('barangay_125', UpgradeStat.maxSpeed), UpgradeResult.locked);
      final cost = garage.upgradeCost('kamote_110', UpgradeStat.maxSpeed)!;
      expect(garage.upgrade('kamote_110', UpgradeStat.maxSpeed), UpgradeResult.success);
      expect(s.profile.data.wallet, 1000 - cost);
      expect(garage.upgradesOf('kamote_110')[UpgradeStat.maxSpeed], 2);
      expect(garage.upgradesOf('barangay_125')[UpgradeStat.maxSpeed], 1, reason: 'each bike keeps its own levels');
      s.profile.data.wallet = 0;
      expect(garage.upgrade('kamote_110', UpgradeStat.maxSpeed), UpgradeResult.insufficientFunds);
      expect(garage.upgradesOf('kamote_110')[UpgradeStat.maxSpeed], 2);

      await Future<void>.delayed(Duration.zero);
      final reloaded = await reloadProfile();
      expect(reloaded.data.upgradesOf('kamote_110')[UpgradeStat.maxSpeed], 2);
      expect(reloaded.selectedStats.topSpeedKmh, greaterThan(BikeStats.of(reloaded.selectedBike).topSpeedKmh));
    });

    test('broken or unknown upgrade data loads safely', () {
      final m = PlayerSaveModel.fromJson({
        'upg': {
          'kamote_110': {'maxSpeed': 99, 'handling': 'x'},
          'no_such_bike': {'maxSpeed': 3},
        },
      });
      expect(m.upgradesOf('kamote_110')[UpgradeStat.maxSpeed], UpgradeLevels.maxLevel);
      expect(m.upgradesOf('kamote_110')[UpgradeStat.handling], 1);
      expect(m.upgrades.containsKey('no_such_bike'), isFalse);
    });
  });

  testWithGame<KamoteGame>('upgrades change the bike the run actually uses', _create, (game) async {
    final levels = services.profile.data.upgradesOf('kamote_110');
    for (var i = 0; i < 4; i++) {
      levels
        ..raise(UpgradeStat.maxSpeed)
        ..raise(UpgradeStat.fuelCapacity);
    }
    game.restartRun();
    await _prepare(game);
    final stock = BikeStats.of(MotorcycleCatalog.byId('kamote_110'));
    expect(game.stats.topSpeedKmh, greaterThan(stock.topSpeedKmh));
    expect(game.fuel.capacity, greaterThan(GameConfig.maxFuel));
    expect(game.player.stats.topSpeedKmh, game.stats.topSpeedKmh);
    await _step(game, 4);
    expect(game.speedKmh, greaterThan(stock.topSpeedKmh * game.difficulty.startSpeedMultiplier));
  });

  testWithGame<KamoteGame>('the LTO pursuit renders without errors', _create, (game) async {
    await _prepare(game);
    game.distance.advance(2 * PursuitSystem.metersPerLevel);
    for (var i = 0; i < 60 * 10 && game.world.children.whereType<PursuitOfficer>().isEmpty; i++) {
      await _step(game, 1 / 60);
    }
    expect(game.world.children.whereType<PursuitOfficer>(), isNotEmpty);
    await _step(game, 3, render: true);
  });

  // ------------------------------------------------------------ traffic

  testWithGame<KamoteGame>('the left (oncoming) lanes get extra traffic, and an escape lane stays open', _create, (
    game,
  ) async {
    await _prepare(game);
    game.spawner.enabled = true;
    game.tunnels.enabled = false;
    game.player.startInvulnerability(1e9);
    final seen = <TrafficVehicle>{};
    var worst = 0;
    for (var frame = 0; frame < 120 * 60; frame++) {
      await game.ready();
      game.update(1 / 60);
      seen.addAll(game.world.children.whereType<TrafficVehicle>());
      worst = math.max(worst, game.spawner.scheduler.blockedLanesAt(game.runTime));
    }
    final left = seen.where((v) => v.lane < GameConfig.oncomingLaneCount).length;
    final right = seen.length - left;
    // Before the extra oncoming spawn this run had about 16 left vs 59 right.
    expect(left, greaterThan(right ~/ 2), reason: 'the left lanes are much busier than before');
    expect(left, greaterThan(20));
    expect(right, greaterThan(20), reason: 'the right lanes keep their traffic');
    expect(worst, lessThanOrEqualTo(2));
  });

  // ------------------------------------------------------------ high score

  testWithGame<KamoteGame>('the HUD shows the score to beat and announces a new high score once', _create, (
    game,
  ) async {
    services.profile.data.leaderboard.add(
      LeaderboardEntry(
        playerName: 'Ben',
        score: 300,
        distanceMeters: 200,
        earnings: 100,
        difficultyLabel: 'MEDIUM',
        bikeName: 'Kamote 110',
        timestamp: DateTime(2026, 10, 1),
      ),
    );
    game.restartRun();
    await _prepare(game);
    await _step(game, 1);
    expect(game.highScore, 300);
    expect(game.hud.highScore, 300);
    expect(game.hud.score, game.liveScore);
    expect(game.hud.score, lessThan(300));
    bool announced() => game.hud.toasts.any((t) => t.text.startsWith('NEW HIGH SCORE'));
    expect(announced(), isFalse);

    game.rewards.addBill(500);
    await _step(game, 0.1);
    expect(game.hud.score, greaterThan(300));
    expect(announced(), isTrue);
    game.hud.toasts.clear();
    game.rewards.addBill(100);
    await _step(game, 0.5);
    expect(announced(), isFalse, reason: 'announced once per run');
    expect(game.hud.highScore, 300, reason: 'the target stays the record set before this run');
  });

  // ------------------------------------------------------------ curves

  group('curves', () {
    test('straight for the first kilometer, then gradual and smooth', () {
      final c = CurveSystem(random: math.Random(4));
      var meters = 0.0;
      var maxSeen = 0.0;
      while (meters < 1000) {
        c.update(meters, 1);
        meters += 1;
        expect(c.curvature, 0);
      }
      var previous = c.curvature;
      while (meters < 4000) {
        c.update(meters, 1);
        meters += 1;
        expect((c.curvature - previous).abs(), lessThanOrEqualTo(CurveSystem.changePerMeter + 1e-9));
        previous = c.curvature;
        maxSeen = math.max(maxSeen, c.curvature.abs());
      }
      expect(maxSeen, greaterThan(0), reason: 'bends appear after 1 km');
      expect(maxSeen, lessThanOrEqualTo(CurveSystem.profileAt(4000).maxIntensity));
      expect(CurveSystem.profileAt(12000).maxIntensity, greaterThan(CurveSystem.profileAt(2000).maxIntensity));
      expect(CurveSystem.profileAt(16000).straightChance, lessThan(CurveSystem.profileAt(6000).straightChance));
    });

    test("the bend never moves the rider's own row", () {
      final cam = Camera3D()
        ..setup(screenWidth: 400, screenHeight: 800, playerY: 600, focusX: 200)
        ..curve = Camera3D.maxCurve;
      expect(cam.bendX(600), 0);
      expect(cam.bendX(700), 0, reason: 'behind the rider is straight');
      expect(cam.bendX(-600), greaterThan(0));
      final straight = Camera3D()..setup(screenWidth: 400, screenHeight: 800, playerY: 600, focusX: 200);
      expect(cam.project(200, 600), straight.project(200, 600));
    });
  });

  testWithGame<KamoteGame>('a curved road renders without errors', _create, (game) async {
    await _prepare(game);
    game.spawner.enabled = true;
    // Nobody steers here, so keep the run alive through the traffic.
    game.player.startInvulnerability(1e9);
    game.distance.advance(2500);
    for (var i = 0; i < 400 && game.curves.curvature.abs() < 0.1; i++) {
      await _step(game, 0.5);
    }
    expect(game.curves.curvature.abs(), greaterThan(0));
    await _step(game, 2, render: true);
  });

  // ------------------------------------------------------------ app flow

  group('in the app', () {
    Future<AppServices> pumpApp(WidgetTester tester, {int wallet = 0}) async {
      tester.view.physicalSize = const Size(393, 851) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final s = await makeServices();
      s.profile.data.wallet = wallet;
      await tester.pumpWidget(KamoteApp(services: s));
      await tester.pump(const Duration(milliseconds: 100));
      return s;
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('the HUD shows the score and opens the shop', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('PLAY'));
      await settle(tester);
      await tester.tap(find.text('START RIDE'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('HIGH: set the first record!'), findsOneWidget);
      expect(find.textContaining('SCORE '), findsOneWidget);
      expect(find.text('0 VIOLATIONS'), findsOneWidget);
      await tester.tap(find.byTooltip('Shop'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('ROADSIDE SHOP'), findsOneWidget);
      expect(find.text('Small Refill'), findsOneWidget);
      expect(find.text('Long Booster'), findsOneWidget);
      await tester.tap(find.text('BACK TO THE ROAD'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('ROADSIDE SHOP'), findsNothing);
    });

    testWidgets('the garage upgrades the selected bike', (tester) async {
      final s = await pumpApp(tester, wallet: 5000);
      await tester.tap(find.text('GARAGE'));
      await settle(tester);
      await tester.tap(find.text('UPGRADE').first);
      await settle(tester);
      expect(find.text('Max Speed'), findsOneWidget);
      final cost = s.garage.upgradeCost('kamote_110', UpgradeStat.maxSpeed)!;
      await tester.tap(find.text('₱$cost').first);
      await settle(tester);
      expect(s.garage.upgradesOf('kamote_110')[UpgradeStat.maxSpeed], 2);
      expect(s.profile.data.wallet, 5000 - cost);
      await tester.tap(find.text('BACK'));
      await settle(tester);
      expect(find.text('UPG 1/20'), findsWidgets);
    });
  });
}
