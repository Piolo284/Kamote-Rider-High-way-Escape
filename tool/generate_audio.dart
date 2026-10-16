// Generates the game's original placeholder sound effects and music as
// 16-bit mono WAV files in assets/audio/.
//
//   dart run tool/generate_audio.dart
//
// Everything is synthesized from scratch (no third-party samples), so the
// output is free to use. Replace any file with your own audio of the same
// name to upgrade the sound.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int sampleRate = 22050;
final math.Random _rnd = math.Random(7);

void main() {
  final out = Directory('assets/audio')..createSync(recursive: true);
  final files = <String, List<double>>{
    'sfx_cash.wav': cash(),
    'sfx_fuel.wav': fuel(),
    'sfx_impact.wav': impact(),
    'sfx_bump.wav': bump(),
    'sfx_whistle.wav': whistle(),
    'sfx_click.wav': click(),
    'sfx_unlock.wav': unlock(),
    'sfx_mission.wav': mission(),
    'sfx_kilometer.wav': kilometer(),
    'sfx_crash.wav': crash(),
    'sfx_sputter.wav': sputter(),
    'sfx_game_over.wav': gameOver(),
    'loop_engine.wav': engineLoop(),
    'loop_siren.wav': sirenLoop(),
    'loop_ambulance.wav': ambulanceLoop(),
    'music_menu.wav': menuMusic(),
    'music_ride.wav': rideMusic(),
    'sfx_whoosh.wav': whoosh(),
    'sfx_brake.wav': brakeScreech(),
    'sfx_challenge.wav': challengeChime(),
    'meme_boing.wav': memeBoing(),
    'meme_wahwah.wav': memeWahWah(),
    'meme_airhorn.wav': memeAirhorn(),
    'meme_tada.wav': memeTada(),
    'meme_woof.wav': memeWoof(),
    'meme_meow.wav': memeMeow(),
    'meme_cluck.wav': memeCluck(),
    'meme_uhoh.wav': memeUhOh(),
  };
  for (final e in files.entries) {
    final f = File('${out.path}/${e.key}');
    f.writeAsBytesSync(encodeWav(e.value));
    stdout.writeln('wrote ${f.path} (${(f.lengthSync() / 1024).toStringAsFixed(0)} KB)');
  }
}

// ---------------------------------------------------------------- helpers

List<double> buffer(double seconds) => List<double>.filled((seconds * sampleRate).round(), 0);

double square(double phase, [double duty = 0.5]) => (phase % 1.0) < duty ? 1.0 : -1.0;
double saw(double phase) => 2 * (phase % 1.0) - 1;
double tri(double phase) => 1 - 4 * ((phase % 1.0) - 0.5).abs();
double noise() => _rnd.nextDouble() * 2 - 1;
double midi(num note) => 440 * math.pow(2, (note - 69) / 12).toDouble();

/// Adds a tone with a simple attack/decay envelope into [buf].
void tone(
  List<double> buf,
  double start,
  double length,
  double freq, {
  double vol = 0.3,
  double Function(double)? wave,
  double attack = 0.005,
  double release = 0.05,
  double slide = 0,
}) {
  final w = wave ?? (p) => square(p);
  final s0 = (start * sampleRate).round();
  final n = (length * sampleRate).round();
  var phase = 0.0;
  for (var i = 0; i < n && s0 + i < buf.length; i++) {
    final t = i / sampleRate;
    final f = freq + slide * t / length;
    phase += f / sampleRate;
    var env = 1.0;
    if (t < attack) env = t / attack;
    if (t > length - release) env = math.max(0, (length - t) / release);
    buf[s0 + i] += w(phase) * vol * env;
  }
}

void noiseBurst(
  List<double> buf,
  double start,
  double length, {
  double vol = 0.4,
  double decay = 8,
  double lowpass = 0.3,
}) {
  final s0 = (start * sampleRate).round();
  final n = (length * sampleRate).round();
  var last = 0.0;
  for (var i = 0; i < n && s0 + i < buf.length; i++) {
    final t = i / sampleRate;
    last += (noise() - last) * lowpass;
    buf[s0 + i] += last * vol * math.exp(-t * decay);
  }
}

Uint8List encodeWav(List<double> samples) {
  var peak = 0.0;
  for (final s in samples) {
    peak = math.max(peak, s.abs());
  }
  final gain = peak > 0.95 ? 0.95 / peak : 1.0;
  final data = ByteData(44 + samples.length * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, (samples[i] * gain * 32767).round().clamp(-32768, 32767), Endian.little);
  }
  return data.buffer.asUint8List();
}

// ---------------------------------------------------------------- effects

