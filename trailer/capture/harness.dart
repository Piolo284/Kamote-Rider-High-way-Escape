// Shared helpers for recording trailer footage from the real game inside
// `flutter test`. Not part of the app or the normal test suite.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/services/app_services.dart';
import 'package:kamote_rider/widgets/ui_kit.dart';

/// Logical screen of a 1080×1920 phone at 2.7× density (the default).
Size logicalSize = const Size(400, 711.12);
double pixelRatio = 2.7;
double fps = 30;

/// Full HD widescreen (1920×1080) for the PC-style gameplay showcase.
void useWidescreen({double frameRate = 60}) {
  logicalSize = const Size(960, 540);
  pixelRatio = 2.0;
  fps = frameRate;
}

/// Portrait phone (1080×1920).
void usePhone({double frameRate = 30}) {
  logicalSize = const Size(400, 711.12);
  pixelRatio = 2.7;
  fps = frameRate;
}

final GlobalKey captureKey = GlobalKey();

String get framesRoot => Platform.environment['TRAILER_FRAMES'] ?? 'build/trailer_frames';

Future<void> loadFonts(WidgetTester tester) async {
  const dir = r'C:\src\flutter\bin\cache\artifacts\material_fonts';
  Future<ByteData> bytes(String name) async => ByteData.sublistView(File('$dir\\$name').readAsBytesSync());
  await tester.runAsync(() async {
    final roboto = FontLoader('Roboto')
      ..addFont(bytes('roboto-regular.ttf'))
      ..addFont(bytes('roboto-medium.ttf'))
      ..addFont(bytes('roboto-bold.ttf'))
      ..addFont(bytes('roboto-black.ttf'))
      // Colour emoji (the 👑 on the results screen).
      ..addFont(Future.value(ByteData.sublistView(File(r'C:\Windows\Fonts\seguiemj.ttf').readAsBytesSync())));
    await roboto.load();
    // Text with no font family falls back to the test font; point that at
    // Roboto too, as on a real Android phone.
    for (final family in ['FlutterTest', 'Ahem']) {
      final fallback = FontLoader(family)
        ..addFont(bytes('roboto-regular.ttf'))
        ..addFont(bytes('roboto-bold.ttf'))
        ..addFont(bytes('roboto-black.ttf'));
      await fallback.load();
    }
    final icons = FontLoader('MaterialIcons')..addFont(bytes('materialicons-regular.otf'));
    await icons.load();
  });
}

void setPhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = logicalSize * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
}

/// Same look as the real app, with [child] as the only screen.
Widget appShell(AppServices services, Widget child) => AppServicesScope(
  services: services,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: KColors.background,
      colorScheme: ColorScheme.fromSeed(seedColor: KColors.yellow, brightness: Brightness.dark, surface: KColors.panel),
      useMaterial3: true,
    ),
    home: RepaintBoundary(
      key: captureKey,
      child: Material(color: Colors.black, child: child),
    ),
  ),
);

/// Writes frames of one shot as numbered PNGs.
class Recorder {
  Recorder(this.shot) {
    if (!enabled) return;
    final dir = Directory('$framesRoot/$shot');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
  }

  final String shot;
  int frames = 0;

  /// TRAILER_ONLY=shot1,shot2 re-records just those shots; the others are
  /// still simulated (so the run stays identical) but not captured.
  bool get enabled {
    final only = Platform.environment['TRAILER_ONLY'];
    return only == null || only.split(',').contains(shot);
  }

  /// Per-frame game state, saved next to the frames so the soundtrack can
  /// follow what happens on screen.
  final List<Map<String, Object?>> events = [];

  Future<void> grab(WidgetTester tester) async {
    final boundary = captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final png = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    File('$framesRoot/$shot/${(frames++).toString().padLeft(5, '0')}.png').writeAsBytesSync(png!);
  }

  /// Advances [seconds] at the trailer frame rate, grabbing every frame.
  Future<void> record(
    WidgetTester tester,
    double seconds, {
    void Function()? each,
    Map<String, Object?> Function()? log,
  }) async {
    final n = (seconds * fps).round();
    for (var i = 0; i < n; i++) {
      each?.call();
      await tester.pump(Duration(microseconds: 1000000 ~/ fps));
      if (!enabled) {
        frames++;
        continue;
      }
      await grab(tester);
      if (log != null) events.add(log());
    }
    if (enabled && events.isNotEmpty) File('$framesRoot/$shot/events.json').writeAsStringSync(jsonEncode(events));
  }
}
