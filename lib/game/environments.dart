import 'dart:ui';

enum VehicleType { car, taxi, jeepney, bus, truck, tricycle, van, suv, lrt }

enum ObstacleType { pothole, cone, barrier, box }

enum PropType {
  building,
  tower,
  nipaHut,
  sariSari,
  tree,
  palm,
  pine,
  streetlight,
  roadSign,
  warningSign,
  rock,
  billboard,
  boat,
  bush,
  flyover,
  tunnelLamp,
  pillar,
}

/// How the ground beside the road is drawn.
enum GroundStyle { sidewalk, ricefield, forest, cliff, sea, sand, concrete, tunnel }

/// Visual and gameplay settings for one of the five highway worlds.
class EnvironmentTheme {
  const EnvironmentTheme({
    required this.name,
    required this.tagline,
    required this.leftGround,
    required this.rightGround,
    required this.leftColor,
    required this.rightColor,
    required this.detailColor,
    required this.asphalt,
    required this.shoulder,
    required this.guardrails,
    required this.crosswalks,
    required this.leftProps,
    required this.rightProps,
    required this.propSpacing,
    required this.vehicleWeights,
    required this.obstacleWeights,
    required this.trafficDensity,
    required this.oncomingShare,
    required this.accent,
    this.underground = false,
  });

  final String name;
  final String tagline;
  final GroundStyle leftGround;
  final GroundStyle rightGround;
  final Color leftColor;
  final Color rightColor;
  final Color detailColor;
  final Color asphalt;
  final Color shoulder;
  final bool guardrails;
  final bool crosswalks;
  final List<PropType> leftProps;
  final List<PropType> rightProps;

  /// Average distance in world units between roadside props.
  final double propSpacing;
  final Map<VehicleType, int> vehicleWeights;
  final Map<ObstacleType, int> obstacleWeights;

  /// Multiplier on how often traffic rows contain vehicles.
  final double trafficDensity;

  /// Fraction of vehicles that are oncoming (head-on danger).
  final double oncomingShare;
  final Color accent;

  /// The secret manhole tunnel: dark, with LRT rails in every lane.
  final bool underground;
}

class Environments {
  Environments._();

