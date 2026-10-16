import '../difficulty_config.dart';
import '../environments.dart';
import '../game_config.dart';

/// Difficulty parameters derived from distance and the selected
/// [DifficultyConfig], so they always match the distance counter and the
/// current environment.
class Difficulty {
  const Difficulty({
    required this.speedMultiplier,
    required this.rowSpacingMeters,
    required this.vehicleChance,
    required this.obstacleChance,
    required this.oncomingShare,
    required this.oncomingSpeedKmh,
  });

  /// Multiplier on the bike's cruising speed.
  final double speedMultiplier;

  /// Meters between spawn rows. Smaller = denser traffic.
  final double rowSpacingMeters;

  /// Chance that a row tries to spawn a vehicle.
  final double vehicleChance;

  /// Chance that a row tries to spawn a road obstacle.
  final double obstacleChance;

  /// Fraction of vehicles that are oncoming.
  final double oncomingShare;

  /// Speed of oncoming vehicles relative to the road.
  final double oncomingSpeedKmh;

  factory Difficulty.at(double meters, [DifficultyConfig config = DifficultyConfig.medium]) {
    final km = meters / 1000;
    // Density ramps with "effective" kilometers so Easy progresses slower.
    final rampKm = km * config.progressionRate;
    final cycle = (meters / (GameConfig.metersPerEnvironment * GameConfig.environmentCount)).floor();
    final env = Environments.at((meters / GameConfig.metersPerEnvironment).floor());
    // Gentle ramp in the first 300 m so the checkpoint chase is survivable.
    final warmup = (meters / 300).clamp(0.35, 1.0);
    final speedMult =
        config.startSpeedMultiplier * (1 + (config.speedGrowthPerKm * km).clamp(0.0, config.maxSpeedBonus));
    return Difficulty(
      speedMultiplier: speedMult,
      rowSpacingMeters: (21 - 1.3 * rampKm - 1.5 * cycle).clamp(10.0, 21.0) * config.rowSpacingMultiplier,
      vehicleChance: ((0.55 + 0.04 * rampKm) * env.trafficDensity * warmup * config.trafficDensity).clamp(0.0, 0.92),
      obstacleChance: ((0.28 + 0.03 * rampKm) * warmup * config.obstacleDensity).clamp(0.0, 0.6),
      oncomingShare: (env.oncomingShare + 0.04 * cycle + config.oncomingShareBonus).clamp(0.05, 0.55),
      oncomingSpeedKmh: (45 + 2.5 * rampKm).clamp(45.0, 70.0),
    );
  }
}
