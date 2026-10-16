import 'package:flutter/material.dart';

import '../game/kamote_game.dart';
import '../widgets/ui_kit.dart';

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.game});

  final KamoteGame game;

  @override
  Widget build(BuildContext context) {
    final chase = game.chase;
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: KPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.pause_circle_filled_rounded, color: KColors.yellow, size: 56),
                  const Text(
                    'PAUSED',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: KColors.text, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 3),
                  ),
                  const SizedBox(height: 12),
                  _row('Distance', formatDistance(game.distance.meters)),
                  _row('Run earnings', formatPeso(game.rewards.runEarnings)),
                  _row('Fuel', '${(game.fuel.fraction * 100).round()}%'),
                  if (chase.active) _row('LTO chase', '${chase.remaining.toStringAsFixed(1)}s left (frozen)'),
                  const SizedBox(height: 18),
                  ArcadeButton(label: 'RESUME', icon: Icons.play_arrow_rounded, onPressed: game.resumeRun),
                  const SizedBox(height: 10),
                  ArcadeButton(
                    label: 'RESTART',
                    icon: Icons.replay_rounded,
                    color: KColors.blue,
                    textColor: Colors.white,
                    fontSize: 17,
                    onPressed: game.restartRun,
                  ),
                  const SizedBox(height: 10),
                  ArcadeButton(
                    label: 'MAIN MENU',
                    icon: Icons.home_rounded,
                    color: const Color(0xFF546E7A),
                    textColor: Colors.white,
                    fontSize: 17,
                    onPressed: game.exitToMenu,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Quitting keeps the money you collected this run.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: KColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: KColors.muted)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(color: KColors.text, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
