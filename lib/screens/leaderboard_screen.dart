import 'package:flutter/material.dart';

import '../models/leaderboard_model.dart';
import '../services/app_services.dart';
import '../services/player_profile.dart';
import '../widgets/ui_kit.dart';

/// Every saved run ranked by score or distance, with the top scorer on top.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LeaderboardSort _sort = LeaderboardSort.score;
  bool _bestPerPlayer = false;

  static const _gold = Color(0xFFFFD54F);
  static const _silver = Color(0xFFCFD8DC);
  static const _bronze = Color(0xFFD7965B);

  Future<void> _editName(PlayerProfile profile) async {
    final controller = TextEditingController(text: profile.data.playerName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KColors.panel,
        title: const Text('Rider name', style: TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: Leaderboard.maxNameLength,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Who is riding?'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('SAVE')),
        ],
      ),
    );
    controller.dispose();
    if (name != null) profile.setPlayerName(name);
  }

  Future<void> _confirmClear(PlayerProfile profile) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KColors.panel,
        title: const Text('Clear leaderboard?'),
        content: const Text('All saved runs on this device will be removed. Wallet and bikes are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('CLEAR', style: TextStyle(color: KColors.red)),
          ),
        ],
      ),
    );
    if (ok == true) profile.clearLeaderboard();
  }

  @override
  Widget build(BuildContext context) {
    final profile = AppServices.of(context).profile;
    return ListenableBuilder(
      listenable: profile,
      builder: (context, _) {
        final all = profile.data.leaderboard;
        final rows = _bestPerPlayer
            ? Leaderboard.bestPerPlayer(all, _sort)
            : Leaderboard.sorted(all, _sort);
        final topScorer = all.isEmpty ? null : Leaderboard.sorted(all, LeaderboardSort.score).first;
        final longest = all.isEmpty ? null : Leaderboard.sorted(all, LeaderboardSort.distance).first;
        return KScaffold(
          title: 'LEADERBOARD',
          actions: [
            if (all.isNotEmpty)
              IconButton(
                tooltip: 'Clear leaderboard',
                icon: const Icon(Icons.delete_sweep_rounded),
                onPressed: () => _confirmClear(profile),
              ),
          ],
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    sliver: SliverList.list(
                      children: [
                        _RiderBar(name: profile.data.playerName, onEdit: () => _editName(profile)),
                        const SizedBox(height: 12),
                        if (topScorer != null) ...[
                          _TopScorerCard(entry: topScorer, longest: longest!),
                          const SizedBox(height: 12),
                        ],
                        _controls(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  if (rows.isEmpty)
                    const SliverFillRemaining(hasScrollBody: false, child: _EmptyBoard())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      sliver: SliverList.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, i) => _EntryRow(
                          rank: i + 1,
                          entry: rows[i],
                          sort: _sort,
                          medal: switch (i) {
                            0 => _gold,
                            1 => _silver,
                            2 => _bronze,
                            _ => null,
                          },
                          isYou: rows[i].playerName.toLowerCase() == profile.data.playerName.toLowerCase(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _controls() {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<LeaderboardSort>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: LeaderboardSort.score, label: Text('SCORE')),
              ButtonSegment(value: LeaderboardSort.distance, label: Text('DISTANCE')),
            ],
            selected: {_sort},
            onSelectionChanged: (s) => setState(() => _sort = s.first),
          ),
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Best each'),
          visualDensity: VisualDensity.compact,
          tooltip: 'Show only each rider\'s best run',
          selected: _bestPerPlayer,
          onSelected: (v) => setState(() => _bestPerPlayer = v),
        ),
      ],
    );
  }
}

class _RiderBar extends StatelessWidget {
  const _RiderBar({required this.name, required this.onEdit});

  final String name;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return KPanel(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.person_rounded, color: KColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RIDING AS', style: TextStyle(color: KColors.muted, fontSize: 10, letterSpacing: 2)),
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: KColors.text, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Change rider name',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded, color: KColors.yellow),
          ),
        ],
      ),
    );
  }
}

class _TopScorerCard extends StatelessWidget {
  const _TopScorerCard({required this.entry, required this.longest});

  final LeaderboardEntry entry;
  final LeaderboardEntry longest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF5D4300), Color(0xFF2A2210)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: KColors.yellow, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: KColors.yellow, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOP SCORER',
                      style: TextStyle(color: KColors.yellow, fontSize: 12, letterSpacing: 3, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      entry.playerName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: KColors.text, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatScore(entry.score),
                    style: const TextStyle(color: KColors.yellow, fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const Text('PTS', style: TextStyle(color: KColors.muted, fontSize: 11, letterSpacing: 2)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${formatDistance(entry.distanceMeters)} · ${formatPeso(entry.earnings)} · '
            '${entry.difficultyLabel} · ${entry.bikeName}',
            style: const TextStyle(color: KColors.text, fontSize: 12),
          ),
          if (!identical(longest, entry)) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.route_rounded, color: KColors.muted, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Longest ride: ${longest.playerName} · ${formatDistance(longest.distanceMeters)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: KColors.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.rank,
    required this.entry,
    required this.sort,
    required this.medal,
    required this.isYou,
  });

  final int rank;
  final LeaderboardEntry entry;
  final LeaderboardSort sort;
  final Color? medal;
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    final byScore = sort == LeaderboardSort.score;
    final primary = byScore ? '${formatScore(entry.score)} pts' : formatDistance(entry.distanceMeters);
    final secondary = byScore ? formatDistance(entry.distanceMeters) : '${formatScore(entry.score)} pts';
    return KPanel(
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      border: isYou ? KColors.green.withValues(alpha: 0.7) : null,
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: medal ?? Colors.white10,
              child: Text(
                '$rank',
                style: TextStyle(
                  color: medal != null ? Colors.black : KColors.text,
                  fontWeight: FontWeight.w900,
                  fontSize: rank > 99 ? 11 : 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.playerName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: KColors.text, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                Text(
                  '${entry.difficultyLabel} · ${entry.bikeName} · ${_date(entry.timestamp)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: KColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                primary,
                style: TextStyle(color: medal ?? KColors.text, fontWeight: FontWeight.w900, fontSize: 15),
              ),
              Text(secondary, style: const TextStyle(color: KColors.muted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  static String _date(DateTime t) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[t.month - 1]} ${t.day}, ${t.year}';
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard_rounded, color: KColors.muted, size: 64),
          SizedBox(height: 12),
          Text(
            'No runs yet.\nHit the highway to claim the top spot!',
            textAlign: TextAlign.center,
            style: TextStyle(color: KColors.muted),
          ),
          SizedBox(height: 8),
          Text(
            'Score = meters travelled + pesos earned',
            textAlign: TextAlign.center,
            style: TextStyle(color: KColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
