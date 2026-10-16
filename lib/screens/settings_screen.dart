import 'package:flutter/material.dart';

import '../game/systems/meme_event_manager.dart';
import '../services/app_services.dart';
import '../services/audio_service.dart';
import '../widgets/ui_kit.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    final profile = services.profile;

    void changed() {
      profile.commit();
      services.audio.applySettings();
    }

    return KScaffold(
      title: 'SETTINGS',
      child: ListenableBuilder(
        listenable: profile,
        builder: (context, _) {
          final s = profile.settings;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              KPanel(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Music'),
                      secondary: const Icon(Icons.music_note_rounded),
                      value: s.musicEnabled,
                      onChanged: (v) {
                        s.musicEnabled = v;
                        changed();
                        services.audio.playMusic(MusicTrack.menu);
                      },
                    ),
                    _VolumeSlider(
                      value: s.musicVolume,
                      enabled: s.musicEnabled,
                      onChanged: (v) => s.musicVolume = v,
                      onChangeEnd: (_) => changed(),
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Sound effects'),
                      secondary: const Icon(Icons.volume_up_rounded),
                      value: s.sfxEnabled,
                      onChanged: (v) {
                        s.sfxEnabled = v;
                        changed();
                      },
                    ),
                    _VolumeSlider(
                      value: s.sfxVolume,
                      enabled: s.sfxEnabled,
                      onChanged: (v) => s.sfxVolume = v,
                      onChangeEnd: (_) {
                        changed();
                        services.audio.play(Sfx.cash);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              KPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: const Text('Meme sounds'),
                      subtitle: const Text('Funny stingers & voice lines (separate from other sounds)'),
                      secondary: const Icon(Icons.campaign_rounded),
                      value: s.memeSounds,
                      onChanged: (v) {
                        s.memeSounds = v;
                        changed();
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
                      child: Text('Meme pop-ups', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SegmentedButton<MemePopupMode>(
                        segments: const [
                          ButtonSegment(value: MemePopupMode.full, label: Text('Full')),
                          ButtonSegment(value: MemePopupMode.reduced, label: Text('Reduced')),
                          ButtonSegment(value: MemePopupMode.off, label: Text('Off')),
                        ],
                        selected: {s.memePopups},
                        showSelectedIcon: false,
                        onSelectionChanged: (v) {
                          s.memePopups = v.first;
                          changed();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              KPanel(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('On-screen steering buttons'),
                      subtitle: const Text('Swipe steering always works'),
                      secondary: const Icon(Icons.swap_horiz_rounded),
                      value: s.showSteerButtons,
                      onChanged: (v) {
                        s.showSteerButtons = v;
                        changed();
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Vibration'),
                      secondary: const Icon(Icons.vibration_rounded),
                      value: s.haptics,
                      onChanged: (v) {
                        s.haptics = v;
                        changed();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const KPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HOW TO PLAY', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    SizedBox(height: 8),
                    Text(
                      '• Swipe left/right (or use the arrow buttons) to change lanes.\n'
                      '• Grab paper bills for cash and red jerry cans for fuel.\n'
                      '• Hitting a car\'s side, a barrier or the guardrail starts a 10-second LTO chase. '
                      'Crash again before it ends and you get ticketed and jailed.\n'
                      '• Potholes and cones only slow you down.\n'
                      '• Never hit oncoming traffic head-on (left lanes)!\n'
                      '• Every kilometer takes you to a new part of the highway.\n'
                      '• Pass hazards by a hair for NEAR MISS bonuses; dodges build a combo that a crash resets.\n'
                      '• Random challenges (animal crossings, road works, convoys, LTO surprises...) are announced '
                      'under the top bar. Clear them without touching anything for bonus pesos.\n'
                      '• Dogs, cats and chickens are never hurt: bumping one just stops you short.',
                      style: TextStyle(color: KColors.muted, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ArcadeButton(
                label: 'RESET PROGRESS',
                icon: Icons.delete_forever_rounded,
                color: KColors.red,
                textColor: Colors.white,
                fontSize: 16,
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: KColors.panel,
                      title: const Text('Reset all progress?'),
                      content: const Text('Wallet, bikes, records and missions will be erased. Settings are kept.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: KColors.red),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('RESET'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) await profile.resetProgress();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VolumeSlider extends StatefulWidget {
  const _VolumeSlider({required this.value, required this.enabled, required this.onChanged, required this.onChangeEnd});

  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  late double _v = widget.value;

  @override
  void didUpdateWidget(_VolumeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _v = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const Icon(Icons.volume_down_rounded, color: KColors.muted),
          Expanded(
            child: Slider(
              value: _v,
              onChanged: widget.enabled
                  ? (v) {
                      setState(() => _v = v);
                      widget.onChanged(v);
                    }
                  : null,
              onChangeEnd: widget.enabled ? widget.onChangeEnd : null,
            ),
          ),
          Text('${(_v * 100).round()}%', style: const TextStyle(color: KColors.muted)),
        ],
      ),
    );
  }
}
