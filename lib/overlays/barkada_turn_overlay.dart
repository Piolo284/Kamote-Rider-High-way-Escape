import 'package:flutter/material.dart';

import '../game/kamote_game.dart';
import '../widgets/ui_kit.dart';

/// "Pass the phone" card shown before each Barkada Race turn.
class BarkadaTurnOverlay extends StatelessWidget {
  const BarkadaTurnOverlay({super.key, required this.game});

  final KamoteGame game;

  static const _purple = Color(0xFF7C4DFF);

  void _start() {
    game.overlays.remove(KamoteGame.barkadaTurnOverlay);
    game.startRun();
  }

  @override
  Widget build(BuildContext context) {
    final session = game.barkada!;
    final leader = session.standings.firstOrNull;
    return ColoredBox(
      color: const Color(0xEE10131C),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.groups_rounded, color: _purple, size: 56),
                  const Text(
                    'BARKADA RACE',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: KColors.muted, fontWeight: FontWeight.w900, letterSpacing: 3),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'PLAYER ${session.turn + 1} OF ${session.playerCount}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: KColors.text, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    session.currentName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: KColors.yellow, fontSize: 38, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    session.turn == 0 ? 'You ride first!' : 'Pass the phone to ${session.currentName}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: KColors.muted),
                  ),
                  const SizedBox(height: 16),
                  KPanel(
                    border: _purple.withValues(alpha: 0.6),
                    child: Column(
                      children: [
                        _line('Difficulty', game.difficulty.label),
                        _line('Bike', game.profile.selectedBike.name),
                        if (leader != null) _line('Score to beat', '${leader.$1}: ${formatScore(leader.$2.score)}'),
                        const SizedBox(height: 6),
                        const Text(
                          'Same highway for everyone. One run each, no restarts. Highest score wins!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: KColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  ArcadeButton(
                    label: 'START',
                    icon: Icons.play_arrow_rounded,
                    height: 64,
                    fontSize: 26,
                    onPressed: _start,
                  ),
                  const SizedBox(height: 10),
                  ArcadeButton(
                    label: 'QUIT RACE',
                    icon: Icons.home_rounded,
                    color: const Color(0xFF546E7A),
                    textColor: Colors.white,
                    fontSize: 15,
                    onPressed: game.onExitToMenu,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: KColors.muted)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: KColors.text, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}
