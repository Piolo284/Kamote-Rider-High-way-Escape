import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../app.dart';
import '../game/difficulty_config.dart';
import '../game/kamote_game.dart';
import '../game/systems/swipe_steering.dart';
import '../game/systems/tilt_steering.dart';
import '../models/barkada_model.dart';
import '../overlays/barkada_turn_overlay.dart';
import '../overlays/ambulance_overlay.dart';
import '../overlays/fuel_game_over_overlay.dart';
import '../overlays/game_hud.dart';
import '../overlays/general_game_over_overlay.dart';
import '../overlays/pause_overlay.dart';
import '../overlays/shop_overlay.dart';
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

  late final SwipeSteering _swipe = SwipeSteering(onSteer: (dir) => _game!.steer(dir));

  late final TiltSteering _tilt = TiltSteering(onSteer: (dir) => _game!.steer(dir));
  StreamSubscription<AccelerometerEvent>? _tiltSub;
  DateTime? _lastTilt;
  bool _tiltWasPlaying = false;

  /// Listens to the accelerometer only while tilt steering is switched on.
  void _startTilt() {
    if (_tiltSub != null || !_game!.profile.settings.tiltSteering) return;
    try {
      _tiltSub = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
        _onTilt,
        // No sensor (emulator, desktop): swipe and buttons still work.
        onError: (Object _) => _stopTilt(),
        cancelOnError: true,
      );
    } catch (_) {
      _tiltSub = null;
    }
  }

  void _stopTilt() {
    _tiltSub?.cancel();
    _tiltSub = null;
  }

  void _onTilt(AccelerometerEvent e) {
    final game = _game!;
    final playing = game.state.isPlaying;
    if (!playing) {
      _tiltWasPlaying = false;
      return;
    }
    // Each new ride and each resume takes the current grip as level.
    if (!_tiltWasPlaying) _tilt.recenter();
    _tiltWasPlaying = true;
    final now = e.timestamp;
    final dt = _lastTilt == null ? 0.02 : (now.difference(_lastTilt!).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _lastTilt = now;
    _tilt
      ..rangeDegrees = game.profile.settings.tiltRange
      ..update(TiltSteering.rollDegrees(e.x, e.y, e.z), dt, currentLane: game.player.lane);
  }

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
          ..onOpenLeaderboard = _leaveToLeaderboard
          ..onBarkadaNext = _nextBarkadaTurn;
    _startTilt();
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

  void _leaveToLeaderboard() {
    if (_leaving || !mounted) return;
    _leaving = true;
    Navigator.of(context).pushReplacementNamed(Routes.leaderboard);
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
    _stopTilt();
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
          onHorizontalDragStart: (_) => _swipe
            ..sensitivity = game.profile.settings.steerSensitivity
            ..start(),
          onHorizontalDragUpdate: (d) => _swipe.update(d.delta.dx),
          onHorizontalDragEnd: (d) => _swipe.end(d.primaryVelocity ?? 0),
          child: GameWidget<KamoteGame>(
            game: game,
            loadingBuilder: (_) => const _Loading(),
            initialActiveOverlays: widget.barkada != null ? const [KamoteGame.barkadaTurnOverlay] : const [],
            overlayBuilderMap: {
              KamoteGame.barkadaTurnOverlay: (context, g) => BarkadaTurnOverlay(game: g),
              KamoteGame.hudOverlay: (context, g) => GameHud(game: g),
              KamoteGame.pauseOverlay: (context, g) => PauseOverlay(game: g),
              KamoteGame.shopOverlay: (context, g) => ShopOverlay(game: g),
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
