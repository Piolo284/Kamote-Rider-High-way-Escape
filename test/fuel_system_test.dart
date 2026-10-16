import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/game/game_config.dart';
import 'package:kamote_rider/game/systems/fuel_system.dart';

void main() {
  group('FuelSystem', () {
    test('starts full and drains over time', () {
      final fuel = FuelSystem()..reset(drainMultiplier: 1);
      expect(fuel.fuel, GameConfig.maxFuel);
      fuel.consume(2);
      expect(fuel.fuel, closeTo(GameConfig.maxFuel - 2 * GameConfig.baseFuelDrainPerSecond, 1e-9));
    });

    test('efficient bikes drain slower', () {
      final thirsty = FuelSystem()..reset(drainMultiplier: 1.2);
      final frugal = FuelSystem()..reset(drainMultiplier: 0.8);
      thirsty.consume(5);
      frugal.consume(5);
      expect(frugal.fuel, greaterThan(thirsty.fuel));
    });

    test('refill never exceeds capacity', () {
      final fuel = FuelSystem()..reset(drainMultiplier: 1);
      fuel.consume(1);
      final added = fuel.refill(1000);
      expect(fuel.fuel, GameConfig.maxFuel);
      expect(added, closeTo(GameConfig.baseFuelDrainPerSecond, 1e-9));
    });

    test('clamps to zero and reports empty exactly once', () {
      final fuel = FuelSystem()..reset(drainMultiplier: 1);
      fuel.setFuel(0.5);
      expect(fuel.consume(10), isTrue);
      expect(fuel.fuel, 0);
      expect(fuel.isEmpty, isTrue);
      expect(fuel.consume(10), isFalse, reason: 'empty tank must not fire again');
      expect(fuel.fuel, 0, reason: 'fuel never goes negative');
    });

    test('low fuel warning threshold', () {
      final fuel = FuelSystem()..reset(drainMultiplier: 1);
      expect(fuel.isLow, isFalse);
      fuel.setFuel(GameConfig.lowFuelThreshold - 1);
      expect(fuel.isLow, isTrue);
    });
  });
}
