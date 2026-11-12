import 'dart:math' as math;

import 'notes.dart';

/// Variant of a swara: natural (Sa, Pa), komal (flat), shuddh (natural of a
/// swara that also has a komal form) or tivra (sharp Ma).
enum SwaraVariant { none, komal, shuddh, tivra }

/// One of the 12 swarasthanas above Sa.
class Swara {
  const Swara(this.degree, this.roman, this.devanagari, this.variant, this.justRatio);

  /// Semitones above Sa, 0..11.
  final int degree;

  /// Name in Latin letters: Sa, Re, Ga, Ma, Pa, Dha, Ni.
  final String roman;

  /// Name in Devanagari.
  final String devanagari;

  final SwaraVariant variant;

  /// Frequency ratio to Sa in just intonation.
  final double justRatio;

  String get variantRoman => switch (variant) {
        SwaraVariant.none => '',
        SwaraVariant.komal => 'komal',
        SwaraVariant.shuddh => 'shuddh',
        SwaraVariant.tivra => 'tivra',
      };

  String get variantDevanagari => switch (variant) {
        SwaraVariant.none => '',
        SwaraVariant.komal => 'कोमल',
        SwaraVariant.shuddh => 'शुद्ध',
        SwaraVariant.tivra => 'तीव्र',
      };

  /// Short label such as `Re`, `komal Re` or `tivra Ma`.
  String label({bool devanagariScript = false}) {
    final base = devanagariScript ? devanagari : roman;
    final v = devanagariScript ? variantDevanagari : variantRoman;
    return v.isEmpty ? base : '$v $base';
  }

  /// Compact label: komal swaras in lower case (re, ga, dha, ni), tivra Ma as
  /// `Ma+`. Devanagari adds a combining mark instead.
  String get short => switch (variant) {
        SwaraVariant.komal => roman.toLowerCase(),
        SwaraVariant.tivra => '$roman+',
        _ => roman,
      };
}

/// The 12 swaras, indexed by semitones above Sa.
const swaras = <Swara>[
  Swara(0, 'Sa', 'सा', SwaraVariant.none, 1),
  Swara(1, 'Re', 'रे', SwaraVariant.komal, 16 / 15),
  Swara(2, 'Re', 'रे', SwaraVariant.shuddh, 9 / 8),
  Swara(3, 'Ga', 'ग', SwaraVariant.komal, 6 / 5),
  Swara(4, 'Ga', 'ग', SwaraVariant.shuddh, 5 / 4),
  Swara(5, 'Ma', 'म', SwaraVariant.shuddh, 4 / 3),
  Swara(6, 'Ma', 'म', SwaraVariant.tivra, 45 / 32),
  Swara(7, 'Pa', 'प', SwaraVariant.none, 3 / 2),
  Swara(8, 'Dha', 'ध', SwaraVariant.komal, 8 / 5),
  Swara(9, 'Dha', 'ध', SwaraVariant.shuddh, 5 / 3),
  Swara(10, 'Ni', 'नि', SwaraVariant.komal, 9 / 5),
  Swara(11, 'Ni', 'नि', SwaraVariant.shuddh, 15 / 8),
];

/// Register of a swara relative to the octave of Sa.
enum Saptak { atiMandra, mandra, madhya, taar, atiTaar }

extension SaptakNames on Saptak {
  String get roman => switch (this) {
        Saptak.atiMandra => 'ati-mandra',
        Saptak.mandra => 'mandra',
        Saptak.madhya => 'madhya',
        Saptak.taar => 'taar',
        Saptak.atiTaar => 'ati-taar',
      };

  String get devanagari => switch (this) {
        Saptak.atiMandra => 'अति मन्द्र',
        Saptak.mandra => 'मन्द्र',
        Saptak.madhya => 'मध्य',
        Saptak.taar => 'तार',
        Saptak.atiTaar => 'अति तार',
      };
}

