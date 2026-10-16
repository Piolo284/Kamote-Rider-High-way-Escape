import 'package:flutter/material.dart';

import '../app.dart';
import '../models/motorcycle_model.dart';
import '../services/app_services.dart';
import '../services/audio_service.dart';
import '../widgets/bike_preview.dart';
import '../widgets/road_backdrop.dart';
import '../widgets/ui_kit.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  bool _navigating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppServices.of(context).audio.playMusic(MusicTrack.menu);
  }

  /// Opens a screen once, even if the button is tapped repeatedly, and
  /// restores the menu music on return.
  Future<void> _open(String route, {Object? arguments}) async {
    if (_navigating) return;
    _navigating = true;
    final audio = AppServices.of(context).audio;
    await Navigator.of(context).pushNamed(route, arguments: arguments);
    _navigating = false;
    // Only restore menu music if the menu is actually showing again (a
    // replaced route, e.g. difficulty -> game, also completes the push).
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) audio.playMusic(MusicTrack.menu);
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    return Scaffold(
      body: RoadBackdrop(
        speed: 0.6,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: services.profile,
            builder: (context, _) {
              final data = services.profile.data;
              final bike = services.profile.selectedBike;
              final settings = services.profile.settings;
              final claimable = services.missions.claimableCount;
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                WalletChip(amount: data.wallet),
                                const Spacer(),
                                _ToggleIcon(
                                  on: settings.musicEnabled,
                                  onIcon: Icons.music_note_rounded,
                                  offIcon: Icons.music_off_rounded,
                                  tooltip: 'Music',
                                  onTap: () {
                                    settings.musicEnabled = !settings.musicEnabled;
                                    services.profile.commit();
                                    services.audio.applySettings();
                                    services.audio.playMusic(MusicTrack.menu);
                                  },
                                ),
                                _ToggleIcon(
                                  on: settings.sfxEnabled,
                                  onIcon: Icons.volume_up_rounded,
                                  offIcon: Icons.volume_off_rounded,
                                  tooltip: 'Sound effects',
                                  onTap: () {
                                    settings.sfxEnabled = !settings.sfxEnabled;
                                    services.profile.commit();
                                    services.audio.applySettings();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            const _Logo(),
                            const SizedBox(height: 14),
                            _SelectedBikeCard(
                              bike: bike,
                              bestDistance: data.bestDistance,
                              onTap: () => _open(Routes.garage, arguments: bike.id),
                            ),
                            const SizedBox(height: 18),
                            ArcadeButton(
                              label: 'PLAY',
                              icon: Icons.sports_motorsports_rounded,
                              height: 68,
                              fontSize: 28,
                              onPressed: () => _open(Routes.difficulty),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ArcadeButton(
                                    label: 'GARAGE',
                                    icon: Icons.garage_rounded,
                                    color: KColors.blue,
                                    textColor: Colors.white,
                                    fontSize: 16,
                                    onPressed: () => _open(Routes.garage),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ArcadeButton(
                                    label: 'MISSIONS',
                                    icon: Icons.flag_rounded,
                                    color: KColors.green,
                                    textColor: Colors.white,
                                    fontSize: 16,
                                    badge: claimable > 0 ? '$claimable' : null,
                                    onPressed: () => _open(Routes.missions),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ArcadeButton(
                              label: 'LEADERBOARD',
                              icon: Icons.leaderboard_rounded,
                              color: const Color(0xFFF57C00),
                              textColor: Colors.white,
                              fontSize: 16,
                              onPressed: () => _open(Routes.leaderboard),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ArcadeButton(
                                    label: 'COLLECTION',
                                    icon: Icons.collections_rounded,
                                    color: const Color(0xFF8E24AA),
                                    textColor: Colors.white,
                                    fontSize: 15,
                                    onPressed: () => _open(Routes.collection),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ArcadeButton(
                                    label: 'SETTINGS',
                                    icon: Icons.settings_rounded,
                                    color: const Color(0xFF546E7A),
                                    textColor: Colors.white,
                                    fontSize: 15,
                                    onPressed: () => _open(Routes.settings),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'A fictional arcade game. Ride safe in real life!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: KColors.muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Transform.rotate(
          angle: -0.05,
          child: Stack(
            children: [
              Text(
                'KAMOTE\nRIDER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 58,
                  height: 0.92,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 2,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 10
                    ..color = const Color(0xFF1A1A1A),
                ),
              ),
              const Text(
                'KAMOTE\nRIDER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 58,
                  height: 0.92,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 2,
                  color: KColors.yellow,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(color: KColors.red, borderRadius: BorderRadius.circular(6)),
          child: const Text(
            'HIGHWAY ESCAPE',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 4, fontSize: 16),
          ),
        ),
      ],
    );
  }
}

class _SelectedBikeCard extends StatelessWidget {
  const _SelectedBikeCard({required this.bike, required this.bestDistance, required this.onTap});

  final Motorcycle bike;
  final double bestDistance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: KPanel(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        color: KColors.panel.withValues(alpha: 0.92),
        child: Row(
          children: [
            BikePreview(bike: bike, height: 96),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('YOUR RIDE', style: TextStyle(color: KColors.muted, fontSize: 11, letterSpacing: 2)),
                  Text(
                    bike.name,
                    style: const TextStyle(color: KColors.text, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${bike.topSpeedKmh.round()} km/h · Handling ${bike.handling} · Eff. ${bike.fuelEfficiency}',
                    style: const TextStyle(color: KColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded, color: KColors.yellow, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Best: ${formatDistance(bestDistance)}',
                        style: const TextStyle(color: KColors.text, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: KColors.muted),
          ],
        ),
      ),
    );
  }
}

class _ToggleIcon extends StatelessWidget {
  const _ToggleIcon({
    required this.on,
    required this.onIcon,
    required this.offIcon,
    required this.tooltip,
    required this.onTap,
  });

  final bool on;
  final IconData onIcon;
  final IconData offIcon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(on ? onIcon : offIcon, color: on ? KColors.text : KColors.muted),
      style: IconButton.styleFrom(backgroundColor: Colors.black38),
    );
  }
}
