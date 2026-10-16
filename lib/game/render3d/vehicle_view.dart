import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart' show Vector2;

import '../components/effects.dart';
import '../components/traffic_vehicle.dart';
import '../environments.dart';
import '../painting/vehicle_painter.dart';
import 'camera3d.dart';
import 'shapes.dart';

/// Which end of a vehicle a face shows.
enum _End { front, rear }

/// What a block of a vehicle represents, which decides its face art.
enum _Part { body, cabin, upper, hood, cargo, cab, sideCab, bikeFrame, sirenBar, train }

/// One block of a vehicle. [from]..[to] run from the front (0) to the rear
/// (1); [inset] narrows it on both sides; [xFrom]..[xTo] place it across
/// the vehicle (0 = left, 1 = right, as seen from behind).
class _Block {
  const _Block(
    this.part,
    this.from,
    this.to,
    this.bottom,
    this.top, {
    this.inset = 0,
    this.xFrom = 0,
    this.xTo = 1,
    this.wheels = false,
  });

  final _Part part;
  final double from;
  final double to;
  final double bottom;
  final double top;
  final double inset;
  final double xFrom;
  final double xTo;
  final bool wheels;
}

/// Traffic drawn as solid 3D blocks, with the procedural top-down art
/// mapped onto the roofs and new front/rear art on the faces.
class VehicleView {
  VehicleView._();

  static final Paint _p = Paint()..isAntiAlias = true;

  static const _glass = Color(0xFF22344A);
  static const _glassHi = Color(0x335E86B0);
  static const _tire = Color(0xFF151515);
  static const _chrome = Color(0xFFCFD8DC);

  static List<_Block> _blocks(VehicleType type) => switch (type) {
    VehicleType.car || VehicleType.taxi => const [
      _Block(_Part.body, 0, 1, 0, 14, wheels: true),
      _Block(_Part.cabin, 0.27, 0.8, 14, 27, inset: 4),
    ],
    VehicleType.suv => const [
      _Block(_Part.body, 0, 1, 0, 17, wheels: true),
      _Block(_Part.cabin, 0.2, 0.88, 17, 35, inset: 3),
    ],
    VehicleType.van => const [
      _Block(_Part.hood, 0, 0.14, 0, 17, inset: 1, wheels: true),
      _Block(_Part.upper, 0.12, 1, 0, 38, wheels: true),
    ],
    VehicleType.jeepney => const [
      _Block(_Part.hood, 0, 0.22, 0, 18, inset: 4, wheels: true),
      _Block(_Part.body, 0.22, 1, 0, 37, wheels: true),
    ],
    VehicleType.bus => const [_Block(_Part.upper, 0, 1, 0, 58, wheels: true)],
    VehicleType.truck => const [
      _Block(_Part.cab, 0, 0.25, 0, 36, inset: 2, wheels: true),
      _Block(_Part.cargo, 0.26, 1, 0, 48, wheels: true),
    ],
    VehicleType.tricycle => const [
      _Block(_Part.bikeFrame, 0.05, 0.95, 0, 18, xFrom: 0.12, xTo: 0.36, wheels: true),
      _Block(_Part.sideCab, 0.05, 0.95, 0, 33, xFrom: 0.38, xTo: 0.96, wheels: true),
    ],
    VehicleType.lrt => const [
      _Block(_Part.train, 0, 0.49, 0, 52, wheels: true),
      _Block(_Part.train, 0.51, 1, 0, 52, wheels: true),
    ],
  };

  static const List<_Block> _ambulance = [
    _Block(_Part.hood, 0, 0.14, 0, 18, inset: 1, wheels: true),
    _Block(_Part.upper, 0.12, 1, 0, 40, wheels: true),
    _Block(_Part.sirenBar, 0.2, 0.32, 40, 44, inset: 6),
  ];

