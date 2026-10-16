import 'package:kamote_rider/services/app_services.dart';
import 'package:kamote_rider/services/audio_service.dart';
import 'package:kamote_rider/services/player_profile.dart';
import 'package:kamote_rider/services/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds real services on top of in-memory SharedPreferences with audio
/// disabled.
Future<AppServices> makeServices({Map<String, Object> initial = const {}}) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final profile = PlayerProfile(SaveService(prefs));
  final audio = AudioService(() => profile.settings, backendEnabled: false);
  return AppServices(profile: profile, audio: audio);
}

/// Simulates an app restart: a fresh profile reading the same storage.
Future<PlayerProfile> reloadProfile() async {
  final prefs = await SharedPreferences.getInstance();
  return PlayerProfile(SaveService(prefs));
}