List<double> cash() {
  final b = buffer(0.22);
  tone(b, 0, 0.07, midi(88), vol: 0.25, wave: (p) => square(p, 0.25));
  tone(b, 0.06, 0.16, midi(93), vol: 0.25, wave: (p) => square(p, 0.25), release: 0.12);
  return b;
}

List<double> fuel() {
  final b = buffer(0.4);
  for (var i = 0; i < 3; i++) {
    tone(b, i * 0.11, 0.1, 330 - i * 40.0, vol: 0.35, wave: tri, slide: -120, release: 0.04);
  }
  tone(b, 0.32, 0.08, 660, vol: 0.2, wave: tri);
  return b;
}

List<double> impact() {
  final b = buffer(0.35);
  noiseBurst(b, 0, 0.35, vol: 0.7, decay: 12, lowpass: 0.5);
  tone(b, 0, 0.2, 110, vol: 0.5, wave: tri, slide: -70);
  return b;
}

List<double> bump() {
  final b = buffer(0.15);
  tone(b, 0, 0.14, 90, vol: 0.6, wave: tri, slide: -40, release: 0.1);
  noiseBurst(b, 0, 0.08, vol: 0.25, decay: 30, lowpass: 0.2);
  return b;
}

List<double> whistle() {
  final b = buffer(0.6);
  final n = b.length;
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    phase += (2900 + 120 * math.sin(t * 2 * math.pi * 28)) / sampleRate;
    final env = math.min(1.0, t / 0.02) * math.min(1.0, (0.6 - t) / 0.08);
    b[i] = (math.sin(phase * 2 * math.pi) * 0.35 + noise() * 0.04) * env;
  }
  return b;
}

List<double> click() {
  final b = buffer(0.04);
  tone(b, 0, 0.035, 1200, vol: 0.25, wave: (p) => square(p, 0.3), release: 0.03);
  return b;
}

List<double> unlock() {
  final b = buffer(0.8);
  const notes = [72, 76, 79, 84];
  for (var i = 0; i < notes.length; i++) {
    tone(b, i * 0.1, i == 3 ? 0.4 : 0.12, midi(notes[i]), vol: 0.25, wave: (p) => square(p, 0.25), release: 0.08);
  }
  tone(b, 0.3, 0.45, midi(60), vol: 0.2, wave: tri, release: 0.2);
  return b;
}

List<double> mission() {
  final b = buffer(0.75);
  const notes = [67, 72, 76, 79, 76, 79];
  const times = [0.0, 0.08, 0.16, 0.24, 0.36, 0.44];
  for (var i = 0; i < notes.length; i++) {
    tone(b, times[i], i == 5 ? 0.3 : 0.1, midi(notes[i]), vol: 0.22, wave: (p) => square(p, 0.5), release: 0.06);
  }
  return b;
}

List<double> kilometer() {
  final b = buffer(0.4);
  tone(b, 0, 0.15, midi(81), vol: 0.22, wave: tri);
  tone(b, 0.13, 0.25, midi(86), vol: 0.22, wave: tri, release: 0.15);
  return b;
}

List<double> crash() {
  final b = buffer(1.0);
  noiseBurst(b, 0, 1.0, vol: 0.8, decay: 4, lowpass: 0.6);
  tone(b, 0, 0.5, 160, vol: 0.5, wave: saw, slide: -120);
  for (var i = 0; i < 5; i++) {
    noiseBurst(b, 0.25 + i * 0.12, 0.08, vol: 0.3, decay: 40, lowpass: 0.9);
  }
  return b;
}

List<double> sputter() {
  final b = buffer(1.2);
  var t = 0.0;
  var gap = 0.07;
  while (t < 1.05) {
    tone(b, t, 0.05, 70, vol: 0.5, wave: saw, release: 0.03);
    noiseBurst(b, t, 0.05, vol: 0.15, decay: 40);
    t += gap;
    gap *= 1.22;
  }
  return b;
}

List<double> gameOver() {
  final b = buffer(1.1);
  const notes = [67, 64, 60, 55];
  for (var i = 0; i < notes.length; i++) {
    tone(b, i * 0.2, i == 3 ? 0.5 : 0.18, midi(notes[i]), vol: 0.25, wave: (p) => square(p, 0.5), release: 0.1);
  }
  return b;
}

// ---------------------------------------------------------------- loops

/// 1 s engine loop; 92 Hz gives a whole number of cycles so it loops cleanly.
List<double> engineLoop() {
  final b = buffer(1.0);
  for (var i = 0; i < b.length; i++) {
    final t = i / sampleRate;
    final p = t * 92;
    final putt = 0.75 + 0.25 * math.sin(2 * math.pi * 23 * t);
    b[i] = (saw(p) * 0.5 + square(p * 2, 0.3) * 0.15) * putt * 0.5;
  }
  return b;
}

