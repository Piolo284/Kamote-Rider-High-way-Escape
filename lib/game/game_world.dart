import 'package:flame/components.dart';

/// World holding the road, the rider and everything that scrolls.
class HighwayWorld extends World {
  /// Removes everything that belongs to a single run, keeping the
  /// persistent components in [keep] (road, rider, guardrails).
  void clearRunEntities(Set<Component> keep) {
    for (final child in children.toList()) {
      if (!keep.contains(child)) child.removeFromParent();
    }
  }
}
