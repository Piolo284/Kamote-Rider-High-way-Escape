import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/painting/bike_painter.dart';
import '../models/motorcycle_model.dart';

/// Renders a motorcycle with the same painter used in-game.
///
/// [silhouette] draws a locked bike as a dark shape; [animate] adds a gentle
/// idle bob.
class BikePreview extends StatefulWidget {
  const BikePreview({super.key, required this.bike, this.height = 120, this.silhouette = false, this.animate = true});

  final Motorcycle bike;
  final double height;
  final bool silhouette;
  final bool animate;

  @override
  State<BikePreview> createState() => _BikePreviewState();
}

class _BikePreviewState extends State<BikePreview> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(BikePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_c.isAnimating) _c.repeat();
    if (!widget.animate && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wide bikes (sidecar / tricycle) need extra room on the right.
    final wide = widget.bike.style == BikeStyle.sidecar || widget.bike.style == BikeStyle.tricycle;
    final w = widget.height / 2;
    Widget paint = AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * math.pi * 2;
        return Transform.translate(
          offset: Offset(0, math.sin(t) * widget.height * 0.015),
          child: Transform.rotate(
            angle: math.sin(t) * 0.04,
            child: CustomPaint(size: Size(w, widget.height), painter: _BikePainterDelegate(widget.bike)),
          ),
        );
      },
    );
    if (widget.silhouette) {
      paint = ColorFiltered(colorFilter: const ColorFilter.mode(Color(0xFF0B0E16), BlendMode.srcATop), child: paint);
    }
    return SizedBox(
      width: wide ? w * 1.7 : w,
      height: widget.height,
      child: Align(alignment: Alignment.centerLeft, child: paint),
    );
  }
}

class _BikePainterDelegate extends CustomPainter {
  _BikePainterDelegate(this.bike);

  final Motorcycle bike;

  @override
  void paint(Canvas canvas, Size size) => BikePainter.paint(canvas, size, bike);

  @override
  bool shouldRepaint(_BikePainterDelegate old) => old.bike.id != bike.id;
}