  static void draw(Canvas c, Camera3D cam, TrafficVehicle v, {double alpha = 1}) {
    final sway = math.sin(v.animTime * 2.3 + v.variant) * 0.5;
    final shake = v.shakeAmount > 0 ? math.sin(v.animTime * 60) * 2.5 * v.shakeAmount / 0.35 : 0.0;
    _drawVehicle(
      c,
      cam,
      blocks: _blocks(v.type),
      x: v.x + sway + shake,
      y: v.y,
      width: v.width,
      length: v.height,
      color: v.color,
      facingCamera: v.oncoming,
      alpha: alpha,
      roofArt: (c, size) {
        final sprite = v.spriteOverride;
        if (sprite != null) {
          if (v.oncoming) {
            c.translate(size.width, size.height);
            c.rotate(math.pi);
          }
          sprite.render(c, size: Vector2(size.width, size.height));
          return;
        }
        VehiclePainter.paint(
          c,
          size,
          v.type,
          v.color,
          facingDown: v.oncoming,
          variant: v.variant,
          braking: v.braking,
          signal: v.signal,
          blinkPhase: v.animTime,
        );
      },
      faceArt: (part, end, c, size) => _face(
        c,
        size,
        v.type,
        part,
        end,
        v.color,
        v.variant,
        braking: v.braking,
        signal: v.signal,
        blink: v.animTime,
      ),
      sideArt: (part, c, size, wheels) => _side(c, size, v.type, part, v.color, v.variant, wheels),
    );
  }

  static void drawAmbulance(Canvas c, Camera3D cam, AmbulanceResponder a) {
    const white = Color(0xFFF5F5F5);
    _drawVehicle(
      c,
      cam,
      blocks: _ambulance,
      x: a.x,
      y: a.y,
      width: a.width,
      length: a.height,
      color: white,
      facingCamera: true,
      roofArt: (c, size) => VehiclePainter.paintAmbulance(c, size, sirenPhase: a.time * 3),
      faceArt: (part, end, c, size) {
        if (part == _Part.sirenBar) {
          _sirenBar(c, size, a.time * 3);
        } else {
          _face(c, size, VehicleType.van, part, end, white, 0, ambulance: true);
        }
      },
      sideArt: (part, c, size, wheels) {
        if (part == _Part.sirenBar) {
          _sirenBar(c, size, a.time * 3);
        } else {
          _side(c, size, VehicleType.van, part, white, 0, wheels);
          if (part == _Part.upper) {
            _p.color = const Color(0xFFD32F2F);
            c.drawRect(Rect.fromLTWH(0, size.height * 0.55, size.width, 4), _p);
          }
        }
      },
    );
  }

