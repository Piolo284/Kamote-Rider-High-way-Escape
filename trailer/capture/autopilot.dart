import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import 'package:kamote_rider/game/components/cash_collectible.dart';
import 'package:kamote_rider/game/components/fuel_collectible.dart';
import 'package:kamote_rider/game/components/manhole.dart';
import 'package:kamote_rider/game/components/road_animal.dart';
import 'package:kamote_rider/game/components/road_obstacle.dart';
import 'package:kamote_rider/game/components/traffic_vehicle.dart';
import 'package:kamote_rider/game/game_config.dart';
import 'package:kamote_rider/game/kamote_game.dart';

/// Steers the rider like a decent player: away from traffic, toward cash
/// and fuel, and (when asked) into the manhole.
class Autopilot {
  /// Lane to aim for regardless of pickups (still dodges hazards).
  int? preferLane;

  /// Ride into open manholes instead of avoiding them.
  bool seekManhole = false;

  /// Avoid the oncoming lanes unless they are clearly safer.
  bool keepRight = false;

  double _cooldown = 0;

  static (double, double) _laneSpan(int lane) {
    final l = GameConfig.roadLeft + lane * GameConfig.laneWidth;
    return (l + 4, l + GameConfig.laneWidth - 4);
  }

  void step(KamoteGame game, double dt) {
    _cooldown -= dt;
    if (!game.state.acceptsGameplay || game.underground.transitioning) return;
    final p = game.player;
    if ((p.x - GameConfig.laneCenter(p.lane)).abs() > 6 || _cooldown > 0) return;

    final score = List<double>.filled(GameConfig.laneCount, 0);
    for (var lane = 0; lane < GameConfig.laneCount; lane++) {
      final (l0, l1) = _laneSpan(lane);
      var nearest = double.infinity;
      for (final c in game.world.children) {
        Rect? r;
        var reach = 330.0;
        if (c is TrafficVehicle) {
          r = c.hitRect;
          if (c.oncoming) reach = 620;
        } else if (c is RoadObstacle) {
          r = c.hitRect;
        } else if (c is RoadAnimal && c.isActive) {
          r = c.hitRect.inflate(14);
        }
        if (r == null || r.right < l0 || r.left > l1) continue;
        final ahead = p.y - 34 - r.bottom;
        if (r.top > p.y + 40 || ahead > reach) continue;
        nearest = math.min(nearest, math.max(0, ahead));
      }
      score[lane] = nearest.isInfinite ? 1000 : nearest;
      for (final c in game.world.children.whereType<PositionComponent>()) {
        final double gain;
        if (c is CashCollectible && !c.collected) {
          gain = 40;
        } else if (c is FuelCollectible && !c.collected) {
          gain = 160;
        } else if (c is OpenManhole && !c.used) {
          gain = seekManhole ? 900 : -500;
        } else {
          continue;
        }
        if ((c.x - GameConfig.laneCenter(lane)).abs() > 20) continue;
        final ahead = p.y - c.y;
        if (ahead > 20 && ahead < 420) score[lane] += gain;
      }
      if (keepRight && lane < GameConfig.oncomingLaneCount) score[lane] -= 120;
      if (preferLane == lane) score[lane] += 300;
      // Lanes further away take longer to reach.
      score[lane] -= (lane - p.lane).abs() * 25;
    }
    // Only consider lanes reachable without crossing a blocked one.
    var best = p.lane;
    for (final dir in [-1, 1]) {
      for (var lane = p.lane + dir; lane >= 0 && lane < GameConfig.laneCount; lane += dir) {
        if (score[lane] < 160 && score[lane] < score[p.lane]) break;
        if (score[lane] > score[best] + 30) best = lane;
      }
    }
    if (best != p.lane) {
      game.steer((best - p.lane).sign);
      _cooldown = 0.12;
    }
  }
}
