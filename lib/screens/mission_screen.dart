import 'package:flutter/material.dart';

import '../models/mission_model.dart';
import '../services/app_services.dart';
import '../services/audio_service.dart';
import '../widgets/reward_popup.dart';
import '../widgets/ui_kit.dart';

/// Lists missions with live progress; completed ones can be claimed once.
class MissionScreen extends StatelessWidget {
  const MissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    return KScaffold(
      title: 'MISSIONS',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ListenableBuilder(
            listenable: services.profile,
            builder: (context, _) => Center(child: WalletChip(amount: services.profile.data.wallet)),
          ),
        ),
      ],
      child: ListenableBuilder(
        listenable: services.profile,
        builder: (context, _) {
          final defs = [...MissionCatalog.all]
            ..sort((a, b) {
              final ca = services.missions.stateOf(a).completed ? 0 : 1;
              final cb = services.missions.stateOf(b).completed ? 0 : 1;
              return ca.compareTo(cb);
            });
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: defs.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == 0) {
                return const Text(
                  'Missions repeat: claiming a reward unlocks a tougher level of the same mission.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: KColors.muted, fontSize: 12),
                );
              }
              return _MissionTile(def: defs[i - 1]);
            },
          );
        },
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.def});

  final MissionDef def;

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    final state = services.missions.stateOf(def);
    final target = def.targetFor(state.level);
    final reward = def.rewardFor(state.level);
    final fraction = (state.progress / target).clamp(0.0, 1.0);
    final isDistance =
        def.objective == MissionObjective.lifetimeDistance ||
        def.objective == MissionObjective.singleRunDistance ||
        def.objective == MissionObjective.cleanDistance ||
        def.objective == MissionObjective.rideSpecificBike;
    final progressText = isDistance
        ? '${formatMeters(state.progress)} / ${formatMeters(target)}'
        : def.objective == MissionObjective.singleRunCash
        ? '${formatPeso(state.progress)} / ${formatPeso(target)}'
        : '${state.progress} / $target';

    return KPanel(
      border: state.completed ? KColors.yellow : null,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  def.titleFor(state.level),
                  style: const TextStyle(color: KColors.text, fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              _Tag(text: 'LV ${state.level + 1}', color: KColors.blue),
              const SizedBox(width: 6),
              _Tag(
                text: def.scope == MissionScope.lifetime ? 'ALL RUNS' : 'ONE RUN',
                color: def.scope == MissionScope.lifetime ? KColors.green : const Color(0xFFFF7043),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(def.descriptionFor(state.level), style: const TextStyle(color: KColors.muted)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 10,
                    color: state.completed ? KColors.yellow : KColors.green,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                progressText,
                style: const TextStyle(color: KColors.text, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.payments_rounded, color: KColors.yellow, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Reward ${formatPeso(reward)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: KColors.yellow, fontWeight: FontWeight.w800),
                ),
              ),
              SizedBox(
                width: 112,
                child: ArcadeButton(
                  label: state.completed ? 'CLAIM' : 'IN PROGRESS',
                  height: 40,
                  fontSize: state.completed ? 16 : 11,
                  onPressed: state.completed
                      ? () {
                          final title = def.titleFor(state.level);
                          final paid = services.missions.claim(def.id);
                          if (paid > 0) {
                            services.audio.play(Sfx.mission);
                            services.audio.haptic(heavy: true);
                            final next = services.missions.stateOf(def).level;
                            showMissionClaimedPopup(
                              context,
                              missionTitle: title,
                              reward: paid,
                              walletAfter: services.profile.data.wallet,
                              nextGoal: def.descriptionFor(next),
                              nextLevel: next + 1,
                            );
                          }
                        }
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
      ),
    );
  }
}
