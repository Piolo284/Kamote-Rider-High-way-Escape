import 'dart:math' as math;

import '../components/road_animal.dart';
import '../game_config.dart';
import '../kamote_game.dart';
import 'traffic_spawner.dart';

/// Plans and spawns dog, cat and chicken crossings.
///
/// Fairness rules:
/// * Animals start on the roadside above the screen and only begin
///   crossing once visible, so they never appear on or under the rider.
/// * The path is simulated ahead of time; the lanes the animal will occupy
///   when it reaches the rider's row are booked in the [LaneScheduler]
///   (never more than two), and every other lane must be clear then.
/// * Only one animal event at a time, and ordinary traffic rows pause until
///   the animal has passed.
class AnimalCrossingManager {
  AnimalCrossingManager(this.game, this._rnd);

  final KamoteGame game;
  final math.Random _rnd;

  static const Map<AnimalKind, String> names = {
    AnimalKind.dog: 'DOG DODGE',
    AnimalKind.cat: 'CAT DODGE',
    AnimalKind.chicken: 'CHICKEN DODGE',
    AnimalKind.pedestrian: 'PEDESTRIAN DODGE',
  };

  static const Map<AnimalKind, int> rewards = {
    AnimalKind.dog: 30,
    AnimalKind.cat: 35,
    AnimalKind.chicken: 30,
    AnimalKind.pedestrian: 25,
  };

  bool get animalActive => game.world.children.any((c) => c is RoadAnimal);

  /// Returns the lanes the animal's hitbox overlaps around the moment it
  /// reaches the rider's row, or null if the plan is not fair.
  static Set<int>? lanesAtRider({
    required AnimalPath path,
    required double startX,
    required double hitWidth,
    required double activateTime,
    required double rowStart,
    required double rowEnd,
  }) {
    final lanes = <int>{};
    for (var t = rowStart - 0.1; t <= rowEnd + 0.1; t += 0.04) {
      final x = t < activateTime ? startX : startX + path.offsetAt(t - activateTime);
      final left = x - hitWidth / 2;
      final right = x + hitWidth / 2;
      for (var lane = 0; lane < GameConfig.laneCount; lane++) {
        final l0 = GameConfig.roadLeft + lane * GameConfig.laneWidth;
        if (right > l0 && left < l0 + GameConfig.laneWidth) lanes.add(lane);
      }
    }
    return lanes.length > 2 ? null : lanes;
  }

  bool trySpawn(AnimalKind kind) {
    final spawner = game.spawner;
    final scroll = game.scrollSpeed;
    if (scroll < 80 || animalActive) return false;
    // The stretch of road ahead must be empty so the crossing reads clearly.
    if (spawner.roadHasHazardsAhead(above: 40)) return false;

    const y0 = GameConfig.spawnY;
    final activateY = game.hudTopInset + 30;
    final now = game.runTime;

    // Search directions, behaviours and start delays (in random order) for
    // a crossing that never covers more than two lanes at the rider.
    final options = [
      for (final dir in const [1, -1])
        for (var variant = 0; variant < 3; variant++)
          for (final delay in const [0.0, 0.35, 0.7, 1.0]) (dir, variant, delay),
    ]..shuffle(_rnd);
    for (final (dir, variant, delay) in options) {
      final base = AnimalPath.forKind(kind, dir, variant);
      final path = delay > 0 ? AnimalPath([PathStep(delay, 0, alert: true), ...base.steps]) : base;
      final startX = dir > 0 ? GameConfig.roadLeft - 24 : GameConfig.roadRight + 24;
      final probe = RoadAnimal(kind: kind, path: path, startX: startX, activateY: activateY, variant: variant);
      final hit = probe.hitSize;
      final activateTime = (activateY - y0) / scroll;
      final rowStart = (game.playerY - 32 - hit.y / 2 - y0) / scroll;
      final rowEnd = (game.playerY + 32 + hit.y / 2 - y0) / scroll;
      final lanes = lanesAtRider(
        path: path,
        startX: startX,
        hitWidth: hit.x,
        activateTime: activateTime,
        rowStart: rowStart,
        rowEnd: rowEnd,
      );
      if (lanes == null) continue;
      final window = LaneWindow(now + rowStart, now + rowEnd);
      if (!spawner.scheduler.allClear(window.start - 0.5, window.end + 0.5)) return false;
      for (final lane in lanes) {
        spawner.scheduler.block(lane, window.start, window.end);
      }
      _spawn(probe, kind, y0, rowEnd);
      return true;
    }
    return false;
  }

  void _spawn(RoadAnimal probe, AnimalKind kind, double y0, double rowEnd) {
    final spawner = game.spawner;
    probe
      ..y = y0
      ..challengeId = game.challengeRewards.begin(name: names[kind]!, reward: rewards[kind]!, pieces: 1);
    game.world.add(probe);
    spawner.holdHazardsFor(rowEnd + 0.4);
  }
}
