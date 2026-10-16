import 'package:flutter/material.dart';

import '../game/systems/underground_system.dart';
import '../game/game_config.dart';
import '../game/hud_model.dart';
import '../game/kamote_game.dart';
import '../game/systems/meme_event_manager.dart';
import '../widgets/ui_kit.dart';

/// Top bar (fuel, distance, cash, pause), chase countdown, toasts,
/// world banner and optional steering buttons.
class GameHud extends StatelessWidget {
  const GameHud({super.key, required this.game});

  final KamoteGame game;

  @override
  Widget build(BuildContext context) {
    final showButtons = game.profile.settings.showSteerButtons;
    return ListenableBuilder(
      listenable: game.hud,
      builder: (context, _) {
        final hud = game.hud;
        return Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(hud: hud, onPause: game.pauseRun),
                    const SizedBox(height: 6),
                    if (hud.chaseActive) _ChaseBanner(remaining: hud.chaseRemaining),
                    if (hud.undergroundActive) _UndergroundBanner(remaining: hud.undergroundRemaining),
                    const SizedBox(height: 6),
                    if (hud.announcement != null)
                      _Announcement(key: ValueKey(hud.announcement!.id), banner: hud.announcement!),
                    for (final t in hud.toasts) _ToastView(key: ValueKey(t.id), toast: t),
                  ],
                ),
              ),
            ),
            if (hud.banner != null)
              Align(
                alignment: const Alignment(0, -0.25),
                child: IgnorePointer(
                  child: _WorldBanner(key: ValueKey(hud.banner!.id), banner: hud.banner!),
                ),
              ),
            // Meme pop-ups live below the rider, between the steering
            // buttons: road already passed, so they never hide hazards, the
            // fuel gauge or the chase timer.
            if (hud.meme != null && game.profile.settings.memePopups != MemePopupMode.off)
              Positioned(
                left: 84,
                right: 84,
                bottom: 22 + MediaQuery.paddingOf(context).bottom,
                child: IgnorePointer(
                  child: _MemePop(key: ValueKey(hud.meme!.id), text: hud.meme!.text),
                ),
              ),
            if (showButtons)
              Positioned(
                left: 12,
                bottom: 18 + MediaQuery.paddingOf(context).bottom,
                child: _SteerButton(icon: Icons.chevron_left_rounded, onPress: () => game.steer(-1)),
              ),
            if (showButtons)
              Positioned(
                right: 12,
                bottom: 18 + MediaQuery.paddingOf(context).bottom,
                child: _SteerButton(icon: Icons.chevron_right_rounded, onPress: () => game.steer(1)),
              ),
          ],
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.hud, required this.onPause});

  final HudModel hud;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: const Color(0xCC10141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _FuelGauge(fraction: hud.fuelFraction, low: hud.lowFuel),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Pause',
                onPressed: onPause,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(backgroundColor: Colors.white10),
                icon: const Icon(Icons.pause_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _Stat(
                icon: Icons.route_rounded,
                text: formatDistance(hud.distanceMeters.toDouble()),
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              _Stat(icon: Icons.speed_rounded, text: '${hud.speedKmh} km/h', color: const Color(0xFF80D8FF)),
              const Spacer(),
              _Stat(icon: Icons.payments_rounded, text: formatPeso(hud.runCash), color: KColors.yellow),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.two_wheeler_rounded, size: 14, color: KColors.muted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  hud.bikeName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: KColors.muted, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
              _Chip(text: hud.difficultyLabel, color: hud.difficultyColor),
              const Spacer(),
              if (hud.combo >= 2) ...[
                _Chip(text: 'x${hud.combo} COMBO', color: const Color(0xFF80D8FF)),
                const SizedBox(width: 6),
              ],
              Flexible(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: hud.environmentColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hud.environmentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: hud.environmentColor, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15),
        ),
      ],
    );
  }
}

class _FuelGauge extends StatefulWidget {
  const _FuelGauge({required this.fraction, required this.low});

  final double fraction;
  final bool low;

  @override
  State<_FuelGauge> createState() => _FuelGaugeState();
}

class _FuelGaugeState extends State<_FuelGauge> with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void didUpdateWidget(_FuelGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.low && !_blink.isAnimating) _blink.repeat(reverse: true);
    if (!widget.low && _blink.isAnimating) {
      _blink.stop();
      _blink.value = 0;
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fraction.clamp(0.0, 1.0);
    final color = f > 0.5
        ? const Color(0xFF66BB6A)
        : f > GameConfig.lowFuelThreshold / GameConfig.maxFuel
        ? const Color(0xFFFFCA28)
        : const Color(0xFFFF5252);
    return AnimatedBuilder(
      animation: _blink,
      builder: (context, _) => Row(
        children: [
          Icon(Icons.local_gas_station_rounded, size: 20, color: Color.lerp(color, Colors.white, _blink.value * 0.8)),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.low ? Color.lerp(Colors.transparent, Colors.redAccent, _blink.value)! : Colors.white24,
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: f,
                    heightFactor: 1,
                    child: ColoredBox(color: color),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 52,
            child: Text(
              widget.low ? 'LOW!' : '${(f * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: widget.low ? Color.lerp(Colors.redAccent, Colors.white, _blink.value) : Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChaseBanner extends StatelessWidget {
  const _ChaseBanner({required this.remaining});

  final double remaining;

  @override
  Widget build(BuildContext context) {
    // Alternates police red/blue every half second.
    final red = (remaining * 2).floor().isEven;
    final color = red ? const Color(0xFFD50000) : const Color(0xFF2962FF);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 14)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.local_police_rounded, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'LTO CHASE! Don\'t crash!',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
              Text(
                '${remaining.toStringAsFixed(1)}s',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (remaining / GameConfig.chaseDuration).clamp(0.0, 1.0),
              minHeight: 6,
              color: Colors.white,
              backgroundColor: Colors.white24,
            ),
          ),
        ],
      ),
    );
  }
}