Saptak saptakForOctave(int octave) {
  if (octave <= -2) return Saptak.atiMandra;
  return switch (octave) {
    -1 => Saptak.mandra,
    0 => Saptak.madhya,
    1 => Saptak.taar,
    _ => Saptak.atiTaar,
  };
}

/// A swara heard at a given frequency.
class SwaraReading {
  const SwaraReading({
    required this.swara,
    required this.octave,
    required this.cents,
    required this.freq,
    required this.targetFreq,
  });

  final Swara swara;

  /// Octaves above (positive) or below the octave that starts at Sa.
  final int octave;

  /// Deviation from the target pitch, -50..+50 for equal temperament.
  final double cents;
  final double freq;
  final double targetFreq;

  Saptak get saptak => saptakForOctave(octave);
}

/// Sa choice: a pitch class (0 = C), an octave (scientific notation) and a
/// fine tuning in cents.
class SaPitch {
  const SaPitch({this.pitchClass = 0, this.octave = 3, this.fineCents = 0});

  final int pitchClass;
  final int octave;
  final double fineCents;

  int get midi => (octave + 1) * 12 + pitchClass;

  String get name => noteNames[pitchClass];
  String get label => '$name$octave';

  /// Frequency of Sa in Hz.
  double freq(double refA) => midiToFreq(midi + fineCents / 100, refA: refA);

  SaPitch copyWith({int? pitchClass, int? octave, double? fineCents}) =>
      SaPitch(pitchClass: pitchClass ?? this.pitchClass, octave: octave ?? this.octave, fineCents: fineCents ?? this.fineCents);
}

/// Common harmonium keyboard names for the 12 notes starting at C:
/// Safed 1 = C, Kali 1 = C#, Safed 2 = D, Kali 2 = D#, Safed 3 = E, Safed 4 = F,
/// Kali 3 = F#, Safed 5 = G, Kali 4 = G#, Safed 6 = A, Kali 5 = A#, Safed 7 = B.
/// (Safed = white key, kali = black key.)
String kaliSafedName(int pitchClass) {
  const names = [
    'Safed 1',
    'Kali 1',
    'Safed 2',
    'Kali 2',
    'Safed 3',
    'Safed 4',
    'Kali 3',
    'Safed 5',
    'Kali 4',
    'Safed 6',
    'Kali 5',
    'Safed 7',
  ];
  return names[pitchClass % 12];
}

/// Finds the swara closest to [freq] for a given Sa frequency.
///
/// With [just] false the 12 swaras are the equal-tempered semitones above Sa.
/// With [just] true they sit at the just-intonation ratios of [swaras]
/// (Sa 1, komal Re 16/15, Re 9/8, ... Ni 15/8), which is how a sruti-based
/// singer or a tanpura hears them. Returns null for a non-positive input.
SwaraReading? swaraForFreq(double freq, double saFreq, {bool just = false}) {
  if (freq <= 0 || saFreq <= 0) return null;
  final total = centsBetween(freq, saFreq);
  final octave = (total / 1200).floor();
  final within = total - octave * 1200;

  // Candidates: all 12 in this octave, plus Sa of the next octave (and the
  // top swara of the one below, for just intonation close to Sa).
  var bestDegree = 0;
  var bestOctave = octave;
  var bestDelta = double.infinity;
  for (var o = octave; o <= octave + 1; o++) {
    for (final s in swaras) {
      if (o == octave + 1 && s.degree != 0) continue;
      final target = just ? 1200 * math.log(s.justRatio) / math.ln2 : s.degree * 100.0;
      final delta = (o - octave) * 1200 + target - within;
      if (delta.abs() < bestDelta.abs()) {
        bestDelta = delta;
        bestDegree = s.degree;
        bestOctave = o;
      }
    }
  }
  final swara = swaras[bestDegree];
  final targetFreq = saFreq * math.pow(2, bestOctave) * (just ? swara.justRatio : math.pow(2, swara.degree / 12));
  return SwaraReading(
    swara: swara,
    octave: bestOctave,
    cents: -bestDelta,
    freq: freq,
    targetFreq: targetFreq.toDouble(),
  );
}
