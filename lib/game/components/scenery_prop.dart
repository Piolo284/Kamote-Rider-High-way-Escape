import 'package:flame/extensions.dart';

import '../environments.dart';
import '../painting/prop_painter.dart';
import 'highway_entity.dart';

/// Decorative roadside object. No hitbox; scrolls with the road.
class SceneryProp extends HighwayEntity {
  SceneryProp({required this.type, required this.onLeft, required this.variant})
    : super(size: PropPainter.sizeOf(type).toVector2(), priority: type == PropType.flyover ? 40 : 5);

  final PropType type;
  final bool onLeft;
  final int variant;

  @override
  void render(Canvas canvas) {
    PropPainter.paint(canvas, type, size.toSize(), variant: variant, onLeft: onLeft);
  }
}