/// Police "wail": symmetric sweep so phase lines up at the loop point.
List<double> sirenLoop() {
  final b = buffer(1.2);
  var phase = 0.0;
  for (var i = 0; i < b.length; i++) {
    final t = i / sampleRate;
    final f = 950 + 260 * -math.cos(2 * math.pi * t / 1.2);
    phase += f / sampleRate;
    b[i] = (square(phase, 0.5) * 0.18 + math.sin(2 * math.pi * phase) * 0.12);
  }
  return b;
}

/// Ambulance "wee-woo" two-tone; each half holds a whole number of cycles.
List<double> ambulanceLoop() {
  final b = buffer(1.0);
  for (var i = 0; i < b.length; i++) {
    final t = i / sampleRate;
    final f = t < 0.5 ? 960.0 : 770.0;
    b[i] = math.sin(2 * math.pi * f * t) * 0.25 + square(f * t, 0.5) * 0.06;
  }
  return b;
}

// ---------------------------------------------------------------- music

/// Simple step sequencer: melody, bass and hi-hat on an 8th-note grid.
List<double> sequence({
  required int bpm,
  required List<int?> melody,
  required List<int?> bass,
  required double melodyVol,
  double duty = 0.25,
  bool driving = false,
}) {
  final step = 60 / bpm / 2;
  final steps = melody.length;
  final b = buffer(step * steps);
  for (var i = 0; i < steps; i++) {
    final t = i * step;
    final m = melody[i];
    if (m != null) {
      tone(b, t, step * 0.9, midi(m), vol: melodyVol, wave: (p) => square(p, duty), release: step * 0.4);
    }
    final bn = bass[i % bass.length];
    if (bn != null) tone(b, t, step * 0.95, midi(bn), vol: 0.22, wave: tri, release: step * 0.2);
    noiseBurst(b, t, 0.04, vol: i.isEven ? 0.08 : 0.05, decay: 80, lowpass: 0.95);
    if (driving && i % 4 == 0) tone(b, t, 0.08, 60, vol: 0.4, wave: tri, slide: -30, release: 0.06);
    if (driving && i % 8 == 4) noiseBurst(b, t, 0.1, vol: 0.18, decay: 30, lowpass: 0.5);
  }
  return b;
}

List<double> menuMusic() {
  // Bright, festive C-major pentatonic tune (8 bars of 8th notes).
  const melody = <int?>[
    72, null, 74, 76, 79, null, 76, 74, //
    72, null, 69, 72, 74, null, null, null,
    76, null, 79, 81, 79, 76, 74, 76,
    72, null, 74, 72, 69, null, null, null,
    72, null, 74, 76, 79, null, 81, 79,
    84, null, 81, 79, 76, null, 74, null,
    76, 79, 76, 74, 72, null, 69, 72,
    74, null, 72, null, 72, null, null, null,
  ];
  const bass = <int?>[48, null, 55, null, 52, null, 55, null, 45, null, 52, null, 50, null, 55, null];
  return sequence(bpm: 124, melody: melody, bass: bass, melodyVol: 0.13);
}

List<double> rideMusic() {
  // Faster, driving A-minor riff for gameplay.
  const melody = <int?>[
    69, null, 69, 72, null, 74, 76, null, //
    74, 72, null, 69, null, 67, 69, null,
    69, null, 69, 72, null, 74, 76, 79,
    81, null, 79, 76, 74, null, 72, null,
    77, null, 76, 74, null, 72, 74, null,
    76, null, 74, 72, 69, null, 67, null,
    69, 72, 74, 76, 79, 76, 74, 72,
    69, null, null, 64, 69, null, null, null,
  ];
  const bass = <int?>[45, 45, 57, 45, 45, 57, 45, 57, 41, 41, 53, 41, 43, 43, 55, 43];
  return sequence(bpm: 150, melody: melody, bass: bass, melodyVol: 0.1, duty: 0.5, driving: true);
}

// ---------------------------------------------------------------- update 2

List<double> whoosh() {
  final b = buffer(0.35);
  var last = 0.0;
  for (var i = 0; i < b.length; i++) {
    final t = i / sampleRate;
    // Band-limited noise swelling then fading, like a car rushing past.
    final cutoff = 0.05 + 0.4 * math.sin(math.pi * t / 0.35);
    last += (noise() - last) * cutoff;
    b[i] = last * math.sin(math.pi * t / 0.35) * 0.8;
  }
  return b;
}

