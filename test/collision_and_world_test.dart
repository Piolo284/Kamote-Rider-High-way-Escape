import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/game/environments.dart';
import 'package:kamote_rider/game/systems/collision_system.dart';
import 'package:kamote_rider/game/systems/distance_system.dart';
import 'package:kamote_rider/game/systems/traffic_spawner.dart';

void main() {
  group('impact classification', () {
    test('car coming straight down at the rider is frontal', () {
      final axis = classifyImpact(
        previousA: const Rect.fromLTWH(100, 500, 16, 44),
        currentA: const Rect.fromLTWH(100, 500, 16, 44),
        previousB: const Rect.fromLTWH(90, 420, 36, 70),
        currentB: const Rect.fromLTWH(90, 435, 36, 70),
      );
      expect(axis, ImpactAxis.frontal);
      expect(outcomeFor(kind: HazardKind.vehicle, oncoming: true, axis: axis), CollisionOutcome.headOn);
    });

    test('swerving into a car alongside is a side hit', () {
      final axis = classifyImpact(
        previousA: const Rect.fromLTWH(100, 500, 16, 44),
        currentA: const Rect.fromLTWH(108, 500, 16, 44),
        previousB: const Rect.fromLTWH(118, 480, 36, 70),
        currentB: const Rect.fromLTWH(118, 482, 36, 70),
      );
      expect(axis, ImpactAxis.side);
      expect(outcomeFor(kind: HazardKind.vehicle, oncoming: true, axis: axis), CollisionOutcome.sideCollision);
    });

    test('minor hazards never start a chase', () {
      expect(outcomeFor(kind: HazardKind.pothole, oncoming: false), CollisionOutcome.minor);
      expect(outcomeFor(kind: HazardKind.cone, oncoming: false), CollisionOutcome.minor);
      expect(outcomeFor(kind: HazardKind.barrier, oncoming: false), CollisionOutcome.sideCollision);
      expect(outcomeFor(kind: HazardKind.roadEdge, oncoming: false), CollisionOutcome.sideCollision);
    });

    test('same-frame collisions resolve to the highest priority', () {
      final c = CollisionSystem();
      c.report(const CollisionEvent(outcome: CollisionOutcome.minor, kind: HazardKind.cone, source: 1));
      c.report(const CollisionEvent(outcome: CollisionOutcome.headOn, kind: HazardKind.vehicle, source: 2));
      c.report(const CollisionEvent(outcome: CollisionOutcome.sideCollision, kind: HazardKind.barrier, source: 3));
      expect(c.resolve()!.outcome, CollisionOutcome.headOn);
      expect(c.resolve(), isNull, reason: 'buffer is cleared after resolving');
    });
  });

  group('world progression', () {
    test('environment changes every kilometer and repeats in order', () {
      expect(DistanceSystem.environmentFor(0), 0);
      expect(DistanceSystem.environmentFor(999), 0);
      expect(DistanceSystem.environmentFor(1000), 1);
      expect(DistanceSystem.environmentFor(4999), 4);
      expect(DistanceSystem.environmentFor(5000), 0);
      expect(DistanceSystem.environmentFor(7500), 2);
      expect(Environments.all.map((e) => e.name).toList(), [
        'City Highway',
        'Provincial Road',
        'Mountain Road',
        'Coastal Highway',
        'Urban Road',
      ]);
    });

    test('milestones fire once per kilometer', () {
      final d = DistanceSystem();
      final kms = <int>[];
      for (var i = 0; i < 2500; i++) {
        final km = d.advance(1.0);
        if (km != null) kms.add(km);
      }
      expect(kms, [1, 2]);
      expect(d.distinctEnvironmentsVisited, 3);
      expect(d.cycle, 0);
    });
  });

  group('LaneScheduler fairness', () {
    test('never lets more than two lanes be blocked at once', () {
      final rnd = math.Random(42);
      final s = LaneScheduler();
      for (var i = 0; i < 4000; i++) {
        final lane = rnd.nextInt(4);
        final start = rnd.nextDouble() * 200;
        final end = start + 0.1 + rnd.nextDouble() * 0.6;
        if (s.canBlock(lane, start, end)) s.block(lane, start, end);
      }
      for (var t = 0.0; t < 200; t += 0.01) {
        expect(s.blockedLanesAt(t), lessThanOrEqualTo(2), reason: 'at t=$t');
      }
    });

    test('reserved fuel lanes are not blocked afterwards', () {
      final s = LaneScheduler()..reserve(2, 10, 11);
      expect(s.canBlock(2, 10.2, 10.8), isFalse);
      expect(s.canBlock(3, 10.2, 10.8), isTrue);
    });
  });
}
