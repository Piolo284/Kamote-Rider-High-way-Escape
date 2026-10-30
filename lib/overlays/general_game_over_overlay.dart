import 'package:flutter/material.dart';

import '../game/kamote_game.dart';
import '../widgets/ui_kit.dart';

/// Shared results card + buttons used by every ending. Each ending supplies
/// its own [scene] and colors so the three endings look distinct.
class GameOverPanel extends StatelessWidget {
  const GameOverPanel({
    super.key,
    required this.game,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.scene,
    this.background = const Color(0xF0141824),
  });

  final KamoteGame game;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget scene;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final summary = game.lastSummary;
    final result = summary?.result;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: ColoredBox(
        color: background,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 190, child: scene),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: accent, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2),
                    ),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: KColors.muted),
                    ),
                    const SizedBox(height: 14),
                    KPanel(
                      border: accent.withValues(alpha: 0.5),
                      child: Column(
                        children: [
                          if (summary?.isTopScore == true) _badge('NEW TOP SCORER!', const Color(0xFFFF9800)),
                          if (summary?.isNewBest == true) _badge('NEW BEST DISTANCE!', KColors.yellow),
                          _line('Difficulty', result?.difficultyLabel ?? game.difficulty.label),
                          _line('Distance', formatDistance(result?.distanceMeters ?? game.distance.meters), big: true),
                          const Divider(),
                          _line('Paper bills (${result?.billsCollected ?? 0})', formatPeso(result?.billCash ?? 0)),
                          _line('Distance milestones', formatPeso(result?.milestoneCash ?? 0)),
                          _line('LTO escape bonus', formatPeso(result?.chaseBonusCash ?? 0)),
                          _line(
                            'Near misses & streaks${(result?.bestCombo ?? 0) > 1 ? ' (best x${result!.bestCombo})' : ''}',
                            formatPeso(result?.skillBonusCash ?? 0),
                          ),
                          _line(
                            'Challenges cleared (${result?.challengesCompleted ?? 0})',
                            formatPeso(result?.challengeCash ?? 0),
                          ),
                          const Divider(),
                          _line('Money collected', formatPeso(result?.grossEarnings ?? 0)),
                          _line('Spent on gas & boosters', '-${formatPeso(result?.spentCash ?? 0)}'),
                          _line(
                            'Violation penalties (${result?.violations ?? 0})',
                            '-${formatPeso(result?.penaltyCash ?? 0)}',
                            color: (result?.penaltyCash ?? 0) > 0 ? const Color(0xFFFF8A80) : KColors.text,
                          ),
                          const Divider(),
                          _line(
                            'Final money earned',
                            formatPeso(result?.totalEarnings ?? 0),
                            big: true,
                            color: KColors.yellow,
                          ),
                          _line('Wallet balance', formatPeso(summary?.walletAfter ?? game.profile.data.wallet)),
                          const Divider(),
                          _line('Violations committed', '${result?.violations ?? game.violations.count}'),
                          _line('Highest LTO pursuit', _pursuitText(result?.maxPursuitLevel ?? game.pursuit.maxLevel)),
                          _line('Best distance record', formatDistance(game.profile.data.bestDistance)),
                          if (result != null) ...[
                            const Divider(),
                            _line(
                              'Score (${game.barkada?.currentName ?? game.profile.data.playerName})',
                              formatScore(result.score),
                              big: true,
                              color: KColors.yellow,
                            ),
                            if (summary?.leaderboardRank case final rank?)
                              _line('Leaderboard rank', '#$rank${rank == 1 ? ' 👑' : ''}'),
                          ],
                          if (result != null && result.missionsCompleted.isNotEmpty) ...[
                            const Divider(),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Missions completed: ${result.missionsCompleted.join(', ')}\nClaim rewards in Missions.',
                                style: const TextStyle(
                                  color: Color(0xFFFFD740),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (game.barkada case final session?) ...[
                      ArcadeButton(
                        label: session.isLastTurn ? 'SEE RESULTS' : 'NEXT: ${session.names[session.turn + 1]}',
                        icon: session.isLastTurn ? Icons.emoji_events_rounded : Icons.skip_next_rounded,
                        onPressed: game.onBarkadaNext,
                      ),
                      const SizedBox(height: 10),
                      ArcadeButton(
                        label: 'QUIT RACE',
                        icon: Icons.home_rounded,
                        color: const Color(0xFF546E7A),
                        textColor: Colors.white,
                        fontSize: 15,
                        onPressed: game.exitToMenu,
                      ),
                    ] else ...[
                      ArcadeButton(label: 'RETRY', icon: Icons.replay_rounded, onPressed: game.restartRun),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ArcadeButton(
                              label: 'GARAGE',
                              icon: Icons.garage_rounded,
                              color: KColors.blue,
                              textColor: Colors.white,
                              fontSize: 15,
                              onPressed: game.openGarage,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ArcadeButton(
                              label: 'LEADERBOARD',
                              icon: Icons.leaderboard_rounded,
                              color: const Color(0xFFF57C00),
                              textColor: Colors.white,
                              fontSize: 13,
                              onPressed: game.openLeaderboard,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ArcadeButton(
                        label: 'MAIN MENU',
                        icon: Icons.home_rounded,
                        color: const Color(0xFF546E7A),
                        textColor: Colors.white,
                        fontSize: 15,
                        onPressed: game.exitToMenu,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _pursuitText(int level) => level == 0 ? 'None' : '$level officer${level == 1 ? '' : 's'}';

  Widget _badge(String text, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
    child: Text(
      text,
      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
    ),
  );

  Widget _line(String label, String value, {bool big = false, Color color = KColors.text}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: KColors.muted, fontSize: big ? 15 : 13),
          ),
        ),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: big ? 20 : 14),
        ),
      ],
    ),
  );
}

/// Fallback ending (e.g. a quit run) using the shared panel.
class GeneralGameOverOverlay extends StatelessWidget {
  const GeneralGameOverOverlay({super.key, required this.game});

  final KamoteGame game;

  @override
  Widget build(BuildContext context) {
    return GameOverPanel(
      game: game,
      title: 'GAME OVER',
      subtitle: 'The highway will be waiting.',
      accent: KColors.yellow,
      scene: const Icon(Icons.sports_motorsports_rounded, size: 120, color: KColors.yellow),
    );
  }
}
