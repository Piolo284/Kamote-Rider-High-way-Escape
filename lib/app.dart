import 'package:flutter/material.dart';

import 'game/difficulty_config.dart';
import 'screens/collection_screen.dart';
import 'screens/difficulty_screen.dart';
import 'screens/game_screen.dart';
import 'screens/garage_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/mission_screen.dart';
import 'screens/settings_screen.dart';
import 'services/app_services.dart';
import 'widgets/ui_kit.dart';

class Routes {
  Routes._();

  static const menu = '/';
  static const difficulty = '/difficulty';
  static const play = '/play';
  static const garage = '/garage';
  static const missions = '/missions';
  static const collection = '/collection';
  static const leaderboard = '/leaderboard';
  static const settings = '/settings';
}

class KamoteApp extends StatelessWidget {
  const KamoteApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return AppServicesScope(
      services: services,
      child: MaterialApp(
        title: 'Kamote Rider: Highway Escape',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: KColors.background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: KColors.yellow,
            brightness: Brightness.dark,
            surface: KColors.panel,
          ),
          useMaterial3: true,
        ),
        initialRoute: Routes.menu,
        onGenerateRoute: (settings) {
          final Widget page = switch (settings.name) {
            Routes.difficulty => const DifficultyScreen(),
            Routes.play => GameScreen(difficulty: settings.arguments as DifficultyLevel?),
            Routes.garage => GarageScreen(initialBikeId: settings.arguments as String?),
            Routes.missions => const MissionScreen(),
            Routes.collection => const CollectionScreen(),
            Routes.leaderboard => const LeaderboardScreen(),
            Routes.settings => const SettingsScreen(),
            _ => const MainMenuScreen(),
          };
          return PageRouteBuilder(
            settings: settings,
            transitionDuration: const Duration(milliseconds: 280),
            pageBuilder: (context, animation, secondary) => page,
            transitionsBuilder: (context, animation, secondary, child) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
