import 'package:flutter_test/flutter_test.dart';
import 'package:sruti/core/notes.dart';
import 'package:sruti/core/tunings.dart';

void main() {
  group('note math', () {
    test('A4 is 440 and MIDI 69', () {
      expect(midiToFreq(69), 440);
      expect(freqToMidi(440), closeTo(69, 1e-9));
    });

    test('middle C', () {
      expect(midiToFreq(60), closeTo(261.6256, 1e-3));
    });

    test('adjustable reference', () {
      expect(midiToFreq(69, refA: 432), closeTo(432, 1e-9));
      expect(midiToFreq(57, refA: 432), closeTo(216, 1e-9));
      final r = NoteReading.fromFreq(432, refA: 432);
      expect(r.label, 'A4');
      expect(r.cents.abs(), lessThan(1e-9));
    });

    test('cents between octave and semitone', () {
      expect(centsBetween(880, 440), closeTo(1200, 1e-9));
      expect(centsBetween(440 * 1.0594630943593, 440), closeTo(100, 1e-6));
      expect(centsBetween(430, 440), lessThan(0));
    });

    test('names and octaves', () {
      expect(noteName(60), 'C');
      expect(noteOctave(60), 4);
      expect(noteName(61), 'C#');
      expect(noteOctave(40), 2);
      expect(noteName(40), 'E');
      expect(noteOctave(23), 0);
    });

    test('NoteReading rounds to the nearest note', () {
      final r = NoteReading.fromFreq(445);
      expect(r.label, 'A4');
      expect(r.cents, closeTo(19.56, 0.05));
      final low = NoteReading.fromFreq(82.41);
      expect(low.label, 'E2');
      expect(low.cents.abs(), lessThan(0.5));
      final flat = NoteReading.fromFreq(midiToFreq(60, refA: 440) * 0.99);
      expect(flat.label, 'C4');
      expect(flat.cents, lessThan(0));
    });

    test('cents stay within +-50', () {
      for (var f = 40.0; f < 1800; f *= 1.013) {
        expect(NoteReading.fromFreq(f).cents.abs(), lessThanOrEqualTo(50.0000001));
      }
    });

    test('in tune window', () {
      expect(isInTune(3.9), isTrue);
      expect(isInTune(-4), isTrue);
      expect(isInTune(5), isFalse);
    });
  });

  group('tunings', () {
    test('standard guitar frequencies', () {
      final t = tuningById('standard');
      final f = t.strings.map((s) => s.freq(440)).toList();
      const expected = [82.407, 110.0, 146.832, 195.998, 246.942, 329.628];
      for (var i = 0; i < 6; i++) {
        expect(f[i], closeTo(expected[i], 0.01));
      }
      expect(t.notes, 'E A D G B E');
    });

    test('guitar tunings have six strings, bass four, ukulele four', () {
      for (final t in tunings) {
        expect(t.strings.length, t.instrument == 'Guitar' ? 6 : 4, reason: t.name);
      }
    });

    test('alternate tunings', () {
      expect(tuningById('drop_d').notes, 'D A D G B E');
      expect(tuningById('d_standard').notes, 'D G C F A D');
      expect(tuningById('open_g').notes, 'D G D G B D');
      expect(tuningById('open_d').notes, 'D A D F# A D');
      expect(tuningById('dadgad').notes, 'D A D G A D');
      expect(tuningById('half_down').notes, 'D# G# C# F# A# D#');
      expect(tuningById('bass4').notes, 'E A D G');
      expect(tuningById('ukulele').notes, 'G C E A');
    });

    test('bass E1 and ukulele G4', () {
      expect(tuningById('bass4').strings.first.freq(440), closeTo(41.203, 0.01));
      expect(tuningById('ukulele').strings.first.label, 'G4');
    });

    test('ids are unique and unknown falls back to the default', () {
      expect(tunings.map((t) => t.id).toSet().length, tunings.length);
      expect(tuningById('nope').id, tunings.first.id);
      expect(tuningById(null).id, 'standard');
    });

    test('nearestString picks the closest string', () {
      final t = tuningById('standard');
      expect(t.nearestString(82, 440), 0);
      expect(t.nearestString(112, 440), 1);
      expect(t.nearestString(150, 440), 2);
      expect(t.nearestString(330, 440), 5);
      expect(t.nearestString(240, 440), 4);
    });

    test('nearestString follows the reference pitch', () {
      final t = tuningById('standard');
      // A2 at A4 = 430 is 107.5 Hz.
      expect(t.nearestString(107.5, 430), 1);
      expect(t.centsFromString(107.5, 1, 430).abs(), lessThan(0.01));
    });

    test('centsFromString sign', () {
      final t = tuningById('standard');
      expect(t.centsFromString(112, 1, 440), greaterThan(0));
      expect(t.centsFromString(108, 1, 440), lessThan(0));
    });
  });
}
