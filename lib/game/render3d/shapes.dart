import 'dart:math' as math;
import 'dart:ui';

import 'camera3d.dart';

/// Paints art on one face of a shape, in that face's own units
/// (width × height, origin at the top-left).
typedef FacePainter = void Function(Canvas canvas, Size size);

/// Building blocks for the 3D view: boxes, upright billboards and flat
/// decals, all positioned in world units.
class Shapes {
  Shapes._();

  static final Paint _p = Paint()..isAntiAlias = true;
  static final Path _path = Path();

  static Color shade(Color c, double amount) => Color.lerp(c, const Color(0xFF000000), amount)!;
  static Color tint(Color c, double amount) => Color.lerp(c, const Color(0xFFFFFFFF), amount)!;

  /// A solid block spanning [left]..[right] across the road, [far]..[near]
  /// along it, and [bottom]..[top] in height. Only faces turned toward the
  /// camera are drawn.
  ///
  /// [roof] paints the top face in [roofSrc] coordinates, which map to the
  /// block's far-left corner (top-left) through its near-right corner.
  static void box(
    Canvas c,
    Camera3D cam, {
    required double left,
    required double right,
    required double far,
    required double near,
    double bottom = 0,
    required double top,
    required Color color,
    FacePainter? nearFace,
    FacePainter? sideFace,
    Rect? roofSrc,
    void Function(Canvas canvas)? roof,
    Color? roofColor,
    double alpha = 1,
  }) {
    // Cut off whatever is too close to (or behind) the camera.
    near = math.min(near, cam.nearY);
    if (far >= near || cam.zOf(far) > Camera3D.farZ) return;
    final nTL = cam.project(left, near, top);
    final nTR = cam.project(right, near, top);
    final nBR = cam.project(right, near, bottom);
    final nBL = cam.project(left, near, bottom);
    final fTL = cam.project(left, far, top);
    final fTR = cam.project(right, far, top);
    final fBR = cam.project(right, far, bottom);
    final fBL = cam.project(left, far, bottom);

    final fading = alpha < 0.999;
    if (fading) {
      final bounds = Rect.fromPoints(fTL, nBR).expandToInclude(Rect.fromPoints(nTL, fBR)).inflate(4);
      c.saveLayer(bounds, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    }

    final len = near - far;
    final height = top - bottom;
    if (cam.camX < left) {
      _quad(c, [fTL, nTL, nBL, fBL], shade(color, 0.32));
      if (sideFace != null) {
        paintOnQuad(c, Rect.fromLTWH(0, 0, len, height), [fTL, nTL, nBL, fBL], (c) => sideFace(c, Size(len, height)));
      }
    } else if (cam.camX > right) {
      _quad(c, [fTR, nTR, nBR, fBR], shade(color, 0.32));
      if (sideFace != null) {
        paintOnQuad(c, Rect.fromLTWH(0, 0, len, height), [fTR, nTR, nBR, fBR], (c) => sideFace(c, Size(len, height)));
      }
    }

    if (top < cam.camHeight) {
      final quad = [fTL, fTR, nTR, nTL];
      _quad(c, quad, roofColor ?? tint(color, 0.06));
      if (roof != null) paintOnQuad(c, roofSrc ?? Rect.fromLTRB(left, far, right, near), quad, roof);
    }

    _p.color = shade(color, 0.12);
    final face = Rect.fromPoints(nTL, nBR);
    c.drawRect(face, _p);
    if (nearFace != null && face.width > 0.5) {
      final s = cam.scaleAt(near);
      c.save();
      c.translate(nTL.dx, nTL.dy);
      c.scale(s);
      nearFace(c, Size(right - left, height));
      c.restore();
    }

    if (fading) c.restore();
  }

  static void _quad(Canvas c, List<Offset> q, Color color) {
    _path
      ..reset()
      ..moveTo(q[0].dx, q[0].dy)
      ..lineTo(q[1].dx, q[1].dy)
      ..lineTo(q[2].dx, q[2].dy)
      ..lineTo(q[3].dx, q[3].dy)
      ..close();
    _p.color = color;
    c.drawPath(_path, _p);
  }

  /// An upright cut-out facing the camera, [width] × [height] world units,
  /// standing at (x, y) with its base [lift] units above the road.
  /// [angle] tilts it around the base (e.g. a leaning rider).
  static void billboard(
    Canvas c,
    Camera3D cam,
    double x,
    double y,
    double width,
    double height,
    FacePainter painter, {
    double lift = 0,
    double angle = 0,
    double alpha = 1,
  }) {
    if (!cam.isVisible(y) || alpha <= 0.01) return;
    final s = cam.scaleAt(y);
    final base = cam.project(x, y, lift);
    c.save();
    c.translate(base.dx, base.dy);
    if (angle != 0) c.rotate(angle);
    c.scale(s);
    c.translate(-width / 2, -height);
    if (alpha < 0.999) {
      c.saveLayer(
        Rect.fromLTWH(-width, -height, width * 3, height * 3),
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
      );
      painter(c, Size(width, height));
      c.restore();
    } else {
      painter(c, Size(width, height));
    }
    c.restore();
  }

  /// Soft oval shadow on the road under a [width] × [length] footprint.
  static void shadow(Canvas c, Camera3D cam, double x, double y, double width, double length, {double opacity = 0.3}) {
    if (!cam.isVisible(y)) return;
    final hw = width / 2 + 3;
    final hl = length / 2 + 2;
    final quad = [
      cam.project(x - hw, y - hl),
      cam.project(x + hw, y - hl),
      cam.project(x + hw, y + hl),
      cam.project(x - hw, y + hl),
    ];
    paintOnQuad(c, const Rect.fromLTWH(0, 0, 1, 1), quad, (c) {
      _p.color = Color.fromRGBO(0, 0, 0, opacity);
      c.drawOval(const Rect.fromLTWH(0.02, 0.02, 0.96, 0.96), _p);
    });
  }

  /// Paints flat art lying on the road. [painter] draws in world
  /// coordinates inside [area].
  static void decal(Canvas c, Camera3D cam, Rect area, void Function(Canvas canvas) painter) {
    if (area.top >= cam.nearY || cam.zOf(area.bottom) > Camera3D.farZ) return;
    if (area.bottom > cam.nearY) area = Rect.fromLTRB(area.left, area.top, area.right, cam.nearY);
    final quad = [
      cam.project(area.left, area.top),
      cam.project(area.right, area.top),
      cam.project(area.right, area.bottom),
      cam.project(area.left, area.bottom),
    ];
    paintOnQuad(c, area, quad, painter);
  }
}
