import 'dart:math' as math;

/// Moments in a run that can trigger a meme reaction.
enum MemeEvent {
  nearMiss,
  kamoteMoment,
  chaseStart,
  fuelCritical,
  restart,
  dangerZone,
  cashCombo,
  dogDodge,
  catDodge,
  chickenDodge,
  animalBump,
  challengeComplete,
  ltoSlip,
}

/// How many meme pop-ups the player wants to see.
enum MemePopupMode { full, reduced, off }

/// Original comedic sound stinger played with a meme (when no voice line
/// file is supplied).
enum MemeSound { boing, wahwah, airhorn, tada, woof, meow, cluck, uhoh }

class MemeLine {
  const MemeLine(this.event, this.text, this.sound);

  final MemeEvent event;
  final String text;
  final MemeSound sound;
}

/// Picks a contextual Taglish line for a gameplay event, with per-event and
/// global cooldowns so jokes never spam the screen.
///
/// All lines are original, meme-inspired writing; no copyrighted clips.
class MemeEventManager {
  MemeEventManager({math.Random? random}) : _rnd = random ?? math.Random();

  final math.Random _rnd;

  static const Map<MemeEvent, List<String>> pools = {
    MemeEvent.nearMiss: ['AY, NAKO!', 'MUNTIK NA, IDOL!', 'ISA PANG CHANCE!', 'KABADO SI KUYA!', 'GALING UMIWAS!'],
    MemeEvent.kamoteMoment: ['KAMOTE MOMENT!', 'AWIT, BOSS!', 'ANO BA \'YAN, IDOL?', 'LUBAK LIFE!'],
    MemeEvent.chaseStart: ['LAGOT KA, BOSS!', 'TAKBO, KAMOTE!', 'PATAY TAYO DIYAN!', 'HULIHAN NA \'TO!'],
    MemeEvent.fuelCritical: ['SANA ALL MAY GASOLINA!', 'GAS PA MORE!', 'E DI WOW, EMPTY!'],
    MemeEvent.restart: ['ISA PANG CHANCE!', 'BAWI TAYO, IDOL!', 'ROUND 2, KAMOTE!'],
    MemeEvent.dangerZone: ['SLOW DOWN, IDOL!', 'INGAT, LODI!', 'DAHAN-DAHAN LANG!'],
    MemeEvent.cashCombo: ['NICE ONE, IDOL!', 'YAMAN MO NA!', 'PAMASKO EARLY!', 'SANA ALL MAY PERA!'],
    MemeEvent.dogDodge: ['GOOD BOY, GOOD SAVE!', 'ASO SA DAAN, ILAG IDOL!', 'ARF-SOME REFLEXES!'],
    MemeEvent.catDodge: [
      'PUSA SA GITNA!',
      'CATastrophe avoided!',
      'MEOW-velous reflexes!',
      'PUSANG LIGAW, REFLEXES MO ANG SUBOK!',
    ],
    MemeEvent.chickenDodge: ['BAKIT TUMAWID ANG MANOK?', 'TAWID MANOK, ILAG IDOL!', 'TIKTILAOK SAVE!'],
    MemeEvent.animalBump: ['SORRY PO, BANTAY!', 'INGAT SA ALAGA, IDOL!', 'OKAY LANG SIYA, NAGULAT LANG!'],
    MemeEvent.challengeComplete: ['PASADO, IDOL!', 'LODI KA TALAGA!', 'PETMALU!'],
    MemeEvent.ltoSlip: ['LUSOT KA, IDOL!', 'DISIPLINADO PALA!', 'GOOD JOB, LAWFUL KAMOTE!'],
  };

  static const Map<MemeEvent, MemeSound> sounds = {
    MemeEvent.nearMiss: MemeSound.uhoh,
    MemeEvent.kamoteMoment: MemeSound.boing,
    MemeEvent.chaseStart: MemeSound.airhorn,
    MemeEvent.fuelCritical: MemeSound.wahwah,
    MemeEvent.restart: MemeSound.boing,
    MemeEvent.dangerZone: MemeSound.uhoh,
    MemeEvent.cashCombo: MemeSound.tada,
    MemeEvent.dogDodge: MemeSound.woof,
    MemeEvent.catDodge: MemeSound.meow,
    MemeEvent.chickenDodge: MemeSound.cluck,
    MemeEvent.animalBump: MemeSound.wahwah,
    MemeEvent.challengeComplete: MemeSound.tada,
    MemeEvent.ltoSlip: MemeSound.tada,
  };

  /// Seconds before the same event may fire again.
  static const Map<MemeEvent, double> eventCooldowns = {
    MemeEvent.nearMiss: 5,
    MemeEvent.kamoteMoment: 6,
    MemeEvent.cashCombo: 8,
    MemeEvent.dangerZone: 10,
  };
  static const double defaultEventCooldown = 4;

  /// Minimum gap between any two memes.
  static const double fullGlobalCooldown = 1.6;
  static const double reducedGlobalCooldown = 7;

  /// Events still shown in reduced mode.
  static const Set<MemeEvent> majorEvents = {
    MemeEvent.chaseStart,
    MemeEvent.fuelCritical,
    MemeEvent.cashCombo,
    MemeEvent.dogDodge,
    MemeEvent.catDodge,
    MemeEvent.chickenDodge,
    MemeEvent.challengeComplete,
  };

  final Map<MemeEvent, double> _lastFired = {};
  final Map<MemeEvent, String> _lastText = {};
  double _lastAny = -1e9;

  /// Returns a line to show, or null if suppressed by cooldown or mode.
  MemeLine? trigger(MemeEvent event, double now, {MemePopupMode mode = MemePopupMode.full}) {
    final reduced = mode != MemePopupMode.full;
    if (reduced && !majorEvents.contains(event)) return null;
    final global = reduced ? reducedGlobalCooldown : fullGlobalCooldown;
    if (now - _lastAny < global) return null;
    final cooldown = eventCooldowns[event] ?? defaultEventCooldown;
    final last = _lastFired[event];
    if (last != null && now - last < cooldown) return null;

    final pool = pools[event]!;
    var text = pool[_rnd.nextInt(pool.length)];
    // Never show the same line twice in a row for an event.
    if (pool.length > 1 && text == _lastText[event]) {
      text = pool[(pool.indexOf(text) + 1 + _rnd.nextInt(pool.length - 1)) % pool.length];
    }
    _lastFired[event] = now;
    _lastText[event] = text;
    _lastAny = now;
    return MemeLine(event, text, sounds[event]!);
  }

  void reset() {
    _lastFired.clear();
    _lastAny = -1e9;
  }
}
