import 'motorcycle_model.dart';

/// What gameplay statistic a mission measures.
enum MissionObjective {
  /// Lifetime count of paper bills picked up.
  collectBills,

  /// Lifetime distance in meters across all runs.
  lifetimeDistance,

  /// Distance in meters reached in a single run.
  singleRunDistance,

  /// Lifetime count of fuel canisters picked up.
  collectFuel,

  /// Lifetime count of LTO chases survived.
  surviveChases,

  /// Meters travelled in a single run before the first collision of any kind.
  cleanDistance,

  /// Bill money (₱) collected in a single run.
  singleRunCash,

  /// Distinct environments visited in a single run.
  visitEnvironments,

  /// Meters travelled in a single run on a specific motorcycle.
  rideSpecificBike,
}

/// Whether progress accumulates across runs or is the best single-run value.
enum MissionScope { lifetime, singleRun }

/// Static definition of a repeatable mission. Each claim raises its level,
/// which raises the target and the reward.
class MissionDef {
  const MissionDef({
    required this.id,
    required this.objective,
    required this.scope,
    required this.baseTarget,
    required this.targetStep,
    required this.maxTarget,
    required this.baseReward,
    required this.rewardStep,
  });

  final String id;
  final MissionObjective objective;
  final MissionScope scope;
  final int baseTarget;
  final int targetStep;
  final int maxTarget;
  final int baseReward;
  final int rewardStep;

  int targetFor(int level) {
    final t = baseTarget + targetStep * level;
    return t > maxTarget ? maxTarget : t;
  }

  int rewardFor(int level) => baseReward + rewardStep * level;

  /// Bike required for [MissionObjective.rideSpecificBike] at [level].
  /// Rotates through the catalog, skipping the free starter bike.
  Motorcycle? bikeFor(int level) {
    if (objective != MissionObjective.rideSpecificBike) return null;
    final pool = MotorcycleCatalog.all.where((m) => !m.isFree).toList();
    return pool[level % pool.length];
  }

  String titleFor(int level) {
    final t = targetFor(level);
    return switch (objective) {
      MissionObjective.collectBills => 'Money Magnet',
      MissionObjective.lifetimeDistance => 'Road Warrior',
      MissionObjective.singleRunDistance => 'Long Haul',
      MissionObjective.collectFuel => 'Gas Station Hopper',
      MissionObjective.surviveChases => t == 1 ? 'Slippery Kamote' : 'Wanted Rider',
      MissionObjective.cleanDistance => 'Clean Rider',
      MissionObjective.singleRunCash => 'Payday Run',
      MissionObjective.visitEnvironments => 'Highway Tourist',
      MissionObjective.rideSpecificBike => 'Test Ride',
    };
  }

  String descriptionFor(int level) {
    final t = targetFor(level);
    return switch (objective) {
      MissionObjective.collectBills => 'Collect $t paper bills (all runs).',
      MissionObjective.lifetimeDistance => 'Travel ${formatMeters(t)} in total.',
      MissionObjective.singleRunDistance => 'Travel ${formatMeters(t)} in a single run.',
      MissionObjective.collectFuel => 'Collect $t fuel canisters (all runs).',
      MissionObjective.surviveChases => t == 1 ? 'Survive an LTO chase.' : 'Survive $t LTO chases (all runs).',
      MissionObjective.cleanDistance => 'Reach ${formatMeters(t)} in one run without any collision.',
      MissionObjective.singleRunCash => 'Collect ₱$t in bills in a single run.',
      MissionObjective.visitEnvironments => 'Visit $t different environments in one run.',
      MissionObjective.rideSpecificBike => 'Ride ${formatMeters(t)} in one run on the ${bikeFor(level)!.name}.',
    };
  }
}

String formatMeters(num meters) {
  if (meters >= 1000) {
    final km = meters / 1000;
    return km == km.roundToDouble() ? '${km.toInt()} km' : '${km.toStringAsFixed(1)} km';
  }
  return '${meters.toInt()} m';
}

/// Persistent per-mission progress.
class MissionState {
  MissionState({this.level = 0, this.progress = 0, this.completed = false, this.timesClaimed = 0});

  int level;
  int progress;
  bool completed;
  int timesClaimed;

  Map<String, dynamic> toJson() => {
    'level': level,
    'progress': progress,
    'completed': completed,
    'claims': timesClaimed,
  };

  factory MissionState.fromJson(Object? raw) {
    if (raw is! Map) return MissionState();
    int readInt(String k) {
      final v = raw[k];
      if (v is int && v >= 0) return v;
      if (v is double && v >= 0 && v.isFinite) return v.toInt();
      return 0;
    }

    return MissionState(
      level: readInt('level'),
      progress: readInt('progress'),
      completed: raw['completed'] == true,
      timesClaimed: readInt('claims'),
    );
  }

  MissionState copy() =>
      MissionState(level: level, progress: progress, completed: completed, timesClaimed: timesClaimed);
}

class MissionCatalog {
  MissionCatalog._();

  static const List<MissionDef> all = [
    MissionDef(
      id: 'collect_bills',
      objective: MissionObjective.collectBills,
      scope: MissionScope.lifetime,
      baseTarget: 50,
      targetStep: 50,
      maxTarget: 1000,
      baseReward: 300,
      rewardStep: 150,
    ),
    MissionDef(
      id: 'travel_total',
      objective: MissionObjective.lifetimeDistance,
      scope: MissionScope.lifetime,
      baseTarget: 1000,
      targetStep: 2000,
      maxTarget: 50000,
      baseReward: 200,
      rewardStep: 200,
    ),
    MissionDef(
      id: 'single_run_distance',
      objective: MissionObjective.singleRunDistance,
      scope: MissionScope.singleRun,
      baseTarget: 3000,
      targetStep: 1000,
      maxTarget: 15000,
      baseReward: 800,
      rewardStep: 400,
    ),
    MissionDef(
      id: 'collect_fuel',
      objective: MissionObjective.collectFuel,
      scope: MissionScope.lifetime,
      baseTarget: 5,
      targetStep: 10,
      maxTarget: 200,
      baseReward: 250,
      rewardStep: 150,
    ),
    MissionDef(
      id: 'survive_chase',
      objective: MissionObjective.surviveChases,
      scope: MissionScope.lifetime,
      baseTarget: 1,
      targetStep: 2,
      maxTarget: 40,
      baseReward: 300,
      rewardStep: 200,
    ),
    MissionDef(
      id: 'clean_ride',
      objective: MissionObjective.cleanDistance,
      scope: MissionScope.singleRun,
      baseTarget: 1500,
      targetStep: 500,
      maxTarget: 6000,
      baseReward: 600,
      rewardStep: 300,
    ),
    MissionDef(
      id: 'cash_run',
      objective: MissionObjective.singleRunCash,
      scope: MissionScope.singleRun,
      baseTarget: 1000,
      targetStep: 500,
      maxTarget: 8000,
      baseReward: 400,
      rewardStep: 200,
    ),
    MissionDef(
      id: 'world_tour',
      objective: MissionObjective.visitEnvironments,
      scope: MissionScope.singleRun,
      baseTarget: 3,
      targetStep: 1,
      maxTarget: 5,
      baseReward: 500,
      rewardStep: 350,
    ),
    MissionDef(
      id: 'test_ride',
      objective: MissionObjective.rideSpecificBike,
      scope: MissionScope.singleRun,
      baseTarget: 1000,
      targetStep: 0,
      maxTarget: 1000,
      baseReward: 700,
      rewardStep: 100,
    ),
  ];

  static MissionDef? byId(String id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }
}
