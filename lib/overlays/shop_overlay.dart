import 'package:flutter/material.dart';

import '../game/kamote_game.dart';
import '../game/systems/shop_system.dart';
import '../widgets/ui_kit.dart';

/// Roadside shop opened from the HUD. The run is paused while it is open.
class ShopOverlay extends StatefulWidget {
  const ShopOverlay({super.key, required this.game});

  final KamoteGame game;

  @override
  State<ShopOverlay> createState() => _ShopOverlayState();
}

class _ShopOverlayState extends State<ShopOverlay> {
  String? _message;
  Color _messageColor = KColors.text;

  KamoteGame get game => widget.game;

  void _buy(ShopItem item) {
    final result = game.buy(item);
    final (String, Color) feedback = switch (result) {
      ShopResult.success => ('Bought ${item.name}: -${formatPeso(item.price)}', const Color(0xFF69F0AE)),
      ShopResult.insufficientFunds => ('Not enough money for ${item.name}.', const Color(0xFFFF8A80)),
      ShopResult.tankFull => ('Your tank is already full.', KColors.yellow),
      ShopResult.boostActive => ('A booster is already running.', KColors.yellow),
      ShopResult.boostCoolingDown => ('Booster cooling down: ${game.boost.cooldown.ceil()} s left.', KColors.yellow),
      ShopResult.unavailable => ('The shop is closed right now.', const Color(0xFFFF8A80)),
    };
    setState(() {
      _message = feedback.$1;
      _messageColor = feedback.$2;
    });
  }

  String? _blockedReason(ShopItem item, int money) {
    if (item.kind == ShopItemKind.fuel && game.fuel.isFull) return 'TANK FULL';
    if (item.kind == ShopItemKind.booster) {
      if (game.boost.active) return 'ACTIVE';
      if (game.boost.coolingDown) return '${game.boost.cooldown.ceil()} s';
    }
    if (money < item.price) return 'NEED ${formatPeso(item.price - money)}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final money = game.rewards.runEarnings;
    final fuel = game.fuel.fraction.clamp(0.0, 1.0);
    final boost = game.boost;
    return ColoredBox(
      color: const Color(0xCC05070C),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: KPanel(
                border: KColors.yellow,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'ROADSIDE SHOP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: KColors.yellow,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const Text(
                      'The ride is paused while you shop.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: KColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.payments_rounded, color: KColors.yellow),
                        const SizedBox(width: 6),
                        const Text('Your cash', style: TextStyle(color: KColors.muted)),
                        const Spacer(),
                        Text(
                          formatPeso(money),
                          style: const TextStyle(color: KColors.yellow, fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.local_gas_station_rounded, color: Color(0xFF66BB6A), size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: fuel,
                              minHeight: 10,
                              color: const Color(0xFF66BB6A),
                              backgroundColor: Colors.white12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${(fuel * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900)),
                      ],
                    ),
                    if (boost.active || boost.coolingDown)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          boost.active
                              ? 'Booster active: ${boost.remaining.toStringAsFixed(1)} s left'
                              : 'Next booster in ${boost.cooldown.ceil()} s',
                          style: const TextStyle(color: Color(0xFFFFB74D), fontWeight: FontWeight.w700),
                        ),
                      ),
                    const SizedBox(height: 12),
                    const _Section('GASOLINE'),
                    for (final item in ShopCatalog.fuel)
                      _ItemTile(item: item, blocked: _blockedReason(item, money), onBuy: () => _buy(item)),
                    const SizedBox(height: 8),
                    const _Section('BOOSTERS · speed only, no crash protection'),
                    for (final item in ShopCatalog.boosters)
                      _ItemTile(item: item, blocked: _blockedReason(item, money), onBuy: () => _buy(item)),
                    if (_message case final message?)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _messageColor, fontWeight: FontWeight.w800),
                        ),
                      ),
                    const SizedBox(height: 12),
                    ArcadeButton(label: 'BACK TO THE ROAD', icon: Icons.play_arrow_rounded, onPressed: game.closeShop),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: const TextStyle(color: KColors.muted, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
    ),
  );
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.blocked, required this.onBuy});

  final ShopItem item;

  /// Why it can't be bought right now, or null when it can.
  final String? blocked;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final booster = item.kind == ShopItemKind.booster;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            booster ? Icons.bolt_rounded : Icons.local_gas_station_rounded,
            color: booster ? const Color(0xFFFF9100) : const Color(0xFF66BB6A),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(item.effect, style: const TextStyle(color: KColors.muted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: blocked == null ? onBuy : null,
            style: FilledButton.styleFrom(
              backgroundColor: KColors.yellow,
              foregroundColor: Colors.black,
              minimumSize: const Size(96, 44),
            ),
            child: Text(
              blocked ?? 'BUY ${formatPeso(item.price)}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
