import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sruti/core/notes.dart';
import 'package:sruti/core/swara.dart';

void main() {
  const sa = 130.8128; // C3

  group('swaraForFreq, equal temperament', () {
    test('Sa itself', () {
      final r = swaraForFreq(sa, sa)!;
      expect(r.swara.roman, 'Sa');
      expect(r.octave, 0);
      expect(r.saptak, Saptak.madhya);
      expect(r.cents.abs(), lessThan(1e-6));
    });

    test('all 12 degrees in the middle octave', () {
      const names = [
        'Sa', 'Re', 'Re', 'Ga', 'Ga', 'Ma', 'Ma', 'Pa', 'Dha', 'Dha', 'Ni', 'Ni', //
      ];
      const variants = [
        SwaraVariant.none,
        SwaraVariant.komal,
        SwaraVariant.shuddh,
        SwaraVariant.komal,
        SwaraVariant.shuddh,
        SwaraVariant.shuddh,
        SwaraVariant.tivra,
        SwaraVariant.none,
        SwaraVariant.komal,
        SwaraVariant.shuddh,
        SwaraVariant.komal,
        SwaraVariant.shuddh,
      ];
      for (var d = 0; d < 12; d++) {
        final f = sa * math.pow(2, d / 12);
        final r = swaraForFreq(f.toDouble(), sa)!;
        expect(r.swara.degree, d);
        expect(r.swara.roman, names[d]);
        expect(r.swara.variant, variants[d]);
        expect(r.octave, 0);
        expect(r.cents.abs(), lessThan(1e-6));
      }
    });

    test('mandra and taar saptak', () {
      final low = swaraForFreq(sa * math.pow(2, 7 / 12) / 2, sa)!;
      expect(low.swara.roman, 'Pa');
      expect(low.saptak, Saptak.mandra);
      final high = swaraForFreq(sa * 2 * math.pow(2, 4 / 12), sa)!;
      expect(high.swara.label(), 'shuddh Ga');
      expect(high.saptak, Saptak.taar);
      expect(swaraForFreq(sa * 4, sa)!.saptak, Saptak.atiTaar);
      expect(swaraForFreq(sa / 4, sa)!.saptak, Saptak.atiMandra);
    });

    test('cents deviation sign and size', () {
      final sharp = swaraForFreq(sa * math.pow(2, (7 + 0.2) / 12), sa)!;
      expect(sharp.swara.roman, 'Pa');
      expect(sharp.cents, closeTo(20, 1e-6));
      final flat = swaraForFreq(sa * math.pow(2, (7 - 0.3) / 12), sa)!;
      expect(flat.cents, closeTo(-30, 1e-6));
    });

    test('just below Sa belongs to Ni of the lower octave when 40 cents flat of Sa', () {
      final r = swaraForFreq(sa * math.pow(2, -0.4 / 12), sa)!;
      expect(r.swara.roman, 'Sa');
      expect(r.cents, closeTo(-40, 1e-6));
      final lowNi = swaraForFreq(sa * math.pow(2, -1 / 12), sa)!;
      expect(lowNi.swara.degree, 11);
      expect(lowNi.octave, -1);
    });

    test('rounds up to the next Sa', () {
      final r = swaraForFreq(sa * 2 * 0.998, sa)!;
      expect(r.swara.degree, 0);
      expect(r.octave, 1);
      expect(r.cents, lessThan(0));
    });

    test('invalid input', () {
      expect(swaraForFreq(0, sa), isNull);
      expect(swaraForFreq(100, 0), isNull);
    });

    test('target frequency matches', () {
      final r = swaraForFreq(sa * 1.5, sa)!;
      expect(r.swara.roman, 'Pa');
      expect(r.targetFreq, closeTo(sa * math.pow(2, 7 / 12), 1e-6));
    });
  });

  group('swaraForFreq, just intonation', () {
    test('pure fifth is exactly Pa', () {
      final r = swaraForFreq(sa * 1.5, sa, just: true)!;
      expect(r.swara.roman, 'Pa');
      expect(r.cents.abs(), lessThan(1e-6));
      expect(r.targetFreq, closeTo(sa * 1.5, 1e-9));
    });

    test('pure major third is exactly shuddh Ga, 14 cents under equal temperament', () {
      final r = swaraForFreq(sa * 5 / 4, sa, just: true)!;
      expect(r.swara.label(), 'shuddh Ga');
      expect(r.cents.abs(), lessThan(1e-6));
      final et = swaraForFreq(sa * 5 / 4, sa)!;
      expect(et.cents, closeTo(-13.69, 0.01));
    });

    test('every degree at its just ratio is exact', () {
      for (final s in swaras) {
        for (final oct in [-1, 0, 1]) {
          final r = swaraForFreq(sa * s.justRatio * math.pow(2, oct), sa, just: true)!;
          expect(r.swara.degree, s.degree, reason: s.label());
          expect(r.octave, oct);
          expect(r.cents.abs(), lessThan(1e-6));
        }
      }
    });

    test('ratios rise monotonically', () {
      for (var i = 1; i < swaras.length; i++) {
        expect(swaras[i].justRatio, greaterThan(swaras[i - 1].justRatio));
      }
    });
  });

  group('labels', () {
    test('roman and devanagari', () {
      expect(swaras[1].label(), 'komal Re');
      expect(swaras[1].label(devanagariScript: true), 'कोमल रे');
      expect(swaras[6].label(), 'tivra Ma');
      expect(swaras[6].label(devanagariScript: true), 'तीव्र म');
      expect(swaras[0].label(), 'Sa');
      expect(swaras[0].label(devanagariScript: true), 'सा');
      expect(swaras[7].devanagari, 'प');
      expect(swaras[11].devanagari, 'नि');
    });

    test('short labels', () {
      expect(swaras[1].short, 're');
      expect(swaras[6].short, 'Ma+');
      expect(swaras[4].short, 'Ga');
    });

    test('saptak names', () {
      expect(Saptak.mandra.devanagari, 'मन्द्र');
      expect(Saptak.taar.roman, 'taar');
      expect(saptakForOctave(0), Saptak.madhya);
    });

    test('kali safed numbering', () {
      expect(kaliSafedName(0), 'Safed 1');
      expect(kaliSafedName(1), 'Kali 1');
      expect(kaliSafedName(11), 'Safed 7');
      expect(List.generate(12, kaliSafedName).where((n) => n.startsWith('Safed')).length, 7);
      expect(List.generate(12, kaliSafedName).where((n) => n.startsWith('Kali')).length, 5);
    });
  });

  group('SaPitch', () {
    test('C3 is MIDI 48', () {
      const s = SaPitch(pitchClass: 0, octave: 3);
      expect(s.midi, 48);
      expect(s.label, 'C3');
      expect(s.freq(440), closeTo(130.8128, 1e-3));
    });

    test('fine tune and reference', () {
      const s = SaPitch(pitchClass: 9, octave: 3, fineCents: 50);
      expect(centsBetween(s.freq(440), 220), closeTo(50, 1e-6));
      expect(const SaPitch(pitchClass: 9, octave: 4).freq(432), closeTo(432, 1e-9));
    });

    test('copyWith', () {
      final s = const SaPitch().copyWith(pitchClass: 2, fineCents: -10);
      expect(s.pitchClass, 2);
      expect(s.octave, 3);
      expect(s.fineCents, -10);
    });
  });
}
