import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/app_services.dart';
import 'services/audio_service.dart';
import 'services/player_profile.dart';
import 'services/save_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Saved progress must be loaded before any screen that shows it.
  final saveService = await SaveService.create();
  final profile = PlayerProfile(saveService);
  final audio = AudioService(() => profile.settings);
  // Audio is optional: never let a slow or missing backend block startup.
  await audio.init().timeout(const Duration(seconds: 5), onTimeout: () {});

  runApp(
    KamoteApp(
      services: AppServices(profile: profile, audio: audio),
    ),
  );
}
