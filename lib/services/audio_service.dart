import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../game/systems/meme_event_manager.dart';
import '../models/player_save_model.dart';

enum Sfx {
  cash,
  fuel,
  impact,
  bump,
  whistle,
  click,
  unlock,
  mission,
  kilometer,
  crash,
  sputter,
  gameOver,
  whoosh,
  brake,
  challenge,
}

enum LoopSound { engine, siren, ambulance }

enum MusicTrack { menu, ride }

/// Music, sound effects and haptics.
///
/// Every call is fire-and-forget and failure-tolerant: if an audio file is
/// missing or the platform has no audio backend, the game keeps running
/// silently.
class AudioService {
  AudioService(this._settings, {this.backendEnabled = true});

  final GameSettings Function() _settings;

  /// False in tests or on platforms without an audio plugin.
  final bool backendEnabled;

  static const Map<Sfx, String> _sfxFiles = {
    Sfx.cash: 'sfx_cash.wav',
    Sfx.fuel: 'sfx_fuel.wav',
    Sfx.impact: 'sfx_impact.wav',
    Sfx.bump: 'sfx_bump.wav',
    Sfx.whistle: 'sfx_whistle.wav',
    Sfx.click: 'sfx_click.wav',
    Sfx.unlock: 'sfx_unlock.wav',
    Sfx.mission: 'sfx_mission.wav',
    Sfx.kilometer: 'sfx_kilometer.wav',
    Sfx.crash: 'sfx_crash.wav',
    Sfx.sputter: 'sfx_sputter.wav',
    Sfx.gameOver: 'sfx_game_over.wav',
    Sfx.whoosh: 'sfx_whoosh.wav',
    Sfx.brake: 'sfx_brake.wav',
    Sfx.challenge: 'sfx_challenge.wav',
  };

  static String _memeFile(MemeSound s) => 'meme_${s.name}.wav';

