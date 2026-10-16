/// Lifecycle of one run inside the game screen.
///
/// Menu, garage and mission screens are Flutter routes, so this machine only
/// covers what happens while the game screen is open.
enum RunPhase {
  /// Game loaded but no run started yet.
  idle,

  /// Simulation running and accepting input and collisions.
  playing,

  /// Simulation frozen by the pause menu or by the app losing focus.
  paused,

  /// A run-ending event happened; the ending animation is playing and all
  /// further collisions, pickups and input are ignored.
  ending,

  /// The run is over and the result has been banked.
  gameOver,
}

enum EndReason { ticketAndJail, headOnCrash, outOfFuel, quit }

/// High-level status shown to the player, derived from the phase plus the
/// chase and end reason. PoliceChase is a condition layered on Playing, so
/// starting a chase never tears down the running game.
enum GameStatus { idle, playing, policeChase, paused, ticketAndJail, headOnCrash, outOfFuel, gameOver }

class RunStateMachine {
  RunPhase _phase = RunPhase.idle;
  EndReason? _endReason;

  RunPhase get phase => _phase;
  EndReason? get endReason => _endReason;

  bool get isPlaying => _phase == RunPhase.playing;
  bool get isPaused => _phase == RunPhase.paused;
  bool get isEnding => _phase == RunPhase.ending;
  bool get isOver => _phase == RunPhase.gameOver;

  /// Collisions, pickups, fuel use and distance only advance while playing.
  bool get acceptsGameplay => _phase == RunPhase.playing;

  /// A run is "live" (not yet banked) while playing, paused or ending.
  bool get isRunLive => _phase == RunPhase.playing || _phase == RunPhase.paused || _phase == RunPhase.ending;

  GameStatus status({required bool chaseActive}) {
    switch (_phase) {
      case RunPhase.idle:
        return GameStatus.idle;
      case RunPhase.playing:
        return chaseActive ? GameStatus.policeChase : GameStatus.playing;
      case RunPhase.paused:
        return GameStatus.paused;
      case RunPhase.ending:
      case RunPhase.gameOver:
        return switch (_endReason) {
          EndReason.ticketAndJail => GameStatus.ticketAndJail,
          EndReason.headOnCrash => GameStatus.headOnCrash,
          EndReason.outOfFuel => GameStatus.outOfFuel,
          _ => GameStatus.gameOver,
        };
    }
  }

  /// Starts a new run. Only valid from idle or game over, so a single Play
  /// action can never start two runs.
  bool start() {
    if (_phase != RunPhase.idle && _phase != RunPhase.gameOver) return false;
    _phase = RunPhase.playing;
    _endReason = null;
    return true;
  }

  bool pause() {
    if (_phase != RunPhase.playing) return false;
    _phase = RunPhase.paused;
    return true;
  }

  bool resume() {
    if (_phase != RunPhase.paused) return false;
    _phase = RunPhase.playing;
    return true;
  }

  /// First run-ending event wins; later ones are rejected.
  bool beginEnding(EndReason reason) {
    if (_phase != RunPhase.playing) return false;
    _phase = RunPhase.ending;
    _endReason = reason;
    return true;
  }

  bool finishEnding() {
    if (_phase != RunPhase.ending) return false;
    _phase = RunPhase.gameOver;
    return true;
  }

  /// Abandons a live run (Restart / Main Menu from the pause menu).
  bool quit() {
    if (_phase != RunPhase.playing && _phase != RunPhase.paused) return false;
    _phase = RunPhase.gameOver;
    _endReason = EndReason.quit;
    return true;
  }

  void reset() {
    _phase = RunPhase.idle;
    _endReason = null;
  }
}
