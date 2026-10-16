import 'dart:math' as math;

import 'package:flame/components.dart';

import '../environments.dart';
import '../game_config.dart';
import '../kamote_game.dart';
import 'scenery_prop.dart';

/// Spawns roadside scenery for the active environment and announces world
/// changes. The active environment always comes from the distance counter.
class EnvironmentManager extends Component with HasGameReference<KamoteGame> {
  EnvironmentManager({math.Random? random}) : _rnd = random ?? math.Random();

  final math.Random _rnd;
  static const int maxProps = 36;

  int _currentIndex = -1;
  double _leftCountdown = 0;
  double _rightCountdown = 0;
  double _flyoverCountdown = 0;
  int _liveProps = 0;
  int _generation = 0;

  EnvironmentTheme get theme => Environments.at(_currentIndex < 0 ? 0 : _currentIndex);

  void reset() {
    _currentIndex = -1;
    _leftCountdown = 0;
    _rightCountdown = 40;
    _flyoverCountdown = 500;
    _liveProps = 0;
    _generation++;
  }

  /// Pre-fills the screen with scenery so a run never starts on bare ground.
  void populate(double viewHeight) {
    _sync();
    for (var y = viewHeight; y > -40; y -= theme.propSpacing * 0.7) {
      _spawnProp(true, y + _rnd.nextDouble() * 30);
      _spawnProp(false, y - 30 + _rnd.nextDouble() * 30);
    }
  }

  @override
  void update(double dt) {
    _sync();
    final moved = game.scrollSpeed * dt;
    if (moved <= 0) return;
    _leftCountdown -= moved;
    _rightCountdown -= moved;
    _flyoverCountdown -= moved;
    if (_leftCountdown <= 0) {
      _spawnProp(true, GameConfig.spawnY + 40);
      _leftCountdown = theme.propSpacing * (0.6 + _rnd.nextDouble() * 0.8);
    }
    if (_rightCountdown <= 0) {
      _spawnProp(false, GameConfig.spawnY + 40);
      _rightCountdown = theme.propSpacing * (0.6 + _rnd.nextDouble() * 0.8);
    }
    if (_flyoverCountdown <= 0) {
      _flyoverCountdown = 900 + _rnd.nextDouble() * 900;
      if (_currentIndex == 0) _spawnFlyover();
    }
  }

  void _sync() {
    final index = game.distance.environmentIndex;
    if (index == _currentIndex) return;
    final first = _currentIndex < 0;
    _currentIndex = index;
    game.onEnvironmentChanged(index, announce: !first);
  }

  void _spawnProp(bool left, double y) {
    if (_liveProps >= maxProps) return;
    final options = left ? theme.leftProps : theme.rightProps;
    if (options.isEmpty) return;
    final type = options[_rnd.nextInt(options.length)];
    final prop = SceneryProp(type: type, onLeft: left, variant: _rnd.nextInt(8));
    const edgeGap = GameConfig.shoulderWidth + 4;
    final w = prop.size.x;
    final hugsRoad = type == PropType.streetlight || type == PropType.roadSign || type == PropType.warningSign;
    final double x;
    if (left) {
      final nearest = GameConfig.roadLeft - edgeGap - w / 2;
      x = hugsRoad ? nearest + 6 : nearest - _rnd.nextDouble() * 10;
    } else {
      final nearest = GameConfig.roadRight + edgeGap + w / 2;
      x = hugsRoad ? nearest - 6 : nearest + _rnd.nextDouble() * 10;
    }
    prop.position = Vector2(x, y);
    _track(prop);
    game.world.add(prop);
  }

  void _spawnFlyover() {
    final prop = SceneryProp(type: PropType.flyover, onLeft: false, variant: 0)
      ..position = Vector2(GameConfig.worldWidth / 2, GameConfig.spawnY);
    _track(prop);
    game.world.add(prop);
  }

  void _track(SceneryProp prop) {
    _liveProps++;
    final generation = _generation;
    prop.removed.then((_) {
      if (generation == _generation) _liveProps--;
    });
  }
}
