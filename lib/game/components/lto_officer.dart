import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, FontWeight, TextAlign;

import '../game_config.dart';
import '../kamote_game.dart';
import '../painting/bike_painter.dart';
import 'effects.dart';
import 'highway_entity.dart';

enum OfficerMode { entering, chasing, leaving, catching }

/// Fictional LTO enforcer who pursues the rider during a chase. Purely
/// visual: the chase rules live in `ChaseSystem`.
class LtoOfficer extends PositionComponent with HasGameReference<KamoteGame> {
  LtoOfficer() : super(size: Vector2(34, 68), anchor: Anchor.center, priority: 31);

  OfficerMode mode = OfficerMode.entering;
  double _time = 0;
  double _shoutIn = 1.2;
  int _shout = 0;
  static const _shouts = ['HOY! TABI!', 'PARA, BOSS!', 'LISENSYA MO!', 'HINTO!'];
  bool _caught = false;
  Sprite? _override;

  bool get hasCaughtRider => _caught;
  double get time => _time;

  @override
  Future<void> onLoad() async {
    _override = game.sprites.get('officer');
    x = game.player.x;
    y = game.viewHeight + 60;
  }

  void leave() {
    if (mode != OfficerMode.catching) mode = OfficerMode.leaving;
  }

  void catchRider() {
    mode = OfficerMode.catching;
    _caught = false;
  }

  /// Rejoins an existing chase instead of spawning a second officer.
  void rejoin() {
    if (mode == OfficerMode.leaving) mode = OfficerMode.entering;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    final player = game.player;
    switch (mode) {
      case OfficerMode.entering:
      case OfficerMode.chasing:
        // Falls slightly further behind as the countdown runs out.
        final progress = 1 - (game.chase.remaining / GameConfig.chaseDuration).clamp(0.0, 1.0);
        final targetY = player.y + 92 + progress * 40 + math.sin(_time * 3) * 6;
        y += (targetY - y) * math.min(1.0, dt * (mode == OfficerMode.entering ? 3.5 : 5));
        x += (player.x - x) * math.min(1.0, dt * 3.2);
        if (mode == OfficerMode.entering && (y - targetY).abs() < 6) mode = OfficerMode.chasing;
        // Shouts appear behind the rider, never over the road ahead.
        _shoutIn -= dt;
        if (_shoutIn <= 0 && game.state.acceptsGameplay) {
          _shoutIn = 3.2;
          game.world.add(
            FloatingText(
              _shouts[_shout++ % _shouts.length],
              position: Vector2(x, y + 30),
              color: const Color(0xFF82B1FF),
              fontSize: 12,
            ),
          );
        }
      case OfficerMode.leaving:
        y += 260 * dt;
        if (y > game.viewHeight + 90) removeFromParent();
      case OfficerMode.catching:
        final tx = player.x + (player.x > GameConfig.worldWidth / 2 ? -30.0 : 30.0);
        final ty = player.y + 10;
        x += (tx - x) * math.min(1.0, dt * 5);
        y += (ty - y) * math.min(1.0, dt * 5);
        if ((x - tx).abs() < 3 && (y - ty).abs() < 3) _caught = true;
    }
  }

  @override
  void render(Canvas canvas) {
    final sprite = _override;
    if (sprite != null) {
      sprite.render(canvas, size: size);
    } else {
      BikePainter.paintOfficer(canvas, size.toSize(), sirenPhase: _time * 4);
    }
  }
}

/// The fictional LTO checkpoint shown at the start of every run.
class LtoCheckpoint extends HighwayEntity {
  LtoCheckpoint({this.surprise = false}) : super(size: Vector2(GameConfig.worldWidth, 90), priority: 41) {
    x = GameConfig.worldWidth / 2;
  }

  /// Mid-run surprise checkpoint: riders who keep right slip through.
  final bool surprise;
  bool _passed = false;
  double _time = 0;

  static final Paint _p = Paint()..isAntiAlias = true;
  static TextPainter? _bannerText;
  static TextPainter? _boothText;

  double get time => _time;

