import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ui_kit.dart';

/// Celebration popup shown after claiming a mission reward: spinning sun
/// rays, a coin burst, a counting reward amount and the next level preview.
Future<void> showMissionClaimedPopup(
  BuildContext context, {
  required String missionTitle,
  required int reward,
  required int walletAfter,
  required String nextGoal,
  required int nextLevel,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Reward claimed',
    barrierColor: Colors.black.withValues(alpha: 0.75),
    transitionDuration: const Duration(milliseconds: 550),
    pageBuilder: (context, _, _) => _MissionClaimedPopup(
      missionTitle: missionTitle,
      reward: reward,
      walletAfter: walletAfter,
      nextGoal: nextGoal,
      nextLevel: nextLevel,
    ),
    transitionBuilder: (context, animation, _, child) {
      final pop = CurvedAnimation(parent: animation, curve: Curves.elasticOut, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.4)),
        child: ScaleTransition(scale: Tween(begin: 0.4, end: 1.0).animate(pop), child: child),
      );
    },
  );
}

class _MissionClaimedPopup extends StatefulWidget {
  const _MissionClaimedPopup({
    required this.missionTitle,
    required this.reward,
    required this.walletAfter,
    required this.nextGoal,
    required this.nextLevel,
  });

  final String missionTitle;
  final int reward;
  final int walletAfter;
  final String nextGoal;
  final int nextLevel;

  @override
  State<_MissionClaimedPopup> createState() => _MissionClaimedPopupState();
}

class _MissionClaimedPopupState extends State<_MissionClaimedPopup> with TickerProviderStateMixin {
  // Continuous spin for the sun rays.
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 8))
    ..repeat();

  // One-shot timeline: coin burst, count-up, staggered text.
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..forward();

  static const _cheers = ['SULIT, IDOL!', 'PETMALU!', 'LODI KA TALAGA!', 'YAMAN MO NA!', 'PANALO!'];
  late final String _cheer = _cheers[math.Random().nextInt(_cheers.length)];

  @override
  void dispose() {
    _spin.dispose();
    _intro.dispose();
    super.dispose();
  }

  Animation<double> _stagger(double start, double end, [Curve curve = Curves.easeOutBack]) => CurvedAnimation(
    parent: _intro,
    curve: Interval(start, end, curve: curve),
  );

  Widget _rise(double start, Widget child) {
    final a = _stagger(start, math.min(1, start + 0.3));
    return AnimatedBuilder(
      animation: a,
      builder: (context, child) => Opacity(
        opacity: a.value.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 18 * (1 - a.value)), child: child),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _stagger(0.15, 0.7, Curves.easeOutCubic);
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 70),
                  padding: const EdgeInsets.fromLTRB(20, 84, 20, 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF2A3247), KColors.panel],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: KColors.yellow, width: 3),
                    boxShadow: [BoxShadow(color: KColors.yellow.withValues(alpha: 0.35), blurRadius: 30)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _rise(
                        0.05,
                        const Text(
                          'MISSION CLAIMED!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: KColors.yellow,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _rise(
                        0.12,
                        Text(
                          widget.missionTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: KColors.text, fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Reward counting up, with a little punch when it lands.
                      AnimatedBuilder(
                        animation: count,
                        builder: (context, _) {
                          final landed = count.value >= 1;
                          return AnimatedScale(
                            scale: landed ? 1.12 : 1,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutBack,
                            child: Text(
                              '+${formatPeso((widget.reward * count.value).round())}',
                              style: const TextStyle(
                                color: Color(0xFF69F0AE),
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                shadows: [Shadow(color: Colors.black54, offset: Offset(2, 3), blurRadius: 4)],
                              ),
                            ),
                          );
                        },
                      ),
                      _rise(
                        0.55,
                        Text(
                          'Wallet: ${formatPeso(widget.walletAfter)}',
                          style: const TextStyle(color: KColors.muted, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _rise(
                        0.6,
                        Transform.rotate(
                          angle: -0.04,
                          child: Text(
                            _cheer,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _rise(
                        0.68,
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: KColors.blue.withValues(alpha: 0.6)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'NEXT: LEVEL ${widget.nextLevel}',
                                style: const TextStyle(color: KColors.blue, fontSize: 11, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.nextGoal,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: KColors.text, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _rise(
                        0.75,
                        ArcadeButton(
                          label: 'COLLECT',
                          icon: Icons.check_rounded,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
                // Medallion with spinning rays and a coin burst.
                SizedBox(
                  width: 170,
                  height: 170,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      RotationTransition(
                        turns: _spin,
                        child: const CustomPaint(size: Size(170, 170), painter: _RaysPainter()),
                      ),
                      AnimatedBuilder(
                        animation: _intro,
                        builder: (context, _) =>
                            CustomPaint(size: const Size(170, 170), painter: _CoinBurstPainter(_intro.value)),
                      ),
                      ScaleTransition(
                        scale: _stagger(0, 0.35, Curves.elasticOut),
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(colors: [Color(0xFFFFE082), Color(0xFFFFA000)]),
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))],
                          ),
                          child: const Icon(Icons.emoji_events_rounded, color: Color(0xFF6D4C00), size: 48),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Alternating translucent gold rays behind the medallion.
class _RaysPainter extends CustomPainter {
  const _RaysPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final p = Paint();
    const rays = 14;
    for (var i = 0; i < rays; i++) {
      final a0 = i * 2 * math.pi / rays;
      final a1 = a0 + math.pi / rays;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a0) * r, c.dy + math.sin(a0) * r)
        ..lineTo(c.dx + math.cos(a1) * r, c.dy + math.sin(a1) * r)
        ..close();
      p.color = (i.isEven ? KColors.yellow : Colors.white).withValues(alpha: 0.22);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter oldDelegate) => false;
}

/// Coins that burst out of the medallion and fall away.
class _CoinBurstPainter extends CustomPainter {
  _CoinBurstPainter(this.t);

  final double t;
  static const int _coins = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final burst = (t / 0.6).clamp(0.0, 1.0);
    if (burst <= 0 || burst >= 1) return;
    final c = size.center(Offset.zero);
    final fill = Paint();
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFB8860B);
    for (var i = 0; i < _coins; i++) {
      final a = i * 2 * math.pi / _coins + (i.isEven ? 0.15 : -0.1);
      final dist = 30 + (60 + (i % 3) * 18) * Curves.easeOutCubic.transform(burst);
      final gravity = 70 * burst * burst;
      final pos = c + Offset(math.cos(a) * dist, math.sin(a) * dist + gravity);
      final flip = math.cos(burst * 12 + i).abs();
      fill.color = const Color(0xFFFFD54F).withValues(alpha: 1 - burst);
      final rect = Rect.fromCenter(center: pos, width: 12 * flip + 2, height: 12);
      canvas.drawOval(rect, fill);
      canvas.drawOval(rect, rim);
    }
  }

  @override
  bool shouldRepaint(_CoinBurstPainter old) => old.t != t;
}