/// Countdown to the tunnel exit.
class _UndergroundBanner extends StatelessWidget {
  const _UndergroundBanner({required this.remaining});

  final double remaining;

  static const _purple = Color(0xFF7C4DFF);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xE6221A33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _purple, width: 1.5),
        boxShadow: [BoxShadow(color: _purple.withValues(alpha: 0.45), blurRadius: 12)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.subway_rounded, color: Color(0xFFB388FF)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'UNDERGROUND! Exit in',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
              Text(
                '${remaining.toStringAsFixed(1)}s',
                style: const TextStyle(color: Color(0xFFB388FF), fontWeight: FontWeight.w900, fontSize: 22),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (remaining / UndergroundSystem.duration).clamp(0.0, 1.0),
              minHeight: 6,
              color: const Color(0xFFB388FF),
              backgroundColor: Colors.white12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToastView extends StatelessWidget {
  const _ToastView({super.key, required this.toast});

  final HudToast toast;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, -10 * (1 - t)), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              toast.text,
              textAlign: TextAlign.center,
              style: TextStyle(color: toast.color, fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}

/// "WORLD 2: PROVINCIAL ROAD" announcement that fades in, holds, fades out.
class _WorldBanner extends StatefulWidget {
  const _WorldBanner({super.key, required this.banner});

  final HudBanner banner;

  @override
  State<_WorldBanner> createState() => _WorldBannerState();
}

class _WorldBannerState extends State<_WorldBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = _c.value;
        final opacity = v < 0.12 ? v / 0.12 : (v > 0.8 ? (1 - v) / 0.2 : 1.0);
        final scale = v < 0.12 ? 0.8 + v / 0.12 * 0.2 : 1.0;
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xDD10141F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.banner.color, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.banner.title,
              textAlign: TextAlign.center,
              style: TextStyle(color: widget.banner.color, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1),
            ),
            const SizedBox(height: 4),
            Text(
              widget.banner.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _SteerButton extends StatelessWidget {
  const _SteerButton({required this.icon, required this.onPress});

  final IconData icon;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context) {
    // Listener fires on pointer-down for zero-latency steering.
    return Listener(
      onPointerDown: (_) => onPress(),
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(color: Colors.white38, width: 2),
        ),
        child: Icon(icon, color: Colors.white70, size: 40),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(6)),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
      ),
    );
  }
}

/// Compact challenge announcement under the top bar.
class _Announcement extends StatefulWidget {
  const _Announcement({super.key, required this.banner});

  final HudBanner banner;

  @override
  State<_Announcement> createState() => _AnnouncementState();
}

class _AnnouncementState extends State<_Announcement> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = _c.value;
        if (v >= 1) return const SizedBox.shrink();
        final opacity = v < 0.08 ? v / 0.08 : (v > 0.85 ? (1 - v) / 0.15 : 1.0);
        final slide = v < 0.08 ? (1 - v / 0.08) * -12 : 0.0;
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, slide), child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xDD10141F),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: widget.banner.color, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, color: widget.banner.color, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.banner.title,
                        style: TextStyle(color: widget.banner.color, fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                      Text(
                        widget.banner.subtitle,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouncy meme caption ("AY, NAKO!") with a thick outline.
class _MemePop extends StatefulWidget {
  const _MemePop({super.key, required this.text});

  final String text;

  @override
  State<_MemePop> createState() => _MemePopState();
}

class _MemePopState extends State<_MemePop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 22, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1.05);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = _c.value;
        if (v >= 1) return const SizedBox.shrink();
        final pop = v < 0.12 ? Curves.elasticOut.transform(v / 0.12) : 1.0;
        final opacity = v > 0.8 ? (1 - v) / 0.2 : 1.0;
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: -0.06,
            child: Transform.scale(scale: 0.4 + 0.6 * pop, child: child),
          ),
        );
      },
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Stack(
          children: [
            Text(
              widget.text,
              textAlign: TextAlign.center,
              style: style.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 6
                  ..color = const Color(0xFF1A1A1A),
              ),
            ),
            Text(
              widget.text,
              textAlign: TextAlign.center,
              style: style.copyWith(color: KColors.yellow),
            ),
          ],
        ),
      ),
    );
  }
}