  static void _drawVehicle(
    Canvas c,
    Camera3D cam, {
    required List<_Block> blocks,
    required double x,
    required double y,
    required double width,
    required double length,
    required Color color,
    required bool facingCamera,
    required void Function(Canvas c, Size size) roofArt,
    required void Function(_Part part, _End end, Canvas c, Size size) faceArt,
    required void Function(_Part part, Canvas c, Size size, bool wheels) sideArt,
    double alpha = 1,
  }) {
    final left = x - width / 2;
    final topY = y - length / 2;
    Shapes.shadow(c, cam, x, y, width, length, opacity: 0.32 * alpha);
    if (alpha < 0.999) {
      final a = cam.project(left - 10, topY, 60);
      final b = cam.project(left + width + 10, topY + length);
      c.saveLayer(Rect.fromPoints(a, b).inflate(40), Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    }
    // Same-direction traffic shows its rear; oncoming traffic its front.
    // Draw the far blocks first so nearer ones overlap them.
    final ordered = facingCamera ? blocks.reversed : blocks;
    for (final b in ordered) {
      final double far, near;
      if (facingCamera) {
        far = topY + length * (1 - b.to);
        near = topY + length * (1 - b.from);
      } else {
        far = topY + length * b.from;
        near = topY + length * b.to;
      }
      // Oncoming vehicles are turned around, so left and right swap.
      final xa = facingCamera ? 1 - b.xTo : b.xFrom;
      final xb = facingCamera ? 1 - b.xFrom : b.xTo;
      final bl = left + width * xa + b.inset;
      final br = left + width * xb - b.inset;
      final end = facingCamera ? _End.front : _End.rear;
      final bodyColor = switch (b.part) {
        _Part.cabin => Shapes.tint(color, 0.1),
        _Part.bikeFrame => const Color(0xFF37474F),
        _Part.sirenBar => const Color(0xFF263238),
        _Part.cargo when color != const Color(0xFFF5F5F5) => const Color(0xFFE0E0E0),
        _ => color,
      };
      Shapes.box(
        c,
        cam,
        left: bl,
        right: br,
        far: far,
        near: near,
        bottom: b.bottom,
        top: b.top,
        color: bodyColor,
        roofSrc: Rect.fromLTRB(bl, far, br, near),
        roof: (c) {
          c.translate(left, topY);
          roofArt(c, Size(width, length));
        },
        nearFace: (c, size) => faceArt(b.part, end, c, size),
        sideFace: (c, size) => sideArt(b.part, c, size, b.wheels),
      );
    }
    if (alpha < 0.999) c.restore();
  }

  // ------------------------------------------------------------ face art

  static void _face(
    Canvas c,
    Size s,
    VehicleType type,
    _Part part,
    _End end,
    Color color,
    int variant, {
    bool braking = false,
    int signal = 0,
    double blink = 0,
    bool ambulance = false,
  }) {
    final w = s.width;
    final h = s.height;
    final front = end == _End.front;
    switch (part) {
      case _Part.cabin:
        // Rear window or windshield.
        _p.color = _glass;
        c.drawRRect(RRect.fromLTRBR(2, 1.5, w - 2, h - 1, const Radius.circular(3)), _p);
        _p.color = _glassHi;
        c.drawPath(
          Path()
            ..moveTo(w * 0.2, 1.5)
            ..lineTo(w * 0.42, 1.5)
            ..lineTo(w * 0.25, h - 1)
            ..lineTo(w * 0.05, h - 1)
            ..close(),
          _p,
        );
        if (type == VehicleType.suv && front) _strobes(c, w, 3, blink);
        if (type == VehicleType.taxi && !front) {
          _p.color = const Color(0xFFFFC107);
          c.drawRect(Rect.fromLTWH(w * 0.3, -3, w * 0.4, 3), _p);
        }
      case _Part.body:
      case _Part.hood:
      case _Part.cab:
        if (type == VehicleType.jeepney && part == _Part.body) {
          front ? _jeepneyFrontUpper(c, w, h, variant) : _jeepneyRear(c, w, h, color, variant);
        } else if (front) {
          final glassTop = part == _Part.cab ? h * 0.12 : -1.0;
          if (glassTop >= 0) {
            _p.color = _glass;
            c.drawRRect(RRect.fromLTRBR(3, glassTop, w - 3, h * 0.48, const Radius.circular(3)), _p);
            _p.color = _glassHi;
            c.drawRect(Rect.fromLTWH(w * 0.15, glassTop + 1, w * 0.12, h * 0.3), _p);
          }
          _headlights(c, w, h, jeepney: type == VehicleType.jeepney);
        } else {
          _rearLights(c, w, h, braking: braking, signal: signal, blink: blink);
        }
        if (type == VehicleType.taxi && part == _Part.body) {
          _p.color = const Color(0xFF212121);
          c.drawRect(Rect.fromLTWH(0, h * 0.2, w, 1.5), _p);
        }
      case _Part.upper:
        if (type == VehicleType.bus) {
          front ? _busFront(c, w, h) : _busRear(c, w, h, color, braking, signal, blink);
        } else {
          front ? _vanFront(c, w, h, ambulance) : _vanRear(c, w, h, braking, signal, blink, ambulance);
        }
      case _Part.cargo:
        if (front) {
          _p.color = Shapes.shade(const Color(0xFFE0E0E0), 0.1);
          c.drawRect(Rect.fromLTWH(0, 0, w, h), _p);
        } else {
          _cargoRear(c, w, h, braking, signal, blink);
        }
      case _Part.sideCab:
        _p.color = const Color(0xFFFFF8E1);
        c.drawRRect(RRect.fromLTRBR(3, h * 0.18, w - 3, h * 0.8, const Radius.circular(4)), _p);
        _p.color = color;
        c.drawRect(Rect.fromLTWH(0, 0, w, h * 0.16), _p);
        _p.color = Shapes.shade(color, 0.3);
        c.drawRect(Rect.fromLTWH(3, h * 0.55, w - 6, 3), _p);
        if (front) {
          _p.color = _glass;
          c.drawRRect(RRect.fromLTRBR(4, h * 0.2, w - 4, h * 0.45, const Radius.circular(2)), _p);
        } else {
          _p.color = braking ? const Color(0xFFFF1744) : const Color(0xFFC62828);
          c.drawRect(Rect.fromLTWH(2, h * 0.82, 5, 3), _p);
        }
        _tires(c, w, h, inset: 1);
      case _Part.bikeFrame:
        _p.color = _tire;
        c.drawRRect(RRect.fromLTRBR(w * 0.3, h * 0.45, w * 0.7, h, const Radius.circular(2)), _p);
        _p.color = front ? const Color(0xFFFFF9C4) : const Color(0xFFC62828);
        c.drawCircle(Offset(w / 2, h * 0.3), 2.2, _p);
      case _Part.sirenBar:
        _sirenBar(c, s, blink);
      case _Part.train:
        front ? _trainFront(c, w, h) : _trainRear(c, w, h, braking);
    }
  }

  static void _trainFront(Canvas c, double w, double h) {
    // Route sign, wide windscreen and bright headlights.
    _p.color = const Color(0xFF111111);
    c.drawRect(Rect.fromLTWH(w * 0.2, 3, w * 0.6, 7), _p);
    _p.color = const Color(0xFFFFAB00);
    c.drawRect(Rect.fromLTWH(w * 0.28, 5, w * 0.44, 3), _p);
    _p.color = _glass;
    c.drawRRect(RRect.fromLTRBR(4, 12, w - 4, h * 0.5, const Radius.circular(5)), _p);
    _p.color = _glassHi;
    c.drawRect(Rect.fromLTWH(w * 0.12, 14, w * 0.1, h * 0.3), _p);
    _p.color = const Color(0xFF7E57C2);
    c.drawRect(Rect.fromLTWH(0, h * 0.56, w, 5), _p);
    _p.color = const Color(0x66FFF59D);
    c.drawCircle(Offset(8, h * 0.74), 10, _p);
    c.drawCircle(Offset(w - 8, h * 0.74), 10, _p);
    _p.color = const Color(0xFFFFFDE7);
    c.drawCircle(Offset(8, h * 0.74), 4, _p);
    c.drawCircle(Offset(w - 8, h * 0.74), 4, _p);
    _p.color = const Color(0xFF263238);
    c.drawRect(Rect.fromLTWH(w * 0.3, h - 6, w * 0.4, 6), _p);
  }

  static void _trainRear(Canvas c, double w, double h, bool braking) {
    _p.color = _glass;
    c.drawRRect(RRect.fromLTRBR(w * 0.3, 8, w * 0.7, h * 0.7, const Radius.circular(3)), _p);
    _p.color = const Color(0xFF7E57C2);
    c.drawRect(Rect.fromLTWH(0, h * 0.56, w * 0.28, 5), _p);
    c.drawRect(Rect.fromLTWH(w * 0.72, h * 0.56, w * 0.28, 5), _p);
    _p.color = braking ? const Color(0xFFFF1744) : const Color(0xFFC62828);
    c.drawRRect(RRect.fromLTRBR(4, h * 0.72, 12, h * 0.8, const Radius.circular(2)), _p);
    c.drawRRect(RRect.fromLTRBR(w - 12, h * 0.72, w - 4, h * 0.8, const Radius.circular(2)), _p);
  }

  static void _tires(Canvas c, double w, double h, {double inset = 3}) {
    _p.color = _tire;
    c.drawRRect(RRect.fromLTRBR(inset, h - 4, inset + 7, h + 0.5, const Radius.circular(1.5)), _p);
    c.drawRRect(RRect.fromLTRBR(w - inset - 7, h - 4, w - inset, h + 0.5, const Radius.circular(1.5)), _p);
  }

  static void _rearLights(Canvas c, double w, double h, {bool braking = false, int signal = 0, double blink = 0}) {
    _tires(c, w, h);
    // Bumper and plate.
    _p.color = const Color(0xFF263238);
    c.drawRRect(RRect.fromLTRBR(1, h - 5, w - 1, h - 1.5, const Radius.circular(1.5)), _p);
    _p.color = const Color(0xFFF5F5F5);
    c.drawRect(Rect.fromLTWH(w / 2 - 5, h * 0.42, 10, 4.5), _p);
    _p.color = const Color(0xFF37474F);
    c.drawRect(Rect.fromLTWH(w / 2 - 3.5, h * 0.42 + 1.5, 7, 1.2), _p);
    // Tail lights.
    _p.color = braking ? const Color(0xFFFF1744) : const Color(0xFFB71C1C);
    c.drawRRect(RRect.fromLTRBR(1.5, h * 0.18, 9, h * 0.42, const Radius.circular(1.5)), _p);
    c.drawRRect(RRect.fromLTRBR(w - 9, h * 0.18, w - 1.5, h * 0.42, const Radius.circular(1.5)), _p);
    if (braking) {
      _p.color = const Color(0x66FF1744);
      c.drawCircle(Offset(5, h * 0.3), 9, _p);
      c.drawCircle(Offset(w - 5, h * 0.3), 9, _p);
    }
    _signal(c, w, h * 0.12, signal, blink);
  }

  static void _signal(Canvas c, double w, double y, int signal, double blink) {
    if (signal == 0 || !(blink * 2.5).floor().isEven) return;
    final sx = signal < 0 ? 1.0 : w - 7;
    _p.color = const Color(0xFFFFAB00);
    c.drawRRect(RRect.fromLTRBR(sx, y, sx + 6, y + 4, const Radius.circular(1.5)), _p);
    _p.color = const Color(0x55FFAB00);
    c.drawCircle(Offset(sx + 3, y + 2), 8, _p);
  }

  static void _headlights(Canvas c, double w, double h, {bool jeepney = false}) {
    _tires(c, w, h);
    _p.color = const Color(0xFF263238);
    c.drawRRect(RRect.fromLTRBR(1, h - 5, w - 1, h - 1.5, const Radius.circular(1.5)), _p);
    // Grille.
    _p.color = jeepney ? _chrome : const Color(0xFF37474F);
    c.drawRRect(RRect.fromLTRBR(w * 0.3, h * 0.5, w * 0.7, h - 6, const Radius.circular(1.5)), _p);
    if (jeepney) {
      _p.color = const Color(0xFF90A4AE);
      for (var x = w * 0.33; x < w * 0.68; x += 3) {
        c.drawRect(Rect.fromLTWH(x, h * 0.52, 1, h * 0.4 - 6), _p);
      }
      // Chrome horse on the hood.
      _p.color = const Color(0xFFFFD54F);
      c.drawCircle(Offset(w / 2, h * 0.32), 2.4, _p);
    }
    // Lamps with a glow, so oncoming traffic is easy to spot.
    final ly = h * 0.58;
    _p.color = const Color(0x55FFF59D);
    c.drawCircle(Offset(6, ly), 8, _p);
    c.drawCircle(Offset(w - 6, ly), 8, _p);
    _p.color = const Color(0xFFFFFDE7);
    if (jeepney) {
      c.drawCircle(Offset(6, ly), 3.2, _p);
      c.drawCircle(Offset(w - 6, ly), 3.2, _p);
    } else {
      c.drawRRect(RRect.fromLTRBR(2, ly - 2.5, 11, ly + 2.5, const Radius.circular(2)), _p);
      c.drawRRect(RRect.fromLTRBR(w - 11, ly - 2.5, w - 2, ly + 2.5, const Radius.circular(2)), _p);
    }
  }

  static void _strobes(Canvas c, double w, double y, double blink) {
    final on = (blink * 6).floor().isEven;
    _p.color = on ? const Color(0xFF2979FF) : const Color(0xFFFF1744);
    c.drawRect(Rect.fromLTWH(w * 0.25, y, w * 0.2, 2.5), _p);
    _p.color = on ? const Color(0xFFFF1744) : const Color(0xFF2979FF);
    c.drawRect(Rect.fromLTWH(w * 0.55, y, w * 0.2, 2.5), _p);
    _p.color = (on ? const Color(0xFF2979FF) : const Color(0xFFFF1744)).withValues(alpha: 0.3);
    c.drawCircle(Offset(w * 0.35, y + 1), 7, _p);
  }

  static const _stripes = [Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFFFFEB3B), Color(0xFF43A047)];

