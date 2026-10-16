import '../models/mission_model.dart';
import 'player_profile.dart';

/// Tracks mission progress from gameplay events and handles reward claims.
///
/// During a run the game calls the `on*` methods. Progress is written to the
/// profile's in-memory model immediately and persisted when the run is
/// finalized (or when a reward is claimed).
class MissionService {
  MissionService(this._profile);

  final PlayerProfile _profile;

  String _runBikeId = '';
  int _environmentsVisited = 0;
  final List<String> _completedThisRun = [];

  /// Missions completed since [beginRun], by title.
  List<String> get completedThisRun => List.unmodifiable(_completedThisRun);

  MissionState stateOf(MissionDef def) => _profile.data.missionState(def.id);

  int get claimableCount => MissionCatalog.all.where((d) => stateOf(d).completed).length;

  void beginRun(String bikeId) {
    _runBikeId = bikeId;
    _environmentsVisited = 0;
    _completedThisRun.clear();
  }

  // ---------------------------------------------------------------- events

  List<MissionDef> onBillCollected() => _apply(MissionObjective.collectBills, add: 1);

  List<MissionDef> onFuelCollected() => _apply(MissionObjective.collectFuel, add: 1);

  List<MissionDef> onChaseSurvived() => _apply(MissionObjective.surviveChases, add: 1);

  List<MissionDef> onRunCashChanged(int runCash) => _apply(MissionObjective.singleRunCash, best: runCash);

  List<MissionDef> onEnvironmentVisited(int distinctEnvironments) {
    if (distinctEnvironments <= _environmentsVisited) return const [];
    _environmentsVisited = distinctEnvironments;
    return _apply(MissionObjective.visitEnvironments, best: distinctEnvironments);
  }

  /// [deltaMeters] feeds lifetime distance; run and clean distance feed the
  /// single-run objectives. Values are whole meters to keep saves compact.
  List<MissionDef> onDistance({required int deltaMeters, required int runMeters, required int cleanMeters}) {
    return [
      if (deltaMeters > 0) ..._apply(MissionObjective.lifetimeDistance, add: deltaMeters),
      ..._apply(MissionObjective.singleRunDistance, best: runMeters),
      ..._apply(MissionObjective.cleanDistance, best: cleanMeters),
      ..._applyBikeRide(runMeters),
    ];
  }

  // ---------------------------------------------------------------- claims

  /// Pays the reward of a completed mission and advances it to its next
  /// level. Returns the amount paid, or 0 if the mission is not claimable.
  int claim(String missionId) {
    final def = MissionCatalog.byId(missionId);
    if (def == null) return 0;
    final state = stateOf(def);
    if (!state.completed) return 0;
    final reward = def.rewardFor(state.level);
    state
      ..completed = false
      ..progress = 0
      ..level += 1
      ..timesClaimed += 1;
    _profile.data.wallet += reward;
    _profile.commit();
    return reward;
  }

  // -------------------------------------------------------------- internal

  List<MissionDef> _applyBikeRide(int runMeters) {
    final out = <MissionDef>[];
    for (final def in MissionCatalog.all) {
      if (def.objective != MissionObjective.rideSpecificBike) continue;
      final state = stateOf(def);
      if (def.bikeFor(state.level)?.id != _runBikeId) continue;
      if (_update(def, state, best: runMeters)) out.add(def);
    }
    return out;
  }

  List<MissionDef> _apply(MissionObjective objective, {int? add, int? best}) {
    List<MissionDef>? out;
    for (final def in MissionCatalog.all) {
      if (def.objective != objective) continue;
      if (_update(def, stateOf(def), add: add, best: best)) (out ??= []).add(def);
    }
    return out ?? const [];
  }

  /// Returns true when this update completed the mission.
  bool _update(MissionDef def, MissionState state, {int? add, int? best}) {
    if (state.completed) return false;
    final target = def.targetFor(state.level);
    var next = state.progress;
    if (add != null) next += add;
    if (best != null && best > next) next = best;
    if (next > target) next = target;
    state.progress = next;
    if (next >= target) {
      state.completed = true;
      _completedThisRun.add(def.titleFor(state.level));
      return true;
    }
    return false;
  }
}
