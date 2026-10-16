import 'package:flutter/material.dart';

import '../app.dart';
import '../models/motorcycle_model.dart';
import '../services/app_services.dart';
import '../widgets/bike_preview.dart';
import '../widgets/ui_kit.dart';

/// Showcase of all 15 impounded motorcycles and collection progress.
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    return KScaffold(
      title: 'COLLECTION',
      child: ListenableBuilder(
        listenable: services.profile,
        builder: (context, _) {
          final owned = services.garage.unlockedCount;
          const total = 15;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: KPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$owned / $total motorcycles released',
                        style: const TextStyle(color: KColors.text, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: owned / total,
                          minHeight: 12,
                          color: KColors.yellow,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Lifetime distance: ${formatDistance(services.profile.data.totalDistance)} · '
                        'Runs: ${services.profile.data.runsPlayed}',
                        style: const TextStyle(color: KColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 150,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.66,
                  ),
                  itemCount: MotorcycleCatalog.all.length,
                  itemBuilder: (context, i) {
                    final bike = MotorcycleCatalog.all[i];
                    final unlocked = services.garage.isUnlocked(bike.id);
                    final selected = services.garage.isSelected(bike.id);
                    return GestureDetector(
                      onTap: () => Navigator.of(context).pushNamed(Routes.garage, arguments: bike.id),
                      child: KPanel(
                        padding: const EdgeInsets.all(8),
                        border: selected ? KColors.green : (unlocked ? bike.rarity.color : Colors.white10),
                        child: Column(
                          children: [
                            Expanded(
                              child: FittedBox(
                                child: BikePreview(bike: bike, height: 110, silhouette: !unlocked, animate: false),
                              ),
                            ),
                            Text(
                              unlocked ? bike.name : '???',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: KColors.text, fontWeight: FontWeight.w800, fontSize: 12),
                            ),
                            Text(
                              unlocked ? (selected ? 'SELECTED' : bike.rarity.label) : formatPeso(bike.price),
                              style: TextStyle(
                                color: unlocked ? (selected ? KColors.green : bike.rarity.color) : KColors.yellow,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
