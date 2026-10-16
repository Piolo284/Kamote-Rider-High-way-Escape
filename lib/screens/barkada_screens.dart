import 'package:flutter/material.dart';

import '../app.dart';
import '../game/difficulty_config.dart';
import '../models/barkada_model.dart';
import '../models/leaderboard_model.dart';
import '../services/app_services.dart';
import '../widgets/ui_kit.dart';

const _purple = Color(0xFF7C4DFF);

/// Sets up a Barkada Race: 2–4 friends take turns on one phone.
class BarkadaSetupScreen extends StatefulWidget {
  const BarkadaSetupScreen({super.key});

  @override
  State<BarkadaSetupScreen> createState() => _BarkadaSetupScreenState();
}

class _BarkadaSetupScreenState extends State<BarkadaSetupScreen> {
  final List<TextEditingController> _names = List.generate(BarkadaSession.maxPlayers, (_) => TextEditingController());
  int _count = 2;
  DifficultyLevel? _difficulty;
  bool _starting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_difficulty != null) return;
    final profile = AppServices.of(context).profile;
    _difficulty = profile.settings.lastDifficulty;
    _names[0].text = profile.data.playerName;
    for (var i = 1; i < _names.length; i++) {
      _names[i].text = 'Player ${i + 1}';
    }
  }

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  /// Clean names, with duplicates numbered so the standings stay clear.
  List<String> _playerNames() {
    final used = <String, int>{};
    return [
      for (var i = 0; i < _count; i++)
        () {
          final base = Leaderboard.cleanName(_names[i].text.trim().isEmpty ? 'Player ${i + 1}' : _names[i].text);
          final n = used.update(base.toLowerCase(), (v) => v + 1, ifAbsent: () => 1);
          return n == 1 ? base : Leaderboard.cleanName('$base $n');
        }(),
    ];
  }

  void _start() {
    if (_starting) return;
    _starting = true;
    final session = BarkadaSession(names: _playerNames(), difficulty: _difficulty!);
    Navigator.of(context).pushReplacementNamed(Routes.play, arguments: session);
  }

  @override
  Widget build(BuildContext context) {
    final bike = AppServices.of(context).profile.selectedBike;
    return KScaffold(
      title: 'BARKADA RACE',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Text(
            'Pass-and-play multiplayer: everyone rides the same highway, one run each. '
            'Highest score wins, and every run goes on the leaderboard.',
            textAlign: TextAlign.center,
            style: TextStyle(color: KColors.muted),
          ),
          const SizedBox(height: 16),
          const _Label('PLAYERS'),
          Row(
            children: [
              for (var n = BarkadaSession.minPlayers; n <= BarkadaSession.maxPlayers; n++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: SizedBox(
                        width: double.infinity,
                        child: Text('$n', textAlign: TextAlign.center),
                      ),
                      selected: _count == n,
                      selectedColor: _purple,
                      onSelected: (_) => setState(() => _count = n),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _names[i],
                maxLength: Leaderboard.maxNameLength,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Player ${i + 1}',
                  counterText: '',
                  prefixIcon: Icon(Icons.person_rounded, color: i == 0 ? KColors.yellow : _purple),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          const SizedBox(height: 8),
          const _Label('DIFFICULTY'),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final config in DifficultyConfig.all)
                ChoiceChip(
                  label: Text(config.label),
                  selected: _difficulty == config.level,
                  selectedColor: config.color.withValues(alpha: 0.6),
                  onSelected: (_) => setState(() => _difficulty = config.level),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Everyone rides your selected bike: ${bike.name}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: KColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ArcadeButton(label: 'START RACE', icon: Icons.flag_rounded, height: 64, fontSize: 24, onPressed: _start),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(color: KColors.muted, fontWeight: FontWeight.w900, letterSpacing: 2),
    ),
  );
}

/// Final standings after every friend has ridden.
class BarkadaResultsScreen extends StatelessWidget {
  const BarkadaResultsScreen({super.key, required this.session});

  final BarkadaSession session;

  static const _medals = [Color(0xFFFFD54F), Color(0xFFCFD8DC), Color(0xFFD7965B)];

  @override
  Widget build(BuildContext context) {
    final standings = session.standings;
    final winner = standings.firstOrNull;
    return KScaffold(
      title: 'RACE RESULTS',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Icon(Icons.emoji_events_rounded, color: KColors.yellow, size: 72),
          if (winner != null) ...[
            const Text(
              'WINNER',
              textAlign: TextAlign.center,
              style: TextStyle(color: KColors.muted, fontWeight: FontWeight.w900, letterSpacing: 3),
            ),
            Text(
              winner.$1,
              textAlign: TextAlign.center,
              style: const TextStyle(color: KColors.yellow, fontSize: 34, fontWeight: FontWeight.w900),
            ),
            Text(
              '${formatScore(winner.$2.score)} points',
              textAlign: TextAlign.center,
              style: const TextStyle(color: KColors.text, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 16),
          for (var i = 0; i < standings.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: KPanel(
                border: (i < _medals.length ? _medals[i] : _purple).withValues(alpha: 0.6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: i < _medals.length ? _medals[i] : KColors.panelLight,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            standings[i].$1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: KColors.text, fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                          Text(
                            '${formatDistance(standings[i].$2.distanceMeters)} · ${formatPeso(standings[i].$2.earnings)}'
                            '${standings[i].$2.tunnelTrips > 0 ? ' · tunnel x${standings[i].$2.tunnelTrips}' : ''}'
                            '\n${standings[i].$2.ending}',
                            style: const TextStyle(color: KColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatScore(standings[i].$2.score),
                      style: const TextStyle(color: KColors.yellow, fontWeight: FontWeight.w900, fontSize: 20),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          ArcadeButton(
            label: 'REMATCH',
            icon: Icons.replay_rounded,
            onPressed: () => Navigator.of(context).pushReplacementNamed(Routes.play, arguments: session.rematch()),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ArcadeButton(
                  label: 'RANKS',
                  icon: Icons.leaderboard_rounded,
                  color: const Color(0xFFF57C00),
                  textColor: Colors.white,
                  fontSize: 15,
                  onPressed: () => Navigator.of(context).pushReplacementNamed(Routes.leaderboard),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ArcadeButton(
                  label: 'MENU',
                  icon: Icons.home_rounded,
                  color: const Color(0xFF546E7A),
                  textColor: Colors.white,
                  fontSize: 15,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
