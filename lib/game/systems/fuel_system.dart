import '../game_config.dart';

/// Fuel tank for one run. Never goes below zero or above [capacity].
class FuelSystem {
  FuelSystem({this.capacity = GameConfig.maxFuel, this.lowThreshold = GameConfig.lowFuelThreshold}) : _fuel = capacity;

  final double capacity;
  final double lowThreshold;
  double _fuel;
  double drainPerSecond = GameConfig.baseFuelDrainPerSecond;

  double get fuel => _fuel;
  double get fraction => _fuel / capacity;
  bool get isEmpty => _fuel <= 0;
  bool get isLow => _fuel <= lowThreshold;

  void reset({required double drainMultiplier}) {
    _fuel = capacity;
    drainPerSecond = GameConfig.baseFuelDrainPerSecond * drainMultiplier;
  }

  /// Burns fuel for [dt] seconds. [throttle] (0–1) scales consumption so a
  /// bike that is still accelerating burns less. Returns true only on the
  /// frame the tank runs dry.
  bool consume(double dt, {double throttle = 1}) {
    if (_fuel <= 0 || dt <= 0) return false;
    _fuel -= drainPerSecond * throttle.clamp(0.0, 1.0) * dt;
    if (_fuel <= 0) {
      _fuel = 0;
      return true;
    }
    return false;
  }

  /// Adds fuel up to capacity and returns the amount actually added.
  double refill(double amount) {
    if (amount <= 0) return 0;
    final before = _fuel;
    _fuel = (_fuel + amount).clamp(0.0, capacity);
    return _fuel - before;
  }

  /// Test/debug helper.
  void setFuel(double value) => _fuel = value.clamp(0.0, capacity);
}
