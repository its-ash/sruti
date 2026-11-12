import 'notes.dart';

/// One string of an instrument: its note as a MIDI number.
class InstrumentString {
  const InstrumentString(this.midi);

  final int midi;

  String get name => noteName(midi);
  int get octave => noteOctave(midi);
  String get label => '$name$octave';

  double freq(double refA) => midiToFreq(midi.toDouble(), refA: refA);
}

/// A named set of strings, listed from the low-pitched string to the high one
/// (a ukulele is listed in playing order G C E A, where G is the high string).
class Tuning {
  const Tuning(this.id, this.name, this.instrument, this.strings);

  final String id;
  final String name;
  final String instrument;
  final List<InstrumentString> strings;

  /// Index of the string whose pitch is closest to [freq] (in cents).
  int nearestString(double freq, double refA) {
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < strings.length; i++) {
      final d = centsBetween(freq, strings[i].freq(refA)).abs();
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return best;
  }

  /// Cents of [freq] from string [index].
  double centsFromString(double freq, int index, double refA) => centsBetween(freq, strings[index].freq(refA));

  String get notes => strings.map((s) => s.name).join(' ');
}

const _e2 = 40, _a2 = 45, _d3 = 50, _g3 = 55, _b3 = 59, _e4 = 64;

/// Built-in tunings. The first one is the default.
const tunings = <Tuning>[
  Tuning('standard', 'Standard', 'Guitar', [
    InstrumentString(_e2),
    InstrumentString(_a2),
    InstrumentString(_d3),
    InstrumentString(_g3),
    InstrumentString(_b3),
    InstrumentString(_e4),
  ]),
  Tuning('drop_d', 'Drop D', 'Guitar', [
    InstrumentString(38),
    InstrumentString(_a2),
    InstrumentString(_d3),
    InstrumentString(_g3),
    InstrumentString(_b3),
    InstrumentString(_e4),
  ]),
  Tuning('d_standard', 'D standard', 'Guitar', [
    InstrumentString(38),
    InstrumentString(43),
    InstrumentString(48),
    InstrumentString(53),
    InstrumentString(57),
    InstrumentString(62),
  ]),
  Tuning('open_g', 'Open G', 'Guitar', [
    InstrumentString(38),
    InstrumentString(43),
    InstrumentString(_d3),
    InstrumentString(_g3),
    InstrumentString(_b3),
    InstrumentString(62),
  ]),
  Tuning('open_d', 'Open D', 'Guitar', [
    InstrumentString(38),
    InstrumentString(_a2),
    InstrumentString(_d3),
    InstrumentString(54),
    InstrumentString(57),
    InstrumentString(62),
  ]),
  Tuning('dadgad', 'DADGAD', 'Guitar', [
    InstrumentString(38),
    InstrumentString(_a2),
    InstrumentString(_d3),
    InstrumentString(_g3),
    InstrumentString(57),
    InstrumentString(62),
  ]),
  Tuning('half_down', 'Half step down', 'Guitar', [
    InstrumentString(39),
    InstrumentString(44),
    InstrumentString(49),
    InstrumentString(54),
    InstrumentString(58),
    InstrumentString(63),
  ]),
  Tuning('bass4', 'Bass 4-string', 'Bass', [
    InstrumentString(28),
    InstrumentString(33),
    InstrumentString(38),
    InstrumentString(43),
  ]),
  Tuning('ukulele', 'Ukulele GCEA', 'Ukulele', [
    InstrumentString(67),
    InstrumentString(60),
    InstrumentString(64),
    InstrumentString(69),
  ]),
];

Tuning tuningById(String? id) => tunings.firstWhere((t) => t.id == id, orElse: () => tunings.first);
