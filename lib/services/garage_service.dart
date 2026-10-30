import '../models/motorcycle_model.dart';
import '../models/upgrade_model.dart';
import 'player_profile.dart';

enum PurchaseResult { success, alreadyOwned, insufficientFunds, unknownBike }

enum UpgradeResult { success, maxed, insufficientFunds, locked, unknownBike }

/// Purchase and selection rules for the impound garage.
class GarageService {
  GarageService(this._profile);

  final PlayerProfile _profile;

  bool isUnlocked(String id) => _profile.data.unlockedBikes.contains(id);

  bool isSelected(String id) => _profile.data.selectedBike == id;

  int get unlockedCount => _profile.data.unlockedBikes.length;

  bool canBuy(String id) {
    final bike = MotorcycleCatalog.byIdOrNull(id);
    return bike != null && !isUnlocked(id) && _profile.data.wallet >= bike.price;
  }

  /// Deducts the price and unlocks the bike. Purchases are synchronous, so a
  /// repeated tap sees [PurchaseResult.alreadyOwned] and is never charged twice.
  PurchaseResult buy(String id) {
    final bike = MotorcycleCatalog.byIdOrNull(id);
    if (bike == null) return PurchaseResult.unknownBike;
    if (isUnlocked(id)) return PurchaseResult.alreadyOwned;
    if (_profile.data.wallet < bike.price) return PurchaseResult.insufficientFunds;
    _profile.data.wallet -= bike.price;
    _profile.data.unlockedBikes.add(id);
    _profile.commit();
    return PurchaseResult.success;
  }

  UpgradeLevels upgradesOf(String id) => _profile.data.upgradesOf(id);

  BikeStats statsOf(Motorcycle bike) => BikeStats.of(bike, upgradesOf(bike.id));

  /// Price of the next level of [stat] on [id], or null when it is maxed.
  int? upgradeCost(String id, UpgradeStat stat) {
    final bike = MotorcycleCatalog.byIdOrNull(id);
    if (bike == null) return null;
    return UpgradeCatalog.costFor(bike, upgradesOf(id)[stat]);
  }

  /// Buys one level of [stat] for an owned bike. Like [buy], it is
  /// synchronous, so a double tap can never charge twice for one level.
  UpgradeResult upgrade(String id, UpgradeStat stat) {
    final bike = MotorcycleCatalog.byIdOrNull(id);
    if (bike == null) return UpgradeResult.unknownBike;
    if (!isUnlocked(id)) return UpgradeResult.locked;
    final levels = upgradesOf(id);
    final cost = UpgradeCatalog.costFor(bike, levels[stat]);
    if (cost == null) return UpgradeResult.maxed;
    if (_profile.data.wallet < cost) return UpgradeResult.insufficientFunds;
    _profile.data.wallet -= cost;
    levels.raise(stat);
    _profile.commit();
    return UpgradeResult.success;
  }

  bool select(String id) {
    if (!isUnlocked(id)) return false;
    if (_profile.data.selectedBike != id) {
      _profile.data.selectedBike = id;
      _profile.commit();
    }
    return true;
  }
}
