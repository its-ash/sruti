import 'dart:math' as math;
import 'dart:typed_data';

/// What the drone plays.
enum DronePattern {
  /// Tanpura strings Pa (low), Sa, Sa, Sa (low).
  paSa('Pa Sa Sa Sa', 'प सा सा सा'),

  /// Tanpura strings Ma (low), Sa, Sa, Sa (low).
  maSa('Ma Sa Sa Sa', 'म सा सा सा'),

  /// Tanpura strings Ni (low), Sa, Sa, Sa (low).
  niSa('Ni Sa Sa Sa', 'नि सा सा सा'),

  /// A steady, continuous Sa and Pa (sruti box).
  sruti('Sruti (Sa Pa)', 'श्रुति (सा प)');

  const DronePattern(this.label, this.devanagari);

  final String label;
  final String devanagari;

  bool get isTanpura => this != DronePattern.sruti;
}

/// Frequency ratios of the four tanpura strings in plucking order, relative
/// to the middle Sa (just intonation: Pa 3/2, Ma 4/3, Ni 15/8, one octave
/// down for the first string).
List<double> tanpuraRatios(DronePattern pattern) {
  final first = switch (pattern) {
    DronePattern.paSa => 3 / 4,
    DronePattern.maSa => 2 / 3,
    DronePattern.niSa => 15 / 16,
    DronePattern.sruti => 3 / 4,
  };
  return [first, 1, 1, 0.5];
}

const droneSampleRate = 22050;
const minDroneBpm = 20.0;
const maxDroneBpm = 90.0;

/// Seconds a tanpura pluck rings.
const _pluckSeconds = 7.0;

/// Renders one seamless loop of the drone as mono samples, peak 0.85.
///
/// Tanpura patterns pluck four strings evenly spaced at [bpm] plucks per
/// minute; the tails of the plucks wrap around the end of the loop, so
/// looping it gives a continuous tanpura. Each pluck is additive: up to 16
/// harmonics whose amplitudes first swell and then fade at different rates,
/// the sweep of the jawari bridge.
///
/// [DronePattern.sruti] is a sustained Sa + Pa + low Sa. The loop length is
/// chosen so that every partial completes a whole number of cycles in it,
/// which makes the seam inaudible without detuning Sa.
Float64List renderDrone({
  required double saFreq,
  required DronePattern pattern,
  double bpm = 45,
  int sampleRate = droneSampleRate,
}) {
  final buf = pattern.isTanpura
      ? _renderTanpura(saFreq, pattern, bpm.clamp(minDroneBpm, maxDroneBpm).toDouble(), sampleRate)
      : _renderSruti(saFreq, sampleRate);
  var peak = 0.0;
  for (final v in buf) {
    if (v.abs() > peak) peak = v.abs();
  }
  if (peak > 0) {
    final g = 0.85 / peak;
    for (var i = 0; i < buf.length; i++) {
      buf[i] *= g;
    }
  }
  return buf;
}

Float64List _renderTanpura(double saFreq, DronePattern pattern, double bpm, int sr) {
  final interval = 60 / bpm;
  final n = (4 * interval * sr).round();
  final out = Float64List(n);
  final ratios = tanpuraRatios(pattern);
  const gains = [1.0, 0.85, 0.85, 0.95];
  for (var s = 0; s < 4; s++) {
    _addPluck(out, startSample: (s * interval * sr).round(), freq: saFreq * ratios[s], gain: gains[s], sr: sr);
  }
  return out;
}

/// One jawari-like pluck of [freq] Hz, [seconds] long (for tests and previews).
Float64List renderPluck(double freq, {double seconds = 3, int sampleRate = droneSampleRate}) {
  final out = Float64List((seconds * sampleRate).round());
  _addPluck(out, startSample: 0, freq: freq, gain: 1, sr: sampleRate);
  return out;
}

/// Adds a jawari-like plucked string to [out], wrapping around its end.
void _addPluck(Float64List out, {required int startSample, required double freq, required double gain, required int sr}) {
  final n = out.length;
  final harmonics = math.min(16, (0.45 * sr / freq).floor());
  final length = (_pluckSeconds * sr).round();
  final amp = List<double>.generate(harmonics, (h) => 1 / math.pow(h + 1, 0.75));
  final decay = List<double>.generate(harmonics, (h) => 1 / (3.4 / (1 + 0.28 * h)));
  // Higher partials bloom later: the jawari buzz.
  final swell = List<double>.generate(harmonics, (h) => h < 2 ? 0.0 : 1.6);
  final swellTime = List<double>.generate(harmonics, (h) => 0.25 + 0.05 * h);
  final w = List<double>.generate(harmonics, (h) => 2 * math.pi * freq * (h + 1) / sr);
  for (var i = 0; i < length; i++) {
    final t = i / sr;
    var v = 0.0;
    for (var h = 0; h < harmonics; h++) {
      final x = t / swellTime[h];
      final bloom = 1 + swell[h] * x * math.exp(1 - x);
      v += amp[h] * bloom * math.exp(-t * decay[h]) * math.sin(w[h] * i);
    }
    final attack = 1 - math.exp(-t / 0.003);
    out[(startSample + i) % n] += gain * attack * v;
  }
}

/// Picks a loop length (samples) near four seconds in which Sa completes an
/// even whole number of cycles, so Pa (3/2) and low Sa (1/2) do too.
/// Returns the length and the cycle count.
({int samples, int cycles}) loopFor(double saFreq, int sr) {
  final lo = (3.5 * sr).round();
  final hi = (4.5 * sr).round();
  var bestN = lo;
  var bestK = 2;
  var bestErr = double.infinity;
  for (var n = lo; n <= hi; n++) {
    final cycles = saFreq * n / sr;
    final k = 2 * (cycles / 2).round();
    final err = (cycles - k).abs() / cycles;
    if (k >= 2 && err < bestErr) {
      bestErr = err;
      bestN = n;
      bestK = k;
    }
  }
  return (samples: bestN, cycles: bestK);
}

Float64List _renderSruti(double saFreq, int sr) {
  final loop = loopFor(saFreq, sr);
  final n = loop.samples;
  final out = Float64List(n);
  // Effective Sa such that loop.cycles cycles fit exactly in n samples.
  final sa = loop.cycles * sr / n;
  const voices = [(0.5, 0.7), (1.0, 1.0), (1.5, 0.75)];
  for (final (ratio, gain) in voices) {
    final f = sa * ratio;
    final harmonics = math.min(10, (0.45 * sr / f).floor());
    for (var h = 1; h <= harmonics; h++) {
      final a = gain / math.pow(h, 1.1);
      final w = 2 * math.pi * f * h / sr;
      for (var i = 0; i < n; i++) {
        out[i] += a * math.sin(w * i);
      }
    }
  }
  // Gentle breathing: two whole cycles of amplitude modulation per loop.
  for (var i = 0; i < n; i++) {
    out[i] *= 1 + 0.1 * math.sin(2 * math.pi * 2 * i / n);
  }
  return out;
}

/// 16-bit little-endian PCM from samples in -1..1.
Uint8List toPcm16(Float64List samples) {
  final bytes = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    bytes.setInt16(i * 2, v, Endian.little);
  }
  return bytes.buffer.asUint8List();
}