  static const List<EnvironmentTheme> all = [
    EnvironmentTheme(
      name: 'City Highway',
      tagline: 'Flyovers, streetlights, and traffic',
      leftGround: GroundStyle.sidewalk,
      rightGround: GroundStyle.sidewalk,
      leftColor: Color(0xFF8D9AA3),
      rightColor: Color(0xFF8D9AA3),
      detailColor: Color(0xFF7A8790),
      asphalt: Color(0xFF3C4043),
      shoulder: Color(0xFF5F6368),
      guardrails: false,
      crosswalks: false,
      leftProps: [PropType.building, PropType.streetlight, PropType.building, PropType.roadSign],
      rightProps: [PropType.building, PropType.streetlight, PropType.billboard, PropType.building],
      propSpacing: 120,
      vehicleWeights: {VehicleType.car: 5, VehicleType.taxi: 3, VehicleType.bus: 2, VehicleType.van: 2},
      obstacleWeights: {ObstacleType.pothole: 2, ObstacleType.cone: 3, ObstacleType.barrier: 1},
      trafficDensity: 1.0,
      oncomingShare: 0.25,
      accent: Color(0xFF42A5F5),
    ),
    EnvironmentTheme(
      name: 'Provincial Road',
      tagline: 'Rice fields and sari-sari stores',
      leftGround: GroundStyle.ricefield,
      rightGround: GroundStyle.ricefield,
      leftColor: Color(0xFF7CB342),
      rightColor: Color(0xFF8BC34A),
      detailColor: Color(0xFF558B2F),
      asphalt: Color(0xFF4A4A48),
      shoulder: Color(0xFFA1887F),
      guardrails: false,
      crosswalks: false,
      leftProps: [PropType.nipaHut, PropType.palm, PropType.tree, PropType.bush],
      rightProps: [PropType.sariSari, PropType.palm, PropType.tree, PropType.nipaHut],
      propSpacing: 150,
      vehicleWeights: {VehicleType.tricycle: 5, VehicleType.jeepney: 4, VehicleType.truck: 1, VehicleType.car: 2},
      obstacleWeights: {ObstacleType.pothole: 5, ObstacleType.cone: 1, ObstacleType.barrier: 1},
      trafficDensity: 0.95,
      oncomingShare: 0.3,
      accent: Color(0xFF9CCC65),
    ),
    EnvironmentTheme(
      name: 'Mountain Road',
      tagline: 'Cliffs, pines, and sharp curves',
      leftGround: GroundStyle.cliff,
      rightGround: GroundStyle.forest,
      leftColor: Color(0xFF795548),
      rightColor: Color(0xFF2E7D32),
      detailColor: Color(0xFF5D4037),
      asphalt: Color(0xFF424242),
      shoulder: Color(0xFF6D6D6D),
      guardrails: true,
      crosswalks: false,
      leftProps: [PropType.rock, PropType.warningSign, PropType.rock],
      rightProps: [PropType.pine, PropType.pine, PropType.warningSign, PropType.pine],
      propSpacing: 110,
      vehicleWeights: {VehicleType.truck: 4, VehicleType.car: 3, VehicleType.jeepney: 2, VehicleType.van: 1},
      obstacleWeights: {ObstacleType.pothole: 2, ObstacleType.cone: 2, ObstacleType.barrier: 3},
      trafficDensity: 1.05,
      oncomingShare: 0.35,
      accent: Color(0xFF8D6E63),
    ),
    EnvironmentTheme(
      name: 'Coastal Highway',
      tagline: 'Ocean breeze and palm trees',
      leftGround: GroundStyle.sea,
      rightGround: GroundStyle.sand,
      leftColor: Color(0xFF29B6F6),
      rightColor: Color(0xFFFFE082),
      detailColor: Color(0xFF81D4FA),
      asphalt: Color(0xFF455A64),
      shoulder: Color(0xFFFFECB3),
      guardrails: true,
      crosswalks: false,
      leftProps: [PropType.boat, PropType.boat],
      rightProps: [PropType.palm, PropType.palm, PropType.sariSari, PropType.bush],
      propSpacing: 140,
      vehicleWeights: {VehicleType.car: 4, VehicleType.van: 3, VehicleType.bus: 2, VehicleType.jeepney: 2},
      obstacleWeights: {ObstacleType.pothole: 2, ObstacleType.cone: 3, ObstacleType.barrier: 2},
      trafficDensity: 1.1,
      oncomingShare: 0.35,
      accent: Color(0xFF26C6DA),
    ),
    EnvironmentTheme(
      name: 'Urban Road',
      tagline: 'Jeepneys, crosswalks, and chaos',
      leftGround: GroundStyle.concrete,
      rightGround: GroundStyle.concrete,
      leftColor: Color(0xFF9E9E9E),
      rightColor: Color(0xFFA5A5A5),
      detailColor: Color(0xFF888888),
      asphalt: Color(0xFF353535),
      shoulder: Color(0xFFBDBDBD),
      guardrails: false,
      crosswalks: true,
      leftProps: [PropType.tower, PropType.building, PropType.billboard, PropType.tower],
      rightProps: [PropType.tower, PropType.streetlight, PropType.building, PropType.tower],
      propSpacing: 100,
      vehicleWeights: {
        VehicleType.jeepney: 5,
        VehicleType.car: 3,
        VehicleType.bus: 2,
        VehicleType.taxi: 2,
        VehicleType.tricycle: 2,
      },
      obstacleWeights: {ObstacleType.pothole: 2, ObstacleType.cone: 3, ObstacleType.barrier: 2},
      trafficDensity: 1.25,
      oncomingShare: 0.4,
      accent: Color(0xFFFF7043),
    ),
  ];

  /// Index used for the secret tunnel reached through an open manhole.
  /// It sits outside [all], so the five surface worlds keep cycling.
  static const int undergroundIndex = 5;

  static const EnvironmentTheme underground = EnvironmentTheme(
    name: 'Underground Tunnel',
    tagline: 'LRT tracks, dim lights, and people crossing',
    leftGround: GroundStyle.tunnel,
    rightGround: GroundStyle.tunnel,
    leftColor: Color(0xFF3A3F45),
    rightColor: Color(0xFF3A3F45),
    detailColor: Color(0xFF2E3237),
    asphalt: Color(0xFF2B2D30),
    shoulder: Color(0xFF55595E),
    guardrails: false,
    crosswalks: false,
    leftProps: [PropType.tunnelLamp, PropType.pillar],
    rightProps: [PropType.tunnelLamp, PropType.pillar],
    propSpacing: 130,
    vehicleWeights: {VehicleType.lrt: 1},
    obstacleWeights: {ObstacleType.box: 2, ObstacleType.cone: 1},
    trafficDensity: 1.0,
    oncomingShare: 0.4,
    accent: Color(0xFFB388FF),
    underground: true,
  );

  /// Surface world for a distance-based index (wraps around).
  static EnvironmentTheme at(int index) => all[index % all.length];

  /// What is on screen: a surface world, or the tunnel for [undergroundIndex].
  static EnvironmentTheme visual(int index) => index == undergroundIndex ? underground : at(index);
}
