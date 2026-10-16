import '../models/motorcycle_model.dart';
import 'player_profile.dart';

enum PurchaseResult { success, alreadyOwned, insufficientFunds, unknownBike }

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

  bool select(String id) {
    if (!isUnlocked(id)) return false;
    if (_profile.data.selectedBike != id) {
      _profile.data.selectedBike = id;
      _profile.commit();
    }
    return true;
  }
}
