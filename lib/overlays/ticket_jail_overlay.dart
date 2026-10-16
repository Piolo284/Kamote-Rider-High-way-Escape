import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/kamote_game.dart';
import '../widgets/bike_preview.dart';
import '../widgets/ui_kit.dart';
import 'general_game_over_overlay.dart';

/// Ending for a second collision during an LTO chase: humorous ticket and a
/// fictional holding cell.
class TicketJailOverlay extends StatelessWidget {
  const TicketJailOverlay({super.key, required this.game});

  final KamoteGame game;

  @override
  Widget build(BuildContext context) {
    return GameOverPanel(
      game: game,
      title: 'TICKETED & JAILED!',
      subtitle: 'The LTO officer caught up. Maybe drive less kamote next time.',
      accent: const Color(0xFF82B1FF),
      background: const Color(0xF00D1530),
      scene: _JailScene(game: game),
    );
  }
}

class _JailScene extends StatelessWidget {
  const _JailScene({required this.game});

  final KamoteGame game;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _CellPainter()),
          Align(
            alignment: const Alignment(-0.45, 0.4),
            child: Opacity(opacity: 0.9, child: BikePreview(bike: game.player.bike, height: 110)),
          ),
          const CustomPaint(painter: _BarsPainter()),
          // Cellmate gag, fades in after the ticket lands.
          Positioned(
            left: 10,
            top: 34,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1400),
              curve: const Interval(0.6, 1),
              builder: (context, t, child) => Opacity(opacity: t, child: child),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: const Text(
                  'Kamote ka rin, pre?',
                  style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            builder: (context, t, child) => Align(
              alignment: Alignment(0.75 + t * 1.5, -0.1),
              child: Transform.rotate(angle: 0.12 + t * 0.6, child: child),
            ),
            // Scale the ticket to whatever height the scene has.
            child: const FractionallySizedBox(heightFactor: 0.92, child: FittedBox(child: _Ticket())),
          ),
        ],
      ),
    );
  }
}

class _Ticket extends StatelessWidget {
  const _Ticket();

  @override
  Widget build(BuildContext context) {
    const lines = [
      'Reckless kamote riding',
      'Ignoring an LTO officer',
      'Swerving like a lost squid',
      'Excessive confidence',
    ];
    return Container(
      width: 170,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(2, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TRAFFIC VIOLATION TICKET',
            style: TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.w900, fontSize: 10),
          ),
          const Text('Fictional Land Transport Office', style: TextStyle(color: Colors.black54, fontSize: 8)),
          const Divider(height: 8, color: Colors.black26),
          for (final l in lines)
            Text(
              '☒ $l',
              style: const TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 4),
          const Text(
            'Penalty: 1 night in the holding cell',
            style: TextStyle(color: Color(0xFFB71C1C), fontSize: 9, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _CellPainter extends CustomPainter {
  const _CellPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF5D6670);
    canvas.drawRect(Offset.zero & size, p);
    p.color = const Color(0xFF4A525B);
    const bh = 18.0;
    const bw = 40.0;
    for (var row = 0; row * bh < size.height; row++) {
      final offset = row.isEven ? 0.0 : bw / 2;
      for (var x = -offset; x < size.width; x += bw) {
        canvas.drawRect(Rect.fromLTWH(x + 1, row * bh + 1, bw - 2, bh - 2), p);
      }
    }
    p.color = const Color(0xFF3E3A36);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.8, size.width, size.height * 0.2), p);
    // Mugshot height chart on the back wall.
    final chart = Paint()..color = const Color(0x55FFFFFF);
    for (var i = 0; i < 6; i++) {
      final y = size.height * (0.25 + i * 0.09);
      canvas.drawRect(Rect.fromLTWH(size.width * 0.05, y, i.isEven ? 28 : 16, 2), chart);
    }
    // A tiny barred window with moonlight.
    p.color = const Color(0xFF90CAF9);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.1, size.height * 0.1, 46, 30), p);
  }

  @override
  bool shouldRepaint(_CellPainter oldDelegate) => false;
}

class _BarsPainter extends CustomPainter {
  const _BarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF263238);
    final hi = Paint()..color = const Color(0x55FFFFFF);
    final count = math.max(5, (size.width / 34).floor());
    for (var i = 0; i < count; i++) {
      final x = (i + 0.5) * size.width / count;
      canvas.drawRect(Rect.fromLTWH(x - 4, 0, 8, size.height), p);
      canvas.drawRect(Rect.fromLTWH(x - 3, 0, 2, size.height), hi);
    }
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.15, size.width, 8), p);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.85, size.width, 8), p);
    final sign = TextPainter(
      text: const TextSpan(
        text: 'HOLDING CELL',
        style: TextStyle(color: KColors.yellow, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2 - sign.width / 2 - 8, 4, sign.width + 16, sign.height + 6),
      Paint()..color = const Color(0xFF1A237E),
    );
    sign.paint(canvas, Offset(size.width / 2 - sign.width / 2, 7));
  }

  @override
  bool shouldRepaint(_BarsPainter oldDelegate) => false;
}
