import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/kamote_game.dart';
import '../widgets/bike_preview.dart';
import 'general_game_over_overlay.dart';

/// Ending when the tank runs dry: stopped bike and an empty gauge.
class FuelGameOverOverlay extends StatelessWidget {
  const FuelGameOverOverlay({super.key, required this.game});

  final KamoteGame game;

  @override
  Widget build(BuildContext context) {
    return GameOverPanel(
      game: game,
      title: 'OUT OF FUEL!',
      subtitle: 'Your bike coughed, sputtered and rolled to a stop.',
      accent: const Color(0xFFFFAB40),
      background: const Color(0xF0221A0D),
      scene: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.3, end: 0),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            builder: (context, t, child) => Transform.translate(offset: Offset(0, -200 * t), child: child),
            child: BikePreview(bike: game.player.bike, height: 150, animate: false),
          ),
          const SizedBox(width: 150, height: 150, child: _EmptyGauge()),
        ],
      ),
    );
  }
}

class _EmptyGauge extends StatefulWidget {
  const _EmptyGauge();

  @override
  State<_EmptyGauge> createState() => _EmptyGaugeState();
}

class _EmptyGaugeState extends State<_EmptyGauge> with SingleTickerProviderStateMixin {
  // Needle drops from where it was to E, then twitches.
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(painter: _GaugePainter(Curves.bounceOut.transform(_c.value))),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.62);
    final r = size.width * 0.45;
    final p = Paint()..isAntiAlias = true;
    p.color = const Color(0xFF1F2536);
    canvas.drawCircle(c, r + 8, p);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    arc.color = const Color(0xFFFF5252);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r - 6), math.pi, math.pi * 0.25, false, arc);
    arc.color = const Color(0xFFFFCA28);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r - 6), math.pi * 1.25, math.pi * 0.25, false, arc);
    arc.color = const Color(0xFF66BB6A);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r - 6), math.pi * 1.5, math.pi * 0.5, false, arc);

    void label(String s, Offset at, Color color) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }

    label('E', c + Offset(-r + 16, 14), const Color(0xFFFF5252));
    label('F', c + Offset(r - 16, 14), const Color(0xFF66BB6A));

    // Needle sweeps from ~half tank down to empty.
    final angle = math.pi * 1.5 - t * math.pi * 0.5;
    final needle = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c, c + Offset(math.cos(angle), math.sin(angle)) * (r - 14), needle);
    p.color = Colors.white;
    canvas.drawCircle(c, 7, p);
    label('⛽', c + const Offset(0, 30), Colors.white70);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.t != t;
}
