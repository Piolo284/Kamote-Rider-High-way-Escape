import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Optional artwork that replaces the procedural placeholder art.
///
/// Drop PNGs into `assets/images/sprites/` using these names and they are
/// picked up automatically on the next launch (no code changes):
///
/// * `bike_<motorcycle id>.png` – e.g. `bike_kamote_110.png` (drawn 30×60, front up)
/// * `vehicle_<type>.png` – car, taxi, jeepney, bus, truck, tricycle, van (front up)
/// * `cash.png`, `fuel.png`, `officer.png`, `ambulance.png`
///
/// Missing files are simply skipped, so the game always stays playable.
class SpriteOverrides {
  SpriteOverrides();

  static const String folder = 'assets/images/sprites/';

  final Map<String, Sprite> _sprites = {};

  Sprite? get(String key) => _sprites[key];

  int get count => _sprites.length;

  Future<void> load(Images images) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final files = manifest.listAssets().where((a) => a.startsWith(folder) && a.endsWith('.png'));
      for (final path in files) {
        final key = path.substring(folder.length, path.length - 4);
        try {
          // Flame's image cache is rooted at assets/images/.
          final image = await images.load(path.substring('assets/images/'.length));
          _sprites[key] = Sprite(image);
        } catch (e) {
          debugPrint('Could not load sprite override $path: $e');
        }
      }
    } catch (e) {
      debugPrint('Sprite overrides unavailable, using procedural art: $e');
    }
  }
}
