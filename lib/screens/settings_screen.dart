import 'package:flutter/material.dart';

import '../game/systems/meme_event_manager.dart';
import '../game/systems/swipe_steering.dart';
import '../game/systems/tilt_steering.dart';
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
                    const Divider(),
                    _SensitivitySlider(
                      value: s.steerSensitivity,
                      onChangeEnd: (v) {
                        s.steerSensitivity = v;
                        changed();
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Tilt steering'),
                      subtitle: const Text(
                        'Tilt the phone left or right to pick a lane. Hold it comfortably when the ride '
                        'starts: that grip counts as straight. Swipe and buttons still work.',
                      ),
                      secondary: const Icon(Icons.screen_rotation_rounded),
                      value: s.tiltSteering,
                      onChanged: (v) {
                        s.tiltSteering = v;
                        changed();
                      },
                    ),
                    if (s.tiltSteering)
                      _TiltRangeSlider(
                        value: s.tiltRange,
                        onChangeEnd: (v) {
                          s.tiltRange = v;
                          changed();
                        },
                      ),
                    const Divider(),
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
                      '• Hitting a car\'s side, a barrier, the guardrail or an LTO officer is a traffic '
                      'violation with a ₱100 fine from your run cash, and starts a 10-second LTO chase. '
                      'Crash again before it ends and you get ticketed and jailed.\n'
                      '• Tap the shop button to buy gasoline or a speed booster with your run cash. '
                      'The ride pauses while you shop.\n'
                      '• Every 5 km another LTO officer joins the pursuit and may block a lane beside you.\n'
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

/// How far to tilt for the outer lanes, from a small to a big tilt.
class _TiltRangeSlider extends StatefulWidget {
  const _TiltRangeSlider({required this.value, required this.onChangeEnd});

  final double value;
  final ValueChanged<double> onChangeEnd;

  @override
  State<_TiltRangeSlider> createState() => _TiltRangeSliderState();
}

class _TiltRangeSliderState extends State<_TiltRangeSlider> {
  late double _v = widget.value;

  @override
  void didUpdateWidget(_TiltRangeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _v = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    const min = TiltSteering.minRange;
    const max = TiltSteering.maxRange;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Tilt needed', style: TextStyle(fontSize: 16))),
              Text(
                '${_v.round()}°',
                style: const TextStyle(color: KColors.yellow, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Slider(
            value: _v,
            min: min,
            max: max,
            divisions: ((max - min) / 1).round(),
            label: '${_v.round()}°',
            onChanged: (v) => setState(() => _v = v),
            onChangeEnd: widget.onChangeEnd,
          ),
          const Row(
            children: [
              Expanded(
                child: Text('Small tilt', style: TextStyle(color: KColors.muted, fontSize: 12)),
              ),
              Expanded(
                child: Text(
                  'Big tilt',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: KColors.muted, fontSize: 12),
                ),
              ),
            ],
          ),
          Text(
            'Tilt ${_v.round()}° left or right to reach the outer lane.',
            style: const TextStyle(color: KColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Swipe sensitivity from 0.5× to 2× in quarter steps.
class _SensitivitySlider extends StatefulWidget {
  const _SensitivitySlider({required this.value, required this.onChangeEnd});

  final double value;
  final ValueChanged<double> onChangeEnd;

  @override
  State<_SensitivitySlider> createState() => _SensitivitySliderState();
}

class _SensitivitySliderState extends State<_SensitivitySlider> {
  late double _v = widget.value;

  @override
  void didUpdateWidget(_SensitivitySlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _v = widget.value;
  }

  String get _times => '${_v.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '')}×';

  String get _label {
    final x = _times;
    if (_v < 0.9) return 'Low · $x';
    if (_v > 1.1) return 'High · $x';
    return 'Normal · $x';
  }

  @override
  Widget build(BuildContext context) {
    const min = SwipeSteering.minSensitivity;
    const max = SwipeSteering.maxSensitivity;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swipe_rounded, color: KColors.muted),
              const SizedBox(width: 16),
              const Expanded(child: Text('Swipe sensitivity', style: TextStyle(fontSize: 16))),
              Text(
                _label,
                style: const TextStyle(color: KColors.yellow, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Slider(
            value: _v,
            min: min,
            max: max,
            divisions: ((max - min) * 4).round(),
            label: _times,
            onChanged: (v) => setState(() => _v = v),
            onChangeEnd: widget.onChangeEnd,
          ),
          const Row(
            children: [
              Expanded(
                child: Text('Longer swipe', style: TextStyle(color: KColors.muted, fontSize: 12)),
              ),
              Expanded(
                child: Text(
                  'Shorter swipe',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: KColors.muted, fontSize: 12),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'One lane every ${(SwipeSteering.baseStep / _v).round()} px of swipe. '
                  'Buttons and keys are not affected.',
                  style: const TextStyle(color: KColors.muted, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: _v == 1
                    ? null
                    : () {
                        setState(() => _v = 1);
                        widget.onChangeEnd(1);
                      },
                child: const Text('RESET'),
              ),
            ],
          ),
        ],
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
