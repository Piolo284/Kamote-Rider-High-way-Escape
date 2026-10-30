import '../game_config.dart';

/// Fuel tank for one run. Never goes below zero or above [capacity].
class FuelSystem {
  FuelSystem({double capacity = GameConfig.maxFuel}) : _capacity = capacity, _fuel = capacity;

  /// Share of the tank under which fuel counts as low.
  static const double lowFraction = GameConfig.lowFuelThreshold / GameConfig.maxFuel;

  double _capacity;
  double _fuel;
  double drainPerSecond = GameConfig.baseFuelDrainPerSecond;

  /// Tank size; bigger with the Fuel Capacity upgrade.
  double get capacity => _capacity;
  double get fuel => _fuel;
  double get fraction => _fuel / _capacity;
  bool get isEmpty => _fuel <= 0;
  bool get isFull => _fuel >= _capacity - 0.01;
  bool get isLow => fraction <= lowFraction;

  void reset({required double drainMultiplier, double capacity = GameConfig.maxFuel}) {
    _capacity = capacity <= 0 ? GameConfig.maxFuel : capacity;
    _fuel = _capacity;
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
    _fuel = (_fuel + amount).clamp(0.0, _capacity);
    return _fuel - before;
  }

  /// Refills a share of the whole tank (shop gasoline). Never overfills.
  double refillFraction(double share) => refill(_capacity * share);

  /// Test/debug helper.
  void setFuel(double value) => _fuel = value.clamp(0.0, _capacity);
}
