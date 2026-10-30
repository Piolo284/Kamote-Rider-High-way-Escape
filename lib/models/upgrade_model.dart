import '../game/game_config.dart';
import 'motorcycle_model.dart';

/// Garage upgrade categories. Each bike keeps its own level per category.
enum UpgradeStat { maxSpeed, acceleration, handling, fuelEfficiency, fuelCapacity }

extension UpgradeStatInfo on UpgradeStat {
  String get label => switch (this) {
    UpgradeStat.maxSpeed => 'Max Speed',
    UpgradeStat.acceleration => 'Acceleration',
    UpgradeStat.handling => 'Handling',
    UpgradeStat.fuelEfficiency => 'Fuel Efficiency',
    UpgradeStat.fuelCapacity => 'Fuel Capacity',
  };

  String get description => switch (this) {
    UpgradeStat.maxSpeed => 'Higher top speed on the highway.',
    UpgradeStat.acceleration => 'Reaches top speed faster after a slowdown.',
    UpgradeStat.handling => 'Quicker, snappier lane changes.',
    UpgradeStat.fuelEfficiency => 'Burns gasoline more slowly.',
    UpgradeStat.fuelCapacity => 'A bigger tank that lasts longer.',
  };

  /// Change per level above 1, as a fraction (0.03 = 3%).
  double get stepPerLevel => switch (this) {
    UpgradeStat.maxSpeed => 0.03,
    UpgradeStat.acceleration => 0.10,
    UpgradeStat.handling => 0.05,
    UpgradeStat.fuelEfficiency => 0.05,
    UpgradeStat.fuelCapacity => 0.10,
  };
}

/// Upgrade levels of one motorcycle, each from [minLevel] to [maxLevel].
class UpgradeLevels {
  UpgradeLevels([Map<UpgradeStat, int>? levels]) : _levels = {...?levels} {
    for (final stat in UpgradeStat.values) {
      _levels[stat] = (_levels[stat] ?? minLevel).clamp(minLevel, maxLevel);
    }
  }

  static const int minLevel = 1;
  static const int maxLevel = 5;

  final Map<UpgradeStat, int> _levels;

  int operator [](UpgradeStat stat) => _levels[stat]!;

  bool isMaxed(UpgradeStat stat) => this[stat] >= maxLevel;

  /// Levels bought above the starting level, across all categories.
  int get purchased => _levels.values.fold(0, (sum, l) => sum + l - minLevel);

  /// Raises [stat] by one level. Returns false when already maxed.
  bool raise(UpgradeStat stat) {
    if (isMaxed(stat)) return false;
    _levels[stat] = this[stat] + 1;
    return true;
  }

  Map<String, int> toJson() => {for (final e in _levels.entries) e.key.name: e.value};

  factory UpgradeLevels.fromJson(Object? raw) {
    if (raw is! Map) return UpgradeLevels();
    return UpgradeLevels({
      for (final stat in UpgradeStat.values)
        if (raw[stat.name] is int) stat: raw[stat.name] as int,
    });
  }
}

/// Prices for garage upgrades. Higher levels and higher tiers cost more.
class UpgradeCatalog {
  UpgradeCatalog._();

  /// Price multipliers for reaching levels 2, 3, 4 and 5.
  static const List<double> _levelMultipliers = [1, 2, 3.5, 5];

  static int baseCost(Motorcycle bike) => 200 + 100 * bike.tier;

  /// Cost to raise a stat from [currentLevel] to the next one, or null when
  /// it is already at the maximum.
  static int? costFor(Motorcycle bike, int currentLevel) {
    if (currentLevel >= UpgradeLevels.maxLevel) return null;
    final index = (currentLevel - UpgradeLevels.minLevel).clamp(0, _levelMultipliers.length - 1);
    return (baseCost(bike) * _levelMultipliers[index]).round();
  }
}

/// The numbers the game actually uses for a bike: its base design plus its
/// garage upgrades.
class BikeStats {
  const BikeStats({
    required this.topSpeedKmh,
    required this.accelerationKmhPerSec,
    required this.laneChangeSeconds,
    required this.fuelDrainMultiplier,
    required this.fuelCapacity,
  });

  /// Cruising speed in km/h before difficulty scaling.
  final double topSpeedKmh;
  final double accelerationKmhPerSec;

  /// Seconds needed to slide one lane over.
  final double laneChangeSeconds;

  /// Multiplier on the base fuel drain.
  final double fuelDrainMultiplier;

  /// Tank size in fuel units (the base tank is [GameConfig.maxFuel]).
  final double fuelCapacity;

  factory BikeStats.of(Motorcycle bike, [UpgradeLevels? upgrades]) {
    final u = upgrades ?? UpgradeLevels();
    double steps(UpgradeStat s) => (u[s] - UpgradeLevels.minLevel) * s.stepPerLevel;
    return BikeStats(
      topSpeedKmh: bike.topSpeedKmh * (1 + steps(UpgradeStat.maxSpeed)),
      accelerationKmhPerSec: bike.accelerationKmhPerSec * (1 + steps(UpgradeStat.acceleration)),
      laneChangeSeconds: bike.laneChangeSeconds * (1 - steps(UpgradeStat.handling)),
      fuelDrainMultiplier: bike.fuelDrainMultiplier * (1 - steps(UpgradeStat.fuelEfficiency)),
      fuelCapacity: GameConfig.maxFuel * (1 + steps(UpgradeStat.fuelCapacity)),
    );
  }

  /// Short value shown in the garage for [stat].
  String display(UpgradeStat stat) => switch (stat) {
    UpgradeStat.maxSpeed => '${topSpeedKmh.round()} km/h',
    UpgradeStat.acceleration => '${accelerationKmhPerSec.round()} km/h/s',
    UpgradeStat.handling => '${laneChangeSeconds.toStringAsFixed(2)} s/lane',
    UpgradeStat.fuelEfficiency => '${(fuelDrainMultiplier * 100).round()}% burn',
    UpgradeStat.fuelCapacity => '${fuelCapacity.round()} L',
  };
}