  static void _jeepneyRear(Canvas c, double w, double h, Color color, int variant) {
    // Open back entrance with a grab bar and step.
    _p.color = const Color(0xFF2B2B2B);
    c.drawRRect(RRect.fromLTRBR(w * 0.3, h * 0.2, w * 0.7, h - 4, const Radius.circular(3)), _p);
    _p.color = const Color(0xFF5D4037);
    c.drawRect(Rect.fromLTWH(w * 0.32, h * 0.62, w * 0.36, 3), _p);
    _p.color = _chrome;
    c.drawRect(Rect.fromLTWH(w * 0.28, h - 4, w * 0.44, 2.5), _p);
    c.drawRect(Rect.fromLTWH(w * 0.48, h * 0.2, 1.5, h * 0.4), _p);
    for (var i = 0; i < 3; i++) {
      _p.color = _stripes[(i + variant) % _stripes.length];
      c.drawRect(Rect.fromLTWH(0, 2 + i * 3.2, w, 2), _p);
    }
    _tires(c, w, h);
    _p.color = const Color(0xFFD50000);
    c.drawRect(Rect.fromLTWH(2, h * 0.7, 5, 4), _p);
    c.drawRect(Rect.fromLTWH(w - 7, h * 0.7, 5, 4), _p);
  }

