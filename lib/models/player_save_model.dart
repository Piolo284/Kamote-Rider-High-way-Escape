import '../game/difficulty_config.dart';
import '../game/systems/meme_event_manager.dart';
import 'leaderboard_model.dart';
import 'mission_model.dart';
import 'motorcycle_model.dart';

/// Player-adjustable settings.
class GameSettings {
  GameSettings({
    this.musicEnabled = true,
    this.sfxEnabled = true,
    this.musicVolume = 0.6,
    this.sfxVolume = 0.9,
    this.showSteerButtons = true,
    this.haptics = true,
    this.memeSounds = true,
    this.memePopups = MemePopupMode.full,
    this.lastDifficulty = DifficultyLevel.medium,
  });

  bool musicEnabled;
  bool sfxEnabled;
  double musicVolume;
  double sfxVolume;
  bool showSteerButtons;
  bool haptics;

  /// Meme stingers and voice lines, independent from other sound effects.
  bool memeSounds;
  MemePopupMode memePopups;

  /// Difficulty pre-selected on the difficulty screen. New players get Medium.
  DifficultyLevel lastDifficulty;

  Map<String, dynamic> toJson() => {
    'music': musicEnabled,
    'sfx': sfxEnabled,
    'musicVol': musicVolume,
    'sfxVol': sfxVolume,
    'buttons': showSteerButtons,
    'haptics': haptics,
    'memeSounds': memeSounds,
    'memePopups': memePopups.name,
    'difficulty': lastDifficulty.name,
  };

  factory GameSettings.fromJson(Object? raw) {
    final d = GameSettings();
    if (raw is! Map) return d;
    bool readBool(String k, bool fallback) => raw[k] is bool ? raw[k] as bool : fallback;
    double readVol(String k, double fallback) {
      final v = raw[k];
      if (v is num && v.isFinite) return v.toDouble().clamp(0.0, 1.0);
      return fallback;
    }

    return GameSettings(
      musicEnabled: readBool('music', d.musicEnabled),
      sfxEnabled: readBool('sfx', d.sfxEnabled),
      musicVolume: readVol('musicVol', d.musicVolume),
      sfxVolume: readVol('sfxVol', d.sfxVolume),
      showSteerButtons: readBool('buttons', d.showSteerButtons),
      haptics: readBool('haptics', d.haptics),
      memeSounds: readBool('memeSounds', d.memeSounds),
      memePopups: MemePopupMode.values.firstWhere((m) => m.name == raw['memePopups'], orElse: () => d.memePopups),
      lastDifficulty: DifficultyConfig.parse(raw['difficulty']),
    );
  }
}

/// Everything that persists between app launches.
///
/// Temporary run data lives in the game systems and is never stored here
/// until a run is finalized.
class PlayerSaveModel {
  PlayerSaveModel({
    this.wallet = 0,
    this.bestDistance = 0,
    this.totalDistance = 0,
    this.runsPlayed = 0,
    Set<String>? unlockedBikes,
    this.selectedBike = MotorcycleCatalog.starterId,
    Map<String, MissionState>? missions,
    GameSettings? settings,
    String? playerName,
    List<LeaderboardEntry>? leaderboard,
  }) : playerName = Leaderboard.cleanName(playerName),
       leaderboard = leaderboard ?? [],
       unlockedBikes = unlockedBikes ?? {MotorcycleCatalog.starterId},
       missions = missions ?? {},
       settings = settings ?? GameSettings() {
    _sanitize();
  }

  static const int schemaVersion = 1;

  int wallet;
  double bestDistance;
  double totalDistance;
  int runsPlayed;
  final Set<String> unlockedBikes;
  String selectedBike;
  final Map<String, MissionState> missions;
  GameSettings settings;

  /// Name stamped on new leaderboard entries; riders sharing a device switch it.
  String playerName;

  /// Finished runs, highest score first.
  final List<LeaderboardEntry> leaderboard;

  MissionState missionState(String id) => missions.putIfAbsent(id, MissionState.new);

  /// Repairs invalid values so a corrupted or outdated save can never crash
  /// the game or produce impossible states.
  void _sanitize() {
    if (wallet < 0) wallet = 0;
    if (!bestDistance.isFinite || bestDistance < 0) bestDistance = 0;
    if (!totalDistance.isFinite || totalDistance < 0) totalDistance = 0;
    if (runsPlayed < 0) runsPlayed = 0;
    unlockedBikes.removeWhere((id) => !MotorcycleCatalog.exists(id));
    unlockedBikes.add(MotorcycleCatalog.starterId);
    if (!unlockedBikes.contains(selectedBike)) selectedBike = MotorcycleCatalog.starterId;
    missions.removeWhere((id, _) => MissionCatalog.byId(id) == null);
    for (final def in MissionCatalog.all) {
      missions.putIfAbsent(def.id, MissionState.new);
    }
    Leaderboard.trim(leaderboard);
  }

  Map<String, dynamic> toJson() => {
    'v': schemaVersion,
    'wallet': wallet,
    'best': bestDistance,
    'total': totalDistance,
    'runs': runsPlayed,
    'unlocked': unlockedBikes.toList(),
    'selected': selectedBike,
    'missions': {for (final e in missions.entries) e.key: e.value.toJson()},
    'settings': settings.toJson(),
    'name': playerName,
    'board': [for (final e in leaderboard) e.toJson()],
  };

  factory PlayerSaveModel.fromJson(Object? raw) {
    if (raw is! Map) return PlayerSaveModel();
    int readInt(String k) {
      final v = raw[k];
      if (v is int) return v;
      if (v is double && v.isFinite) return v.toInt();
      return 0;
    }

    double readDouble(String k) {
      final v = raw[k];
      return v is num ? v.toDouble() : 0;
    }

    final unlockedRaw = raw['unlocked'];
    final unlocked = <String>{
      if (unlockedRaw is List)
        for (final v in unlockedRaw)
          if (v is String) v,
    };
    final missionsRaw = raw['missions'];
    final missions = <String, MissionState>{
      if (missionsRaw is Map)
        for (final e in missionsRaw.entries)
          if (e.key is String) e.key as String: MissionState.fromJson(e.value),
    };
    final selected = raw['selected'];
    final boardRaw = raw['board'];
    final board = <LeaderboardEntry>[
      if (boardRaw is List)
        for (final v in boardRaw)
          ?LeaderboardEntry.fromJson(v),
    ];
    final name = raw['name'];

    return PlayerSaveModel(
      wallet: readInt('wallet'),
      bestDistance: readDouble('best'),
      totalDistance: readDouble('total'),
      runsPlayed: readInt('runs'),
      unlockedBikes: unlocked,
      selectedBike: selected is String ? selected : MotorcycleCatalog.starterId,
      missions: missions,
      settings: GameSettings.fromJson(raw['settings']),
      playerName: name is String ? name : null,
      leaderboard: board,
    );
  }
}
