/// What a shop item does.
enum ShopItemKind { fuel, booster }

/// One thing the rider can buy mid-run with the money collected so far.
class ShopItem {
  const ShopItem({
    required this.id,
    required this.kind,
    required this.name,
    required this.price,
    this.fuelFraction = 0,
    this.boostSeconds = 0,
  });

  final String id;
  final ShopItemKind kind;
  final String name;
  final int price;

  /// Share of the tank refilled (fuel items).
  final double fuelFraction;

  /// Boost length in seconds (booster items).
  final double boostSeconds;

  String get effect => switch (kind) {
    ShopItemKind.fuel => '+${(fuelFraction * 100).round()}% fuel',
    ShopItemKind.booster => '${boostSeconds.round()} s speed boost',
  };
}

class ShopCatalog {
  ShopCatalog._();

  static const smallRefill = ShopItem(
    id: 'fuel_small',
    kind: ShopItemKind.fuel,
    name: 'Small Refill',
    price: 60,
    fuelFraction: 0.25,
  );
  static const mediumRefill = ShopItem(
    id: 'fuel_medium',
    kind: ShopItemKind.fuel,
    name: 'Medium Refill',
    price: 110,
    fuelFraction: 0.5,
  );
  static const largeRefill = ShopItem(
    id: 'fuel_large',
    kind: ShopItemKind.fuel,
    name: 'Large Refill',
    price: 200,
    fuelFraction: 1,
  );
  static const shortBooster = ShopItem(
    id: 'boost_short',
    kind: ShopItemKind.booster,
    name: 'Short Booster',
    price: 50,
    boostSeconds: 5,
  );
  static const mediumBooster = ShopItem(
    id: 'boost_medium',
    kind: ShopItemKind.booster,
    name: 'Medium Booster',
    price: 90,
    boostSeconds: 10,
  );
  static const longBooster = ShopItem(
    id: 'boost_long',
    kind: ShopItemKind.booster,
    name: 'Long Booster',
    price: 120,
    boostSeconds: 15,
  );

  static const List<ShopItem> fuel = [smallRefill, mediumRefill, largeRefill];
  static const List<ShopItem> boosters = [shortBooster, mediumBooster, longBooster];
  static const List<ShopItem> all = [...fuel, ...boosters];
}

enum ShopResult { success, insufficientFunds, tankFull, boostActive, boostCoolingDown, unavailable }

/// A temporary speed boost bought in the shop. It never protects the rider:
/// crashes and violations count as usual.
class BoostSystem {
  /// Top speed multiplier while a boost runs.
  static const double speedMultiplier = 1.3;

  /// Extra acceleration so the boost kicks in quickly.
  static const double accelerationMultiplier = 2;

  /// Wait after a boost ends before another can start.
  static const double cooldownSeconds = 15;

  double _remaining = 0;
  double _duration = 0;
  double _cooldown = 0;

  bool get active => _remaining > 0;
  double get remaining => _remaining;
  double get duration => _duration;
  bool get coolingDown => !active && _cooldown > 0;
  double get cooldown => _cooldown;
  bool get ready => !active && _cooldown <= 0;

  /// Starts a boost. Refused while one runs or during the cooldown.
  bool start(double seconds) {
    if (!ready || seconds <= 0) return false;
    _remaining = seconds;
    _duration = seconds;
    return true;
  }

  /// Advances the timers. Returns true on the frame the boost ends.
  bool update(double dt) {
    if (dt <= 0) return false;
    if (_remaining > 0) {
      _remaining -= dt;
      if (_remaining <= 0) {
        _remaining = 0;
        _cooldown = cooldownSeconds;
        return true;
      }
      return false;
    }
    if (_cooldown > 0) _cooldown = (_cooldown - dt).clamp(0.0, cooldownSeconds);
    return false;
  }

  void reset() {
    _remaining = 0;
    _duration = 0;
    _cooldown = 0;
  }
}