  static void _jeepneyFrontUpper(Canvas c, double w, double h, int variant) {
    // Destination sign over a split windshield; the hood block hides the rest.
    _p.color = _stripes[variant % _stripes.length];
    c.drawRect(Rect.fromLTWH(0, 0, w, 6), _p);
    _p.color = const Color(0xFFFFFFFF);
    c.drawRect(Rect.fromLTWH(w * 0.25, 1.5, w * 0.5, 3), _p);
    _p.color = _glass;
    c.drawRect(Rect.fromLTWH(3, 8, w / 2 - 4, h * 0.3), _p);
    c.drawRect(Rect.fromLTWH(w / 2 + 1, 8, w / 2 - 4, h * 0.3), _p);
  }

  static void _busFront(Canvas c, double w, double h) {
    _p.color = const Color(0xFF212121);
    c.drawRect(Rect.fromLTWH(4, 3, w - 8, 6), _p);
    _p.color = const Color(0xFFFFAB00);
    c.drawRect(Rect.fromLTWH(w * 0.25, 5, w * 0.5, 2), _p);
    _p.color = _glass;
    c.drawRRect(RRect.fromLTRBR(3, 11, w - 3, h * 0.55, const Radius.circular(4)), _p);
    _p.color = _glassHi;
    c.drawRect(Rect.fromLTWH(w * 0.12, 12, w * 0.1, h * 0.38), _p);
    c.save();
    c.translate(0, h * 0.55);
    _headlights(c, w, h * 0.45);
    c.restore();
  }

