import 'dart:ui';

/// What the player ran into.
enum HazardKind {
  /// Car, bus, truck, jeepney, tricycle or van.
  vehicle,

  /// The guardrail / edge of the road.
  roadEdge,

  /// Concrete or construction barrier. Qualifies for the LTO chase.
  barrier,

  /// Traffic cone. Minor hazard.
  cone,

  /// Pothole. Minor hazard.
  pothole,

  /// Fallen cargo such as a cardboard box. Minor hazard.
  debris,

  /// Dog, cat or chicken crossing. Minor (sudden stop), never a chase.
  animal,

  /// LTO officer riding beside the rider to block a lane.
  officer,
}

/// Gameplay outcome of a collision, ordered by priority (highest last).
enum CollisionOutcome {
  /// Slows the bike briefly. Never starts a chase.
  minor,

  /// Starts the LTO chase, or triggers ticket-and-jail if one is active.
  sideCollision,

  /// Ends the run immediately with the ambulance scene.
  headOn,
}

enum ImpactAxis { frontal, side }

class CollisionEvent {
  const CollisionEvent({required this.outcome, required this.kind, required this.source, this.axis});

  final CollisionOutcome outcome;
  final HazardKind kind;
  final ImpactAxis? axis;

  /// The component that was hit; used to mark it as already processed.
  final Object source;
}

/// Decides whether two boxes met front-to-back or side-to-side, using their
/// positions on the previous frame (swept AABB).
ImpactAxis classifyImpact({
  required Rect previousA,
  required Rect currentA,
  required Rect previousB,
  required Rect currentB,
}) {
  final wereOverlappingX = previousA.left < previousB.right && previousB.left < previousA.right;
  final wereOverlappingY = previousA.top < previousB.bottom && previousB.top < previousA.bottom;
  if (wereOverlappingX && !wereOverlappingY) return ImpactAxis.frontal;
  if (wereOverlappingY && !wereOverlappingX) return ImpactAxis.side;

  // Diagonal entry (or spawned overlapping): the axis with the shallower
  // penetration is the one that was crossed most recently.
  final overlap = currentA.intersect(currentB);
  final depthX = overlap.width / (currentA.width < currentB.width ? currentA.width : currentB.width);
  final depthY = overlap.height / (currentA.height < currentB.height ? currentA.height : currentB.height);
  return depthY <= depthX ? ImpactAxis.frontal : ImpactAxis.side;
}

/// Maps what was hit and how into a gameplay outcome.
///
/// * Front-on with an oncoming vehicle → head-on (run ends).
/// * Any other vehicle contact, the road edge or a barrier → side collision.
/// * Cones and potholes → minor.
CollisionOutcome outcomeFor({required HazardKind kind, required bool oncoming, ImpactAxis? axis}) {
  switch (kind) {
    case HazardKind.vehicle:
      return oncoming && axis == ImpactAxis.frontal ? CollisionOutcome.headOn : CollisionOutcome.sideCollision;
    case HazardKind.roadEdge:
    case HazardKind.barrier:
    case HazardKind.officer:
      return CollisionOutcome.sideCollision;
    case HazardKind.cone:
    case HazardKind.pothole:
    case HazardKind.debris:
    case HazardKind.animal:
      return CollisionOutcome.minor;
  }
}

/// Buffers collision events reported during a frame so that only the
/// highest-priority one is processed.
class CollisionSystem {
  final List<CollisionEvent> _pending = [];

  bool get hasPending => _pending.isNotEmpty;

  void report(CollisionEvent event) => _pending.add(event);

  /// Returns the most severe event reported this frame and clears the buffer.
  CollisionEvent? resolve() {
    if (_pending.isEmpty) return null;
    var best = _pending.first;
    for (final e in _pending) {
      if (e.outcome.index > best.outcome.index) best = e;
    }
    _pending.clear();
    return best;
  }

  void clear() => _pending.clear();
}
