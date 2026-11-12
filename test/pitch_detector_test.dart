import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sruti/core/notes.dart';
import 'package:sruti/core/pitch_detector.dart';

/// [partials] is a list of (harmonic number, amplitude).
Float64List synth(
  double f0,
  int n, {
  int sr = 44100,
  List<(int, double)> partials = const [(1, 1.0)],
  double phase = 0,
  double amp = 0.5,
}) {
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    var v = 0.0;
    for (final (h, a) in partials) {
      v += a * math.sin(2 * math.pi * f0 * h * i / sr + phase * h);
    }
    out[i] = amp * v;
  }
  return out;
}

const rich = <(int, double)>[(1, 1.0), (2, 0.7), (3, 0.5), (4, 0.35), (5, 0.25), (6, 0.2), (7, 0.1), (8, 0.08)];

void main() {
  final detector = PitchDetector();

  double cents(double f, double target) => centsBetween(f, target);

  group('PitchDetector sine waves', () {
    for (final f in [41.2, 55.0, 82.41, 110.0, 146.83, 196.0, 261.63, 329.63, 440.0, 659.26, 1000.0, 1318.5, 1900.0]) {
      test('$f Hz', () {
        final r = detector.detect(synth(f, detector.bufferSize));
        expect(r, isNotNull);
        expect(cents(r!.freq, f).abs(), lessThan(3), reason: 'got ${r.freq}');
        expect(r.confidence, greaterThan(0.9));
      });
    }

    test('any phase gives the same pitch', () {
      for (final p in [0.0, 1.0, 2.5, 4.0]) {
        final r = detector.detect(synth(220, detector.bufferSize, phase: p));
        expect(cents(r!.freq, 220).abs(), lessThan(3));
      }
    });

    test('only the last bufferSize samples are used', () {
      final tail = synth(330, detector.bufferSize);
      final x = Float64List(detector.bufferSize + 3000)..setAll(3000, tail);
      for (var i = 0; i < 3000; i++) {
        x[i] = math.sin(i * 0.9); // junk before
      }
      final r = detector.detect(x);
      expect(cents(r!.freq, 330).abs(), lessThan(3));
    });

    test('detects a 3 cent sharp note as 3 cents sharp', () {
      final f = 440 * math.pow(2, 3 / 1200);
      final r = detector.detect(synth(f.toDouble(), detector.bufferSize));
      expect(cents(r!.freq, 440), closeTo(3, 1.5));
    });

    test('works at 48 kHz', () {
      final d = PitchDetector(sampleRate: 48000);
      for (final f in [82.41, 440.0, 1500.0]) {
        final r = d.detect(synth(f, d.bufferSize, sr: 48000));
        expect(cents(r!.freq, f).abs(), lessThan(3), reason: '$f');
      }
    });
  });

  group('PitchDetector harmonic-rich signals (octave errors)', () {
    for (final f in [41.2, 82.41, 110.0, 146.83, 196.0, 246.94, 329.63, 523.25, 880.0]) {
      test('rich tone at $f Hz is not an octave off', () {
        final r = detector.detect(synth(f, detector.bufferSize, partials: rich));
        expect(r, isNotNull);
        expect(cents(r!.freq, f).abs(), lessThan(5), reason: 'got ${r.freq}, expected $f');
      });
    }

    test('strong second harmonic and weak fundamental', () {
      const p = <(int, double)>[(1, 0.25), (2, 1.0), (3, 0.6), (4, 0.4)];
      final r = detector.detect(synth(110, detector.bufferSize, partials: p));
      expect(cents(r!.freq, 110).abs(), lessThan(5), reason: 'got ${r.freq}');
    });

    test('missing fundamental still gives the period', () {
      const p = <(int, double)>[(2, 1.0), (3, 0.8), (4, 0.6), (5, 0.4)];
      final r = detector.detect(synth(130.81, detector.bufferSize, partials: p));
      expect(cents(r!.freq, 130.81).abs(), lessThan(5), reason: 'got ${r.freq}');
    });

    test('sawtooth', () {
      const f = 200.0;
      final x = Float64List(detector.bufferSize);
      for (var i = 0; i < x.length; i++) {
        final t = (i * f / 44100) % 1.0;
        x[i] = 0.5 * (2 * t - 1);
      }
      final r = detector.detect(x);
      expect(cents(r!.freq, f).abs(), lessThan(5));
    });

    test('decaying plucked string with a little noise', () {
      final rng = math.Random(7);
      const f = 110.0;
      final x = synth(f, detector.bufferSize, partials: rich);
      for (var i = 0; i < x.length; i++) {
        x[i] = x[i] * math.exp(-i / 20000) + 0.01 * (rng.nextDouble() - 0.5);
      }
      final r = detector.detect(x);
      expect(cents(r!.freq, f).abs(), lessThan(5));
    });

    test('every standard guitar string with harmonics', () {
      for (final midi in [40, 45, 50, 55, 59, 64]) {
        final f = midiToFreq(midi.toDouble());
        final r = detector.detect(synth(f, detector.bufferSize, partials: rich));
        expect(cents(r!.freq, f).abs(), lessThan(5), reason: 'midi $midi got ${r.freq} want $f');
      }
    });
  });

  group('PitchDetector rejects non-pitched input', () {
    test('silence', () {
      expect(detector.detect(Float64List(detector.bufferSize)), isNull);
    });

    test('very quiet signal', () {
      expect(detector.detect(synth(440, detector.bufferSize, amp: 0.0002)), isNull);
    });

    test('white noise', () {
      final rng = math.Random(1);
      final x = Float64List(detector.bufferSize);
      for (var i = 0; i < x.length; i++) {
        x[i] = 0.4 * (rng.nextDouble() * 2 - 1);
      }
      final r = detector.detect(x);
      expect(r == null || r.confidence < 0.8, isTrue);
    });

    test('too short input', () {
      expect(detector.detect(Float64List(100)), isNull);
    });

    test('out of range: 20 Hz and 3 kHz', () {
      expect(detector.detect(synth(20, detector.bufferSize)), isNull);
      final r = detector.detect(synth(3000, detector.bufferSize));
      expect(r == null || r.freq < 2000, isTrue);
    });
  });

  group('PitchTracker', () {
    PitchResult at(double f, [double c = 0.95]) => PitchResult(freq: f, confidence: c, rms: 0.1);

    test('needs two agreeing frames to show the first pitch', () {
      final t = PitchTracker();
      expect(t.update(at(440)), isNull);
      expect(t.update(at(440.5)), closeTo(440.5, 0.01));
    });

    test('ignores a single octave blip', () {
      final t = PitchTracker();
      t.update(at(220));
      t.update(at(220));
      expect(t.update(at(440)), closeTo(220, 0.01));
      final back = t.update(at(220.2))!;
      expect(back, closeTo(220, 1));
    });

    test('follows a real jump after two frames', () {
      final t = PitchTracker();
      t.update(at(220));
      t.update(at(220));
      t.update(at(330));
      expect(t.update(at(330.2)), closeTo(330.2, 0.01));
    });

    test('smooths small changes', () {
      final t = PitchTracker();
      t.update(at(440));
      t.update(at(440));
      final v = t.update(at(444))!;
      expect(v, greaterThan(440));
      expect(v, lessThan(444));
    });

    test('holds through short gaps, clears after long ones', () {
      final t = PitchTracker(holdFrames: 3);
      t.update(at(440));
      t.update(at(440));
      for (var i = 0; i < 3; i++) {
        expect(t.update(null), closeTo(440, 0.01));
      }
      expect(t.update(null), isNull);
    });

    test('low confidence counts as a gap', () {
      final t = PitchTracker(holdFrames: 0);
      t.update(at(440));
      t.update(at(440));
      expect(t.update(at(300, 0.3)), isNull);
    });
  });
}
