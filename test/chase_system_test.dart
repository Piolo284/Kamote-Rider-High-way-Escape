import 'package:flutter_test/flutter_test.dart';
import 'package:kamote_rider/game/game_state.dart';
import 'package:kamote_rider/game/systems/chase_system.dart';

void main() {
  group('ChaseSystem', () {
    test('runs a 10 second countdown and reports escape once', () {
      final chase = ChaseSystem();
      expect(chase.start(ChaseTrigger.sideCollision), isTrue);
      expect(chase.remaining, 10);
      var escapes = 0;
      for (var i = 0; i < 700; i++) {
        if (chase.update(1 / 60)) escapes++;
      }
      expect(escapes, 1);
      expect(chase.active, isFalse);
      expect(chase.survivedCount, 1);
    });

    test('a second start while active never stacks a timer', () {
      final chase = ChaseSystem();
      chase.start(ChaseTrigger.checkpoint);
      chase.update(4);
      expect(chase.start(ChaseTrigger.sideCollision), isFalse);
      expect(chase.remaining, closeTo(6, 1e-9), reason: 'timer must not restart');
      expect(chase.trigger, ChaseTrigger.checkpoint);
    });

    test('countdown is frozen when not updated (pause)', () {
      final chase = ChaseSystem()..start(ChaseTrigger.sideCollision);
      chase.update(3);
      final frozen = chase.remaining;
      chase.update(0);
      expect(chase.remaining, frozen);
    });
  });

  group('RunStateMachine', () {
    test('only one ending can begin', () {
      final s = RunStateMachine()..start();
      expect(s.beginEnding(EndReason.headOnCrash), isTrue);
      expect(s.beginEnding(EndReason.ticketAndJail), isFalse);
      expect(s.endReason, EndReason.headOnCrash);
      expect(s.finishEnding(), isTrue);
      expect(s.finishEnding(), isFalse);
    });

    test('a run cannot start twice', () {
      final s = RunStateMachine();
      expect(s.start(), isTrue);
      expect(s.start(), isFalse);
      s.pause();
      expect(s.start(), isFalse);
    });

    test('police chase is a condition on playing, not a separate screen', () {
      final s = RunStateMachine()..start();
      expect(s.status(chaseActive: true), GameStatus.policeChase);
      expect(s.acceptsGameplay, isTrue);
      s.pause();
      expect(s.status(chaseActive: true), GameStatus.paused);
      expect(s.acceptsGameplay, isFalse);
    });
  });
}
