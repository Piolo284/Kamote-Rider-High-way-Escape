import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flame/components.dart';

import '../components/cash_collectible.dart';
import '../components/effects.dart';
import '../components/fuel_collectible.dart';
import '../components/lto_officer.dart';
import '../components/player_motorcycle.dart';
import '../components/road_animal.dart';
import '../components/road_obstacle.dart';
import '../components/scenery_prop.dart';
import '../components/traffic_vehicle.dart';
import '../environments.dart';
import '../game_config.dart';
import '../kamote_game.dart';
import 'camera3d.dart';
import 'prop_view.dart';
import 'rider_view.dart';
import 'shapes.dart';
import 'sky.dart';
import 'small_views.dart';
import 'vehicle_view.dart';

/// Draws the whole game from the chase camera behind the rider.
///
/// Gameplay is unchanged: every component still lives on the flat world and
/// collides there. This class only decides how that world looks.
class SceneRenderer {
  SceneRenderer(this.game);

  final KamoteGame game;
  final Camera3D cam = Camera3D();
  final SkyPainter _sky = SkyPainter();
  final List<Drawable3D> _drawables = [];
  final List<PositionComponent> _effects = [];

  static final Paint _p = Paint()..isAntiAlias = true;
  static final Path _path = Path();

  double _time = 0;
  int _env = -1;
  int _previousEnv = 0;
  double _blend = 1;

  /// Top-down view zoom, used to keep screen-space layers the same size.
  double get _uiZoom => math.min(game.size.x / GameConfig.worldWidth, game.size.y / GameConfig.minVisibleHeight);

  void update(double dt) {
    _time += dt;
    final env = game.distance.environmentIndex % Environments.all.length;
    if (_env < 0) {
      _env = env;
    } else if (env != _env) {
      _previousEnv = _env;
      _env = env;
      _blend = 0;
    }
    if (_blend < 1) _blend = math.min(1, _blend + dt / 2.5);
  }