  static void _busRear(Canvas c, double w, double h, Color color, bool braking, int signal, double blink) {
    _p.color = _glass;
    c.drawRRect(RRect.fromLTRBR(5, 4, w - 5, h * 0.3, const Radius.circular(3)), _p);
    _p.color = const Color(0xFFF5F5F5);
    c.drawRect(Rect.fromLTWH(0, h * 0.36, w, 4), _p);
    // Engine vents.
    _p.color = Shapes.shade(color, 0.35);
    for (var y = h * 0.48; y < h * 0.68; y += 3) {
      c.drawRect(Rect.fromLTWH(w * 0.25, y, w * 0.5, 1.4), _p);
    }
    c.save();
    c.translate(0, h * 0.6);
    _rearLights(c, w, h * 0.4, braking: braking, signal: signal, blink: blink);
    c.restore();
  }

  static void _vanFront(Canvas c, double w, double h, bool ambulance) {
    _p.color = _glass;
    c.drawRRect(RRect.fromLTRBR(3, 3, w - 3, h * 0.42, const Radius.circular(4)), _p);
    _p.color = _glassHi;
    c.drawRect(Rect.fromLTWH(w * 0.14, 4, w * 0.1, h * 0.32), _p);
    if (ambulance) {
      _p.color = const Color(0xFFD32F2F);
      c.drawRect(Rect.fromLTWH(0, h * 0.48, w, 4), _p);
      _cross(c, Offset(w / 2, h * 0.7), 6);
    }
  }

