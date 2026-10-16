import 'package:flutter/material.dart';

/// Animated scrolling highway used behind menus.
class RoadBackdrop extends StatefulWidget {
  const RoadBackdrop({super.key, this.speed = 1.0, this.child});

  final double speed;
  final Widget? child;

  @override
  State<RoadBackdrop> createState() => _RoadBackdropState();
}

class _RoadBackdropState extends State<RoadBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: CustomPaint(painter: _RoadPainter(_c, widget.speed))),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xEE141824), Color(0x88141824), Color(0xDD141824)],
              stops: [0, 0.45, 1],
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _RoadPainter extends CustomPainter {
  _RoadPainter(this.anim, this.speed) : super(repaint: anim);

  final Animation<double> anim;
  final double speed;
  final Paint _p = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final roadW = w * 0.68;
    final left = (w - roadW) / 2;
    _p.color = const Color(0xFF4E7D3A);
    canvas.drawRect(Offset.zero & size, _p);
    _p.color = const Color(0xFF3C4043);
    canvas.drawRect(Rect.fromLTWH(left, 0, roadW, h), _p);
    _p.color = const Color(0xFFFFC400);
    canvas.drawRect(Rect.fromLTWH(w / 2 - 5, 0, 3, h), _p);
    canvas.drawRect(Rect.fromLTWH(w / 2 + 2, 0, 3, h), _p);
    _p.color = Colors.white70;
    canvas.drawRect(Rect.fromLTWH(left + 3, 0, 3, h), _p);
    canvas.drawRect(Rect.fromLTWH(left + roadW - 6, 0, 3, h), _p);
    const period = 70.0;
    final phase = anim.value * period * 4 * speed % period;
    for (final lx in [left + roadW * 0.25, left + roadW * 0.75]) {
      for (var y = -period + phase; y < h; y += period) {
        canvas.drawRect(Rect.fromLTWH(lx - 2, y, 4, 34), _p);
      }
    }
  }

  @override
  bool shouldRepaint(_RoadPainter oldDelegate) => false;
}
