import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../game_config.dart';

/// Chase camera that looks down the highway from behind and above the rider.
///
/// Gameplay still runs on the flat 2D world: x across the road and y down
/// the screen, with the rider at [playerY]. The camera turns that plane into
/// a perspective view. A world point at (x, y) with height h above the
/// asphalt is [zOf] units ahead of the rider and projects to the screen
/// through [project].
class Camera3D {
  /// Screen size in logical pixels.
  double width = 400;
  double height = 800;

  /// Screen y of the vanishing point.
  double horizonY = 270;

  /// Screen x of the vanishing point.
  double cx = 200;

  /// Focal length in pixels.
  double focal = 360;

  /// Camera height above the road and distance behind the rider (world units).
  double camHeight = 250;
  double camBack = 220;

  /// World x the camera is centred on.
  double camX = GameConfig.worldWidth / 2;

  /// World y of the rider.
  double playerY = 600;

  /// Road bend: sideways shift (world units) per squared unit of distance
  /// ahead. Zero at and behind the rider, so gameplay never moves.
  double curve = 0;

  /// Bend used for the sharpest curve (curvature 1).
  static const double maxCurve = 1.1e-4;

  /// How much [pullBehind] shortens distances behind the rider.
  static const double behindCompression = 0.4;

  /// Draw distance ahead of the rider.
  static const double farZ = 2600;

  /// Nearest depth (from the camera) that is still drawn.
  static const double nearDepth = 30;

  /// Pixels per world unit at the rider's depth.
  double get playerScale => focal / camBack;

  void setup({
    required double screenWidth,
    required double screenHeight,
    required double playerY,
    required double focusX,
    Offset shake = Offset.zero,
  }) {
    width = screenWidth;
    height = screenHeight;
    this.playerY = playerY;
    const roadWidth = GameConfig.roadRight - GameConfig.roadLeft;
    // Fit the four lanes to the screen at the rider's depth, then pick the
    // camera height that puts the rider near the bottom of the screen.
    final roadPx = math.min(screenWidth * 1.12, screenHeight * 0.95);
    focal = roadPx * camBack / roadWidth;
    final baseHorizon = screenHeight * 0.34;
    final riderScreenY = screenHeight * 0.80;
    camHeight = (riderScreenY - baseHorizon) * camBack / focal;
    horizonY = baseHorizon + shake.dy;
    cx = screenWidth / 2 + shake.dx;
    // Follow the rider a little so lane changes feel like steering.
    camX = GameConfig.worldWidth / 2 + (focusX - GameConfig.worldWidth / 2) * 0.35;
  }

  /// Distance ahead of the rider (negative = behind).
  double zOf(double y) => playerY - y;

  /// Moves a row behind the rider closer to them, so the chasing LTO
  /// officer and pop-up text stay on screen instead of below it.
  double pullBehind(double y) => y > playerY ? playerY + (y - playerY) * behindCompression : y;

  /// Distance from the camera along the road.
  double depthOf(double y) => zOf(y) + camBack;

  /// Pixels per world unit at world row [y].
  double scaleAt(double y) => focal / depthOf(y);

  bool isVisible(double y) {
    final z = zOf(y);
    return z < farZ && z + camBack > nearDepth;
  }

  /// How far the bent road has drifted sideways at world row [y].
  double bendX(double y) {
    if (curve == 0) return 0;
    final z = zOf(y);
    return z <= 0 ? 0 : curve * z * z;
  }

  /// Screen pixels the bend moves things at row [y].
  double bendPx(double y) => bendX(y) * focal / depthOf(y);

  /// Sideways pixel shift of the horizon, for parallax on the sky.
  double get horizonBendPx => bendPx(playerY - farZ);

  Offset project(double x, double y, [double h = 0]) {
    final s = focal / depthOf(y);
    return Offset(cx + (x + bendX(y) - camX) * s, horizonY + (camHeight - h) * s);
  }

  /// World y of the nearest row that is drawn.
  double get nearY => playerY + camBack - nearDepth;

  /// World y of the farthest row that is drawn.
  double get farY => playerY - farZ;

  /// Maps the flat world (x, y) onto the road surface. Only rows up to
  /// [nearY] may be drawn with it.
  Float64List groundMatrix() {
    final p = playerY + camBack;
    // Column-major 4x4: x' = f·X − cx·Y + (cx·P − f·camX), y' = −hz·Y + hz·P + h·f,
    // w = P − Y.
    return Float64List.fromList([
      focal, 0, 0, 0, //
      -cx, -horizonY, 0, -1, //
      0, 0, 1, 0, //
      cx * p - focal * camX, horizonY * p + camHeight * focal, 0, p, //
    ]);
  }
}

/// Draws art authored in [src] space onto the screen quad [quad]
/// (top-left, top-right, bottom-right, bottom-left), with perspective.
void paintOnQuad(Canvas canvas, Rect src, List<Offset> quad, void Function(Canvas canvas) painter) {
  final m = _squareToQuad(quad[0], quad[1], quad[2], quad[3]);
  if (m == null) return;
  canvas.save();
  canvas.transform(m);
  canvas.scale(1 / src.width, 1 / src.height);
  canvas.translate(-src.left, -src.top);
  canvas.clipRect(src);
  painter(canvas);
  canvas.restore();
}

/// Projective map from the unit square onto a quad (Heckbert's method),
/// as a column-major 4x4 matrix for [Canvas.transform].
Float64List? _squareToQuad(Offset q0, Offset q1, Offset q2, Offset q3) {
  final sx = q0.dx - q1.dx + q2.dx - q3.dx;
  final sy = q0.dy - q1.dy + q2.dy - q3.dy;
  double a, b, c, d, e, f, g, h;
  if (sx.abs() < 1e-6 && sy.abs() < 1e-6) {
    a = q1.dx - q0.dx;
    b = q2.dx - q1.dx;
    c = q0.dx;
    d = q1.dy - q0.dy;
    e = q2.dy - q1.dy;
    f = q0.dy;
    g = 0;
    h = 0;
  } else {
    final dx1 = q1.dx - q2.dx;
    final dx2 = q3.dx - q2.dx;
    final dy1 = q1.dy - q2.dy;
    final dy2 = q3.dy - q2.dy;
    final det = dx1 * dy2 - dx2 * dy1;
    if (det.abs() < 1e-9) return null;
    g = (sx * dy2 - dx2 * sy) / det;
    h = (dx1 * sy - sx * dy1) / det;
    a = q1.dx - q0.dx + g * q1.dx;
    b = q3.dx - q0.dx + h * q3.dx;
    c = q0.dx;
    d = q1.dy - q0.dy + g * q1.dy;
    e = q3.dy - q0.dy + h * q3.dy;
    f = q0.dy;
  }
  return Float64List.fromList([
    a, d, 0, g, //
    b, e, 0, h, //
    0, 0, 1, 0, //
    c, f, 0, 1, //
  ]);
}
