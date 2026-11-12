import 'dart:math' as math;

/// Note names with sharps, indexed by pitch class (0 = C).
const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

/// Concert pitch of A4 in Hz.
const defaultReferenceA = 440.0;
const minReferenceA = 430.0;
const maxReferenceA = 450.0;

/// Lowest and highest pitch the tuner reports.
const minDetectHz = 30.0;
const maxDetectHz = 2000.0;

/// MIDI note number 69 is A4.
double midiToFreq(double midi, {double refA = defaultReferenceA}) => refA * math.pow(2, (midi - 69) / 12);

/// Fractional MIDI note number of [freq].
double freqToMidi(double freq, {double refA = defaultReferenceA}) => 69 + 12 * math.log(freq / refA) / math.ln2;

/// Signed distance in cents from [reference] to [freq]; positive means sharp.
double centsBetween(double freq, double reference) => 1200 * math.log(freq / reference) / math.ln2;

/// Name of a MIDI note without octave, e.g. `C#`.
String noteName(int midi) => noteNames[midi % 12];

/// Octave in scientific pitch notation (MIDI 60 = C4).
int noteOctave(int midi) => (midi ~/ 12) - 1;

/// The nearest equal-tempered note to a frequency.
class NoteReading {
  const NoteReading({required this.midi, required this.cents, required this.freq, required this.targetFreq});

  /// Nearest MIDI note number.
  final int midi;

  /// Offset from that note, -50..+50.
  final double cents;

  /// The measured frequency.
  final double freq;

  /// Exact frequency of the nearest note.
  final double targetFreq;

  String get name => noteName(midi);
  int get octave => noteOctave(midi);
  String get label => '$name$octave';

  /// Rounds [freq] to the closest note.
  factory NoteReading.fromFreq(double freq, {double refA = defaultReferenceA}) {
    final exact = freqToMidi(freq, refA: refA);
    final midi = exact.round();
    final target = midiToFreq(midi.toDouble(), refA: refA);
    return NoteReading(midi: midi, cents: centsBetween(freq, target), freq: freq, targetFreq: target);
  }
}

/// A reading counts as in tune within this many cents.
const inTuneCents = 4.0;

bool isInTune(double cents) => cents.abs() <= inTuneCents;
