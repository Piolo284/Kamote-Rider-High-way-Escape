import 'dart:ui';

enum DifficultyLevel { easy, medium, hard }

/// Every gameplay parameter that changes with the selected difficulty.
///
/// This is the single source of truth: systems read these values instead of
/// checking the difficulty level themselves. Rules that must stay the same
/// in every mode (10-second chase, second offense = jail, head-on = game
/// over) are deliberately not configurable here.
class DifficultyConfig {
  const DifficultyConfig({
    required this.level,
    required this.label,
    required this.tagline,
    required this.description,
    required this.effects,
    required this.color,
    required this.startSpeedMultiplier,
    required this.speedGrowthPerKm,
    required this.maxSpeedBonus,
    required this.progressionRate,
    required this.rowSpacingMultiplier,
    required this.trafficDensity,
    required this.obstacleDensity,
    required this.oncomingShareBonus,
    required this.reactionPadding,
    required this.oncomingWarningSeconds,
    required this.fuelDrainMultiplier,
    required this.fuelIntervalMultiplier,
    required this.cashIntervalMultiplier,
    required this.challengeIntervalSeconds,
    required this.rewardMultiplier,
    required this.invulnerabilitySeconds,
    required this.steeringMultiplier,
  });

  final DifficultyLevel level;
  final String label;
  final String tagline;
  final String description;
  final List<String> effects;
  final Color color;

  /// Multiplier on the bike's cruising speed at the start of a run.
  final double startSpeedMultiplier;

  /// Extra speed fraction gained per kilometer.
  final double speedGrowthPerKm;

  /// Cap on the extra speed fraction from distance.
  final double maxSpeedBonus;

  /// How fast traffic density ramps up with distance (1 = standard).
  final double progressionRate;

  /// Multiplier on the distance between spawn rows (bigger = sparser).
  final double rowSpacingMultiplier;

  /// Multiplier on the chance a row spawns a vehicle.
  final double trafficDensity;

  /// Multiplier on the chance a row spawns an obstacle.
  final double obstacleDensity;

  /// Added to each world's oncoming-traffic share.
  final double oncomingShareBonus;

  /// Seconds of clear road the lane planner keeps before each hazard.
  final double reactionPadding;

  /// Minimum warning before an oncoming car reaches the rider.
  final double oncomingWarningSeconds;

  /// Multiplier on fuel burn.
  final double fuelDrainMultiplier;

  /// Multiplier on time between fuel cans (smaller = more fuel).
  final double fuelIntervalMultiplier;

  /// Multiplier on distance between cash lines (smaller = more cash).
  final double cashIntervalMultiplier;

  /// Average seconds between random highway challenges.
  final double challengeIntervalSeconds;

  /// Multiplier on bonus money (milestones, escapes, dodges, challenges).
  /// Paper bills always pay face value.
  final double rewardMultiplier;

  /// Grace period after a hit.
  final double invulnerabilitySeconds;

  /// Multiplier on lane-change speed (more forgiving steering on Easy).
  final double steeringMultiplier;

  static const easy = DifficultyConfig(
    level: DifficultyLevel.easy,
    label: 'EASY',
    tagline: 'Chill ride, idol.',
    description: 'For beginners and casual riders. Slower road, lighter traffic, more fuel.',
    effects: [
      'Slower speed & progression',
      'Light traffic, simple obstacles',
      'More fuel, slower burn',
      'Bonus money ×0.75',
    ],
    color: Color(0xFF66BB6A),
    startSpeedMultiplier: 0.86,
    speedGrowthPerKm: 0.02,
    maxSpeedBonus: 0.2,
    progressionRate: 0.6,
    rowSpacingMultiplier: 1.3,
    trafficDensity: 0.7,
    obstacleDensity: 0.7,
    oncomingShareBonus: -0.1,
    reactionPadding: 0.75,
    oncomingWarningSeconds: 1.6,
    fuelDrainMultiplier: 0.8,
    fuelIntervalMultiplier: 0.75,
    cashIntervalMultiplier: 0.9,
    challengeIntervalSeconds: 22,
    rewardMultiplier: 0.75,
    invulnerabilitySeconds: 1.6,
    steeringMultiplier: 1.15,
  );

  static const medium = DifficultyConfig(
    level: DifficultyLevel.medium,
    label: 'MEDIUM',
    tagline: 'Sakto lang, pero ingat.',
    description: 'The balanced kamote experience. Standard speed, traffic and fuel.',
    effects: ['Standard speed & progression', 'Moderate traffic', 'Normal fuel', 'Bonus money ×1.0'],
    color: Color(0xFFFFC400),
    startSpeedMultiplier: 1.0,
    speedGrowthPerKm: 0.035,
    maxSpeedBonus: 0.32,
    progressionRate: 1.0,
    rowSpacingMultiplier: 1.0,
    trafficDensity: 1.0,
    obstacleDensity: 1.0,
    oncomingShareBonus: 0,
    reactionPadding: 0.5,
    oncomingWarningSeconds: 1.3,
    fuelDrainMultiplier: 1.0,
    fuelIntervalMultiplier: 1.0,
    cashIntervalMultiplier: 1.0,
    challengeIntervalSeconds: 16,
    rewardMultiplier: 1.0,
    invulnerabilitySeconds: 1.3,
    steeringMultiplier: 1.0,
  );

  static const hard = DifficultyConfig(
    level: DifficultyLevel.hard,
    label: 'HARD',
    tagline: 'Para sa tunay na kamote survivor.',
    description: 'Fast road, heavy traffic, scarce fuel. Bigger rewards for survivors.',
    effects: [
      'Faster speed & progression',
      'Heavy traffic, tricky patterns',
      'Scarce fuel, faster burn',
      'Bonus money ×1.5',
    ],
    color: Color(0xFFFF5252),
    startSpeedMultiplier: 1.1,
    speedGrowthPerKm: 0.045,
    maxSpeedBonus: 0.4,
    progressionRate: 1.4,
    rowSpacingMultiplier: 0.85,
    trafficDensity: 1.22,
    obstacleDensity: 1.25,
    oncomingShareBonus: 0.05,
    reactionPadding: 0.4,
    oncomingWarningSeconds: 1.1,
    fuelDrainMultiplier: 1.2,
    fuelIntervalMultiplier: 1.2,
    cashIntervalMultiplier: 1.1,
    challengeIntervalSeconds: 11,
    rewardMultiplier: 1.5,
    invulnerabilitySeconds: 1.2,
    steeringMultiplier: 1.0,
  );

  static const List<DifficultyConfig> all = [easy, medium, hard];

  static DifficultyConfig of(DifficultyLevel level) => switch (level) {
    DifficultyLevel.easy => easy,
    DifficultyLevel.medium => medium,
    DifficultyLevel.hard => hard,
  };

  static DifficultyLevel parse(Object? raw) {
    for (final l in DifficultyLevel.values) {
      if (l.name == raw) return l;
    }
    return DifficultyLevel.medium;
  }
}