  void render(Canvas canvas) {
    final size = game.size;
    if (size.x <= 0 || size.y <= 0) return;
    final zoom = _uiZoom;
    final view = game.camera.viewfinder.position;
    cam.setup(
      screenWidth: size.x,
      screenHeight: size.y,
      playerY: game.playerY,
      focusX: game.player.isMounted ? game.player.x : GameConfig.worldWidth / 2,
      shake: Offset((view.x - GameConfig.worldWidth / 2) * zoom, view.y * zoom),
    );
    final env = _env < 0 ? 0 : _env;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.x, size.y));

    if (_blend < 1) _sky.paint(canvas, cam, _previousEnv, _time);
    _sky.paint(canvas, cam, env, _time, alpha: _blend);
    _groundBase(canvas, Environments.at(env));
    _road(canvas);
    _horizonHaze(canvas, env);
    _guardrails(canvas);

    _collect();
    _drawables.sort((a, b) => a.sortY.compareTo(b.sortY));
    for (final d in _drawables) {
      d.draw(canvas);
    }
    _drawables.clear();

    for (final e in _effects) {
      switch (e) {
        case FloatingText():
          SmallViews.drawFloatingText(canvas, cam, e);
        case ImpactBurst():
          SmallViews.drawBurst(canvas, cam, e.x, e.y, 22, e.render);
        case PickupSparkle():
          SmallViews.drawBurst(canvas, cam, e.x, e.y, 14, e.render);
        case OncomingWarning():
          SmallViews.drawOncomingWarning(canvas, cam, e);
      }
    }
    _effects.clear();

    // Weather and speed streaks stay flat on the screen, as before.
    canvas.save();
    canvas.translate(size.x / 2, 0);
    canvas.scale(zoom);
    canvas.translate(-GameConfig.worldWidth / 2, 0);
    game.atmosphere.render(canvas);
    game.speedLines.render(canvas);
    canvas.restore();

    canvas.restore();
  }

  // ------------------------------------------------------------ ground

  /// Point where the road line at world [x] leaves the bottom of the screen.
  Offset _edgeAtBottom(double x) {
    final vp = Offset(cam.cx, cam.horizonY);
    final p = cam.project(x, cam.playerY);
    final t = (cam.height - vp.dy) / (p.dy - vp.dy);
    return vp + (p - vp) * t;
  }

  void _poly(Canvas c, List<Offset> points, Color color) {
    _path.reset();
    _path.moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      _path.lineTo(p.dx, p.dy);
    }
    _path.close();
    _p.color = color;
    c.drawPath(_path, _p);
  }

  /// Fills everything below the horizon, so the ground reaches the sky
  /// beyond the detailed road.
  void _groundBase(Canvas c, EnvironmentTheme env) {
    final w = cam.width;
    final h = cam.height;
    final hz = cam.horizonY;
    final vp = Offset(cam.cx, hz);
    const sh = GameConfig.shoulderWidth;
    _p.color = env.leftColor;
    c.drawRect(Rect.fromLTRB(0, hz, w, h), _p);
    final rl = _edgeAtBottom(GameConfig.roadLeft);
    final rr = _edgeAtBottom(GameConfig.roadRight);
    final sl = _edgeAtBottom(GameConfig.roadLeft - sh);
    final sr = _edgeAtBottom(GameConfig.roadRight + sh);
    final farRight = math.max(w * 4, sr.dx + 10);
    _poly(c, [vp, sr, Offset(farRight, h), Offset(farRight, hz)], env.rightColor);
    _poly(c, [vp, sl, rl], env.shoulder);
    _poly(c, [vp, rr, sr], env.shoulder);
    _poly(c, [vp, rl, rr], env.asphalt);
  }

  void _road(Canvas c) {
    c.save();
    c.clipRect(Rect.fromLTRB(0, cam.horizonY, cam.width, cam.height));
    c.transform(cam.groundMatrix());
    c.clipRect(Rect.fromLTRB(-4000, cam.farY, 4000, cam.nearY));
    game.road.renderRange(c, cam.farY, cam.nearY);
    c.restore();
  }

  void _horizonHaze(Canvas c, int env) {
    final hz = cam.horizonY;
    final depth = cam.height * 0.1;
    final color = SkyPainter.horizonColor(env);
    _p.shader = ui.Gradient.linear(Offset(0, hz), Offset(0, hz + depth), [color, color.withValues(alpha: 0)]);
    c.drawRect(Rect.fromLTRB(0, hz - 1, cam.width, hz + depth), _p);
    _p.shader = null;
  }

  /// Upright guardrails along the mountain and coastal roads.
  void _guardrails(Canvas c) {
    game.road.forEachSegment(cam.farY, cam.nearY, (env, top) {
      if (!env.guardrails) return;
      final far = math.max(top, cam.farY);
      final near = math.min(top + 200, cam.nearY);
      if (far >= near) return;
      for (final x in [
        GameConfig.roadLeft - GameConfig.shoulderWidth + 1,
        GameConfig.roadRight + GameConfig.shoulderWidth - 1,
      ]) {
        final quad = [
          cam.project(x, far, 15),
          cam.project(x, near, 15),
          cam.project(x, near, 0),
          cam.project(x, far, 0),
        ];
        paintOnQuad(c, Rect.fromLTRB(far, 0, near, 15), quad, (c) {
          _p.color = const Color(0xFF546E7A);
          final first = (far / 25).floor() * 25.0;
          for (var y = first; y < near; y += 25) {
            c.drawRect(Rect.fromLTWH(y, 4, 3, 11), _p);
          }
          _p.color = const Color(0xFFB0BEC5);
          c.drawRect(Rect.fromLTRB(far, 1, near, 8), _p);
          _p.color = const Color(0xFF78909C);
          c.drawRect(Rect.fromLTRB(far, 4, near, 5.2), _p);
        });
      }
    });
  }

  // ------------------------------------------------------------ objects

  /// Gameplay objects fade in where the top-down screen used to start.
  double _fade(double y) {
    final start = cam.playerY - GameConfig.spawnY - 20;
    return ((start - cam.zOf(y)) / 120).clamp(0.0, 1.0);
  }

  void _add(double sortY, void Function(Canvas) draw) => _drawables.add(Drawable3D(sortY, draw));

  void _collect() {
    final player = game.player;
    // Headlight pool on the road ahead of the rider.
    if (player.isMounted && !player.isCrashed) {
      _add(-1e9, (c) {
        Shapes.decal(c, cam, Rect.fromLTRB(player.x - 60, player.y - 260, player.x + 60, player.y - 8), (c) {
          _path
            ..reset()
            ..moveTo(player.x - 5, player.y - 8)
            ..lineTo(player.x + 5, player.y - 8)
            ..lineTo(player.x + 55, player.y - 260)
            ..lineTo(player.x - 55, player.y - 260)
            ..close();
          _p.shader = ui.Gradient.linear(Offset(0, player.y - 8), Offset(0, player.y - 260), const [
            Color(0x22FFF59D),
            Color(0x00FFF59D),
          ]);
          c.drawPath(_path, _p);
          _p.shader = null;
        });
      });
    }

    for (final child in game.world.children) {
      switch (child) {
        case SceneryProp():
          _add(child.y + child.height / 2, (c) => PropView.drawProp(c, cam, child));
        case TrafficVehicle():
          final alpha = _fade(child.y + child.height / 2);
          if (alpha > 0) _add(child.y + child.height / 2, (c) => VehicleView.draw(c, cam, child, alpha: alpha));
        case RoadObstacle():
          final alpha = _fade(child.y);
          if (alpha <= 0) continue;
          if (child.type == ObstacleType.pothole) {
            // Flat on the road, so it goes under everything.
            _add(-1e9 + child.y, (c) => SmallViews.drawPothole(c, cam, child));
          } else {
            _add(child.y + child.height / 2, (c) => SmallViews.drawObstacle(c, cam, child, alpha: alpha));
          }
        case RoadAnimal():
          final alpha = _fade(child.y);
          if (alpha > 0) _add(child.y, (c) => SmallViews.drawAnimal(c, cam, child, alpha: alpha));
        case CashCollectible():
          final alpha = _fade(child.y);
          if (alpha > 0) _add(child.y, (c) => SmallViews.drawCash(c, cam, child, alpha: alpha));
        case FuelCollectible():
          final alpha = _fade(child.y);
          if (alpha > 0) _add(child.y, (c) => SmallViews.drawFuel(c, cam, child, alpha: alpha));
        case LtoCheckpoint():
          _add(-1e9 + child.y, (c) => PropView.drawCheckpointDecal(c, cam, child));
          PropView.collectCheckpoint(_drawables, cam, child);
        case LtoOfficer():
          final y = cam.pullBehind(child.y);
          // Ride half a lane to the side so the officer never hides the rider.
          final side = child.mode == OfficerMode.catching ? 0.0 : (child.x < GameConfig.worldWidth / 2 ? 1.0 : -1.0);
          final behind = ((child.y - player.y) / 60).clamp(0.0, 1.0);
          _add(y, (c) => RiderView.drawOfficer(c, cam, child.x + side * 34 * behind, y, child.time));
        case AmbulanceResponder():
          _add(child.y + child.height / 2, (c) => VehicleView.drawAmbulance(c, cam, child));
        case PlayerMotorcycle():
          _add(child.y, (c) => _drawPlayer(c, child));
        case FloatingText() || ImpactBurst() || PickupSparkle() || OncomingWarning():
          _effects.add(child as PositionComponent);
      }
    }
  }

  void _drawPlayer(Canvas c, PlayerMotorcycle player) {
    var roll = player.roll;
    if (player.isCrashed) {
      // Bike slides and tips over: a cartoon spill, nothing graphic.
      final t = math.min(player.crashTime / 0.6, 1.0);
      roll = 1.4 * (1 - (1 - t) * (1 - t));
    }
    RiderView.drawBike(
      c,
      cam,
      player.x,
      player.y,
      player.bike,
      roll: roll,
      opacity: player.isCrashed ? 1 : player.opacity,
      braking: player.braking,
      anim: player.isCrashed ? 0 : player.wheelTravel,
    );
  }
}
