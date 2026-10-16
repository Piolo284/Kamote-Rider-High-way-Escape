import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/game/difficulty_config.dart';
import 'package:kamote_rider/game/kamote_game.dart';
import 'package:kamote_rider/overlays/ambulance_overlay.dart';
import 'package:kamote_rider/overlays/fuel_game_over_overlay.dart';
import 'package:kamote_rider/overlays/game_hud.dart';
import 'package:kamote_rider/overlays/general_game_over_overlay.dart';
import 'package:kamote_rider/overlays/pause_overlay.dart';
import 'package:kamote_rider/overlays/ticket_jail_overlay.dart';
import 'package:kamote_rider/services/app_services.dart';

import 'helpers.dart';

/// Renders every in-game overlay on real phone sizes to catch layout errors.
void main() {
  final overlays = <String, Widget Function(KamoteGame)>{
    'hud': (g) => GameHud(game: g),
    'pause': (g) => PauseOverlay(game: g),
    'jail': (g) => TicketJailOverlay(game: g),
    'ambulance': (g) => AmbulanceOverlay(game: g),
    'fuel': (g) => FuelGameOverOverlay(game: g),
    'general': (g) => GeneralGameOverOverlay(game: g),
  };

  for (final logical in const [Size(320, 568), Size(393, 851)]) {
    for (final entry in overlays.entries) {
      testWidgets('${entry.key} overlay renders at ${logical.width.toInt()}x${logical.height.toInt()}', (tester) async {
        tester.view.physicalSize = logical * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        late AppServices services;
        late KamoteGame game;
        await tester.runAsync(() async {
          services = await makeServices();
          game = await initializeGame(
            () => KamoteGame(
              profile: services.profile,
              missions: services.missions,
              audio: services.audio,
              random: math.Random(1),
              loadSprites: false,
              autoStart: false,
              difficultyLevel: DifficultyLevel.hard,
            ),
          );
          game.onGameResize(Vector2(logical.width, logical.height));
        });
        // Busy HUD: chase, combo, announcement, meme and toasts at once.
        game.hud
          ..setChase(active: true, remaining: 6.4)
          ..setCombo(7)
          ..setDifficulty('HARD', Colors.red)
          ..setEnvironment('Coastal Highway', Colors.cyan)
          ..announce('LTO CHECKPOINT AHEAD!', 'Keep right (lanes 3–4) to slip through.', Colors.blue)
          ..showMeme('PUSANG LIGAW, REFLEXES MO ANG SUBOK!')
          ..toast('MISSION COMPLETE: Highway Tourist')
          ..toast('CASH STREAK x16! +₱60');
        await tester.pumpWidget(
          AppServicesScope(
            services: services,
            child: MaterialApp(home: Scaffold(body: entry.value(game))),
          ),
        );
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