  static void _vanRear(Canvas c, double w, double h, bool braking, int signal, double blink, bool ambulance) {
    _p.color = _glass;
    c.drawRect(Rect.fromLTWH(4, 4, w / 2 - 5, h * 0.28), _p);
    c.drawRect(Rect.fromLTWH(w / 2 + 1, 4, w / 2 - 5, h * 0.28), _p);
    _p.color = const Color(0x33000000);
    c.drawRect(Rect.fromLTWH(w / 2 - 0.5, 2, 1, h - 6), _p);
    if (ambulance) _cross(c, Offset(w / 2, h * 0.52), 6);
    c.save();
    c.translate(0, h * 0.55);
    _rearLights(c, w, h * 0.45, braking: braking, signal: signal, blink: blink);
    c.restore();
  }

  static void _cargoRear(Canvas c, double w, double h, bool braking, int signal, double blink) {
    _p.color = const Color(0xFFBDBDBD);
    c.drawRect(Rect.fromLTWH(w / 2 - 0.6, 2, 1.2, h - 10), _p);
    c.drawRect(Rect.fromLTWH(2, 2, w - 4, 1.2), _p);
    _p.color = const Color(0xFF757575);
    for (final x in [w * 0.3, w * 0.7]) {
      c.drawRect(Rect.fromLTWH(x - 0.8, 4, 1.6, h - 14), _p);
    }
    _p.color = const Color(0xFFFF6F00);
    c.drawRect(Rect.fromLTWH(0, h - 9, w, 3), _p);
    c.save();
    c.translate(0, h * 0.7);
    _rearLights(c, w, h * 0.3, braking: braking, signal: signal, blink: blink);
    c.restore();
  }

  static void _cross(Canvas c, Offset center, double r) {
    _p.color = const Color(0xFFD32F2F);
    c.drawRect(Rect.fromCenter(center: center, width: r * 2, height: r * 0.7), _p);
    c.drawRect(Rect.fromCenter(center: center, width: r * 0.7, height: r * 2), _p);
  }

  static void _sirenBar(Canvas c, Size s, double phase) {
    final on = (phase * 2).floor().isEven;
    _p.color = on ? const Color(0xFFFF1744) : const Color(0xFF2979FF);
    c.drawRect(Rect.fromLTWH(0, 0, s.width / 2, s.height), _p);
    _p.color = on ? const Color(0xFF2979FF) : const Color(0xFFFF1744);
    c.drawRect(Rect.fromLTWH(s.width / 2, 0, s.width / 2, s.height), _p);
    _p.color = (on ? const Color(0xFFFF1744) : const Color(0xFF2979FF)).withValues(alpha: 0.35);
    c.drawCircle(Offset(s.width * (on ? 0.25 : 0.75), s.height / 2), 12, _p);
  }

