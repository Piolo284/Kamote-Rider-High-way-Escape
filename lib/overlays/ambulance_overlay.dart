import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/painting/vehicle_painter.dart';
import '../game/kamote_game.dart';
import 'general_game_over_overlay.dart';

/// Ending for a head-on crash: an arcade-style (non-graphic) ambulance
/// response.
class AmbulanceOverlay extends StatelessWidget {
  const AmbulanceOverlay({super.key, required this.game});

  final KamoteGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GameOverPanel(
          game: game,
          title: 'HEAD-ON CRASH!',
          subtitle: 'The ambulance arrived. Rider is okay, just a bruised ego and a long recovery.',
          accent: const Color(0xFFFF5252),
          background: const Color(0xF0200D12),
          scene: const _AmbulanceScene(),
        ),
        // Quick white flash that fades out as the scene appears.
        IgnorePointer(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: const Duration(milliseconds: 600),
            builder: (context, t, _) => ColoredBox(color: Colors.white.withValues(alpha: t * 0.85)),
          ),
        ),
      ],
    );
  }
}

class _AmbulanceScene extends StatefulWidget {
  const _AmbulanceScene();

  @override
  State<_AmbulanceScene> createState() => _AmbulanceSceneState();
}

class _AmbulanceSceneState extends State<_AmbulanceScene> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(painter: _ScenePainter(_c.value * 4)),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.seconds);

  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    // Night road.
    p.color = const Color(0xFF263238);
    canvas.drawRect(Offset.zero & size, p);
    p.color = const Color(0xFF37474F);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.15, 0, size.width * 0.7, size.height), p);
    p.color = const Color(0xFFFFC400);
    canvas.drawRect(Rect.fromLTWH(size.width / 2 - 3, 0, 2, size.height), p);
    canvas.drawRect(Rect.fromLTWH(size.width / 2 + 1, 0, 2, size.height), p);

    // Siren glow pulses red/blue across the whole scene.
    final red = (seconds * 3).floor().isEven;
    p.color = (red ? const Color(0xFFFF1744) : const Color(0xFF2979FF)).withValues(alpha: 0.18);
    canvas.drawRect(Offset.zero & size, p);

    // Ambulance slides in from the top during the first second, then idles.
    final arrive = (seconds / 1.0).clamp(0.0, 1.0);
    final eased = 1 - (1 - arrive) * (1 - arrive);
    const aw = 62.0;
    const ah = 116.0;
    canvas.save();
    canvas.translate(size.width * 0.32 - aw / 2, -ah + eased * (size.height * 0.5 + ah / 2));
    VehiclePainter.paintAmbulance(canvas, const Size(aw, ah), sirenPhase: seconds * 3);
    canvas.restore();

    // Stretcher with a bandaged (cartoon) rider.
    final sx = size.width * 0.68;
    final sy = size.height * 0.55;
    p.color = const Color(0xFFECEFF1);
    canvas.drawRRect(RRect.fromLTRBR(sx - 18, sy - 40, sx + 18, sy + 40, const Radius.circular(6)), p);
    p.color = const Color(0xFF90A4AE);
    canvas.drawRRect(RRect.fromLTRBR(sx - 14, sy - 10, sx + 14, sy + 34, const Radius.circular(6)), p);
    p.color = const Color(0xFFFFCC80);
    canvas.drawCircle(Offset(sx, sy - 24), 10, p);
    p.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(sx - 10, sy - 28, 20, 5), p);
    // Two cartoon paramedics in orange vests tending to the rider.
    for (final dx in [-34.0, 34.0]) {
      final bob = (seconds * 2 + dx).floor().isEven ? 1.5 : -1.5;
      p.color = const Color(0xFFFF6D00);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(sx + dx, sy + bob), width: 22, height: 26),
          const Radius.circular(8),
        ),
        p,
      );
      p.color = const Color(0xFFFFF59D);
      canvas.drawRect(Rect.fromCenter(center: Offset(sx + dx, sy + bob), width: 22, height: 3), p);
      p.color = const Color(0xFF6D4C41);
      canvas.drawCircle(Offset(sx + dx, sy - 16 + bob), 7, p);
    }
    // Little "dizzy" stars circle above the rider.
    p.color = const Color(0xFFFFEB3B);
    for (var i = 0; i < 3; i++) {
      final a = seconds * 4 + i * 2.1;
      canvas.drawCircle(Offset(sx + 16 * math.cos(a), sy - 40 + 6 * math.sin(a)), 3, p);
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.seconds != seconds;
}
