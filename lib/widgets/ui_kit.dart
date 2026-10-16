import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../services/audio_service.dart';

/// Shared palette for the arcade look.
class KColors {
  KColors._();

  static const background = Color(0xFF141824);
  static const panel = Color(0xFF1F2536);
  static const panelLight = Color(0xFF2A3247);
  static const yellow = Color(0xFFFFC400);
  static const red = Color(0xFFE53935);
  static const blue = Color(0xFF1E88E5);
  static const green = Color(0xFF43A047);
  static const text = Color(0xFFF5F5F5);
  static const muted = Color(0xFF9AA4B8);
}

String formatPeso(int amount) => '${amount < 0 ? '-' : ''}₱${formatScore(amount.abs())}';

/// Groups digits with commas, e.g. 12345 -> "12,345".
String formatScore(int value) {
  final s = value.abs().toString();
  final buf = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String formatDistance(double meters) {
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(2)} km';
  return '${meters.floor()} m';
}

/// Chunky arcade button with a press-down animation and click sound.
class ArcadeButton extends StatefulWidget {
  const ArcadeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = KColors.yellow,
    this.textColor = const Color(0xFF1A1A1A),
    this.height = 56,
    this.fontSize = 20,
    this.badge,
    this.dimWhenDisabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color textColor;
  final double height;
  final double fontSize;
  final String? badge;

  /// False keeps the colors for status buttons such as "SELECTED".
  final bool dimWhenDisabled;

  @override
  State<ArcadeButton> createState() => _ArcadeButtonState();
}

class _ArcadeButtonState extends State<ArcadeButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final looksEnabled = enabled || !widget.dimWhenDisabled;
    final base = looksEnabled ? widget.color : const Color(0xFF555B66);
    final shade = HSLColor.fromColor(
      base,
    ).withLightness((HSLColor.fromColor(base).lightness * 0.6).clamp(0, 1)).toColor();
    final depth = _down ? 1.0 : 5.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: enabled
            ? () {
                AppServices.of(context).audio.play(Sfx.click, gain: 0.6);
                widget.onPressed!();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          height: widget.height,
          margin: EdgeInsets.only(top: 5 - depth),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: shade),
          padding: EdgeInsets.only(bottom: depth),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.lerp(base, Colors.white, 0.25)!, base],
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        color: looksEnabled ? widget.textColor : Colors.white54,
                        size: widget.fontSize + 4,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: looksEnabled ? widget.textColor : Colors.white54,
                          fontSize: widget.fontSize,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.badge != null)
                Positioned(
                  right: -6,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: KColors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      widget.badge!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded dark panel.
class KPanel extends StatelessWidget {
  const KPanel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.border});

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? KColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border ?? Colors.white10, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: child,
    );
  }
}

/// Pill showing the wallet balance.
class WalletChip extends StatelessWidget {
  const WalletChip({super.key, required this.amount, this.label});

  final int amount;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KColors.yellow.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.payments_rounded, color: KColors.yellow, size: 18),
          const SizedBox(width: 6),
          if (label != null)
            Text(
              '$label ',
              style: const TextStyle(color: KColors.muted, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          Text(
            formatPeso(amount),
            style: const TextStyle(color: KColors.yellow, fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

/// Labelled horizontal stat bar.
class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    this.trailing,
  });

  final String label;
  final int value;
  final int max;
  final Color color;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(color: KColors.muted, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value / max,
                minHeight: 10,
                color: color,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              trailing ?? '$value/$max',
              textAlign: TextAlign.right,
              style: const TextStyle(color: KColors.text, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen scaffold with the dark arcade background and a back button.
class KScaffold extends StatelessWidget {
  const KScaffold({super.key, required this.title, required this.child, this.actions = const []});

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.background,
      appBar: AppBar(
        backgroundColor: KColors.background,
        foregroundColor: KColors.text,
        elevation: 0,
        centerTitle: true,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        actions: actions,
      ),
      body: SafeArea(top: false, child: child),
    );
  }
}