  // ------------------------------------------------------------ side art

  static void _side(Canvas c, Size s, VehicleType type, _Part part, Color color, int variant, bool wheels) {
    final l = s.width;
    final h = s.height;
    switch (part) {
      case _Part.cabin:
        _p.color = _glass;
        c.drawRRect(RRect.fromLTRBR(3, 2, l - 3, h - 1.5, const Radius.circular(3)), _p);
        _p.color = Shapes.shade(color, 0.25);
        c.drawRect(Rect.fromLTWH(l * 0.48, 1, 2.5, h - 1), _p);
      case _Part.upper:
        if (type == VehicleType.bus) {
          _p.color = _glass;
          c.drawRect(Rect.fromLTWH(4, h * 0.14, l - 8, h * 0.3), _p);
          _p.color = Shapes.shade(color, 0.3);
          for (var x = 4.0 + 18; x < l - 4; x += 18) {
            c.drawRect(Rect.fromLTWH(x, h * 0.14, 2, h * 0.3), _p);
          }
          _p.color = const Color(0xFFF5F5F5);
          c.drawRect(Rect.fromLTWH(0, h * 0.5, l, 3), _p);
        } else {
          _p.color = _glass;
          c.drawRect(Rect.fromLTWH(4, h * 0.1, l - 8, h * 0.28), _p);
        }
      case _Part.body when type == VehicleType.jeepney:
        _p.color = _glass;
        c.drawRect(Rect.fromLTWH(3, 6, l - 6, h * 0.28), _p);
        for (var i = 0; i < 3; i++) {
          _p.color = _stripes[(i + variant) % _stripes.length];
          c.drawRect(Rect.fromLTWH(0, h * 0.5 + i * 3.2, l, 2), _p);
        }
      case _Part.cargo:
        _p.color = const Color(0xFFBDBDBD);
        for (var x = 6.0; x < l; x += 9) {
          c.drawRect(Rect.fromLTWH(x, 2, 1.4, h - 8), _p);
        }
        _p.color = const Color(0xFFFF6F00);
        c.drawRect(Rect.fromLTWH(0, h - 8, l, 3), _p);
      case _Part.cab:
        _p.color = _glass;
        c.drawRect(Rect.fromLTWH(3, h * 0.12, l - 6, h * 0.32), _p);
      case _Part.sideCab:
        _p.color = const Color(0xFFFFF8E1);
        c.drawRect(Rect.fromLTWH(4, h * 0.2, l - 8, h * 0.4), _p);
      case _Part.train:
        // Lit windows with doors between them, and the purple line livery.
        for (var x = 6.0; x < l - 14; x += 16) {
          _p.color = const Color(0xFFFFF3C4);
          c.drawRect(Rect.fromLTWH(x, h * 0.16, 11, h * 0.3), _p);
        }
        _p.color = Shapes.shade(color, 0.2);
        c.drawRect(Rect.fromLTWH(l * 0.48, h * 0.12, 8, h * 0.8), _p);
        _p.color = const Color(0xFF7E57C2);
        c.drawRect(Rect.fromLTWH(0, h * 0.56, l, 5), _p);
      case _:
        _p.color = const Color(0x22000000);
        c.drawRect(Rect.fromLTWH(0, h * 0.55, l, 1.5), _p);
    }
    if (wheels) {
      _p.color = _tire;
      final r = math.min(7.0, h * 0.42);
      final positions = l > 40 ? [l * 0.18, l * 0.82] : [l * 0.5];
      for (final x in positions) {
        c.drawOval(Rect.fromCenter(center: Offset(x, h), width: r * 2.2, height: r * 2), _p);
        _p.color = const Color(0xFF9E9E9E);
        c.drawOval(Rect.fromCenter(center: Offset(x, h - 0.5), width: r * 0.9, height: r * 0.8), _p);
        _p.color = _tire;
      }
    }
  }
}