  /// Optional recorded voice line per meme event, e.g. `voice_chase_start.wav`.
  /// Not shipped; drop original or licensed recordings into assets/audio/.
  static String voiceFile(MemeEvent e) =>
      'voice_${e.name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}')}.wav';

  static const Map<LoopSound, String> _loopFiles = {
    LoopSound.engine: 'loop_engine.wav',
    LoopSound.siren: 'loop_siren.wav',
    LoopSound.ambulance: 'loop_ambulance.wav',
  };

  static const Map<LoopSound, double> _loopGain = {
    LoopSound.engine: 0.35,
    LoopSound.siren: 0.55,
    LoopSound.ambulance: 0.6,
  };

  static const Map<MusicTrack, String> _musicFiles = {
    MusicTrack.menu: 'music_menu.wav',
    MusicTrack.ride: 'music_ride.wav',
  };

  final Set<String> _available = {};
  final Map<LoopSound, AudioPlayer> _loops = {};
  final Set<LoopSound> _wantedLoops = {};
  AudioPool? _cashPool;
  MusicTrack? _currentMusic;
  bool _initialized = false;
  bool _loopsPaused = false;

  GameSettings get settings => _settings();

  Future<void> init() async {
    if (_initialized || !backendEnabled) return;
    _initialized = true;
    final files = [
      ..._sfxFiles.values,
      ..._loopFiles.values,
      ..._musicFiles.values,
      for (final m in MemeSound.values) _memeFile(m),
    ];
    // Voice lines are optional, so only load the ones actually bundled.
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets().toSet();
      for (final e in MemeEvent.values) {
        if (assets.contains('assets/audio/${voiceFile(e)}')) files.add(voiceFile(e));
      }
    } catch (_) {}
    for (final f in files) {
      try {
        await FlameAudio.audioCache.load(f);
        _available.add(f);
      } catch (_) {
        debugPrint('Optional audio asset missing: $f');
      }
    }
    await _guard(() async {
      FlameAudio.bgm.initialize();
      if (_available.contains(_sfxFiles[Sfx.cash])) {
        _cashPool = await FlameAudio.createPool(_sfxFiles[Sfx.cash]!, maxPlayers: 4);
      }
    });
  }

  bool get _canPlay => backendEnabled && _initialized;

  void play(Sfx sfx, {double gain = 1}) {
    if (!_canPlay || !settings.sfxEnabled) return;
    final file = _sfxFiles[sfx]!;
    if (!_available.contains(file)) return;
    final volume = (settings.sfxVolume * gain).clamp(0.0, 1.0);
    if (volume <= 0) return;
    if (sfx == Sfx.cash && _cashPool != null) {
      unawaited(_guard(() => _cashPool!.start(volume: volume)));
    } else {
      unawaited(_guard(() => FlameAudio.play(file, volume: volume)));
    }
  }

  /// Plays a meme reaction: a recorded voice line if one is bundled,
  /// otherwise an original comedic stinger. Controlled by the separate
  /// "Meme sounds" setting.
  void playMeme(MemeEvent event, MemeSound fallback) {
    if (!_canPlay || !settings.memeSounds) return;
    final voice = voiceFile(event);
    final file = _available.contains(voice) ? voice : _memeFile(fallback);
    if (!_available.contains(file)) return;
    final volume = (settings.sfxVolume * 0.8).clamp(0.0, 1.0);
    if (volume <= 0) return;
    unawaited(_guard(() => FlameAudio.play(file, volume: volume)));
  }

  void startLoop(LoopSound loop) {
    _wantedLoops.add(loop);
    if (!_canPlay || !settings.sfxEnabled || _loops.containsKey(loop)) return;
    final file = _loopFiles[loop]!;
    if (!_available.contains(file)) return;
    unawaited(
      _guard(() async {
        final player = await FlameAudio.loop(file, volume: _loopVolume(loop));
        // The loop may have been stopped while the player was starting.
        if (!_wantedLoops.contains(loop) || _loops.containsKey(loop)) {
          await player.dispose();
          return;
        }
        _loops[loop] = player;
        if (_loopsPaused) await player.pause();
      }),
    );
  }

  void stopLoop(LoopSound loop) {
    _wantedLoops.remove(loop);
    final player = _loops.remove(loop);
    if (player != null) unawaited(_guard(() => player.dispose()));
  }

  void stopAllLoops() {
    for (final loop in LoopSound.values) {
      stopLoop(loop);
    }
    _loopsPaused = false;
  }

  void pauseLoops() {
    _loopsPaused = true;
    for (final p in _loops.values) {
      unawaited(_guard(() => p.pause()));
    }
  }

  void resumeLoops() {
    _loopsPaused = false;
    for (final p in _loops.values) {
      unawaited(_guard(() => p.resume()));
    }
  }

  double _loopVolume(LoopSound loop) => (settings.sfxVolume * _loopGain[loop]!).clamp(0.0, 1.0);

  void playMusic(MusicTrack track) {
    if (!_canPlay) return;
    final file = _musicFiles[track]!;
    if (!settings.musicEnabled || !_available.contains(file)) {
      stopMusic();
      _currentMusic = track;
      return;
    }
    if (_currentMusic == track && FlameAudio.bgm.isPlaying) return;
    _currentMusic = track;
    unawaited(_guard(() => FlameAudio.bgm.play(file, volume: settings.musicVolume * 0.7)));
  }

  void stopMusic() {
    if (!_canPlay) return;
    unawaited(_guard(() => FlameAudio.bgm.stop()));
  }

  void pauseMusic() {
    if (!_canPlay) return;
    unawaited(_guard(() => FlameAudio.bgm.pause()));
  }

  void resumeMusic() {
    if (!_canPlay || !settings.musicEnabled) return;
    unawaited(_guard(() => FlameAudio.bgm.resume()));
  }

  /// Re-applies volume and enable flags after the settings screen changes.
  void applySettings() {
    if (!_canPlay) return;
    final track = _currentMusic;
    if (!settings.musicEnabled) {
      stopMusic();
    } else if (track != null) {
      if (FlameAudio.bgm.isPlaying) {
        unawaited(_guard(() => FlameAudio.bgm.audioPlayer.setVolume(settings.musicVolume * 0.7)));
      } else {
        _currentMusic = null;
        playMusic(track);
      }
    }
    if (!settings.sfxEnabled) {
      final wanted = Set.of(_wantedLoops);
      stopAllLoops();
      _wantedLoops.addAll(wanted);
    } else {
      for (final e in _loops.entries) {
        unawaited(_guard(() => e.value.setVolume(_loopVolume(e.key))));
      }
      for (final loop in Set.of(_wantedLoops)) {
        startLoop(loop);
      }
    }
  }

  void haptic({bool heavy = false}) {
    if (!settings.haptics || !backendEnabled) return;
    unawaited(_guard(() => heavy ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact()));
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('Audio error ignored: $e');
    }
  }
}
