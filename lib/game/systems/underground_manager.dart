import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../services/audio_service.dart';
import '../components/manhole.dart';
import '../components/road_animal.dart';
import '../game_config.dart';
import '../kamote_game.dart';
import 'underground_system.dart';

/// Places one open manhole per world and, while the rider is in the
/// tunnel, sends pedestrians across the tracks at unpredictable moments.
class UndergroundManager extends Component with HasGameReference<KamoteGame> {
  UndergroundManager({math.Random? random}) : _rnd = random ?? math.Random(), planner = ManholePlanner(random: random);

  final math.Random _rnd;
  final ManholePlanner planner;

  /// Disabled by tests that place entities by hand.
  bool enabled = true;

  double _pedestrianIn = 0;

  void reset() {
    planner.reset();
    _pedestrianIn = 0;
  }

  /// Called when the rider lands in the tunnel.
  void onArrived() => _pedestrianIn = 1.2 + _rnd.nextDouble() * 1.2;

  @override
  void update(double dt) {
    if (!enabled || !game.spawner.enabled || !game.state.acceptsGameplay) return;
    final underground = game.underground;
    if (underground.phase == UndergroundPhase.inside) {
      _pedestrians(dt);
      return;
    }
    if (underground.active) return;
    final meters = game.distance.meters;
    final world = (meters / GameConfig.metersPerEnvironment).floor();
    if (!planner.due(world, meters)) return;
    if (_placeManhole()) {
      planner.markPlaced(world);
    } else {
      planner.retry();
    }
  }

  bool _placeManhole() {
    final spawner = game.spawner;
    final window = spawner.windowFor(GameConfig.spawnY, 24, game.scrollSpeed);
    if (window == null) return false;
    final lanes = List.generate(GameConfig.laneCount, (i) => i)..shuffle(_rnd);
    for (final lane in lanes) {
      if (!spawner.scheduler.isClear(lane, window.start, window.end)) continue;
      // Keep the lane free of hazards so the manhole can always be reached.
      spawner.scheduler.reserve(lane, window.start, window.end);
      game.world.add(OpenManhole(lane: lane)..y = GameConfig.spawnY);
      game.hud.toast('OPEN MANHOLE AHEAD! Ride in for a secret tunnel.', color: const Color(0xFFB388FF), seconds: 3);
      game.audio.play(Sfx.challenge, gain: 0.5);
      return true;
    }
    return false;
  }

  void _pedestrians(double dt) {
    _pedestrianIn -= dt;
    if (_pedestrianIn > 0) return;
    // Let the tracks clear briefly so the crossing can be planned fairly.
    game.spawner.holdHazardsFor(0.6);
    if (game.challenges.animals.trySpawn(AnimalKind.pedestrian)) {
      _pedestrianIn = 2.2 + _rnd.nextDouble() * 2.6;
    } else {
      _pedestrianIn = 0.3;
    }
  }
}
