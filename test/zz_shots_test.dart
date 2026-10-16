import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/game/components/highway_entity.dart';
import 'package:kamote_rider/game/components/manhole.dart';
import 'package:kamote_rider/game/components/scenery_prop.dart';
import 'package:kamote_rider/game/components/road_animal.dart';
import 'package:kamote_rider/game/kamote_game.dart';
import 'package:kamote_rider/game/systems/underground_system.dart';
import 'package:kamote_rider/services/app_services.dart';

import 'helpers.dart';

// Temporary dev tool: renders frames to PNG for visual review.
late AppServices services;
const outDir =
    r'C:\Users\CICS_S~1\AppData\Local\Temp\claude\c--GAME-PROG-Kamote-Rider-Highway-Escape-kamote-rider\3dfe2e73-110a-4fc6-a984-a4423de32e7b\scratchpad\shots2';

KamoteGame _create() {
  final game = KamoteGame(
    profile: services.profile,
    missions: services.missions,
    audio: services.audio,
    random: math.Random(4),
    loadSprites: false,
  );
  for (final name in [KamoteGame.hudOverlay, KamoteGame.pauseOverlay, ...KamoteGame.endOverlays]) {
    game.overlays.addEntry(name, (_, _) => const SizedBox());
  }
  return game;
}

Future<void> _run(KamoteGame game, double seconds) async {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    await game.ready();
    game.update(1 / 60);
  }
}

Future<void> _shot(KamoteGame game, String name) async {
  final recorder = PictureRecorder();
  game.render(Canvas(recorder));
  final image = await recorder.endRecording().toImage(game.size.x.toInt(), game.size.y.toInt());
  final bytes = await image.toByteData(format: ImageByteFormat.png);
  File('$outDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  setUp(() async => services = await makeServices());

  testWithGame<KamoteGame>('tunnel', _create, (game) async {
    game.onGameResize(Vector2(400, 860));
    game.fuel.drainPerSecond = 0;
    await _run(game, 12);
    game.world.add(OpenManhole(lane: game.player.lane)..y = game.playerY - 260);
    await _run(game, 0.2);
    await _shot(game, 'a_manhole');
    var guard = 0;
    while (game.underground.phase != UndergroundPhase.falling && guard++ < 200) {
      await _run(game, 1 / 60);
    }
    await _run(game, 0.45);
    await _shot(game, 'b_falling');
    await _run(game, 3);
    await _shot(game, 'c_tunnel');
    game.player.startInvulnerability(1e9);
    await _run(game, 7);
    await _shot(game, 'd_tunnel_traffic');
    for (final c in game.world.children.toList()) {
      if (c is HighwayEntity && c is! SceneryProp) c.removeFromParent();
    }
    await _run(game, 0.1);
    game.spawner.scheduler.reset();
    expect(game.challenges.animals.trySpawn(AnimalKind.pedestrian), isTrue);
    await _run(game, 1.9);
    await _shot(game, 'e_pedestrian');
    await _run(game, 8.2);
    await _shot(game, 'f_exit_light');
    await _run(game, 2.5);
    await _shot(game, 'g_surfaced');
    expect(game.underground.trips, 1);
  });
}