  static TextPainter get bannerText => _bannerText ??= _label('LTO CHECKPOINT', 13, const Color(0xFFFFFFFF));
  static TextPainter get boothText => _boothText ??= _label('LTO', 10, const Color(0xFF0D47A1));

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (!_passed && y - 20 > game.player.y) {
      _passed = true;
      game.onCheckpointPassed(surprise: surprise);
    }
  }

  @override
  void render(Canvas canvas) {
    const roadL = GameConfig.roadLeft;
    const roadR = GameConfig.roadRight;
    final h = height;

    // Cones lining the right shoulder.
    for (var i = 0; i < 4; i++) {
      final cy = 8.0 + i * 22;
      _p.color = const Color(0xFFFF6D00);
      canvas.drawCircle(Offset(roadR - 10, cy), 5, _p);
      _p.color = const Color(0xFFFFFFFF);
      canvas.drawCircle(Offset(roadR - 10, cy), 2.4, _p);
    }

    // Booth on the right side.
    _p.color = const Color(0x44000000);
    canvas.drawRect(Rect.fromLTWH(roadR + 18, h * 0.3 + 4, 44, 40), _p);
    _p.color = const Color(0xFF1565C0);
    canvas.drawRect(Rect.fromLTWH(roadR + 14, h * 0.3, 44, 40), _p);
    _p.color = const Color(0xFFFFFFFF);
    canvas.drawRect(Rect.fromLTWH(roadR + 14, h * 0.3 + 16, 44, 8), _p);
    _boothText ??= _label('LTO', 10, const Color(0xFF0D47A1));
    _boothText!.paint(canvas, Offset(roadR + 36 - _boothText!.width / 2, h * 0.3 + 14));

    // Flashing amber beacon on the booth roof.
    final beaconOn = (_time * 3).floor().isEven;
    _p.color = beaconOn ? const Color(0xFFFFAB00) : const Color(0xFF8D6E00);
    canvas.drawCircle(Offset(roadR + 50, h * 0.3 + 6), 4, _p);
    if (beaconOn) {
      _p.color = const Color(0x44FFAB00);
      canvas.drawCircle(Offset(roadR + 50, h * 0.3 + 6), 14, _p);
    }

    // Boom gate, raised, with red/white stripes along the shoulder.
    _p.color = const Color(0xFF37474F);
    canvas.drawRect(Rect.fromLTWH(roadR + 2, h * 0.86, 8, 8), _p);
    for (var i = 0; i < 6; i++) {
      _p.color = i.isEven ? const Color(0xFFD50000) : const Color(0xFFFFFFFF);
      canvas.drawRect(Rect.fromLTWH(roadR + 4, h * 0.86 - (i + 1) * 9, 4, 9), _p);
    }

    // "SLOW DOWN" chevrons painted on the asphalt before the gantry.
    _p.color = const Color(0x99FFFFFF);
    for (var lane = 0; lane < GameConfig.laneCount; lane++) {
      final cx = GameConfig.laneCenter(lane);
      final chevron = Path()
        ..moveTo(cx - 14, h - 4)
        ..lineTo(cx, h - 14)
        ..lineTo(cx + 14, h - 4)
        ..lineTo(cx + 14, h)
        ..lineTo(cx, h - 10)
        ..lineTo(cx - 14, h)
        ..close();
      canvas.drawPath(chevron, _p);
    }

    // Officer waving a stop paddle beside the booth.
    final wave = math.sin(_time * 10) * 4;
    _p.color = const Color(0xFF0D47A1);
    canvas.drawCircle(Offset(roadR + 4, h * 0.75), 7, _p);
    _p.color = const Color(0xFFFFFFFF);
    canvas.drawCircle(Offset(roadR + 4, h * 0.75), 4.5, _p);
    _p.color = const Color(0xFFD50000);
    canvas.drawCircle(Offset(roadR - 6 + wave, h * 0.6), 5, _p);

    // Overhead gantry with the checkpoint banner.
    _p.color = const Color(0x55000000);
    canvas.drawRect(Rect.fromLTWH(roadL - 8, 10, roadR - roadL + 16, 22), _p);
    _p.color = const Color(0xFF37474F);
    canvas.drawRect(Rect.fromLTWH(roadL - 12, 2, 8, 26), _p);
    canvas.drawRect(Rect.fromLTWH(roadR + 4, 2, 8, 26), _p);
    _p.color = const Color(0xFF0D47A1);
    canvas.drawRRect(RRect.fromLTRBR(roadL + 30, 2, roadR - 30, 26, const Radius.circular(4)), _p);
    _p.color = const Color(0xFFFFD600);
    canvas.drawRect(Rect.fromLTWH(roadL + 30, 22, roadR - roadL - 60, 3), _p);
    _bannerText ??= _label('LTO CHECKPOINT', 13, const Color(0xFFFFFFFF));
    _bannerText!.paint(canvas, Offset(GameConfig.worldWidth / 2 - _bannerText!.width / 2, 5));
  }

  static TextPainter _label(String text, double size, Color color) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w900, letterSpacing: 1.2),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout();
}
