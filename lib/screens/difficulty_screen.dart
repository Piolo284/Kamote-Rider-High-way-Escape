import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app.dart';
import '../game/difficulty_config.dart';
import '../services/app_services.dart';
import '../widgets/ui_kit.dart';

/// Pick Easy / Medium / Hard before every new run. The last choice is
/// remembered and pre-selected next time.
class DifficultyScreen extends StatefulWidget {
  const DifficultyScreen({super.key});

  @override
  State<DifficultyScreen> createState() => _DifficultyScreenState();
}

class _DifficultyScreenState extends State<DifficultyScreen> {
  DifficultyLevel? _selected;
  bool _starting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selected ??= AppServices.of(context).profile.settings.lastDifficulty;
  }

  void _start() {
    if (_starting) return;
    _starting = true;
    final services = AppServices.of(context);
    services.profile.settings.lastDifficulty = _selected!;
    services.profile.commit();
    Navigator.of(context).pushReplacementNamed(Routes.play, arguments: _selected);
  }

  @override
  Widget build(BuildContext context) {
    return KScaffold(
      title: 'CHOOSE DIFFICULTY',
      child: LayoutBuilder(
        builder: (context, c) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: [
                  for (final config in DifficultyConfig.all)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DifficultyCard(
                        config: config,
                        selected: _selected == config.level,
                        compact: c.maxHeight < 560,
                        onTap: () => setState(() => _selected = config.level),
                      ),
                    ),
                  const Text(
                    'The 10-second LTO chase and crash rules are the same on every difficulty.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: KColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ArcadeButton(
                      label: 'BACK',
                      icon: Icons.arrow_back_rounded,
                      color: const Color(0xFF546E7A),
                      textColor: Colors.white,
                      fontSize: 16,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: ArcadeButton(
                      label: 'START RIDE',
                      icon: Icons.sports_motorsports_rounded,
                      fontSize: 18,
                      onPressed: _selected == null ? null : _start,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard({required this.config, required this.selected, required this.compact, required this.onTap});

  final DifficultyConfig config;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = config.color;
    return Semantics(
      selected: selected,
      button: true,
      label: '${config.label} difficulty',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.16) : KColors.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? color : Colors.white10, width: selected ? 3 : 1.5),
            boxShadow: [if (selected) BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 16)],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: compact ? 84 : 104,
                  child: CustomPaint(painter: _PreviewPainter(config.level)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              config.level == DifficultyLevel.medium ? '${config.label} · DEFAULT' : config.label,
                              style: TextStyle(
                                color: color,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          color: selected ? color : KColors.muted,
                        ),
                      ],
                    ),
                    Text(
                      '"${config.tagline}"',
                      style: const TextStyle(
                        color: KColors.text,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      Text(config.description, style: const TextStyle(color: KColors.muted, fontSize: 12)),
                    ],
                    const SizedBox(height: 6),
                    for (final e in config.effects)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            Icon(Icons.chevron_right_rounded, size: 14, color: color),
                            Expanded(
                              child: Text(e, style: const TextStyle(color: KColors.text, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny road preview: more cars and longer speed streaks on harder levels.
class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.level);

  final DifficultyLevel level;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    final w = size.width;
    final h = size.height;
    p.color = const Color(0xFF4E7D3A);
    canvas.drawRect(Offset.zero & size, p);
    p.color = const Color(0xFF3C4043);
    canvas.drawRect(Rect.fromLTWH(w * 0.12, 0, w * 0.76, h), p);
    p.color = const Color(0xFFFFC400);
    canvas.drawRect(Rect.fromLTWH(w / 2 - 1, 0, 2, h), p);
    p.color = Colors.white70;
    for (var y = 4.0; y < h; y += 16) {
      canvas.drawRect(Rect.fromLTWH(w * 0.31, y, 2, 8), p);
      canvas.drawRect(Rect.fromLTWH(w * 0.69, y, 2, 8), p);
    }
    final cars = switch (level) {
      DifficultyLevel.easy => const [Offset(0.7, 0.2)],
      DifficultyLevel.medium => const [Offset(0.7, 0.15), Offset(0.32, 0.45)],
      DifficultyLevel.hard => const [Offset(0.7, 0.1), Offset(0.32, 0.3), Offset(0.88, 0.45), Offset(0.5, 0.05)],
    };
    const colors = [Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFFFDD835), Color(0xFF8E24AA)];
    for (var i = 0; i < cars.length; i++) {
      p.color = colors[i];
      final c = Offset(cars[i].dx * w - 6, cars[i].dy * h);
      canvas.drawRRect(RRect.fromRectAndRadius(c & const Size(11, 18), const Radius.circular(3)), p);
    }
    // Rider.
    p.color = const Color(0xFFFFC400);
    canvas.drawCircle(Offset(w * 0.6, h * 0.8), 4, p);
    // Speed streaks.
    p.color = Colors.white.withValues(alpha: 0.5);
    final streaks = level.index * 2;
    for (var i = 0; i < streaks; i++) {
      final x = i.isEven ? w * 0.06 : w * 0.94;
      final y = (i * 23 % h).toDouble();
      canvas.drawRect(Rect.fromLTWH(x, y, 1.5, math.min(26, h - y)), p);
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => old.level != level;
}