List<double> brakeScreech() {
  final b = buffer(0.7);
  var phase = 0.0;
  for (var i = 0; i < b.length; i++) {
    final t = i / sampleRate;
    phase += (2300 - 500 * t + 60 * math.sin(t * 90)) / sampleRate;
    final env = math.min(1.0, t / 0.03) * math.max(0, 1 - t / 0.7);
    b[i] = (math.sin(2 * math.pi * phase) * 0.25 + noise() * 0.08) * env;
  }
  return b;
}

List<double> challengeChime() {
  final b = buffer(0.45);
  tone(b, 0, 0.12, midi(76), vol: 0.22, wave: tri);
  tone(b, 0.1, 0.12, midi(79), vol: 0.22, wave: tri);
  tone(b, 0.2, 0.22, midi(83), vol: 0.22, wave: tri, release: 0.15);
  return b;
}

/// Cartoon spring "boing".
List<double> memeBoing() {
  final b = buffer(0.5);
  var phase = 0.0;
  for (var i = 0; i < b.length; i++) {
    final t = i / sampleRate;
    final f = 180 + 220 * math.exp(-t * 6) * (1 + 0.3 * math.sin(t * 60));
    phase += f / sampleRate;
    b[i] = math.sin(2 * math.pi * phase) * 0.45 * math.exp(-t * 4);
  }
  return b;
}

/// Sad descending "wah wah wah waaah" (original melody).
List<double> memeWahWah() {
  final b = buffer(1.4);
  const notes = [62, 61, 60, 59];
  for (var i = 0; i < 4; i++) {
    final len = i == 3 ? 0.65 : 0.22;
    final start = i * 0.25;
    final s0 = (start * sampleRate).round();
    final n = (len * sampleRate).round();
    var phase = 0.0;
    for (var j = 0; j < n && s0 + j < b.length; j++) {
      final t = j / sampleRate;
      final vib = i == 3 ? math.sin(t * 2 * math.pi * 6) * 4 : 0;
      phase += (midi(notes[i]) + vib) / sampleRate;
      // "Wah" filter sweep approximated by mixing harmonics over time.
      final wah = 0.5 + 0.5 * math.sin(math.pi * math.min(1.0, t / len));
      final v = saw(phase) * wah + square(phase, 0.3) * (1 - wah) * 0.5;
      final env = math.min(1.0, t / 0.02) * math.min(1.0, (len - t) / 0.05);
      b[s0 + j] += v * 0.3 * env;
    }
  }
  return b;
}

/// Short stadium-style air horn blast (synthesized chord).
List<double> memeAirhorn() {
  final b = buffer(0.6);
  for (final f in [415.0, 523.0, 622.0]) {
    tone(b, 0, 0.55, f, vol: 0.14, wave: saw, attack: 0.01, release: 0.08);
  }
  return b;
}

List<double> memeTada() {
  final b = buffer(0.8);
  tone(b, 0, 0.1, midi(72), vol: 0.2, wave: (p) => square(p, 0.25));
  for (final n in [72, 76, 79, 84]) {
    tone(b, 0.12, 0.6, midi(n), vol: 0.1, wave: (p) => square(p, 0.25), release: 0.3);
  }
  return b;
}

/// Two little synthesized barks.
List<double> memeWoof() {
  final b = buffer(0.5);
  for (final start in [0.0, 0.22]) {
    tone(b, start, 0.14, 330, vol: 0.4, wave: saw, slide: -160, release: 0.08);
    noiseBurst(b, start, 0.06, vol: 0.2, decay: 40, lowpass: 0.4);
  }
  return b;
}

List<double> memeMeow() {
  final b = buffer(0.6);
  var phase = 0.0;
  for (var i = 0; i < b.length; i++) {
    final t = i / sampleRate;
    // Rising then falling pitch: "mee-ow".
    final f = 600 + 500 * math.sin(math.pi * t / 0.6) - 150 * t;
    phase += f / sampleRate;
    final env = math.sin(math.pi * t / 0.6);
    b[i] = (math.sin(2 * math.pi * phase) * 0.6 + square(phase, 0.5) * 0.08) * env * 0.4;
  }
  return b;
}

List<double> memeCluck() {
  final b = buffer(0.55);
  for (final start in [0.0, 0.12, 0.24, 0.36]) {
    tone(b, start, 0.07, 900, vol: 0.3, wave: (p) => square(p, 0.2), slide: -400, release: 0.04);
  }
  return b;
}

/// Two-note "uh-oh".
List<double> memeUhOh() {
  final b = buffer(0.5);
  tone(b, 0, 0.18, midi(67), vol: 0.3, wave: tri, release: 0.06);
  tone(b, 0.22, 0.26, midi(62), vol: 0.3, wave: tri, release: 0.12);
  return b;
}
