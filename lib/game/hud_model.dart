import 'dart:ui';

import 'package:flutter/foundation.dart';

class HudToast {
  HudToast(this.id, this.text, this.color, this.remaining);

  final int id;
  final String text;
  final Color color;
  double remaining;
}

class HudBanner {
  const HudBanner(this.id, this.title, this.subtitle, this.color);

  final int id;
  final String title;
  final String subtitle;
  final Color color;
}

/// Short meme pop-up shown in the safe area below the rider.
class HudMeme {
  const HudMeme(this.id, this.text);

  final int id;
  final String text;
}

/// Live values shown by the Flutter HUD overlay.
///
/// The game writes every frame; listeners are only notified when a value
/// that is actually displayed (after rounding) has changed.
class HudModel extends ChangeNotifier {
  int distanceMeters = 0;
  int speedKmh = 0;
  double fuelFraction = 1;
  bool lowFuel = false;
  int runCash = 0;
  double chaseRemaining = 0;
  bool chaseActive = false;
  String bikeName = '';
  String environmentName = '';
  Color environmentColor = const Color(0xFF42A5F5);
  bool invulnerable = false;
  String difficultyLabel = 'MEDIUM';
  Color difficultyColor = const Color(0xFFFFC400);
  int combo = 0;
  bool undergroundActive = false;
  double undergroundRemaining = 0;

  HudBanner? banner;

  /// Challenge announcement ("ROAD WORKS, IDOL!").
  HudBanner? announcement;
  HudMeme? meme;
  final List<HudToast> toasts = [];

  int _nextId = 0;
  bool _dirty = false;

  void setDistance(double meters) => _set(meters.floor(), distanceMeters, (v) => distanceMeters = v);
  void setSpeed(double kmh) => _set(kmh.round(), speedKmh, (v) => speedKmh = v);
  void setRunCash(int cash) => _set(cash, runCash, (v) => runCash = v);
  void setLowFuel(bool low) => _set(low, lowFuel, (v) => lowFuel = v);
  void setInvulnerable(bool value) => _set(value, invulnerable, (v) => invulnerable = v);

  void setFuel(double fraction) {
    // Quantize to 0.5% steps to avoid needless rebuilds.
    final q = (fraction * 200).round() / 200;
    _set(q, fuelFraction, (v) => fuelFraction = v);
  }

  void setChase({required bool active, required double remaining}) {
    _set(active, chaseActive, (v) => chaseActive = v);
    final q = (remaining * 10).ceil() / 10;
    _set(q, chaseRemaining, (v) => chaseRemaining = v);
  }

  void setUnderground({required bool active, required double remaining}) {
    _set(active, undergroundActive, (v) => undergroundActive = v);
    _set((remaining * 10).ceil() / 10, undergroundRemaining, (v) => undergroundRemaining = v);
  }

  void setBike(String name) => _set(name, bikeName, (v) => bikeName = v);

  void setDifficulty(String label, Color color) {
    _set(label, difficultyLabel, (v) => difficultyLabel = v);
    _set(color, difficultyColor, (v) => difficultyColor = v);
  }

  void setCombo(int value) => _set(value, combo, (v) => combo = v);

  void announce(String title, String subtitle, Color color) {
    announcement = HudBanner(_nextId++, title, subtitle, color);
    _dirty = true;
  }

  void showMeme(String text) {
    meme = HudMeme(_nextId++, text);
    _dirty = true;
  }

  void setEnvironment(String name, Color color) {
    _set(name, environmentName, (v) => environmentName = v);
    _set(color, environmentColor, (v) => environmentColor = v);
  }

  void showBanner(String title, String subtitle, Color color) {
    banner = HudBanner(_nextId++, title, subtitle, color);
    _dirty = true;
  }

  void toast(String text, {Color color = const Color(0xFFFFFFFF), double seconds = 2.2}) {
    toasts.add(HudToast(_nextId++, text, color, seconds));
    if (toasts.length > 3) toasts.removeAt(0);
    _dirty = true;
  }

  /// Ages toasts; call once per simulated frame.
  void tick(double dt) {
    if (toasts.isEmpty) return;
    for (final t in toasts) {
      t.remaining -= dt;
    }
    final before = toasts.length;
    toasts.removeWhere((t) => t.remaining <= 0);
    if (toasts.length != before) _dirty = true;
  }

  void resetRun() {
    distanceMeters = 0;
    speedKmh = 0;
    fuelFraction = 1;
    lowFuel = false;
    runCash = 0;
    chaseRemaining = 0;
    chaseActive = false;
    undergroundActive = false;
    undergroundRemaining = 0;
    invulnerable = false;
    banner = null;
    announcement = null;
    meme = null;
    combo = 0;
    toasts.clear();
    _dirty = true;
  }

  /// Sends one notification if anything changed since the last flush.
  void flush() {
    if (!_dirty) return;
    _dirty = false;
    notifyListeners();
  }

  void _set<T>(T next, T current, void Function(T) assign) {
    if (next == current) return;
    assign(next);
    _dirty = true;
  }
}
