import 'package:flutter/widgets.dart';

import 'audio_service.dart';
import 'garage_service.dart';
import 'mission_service.dart';
import 'player_profile.dart';

/// Long-lived services shared by every screen.
class AppServices {
  AppServices({required this.profile, required this.audio})
    : garage = GarageService(profile),
      missions = MissionService(profile);

  final PlayerProfile profile;
  final AudioService audio;
  final GarageService garage;
  final MissionService missions;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppServicesScope>();
    assert(scope != null, 'AppServicesScope missing above $context');
    return scope!.services;
  }
}

class AppServicesScope extends InheritedWidget {
  const AppServicesScope({super.key, required this.services, required super.child});

  final AppServices services;

  @override
  bool updateShouldNotify(AppServicesScope oldWidget) => services != oldWidget.services;
}
