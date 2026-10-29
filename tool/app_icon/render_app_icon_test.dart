// Renders the Android launcher icon from the game's own art: the starter
// Kamote 110 drawn by BikePainter on a highway in the menu colors.
//
//   flutter test tool/app_icon/render_app_icon_test.dart
//
// Writes the legacy and adaptive icon PNGs into android/app/src/main/res/,
// plus a 512 px preview in build/app_icon/. Not part of the normal test suite.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/game/painting/bike_painter.dart';
import 'package:kamote_rider/models/motorcycle_model.dart';
import 'package:kamote_rider/widgets/ui_kit.dart';

const _res = 'android/app/src/main/res';
const _densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};

final _bike = MotorcycleCatalog.byId(MotorcycleCatalog.starterId);

/// The highway seen from above, filling a square of side [s].
void _paintRoad(Canvas c, double s) {
  c.drawRect(Offset.zero & Size(s, s), Paint()..color = KColors.background);
  c.drawRect(Rect.fromLTWH(s * 0.18, 0, s * 0.64, s), Paint()..color = const Color(0xFF2B303D));
  final edge = Paint()..color = KColors.text.withValues(alpha: 0.85);
  c.drawRect(Rect.fromLTWH(s * 0.2, 0, s * 0.016, s), edge);
  c.drawRect(Rect.fromLTWH(s * 0.784, 0, s * 0.016, s), edge);
  final dash = Paint()..color = KColors.yellow;
  for (final x in [0.37, 0.614]) {
    for (var y = -s * 0.06; y < s; y += s * 0.2) {
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(s * x, y, s * 0.016, s * 0.11), Radius.circular(s * 0.008)),
        dash,
      );
    }
  }
}

/// The rider, centred, [h] tall, with speed streaks beside it.
void _paintRider(Canvas c, double s, double h) {
  final w = h / 2;
  final streak = Paint()
    ..color = KColors.text.withValues(alpha: 0.35)
    ..strokeWidth = s * 0.012
    ..strokeCap = StrokeCap.round;
  for (final (x, y, len) in [(-0.62, 0.05, 0.22), (-0.52, 0.32, 0.16), (0.62, 0.12, 0.2), (0.54, 0.38, 0.14)]) {
    final dx = s / 2 + x * w * 1.6;
    final dy = s / 2 + y * h;
    c.drawLine(Offset(dx, dy), Offset(dx, dy + len * h), streak);
  }
  c.save();
  c.translate(s / 2, s / 2 + h * 0.06);
  c.rotate(-6 * math.pi / 180);
  c.translate(-w / 2, -h / 2);
  BikePainter.paint(c, Size(w, h), _bike, beam: true);
  c.restore();
}

/// Full icon for launchers without adaptive icons: rounded square, yellow rim.
void _paintLegacy(Canvas c, double s) {
  final shape = RRect.fromRectAndRadius(Offset.zero & Size(s, s), Radius.circular(s * 0.2));
  c.save();
  c.clipRRect(shape);
  _paintRoad(c, s);
  _paintRider(c, s, s * 0.66);
  c.restore();
  c.drawRRect(
    shape.deflate(s * 0.02),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.04
      ..color = KColors.yellow,
  );
}

Future<void> _write(WidgetTester tester, String path, int px, void Function(Canvas, double) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder), px.toDouble());
  final picture = recorder.endRecording();
  final png = await tester.runAsync(() async {
    final image = await picture.toImage(px, px);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!);
}

void main() {
  testWidgets('render the launcher icon', (tester) async {
    for (final MapEntry(key: name, value: scale) in _densities.entries) {
      final dir = '$_res/mipmap-$name';
      await _write(tester, '$dir/ic_launcher.png', (48 * scale).round(), _paintLegacy);
      // Adaptive layers are 108 dp; launchers mask them and keep the middle 66 dp.
      final layer = (108 * scale).round();
      await _write(tester, '$dir/ic_launcher_background.png', layer, _paintRoad);
      await _write(tester, '$dir/ic_launcher_foreground.png', layer, (c, s) => _paintRider(c, s, s * 0.5));
    }
    await _write(tester, 'build/app_icon/icon_512.png', 512, _paintLegacy);
    await _write(tester, 'build/app_icon/adaptive_preview_512.png', 512, (c, s) {
      c.clipPath(Path()..addOval(Rect.fromCircle(center: Offset(s / 2, s / 2), radius: s * 0.5 * 66 / 108 * 1.5)));
      _paintRoad(c, s);
      _paintRider(c, s, s * 0.5);
    });
  });
}
