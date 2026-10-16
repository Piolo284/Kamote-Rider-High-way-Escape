import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../game/difficulty_config.dart';
import '../game/kamote_game.dart';
import '../models/barkada_model.dart';
import '../overlays/barkada_turn_overlay.dart';
import '../overlays/ambulance_overlay.dart';
import '../overlays/fuel_game_over_overlay.dart';
import '../overlays/game_hud.dart';
import '../overlays/general_game_over_overlay.dart';
import '../overlays/pause_overlay.dart';
import '../overlays/ticket_jail_overlay.dart';
import '../services/app_services.dart';
import '../widgets/ui_kit.dart';

/// Hosts one [KamoteGame] instance for as long as the route is open.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.difficulty, this.barkada});

  /// Difficulty chosen on the difficulty screen (defaults to the last one).
  final DifficultyLevel? difficulty;

  /// Set when this screen hosts one turn of a Barkada Race.
  final BarkadaSession? barkada;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  KamoteGame? _game;
  bool _leaving = false;

  // Swipe tracking.
  static const double _swipeStep = 26;
  double _dragAccum = 0;
  int _stepsThisDrag = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_game != null) return;
    final services = AppServices.of(context);
    _game =
        KamoteGame(
            profile: services.profile,
            missions: services.missions,
            audio: services.audio,
            difficultyLevel: widget.difficulty,
            barkada: widget.barkada,
            // Barkada turns start when the next player taps START.
            autoStart: widget.barkada == null,
          )
          ..onExitToMenu = _leaveToMenu
          ..onOpenGarage = _leaveToGarage
          ..onBarkadaNext = _nextBarkadaTurn;
  }

  void _leaveToMenu() {
    if (_leaving || !mounted) return;
    _leaving = true;
    Navigator.of(context).pop();
  }

  void _leaveToGarage() {
    if (_leaving || !mounted) return;
    _leaving = true;
    Navigator.of(context).pushReplacementNamed(Routes.garage);
  }

  void _nextBarkadaTurn() {
    final session = widget.barkada;
    if (_leaving || !mounted || session == null) return;
    _leaving = true;
    final nav = Navigator.of(context);
    if (session.advance()) {
      nav.pushReplacementNamed(Routes.play, arguments: session);
    } else {
      nav.pushReplacementNamed(Routes.barkadaResults, arguments: session);
    }
  }

  @override
  void dispose() {
    _game?.shutdown();
    super.dispose();
  }

  void _onBack() {
    final game = _game!;
    if (game.state.isPlaying) {
      game.pauseRun();
    } else if (game.state.isPaused) {
      game.resumeRun();
    } else if (game.state.isOver) {
      game.exitToMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = _game!;
    game.setSafeTop(MediaQuery.paddingOf(context).top);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {
            _dragAccum = 0;
            _stepsThisDrag = 0;
          },
          onHorizontalDragUpdate: (d) {
            _dragAccum += d.delta.dx;
            // Each threshold crossed mid-drag is one lane, so steering
            // responds before the finger lifts.
            while (_dragAccum.abs() >= _swipeStep) {
              final dir = _dragAccum.sign.toInt();
              game.steer(dir);
              _dragAccum -= dir * _swipeStep;
              _stepsThisDrag++;
            }
          },
          onHorizontalDragEnd: (d) {
            // A quick flick shorter than the threshold still counts.
            final v = d.primaryVelocity ?? 0;
            if (_stepsThisDrag == 0 && v.abs() > 250) game.steer(v.sign.toInt());
          },
          child: GameWidget<KamoteGame>(
            game: game,
            loadingBuilder: (_) => const _Loading(),
            initialActiveOverlays: widget.barkada != null ? const [KamoteGame.barkadaTurnOverlay] : const [],
            overlayBuilderMap: {
              KamoteGame.barkadaTurnOverlay: (context, g) => BarkadaTurnOverlay(game: g),
              KamoteGame.hudOverlay: (context, g) => GameHud(game: g),
              KamoteGame.pauseOverlay: (context, g) => PauseOverlay(game: g),
              KamoteGame.jailOverlay: (context, g) => TicketJailOverlay(game: g),
              KamoteGame.ambulanceOverlay: (context, g) => AmbulanceOverlay(game: g),
              KamoteGame.fuelOverlay: (context, g) => FuelGameOverOverlay(game: g),
              KamoteGame.gameOverOverlay: (context, g) => GeneralGameOverOverlay(game: g),
            },
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: KColors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: KColors.yellow),
            SizedBox(height: 16),
            Text(
              'Warming up the engine...',
              style: TextStyle(color: KColors.muted, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
