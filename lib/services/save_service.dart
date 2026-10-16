import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_save_model.dart';

/// Reads and writes [PlayerSaveModel] to SharedPreferences as one JSON blob.
///
/// Writes are chained so they always land in the order they were requested
/// and never block the game loop.
class SaveService {
  SaveService(this._prefs);

  static const String storageKey = 'kamote_rider_save';

  final SharedPreferences _prefs;
  Future<void> _pending = Future.value();

  static Future<SaveService> create() async => SaveService(await SharedPreferences.getInstance());

  PlayerSaveModel load() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return PlayerSaveModel();
    try {
      return PlayerSaveModel.fromJson(jsonDecode(raw));
    } catch (e) {
      debugPrint('Save data corrupted, using defaults: $e');
      return PlayerSaveModel();
    }
  }

  Future<void> save(PlayerSaveModel model) {
    final encoded = jsonEncode(model.toJson());
    _pending = _pending
        .then((_) => _prefs.setString(storageKey, encoded))
        .then(
          (_) {},
          onError: (Object e) {
            debugPrint('Failed to save progress: $e');
          },
        );
    return _pending;
  }

  Future<void> clear() {
    _pending = _pending.then((_) => _prefs.remove(storageKey)).then((_) {});
    return _pending;
  }
}
