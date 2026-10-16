import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/motorcycle_model.dart';
import '../services/app_services.dart';
import '../services/audio_service.dart';
import '../services/garage_service.dart';
import '../widgets/bike_preview.dart';
import '../widgets/ui_kit.dart';

/// The impound garage: browse all 15 bikes, buy with wallet money, select.
class GarageScreen extends StatefulWidget {
  const GarageScreen({super.key, this.initialBikeId});

  final String? initialBikeId;

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  late final PageController _pages;
  late int _index;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final i = MotorcycleCatalog.all.indexWhere((m) => m.id == widget.initialBikeId);
    _index = i < 0 ? 0 : i;
    _pages = PageController(initialPage: _index, viewportFraction: 0.86);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.initialBikeId == null) {
      // Open on the selected bike by default.
      final selected = AppServices.of(context).profile.data.selectedBike;
      final i = MotorcycleCatalog.all.indexWhere((m) => m.id == selected);
      if (i >= 0 && i != _index) {
        _index = i;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pages.hasClients) _pages.jumpToPage(i);
        });
      }
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _buy(Motorcycle bike) async {
    if (_busy) return;
    final services = AppServices.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KColors.panel,
        title: Text('Release ${bike.name}?'),
        content: Text('Pay the impound fee of ${formatPeso(bike.price)} to unlock this motorcycle permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('PAY')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _busy = true;
    final result = services.garage.buy(bike.id);
    _busy = false;
    switch (result) {
      case PurchaseResult.success:
        services.audio.play(Sfx.unlock);
        services.audio.haptic(heavy: true);
        await showDialog<void>(
          context: context,
          builder: (_) => _UnlockDialog(bike: bike),
        );
        if (!mounted) return;
        services.garage.select(bike.id);
      case PurchaseResult.insufficientFunds:
        _snack('Not enough money. Ride more to earn pesos!');
      case PurchaseResult.alreadyOwned:
        _snack('You already own this motorcycle.');
      case PurchaseResult.unknownBike:
        _snack('Unknown motorcycle.');
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    return KScaffold(
      title: 'IMPOUND GARAGE',
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
          return Column(
            children: [
              const SizedBox(height: 8),
              Text(
                '${_index + 1} / ${MotorcycleCatalog.all.length}  ·  ${services.garage.unlockedCount} owned',
                style: const TextStyle(color: KColors.muted, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: MotorcycleCatalog.all.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final bike = MotorcycleCatalog.all[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: _BikeCard(
                        bike: bike,
                        unlocked: services.garage.isUnlocked(bike.id),
                        selected: services.garage.isSelected(bike.id),
                        canBuy: services.garage.canBuy(bike.id),
                        wallet: services.profile.data.wallet,
                        onBuy: () => _buy(bike),
                        onSelect: () {
                          services.garage.select(bike.id);
                          services.audio.play(Sfx.click);
                        },
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Previous',
                      onPressed: _index > 0
                          ? () =>
                                _pages.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut)
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text(
                      'TIER ${MotorcycleCatalog.all[_index].tier}',
                      style: const TextStyle(color: KColors.yellow, fontWeight: FontWeight.w900, letterSpacing: 2),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Next',
                      onPressed: _index < MotorcycleCatalog.all.length - 1
                          ? () => _pages.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut)
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BikeCard extends StatelessWidget {
  const _BikeCard({
    required this.bike,
    required this.unlocked,
    required this.selected,
    required this.canBuy,
    required this.wallet,
    required this.onBuy,
    required this.onSelect,
  });

  final Motorcycle bike;
  final bool unlocked;
  final bool selected;
  final bool canBuy;
  final int wallet;
  final VoidCallback onBuy;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final Widget action;
    if (!unlocked) {
      action = ArcadeButton(
        label: canBuy ? 'BUY ${formatPeso(bike.price)}' : 'NEED ${formatPeso(bike.price - wallet)} MORE',
        icon: canBuy ? Icons.lock_open_rounded : Icons.lock_rounded,
        onPressed: canBuy ? onBuy : null,
        height: 50,
        fontSize: 16,
      );
    } else if (selected) {
      action = const ArcadeButton(
        label: 'SELECTED',
        icon: Icons.check_circle_rounded,
        color: KColors.green,
        textColor: Colors.white,
        onPressed: null,
        dimWhenDisabled: false,
        height: 50,
        fontSize: 16,
      );
    } else {
      action = ArcadeButton(
        label: 'SELECT',
        icon: Icons.two_wheeler_rounded,
        color: KColors.blue,
        textColor: Colors.white,
        onPressed: onSelect,
        height: 50,
        fontSize: 16,
      );
    }

    return KPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      border: selected ? KColors.green : bike.rarity.color.withValues(alpha: 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: _Chip(text: bike.rarity.label.toUpperCase(), color: bike.rarity.color),
              ),
              const Spacer(),
              Flexible(
                child: _Chip(
                  text: unlocked ? 'OWNED' : (bike.isFree ? 'FREE' : 'IMPOUNDED'),
                  color: unlocked ? KColors.green : KColors.red,
                ),
              ),
            ],
          ),
          // The preview absorbs whatever height is left, so the card
          // fits short phones without overflowing.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: FittedBox(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    BikePreview(bike: bike, height: 170),
                    if (!unlocked)
                      Positioned(
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.lock_rounded, color: KColors.yellow, size: 22),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              bike.name,
              maxLines: 1,
              style: const TextStyle(color: KColors.text, fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bike.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: KColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 6),
          StatBar(
            label: 'Speed',
            value: bike.speed,
            max: 15,
            color: KColors.red,
            trailing: '${bike.topSpeedKmh.round()} km/h',
          ),
          StatBar(label: 'Handling', value: bike.handling, max: 10, color: KColors.blue),
          StatBar(label: 'Fuel eff.', value: bike.fuelEfficiency, max: 10, color: KColors.yellow),
          const SizedBox(height: 4),
          Text(
            bike.isFree ? 'Starter bike' : 'Impound fee: ${formatPeso(bike.price)}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: KColors.text, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          action,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
      ),
    );
  }
}

/// Celebration shown after a successful purchase.
class _UnlockDialog extends StatefulWidget {
  const _UnlockDialog({required this.bike});

  final Motorcycle bike;

  @override
  State<_UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends State<_UnlockDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.elasticOut.transform(_c.value);
          return Transform.scale(
            scale: 0.5 + 0.5 * t,
            child: KPanel(
              border: KColors.yellow,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'UNLOCKED!',
                    style: TextStyle(
                      color: KColors.yellow,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Transform.rotate(
                    angle: (1 - _c.value) * math.pi,
                    child: BikePreview(bike: widget.bike, height: 150),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.bike.name,
                    style: const TextStyle(color: KColors.text, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const Text(
                    'Released from the impound and ready to ride.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: KColors.muted),
                  ),
                  const SizedBox(height: 16),
                  ArcadeButton(label: 'RIDE IT!', onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
